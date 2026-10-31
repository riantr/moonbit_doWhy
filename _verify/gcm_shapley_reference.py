"""The upstream reference for the Shapley values and the independence tests.

The script runs the upstream `dowhy.gcm.shapley` and the upstream independence
tests on the very rows the MoonBit port works on, and prints the numbers the
port has to reproduce. The rows are generated with a Python replica of the
xorshift generator of `src/utils/random.mbt`, so the two sides fit the same
data.

The upstream package cannot be imported as it is, because its `__init__` pulls
in `causallearn`; the loader of `upstream_gcm.py` reads the modules straight
from their files instead.

The p-values of the regression based independence test depend on the folds the
upstream draws with `KFold(shuffle=True)` and on the basis points its
`Nystroem` transformer picks, and both come from the global numpy generator.
The seed of numpy is therefore fixed before every call, so that the printed
numbers are reproducible. The port draws the folds and the basis points from
the generator it is given, which is why its p-values differ slightly from the
printed ones; the two agree on the decision the tests assert.

Usage:
    python _verify/gcm_shapley_reference.py
"""

from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from upstream_gcm import load  # noqa: E402

MASK64 = (1 << 64) - 1

# The seed of the fixtures; the same one the MoonBit tests use.
SEED = 2024

# The size of the Shapley fixture.
SHAPLEY_NUM_SAMPLES = 100
SHAPLEY_NUM_FEATURES = 8

# The number of features of the model with few players, which the automatic
# method estimates with the exact method.
SHAPLEY_NUM_FEATURES_FEW = 4

# The size of the fixtures of the independence tests.
INDEPENDENCE_NUM_SAMPLES = 1000


class Xorshift:
    """The generator of `src/utils/random.mbt`."""

    def __init__(self, seed: int) -> None:
        self.state = seed if seed != 0 else 0x9E3779B97F4A7C15

    def next_u64(self) -> int:
        x = self.state
        x ^= (x << 13) & MASK64
        x ^= x >> 7
        x ^= (x << 17) & MASK64
        self.state = x
        return x

    def next_double(self) -> float:
        return (self.next_u64() >> 11) / 9007199254740992.0

    def next_normal(self) -> float:
        u1 = self.next_double()
        u2 = self.next_double()
        u1 = 1.0e-12 if u1 < 1.0e-12 else u1
        return np.sqrt(-2.0 * np.log(u1)) * np.cos(2.0 * np.pi * u2)

    def next_int(self, bound: int) -> int:
        return self.next_u64() % bound


def shapley_fixture() -> tuple[np.ndarray, np.ndarray]:
    """The rows and the coefficients of the linear model of the Shapley tests.

    The draws happen in the order of the MoonBit test: the whole matrix row by
    row, and then the coefficients.
    """
    rng = Xorshift(SEED)
    samples = np.array(
        [[rng.next_normal() for _ in range(SHAPLEY_NUM_FEATURES)] for _ in range(SHAPLEY_NUM_SAMPLES)]
    )
    coefficients = np.array([rng.next_int(20) - 10 for _ in range(SHAPLEY_NUM_FEATURES)], dtype=float)
    return samples, coefficients


def independence_fixture() -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """The rows of the independence tests: `z`, `w`, `x` and `y`.

    The draws happen in the order of the MoonBit test: the two normal vectors
    first, and then the two uniform vectors that shift `z` into `x` and `y`.
    """
    rng = Xorshift(SEED)
    count = INDEPENDENCE_NUM_SAMPLES
    z = np.array([[rng.next_normal()] for _ in range(count)])
    w = np.array([[rng.next_normal()] for _ in range(count)])
    x = np.exp(z + np.array([[rng.next_double()] for _ in range(count)]))
    y = np.exp(z + np.array([[rng.next_double()] for _ in range(count)]))
    return z, w, x, y


def set_function(subset: np.ndarray, samples: np.ndarray, coefficients: np.ndarray) -> float:
    """The set function of the Shapley tests.

    It is the upstream `_set_function_for_aggregated_feature_attribution`: the
    features of the subset keep the values of the first sample, the other ones
    are permuted, and the difference of the means of the model is returned.
    """
    stats = load("dowhy.gcm.stats")
    general = load("dowhy.gcm.util.general")
    permuted = stats.permute_features(samples, np.arange(0, samples.shape[1])[subset == 0], False)
    permuted[:, subset == 1] = samples[0, subset == 1]
    model = np.sum(coefficients * permuted, axis=1)
    return general.means_difference(model, samples[0])


def main() -> None:
    shapley = load("dowhy.gcm.shapley")
    general = load("dowhy.gcm.util.general")
    stats = load("dowhy.gcm.stats")
    regression = load("dowhy.gcm.independence_test.regression")
    # The generalised covariance measure reaches for the automatic model
    # selection of `dowhy.gcm.auto`, which needs the prediction models of
    # `dowhy.gcm.ml`; the real package has to be loaded before it, because the
    # loader stubs the packages out.
    load("dowhy.gcm.ml")
    generalised = load("dowhy.gcm.independence_test.generalised_cov_measure")

    # The upstream code runs its folds in parallel with joblib, whose workers
    # cannot import the stubbed `dowhy` package; one job keeps it in this
    # process, and the progress bars are turned off to keep the output clean.
    config = load("dowhy.gcm.config")
    config.set_default_n_jobs(1)
    config.disable_progress_bars()

    samples, coefficients = shapley_fixture()
    print("SHAPLEY_FIXTURE")
    print(f"  num_samples = {SHAPLEY_NUM_SAMPLES}")
    print(f"  num_features = {SHAPLEY_NUM_FEATURES}")
    for index, coefficient in enumerate(coefficients):
        print(f"  coefficient[{index}] = {coefficient:.12f}")
    expected = coefficients * (samples[0, :] - np.mean(samples, axis=0))
    print("  expected = coefficients * (X[0, :] - mean(X, axis=0))")
    for index, value in enumerate(expected):
        print(f"  expected[{index}] = {value:.12f}")

    for name in (
        "AUTO",
        "EXACT",
        "EXACT_FAST",
        "SUBSET_SAMPLING",
        "PERMUTATION",
        "EARLY_STOPPING",
    ):
        method = getattr(shapley.ShapleyApproximationMethods, name)
        config = shapley.ShapleyConfig(approximation_method=method, n_jobs=1)
        np.random.seed(0)
        values = shapley.estimate_shapley_values(
            lambda subset: set_function(subset, samples, coefficients),
            samples.shape[1],
            config,
        )
        print(f"SHAPLEY_{name}")
        for index, value in enumerate(np.asarray(values).reshape(-1)):
            print(f"  shapley[{index}] = {value:.12f}")

    # The same model with the first four features, which is the case of the
    # automatic method that uses the exact method.
    few_samples = samples[:, :SHAPLEY_NUM_FEATURES_FEW]
    few_coefficients = coefficients[:SHAPLEY_NUM_FEATURES_FEW]
    few_expected = few_coefficients * (few_samples[0, :] - np.mean(few_samples, axis=0))
    print("SHAPLEY_FIXTURE_FEW")
    print(f"  num_features = {SHAPLEY_NUM_FEATURES_FEW}")
    for index, coefficient in enumerate(few_coefficients):
        print(f"  coefficient[{index}] = {coefficient:.12f}")
    for index, value in enumerate(few_expected):
        print(f"  expected[{index}] = {value:.12f}")
    method = shapley.ShapleyApproximationMethods.AUTO
    config = shapley.ShapleyConfig(approximation_method=method, n_jobs=1)
    np.random.seed(0)
    values = shapley.estimate_shapley_values(
        lambda subset: set_function(subset, few_samples, few_coefficients),
        few_samples.shape[1],
        config,
    )
    print("SHAPLEY_AUTO_FEW")
    for index, value in enumerate(np.asarray(values).reshape(-1)):
        print(f"  shapley[{index}] = {value:.12f}")

    z, w, x, y = independence_fixture()
    print("INDEPENDENCE_FIXTURE")
    print(f"  num_samples = {INDEPENDENCE_NUM_SAMPLES}")
    print(f"  mean(z) = {np.mean(z):.12f}")
    print(f"  mean(x) = {np.mean(x):.12f}")
    print(f"  mean(y) = {np.mean(y):.12f}")
    print(f"  mean(w) = {np.mean(w):.12f}")

    np.random.seed(0)
    conditional_independent = regression.regression_based(x, y, z)
    np.random.seed(0)
    conditional_dependent = regression.regression_based(x, y, w)
    np.random.seed(0)
    pairwise_independent = regression.regression_based(x, w)
    np.random.seed(0)
    pairwise_dependent = regression.regression_based(x, y)
    print("REGRESSION_BASED")
    print(f"  conditional_independent = {conditional_independent:.12f}")
    print(f"  conditional_dependent = {conditional_dependent:.12f}")
    print(f"  pairwise_independent = {pairwise_independent:.12f}")
    print(f"  pairwise_dependent = {pairwise_dependent:.12f}")

    np.random.seed(0)
    generalised_conditional_independent = generalised.generalised_cov_based(x, y, z)
    np.random.seed(0)
    generalised_conditional_dependent = generalised.generalised_cov_based(x, y, w)
    np.random.seed(0)
    generalised_pairwise_independent = generalised.generalised_cov_based(x, w)
    np.random.seed(0)
    generalised_pairwise_dependent = generalised.generalised_cov_based(x, y)
    print("GENERALISED_COV_BASED")
    print(f"  conditional_independent = {generalised_conditional_independent:.12f}")
    print(f"  conditional_dependent = {generalised_conditional_dependent:.12f}")
    print(f"  pairwise_independent = {generalised_pairwise_independent:.12f}")
    print(f"  pairwise_dependent = {generalised_pairwise_dependent:.12f}")

    # The helpers the port shares with the upstream.
    print("HELPERS")
    print(f"  comb(7, 3) = {__import__('scipy.special', fromlist=['comb']).comb(7, 3):.12f}")
    print(f"  merge_p_values_average([0.1, 0.2]) = {stats.merge_p_values_average([0.1, 0.2]):.12f}")
    print(f"  means_difference = {general.means_difference([1.0, 2.0], [0.0, 0.0]):.12f}")


if __name__ == "__main__":
    main()
