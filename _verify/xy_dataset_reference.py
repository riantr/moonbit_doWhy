"""The upstream reference of the data set `dowhy.datasets.xy_dataset`.

The script runs the upstream `dowhy.datasets.xy_dataset` with the global
generator of numpy seeded with the seed of the fixture and prints the rows the
MoonBit port has to reproduce:

  * the hidden confounder, the time variable, the treatment and the outcome of
    the data set with one common cause,
  * the same columns of the data set with three common causes,
  * the same columns of the data set without an effect,
  * the same columns of the data set of the non-linear relation.

The numbers are the ones of the upstream code itself and not a reading of it:
the port draws its rows from the generator of numpy, with the same seed and the
same order of the draws, so the rows of the port and the rows of this script
are the same numbers.

Usage:
    python _verify/xy_dataset_reference.py
"""

from __future__ import annotations

import sys

import numpy as np

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

from dowhy.datasets import xy_dataset  # noqa: E402

# The seed of the generator of the fixtures.
SEED = 2025

# The number of the rows of the fixtures.
NUM_ROWS = 6

# The number of the rows the script prints.
NUM_PRINTED_ROWS = 4


def describe(name: str, data: dict, columns: list[str]) -> None:
    frame = data["df"]
    print(f"--- {name}")
    print("  columns:", list(frame.columns))
    print("  treatment:", data["treatment_name"])
    print("  outcome:", data["outcome_name"])
    print("  common causes:", data["common_causes_names"])
    print("  time:", data["time_val"])
    print("  ate:", data["ate"])
    for column in columns:
        values = [float(v) for v in frame[column].to_numpy()[:NUM_PRINTED_ROWS]]
        print(f"  {column}: {values}")


def main() -> None:
    print("=== the data set with one common cause ===")
    np.random.seed(SEED)
    data = xy_dataset(NUM_ROWS)
    describe("one common cause", data, ["Treatment", "Outcome", "w0", "s"])

    print()
    print("=== the data set with three common causes ===")
    np.random.seed(SEED)
    data = xy_dataset(NUM_ROWS, num_common_causes=3)
    describe("three common causes", data, ["Treatment", "Outcome", "w0", "s", "w1", "w2"])

    print()
    print("=== the data set without an effect ===")
    np.random.seed(SEED)
    data = xy_dataset(NUM_ROWS, effect=False)
    describe("without an effect", data, ["Treatment", "Outcome", "w0", "s"])

    print()
    print("=== the data set of the non-linear relation ===")
    np.random.seed(SEED)
    data = xy_dataset(NUM_ROWS, is_linear=False)
    describe("non-linear", data, ["Treatment", "Outcome", "w0", "s"])

    print()
    print("=== the data set with the deviation of the error terms ===")
    np.random.seed(SEED)
    data = xy_dataset(NUM_ROWS, sd_error=2.5)
    describe("sd_error 2.5", data, ["Treatment", "Outcome", "w0", "s"])


if __name__ == "__main__":
    main()
