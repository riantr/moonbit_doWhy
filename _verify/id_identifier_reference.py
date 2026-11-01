"""Runs the upstream ID algorithm on the graphs of the upstream test file.

The upstream test file ``tests/causal_identifiers/test_id_identifier.py``
compares the string of the estimand with a fixed one, so the string is the
number the port has to reproduce.
"""

import sys

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

import networkx as nx

from dowhy import identify_effect_id

GRAPHS = [
    ("test_1", "digraph{T->Y;}"),
    ("test_2", "digraph{T->Y; Y->T;}"),
    ("test_3", "digraph{T->X1;X1->Y;}"),
    ("test_4", "digraph{T->Y;T->X1;X1->Y;}"),
    ("test_5", "digraph{T->Y;X1->T;X1->Y;X2->T;}"),
    ("test_6", "digraph{T;X1->Y;}"),
]


def build(graph_string):
    graph = nx.DiGraph()
    body = graph_string[graph_string.index("{") + 1 : graph_string.rindex("}")]
    for edge in body.split(";"):
        edge = edge.strip()
        if not edge:
            continue
        if "->" not in edge:
            # A node without an edge.
            graph.add_node(edge)
            continue
        source, target = edge.split("->")
        graph.add_edge(source.strip(), target.strip())
    return graph


for name, graph_string in GRAPHS:
    print(name)
    try:
        estimand = identify_effect_id(
            build(graph_string), action_nodes=["T"], outcome_nodes=["Y"]
        )
    except Exception as error:  # noqa: BLE001
        print("   error:", type(error).__name__, error)
        continue
    if estimand is None:
        print("   none")
        continue
    print("   string:", repr(str(estimand)))
    print("   sum:", estimand.get_val("sum"))
