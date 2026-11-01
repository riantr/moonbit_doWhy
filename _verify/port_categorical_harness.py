"""The harness of the four categorical tests of the upstream.

The script reproduces the pipeline of the MoonBit port for the four
categorical tests of `tests/gcm/independence_test/test_regression.py` and
prints the p-value and the decision of every fold, for the solves that the port
can use.

Usage:
    python _verify/port_categorical_harness.py
"""

from __future__ import annotations

import os
import sys

import numpy as np
from scipy import stats

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from replicate_port_pipeline import (  # noqa: E402
    EPS,
    Rng,
    gram_pinv,
    random_permutation,
    scale_columns,
)

K_FOLDS = 3
NUM_COMPONENTS = 40


def rbf(left: np.ndarray, right: np.ndarray, gamma: float) -> np.ndarray:
    squared = ((left[:, None, :] - right[None, :, :]) ** 2).sum(-1)
    return np.exp(-gamma * squared)


def nystroem(samples: np.ndarray, n_components: int, rng: Rng, normalisation: str = "eigen"):
    n_samples = samples.shape[0]
    count = min(n_components, n_samples)
    order = random_permutation(rng, n_samples)
    basis = samples[order[:count]]
    gamma = 1.0 / samples.shape[1]
    kernel = rbf(basis, basis, gamma)
    if normalisation == "eigen":
        values, vectors = np.linalg.eigh(kernel)
        values = np.where(values < EPS, EPS, values)
        matrix = (vectors * (1.0 / np.sqrt(values))) @ vectors.T
    else:
        u, s, vh = np.linalg.svd(kernel)
        s = np.clip(s, EPS, None)
        matrix = (u / np.sqrt(s)) @ vh
    return basis, matrix, gamma


def transform(samples: np.ndarray, transformer) -> np.ndarray:
    basis, normalisation, gamma = transformer
    return rbf(samples, basis, gamma) @ normalisation.T


def fit(x: np.ndarray, y: np.ndarray, solver: str, cutoff: float):
    """The centred fit of `sklearn.linear_model.LinearRegression`."""
    offsets = x.mean(axis=0)
    y_offset = y.mean()
    centred = x - offsets
    centred_y = y - y_offset
    if solver == "port":
        beta = gram_pinv(centred).dot(centred_y)
    elif solver == "svd":
        beta = np.linalg.lstsq(centred, centred_y, rcond=None)[0]
    else:
        u, s, vh = np.linalg.svd(centred, full_matrices=False)
        keep = s > cutoff * s[0]
        beta = vh[keep].T @ ((u[:, keep].T @ centred_y) / s[keep])
    intercept = y_offset - offsets.dot(beta)
    return beta, intercept


def f_test(
    design_training: np.ndarray,
    design_testing: np.ndarray,
    target_training: np.ndarray,
    target_testing: np.ndarray,
    solver: str,
    cutoff: float,
    design_b_training: np.ndarray | None = None,
    design_b_testing: np.ndarray | None = None,
) -> tuple[float, float, float]:
    ssr_a = 0.0
    ssr_b = 0.0
    for k in range(target_training.shape[1]):
        column_training = target_training[:, k]
        column_testing = target_testing[:, k]
        beta, intercept = fit(design_training, column_training, solver, cutoff)
        prediction = design_testing.dot(beta) + intercept
        ssr_a += float(((column_testing - prediction) ** 2).sum())
        if design_b_training is None or design_b_training.shape[1] == 0:
            ssr_b += float(((column_testing - column_training.mean()) ** 2).sum())
        else:
            beta_b, intercept_b = fit(
                design_b_training, column_training, solver, cutoff
            )
            prediction_b = design_b_testing.dot(beta_b) + intercept_b
            ssr_b += float(((column_testing - prediction_b) ** 2).sum())
    dof_diff_1 = design_testing.shape[1] - (
        0 if design_b_training is None else design_b_training.shape[1]
    )
    dof_diff_2 = design_testing.shape[0] - design_testing.shape[1] - 1
    f_statistic = (ssr_b - ssr_a) / dof_diff_1 * dof_diff_2
    if ssr_a < EPS:
        ssr_a = 0.0
    if ssr_b < EPS:
        ssr_b = 0.0
    if ssr_a == 0.0 and ssr_b == 0.0:
        f_statistic = 0.0
    elif ssr_a != 0.0:
        f_statistic = f_statistic / ssr_a
    return ssr_a, ssr_b, float(stats.f.sf(f_statistic, dof_diff_1, dof_diff_2))


def merge(p_values: list[float]) -> float:
    """The `merge_p_values_average` of `dowhy.gcm.stats`."""
    ordered = sorted(p_values)
    k = len(ordered)
    result = 1.0
    for m in range(1, k + 1):
        ratio = k * 1.0 / m
        if ratio < 2.0:
            candidate = 2.0 * float(np.mean(ordered[:m])) / (2.0 - ratio)
            result = min(result, candidate)
    return min(1.0, result)


def fixture(num_samples: int, seed: int = 2080):
    rng = Rng(seed)
    x = np.array([rng.next_normal() for _ in range(num_samples)])
    classes = np.where(x > 0, "Class 1", "Class 2")
    noise = np.array([rng.next_normal() for _ in range(num_samples)])
    y = np.where(x > 0, 1.0, 0.0) + noise
    return x, classes, y


def one_hot(labels: np.ndarray) -> np.ndarray:
    return np.column_stack(
        [(labels == "Class 1").astype(float), (labels == "Class 2").astype(float)]
    )


def run(
    inputs: np.ndarray,
    target: np.ndarray,
    conditioning: np.ndarray | None,
    solver: str,
    cutoff: float,
    seed: int = 2080,
) -> tuple[float, list[float]]:
    scaled_inputs = scale_columns(inputs)
    scaled_target = scale_columns(target)
    scaled_conditioning = (
        None if conditioning is None else scale_columns(conditioning)
    )
    rng = Rng(seed)
    n = scaled_inputs.shape[0]
    order = random_permutation(rng, n)
    p_values = []
    for fold in range(K_FOLDS):
        start = n * fold // K_FOLDS
        end = n * (fold + 1) // K_FOLDS
        testing = order[start:end]
        held = set(testing)
        training = [index for index in order if index not in held]
        if scaled_conditioning is None:
            all_inputs = scaled_inputs
        else:
            all_inputs = np.column_stack([scaled_inputs, scaled_conditioning])
        transformer_all = nystroem(all_inputs[training], NUM_COMPONENTS, rng)
        design_training = transform(all_inputs[training], transformer_all)
        design_testing = transform(all_inputs[testing], transformer_all)
        if scaled_conditioning is None:
            design_b_training = np.zeros((len(training), 0))
            design_b_testing = np.zeros((len(testing), 0))
        else:
            transformer_z = nystroem(
                scaled_conditioning[training], NUM_COMPONENTS // 2, rng
            )
            design_b_training = transform(scaled_conditioning[training], transformer_z)
            design_b_testing = transform(scaled_conditioning[testing], transformer_z)
        _, _, p_value = f_test(
            design_training,
            design_testing,
            scaled_target[training],
            scaled_target[testing],
            solver,
            cutoff,
            design_b_training,
            design_b_testing,
        )
        p_values.append(p_value)
    return merge(p_values), p_values


def main() -> None:
    for num_samples in (1000, 5000):
        print(f"================ {num_samples} samples ================")
        x, classes, y = fixture(num_samples)
        independent_rng = Rng(2080)
        independent_x = np.array(
            [independent_rng.next_normal() for _ in range(num_samples)]
        )
        independent_classes = np.where(
            np.array([independent_rng.next_double() for _ in range(num_samples)]) < 0.5,
            "Class 1",
            "Class 2",
        )

        cases = [
            (
                "independent categorical, conditional",
                x.reshape(-1, 1),
                y.reshape(-1, 1),
                one_hot(classes),
                False,
            ),
            (
                "dependent categorical, conditional",
                x.reshape(-1, 1),
                one_hot(classes),
                y.reshape(-1, 1),
                True,
            ),
            (
                "independent categorical, pairwise",
                independent_x.reshape(-1, 1),
                one_hot(independent_classes),
                None,
                False,
            ),
            (
                "dependent categorical, pairwise",
                x.reshape(-1, 1),
                one_hot(classes),
                None,
                True,
            ),
        ]

        for solver, cutoff in (
            ("port", 0.0),
            ("svd", 0.0),
            ("cut", 1e-2),
            ("cut", 1e-3),
            ("cut", 1e-4),
        ):
            print(f"--- solve {solver} {cutoff:.0e} ---")
            for name, inputs, target, conditioning, dependent in cases:
                p_value, p_values = run(
                    inputs, target, conditioning, solver, cutoff
                )
                decision = p_value < 0.05 if dependent else p_value > 0.05
                expected = "dependent" if dependent else "independent"
                got = "dependent" if p_value < 0.05 else "independent"
                mark = "ok " if decision else "FAIL"
                folds = " ".join(f"{value:.3g}" for value in p_values)
                print(
                    f"    {mark} {name:36s} p={p_value:.6g} "
                    f"expected {expected:11s} got {got:11s} folds {folds}"
                )


if __name__ == "__main__":
    main()
