"""Searches for a fixture whose four categorical decisions are the ones the
upstream test asserts, with the margins of the folds.

The upstream test of the regression based independence test with categorical
data is marked as flaky, because the residual sums of squares of the two models
of the F-test are of the same order in the folds of the case that has to find
no dependence. The upstream finds a dependence in the folds of that case in
half of the seeds at a thousand samples.

The script runs the pipeline of the port for every seed and every number of
samples and prints the ratio of the residual sums of squares of the two models
of every fold of every case, so that the seed with the most comfortable
margins can be chosen.

Usage:
    python _verify/search_categorical_seed.py [num_samples]
"""

from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import port_categorical_harness as harness  # noqa: E402
from port_categorical_harness import fixture, one_hot  # noqa: E402
from replicate_port_pipeline import random_permutation, scale_columns  # noqa: E402


def fold_ratios(inputs, target, conditioning, seed):
    """The ratio of the residual sums of squares of the two models of the F-test
    of every fold."""
    scaled_inputs = scale_columns(inputs)
    scaled_target = scale_columns(target)
    scaled_conditioning = (
        None if conditioning is None else scale_columns(conditioning)
    )
    rng = harness.Rng(seed)
    n = scaled_inputs.shape[0]
    order = random_permutation(rng, n)
    ratios = []
    for fold in range(harness.K_FOLDS):
        start = n * fold // harness.K_FOLDS
        end = n * (fold + 1) // harness.K_FOLDS
        testing = order[start:end]
        held = set(testing)
        training = [index for index in order if index not in held]
        if scaled_conditioning is None:
            all_inputs = scaled_inputs
        else:
            all_inputs = np.column_stack([scaled_inputs, scaled_conditioning])
        transformer_all = harness.nystroem(all_inputs[training], 40, rng)
        design_a = harness.transform(all_inputs[training], transformer_all)
        design_a_test = harness.transform(all_inputs[testing], transformer_all)
        if scaled_conditioning is None:
            design_b = np.zeros((len(training), 0))
            design_b_test = np.zeros((len(testing), 0))
        else:
            transformer_z = harness.nystroem(scaled_conditioning[training], 20, rng)
            design_b = harness.transform(scaled_conditioning[training], transformer_z)
            design_b_test = harness.transform(scaled_conditioning[testing], transformer_z)
        ssr_a, ssr_b, _ = harness.f_test(
            design_a,
            design_a_test,
            scaled_target[training],
            scaled_target[testing],
            "port",
            0.0,
        )
        ratios.append(ssr_a / ssr_b)
    return ratios


def main() -> None:
    num_samples = int(sys.argv[1]) if len(sys.argv) > 1 else 5000
    for seed in range(1, 41):
        x, classes, y = fixture(num_samples, seed)
        independent_rng = harness.Rng(seed)
        independent_x = np.array(
            [independent_rng.next_normal() for _ in range(num_samples)]
        )
        independent_classes = np.where(
            np.array([independent_rng.next_double() for _ in range(num_samples)]) < 0.5,
            "Class 1",
            "Class 2",
        )
        cases = [
            ("indep-cond", x.reshape(-1, 1), y.reshape(-1, 1), one_hot(classes), False),
            ("dep-cond", x.reshape(-1, 1), one_hot(classes), y.reshape(-1, 1), True),
            ("indep-pair", independent_x.reshape(-1, 1), one_hot(independent_classes), None, False),
            ("dep-pair", x.reshape(-1, 1), one_hot(classes), None, True),
        ]
        good = True
        line = f"seed {seed:3d} "
        for name, inputs, target, conditioning, dependent in cases:
            ratios = fold_ratios(inputs, target, conditioning, seed)
            # A detection needs the ratio to be below one, a non detection needs
            # it to be above one.
            decided = all(r < 1.0 for r in ratios) if dependent else all(r > 1.0 for r in ratios)
            if not decided:
                good = False
            worst = min(abs(np.log(r)) for r in ratios)
            line += f" {name}[" + ",".join(f"{r:.3f}" for r in ratios) + f"]"
        print(("OK  " if good else "    ") + line)


if __name__ == "__main__":
    main()
