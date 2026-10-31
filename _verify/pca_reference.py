"""An independent reference for the PCA reducer of the port.

This script runs `sklearn.decomposition.PCA` on the very data set the
`data_transformers` package of the port reduces, and prints the numbers the
MoonBit implementation has to reproduce. The data set is generated with a
Python replica of the xorshift generator of `src/utils/random.mbt`, so the
two data sets are the same rows and not merely the same distribution.

Usage:
    python _verify/pca_reference.py
"""

from __future__ import annotations

import os
import sys

import numpy as np
from sklearn.decomposition import PCA

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from pc_reference import Xorshift  # noqa: E402

ROWS = 10000
SEED = 42


def fixture(rows: int, seed: int) -> np.ndarray:
    """The fixture of `src/data_transformers/reducer_test.mbt`."""
    rng = Xorshift(seed)
    mean0 = -1.0 + 2.0 * rng.next_double()
    mean1 = -1.0 + 2.0 * rng.next_double()
    first = []
    second = []
    for _ in range(rows):
        z0 = rng.next_normal()
        z1 = rng.next_normal()
        first.append(mean0 + z0)
        second.append(mean1 + 0.5 * z0 + 0.8660254037844386 * z1)
    return np.column_stack([np.array(first), np.array(second)])


def main() -> None:
    data = fixture(ROWS, SEED)

    # `standardize=False`: PCA centres the data and keeps the scale.
    reduced = PCA(n_components=2).fit_transform(data)
    print("REDUCED")
    for row in reduced[:5]:
        print(f"  {row[0]:.12f} {row[1]:.12f}")

    model = PCA(n_components=2).fit(data)
    print("COMPONENTS")
    for row in model.components_:
        print(f"  {row[0]:.12f} {row[1]:.12f}")
    print("RATIOS")
    for ratio in model.explained_variance_ratio_:
        print(f"  {ratio:.12f}")

    # `standardize=True`: the columns are scaled before the reduction.
    standardised = PCA(n_components=2).fit_transform(
        (data - data.mean(axis=0)) / data.std(axis=0)
    )
    print("STANDARDISED")
    for row in standardised[:5]:
        print(f"  {row[0]:.12f} {row[1]:.12f}")


if __name__ == "__main__":
    main()
