"""The upstream reference of the attribution of the anomalies of `dowhy.gcm`.

The script runs the upstream `dowhy.gcm.anomaly.attribute_anomalies` on the
fixture of the causal chain of the upstream test file
`tests/gcm/test_anomaly_attribution.py` and prints the numbers the MoonBit port
has to reproduce:

  * the contribution of every upstream node to the anomaly score of every
    anomaly sample, with the information theoretic score,
  * the contribution of every upstream node to the deviation of the anomaly
    score, with the feature relevance,
  * the total anomaly score of every anomaly sample, which is the sum of the
    contributions.

The fixtures are the ones of the upstream test file, with the draws of the
upstream replaced by the draws of the generator of the port. The generator of
the port is a 64 bit xorshift whose normal variate is the Box-Muller transform
of two of its uniform variates, and this script reproduces it, so that the
fixtures of the port and the fixtures of this script are the same numbers.

The numbers are the ones of the upstream code itself and not a reading of it: a
re-implementation of the attribution in this script would only produce a second
opinion of the upstream instead of its numbers. The port compares its numbers
with the ones printed here.

The upstream package cannot be imported as it is, because its `__init__` pulls
in `causallearn`; the loader of `upstream_gcm.py` reads the modules straight
from their files instead. The upstream modules that the loader does not know
are registered with it before loading them.

The global generator of numpy is seeded with `SEED` before every fixture, so
that the numbers of one fixture do not depend on the fixtures before it and
the printed values are reproducible. The attribution permutes the samples of the
distribution with the global generator of numpy, so its numbers depend on that
generator.

Usage:
    python _verify/gcm_anomaly_attribution_reference.py
"""

from __future__ import annotations

import math
import os
import sys

import networkx as nx
import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import upstream_gcm  # noqa: E402
from upstream_gcm import load, upstream_root  # noqa: E402

# The seed of the generator of the fixtures. The generator of the port is
# seeded with the seed of the fixture and its index, so that the fixtures do
# not depend on each other.
SEED = 2025

# The number of the rows of the fixture of the causal chain.
NUM_ROWS = 5000

# The upstream modules of the layer.
ML = None
MECHANISMS = None
CAUSAL_MODELS = None
STOCHASTIC = None
FITTING = None
AUTO = None
SCORERS = None
ANOMALY = None


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

    def normals(self, count: int) -> np.ndarray:
        return np.array([self.next_normal() for _ in range(count)], dtype=float)


def fixture_rng(index: int) -> PortRandom:
    """The generator of the fixture with the given index."""
    return PortRandom(SEED + index)


def register_missing_modules() -> None:
    """Registers the upstream modules the loader does not know.

    The loader of `upstream_gcm.py` owns the list of the modules it reads, but
    it does not know the modules this script needs. Its list is only extended
    here, the file itself is left alone.
    """
    upstream_gcm._PATHS["dowhy.gcm.anomaly_scorers"] = "gcm/anomaly_scorers.py"
    upstream_gcm._PATHS["dowhy.gcm.anomaly"] = "gcm/anomaly.py"
    upstream_gcm._PATHS["dowhy.gcm._noise"] = "gcm/_noise.py"
    upstream_gcm._PATHS["dowhy.gcm.fitting_sampling"] = "gcm/fitting_sampling.py"
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


def load_upstream() -> None:
    """Loads the upstream modules of the layer."""
    global ML, MECHANISMS, CAUSAL_MODELS, STOCHASTIC, FITTING, AUTO, SCORERS, ANOMALY

    register_missing_modules()
    upstream_gcm._stub_packages()
    expose_upstream_packages()

    ML = load("dowhy.gcm.ml")
    load("dowhy.gcm.util")
    config = load("dowhy.gcm.config")
    MECHANISMS = load("dowhy.gcm.causal_mechanisms")
    STOCHASTIC = load("dowhy.gcm.stochastic_models")
    CAUSAL_MODELS = load("dowhy.gcm.causal_models")
    FITTING = load("dowhy.gcm.fitting_sampling")
    AUTO = load("dowhy.gcm.auto")
    load("dowhy.gcm.stats")
    load("dowhy.gcm.shapley")
    load("dowhy.gcm.density_estimators")

    # The stub of the package holds no causal mechanism and no causal model, so
    # the names the upstream module imports are set here. The names have to be
    # set before the module is loaded, because it imports them from the package.
    gcm_package = sys.modules["dowhy.gcm"]
    gcm_package.ClassifierFCM = MECHANISMS.ClassifierFCM
    gcm_package.PostNonlinearModel = MECHANISMS.PostNonlinearModel
    gcm_package.PredictionModel = ML.PredictionModel
    gcm_package.ProbabilisticCausalModel = CAUSAL_MODELS.ProbabilisticCausalModel
    gcm_package.config = config
    gcm_package.draw_samples = FITTING.draw_samples

    # The workers of a process pool cannot import the upstream package when it
    # is read from its files, so the runs of the model assignment have to stay
    # in one process.
    config.set_default_n_jobs(1)

    SCORERS = load("dowhy.gcm.anomaly_scorers")
    ANOMALY = load("dowhy.gcm.anomaly")


def show(label: str, value: object) -> None:
    """Prints a value with its label and the full precision of a double."""
    print(f"{label} = {repr(float(value))}")  # type: ignore[arg-type]


def show_list(label: str, values: object) -> None:
    """Prints a list of values with its label."""
    print(f"{label} = {[float(value) for value in np.asarray(values, dtype=float)]!r}")


def causal_chain_fixture() -> tuple[object, pd.DataFrame, pd.DataFrame]:
    """The causal model, the training data and the anomaly data of the fixture."""
    rng = fixture_rng(1)
    x0 = rng.normals(NUM_ROWS)
    x1 = x0 + rng.normals(NUM_ROWS)
    x2 = x1 + rng.normals(NUM_ROWS)
    x3 = x2 + rng.normals(NUM_ROWS)
    training_data = pd.DataFrame({"X0": x0, "X1": x1, "X2": x2, "X3": x3})
    anomaly_data = pd.DataFrame(
        {
            "X0": np.array([0.0, 10.0, 10.0]),
            "X1": np.array([10.0, 10.0, 10.0]),
            "X2": np.array([10.0, 10.0, 10.0]),
            "X3": np.array([10.0, 10.0, 20.0]),
        }
    )
    causal_model = CAUSAL_MODELS.InvertibleStructuralCausalModel(
        nx.DiGraph([("X0", "X1"), ("X1", "X2"), ("X2", "X3")])
    )
    return causal_model, training_data, anomaly_data


def total_anomaly_score(training_data: pd.DataFrame, anomaly_sample: np.ndarray) -> float:
    """The anomaly score of the target, like the upstream test computes it."""
    distribution_samples = training_data["X3"].to_numpy()
    scorer = SCORERS.MedianCDFQuantileScorer()
    scorer.fit(distribution_samples)
    scores = scorer.score(distribution_samples)
    frequency = (np.sum(scores >= scorer.score(anomaly_sample)) + 0.5) / (len(scores) + 0.5)
    return -np.log(frequency)


def main() -> None:
    """Runs every fixture of the layer."""
    load_upstream()
    causal_model, training_data, anomaly_data = causal_chain_fixture()

    print("== the attribution with the information theoretic score ==")
    np.random.seed(SEED)
    AUTO.assign_causal_mechanisms(causal_model, training_data, AUTO.AssignmentQuality.GOOD)
    FITTING.fit(causal_model, training_data)
    scores = ANOMALY.attribute_anomalies(
        causal_model,
        "X3",
        anomaly_data,
        anomaly_scorer=SCORERS.MedianCDFQuantileScorer(),
        num_distribution_samples=NUM_ROWS,
        attribute_mean_deviation=False,
    )
    for node in sorted(scores):
        show_list(f"attribution[{node}]", scores[node])
    for i in range(3):
        total = sum(scores[node][i] for node in scores)
        show(f"attribution.total[{i}]", total)
        show(f"total_anomaly_score[{i}]", total_anomaly_score(training_data, anomaly_data["X3"].to_numpy()[i]))

    print("== the attribution with the feature relevance ==")
    np.random.seed(SEED)
    AUTO.assign_causal_mechanisms(causal_model, training_data, AUTO.AssignmentQuality.GOOD)
    FITTING.fit(causal_model, training_data)
    scores = ANOMALY.attribute_anomalies(
        causal_model,
        "X3",
        anomaly_data,
        anomaly_scorer=SCORERS.MedianCDFQuantileScorer(),
        num_distribution_samples=NUM_ROWS,
        attribute_mean_deviation=True,
    )
    for node in sorted(scores):
        show_list(f"relevance[{node}]", scores[node])
    for i in range(3):
        total = sum(scores[node][i] for node in scores)
        show(f"relevance.total[{i}]", total)


if __name__ == "__main__":
    main()
