"""What the upstream does with the binary treatment cases of the dummy outcome refuter.

`tests/causal_refuters/test_dummy_outcome_refuter.py` drives ten binary treatment
cases through the `SimpleRefuter` harness of `tests/causal_refuters/base.py`.  The
port mirrors all ten.  This script runs all ten and prints what the upstream does
with each one:

  * the seven cases whose assertion holds come back with a refutation,
  * the case of the custom model with a noise, which the upstream marks `xfail`,
    comes back with an effect of 0.513615, which does not clear the tolerance of
    0.2 of the case, and
  * the case of the permuted custom model, which the upstream marks `xfail` as
    well, raises on numpy 2 before it reaches its assertion.

The script is the evidence for the cases of the port that mirror a failure of the
upstream instead of a number of the upstream.

Two facts of the upstream are the reason the port can mirror the cases:

  * the binary treatment of `dowhy.datasets.linear_dataset` is cast to the dtype
    of a boolean, so the `preprocess_data_by_treatment` of the refuter groups it
    by its values and a binary treatment has two buckets, and
  * the data set of the upstream carries an instrument, so the covariates of a
    bucket are the confounder and the instrument.  The custom model of the
    upstream adds the first covariate to twice the second one, so it needs the
    two of them.

`dowhy.datasets.linear_dataset` is broken on numpy 2.5.1 -- its
`np.vectorize(convert_to_binary)` builds a one element array per row -- so the
binary treatment is generated through the shim of
`_verify/notebooks_reference.py`, which draws the same number and gives it to the
vectorize as a number.

Usage:

    python _verify/dummy_outcome_binary_reference.py
"""

from __future__ import annotations

import math
import sys

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

import numpy as np  # noqa: E402

import dowhy.datasets  # noqa: E402
from dowhy import CausalModel  # noqa: E402


def convert_to_binary(x, stochastic=True):
    """The binary treatment of the upstream, with the number it draws."""
    p = 1 / (1 + math.exp(-x))
    if stochastic:
        return np.random.choice([0, 1], p=[1 - p, p])
    return int(p > 0.5)


dowhy.datasets.convert_to_binary = convert_to_binary


def simple_linear_outcome_model(x_train, output_train):
    """The custom model of the upstream file: the first column plus twice the
    second one plus three, fitted by nothing."""
    return lambda x: x[:, 0] + 2 * x[:, 1] + 3


# The ten binary treatment cases of the upstream file: the label, the tolerance,
# the estimator, the transformation list and the number of the samples.
CASES = [
    (
        "default_binary_treatment",
        0.1,
        "backdoor.propensity_score_matching",
        None,
    ),
    (
        "randomly_generated_binary_treatment",
        0.05,
        "backdoor.propensity_score_matching",
        [("zero", ""), ("noise", {"std_dev": 1})],
    ),
    (
        "permute_data_binary_treatment",
        0.1,
        "backdoor.linear_regression",
        [("permute", {"permute_fraction": 1})],
    ),
    (
        "custom_function_with_noise_binary_treatment",
        0.2,
        "backdoor.linear_regression",
        [(simple_linear_outcome_model, {}), ("noise", {"std_dev": 1})],
    ),
    (
        "custom_function_with_permute_binary_treatment",
        0.2,
        "backdoor.propensity_score_matching",
        [
            ("permute", {"permute_fraction": 0.5}),
            (simple_linear_outcome_model, {}),
            ("noise", {"std_dev": 1}),
        ],
    ),
    (
        "internal_linear_regression_binary_treatment",
        0.2,
        "backdoor.propensity_score_matching",
        [("linear_regression", {}), ("zero", ""), ("noise", {"std_dev": 1})],
    ),
    (
        "internal_knn_binary_treatment",
        0.2,
        "backdoor.propensity_score_matching",
        [("knn", {"n_neighbors": 5}), ("zero", ""), ("noise", {"std_dev": 1})],
    ),
    (
        "internal_svm_binary_treatment",
        0.1,
        "backdoor.propensity_score_matching",
        [("svm", {"C": 1, "epsilon": 0.2}), ("zero", ""), ("noise", {"std_dev": 1})],
    ),
    (
        "internal_random_forest_binary_treatment",
        0.1,
        "backdoor.propensity_score_matching",
        [
            ("random_forest", {"max_depth": 20}),
            ("zero", ""),
            ("noise", {"std_dev": 1}),
        ],
    ),
    (
        "internal_neural_network_binary_treatment",
        0.1,
        "backdoor.propensity_score_matching",
        [
            (
                "neural_network",
                {"solver": "lbfgs", "alpha": 1e-5, "hidden_layer_sizes": (5, 2)},
            ),
            ("zero", ""),
            ("noise", {"std_dev": 1}),
        ],
    ),
]

NUM_SAMPLES = 1000


def run(label, tolerance, estimator_method, transformations):
    np.random.seed(0)
    data = dowhy.datasets.linear_dataset(
        beta=10,
        num_common_causes=1,
        num_instruments=1,
        num_samples=NUM_SAMPLES,
        treatment_is_binary=True,
    )
    model = CausalModel(
        data=data["df"],
        treatment=data["treatment_name"],
        outcome=data["outcome_name"],
        graph=data["gml_graph"],
        proceed_when_unidentifiable=True,
        test_significance=None,
    )
    estimand = model.identify_effect(method_name="exhaustive-search")
    estimand.set_identifier_method("backdoor")
    estimate = model.estimate_effect(
        identified_estimand=estimand,
        method_name=estimator_method,
        test_significance=None,
    )
    kwargs = {"num_simulations": 2}
    if transformations is not None:
        kwargs["transformation_list"] = transformations
    # The covariates of a bucket are the adjustment set of the estimand and its
    # instruments, the way the `_variables_of_interest` of the upstream builds
    # them.
    chosen = estimand.get_adjustment_set() + estimand.instrumental_variables
    try:
        refs = model.refute_estimate(
            estimand, estimate, method_name="dummy_outcome_refuter", **kwargs
        )
    except Exception as exc:  # noqa: BLE001
        print(
            "{:55s} raised {}: {}".format(label, type(exc).__name__, exc),
        )
        return
    ref = refs[0]
    error = abs(ref.new_effect)
    print(
        "{:55s} ate={: .4f} covariates={} refutations={} new_effect={: .6f} "
        "tolerance={:.2f} holds={}".format(
            label,
            estimate.value,
            chosen,
            len(refs),
            ref.new_effect,
            tolerance,
            error < tolerance,
        )
    )


print("=" * 78)
print("the ten binary treatment cases of the upstream, on {} rows".format(NUM_SAMPLES))
print("=" * 78)
for case in CASES:
    run(*case)
