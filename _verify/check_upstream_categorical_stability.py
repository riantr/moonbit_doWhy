"""Checks the stability of the four categorical tests of the upstream.

The script runs the upstream `dowhy.gcm.independence_test.regression` with
several seeds of the global generator of numpy and counts how many seeds give
the decision the upstream test asserts, for every number of samples of the
fixture.

The upstream marks its tests as flaky, so the numbers show how unstable the
decision of the upstream is.

Usage:
    python _verify/check_upstream_categorical_stability.py [num_samples] [seeds]
"""

from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import upstream_gcm  # noqa: E402
from upstream_gcm import load  # noqa: E402

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
    independent_rng = Xorshift(SEED)
    independent_x = np.array(
        [independent_rng.next_normal() for _ in range(num_samples)]
    )
    independent_classes = np.where(
        np.array([independent_rng.next_double() for _ in range(num_samples)]) < 0.5,
        "Class 1",
        "Class 2",
    )
    return x, classes, y, independent_x, independent_classes


def main() -> None:
    num_samples = int(sys.argv[1]) if len(sys.argv) > 1 else 5000
    number_of_seeds = int(sys.argv[2]) if len(sys.argv) > 2 else 8

    load("dowhy.gcm.ml")
    load("dowhy.gcm.ml.regression")
    config = load("dowhy.gcm.config")
    config.set_default_n_jobs(1)
    regression = load("dowhy.gcm.independence_test.regression")
    regression_based = regression.regression_based

    x, classes, y, independent_x, independent_classes = fixture(num_samples)

    counts = {
        "independent conditional": 0,
        "dependent conditional": 0,
        "independent pairwise": 0,
        "dependent pairwise": 0,
    }
    for seed in range(1, number_of_seeds + 1):
        cases = [
            ("independent conditional", lambda: regression_based(x, y, classes), False),
            ("dependent conditional", lambda: regression_based(x, classes, y), True),
            ("independent pairwise", lambda: regression_based(independent_x, independent_classes), False),
            ("dependent pairwise", lambda: regression_based(x, classes), True),
        ]
        line = f"seed {seed:3d} "
        for name, call, dependent in cases:
            np.random.seed(seed)
            p_value = call()
            correct = (p_value < 0.05) if dependent else (p_value > 0.05)
            if correct:
                counts[name] += 1
            line += f" {name.split()[0][0]}{'d' if dependent else 'i'}={p_value:.3g}"
        print(line)

    print(f"{num_samples} samples: " + "  ".join(
        f"{name} {counts[name]}/{number_of_seeds}" for name in counts
    ))


if __name__ == "__main__":
    main()
