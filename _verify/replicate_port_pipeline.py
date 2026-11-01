"""Replicates the pipeline of the regression based independence test of the
MoonBit port, so that the numbers of the port can be traced in Python.

The script walks the very steps of the port:

  * the fixture of `src/gcm/independence_categorical_test.mbt`,
  * the split into folds of `src/gcm/independence.mbt`,
  * the Nystroem transformer of `src/gcm/independence.mbt`,
  * the F-test of `src/gcm/stats.mbt`,
  * the least squares fit of `src/utils/linalg.mbt`, which is the pseudo inverse
    of the Gram matrix of the design matrix.

Every step has a counterpart that solves the problem the way the upstream code
does, so that the two can be compared.

Usage:
    python _verify/replicate_port_pipeline.py
"""

from __future__ import annotations

import numpy as np

MASK64 = (1 << 64) - 1
SEED = 2080
NUM_SAMPLES = 1000
NUM_COMPONENTS = 40
K_FOLDS = 3
EPS = 1e-12


class Rng:
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

    def next_int(self, bound: int) -> int:
        return self.next_u64() % bound

    def shuffle(self, values: list[int]) -> list[int]:
        out = list(values)
        i = len(out) - 1
        while i > 0:
            j = self.next_int(i + 1)
            out[i], out[j] = out[j], out[i]
            i -= 1
        return out


def random_permutation(rng: Rng, n: int) -> list[int]:
    return rng.shuffle(list(range(n)))


def scale_columns(m: np.ndarray) -> np.ndarray:
    """The `scale_columns` of `src/gcm/util_general.mbt`."""
    out = m.copy()
    for j in range(out.shape[1]):
        column = out[:, j]
        spread = column.std()
        if spread <= 0.0:
            continue
        out[:, j] = (column - column.mean()) / spread
    return out


def rbf(left: np.ndarray, right: np.ndarray, gamma: float) -> np.ndarray:
    squared = ((left[:, None, :] - right[None, :, :]) ** 2).sum(-1)
    return np.exp(-gamma * squared)


def nystroem_fit(samples: np.ndarray, n_components: int, rng: Rng):
    """The `nystroem_fit` of `src/gcm/independence.mbt`."""
    n_samples = samples.shape[0]
    count = min(n_components, n_samples)
    order = random_permutation(rng, n_samples)
    basis = samples[order[:count]]
    gamma = 1.0 / samples.shape[1]
    kernel = rbf(basis, basis, gamma)
    values, vectors = np.linalg.eigh(kernel)
    values = np.where(values < EPS, EPS, values)
    normalisation = (vectors * (1.0 / np.sqrt(values))) @ vectors.T
    return basis, normalisation, gamma


def nystroem_transform(samples: np.ndarray, transformer) -> np.ndarray:
    basis, normalisation, gamma = transformer
    return rbf(samples, basis, gamma) @ normalisation.T


def gram_pinv(a: np.ndarray, tol_factor: float = 1.0e-12) -> np.ndarray:
    """The `mat_pinv` of `src/utils/linalg.mbt`."""
    gram = a.T @ a
    values, vectors = np.linalg.eigh(gram)
    max_val = float(np.max(np.abs(values)))
    tol = tol_factor * max_val
    inv_gram = np.zeros_like(gram)
    for k in range(len(values)):
        lam = values[k]
        if abs(lam) <= tol:
            continue
        inv_gram += (1.0 / lam) * np.outer(vectors[:, k], vectors[:, k])
    return inv_gram @ a.T


def centred_fit(x: np.ndarray, y: np.ndarray, solver: str):
    """The `centered_ols_fit` of `src/gcm/stats.mbt`."""
    offsets = x.mean(axis=0)
    y_offset = y.mean()
    centred = x - offsets
    centred_y = y - y_offset
    if solver == "port":
        beta = gram_pinv(centred).dot(centred_y)
    else:
        beta = np.linalg.lstsq(centred, centred_y, rcond=None)[0]
    intercept = y_offset - offsets.dot(beta)
    return beta, intercept


def predict(x: np.ndarray, beta: np.ndarray, intercept: float) -> np.ndarray:
    return x.dot(beta) + intercept


def f_test(
    x_training_a: np.ndarray,
    x_test_a: np.ndarray,
    y_training: np.ndarray,
    y_test: np.ndarray,
    solver: str,
) -> tuple[float, float, float]:
    """The `estimate_ftest_pvalue_of_targets` of `src/gcm/stats.mbt`."""
    ssr_a = 0.0
    for k in range(y_training.shape[1]):
        beta, intercept = centred_fit(x_training_a, y_training[:, k], solver)
        residual = y_test[:, k] - predict(x_test_a, beta, intercept)
        ssr_a += float((residual**2).sum())
    ssr_b = 0.0
    for k in range(y_training.shape[1]):
        residual = y_test[:, k] - y_training[:, k].mean()
        ssr_b += float((residual**2).sum())
    dof_diff_1 = x_test_a.shape[1]
    dof_diff_2 = x_test_a.shape[0] - x_test_a.shape[1] - 1
    f_statistic = (ssr_b - ssr_a) / dof_diff_1 * dof_diff_2
    if ssr_a < EPS:
        ssr_a = 0.0
    if ssr_b < EPS:
        ssr_b = 0.0
    if ssr_a == 0.0 and ssr_b == 0.0:
        f_statistic = 0.0
    elif ssr_a != 0.0:
        f_statistic = f_statistic / ssr_a
    return ssr_a, ssr_b, f_statistic


def main() -> None:
    rng = Rng(SEED)
    x = np.array([rng.next_normal() for _ in range(NUM_SAMPLES)])
    classes = np.where(x > 0, "Class 1", "Class 2")
    noise = np.array([rng.next_normal() for _ in range(NUM_SAMPLES)])
    y = np.where(x > 0, 1.0, 0.0) + noise

    # The pairwise dependent categorical case: the target is the one-hot
    # encoding of the classes.
    target = np.column_stack([(classes == "Class 1").astype(float), (classes == "Class 2").astype(float)])
    inputs = scale_columns(x.reshape(-1, 1))
    scaled_target = scale_columns(target)

    test_rng = Rng(SEED)
    order = random_permutation(test_rng, NUM_SAMPLES)
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
        condition = np.linalg.cond(design_training)
        print(f"--- fold {fold + 1} ---")
        print(f"    rows {design_training.shape[0]}/{design_testing.shape[0]} cond {condition:.4e}")
        for solver in ("port", "svd"):
            ssr_a, ssr_b, f_statistic = f_test(
                design_training, design_testing,
                scaled_target[training], scaled_target[testing],
                solver,
            )
            print(
                f"    {solver:5s} ssr_a={ssr_a:14.6f} ssr_b={ssr_b:12.6f} f={f_statistic:.6e}"
            )


if __name__ == "__main__":
    main()
