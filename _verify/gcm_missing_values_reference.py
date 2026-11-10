"""An independent reference for the missing values of the automatic assignment.

The script runs the upstream `dowhy.gcm` on the fixtures of the missing values
of the tests of the port and prints the numbers it computes, so that the
expectations of the MoonBit tests can be checked against the Python fixture.

The fixtures of the port are drawn with the generator of the `utils` package of
the port, which is a 64 bit xorshift with the Box-Muller transform. The script
reproduces that generator, so it runs the upstream on the very same rows the
port uses.

The upstream takes the experimental flag `experimental_allow_nans` and it fits
its histogram gradient boosting model, which reads the rows whose features
hold a missing value. The port has no model that reads them, so it drops
them; the script prints the number of the rows every model of the upstream is
fitted on, so that the difference of the two is visible.

Usage:
    python _verify/gcm_missing_values_reference.py
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
from dowhy.gcm.fitting_sampling import draw_samples, fit  # noqa: E402
from dowhy.gcm.whatif import counterfactual_samples, interventional_samples  # noqa: E402

MISSING_ROWS = 600
MISSING_SEED = 20240301
MIXED_SEED = MISSING_SEED + 5
MISSING_SHARE = 0.25
NUM_DRAWN = 5000
NUM_INTERVENTIONAL = 100
NUM_INTERVENTIONAL_MIXED = 10

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


def missing_frame() -> pd.DataFrame:
    """The fixture of the numerical case of the port."""
    rng = PortRandom(MISSING_SEED)
    x = []
    y = []
    z = []
    for _ in range(MISSING_ROWS):
        value = 5.0 * rng.next_normal()
        middle = 2.0 * value + 10.0 + 0.05 * rng.next_normal()
        last = value + middle + 20.0 + 0.05 * rng.next_normal()
        x.append(np.nan if rng.next_double() < MISSING_SHARE else value)
        y.append(middle)
        z.append(np.nan if rng.next_double() < MISSING_SHARE else last)
    return pd.DataFrame({"X": np.array(x), "Y": np.array(y), "Z": np.array(z)})


def missing_mixed_frame() -> pd.DataFrame:
    """The fixture of the mixed case of the port."""
    rng = PortRandom(MIXED_SEED)
    x = []
    y = []
    z = []
    for _ in range(MISSING_ROWS):
        value = 5.0 * rng.next_normal()
        class_zero = value < 0.0
        last = value + (-10.0 if class_zero else 10.0) + 0.1 * rng.next_normal()
        x.append(np.nan if rng.next_double() < MISSING_SHARE else value)
        y.append("Class 0" if class_zero else "Class 1")
        z.append(np.nan if rng.next_double() < MISSING_SHARE else last)
    return pd.DataFrame({"X": np.array(x), "Y": np.array(y), "Z": np.array(z)})


def graph() -> nx.DiGraph:
    """The graph of the fixtures of the port."""
    return nx.DiGraph([("X", "Y"), ("Y", "Z"), ("X", "Z")])


def count_complete(frame: pd.DataFrame) -> dict[str, int]:
    """The number of the rows of every column that hold no missing value."""
    return {name: int(np.sum(~pd.isna(frame[name]).to_numpy())) for name in frame.columns}


def run(name: str, frame: pd.DataFrame, num_interventional: int, mixed: bool) -> None:
    """Run the upstream on the fixture and print the numbers it computes."""
    np.random.seed(7)
    model = ProbabilisticCausalModel(graph())
    print(f"=== {name}")
    print(f"  the rows of the fixture: {len(frame)}")
    print(f"  the rows that hold no missing value: {count_complete(frame)}")
    assign_causal_mechanisms(
        model,
        frame,
        quality=AssignmentQuality.GOOD,
        experimental_allow_nans=True,
    )
    fit(model, frame)
    samples = draw_samples(model, NUM_DRAWN)
    print(f"  the mean of X: {np.mean(samples['X']):.6f}")
    if mixed:
        print(f"  the number of the samples of Y that hold Class 0: {int(np.sum(samples['Y'] == 'Class 0'))}")
    else:
        print(f"  the mean of Y: {np.mean(samples['Y']):.6f}")
    print(f"  the mean of Z: {np.mean(samples['Z']):.6f}")

    interventional = interventional_samples(
        model,
        {"X": lambda x: 10},
        num_samples_to_draw=num_interventional,
    )
    print(f"  the mean of X of the interventional samples: {np.mean(interventional['X']):.6f}")
    if mixed:
        print(f"  the mean of Y of the interventional samples: {np.mean(interventional['Y'] == 'Class 1'):.6f}")
        print(f"  the mean of Z of the interventional samples: {np.mean(interventional['Z']):.6f}")
    else:
        print(f"  the mean of Y of the interventional samples: {np.mean(interventional['Y']):.6f}")
        print(f"  the mean of Z of the interventional samples: {np.mean(interventional['Z']):.6f}")

    counterfactual = counterfactual_samples(
        model,
        {"X": lambda x: 10},
        noise_data=pd.DataFrame({"X": [10], "Y": [1], "Z": [10]}),
    )
    print(f"  the X of the counterfactual: {counterfactual['X'][0]!r}")
    print(f"  the Y of the counterfactual: {counterfactual['Y'][0]!r}")
    print(f"  the Z of the counterfactual: {counterfactual['Z'][0]!r}")


def main() -> None:
    from dowhy.gcm import config

    config.set_default_n_jobs(1)
    run("the numerical case", missing_frame(), NUM_INTERVENTIONAL, mixed=False)
    run("the mixed case", missing_mixed_frame(), NUM_INTERVENTIONAL_MIXED, mixed=True)


if __name__ == "__main__":
    main()
