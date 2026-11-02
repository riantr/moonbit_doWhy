"""Prints the graph that networkx reads out of the GML strings of the upstream
tests.

The script shows which names networkx gives to the nodes of a GML graph and
which edges it reads, because the port has to read the same graph.

Usage:
    python _verify/check_networkx_gml.py
"""

from __future__ import annotations

import networkx as nx

GML = (
    'graph[directed 1 node[ id "y" label "y"] node[ id "W0" label "W0"]'
    ' node[ id "v0" label "v0"] edge[ source "v0" target "y"]'
    ' edge[ source "W0" target "v0"] edge[ source "W0" target "y"]]'
)

GML_WITH_UNOBSERVED = (
    'graph[directed 1 node[ id "v0" label "v0"] node[ id "y" label "y"]'
    ' node[ id "Unobserved Confounders" label "Unobserved Confounders"]'
    ' edge[source "v0" target "y"]'
    ' edge[source "Unobserved Confounders" target "v0"]'
    ' edge[source "Unobserved Confounders" target "y"]'
    ' node[ id "X0" label "X0"] edge[ source "X0" target "v0"]'
    ' node[ id "X1" label "X1"] edge[ source "X1" target "v0"]'
    ' node[ id "X2" label "X2"] edge[ source "X2" target "v0"]'
    ' edge[ source "X0" target "y"] edge[ source "X1" target "y"]'
    ' edge[ source "X2" target "y"] node[ id "Z0" label "Z0"]'
    ' edge[ source "Z0" target "v0"]]'
)


def show(name: str, text: str) -> None:
    print(f"--- {name} ---")
    parsed = nx.parse_gml(text)
    print("    parse_gml nodes:", list(parsed.nodes()))
    print("    parse_gml edges:", list(parsed.edges()))
    for node, attributes in parsed.nodes(data=True):
        print(f"    node {node!r} attributes {attributes}")


def main() -> None:
    print("networkx", nx.__version__)
    show("plain", GML)
    show("with unobserved", GML_WITH_UNOBSERVED)


if __name__ == "__main__":
    main()
