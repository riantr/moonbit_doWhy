"""The upstream reference of the mechanism evaluation layer of `dowhy.gcm`.

The script runs the upstream `dowhy.gcm.model_evaluation` on the fixtures of
the mechanism evaluation layer and prints the numbers the MoonBit port has to
reproduce:

  * the normalised mean squared error of the three fixtures of the upstream test
    of the metric, with a good fit, with a bad fit and with a noisy fit,
  * the continuous ranked probability score of the four continuous fixtures of
    the upstream test of the metric, with a good fit, with a bad fit, with a
    noisy fit and with a very bad fit,
  * the continuous ranked probability score of the two categorical fixtures of
    the upstream test of the metric, with a good fit and with a bad fit,
  * the outcome of the evaluation of the invertibility assumption of the
    multiplicative and of the additive noise fixture,
  * the performance of the causal mechanisms and the overall divergence of the
    continuous and of the categorical fixture of the evaluation of a model.

The fixtures are the ones of the upstream test file
`tests/gcm/test_model_evaluation.py`, with the draws of the upstream replaced
by the draws of the generator of the port. The generator of the port is a 64
bit xorshift whose normal variate is the Box-Muller transform of two of its
uniform variates, and this script reproduces it, so that the fixtures of the
port and the fixtures of this script are the same numbers. Every fixture has
its own generator, and the draws of a fixture follow each other in one
generator, so that the fixtures do not depend on each other.

The numbers are the ones of the upstream code itself and not a reading of it: a
re-implementation of the metrics in this script would only produce a second
opinion of the upstream instead of its numbers. The port compares its numbers
with the ones printed here.

The upstream package cannot be imported as it is, because its `__init__` pulls
in `causallearn`; the loader of `upstream_gcm.py` reads the modules straight
from their files instead. The upstream modules that the loader does not know
are registered with it before loading them.

The independence test of the falsification of the graph is the generalised
covariance measure of the upstream with a linear regressor and not the kernel
based test of the upstream: the kernel based test is cubic in the number of the
samples, and the falsification runs it for every permutation of the nodes of
the graph. The decision of the two tests on the fixtures of the layer is the
same, and the decision is what the upstream test asserts.

The global generator of numpy is seeded with `SEED` before every fixture, so
that the numbers of one fixture do not depend on the fixtures before it and
the printed values are reproducible.

Usage:
    python _verify/gcm_model_evaluation_reference.py
"""

from __future__ import annotations

import math
import os
import sys
import time

import networkx as nx
import numpy as np
import pandas as pd
from scipy import stats

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import upstream_gcm  # noqa: E402
from upstream_gcm import load, upstream_root  # noqa: E402

# The seed of the generator of the fixtures. The generator of the port is
# seeded with the seed of the fixture and its index, so that the fixtures do
# not depend on each other.
SEED = 2025

# The number of rows of the fixtures of the metrics.
NUM_ROWS = 1000

# The number of rows of the fixtures of the evaluation of a model. The
# evaluation runs a cross validation and a falsification of the graph, so it
# needs fewer rows than the metrics do.
NUM_ROWS_EVAL = 500

# The number of the permutations of the falsification of the graph. The default
# of the upstream is fifty, which is more than the reference script and the
# test of the port need for the numbers they compare.
NUM_PERMUTATIONS = 5

# The significance level of the tests of the invertibility assumption.
SIGNIFICANCE_LEVEL = 0.05

# The number of the folds of the cross validation of the mechanisms.
KFOLDS = 5

# The upstream modules of the layer, which the functions of this script use.
ML = None
MECHANISMS = None
CAUSAL_MODELS = None
STOCHASTIC = None
FITTING = None
INDEPENDENCE = None
EVALUATION = None


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
    upstream_gcm._PATHS["dowhy.gcm.falsify"] = "gcm/falsify.py"
    upstream_gcm._PATHS["dowhy.gcm.model_evaluation"] = "gcm/model_evaluation.py"
    upstream_gcm._PATHS["dowhy.gcm.fitting_sampling"] = "gcm/fitting_sampling.py"
    upstream_gcm._PATHS["dowhy.gcm.validation"] = "gcm/validation.py"
    upstream_gcm._PATHS["dowhy.gcm.independence_test"] = "gcm/independence_test/__init__.py"
    upstream_gcm._PATHS["dowhy.gcm.independence_test.kernel"] = "gcm/independence_test/kernel.py"
    upstream_gcm._PATHS["dowhy.gcm.independence_test.kernel_operation"] = (
        "gcm/independence_test/kernel_operation.py"
    )
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
    global ML, MECHANISMS, CAUSAL_MODELS, STOCHASTIC, FITTING, INDEPENDENCE, EVALUATION

    register_missing_modules()
    upstream_gcm._stub_packages()
    expose_upstream_packages()

    # The real `dowhy.gcm.ml` has to exist before the modules that use it.
    ML = load("dowhy.gcm.ml")
    load("dowhy.gcm.util")
    load("dowhy.gcm.config")
    MECHANISMS = load("dowhy.gcm.causal_mechanisms")
    STOCHASTIC = load("dowhy.gcm.stochastic_models")
    CAUSAL_MODELS = load("dowhy.gcm.causal_models")
    FITTING = load("dowhy.gcm.fitting_sampling")
    INDEPENDENCE = load("dowhy.gcm.independence_test")
    load("dowhy.gcm.auto")
    load("dowhy.gcm.stats")
    load("dowhy.gcm.falsify")

    # The stub of the package holds no prediction model and no causal
    # mechanism, so the names the upstream module imports are set here. The
    # names have to be set before the module is loaded, because it imports
    # them from the package.
    config = load("dowhy.gcm.config")
    # The workers of a process pool cannot import the upstream package when it
    # is read from its files, so the runs of the kernel based test have to stay
    # in one process.
    config.set_default_n_jobs(1)
    gcm_package = sys.modules["dowhy.gcm"]
    gcm_package.ClassifierFCM = MECHANISMS.ClassifierFCM
    gcm_package.PostNonlinearModel = MECHANISMS.PostNonlinearModel
    gcm_package.PredictionModel = ML.PredictionModel
    gcm_package.ProbabilisticCausalModel = CAUSAL_MODELS.ProbabilisticCausalModel
    gcm_package.config = config
    gcm_package.draw_samples = FITTING.draw_samples
    gcm_package.kernel_based = INDEPENDENCE.kernel_based

    EVALUATION = load("dowhy.gcm.model_evaluation")


def show(label: str, value: object) -> None:
    """Prints a value with its label and the full precision of a double."""
    print(f"{label} = {repr(float(value))}")  # type: ignore[arg-type]


def show_int(label: str, value: object) -> None:
    """Prints a value with its label as a whole number."""
    print(f"{label} = {int(value)}")  # type: ignore[arg-type]


def show_bool(label: str, value: object) -> None:
    """Prints a value with its label as a decision."""
    print(f"{label} = {bool(value)}")


def linear_dependence(x: np.ndarray, y: np.ndarray, z: np.ndarray | None = None) -> float:
    """The p-value of the generalised covariance measure with a linear fit."""
    return INDEPENDENCE.generalised_cov_based(
        x,
        y,
        Z=z,
        prediction_model_X=ML.create_linear_regressor,
        prediction_model_Y=ML.create_linear_regressor,
    )


def kernel_dependence(x: np.ndarray, y: np.ndarray, z: np.ndarray | None = None) -> float:
    """The p-value of the kernel based test of the upstream."""
    return INDEPENDENCE.kernel_based(x, y, Z=z)


def additive_mechanism(coefficient: float, scale: float):
    """The additive noise model of the upstream with the given parameters."""
    return MECHANISMS.AdditiveNoiseModel(
        ML.create_linear_regressor_with_given_parameters(
            np.array([coefficient]), intercept=0
        ),
        noise_model=STOCHASTIC.ScipyDistribution(stats.norm, loc=0, scale=scale),
    )


def fitted_model(data: pd.DataFrame, categorical: bool):
    """The causal model of the upstream with the mechanisms of the port."""
    causal_model = CAUSAL_MODELS.InvertibleStructuralCausalModel(
        nx.DiGraph([("X0", "Y"), ("X1", "Y")])
    )
    for node in ("X0", "X1"):
        causal_model.set_causal_mechanism(node, STOCHASTIC.ScipyDistribution(stats.norm))
    if categorical:
        causal_model.set_causal_mechanism(
            "Y",
            MECHANISMS.ClassifierFCM(ML.create_logistic_regression_classifier()),
        )
    else:
        causal_model.set_causal_mechanism(
            "Y",
            MECHANISMS.AdditiveNoiseModel(ML.create_linear_regressor()),
        )
    FITTING.fit(causal_model, data)
    return causal_model


def main() -> None:
    """Prints the numbers of the upstream."""
    load_upstream()

    print(f"SEED = {SEED}")
    print(f"NUM_ROWS = {NUM_ROWS}")
    print(f"NUM_ROWS_EVAL = {NUM_ROWS_EVAL}")
    print(f"NUM_PERMUTATIONS = {NUM_PERMUTATIONS}")

    # ------------------------------------------------------------------
    # The normalised mean squared error.
    # ------------------------------------------------------------------
    print()
    print("==== the normalised mean squared error ====")

    np.random.seed(SEED + 0)
    rng = fixture_rng(0)
    x = rng.normals(NUM_ROWS)
    y = 2.0 * x
    mechanism = additive_mechanism(2.0, 0.0)
    conditional = EVALUATION._estimate_conditional_expectations(mechanism, x, False, 1)
    show("[nmse good] squared", EVALUATION.nmse(y, conditional, squared=True))
    show("[nmse good] not squared", EVALUATION.nmse(y, conditional, squared=False))

    np.random.seed(SEED + 1)
    rng = fixture_rng(1)
    x = rng.normals(NUM_ROWS)
    y = 2.0 * x
    mechanism = additive_mechanism(20.0, 0.0)
    conditional = EVALUATION._estimate_conditional_expectations(mechanism, x, False, 1)
    show("[nmse bad] squared", EVALUATION.nmse(y, conditional, squared=True))
    show("[nmse bad] not squared", EVALUATION.nmse(y, conditional, squared=False))

    np.random.seed(SEED + 2)
    rng = fixture_rng(2)
    x = rng.normals(NUM_ROWS)
    y = 2.0 * x + 2.0 * rng.normals(NUM_ROWS)
    mechanism = additive_mechanism(2.0, 2.0)
    conditional = EVALUATION._estimate_conditional_expectations(mechanism, x, False, 1)
    show("[nmse noisy] squared", EVALUATION.nmse(y, conditional, squared=True))
    show("[nmse noisy] not squared", EVALUATION.nmse(y, conditional, squared=False))
    show("[nmse noisy] variance of the target", np.var(y))

    # ------------------------------------------------------------------
    # The continuous ranked probability score.
    # ------------------------------------------------------------------
    print()
    print("==== the continuous ranked probability score ====")

    np.random.seed(SEED + 3)
    rng = fixture_rng(3)
    x = rng.normals(NUM_ROWS)
    y = 2.0 * x
    mechanism = additive_mechanism(2.0, 0.0)
    show("[crps good]", EVALUATION.crps(x, y, mechanism.draw_samples))

    np.random.seed(SEED + 4)
    rng = fixture_rng(4)
    x = rng.normals(NUM_ROWS)
    y = x.copy()
    mechanism = additive_mechanism(1.0, 2.0)
    show("[crps bad]", EVALUATION.crps(x, y, mechanism.draw_samples))

    np.random.seed(SEED + 5)
    rng = fixture_rng(5)
    x = rng.normals(NUM_ROWS)
    y = 2.0 * x + rng.normals(NUM_ROWS)
    mechanism = additive_mechanism(2.0, 1.0)
    show("[crps noisy]", EVALUATION.crps(x, y, mechanism.draw_samples))

    np.random.seed(SEED + 6)
    rng = fixture_rng(6)
    x = rng.normals(NUM_ROWS)
    y = x.copy()
    mechanism = additive_mechanism(100.0, 2.0)
    show("[crps very bad]", EVALUATION.crps(x, y, mechanism.draw_samples))

    # ------------------------------------------------------------------
    # The continuous ranked probability score of the categorical data.
    # ------------------------------------------------------------------
    print()
    print("==== the continuous ranked probability score of the categorical data ====")

    np.random.seed(SEED + 7)
    rng = fixture_rng(7)
    x_fit = rng.normals(NUM_ROWS)
    y_fit = (x_fit > 0).astype(str)
    classifier_model = MECHANISMS.ClassifierFCM(ML.create_logistic_regression_classifier())
    classifier_model.fit(x_fit, y_fit)
    x = rng.normals(NUM_ROWS)
    y = (x > 0).astype(str)
    show("[crps categorical good]", EVALUATION.crps(x, y, classifier_model.draw_samples))

    np.random.seed(SEED + 8)
    rng = fixture_rng(8)
    x_fit = rng.normals(NUM_ROWS)
    y_fit = (x_fit > 0).astype(str)
    classifier_model = MECHANISMS.ClassifierFCM(ML.create_logistic_regression_classifier())
    classifier_model.fit(x_fit, y_fit)
    x = rng.normals(NUM_ROWS)
    y = ((x + 1.0) > 0).astype(str)
    show("[crps categorical bad]", EVALUATION.crps(x, y, classifier_model.draw_samples))

    # ------------------------------------------------------------------
    # The evaluation of the invertibility assumption.
    # ------------------------------------------------------------------
    print()
    print("==== the evaluation of the invertibility assumption ====")

    for index, name, multiplicative in (
        (9, "[invertibility multiplicative]", True),
        (10, "[invertibility additive]", False),
    ):
        np.random.seed(SEED + index)
        rng = fixture_rng(index)
        x0 = rng.normals(NUM_ROWS)
        noise = 0.1 * rng.normals(NUM_ROWS)
        y = x0 * noise if multiplicative else x0 + noise
        data = pd.DataFrame({"X0": x0, "Y": y})

        causal_model = CAUSAL_MODELS.InvertibleStructuralCausalModel(
            nx.DiGraph([("X0", "Y")])
        )
        causal_model.set_causal_mechanism("X0", STOCHASTIC.ScipyDistribution(stats.norm))
        causal_model.set_causal_mechanism(
            "Y", MECHANISMS.AdditiveNoiseModel(ML.create_linear_regressor())
        )
        FITTING.fit(causal_model, data)

        np.random.seed(SEED + index)
        started = time.time()
        assumptions = EVALUATION._evaluate_invertibility_assumptions(
            causal_model,
            data,
            kernel_dependence,
            SIGNIFICANCE_LEVEL,
            None,
            1,
        )
        elapsed = time.time() - started
        show(f"{name} p-value", assumptions["Y"][0])
        show_bool(f"{name} rejected", assumptions["Y"][1])
        show(f"{name} significance level", assumptions["Y"][2])
        print(f"{name} seconds = {elapsed:.1f}")

    # ------------------------------------------------------------------
    # The evaluation of a model.
    # ------------------------------------------------------------------
    print()
    print("==== the evaluation of a model with continuous data ====")

    np.random.seed(SEED + 11)
    rng = fixture_rng(11)
    x0 = rng.normals(NUM_ROWS_EVAL)
    x1 = rng.normals(NUM_ROWS_EVAL)
    y = x0 + x1 + 0.1 * rng.normals(NUM_ROWS_EVAL)
    data = pd.DataFrame({"X0": x0, "X1": x1, "Y": y})
    evaluate_model(data, categorical=False)

    print()
    print("==== the evaluation of a model with categorical data ====")

    np.random.seed(SEED + 12)
    rng = fixture_rng(12)
    x0 = rng.normals(NUM_ROWS_EVAL)
    x1 = rng.normals(NUM_ROWS_EVAL)
    y = (x0 + x1 + 0.1 * rng.normals(NUM_ROWS_EVAL) > 0).astype(str)
    data = pd.DataFrame({"X0": x0, "X1": x1, "Y": y})
    evaluate_model(data, categorical=True)


def evaluate_model(data: pd.DataFrame, categorical: bool) -> None:
    """Prints the numbers of the evaluation of a model with the given data."""
    causal_model = fitted_model(data, categorical)

    baselines = (
        [
            ML.create_logistic_regression_classifier,
            ML.create_hist_gradient_boost_classifier,
        ]
        if categorical
        else [ML.create_linear_regressor, ML.create_hist_gradient_boost_regressor]
    )
    np.random.seed(SEED + 13)
    started = time.time()
    summary = EVALUATION.evaluate_causal_model(
        causal_model,
        data,
        compare_mechanism_baselines=True,
        evaluate_causal_structure=not categorical,
        config=EVALUATION.EvaluateCausalModelConfig(
            baseline_models_regression=(None if categorical else baselines),
            baseline_models_classification=(baselines if categorical else None),
            independence_test_invertible=kernel_dependence,
            independence_test_falsify=linear_dependence,
            conditional_independence_test_falsify=linear_dependence,
            max_num_permutations_falsify=NUM_PERMUTATIONS,
            mechanism_evaluation_kfolds=KFOLDS,
        ),
    )
    elapsed = time.time() - started
    print(f"[model] seconds = {elapsed:.1f}")

    show("[model] overall kl divergence", summary.overall_kl_divergence)
    for node in ("X0", "X1", "Y"):
        performance = summary.mechanism_performances[node]
        show(f"[model {node}] kl divergence", performance.kl_divergence or 0.0)
        show(f"[model {node}] crps", performance.crps or 0.0)
        show(f"[model {node}] mse", performance.mse or 0.0)
        show(f"[model {node}] nmse", performance.nmse or 0.0)
        show(f"[model {node}] r2", performance.r2 or 0.0)
        show(f"[model {node}] f1", performance.f1 or 0.0)
        show_int(
            f"[model {node}] total number of baselines",
            performance.total_number_baselines,
        )
        show_int(
            f"[model {node}] count of better baselines",
            performance.count_better_performance or 0,
        )
        show(
            f"[model {node}] best baseline performance",
            performance.best_baseline_performance or 0.0,
        )
        print(f"[model {node}] best baseline model = {performance.best_baseline_model}")
    for node, assumption in summary.pnl_assumptions.items():
        show(f"[model {node}] invertibility p-value", assumption[0])
        show_bool(f"[model {node}] invertibility rejected", assumption[1])


if __name__ == "__main__":
    main()
