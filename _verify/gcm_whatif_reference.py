"""The upstream reference of the what-if layer of `dowhy.gcm`.

The script runs the upstream `dowhy.gcm.whatif` and `dowhy.gcm._noise` on the
very fixtures of the upstream test file `tests/gcm/test_whatif.py`, and prints
the numbers the MoonBit port has to reproduce:

  * the interventional samples of the simple probabilistic causal model of the
    upstream tests, for an atomic, a conditional, a multiple and a
    data-less intervention,
  * the counterfactual samples of that model, both recovered from the observed
    data and computed from a given noise,
  * the average causal effect of a fitted model, for a continuous and for a
    binary target,
  * the noise of the model and the data of the model.

The upstream package cannot be imported as it is, because its `__init__` pulls
in `causallearn`; the loader of `upstream_gcm.py` reads the modules straight
from their files instead. Five of the upstream modules are not known to that
loader, so this script registers them with it before loading them:

  * `dowhy.gcm.whatif` holds the upstream `interventional_samples`,
    `counterfactual_samples` and `average_causal_effect`,
  * `dowhy.gcm._noise` holds the upstream `compute_noise_from_data` and
    `compute_data_from_noise`,
  * `dowhy.gcm.fitting_sampling` holds the upstream `fit` and `draw_samples`,
  * `dowhy.causal_graph` and `dowhy.causal_model` are imported by the
    constructor of `ProbabilisticCausalModel` itself.

The two latter modules are pulled in through the real package directories, to
which the stubbed packages of the loader are pointed. The upstream code of them
only serves to recognise a `CausalGraph` or a `CausalModel` that is handed over
as the graph of the model, so the printed numbers do not depend on them.

The global generator of numpy is seeded with `SEED` before every fixture, so
that the numbers of one fixture do not depend on the fixtures before it and
the printed values are reproducible. The port draws its own noise, so its
numbers differ slightly from the printed ones; the two agree on the values the
tests assert.

Usage:
    python _verify/gcm_whatif_reference.py
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

# The seed of the global generator of numpy. It is set before every fixture, so
# that the numbers of one fixture do not depend on the fixtures before it.
SEED = 2024

# The number of rows of the fixture of the upstream tests.
NUM_SAMPLES = 10000

np.random.seed(SEED)


def register_missing_modules() -> None:
    """Registers the upstream modules the loader does not know.

    The loader of `upstream_gcm.py` owns the list of the modules it reads, but
    it does not know the five modules this script needs. Its list is only
    extended here, the file itself is left alone.
    """
    upstream_gcm._PATHS["dowhy.gcm.whatif"] = "gcm/whatif.py"
    upstream_gcm._PATHS["dowhy.gcm._noise"] = "gcm/_noise.py"
    upstream_gcm._PATHS["dowhy.gcm.fitting_sampling"] = "gcm/fitting_sampling.py"
    upstream_gcm._PATHS["dowhy.causal_graph"] = "causal_graph.py"
    upstream_gcm._PATHS["dowhy.causal_model"] = "causal_model.py"


def expose_upstream_packages() -> None:
    """Points the stubbed packages at the real directories of the upstream.

    The loader stubs the packages of the upstream out, so that the modules of
    `dowhy.gcm` can be read without the `causallearn` dependency of the real
    package. The constructor of `ProbabilisticCausalModel` imports
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


def show(label: str, value: object) -> None:
    """Prints a value with its label and the full precision of a double."""
    if isinstance(value, np.ndarray):
        if value.dtype.kind in "biufc":
            # The intervened column of the upstream comes back with an integer
            # dtype, because the upstream intervention of the tests returns the
            # integer `10`. The values are printed as doubles nevertheless, since
            # that is what the port computes.
            value = value.astype(np.float64)
        print(f"  {label} = {repr(value.tolist())}")
    else:
        print(f"  {label} = {repr(float(value))}")  # type: ignore[arg-type]


def create_and_fit_simple_probabilistic_causal_model(models, mechanisms, stochastic, ml, fitting):
    """The fixture of the upstream tests.

    This is the `_create_and_fit_simple_probabilistic_causal_model` of the
    upstream test file `tests/gcm/test_whatif.py`, copied over unchanged: the
    graph `X0 -> X1`, `X0 -> X2`, `X2 -> X3`, an empirical distribution for the
    root node `X0` and additive noise models with a linear regressor for the
    other nodes.
    """
    X0 = np.random.uniform(-1, 1, NUM_SAMPLES)
    X1 = 2 * X0 + np.random.normal(0, 0.1, NUM_SAMPLES)
    X2 = 0.5 * X0 + np.random.normal(0, 0.1, NUM_SAMPLES)
    X3 = 0.5 * X2 + np.random.normal(0, 0.1, NUM_SAMPLES)

    original_observations = pd.DataFrame({"X0": X0, "X1": X1, "X2": X2, "X3": X3})

    causal_model = models.InvertibleStructuralCausalModel(nx.DiGraph([("X0", "X1"), ("X0", "X2"), ("X2", "X3")]))
    causal_model.set_causal_mechanism("X0", stochastic.EmpiricalDistribution())
    causal_model.set_causal_mechanism("X1", mechanisms.AdditiveNoiseModel(prediction_model=ml.create_linear_regressor()))
    causal_model.set_causal_mechanism("X2", mechanisms.AdditiveNoiseModel(prediction_model=ml.create_linear_regressor()))
    causal_model.set_causal_mechanism("X3", mechanisms.AdditiveNoiseModel(prediction_model=ml.create_linear_regressor()))

    fitting.fit(causal_model, original_observations)

    return causal_model, original_observations


def create_and_fit_treatment_model(models, auto, fitting, binary_target: bool):
    """The fixture of the upstream tests of the average causal effect.

    This is the fixture of `test_given_continuous_target_when_estimate_average_
    causal_effect_then_return_expected_result` and of its binary counterpart
    `test_given_binary_target_when_estimate_average_causal_effect_then_return_
    expected_result` of the upstream test file `tests/gcm/test_whatif.py`. The
    mechanisms are assigned by the upstream `auto.assign_causal_mechanisms` with
    the quality `GOOD`, and then the model is fitted.
    """
    T = np.random.choice(2, 1000, replace=True)
    X0 = np.random.normal(0, 0.2, 1000) + T
    X1 = np.random.normal(0, 0.2, 1000) + 0.5 * T
    if binary_target:
        Y = ((X0 + X1 + np.random.normal(0, 0.1, 1000)) >= 1.5).astype(str)
    else:
        Y = X0 + X1 + np.random.normal(0, 0.1, 1000)

    data = pd.DataFrame(dict(T=T, X0=X0, X1=X1, Y=Y))

    causal_model = models.ProbabilisticCausalModel(nx.DiGraph([("T", "X0"), ("T", "X1"), ("X0", "Y"), ("X1", "Y")]))
    auto.assign_causal_mechanisms(causal_model, data, auto.AssignmentQuality.GOOD)
    fitting.fit(causal_model, data)

    return causal_model


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
    ml = load("dowhy.gcm.ml")
    regression = load("dowhy.gcm.ml.regression")
    mechanisms = load("dowhy.gcm.causal_mechanisms")
    models = load("dowhy.gcm.causal_models")
    stochastic = load("dowhy.gcm.stochastic_models")
    fitting = load("dowhy.gcm.fitting_sampling")
    noise = load("dowhy.gcm._noise")
    whatif = load("dowhy.gcm.whatif")
    auto = load("dowhy.gcm.auto")
    # The constructor of `ProbabilisticCausalModel` imports the two modules of
    # the wider package, which the stubbed packages do not reach.
    expose_upstream_packages()
    load("dowhy.causal_graph")
    load("dowhy.causal_model")

    print(f"SEED = {SEED}")

    # ------------------------------------------------------------------
    # The simple probabilistic causal model of the upstream tests.
    # ------------------------------------------------------------------
    np.random.seed(SEED)
    causal_model, _training_observations = create_and_fit_simple_probabilistic_causal_model(
        models, mechanisms, stochastic, ml, fitting
    )

    observed_row = pd.DataFrame({"X0": [0], "X1": [1], "X2": [2], "X3": [3]})

    # ------------------------------------------------------------------
    # A.1. The atomic intervention of the upstream test.
    #
    # The upstream test `test_given_atomic_intervention_with_specific_input_
    # when_draw_interventional_samples_then_return_correct_sample_values`
    # expects 0, 1, 10 and a value of about 5.
    # ------------------------------------------------------------------
    np.random.seed(SEED)
    atomic = whatif.interventional_samples(
        causal_model, dict(X2=lambda x: np.array(10)), observed_data=observed_row
    )
    print("INTERVENTIONAL_ATOMIC")
    for node in ("X0", "X1", "X2", "X3"):
        show(node, atomic[node].to_numpy().squeeze())

    # ------------------------------------------------------------------
    # A.2. The conditional intervention of the upstream test.
    #
    # The upstream test `test_given_conditional_intervention_with_specific_
    # input_when_draw_interventional_samples_then_return_correct_sample_
    # values` expects 0, 1, about 12 and about 6.
    # ------------------------------------------------------------------
    np.random.seed(SEED)
    conditional = whatif.interventional_samples(
        causal_model, dict(X2=lambda x: x + 10), observed_data=observed_row
    )
    print("INTERVENTIONAL_CONDITIONAL")
    for node in ("X0", "X1", "X2", "X3"):
        show(node, conditional[node].to_numpy().squeeze())

    # ------------------------------------------------------------------
    # A.3. The multiple atomic intervention of the upstream test.
    #
    # The upstream test `test_given_multiple_atomic_intervention_with_specific_
    # input_when_draw_interventional_samples_then_return_correct_sample_values`
    # expects 10, about 20, about 10 and about 5.
    # ------------------------------------------------------------------
    np.random.seed(SEED)
    multiple = whatif.interventional_samples(
        causal_model, dict(X0=lambda x: 10, X2=lambda x: x + 5), observed_data=observed_row
    )
    print("INTERVENTIONAL_MULTIPLE_ATOMIC")
    for node in ("X0", "X1", "X2", "X3"):
        show(node, multiple[node].to_numpy().squeeze())

    # ------------------------------------------------------------------
    # A.4. The atomic intervention without observed data.
    #
    # The upstream test `test_given_atomic_intervention_without_specific_input_
    # when_draw_interventional_samples_then_return_correct_sample_values`
    # expects the ten values of `X2` to be 10.
    # ------------------------------------------------------------------
    np.random.seed(SEED)
    without_data = whatif.interventional_samples(
        causal_model, dict(X2=lambda x: np.array(10)), num_samples_to_draw=10
    )
    print("INTERVENTIONAL_WITHOUT_DATA")
    show("X2", without_data["X2"].to_numpy())
    show("X1_mean", np.mean(without_data["X1"].to_numpy()))
    show("X1_std", np.std(without_data["X1"].to_numpy()))

    # ------------------------------------------------------------------
    # A.5. The conditional intervention without observed data.
    #
    # The upstream test `test_given_conditional_intervention_without_specific_
    # input_when_draw_interventional_samples_then_return_correct_sample_values`
    # expects the mean of `X2` to be the mean of the training data plus 10.
    # ------------------------------------------------------------------
    np.random.seed(SEED)
    average = whatif.interventional_samples(
        causal_model, dict(X2=lambda x: x + 10), num_samples_to_draw=10
    )
    print("INTERVENTIONAL_AVERAGE")
    show("X2_mean", np.mean(average["X2"].to_numpy()))
    show("X1_mean", np.mean(average["X1"].to_numpy()))

    # ------------------------------------------------------------------
    # B.1. The counterfactual of the observed data.
    #
    # The upstream test `test_given_observed_sample_when_estimate_counterfactual_
    # then_returns_correct_sample_values` expects 1, 3, 2 and about 3.5.
    # ------------------------------------------------------------------
    np.random.seed(SEED)
    counterfactual_observed = whatif.counterfactual_samples(
        causal_model,
        dict(X2=lambda x: 2),
        observed_data=pd.DataFrame({"X0": [1], "X1": [3], "X2": [3], "X3": [4]}),
    )
    print("COUNTERFACTUAL_FROM_OBSERVED")
    for node in ("X0", "X1", "X2", "X3"):
        show(node, counterfactual_observed[node].to_numpy().squeeze())

    # ------------------------------------------------------------------
    # B.2. The counterfactual of a given noise.
    #
    # The upstream test `test_given_noise_sample_when_estimate_counterfactual_
    # then_returns_correct_sample_values` expects 1, about 4, 2 and about 5.
    # ------------------------------------------------------------------
    np.random.seed(SEED)
    counterfactual_noise = whatif.counterfactual_samples(
        causal_model,
        dict(X2=lambda x: 2),
        noise_data=pd.DataFrame({"X0": [1], "X1": [2], "X2": [3], "X3": [4]}),
    )
    print("COUNTERFACTUAL_FROM_NOISE")
    for node in ("X0", "X1", "X2", "X3"):
        show(node, counterfactual_noise[node].to_numpy().squeeze())

    # ------------------------------------------------------------------
    # C.1. The average causal effect of a continuous target.
    #
    # The upstream test `test_given_continuous_target_when_estimate_average_
    # causal_effect_then_return_expected_result` expects about 1.5.
    # ------------------------------------------------------------------
    np.random.seed(SEED)
    continuous_model = create_and_fit_treatment_model(models, auto, fitting, binary_target=False)
    np.random.seed(SEED)
    continuous_effect = whatif.average_causal_effect(
        continuous_model,
        "Y",
        interventions_alternative={"T": lambda _ : 1},
        interventions_reference={"T": lambda _ : 0},
        num_samples_to_draw=1000,
    )
    print("AVERAGE_CAUSAL_EFFECT_CONTINUOUS")
    show("ace", continuous_effect)

    # ------------------------------------------------------------------
    # C.2. The average causal effect of a binary target.
    #
    # The upstream test `test_given_binary_target_when_estimate_average_causal_
    # effect_then_return_expected_result` expects about 0.5.
    # ------------------------------------------------------------------
    np.random.seed(SEED)
    binary_model = create_and_fit_treatment_model(models, auto, fitting, binary_target=True)
    np.random.seed(SEED)
    binary_effect = whatif.average_causal_effect(
        binary_model,
        "Y",
        interventions_alternative={"T": lambda _ : 1},
        interventions_reference={"T": lambda _ : 0},
        num_samples_to_draw=1000,
    )
    print("AVERAGE_CAUSAL_EFFECT_BINARY")
    show("ace", binary_effect)

    # ------------------------------------------------------------------
    # D.1. The noise of the model, recovered from the observed data.
    # ------------------------------------------------------------------
    np.random.seed(SEED)
    computed_noise = noise.compute_noise_from_data(
        causal_model, pd.DataFrame({"X0": [1], "X1": [3], "X2": [3], "X3": [4]})
    )
    print("NOISE_FROM_DATA")
    for node in ("X0", "X1", "X2", "X3"):
        show(node, computed_noise[node].to_numpy().squeeze())

    # ------------------------------------------------------------------
    # D.2. The data of the model, computed from a given noise.
    # ------------------------------------------------------------------
    np.random.seed(SEED)
    computed_data = noise.compute_data_from_noise(
        causal_model, pd.DataFrame({"X0": [1], "X1": [2], "X2": [3], "X3": [4]})
    )
    print("DATA_FROM_NOISE")
    for node in ("X0", "X1", "X2", "X3"):
        show(node, computed_data[node].to_numpy().squeeze())


if __name__ == "__main__":
    main()
