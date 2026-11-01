"""Compares the design matrix of the model B of the F-test with the one of
scikit-learn.

The model B of the conditional test of the regression based independence test
is fitted on the kernel features of the conditioning variable. The conditioning
variable of the categorical test holds two categories, so the kernel matrix of
its basis points has a rank of two and the normalisation amplifies its null
space. The script prints the singular values of the design matrix of the port
and of the normalisation of scikit-learn, and the residual sums of squares of
the fit of the model B with both.

Usage:
    python _verify/compare_model_b_design.py [num_samples]
"""

from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import port_categorical_harness as harness  # noqa: E402
from port_categorical_harness import fixture, one_hot  # noqa: E402
from replicate_port_pipeline import random_permutation, scale_columns  # noqa: E402


def main() -> None:
    num_samples = int(sys.argv[1]) if len(sys.argv) > 1 else 5000
    seed = 2080
    x, classes, y = fixture(num_samples, seed)

    inputs = scale_columns(x.reshape(-1, 1))
    target = scale_columns(y.reshape(-1, 1))
    conditioning = scale_columns(one_hot(classes))

    rng = harness.Rng(seed)
    n = inputs.shape[0]
    order = random_permutation(rng, n)
    fold = 0
    start = n * fold // harness.K_FOLDS
    end = n * (fold + 1) // harness.K_FOLDS
    testing = order[start:end]
    held = set(testing)
    training = [index for index in order if index not in held]

    print(f"distinct rows of the conditioning variable: {len(np.unique(conditioning, axis=0))}")
    print(f"training rows {len(training)} test rows {len(testing)}")

    # The basis of the port.
    basis_order = random_permutation(rng, len(training))
    basis = conditioning[training][basis_order[:20]]
    print(f"distinct rows of the basis: {len(np.unique(basis, axis=0))}")

    gamma = 1.0 / conditioning.shape[1]
    kernel = harness.rbf(basis, basis, gamma)
    values, vectors = np.linalg.eigh(kernel)
    print("eigenvalues of the kernel matrix of the basis:")
    print("   ", np.array2string(values, precision=4, max_line_width=200))

    embedded_training = harness.rbf(conditioning[training], basis, gamma)
    embedded_testing = harness.rbf(conditioning[testing], basis, gamma)

    for name in ("eigen", "svd"):
        if name == "eigen":
            clipped = np.where(values < harness.EPS, harness.EPS, values)
            normalisation = (vectors * (1.0 / np.sqrt(clipped))) @ vectors.T
        else:
            u, s, vh = np.linalg.svd(kernel)
            s = np.clip(s, harness.EPS, None)
            normalisation = (u / np.sqrt(s)) @ vh
        design_training = embedded_training @ normalisation.T
        design_testing = embedded_testing @ normalisation.T
        singular = np.linalg.svd(design_training, compute_uv=False)
        beta, intercept = harness.fit(design_training, target[training][:, 0], "port", 0.0)
        prediction = design_testing.dot(beta) + intercept
        ssr = float(((target[testing][:, 0] - prediction) ** 2).sum())
        mean_ssr = float(((target[testing][:, 0] - target[training][:, 0].mean()) ** 2).sum())
        print(
            f"{name:5s} largest singular {singular[0]:.4e} smallest {singular[-1]:.4e}"
            f" ssr_b={ssr:14.6f} mean model {mean_ssr:14.6f}"
        )
        print("      singular values:", np.array2string(singular, precision=3, max_line_width=200))


if __name__ == "__main__":
    main()
