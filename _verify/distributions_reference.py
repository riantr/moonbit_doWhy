"""An independent reference for the distribution functions of the port.

This script runs `scipy.stats` on the very arguments the `utils` package of
the port evaluates, and prints the numbers the MoonBit implementation has to
reproduce. The MoonBit side has no SciPy, so the reference values live here
and in the test file; this script is the evidence that they are the SciPy ones
and not numbers that were made up while porting.

Usage:
    python _verify/distributions_reference.py
"""

from __future__ import annotations

import numpy as np
from scipy import special, stats

# The chi-square arguments of `src/utils/distributions_test.mbt`.
CHI2_CDF = [(0.5, 1.0), (1.0, 3.0), (3.84, 1.0), (10.0, 5.0), (23.0, 10.0), (0.001, 4.0)]
CHI2_SF = [(0.5, 1.0), (3.84, 1.0), (10.0, 5.0), (23.0, 10.0)]
CHI2_PPF = [(0.5, 1.0), (0.95, 3.0), (0.99, 10.0), (0.025, 1.0), (0.999, 7.0)]

# The F distribution arguments of `src/utils/distributions_test.mbt`.
F_CDF = [(1.0, 3.0, 10.0), (2.5, 5.0, 20.0), (0.5, 1.0, 1.0), (4.0, 12.0, 30.0)]
F_SF = [(1.0, 3.0, 10.0), (2.5, 5.0, 20.0), (0.5, 1.0, 1.0), (4.0, 12.0, 30.0)]
F_PPF = [(0.5, 3.0, 10.0), (0.95, 5.0, 20.0), (0.975, 1.0, 1.0), (0.99, 12.0, 30.0)]

# The correlation samples of `src/utils/distributions_test.mbt`.
X = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
Y = [2.0, 1.0, 4.0, 3.0, 6.0, 5.0, 8.0, 7.0]
XT = [1.0, 2.0, 2.0, 3.0, 4.0, 4.0]
YT = [1.0, 3.0, 2.0, 4.0, 3.0, 4.0]

# The arguments of the regularised incomplete gamma function. The shape one is
# the exponential distribution, and the shape one half is the chi-square
# distribution with one degree of freedom.
GAMMAINC = [(1.0, 1.0), (1.0, 2.0), (2.5, 3.0), (0.5, 0.25)]

# The arguments of the error function and of the standard normal distribution.
ERFC = [0.0, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, -0.5, -1.0]
ERF = [0.0, 0.25, 0.5, 1.0, 2.0, -0.5]
NORMAL_CDF = [-3.0, -1.959963984540054, -1.0, 0.0, 1.0, 1.959963984540054, 3.0]
NORMAL_PPF = [0.001, 0.025, 0.1, 0.5, 0.9, 0.975, 0.999]

# The arguments of the regularised upper incomplete gamma function.
GAMMAINCC = [(0.5, 0.25), (0.5, 4.0), (1.0, 2.0), (0.5, 0.0)]


def main() -> None:
    print("CHI2_CDF")
    for x, df in CHI2_CDF:
        print(f"  chi2_cdf({x}, {df}) = {stats.chi2.cdf(x, df):.15f}")

    print("CHI2_SF")
    for x, df in CHI2_SF:
        print(f"  chi2_sf({x}, {df}) = {stats.chi2.sf(x, df):.15f}")

    print("CHI2_PPF")
    for p, df in CHI2_PPF:
        print(f"  chi2_ppf({p}, {df}) = {stats.chi2.ppf(p, df):.15f}")

    print("F_CDF")
    for f, df1, df2 in F_CDF:
        print(f"  f_cdf({f}, {df1}, {df2}) = {stats.f.cdf(f, df1, df2):.15f}")

    print("F_SF")
    for f, df1, df2 in F_SF:
        print(f"  f_sf({f}, {df1}, {df2}) = {stats.f.sf(f, df1, df2):.15f}")

    print("F_PPF")
    for p, df1, df2 in F_PPF:
        print(f"  f_ppf({p}, {df1}, {df2}) = {stats.f.ppf(p, df1, df2):.15f}")

    print("CORRELATIONS")
    print(f"  pearson(x, y) = {np.corrcoef(X, Y)[0][1]:.15f}")
    print(f"  spearman(x, y) = {stats.spearmanr(X, Y).statistic:.15f}")
    print(f"  spearman(xt, yt) = {stats.spearmanr(XT, YT).statistic:.15f}")
    print(f"  kendall(x, y) = {stats.kendalltau(X, Y).statistic:.15f}")
    print(f"  kendall(xt, yt) = {stats.kendalltau(XT, YT).statistic:.15f}")

    print("GAMMAINC")
    for a, x in GAMMAINC:
        print(f"  gammainc({a}, {x}) = {stats.gamma.cdf(x, a):.15f}")

    print("ERFC")
    for x in ERFC:
        print(f"  erfc({x}) = {special.erfc(x):.15f}")

    print("ERF")
    for x in ERF:
        print(f"  erf({x}) = {special.erf(x):.15f}")

    print("NORMAL_CDF")
    for z in NORMAL_CDF:
        print(f"  normal_cdf({z}) = {stats.norm.cdf(z):.15f}")

    print("NORMAL_PPF")
    for p in NORMAL_PPF:
        print(f"  normal_ppf({p}) = {stats.norm.ppf(p):.15f}")

    print("GAMMAINCC")
    for a, x in GAMMAINCC:
        print(f"  gammaincc({a}, {x}) = {special.gammaincc(a, x):.15f}")


if __name__ == "__main__":
    main()
