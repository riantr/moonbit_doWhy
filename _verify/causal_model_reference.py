"""The upstream reference of the causal model of DoWhy.

The script runs the upstream `dowhy.causal_graph.CausalGraph` and the upstream
`dowhy.datasets.linear_dataset` on the fixtures of the upstream test file
`tests/test_causal_model.py`, and prints the facts the MoonBit port has to
reproduce:

  * the columns of the data set, the name of the treatment and the name of
    the outcome,
  * the GML graph of the data set, character for character,
  * the nodes and the edges of the graph of the upstream test
    `test_graph_input`, together with its common causes and its observed and
    unobserved variables,
  * the DOT graph the upstream turns the graph of the daggity web site into,
  * the observed and the unobserved variables of the fixture of the upstream
    test `test_unobserved_graph_variables_log_warning`, which drops the column
    `W0` from the data.

The upstream package cannot be imported as it is, because its `__init__` pulls
in `causallearn`; the loader of `upstream_gcm.py` reads the modules straight
from their files instead. The loader needs the modules of the causal graph, of
the data sets and of the plotting, which it reads as well.

The upstream reads a DOT graph with `pygraphviz` or `pydot`, and neither of
them is installed here, so the graph of the daggity web site is checked
through the DOT text the upstream produces, and not through a graph the
upstream builds out of it.

The upstream `linear_dataset` turns the treatment into a binary variable with
`np.vectorize(convert_to_binary)`, and `convert_to_binary` returns a one
element array. NumPy 1.x collected the results of such a function into an
array of the shape `(n, 1)`; NumPy 2.x calls the function through a ufunc,
which cannot store a one element array in the output of a scalar, so the
upstream raises a `ValueError` here. The script therefore restores the
behaviour of NumPy 1.x for `np.vectorize`, which is what the upstream was
written against. The numbers the upstream draws are not affected by it: the
same values are drawn from the generator of NumPy in the same order.

Usage:
    python _verify/causal_model_reference.py
"""

from __future__ import annotations

import os
import sys

import networkx as nx
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from upstream_gcm import load  # noqa: E402

_real_vectorize = np.vectorize


def _vectorize_of_numpy_one(func=None, *args, **kwargs):
    """The `np.vectorize` of NumPy 1.x, which the upstream was written against.

    NumPy 1.x called the function on every element and collected the results
    into one array, so a function that returns a one element array produced an
    array of the shape `(n, 1)`. NumPy 2.x calls the function through a ufunc,
    which cannot store a one element array in the output of a scalar.
    """
    if func is None or kwargs.get("otypes") is not None:
        return _real_vectorize(func, *args, **kwargs)

    def vectorized(*call_args):
        inputs = [np.asanyarray(arg) for arg in call_args]
        results = [
            func(*values) for values in zip(*(i.ravel() for i in inputs))
        ]
        if not results:
            return np.empty(inputs[0].shape)
        first = np.asanyarray(results[0])
        return np.asanyarray(results, dtype=first.dtype)

    return vectorized


def linear_dataset(**kwargs):
    """The upstream `linear_dataset`, with the `np.vectorize` of NumPy 1.x."""
    np.vectorize = _vectorize_of_numpy_one
    try:
        return datasets.linear_dataset(**kwargs)
    finally:
        np.vectorize = _real_vectorize

# The modules are loaded in the order of their dependencies, because the loader
# of the upstream reads a module straight from its file.
load("dowhy.utils.ordered_set")
load("dowhy.utils.api")
load("dowhy.utils.graph_operations")
load("dowhy.graph")
load("dowhy.gcm.ml")
load("dowhy.gcm.causal_mechanisms")
load("dowhy.gcm.causal_models")
load("dowhy.utils.plotting")
causal_graph_module = load("dowhy.causal_graph")
datasets = load("dowhy.datasets")
graph_operations = load("dowhy.utils.graph_operations")

CausalGraph = causal_graph_module.CausalGraph


def section(title: str) -> None:
    print()
    print("=" * 72)
    print(title)
    print("=" * 72)


def show(label: str, value: object) -> None:
    print(f"{label}: {value!r}")


def graph_facts(title: str, graph: nx.DiGraph, observed: list[str]) -> None:
    """Prints the facts of a graph of the upstream."""
    section(title)
    show("nodes", sorted(str(node) for node in graph.nodes))
    show("edges", sorted((str(source), str(target)) for source, target in graph.edges))
    show("observed", sorted(observed))
    unobserved = sorted(str(node) for node in graph.nodes if str(node) not in observed)
    show("unobserved", unobserved)


def causal_graph_of(graph_string: str, treatment: str, outcome: str, observed: list[str]) -> CausalGraph:
    """Builds the upstream causal graph of a GML string."""
    return CausalGraph(treatment, outcome, graph=graph_string, observed_node_names=observed)


def main() -> None:
    np.random.seed(2024)

    # ------------------------------------------------------------------
    # The fixture of the upstream tests of the causal model.
    # ------------------------------------------------------------------
    section("The fixture of the upstream tests: five common causes, one instrument")
    data = linear_dataset(
        beta=10,
        num_common_causes=5,
        num_instruments=1,
        num_samples=100,
        num_treatments=1,
        treatment_is_binary=True,
    )
    frame = data["df"]
    show("columns", list(frame.columns))
    show("treatment_name", data["treatment_name"])
    show("outcome_name", data["outcome_name"])
    show("common_causes_names", data["common_causes_names"])
    show("instrument_names", data["instrument_names"])
    show("effect_modifier_names", data["effect_modifier_names"])
    print()
    print("gml_graph:")
    print(data["gml_graph"])

    treatment = data["treatment_name"][0]
    outcome = data["outcome_name"]
    observed = list(frame.columns)

    # ------------------------------------------------------------------
    # The GML string of the upstream test `test_graph_input`.
    # ------------------------------------------------------------------
    gml_str = (
        'graph[directed 1 node[ id "{0}" label "{0}"]node[ id "{1}" label "{1}"]'
        'node[ id "Unobserved Confounders" label "Unobserved Confounders"]'
        'edge[source "{0}" target "{1}"]'
        'edge[source "Unobserved Confounders" target "{0}"]'
        'edge[source "Unobserved Confounders" target "{1}"]'
        'node[ id "X0" label "X0"] edge[ source "X0" target "{0}"]'
        ' node[ id "X1" label "X1"] edge[ source "X1" target "{0}"]'
        ' node[ id "X2" label "X2"] edge[ source "X2" target "{0}"]'
        ' edge[ source "X0" target "{1}"] edge[ source "X1" target "{1}"]'
        ' edge[ source "X2" target "{1}"] node[ id "Z0" label "Z0"]'
        ' edge[ source "Z0" target "{0}"]]'
    ).format(treatment, outcome)
    print()
    print("gml_str of test_graph_input:")
    print(gml_str)

    graph = nx.parse_gml(gml_str)
    graph_facts("The graph of the upstream test `test_graph_input`", graph, observed)

    # The model of the upstream test adds the columns of the data that are not
    # part of the graph as common causes, so the graph of the model holds them.
    model_graph = causal_graph_of(gml_str, treatment, outcome, observed)
    model_graph._graph = model_graph.add_missing_nodes_as_common_causes(observed)
    graph_facts(
        "The graph of the model of the upstream test `test_graph_input`",
        model_graph._graph,
        observed,
    )
    show("common_causes", sorted(model_graph.get_common_causes([treatment], [outcome])))
    show("instruments", sorted(model_graph.get_instruments([treatment], [outcome])))
    show("effect_modifiers", sorted(model_graph.get_effect_modifiers([treatment], [outcome])))
    show(
        "get_all_nodes(include_unobserved=True)",
        sorted(model_graph.get_all_nodes(include_unobserved=True)),
    )
    show(
        "get_all_nodes(include_unobserved=False)",
        sorted(model_graph.get_all_nodes(include_unobserved=False)),
    )

    # ------------------------------------------------------------------
    # The graph of the daggity web site of the upstream test
    # `test_graph_input3`, and the one of `tests/sample_dag.txt`.
    # ------------------------------------------------------------------
    daggity_str = (
        'dag {\n'
        '        "Unobserved Confounders" [pos="0.491,-1.056"]\n'
        '        X0 [pos="-2.109,0.057"]\n'
        '        X1 [adjusted, pos="-0.453,-1.562"]\n'
        '        X2 [pos="-2.268,-1.210"]\n'
        '        Z0 [pos="-1.918,-1.735"]\n'
        '        v0 [latent, pos="-1.525,-1.293"]\n'
        '        y [outcome, pos="-1.164,-0.116"]\n'
        '        "Unobserved Confounders" -> v0\n'
        '        "Unobserved Confounders" -> y\n'
        '        X0 -> v0\n'
        '        X0 -> y\n'
        '        X1 -> v0\n'
        '        X1 -> y\n'
        '        X2 -> v0\n'
        '        X2 -> y\n'
        '        Z0 -> v0\n'
        '        v0 -> y\n'
        '        }\n'
        '        '
    )
    section("The DOT graph the upstream turns the graph of the daggity web site into")
    print("daggity_to_dot of test_graph_input3:")
    print(graph_operations.daggity_to_dot(daggity_str))

    sample_dag = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "dowhy",
        "dowhy-0.14",
        "tests",
        "sample_dag.txt",
    )
    if os.path.isfile(sample_dag):
        with open(sample_dag, encoding="utf-8") as handle:
            sample = handle.read()
        section("The DOT graph the upstream turns `tests/sample_dag.txt` into")
        print("daggity_to_dot of sample_dag.txt:")
        print(graph_operations.daggity_to_dot(sample))

    # ------------------------------------------------------------------
    # The fixture of the upstream test
    # `test_unobserved_graph_variables_log_warning`.
    # ------------------------------------------------------------------
    section("The fixture of the upstream test `test_unobserved_graph_variables_log_warning`")
    warning_data = linear_dataset(
        beta=10,
        num_common_causes=3,
        num_instruments=1,
        num_effect_modifiers=1,
        num_samples=3,
        treatment_is_binary=True,
        stddev_treatment_noise=2,
        num_discrete_common_causes=1,
    )
    warning_frame = warning_data["df"]
    show("columns", list(warning_frame.columns))
    show("treatment_name", warning_data["treatment_name"])
    show("outcome_name", warning_data["outcome_name"])
    print()
    print("gml_graph:")
    print(warning_data["gml_graph"])
    warning_graph = nx.parse_gml(warning_data["gml_graph"])
    graph_facts(
        "The graph of the fixture of the upstream test `test_unobserved_graph_variables_log_warning`",
        warning_graph,
        list(warning_frame.columns),
    )
    dropped = warning_frame.drop(columns=["W0"])
    observed_without_w0 = [str(column) for column in dropped.columns]
    graph_facts(
        "The same graph, with the column `W0` dropped from the data",
        warning_graph,
        observed_without_w0,
    )


if __name__ == "__main__":
    main()
