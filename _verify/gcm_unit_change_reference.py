"""The upstream reference of the unit change layer of `dowhy.gcm`.

The script runs the upstream `dowhy.gcm.unit_change` on the fixtures of the
layer and prints the numbers the MoonBit port has to reproduce:

  * the contributions of the inputs and of the mechanism to the change of the
    output of a linear mechanism,
  * the contributions of the inputs and of the mechanism to the change of the
    output of a non-linear mechanism,
  * the contributions of the inputs to the change of the output of a linear
    mechanism, without the mechanism as a player,
  * the contributions of the inputs to the change of the output of a non-linear
    mechanism, without the mechanism as a player.

The fixtures are the ones of the upstream test file
`tests/gcm/test_unit_change.py`, with the draws of the upstream replaced by the
draws of the generator of the port. The generator of the port is a 64 bit
xorshift whose normal variate is the Box-Muller transform of two of its uniform
variates, and this script reproduces it, so that the fixtures of the port and
the fixtures of this script are the same numbers.

The numbers are the ones of the upstream code itself and not a reading of it: a
re-implementation of the unit change in this script would only produce a second
opinion of the upstream instead of its numbers. The port compares its numbers
with the ones printed here.

The upstream package cannot be imported as it is, because its `__init__` pulls
in `causallearn`; the loader of `upstream_gcm.py` reads the modules straight
from their files instead. The upstream modules that the loader does not know
are registered with it before loading them.

Usage:
    python _verify/gcm_unit_change_reference.py
"""

from __future__ import annotations

import math
import os
import sys

import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import upstream_gcm  # noqa: E402
from upstream_gcm import load, upstream_root  # noqa: E402

# The seed of the generator of the fixtures. The generator of the port is
# seeded with the seed of the fixture and its index, so that the fixtures do
# not depend on each other.
SEED = 2025

# The number of the rows of the fixtures.
NUM_ROWS = 100

# The number of the rows the script prints.
NUM_PRINTED_ROWS = 3

# The upstream modules of the layer.
ML = None
MECHANISMS = None
CAUSAL_MODELS = None
STOCHASTIC = None
FITTING = None
AUTO = None
SHAPLEY = None
UNIT_CHANGE = None


class PortRandom:
    """The generator of the `utils` package of the port.

    The port draws the samples of its fixtures from its own generator, so that
    the fixtures of the port and the fixtures of this script are the same
    numbers. The generator is a 64 bit xorshift, and its normal variate is the
    Box-Muller transform of two of its uniform variates.
    """

    MASK = (1 << 64) - 1

    def __init__(self, seed: int) -> None:
        self.state = seed & self.MASK
        if self.state == 0:
            self.state = 0x9E3779B97F4A7C15

    def next_u64(self) -> int:
        x = self.state
        x ^= (x << 13) & self.MASK
        x ^= x >> 7
        x ^= (x << 17) & self.MASK
        self.state = x
        return x

    def next_double(self) -> float:
        return (self.next_u64() >> 11) / 9007199254740992.0

    def next_normal(self) -> float:
        u1 = self.next_double()
        u2 = self.next_double()
        if u1 < 1.0e-12:
            u1 = 1.0e-12
        return math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2)

    def normals(self, count: int) -> np.ndarray:
        return np.array([self.next_normal() for _ in range(count)], dtype=float)


def fixture_rng(index: int) -> PortRandom:
    """The generator of the fixture with the given index."""
    return PortRandom(SEED + index)


def register_missing_modules() -> None:
    """Registers the upstream modules the loader does not know.

    The loader of `upstream_gcm.py` owns the list of the modules it reads, but
    it does not know the modules this script needs. Its list is only extended
    here, the file itself is left alone.
    """
    upstream_gcm._PATHS["dowhy.gcm.unit_change"] = "gcm/unit_change.py"
    upstream_gcm._PATHS["dowhy.gcm.fitting_sampling"] = "gcm/fitting_sampling.py"
    upstream_gcm._PATHS["dowhy.gcm.util"] = "gcm/util/__init__.py"


def expose_upstream_packages() -> None:
    """Points the stubbed packages at the real directories of the upstream.

    The loader stubs the packages of the upstream out, so that the modules of
    `dowhy.gcm` can be read without the `causallearn` dependency of the real
    package. The plotting module of `dowhy.gcm.util` reaches the plotting
    module of `dowhy.utils`, which the stubbed packages do not reach, so their
    paths are set to the directories of the upstream.
    """
    root = upstream_root()
    for name, relative in (
        ("dowhy", "dowhy"),
        ("dowhy.gcm", os.path.join("dowhy", "gcm")),
        ("dowhy.gcm.util", os.path.join("dowhy", "gcm", "util")),
        ("dowhy.utils", os.path.join("dowhy", "utils")),
    ):
        sys.modules[name].__path__ = [str(root / relative)]


def load_upstream() -> None:
    """Loads the upstream modules of the layer."""
    global ML, MECHANISMS, CAUSAL_MODELS, STOCHASTIC, FITTING, AUTO, SHAPLEY, UNIT_CHANGE

    register_missing_modules()
    upstream_gcm._stub_packages()
    expose_upstream_packages()

    ML = load("dowhy.gcm.ml")
    load("dowhy.gcm.util")
    config = load("dowhy.gcm.config")
    MECHANISMS = load("dowhy.gcm.causal_mechanisms")
    STOCHASTIC = load("dowhy.gcm.stochastic_models")
    CAUSAL_MODELS = load("dowhy.gcm.causal_models")
    FITTING = load("dowhy.gcm.fitting_sampling")
    AUTO = load("dowhy.gcm.auto")
    SHAPLEY = load("dowhy.gcm.shapley")

    # The workers of a process pool cannot import the upstream package when it
    # is read from its files, so the runs have to stay in one process.
    config.set_default_n_jobs(1)

    UNIT_CHANGE = load("dowhy.gcm.unit_change")


def show(label: str, value: object) -> None:
    """Prints a value with its label and the full precision of a double."""
    print(f"{label} = {repr(float(value))}")  # type: ignore[arg-type]


def show_frame(label: str, frame: pd.DataFrame) -> None:
    """Prints the first rows of a frame with its label."""
    print(f"== {label} ==")
    for index in range(min(NUM_PRINTED_ROWS, len(frame))):
        row = frame.iloc[index]
        values = ", ".join(f"{column}={float(row[column])!r}" for column in frame.columns)
        print(f"  row {index}: {values}")
    for column in frame.columns:
        show(f"{label}.{column}.sum", frame[column].sum())


def fixture() -> tuple[pd.DataFrame, pd.DataFrame, object, object]:
    """The background data, the foreground data and the two mechanisms."""
    rng = fixture_rng(1)
    a1 = rng.normals(NUM_ROWS)
    b1 = rng.normals(NUM_ROWS)
    c1 = 2.0 * a1 + 3.0 * b1
    a2 = rng.normals(NUM_ROWS)
    b2 = rng.normals(NUM_ROWS)
    c2 = 3.0 * a2 + 2.0 * b2

    background_df = pd.DataFrame(data={"A": a1, "B": b1})
    foreground_df = pd.DataFrame(data={"A": a2, "B": b2})

    from sklearn.linear_model import LinearRegression

    background_mechanism = UNIT_CHANGE.SklearnLinearRegressionModel(
        LinearRegression(fit_intercept=False).fit(np.column_stack((a1, b1)), c1)
    )
    foreground_mechanism = UNIT_CHANGE.SklearnLinearRegressionModel(
        LinearRegression(fit_intercept=False).fit(np.column_stack((a2, b2)), c2)
    )
    return background_df, foreground_df, background_mechanism, foreground_mechanism


def main() -> None:
    """Runs every fixture of the layer."""
    load_upstream()
    background_df, foreground_df, background_mechanism, foreground_mechanism = fixture()
    shapley_config = SHAPLEY.ShapleyConfig(n_jobs=1)

    show_frame(
        "unit_change_linear",
        UNIT_CHANGE.unit_change_linear(
            background_mechanism,
            background_df,
            foreground_mechanism,
            foreground_df,
            ["A", "B"],
        ),
    )
    show_frame(
        "unit_change_nonlinear",
        UNIT_CHANGE.unit_change_nonlinear(
            background_mechanism,
            background_df,
            foreground_mechanism,
            foreground_df,
            ["A", "B"],
            shapley_config=shapley_config,
        ),
    )
    show_frame(
        "unit_change_linear_input_only",
        UNIT_CHANGE.unit_change_linear_input_only(
            background_mechanism,
            background_df,
            foreground_df,
            ["A", "B"],
        ),
    )
    show_frame(
        "unit_change_nonlinear_input_only",
        UNIT_CHANGE.unit_change_nonlinear_input_only(
            background_mechanism,
            background_df,
            foreground_df,
            ["A", "B"],
            shapley_config=shapley_config,
        ),
    )


if __name__ == "__main__":
    main()
