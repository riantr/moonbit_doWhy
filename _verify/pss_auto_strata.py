"""The number of strata the upstream searches for, on the rows of the port.

The upstream takes the number of strata of the propensity score stratification
estimator from the string `"auto"`: it starts with `0.5 * rows / clipping
threshold` strata and halves the number until at least half of the strata hold
more than `clipping_threshold` units of both arms.

Usage:
    python _verify/pss_auto_strata.py
"""

from __future__ import annotations

import os
import sys

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from port_linear_dataset import binary_treatment_dataset  # noqa: E402

NUM_ROWS = 100000
SEED = 42
CLIPPING_THRESHOLD = 10


def strata_of(scores: np.ndarray, num_strata: float) -> np.ndarray:
    ranks = pd.Series(scores).rank(ascending=True)
    return ((ranks / len(scores)) * num_strata).round(0)


def kept_strata(
    scores: np.ndarray,
    treatment: np.ndarray,
    num_strata: float,
) -> tuple[list, int]:
    strata = strata_of(scores, num_strata)
    frame = pd.DataFrame({"strata": strata, "t": treatment})
    kept = []
    for _, group in frame.groupby("strata"):
        treated = int((group["t"] == 1).sum())
        control = int((group["t"] == 0).sum())
        if min(treated, control) > CLIPPING_THRESHOLD:
            kept.append(group)
    return kept, len(kept)


def main() -> None:
    for num_common_causes in (1, 2):
        data = binary_treatment_dataset(SEED, NUM_ROWS, num_common_causes)
        frame = pd.DataFrame(
            {name: data["columns"][name] for name in data["column_order"]},
        )
        causes = data["common_cause_names"]
        treatment = frame[data["treatment_names"][0]].astype(int)
        model = LogisticRegression()
        model.fit(frame[causes], treatment)
        scores = model.predict_proba(frame[causes])[:, 1]
        num_strata = 0.5 * NUM_ROWS / CLIPPING_THRESHOLD
        print(f"--- {num_common_causes} common causes")
        while True:
            kept, count = kept_strata(scores, treatment, num_strata)
            print(
                f"    num_strata={num_strata} kept={count} "
                f"half={0.5 * num_strata} enough={count >= 0.5 * num_strata}"
            )
            if count >= 0.5 * num_strata:
                break
            num_strata = int(num_strata / 2)
            if num_strata < 2:
                print("    not enough data")
                break


if __name__ == "__main__":
    main()
