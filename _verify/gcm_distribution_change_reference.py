"""The upstream reference of the distribution change layer of `dowhy.gcm`.

The script runs the upstream `dowhy.gcm.distribution_change` on the fixtures of
the layer and prints the numbers the MoonBit port has to reproduce:

  * the p-values of the test of the change of a mechanism, for the three
    fixtures of the upstream test file `tests/gcm/test_distribution_change.py`,
  * the attributions of the change of the distribution of the target node, for
    the data of the upstream test file.

The fixtures are the ones of the upstream test file, with the draws of the
upstream replaced by the draws of the generator of the port. The generator of the
port is a 64 bit xorshift whose normal variate is the Box-Muller transform of
two of its uniform variates, and this script reproduces it, so that the fixtures
of the port and the fixtures of this script are the same numbers.

The numbers are the ones of the upstream code itself and not a reading of it: a
re-implementation of the distribution change in this script would only produce a
second opinion of the upstream instead of its numbers. The port compares its
numbers with the ones printed here.

The p-values of the test of the change of a mechanism depend on the permutation
of the rows that the upstream draws from the global generator of numpy, and the
port draws its permutation from its own generator. The p-values are therefore
the same numbers up to the permutation, and the test of the port asserts the
relations the upstream test file asserts.

The upstream package cannot be imported as it is, because its `__init__` pulls
in `causallearn`; the loader of `upstream_gcm.py` reads the modules straight
from their files instead. The upstream modules that the loader does not know
are registered with it before loading them.

Usage:
    python _verify/gcm_distribution_change_reference.py
"""

from __future__ import annotations

import math
import os
import sys

import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import upstream_gcm  # noqa: E402
from upstream_gcm import load  # noqa: E402

# The seed of the generator of the fixtures. The generator of the port is
# seeded with the seed of the fixture and its index, so that the fixtures do
# not depend on each other.
SEED = 2025

# The number of the rows of the fixtures of the test of the change of a
# mechanism. The upstream uses five hundred rows, but the kernel based test of
# the upstream inverts a kernel matrix whose size is the number of the rows of
# the joint sample, and the port does the same with its own inversion. The
# fixtures are therefore a fifth of the size of the ones of the upstream, which
# keeps the gate of the port within the time it needs on every backend.
NUM_ROWS_TEST = 100

# The number of the rows of the fixtures of the change of the distribution.
# The upstream uses a thousand rows, and the port uses a fifth of them for the
# reason of the fixtures of the test of the change of a mechanism.
NUM_ROWS_DATA = 200

ML = None
MECHANISMS = None
CAUSAL_MODELS = None
STOCHASTIC = None
FITTING = None
AUTO = None
SHAPLEY = None
KERNEL = None
DISTRIBUTION_CHANGE = None


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

    def uniforms(self, count: int, low: float, high: float) -> np.ndarray:
        return np.array([low + (high - low) * self.next_double() for _ in range(count)])

    def normals(self, count: int, scale: float) -> np.ndarray:
        return np.array([scale * self.next_normal() for _ in range(count)], dtype=float)


def fixture_rng(index: int) -> PortRandom:
    """The generator of the fixture with the given index."""
    return PortRandom(SEED + index)


def register_missing_modules() -> None:
    """Registers the upstream modules the loader does not know.

    The loader of `upstream_gcm.py` owns the list of the modules it reads, but
    it does not know the modules this script needs. Its list is only extended
    here, the file itself is left alone.
    """
    upstream_gcm._PATHS["dowhy.gcm.fitting_sampling"] = "gcm/fitting_sampling.py"
    upstream_gcm._PATHS["dowhy.gcm.independence_test.kernel"] = "gcm/independence_test/kernel.py"
    upstream_gcm._PATHS["dowhy.gcm.independence_test.kernel_operation"] = (
        "gcm/independence_test/kernel_operation.py"
    )
    upstream_gcm._PATHS["dowhy.gcm.distribution_change"] = "gcm/distribution_change.py"


def load_upstream() -> None:
    """Loads the upstream modules of the layer."""
    global ML, MECHANISMS, CAUSAL_MODELS, STOCHASTIC, FITTING, AUTO, SHAPLEY, KERNEL, DISTRIBUTION_CHANGE

    register_missing_modules()
    upstream_gcm._stub_packages()
    expose_upstream_packages()

    ML = load("dowhy.gcm.ml")
    MECHANISMS = load("dowhy.gcm.causal_mechanisms")
    STOCHASTIC = load("dowhy.gcm.stochastic_models")
    CAUSAL_MODELS = load("dowhy.gcm.causal_models")
    FITTING = load("dowhy.gcm.fitting_sampling")
    AUTO = load("dowhy.gcm.auto")
    SHAPLEY = load("dowhy.gcm.shapley")
    KERNEL = load("dowhy.gcm.independence_test.kernel")

    # The workers of a process pool cannot import the upstream package when it
    # is read from its files, so the runs have to stay in one process.
    config = load("dowhy.gcm.config")
    config.set_default_n_jobs(1)

    DISTRIBUTION_CHANGE = load("dowhy.gcm.distribution_change")


def expose_upstream_packages() -> None:
    """Points the stubbed packages at the real directories of the upstream.

    The loader stubs the packages of the upstream out, so that the modules of
    `dowhy.gcm` can be read without the `causallearn` dependency of the real
    package. The plotting module of `dowhy.gcm.util` reaches the plotting
    module of `dowhy.utils`, which the stubbed packages do not reach, so their
    paths are set to the directories of the upstream.
    """
    root = upstream_gcm.upstream_root()
    for name, relative in (
        ("dowhy", "dowhy"),
        ("dowhy.gcm", os.path.join("dowhy", "gcm")),
        ("dowhy.gcm.util", os.path.join("dowhy", "gcm", "util")),
        ("dowhy.utils", os.path.join("dowhy", "utils")),
    ):
        sys.modules[name].__path__ = [str(root / relative)]


def show(label: str, value: object) -> None:
    """Prints a value with its label and the full precision of a double."""
    print(f"{label} = {repr(float(value))}")  # type: ignore[arg-type]


def mechanism_change_fixtures() -> None:
    """The three fixtures of the test of the change of a mechanism."""
    # The mechanism of the target changed.
    rng = fixture_rng(1)
    x0_org = rng.uniforms(NUM_ROWS_TEST, -1.0, 1.0)
    x1_org = 0.5 * x0_org + rng.normals(NUM_ROWS_TEST, 0.1)
    x0_new = rng.uniforms(NUM_ROWS_TEST, -1.0, 1.0)
    x1_new = 2.0 * x0_new + rng.normals(NUM_ROWS_TEST, 0.1)
    show(
        "mechanism_changed",
        DISTRIBUTION_CHANGE.mechanism_change_test(x1_org, x1_new, x0_org, x0_new),
    )
    show(
        "mechanism_unchanged",
        DISTRIBUTION_CHANGE.mechanism_change_test(x1_org, x1_org, x0_org, x0_org),
    )

    # The mechanism of a root node changed.
    rng = fixture_rng(2)
    x0_org = rng.uniforms(NUM_ROWS_TEST, -1.0, 1.0)
    x0_new = rng.uniforms(NUM_ROWS_TEST, -2.0, 2.0)
    show("root_changed", DISTRIBUTION_CHANGE.mechanism_change_test(x0_org, x0_new))
    show("root_unchanged", DISTRIBUTION_CHANGE.mechanism_change_test(x0_org, x0_org))

    # The noise of the mechanism changed.
    rng = fixture_rng(3)
    x0_org = rng.uniforms(NUM_ROWS_TEST, -1.0, 1.0)
    x1_org = 2.0 * x0_org + rng.normals(NUM_ROWS_TEST, 0.1)
    x0_new = rng.uniforms(NUM_ROWS_TEST, -1.0, 1.0)
    x1_new = 2.0 * x0_new + rng.normals(NUM_ROWS_TEST, 1.0)
    show(
        "noise_changed",
        DISTRIBUTION_CHANGE.mechanism_change_test(x1_org, x1_new, x0_org, x0_new),
    )
    show(
        "noise_unchanged",
        DISTRIBUTION_CHANGE.mechanism_change_test(x1_org, x1_org, x0_org, x0_org),
    )


def distribution_change_fixture() -> tuple[pd.DataFrame, pd.DataFrame]:
    """The data of the change of the distribution.

    The data is the one of the upstream test file
    `tests/gcm/test_distribution_change.py`: the relation of the original data
    is `X2 = 0.5 X0` and the relation of the new data is `X2 = 2 X0`, and the
    relation of the target changed as well.
    """
    rng = fixture_rng(4)
    x0 = rng.uniforms(NUM_ROWS_DATA, -1.0, 1.0)
    x1 = 2.0 * x0 + rng.normals(NUM_ROWS_DATA, 0.1)
    x2 = 0.5 * x0 + rng.normals(NUM_ROWS_DATA, 0.1)
    x3 = 0.5 * x2 + rng.normals(NUM_ROWS_DATA, 0.1)
    original = pd.DataFrame(data={"X0": x0, "X1": x1, "X2": x2, "X3": x3})

    x0 = rng.uniforms(NUM_ROWS_DATA, -1.0, 1.0)
    x1 = 2.0 * x0 + rng.normals(NUM_ROWS_DATA, 0.1)
    x2 = 2.0 * x0 + rng.normals(NUM_ROWS_DATA, 0.1)
    x3 = 3.0 * x2 + rng.normals(NUM_ROWS_DATA, 0.1)
    new = pd.DataFrame(data={"X0": x0, "X1": x1, "X2": x2, "X3": x3})
    return original, new


def causal_model() -> object:
    """The causal model of the fixture of the change of the distribution."""
    import networkx as nx

    model = CAUSAL_MODELS.ProbabilisticCausalModel(
        nx.DiGraph([("X0", "X1"), ("X0", "X2"), ("X2", "X3")])
    )
    model.set_causal_mechanism("X0", STOCHASTIC.EmpiricalDistribution())
    model.set_causal_mechanism(
        "X1", MECHANISMS.AdditiveNoiseModel(ML.create_linear_regressor())
    )
    model.set_causal_mechanism(
        "X2", MECHANISMS.AdditiveNoiseModel(ML.create_linear_regressor())
    )
    model.set_causal_mechanism(
        "X3", MECHANISMS.AdditiveNoiseModel(ML.create_linear_regressor())
    )
    return model


def show_attributions(label: str, attributions: dict) -> None:
    """Prints the attributions of the change of the distribution."""
    for node in sorted(attributions.keys()):
        show(f"{label}.{node}", attributions[node])


def main() -> None:
    """Runs every fixture of the layer."""
    load_upstream()
    mechanism_change_fixtures()

    original, new = distribution_change_fixture()
    shapley_config = SHAPLEY.ShapleyConfig(n_jobs=1)

    model = causal_model()
    attributions, mechanism_changes, _, _ = DISTRIBUTION_CHANGE.distribution_change(
        model,
        original,
        new,
        "X3",
        shapley_config=shapley_config,
        return_additional_info=True,
    )
    show_attributions("distribution_change", attributions)
    for node in sorted(mechanism_changes.keys()):
        print(f"distribution_change.{node}.mechanism_changed = {mechanism_changes[node]}")

    model_old = causal_model()
    model_new = causal_model()
    FITTING.fit(model_old, original)
    FITTING.fit(model_new, new)
    show_attributions(
        "distribution_change_of_graphs",
        DISTRIBUTION_CHANGE.distribution_change_of_graphs(model_old, model_new, "X3"),
    )


if __name__ == "__main__":
    main()
