"""The reference numbers of the equation parser of the `gcm` package.

The script runs the upstream `dowhy.gcm.equation_parser` on the very equations
the MoonBit port works on, and prints the graph of the model it builds, the
parents of every node and the predictions of the custom function of a node, so
that the two can be compared.

The upstream evaluates the custom function with the `eval` of Python over the
arrays of the parents; the port parses the expression and evaluates it over the
rows of the design matrix. The numbers are the same, because the two compute
the same arithmetic.

Usage:
    python _verify/gcm_equation_parser_reference.py
"""

from __future__ import annotations

import os
import sys
import types

import networkx as nx
import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import upstream_gcm  # noqa: E402
from upstream_gcm import load  # noqa: E402

# The loader of `upstream_gcm.py` owns the list of the modules it reads, but it
# does not know the modules this script needs, so its list is only extended
# here.
upstream_gcm._PATHS["dowhy.gcm.equation_parser"] = "gcm/equation_parser.py"

# The equations of the chain of the fixture.
CHAIN = """
X0 = norm(loc=0,scale=0.1)
X1 = 2*X0 + norm(loc=0, scale=0.1)
X2 = 0.5*X0 + norm(loc=0, scale=0.1)
X3 = 0.5*X2 + norm(loc=0, scale=0.1)
"""

# The equations with a node whose relation to its parents is unknown.
UNKNOWN = """
A = norm(loc=0,scale=0.1)
B = norm(loc=0, scale=0.1)
Y = 0.5*B + 2*A+ norm(loc=0, scale=0.1)
Z->Y,A
C = exp(A) + 5 * Z + parametric()
"""

# The design matrix the predictions of the custom function are computed on.
DESIGN = np.array([[1.0, 4.0], [2.0, 5.0], [3.0, 6.0]])


def stub_causal_model() -> None:
    """Stubs the upstream `dowhy.causal_model` with a placeholder class.

    The constructor of `StructuralCausalModel` imports the module and uses its
    `CausalModel` class for an `isinstance` check of the graph it is given. The
    graph of the reference is a `networkx` graph, so the check is false with
    the placeholder class as well. The real module is not loaded, because it
    pulls in the whole graph learning stack of the upstream.
    """
    module = types.ModuleType("dowhy.causal_model")

    class CausalModel:  # noqa: D101
        """The placeholder of the class the upstream checks the graph against."""

    module.CausalModel = CausalModel  # type: ignore[attr-defined]
    sys.modules["dowhy.causal_model"] = module


def expose_upstream_packages() -> None:
    """Points the stubbed packages at the real directories of the upstream.

    The loader stubs the packages of the upstream out, so that the modules of
    `dowhy.gcm` can be read without the `causallearn` dependency of the real
    package. The constructor of `StructuralCausalModel` imports
    `dowhy.causal_graph`, which the stubbed packages do not reach, so their
    paths are set to the directories of the upstream.
    """
    root = upstream_gcm.upstream_root()
    for name, relative in (
        ("dowhy", "dowhy"),
        ("dowhy.gcm", os.path.join("dowhy", "gcm")),
        ("dowhy.gcm.util", os.path.join("dowhy", "gcm", "util")),
        ("dowhy.utils", os.path.join("dowhy", "utils")),
    ):
        sys.modules[name].__path__ = [str(root / relative)]


def load_parser():
    """Loads the upstream equation parser with the names it needs."""
    # The upstream `dowhy.gcm.ml` has to be read before the modules that import
    # the names it re-exports, so it is loaded first.
    load("dowhy.gcm.ml")
    load("dowhy.gcm.ml.regression")
    mechanisms = load("dowhy.gcm.causal_mechanisms")
    stochastic = load("dowhy.gcm.stochastic_models")
    models = load("dowhy.gcm.causal_models")
    # The upstream module `dowhy.gcm.equation_parser` imports the names it
    # needs from the package `dowhy.gcm`, which the loader stubs out, so the
    # stub has to carry them before the module is read.
    package = sys.modules["dowhy.gcm"]
    package.AdditiveNoiseModel = mechanisms.AdditiveNoiseModel
    package.EmpiricalDistribution = stochastic.EmpiricalDistribution
    package.ScipyDistribution = stochastic.ScipyDistribution
    package.StructuralCausalModel = models.StructuralCausalModel
    expose_upstream_packages()
    upstream_gcm._PATHS["dowhy.causal_graph"] = "causal_graph.py"
    upstream_gcm._PATHS["dowhy.causal_model"] = "causal_model.py"
    load("dowhy.causal_graph")
    stub_causal_model()
    return load("dowhy.gcm.equation_parser")


def print_model(name, causal_model):
    """Prints the graph of a model and the parents of every node."""
    print(name)
    nodes = sorted(causal_model.graph.nodes)
    print("  nodes = " + str(nodes))
    edges = sorted(
        (str(source), str(target)) for source, target in causal_model.graph.edges
    )
    print("  edges = " + str(edges))
    for node in nodes:
        parents = sorted(causal_model.graph.predecessors(node))
        print(f"  parents[{node}] = {parents}")


def main() -> None:
    parser = load_parser()

    chain = parser.create_causal_model_from_equations(CHAIN)
    print_model("CHAIN", chain)
    predictions = chain.causal_mechanism("X1")._prediction_model.predict(
        DESIGN[:, 0:1]
    ).ravel()
    print("  predictions[X1] = " + str([round(float(value), 12) for value in predictions]))

    unknown = parser.create_causal_model_from_equations(UNKNOWN)
    print_model("UNKNOWN", unknown)
    # The node with the unknown relation has no causal mechanism, and the
    # upstream raises an error when it is asked for one.
    try:
        mechanism = unknown.causal_mechanism("Z")
    except KeyError:
        mechanism = "undefined"
    print("  mechanism[Z] = " + str(mechanism))
    print(
        "  mechanism[C] = "
        + str(type(unknown.causal_mechanism("C")).__name__)
    )
    predictions = unknown.causal_mechanism("Y")._prediction_model.predict(DESIGN).ravel()
    print("  predictions[Y] = " + str([round(float(value), 12) for value in predictions]))


if __name__ == "__main__":
    main()
