"""Print the numbers the upstream of DoWhy computes for the tests of the
conditional independence of the columns of a table, and compare them with the
ones of the port.

The upstream draws its samples with the global generator of numpy, so the port
cannot work on the very rows of the upstream. The fixture of this script is
deterministic, so the two sides work on the very same rows.

This script runs the upstream `dowhy.utils.cit` on the fixture of the port and
prints the numbers the port has to reproduce: the partial correlation of two
columns given the other ones, the confidence interval of a correlation
coefficient, the entropy of a categorical variable and the conditional mutual
information of two columns.

Run: python _verify/cit_reference.py
"""

from __future__ import annotations

import sys

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

import numpy as np
import pandas as pd

from dowhy.utils.cit import compute_ci, conditional_MI, entropy, partial_corr

# The fixture of the port: fifty rows of four columns.
N = 50
Z = np.array([float(i % 7) - 3.0 for i in range(N)])
X = 2.0 * Z + 0.5 * np.array([float(i % 5) - 2.0 for i in range(N)])
Y = 1.5 * X + 0.3 * np.array([float(i % 3) - 1.0 for i in range(N)])
W = np.array([float(i % 11) - 5.0 for i in range(N)])
FRAME = pd.DataFrame({"x0": X, "y0": Y, "z0": Z, "w0": W})

# The discrete fixture of the port: the columns of the frame of the upstream,
# cut into two classes.
D = (Z > 0).astype(int)
E = (W > 0).astype(int)
DISCRETE = pd.DataFrame({"d0": D, "e0": E, "z0": Z, "w0": W})


def main() -> int:
    print("=" * 78)
    print("the partial correlation of the upstream")
    print("=" * 78)
    for x, y, z in [("x0", "y0", ["z0"]), ("x0", "w0", ["z0"]), ("x0", "w0", ["z0", "y0"])]:
        stats = partial_corr(data=FRAME, x=x, y=y, z=z)
        print("  partial_corr(x={}, y={}, z={})".format(x, y, z))
        print("    n = {}".format(stats["n"]))
        print("    r = {!r}".format(stats["r"]))
        print("    CI95% = {}".format(stats["CI95%"]))
        print("    p-val = {!r}".format(stats["p-val"]))

    print()
    print("=" * 78)
    print("the partial correlation of the upstream, the Spearman one")
    print("=" * 78)
    stats = partial_corr(data=FRAME, x="x0", y="w0", z=["z0"], method="spearman")
    print("  n = {}".format(stats["n"]))
    print("  r = {!r}".format(stats["r"]))
    print("  CI95% = {}".format(stats["CI95%"]))
    print("  p-val = {!r}".format(stats["p-val"]))

    print()
    print("=" * 78)
    print("the confidence interval of a correlation of the upstream")
    print("=" * 78)
    for r, nx in [(0.5, 200), (0.9, 50), (-0.3, 100), (0.0, 47)]:
        print("  compute_ci({}, {}) = {}".format(r, nx, compute_ci(r=r, nx=nx, ny=nx)))

    print()
    print("=" * 78)
    print("the entropy of the upstream")
    print("=" * 78)
    for values in [
        [0, 0, 1, 1],
        [0, 0, 0, 0],
        ["a", "a", "b"],
        [0, 1, 2, 3, 4, 5, 6, 7],
    ]:
        print("  entropy({}) = {!r}".format(values, entropy(values)))

    print()
    print("=" * 78)
    print("the conditional mutual information of the upstream")
    print("=" * 78)
    print(
        "  conditional_MI(d0, e0 | z0) = {!r}".format(
            conditional_MI(data=DISCRETE, x=["d0"], y=["e0"], z=["z0"])
        )
    )
    print(
        "  conditional_MI(d0, e0 | z0, w0) = {!r}".format(
            conditional_MI(data=DISCRETE, x=["d0"], y=["e0"], z=["z0", "w0"])
        )
    )
    print(
        "  conditional_MI(d0, d0 | z0) = {!r}".format(
            conditional_MI(data=DISCRETE, x=["d0"], y=["d0"], z=["z0"])
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
