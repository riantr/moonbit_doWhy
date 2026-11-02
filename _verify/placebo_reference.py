"""The upstream reference of the placebo treatment refuter.

The script runs the upstream `dowhy` on the cases of the upstream test file
`tests/causal_refuters/test_placebo_refuter.py` and prints the numbers the
MoonBit port has to reproduce:

  * the placebo column the upstream builds for every kind of treatment, the
    random data one and the permuted one;
  * the estimate of the refutation, the p-value of the significance test and
    the decision the significance test makes.

The rows of the port are replicated by `_verify/port_linear_dataset.py`, so
the upstream runs on the very same rows the port works on. The placebo itself
is drawn with the global generator of numpy and the port draws it with its
own generator, so the numbers of the two are not the same numbers; what the
two share is the behaviour the upstream test asserts.

The upstream package cannot be imported as it is, because its `__init__` pulls
in `causallearn`; the loader of `upstream_gcm.py` reads the modules straight
from their files instead. The upstream `CausalModel` cannot be read either,
because it pulls in the graph learners, so the script identifies the effect and
estimates it the way the upstream test does, with the upstream functions.

Usage:
    python _verify/placebo_reference.py
"""

from __future__ import annotations

import os
import sys

import networkx as nx
import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from port_linear_dataset import frontdoor_dataset  # noqa: E402
from upstream_gcm import linear_dataset  # noqa: E402
from upstream_gcm import load  # noqa: E402

# The modules are loaded in the order of their dependencies.
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
load("dowhy.causal_estimators.instrumental_variable_estimator")
load("dowhy.causal_refuters.placebo_treatment_refuter")
datasets = load("dowhy.datasets")

EstimandType = auto_identifier.EstimandType
BackdoorAdjustment = auto_identifier.BackdoorAdjustment
identify_effect_auto = auto_identifier.identify_effect_auto
placebo_module = sys.modules["dowhy.causal_refuters.placebo_treatment_refuter"]
refute_placebo_treatment = placebo_module.refute_placebo_treatment
PlaceboType = placebo_module.PlaceboType
LinearRegressionEstimator = sys.modules[
    "dowhy.causal_estimators.linear_regression_estimator"
].LinearRegressionEstimator

# The number of rows of the fixtures.
NUM_ROWS = 1000

# The seed of the generator of numpy, so that the rows of the upstream are the
# same on every run.
SEED = 0


def section(title: str) -> None:
    print()
    print("=" * 72)
    print(title)
    print("=" * 72)


def show(label: str, value: object) -> None:
    print(f"{label}: {value!r}")


def upstream_rows(treatment_is_binary: bool, treatment_is_category: bool) -> pd.DataFrame:
    """The rows of the upstream for the given kind of treatment."""
    np.random.seed(SEED)
    data = linear_dataset(
        datasets,
        beta=10,
        num_common_causes=1,
        num_instruments=1,
        num_samples=NUM_ROWS,
        treatment_is_binary=treatment_is_binary,
        treatment_is_category=treatment_is_category,
    )
    return data


def port_rows(treatment_is_binary: bool, treatment_is_category: bool) -> pd.DataFrame:
    """The rows of the port, replicated in Python."""
    if treatment_is_category:
        raise NotImplementedError("the categorical data set of the port is not replicated here")
    data = frontdoor_dataset(SEED, NUM_ROWS)
    return pd.DataFrame(
        {name: data["columns"][name] for name in data["column_order"]},
    )


def estimate_of(frame: pd.DataFrame, gml_graph: str, treatment: list[str]) -> object:
    """The estimand and the estimate of the upstream."""
    graph = nx.DiGraph(nx.parse_gml(gml_graph))
    estimand = identify_effect_auto(
        graph,
        treatment,
        ["y"],
        list(frame.columns),
        estimand_type=EstimandType.NONPARAMETRIC_ATE,
        backdoor_adjustment=BackdoorAdjustment.BACKDOOR_DEFAULT,
    )
    estimand.set_identifier_method("backdoor")
    estimator = LinearRegressionEstimator(estimand)
    estimator.fit(frame, effect_modifier_names=[])
    estimate = estimator.estimate_effect(
        frame,
        control_value=0,
        treatment_value=1,
        target_units="ate",
    )
    return estimand, estimate


def main() -> None:
    for kind, binary, category in (
        ("continuous", False, False),
        ("binary", True, False),
        ("categorical", False, True),
    ):
        section(f"The {kind} treatment of the upstream")
        data = upstream_rows(binary, category)
        frame = data["df"]
        show("columns", list(frame.columns))
        show("dtypes", {name: str(dtype) for name, dtype in frame.dtypes.items()})
        estimand, estimate = estimate_of(frame, data["gml_graph"], data["treatment_name"])
        show("estimate", float(estimate.value))
        for placebo_type in (PlaceboType.DEFAULT, PlaceboType.PERMUTE):
            np.random.seed(SEED)
            refutation = refute_placebo_treatment(
                data=frame,
                target_estimand=estimand,
                estimate=estimate,
                treatment_names=data["treatment_name"],
                num_simulations=10,
                placebo_type=placebo_type,
                random_state=SEED,
            )
            print()
            show("placebo type", placebo_type.value)
            show("new effect", float(refutation.new_effect))
            show("significance test", refutation.refutation_result)


if __name__ == "__main__":
    main()
