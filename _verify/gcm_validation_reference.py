"""The upstream reference of the validation layer of `dowhy.gcm`.

The script runs the upstream `dowhy.gcm.validation` on the fixtures of the
validation layer, which `_verify/gen_validation_testdata.py` builds, and prints
the numbers the MoonBit port has to reproduce:

  * the outcome of the validation of the causal structure of the four graph
    fixtures (the collider, the chain, the fork and the general graph),
    together with the p-value, the FDR adjusted p-value and the success flag of
    the local Markov test of every node and of the edge dependence test of
    every parent,
  * the outcome of the validation of the invertible model of the non-linear
    data, for the correct graph and for the two wrong ones, both for the data
    of the upstream test file and for the non-linear fixture of the generator,
  * the p-values of the kernel based independence test for every pair of every
    fixture, with and without a conditioning variable.

The numbers are the ones of the upstream code itself and not a reading of it:
the validation of a causal structure depends on the p-values of a kernel based
independence test, on the FDR control of `statsmodels` and on the model
selection of the upstream, so a re-implementation of those in this script would
only produce a second opinion of the upstream instead of its numbers. The port
compares its numbers with the ones printed here.

The upstream package cannot be imported as it is, because its `__init__` pulls
in `causallearn`; the loader of `upstream_gcm.py` reads the modules straight
from their files instead. Five of the upstream modules are not known to that
loader, so this script registers them with it before loading them:

  * `dowhy.gcm.validation` holds the upstream `refute_causal_structure` and
    `refute_invertible_model`,
  * `dowhy.gcm.independence_test` and its `kernel` and `kernel_operation`
    modules hold the upstream `kernel_based` test,
  * `dowhy.gcm.fitting_sampling` holds the upstream `fit`.

The constructor of `InvertibleStructuralCausalModel` imports
`dowhy.causal_graph` and `dowhy.causal_model`, so those two modules are
registered as well, and the stubbed packages of the loader are pointed at the
real directories of the upstream, the way `gcm_whatif_reference.py` does it.

The script needs the `causal-learn` package to be installed, because the
upstream delegates the kernel based independence test to it.

The global generator of numpy is seeded with `SEED` before every fixture and
before every computation of a p-value, so that the numbers of one fixture do
not depend on the fixtures before it and the printed values are reproducible.
The seeding matters: the upstream draws a random permutation of the rows for
every call of the kernel based test, and for the larger samples the p-value of
the test depends on that permutation.

The outcome of the validation of the invertible model depends on the number of
rows as well, so the script validates the non-linear data of the upstream test
file, whose outcomes the upstream test file asserts, and the non-linear
fixture of the generator, whose sixty rows are too few for the upstream to
tell the signal from the noise.

Usage:
    python _verify/gcm_validation_reference.py
"""

from __future__ import annotations

import os
import sys

import networkx as nx
import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gen_validation_testdata  # noqa: E402
import upstream_gcm  # noqa: E402
from upstream_gcm import load, upstream_root  # noqa: E402

# The seed of the global generator of numpy. It is set before every fixture, so
# that the numbers of one fixture do not depend on the fixtures before it. It is
# the seed of the generator of the fixtures, so that the two agree.
SEED = gen_validation_testdata.SEED

# The number of rows of every fixture of the validation layer.
NUM_ROWS = gen_validation_testdata.NUM_ROWS

# The number of rows of the non-linear data of the upstream test file
# `tests/gcm/test_validation.py`. The outcome of the validation of the
# invertible model depends on the number of rows, and only the data of the
# upstream reproduces the outcome that the upstream test asserts.
NUM_ROWS_UPSTREAM = 5000

# The graphs of the four graph fixtures, in the order of the fixtures of the
# generator.
GRAPH_FIXTURES: dict[str, tuple[tuple[str, str], ...]] = {
    "collider": (("X", "Z"), ("Y", "Z")),
    "chain": (("X", "Z"), ("Z", "Y")),
    "fork": (("Z", "X"), ("Z", "Y")),
    "general": (("Z", "X"), ("Z", "Y"), ("X", "Y")),
}

# The three graphs of the validation of the invertible model.
INVERTIBLE_GRAPHS: dict[str, tuple[tuple[str, str], ...]] = {
    "correct": (("X", "Y"), ("Y", "Z")),
    "reversed": (("Z", "Y"), ("Y", "X")),
    "collider": (("X", "Y"), ("Z", "Y")),
}

np.random.seed(SEED)


def register_missing_modules() -> None:
    """Registers the upstream modules the loader does not know.

    The loader of `upstream_gcm.py` owns the list of the modules it reads, but
    it does not know the modules this script needs. Its list is only extended
    here, the file itself is left alone.
    """
    upstream_gcm._PATHS["dowhy.gcm.validation"] = "gcm/validation.py"
    upstream_gcm._PATHS["dowhy.gcm.independence_test"] = "gcm/independence_test/__init__.py"
    upstream_gcm._PATHS["dowhy.gcm.independence_test.kernel"] = "gcm/independence_test/kernel.py"
    upstream_gcm._PATHS["dowhy.gcm.independence_test.kernel_operation"] = "gcm/independence_test/kernel_operation.py"
    upstream_gcm._PATHS["dowhy.gcm.fitting_sampling"] = "gcm/fitting_sampling.py"
    upstream_gcm._PATHS["dowhy.causal_graph"] = "causal_graph.py"
    upstream_gcm._PATHS["dowhy.causal_model"] = "causal_model.py"


def expose_upstream_packages() -> None:
    """Points the stubbed packages at the real directories of the upstream.

    The loader stubs the packages of the upstream out, so that the modules of
    `dowhy.gcm` can be read without the `causallearn` dependency of the real
    package. The constructor of `InvertibleStructuralCausalModel` imports
    `dowhy.causal_graph` and `dowhy.causal_model`, which the stubbed packages
    do not reach, so their paths are set to the directories of the upstream.
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


def frame_of(fixtures: dict[str, np.ndarray], name: str) -> pd.DataFrame:
    """The frame of a fixture, with the columns `X`, `Y` and `Z`."""
    data = fixtures[name]
    if data.shape[0] != NUM_ROWS:
        raise RuntimeError(f"the fixture {name} does not have {NUM_ROWS} rows")
    return pd.DataFrame(data, columns=["X", "Y", "Z"])


def upstream_non_linear_data(num_rows: int) -> pd.DataFrame:
    """The non-linear data of the upstream test file.

    This is the `_generate_simple_non_linear_data` of the upstream test file
    `tests/gcm/test_validation.py`, with the draws of the global generator of
    numpy replaced by the draws of a fixed seed, so that the printed numbers
    are reproducible.
    """
    np.random.seed(SEED)
    x = np.random.normal(loc=0, scale=1, size=num_rows)
    y = x**2 + np.random.normal(loc=0, scale=1, size=num_rows)
    z = np.exp(-y) + np.random.normal(loc=0, scale=1, size=num_rows)
    return pd.DataFrame(data=dict(X=x, Y=y, Z=z))


def print_validation_summary(summary: dict) -> None:
    """Prints the summary of the upstream validation of a causal structure.

    The summary holds, for every node of the graph, the result of the local
    Markov test and the result of the edge dependence test of every parent of
    the node. A test that the upstream did not run has an empty result.
    """
    for node, node_summary in summary.items():
        print(f"  node {node}")
        local_markov_test = node_summary["local_markov_test"]
        if not local_markov_test:
            print("    local_markov_test = none")
        else:
            print("    local_markov_test")
            show("p_value", local_markov_test["p_value"], indent=6)
            show("fdr_adjusted_p_value", local_markov_test["fdr_adjusted_p_value"], indent=6)
            print(f"      success = {bool(local_markov_test['success'])}")
        edge_dependence_test = node_summary["edge_dependence_test"]
        if not edge_dependence_test:
            print("    edge_dependence_test = none")
        else:
            print("    edge_dependence_test")
            for parent, parent_summary in edge_dependence_test.items():
                print(f"      parent {parent}")
                show("p_value", parent_summary["p_value"], indent=8)
                show("fdr_adjusted_p_value", parent_summary["fdr_adjusted_p_value"], indent=8)
                print(f"        success = {bool(parent_summary['success'])}")


def invertible_model_p_values(model, data: pd.DataFrame, kernel_based, graph) -> dict:
    """The p-values the upstream computes inside `refute_invertible_model`.

    The upstream does not return them, but it computes one p-value for every
    node with a parent: the p-value of the independence test of the parents of
    the node and of the noise that the causal mechanism of the node estimates
    from the data.
    """
    values = {}
    for node in model.graph.nodes:
        parents = graph.get_ordered_predecessors(model.graph, node)
        if not parents:
            continue
        parents_samples = data[parents].to_numpy()
        residuals = model.causal_mechanism(node).estimate_noise(data[node].to_numpy(), parents_samples)
        values[node] = kernel_based(parents_samples, residuals)
    return values


def print_invertible_model_outcome(
    label: str, models, auto, fitting, validation, kernel_based, graph, data: pd.DataFrame, edges
) -> None:
    """Validates the invertible model of the given graph and prints the outcome.

    The causal mechanisms are assigned by the upstream
    `assign_causal_mechanisms` with the quality `GOOD`, and then the model is
    fitted with the upstream `fit`, the way the upstream test file does it.
    """
    np.random.seed(SEED)
    model = models.InvertibleStructuralCausalModel(nx.DiGraph(list(edges)))
    auto.assign_causal_mechanisms(model, data, auto.AssignmentQuality.GOOD)
    fitting.fit(model, data)

    np.random.seed(SEED)
    outcome = validation.refute_invertible_model(model, data)
    print(f"  graph {label}")
    print(f"    outcome = {outcome.name}")

    np.random.seed(SEED)
    for node, p_value in invertible_model_p_values(model, data, kernel_based, graph).items():
        print(f"    node {node}")
        show("p_value", p_value, indent=6)


def main() -> None:
    register_missing_modules()

    config = load("dowhy.gcm.config")
    # The progress bars of the upstream fitting would write to the standard
    # error stream and clutter the output of the reference.
    config.disable_progress_bars()
    # The automatic assignment of the causal mechanisms evaluates the candidate
    # models with joblib, which distributes them over the worker processes by
    # default. The worker processes cannot import the stubbed `dowhy` package
    # of the loader, so the models are evaluated in this process instead.
    config.set_default_n_jobs(1)

    # The `ml` package has to come first: the loader stubs the packages out, so
    # the `causal_mechanisms` module needs the prediction models already.
    load("dowhy.gcm.ml")
    load("dowhy.gcm.ml.regression")
    load("dowhy.gcm.causal_mechanisms")
    models = load("dowhy.gcm.causal_models")
    load("dowhy.gcm.stochastic_models")
    fitting = load("dowhy.gcm.fitting_sampling")
    auto = load("dowhy.gcm.auto")
    independence = load("dowhy.gcm.independence_test")
    validation = load("dowhy.gcm.validation")
    graph = load("dowhy.graph")
    # The constructor of `InvertibleStructuralCausalModel` imports the two
    # modules of the wider package, which the stubbed packages do not reach.
    expose_upstream_packages()
    load("dowhy.causal_graph")
    load("dowhy.causal_model")

    kernel_based = independence.kernel_based

    fixtures = gen_validation_testdata.build_fixtures()

    print(f"SEED = {SEED}")
    print(f"NUM_ROWS = {NUM_ROWS}")
    print(f"NUM_ROWS_UPSTREAM = {NUM_ROWS_UPSTREAM}")

    # ------------------------------------------------------------------
    # A. The validation of the causal structure of the four graph fixtures.
    #
    # The upstream test file `tests/gcm/test_validation.py` expects a
    # `NOT_REJECTED` for every one of them.
    # ------------------------------------------------------------------
    for name, edges in GRAPH_FIXTURES.items():
        np.random.seed(SEED)
        data = frame_of(fixtures, name)
        outcome, summary = validation.refute_causal_structure(nx.DiGraph(list(edges)), data)
        print(f"REFUTE_CAUSAL_STRUCTURE {name}")
        print(f"  outcome = {outcome.name}")
        print_validation_summary(summary)

    # ------------------------------------------------------------------
    # B. The validation of the invertible model on the non-linear data of
    # the upstream test file.
    #
    # The upstream test file expects a `NOT_REJECTED` for the correct graph
    # and a `REJECTED` for the two wrong ones.
    # ------------------------------------------------------------------
    print("REFUTE_INVERTIBLE_MODEL upstream_data")
    upstream_data = upstream_non_linear_data(NUM_ROWS_UPSTREAM)
    for label, edges in INVERTIBLE_GRAPHS.items():
        print_invertible_model_outcome(
            label, models, auto, fitting, validation, kernel_based, graph, upstream_data, edges
        )

    # ------------------------------------------------------------------
    # C. The validation of the invertible model on the non-linear fixture.
    #
    # The outcome of the validation of the invertible model depends on the
    # number of rows: the sixty rows of the fixture are too few for the
    # upstream to tell the signal from the noise, so the outcomes differ from
    # the ones of the data of the upstream test file. The p-values below are
    # the ones the upstream computes.
    # ------------------------------------------------------------------
    print("REFUTE_INVERTIBLE_MODEL nonlinear_fixture")
    print("  note the outcome depends on the number of rows: the sixty rows of the")
    print("       fixture are too few for the upstream to tell the signal from the")
    print("       noise, so the outcomes differ from the ones of the data of the")
    print("       upstream test file above")
    fixture_data = frame_of(fixtures, "nonlinear")
    for label, edges in INVERTIBLE_GRAPHS.items():
        print_invertible_model_outcome(
            label, models, auto, fitting, validation, kernel_based, graph, fixture_data, edges
        )

    # ------------------------------------------------------------------
    # D. The p-values of the kernel based independence test of every pair of
    # every fixture, with and without a conditioning variable.
    # ------------------------------------------------------------------
    for name in ("collider", "chain", "fork", "general", "nonlinear"):
        np.random.seed(SEED)
        data = frame_of(fixtures, name)
        x = data["X"].to_numpy()
        y = data["Y"].to_numpy()
        z = data["Z"].to_numpy()
        print(f"KERNEL_BASED_TEST {name}")
        show("p(X,Y)", kernel_based(x, y))
        show("p(X,Z)", kernel_based(x, z))
        show("p(Y,Z)", kernel_based(y, z))
        show("p(X,Y|Z)", kernel_based(x, y, z))
        show("p(X,Z|Y)", kernel_based(x, z, y))
        show("p(Y,Z|X)", kernel_based(y, z, x))


if __name__ == "__main__":
    main()
