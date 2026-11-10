"""An independent reference for the model selection of the automatic assignment.

The script runs the upstream `dowhy.gcm.auto` on the fixtures of the tests of
the port and prints the models it picks and the scores of the models it
evaluated, so that the expectations of the MoonBit tests can be checked
against the Python fixture.

The fixtures of the port are drawn with the generator of the `utils` package of
the port, which is a 64 bit xorshift with the Box-Muller transform. The
script reproduces that generator, so it runs the upstream on the very same
rows the port uses and the two selections can be compared.

The upstream shuffles the rows of its cross validation with the global
generator of numpy and it does not seed it, so its own selection is not
reproducible. The script seeds numpy before every run and it prints the
result of several seeds, so that the stability of the outcome is visible.

The upstream evaluates a zoo of scikit-learn estimators and it picks one of
them. The port evaluates the models of the `gcm` package and it picks one of
them, so the script prints the family of the model the upstream picked: the
linear one or the non-linear one. The tests of the port assert the family
that the upstream picks.

Usage:
    python _verify/gcm_auto_reference.py
"""

from __future__ import annotations

import math
import sys
import types

import networkx as nx
import numpy as np
import pandas as pd

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")
sys.modules.setdefault("cvxpy", types.ModuleType("cvxpy"))

from dowhy.gcm import ProbabilisticCausalModel  # noqa: E402
from dowhy.gcm.auto import AssignmentQuality, assign_causal_mechanisms  # noqa: E402

NUM_FEATURES = 5
NUM_ROWS = 120
SEED = 20240101
TARGET_SEED = 20240102
NOISE = 0.2
WEIGHTS = [2.0, -1.5, 3.0, -0.5, 1.0]

MASK64 = (1 << 64) - 1


class PortRandom:
    """The generator of the `utils` package of the port."""

    def __init__(self, seed: int) -> None:
        self.state = seed if seed != 0 else 0x9E3779B97F4A7C15

    def next_u64(self) -> int:
        x = self.state
        x ^= (x << 13) & MASK64
        x ^= x >> 7
        x ^= (x << 17) & MASK64
        self.state = x
        return x

    def next_double(self) -> float:
        return (self.next_u64() >> 11) / 9007199254740992.0

    def next_normal(self) -> float:
        u1 = self.next_double()
        u2 = self.next_double()
        u1 = u1 if u1 >= 1e-12 else 1e-12
        return math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2)


def port_features() -> list[list[float]]:
    """The features of the fixtures of the port, column by column."""
    rng = PortRandom(SEED)
    return [[rng.next_normal() for _ in range(NUM_ROWS)] for _ in range(NUM_FEATURES)]


def linear_target(columns: list[list[float]]) -> np.ndarray:
    """The target of the linear regression fixture."""
    rng = PortRandom(TARGET_SEED)
    values = []
    for i in range(NUM_ROWS):
        value = sum(WEIGHTS[j] * columns[j][i] for j in range(NUM_FEATURES))
        values.append(value + NOISE * rng.next_normal())
    return np.array(values)


def non_linear_target(columns: list[list[float]]) -> np.ndarray:
    """The target of the non-linear regression fixture."""
    return np.array(
        [
            sum(math.log(abs(columns[j][i])) for j in range(NUM_FEATURES))
            for i in range(NUM_ROWS)
        ]
    )


def linear_labels(columns: list[list[float]]) -> np.ndarray:
    """The target of the linear classification fixture."""
    rng = PortRandom(TARGET_SEED)
    labels = []
    for i in range(NUM_ROWS):
        value = sum(WEIGHTS[j] * columns[j][i] for j in range(NUM_FEATURES))
        probability = 1.0 / (1.0 + math.exp(-value))
        labels.append("Class 0" if rng.next_double() < probability else "Class 1")
    return np.array(labels)


def non_linear_labels(columns: list[list[float]]) -> np.ndarray:
    """The target of the non-linear classification fixture."""
    return np.array(
        [
            "Class 0" if columns[0][i] * columns[1][i] > 0.0 else "Class 1"
            for i in range(NUM_ROWS)
        ]
    )


def run(name: str, target: np.ndarray, quality: AssignmentQuality, seed: int) -> None:
    """Run the upstream on the fixture and print the models it evaluated."""
    np.random.seed(seed)
    columns = port_features()
    data = {"X" + str(j): np.array(columns[j]) for j in range(NUM_FEATURES)}
    data["Y"] = target
    graph = nx.DiGraph([("X" + str(j), "Y") for j in range(NUM_FEATURES)])
    model = ProbabilisticCausalModel(graph)
    summary = assign_causal_mechanisms(model, pd.DataFrame(data), quality=quality)
    mechanism = model.causal_mechanism("Y")
    if hasattr(mechanism, "classifier_model"):
        picked = type(mechanism.classifier_model.sklearn_model).__name__
    else:
        picked = type(mechanism.prediction_model.sklearn_model).__name__
    print(f"  [{name} seed {seed}] the model of the upstream: {picked}")
    for factory, performance, metric in summary._nodes["Y"]["model_performances"]:
        print(f"    {str(factory()):<52} {performance!r}  [{metric}]")


def main() -> None:
    columns = port_features()
    print("=== the fixtures of the port")
    print(f"  the number of the rows: {NUM_ROWS}, the number of the features: {NUM_FEATURES}")
    print(f"  the mean of the first feature: {np.mean(columns[0]):.6f}")
    print(f"  the standard deviation of the first feature: {np.std(columns[0]):.6f}")

    print("=== the linear regression")
    for seed in (7, 11):
        run("linear GOOD", linear_target(columns), AssignmentQuality.GOOD, seed)
    run("linear BETTER", linear_target(columns), AssignmentQuality.BETTER, 7)

    print("=== the non-linear regression")
    for seed in (7, 11):
        run("non-linear GOOD", non_linear_target(columns), AssignmentQuality.GOOD, seed)
    run("non-linear BETTER", non_linear_target(columns), AssignmentQuality.BETTER, 7)

    print("=== the linear classification")
    for seed in (7, 11):
        run("linear GOOD", linear_labels(columns), AssignmentQuality.GOOD, seed)
    run("linear BETTER", linear_labels(columns), AssignmentQuality.BETTER, 7)

    print("=== the non-linear classification")
    for seed in (7, 11):
        run("non-linear GOOD", non_linear_labels(columns), AssignmentQuality.GOOD, seed)
    run("non-linear BETTER", non_linear_labels(columns), AssignmentQuality.BETTER, 7)


if __name__ == "__main__":
    main()
