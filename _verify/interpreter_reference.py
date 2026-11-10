"""Print the text the upstream of DoWhy writes for the interpretation of an
estimate, and compare it with the one of the port.

The textual interpreter of the upstream reads the estimate and the data of the
model and writes one sentence: how much a unit change of the treatment moves
the expected value of the outcome.

The fixture of this script is deterministic, so the two sides work on the very
same rows.

Run: python _verify/interpreter_reference.py
"""

from __future__ import annotations

import sys

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

import numpy as np
import pandas as pd

from dowhy import CausalModel
from dowhy.interpreters.textual_effect_interpreter import TextualEffectInterpreter

# The fixture of the port: sixty rows of a treatment, of a common cause and of
# an outcome.
N = 60
W = np.array([float(i % 7) - 3.0 for i in range(N)])
V = np.array([float(i % 2) for i in range(N)])
NOISE = np.array([float(i % 5) - 2.0 for i in range(N)]) * 0.25
Y = 2.0 * V + 0.5 * W + NOISE
FRAME = pd.DataFrame({"v0": V, "W0": W, "y": Y})


def main() -> int:
    print("=" * 78)
    print("the interpretation of the upstream")
    print("=" * 78)
    model = CausalModel(
        data=FRAME,
        treatment="v0",
        outcome="y",
        common_causes=["W0"],
    )
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
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
