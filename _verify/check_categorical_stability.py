"""Checks the stability of the four categorical tests of the upstream.

The script runs the pipeline of the MoonBit port for the four categorical tests
of `tests/gcm/independence_test/test_regression.py` with the solve of the port
and counts, for every number of samples, how many seeds give the decision the
upstream test asserts.

Usage:
    python _verify/check_categorical_stability.py
"""

from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from port_categorical_harness import (  # noqa: E402
    fixture,
    one_hot,
    run,
)
from replicate_port_pipeline import Rng  # noqa: E402


def main() -> None:
    seeds = list(range(1, 13))
    for num_samples in (1000, 2000, 5000):
        counts = {"independent conditional": 0, "dependent conditional": 0,
                  "independent pairwise": 0, "dependent pairwise": 0}
        for seed in seeds:
            x, classes, y = fixture(num_samples, seed)
            independent_rng = Rng(seed)
            independent_x = np.array(
                [independent_rng.next_normal() for _ in range(num_samples)]
            )
            independent_classes = np.where(
                np.array(
                    [independent_rng.next_double() for _ in range(num_samples)]
                )
                < 0.5,
                "Class 1",
                "Class 2",
            )
            cases = [
                ("independent conditional", x.reshape(-1, 1), y.reshape(-1, 1),
                 one_hot(classes), False),
                ("dependent conditional", x.reshape(-1, 1), one_hot(classes),
                 y.reshape(-1, 1), True),
                ("independent pairwise", independent_x.reshape(-1, 1),
                 one_hot(independent_classes), None, False),
                ("dependent pairwise", x.reshape(-1, 1), one_hot(classes), None, True),
            ]
            for name, inputs, target, conditioning, dependent in cases:
                p_value, _ = run(inputs, target, conditioning, "port", 0.0, seed)
                correct = (p_value < 0.05) if dependent else (p_value > 0.05)
                if correct:
                    counts[name] += 1
        print(f"{num_samples:5d} samples: " + "  ".join(
            f"{name} {counts[name]}/{len(seeds)}" for name in counts
        ))


if __name__ == "__main__":
    main()
