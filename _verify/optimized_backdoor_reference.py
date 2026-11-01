"""Runs the upstream optimized backdoor search on the graphs of the upstream test.

The upstream test file ``tests/causal_identifiers/test_optimize_backdoor.py``
checks that the set the optimized search finds blocks every backdoor path; it
does not compare the set with a fixed one. This script prints the set the
upstream finds, so that the port can be compared with it, and it prints it
twice, because the upstream breaks a tie in its hitting set algorithm with the
iteration order of a Python dictionary of strings, and the order of the strings
changes between the runs of the interpreter.
"""

import sys

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

import networkx as nx

from dowhy.causal_identifier.backdoor import Backdoor

GRAPHS = [
    ("test_1", "digraph{X1->T;X2->T;X1->X2;X2->Y;T->Y}"),
    ("test_2", "digraph{T->X1;T->X2;X1->X2;X2->Y;T->Y}"),
    ("test_3", "digraph{X1->T;X1->X2;Y->X2;X3->T;X3->Y;T->Y}"),
    ("test_4", "digraph{T->Y;X1->T;X1->Y;X2->T;}"),
    ("test_5", "digraph{X1->T;X1->X2;X2->Y;X3->T;X3->X4;X4->Y;T->Y}"),
    ("test_6", "digraph{X1->T;X1->X2;Y->X2;X3->T;X3->X4;X4->Y;T->Y}"),
]


def build(graph_string):
    """The graph of the upstream test file, built from its dot string."""
    graph = nx.DiGraph()
    body = graph_string[graph_string.index("{") + 1 : graph_string.rindex("}")]
    for edge in body.split(";"):
        edge = edge.strip()
        if not edge:
            continue
        source, target = edge.split("->")
        graph.add_edge(source.strip(), target.strip())
    return graph


def run(name, graph_string):
    graph = build(graph_string)
    backdoor = Backdoor(graph, ["T"], ["Y"])
    sets = backdoor.get_backdoor_vars()
    print(name)
    print("   number of sets:", len(sets))
    for adjustment in sets:
        print("   variables:", sorted(adjustment.get_adjustment_variables()))
    return sets


for _ in range(2):
    print("=== run ===")
    for name, graph_string in GRAPHS:
        run(name, graph_string)
