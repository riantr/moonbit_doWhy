"""The numbers of the scenarios of the notebooks of the upstream.

The upstream executes the notebooks of its documentation and asserts that no
cell of them fails. The script runs the scenarios of the three notebooks the
port mirrors and prints the numbers they compute, so the tests of the port can
assert the same range.

The notebooks of the upstream do not seed the global generator of numpy, so
their numbers are not reproducible. The script seeds it and prints the numbers
of the seeded run, which is the run the port reproduces.

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

print("=== the causal api of the upstream")
np.random.seed(SEED)
data = dowhy.datasets.linear_dataset(
    beta=5,
    num_common_causes=1,
    num_samples=1000,
    num_instruments=0,
    treatment_is_binary=True,
)
frame = data["df"]
treatment = data["treatment_name"][0]
outcome = data["outcome_name"][0]
common_cause = data["common_causes_names"][0]
graph = build_graph_from_str(data["dot_graph"])
types = {treatment: "b", outcome: "c", common_cause: "c"}
treated = frame.causal.do(
    x={treatment: 1}, variable_types=types, outcome=outcome, graph=graph
)
control = frame.causal.do(
    x={treatment: 0}, variable_types=types, outcome=outcome, graph=graph
)
print("the mean of the treated outcome")
print(treated[outcome].mean())
print("the mean of the control outcome")
print(control[outcome].mean())
print("the difference of the two means")
print((treated[outcome] - control[outcome]).mean())
print()

print("=== the interpreter of the upstream")
np.random.seed(SEED)
data = dowhy.datasets.linear_dataset(
    beta=1,
    num_common_causes=5,
    num_samples=1000,
    num_instruments=2,
    treatment_is_binary=True,
)
frame = data["df"]
model = CausalModel(
    data=frame,
    treatment=data["treatment_name"],
    outcome=data["outcome_name"],
    graph=data["gml_graph"],
    instruments=data["instrument_names"],
)
estimand = model.identify_effect()
estimate = model.estimate_effect(
    estimand, method_name="backdoor.propensity_score_stratification", target_units="ate"
)
print("the estimate of the stratification")
print(estimate.value)
print()

print("=== the basic gcm of the upstream")
np.random.seed(SEED)
graph = nx.DiGraph([("X", "Y"), ("Y", "Z")])
causal_model = gcm.StructuralCausalModel(graph)
values_of_x = np.random.normal(0, 1, 1000)
values_of_y = 2 * values_of_x + np.random.normal(0, 1, 1000)
values_of_z = 3 * values_of_y + np.random.normal(0, 1, 1000)
frame = pd.DataFrame(
    data=dict(X=values_of_x, Y=values_of_y, Z=values_of_z),
)
summary = auto.assign_causal_mechanisms(causal_model, frame)
print("the number of the nodes of the graph")
print(len(causal_model.graph.nodes))
gcm.fit(causal_model, frame)
samples = gcm.interventional_samples(
    causal_model, {"Y": lambda y: 2.34}, num_samples_to_draw=100
)
print("the mean of the intervened outcome")
print(samples["Y"].mean())
print("the mean of the downstream outcome")
print(samples["Z"].mean())
