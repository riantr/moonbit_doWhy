"""An independent reference for the general helpers of the `gcm` package.

The script runs the upstream `dowhy.gcm.util.general` on the very data the
MoonBit port works on, and prints the numbers the port has to reproduce. The
data is generated with a Python replica of the xorshift generator of
`src/utils/random.mbt`, so the two sides fit the same rows.

The upstream package cannot be imported as it is, because its `__init__` pulls
in `causallearn`; the loader of `upstream_gcm.py` reads the modules straight
from their files instead.

Usage:
    python _verify/gcm_general_reference.py
"""

from __future__ import annotations

import os
import sys

import numpy as np
from scipy.optimize import minimize

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


SEED = 2024


def normal_around(rng: Xorshift, mean: float, count: int) -> list[float]:
    """`count` standard normal draws around `mean`."""
    return [mean + rng.next_normal() for _ in range(count)]


def median_fixture() -> np.ndarray:
    """The fixture of the geometric median test.

    It is the upstream fixture of `tests/gcm/test_stats.py`: a hundred points
    around `(10, -5)` and twenty points around `(10000, -10000)`.
    """
    rng = Xorshift(SEED)
    a = normal_around(rng, 10.0, 100) + normal_around(rng, 10000.0, 20)
    b = normal_around(rng, -5.0, 100) + normal_around(rng, -10000.0, 20)
    return np.column_stack([np.array(a), np.array(b)])


def converged_geometric_median(points: np.ndarray) -> np.ndarray:
    """The geometric median of the points, computed to a tight tolerance."""

    def distance(x: np.ndarray) -> float:
        return float(np.sum(np.sqrt(np.sum((points - x) ** 2, axis=1))))

    result = minimize(
        distance,
        points.mean(axis=0),
        method="Nelder-Mead",
        options={"xatol": 1e-12, "fatol": 1e-12, "maxiter": 100000, "maxfev": 100000},
    )
    return np.asarray(result.x, dtype=float)


def main() -> None:
    general = load("dowhy.gcm.util.general")

    points = median_fixture()
    # The upstream code minimises the sum of the distances with the default
    # settings of `scipy.optimize.minimize`, which stop at a tolerance of
    # about 1e-5. The reference is the optimum itself, so that the port and
    # the reference do not differ by the tolerance of the optimiser.
    median = np.asarray(converged_geometric_median(points)).reshape(-1)
    upstream = np.asarray(general.geometric_median(points)).reshape(-1)
    print("GEOMETRIC_MEDIAN")
    print(f"  median[0] = {median[0]:.12f}")
    print(f"  median[1] = {median[1]:.12f}")
    print(f"  upstream[0] = {upstream[0]:.12f}")
    print(f"  upstream[1] = {upstream[1]:.12f}")

    # The set difference of the rows, with the sorting and the removal of the
    # duplicates that numpy does.
    a = np.array([[1.0, 2.0], [3.0, 4.0], [1.0, 2.0], [5.0, 6.0]])
    b = np.array([[3.0, 4.0]])
    difference = np.asarray(general.setdiff2d(a, b))
    print("SETDIFF")
    for row in difference:
        print(f"  {row[0]:.12f} {row[1]:.12f}")

    # The scaling of the columns, which the upstream code takes from sklearn.
    from sklearn.preprocessing import scale

    scaled = scale(points)
    print("SCALED")
    print(f"  mean[0] = {scaled[:, 0].mean():.12f}")
    print(f"  std[0] = {scaled[:, 0].std():.12f}")
    print(f"  mean[1] = {scaled[:, 1].mean():.12f}")
    print(f"  std[1] = {scaled[:, 1].std():.12f}")

    # The CatBoost encoder of the categorical columns, with and without the
    # target of the rows, and the choice of the automatic encoder.
    catboost_x = np.array(["A", "B", "A", "D", "C", "C", "C", "A"])
    catboost_y = np.array([1.0, 2.0, 3.0, 4.0, 2.0, 3.0, 4.0, 2.0])
    with_target = np.asarray(
        general.apply_catboost_encoding(
            catboost_x, general.fit_catboost_encoders(catboost_x, catboost_y), catboost_y
        )
    ).reshape(-1)
    without_target = np.asarray(
        general.apply_catboost_encoding(catboost_x, general.fit_catboost_encoders(catboost_x, catboost_y))
    ).reshape(-1)
    print("CATBOOST")
    for value in with_target:
        print(f"  with_target = {value:.12f}")
    for value in without_target:
        print(f"  without_target = {value:.12f}")

    # The CatBoost encoder of a categorical target, whose labels the upstream
    # encodes with the numbers zero to n.
    labels_x = np.array(["A", "B", "A", "C", "A"])
    labels_y = np.array(["C1", "C1", "C1", "C2", "C1"])
    labels = np.asarray(
        general.apply_catboost_encoding(labels_x, general.fit_catboost_encoders(labels_x, labels_y), labels_y)
    ).reshape(-1)
    print("CATBOOST_LABELS")
    for value in labels:
        print(f"  label = {value:.12f}")

    # The automatic encoder picks the CatBoost encoder above the threshold and
    # the one-hot encoder below it.
    automatic = np.asarray(
        general.auto_apply_encoders(
            catboost_x, general.auto_fit_encoders(catboost_x, catboost_y, catboost_threshold=3), catboost_y
        )
    ).reshape(-1)
    print("CATBOOST_AUTO")
    for value in automatic:
        print(f"  automatic = {value:.12f}")
    one_hot = np.asarray(
        general.auto_apply_encoders(
            catboost_x, general.auto_fit_encoders(catboost_x, catboost_y, catboost_threshold=5), catboost_y
        )
    )
    print("CATBOOST_AUTO_ONE_HOT")
    for row in one_hot:
        print("  " + " ".join(f"{value:.12f}" for value in row))

    # The differences of the means and the variances of the deviations.
    randomized = np.array([1.0, 2.0, 3.0, 4.0])
    baseline = np.array([2.0, 2.0, 2.0, 2.0])
    print("MEANS_DIFFERENCE")
    print(f"  means_difference = {general.means_difference(randomized, baseline):.12f}")
    print(f"  variance_of_deviations = {general.variance_of_deviations(randomized, baseline):.12f}")
    print(f"  variance_of_matching_values = {general.variance_of_matching_values(randomized, baseline):.12f}")


if __name__ == "__main__":
    main()
