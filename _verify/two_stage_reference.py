"""The upstream reference of the two stage regression estimator.

The script runs the upstream `dowhy` on the rows of the integration test of the
book "Causal Inference and Discovery in Python", the one of the chapter 7, and
prints the numbers the MoonBit port has to reproduce:

  * the frontdoor variables of the identification,
  * the confounders of the two stages of the mediation,
  * the estimate of the two stage regression estimator,
  * the coefficients of the two stages of the estimator.

The upstream package cannot be imported as it is, because its `__init__` pulls
in `causallearn`; the loader of `upstream_gcm.py` reads the modules straight
from their files instead. The module of the interpreters is stubbed out,
because it pulls in the causal model of the upstream, which pulls in the graph
learners, which need the package `causallearn`.

The refutation of the upstream test cannot be run here: the module of the data
subset refuter needs the package `econml`, which is not installed. The port
runs the refutation with its own generator, so the number of the refutation is
not one the two implementations share.

Usage:
    python _verify/two_stage_reference.py
"""

from __future__ import annotations

import os
import sys

import numpy as np
import pandas as pd
import networkx as nx

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from book_scm import GML_GRAPH, sample_rows  # noqa: E402
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

EstimandType = auto_identifier.EstimandType
BackdoorAdjustment = auto_identifier.BackdoorAdjustment
identify_effect_auto = auto_identifier.identify_effect_auto
TwoStageRegressionEstimator = two_stage_module.TwoStageRegressionEstimator


def section(title: str) -> None:
    print()
    print("=" * 72)
    print(title)
    print("=" * 72)


def show(label: str, value: object) -> None:
    print(f"{label}: {value!r}")


def main() -> None:
    columns = sample_rows()
    frame = pd.DataFrame(
        np.vstack([columns["X"], columns["Z"], columns["Y"]]).T,
        columns=["X", "Z", "Y"],
    )
    section("The data set of the upstream test")
    show("columns", list(frame.columns))
    show("rows", len(frame.index))
    show("X", (float(frame["X"].min()), float(frame["X"].max())))
    show("Z", (float(frame["Z"].min()), float(frame["Z"].max())))
    show("Y", (float(frame["Y"].min()), float(frame["Y"].max())))

    section("The graph of the upstream test")
    # The upstream reads a GML string with `nx.parse_gml`, after it has
    # replaced the newlines of the string with spaces.
    graph = nx.DiGraph(nx.parse_gml(GML_GRAPH.replace("\n", " ")))
    show("nodes", sorted(str(node) for node in graph.nodes))
    show("edges", sorted((str(source), str(target)) for source, target in graph.edges))

    section("The identification of the upstream")
    estimand = identify_effect_auto(
        graph,
        ["X"],
        ["Y"],
        list(frame.columns),
        estimand_type=EstimandType.NONPARAMETRIC_ATE,
        backdoor_adjustment=BackdoorAdjustment.BACKDOOR_DEFAULT,
    )
    show("estimand_type", estimand.estimand_type)
    show("estimands", sorted(estimand.estimands.keys()))
    show("frontdoor_variables", estimand.frontdoor_variables)
    show("instrumental_variables", estimand.instrumental_variables)
    show("default_backdoor_id", estimand.default_backdoor_id)
    show("backdoor_variables", estimand.backdoor_variables)
    show("mediation_first_stage_confounders", estimand.mediation_first_stage_confounders)
    show("mediation_second_stage_confounders", estimand.mediation_second_stage_confounders)
    show(
        "frontdoor assumptions",
        list(estimand.estimands["frontdoor"]["assumptions"].values()),
    )

    section("The two stage regression of the upstream")
    estimand.set_identifier_method("frontdoor")
    estimator = TwoStageRegressionEstimator(estimand)
    estimator.fit(frame, effect_modifier_names=[])
    estimate = estimator.estimate_effect(
        frame,
        treatment_value=1,
        control_value=0,
        target_units="ate",
    )
    show("estimate", estimate.value)
    show("treatment_name", estimate._treatment_name)
    show("outcome_name", estimate._outcome_name)
    first = estimator._first_stage_model
    second = estimator._second_stage_model
    show("first stage outcome", first._target_estimand.outcome_variable)
    show("first stage treatment", first._target_estimand.treatment_variable)
    show(
        "first stage adjustment",
        first._target_estimand.get_adjustment_set(),
    )
    show("first stage params", [float(v) for v in first.model.params])
    show("first stage design", [str(c) for c in first.model.model.exog_names])
    show("second stage outcome", second._target_estimand.outcome_variable)
    show("second stage treatment", second._target_estimand.treatment_variable)
    show(
        "second stage adjustment",
        second._target_estimand.get_adjustment_set(),
    )
    show("second stage params", [float(v) for v in second.model.params])
    show("second stage design", [str(c) for c in second.model.model.exog_names])
    show(
        "product of the two coefficients",
        float(first.model.params.iloc[1]) * float(second.model.params.iloc[1]),
    )


if __name__ == "__main__":
    main()
