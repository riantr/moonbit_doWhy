"""Compares the normalisation of the Nystroem transformer of the port with the
one of scikit-learn.

The port normalises the kernel matrix of the basis points with the inverse
square root of its eigen decomposition, and scikit-learn normalises it with the
inverse square root of its singular value decomposition. The script builds the
design matrix of the fold that the port fits worst with both normalisations and
prints the condition number of the design matrix and the residual sums of
squares of the two models of the F-test.

Usage:
    python _verify/compare_nystroem_normalisation.py
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
    centred_fit,
    f_test,
    nystroem_fit,
    random_permutation,
    rbf,
    scale_columns,
)


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
    fold = 0
    start = NUM_SAMPLES * fold // K_FOLDS
    end = NUM_SAMPLES * (fold + 1) // K_FOLDS
    testing = order[start:end]
    held = set(testing)
    training = [index for index in order if index not in held]
    training_all = inputs[training]
    testing_all = inputs[testing]

    basis, _, gamma = nystroem_fit(training_all, NUM_COMPONENTS, test_rng)
    kernel = rbf(basis, basis, gamma)

    values, vectors = np.linalg.eigh(kernel)
    print("eigenvalues of the basis kernel matrix:")
    print("   ", np.array2string(values, precision=3, max_line_width=200))
    print(f"    smallest {values.min():.6e}  largest {values.max():.6e}")

    singular = np.linalg.svd(kernel, compute_uv=False)
    print("singular values of the basis kernel matrix:")
    print("   ", np.array2string(singular, precision=3, max_line_width=200))
    print(f"    smallest {singular.min():.6e}  largest {singular.max():.6e}")

    # The normalisation of the port: the inverse square root of the eigen
    # decomposition.
    clipped_eigen = np.where(values < EPS, EPS, values)
    port_normalisation = (vectors * (1.0 / np.sqrt(clipped_eigen))) @ vectors.T

    # The normalisation of scikit-learn: the inverse square root of the singular
    # value decomposition.
    u, s, vh = np.linalg.svd(kernel)
    s = np.clip(s, EPS, None)
    sklearn_normalisation = (u / np.sqrt(s)) @ vh

    embedded_training = rbf(training_all, basis, gamma)
    embedded_testing = rbf(testing_all, basis, gamma)

    for name, normalisation in (
        ("port", port_normalisation),
        ("sklearn", sklearn_normalisation),
    ):
        design_training = embedded_training @ normalisation.T
        design_testing = embedded_testing @ normalisation.T
        condition = np.linalg.cond(design_training)
        ssr_a, ssr_b, f_statistic = f_test(
            design_training,
            design_testing,
            scaled_target[training],
            scaled_target[testing],
            "svd",
        )
        print(
            f"{name:8s} cond={condition:.4e} largest={np.abs(design_training).max():.4e}"
            f" ssr_a={ssr_a:14.6f} ssr_b={ssr_b:12.6f} f={f_statistic:.6e}"
        )


if __name__ == "__main__":
    main()
