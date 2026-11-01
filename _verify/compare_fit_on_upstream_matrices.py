"""Compares the fit of the port with the fit of scikit-learn on the same
design matrix.

The script runs the upstream code, captures the design matrices of every fold
of the F-test and fits the two models of the test with the solve of the port
and with the solve of scikit-learn. The two have to agree on the residual sums
of squares, or the port fits the models of the test differently.

Usage:
    python _verify/compare_fit_on_upstream_matrices.py [num_samples]
"""

from __future__ import annotations

import os
import sys

import numpy as np
from sklearn.linear_model import LinearRegression

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import upstream_gcm  # noqa: E402
from upstream_gcm import load  # noqa: E402
from replicate_port_pipeline import gram_pinv  # noqa: E402

MASK64 = (1 << 64) - 1
SEED = 2080


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


def fixture(num_samples: int):
    rng = Xorshift(SEED)
    x = np.array([rng.next_normal() for _ in range(num_samples)])
    classes = np.where(x > 0, "Class 1", "Class 2")
    noise = np.array([rng.next_normal() for _ in range(num_samples)])
    y = np.where(x > 0, 1.0, 0.0) + noise
    return x, classes, y


def port_fit(x: np.ndarray, y: np.ndarray):
    """The `centered_ols_fit` of `src/gcm/stats.mbt`."""
    offsets = x.mean(axis=0)
    y_offset = y.mean()
    centred = x - offsets
    beta = gram_pinv(centred).dot(y - y_offset)
    intercept = y_offset - offsets.dot(beta)
    return beta, intercept


def main() -> None:
    num_samples = int(sys.argv[1]) if len(sys.argv) > 1 else 5000

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
        sklearn_a = np.sum(
            (y_test - LinearRegression().fit(x_training_a, y_training).predict(x_test_a)) ** 2
        )
        if x_training_b.size > 0:
            sklearn_b = np.sum(
                (y_test - LinearRegression().fit(x_training_b, y_training).predict(x_test_b)) ** 2
            )
        else:
            sklearn_b = np.sum((y_test - np.mean(y_training)) ** 2)
        port_a = 0.0
        for k in range(y_training.shape[1]):
            beta, intercept = port_fit(x_training_a, y_training[:, k])
            prediction = x_test_a.dot(beta) + intercept
            port_a += float(((y_test[:, k] - prediction) ** 2).sum())
        if x_training_b.size > 0:
            port_b = 0.0
            for k in range(y_training.shape[1]):
                beta, intercept = port_fit(x_training_b, y_training[:, k])
                prediction = x_test_b.dot(beta) + intercept
                port_b += float(((y_test[:, k] - prediction) ** 2).sum())
        else:
            port_b = float(((y_test - np.mean(y_training)) ** 2).sum())
        dof_diff_1 = x_test_a.shape[1] - (
            x_training_b.shape[1] if x_training_b.size > 0 else 0
        )
        dof_diff_2 = x_test_a.shape[0] - x_test_a.shape[1] - 1
        f_statistic = (sklearn_b - sklearn_a) / dof_diff_1 * dof_diff_2 / sklearn_a
        p_value = float(
            __import__("scipy.stats", fromlist=["stats"]).f.sf(
                f_statistic, dof_diff_1, dof_diff_2
            )
        )
        print(
            f"--- fold {counter['fold']} --- design {x_training_a.shape} -> {x_test_a.shape}"
            f" target {y_training.shape} features_b {x_training_b.shape[1]}"
        )
        print(
            f"    sklearn ssr_a={sklearn_a:16.6f} ssr_b={sklearn_b:16.6f} p={p_value:.6g}"
            f"   port ssr_a={port_a:16.6f} ssr_b={port_b:16.6f}"
        )
        return original(x_training_a, x_training_b, y_training, x_test_a, x_test_b, y_test)

    regression.estimate_ftest_pvalue = traced

    x, classes, y = fixture(num_samples)
    print("=== independent categorical, conditional ===")
    np.random.seed(SEED)
    print(f"p-value: {regression.regression_based(x, y, classes):.12f}")
    print("=== dependent categorical, conditional ===")
    np.random.seed(SEED)
    print(f"p-value: {regression.regression_based(x, classes, y):.12f}")
    print("=== dependent categorical, pairwise ===")
    np.random.seed(SEED)
    print(f"p-value: {regression.regression_based(x, classes):.12f}")


if __name__ == "__main__":
    main()
