"""Print the number the upstream of DoWhy computes for the do operator, and
compare it with the one of the port.

The do operator of the upstream returns the mean of the interventional
outcomes of the data: the value of the outcome when the treatment is set to a
value, and not the difference between the two arms.

The fixture of this script is deterministic, so the two sides work on the very
same rows.

Run: python _verify/do_operator_reference.py
"""

from __future__ import annotations

import sys

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

import numpy as np
import pandas as pd

from dowhy import CausalModel
from dowhy.causal_estimators.linear_regression_estimator import LinearRegressionEstimator

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
    print("the do operator of the upstream")
    print("=" * 78)
    model = CausalModel(
        data=FRAME,
        treatment="v0",
        outcome="y",
        common_causes=["W0"],
    )
    estimand = model.identify_effect("nonparametric-ate", "default")
    estimator = LinearRegressionEstimator(estimand)
    estimator.fit(FRAME)
    for value in (0.0, 1.0):
        print("  do(x={}) = {!r}".format(value, estimator.do(x=value, data_df=FRAME)))

    print()
    print("=" * 78)
    print("the do operator of the upstream, on the rows in another order")
    print("=" * 78)
    permuted = FRAME.iloc[[1] + list(range(2, N)) + [0]].reset_index(drop=True)
    for value in (0.0, 1.0):
        print(
            "  do(x={}) = {!r}".format(
                value, estimator.do(x=value, data_df=permuted)
            )
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
