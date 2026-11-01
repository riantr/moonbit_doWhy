"""Sweeps the cut-off of the normalisation of the Nystroem transformer.

The normalisation of the transformer is the inverse square root of the kernel
matrix of the basis points. The kernel matrix of the basis points of a one
dimensional variable is rank deficient, and the absolute cut-off of
scikit-learn, which is 1e-12, amplifies its null space by a factor of a
million. The amplified directions are noise, and the fit of the F-test explodes
in the folds that get them.

The script prints the residual sums of squares of the two models of the F-test
of every fold of the fixture of the port, for the absolute cut-off of
scikit-learn and for cut-offs that are relative to the largest eigenvalue of
the kernel matrix.

Usage:
    python _verify/sweep_nystroem_cutoff.py
"""

from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from replicate_port_pipeline import (  # noqa: E402
    EPS,
    K_FOLDS,
    NUM_COMPONENTS,
    NUM_SAMPLES,
    Rng,
    random_permutation,
    rbf,
    scale_columns,
)


def design_of(training: np.ndarray, testing: np.ndarray, rng: Rng, clip: float):
    """The design matrix of the fold, with the given cut-off of the
    normalisation."""
    n_samples = training.shape[0]
    order = random_permutation(rng, n_samples)
    basis = training[order[:NUM_COMPONENTS]]
    gamma = 1.0 / training.shape[1]
    kernel = rbf(basis, basis, gamma)
    values, vectors = np.linalg.eigh(kernel)
    largest = float(np.max(values))
    if clip <= 0.0:
        # The absolute cut-off of scikit-learn.
        threshold = EPS
    else:
        threshold = clip * largest
    values = np.where(values < threshold, threshold, values)
    normalisation = (vectors * (1.0 / np.sqrt(values))) @ vectors.T
    return rbf(training, basis, gamma) @ normalisation.T, rbf(testing, basis, gamma) @ normalisation.T


def solve(x: np.ndarray, y: np.ndarray):
    offsets = x.mean(axis=0)
    y_offset = y.mean()
    centred = x - offsets
    beta = np.linalg.lstsq(centred, y - y_offset, rcond=None)[0]
    intercept = y_offset - offsets.dot(beta)
    return beta, intercept


def main() -> None:
    rng = Rng(2080)
    x = np.array([rng.next_normal() for _ in range(NUM_SAMPLES)])
    classes = np.where(x > 0, "Class 1", "Class 2")
    target = np.column_stack(
        [(classes == "Class 1").astype(float), (classes == "Class 2").astype(float)]
    )
    inputs = scale_columns(x.reshape(-1, 1))
    scaled_target = scale_columns(target)

    for clip in (0.0, 1e-12, 1e-10, 1e-8, 1e-6, 1e-4):
        test_rng = Rng(2080)
        order = random_permutation(test_rng, NUM_SAMPLES)
        line = f"clip {clip:8.1e} "
        for fold in range(K_FOLDS):
            start = NUM_SAMPLES * fold // K_FOLDS
            end = NUM_SAMPLES * (fold + 1) // K_FOLDS
            testing = order[start:end]
            held = set(testing)
            training = [index for index in order if index not in held]
            design_training, design_testing = design_of(
                inputs[training], inputs[testing], test_rng, clip
            )
            ssr_a = 0.0
            ssr_b = 0.0
            for k in range(scaled_target.shape[1]):
                column_training = scaled_target[training][:, k]
                column_testing = scaled_target[testing][:, k]
                beta, intercept = solve(design_training, column_training)
                prediction = design_testing.dot(beta) + intercept
                ssr_a += float(((column_testing - prediction) ** 2).sum())
                ssr_b += float(((column_testing - column_training.mean()) ** 2).sum())
            condition = np.linalg.cond(design_training)
            line += f" [ssr_a={ssr_a:12.2f} ssr_b={ssr_b:7.2f} cond={condition:.1e}]"
        print(line)


if __name__ == "__main__":
    main()
