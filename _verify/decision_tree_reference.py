"""Print the decision tree scikit-learn builds for the fixture of the port.

The port of the decision tree classifier of the `gcm` package is the port of
`sklearn.tree.DecisionTreeClassifier` with its default parameters: the gini
impurity as the criterion, every feature at every split, a node of at least two
samples and a leaf of at least one sample.

The fixture of this script is the one of the test of the port, which is built
with the generator of the `utils` package of the port. The script replicates
that generator, so the rows of the script and the rows of the port are the same
rows.

This script prints the tree of scikit-learn node by node, the number of its
nodes and the probability of every class of the first rows of the fixture.

Run: python _verify/decision_tree_reference.py
"""

import math

import numpy as np
from sklearn.tree import DecisionTreeClassifier

# The seed of the fixture of the port.
SEED = 2071

# The number of the rows of the fixture of the port.
ROWS = 200

# The tolerance of the thresholds: scikit-learn keeps them in single precision.
THRESHOLD_TOLERANCE = 1.0e-6


class Random:
    """The generator of the `utils` package of the port, a 64 bit xorshift."""

    def __init__(self, seed):
        self.state = seed if seed != 0 else 0x9E3779B97F4A7C15

    def next_u64(self):
        x = self.state
        x ^= (x << 13) & 0xFFFFFFFFFFFFFFFF
        x ^= x >> 7
        x ^= (x << 17) & 0xFFFFFFFFFFFFFFFF
        self.state = x
        return x

    def next_double(self):
        return (self.next_u64() >> 11) / 9007199254740992.0

    def next_normal(self):
        u1 = self.next_double()
        u2 = self.next_double()
        u1 = u1 if u1 >= 1.0e-12 else 1.0e-12
        return math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2)


def build_fixture():
    rng = Random(SEED)
    first = []
    second = []
    third = []
    for _ in range(ROWS):
        first.append(rng.next_normal())
        second.append(rng.next_normal())
        third.append(1.0 if rng.next_double() > 0.5 else 0.0)
    labels = [
        "true" if first[i] + second[i] - 0.5 * third[i] > 0.0 else "false"
        for i in range(ROWS)
    ]
    X = np.column_stack([first, second, third])
    return X, labels


def walk(tree, index, depth, out):
    """The nodes of the tree, in the order of a walk from the left to the right."""
    if tree.children_left[index] == -1:
        out.append(("leaf", tree.n_node_samples[index], np.rint(tree.value[index][0]).astype(int).tolist()))
        return
    out.append(
        (
            "split",
            tree.feature[index],
            float(tree.threshold[index]),
            tree.n_node_samples[index],
        )
    )
    walk(tree, tree.children_left[index], depth + 1, out)
    walk(tree, tree.children_right[index], depth + 1, out)


def main() -> int:
    X, labels = build_fixture()
    model = DecisionTreeClassifier()
    model.fit(X, labels)
    tree = model.tree_

    nodes = []
    walk(tree, 0, 0, nodes)

    print("=" * 78)
    print("the decision tree of scikit-learn on the fixture of the port")
    print("=" * 78)
    print("the number of the nodes = {}".format(tree.node_count))
    print("the number of the leaves = {}".format(tree.n_leaves))
    print("the nodes of the tree, in the order of a walk:")
    for node in nodes:
        print("    {}".format(node))

    probabilities = model.predict_proba(X)
    print("the probability of the second class of the first ten rows:")
    for value in probabilities[:10, 1]:
        print("    p = {!r}".format(value))
    print(
        "the number of the rows the tree classifies as true = {}".format(
            int((model.predict(X) == "true").sum())
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
