"""The numbers of the remaining utilities of the upstream.

The script runs the functions of `dowhy.utils.ordered_set`,
`dowhy.utils.regression` and `dowhy.utils.propensity_score` on the fixtures of
the port and prints what they return, so the tests of the port can assert the
same numbers.

Usage:

    python _verify/utilities_reference.py
"""

from __future__ import annotations

import sys

import numpy as np
import pandas as pd

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

from dowhy.utils.ordered_set import OrderedSet  # noqa: E402
from dowhy.utils.propensity_score import (  # noqa: E402
    propensity_of_treatment_score,
)
from dowhy.utils.regression import (  # noqa: E402
    create_polynomial_function,
    generate_moment_function,
    get_numeric_features,
)

print("=== the ordered set")
ordered = OrderedSet(["b", "a", "b", "c"])
print("  the elements =", ordered.get_all())
print("  the length =", len(ordered))
print("  the union =", ordered.union(["d", "a"]).get_all())
print("  the intersection =", ordered.intersection(["a", "c", "z"]).get_all())
print("  the difference =", ordered.difference(["a", "c"]).get_all())
print("  the second element =", ordered[1])
print("  the text =", str(ordered))
print()

print("=== the polynomial functions")
polynomials = create_polynomial_function(3)
matrix = np.array([[2.0, 5.0], [3.0, 7.0]])
for index, polynomial in enumerate(polynomials):
    print(f"  the polynomial {index} of a matrix = {polynomial(matrix).ravel()}")
print()

print("=== the moment function")


def squared(x):
    return (x**2).sum(axis=1)


w = np.array([[0.0, 1.0], [1.0, 2.0], [1.0, 3.0]])
print("  the moment function =", generate_moment_function(w, squared))
print()

print("=== the numeric features")
frame = pd.DataFrame(
    {
        "a": [1.0, 2.0, 3.0],
        "b": ["x", "y", "z"],
        "c": [4, 5, 6],
    }
)
print("  the indices =", get_numeric_features(frame))
print()

print("=== the propensity of the treatment")
data = pd.DataFrame(
    {
        "x": [0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0],
        "y": [1.0, 0.0, 1.0, 1.0, 0.0, 1.0, 1.0, 0.0],
    }
)
scores = propensity_of_treatment_score(data, ["x"], "y")
print("  the scores =", scores)
