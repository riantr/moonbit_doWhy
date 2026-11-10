"""The reference numbers of the stochastic models of the `gcm` package.

The script runs the upstream `dowhy.gcm.stochastic_models` on the very rows the
MoonBit port works on, and prints the numbers the port has to reproduce. The
rows are generated with a Python replica of the xorshift generator of
`src/utils/random.mbt`, so the two sides fit the same rows and the parameters
the upstream estimates are the parameters the port has to estimate.

The upstream draws its samples from the global generator of numpy, so the
samples of the upstream and of the port are different numbers. The script
therefore prints the samples of the port, which the replica reproduces, and the
samples of the upstream for the record.

The upstream `BayesianGaussianMixtureDistribution` is not part of the port, so
the two tests of the upstream that use it have no counterpart here.

Usage:
    python _verify/gcm_stochastic_models_reference.py
"""

from __future__ import annotations

import os
import sys

import numpy as np
from scipy import stats

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from upstream_gcm import load  # noqa: E402

MASK64 = (1 << 64) - 1


class Xorshift:
    """The generator of `src/utils/random.mbt`."""

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

    def next_int(self, bound: int) -> int:
        if bound <= 0:
            return 0
        return self.next_u64() % bound

    def next_normal(self) -> float:
        u1 = self.next_double()
        u2 = self.next_double()
        u1 = 1.0e-12 if u1 < 1.0e-12 else u1
        return np.sqrt(-2.0 * np.log(u1)) * np.cos(2.0 * np.pi * u2)

    def next_gamma(self, shape: float, scale: float) -> float:
        """The gamma variate of `src/utils/random.mbt`."""
        if shape < 1.0:
            uniform = self.next_double()
            powered = 1.0e-12 if uniform < 1.0e-12 else uniform ** (1.0 / shape)
            return self.next_gamma(shape + 1.0, scale) * powered
        d = shape - 1.0 / 3.0
        c = 1.0 / np.sqrt(9.0 * d)
        while True:
            x = self.next_normal()
            v = (1.0 + c * x) ** 3
            if v > 0.0:
                u = self.next_double()
                log_u = -27.631021 if u < 1.0e-12 else np.log(u)
                if log_u < 0.5 * x * x + d * (1.0 - v + np.log(v)):
                    return d * v * scale


# The seeds of the fixtures, the same as the ones of the MoonBit tests.
SEED_FIT = 2030
SEED_AUTO = 2031
SEED_AUTO_DRAW = 2032
SEED_SCALED = 2033
SEED_EMPIRICAL = 2034
SEED_EMPIRICAL_DRAW = 2035
SEED_BETA = 2036
SEED_DETECT = 2037
SEED_DETECT_DRAW = 2038

# The number of rows of the fixtures.
FIT_ROWS = 1000
AUTO_ROWS = 5000
DRAWN_ROWS = 1000
SCALED_ROWS = 10000
EMPIRICAL_ROWS = 1000
BETA_ROWS = 10000
DETECT_ROWS = 2000

# The location and the scale of the distribution the scaled fixture is drawn
# from.
SCALED_LOC = 3.0
SCALED_SCALE = 2.0

# The shapes of the beta distribution the beta fixture is drawn from.
BETA_A = 2.0
BETA_B = 2.0


def normal_rows(seed: int, rows: int) -> np.ndarray:
    """The standard normal rows of a fixture."""
    rng = Xorshift(seed)
    return np.array([rng.next_normal() for _ in range(rows)])


def normal_samples(seed: int, rows: int, loc: float, scale: float) -> np.ndarray:
    """The samples of a normal distribution, the way the port draws them."""
    rng = Xorshift(seed)
    return np.array([loc + scale * rng.next_normal() for _ in range(rows)])


def beta_samples(seed: int, rows: int, a: float, b: float) -> np.ndarray:
    """The samples of a beta distribution, the way the port draws them.

    The port draws a beta variate as the ratio of two gamma variates, so the
    replica draws it the same way.
    """
    rng = Xorshift(seed)
    values = []
    for _ in range(rows):
        first = rng.next_gamma(a, 1.0)
        second = rng.next_gamma(b, 1.0)
        values.append(first / (first + second))
    return np.array(values)


def empirical_samples(data_seed: int, draw_seed: int, rows: int, size: int) -> np.ndarray:
    """The samples of an empirical distribution, the way the port draws them.

    The data of the distribution and the draws come from two generators, like
    they do in the MoonBit test.
    """
    values = normal_rows(data_seed, rows)
    rng = Xorshift(draw_seed)
    return np.array([values[rng.next_int(rows)] for _ in range(size)])


def main() -> None:
    # The upstream `dowhy.gcm.ml` has to be read before the modules that import
    # the names it re-exports, so it is loaded first. The divergence module is
    # loaded as well, because the automatic selection of the family of a
    # distribution imports it while it runs.
    load("dowhy.gcm.ml")
    load("dowhy.gcm.config")
    load("dowhy.gcm.auto")
    load("dowhy.gcm.divergence")
    models = load("dowhy.gcm.stochastic_models")

    # The fit of a normal distribution on the rows of the fixture.
    rows = normal_rows(SEED_FIT, FIT_ROWS)
    distribution = models.ScipyDistribution(stats.norm)
    distribution.fit(rows.reshape(-1, 1))
    print("FIT_NORMAL")
    print(f"  mean = {np.mean(rows):.12f}")
    print(f"  std = {np.std(rows):.12f}")
    print(f"  upstream_loc = {distribution.parameters['loc']:.12f}")
    print(f"  upstream_scale = {distribution.parameters['scale']:.12f}")

    # The fit of a normal distribution on the rows of the automatic fixture.
    auto_rows = normal_rows(SEED_AUTO, AUTO_ROWS)
    automatic = models.ScipyDistribution(stats.norm)
    automatic.fit(auto_rows.reshape(-1, 1))
    print("FIT_NORMAL_AUTOMATIC")
    print(f"  mean = {np.mean(auto_rows):.12f}")
    print(f"  std = {np.std(auto_rows):.12f}")
    print(f"  upstream_loc = {automatic.parameters['loc']:.12f}")
    print(f"  upstream_scale = {automatic.parameters['scale']:.12f}")

    # The samples the port draws from the fitted distribution.
    drawn = normal_samples(SEED_AUTO_DRAW, DRAWN_ROWS, automatic.parameters["loc"], automatic.parameters["scale"])
    print("DRAWN_SAMPLES")
    print(f"  mean = {np.mean(drawn):.12f}")
    print(f"  std = {np.std(drawn):.12f}")
    print(f"  first = {drawn[0]:.12f}")
    print(f"  second = {drawn[1]:.12f}")
    print(f"  third = {drawn[2]:.12f}")

    # The samples the upstream draws from the very same distribution.
    np.random.seed(SEED_AUTO_DRAW)
    upstream_drawn = automatic.draw_samples(DRAWN_ROWS)
    print(f"  upstream_mean = {np.mean(upstream_drawn):.12f}")
    print(f"  upstream_std = {np.std(upstream_drawn):.12f}")

    # The fit of a normal distribution on the samples of another one.
    scaled = normal_samples(SEED_SCALED, SCALED_ROWS, SCALED_LOC, SCALED_SCALE)
    scaled_distribution = models.ScipyDistribution(stats.norm)
    scaled_distribution.fit(scaled.reshape(-1, 1))
    print("FIT_NORMAL_OF_NORMAL")
    print(f"  mean = {np.mean(scaled):.12f}")
    print(f"  std = {np.std(scaled):.12f}")
    print(f"  upstream_loc = {scaled_distribution.parameters['loc']:.12f}")
    print(f"  upstream_scale = {scaled_distribution.parameters['scale']:.12f}")

    # The empirical distribution and the samples it draws.
    empirical = models.EmpiricalDistribution()
    empirical_rows = normal_rows(SEED_EMPIRICAL, EMPIRICAL_ROWS)
    empirical.fit(empirical_rows.reshape(-1, 1))
    empirical_drawn = empirical_samples(SEED_EMPIRICAL, SEED_EMPIRICAL_DRAW, EMPIRICAL_ROWS, DRAWN_ROWS)
    print("EMPIRICAL")
    print(f"  distinct = {len(set(empirical_drawn.tolist()))}")
    print(f"  first = {empirical_drawn[0]:.12f}")
    print(f"  second = {empirical_drawn[1]:.12f}")
    print(f"  third = {empirical_drawn[2]:.12f}")
    print(f"  in_data = {bool(np.all(np.isin(empirical_drawn, empirical_rows)))}")

    # The parameters of a distribution that was given them.
    fixed = models.ScipyDistribution(stats.norm, loc=0, scale=1)
    print("FIXED_PARAMETERS")
    print(f"  loc = {fixed.parameters['loc']:.12f}")
    print(f"  scale = {fixed.parameters['scale']:.12f}")

    # The beta distribution and its fit on the rows of the port.
    beta_rows = beta_samples(SEED_BETA, BETA_ROWS, BETA_A, BETA_B)
    beta_distribution = models.ScipyDistribution(stats.beta)
    beta_distribution.fit(beta_rows.reshape(-1, 1))
    print("FIT_BETA")
    print(f"  mean = {np.mean(beta_rows):.12f}")
    print(f"  lowest = {np.min(beta_rows):.12f}")
    print(f"  highest = {np.max(beta_rows):.12f}")
    print(f"  upstream_a = {beta_distribution.parameters['a']:.12f}")
    print(f"  upstream_b = {beta_distribution.parameters['b']:.12f}")
    print(f"  upstream_loc = {beta_distribution.parameters['loc']:.12f}")
    print(f"  upstream_scale = {beta_distribution.parameters['scale']:.12f}")

    # The automatic selection of the family of a distribution.
    detect_rows = normal_rows(SEED_DETECT, DETECT_ROWS)
    detected = models.ScipyDistribution()
    detected.fit(detect_rows.reshape(-1, 1))
    print("AUTOMATIC_SELECTION")
    print(f"  mean = {np.mean(detect_rows):.12f}")
    print(f"  std = {np.std(detect_rows):.12f}")
    print(f"  upstream_distribution = {detected.scipy_distribution.name}")
    print(f"  upstream_loc = {detected.parameters['loc']:.12f}")
    print(f"  upstream_scale = {detected.parameters['scale']:.12f}")


if __name__ == "__main__":
    main()
