"""The reference numbers of the feature relevance of the `gcm` package.

The script runs the upstream `dowhy.gcm.feature_relevance` on the very rows
the MoonBit port works on, and prints the numbers the port has to reproduce.
The rows are generated with a Python replica of the xorshift generator of
`src/utils/random.mbt`, so the two sides work on the same rows.

The upstream draws its permutations with the global generator of numpy, so the
relevance it computes and the relevance the port computes are different
numbers. What the two share is the relation the upstream test asserts: the
relevance of an input of a linear model is its coefficient times the
difference of the sample and the mean of the column. The script prints the
relevance of the upstream and the value of that relation, so that the two can
be compared.

The case with a categorical target is the one of the upstream test
`test_when_using_parent_relevance_with_categorical_data_then_returns_correct_results`.
The upstream uses its default classifier there, which is the histogram gradient
boosting classifier, and the port uses the nearest neighbour classifier with one
neighbour, which is the model of the port that is sharp in the same way: the
class of a sample is certain, so the noise of the mechanism does not change it
and the relevance of the noise is zero. The section `PARENT_RELEVANCE_CATEGORICAL_KNN`
runs the upstream with that classifier on the very rows of the port, so that the
numbers of the two can be compared.

Usage:
    python _verify/gcm_feature_relevance_reference.py
"""

from __future__ import annotations

import os
import sys
import types

import networkx as nx
import numpy as np
import pandas as pd
from scipy import stats

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import upstream_gcm  # noqa: E402
from upstream_gcm import load, upstream_root  # noqa: E402

MASK64 = (1 << 64) - 1


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
# does not know the module of the feature relevance, so its list is only
# extended here.
upstream_gcm._PATHS["dowhy.gcm.feature_relevance"] = "gcm/feature_relevance.py"
upstream_gcm._PATHS["dowhy.gcm.fitting_sampling"] = "gcm/fitting_sampling.py"
upstream_gcm._PATHS["dowhy.causal_graph"] = "causal_graph.py"
upstream_gcm._PATHS["dowhy.causal_model"] = "causal_model.py"

# The seeds of the fixtures, the same as the ones of the MoonBit tests.
SEED = 2050
COEFFICIENT_SEED = 2051
PARENT_SEED = 2052
CATEGORICAL_SEED = 2053

# The number of rows of the fixtures.
ROWS = 200
PARENT_ROWS = 1000
CATEGORICAL_ROWS = 200

# The number of the parents of the fixture with the categorical data.
CATEGORICAL_PARENTS = 5

# The number of the inputs of the linear model.
INPUTS = 5

# The number of the samples of the baseline.
BASELINE = 20


def normal_matrix(seed: int, rows: int, columns: int) -> np.ndarray:
    """The rows of the fixture of the linear model."""
    rng = Xorshift(seed)
    return np.array([[rng.next_normal() for _ in range(columns)] for _ in range(rows)])


def coefficients(seed: int, count: int) -> np.ndarray:
    """The coefficients of the linear model."""
    rng = Xorshift(seed)
    return np.array([rng.next_int(20) - 10 for _ in range(count)], dtype=float)


def parent_data() -> pd.DataFrame:
    """The data of the fixture of the parent relevance."""
    rng = Xorshift(PARENT_SEED)
    x0 = np.array([rng.next_normal() for _ in range(PARENT_ROWS)])
    x1 = np.array([rng.next_normal() for _ in range(PARENT_ROWS)])
    x2 = 3.0 * x0 + x1
    return pd.DataFrame({"X0": x0, "X1": x1, "X2": x2})


def categorical_data() -> pd.DataFrame:
    """The data of the fixture with the categorical data.

    The parents hold a uniform distribution and the target holds the classes
    "0" and "1", the class "0" when the sum of the two first parents is larger
    than one.
    """
    rng = Xorshift(CATEGORICAL_SEED)
    columns = [
        np.array([rng.next_double() for _ in range(CATEGORICAL_ROWS)])
        for _ in range(CATEGORICAL_PARENTS)
    ]
    labels = [
        "0" if columns[0][i] + columns[1][i] > 1.0 else "1"
        for i in range(CATEGORICAL_ROWS)
    ]
    frame = {f"X{i}": columns[i] for i in range(CATEGORICAL_PARENTS)}
    frame["Y"] = np.array(labels)
    return pd.DataFrame(frame)


def main() -> None:
    stub_causal_model()
    # The upstream `dowhy.gcm.ml` has to be read before the modules that import
    # the names it re-exports, so it is loaded first.
    load("dowhy.gcm.ml")
    load("dowhy.gcm.ml.regression")
    models = load("dowhy.gcm.causal_models")
    mechanisms = load("dowhy.gcm.causal_mechanisms")
    stochastic = load("dowhy.gcm.stochastic_models")
    config = load("dowhy.gcm.config")
    # The workers of the process pool of the upstream cannot import the stubbed
    # packages, so the number of the jobs has to be one.
    config.set_default_n_jobs(1)
    fitting = load("dowhy.gcm.fitting_sampling")
    relevance = load("dowhy.gcm.feature_relevance")
    shapley = load("dowhy.gcm.shapley")
    expose_upstream_packages()
    load("dowhy.causal_graph")

    # ------------------------------------------------------------------
    # A. The relevance of the inputs of a linear model.
    # ------------------------------------------------------------------
    samples = normal_matrix(SEED, ROWS, INPUTS)
    weights = coefficients(COEFFICIENT_SEED, INPUTS)

    def model(x: np.ndarray) -> np.ndarray:
        return np.sum(weights * x, axis=1)

    np.random.seed(SEED)
    values = relevance.feature_relevance_sample(
        model,
        feature_samples=samples,
        baseline_samples=samples[:BASELINE],
        subset_scoring_func=lambda randomized, baseline: np.mean(randomized) - np.mean(baseline),
    )
    means = np.mean(samples, axis=0)
    print("FEATURE_RELEVANCE_SAMPLE")
    for i in range(3):
        print(f"  upstream[{i}] = {[float(value) for value in values[i]]}")
        print(f"  relation[{i}] = {[float(weights[j] * (samples[i, j] - means[j])) for j in range(INPUTS)]}")
    print(f"  max_difference = {np.max(np.abs(values - weights * (samples[:BASELINE] - means))):.3e}")

    # ------------------------------------------------------------------
    # B. The relevance of the parents of a node of a causal model.
    # ------------------------------------------------------------------
    data = parent_data()
    graph = nx.DiGraph([("X1", "X2"), ("X0", "X2")])
    causal_model = models.StructuralCausalModel(graph)
    causal_model.set_causal_mechanism("X0", stochastic.ScipyDistribution(stats.norm, loc=0, scale=1))
    causal_model.set_causal_mechanism("X1", stochastic.ScipyDistribution(stats.norm, loc=0, scale=1))
    causal_model.set_causal_mechanism(
        "X2",
        mechanisms.AdditiveNoiseModel(
            prediction_model=load("dowhy.gcm.ml.regression").create_linear_regressor()
        ),
    )
    fitting.fit(causal_model, data)
    np.random.seed(PARENT_SEED)
    parents, noise = relevance.parent_relevance(
        causal_model,
        "X2",
        num_samples_randomization=PARENT_ROWS,
        num_samples_baseline=200,
    )
    print("PARENT_RELEVANCE")
    for key in sorted(parents):
        print(f"  {key} = {parents[key]:.12f}")
    print(f"  noise = {float(np.asarray(noise).reshape(-1)[0]):.12f}")
    print(f"  variance = {np.var(data['X2'].to_numpy()):.12f}")

    # ------------------------------------------------------------------
    # C. The relevance of the parents of a node with a categorical target.
    #
    # The upstream test
    # `test_when_using_parent_relevance_with_categorical_data_then_returns_correct_results`
    # expects a relevance of about 0.125 for the two parents that determine the
    # class of the target and a relevance of about zero for the other three.
    # The case is marked as flaky by the upstream, because the relevance is
    # estimated with a random permutation of the parents.
    # ------------------------------------------------------------------
    categorical = categorical_data()
    graph = nx.DiGraph(
        [(f"X{i}", "Y") for i in range(CATEGORICAL_PARENTS)]
    )
    causal_model = models.StructuralCausalModel(graph)
    for i in range(CATEGORICAL_PARENTS):
        causal_model.set_causal_mechanism(
            f"X{i}", stochastic.ScipyDistribution(stats.uniform, loc=0, scale=1)
        )
    causal_model.set_causal_mechanism("Y", mechanisms.ClassifierFCM())
    fitting.fit(causal_model, categorical)
    np.random.seed(CATEGORICAL_SEED)
    parents, noise = relevance.parent_relevance(
        causal_model,
        "Y",
        num_samples_randomization=500,
        num_samples_baseline=50,
    )
    print("PARENT_RELEVANCE_CATEGORICAL")
    for key in sorted(parents):
        print(f"  {key} = {parents[key]:.12f}")
    print(f"  noise = {float(np.asarray(noise).reshape(-1)[0]):.12f}")

    # ------------------------------------------------------------------
    # D. The same fixture with the classifier of the port.
    #
    # The upstream case uses the default classifier of the upstream, which is
    # the histogram gradient boosting classifier. The port uses the nearest
    # neighbour classifier with one neighbour, which is sharp in the same way:
    # the class of a sample of the background is certain, so the noise of the
    # mechanism does not change it and the relevance of the noise is zero.
    # The upstream is run with the same classifier here, so that the numbers of
    # the two sides can be compared.
    # ------------------------------------------------------------------
    knn_model = models.StructuralCausalModel(graph)
    for i in range(CATEGORICAL_PARENTS):
        knn_model.set_causal_mechanism(
            f"X{i}", stochastic.ScipyDistribution(stats.uniform, loc=0, scale=1)
        )
    knn_model.set_causal_mechanism(
        "Y",
        mechanisms.ClassifierFCM(
            classifier_model=load("dowhy.gcm.ml.classification").create_knn_classifier(
                n_neighbors=1
            )
        ),
    )
    fitting.fit(knn_model, categorical)
    np.random.seed(CATEGORICAL_SEED)
    parents, noise = relevance.parent_relevance(
        knn_model,
        "Y",
        num_samples_randomization=500,
        num_samples_baseline=50,
    )
    print("PARENT_RELEVANCE_CATEGORICAL_KNN")
    for key in sorted(parents):
        print(f"  {key} = {parents[key]:.12f}")
    print(f"  noise = {float(np.asarray(noise).reshape(-1)[0]):.12f}")


if __name__ == "__main__":
    main()
