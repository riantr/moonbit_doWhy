"""The upstream reference of the falsification layer of `dowhy.gcm`.

The script runs the upstream `dowhy.gcm.falsify` on the fixtures of the
falsification layer, which `_verify/gen_falsify_testdata.py` builds, and
prints the numbers the MoonBit port has to reproduce:

  * the summary of every validation method (the local Markov condition, the
    pairwise dependencies, the parental d-separations and the causal minimality)
    of every fixture, with the p-value of every test it ran,
  * the outcome of the falsification of the graph of the collider and of the
    chain, with the number of violations of every permutation and the p-value
    of the permutation test.

The numbers are the ones of the upstream code itself and not a reading of it:
the validations depend on the p-values of the independence test, so a
re-implementation of the test in this script would only produce a second
opinion of the upstream instead of its numbers. The port compares its numbers
with the ones printed here.

The upstream package cannot be imported as it is, because its `__init__` pulls
in `causallearn`; the loader of `upstream_gcm.py` reads the modules straight
from their files instead. The upstream modules that the loader does not know
are registered with it before loading them:

  * `dowhy.gcm.falsify` holds the upstream validation methods,
  * `dowhy.gcm.independence_test` and its `kernel` and `kernel_operation`
    modules hold the upstream `kernel_based` test,
  * `dowhy.gcm.util` holds the upstream plotting function that the falsification
    module imports.

The `ml` package has to be loaded before the modules that use it, because the
loader stubs the packages of the upstream out and the stub of `dowhy.gcm.ml`
holds no prediction model.

The global generator of numpy is seeded with `SEED` before every fixture, so
that the numbers of one fixture do not depend on the fixtures before it and
the printed values are reproducible. The seeding does not change the numbers
of the continuous fixtures, because the generalised covariance measure with a
linear regressor is deterministic, but it keeps the permutations of the
falsification reproducible.

Usage:
    python _verify/gcm_falsify_reference.py
"""

from __future__ import annotations

import os
import sys

import networkx as nx
import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gen_falsify_testdata  # noqa: E402
import upstream_gcm  # noqa: E402
from upstream_gcm import load, upstream_root  # noqa: E402

# The seed of the global generator of numpy. It is the seed of the generator of
# the fixtures, so that the two agree.
SEED = gen_falsify_testdata.SEED

# The number of rows of every fixture of the falsification layer.
NUM_ROWS = gen_falsify_testdata.NUM_ROWS


def register_missing_modules() -> None:
    """Registers the upstream modules the loader does not know.

    The loader of `upstream_gcm.py` owns the list of the modules it reads, but
    it does not know the modules this script needs. Its list is only extended
    here, the file itself is left alone.
    """
    upstream_gcm._PATHS["dowhy.gcm.falsify"] = "gcm/falsify.py"
    upstream_gcm._PATHS["dowhy.gcm.independence_test"] = "gcm/independence_test/__init__.py"
    upstream_gcm._PATHS["dowhy.gcm.independence_test.kernel"] = "gcm/independence_test/kernel.py"
    upstream_gcm._PATHS["dowhy.gcm.independence_test.kernel_operation"] = "gcm/independence_test/kernel_operation.py"
    upstream_gcm._PATHS["dowhy.gcm.util"] = "gcm/util/__init__.py"


def expose_upstream_packages() -> None:
    """Points the stubbed packages at the real directories of the upstream.

    The loader stubs the packages of the upstream out, so that the modules of
    `dowhy.gcm` can be read without the `causallearn` dependency of the real
    package. The plotting module of `dowhy.gcm.util` reaches the plotting
    module of `dowhy.utils`, which the stubbed packages do not reach, so their
    paths are set to the directories of the upstream.
    """
    root = upstream_root()
    for name, relative in (
        ("dowhy", "dowhy"),
        ("dowhy.gcm", os.path.join("dowhy", "gcm")),
        ("dowhy.gcm.util", os.path.join("dowhy", "gcm", "util")),
        ("dowhy.utils", os.path.join("dowhy", "utils")),
    ):
        sys.modules[name].__path__ = [str(root / relative)]


def show(label: str, value: object, indent: int = 2) -> None:
    """Prints a value with its label and the full precision of a double."""
    print(f"{' ' * indent}{label} = {repr(float(value))}")  # type: ignore[arg-type]


def frame_of(fixtures: dict, name: str) -> pd.DataFrame:
    """The frame of a fixture."""
    columns = fixtures[name]
    data = pd.DataFrame({column: values for column, values in columns.items()})
    if len(data) != NUM_ROWS:
        raise RuntimeError(f"the fixture {name} does not have {NUM_ROWS} rows")
    return data


def describe_key(key: tuple) -> str:
    """The description of the key of a p-value."""
    parts = []
    for item in key:
        if isinstance(item, tuple):
            parts.append("{" + ",".join(sorted(str(entry) for entry in item)) + "}")
        else:
            parts.append(str(item))
    return " | ".join(parts)


def print_summary(falsify, label: str, summary: dict) -> None:
    """Prints the summary of one validation method.

    The summary holds the number of violations, the number of tests and the
    p-value of every test, keyed by the nodes the test was run on.
    """
    const = falsify.FalsifyConst
    print(f"  {label}")
    print(f"    n_violations = {summary[const.N_VIOLATIONS]}")
    print(f"    n_tests = {summary[const.N_TESTS]}")
    p_values = summary.get(const.P_VALUES)
    if not p_values:
        print("    p_values = none")
        return
    for key in sorted(p_values.keys(), key=describe_key):
        p_value, violation = p_values[key]
        print(f"    test {describe_key(key)}")
        show("p_value", p_value, indent=6)
        print(f"      violation = {bool(violation)}")


def run_case(
    falsify,
    label: str,
    graph: nx.DiGraph,
    data: pd.DataFrame,
    methods,
) -> None:
    """Runs the validations of one case and prints their summaries."""
    np.random.seed(SEED)
    print(f"CASE {label}")
    summary = falsify.run_validations(graph, data, methods=methods)
    for name in sorted(summary.keys(), key=str):
        print_summary(falsify, str(name).split(".")[-1], summary[name])


def main() -> None:
    register_missing_modules()

    config = load("dowhy.gcm.config")
    config.disable_progress_bars()
    # The validation methods distribute their tests over the worker processes of
    # joblib by default. The worker processes cannot import the stubbed `dowhy`
    # package of the loader, so the tests are run in this process instead.
    config.set_default_n_jobs(1)

    expose_upstream_packages()
    # The `ml` package has to come first: the loader stubs the packages out, so
    # the modules of the upstream that use the prediction models need them
    # already.
    load("dowhy.gcm.ml")
    load("dowhy.gcm.util")
    independence = load("dowhy.gcm.independence_test")
    falsify = load("dowhy.gcm.falsify")
    graph_module = load("dowhy.graph")

    def gcm_linear(x, y, z=None):
        return independence.generalised_cov_based(
            x,
            y,
            Z=z,
            prediction_model_X=load("dowhy.gcm.ml").create_linear_regressor,
            prediction_model_Y=load("dowhy.gcm.ml").create_linear_regressor,
        )

    fixtures = gen_falsify_testdata.build_fixtures()

    print(f"SEED = {SEED}")
    print(f"NUM_ROWS = {NUM_ROWS}")

    # ------------------------------------------------------------------
    # A. The validations of the fixtures.
    #
    # The graphs and the expected numbers are the ones of the upstream test
    # file `tests/gcm/test_falsify.py`.
    # ------------------------------------------------------------------
    collider_data = frame_of(fixtures, "collider")
    chain_data = frame_of(fixtures, "chain")
    full_dag_data = frame_of(fixtures, "full_dag")
    single_node_data = frame_of(fixtures, "single_node")
    single_edge_data = frame_of(fixtures, "single_edge")
    minimality_data = frame_of(fixtures, "causal_minimality")

    collider_graph = nx.DiGraph([("X", "Z"), ("Y", "Z")])
    wrong_collider_graph = nx.DiGraph([("X", "Y"), ("Z", "Y")])
    chain_graph = nx.DiGraph([("X", "Y"), ("Y", "Z")])
    wrong_chain_graph = nx.DiGraph([("X", "Z"), ("Z", "Y")])
    full_dag_graph = nx.DiGraph(
        [("X0", "X1"), ("X0", "X2"), ("X0", "X3"), ("X1", "X2"), ("X1", "X3"), ("X2", "X3")]
    )
    single_node_graph = nx.DiGraph()
    single_node_graph.add_node("X")
    single_edge_graph = nx.DiGraph([("X0", "X1")])
    wrong_single_edge_graph = nx.DiGraph()
    wrong_single_edge_graph.add_node("X0")
    wrong_single_edge_graph.add_node("X1")
    minimality_graph = nx.DiGraph([("X0", "Y"), ("X1", "Y")])
    non_minimality_graph = minimality_graph.copy()
    non_minimality_graph.add_edge("X2", "Y")

    from functools import partial  # noqa: E402

    lmc = partial(
        falsify.validate_lmc,
        independence_test=gcm_linear,
        conditional_independence_test=gcm_linear,
    )
    pd_method = partial(falsify.validate_pd, independence_test=gcm_linear)
    cm = partial(
        falsify.validate_cm,
        independence_test=gcm_linear,
        conditional_independence_test=gcm_linear,
    )

    run_case(
        falsify,
        "collider_correct",
        collider_graph,
        collider_data,
        (lmc, pd_method, partial(falsify.validate_tpa, causal_graph_reference=collider_graph)),
    )
    run_case(
        falsify,
        "collider_wrong",
        wrong_collider_graph,
        collider_data,
        (lmc, pd_method, partial(falsify.validate_tpa, causal_graph_reference=collider_graph)),
    )
    run_case(
        falsify,
        "chain_correct",
        chain_graph,
        chain_data,
        (lmc, pd_method, partial(falsify.validate_tpa, causal_graph_reference=chain_graph)),
    )
    run_case(
        falsify,
        "chain_wrong",
        wrong_chain_graph,
        chain_data,
        (lmc, pd_method, partial(falsify.validate_tpa, causal_graph_reference=chain_graph)),
    )
    run_case(
        falsify,
        "empty",
        nx.DiGraph(),
        pd.DataFrame(),
        (lmc, pd_method, partial(falsify.validate_tpa, causal_graph_reference=nx.DiGraph())),
    )
    run_case(
        falsify,
        "full_dag",
        full_dag_graph,
        full_dag_data,
        (lmc, pd_method, partial(falsify.validate_tpa, causal_graph_reference=full_dag_graph)),
    )
    run_case(
        falsify,
        "single_node",
        single_node_graph,
        single_node_data,
        (lmc, pd_method, partial(falsify.validate_tpa, causal_graph_reference=single_node_graph)),
    )
    run_case(
        falsify,
        "single_edge",
        single_edge_graph,
        single_edge_data,
        (lmc, pd_method, partial(falsify.validate_tpa, causal_graph_reference=single_edge_graph)),
    )
    run_case(
        falsify,
        "single_edge_wrong",
        wrong_single_edge_graph,
        single_edge_data,
        (lmc, pd_method, partial(falsify.validate_tpa, causal_graph_reference=single_edge_graph)),
    )
    run_case(falsify, "causal_minimality_non_minimal", non_minimality_graph, minimality_data, (cm,))
    run_case(falsify, "causal_minimality_minimal", minimality_graph, minimality_data, (cm,))

    # ------------------------------------------------------------------
    # B. The falsification of the graph of the collider and of the chain.
    #
    # The number of the permutations is left at -1, so that every permutation
    # of the nodes is used and the result does not depend on the generator.
    # ------------------------------------------------------------------
    for label, graph, data in (
        ("collider", collider_graph, collider_data),
        ("chain", chain_graph, chain_data),
    ):
        np.random.seed(SEED)
        print(f"FALSIFY_GRAPH {label}")
        result = falsify.falsify_graph(
            graph,
            data,
            independence_test=gcm_linear,
            conditional_independence_test=gcm_linear,
            n_permutations=-1,
        )
        print(f"  can_evaluate = {bool(result.can_evaluate)}")
        print(f"  falsified = {result.falsified}")
        print(f"  falsifiable = {result.falsifiable}")
        for name in sorted(result.summary.keys(), key=str):
            if name == falsify.FalsifyConst.MEC:
                continue
            const = falsify.FalsifyConst
            method_summary = result.summary[name]
            print(f"  method {str(name).split('.')[-1]}")
            print(f"    n_tests = {method_summary[const.N_TESTS]}")
            print(f"    given_violations = {method_summary[const.GIVEN_VIOLATIONS]}")
            print(f"    f_given_violations = {repr(float(method_summary[const.F_GIVEN_VIOLATIONS]))}")
            show("p_value", method_summary[const.P_VALUE], indent=4)
            permuted = method_summary[const.PERM_VIOLATIONS]
            print(f"    perm_violations = {list(permuted)}")
            fractions = method_summary[const.F_PERM_VIOLATIONS]
            print(f"    f_perm_violations = {[repr(float(value)) for value in fractions]}")
        print(f"  mec = {len(result.summary[falsify.FalsifyConst.MEC])} graphs")


if __name__ == "__main__":
    main()
