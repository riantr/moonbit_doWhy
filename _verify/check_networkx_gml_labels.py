"""Shows how networkx reads the GML graph whose nodes have a numeric id and a
letter label.

The edges of a GML graph name the `id` of their nodes, while the name of a
node is its `label`, so a reader has to resolve the ids of the edges with the
labels of the nodes.

Usage:
    python _verify/check_networkx_gml_labels.py
"""

from __future__ import annotations

import networkx as nx

GML = """
graph [
directed 1
node [ id 0 label "a" ]
node [ id 1 label "b" ]
node [ id 2 label "c" ]
node [ id 3 label "d" ]
node [ id 4 label "e" ]
node [ id 5 label "f" ]
node [ id 6 label "g" ]
node [ id 7 label "h" ]
node [ id 8 label "i" ]
node [ id 9 label "j" ]
edge [ source 0 target 1 ]
edge [ source 0 target 3 ]
edge [ source 3 target 2 ]
edge [ source 7 target 4 ]
edge [ source 6 target 5 ]
edge [ source 7 target 8 ]
edge [ source 9 target 2 ]
edge [ source 9 target 8 ]
]
"""


def main() -> None:
    graph = nx.parse_gml(GML)
    print("nodes:", list(graph.nodes()))
    print("edges:", list(graph.edges()))
    for node, attributes in graph.nodes(data=True):
        print(f"node {node!r} attributes {attributes}")


if __name__ == "__main__":
    main()
