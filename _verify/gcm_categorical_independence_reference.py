"""The reference numbers of the regression based independence test with
categorical data.

The script runs the upstream `dowhy.gcm.independence_test.regression` on the
very rows the MoonBit port works on, and prints the p-value of the upstream
next to the decision the upstream test asserts, so that the two can be
compared.

The fixture is generated with a Python replica of the xorshift generator of
`src/utils/random.mbt`, so the two sides work on the same rows.

The upstream draws its folds and its basis points with the global generator of
numpy, so the p-value it computes and the p-value the port computes are
different numbers. What the two share is the decision the upstream test
asserts.

The number of samples of the fixture is the number of the argument of the
upstream fixture, which is 5000.

Usage:
    python _verify/gcm_categorical_independence_reference.py [num_samples]
"""

from __future__ import annotations

import os
import sys

import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import upstream_gcm  # noqa: E402
from upstream_gcm import load  # noqa: E402

MASK64 = (1 << 64) - 1

# The seed of the fixture, the same as the one of the MoonBit test.
SEED = 2080

# The number of samples of the fixture.
NUM_SAMPLES = int(sys.argv[1]) if len(sys.argv) > 1 else 5000


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
    """The samples of the fixture: the numeric variable, the classes and the
    noisy variable."""
    rng = Xorshift(SEED)
    x = np.array([rng.next_normal() for _ in range(NUM_SAMPLES)])
    classes = np.where(x > 0, "Class 1", "Class 2")
    noise = np.array([rng.next_normal() for _ in range(NUM_SAMPLES)])
    y = np.where(x > 0, 1.0, 0.0) + noise
    return x, classes, y


def independent_fixture():
    """The samples of the fixture whose two variables are independent."""
    rng = Xorshift(SEED)
    x = np.array([rng.next_normal() for _ in range(NUM_SAMPLES)])
    classes = np.where(
        np.array([rng.next_double() for _ in range(NUM_SAMPLES)]) < 0.5,
        "Class 1",
        "Class 2",
    )
    return x, classes


def main() -> None:
    load("dowhy.gcm.ml")
    load("dowhy.gcm.ml.regression")
    config = load("dowhy.gcm.config")
    # The workers of the process pool of the upstream cannot import the stubbed
    # packages, so the number of the jobs has to be one.
    config.set_default_n_jobs(1)
    regression = load("dowhy.gcm.independence_test.regression")
    regression_based = regression.regression_based

    x, classes, y = fixture()
    independent_x, independent_classes = independent_fixture()

    np.random.seed(SEED)
    p_value = regression_based(x, y, classes)
    print(f"independent categorical, conditional: {p_value:.12f} (> 0.05)")

    np.random.seed(SEED)
    p_value = regression_based(x, classes, y)
    print(f"dependent categorical, conditional: {p_value:.12f} (< 0.05)")

    np.random.seed(SEED)
    p_value = regression_based(independent_x, independent_classes)
    print(f"independent categorical, pairwise: {p_value:.12f} (> 0.05)")

    np.random.seed(SEED)
    p_value = regression_based(x, classes)
    print(f"dependent categorical, pairwise: {p_value:.12f} (< 0.05)")


if __name__ == "__main__":
    main()
