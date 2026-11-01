"""Checks the numerical stability of the least squares fit of the port.

The port fits the models of the F-test with the pseudo inverse it computes from
the eigen decomposition of the Gram matrix of the design matrix, while the
upstream fits them with the `LinearRegression` of scikit-learn, which solves
the least squares problem with an SVD. The kernel features of the regression
based independence test are ill-conditioned, so the two fits can differ a lot.

The script fits the same design matrix with the two ways of solving the least
squares problem and prints the residual sums of squares of the training set
and of the test set.

Usage:
    python _verify/check_lstsq_stability.py
"""

from __future__ import annotations

import numpy as np

MASK64 = (1 << 64) - 1
SEED = 2080
NUM_SAMPLES = 1000
NUM_COMPONENTS = 40
TRAIN_FRACTION = 2.0 / 3.0


class Xorshift:
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
        return int(self.next_double() * bound) % bound


def gram_pinv(a: np.ndarray, tol_factor: float = 1.0e-12) -> np.ndarray:
    """The pseudo inverse of the port: the eigen decomposition of the Gram."""
    gram = a.T @ a
    values, vectors = np.linalg.eigh(gram)
    max_val = np.max(np.abs(values))
    tol = tol_factor * max_val
    inv_gram = np.zeros_like(gram)
    for k in range(len(values)):
        lam = values[k]
        if abs(lam) <= tol:
            continue
        inv_gram += (1.0 / lam) * np.outer(vectors[:, k], vectors[:, k])
    return inv_gram @ a.T


def main() -> None:
    rng = Xorshift(SEED)
    x = np.array([rng.next_normal() for _ in range(NUM_SAMPLES)])
    classes = (x > 0).astype(float)
    y = np.where(x > 0, 1.0, 0.0) + np.array(
        [rng.next_normal() for _ in range(NUM_SAMPLES)]
    )

    # The standardised input, the way the upstream scales it.
    scaled_x = ((x - x.mean()) / x.std()).reshape(-1, 1)
    # The one-hot target, the way the upstream encodes it.
    target = np.column_stack([classes, 1.0 - classes])
    target = (target - target.mean(axis=0)) / target.std(axis=0)

    order = [rng.next_int(NUM_SAMPLES) for _ in range(NUM_SAMPLES)]
    basis = scaled_x[np.array(order[:NUM_COMPONENTS])]

    gamma = 1.0 / scaled_x.shape[1]
    k_basis = np.exp(-gamma * ((basis[:, None, :] - basis[None, :, :]) ** 2).sum(-1))
    embedded = np.exp(-gamma * ((scaled_x[:, None, :] - basis[None, :, :]) ** 2).sum(-1))

    # The normalisation of the port: the inverse square root of the kernel
    # matrix of the basis points.
    values, vectors = np.linalg.eigh(k_basis)
    values = np.where(np.abs(values) < 1.0e-12, 1.0e-12, values)
    normalisation = (vectors * (1.0 / np.sqrt(values))) @ vectors.T
    features = embedded @ normalisation.T

    # The normalisation of the upstream: the Cholesky factor of the kernel
    # matrix plus a small ridge.
    cholesky = np.linalg.cholesky(k_basis + 1.0e-6 * np.eye(NUM_COMPONENTS))
    features_cholesky = embedded @ np.linalg.solve(cholesky, np.eye(NUM_COMPONENTS))

    n_train = int(NUM_SAMPLES * TRAIN_FRACTION)
    train = np.arange(n_train)
    test = np.arange(n_train, NUM_SAMPLES)

    for name, design in (("eigen", features), ("cholesky", features_cholesky)):
        condition = np.linalg.cond(design[train])
        for solver in ("gram_pinv", "svd"):
            if solver == "gram_pinv":
                beta = gram_pinv(design[train]) @ target[train]
            else:
                beta = np.linalg.lstsq(design[train], target[train], rcond=None)[0]
            ssr_train = float(((target[train] - design[train] @ beta) ** 2).sum())
            ssr_test = float(((target[test] - design[test] @ beta) ** 2).sum())
            print(
                f"{name:9s} {solver:9s} cond={condition:.3e}"
                f" ssr_train={ssr_train:.6f} ssr_test={ssr_test:.6f}"
            )


if __name__ == "__main__":
    main()
