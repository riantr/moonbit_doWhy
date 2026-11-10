"""The upstream reference for the divergence and the density estimators of the `gcm` package.

The script runs the upstream `dowhy.gcm.divergence` and `dowhy.gcm.density_estimators`
on the very data the MoonBit port works on, and prints the numbers the port has to
reproduce. The data is generated with a Python replica of the xorshift generator of
`src/utils/random.mbt`, so the two sides work on the same rows.

The upstream package cannot be imported as it is, because its `__init__` pulls in
`causallearn`; the loader of `upstream_gcm.py` reads the modules straight from their
files instead.

The upstream classifier based estimator draws the folds of its cross validation with
the global numpy random state, so the script seeds numpy before every call. The
printed value is therefore reproducible, but the folds of the port come from its own
generator, so the two values only agree up to the tolerance of the test.

Usage:
    python _verify/gcm_divergence_reference.py
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

    def next_int(self, bound: int) -> int:
        if bound <= 0:
            return 0
        return self.next_u64() % bound

    def shuffle(self, values: list[int]) -> list[int]:
        """The shuffle of `Random::shuffle` of `src/utils/random.mbt`."""
        out = list(values)
        i = len(out) - 1
        while i > 0:
            j = self.next_int(i + 1)
            out[i], out[j] = out[j], out[i]
            i -= 1
        return out


# The seeds of the fixtures. They are the ones the MoonBit tests use.
GAUSSIAN_SEED = 2024
MULTI_SEED = 2025
EXPONENTIAL_SEED = 2026
CATEGORICAL_SEED = 2027
MIXED_SEED = 2028

# The seed of the numpy random state, which the upstream classifier based estimator
# uses for the folds of its cross validation.
NUMPY_SEED = 20240815


def normals(rng: Xorshift, mean: float, count: int) -> np.ndarray:
    """`count` standard normal draws around `mean`."""
    return np.array([mean + rng.next_normal() for _ in range(count)])


def exponentials(rng: Xorshift, scale: float, count: int) -> np.ndarray:
    """`count` exponential draws with the given scale."""
    values = []
    for _ in range(count):
        u = rng.next_double()
        u = 1.0e-12 if u < 1.0e-12 else u
        values.append(-np.log(u) / scale)
    return np.array(values)


def categories(rng: Xorshift, probabilities: list[float], count: int) -> np.ndarray:
    """`count` draws of the categories with the given probabilities."""
    cumulative = np.cumsum(probabilities)
    values = []
    for _ in range(count):
        u = rng.next_double()
        values.append(float(min(int(np.searchsorted(cumulative, u, side="right")), len(probabilities) - 1)))
    return np.array(values)


def gaussian_fixture() -> tuple[np.ndarray, np.ndarray]:
    """Two thousand normal draws around zero and around one."""
    rng = Xorshift(GAUSSIAN_SEED)
    x = normals(rng, 0.0, 2000)
    y = normals(rng, 1.0, 2000)
    return x.reshape(-1, 1), y.reshape(-1, 1)


def gaussian_2d_fixture() -> tuple[np.ndarray, np.ndarray]:
    """Two thousand normal draws around zero and around one, in two columns."""
    rng = Xorshift(MULTI_SEED)
    x = np.column_stack([normals(rng, 0.0, 2000), normals(rng, 0.0, 2000)])
    y = np.column_stack([normals(rng, 1.0, 2000), normals(rng, 1.0, 2000)])
    return x, y


def exponential_fixture() -> tuple[np.ndarray, np.ndarray]:
    """Two thousand exponential draws with the scales one and a half."""
    rng = Xorshift(EXPONENTIAL_SEED)
    x = exponentials(rng, 1.0, 2000)
    y = exponentials(rng, 0.5, 2000)
    return x.reshape(-1, 1), y.reshape(-1, 1)


def categorical_fixture() -> tuple[np.ndarray, np.ndarray]:
    """A thousand draws of four categories with two different distributions."""
    rng = Xorshift(CATEGORICAL_SEED)
    x = categories(rng, [0.25, 0.5, 0.125, 0.125], 1000)
    y = categories(rng, [0.5, 0.25, 0.125, 0.125], 1000)
    return x.reshape(-1, 1), y.reshape(-1, 1)


def overlapping_fixture() -> tuple[np.ndarray, np.ndarray]:
    """The gaussian fixture, with the first ten rows of X in Y as well."""
    x, y = gaussian_fixture()
    y = y.copy()
    y[:10] = x[:10]
    return x, y


def mixed_fixture() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """The fixture of the mixed gaussian and categorical sample.

    The sample `x` holds a gaussian column and a column of three categories,
    `y_gaussian` holds the gaussian column shifted by one and the same
    categories, and `y_categorical` holds the shifted gaussian column and four
    categories. The upstream builds its samples as object arrays, so the
    categories are the strings of the numbers.
    """
    rng = Xorshift(MIXED_SEED)
    x_gaussian = normals(rng, 0.0, 2000)
    x_categories = categories(rng, [1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0], 2000)
    y_gaussian = normals(rng, 1.0, 2000)
    y_categories = categories(rng, [0.25, 0.25, 0.25, 0.25], 2000)

    def sample(gaussian: np.ndarray, categorical: np.ndarray) -> np.ndarray:
        # The upstream builds its samples as object arrays, so the gaussian
        # column keeps its numbers and the categorical column its strings. The
        # array is built the way the upstream builds it, because a column
        # stack of a numeric and a string array would turn the numbers into
        # strings as well.
        return np.array([gaussian, categorical.astype(int).astype(str)], dtype=object).T

    x = sample(x_gaussian, x_categories)
    y_gaussian_same_categories = sample(y_gaussian, x_categories)
    y_other_categories = sample(y_gaussian, y_categories)
    return x, y_gaussian_same_categories, y_other_categories


def probability_fixture() -> tuple[np.ndarray, np.ndarray]:
    """Two rows of probabilities and the same two rows with the first two swapped."""
    x = np.array([[0.25, 0.5, 0.125, 0.125], [0.5, 0.25, 0.125, 0.125]])
    y = np.array([[0.5, 0.25, 0.125, 0.125], [0.25, 0.5, 0.125, 0.125]])
    return x, y


def load_upstream() -> tuple[object, object]:
    """The upstream divergence and density estimator modules."""
    # The modules import each other in a chain, so they are loaded in the order
    # of the loader.
    for name in (
        "dowhy.gcm.constant",
        "dowhy.gcm.config",
        "dowhy.gcm.density_estimator",
        "dowhy.gcm.anomaly_scorer",
        "dowhy.gcm.util.catboost_encoder",
        "dowhy.gcm.util.general",
        "dowhy.gcm.stats",
        "dowhy.gcm.confidence_intervals",
        "dowhy.gcm.ml.prediction_model",
        "dowhy.gcm.ml.regression",
        "dowhy.gcm.ml.classification",
        "dowhy.gcm.ml",
        "dowhy.gcm.stochastic_models",
        "dowhy.gcm.causal_mechanisms",
        "dowhy.gcm.causal_models",
        "dowhy.gcm.auto",
    ):
        load(name)
    return load("dowhy.gcm.divergence"), load("dowhy.gcm.density_estimators")


def upstream_clf(divergence: object, samples_p: np.ndarray, samples_q: np.ndarray) -> float:
    """The upstream classifier based estimator, with a reproducible split."""
    np.random.seed(NUMPY_SEED)
    return float(divergence.estimate_kl_divergence_continuous_clf(samples_p, samples_q))


def main() -> None:
    divergence, density_estimators = load_upstream()

    x, y = gaussian_fixture()
    print("GAUSSIAN_KNN")
    print(f"  same = {divergence.estimate_kl_divergence_continuous_knn(x, x):.12f}")
    print(f"  different = {divergence.estimate_kl_divergence_continuous_knn(x, y):.12f}")
    print("GAUSSIAN_CLF")
    print(f"  same = {upstream_clf(divergence, x, x):.12f}")
    print(f"  different = {upstream_clf(divergence, x, y):.12f}")
    print("GAUSSIAN_AUTO")
    print(f"  same = {divergence.auto_estimate_kl_divergence(x, x):.12f}")
    print(f"  different = {divergence.auto_estimate_kl_divergence(x, y):.12f}")

    x2, y2 = gaussian_2d_fixture()
    print("MULTI_CLF")
    print(f"  same = {upstream_clf(divergence, x2, x2):.12f}")
    print(f"  different = {upstream_clf(divergence, x2, y2):.12f}")

    xe, ye = exponential_fixture()
    print("EXPONENTIAL")
    print(f"  clf = {upstream_clf(divergence, xe, ye):.12f}")
    print(f"  knn = {divergence.estimate_kl_divergence_continuous_knn(xe, ye):.12f}")

    xc, yc = categorical_fixture()
    print("CATEGORICAL")
    print(f"  same = {divergence.estimate_kl_divergence_categorical(xc, xc):.12f}")
    print(f"  different = {divergence.estimate_kl_divergence_categorical(xc, yc):.12f}")
    # The automatic estimate of the upstream detects a categorical input from the
    # dtype of its numpy array, so the categories are the strings of the numbers.
    xc_str = xc.astype(int).astype(str)
    yc_str = yc.astype(int).astype(str)
    print("CATEGORICAL_AUTO")
    print(f"  same = {divergence.auto_estimate_kl_divergence(xc_str, xc_str):.12f}")
    print(f"  different = {divergence.auto_estimate_kl_divergence(xc_str, yc_str):.12f}")

    xm, ym_same, ym_other = mixed_fixture()
    print("MIXED_CLF")
    print(f"  same = {upstream_clf(divergence, xm, xm):.12f}")
    print(f"  gaussian_only = {upstream_clf(divergence, xm, ym_same):.12f}")
    print(f"  both = {upstream_clf(divergence, xm, ym_other):.12f}")

    xo, yo = overlapping_fixture()
    print("OVERLAPPING_KNN")
    print(f"  different = {divergence.estimate_kl_divergence_continuous_knn(xo, yo):.12f}")

    xp, yp = probability_fixture()
    print("PROBABILITIES")
    print(f"  divergence = {divergence.estimate_kl_divergence_of_probabilities(xp, yp):.12f}")
    print(f"  auto = {divergence.auto_estimate_kl_divergence(xp, yp):.12f}")
    print("IS_PROBABILITY_MATRIX")
    print(f"  one_row = {divergence.is_probability_matrix(np.array([[0.5, 0.3, 0.2]]))}")
    print(f"  one_row_wrong = {divergence.is_probability_matrix(np.array([[0.1, 0.3, 0.2]]))}")
    print(
        "  two_rows = "
        f"{divergence.is_probability_matrix(np.array([[0.5, 0.3, 0.2], [0.1, 0.2, 0.7]]))}"
    )
    print(f"  normal = {divergence.is_probability_matrix(np.array([[1.0, 2.0, 3.0], [-1.0, 0.5, 2.0]]))}")
    print(f"  one_column = {divergence.is_probability_matrix(np.array([[0.0], [1.0], [2.0]]))}")

    # The kernel density estimator of the upstream, on the data of its own test.
    # The scikit-learn of the reference environment normalises the gaussian
    # kernel with 1 / sqrt(2 * pi), so the densities it returns are probability
    # densities; the older versions left the factor out.
    data = np.array([[0.0], [2.0], [1.0], [3.0]])
    estimator = density_estimators.KernelDensityEstimator1D()
    estimator.fit(data)
    densities = estimator.density(data)
    bandwidth = float(np.std(data) * np.power(4 / 3 / data.shape[0], 1 / 5))
    print("KERNEL_DENSITY")
    print(f"  bandwidth = {bandwidth:.12f}")
    for index, value in enumerate(densities):
        print(f"  density[{index}] = {value:.12f}")


if __name__ == "__main__":
    main()
