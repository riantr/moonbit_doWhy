"""The upstream reference of the uncertainty estimates of `dowhy.gcm`.

The script runs the upstream `dowhy.gcm.uncertainty` on the fixtures of the
layer and prints the numbers the MoonBit port has to reproduce:

  * the entropy of a Gaussian sample, estimated with a discretisation,
  * the entropy of a Gaussian sample, estimated with the Kozachenko-Leonenko
    estimator,
  * the entropy of a Gaussian sample, estimated with a Gaussian,
  * the variance of a Gaussian sample, in one and in several dimensions,
  * the entropy of the rows of a matrix of probabilities,
  * the entropy of a sample of discrete values.

The fixtures are the ones of the upstream test file
`tests/gcm/test_uncertainty.py`, with the draws of the upstream replaced by the
draws of the generator of the port. The generator of the port is a 64 bit
xorshift whose normal variate is the Box-Muller transform of two of its uniform
variates, and this script reproduces it, so that the fixtures of the port and
the fixtures of this script are the same numbers.

The numbers are the ones of the upstream code itself and not a reading of it: a
re-implementation of the uncertainty estimates in this script would only produce
a second opinion of the upstream instead of its numbers. The port compares its
numbers with the ones printed here.

The upstream package cannot be imported as it is, because its `__init__` pulls
in `causallearn`; the loader of `upstream_gcm.py` reads the modules straight
from their files instead. The upstream modules that the loader does not know
are registered with it before loading them.

Usage:
    python _verify/gcm_uncertainty_reference.py
"""

from __future__ import annotations

import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import upstream_gcm  # noqa: E402
from upstream_gcm import load  # noqa: E402

# The seed of the generator of the fixtures. The generator of the port is
# seeded with the seed of the fixture and its index, so that the fixtures do
# not depend on each other.
SEED = 2025

# The number of the rows of the Gaussian fixtures.
NUM_ROWS = 10000

# The number of the rows of the multivariate Gaussian fixtures. The upstream
# uses a million rows, which is ten times more than the port needs: the
# covariance of the sample is the same number either way, and the port keeps
# the fixture small enough for every backend of the toolchain.
NUM_ROWS_MULTIVARIATE = 100000

# The number of the columns of the multivariate Gaussian fixtures.
NUM_COLUMNS_MULTIVARIATE = 3

# The number of the rows of the discrete fixtures.
NUM_ROWS_DISCRETE = 1000

UNCERTAINTY = None


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


def gaussian_fixture(index: int, rows: int, scale: float) -> np.ndarray:
    """The Gaussian fixture with the given index, rows and scale."""
    rng = fixture_rng(index)
    return rng.normals(rows) * scale


def multivariate_fixture(
    index: int,
    rows: int,
    columns: int,
    scale: float,
) -> np.ndarray:
    """The multivariate Gaussian fixture with the given index."""
    rng = fixture_rng(index)
    values = rng.normals(rows * columns)
    return values.reshape(rows, columns) * scale


def discrete_fixture(index: int, rows: int, columns: int) -> np.ndarray:
    """The discrete fixture with the given index.

    The upstream draws the values with `numpy.random.choice(2, ...)`, which
    draws a coin flip for every value; the port draws the same coin flips from
    its own generator.
    """
    rng = fixture_rng(index)
    out = np.zeros((rows, columns))
    for index_of_value in range(rows * columns):
        out.flat[index_of_value] = 1.0 if rng.next_double() < 0.5 else 0.0
    return out


def register_missing_modules() -> None:
    """Registers the upstream modules the loader does not know.

    The loader of `upstream_gcm.py` owns the list of the modules it reads, but
    it does not know the modules this script needs. Its list is only extended
    here, the file itself is left alone.
    """
    upstream_gcm._PATHS["dowhy.gcm.uncertainty"] = "gcm/uncertainty.py"


def load_upstream() -> None:
    """Loads the upstream modules of the layer."""
    global UNCERTAINTY

    register_missing_modules()
    upstream_gcm._stub_packages()
    UNCERTAINTY = load("dowhy.gcm.uncertainty")


def show(label: str, value: object) -> None:
    """Prints a value with its label and the full precision of a double."""
    print(f"{label} = {repr(float(value))}")  # type: ignore[arg-type]


def show_gaussian(label: str, x: np.ndarray) -> None:
    """Prints every estimate of the layer for the given sample."""
    show(f"{label}.entropy_discretization", UNCERTAINTY.estimate_entropy_using_discretization(x))
    show(f"{label}.entropy_kmeans", UNCERTAINTY.estimate_entropy_kmeans(x))
    show(f"{label}.entropy_gaussian", UNCERTAINTY.estimate_gaussian_entropy(x))
    show(f"{label}.variance", UNCERTAINTY.estimate_variance(x))


def main() -> None:
    """Runs every fixture of the layer."""
    load_upstream()

    x = gaussian_fixture(1, NUM_ROWS, 1.0)
    y = gaussian_fixture(2, NUM_ROWS, 3.0)
    show_gaussian("x", x)
    show_gaussian("y", y)

    x_multi = multivariate_fixture(3, NUM_ROWS_MULTIVARIATE, NUM_COLUMNS_MULTIVARIATE, 1.0)
    y_multi = multivariate_fixture(4, NUM_ROWS_MULTIVARIATE, NUM_COLUMNS_MULTIVARIATE, 3.0)
    show("x_multi.variance", UNCERTAINTY.estimate_variance(x_multi))
    show("y_multi.variance", UNCERTAINTY.estimate_variance(y_multi))
    show("x_multi.entropy_gaussian", UNCERTAINTY.estimate_gaussian_entropy(x_multi))
    show("y_multi.entropy_gaussian", UNCERTAINTY.estimate_gaussian_entropy(y_multi))

    probabilities = np.array(
        [
            [0.25, 0.25, 0.25, 0.25],
            [1.0, 0.0, 0.0, 0.0],
            [0.5, 0.0, 0.0, 0.5],
            [0.0, 0.5, 0.5, 0.0],
            [0.5, 0.0, 0.0, 0.5],
            [1.0, 0.0, 0.0, 0.0],
            [1.0, 0.0, 0.0, 0.0],
        ]
    )
    show(
        "probabilities.entropy",
        UNCERTAINTY.estimate_entropy_of_probabilities(probabilities),
    )

    discrete_one = discrete_fixture(5, NUM_ROWS_DISCRETE, 1)
    discrete_two = discrete_fixture(6, NUM_ROWS_DISCRETE, 2)
    show("discrete_one.entropy", UNCERTAINTY.estimate_entropy_discrete(discrete_one))
    show("discrete_two.entropy", UNCERTAINTY.estimate_entropy_discrete(discrete_two))


if __name__ == "__main__":
    main()
