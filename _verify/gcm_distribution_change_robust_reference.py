"""Runs the upstream multiply-robust causal change attribution on the rows of the port.

The upstream draws the rows of its test fixture from the global generator of
numpy, which is not seeded, so the numbers of the upstream move from one run to
the other.  The port draws its rows from the generator of the `utils` package,
so the rows of the port are the same on every run.  This module reproduces the
generator of the port in Python and hands the very same rows to the upstream,
so that the numbers of the port and the numbers of the upstream can be
compared on one data set.

The script measures the three methods of the estimator -- the regression
method, the re-weighting method and the multiply-robust method -- for the mean
and for the variance of the target.

Usage:
    python _verify/gcm_distribution_change_robust_reference.py
"""

from __future__ import annotations

import math
import os
import sys

MASK64 = (1 << 64) - 1
GOLDEN = 0x9E3779B97F4A7C15
TWO_POW_53 = 9007199254740992.0

SEED = 2024
NUM_ROWS = 10000

UPSTREAM_ROOT = os.environ.get(
    "DOWHY_UPSTREAM_ROOT",
    r"D:\src\MiniMax\git\dowhy\dowhy-0.14",
)


class Rng:
    """The `Random` of `src/utils/random.mbt`."""

    def __init__(self, seed: int) -> None:
        self.state = GOLDEN if seed == 0 else (seed & MASK64)

    @staticmethod
    def step(state: int) -> int:
        x = state & MASK64
        x ^= (x << 13) & MASK64
        x ^= x >> 7
        x ^= (x << 17) & MASK64
        return x

    def next_u64(self) -> int:
        self.state = self.step(self.state)
        return self.state

    def uniform01(self) -> float:
        bits = self.next_u64() >> 11
        return bits * (1.0 / TWO_POW_53)

    def normal(self) -> float:
        u1 = self.uniform01()
        u2 = self.uniform01()
        safe_u1 = u1 if u1 >= 1.0e-12 else 1.0e-12
        variance = -2.0 * math.log(safe_u1)
        radius = math.sqrt(variance)
        return radius * math.cos(2.0 * math.pi * u2)


def build_data(seed: int = SEED, num_rows: int = NUM_ROWS) -> tuple:
    """The two data frames of the test, the old one and the new one.

    The draw order is the one of `src/gcm/distribution_change_robust_test.mbt`:
    the noise of `X1` of the old data set, the noise of `X2`, the noise of `Y`,
    and then the same three noises of the new data set.
    """
    import pandas as pd

    rng = Rng(seed)

    x1_old = [1.0 + rng.normal() for _ in range(num_rows)]
    x2_old = [0.5 * x1_old[i] + rng.normal() for i in range(num_rows)]
    y_old = [
        x1_old[i]
        + x2_old[i]
        + 0.25 * x1_old[i] * x1_old[i]
        + 0.25 * x2_old[i] * x2_old[i]
        + rng.normal()
        for i in range(num_rows)
    ]

    x1_new = [1.0 + 1.1 * rng.normal() for _ in range(num_rows)]
    x2_new = [0.2 * x1_new[i] + rng.normal() for i in range(num_rows)]
    y_new = [
        x1_new[i]
        + x2_new[i]
        + 0.25 * x1_new[i] * x1_new[i]
        - 0.25 * x2_new[i] * x2_new[i]
        + rng.normal()
        for i in range(num_rows)
    ]

    data_old = pd.DataFrame({"X1": x1_old, "X2": x2_old, "Y": y_old})
    data_new = pd.DataFrame({"X1": x1_new, "X2": x2_new, "Y": y_new})
    return data_old, data_new


def main() -> int:
    import networkx as nx

    if UPSTREAM_ROOT not in sys.path:
        sys.path.insert(0, UPSTREAM_ROOT)

    from dowhy import gcm

    data_old, data_new = build_data()
    causal_model = gcm.ProbabilisticCausalModel(
        nx.DiGraph([("X1", "X2"), ("X1", "Y"), ("X2", "Y")])
    )

    for method in ("MR", "regression", "re-weighting"):
        for functional in ("mean", "variance"):
            shap = gcm.distribution_change_robust(
                causal_model,
                data_old,
                data_new,
                "Y",
                target_functional=functional,
                method=method,
                regressor=gcm.ml.regression.create_knn_regressor,
                xfit_folds=10,
            )
            print("%s %s" % (method, functional))
            for name in ("X1", "X2", "Y"):
                print("  %s %.12f" % (name, shap[name]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
