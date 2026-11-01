"""The reference numbers of the noise of the `gcm` package.

The script runs the upstream `dowhy.gcm._noise` on the very rows the MoonBit
port works on, and prints the numbers the port has to reproduce. The rows are
generated with a Python replica of the xorshift generator of
`src/utils/random.mbt`, so the two sides work on the same rows.

Two fixtures are used:

  * the fixture of the upstream test `tests/gcm/test_noise.py`, whose graph is
    `X0 -> X1`, `X0 -> X2` and `X2 -> X3`, so that every node has at most one
    parent;
  * a fixture with a node that has two parents, whose edges are added in an
    order that is not the sorted one. The upstream takes the parents of a node
    in the sorted order (`dowhy.graph.get_ordered_predecessors`), so the
    coefficients of the node belong to the sorted parents and not to the
    parents in the order of the edges.

The upstream `get_noise_dependent_function` is not part of the port, so the
four tests of the upstream that use it have no counterpart here.

Usage:
    python _verify/gcm_noise_reference.py
"""

from __future__ import annotations

import os
import sys

import networkx as nx
import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import upstream_gcm  # noqa: E402
from upstream_gcm import load, upstream_root  # noqa: E402

MASK64 = (1 << 64) - 1


def expose_upstream_packages() -> None:
    """Points the stubbed packages at the real directories of the upstream.

    The loader stubs the packages of the upstream out, so that the modules of
    `dowhy.gcm` can be read without the `causallearn` dependency of the real
    package. The constructor of `StructuralCausalModel` imports
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


class Xorshift:
    """The generator of `src/utils/random.mbt`."""

    def __init__(self, seed: int) -> None:
        self.state = seed if seed != 0 else 0x9E3779B97F4A7C15

    def next_u64(self) -> int:
        x = self.state
        x ^= (x << 13) & MASK64
        x ^= x >> 7
        x ^= (x << 17) & MASK64
        self.state = x
        return x

    def next_double(self) -> float:
        return (self.next_u64() >> 11) / 9007199254740992.0

    def next_normal(self) -> float:
        u1 = self.next_double()
        u2 = self.next_double()
        u1 = 1.0e-12 if u1 < 1.0e-12 else u1
        return np.sqrt(-2.0 * np.log(u1)) * np.cos(2.0 * np.pi * u2)


# The loader of `upstream_gcm.py` owns the list of the modules it reads, but it
# does not know the module of the noise, so its list is only extended here.
upstream_gcm._PATHS["dowhy.gcm._noise"] = "gcm/_noise.py"
upstream_gcm._PATHS["dowhy.causal_graph"] = "causal_graph.py"
upstream_gcm._PATHS["dowhy.causal_model"] = "causal_model.py"

# The seed of the fixtures, the same as the one of the MoonBit tests.
SEED = 2040

# The number of rows of the fixtures.
ROWS = 1000

# The size of the noise of the fixtures.
NOISE_SCALE = 0.1


def noise_rows() -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """The noise of the fixture of the upstream test."""
    rng = Xorshift(SEED)
    n0 = np.array([2.0 * rng.next_double() - 1.0 for _ in range(ROWS)])
    n1 = np.array([NOISE_SCALE * rng.next_normal() for _ in range(ROWS)])
    n2 = np.array([NOISE_SCALE * rng.next_normal() for _ in range(ROWS)])
    n3 = np.array([NOISE_SCALE * rng.next_normal() for _ in range(ROWS)])
    return n0, n1, n2, n3


def data_rows(n0: np.ndarray, n1: np.ndarray, n2: np.ndarray, n3: np.ndarray) -> dict[str, np.ndarray]:
    """The data of the fixture of the upstream test."""
    x0 = n0
    x1 = 2.0 * x0 + n1
    x2 = 0.5 * x0 + n2
    x3 = 0.5 * x2 + n3
    return {"X0": x0, "X1": x1, "X2": x2, "X3": x3}


def two_parent_rows() -> tuple[dict[str, np.ndarray], dict[str, np.ndarray]]:
    """The noise and the data of the fixture with two parents.

    The node `X3` has the parents `X2` and `X1`, and the edges are added in
    the order that puts `X2` first, so that the parents of the node in the
    order of the edges are not the sorted ones.
    """
    n0, n1, n2, n3 = noise_rows()
    x0 = n0
    x1 = 2.0 * x0 + n1
    x2 = 0.5 * x0 + n2
    x3 = 2.0 * x1 + 3.0 * x2 + n3
    noise = {"X0": n0, "X1": n1, "X2": n2, "X3": n3}
    data = {"X0": x0, "X1": x1, "X2": x2, "X3": x3}
    return noise, data


def persist_parents(models, graph) -> None:
    """Persists the parents of every node, like the upstream test does.

    The upstream `validate_causal_dag` checks that the mechanism of every node
    was fitted to the parents the graph has, and the upstream test stores them
    with its `_persist_parents` helper before it computes the noise.
    """
    from dowhy.graph import get_ordered_predecessors

    for node in graph.nodes:
        graph.nodes[node][models.PARENTS_DURING_FIT] = get_ordered_predecessors(graph, node)


def build_model(models, mechanisms, stochastic, regression, graph, x3_coefficients) -> object:
    """The upstream model of the fixture."""
    causal_model = models.StructuralCausalModel(graph)
    persist_parents(models, graph)
    causal_model.set_causal_mechanism("X0", stochastic.EmpiricalDistribution())
    causal_model.set_causal_mechanism(
        "X1",
        mechanisms.AdditiveNoiseModel(
            prediction_model=regression.create_linear_regressor_with_given_parameters(np.array([2.0]))
        ),
    )
    causal_model.set_causal_mechanism(
        "X2",
        mechanisms.AdditiveNoiseModel(
            prediction_model=regression.create_linear_regressor_with_given_parameters(np.array([0.5]))
        ),
    )
    causal_model.set_causal_mechanism(
        "X3",
        mechanisms.AdditiveNoiseModel(
            prediction_model=regression.create_linear_regressor_with_given_parameters(np.array(x3_coefficients))
        ),
    )
    return causal_model


def deviation(left: np.ndarray, right: np.ndarray) -> float:
    """The largest difference between two sets of rows."""
    return float(np.max(np.abs(np.asarray(left, dtype=float) - np.asarray(right, dtype=float))))


def main() -> None:
    # The upstream `dowhy.gcm.ml` has to be read before the modules that import
    # the names it re-exports, so it is loaded first.
    load("dowhy.gcm.ml")
    models = load("dowhy.gcm.causal_models")
    mechanisms = load("dowhy.gcm.causal_mechanisms")
    stochastic = load("dowhy.gcm.stochastic_models")
    noise = load("dowhy.gcm._noise")
    regression = load("dowhy.gcm.ml.regression")
    # The constructor of `StructuralCausalModel` imports the two modules of the
    # wider package, which the stubbed packages do not reach.
    expose_upstream_packages()
    load("dowhy.causal_graph")
    load("dowhy.causal_model")

    # ------------------------------------------------------------------
    # A. The fixture of the upstream test.
    # ------------------------------------------------------------------
    n0, n1, n2, n3 = noise_rows()
    expected_data = data_rows(n0, n1, n2, n3)
    expected_noise = {"X0": n0, "X1": n1, "X2": n2, "X3": n3}

    graph = nx.DiGraph([("X0", "X1"), ("X0", "X2"), ("X2", "X3")])
    causal_model = build_model(models, mechanisms, stochastic, regression, graph, [0.5])

    computed_data = noise.compute_data_from_noise(
        causal_model, pd.DataFrame({name: values for name, values in expected_noise.items()})
    )
    print("DATA_FROM_NOISE")
    for name in ("X0", "X1", "X2", "X3"):
        print(f"  {name} = {computed_data[name].to_numpy().squeeze()[0]:.12f}")
    print(f"  max_deviation = {max(deviation(computed_data[name].to_numpy().squeeze(), expected_data[name]) for name in expected_data):.3e}")

    computed_noise = noise.compute_noise_from_data(
        causal_model, pd.DataFrame({name: values for name, values in expected_data.items()})
    )
    print("NOISE_FROM_DATA")
    for name in ("X0", "X1", "X2", "X3"):
        print(f"  {name} = {computed_noise[name].to_numpy().squeeze()[0]:.12f}")
    print(f"  max_deviation = {max(deviation(computed_noise[name].to_numpy().squeeze(), expected_noise[name]) for name in expected_noise):.3e}")

    # ------------------------------------------------------------------
    # B. The fixture whose node has two parents.
    # ------------------------------------------------------------------
    two_parent_noise, two_parent_data = two_parent_rows()
    graph = nx.DiGraph([("X0", "X1"), ("X0", "X2"), ("X2", "X3"), ("X1", "X3")])
    causal_model = build_model(models, mechanisms, stochastic, regression, graph, [2.0, 3.0])

    computed_data = noise.compute_data_from_noise(
        causal_model, pd.DataFrame({name: values for name, values in two_parent_noise.items()})
    )
    print("DATA_FROM_NOISE_TWO_PARENTS")
    for name in ("X0", "X1", "X2", "X3"):
        print(f"  {name} = {computed_data[name].to_numpy().squeeze()[0]:.12f}")
    print(f"  max_deviation = {max(deviation(computed_data[name].to_numpy().squeeze(), two_parent_data[name]) for name in two_parent_data):.3e}")

    computed_noise = noise.compute_noise_from_data(
        causal_model, pd.DataFrame({name: values for name, values in two_parent_data.items()})
    )
    print("NOISE_FROM_DATA_TWO_PARENTS")
    for name in ("X0", "X1", "X2", "X3"):
        print(f"  {name} = {computed_noise[name].to_numpy().squeeze()[0]:.12f}")
    print(f"  max_deviation = {max(deviation(computed_noise[name].to_numpy().squeeze(), two_parent_noise[name]) for name in two_parent_noise):.3e}")


if __name__ == "__main__":
    main()
