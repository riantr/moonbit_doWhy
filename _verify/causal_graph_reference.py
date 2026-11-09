"""Runs the upstream graph functions on the daggity fixture of the upstream test.

The upstream test file `tests/test_causal_graph.py` compares the graph object of
DoWhy with the same graph built by `networkx`, which needs `pygraphviz`.  The
graph functions themselves do not need it: the graph of the fixture is built by
`dowhy.graph.build_graph_from_str`, which reads the daggity string of the
upstream fixture with `pydot`.

The script therefore builds the graph of the fixture with the upstream's own
reader and prints the answer of every graph function the upstream test file
exercises, so that the numbers of the port can be compared with them.

Usage:
    python _verify/causal_graph_reference.py
"""

from __future__ import annotations

import os
import sys

UPSTREAM_ROOT = os.environ.get(
    "DOWHY_UPSTREAM_ROOT",
    r"D:\src\MiniMax\git\dowhy\dowhy-0.14",
)
if UPSTREAM_ROOT not in sys.path:
    sys.path.insert(0, UPSTREAM_ROOT)

from dowhy.graph import (  # noqa: E402
    build_graph,
    build_graph_from_str,
    check_dseparation,
    check_valid_backdoor_set,
    check_valid_frontdoor_set,
    check_valid_mediation_set,
    do_surgery,
    get_all_nodes,
    get_backdoor_paths,
    get_instruments,
    has_directed_path,
)

FIXTURE = os.path.join(UPSTREAM_ROOT, "tests", "sample_dag.txt")

ACTION = ["v0"]
OUTCOME = ["y"]
OBSERVED = ["W0", "X0", "X1", "X2", "Z0", "v0", "y"]


def main() -> None:
    with open(FIXTURE, "r", encoding="utf-8") as handle:
        daggity = handle.read()

    graph = build_graph_from_str(daggity)
    print("nodes          :", sorted(graph.nodes()))
    print("edges          :", sorted(tuple(sorted(e)) for e in graph.edges()))
    print(
        "backdoor set   :",
        check_valid_backdoor_set(graph, ACTION, OUTCOME, ["X1", "X2"]),
    )
    print(
        "frontdoor set  :",
        check_valid_frontdoor_set(graph, ACTION, OUTCOME, ["X0"]),
    )
    print(
        "mediation set  :",
        check_valid_mediation_set(graph, ACTION, OUTCOME, ["X0"]),
    )
    print("dseparation    :", check_dseparation(graph, ACTION, OUTCOME, ["X1", "X2"]))

    surgery = do_surgery(graph, ACTION)
    print("surgery nodes  :", sorted(surgery.nodes()))
    print("surgery edges  :", sorted(tuple(sorted(e)) for e in surgery.edges()))

    paths = get_backdoor_paths(graph, ACTION, OUTCOME)
    print("backdoor paths :", ["->".join(p) for p in paths])

    instruments = get_instruments(graph, ACTION, OUTCOME)
    print("instruments    :", sorted(instruments))

    for flag in (True, False):
        nodes = get_all_nodes(graph, OBSERVED, include_unobserved_nodes=flag)
        print("all nodes %-5s:" % flag, sorted(nodes))

    for sources, targets in (
        (["X0"], ["y"]),
        (["X0", "X1", "X2"], ["y", "v0"]),
        ([], ["y"]),
        (["X0", "X1", "X2"], ["y", "v0", "Z0"]),
    ):
        print(
            "has path %-24s -> %-14s :" % (sources, targets),
            has_directed_path(graph, sources, targets),
        )

    built = build_graph(
        action_nodes=["v0"],
        outcome_nodes=["y"],
        common_cause_nodes=["W0"],
        instrument_nodes=["Z0"],
    )
    print("built edges    :", sorted(tuple(sorted(e)) for e in built.edges()))
    print("built nodes    :", sorted(built.nodes()))


if __name__ == "__main__":
    main()
