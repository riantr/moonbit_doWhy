"""The upstream reference of the anomaly detection layer of `dowhy.gcm`.

The script runs the upstream `dowhy.gcm.anomaly_scorers` and the upstream
`dowhy.gcm.anomaly` on the fixtures of the anomaly detection layer and prints
the numbers the MoonBit port has to reproduce:

  * the scores of the six scorers of the upstream on the toy fixtures of the
    upstream test file `tests/gcm/test_anomaly_scorers.py`,
  * the score of the inverse density scorer with the kernel based density
    estimator of the upstream, which is the estimator the port uses,
  * the node with the largest anomaly score of every scorer of the upstream on
    the fixture of the causal model of the upstream test file
    `tests/gcm/test_anomaly.py`,
  * the conditional anomaly score of the upstream on the fixture of the causal
    mechanism of the upstream test file `tests/gcm/test_anomaly.py`.

The fixtures are the ones of the upstream test files, with the draws of the
upstream replaced by the draws of the generator of the port. The generator of
the port is a 64 bit xorshift whose normal variate is the Box-Muller transform
of two of its uniform variates, and this script reproduces it, so that the
fixtures of the port and the fixtures of this script are the same numbers.

The numbers are the ones of the upstream code itself and not a reading of it: a
re-implementation of the scorers in this script would only produce a second
opinion of the upstream instead of its numbers. The port compares its numbers
with the ones printed here.

The upstream package cannot be imported as it is, because its `__init__` pulls
in `causallearn`; the loader of `upstream_gcm.py` reads the modules straight
from their files instead. The upstream modules that the loader does not know
are registered with it before loading them.

The global generator of numpy is seeded with `SEED` before every fixture, so
that the numbers of one fixture do not depend on the fixtures before it and
the printed values are reproducible.

Usage:
    python _verify/gcm_anomaly_reference.py
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

# The number of rows of the fixture of the causal model.
NUM_ROWS = 1000

# The number of the samples the upstream draws for the unconditional and for
# the conditional anomaly score.
NUM_SAMPLES_UNCONDITIONAL = 10000
NUM_SAMPLES_CONDITIONAL = 10000

# The upstream modules of the layer.
ML = None
MECHANISMS = None
CAUSAL_MODELS = None
STOCHASTIC = None
FITTING = None
AUTO = None
SCORERS = None
DENSITY = None
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

    def uniforms(self, low: float, high: float, count: int) -> np.ndarray:
        return np.array([low + (high - low) * self.next_double() for _ in range(count)], dtype=float)


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
    global ML, MECHANISMS, CAUSAL_MODELS, STOCHASTIC, FITTING, AUTO, SCORERS, DENSITY, ANOMALY

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
    DENSITY = load("dowhy.gcm.density_estimators")

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


# --------------------------------------------------------------------------
# The toy fixtures of the upstream test file of the scorers.
# --------------------------------------------------------------------------


def toy_fixtures() -> None:
    """The scores of the scorers on the toy fixtures of the upstream test."""
    np.random.seed(SEED)

    print("== the median cdf quantile scorer ==")
    scorer = SCORERS.MedianCDFQuantileScorer()
    scorer.fit(np.array(range(0, 20), dtype=float))
    show_list("median_cdf.score([8, 17])", scorer.score(np.array([8.0, 17.0])))
    show_list("median_cdf.score([0])", scorer.score(np.array([0.0])))
    scorer.fit(np.array([4.0 for _ in range(200)]))
    show_list("median_cdf.score([4]) of the constant data", scorer.score(np.array([4.0])))

    print("== the rescaled median cdf quantile scorer ==")
    training = np.array([1, 2, 3, 4, 5, 6, 7, 8, np.nan, np.nan], dtype=float)
    scorer = SCORERS.RescaledMedianCDFQuantileScorer()
    scorer.fit(training)
    show_list("rescaled_median_cdf.score([1, 4, 8, nan])", scorer.score(np.array([1.0, 4.0, 8.0, np.nan])))

    print("== the rank based scorer ==")
    scorer = SCORERS.RankBasedAnomalyScorer()
    scorer.fit(training)
    show_list("rank_based.score([1, 4, 9, nan])", scorer.score(np.array([1.0, 4.0, 9.0, np.nan])))
    scorer.fit(np.array([np.nan, np.nan, np.nan, np.nan], dtype=float))
    show_list("rank_based.score([1, nan]) of the nan data", scorer.score(np.array([1.0, np.nan])))

    print("== the median deviation scorer ==")
    scorer = SCORERS.MedianDeviationScorer()
    scorer.fit(np.array(range(0, 20)) / 10)
    show_list("median_deviation.score([0.8, 1.7])", scorer.score(np.array([0.8, 1.7])))

    print("== the mean deviation scorer ==")
    scorer = SCORERS.MeanDeviationScorer()
    scorer.fit(np.array(range(0, 20)) / 10)
    show_list("mean_deviation.score([0.8, 1.7])", scorer.score(np.array([0.8, 1.7])))

    print("== the information theoretic scorer ==")
    scorer = SCORERS.ITAnomalyScorer(SCORERS.MedianCDFQuantileScorer())
    scorer.fit(training)
    show_list("it.score([1, 4, 8, nan])", scorer.score(np.array([1.0, 4.0, 8.0, np.nan])))

    print("== the inverse density scorer ==")
    # The upstream uses the Bayesian Gaussian mixture of the upstream by
    # default. The port uses the kernel based estimator of the upstream, whose
    # numbers are printed as well, because they are the ones the port has to
    # reproduce.
    scorer = SCORERS.InverseDensityScorer()
    scorer.fit(np.array(range(0, 20), dtype=float))
    show_list("inverse_density.score([8, 17]) of the mixture", scorer.score(np.array([8.0, 17.0])))
    scorer = SCORERS.InverseDensityScorer(DENSITY.KernelDensityEstimator1D())
    scorer.fit(np.array(range(0, 20), dtype=float))
    show_list("inverse_density.score([8, 17]) of the kernel", scorer.score(np.array([8.0, 17.0])))


# --------------------------------------------------------------------------
# The fixture of the causal model of the upstream test file of the anomaly
# scores.
# --------------------------------------------------------------------------


def causal_model_fixture() -> tuple[pd.DataFrame, pd.DataFrame]:
    """The observations and the outlier observation of the fixture."""
    rng = fixture_rng(1)
    x0 = rng.uniforms(-1.0, 1.0, NUM_ROWS)
    x1 = 2.0 * x0 + 0.1 * rng.normals(NUM_ROWS)
    x2 = 0.5 * x0 + 0.1 * rng.normals(NUM_ROWS)
    x3 = 0.5 * x2 + 0.1 * rng.normals(NUM_ROWS)
    observations = pd.DataFrame({"X0": x0, "X1": x1, "X2": x2, "X3": x3})
    outlier = pd.DataFrame(
        {
            "X0": x0[:1],
            "X1": x1[:1] + np.std(x1) * 3,
            "X2": x2[:1],
            "X3": x3[:1],
        }
    )
    return observations, outlier


def anomaly_score_fixtures() -> None:
    """The node with the largest anomaly score of every scorer."""
    observations, outlier = causal_model_fixture()

    print("== the anomaly scores of the causal model ==")
    pcm = CAUSAL_MODELS.ProbabilisticCausalModel(nx.DiGraph([("X0", "X1"), ("X0", "X2"), ("X2", "X3")]))
    AUTO.assign_causal_mechanisms(pcm, observations)
    FITTING.fit(pcm, observations)

    factories = {
        "median_cdf": lambda: SCORERS.MedianCDFQuantileScorer(),
        "rescaled_median_cdf": lambda: SCORERS.RescaledMedianCDFQuantileScorer(),
        "rank_based": lambda: SCORERS.RankBasedAnomalyScorer(),
        "mean_deviation": lambda: SCORERS.MeanDeviationScorer(),
        "median_deviation": lambda: SCORERS.MedianDeviationScorer(),
        "inverse_density_kernel": lambda: SCORERS.InverseDensityScorer(DENSITY.KernelDensityEstimator1D()),
        "it_median_cdf": lambda: SCORERS.ITAnomalyScorer(SCORERS.MedianCDFQuantileScorer()),
        "it_rescaled_median_cdf": lambda: SCORERS.ITAnomalyScorer(SCORERS.RescaledMedianCDFQuantileScorer()),
        "it_mean_deviation": lambda: SCORERS.ITAnomalyScorer(SCORERS.MeanDeviationScorer()),
        "it_median_deviation": lambda: SCORERS.ITAnomalyScorer(SCORERS.MedianDeviationScorer()),
    }

    for name, factory in factories.items():
        np.random.seed(SEED)
        scores = ANOMALY.anomaly_scores(
            pcm,
            outlier,
            num_samples_conditional=NUM_SAMPLES_CONDITIONAL,
            num_samples_unconditional=NUM_SAMPLES_UNCONDITIONAL,
            anomaly_scorer_factory=factory,
        )
        best = max(scores.items(), key=lambda item: item[1][0])
        print(f"anomaly_scores.{name}.largest = {best[0]}")
        for node in sorted(scores):
            show_list(f"anomaly_scores.{name}[{node}]", scores[node])


def conditional_anomaly_score_fixture() -> None:
    """The conditional anomaly score of the upstream on its fixture."""
    np.random.seed(SEED)
    rng = fixture_rng(2)
    x = rng.normals(NUM_ROWS)
    noise = rng.normals(NUM_ROWS)
    y = 2.0 * x + noise

    mechanism = MECHANISMS.AdditiveNoiseModel(prediction_model=ML.create_linear_regressor())
    mechanism.fit(x.reshape(-1, 1), y)

    scores = ANOMALY.conditional_anomaly_scores(
        x[:5].reshape(-1, 1),
        y[:5],
        mechanism,
        SCORERS.MeanDeviationScorer,
        NUM_SAMPLES_CONDITIONAL,
    )
    show_list("conditional_anomaly_scores", scores)

    scorer = SCORERS.MeanDeviationScorer()
    scorer.fit(noise)
    show_list("conditional_anomaly_scores.expected", scorer.score(y[:5] - 2.0 * x[:5]))


def main() -> None:
    """Runs every fixture of the layer."""
    load_upstream()
    toy_fixtures()
    anomaly_score_fixtures()
    conditional_anomaly_score_fixture()


if __name__ == "__main__":
    main()
