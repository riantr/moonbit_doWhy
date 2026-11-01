"""Sweeps the cut-off of the least squares fit of the F-test.

The Nystroem features of the regression based independence test are built from
a kernel matrix whose null space is amplified, so the design matrix of the test
is ill-conditioned and the fit of the two models of the F-test explodes in
some of the folds. The script sweeps the relative cut-off of a truncated
singular value decomposition and prints the residual sums of squares of the two
models of every fold of the fixture of the port.

A cut-off that keeps the fit of every fold below the residual sum of squares
of the mean model is a cut-off that makes the test of the port as stable as the
test of the upstream, which is marked as flaky.

Usage:
    python _verify/sweep_least_squares_cutoff.py
"""

from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from replicate_port_pipeline import (  # noqa: E402
    K_FOLDS,
    NUM_COMPONENTS,
    NUM_SAMPLES,
    Rng,
    nystroem_fit,
    nystroem_transform,
    random_permutation,
    scale_columns,
)

CUTOFFS = [0.0, 1e-16, 1e-14, 1e-12, 1e-10, 1e-8, 1e-6, 1e-4, 1e-2]


def truncated_fit(x: np.ndarray, y: np.ndarray, cutoff: float):
    """The centred fit of `sklearn.linear_model.LinearRegression`, with the
    singular values below the cut-off dropped."""
    offsets = x.mean(axis=0)
    y_offset = y.mean()
    centred = x - offsets
    centred_y = y - y_offset
    u, s, vh = np.linalg.svd(centred, full_matrices=False)
    if cutoff > 0.0:
        keep = s > cutoff * s[0]
    else:
        keep = np.ones_like(s, dtype=bool)
    beta = vh[keep].T @ ((u[:, keep].T @ centred_y) / s[keep])
    intercept = y_offset - offsets.dot(beta)
    return beta, intercept


def residuals(x: np.ndarray, y: np.ndarray, cutoff: float) -> float:
    beta, intercept = truncated_fit(x, y, cutoff)
    prediction = x.dot(beta) + intercept
    return float(((y - prediction) ** 2).sum())


def test_residuals(
    design_training: np.ndarray,
    design_testing: np.ndarray,
    y_training: np.ndarray,
    y_test: np.ndarray,
    cutoff: float,
) -> float:
    """The residual sum of squares of the test set, with the coefficients of the
    training set."""
    beta, intercept = truncated_fit(design_training, y_training, cutoff)
    prediction = design_testing.dot(beta) + intercept
    return float(((y_test - prediction) ** 2).sum())


def main() -> None:
    rng = Rng(2080)
    x = np.array([rng.next_normal() for _ in range(NUM_SAMPLES)])
    classes = np.where(x > 0, "Class 1", "Class 2")
    target = np.column_stack(
        [(classes == "Class 1").astype(float), (classes == "Class 2").astype(float)]
    )
    inputs = scale_columns(x.reshape(-1, 1))
    scaled_target = scale_columns(target)

    test_rng = Rng(2080)
    order = random_permutation(test_rng, NUM_SAMPLES)
    folds = []
    for fold in range(K_FOLDS):
        start = NUM_SAMPLES * fold // K_FOLDS
        end = NUM_SAMPLES * (fold + 1) // K_FOLDS
        testing = order[start:end]
        held = set(testing)
        training = [index for index in order if index not in held]
        training_all = inputs[training]
        testing_all = inputs[testing]
        transformer = nystroem_fit(training_all, NUM_COMPONENTS, test_rng)
        design_training = nystroem_transform(training_all, transformer)
        design_testing = nystroem_transform(testing_all, transformer)
        folds.append((design_training, design_testing, training, testing))

    for cutoff in CUTOFFS:
        line = f"cutoff {cutoff:8.1e} "
        for design_training, design_testing, training, testing in folds:
            ssr_a = 0.0
            for k in range(scaled_target.shape[1]):
                ssr_a += test_residuals(
                    design_training,
                    design_testing,
                    scaled_target[training][:, k],
                    scaled_target[testing][:, k],
                    cutoff,
                )
            line += f" ssr_a={ssr_a:14.4f}"
        print(line)

    print()
    for index, (design_training, design_testing, training, testing) in enumerate(folds):
        ssr_b = 0.0
        for k in range(scaled_target.shape[1]):
            column = scaled_target[training][:, k]
            ssr_b += float(((scaled_target[testing][:, k] - column.mean()) ** 2).sum())
        print(f"fold {index + 1}: ssr_b={ssr_b:.4f}")


if __name__ == "__main__":
    main()
