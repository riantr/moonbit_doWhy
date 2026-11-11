"""The numbers of the upstream's graph operations.

The script runs the functions of `dowhy.utils.graph_operations` on the
fixtures of the port and prints what they return, so the tests of the port can
assert the same numbers.

Usage:

    python _verify/graph_operations_reference.py
"""

from __future__ import annotations

import sys

import numpy as np
import networkx as nx

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

from dowhy.utils.ordered_set import OrderedSet  # noqa: E402
from dowhy.utils.graph_operations import (  # noqa: E402
    add_edge,
    adjacency_matrix_to_adjacency_list,
    adjacency_matrix_to_graph,
    convert_to_undirected_graph,
    del_edge,
    find_ancestor,
    find_c_components,
    find_predecessor,
    get_random_node_pair,
    get_simple_ordered_tree,
    induced_graph,
    is_connected,
    str_to_dot,
)

# The weighted fixture of the port: the graph `a -> b -> c`, `a -> c` and
# `d -> c`, whose edges hold the weights.
WEIGHTS = np.array(
    [
        [0.0, 0.5, 0.25, 0.0],
        [0.0, 0.0, 0.0, 0.0],
        [0.0, 0.0, 0.0, 0.0],
        [0.0, 0.0, 0.75, 0.0],
    ]
)
NAMES = ["a", "b", "c", "d"]

# The binary fixture of the port: the same graph without the weights. The
# upstream looks for the edges of the ancestors and of the C-components with a
# comparison against one, so it needs a matrix of zeroes and ones.
BINARY = np.array(
    [
        [0.0, 1.0, 1.0, 0.0],
        [0.0, 0.0, 0.0, 0.0],
        [0.0, 0.0, 0.0, 0.0],
        [0.0, 0.0, 1.0, 0.0],
    ]
)
# The binary fixture with the two edges that point in both directions.
BIDIRECTED = np.array(
    [
        [0.0, 1.0, 1.0, 0.0],
        [1.0, 0.0, 0.0, 0.0],
        [0.0, 0.0, 0.0, 1.0],
        [0.0, 0.0, 1.0, 0.0],
    ]
)

node2idx = {name: index for index, name in enumerate(NAMES)}
idx2node = {index: name for index, name in enumerate(NAMES)}

print("=== the adjacency list of the matrix")
print(adjacency_matrix_to_adjacency_list(WEIGHTS))
print()
print("--- with the labels of the caller")
print(adjacency_matrix_to_adjacency_list(WEIGHTS, NAMES))
print()

print("=== the graph of the matrix")
source = adjacency_matrix_to_graph(WEIGHTS).source
print(repr(source))
print("--- the compact graph")
print(repr(str_to_dot(source)))
print()

print("=== the ancestors of the nodes")
nodes = OrderedSet()
nodes.add("c")
print(sorted(find_ancestor(nodes, NAMES, BINARY, node2idx, idx2node).get_all()))
print()

print("=== the induced graph")
print(induced_graph(OrderedSet(["a", "b", "c"]), BINARY, node2idx))
print()

print("=== the C-components")
for component in find_c_components(BIDIRECTED, NAMES, idx2node):
    print(sorted(component.get_all()))
print()

print("=== the simple ordered tree")
tree = get_simple_ordered_tree(4)
print(sorted(tree.nodes()))
print(sorted(tree.edges()))
print()

print("=== the connectivity")
connected = nx.DiGraph()
connected.add_edge("a", "b")
connected.add_edge("b", "c")
print(is_connected(connected))
split = nx.DiGraph()
split.add_edge("a", "b")
split.add_node("c")
print(is_connected(split))
print("--- the undirected graph of the connected one")
undirected = convert_to_undirected_graph(connected)
print(sorted(undirected.nodes()))
print(sorted(undirected.edges()))
print()

print("=== the predecessor")
print(find_predecessor("a", "c", connected))
print(find_predecessor("c", "a", connected))
print()

print("=== the removal of an edge")
triangle = nx.DiGraph()
triangle.add_edge("a", "b")
triangle.add_edge("a", "c")
triangle.add_edge("b", "c")
del_edge("b", "c", triangle)
print(sorted(triangle.edges()))
print("--- the edge that would break the graph")
del_edge("a", "b", triangle)
print(sorted(triangle.edges()))
print()

print("=== the addition of an edge")
fork = nx.DiGraph()
fork.add_edge("a", "b")
fork.add_edge("a", "c")
add_edge("c", "b", fork)
print(sorted(fork.edges()))
print("--- the edge that would make a cycle")
add_edge("b", "c", fork)
print(sorted(fork.edges()))
print()

print("=== the random pair of nodes")
np.random.seed(42)
print(get_random_node_pair(5))
np.random.seed(42)
print(get_random_node_pair(5))
