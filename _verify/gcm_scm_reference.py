"""The upstream reference of the structural causal model layer of `dowhy.gcm`.

The script runs the upstream `dowhy.gcm.causal_mechanisms`,
`dowhy.gcm.causal_models`, `dowhy.gcm.fitting_sampling` and
`dowhy.gcm.stochastic_models` on the very fixtures of the upstream test file
`tests/gcm/test_fcms.py`, and prints the numbers the MoonBit port has to
reproduce.

The upstream package cannot be imported as it is, because its `__init__` pulls
in `causallearn`; the loader of `upstream_gcm.py` reads the modules straight
from their files instead. Three of the upstream modules are not known to that
loader, so this script registers them with it before loading them:

  * `dowhy.gcm.fitting_sampling` holds the upstream `fit` and `draw_samples`,
  * `dowhy.causal_graph` and `dowhy.causal_model` are imported by the
    constructor of `ProbabilisticCausalModel` itself.

The two latter modules are pulled in through the real package directories, to
which the stubbed packages of the loader are pointed. The upstream code of them
only serves to recognise a `CausalGraph` or a `CausalModel` that is handed over
as the graph of the model, so the printed numbers do not depend on them.

The fixtures are the ones of the upstream tests, with the global generator of
numpy seeded before every fixture, so that the printed numbers are
reproducible. The port draws its own noise, so its numbers differ slightly
from the printed ones; the two agree on the values the tests assert.

The logarithmic fixture of the post non-linear models uses the absolute values
of the draws, like the upstream test does: the logarithm of a negative number
is not a number, and the upstream model of the logarithm needs a positive
argument.

Usage:
    python _verify/gcm_scm_reference.py
"""

from __future__ import annotations

import os
import sys

import networkx as nx
import numpy as np
import pandas as pd
from scipy import stats

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import upstream_gcm  # noqa: E402
from upstream_gcm import load, upstream_root  # noqa: E402

# The seed of the global generator of numpy. It is set before every fixture, so
# that the numbers of one fixture do not depend on the fixtures before it.
SEED = 2024

# The number of rows of the fixtures of the upstream tests.
NUM_SAMPLES = 1000


def register_missing_modules() -> None:
    """Registers the upstream modules the loader does not know.

    The loader of `upstream_gcm.py` owns the list of the modules it reads, but
    it does not know the three modules this script needs. Its list is only
    extended here, the file itself is left alone.
    """
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
        print(f"  {label} = {repr(value.tolist())}")
    else:
        print(f"  {label} = {repr(float(value))}")  # type: ignore[arg-type]


def generate_data_with_categorical_input() -> pd.DataFrame:
    """The fixture of the upstream tests with a categorical input.

    This is the `_generate_data_with_categorical_input` of the upstream test
    file `tests/gcm/test_fcms.py`, copied over unchanged.
    """
    X0 = np.random.normal(0, 1, NUM_SAMPLES)
    X1 = np.random.choice(3, NUM_SAMPLES).astype(str)
    X2 = []

    for i in range(NUM_SAMPLES):
        tmp_value = 2 * X0[i]

        if X1[i] == "0":
            tmp_value -= 5
        elif X1[i] == "1":
            tmp_value += 10
        else:
            tmp_value += 5

        X2.append(tmp_value)

    return pd.DataFrame({"X0": X0, "X1": X1, "X2": X2})


def main() -> None:
    register_missing_modules()

    config = load("dowhy.gcm.config")
    # The progress bars of the upstream fitting would write to the standard
    # error stream and clutter the output of the reference.
    config.disable_progress_bars()

    # The `ml` package has to come first: the loader stubs the packages out, so
    # the `causal_mechanisms` module needs the prediction models already.
    ml = load("dowhy.gcm.ml")
    regression = load("dowhy.gcm.ml.regression")
    mechanisms = load("dowhy.gcm.causal_mechanisms")
    models = load("dowhy.gcm.causal_models")
    stochastic = load("dowhy.gcm.stochastic_models")
    fitting = load("dowhy.gcm.fitting_sampling")
    # The constructor of `ProbabilisticCausalModel` imports the two modules of
    # the wider package, which the stubbed packages do not reach.
    expose_upstream_packages()
    load("dowhy.causal_graph")
    load("dowhy.causal_model")

    print(f"SEED = {SEED}")

    # ------------------------------------------------------------------
    # A. The additive noise model on linear data.
    #
    # The upstream test `test_given_linear_data_when_fit_causal_graph_with_
    # linear_anm_then_learns_correct_coefficients` expects a coefficient of 2
    # and an intercept of 2.
    # ------------------------------------------------------------------
    np.random.seed(SEED)
    scm = models.ProbabilisticCausalModel(nx.DiGraph([("X0", "X1")]))
    scm.set_causal_mechanism("X0", stochastic.ScipyDistribution(stats.norm, loc=0, scale=1))
    scm.set_causal_mechanism("X1", mechanisms.AdditiveNoiseModel(prediction_model=ml.create_linear_regressor()))

    X0 = scm.causal_mechanism("X0").draw_samples(NUM_SAMPLES).squeeze()
    test_data = pd.DataFrame({"X0": X0, "X1": X0 * 2 + 2 + np.random.normal(0, 0.1, NUM_SAMPLES)})
    fitting.fit(scm, test_data)

    print("ANM_LINEAR")
    show("coefficient", scm.causal_mechanism("X1").prediction_model.sklearn_model.coef_)
    show("intercept", scm.causal_mechanism("X1").prediction_model.sklearn_model.intercept_)

    # ------------------------------------------------------------------
    # F. Drawing samples from the fitted model.
    #
    # The upstream test `test_given_linear_data_when_draw_samples_from_
    # fitted_anm_then_generates_correct_marginal_distribution` expects a mean
    # of 4 and a standard deviation of 0.1 at the parent value 1, and a mean
    # of 6 at the parent value 2.
    # ------------------------------------------------------------------
    np.random.seed(SEED)
    drawn_at_one = scm.causal_mechanism("X1").draw_samples(np.array([1] * NUM_SAMPLES))
    np.random.seed(SEED)
    drawn_at_two = scm.causal_mechanism("X1").draw_samples(np.array([2] * NUM_SAMPLES))
    print("ANM_LINEAR_DRAW_SAMPLES")
    show("drawn_mean_at_one", np.mean(drawn_at_one))
    show("drawn_std_at_one", np.std(drawn_at_one))
    show("drawn_mean_at_two", np.mean(drawn_at_two))
    show("drawn_std_at_two", np.std(drawn_at_two))

    # ------------------------------------------------------------------
    # B. The additive noise model with a categorical parent.
    #
    # The upstream test `test_given_categorical_input_data_when_fit_causal_
    # graph_with_linear_anm_then_learns_correct_coefficients` expects the
    # coefficients of the one-hot encoding of the categorical parent and an
    # intercept of 10/3.
    # ------------------------------------------------------------------
    np.random.seed(SEED)
    categorical_scm = models.StructuralCausalModel(nx.DiGraph([("X0", "X2"), ("X1", "X2")]))
    categorical_scm.set_causal_mechanism("X0", stochastic.ScipyDistribution(stats.norm, loc=0, scale=1))
    categorical_scm.set_causal_mechanism("X1", stochastic.EmpiricalDistribution())
    categorical_scm.set_causal_mechanism(
        "X2", mechanisms.AdditiveNoiseModel(prediction_model=ml.create_linear_regressor())
    )

    training_data = generate_data_with_categorical_input()
    fitting.fit(categorical_scm, data=training_data)

    print("ANM_CATEGORICAL")
    show("categorical_coefficients", categorical_scm.causal_mechanism("X2").prediction_model.sklearn_model.coef_)
    show("categorical_intercept", categorical_scm.causal_mechanism("X2").prediction_model.sklearn_model.intercept_)
    categorical_evaluation = categorical_scm.causal_mechanism("X2").evaluate(
        np.array([[2, "1"]], dtype=object), np.array([0])
    )
    show("categorical_evaluation", categorical_evaluation)

    # ------------------------------------------------------------------
    # C. The discrete additive noise model.
    #
    # The upstream test `test_given_discrete_target_data_when_fit_discrete_
    # additive_noise_model_then_behaves_as_expected` expects the noise of the
    # model of the random fixture and the rounded predictions of the model of
    # the small fixture.
    # ------------------------------------------------------------------
    np.random.seed(SEED)
    discrete_x = np.random.normal(0, 1, (NUM_SAMPLES, 2))
    discrete_x[discrete_x > 3] = 3
    discrete_x[discrete_x < -3] = -3
    discrete_y = np.round(np.sum(discrete_x, axis=1))

    discrete_model = mechanisms.DiscreteAdditiveNoiseModel(ml.create_linear_regressor())
    discrete_model.fit(discrete_x, discrete_y)
    discrete_noise = discrete_model.estimate_noise(np.array([0, 1, 2]), np.array([[-1, 1], [0, 0], [0, 1]]))

    rounded_x = np.array([0.1, 10.5, 20, 30.7, 40.3])
    rounded_y = np.floor(rounded_x)
    rounded_model = mechanisms.DiscreteAdditiveNoiseModel(ml.create_linear_regressor())
    rounded_model.fit(rounded_x, rounded_y)
    discrete_evaluate = rounded_model.evaluate(
        np.array([-100, -32.4, 0.4, 4, 9, 11, 30.1, 101.4, 0.9]), np.zeros(9)
    )

    print("DISCRETE_ANM")
    show("discrete_evaluate", discrete_evaluate)
    show("discrete_noise", discrete_noise)

    # ------------------------------------------------------------------
    # D. The post non-linear models.
    #
    # The upstream tests `test_given_simple_linear_data_when_fit_post_non_
    # linear_sem_with_invertible_identity_then_returns_expected_results` and
    # its exponential and logarithmic counterparts expect the noise of the
    # model to be the one of the fixture.
    # ------------------------------------------------------------------
    print("POST_NONLINEAR")
    for name, function, transform in (
        ("identity", regression.InvertibleIdentityFunction(), lambda x: x),
        ("exponential", regression.InvertibleExponentialFunction(), np.exp),
        ("logarithmic", regression.InvertibleLogarithmicFunction(), np.log),
    ):
        np.random.seed(SEED)
        parent = np.random.normal(0, 1, NUM_SAMPLES)
        noise = np.random.normal(0, 0.1, NUM_SAMPLES)
        if name == "logarithmic":
            # The upstream test takes the absolute values of the draws, because
            # the logarithm of a negative number is not a number.
            parent = np.abs(parent)
            noise = np.abs(noise)
        target = transform(2 * parent + noise)

        ground_truth = mechanisms.PostNonlinearModel(
            ml.create_linear_regressor_with_given_parameters(coefficients=np.array([2])),
            stochastic.EmpiricalDistribution(),
            function,
        )
        estimated_noise = ground_truth.estimate_noise(target, parent)
        show(f"{name}_noise_max_abs_error", np.max(np.abs(estimated_noise.reshape(-1) - noise)))
        show(f"{name}_evaluate", ground_truth.evaluate(np.array([2]), np.array([0])).squeeze())
        show(f"{name}_evaluate_with_noise", ground_truth.evaluate(np.array([2]), np.array([1])).squeeze())

        fitted = mechanisms.PostNonlinearModel(ml.create_linear_regressor(), stochastic.EmpiricalDistribution(), function)
        fitted.fit(parent, target)
        show(f"{name}_fitted_coefficient", fitted.prediction_model.sklearn_model.coef_)

    # ------------------------------------------------------------------
    # E. The classifier functional causal model.
    #
    # The upstream test `test_when_fit_classifier_fcm_with_categorical_inputs_
    # then_returns_expected_results` expects the probabilities of the class
    # "True" and a balanced split of the drawn samples.
    # ------------------------------------------------------------------
    np.random.seed(SEED)
    classifier_scm = models.StructuralCausalModel(nx.DiGraph([("X0", "X2"), ("X1", "X2")]))
    classifier_scm.set_causal_mechanism("X0", stochastic.ScipyDistribution(stats.norm, loc=0, scale=1))
    classifier_scm.set_causal_mechanism("X1", stochastic.EmpiricalDistribution())
    classifier_scm.set_causal_mechanism(
        "X2", mechanisms.ClassifierFCM(classifier_model=ml.create_logistic_regression_classifier())
    )

    classifier_data = generate_data_with_categorical_input()
    classifier_x2 = classifier_data["X2"].to_numpy()
    classifier_data["X2"] = (classifier_x2 > np.median(classifier_x2)).astype(str)
    fitting.fit(classifier_scm, classifier_data)

    classifier_fcm = classifier_scm.causal_mechanism("X2")
    print("CLASSIFIER_FCM")
    show("classifier_probabilities", classifier_fcm.estimate_probabilities(np.array([[2, "1"]], dtype=object)))
    classifier_test_data = classifier_data.to_numpy()
    np.random.seed(SEED)
    _, classifier_counts = np.unique(classifier_fcm.draw_samples(classifier_test_data[:, :2]), return_counts=True)
    show("classifier_class_counts", classifier_counts / NUM_SAMPLES)


if __name__ == "__main__":
    main()
