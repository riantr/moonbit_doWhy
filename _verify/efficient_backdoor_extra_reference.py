"""Runs the upstream efficient backdoor on the extra graphs of the port test.

The port test "given a graph without an adjustment set ..." checks the message
of the upstream for the case where the treatment is a neighbour of the outcome
in the H1 graph. This script checks what the upstream really does with that
graph, and with the graph of the port test that has no adjustment set.
"""

import networkx as nx
import sys

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

from dowhy.causal_identifier.efficient_backdoor import EfficientBackdoor

METHODS = ("optimal_adj_set", "optimal_minimal_adj_set", "optimal_mincost_adj_set")


def run(name, edges, observed, conditional=(), costs=None):
    graph = nx.DiGraph()
    graph.add_edges_from(edges)
    print(name)
    for method in METHODS:
        efficient = EfficientBackdoor(
            graph=graph,
            action_nodes=["X"],
            outcome_nodes=["Y"],
            observed_nodes=list(observed),
            conditional_node_names=list(conditional),
            costs=costs,
        )
        try:
            print("   ", method, "->", sorted(getattr(efficient, method)()))
        except ValueError as error:
            print("   ", method, "-> error:", error)


# The treatment is a neighbour of the outcome in the H1 graph, so no
# adjustment set exists.
run("W -> X, W -> Y, X -> Y with W unobserved",
    [("W", "X"), ("W", "Y"), ("X", "Y")], ["X", "Y"])

# The graph of the port test without an adjustment set.
run("Z -> X -> Y, W -> Y with X and Y observed",
    [("Z", "X"), ("X", "Y"), ("W", "Y")], ["X", "Y"])

# The same graph, but with every variable observed.
run("Z -> X -> Y, W -> Y with every variable observed",
    [("Z", "X"), ("X", "Y"), ("W", "Y")], ["Z", "X", "Y", "W"])
