"""The upstream reference of the estimator test suites of the upstream.

The script runs the upstream `dowhy` on the very rows the port works on, for
the cases of the upstream estimator test files:

  * the propensity score matching estimator, the propensity score weighting
    estimator, the propensity score stratification estimator and the doubly
    robust estimator, with one and with two common causes, and with the two
    identifiers the upstream uses for them: the backdoor criterion and the
    complete adjustment criterion.
  * the doubly robust estimator with an instrument and with a binary outcome,
    which are the two other configurations of its upstream test file.

The rows of the port are replicated by `_verify/port_linear_dataset.py`, so
the upstream runs on the same rows and the two numbers can be compared
directly.  The upstream package cannot be imported as it is, because its
`__init__` pulls in `causallearn`, so the modules are read straight from their
files with the loader of `upstream_gcm.py`.

Usage:
    python _verify/estimator_suite_reference.py
"""

from __future__ import annotations

import os
import sys

import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from port_linear_dataset import binary_treatment_dataset  # noqa: E402
from upstream_gcm import load  # noqa: E402

# The modules of the upstream, in the order they have to be loaded in.
load("dowhy.utils.ordered_set")
load("dowhy.utils.api")
load("dowhy.utils.encoding")
load("dowhy.utils.graph_operations")
load("dowhy.graph")
load("dowhy.causal_identifier.adjustment_set")
load("dowhy.causal_identifier.identified_estimand")
load("dowhy.causal_identifier.efficient_backdoor")
auto_identifier = load("dowhy.causal_identifier.auto_identifier")
load("dowhy.causal_identifier")
load("dowhy.causal_estimator")
load("dowhy.causal_estimators.regression_estimator")
load("dowhy.causal_estimators.linear_regression_estimator")
load("dowhy.causal_estimators.propensity_score_estimator")
load("dowhy.causal_estimators.propensity_score_matching_estimator")
load("dowhy.causal_estimators.propensity_score_weighting_estimator")
load("dowhy.causal_estimators.propensity_score_stratification_estimator")
load("dowhy.causal_estimators.doubly_robust_estimator")

EstimandType = auto_identifier.EstimandType
identify_effect_auto = auto_identifier.identify_effect_auto
build_graph_from_str = sys.modules["dowhy.graph"].build_graph_from_str

PropensityScoreMatchingEstimator = sys.modules[
    "dowhy.causal_estimators.propensity_score_matching_estimator"
].PropensityScoreMatchingEstimator
PropensityScoreWeightingEstimator = sys.modules[
    "dowhy.causal_estimators.propensity_score_weighting_estimator"
].PropensityScoreWeightingEstimator
PropensityScoreStratificationEstimator = sys.modules[
    "dowhy.causal_estimators.propensity_score_stratification_estimator"
].PropensityScoreStratificationEstimator
DoublyRobustEstimator = sys.modules[
    "dowhy.causal_estimators.doubly_robust_estimator"
].DoublyRobustEstimator

# The number of rows of the upstream test suite.
NUM_ROWS = 100000

# The seed of the generator of the port, the seed of the estimator test
# suite of the port.
SEED = 44


def estimate_of(
    data: dict,
    estimator_class: type,
    identifier_method: str,
) -> float:
    """The estimate of the upstream estimator on the rows of the port."""
    frame = pd.DataFrame(
        {name: data["columns"][name] for name in data["column_order"]},
    )
    graph = build_graph_from_str(data["gml_graph"])
    estimand = identify_effect_auto(
        graph,
        observed_nodes=list(frame.columns),
        action_nodes=data["treatment_names"],
        outcome_nodes=[data["outcome_name"]],
        estimand_type=EstimandType.NONPARAMETRIC_ATE,
    )
    estimand.set_identifier_method(identifier_method)
    estimator = estimator_class(identified_estimand=estimand)
    estimator.fit(frame, effect_modifier_names=[])
    estimate = estimator.estimate_effect(
        frame,
        control_value=0,
        treatment_value=1,
        target_units="ate",
    )
    return float(estimate.value)


def report(
    name: str,
    data: dict,
    estimator_class: type,
    identifier_method: str,
    tolerance: float,
) -> None:
    """The estimate of the upstream and the share of the error."""
    truth = data["ate"]
    try:
        value = estimate_of(data, estimator_class, identifier_method)
    except Exception as error:  # noqa: BLE001
        print(f"  {name}: failed: {error}")
        return
    error = abs(value - truth)
    share = error / abs(truth)
    verdict = "ok" if share < tolerance else "OVER"
    print(
        f"  {name}: {value!r} truth={truth!r} error={error!r} "
        f"share={share:.4f} tolerance={tolerance} {verdict}"
    )


def main() -> None:
    for num_common_causes in (1, 2):
        print()
        print("=" * 72)
        print(f"{num_common_causes} common causes")
        print("=" * 72)
        data = binary_treatment_dataset(SEED, NUM_ROWS, num_common_causes)
        for identifier_method in ("backdoor", "general_adjustment"):
            report(
                f"psm {identifier_method}",
                data,
                PropensityScoreMatchingEstimator,
                identifier_method,
                0.3,
            )
            report(
                f"psw {identifier_method}",
                data,
                PropensityScoreWeightingEstimator,
                identifier_method,
                0.4,
            )
            report(
                f"pss {identifier_method}",
                data,
                PropensityScoreStratificationEstimator,
                identifier_method,
                0.1,
            )
            report(
                f"dr {identifier_method}",
                data,
                DoublyRobustEstimator,
                identifier_method,
                0.1 if identifier_method == "backdoor" else 0.2,
            )
        with_instrument = binary_treatment_dataset(
            SEED, NUM_ROWS, num_common_causes, num_instruments=1
        )
        report(
            "dr backdoor instrument",
            with_instrument,
            DoublyRobustEstimator,
            "backdoor",
            0.1,
        )
        binary = binary_treatment_dataset(
            SEED, NUM_ROWS, num_common_causes, outcome_is_binary=True
        )
        report(
            "dr general_adjustment binary outcome",
            binary,
            DoublyRobustEstimator,
            "general_adjustment",
            0.2,
        )


if __name__ == "__main__":
    main()
