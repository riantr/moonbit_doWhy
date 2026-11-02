"""The upstream reference of the tests of the two stage regression estimator.

The script runs the upstream `dowhy` on the two cases of the upstream test file
`tests/causal_estimators/test_two_stage_regression_estimator.py` and prints the
numbers the MoonBit port has to reproduce:

  * the average treatment effect test suite case: the data set of the upstream
    `linear_dataset` with one frontdoor mediator and no common cause, the true
    average treatment effect of that data set and the estimate of the upstream
    two stage regression estimator;
  * the frontdoor estimator case: the data set of the upstream test, the
    estimate of the upstream two stage regression estimator and the difference
    to the value the upstream test asserts.

The first case is run on the rows of the *port*, so that the number the port
has to reproduce is the number the upstream computes on the very same rows.
The rows of the port are replicated by `_verify/port_linear_dataset.py`, which
mirrors the generator of `src/datasets/datasets.mbt`: the values of the columns
are the same numbers, down to the last bit.

The upstream package cannot be imported as it is, because its `__init__` pulls
in `causallearn`; the loader of `upstream_gcm.py` reads the modules straight
from their files instead. The upstream `CausalModel` cannot be read either,
because it pulls in the graph learners, so the script identifies the effect and
estimates it the way the upstream test does, with the upstream functions.

Usage:
    python _verify/two_stage_estimator_reference.py
"""

from __future__ import annotations

import os
import sys

import networkx as nx
import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from port_linear_dataset import frontdoor_dataset  # noqa: E402
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
two_stage_module = load("dowhy.causal_estimators.two_stage_regression_estimator")
datasets = load("dowhy.datasets")

EstimandType = auto_identifier.EstimandType
BackdoorAdjustment = auto_identifier.BackdoorAdjustment
identify_effect_auto = auto_identifier.identify_effect_auto
TwoStageRegressionEstimator = two_stage_module.TwoStageRegressionEstimator

# The number of rows the upstream test of the frontdoor estimator uses.
UPSTREAM_NUM_ROWS = 10000

# The number of rows the fixture of the port holds.
FIXTURE_NUM_ROWS = 2000

# The seed of the generator of the port.
PORT_SEED = 42

# The value the upstream test of the frontdoor estimator asserts, and the
# tolerance it allows.
UPSTREAM_EXPECTED = 0.45
UPSTREAM_TOLERANCE = 0.025

# The graph of the upstream test of the frontdoor estimator. The upstream
# removes the newlines of the string, so the graph is read the way the
# upstream reads it.
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


def section(title: str) -> None:
    print()
    print("=" * 72)
    print(title)
    print("=" * 72)


def show(label: str, value: object) -> None:
    print(f"{label}: {value!r}")


def estimate_of_frontdoor(
    frame: pd.DataFrame,
    graph: nx.DiGraph,
    observed: list[str],
) -> tuple[float, object]:
    """The estimate of the upstream two stage regression estimator."""
    estimand = identify_effect_auto(
        graph,
        ["X"],
        ["Y"],
        observed,
        estimand_type=EstimandType.NONPARAMETRIC_ATE,
        backdoor_adjustment=BackdoorAdjustment.BACKDOOR_DEFAULT,
    )
    estimand.set_identifier_method("frontdoor")
    estimator = TwoStageRegressionEstimator(estimand)
    estimator.fit(frame, effect_modifier_names=[])
    estimate = estimator.estimate_effect(
        frame,
        treatment_value=1,
        control_value=0,
        target_units="ate",
    )
    return float(estimate.value), estimand


def frontdoor_rows(num_rows: int) -> pd.DataFrame:
    """The rows of the upstream test of the frontdoor estimator."""
    np.random.seed(0)
    u = np.random.randn(num_rows)
    x = np.random.randn(num_rows) + 0.3 * u
    z = 0.7 * x + 0.3 * np.random.randn(num_rows)
    y = 0.65 * z + 0.2 * u
    return pd.DataFrame(np.vstack([x, z, y]).T, columns=["X", "Z", "Y"])


def port_rows(num_rows: int) -> tuple[pd.DataFrame, dict]:
    """The rows of the port, replicated in Python."""
    data = frontdoor_dataset(PORT_SEED, num_rows)
    frame = pd.DataFrame(
        {name: data["columns"][name] for name in data["column_order"]},
    )
    return frame, data


def main() -> None:
    section("The average treatment effect test suite case of the upstream")
    # The configuration of the upstream test: one frontdoor mediator, no
    # common cause, a continuous treatment and a continuous outcome.
    data = datasets.linear_dataset(
        beta=10,
        num_common_causes=0,
        num_instruments=0,
        num_effect_modifiers=0,
        num_treatments=1,
        num_frontdoor_variables=1,
        num_samples=100000,
        treatment_is_binary=False,
        outcome_is_binary=False,
    )
    frame = data["df"]
    show("columns", list(frame.columns))
    show("treatment_name", data["treatment_name"])
    show("outcome_name", data["outcome_name"])
    show("frontdoor_variables_names", data["frontdoor_variables_names"])
    show("ate", data["ate"])
    graph = nx.DiGraph(nx.parse_gml(data["gml_graph"]))
    show("nodes", sorted(str(node) for node in graph.nodes))
    show("edges", sorted((str(s), str(t)) for s, t in graph.edges))
    estimand = identify_effect_auto(
        graph,
        data["treatment_name"],
        [data["outcome_name"]],
        list(frame.columns),
        estimand_type=EstimandType.NONPARAMETRIC_ATE,
        backdoor_adjustment=BackdoorAdjustment.BACKDOOR_DEFAULT,
    )
    estimand.set_identifier_method("frontdoor")
    show("frontdoor_variables", estimand.frontdoor_variables)
    show(
        "mediation_first_stage_confounders",
        estimand.mediation_first_stage_confounders,
    )
    show(
        "mediation_second_stage_confounders",
        estimand.mediation_second_stage_confounders,
    )
    estimator = TwoStageRegressionEstimator(estimand)
    estimator.fit(frame, effect_modifier_names=data["effect_modifier_names"])
    estimate = estimator.estimate_effect(
        frame,
        control_value=0,
        treatment_value=1,
        target_units="ate",
    )
    show("estimate", float(estimate.value))
    show(
        "relative error",
        abs(float(estimate.value) - data["ate"]) / abs(data["ate"]),
    )

    section("The same case on the rows of the port")
    frame, port_data = port_rows(FIXTURE_NUM_ROWS)
    show("columns", list(frame.columns))
    show("ate of the port", port_data["ate"])
    graph = nx.DiGraph(nx.parse_gml(port_data["gml_graph"]))
    show("nodes", sorted(str(node) for node in graph.nodes))
    show("edges", sorted((str(s), str(t)) for s, t in graph.edges))
    estimand = identify_effect_auto(
        graph,
        port_data["treatment_names"],
        [port_data["outcome_name"]],
        list(frame.columns),
        estimand_type=EstimandType.NONPARAMETRIC_ATE,
        backdoor_adjustment=BackdoorAdjustment.BACKDOOR_DEFAULT,
    )
    estimand.set_identifier_method("frontdoor")
    show("frontdoor_variables", estimand.frontdoor_variables)
    show(
        "mediation_first_stage_confounders",
        estimand.mediation_first_stage_confounders,
    )
    show(
        "mediation_second_stage_confounders",
        estimand.mediation_second_stage_confounders,
    )
    show("default_backdoor_id", estimand.default_backdoor_id)
    estimator = TwoStageRegressionEstimator(
        estimand,
        num_simulations=10,
        num_null_simulations=10,
    )
    estimator.fit(frame, effect_modifier_names=[])
    estimate = estimator.estimate_effect(
        frame,
        control_value=0,
        treatment_value=1,
        test_significance=False,
        evaluate_effect_strength=False,
        confidence_intervals=True,
        target_units="ate",
    )
    show("estimate", float(estimate.value))
    show(
        "relative error",
        abs(float(estimate.value) - port_data["ate"]) / abs(port_data["ate"]),
    )
    for level in (None, 0.99):
        try:
            interval = estimate.get_confidence_intervals(confidence_level=level)
            show(f"confidence interval ({level})", interval)
        except Exception as error:  # noqa: BLE001
            show(f"confidence interval ({level}) raises", repr(error))
    try:
        show("standard error", estimate.get_standard_error())
    except Exception as error:  # noqa: BLE001
        show("standard error raises", repr(error))

    section("The case of the upstream that asks for an error")
    # The upstream parametrizes the case with two configurations: one with two
    # treatments and one frontdoor variable, and one with one treatment and two
    # frontdoor variables. The upstream raises an error for both of them.
    for num_treatments, num_frontdoor_variables in ((2, 1), (1, 2)):
        data = datasets.linear_dataset(
            beta=10,
            num_common_causes=1,
            num_instruments=0,
            num_effect_modifiers=0,
            num_treatments=num_treatments,
            num_frontdoor_variables=num_frontdoor_variables,
            num_samples=1000,
            treatment_is_binary=False,
            outcome_is_binary=False,
        )
        frame = data["df"]
        graph = nx.DiGraph(nx.parse_gml(data["gml_graph"]))
        estimand = identify_effect_auto(
            graph,
            data["treatment_name"],
            [data["outcome_name"]],
            list(frame.columns),
            estimand_type=EstimandType.NONPARAMETRIC_ATE,
            backdoor_adjustment=BackdoorAdjustment.BACKDOOR_DEFAULT,
        )
        estimand.set_identifier_method("frontdoor")
        print()
        show("treatments", num_treatments)
        show("frontdoor variables", num_frontdoor_variables)
        show("columns", list(frame.columns))
        show("frontdoor variables of the estimand", estimand.frontdoor_variables)
        try:
            estimator = TwoStageRegressionEstimator(estimand)
            estimator.fit(frame, effect_modifier_names=[])
            estimate = estimator.estimate_effect(
                frame,
                control_value=0,
                treatment_value=1,
                target_units="ate",
            )
            show("estimate", float(estimate.value))
        except Exception as error:  # noqa: BLE001
            show("raises", repr(error))

    section("The frontdoor estimator case of the upstream")
    graph = nx.DiGraph(nx.parse_gml(FRONTDOOR_GRAPH))
    show("nodes", sorted(str(node) for node in graph.nodes))
    show("edges", sorted((str(s), str(t)) for s, t in graph.edges))
    for num_rows in (UPSTREAM_NUM_ROWS, FIXTURE_NUM_ROWS):
        frame = frontdoor_rows(num_rows)
        value, estimand = estimate_of_frontdoor(
            frame, graph, list(frame.columns)
        )
        print()
        show("rows", num_rows)
        show("frontdoor_variables", estimand.frontdoor_variables)
        show(
            "mediation_first_stage_confounders",
            estimand.mediation_first_stage_confounders,
        )
        show(
            "mediation_second_stage_confounders",
            estimand.mediation_second_stage_confounders,
        )
        show("estimate", value)
        show("difference to the asserted value", value - UPSTREAM_EXPECTED)
        show(
            "inside the tolerance of the upstream",
            abs(value - UPSTREAM_EXPECTED) < UPSTREAM_TOLERANCE,
        )


if __name__ == "__main__":
    main()
