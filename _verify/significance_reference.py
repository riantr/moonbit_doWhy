"""The expected numbers of the significance test of the port.

The port's `test_significance` is the port of `dowhy.causal_refuter.test_significance`.
The script computes the p-values of the two kinds of test for the arrays the
MoonBit test uses, so that the expectations of the test are written down.
"""

import math
from statistics import NormalDist

NORM = NormalDist()


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


if __name__ == "__main__":
    main()
