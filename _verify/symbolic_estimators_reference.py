"""The symbolic estimators of the upstream.

The script fits every estimator of the upstream that builds a symbolic
estimator and prints the string it builds, so that the port can be compared
against it.

The upstream builds the symbolic estimators in the `fit` of every estimator and
keeps them in the attribute `symbolic_estimator`, and it hands them to the
estimate as its `realized_estimand_expr`.

Usage:

    python _verify/symbolic_estimators_reference.py
"""

import sys

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")
import numpy as np
import pandas as pd
import statsmodels.api as sm

from dowhy import CausalModel, EstimandType, identify_effect_auto
from dowhy.causal_estimators.linear_regression_estimator import (
    LinearRegressionEstimator,
)
from dowhy.causal_estimators.generalized_linear_model_estimator import (
    GeneralizedLinearModelEstimator,
)
from dowhy.causal_estimators.propensity_score_weighting_estimator import (
    PropensityScoreWeightingEstimator,
)
from dowhy.causal_estimators.propensity_score_matching_estimator import (
    PropensityScoreMatchingEstimator,
)
from dowhy.causal_estimators.propensity_score_stratification_estimator import (
    PropensityScoreStratificationEstimator,
)
from dowhy.causal_estimators.doubly_robust_estimator import DoublyRobustEstimator
from dowhy.causal_estimators.distance_matching_estimator import (
    DistanceMatchingEstimator,
)
from dowhy.graph import build_graph

LCG_MODULUS = 2147483648
LCG_MULTIPLIER = 1103515245
LCG_INCREMENT = 12345

FRONTDOOR_GRAPH = """
        graph [
            directed 1

            node [
                id "X"
                label "X"
            ]
            node [
                id "Z"
                label "Z"
            ]
            node [
                id "Y"
                label "Y"
            ]
            node [
                id "U"
                label "U"
            ]

            edge [
                source "X"
                target "Z"
            ]

            edge [
                source "Z"
                target "Y"
            ]

            edge [
                source "U"
                target "Y"
            ]

            edge [
                source "U"
                target "X"
            ]
        ]
        """.replace("\n", "")


def make_frame(num_rows=60, outcomes=("y",), common_cause=True, modifier=False):
    """The fixture of the port: a treatment, a common cause and an outcome."""
    state = 42
    treatment = []
    common = []
    outcome = []
    effect = []
    for index in range(num_rows):
        state = (LCG_MULTIPLIER * state + LCG_INCREMENT) % LCG_MODULUS
        w = state / LCG_MODULUS * 4.0 - 2.0
        state = (LCG_MULTIPLIER * state + LCG_INCREMENT) % LCG_MODULUS
        noise = state / LCG_MODULUS - 0.5
        t = 1 if (index % 3) == 0 else 0
        treatment.append(t)
        common.append(w)
        outcome.append(2.0 * t + 0.5 * w + noise)
        effect.append(w * 0.5)
    columns = {"v0": treatment}
    if common_cause:
        columns["W0"] = common
    if modifier:
        columns["X0"] = effect
    for name in outcomes:
        columns[name] = outcome
    return pd.DataFrame(columns)


def estimand_of(df, outcomes=("y",), common_causes=("W0",)):
    graph = build_graph(
        action_nodes=["v0"],
        outcome_nodes=list(outcomes),
        common_cause_nodes=list(common_causes),
    )
    estimand = identify_effect_auto(
        graph,
        observed_nodes=list(df.columns),
        action_nodes=["v0"],
        outcome_nodes=list(outcomes),
        estimand_type=EstimandType.NONPARAMETRIC_ATE,
    )
    estimand.set_identifier_method("backdoor")
    return estimand


def symbolic_of(estimator, df, estimand, effect_modifiers=None):
    estimator.fit(df, effect_modifier_names=effect_modifiers)
    return estimator.symbolic_estimator


def main():
    df = make_frame()
    estimand = estimand_of(df)
    print("the estimators of the upstream, with one outcome")
    print(
        "  linear:",
        repr(
            symbolic_of(
                LinearRegressionEstimator(identified_estimand=estimand), df, estimand
            )
        ),
    )
    print(
        "  linear with an effect modifier:",
        repr(
            symbolic_of(
                LinearRegressionEstimator(identified_estimand=estimand),
                df,
                estimand,
                effect_modifiers=["W0"],
            )
        ),
    )
    print(
        "  generalised linear model:",
        repr(
            symbolic_of(
                GeneralizedLinearModelEstimator(
                    identified_estimand=estimand, glm_family=sm.families.Binomial()
                ),
                df,
                estimand,
            )
        ),
    )
    print(
        "  generalised linear model with an effect modifier:",
        repr(
            symbolic_of(
                GeneralizedLinearModelEstimator(
                    identified_estimand=estimand, glm_family=sm.families.Binomial()
                ),
                df,
                estimand,
                effect_modifiers=["W0"],
            )
        ),
    )
    print(
        "  propensity score weighting:",
        repr(
            symbolic_of(
                PropensityScoreWeightingEstimator(identified_estimand=estimand),
                df,
                estimand,
            )
        ),
    )
    print(
        "  propensity score matching:",
        repr(
            symbolic_of(
                PropensityScoreMatchingEstimator(identified_estimand=estimand),
                df,
                estimand,
            )
        ),
    )
    print(
        "  propensity score stratification:",
        repr(
            symbolic_of(
                PropensityScoreStratificationEstimator(identified_estimand=estimand),
                df,
                estimand,
            )
        ),
    )
    print(
        "  doubly robust:",
        repr(
            symbolic_of(
                DoublyRobustEstimator(identified_estimand=estimand), df, estimand
            )
        ),
    )
    print(
        "  distance matching:",
        repr(
            symbolic_of(
                DistanceMatchingEstimator(identified_estimand=estimand), df, estimand
            )
        ),
    )

    print()
    print("the estimators of the upstream, with two outcomes")
    two = make_frame(outcomes=("y", "y2"))
    two_estimand = estimand_of(two, outcomes=("y", "y2"))
    print(
        "  linear:",
        repr(
            symbolic_of(
                LinearRegressionEstimator(identified_estimand=two_estimand),
                two,
                two_estimand,
            )
        ),
    )
    print(
        "  propensity score matching:",
        repr(
            symbolic_of(
                PropensityScoreMatchingEstimator(identified_estimand=two_estimand),
                two,
                two_estimand,
            )
        ),
    )
    print(
        "  distance matching:",
        repr(
            symbolic_of(
                DistanceMatchingEstimator(identified_estimand=two_estimand),
                two,
                two_estimand,
            )
        ),
    )

    print()
    print("the linear regression with an effect modifier and no common cause")
    plain = make_frame(common_cause=False, modifier=True)
    plain_estimand = estimand_of(plain, common_causes=())
    print(
        "  linear:",
        repr(
            symbolic_of(
                LinearRegressionEstimator(identified_estimand=plain_estimand),
                plain,
                plain_estimand,
                effect_modifiers=["X0"],
            )
        ),
    )

    print()
    print("the two stage regression of the frontdoor estimand")
    rng = np.random.RandomState(7)
    n = 200
    u = rng.randn(n)
    x = rng.randn(n) + 0.3 * u
    z = 0.7 * x + 0.3 * rng.randn(n)
    y = 0.65 * z + 0.2 * u
    frontdoor = pd.DataFrame(np.vstack([x, z, y]).T, columns=["X", "Z", "Y"])
    model = CausalModel(
        data=frontdoor, treatment="X", outcome="Y", graph=FRONTDOOR_GRAPH
    )
    frontdoor_estimand = model.identify_effect(proceed_when_unidentifiable=True)
    estimate = model.estimate_effect(
        identified_estimand=frontdoor_estimand,
        method_name="frontdoor.two_stage_regression",
    )
    print("  the estimate =", estimate.value)
    print("  the symbolic estimator =", repr(estimate.realized_estimand_expr))


if __name__ == "__main__":
    main()
