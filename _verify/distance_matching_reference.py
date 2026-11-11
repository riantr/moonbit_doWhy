"""The numbers of the upstream's distance matching estimator.

The script runs the estimator of the upstream
(`dowhy.causal_estimators.distance_matching_estimator.DistanceMatchingEstimator`)
on the fixture of the port and prints the numbers the port has to reproduce.

The fixture is built by a linear congruential generator, so that the port and
the script build the same rows without a shared random number generator.  The
covariates of the fixture are irregular, so that no two candidates of the
nearest neighbour search are at the same distance: the search of the upstream
is a ball tree of scikit-learn and it breaks a tie by the order of the
traversal of the tree, which the port cannot reproduce.

Usage:

    python _verify/distance_matching_reference.py
"""

import sys

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")
import numpy as np
import pandas as pd

from dowhy import EstimandType, identify_effect_auto
from dowhy.causal_estimators.distance_matching_estimator import DistanceMatchingEstimator
from dowhy.graph import build_graph

NUM_ROWS = 30
LCG_MODULUS = 2147483648
LCG_MULTIPLIER = 1103515245
LCG_INCREMENT = 12345


def make_frame(num_rows=NUM_ROWS):
    """The fixture of the port: a treatment, a common cause and an outcome."""
    state = 42
    treatment = []
    common_cause = []
    outcome = []
    for _ in range(num_rows):
        state = (LCG_MULTIPLIER * state + LCG_INCREMENT) % LCG_MODULUS
        w = state / LCG_MODULUS * 4.0 - 2.0
        state = (LCG_MULTIPLIER * state + LCG_INCREMENT) % LCG_MODULUS
        noise = state / LCG_MODULUS - 0.5
        index = len(treatment)
        t = 1 if (index % 3) == 0 else 0
        treatment.append(t)
        common_cause.append(w)
        outcome.append(2.0 * t + 0.5 * w + noise)
    return pd.DataFrame({"v0": treatment, "W0": common_cause, "y": outcome})


def estimand_of(df):
    graph = build_graph(
        action_nodes=["v0"], outcome_nodes=["y"], common_cause_nodes=["W0"]
    )
    return identify_effect_auto(
        graph,
        observed_nodes=list(df.columns),
        action_nodes=["v0"],
        outcome_nodes=["y"],
        estimand_type=EstimandType.NONPARAMETRIC_ATE,
    )


def upstream_numbers(df, num_matches=1):
    estimator = DistanceMatchingEstimator(
        identified_estimand=estimand_of(df), num_matches_per_unit=num_matches
    )
    estimator.fit(df, effect_modifier_names=None)
    numbers = {}
    for units in ("att", "atc", "ate"):
        estimate = estimator.estimate_effect(
            df, control_value=0, treatment_value=1, target_units=units
        )
        numbers[units] = float(estimate.value)
    numbers["symbolic"] = estimator.symbolic_estimator
    return numbers, estimator


def scan_numbers(df, num_matches=1):
    """The reference of the port: an exact scan, the ties broken by the rows."""
    values = df[["W0"]].to_numpy(dtype=float)
    treatment = df["v0"].to_numpy()
    outcome = df["y"].to_numpy()
    treated = [i for i in range(len(df)) if treatment[i] == 1]
    control = [i for i in range(len(df)) if treatment[i] == 0]
    distances = {}
    for i in range(len(df)):
        distances[i] = {
            j: float(np.sum((values[i] - values[j]) ** 2)) for j in range(len(df))
        }
    att = 0.0
    for i in treated:
        matched = sorted(control, key=lambda j: (distances[i][j], j))[:num_matches]
        att += outcome[i] - np.mean([outcome[j] for j in matched])
    att /= len(treated)
    atc = 0.0
    for j in control:
        matched = sorted(treated, key=lambda i: (distances[j][i], i))[:num_matches]
        atc += np.mean([outcome[i] for i in matched]) - outcome[j]
    atc /= len(control)
    ate = (att * len(treated) + atc * len(control)) / (len(treated) + len(control))
    return {"att": float(att), "atc": float(atc), "ate": float(ate)}


def count_ties(df):
    """The number of the queries whose two nearest candidates are equidistant."""
    values = df[["W0"]].to_numpy(dtype=float)
    treatment = df["v0"].to_numpy()
    treated = [i for i in range(len(df)) if treatment[i] == 1]
    control = [i for i in range(len(df)) if treatment[i] == 0]
    ties = 0
    for i in treated:
        ordered = sorted(
            ((float(np.sum((values[i] - values[j]) ** 2)), j) for j in control)
        )
        if len(ordered) > 1 and ordered[0][0] == ordered[1][0]:
            ties += 1
    for j in control:
        ordered = sorted(
            ((float(np.sum((values[j] - values[i]) ** 2)), i) for i in treated)
        )
        if len(ordered) > 1 and ordered[0][0] == ordered[1][0]:
            ties += 1
    return ties


def main():
    df = make_frame()
    print("the fixture")
    print(df.to_string())
    print()
    numbers, estimator = upstream_numbers(df)
    scan = scan_numbers(df)
    print("the upstream")
    for units in ("att", "atc", "ate"):
        print(f"  {units} = {numbers[units]!r}")
    print(f"  symbolic = {numbers['symbolic']}")
    print("the scan of the port")
    for units in ("att", "atc", "ate"):
        print(f"  {units} = {scan[units]!r}")
    print()
    print("the two agree:", all(numbers[u] == scan[u] for u in ("att", "atc", "ate")))
    print("the number of the equidistant queries:", count_ties(df))
    print("the matched indices of the upstream (att):", estimator.matched_indices_att)
    print("the matched indices of the upstream (atc):", estimator.matched_indices_atc)
    print()
    print("two matches per unit")
    numbers2, _ = upstream_numbers(df, num_matches=2)
    scan2 = scan_numbers(df, num_matches=2)
    for units in ("att", "atc", "ate"):
        print(f"  upstream {units} = {numbers2[units]!r}")
        print(f"  scan     {units} = {scan2[units]!r}")


if __name__ == "__main__":
    main()
