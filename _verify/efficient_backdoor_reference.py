"""The upstream reference of the efficient backdoor search.

The script runs the upstream `dowhy.causal_identifier.efficient_backdoor` on
the example graphs of the upstream test file
`tests/causal_identifiers/test_efficient_backdoor_identifier.py` and prints the
adjustment set of every strategy, so that the numbers the MoonBit port has to
reproduce are the numbers of the upstream and not a reading of it.

The upstream package cannot be imported as it is, because its `__init__` pulls
in `causallearn`; the loader of `upstream_gcm.py` reads the modules straight
from their files instead. The upstream modules that the loader does not know
are registered with it before loading them.

Usage:
    python _verify/efficient_backdoor_reference.py
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import upstream_gcm  # noqa: E402
from upstream_gcm import load  # noqa: E402

UPSTREAM = Path(r"D:\src\MiniMax\git\dowhy\dowhy-0.14")
sys.path.insert(0, str(UPSTREAM))
sys.path.insert(0, str(UPSTREAM / "tests"))

from tests.causal_identifiers.example_graphs_efficient import (  # noqa: E402
    TEST_EFFICIENT_BD_SOLUTIONS,
)

EFFICIENT = None


def register_missing_modules() -> None:
    """Registers the upstream modules the loader does not know."""
    upstream_gcm._PATHS["dowhy.graph"] = "graph.py"
    upstream_gcm._PATHS["dowhy.causal_identifier.efficient_backdoor"] = (
        "causal_identifier/efficient_backdoor.py"
    )


def expose_upstream_packages() -> None:
    """Points the stubbed packages at the real directories of the upstream."""
    root = upstream_gcm.upstream_root()
    for name, relative in (
        ("dowhy", "dowhy"),
        ("dowhy.causal_identifier", os.path.join("dowhy", "causal_identifier")),
        ("dowhy.gcm", os.path.join("dowhy", "gcm")),
        ("dowhy.gcm.util", os.path.join("dowhy", "gcm", "util")),
        ("dowhy.utils", os.path.join("dowhy", "utils")),
    ):
        if name not in sys.modules:
            import types

            module = types.ModuleType(name)
            module.__path__ = []  # type: ignore[attr-defined]
            sys.modules[name] = module
        sys.modules[name].__path__ = [str(root / relative)]


def build_graph(graph_str: str):
    """The graph of the upstream test suite, read from its GML string.

    The upstream reads it with `build_graph_from_str`, which ends up in
    `networkx.parse_gml` for the GML flavour of the fixtures.
    """
    import networkx as nx

    return nx.DiGraph(nx.parse_gml(graph_str))


def show(label: str, values) -> None:
    """Prints a set of variables."""
    print(f"{label} = {sorted(values)}")


def main() -> None:
    global EFFICIENT

    register_missing_modules()
    upstream_gcm._stub_packages()
    expose_upstream_packages()

    EFFICIENT = load("dowhy.causal_identifier.efficient_backdoor")

    for name, example in TEST_EFFICIENT_BD_SOLUTIONS.items():
        graph = build_graph(example["graph_str"])
        costs = example.get("costs")
        print(f"--- {name} ---")
        for method in (
            "optimal_adj_set",
            "optimal_minimal_adj_set",
            "optimal_mincost_adj_set",
        ):
            search = EFFICIENT.EfficientBackdoor(
                graph=graph.copy(),
                action_nodes=["X"],
                outcome_nodes=["Y"],
                observed_nodes=example["observed_node_names"],
                conditional_node_names=example["conditional_node_names"],
                costs=costs,
            )
            try:
                values = getattr(search, method)()
            except Exception as error:  # noqa: BLE001
                print(f"{method} = error: {error}")
                continue
            show(method, values)


if __name__ == "__main__":
    main()
