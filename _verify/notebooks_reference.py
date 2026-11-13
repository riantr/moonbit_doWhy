"""The numbers of the scenarios of the notebooks of the upstream.

The upstream executes the notebooks of its documentation and asserts that no
cell of them fails. The script runs the scenarios of the notebooks the port
mirrors and prints the numbers they compute, so the tests of the port can
assert the same range.

The notebooks of the upstream do not seed the global generator of numpy, so
their numbers are not reproducible. The script seeds it and prints the numbers
of the seeded run, which is the run the port reproduces.

The data sets of the notebooks that come from `dowhy.datasets.linear_dataset`
are not the data sets of the port: the port draws them with a generator of its
own, so the numbers of those notebooks are the numbers of the port, and the
tests of the port assert that the estimators recover the true effect of the
data set. The data sets of the notebooks that come from
`dowhy.datasets.xy_dataset` are the rows of the upstream, because that data set
is drawn with the generator of numpy, and the tests of the port assert the
numbers of the upstream.

Usage:

    python _verify/notebooks_reference.py
"""

from __future__ import annotations

import math
import sys

import networkx as nx
import numpy as np
import pandas as pd

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

import dowhy.api  # noqa: E402
import dowhy.datasets  # noqa: E402
from dowhy import CausalModel  # noqa: E402
from dowhy import gcm  # noqa: E402
from dowhy.gcm import auto  # noqa: E402
from dowhy.graph import build_graph_from_str  # noqa: E402


def convert_to_binary(x, stochastic=True):
    """The binary treatment of the upstream, with the number it draws.

    The upstream draws the number of the treatment with the `choice` of numpy
    and the size of one, so it draws an array of one number, and the
    `vectorize` of numpy refuses an array where it wants a number. The shim
    draws the same number and gives it to the vectorize as a number.
    """
    p = 1 / (1 + math.exp(-x))
    if stochastic:
        return np.random.choice([0, 1], p=[1 - p, p])
    return int(p > 0.5)


dowhy.datasets.convert_to_binary = convert_to_binary

SEED = 42


def header(title):
    print()
    print("=== " + title)


header("the estimation methods of the upstream")
np.random.seed(SEED)
data = dowhy.datasets.linear_dataset(
    beta=10,
    num_common_causes=5,
    num_instruments=2,
    num_treatments=1,
    num_samples=10000,
    treatment_is_binary=True,
    outcome_is_binary=False,
    stddev_treatment_noise=10,
)
frame = data["df"]
model = CausalModel(
    data=frame,
    treatment=data["treatment_name"],
    outcome=data["outcome_name"],
    graph=data["gml_graph"],
    instruments=data["instrument_names"],
)
estimand = model.identify_effect(proceed_when_unidentifiable=True)
print("the estimate of the linear regression")
print(model.estimate_effect(estimand, method_name="backdoor.linear_regression").value)
print("the estimate of the distance matching")
print(
    model.estimate_effect(
        estimand,
        method_name="backdoor.distance_matching",
        target_units="att",
        method_params={"distance_metric": "minkowski", "p": 2},
    ).value
)
print("the estimate of the propensity score stratification")
print(
    model.estimate_effect(
        estimand, method_name="backdoor.propensity_score_stratification", target_units="att"
    ).value
)
print("the estimate of the propensity score matching")
print(
    model.estimate_effect(
        estimand, method_name="backdoor.propensity_score_matching", target_units="atc"
    ).value
)
print("the estimate of the propensity score weighting")
print(
    model.estimate_effect(
        estimand,
        method_name="backdoor.propensity_score_weighting",
        target_units="ate",
        method_params={"weighting_scheme": "ips_weight"},
    ).value
)
print("the estimate of the instrumental variable")
print(
    model.estimate_effect(
        estimand,
        method_name="iv.instrumental_variable",
        method_params={"iv_instrument_name": "Z0"},
    ).value
)
print("the estimate of the regression discontinuity")
print(
    model.estimate_effect(
        estimand,
        method_name="iv.regression_discontinuity",
        method_params={
            "rd_variable_name": "Z1",
            "rd_threshold_value": 0.5,
            "rd_bandwidth": 0.15,
        },
    ).value
)
print("the estimate of the doubly robust")
print(
    model.estimate_effect(
        estimand,
        method_name="backdoor.doubly_robust",
        method_params={"propensity_score_column": "propensity_score_dr"},
    ).value
)


header("the simple example of the upstream")
np.random.seed(SEED)
data = dowhy.datasets.linear_dataset(
    beta=10,
    num_common_causes=5,
    num_instruments=2,
    num_effect_modifiers=1,
    num_samples=5000,
    treatment_is_binary=True,
    stddev_treatment_noise=10,
    num_discrete_common_causes=1,
)
frame = data["df"]
model = CausalModel(
    data=frame,
    treatment=data["treatment_name"],
    outcome=data["outcome_name"],
    graph=data["gml_graph"],
)
estimand = model.identify_effect(proceed_when_unidentifiable=True)
print("the estimate of the propensity score stratification")
print(
    model.estimate_effect(
        estimand, method_name="backdoor.propensity_score_stratification"
    ).value
)
print("the estimate of the propensity score stratification on the control group")
print(
    model.estimate_effect(
        estimand, method_name="backdoor.propensity_score_stratification", target_units="atc"
    ).value
)
print("the estimate without the graph")
model2 = CausalModel(
    data=frame,
    treatment=data["treatment_name"],
    outcome=data["outcome_name"],
    common_causes=data["common_causes_names"],
    effect_modifiers=data["effect_modifier_names"],
)
estimand2 = model2.identify_effect(proceed_when_unidentifiable=True)
print(
    model2.estimate_effect(
        estimand2, method_name="backdoor.propensity_score_stratification"
    ).value
)

header("the dummy outcome refuter of the upstream")
np.random.seed(SEED)
data = dowhy.datasets.linear_dataset(
    beta=10,
    num_common_causes=2,
    num_instruments=1,
    num_samples=100000,
    treatment_is_binary=False,
)
frame = data["df"]
model = CausalModel(
    data=frame,
    treatment=data["treatment_name"],
    outcome=data["outcome_name"],
    graph=data["gml_graph"],
    instruments=data["instrument_names"],
)
estimand = model.identify_effect(proceed_when_unidentifiable=True)
estimate = model.estimate_effect(
    estimand,
    method_name="iv.instrumental_variable",
    method_params={"iv_instrument_name": "Z0"},
)
print("the estimate of the instrumental variable")
print(estimate.value)
refutation = model.refute_estimate(
    estimand, estimate, method_name="dummy_outcome_refuter"
)
print("the new effect of the dummy outcome")
print(refutation[0].new_effect)
print("the effect of the original estimate")
print(refutation[0].estimated_effect)

header("the do sampler of the upstream")
np.random.seed(SEED)
N = 5000
z = np.random.uniform(size=N)
d = np.random.binomial(1.0, p=1.0 / (1.0 + np.exp(-5.0 * z)))
y = 2.0 * z + d + 0.1 * np.random.normal(size=N)
frame = pd.DataFrame({"Z": z, "D": d, "Y": y})
print("the difference of the two means of the observed data")
print((frame[frame.D == 1].mean() - frame[frame.D == 0].mean())["Y"])
model = CausalModel(frame, ["D"], ["Y"], common_causes=["Z"])
estimand = model.identify_effect(proceed_when_unidentifiable=True)
from dowhy.do_samplers.weighting_sampler import WeightingSampler  # noqa: E402

sampler = WeightingSampler(
    graph=model._graph._graph,
    action_nodes=["D"],
    outcome_nodes=["Y"],
    observed_nodes=frame.columns.tolist(),
    data=frame,
    keep_original_treatment=True,
    variable_types={"D": "b", "Z": "c", "Y": "c"},
)
interventional = sampler.do_sample(None)
print("the number of the rows of the interventional data")
print(len(interventional))
print("the difference of the two means of the interventional data")
print(
    (interventional[interventional.D == 1].mean() - interventional[interventional.D == 0].mean())[
        "Y"
    ]
)


header("the efficient backdoor of the upstream")
from dowhy.causal_identifier import AutoIdentifier, BackdoorAdjustment, EstimandType  # noqa: E402

graph_str = """graph[directed 1 node[id "coach" label "coach"]
                        node[id "team motivation" label "team motivation"]
                        node[id "fitness" label "fitness"]
                        node[id "pre-game prop" label "pre-game prop"]
                        node[id "intra-game prop" label "intra-game prop"]
                        node[id "neuromusc fatigue" label "neuromusc fatigue"]
                        node[id "warm-up" label "warm-up"]
                        node[id "previous injury" label "previous injury"]
                        node[id "contact sport" label "contact sport"]
                        node[id "genetics" label "genetics"]
                        node[id "injury" label "injury"]
                        node[id "tissue disorder" label "tissue disorder"]
                        node[id "tissue weakness" label "tissue weakness"]
                        edge[source "coach" target "team motivation"]
                        edge[source "coach" target "fitness"]
                        edge[source "fitness" target "pre-game prop"]
                        edge[source "fitness" target "neuromusc fatigue"]
                        edge[source "team motivation" target "warm-up"]
                        edge[source "team motivation" target "previous injury"]
                        edge[source "pre-game prop" target "warm-up"]
                        edge[source "warm-up" target "intra-game prop"]
                        edge[source "contact sport" target "previous injury"]
                        edge[source "contact sport" target "intra-game prop"]
                        edge[source "intra-game prop" target "injury"]
                        edge[source "genetics" target "fitness"]
                        edge[source "genetics" target "neuromusc fatigue"]
                        edge[source "genetics" target "tissue disorder"]
                        edge[source "tissue disorder" target "neuromusc fatigue"]
                        edge[source "tissue disorder" target "tissue weakness"]
                        edge[source "neuromusc fatigue" target "intra-game prop"]
                        edge[source "neuromusc fatigue" target "injury"]
                        edge[source "tissue weakness" target "injury"]
                        ]
"""
observed = [
    "coach",
    "team motivation",
    "fitness",
    "neuromusc fatigue",
    "warm-up",
    "previous injury",
    "contact sport",
    "tissue disorder",
    "injury",
]
conditional = ["previous injury", "team motivation"]
graph = build_graph_from_str(graph_str)
for name, adjustment in (
    ("efficient", BackdoorAdjustment.BACKDOOR_EFFICIENT),
    ("minimal efficient", BackdoorAdjustment.BACKDOOR_MIN_EFFICIENT),
):
    identifier = AutoIdentifier(
        estimand_type=EstimandType.NONPARAMETRIC_ATE, backdoor_adjustment=adjustment
    )
    print("the adjustment set of the " + name + " strategy")
    result = identifier.identify_effect(
        graph=graph,
        action_nodes="warm-up",
        outcome_nodes="injury",
        observed_nodes=observed,
        conditional_node_names=conditional,
    )
    print(sorted(result.get_backdoor_variables()))

print("the adjustment set of the efficient strategy without a conditional node")
graph2 = build_graph_from_str(
    """graph[directed 1 node[id "X" label "X"]
                        node[id "Y" label "Y"]
                        node[id "Z1" label "Z1"]
                        node[id "Z2" label "Z2"]
                        node[id "U" label "U"]
                        edge[source "X" target "Y"]
                        edge[source "Z1" target "X"]
                        edge[source "Z1" target "Z2"]
                        edge[source "U" target "Z2"]
                        edge[source "U" target "Y"]
                        ]
"""
)
identifier = AutoIdentifier(
    estimand_type=EstimandType.NONPARAMETRIC_ATE,
    backdoor_adjustment=BackdoorAdjustment.BACKDOOR_EFFICIENT,
)
try:
    result = identifier.identify_effect(
        graph=graph2,
        action_nodes="X",
        outcome_nodes="Y",
        observed_nodes=["X", "Y", "Z1", "Z2"],
    )
    print(sorted(result.get_backdoor_variables()))
except ValueError as error:
    print("the error of the upstream")
    print(error)


header("the id algorithm of the upstream")
for name, causal_graph in (
    ("a single edge", "digraph{T->Y;}"),
    ("a cycle", "digraph{T->Y; Y->T;}"),
    ("a mediator", "digraph{T->X1;X1->Y;}"),
    ("a cause of the treatment", "digraph{T->Y;T->X1;X1->Y;}"),
    ("two causes of the treatment", "digraph{T->Y;X1->T;X1->Y;X2->T;}"),
    ("an isolated treatment", "digraph{T;X1->Y;}"),
):
    print("the estimand of the graph with " + name)
    model = CausalModel(pd.DataFrame(columns=["T", "Y", "X1"]), "T", "Y", graph=causal_graph)
    try:
        print(model.identify_effect(method_name="id-algorithm"))
    except Exception as error:  # noqa: BLE001
        print("the error of the upstream")
        print(error)

header("the draw samples of the upstream")
np.random.seed(SEED)
values_of_x = np.random.normal(0, 1, 1000)
values_of_y = 2 * values_of_x + np.random.normal(0, 1, 1000)
values_of_z = 3 * values_of_y + np.random.normal(0, 1, 1000)
frame = pd.DataFrame(data=dict(X=values_of_x, Y=values_of_y, Z=values_of_z))
causal_model = gcm.StructuralCausalModel(nx.DiGraph([("X", "Y"), ("Y", "Z")]))
auto.assign_causal_mechanisms(causal_model, frame)
gcm.fit(causal_model, frame)
generated = gcm.draw_samples(causal_model, num_samples=1000)
print("the number of the rows of the generated data")
print(len(generated))
print("the mean of the generated X")
print(generated["X"].mean())
print("the mean of the generated Y")
print(generated["Y"].mean())
print("the mean of the generated Z")
print(generated["Z"].mean())
print("the mean of the observed X")
print(frame["X"].mean())
print("the mean of the observed Y")
print(frame["Y"].mean())
print("the mean of the observed Z")
print(frame["Z"].mean())

header("the confounder example of the upstream")
np.random.seed(SEED)
rvar = 1 if np.random.uniform() > 0.5 else 0
print("the true effect of the upstream")
print(rvar)
data = dowhy.datasets.xy_dataset(
    10000, effect=rvar, num_common_causes=1, sd_error=0.2
)
frame = data["df"]
print("the treatment of the upstream")
print(data["treatment_name"])
print("the outcome of the upstream")
print(data["outcome_name"])
print("the common cause of the upstream")
print(data["common_causes_names"])
model = CausalModel(
    data=frame,
    treatment=data["treatment_name"],
    outcome=data["outcome_name"],
    common_causes=data["common_causes_names"],
    instruments=data["instrument_names"],
)
estimand = model.identify_effect(proceed_when_unidentifiable=True)
print("the estimate of the linear regression")
print(model.estimate_effect(estimand, method_name="backdoor.linear_regression").value)

header("the generalized covariate adjustment of the upstream")
model = CausalModel(pd.DataFrame(columns=["X", "Y", "Z"]), "X", "Y", graph="digraph{Z;X;Y; X->Z;X->Y}")
print("the estimand of the first graph")
print(model.identify_effect())
model = CausalModel(
    pd.DataFrame(columns=["X1", "X2", "Y", "V1", "V2", "V3", "V4", "V5", "L"]),
    ["X1", "X2"],
    "Y",
    graph="""graph[directed 1 node[id "X1" label "X1"]
                node[id "X2" label "X2"]
                node[id "Y" label "Y"]
                node[id "V1" label "V1"]
                node[id "V2" label "V2"]
                node[id "V3" label "V3"]
                node[id "V4" label "V4"]
                node[id "V5" label "V5"]
                node[id "L" label "L"]
                edge[source "V5" target "X1"]
                edge[source "V4" target "X1"]
                edge[source "X1" target "V1"]
                edge[source "V1" target "V2"]
                edge[source "V2" target "X2"]
                edge[source "X2" target "Y"]
                edge[source "X1" target "V3"]
                edge[source "V3" target "Y"]
                edge[source "L" target "V3"]
                edge[source "L" target "V2"]]
                """,
)
print("the estimand of the second graph")
print(model.identify_effect())


header("the mediation analysis of the upstream")
np.random.seed(SEED)
data = dowhy.datasets.linear_dataset(
    10,
    num_common_causes=1,
    num_samples=10000,
    num_instruments=0,
    num_effect_modifiers=0,
    num_treatments=1,
    num_frontdoor_variables=1,
    treatment_is_binary=False,
    outcome_is_binary=False,
)
frame = data["df"]
print("the true effect of the upstream")
print(data["ate"])
model = CausalModel(
    frame,
    data["treatment_name"],
    data["outcome_name"],
    data["gml_graph"],
    missing_nodes_as_confounders=True,
)
estimand_nie = model.identify_effect(
    estimand_type="nonparametric-nie", proceed_when_unidentifiable=True
)
estimand_nde = model.identify_effect(
    estimand_type="nonparametric-nde", proceed_when_unidentifiable=True
)
from dowhy.causal_estimators.linear_regression_estimator import (  # noqa: E402
    LinearRegressionEstimator,
)

print("the estimate of the natural indirect effect")
print(
    model.estimate_effect(
        estimand_nie,
        method_name="mediation.two_stage_regression",
        confidence_intervals=False,
        test_significance=False,
        method_params={
            "first_stage_model": LinearRegressionEstimator,
            "second_stage_model": LinearRegressionEstimator,
        },
    ).value
)
print("the estimate of the natural direct effect")
print(
    model.estimate_effect(
        estimand_nde,
        method_name="mediation.two_stage_regression",
        confidence_intervals=False,
        test_significance=False,
        method_params={
            "first_stage_model": LinearRegressionEstimator,
            "second_stage_model": LinearRegressionEstimator,
        },
    ).value
)


header("the instrumental variable of the upstream")
np.random.seed(SEED)
n_points = 1000
ability = np.random.normal(0, 3, size=n_points)
voucher = np.random.normal(2, 1, size=n_points)
education = np.random.normal(5, 1, size=n_points) + 1 * ability + 2 * voucher
income = np.random.normal(10, 3, size=n_points) + 2 * ability + 4 * education
frame = pd.DataFrame(
    data={"education": education, "income": income, "voucher": voucher}
)
model = CausalModel(
    data=frame,
    treatment="education",
    outcome="income",
    common_causes=["U"],
    instruments=["voucher"],
)
estimand = model.identify_effect(proceed_when_unidentifiable=True)
estimate = model.estimate_effect(
    estimand, method_name="iv.instrumental_variable", test_significance=True
)
print("the estimate of the instrumental variable")
print(estimate.value)
print("the confidence interval of the estimate")
print(estimate.get_confidence_intervals())
refutation = model.refute_estimate(
    estimand,
    estimate,
    method_name="placebo_treatment_refuter",
    placebo_type="permute",
)
print("the new effect of the placebo")
print(refutation.new_effect)

header("the refuter of the conditional independences of the upstream")
from dowhy.datasets import dataset_from_random_graph  # noqa: E402

data = dataset_from_random_graph(
    num_vars=10,
    num_samples=5000,
    prob_edge=0.3,
    random_seed=100,
    prob_type_of_data=(0.333, 0.333, 0.334),
)
frame = data["df"]
print("the columns of the data set")
print(list(frame.columns))
graph_string = """graph [
  directed 1
  node [ id 0 label "a" ]
  node [ id 1 label "b" ]
  node [ id 2 label "c" ]
  node [ id 3 label "d" ]
  node [ id 4 label "e" ]
  node [ id 5 label "f" ]
  node [ id 6 label "g" ]
  node [ id 7 label "h" ]
  node [ id 8 label "i" ]
  node [ id 9 label "j" ]
  edge [ source 0 target 1 ]
  edge [ source 0 target 8 ]
  edge [ source 1 target 2 ]
  edge [ source 1 target 5 ]
  edge [ source 2 target 3 ]
  edge [ source 2 target 4 ]
  edge [ source 3 target 4 ]
  edge [ source 4 target 5 ]
  edge [ source 5 target 6 ]
  edge [ source 6 target 7 ]
  edge [ source 7 target 8 ]
  edge [ source 8 target 9 ]
]"""
model = CausalModel(
    data=frame,
    treatment=data["treatment_name"],
    outcome=data["outcome_name"],
    graph=graph_string,
)
refutation = model.refute_graph(
    k=1,
    independence_test={
        "test_for_continuous": "partial_correlation",
        "test_for_discrete": "conditional_mutual_information",
    },
)
print("the number of the conditional independences of the model")
print(refutation.number_of_constraints_model)
print("the number of the conditional independences the data satisfies")
print(refutation.number_of_constraints_satisfied)
print("the number of the implications that hold true")
print(refutation.number_of_constraints_satisfied)


header("the doubly robust estimator of the upstream")
np.random.seed(SEED)

from sklearn.tree import DecisionTreeClassifier  # noqa: E402

ATE = 10
base_data = dowhy.datasets.linear_dataset(
    beta=ATE,
    num_common_causes=2,
    num_instruments=0,
    num_treatments=1,
    num_samples=20000,
    treatment_is_binary=True,
    outcome_is_binary=False,
    stddev_treatment_noise=10,
)
base = base_data["df"]
mean_w0 = base["W0"].mean()
mean_w1 = base["W1"].mean()


def assign_treatment_linear(row):
    linear_term = 1.5 * row["W0"] + 1.5 * row["W1"]
    prob = 1 / (1 + np.exp(-1 * linear_term))
    return np.random.binomial(1, prob)


def assign_treatment_nonlinear(row):
    if row["W0"] < mean_w0 and row["W1"] < mean_w1:
        return int(np.random.rand() < 0.9)
    return int(np.random.rand() < 0.1)


def assign_effect_linear(row):
    return 6.5 * row["W0"] + 5.5 * row["W1"] + ATE * row["v0"]


def assign_effect_nonlinear(row):
    if row["W0"] < mean_w0 and row["W1"] < mean_w1:
        return 2 * (row["W0"] ** 2) + 2 * (row["W1"] ** 2) + ATE * row["v0"]
    return 2 * (row["W0"] ** 3) + 2 * (row["W1"] ** 3) + ATE * row["v0"]


def build(assign_treatment, assign_effect):
    frame = base.copy(deep=True)
    frame["v0"] = frame.apply(assign_treatment, axis=1)
    frame["y"] = frame.apply(assign_effect, axis=1)
    return frame


def decision_tree():
    return DecisionTreeClassifier(max_depth=2, min_samples_leaf=2000, random_state=42)


for name, frame in (
    ("linear", build(assign_treatment_linear, assign_effect_linear)),
    ("non-linear", build(assign_treatment_nonlinear, assign_effect_nonlinear)),
):
    model = CausalModel(
        data=frame,
        treatment="v0",
        outcome="y",
        graph=base_data["gml_graph"],
    )
    estimand = model.identify_effect(proceed_when_unidentifiable=True)
    print("the estimate of the linear regression of the " + name + " data set")
    print(model.estimate_effect(estimand, method_name="backdoor.linear_regression").value)
    if name == "non-linear":
        # The estimators of the upstream write the column of the propensity
        # score into the frame of the caller, so a second estimator of the
        # propensity score finds the column and builds no model of its own. The
        # doubly robust estimator with the default of the upstream therefore
        # runs before the estimators of the propensity score.
        print("the estimate of the doubly robust estimator with the default of the upstream")
        print(
            model.estimate_effect(
                estimand,
                method_name="backdoor.doubly_robust",
                target_units="ate",
            ).value
        )
    print("the estimate of the propensity score weighting of the " + name + " data set")
    print(
        model.estimate_effect(
            estimand,
            method_name="backdoor.propensity_score_weighting",
            target_units="ate",
            method_params={
                "weighting_scheme": "ips_weight",
                "propensity_score_model": decision_tree(),
            },
        ).value
    )
    print("the estimate of the doubly robust estimator of the " + name + " data set")
    print(
        model.estimate_effect(
            estimand,
            method_name="backdoor.doubly_robust",
            target_units="ate",
            method_params={
                "propensity_score_model": decision_tree(),
                "propensity_score_column": "propensity_score_dr",
            },
        ).value
    )
