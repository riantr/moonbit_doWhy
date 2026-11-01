"""Checks whether the normalisation of the Nystroem transformer is the reason
why the port differs from the upstream.

The script runs the pipeline of the port with the normalisation of scikit-learn,
which is the singular value decomposition of the kernel matrix of the basis
points, and counts how many seeds give the decision the upstream test asserts.

Usage:
    python _verify/check_svd_normalisation_stability.py
"""

from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import port_categorical_harness as harness  # noqa: E402
from port_categorical_harness import fixture, one_hot  # noqa: E402
from replicate_port_pipeline import Rng  # noqa: E402


def nystroem_with_svd(samples: np.ndarray, n_components: int, rng: Rng):
    """The `nystroem_fit` of the port, with the normalisation of
    scikit-learn."""
    n_samples = samples.shape[0]
    count = min(n_components, n_samples)
    order = harness.random_permutation(rng, n_samples)
    basis = samples[order[:count]]
    gamma = 1.0 / samples.shape[1]
    kernel = harness.rbf(basis, basis, gamma)
    u, s, vh = np.linalg.svd(kernel)
    s = np.clip(s, harness.EPS, None)
    matrix = (u / np.sqrt(s)) @ vh
    return basis, matrix, gamma


def main() -> None:
    harness.nystroem = nystroem_with_svd
    seeds = list(range(1, 13))
    for num_samples in (1000, 5000):
        counts = {
            "independent conditional": 0,
            "dependent conditional": 0,
            "independent pairwise": 0,
            "dependent pairwise": 0,
        }
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
                p_value, _ = harness.run(
                    inputs, target, conditioning, "port", 0.0, seed
                )
                correct = (p_value < 0.05) if dependent else (p_value > 0.05)
                if correct:
                    counts[name] += 1
        print(
            f"svd normalisation, {num_samples} samples: "
            + "  ".join(f"{name} {counts[name]}/{len(seeds)}" for name in counts)
        )


if __name__ == "__main__":
    main()
