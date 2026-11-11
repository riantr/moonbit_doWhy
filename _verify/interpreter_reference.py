"""Print the text the upstream of DoWhy writes for the interpretation of an
estimate, and the numbers of its two visual interpreters, and compare them
with the ones of the port.

The textual interpreter of the upstream reads the estimate and the data of the
model and writes one sentence: how much a unit change of the treatment moves
the expected value of the outcome.

The two visual interpreters of the upstream read the estimate and draw a
figure: the balance of the common causes before and after the adjustment of
the strata, and the distribution of a confounder before and after the weights
of the inverse propensity score weighting.

The fixtures of this script are deterministic, so the two sides work on the
very same rows. The fixtures hold the propensity scores of their rows, so the
two sides build the very same strata.

Run: python _verify/interpreter_reference.py
"""

from __future__ import annotations

import sys

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

import matplotlib

matplotlib.use("Agg")

import numpy as np
import pandas as pd

from dowhy import CausalModel
from dowhy.interpreters.confounder_distribution_interpreter import (
    ConfounderDistributionInterpreter,
)
from dowhy.interpreters.propensity_balance_interpreter import (
    PropensityBalanceInterpreter,
)
from dowhy.interpreters.textual_effect_interpreter import TextualEffectInterpreter

# The fixture of the port: sixty rows of a treatment, of a common cause and of
# an outcome.
N = 60
W = np.array([float(i % 7) - 3.0 for i in range(N)])
V = np.array([float(i % 2) for i in range(N)])
NOISE = np.array([float(i % 5) - 2.0 for i in range(N)]) * 0.25
Y = 2.0 * V + 0.5 * W + NOISE
FRAME = pd.DataFrame({"v0": V, "W0": W, "y": Y})

LCG_MODULUS = 2147483648
LCG_MULTIPLIER = 1103515245
LCG_INCREMENT = 12345
VISUAL_ROWS = 400


def visual_frame(discrete):
    """The fixture of the two visual interpreters.

    The rows hold their propensity score, so the two sides build the very same
    strata and the very same weights.
    """
    state = 42
    treatment = []
    common_cause = []
    outcome = []
    propensity = []
    for index in range(VISUAL_ROWS):
        state = (LCG_MULTIPLIER * state + LCG_INCREMENT) % LCG_MODULUS
        w = state / LCG_MODULUS * 4.0 - 2.0
        state = (LCG_MULTIPLIER * state + LCG_INCREMENT) % LCG_MODULUS
        noise = state / LCG_MODULUS - 0.5
        t = 1 if (index % 3) == 0 else 0
        treatment.append(t)
        common_cause.append(float(int(w * 2.0) + 3.0) if discrete else w)
        outcome.append(2.0 * t + 0.5 * w + noise)
        propensity.append(1.0 / (1.0 + np.exp(-0.8 * w)))
    return pd.DataFrame(
        {
            "v0": treatment,
            "W0": common_cause,
            "y": outcome,
            "propensity_score": propensity,
        }
    )


def model_of(frame):
    return CausalModel(
        data=frame,
        treatment="v0",
        outcome="y",
        common_causes=["W0"],
    )


def balance_of(frame):
    """The balance the upstream computes."""
    model = model_of(frame)
    estimand = model.identify_effect("nonparametric-ate", "default")
    estimate = model.estimate_effect(
        estimand,
        method_name="backdoor.propensity_score_stratification",
        control_value=0,
        treatment_value=1,
        target_units="ate",
    )
    interpreter = PropensityBalanceInterpreter(estimate)
    return estimate, interpreter.interpret(frame)


def distribution_of(frame):
    """The distribution the upstream computes."""
    model = model_of(frame)
    estimand = model.identify_effect("nonparametric-ate", "default")
    estimate = model.estimate_effect(
        estimand,
        method_name="backdoor.propensity_score_weighting",
        control_value=0,
        treatment_value=1,
        target_units="ate",
    )
    interpreter = ConfounderDistributionInterpreter(
        estimate,
        fig_size=(6.0, 4.0),
        font_size=12,
        var_name="W0",
        var_type="discrete",
    )
    interpreter.interpret(frame)
    return estimate, frame


def main() -> int:
    print("=" * 78)
    print("the interpretation of the upstream")
    print("=" * 78)
    model = model_of(FRAME)
    estimand = model.identify_effect("nonparametric-ate", "default")
    estimate = model.estimate_effect(
        estimand,
        method_name="backdoor.linear_regression",
        control_value=0,
        treatment_value=1,
        target_units="ate",
    )
    print("  the value of the estimate = {!r}".format(estimate.value))
    interpreter = TextualEffectInterpreter(estimate)
    text = interpreter.interpret(FRAME)
    print("  the text = {}".format(text))

    print()
    print("=" * 78)
    print("the balance of the upstream")
    print("=" * 78)
    frame = visual_frame(discrete=False)
    estimate, plot_df = balance_of(frame)
    print("  the value of the estimate = {!r}".format(estimate.value))
    print("  the strata of the data = {}".format(sorted(frame["strata"].unique())))
    print(plot_df.to_string())

    print()
    print("=" * 78)
    print("the distribution of the upstream")
    print("=" * 78)
    frame = visual_frame(discrete=True)
    estimate, frame = distribution_of(frame)
    print("  the value of the estimate = {!r}".format(estimate.value))
    weights = (
        frame["v0"] * frame["propensity_score"] ** (-1)
        + (1 - frame["v0"]) * (1 - frame["propensity_score"]) ** (-1)
    )
    counted = frame.groupby(["W0", "v0"]).size().reset_index(name="count")
    weighted = (
        frame.assign(weight=weights)
        .groupby(["W0", "v0"])["weight"]
        .sum()
        .reset_index(name="count")
    )
    print(counted.to_string())
    print(weighted.to_string())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
