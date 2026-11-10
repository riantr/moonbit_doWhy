"""The reference numbers of the intrinsic causal influence of the `gcm` package.

The script runs the upstream `dowhy.gcm.influence` on the very rows the MoonBit
port works on, and prints the contributions the port has to reproduce. The rows
are generated with a Python replica of the xorshift generator of
`src/utils/random.mbt`, so the two sides work on the same rows.

The upstream draws its noise samples with the global generator of numpy, so
the contributions it computes and the contributions the port computes are
different numbers. What the two share is the property the upstream test
asserts: the contribution of a node is the variance of the noise of that node.

The predictions of a classifier are a probability per class, so the port
measures the contribution of a categorical target with the drop of the entropy
of the target, the way the upstream does.

Usage:
    python _verify/gcm_intrinsic_influence_reference.py
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
from upstream_gcm import load, upstream_root  # noqa: E402

MASK64 = (1 << 64) - 1


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

    def next_int(self, bound: int) -> int:
        if bound <= 0:
            return 0
        return self.next_u64() % bound


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


# The loader of `upstream_gcm.py` owns the list of the modules it reads, but it
# does not know the modules this script needs, so its list is only extended
# here.
upstream_gcm._PATHS["dowhy.gcm.fitting_sampling"] = "gcm/fitting_sampling.py"
upstream_gcm._PATHS["dowhy.gcm.feature_relevance"] = "gcm/feature_relevance.py"
upstream_gcm._PATHS["dowhy.gcm.influence"] = "gcm/influence.py"
upstream_gcm._PATHS["dowhy.gcm._noise"] = "gcm/_noise.py"
upstream_gcm._PATHS["dowhy.gcm.uncertainty"] = "gcm/uncertainty.py"
upstream_gcm._PATHS["dowhy.causal_graph"] = "causal_graph.py"
upstream_gcm._PATHS["dowhy.causal_model"] = "causal_model.py"

# The seed of the fixture, the same as the one of the MoonBit test.
SEED = 2060

# The seed of the categorical fixture, the same as the one of the MoonBit test.
CATEGORICAL_SEED = 2061

# The seed of the complex categorical fixture, the same as the one of the
# MoonBit test.
COMPLEX_CATEGORICAL_SEED = 2062

# The seed of the fixture of the fully categorical influence, the same as the
# one of the MoonBit test.
ONLY_CATEGORICAL_SEED = 2063

# The number of rows of the fixture.
ROWS = 1000

# The number of the samples the noise terms are randomized with.
RANDOMIZATION_SAMPLES = 250

# The number of the samples of the baseline.
BASELINE_SAMPLES = 500


def fixture() -> pd.DataFrame:
    """The data of the fixture of the intrinsic causal influence."""
    rng = Xorshift(SEED)
    x0 = np.array([rng.next_normal() for _ in range(ROWS)])
    x1 = np.array([x0[i] + 0.001 * rng.next_normal() for i in range(ROWS)])
    x2 = np.array([x1[i] + 2.0 * rng.next_normal() for i in range(ROWS)])
    x3 = np.array([x2[i] + rng.next_normal() for i in range(ROWS)])
    return pd.DataFrame({"X0": x0, "X1": x1, "X2": x2, "X3": x3})


def categorical_fixture() -> pd.DataFrame:
    """The data of the fixture of the categorical intrinsic causal influence.

    The fixture is the one of the upstream test file
    `tests/gcm/test_intrinsic_influence.py` in the case
    `test_given_categorical_data_when_estimate_intrinsic_causal_influence_then_returns_expected_results`:
    the target is the sign of the value of its parent plus its noise.
    """
    rng = Xorshift(CATEGORICAL_SEED)
    x0 = np.array([rng.next_normal() for _ in range(ROWS)])
    x1 = np.array([x0[i] + 0.001 * rng.next_normal() for i in range(ROWS)])
    x2 = np.array([x1[i] + 2.0 * rng.next_normal() for i in range(ROWS)])
    x3 = np.array([(x2[i] + rng.next_normal()) >= 0.0 for i in range(ROWS)])
    return pd.DataFrame({"X0": x0, "X1": x1, "X2": x2, "X3": x3.astype(str)})


def complex_categorical_fixture() -> pd.DataFrame:
    """The data of the fixture of the complex categorical influence.

    The fixture is the one of the upstream test file
    `tests/gcm/test_intrinsic_influence.py` in the case
    `test_given_more_complex_categorical_data_when_estimate_intrinsic_causal_influence_then_returns_expected_results`:
    the target is a mixture of three shifted Gaussians, cut at its median.
    """
    rng = Xorshift(COMPLEX_CATEGORICAL_SEED)
    x0 = np.array([rng.next_normal() for _ in range(ROWS)])
    x1 = np.array([x0[i] + 0.001 * rng.next_normal() for i in range(ROWS)])
    x2 = np.array([x1[i] + 2.0 * rng.next_normal() for i in range(ROWS)])
    values = []
    for i in range(ROWS):
        choice = rng.next_int(3)
        offset = -5.0 if choice == 0 else (10.0 if choice == 1 else 5.0)
        values.append(x2[i] + offset + 0.5 * rng.next_normal())
    median = float(np.median(values))
    x3 = np.array([value > median for value in values]).astype(str)
    return pd.DataFrame({"X0": x0, "X1": x1, "X2": x2, "X3": x3})


def only_categorical_fixture() -> pd.DataFrame:
    """The data of the fixture of the fully categorical influence.

    The fixture is the one of the upstream test file
    `tests/gcm/test_intrinsic_influence.py` in the case
    `test_given_only_categorical_data_when_estimate_icc_then_does_not_fail`:
    every node of the graph holds a category, and the category of a node is the
    sign of the value of the node.
    """
    rng = Xorshift(ONLY_CATEGORICAL_SEED)
    x0 = np.array([rng.next_normal() for _ in range(ROWS)])
    x1 = np.array([x0[i] + 0.001 * rng.next_normal() for i in range(ROWS)])
    x2 = np.array([x1[i] + 2.0 * rng.next_normal() for i in range(ROWS)])
    x3 = np.array([(x2[i] + rng.next_normal()) >= 0.0 for i in range(ROWS)])
    return pd.DataFrame(
        {
            "X0": (x0 >= 0.0).astype(str),
            "X1": (x1 >= 0.0).astype(str),
            "X2": (x2 >= 0.0).astype(str),
            "X3": x3.astype(str),
        }
    )


def main() -> None:
    # The upstream `dowhy.gcm.ml` has to be read before the modules that import
    # the names it re-exports, so it is loaded first.
    load("dowhy.gcm.ml")
    load("dowhy.gcm.ml.regression")
    config = load("dowhy.gcm.config")
    # The workers of the process pool of the upstream cannot import the stubbed
    # packages, so the number of the jobs has to be one.
    config.set_default_n_jobs(1)
    models = load("dowhy.gcm.causal_models")
    fitting = load("dowhy.gcm.fitting_sampling")
    auto = load("dowhy.gcm.auto")
    relevance = load("dowhy.gcm.feature_relevance")
    # The upstream module `dowhy.gcm.influence` imports the names it needs
    # from the package `dowhy.gcm`, which the loader stubs out, so the stub
    # has to carry them before the module is read.
    gcm_package = sys.modules["dowhy.gcm"]
    gcm_package.feature_relevance_sample = relevance.feature_relevance_sample
    gcm_package.feature_relevance_distribution = relevance.feature_relevance_distribution
    gcm_package.parent_relevance = relevance.parent_relevance
    influence = load("dowhy.gcm.influence")
    shapley = load("dowhy.gcm.shapley")
    expose_upstream_packages()
    load("dowhy.causal_graph")
    stub_causal_model()

    data = fixture()
    causal_model = models.StructuralCausalModel(
        nx.DiGraph([("X0", "X1"), ("X1", "X2"), ("X2", "X3")])
    )
    # The assignment of the mechanisms selects a model with a cross validation,
    # which splits the data with the global generator of numpy, so the seed has
    # to be set before the model is fitted. Otherwise the numbers of the script
    # differ from one run to the next.
    np.random.seed(SEED)
    auto.assign_causal_mechanisms(causal_model, data, auto.AssignmentQuality.GOOD)
    fitting.fit(causal_model, data)

    np.random.seed(SEED)
    contributions = influence.intrinsic_causal_influence(
        causal_model,
        "X3",
        prediction_model="exact",
        num_samples_randomization=RANDOMIZATION_SAMPLES,
        num_samples_baseline=BASELINE_SAMPLES,
        shapley_config=shapley.ShapleyConfig(n_jobs=1),
    )
    print("INTRINSIC_CAUSAL_INFLUENCE")
    for key in ("X0", "X1", "X2", "X3"):
        print(f"  {key} = {contributions[key]:.12f}")
    print(f"  sum = {sum(contributions[key] for key in contributions):.12f}")
    print(f"  variance = {np.var(data['X3'].to_numpy()):.12f}")

    np.random.seed(SEED)
    contributions_approx = influence.intrinsic_causal_influence(
        causal_model,
        "X3",
        prediction_model="approx",
        num_samples_randomization=RANDOMIZATION_SAMPLES,
        num_samples_baseline=BASELINE_SAMPLES,
        shapley_config=shapley.ShapleyConfig(n_jobs=1),
    )
    print("INTRINSIC_CAUSAL_INFLUENCE_APPROX")
    for key in ("X0", "X1", "X2", "X3"):
        print(f"  {key} = {contributions_approx[key]:.12f}")
    print(f"  sum = {sum(contributions_approx[key] for key in contributions_approx):.12f}")

    # The influence of a categorical target, which is the drop of the entropy of
    # the target.
    categorical_data = categorical_fixture()
    categorical_model = models.StructuralCausalModel(
        nx.DiGraph([("X0", "X1"), ("X1", "X2"), ("X2", "X3")])
    )
    np.random.seed(CATEGORICAL_SEED)
    auto.assign_causal_mechanisms(
        categorical_model, categorical_data, auto.AssignmentQuality.GOOD
    )
    fitting.fit(categorical_model, categorical_data)

    np.random.seed(CATEGORICAL_SEED)
    categorical_contributions = influence.intrinsic_causal_influence(
        categorical_model,
        "X3",
        prediction_model="exact",
        num_samples_randomization=RANDOMIZATION_SAMPLES,
        num_samples_baseline=BASELINE_SAMPLES,
        shapley_config=shapley.ShapleyConfig(n_jobs=1),
    )
    print("INTRINSIC_CAUSAL_INFLUENCE_CATEGORICAL")
    for key in ("X0", "X1", "X2", "X3"):
        print(f"  {key} = {categorical_contributions[key]:.12f}")
    print(
        f"  sum = {sum(categorical_contributions[key] for key in categorical_contributions):.12f}"
    )

    np.random.seed(CATEGORICAL_SEED)
    categorical_contributions_approx = influence.intrinsic_causal_influence(
        categorical_model,
        "X3",
        prediction_model="approx",
        num_samples_randomization=RANDOMIZATION_SAMPLES,
        num_samples_baseline=BASELINE_SAMPLES,
        shapley_config=shapley.ShapleyConfig(n_jobs=1),
    )
    print("INTRINSIC_CAUSAL_INFLUENCE_CATEGORICAL_APPROX")
    for key in ("X0", "X1", "X2", "X3"):
        print(f"  {key} = {categorical_contributions_approx[key]:.12f}")
    print(
        f"  sum = {sum(categorical_contributions_approx[key] for key in categorical_contributions_approx):.12f}"
    )

    # The influence of a categorical target whose relation is a mixture.
    complex_data = complex_categorical_fixture()
    complex_model = models.StructuralCausalModel(
        nx.DiGraph([("X0", "X1"), ("X1", "X2"), ("X2", "X3")])
    )
    np.random.seed(COMPLEX_CATEGORICAL_SEED)
    auto.assign_causal_mechanisms(
        complex_model, complex_data, auto.AssignmentQuality.GOOD
    )
    fitting.fit(complex_model, complex_data)

    np.random.seed(COMPLEX_CATEGORICAL_SEED)
    complex_contributions = influence.intrinsic_causal_influence(
        complex_model,
        "X3",
        prediction_model="exact",
        num_samples_randomization=RANDOMIZATION_SAMPLES,
        num_samples_baseline=BASELINE_SAMPLES,
        shapley_config=shapley.ShapleyConfig(n_jobs=1),
    )
    print("INTRINSIC_CAUSAL_INFLUENCE_COMPLEX_CATEGORICAL")
    for key in ("X0", "X1", "X2", "X3"):
        print(f"  {key} = {complex_contributions[key]:.12f}")
    print(
        f"  sum = {sum(complex_contributions[key] for key in complex_contributions):.12f}"
    )

    np.random.seed(COMPLEX_CATEGORICAL_SEED)
    complex_contributions_approx = influence.intrinsic_causal_influence(
        complex_model,
        "X3",
        prediction_model="approx",
        num_samples_randomization=RANDOMIZATION_SAMPLES,
        num_samples_baseline=BASELINE_SAMPLES,
        shapley_config=shapley.ShapleyConfig(n_jobs=1),
    )
    print("INTRINSIC_CAUSAL_INFLUENCE_COMPLEX_CATEGORICAL_APPROX")
    for key in ("X0", "X1", "X2", "X3"):
        print(f"  {key} = {complex_contributions_approx[key]:.12f}")
    print(
        f"  sum = {sum(complex_contributions_approx[key] for key in complex_contributions_approx):.12f}"
    )

    # The influence of a target whose every ancestor holds a category. The
    # noise of the root node of the model is a category, so the noise samples
    # of the ancestors hold a column of categories.
    only_data = only_categorical_fixture()
    only_model = models.StructuralCausalModel(
        nx.DiGraph([("X0", "X1"), ("X1", "X2"), ("X2", "X3")])
    )
    np.random.seed(ONLY_CATEGORICAL_SEED)
    auto.assign_causal_mechanisms(
        only_model, only_data, auto.AssignmentQuality.GOOD
    )
    fitting.fit(only_model, only_data)

    np.random.seed(ONLY_CATEGORICAL_SEED)
    only_contributions = influence.intrinsic_causal_influence(
        only_model,
        "X3",
        prediction_model="exact",
        num_samples_randomization=RANDOMIZATION_SAMPLES,
        num_samples_baseline=BASELINE_SAMPLES,
        shapley_config=shapley.ShapleyConfig(n_jobs=1),
    )
    print("INTRINSIC_CAUSAL_INFLUENCE_ONLY_CATEGORICAL")
    for key in ("X0", "X1", "X2", "X3"):
        print(f"  {key} = {only_contributions[key]:.12f}")
    print(
        f"  sum = {sum(only_contributions[key] for key in only_contributions):.12f}"
    )

    np.random.seed(ONLY_CATEGORICAL_SEED)
    only_contributions_approx = influence.intrinsic_causal_influence(
        only_model,
        "X3",
        prediction_model="approx",
        num_samples_randomization=RANDOMIZATION_SAMPLES,
        num_samples_baseline=BASELINE_SAMPLES,
        shapley_config=shapley.ShapleyConfig(n_jobs=1),
    )
    print("INTRINSIC_CAUSAL_INFLUENCE_ONLY_CATEGORICAL_APPROX")
    for key in ("X0", "X1", "X2", "X3"):
        print(f"  {key} = {only_contributions_approx[key]:.12f}")
    print(
        f"  sum = {sum(only_contributions_approx[key] for key in only_contributions_approx):.12f}"
    )

    # The sample wise influence of the linear model with the given mechanisms.
    from scipy import stats

    from dowhy.gcm.causal_mechanisms import AdditiveNoiseModel
    from dowhy.gcm.ml.regression import create_linear_regressor_with_given_parameters
    from dowhy.gcm.stochastic_models import ScipyDistribution

    sample_model = models.InvertibleStructuralCausalModel(
        nx.DiGraph([("X0", "X1"), ("X1", "X2"), ("X2", "X3")])
    )
    sample_model.set_causal_mechanism("X0", ScipyDistribution(stats.norm, loc=0, scale=1))
    for node, coefficient in (("X1", 2.0), ("X2", 1.0), ("X3", 1.0)):
        sample_model.set_causal_mechanism(
            node,
            AdditiveNoiseModel(
                prediction_model=create_linear_regressor_with_given_parameters(np.array([coefficient])),
                noise_model=ScipyDistribution(stats.norm, loc=0, scale=1),
            ),
        )
    for node in ("X0", "X1", "X2", "X3"):
        sample_model.graph.nodes[node]["parents_during_fit"] = (
            [] if node == "X0" else [f"X{int(node[1]) - 1}"]
        )
    np.random.seed(SEED)
    values = influence.intrinsic_causal_influence_sample(
        sample_model,
        "X3",
        pd.DataFrame({"X0": [0, 1], "X1": [0.5, 2.5], "X2": [1.5, 4.5], "X3": [1.5, 5.5]}),
        shapley_config=shapley.ShapleyConfig(n_jobs=1),
    )
    print("INTRINSIC_CAUSAL_INFLUENCE_SAMPLE")
    for index, row in enumerate(values):
        print(f"  sample[{index}] = {[(key, round(float(value), 12)) for key, value in row.items()]}")


if __name__ == "__main__":
    main()
