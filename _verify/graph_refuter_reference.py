"""Print the numbers the upstream of DoWhy computes for the refutation of a
graph, and compare them with the ones of the port.

The upstream draws the rows of its data sets with the global generator of
numpy, so the port cannot work on the very rows of the upstream. The fixture of
this script is deterministic, so the two sides work on the very same rows.

This script runs the upstream `dowhy.causal_refuters.graph_refuter` on the
fixture of the port and prints the numbers the port has to reproduce: the
partial correlation of the continuous data, the conditional mutual information
of the discrete data, and the verdict of the refutation of every constraint.

The upstream reads the names of the columns of the two variables of a
constraint instead of their values, so its conditional mutual information is the
negative entropy of the conditioning columns. The port reproduces that number.

Run: python _verify/graph_refuter_reference.py
"""

from __future__ import annotations

import sys

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

import numpy as np
import pandas as pd

from dowhy.causal_refuters.graph_refuter import GraphRefuter

# The fixture of the port: sixty rows of six columns.
N = 60
Z = np.array([float(i % 7) - 3.0 for i in range(N)])
X = 2.0 * Z + 0.5 * np.array([float(i % 5) - 2.0 for i in range(N)])
Y = 1.5 * X + 0.3 * np.array([float(i % 3) - 1.0 for i in range(N)])
W = np.array([float(i % 11) - 5.0 for i in range(N)])
D = (Z > 0).astype(int)
E = (X > 0).astype(int)
FRAME = pd.DataFrame({"x": X, "y": Y, "z": Z, "w": W, "d": D, "e": E})

# The constraints of the fixture of the port. The upstream hashes the
# constraints, so the variables that are conditioned on have to be a tuple.
CONSTRAINTS = [
    ("x", "y", ("z",)),
    ("x", "y", ("w",)),
    ("x", "y", ("z", "w")),
    ("x", "y", ()),
    ("d", "e", ("x",)),
    ("d", "e", ("z",)),
    ("d", "e", ()),
    ("x", "d", ("z",)),
    ("x", "d", ("y",)),
]


def main() -> int:
    print("=" * 78)
    print("the refutation of the upstream")
    print("=" * 78)
    refuter = GraphRefuter(
        data=FRAME,
        method_name_discrete="conditional_mutual_information",
        method_name_continuous="partial_correlation",
    )
    result = refuter.refute_model(independence_constraints=CONSTRAINTS)
    print("  number_of_constraints_model = {}".format(result.number_of_constraints_model))
    print("  number_of_constraints_satisfied = {}".format(result.number_of_constraints_satisfied))
    print("  refutation_result = {}".format(result.refutation_result))
    print()
    for key in refuter._results:
        value = refuter._results[key]
        print("  {} -> value {!r}, holds {}".format(key, value[0], value[1]))
    print()
    print("  the implications that hold true:")
    for implication in refuter._true_implications:
        print("    {}".format(implication))
    print("  the implications that hold false:")
    for implication in refuter._false_implications:
        print("    {}".format(implication))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
