"""The expected numbers of the significance test of the port.

The port's `test_significance` is the port of `dowhy.causal_refuter.test_significance`.
The script computes the p-values of the two kinds of test for the arrays the
MoonBit test uses, so that the expectations of the test are written down.

It also holds the case of the upstream test file `tests/test_causal_refuter.py`,
which tests the two sided percentile test of the bootstrap on five thousand
standard normal deviates.  The script reproduces the generator of the port, so
that the number the MoonBit test asserts is computed here independently of the
toolchain.
"""

import math
import sys
from statistics import NormalDist

import numpy as np

NORM = NormalDist()

MASK = (1 << 64) - 1
TWO_53 = 9007199254740992.0


def bootstrap_p(estimate, simulations):
    """The two sided percentile p-value of the bootstrap."""
    half = sum((1.0 if x > estimate else 0.0) + (0.5 if x == estimate else 0.0) for x in simulations)
    half /= len(simulations)
    return 2 * min(half, 1 - half)


def normal_p(estimate, simulations):
    """The p-value of the test of the normal distribution."""
    mean = sum(simulations) / len(simulations)
    std = math.sqrt(sum((x - mean) ** 2 for x in simulations) / len(simulations))
    z = (estimate - mean) / std
    return 1 - NORM.cdf(z) if z > 0 else NORM.cdf(z)


def show(label, estimate, simulations):
    print(f"--- {label}")
    print(f"  bootstrap p: {bootstrap_p(estimate, simulations)!r}")
    print(f"  normal   p: {normal_p(estimate, simulations)!r}")


class PortGenerator:
    """The generator of the port, the xorshift64 of `utils.Random`.

    The port draws the deviates of the case with its own generator, so the
    script reproduces it here: the state, the shift of the bits, the double
    that holds the 53 bits of the mantissa and the Box-Muller transform.
    """

    def __init__(self, seed: int):
        self.state = seed if seed else 0x9E3779B97F4A7C15

    def next_u64(self) -> int:
        x = self.state
        x = (x ^ (x << 13)) & MASK
        x = (x ^ (x >> 7)) & MASK
        x = (x ^ (x << 17)) & MASK
        self.state = x
        return x

    def next_double(self) -> float:
        return (self.next_u64() >> 11) / TWO_53

    def next_normal(self) -> float:
        u1 = self.next_double()
        u2 = self.next_double()
        if u1 < 1.0e-12:
            u1 = 1.0e-12
        return math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2)


def port_deviations(count: int, seed: int):
    """The deviates the port draws with the given seed."""
    generator = PortGenerator(seed)
    return [generator.next_normal() for _ in range(count)]


def upstream_case():
    """The case of the upstream test file `tests/test_causal_refuter.py`."""
    print()
    print("=== the case of the upstream test file tests/test_causal_refuter.py")
    print("--- the upstream")
    print("  the upstream draws the simulations with the global generator of numpy")
    for seed in (2027, 2028):
        np.random.seed(seed)
        simulations = np.random.normal(0, 1, 5000)
        print(f"  seed {seed}: p-value {bootstrap_p(0.0, simulations)!r}")
    try:
        sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")
        from dowhy.causal_refuter import perform_bootstrap_test

        class Estimate:
            value = 0

        np.random.seed(2027)
        simulations = np.random.normal(0, 1, 5000)
        print("  the function of the upstream:", perform_bootstrap_test(Estimate(), simulations))
    except Exception as error:  # pragma: no cover - the upstream may not import
        print("  the upstream could not be imported:", error)
    print("--- the port")
    for seed in (2027, 2028):
        deviations = port_deviations(5000, seed)
        value = bootstrap_p(0.0, deviations)
        above = sum(1 for x in deviations if x > 0.0)
        print(f"  seed {seed}: p-value {value!r} ({above} of {len(deviations)} above zero)")


def main():
    five = [1.0, 2.0, 3.0, 4.0, 5.0]
    show("five simulations, estimate 0", 0.0, five)
    show("five simulations, estimate 3", 3.0, five)
    show("five simulations, estimate 9", 9.0, five)

    hundred = [float(i) for i in range(100)]
    show("a hundred simulations, estimate 0", 0.0, hundred)
    show("a hundred simulations, estimate 50", 50.0, hundred)

    ties = [1.0, 1.0, 1.0, 2.0, 2.0]
    show("ties, estimate 1", 1.0, ties)

    # The distribution of the refutations of the placebo test of the port.
    print()
    print("the scipy check")
    try:
        from scipy.stats import norm

        print("  norm.cdf(-2.1213203435596424) =", norm.cdf(-2.1213203435596424))
        print("  erf check", 0.5 * (1 + math.erf(-2.1213203435596424 / math.sqrt(2))))
    except ImportError:
        print("  scipy is not available")

    upstream_case()


if __name__ == "__main__":
    main()
