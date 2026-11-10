"""Print the numbers the upstream dummy outcome refuter produces for the cases
the port mirrors.

`tests/causal_refuters/test_dummy_outcome_refuter.py` drives every case through
the `SimpleRefuter` harness of `tests/causal_refuters/base.py`, which asserts
`abs(ref.new_effect - 0) < error_tolerance` on the first refutation of the list.
This script runs the same cases and prints

  * how many refutations came back,
  * the new effect of each of them,
  * the tolerance of the upstream case and whether it holds.

`dowhy.datasets.linear_dataset` is broken on numpy 2.5.1 — its
`np.vectorize(convert_to_binary)` builds a one element array per row — so the
binary treatment of the upstream cases cannot be generated through the upstream
function here. The continuous treatment is generated through it, because that is
the path the broken call does not take, and the binary cases are reported as
unavailable rather than replaced with a hand built frame.

Run: python _verify/dummy_outcome_reference.py
"""

import sys

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

import numpy as np

import dowhy.datasets
from dowhy import CausalModel

# The cases of the upstream file whose transformation list the port can build:
# (label, tolerance, estimator, transformation list, num_simulations, binary,
# num_samples).
CASES = [
    (
        "default_continuous_treatment",
        0.03,
        "iv.instrumental_variable",
        None,
        2,
        False,
        20000,
    ),
    (
        "randomly_generated_continuous_treatment",
        0.05,
        "iv.instrumental_variable",
        [("zero", ""), ("noise", {"std_dev": 1})],
        2,
        False,
        20000,
    ),
    (
        "permute_data_continuous_treatment",
        0.03,
        "iv.instrumental_variable",
        [("permute", {"permute_fraction": 1})],
        2,
        False,
        20000,
    ),
    (
        "internal_linear_regression_continuous_treatment",
        0.01,
        "iv.instrumental_variable",
        [("linear_regression", {}), ("zero", ""), ("noise", {"std_dev": 1})],
        2,
        False,
        20000,
    ),
    (
        "internal_knn_continuous_treatment",
        0.2,
        "iv.instrumental_variable",
        [("knn", {"n_neighbors": 5}), ("zero", ""), ("noise", {"std_dev": 1})],
        2,
        False,
        20000,
    ),
    (
        "internal_random_forest_continuous_treatment",
        0.01,
        "iv.instrumental_variable",
        [
            ("random_forest", {"max_depth": 20}),
            ("zero", ""),
            ("noise", {"std_dev": 1}),
        ],
        2,
        False,
        20000,
    ),
    (
        "internal_neural_network_continuous_treatment",
        0.01,
        "iv.instrumental_variable",
        [
            (
                "neural_network",
                {"solver": "lbfgs", "alpha": 1e-5, "hidden_layer_sizes": (5, 2)},
            ),
            ("zero", ""),
            ("noise", {"std_dev": 1}),
        ],
        2,
        False,
        20000,
    ),
    (
        "internal_svm_continuous_treatment",
        0.01,
        "iv.instrumental_variable",
        [("svm", {"C": 1, "epsilon": 0.2}), ("zero", ""), ("noise", {"std_dev": 1})],
        2,
        False,
        10000,
    ),
]


def simple_linear_outcome_model(x_train, output_train):
    """The custom model of the upstream file: the first column plus twice the
    second one plus three, fitted by nothing."""
    return lambda x: x[:, 0] + 2 * x[:, 1] + 3


def run(
    label,
    tolerance,
    estimator_method,
    transformations,
    num_simulations,
    binary,
    num_samples=20000,
):
    try:
        data = dowhy.datasets.linear_dataset(
            beta=10,
            num_common_causes=1,
            num_instruments=1,
            num_samples=num_samples,
            treatment_is_binary=binary,
        )
    except Exception as exc:  # noqa: BLE001
        print("{:55s} unavailable: {}: {}".format(label, type(exc).__name__, exc))
        return

    model = CausalModel(
        data=data["df"],
        treatment=data["treatment_name"],
        outcome=data["outcome_name"],
        graph=data["gml_graph"],
        proceed_when_unidentifiable=True,
        test_significance=None,
    )
    estimand = model.identify_effect(method_name="exhaustive-search")
    estimand.set_identifier_method("iv" if estimator_method.startswith("iv") else "backdoor")
    estimate = model.estimate_effect(
        identified_estimand=estimand,
        method_name=estimator_method,
        test_significance=None,
    )

    kwargs = {"num_simulations": num_simulations}
    if transformations is not None:
        kwargs["transformation_list"] = transformations
    try:
        refs = model.refute_estimate(
            estimand, estimate, method_name="dummy_outcome_refuter", **kwargs
        )
    except Exception as exc:  # noqa: BLE001
        print("{:55s} raised: {}: {}".format(label, type(exc).__name__, exc))
        return

    print(
        "{:55s} ate={: .4f} tolerance={:.2f} refutations={}".format(
            label, estimate.value, tolerance, len(refs)
        )
    )
    for i, ref in enumerate(refs):
        print(
            "    [{}] new_effect={: .6f} |new_effect| < tolerance -> {}".format(
                i, ref.new_effect, abs(ref.new_effect) < tolerance
            )
        )


print("=" * 78)
print("the upstream cases the port mirrors, on 20000 rows")
print("the case of the support vector regressor runs on the ten thousand rows of the")
print("upstream case, because the regressor is fitted once per bucket and per simulation")
print("=" * 78)
for case in CASES:
    run(*case)

print()
print("=" * 78)
print("the two custom model cases")
print("=" * 78)
run(
    "custom_function_with_noise_continuous_treatment",
    0.2,
    "iv.instrumental_variable",
    [(simple_linear_outcome_model, {}), ("noise", {"std_dev": 1})],
    2,
    False,
)
run(
    "custom_function_with_permute_continuous_treatment",
    0.2,
    "backdoor.linear_regression",
    [
        ("permute", {"permute_fraction": 0.5}),
        (simple_linear_outcome_model, {}),
        ("noise", {"std_dev": 1}),
    ],
    2,
    False,
)

print()
print("=" * 78)
print("why the binary treatment cases cannot be generated here")
print("=" * 78)
try:
    dowhy.datasets.linear_dataset(
        beta=10,
        num_common_causes=1,
        num_instruments=1,
        num_samples=1000,
        treatment_is_binary=True,
    )
    print("the binary dataset was generated")
except Exception as exc:  # noqa: BLE001
    print("{}: {}".format(type(exc).__name__, exc))
