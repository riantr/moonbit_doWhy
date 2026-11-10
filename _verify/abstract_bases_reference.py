"""The placeholders of the abstract bases of the upstream.

The upstream has two abstract base classes: the class `CausalEstimator` and the
class `DimensionalityReducer`. Their placeholder methods raise a
`NotImplementedError`, and the estimators and the reducers of the upstream that
derive from them inherit every placeholder they do not override.

This script prints the messages of the upstream and the classes that implement
the two placeholder methods of the estimator, so that the predicates of the
port can be compared with them.

Usage:

    python _verify/abstract_bases_reference.py
"""

from __future__ import annotations

import sys

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

from dowhy.causal_estimator import CausalEstimator
from dowhy.causal_estimators.doubly_robust_estimator import (
    DoublyRobustEstimator,
)
from dowhy.causal_estimators.generalized_linear_model_estimator import (
    GeneralizedLinearModelEstimator,
)
from dowhy.causal_estimators.instrumental_variable_estimator import (
    InstrumentalVariableEstimator,
)
from dowhy.causal_estimators.linear_regression_estimator import (
    LinearRegressionEstimator,
)
from dowhy.causal_estimators.propensity_score_matching_estimator import (
    PropensityScoreMatchingEstimator,
)
from dowhy.causal_estimators.propensity_score_stratification_estimator import (
    PropensityScoreStratificationEstimator,
)
from dowhy.causal_estimators.propensity_score_weighting_estimator import (
    PropensityScoreWeightingEstimator,
)
from dowhy.causal_estimators.regression_discontinuity_estimator import (
    RegressionDiscontinuityEstimator,
)
from dowhy.causal_estimators.two_stage_regression_estimator import (
    TwoStageRegressionEstimator,
)
from dowhy.data_transformer import DimensionalityReducer

ESTIMATORS = [
    ("LinearRegression", LinearRegressionEstimator),
    ("GeneralizedLinearModel", GeneralizedLinearModelEstimator),
    ("DoublyRobust", DoublyRobustEstimator),
    ("PropensityScoreWeighting", PropensityScoreWeightingEstimator),
    ("PropensityScoreMatching", PropensityScoreMatchingEstimator),
    ("PropensityScoreStratification", PropensityScoreStratificationEstimator),
    ("InstrumentalVariable", InstrumentalVariableEstimator),
    ("TwoStageRegression", TwoStageRegressionEstimator),
    ("RegressionDiscontinuity", RegressionDiscontinuityEstimator),
]


class MockEstimator(CausalEstimator):
    """The mock estimator of the upstream test file."""


class MockReducer(DimensionalityReducer):
    """The mock reducer of the upstream test file."""


def implements(klass: type, name: str) -> bool:
    """Whether the class or one of its parents below the base implements it."""
    for parent in klass.__mro__:
        if parent is CausalEstimator:
            return False
        if name in parent.__dict__:
            return True
    return False


def show_placeholders() -> None:
    print("=" * 70)
    print("the placeholders of the base estimator of the upstream")
    print("=" * 70)
    estimator = MockEstimator(None)
    calls = (
        ("_do", lambda: estimator._do(None)),
        (
            "construct_symbolic_estimator",
            lambda: estimator.construct_symbolic_estimator(None),
        ),
    )
    for name, call in calls:
        try:
            call()
            print("   %s did not raise" % name)
        except NotImplementedError as error:
            print("   %s raised NotImplementedError:" % name)
            print("      ", str(error))
    print()
    print("   the message of the upstream:")
    print("      ", CausalEstimator.DEFAULT_NOTIMPLEMENTEDERROR_MSG)
    print()


def show_reducer() -> None:
    print("=" * 70)
    print("the placeholder of the base reducer of the upstream")
    print("=" * 70)
    reducer = MockReducer(None, None)
    try:
        reducer.reduce()
        print("   reduce did not raise")
    except NotImplementedError as error:
        print("   reduce raised NotImplementedError:")
        print("      ", str(error))
    print()


def show_estimators() -> None:
    print("=" * 70)
    print("the estimators of the upstream and their placeholders")
    print("=" * 70)
    for name, klass in ESTIMATORS:
        print(
            "   %-28s the do operator: %-5s the symbolic estimator: %s"
            % (
                name,
                str(implements(klass, "_do")),
                str(implements(klass, "construct_symbolic_estimator")),
            )
        )
    print()


def main() -> None:
    show_placeholders()
    show_reducer()
    show_estimators()


if __name__ == "__main__":
    main()
