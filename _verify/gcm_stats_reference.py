"""The reference numbers of the statistics of the `gcm` package.

The script runs the upstream `dowhy.gcm.stats` and
`dowhy.gcm.confidence_intervals` on the very data the MoonBit port works on,
and prints the numbers the port has to reproduce. The data of the F-test and
of the marginal expectation is generated with a Python replica of the xorshift
generator of `src/utils/random.mbt`, so the two sides fit the same rows.

The upstream package cannot be imported as it is, because its `__init__` pulls
in `causallearn`; the loader of `upstream_gcm.py` reads the modules straight
from their files instead.

The marginal expectation of a linear model does not depend on the permutation
of the features: the average of a linear prediction over the randomized
features is the same for every permutation. The upstream code therefore
reproduces the very same number as the port, although the two draw their
permutations from different generators.

Usage:
    python _verify/gcm_stats_reference.py
"""

from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from upstream_gcm import load  # noqa: E402

MASK64 = (1 << 64) - 1


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


# The seed of the fixtures, the same as the one of the MoonBit tests.
SEED_FTEST = 2024
SEED_MARGINAL = 2025

# The number of rows of the fixtures.
FTEST_ROWS = 200
MARGINAL_ROWS = 200

# The number of rows of the samples of the marginal expectation.
SHAPE_BASELINE_ROWS = 34
SHAPE_FEATURE_ROWS = 123

# The size of the noise of the F-test fixtures.
#
# The upstream test uses a noise of 0.05, which makes the p-value of the
# dependent data so small that it underflows to zero and cannot be compared
# with the port. The noise of 5.0 keeps the p-value a number of a moderate
# size, while the dependency of the data is still strong enough for the
# p-value to be below 0.05.
FTEST_NOISE = 4.0

# The size of the noise of the multivariate F-test fixtures. The model with two
# features is compared with a model with one feature, so the extra parameter
# buys less than the extra feature of the univariate case and the noise has to
# be smaller for the p-value to be below 0.05.
FTEST_NOISE_MULTIVARIATE = 3.0


def ftest_fixtures() -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """The dependent fixture of the F-test.

    The target is the feature plus a small noise, so the model with the feature
    is much better than the model without it.
    """
    rng = Xorshift(SEED_FTEST)
    x_training = np.array([rng.next_normal() for _ in range(FTEST_ROWS)])
    y_training = x_training + FTEST_NOISE * np.array([rng.next_normal() for _ in range(FTEST_ROWS)])
    x_test = np.array([rng.next_normal() for _ in range(FTEST_ROWS)])
    y_test = x_test + FTEST_NOISE * np.array([rng.next_normal() for _ in range(FTEST_ROWS)])
    return x_training, y_training, x_test, y_test


def ftest_independent_fixtures() -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """The independent fixture of the F-test.

    The target is pure noise, so the feature does not help at all.
    """
    rng = Xorshift(SEED_FTEST)
    x_training = np.array([rng.next_normal() for _ in range(FTEST_ROWS)])
    y_training = FTEST_NOISE * np.array([rng.next_normal() for _ in range(FTEST_ROWS)])
    x_test = np.array([rng.next_normal() for _ in range(FTEST_ROWS)])
    y_test = FTEST_NOISE * np.array([rng.next_normal() for _ in range(FTEST_ROWS)])
    return x_training, y_training, x_test, y_test


def ftest_multivariate_fixtures() -> tuple[np.ndarray, ...]:
    """The dependent fixture of the F-test with two features.

    The model with the two features is compared with the model with one
    feature, so the residual sum of squares of the smaller model comes from a
    fit and not from the mean of the target.
    """
    rng = Xorshift(SEED_FTEST)
    x1_training = np.array([rng.next_normal() for _ in range(FTEST_ROWS)])
    x2_training = np.array([rng.next_normal() for _ in range(FTEST_ROWS)])
    y_training = x1_training + x2_training + FTEST_NOISE_MULTIVARIATE * np.array(
        [rng.next_normal() for _ in range(FTEST_ROWS)]
    )
    x1_test = np.array([rng.next_normal() for _ in range(FTEST_ROWS)])
    x2_test = np.array([rng.next_normal() for _ in range(FTEST_ROWS)])
    y_test = x1_test + x2_test + FTEST_NOISE_MULTIVARIATE * np.array([rng.next_normal() for _ in range(FTEST_ROWS)])
    return (
        np.column_stack([x1_training, x2_training]),
        x1_training,
        y_training,
        np.column_stack([x1_test, x2_test]),
        x1_test,
        y_test,
    )


def ftest_multivariate_independent_fixtures() -> tuple[np.ndarray, ...]:
    """The independent fixture of the F-test with two features."""
    rng = Xorshift(SEED_FTEST)
    x1_training = np.array([rng.next_normal() for _ in range(FTEST_ROWS)])
    x2_training = np.array([rng.next_normal() for _ in range(FTEST_ROWS)])
    y_training = FTEST_NOISE_MULTIVARIATE * np.array([rng.next_normal() for _ in range(FTEST_ROWS)])
    x1_test = np.array([rng.next_normal() for _ in range(FTEST_ROWS)])
    x2_test = np.array([rng.next_normal() for _ in range(FTEST_ROWS)])
    y_test = FTEST_NOISE_MULTIVARIATE * np.array([rng.next_normal() for _ in range(FTEST_ROWS)])
    return (
        np.column_stack([x1_training, x2_training]),
        x1_training,
        y_training,
        np.column_stack([x1_test, x2_test]),
        x1_test,
        y_test,
    )


def marginal_fixture() -> tuple[np.ndarray, np.ndarray]:
    """The fixture of the marginal expectation.

    The features are standard normal and the target is a linear combination of
    them, like the fixture of the upstream test.
    """
    rng = Xorshift(SEED_MARGINAL)
    rows = [[rng.next_normal() for _ in range(3)] for _ in range(MARGINAL_ROWS)]
    x = np.array(rows)
    y = 3.0 * x[:, 0] + 2.0 * x[:, 1] - x[:, 2]
    return x, y


def shape_fixture() -> tuple[np.ndarray, np.ndarray]:
    """The fixture of the shape of the marginal expectation.

    The baseline samples come first and the samples of the features after
    them, like in the MoonBit test.
    """
    rng = Xorshift(SEED_MARGINAL)
    baseline = np.array([[rng.next_normal() for _ in range(3)] for _ in range(SHAPE_BASELINE_ROWS)])
    features = np.array([[rng.next_normal() for _ in range(3)] for _ in range(SHAPE_FEATURE_ROWS)])
    return baseline, features


def main() -> None:
    stats = load("dowhy.gcm.stats")
    # The upstream confidence intervals import the configuration with
    # `from dowhy.gcm import config`, which needs the submodule to be reachable
    # under the name of the package.
    load("dowhy.gcm.config")
    intervals = load("dowhy.gcm.confidence_intervals")

    # The merging of the p-values with the quantile based method.
    p_values = np.array([0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.09, 0.1])
    print("MERGE_P_VALUES_QUANTILE")
    print(f"  q0.50 = {stats.merge_p_values_quantile(p_values, quantile=0.5):.12f}")
    print(f"  q0.25 = {stats.merge_p_values_quantile(p_values, quantile=0.25):.12f}")
    print(f"  q0.75 = {stats.merge_p_values_quantile(p_values, quantile=0.75):.12f}")
    with_one = np.array([0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.09, 0.1, 1])
    print(f"  with_one = {stats.merge_p_values_quantile(with_one, quantile=0.5):.12f}")
    print(f"  large = {stats.merge_p_values_quantile(np.array([0.9, 0.95, 1]), quantile=0.5):.12f}")
    print(f"  zeros = {stats.merge_p_values_quantile(np.array([0, 0, 0]), quantile=0.5):.12f}")
    print(f"  single = {stats.merge_p_values_quantile(np.array([0.33]), quantile=0.5):.12f}")
    with_nan = np.array([0.01, np.nan, 0.02, 0.03, 0.04, 0.05, np.nan, 0.06, 0.07, 0.08, 0.09, 0.1])
    print(f"  with_nan = {stats.merge_p_values_quantile(with_nan, quantile=0.5):.12f}")

    # The merging of the p-values with the quantile based method and a scaling.
    scaling = np.array([2, 2, 1, 2, 1, 3, 1, 2, 4, 1])
    print("MERGE_P_VALUES_QUANTILE_SCALED")
    print(f"  q0.50 = {stats.merge_p_values_quantile(p_values, scaling, quantile=0.5):.12f}")
    print(f"  q0.25 = {stats.merge_p_values_quantile(p_values, scaling, quantile=0.25):.12f}")
    print(f"  q0.75 = {stats.merge_p_values_quantile(p_values, scaling, quantile=0.75):.12f}")

    # The merging of the p-values with the false discovery rate control.
    print("MERGE_P_VALUES_FDR")
    for name, values in (
        ("zero", [0]),
        ("one", [1]),
        ("single", [0.3]),
        ("zero_one", [0, 1]),
        ("three", [0.1, 0.2, 0.5]),
        ("with_nan", [0.1, np.nan, 0.2, 0.5, np.nan]),
    ):
        print(f"  {name} = {stats.merge_p_values_fdr(np.array(values)):.12f}")

    # The merging of the p-values with the average of the twice the average rule.
    print("MERGE_P_VALUES_AVERAGE")
    for name, values in (
        ("zero", [0]),
        ("one", [1]),
        ("single", [0.3]),
        ("zero_one", [0, 1]),
        ("zero_zero_one", [0, 0, 1]),
        ("with_nan", [0, 0.5, 0.5, np.nan, 1, np.nan]),
        ("zeros_ones", [0, 0, 1, 1, 1]),
    ):
        print(f"  {name} = {stats.merge_p_values_average(np.array(values)):.12f}")

    # The same with the randomization, which draws the value of `u` from the
    # global generator of numpy.
    print("MERGE_P_VALUES_AVERAGE_RANDOMIZED")
    np.random.seed(SEED_FTEST)
    for name, values in (
        ("zero", [0]),
        ("one", [1]),
        ("single", [0.3]),
        ("zero_one", [0, 1]),
        ("zero_zero_one", [0, 0, 1]),
        ("with_nan", [0, np.nan, 0, np.nan, 1, 1]),
    ):
        print(f"  {name} = {stats.merge_p_values_average(np.array(values), randomization=True):.12f}")

    # The p-value of the F-test on the dependent and on the independent data.
    x_training, y_training, x_test, y_test = ftest_fixtures()
    dependent = stats.estimate_ftest_pvalue(
        x_training, np.array([]), y_training, x_test, np.array([]), y_test
    )
    x_training, y_training, x_test, y_test = ftest_independent_fixtures()
    independent = stats.estimate_ftest_pvalue(
        x_training, np.array([]), y_training, x_test, np.array([]), y_test
    )
    print("FTEST")
    print(f"  dependent = {dependent:.12f}")
    print(f"  dependent_exp = {dependent:.6e}")
    print(f"  independent = {independent:.12f}")
    print(f"  independent_exp = {independent:.6e}")

    # The p-value of the F-test with a model of two features against a model of
    # one feature.
    multivariate = stats.estimate_ftest_pvalue(*ftest_multivariate_fixtures())
    multivariate_independent = stats.estimate_ftest_pvalue(*ftest_multivariate_independent_fixtures())
    print("FTEST_MULTIVARIATE")
    print(f"  dependent = {multivariate:.12f}")
    print(f"  dependent_exp = {multivariate:.6e}")
    print(f"  independent = {multivariate_independent:.12f}")
    print(f"  independent_exp = {multivariate_independent:.6e}")

    # The marginal expectation of a linear model, compared to the model that
    # uses the one feature alone.
    from sklearn.linear_model import LinearRegression

    x, y = marginal_fixture()
    x0 = x[:, 0].reshape(-1, 1)
    model_all_features = LinearRegression().fit(x, y)
    model_feature_0 = LinearRegression().fit(x0, y)
    np.random.seed(SEED_MARGINAL)
    expectation = np.asarray(
        stats.marginal_expectation(
            model_all_features.predict,
            x,
            x,
            [0],
            return_averaged_results=True,
            feature_perturbation="randomize_columns_independently",
        )
    ).reshape(-1)
    difference = np.mean(np.abs(model_feature_0.predict(x0).reshape(-1) - expectation))
    print("MARGINAL_EXPECTATION")
    print(f"  mean_abs_difference = {difference:.12f}")
    print(f"  expectation[0] = {float(expectation[0]):.12f}")
    print(f"  feature_model[0] = {float(model_feature_0.predict(x0)[0]):.12f}")

    # The fixture of the shape of the marginal expectation.
    baseline, features = shape_fixture()
    print("MARGINAL_EXPECTATION_SHAPE")
    print(f"  baseline_rows = {baseline.shape[0]}")
    print(f"  feature_rows = {features.shape[0]}")
    for index in range(3):
        print(f"  baseline[0][{index}] = {baseline[0, index]:.12f}")
    for index in range(3):
        print(f"  features[0][{index}] = {features[0, index]:.12f}")

    # The confidence interval of a counter.
    counter = {"value": 0.0}

    def simple_counter() -> dict[str, float]:
        counter["value"] += 1.0
        return {"X": counter["value"]}

    np.random.seed(SEED_FTEST)
    median, interval = intervals.confidence_intervals(simple_counter, num_bootstrap_resamples=20)
    print("CONFIDENCE_INTERVAL")
    print(f"  median = {median['X']:.12f}")
    print(f"  lower = {interval['X'][0]:.12f}")
    print(f"  upper = {interval['X'][1]:.12f}")


if __name__ == "__main__":
    main()
