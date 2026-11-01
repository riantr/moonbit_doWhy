"""Compares the cut of the upstream with the minimum cut of the same network.

The upstream does not use a plain minimum cut: it takes the source side of the
residual network of one maximum flow. With the infinite capacities of the
upstream there are many minimum cuts, and this script shows which one the
upstream picks and what the minimum cut of the same network is.
"""

import networkx as nx
import numpy as np
import sys

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

from dowhy.causal_identifier.efficient_backdoor import EfficientBackdoor
from dowhy.graph import build_graph_from_str

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14\tests\causal_identifiers")
from example_graphs_efficient import TEST_EFFICIENT_BD_SOLUTIONS

NAME = sys.argv[1] if len(sys.argv) > 1 else "sr22_fig2_example_graph"

example = TEST_EFFICIENT_BD_SOLUTIONS[NAME]
graph = build_graph_from_str(example["graph_str"])

efficient = EfficientBackdoor(
    graph=graph,
    action_nodes=["X"],
    outcome_nodes=["Y"],
    observed_nodes=example["observed_node_names"],
    conditional_node_names=example["conditional_node_names"],
    costs=example["costs"],
)

H1 = efficient.build_H1()
print("H1 nodes:", sorted(H1.nodes()))
print("H1 edges:", sorted(tuple(sorted(e)) for e in H1.edges()))

D = efficient.build_D()
print("D edges:")
for u, v, data in D.edges(data=True):
    print("   ", u, "->", v, "cap", data["capacity"])

flow_value, flow_dict = nx.algorithms.flow.maximum_flow(
    flowG=D, _s=efficient.outcome_name + "''", _t=efficient.treatment_name + "'"
)
print("flow value:", flow_value)

# The source side the upstream computes.
s_c = efficient.compute_smallest_mincut()
print("upstream S_c:", sorted(s_c))
print("upstream h(S_c):", sorted(efficient.h_operator(s_c)))

# The minimum cut of the same network.
cut_value, partition = nx.minimum_cut(D, efficient.outcome_name + "''",
                                       efficient.treatment_name + "'")
reachable, non_reachable = partition
print("minimum cut value:", cut_value)
print("minimum cut source side:", sorted(reachable))
print("minimum cut h(S):", sorted(efficient.h_operator(set(reachable))))

print("upstream expects:", example["efficient_mincost_adjustment"])
