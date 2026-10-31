"""Compute the Python reference results for the identification tests.

Loads `dowhy.graph` and `dowhy.causal_identifier.auto_identifier` without
executing the heavyweight `dowhy/__init__.py` (causallearn is not installed).

The GML-ish graph strings of the test suite are parsed here because neither
pygraphviz nor pydot is installed in this environment.

The output of this script is what the expected adjustment sets of
`src/identifiers/test_graphs.mbt` were taken from.
"""

import re
import sys
import types

ROOT = r"D:\src\MiniMax\git\dowhy\dowhy-0.14"
sys.path.insert(0, ROOT)

pkg = types.ModuleType("dowhy")
pkg.__path__ = [ROOT + r"\dowhy"]
sys.modules["dowhy"] = pkg

import networkx as nx  # noqa: E402
from dowhy.causal_identifier.auto_identifier import (  # noqa: E402
    identify_backdoor,
    identify_frontdoor,
    identify_generalized_adjustment_set,
    BackdoorAdjustment,
)

sys.path.insert(0, ROOT + r"\tests")
from tests.causal_identifiers.example_graphs import (  # noqa: E402
    TEST_GRAPH_SOLUTIONS,
    TEST_FRONTDOOR_GRAPH_SOLUTIONS,
    TEST_GRAPH_SOLUTIONS_COMPLETE_ADJUSTMENT,
)


def build_graph_from_str(graph_str):
    """Parse the graph strings of the test suite into a networkx DiGraph."""
    graph = nx.DiGraph()
    if "digraph" in graph_str:
        for node in re.findall(r"([A-Za-z0-9_]+);", graph_str.split("{", 1)[1]):
            graph.add_node(node)
        for src, dst in re.findall(r"([A-Za-z0-9_]+)->([A-Za-z0-9_]+)", graph_str):
            graph.add_edge(src, dst)
        return graph
    # GML flavour
    for node in re.findall(r"node\[id\s+\"([^\"]+)\"", graph_str):
        graph.add_node(node)
    for src, dst in re.findall(r"edge\[source\s+\"([^\"]+)\"\s+target\s+\"([^\"]+)\"", graph_str):
        graph.add_edge(src, dst)
    return graph


def fmt(sets):
    return sorted([sorted(s) for s in sets])


def show(title, value):
    print(f"{title}: {value}")


print("=" * 70)
print("BACKDOOR (exhaustive / minimal / maximal / default)")
print("=" * 70)
for name, sol in TEST_GRAPH_SOLUTIONS.items():
    graph = build_graph_from_str(sol["graph_str"])
    observed = sol["observed_variables"]
    print(f"--- {name}")
    for strat in [
        BackdoorAdjustment.BACKDOOR_EXHAUSTIVE,
        BackdoorAdjustment.BACKDOOR_MIN,
        BackdoorAdjustment.BACKDOOR_MAX,
        BackdoorAdjustment.BACKDOOR_DEFAULT,
    ]:
        res = identify_backdoor(graph, ["X"], ["Y"], observed, strat)
        show(f"    {strat.value}", fmt([r.get_adjustment_variables() for r in res]))
    res = identify_backdoor(
        graph, ["X"], ["Y"], observed, BackdoorAdjustment.BACKDOOR_MAX, direct_effect=True
    )
    show("    direct-maximal", fmt([r.get_adjustment_variables() for r in res]))

print()
print("=" * 70)
print("FRONTDOOR")
print("=" * 70)
for name, sol in TEST_FRONTDOOR_GRAPH_SOLUTIONS.items():
    graph = build_graph_from_str(sol["graph_str"])
    action = sol.get("action_nodes", ["X"])
    outcome = sol.get("outcome_nodes", ["Y"])
    res = identify_frontdoor(graph, action, outcome, sol["observed_variables"])
    show(name, sorted(res))

print()
print("=" * 70)
print("GENERALIZED (complete) ADJUSTMENT")
print("=" * 70)
for name, sol in TEST_GRAPH_SOLUTIONS_COMPLETE_ADJUSTMENT.items():
    graph = build_graph_from_str(sol["graph_str"])
    res = identify_generalized_adjustment_set(
        graph, sol["action_nodes"], sol["outcome_nodes"], sol["observed_variables"]
    )
    show(name, fmt([r.get_adjustment_variables() for r in res]))
