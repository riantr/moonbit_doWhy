"""Traces the internals of the upstream regression based independence test.

The script runs the upstream code on the fixture of the MoonBit port and
prints, for every fold, the condition number of the design matrix of the
Nystroem transformer, the eigenvalues of the kernel matrix of the basis points
and the two residual sums of squares of the F-test.

Usage:
    python _verify/upstream_categorical_internals.py
"""

from __future__ import annotations

import os
import sys

import numpy as np
from sklearn.linear_model import LinearRegression

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import upstream_gcm  # noqa: E402
from upstream_gcm import load  # noqa: E402

MASK64 = (1 << 64) - 1
SEED = 2080
NUM_SAMPLES = 1000


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


def fixture():
    rng = Xorshift(SEED)
    x = np.array([rng.next_normal() for _ in range(NUM_SAMPLES)])
    classes = np.where(x > 0, "Class 1", "Class 2")
    noise = np.array([rng.next_normal() for _ in range(NUM_SAMPLES)])
    y = np.where(x > 0, 1.0, 0.0) + noise
    return x, classes, y


def main() -> None:
    load("dowhy.gcm.ml")
    load("dowhy.gcm.ml.regression")
    config = load("dowhy.gcm.config")
    config.set_default_n_jobs(1)
    stats = load("dowhy.gcm.stats")
    regression = load("dowhy.gcm.independence_test.regression")

    original = stats.estimate_ftest_pvalue
    counter = {"fold": 0}

    def traced(x_training_a, x_training_b, y_training, x_test_a, x_test_b, y_test):
        counter["fold"] += 1
        condition = np.linalg.cond(x_training_a)
        ssr_a = np.sum((y_test - LinearRegression().fit(x_training_a, y_training).predict(x_test_a)) ** 2)
        if x_training_b.size > 0:
            ssr_b = np.sum((y_test - LinearRegression().fit(x_training_b, y_training).predict(x_test_b)) ** 2)
        else:
            ssr_b = np.sum((y_test - np.mean(y_training)) ** 2)
        print(
            f"--- fold {counter['fold']} ---"
            f" design {x_training_a.shape} -> {x_test_a.shape}"
            f" cond {condition:.4e} largest {np.abs(x_training_a).max():.4e}"
        )
        print(f"    ssr_a={ssr_a:14.6f} ssr_b={ssr_b:12.6f}")
        return original(x_training_a, x_training_b, y_training, x_test_a, x_test_b, y_test)

    regression.estimate_ftest_pvalue = traced

    x, classes, y = fixture()
    np.random.seed(SEED)
    p_value = regression.regression_based(x, classes)
    print(f"p-value of the upstream: {p_value:.12f}")


if __name__ == "__main__":
    main()
