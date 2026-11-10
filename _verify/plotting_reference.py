"""Print the numbers the upstream of DoWhy computes for the plotting layer, and
compare them with the ones of the port.

The upstream draws a causal graph with Graphviz and falls back to `matplotlib`
when Graphviz is not installed, and it draws the bar plots with `matplotlib`.
MoonBit has neither of them, so the port computes the attributes the two
backends compute: the width of the arrow of an edge, the label and the colour
of the nodes and of the edges, the layer of every node and the uncertainty bars
of a bar plot.

This script runs the upstream on the very graph and on the very values the port
works on, and prints the numbers the port has to reproduce.

The Graphviz backend of the upstream is exercised with a stub of `pygraphviz`,
because the package is an optional dependency of the upstream and it is not
installed here. The stub records the nodes and the edges the upstream asks
`pygraphviz` to draw, so the attributes below are the ones of the upstream and
not of the stub.

Run: python _verify/plotting_reference.py
"""

from __future__ import annotations

import sys
import types

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

import matplotlib

matplotlib.use("Agg")

import networkx as nx
import numpy as np
import pandas as pd

# --- a stub of pygraphviz that records what the upstream asks for -----------

RECORDED_NODES = []
RECORDED_EDGES = []


class FakeAGraph:
    def __init__(self, directed=True, **kwargs):
        self.directed = directed

    def add_node(self, node, **attrs):
        RECORDED_NODES.append((node, dict(attrs)))

    def add_edge(self, source, target, **attrs):
        RECORDED_EDGES.append((source, target, dict(attrs)))

    def layout(self, prog=None):
        pass

    def draw(self, path):
        pass


fake = types.ModuleType("pygraphviz")
fake.AGraph = FakeAGraph
sys.modules["pygraphviz"] = fake

from dowhy.utils.graphviz_plotting import plot_causal_graph_graphviz
from dowhy.utils.networkx_plotting import (
    _custom_assign_layers,
    plot_causal_graph_networkx,
)
from dowhy.utils.plotting import _calc_arrow_width, bar_plot

# The numbers the port produces for the fixtures below.
PORT_ARROW_WIDTHS = {
    (0.4, 0.5): 3.3000000000000003,
    (0.2, 0.5): 1.7000000000000002,
    (-0.2, 0.5): 1.7000000000000002,
    (0.5, 0.5): 4.1,
    (0.35, 0.5): 2.9,
    (100, 101): 4.06039603960396,
    (100, 0): 4.1,
}

PORT_BAR_YERR = {
    "misspecified": [[0.0, 0.5, 0.0], [0.0, 0.10000000000000009, 0.0]],
    "dropped": [[0.0, 0.0], [0.0, 0.0]],
    "below": [[1.0], [0.0]],
    "reaching": [[0.0], [0.0]],
    "around": [[9.992007221626409e-16], [1.1102230246251565e-15]],
}

PORT_GRAPHVIZ_EDGES = [
    ("X", "Y", {"label": " 10.0", "penwidth": "4.1", "color": "black"}),
    ("Y", "Z", {"color": "black"}),
]

PORT_NETWORKX_LAYERS = {"X": 0, "Y": 1, "Z": 2}


def graph() -> nx.DiGraph:
    return nx.DiGraph([("X", "Y"), ("Y", "Z")])


def captured_bar_plot(values, uncertainties):
    """The bars and the error bars the upstream hands to `matplotlib`."""
    import dowhy.utils.plotting as plotting

    captured = {}

    def fake_bar(*args, **kwargs):
        captured["yerr"] = kwargs.get("yerr")

    original = plotting.plt.bar
    plotting.plt.bar = fake_bar
    try:
        bar_plot(values, uncertainties=uncertainties)
    finally:
        plotting.plt.bar = original
    return captured


def main() -> int:
    print("=" * 78)
    print("the width of the arrow, the upstream and the port")
    print("=" * 78)
    for (strength, maximum), port in PORT_ARROW_WIDTHS.items():
        upstream = _calc_arrow_width(strength, max_strength=maximum)
        print(
            "  _calc_arrow_width({}, {}) upstream {!r} port {!r} difference {!r}".format(
                strength, maximum, upstream, port, abs(upstream - port)
            )
        )
    try:
        _calc_arrow_width(100, max_strength=-1)
        print("  the upstream accepts a negative largest strength")
    except ValueError as error:
        print("  the upstream refuses a negative largest strength: {}".format(error))
    print("  the port refuses it too: calc_arrow_width(100.0, -1.0) is None")

    print()
    print("=" * 78)
    print("the bars of a bar plot, the upstream and the port")
    print("=" * 78)
    cases = [
        (
            "misspecified",
            {"X": 1, "Y": 2, "Z": 3},
            {"X": (1.1, 0.9), "Y": (1.5, 2.1)},
        ),
        ("dropped", {"X": 1, "Y": 2}, {"X": (10**-2, 10**-1), "Y": (10**-2, 10**-1)}),
        ("below", {"X": 1}, {"X": (0, 1)}),
        ("reaching", {"X": 1}, {"X": (0, 0.99999999999)}),
        ("around", {"X": 1}, {"X": (1 - 10**-15, 1 + 10**-15)}),
    ]
    for name, values, uncertainties in cases:
        captured = captured_bar_plot(values, uncertainties)
        upstream = [list(row) for row in np.asarray(captured["yerr"])]
        port = PORT_BAR_YERR[name]
        print("  {}".format(name))
        print("    upstream yerr = {}".format(upstream))
        print("    port    yerr = {}".format(port))
        difference = np.max(np.abs(np.asarray(upstream) - np.asarray(port)))
        print("    the largest difference = {!r}".format(difference))

    print()
    print("=" * 78)
    print("the attributes of the Graphviz backend, the upstream")
    print("=" * 78)
    for strengths in [{("X", "Y"): 10}, {("X", "Y"): 0.29}, {("X", "Y"): float("inf")}]:
        RECORDED_NODES.clear()
        RECORDED_EDGES.clear()
        plot_causal_graph_graphviz(
            graph(), causal_strengths=strengths, display_plot=False
        )
        print("  the strengths {}".format(strengths))
        print("    the nodes = {}".format(RECORDED_NODES))
        print("    the edges = {}".format(RECORDED_EDGES))
    print("  the port for the strength 10:")
    print("    the edges = {}".format(PORT_GRAPHVIZ_EDGES))

    print()
    print("=" * 78)
    print("the attributes of the networkx backend, the upstream")
    print("=" * 78)
    captured = {}

    def fake_draw_nodes(graph, pos, **kwargs):
        captured.setdefault("node_color", []).append(kwargs.get("node_color"))

    def fake_draw_edges(graph, pos, **kwargs):
        captured.setdefault("edge_color", []).append(kwargs.get("edge_color"))
        captured.setdefault("width", []).append(kwargs.get("width"))

    original_nodes = nx.draw_networkx_nodes
    original_edges = nx.draw_networkx_edges
    nx.draw_networkx_nodes = fake_draw_nodes
    nx.draw_networkx_edges = fake_draw_edges
    try:
        plot_causal_graph_networkx(graph(), causal_strengths={("X", "Y"): 10})
    finally:
        nx.draw_networkx_nodes = original_nodes
        nx.draw_networkx_edges = original_edges
    print("  the colour of the nodes = {}".format(captured.get("node_color")))
    print("  the colour of the edges = {}".format(captured.get("edge_color")))
    print("  the width of the edges = {}".format(captured.get("width")))
    layers = _custom_assign_layers(graph())
    print("  the layers = {}".format(layers))
    print("  the layers of the port = {}".format(PORT_NETWORKX_LAYERS))

    print()
    print("=" * 78)
    print("the graph of an adjacency matrix, the upstream")
    print("=" * 78)
    frame = pd.DataFrame(
        np.array([[0, 1, 0], [0, 0, 1], [0, 0, 0]]),
        columns=["X", "Y", "Z"],
        index=["X", "Y", "Z"],
    )
    directed = nx.from_pandas_adjacency(frame, nx.DiGraph())
    undirected = nx.from_pandas_adjacency(frame, nx.Graph())
    print("  the nodes of the directed graph = {}".format(list(directed.nodes())))
    print("  the edges of the directed graph = {}".format(list(directed.edges())))
    print("  the nodes of the undirected graph = {}".format(list(undirected.nodes())))
    print("  the edges of the undirected graph = {}".format(list(undirected.edges())))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
