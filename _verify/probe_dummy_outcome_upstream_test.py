"""Run the upstream's own continuous-treatment internal-estimator dummy outcome
test and report what happens.

`tests/causal_refuters/test_dummy_outcome_refuter.py` runs, for a continuous
treatment and the `iv.instrumental_variable` estimator,

    refute_estimate(..., method_name="dummy_outcome_refuter",
                    transformation_list=[("linear_regression", {}),
                                         ("zero", ""), ("noise", {"std_dev": 1})])

That transformation list carries an estimator, so the refuter takes its
bucketing branch.  This script runs the very same call on the upstream's own
`linear_dataset` and prints the outcome, so the reachability of the branch is
measured rather than reasoned about.

Run: python _verify/probe_dummy_outcome_upstream_test.py
"""

import sys

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

import dowhy.datasets
from dowhy import CausalModel


def run(label, transformations, binary):
    data = dowhy.datasets.linear_dataset(
        beta=10,
        num_common_causes=1,
        num_instruments=1,
        num_samples=1000,
        treatment_is_binary=binary,
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
    estimand.set_identifier_method("iv" if "iv" in label else "backdoor")
    estimate = model.estimate_effect(
        identified_estimand=estimand,
        method_name="iv.instrumental_variable" if "iv" in label else "backdoor.linear_regression",
        test_significance=None,
    )
    print()
    print("=" * 70)
    print(label, "| treatment_is_binary =", binary)
    print("=" * 70)
    print("ate:", estimate.value)
    try:
        refs = model.refute_estimate(
            estimand,
            estimate,
            method_name="dummy_outcome_refuter",
            transformation_list=transformations,
            num_simulations=2,
        )
        print("returned", type(refs).__name__, "of length", len(refs))
        for i, ref in enumerate(refs):
            print("  [{}] estimated={: .6f} new={: .6f}".format(i, ref.estimated_effect, ref.new_effect))
    except Exception as exc:  # noqa: BLE001
        print("raised {}: {}".format(type(exc).__name__, exc))


# the continuous treatment of the upstream tests is the only one that the
# broken `convert_to_binary` of the tree does not break first
run(
    "iv + internal linear_regression, continuous",
    [("linear_regression", {}), ("zero", ""), ("noise", {"std_dev": 1})],
    False,
)
run(
    "iv + internal knn, continuous",
    [("knn", {"n_neighbors": 5}), ("zero", ""), ("noise", {"std_dev": 1})],
    False,
)
