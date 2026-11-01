"""Prints the residual sums of squares of the two models of the F-test of every
fold of the independent categorical conditional case.

The upstream gets a residual sum of squares of 1433.10 against 1392.88 in its
first fold, so the test is on a knife's edge there: the model with the kernel
features of the inputs has to be worse than the model with the kernel features
of the conditioning variable for the test to find no dependence.

Usage:
    python _verify/print_port_fold_residuals.py [num_samples]
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
    all_inputs = np.column_stack([inputs, conditioning])

    rng = harness.Rng(seed)
    n = inputs.shape[0]
    order = random_permutation(rng, n)
    for fold in range(harness.K_FOLDS):
        start = n * fold // harness.K_FOLDS
        end = n * (fold + 1) // harness.K_FOLDS
        testing = order[start:end]
        held = set(testing)
        training = [index for index in order if index not in held]
        transformer_all = harness.nystroem(all_inputs[training], 40, rng)
        design_a = harness.transform(all_inputs[training], transformer_all)
        design_a_test = harness.transform(all_inputs[testing], transformer_all)
        transformer_z = harness.nystroem(conditioning[training], 20, rng)
        design_b = harness.transform(conditioning[training], transformer_z)
        design_b_test = harness.transform(conditioning[testing], transformer_z)
        ssr_a, ssr_b, p_value = harness.f_test(
            design_a,
            design_a_test,
            target[training],
            target[testing],
            "port",
            0.0,
        )
        print(
            f"fold {fold + 1}: ssr_a={ssr_a:14.6f} ssr_b={ssr_b:14.6f} p={p_value:.6g}"
        )


if __name__ == "__main__":
    main()
