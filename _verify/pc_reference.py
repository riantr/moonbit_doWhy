"""An independent reference implementation of the PC algorithm.

This script re-implements, in Python, both the fixture generator of the
`cm` package and the PC algorithm, so that the MoonBit port can be checked
against something that was written separately. The generator replicates the
xorshift generator of `src/utils/random.mbt`, which makes the two data sets
bit-for-bit comparable.

Usage:
    python _verify/pc_reference.py
"""

from __future__ import annotations

import itertools
import math
from typing import Iterable

import numpy as np
from scipy.stats import norm

MASK64 = (1 << 64) - 1


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
        return math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2)


def fixture(rows: int, seed: int) -> dict[str, np.ndarray]:
    """The fixture of `src/cm/pc_test.mbt`: `x -> y`, `z -> y`, `x -> w`."""
    rng = Xorshift(seed)
    xs, ys, zs, ws = [], [], [], []
    for _ in range(rows):
        x = rng.next_normal()
        z = rng.next_normal()
        w = 0.8 * x + rng.next_normal()
        y = 0.8 * x + 0.8 * z + rng.next_normal()
        xs.append(x)
        ys.append(y)
        zs.append(z)
        ws.append(w)
    return {"x": np.array(xs), "y": np.array(ys), "z": np.array(zs), "w": np.array(ws)}


def correlation_matrix(data: dict[str, np.ndarray], labels: list[str]) -> np.ndarray:
    columns = [data[name] for name in labels]
    corr = np.corrcoef(np.vstack(columns))
    return np.asarray(corr, dtype=float)


def partial_correlation(corr: np.ndarray, x: int, y: int, s: list[int]) -> float:
    indices = [x, y] + list(s)
    sub = corr[np.ix_(indices, indices)]
    try:
        inv = np.linalg.inv(sub)
    except np.linalg.LinAlgError:
        inv = np.linalg.pinv(sub)
    denominator = math.sqrt(inv[0, 0] * inv[1, 1])
    if denominator <= 0.0:
        return 0.0
    return float(-inv[0, 1] / denominator)


def fisher_z(corr: np.ndarray, n: int, x: int, y: int, s: list[int]) -> tuple[float, float]:
    """The partial correlation and the p value of the Fisher z test."""
    r = partial_correlation(corr, x, y, s)
    clipped = min(max(r, -1.0 + 1.0e-12), 1.0 - 1.0e-12)
    z = 0.5 * math.log((1.0 + clipped) / (1.0 - clipped))
    df = n - len(s) - 3
    se = 1.0 / math.sqrt(df) if df > 0 else 1.0
    statistic = z / se
    p_value = float(2.0 * (1.0 - norm.cdf(abs(statistic))))
    return r, p_value


def pc(
    corr: np.ndarray,
    n: int,
    alpha: float,
) -> tuple[list[tuple[int, int]], list[tuple[int, int]], list[tuple[int, int, int]]]:
    """The PC skeleton and orientation.

    Returns the skeleton edges, the directed edges and the v-structures.
    """
    size = corr.shape[0]
    adjacent = {(i, j) for i in range(size) for j in range(i + 1, size)}
    sepset: dict[tuple[int, int], list[int]] = {}

    def neighbours(node: int) -> list[int]:
        found = []
        for a, b in adjacent:
            if a == node:
                found.append(b)
            elif b == node:
                found.append(a)
        return sorted(found)

    level = 0
    while True:
        removals = []
        for a, b in sorted(adjacent):
            candidates = [n for n in neighbours(a) if n != b]
            if len(candidates) < level:
                continue
            for subset in itertools.combinations(candidates, level):
                _, p_value = fisher_z(corr, n, a, b, list(subset))
                if p_value > alpha:
                    removals.append((a, b, list(subset)))
                    break
        if not removals:
            if level >= size - 2:
                break
            level += 1
            continue
        for a, b, subset in removals:
            adjacent.discard((a, b))
            key = (a, b) if a < b else (b, a)
            sepset[key] = subset

    skeleton = sorted(adjacent)

    # The v-structures.
    directed: set[tuple[int, int]] = set()
    colliders: list[tuple[int, int, int]] = []
    for z in range(size):
        for x, y in itertools.combinations(neighbours(z), 2):
            if (min(x, y), max(x, y)) in adjacent:
                continue
            key = (x, y) if x < y else (y, x)
            if z not in sepset.get(key, []):
                directed.add((x, z))
                directed.add((y, z))
                colliders.append((x, z, y))

    # Meek's rules, written in the form "orient the undirected edge (a, b)
    # as a -> b".
    def is_directed(a: int, b: int) -> bool:
        return (a, b) in directed

    def adjacent_pair(a: int, b: int) -> bool:
        return (min(a, b), max(a, b)) in adjacent

    def meek_orients(a: int, b: int) -> bool:
        for w in range(size):
            if w in (a, b):
                continue
            # R1: w -> a, a - b and w, b not adjacent gives a -> b.
            if is_directed(w, a) and not adjacent_pair(w, b):
                return True
            # R2: a -> w -> b gives a -> b.
            if is_directed(a, w) and is_directed(w, b):
                return True
        for c in range(size):
            if c in (a, b) or not adjacent_pair(a, c):
                continue
            for d in range(size):
                if d in (a, b, c):
                    continue
                # R3: a - c -> b, a - d -> b and c, d not adjacent give a -> b.
                if (
                    is_directed(c, b)
                    and is_directed(d, b)
                    and adjacent_pair(a, d)
                    and not adjacent_pair(c, d)
                ):
                    return True
                # R4: a - c -> d -> b and a, d not adjacent give a -> b.
                if (
                    is_directed(c, d)
                    and is_directed(d, b)
                    and not adjacent_pair(a, d)
                ):
                    return True
        return False

    changed = True
    while changed:
        changed = False
        for a, b in list(adjacent):
            if is_directed(a, b) or is_directed(b, a):
                continue
            if meek_orients(a, b):
                directed.add((a, b))
                changed = True
                break

    return skeleton, sorted(directed), sorted(colliders)


def main() -> None:
    labels = ["x", "y", "z", "w"]
    rows = 1000
    data = fixture(rows, 42)
    corr = correlation_matrix(data, labels)
    print("CORR", " ".join(f"{value:.12f}" for value in corr.reshape(-1)))
    skeleton, directed, colliders = pc(corr, rows, 0.05)
    print("SKELETON", " ".join(f"{labels[a]}-{labels[b]}" for a, b in skeleton))
    print("DIRECTED", " ".join(f"{labels[a]}->{labels[b]}" for a, b in directed))
    print("COLLIDERS", " ".join(f"{labels[a]}-{labels[b]}-{labels[c]}" for a, b, c in colliders))

    # The Fisher z test of the fixture of `src/cm/pc_test.mbt`, whose expected
    # numbers the test pins. The critical value is the quantile of the standard
    # normal distribution, and the p value comes from the normal distribution
    # as well, so both of them change with the error function of the port.
    test_rows = 500
    test_data = fixture(test_rows, 7)
    test_corr = correlation_matrix(test_data, labels)
    correlation, p_value = fisher_z(test_corr, test_rows, 0, 1, [])
    print("FISHER_Z")
    print(f"  critical_value = {norm.ppf(1.0 - 0.05 / 2.0):.15f}")
    print(f"  correlation = {correlation:.15f}")
    print(f"  p_value = {p_value:.15f}")
    _, independent_p_value = fisher_z(test_corr, test_rows, 0, 2, [])
    print(f"  independent_p_value = {independent_p_value:.15f}")


if __name__ == "__main__":
    main()
