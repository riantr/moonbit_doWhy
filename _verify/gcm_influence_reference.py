"""The upstream reference of the influence layer of `dowhy.gcm`.

The script runs the upstream `dowhy.gcm.influence` on the fixtures of the layer
and prints the numbers the MoonBit port has to reproduce:

  * the causal strength of every edge that points at the target node, with the
    default measure of the difference of the two distributions,
  * the causal strength with the Kullback-Leibler divergence as the measure,
  * the causal strength with the observed samples of the parents,
  * the strength of every input of a classifier.

The fixtures are the ones of the upstream test file `tests/gcm/test_arrow_strength.py`,
with the draws of the upstream replaced by the draws of the generator of the port.
The generator of the port is a 64 bit xorshift whose normal variate is the
Box-Muller transform of two of its uniform variates, and this script reproduces
it, so that the fixtures of the port and the fixtures of this script are the
same numbers.

The numbers are the ones of the upstream code itself and not a reading of it: a
re-implementation of the arrow strength in this script would only produce a
second opinion of the upstream instead of its numbers. The port compares its
numbers with the ones printed here.

The upstream draws the permutations and the noise of the arrow strength from
the global generator of numpy, and the port draws them from its own generator,
so the two numbers are close to each other and not equal. The tests of the port
therefore assert the relations the upstream test file asserts, with a
tolerance around the numbers printed here.

The samples of the conditional distribution and the number of the runs of the
estimate are smaller than the ones of the upstream, the way they are in the
tests of the port: the upstream draws two thousand samples of the conditional
distribution and runs the estimate up to five thousand times, and the estimate
of the port has to stay within the time the gate of the port needs on every
backend.

The upstream package cannot be imported as it is, because its `__init__` pulls
in `causallearn`; the loader of `upstream_gcm.py` reads the modules straight
from their files instead. The upstream modules that the loader does not know
are registered with it before loading them.

Usage:
    python _verify/gcm_influence_reference.py
"""

from __future__ import annotations

import math
import os
import sys

import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import upstream_gcm  # noqa: E402
from upstream_gcm import load  # noqa: E402

# The seed of the generator of the fixtures. The generator of the port is
# seeded with the seed of the fixture and its index, so that the fixtures do
# not depend on each other.
SEED = 2025

# The number of the rows of the fixture. The upstream uses a thousand rows.
NUM_ROWS = 300

# The number of the samples of the conditional distribution. The upstream uses
# two thousand of them.
NUM_SAMPLES_CONDITIONAL = 200

# The number of the runs of the estimate. The upstream uses five thousand of
# them.
MAX_NUM_RUNS = 20

ML = None
MECHANISMS = None
CAUSAL_MODELS = None
STOCHASTIC = None
FITTING = None
AUTO = None
DIVERGENCE = None
INFLUENCE = None


class PortRandom:
    """The generator of the `utils` package of the port.

    The port draws the samples of its fixtures from its own generator, so that
    the fixtures of the port and the fixtures of this script are the same
    numbers. The generator is a 64 bit xorshift, and its normal variate is the
    Box-Muller transform of two of its uniform variates.
    """

    MASK = (1 << 64) - 1

    def __init__(self, seed: int) -> None:
        self.state = seed & self.MASK
        if self.state == 0:
            self.state = 0x9E3779B97F4A7C15

    def next_u64(self) -> int:
        x = self.state
        x ^= (x << 13) & self.MASK
        x ^= x >> 7
        x ^= (x << 17) & self.MASK
        self.state = x
        return x

    def next_double(self) -> float:
        return (self.next_u64() >> 11) / 9007199254740992.0

    def next_normal(self) -> float:
        u1 = self.next_double()
        u2 = self.next_double()
        if u1 < 1.0e-12:
            u1 = 1.0e-12
        return math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2)

    def normals(self, count: int, scale: float) -> np.ndarray:
        return np.array([scale * self.next_normal() for _ in range(count)], dtype=float)

    def uniforms(self, count: int, low: float, high: float) -> np.ndarray:
        return np.array([low + (high - low) * self.next_double() for _ in range(count)])


def fixture_rng(index: int) -> PortRandom:
    """The generator of the fixture with the given index."""
    return PortRandom(SEED + index)


def register_missing_modules() -> None:
    """Registers the upstream modules the loader does not know.

    The loader of `upstream_gcm.py` owns the list of the modules it reads, but
    it does not know the modules this script needs. Its list is only extended
    here, the file itself is left alone.
    """
    upstream_gcm._PATHS["dowhy.gcm.fitting_sampling"] = "gcm/fitting_sampling.py"
    upstream_gcm._PATHS["dowhy.gcm.uncertainty"] = "gcm/uncertainty.py"
    upstream_gcm._PATHS["dowhy.gcm.feature_relevance"] = "gcm/feature_relevance.py"
    upstream_gcm._PATHS["dowhy.gcm._noise"] = "gcm/_noise.py"
    upstream_gcm._PATHS["dowhy.gcm.influence"] = "gcm/influence.py"


def expose_upstream_packages() -> None:
    """Points the stubbed packages at the real directories of the upstream.

    The loader stubs the packages of the upstream out, so that the modules of
    `dowhy.gcm` can be read without the `causallearn` dependency of the real
    package. The plotting module of `dowhy.gcm.util` reaches the plotting
    module of `dowhy.utils`, which the stubbed packages do not reach, so their
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


def load_upstream() -> None:
    """Loads the upstream modules of the layer."""
    global ML, MECHANISMS, CAUSAL_MODELS, STOCHASTIC, FITTING, AUTO, DIVERGENCE, INFLUENCE

    register_missing_modules()
    upstream_gcm._stub_packages()
    expose_upstream_packages()

    ML = load("dowhy.gcm.ml")
    MECHANISMS = load("dowhy.gcm.causal_mechanisms")
    STOCHASTIC = load("dowhy.gcm.stochastic_models")
    CAUSAL_MODELS = load("dowhy.gcm.causal_models")
    FITTING = load("dowhy.gcm.fitting_sampling")
    AUTO = load("dowhy.gcm.auto")
    DIVERGENCE = load("dowhy.gcm.divergence")

    # The workers of a process pool cannot import the upstream package when it
    # is read from its files, so the runs have to stay in one process.
    config = load("dowhy.gcm.config")
    config.set_default_n_jobs(1)

    # The upstream module of the influence reads the feature relevance from
    # the package of the upstream, which the loader stubs out. The function is
    # put on the stubbed package, the way the `__init__` of the upstream does.
    feature_relevance = load("dowhy.gcm.feature_relevance")
    sys.modules["dowhy.gcm"].feature_relevance_sample = (
        feature_relevance.feature_relevance_sample
    )

    INFLUENCE = load("dowhy.gcm.influence")


def show(label: str, value: object) -> None:
    """Prints a value with its label and the full precision of a double."""
    print(f"{label} = {repr(float(value))}")  # type: ignore[arg-type]


def fixture_data(index: int) -> pd.DataFrame:
    """The data of the fixture with the given index."""
    rng = fixture_rng(index)
    x0 = rng.normals(NUM_ROWS, 1.0)
    x1 = rng.normals(NUM_ROWS, 1.0)
    noise = rng.normals(NUM_ROWS, 1.0)
    return pd.DataFrame({"X0": x0, "X1": x1, "X2": 3 * x0 + x1 + noise})


def create_causal_model(data: pd.DataFrame):
    """The causal model of the fixture, fitted on the given data."""
    from scipy import stats

    graph = nx_di_graph()
    causal_model = CAUSAL_MODELS.ProbabilisticCausalModel(graph)
    causal_model.set_causal_mechanism("X1", STOCHASTIC.ScipyDistribution(stats.norm, loc=0, scale=1))
    causal_model.set_causal_mechanism("X0", STOCHASTIC.ScipyDistribution(stats.norm, loc=0, scale=1))
    causal_model.set_causal_mechanism(
        "X2",
        MECHANISMS.AdditiveNoiseModel(
            prediction_model=ML.create_linear_regressor_with_given_parameters([3, 1]),
            noise_model=STOCHASTIC.ScipyDistribution(stats.norm, loc=0, scale=1),
        ),
    )
    FITTING.fit(causal_model, data)
    return causal_model


def nx_di_graph():
    """The graph of the fixture."""
    import networkx as nx

    return nx.DiGraph([("X1", "X2"), ("X0", "X2")])


def main() -> None:
    load_upstream()

    data = fixture_data(30)
    causal_model = create_causal_model(data)

    strengths = INFLUENCE.arrow_strength(
        causal_model,
        "X2",
        num_samples_conditional=NUM_SAMPLES_CONDITIONAL,
        max_num_runs=MAX_NUM_RUNS,
        n_jobs=1,
    )
    show("arrow_strength.X0", strengths[("X0", "X2")])
    show("arrow_strength.X1", strengths[("X1", "X2")])

    strengths = INFLUENCE.arrow_strength(
        causal_model,
        "X2",
        num_samples_conditional=NUM_SAMPLES_CONDITIONAL,
        max_num_runs=MAX_NUM_RUNS,
        n_jobs=1,
        difference_estimation_func=DIVERGENCE.estimate_kl_divergence_continuous_knn,
    )
    show("arrow_strength_kl.X0", strengths[("X0", "X2")])
    show("arrow_strength_kl.X1", strengths[("X1", "X2")])

    strengths = INFLUENCE.arrow_strength(
        causal_model,
        "X2",
        parent_samples=data,
        num_samples_conditional=NUM_SAMPLES_CONDITIONAL,
        max_num_runs=MAX_NUM_RUNS,
        n_jobs=1,
    )
    show("arrow_strength_observed.X0", strengths[("X0", "X2")])
    show("arrow_strength_observed.X1", strengths[("X1", "X2")])

    # The strength of every input of a classifier.
    from dowhy.gcm.ml import create_logistic_regression_classifier

    classifier_rng = fixture_rng(31)
    inputs = classifier_rng.uniforms(5000, 0.0, 1.0).reshape(1000, 5)
    labels = []
    for row in inputs:
        if (row[0] + row[1] + classifier_rng.next_double()) > 1.5:
            labels.append("0")
        else:
            labels.append("1")
    classifier = MECHANISMS.ClassifierFCM(create_logistic_regression_classifier())
    classifier.fit(inputs, np.array(labels))
    strengths = INFLUENCE.arrow_strength_of_model(
        classifier,
        inputs,
        num_samples_from_conditional=NUM_SAMPLES_CONDITIONAL,
        max_num_runs=MAX_NUM_RUNS,
        n_jobs=1,
    )
    for index, value in enumerate(strengths):
        show(f"arrow_strength_of_model.{index}", value)


if __name__ == "__main__":
    main()
