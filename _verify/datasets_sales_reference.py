"""An independent reference for the sales data set of the port.

The script runs `dowhy.datasets.sales_dataset` the way the upstream test
`tests/test_datasets.py` runs it and prints the numbers the upstream produces,
so that the expected values of the MoonBit tests can be checked against the
Python fixture.

The upstream draws its numbers with the global generator of NumPy, so the
script repeats the fixture over several seeds: the relations of the upstream
test hold for every one of them, and the absolute numbers differ from seed to
seed.  The script prints the mean of the three columns the upstream test
compares, the number of the shopping events and the shape of the frame.

The script also prints the mean and the variance of the distributions the port
draws from, so that the sampler of the port can be checked against the ones of
SciPy.

Usage:
    python _verify/datasets_sales_reference.py
"""

from __future__ import annotations

import sys

import numpy as np
import scipy.stats as ss

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

from dowhy.datasets import sales_dataset  # noqa: E402


def describe(frame) -> None:
    print("  columns:", list(frame.columns))
    print("  rows:", len(frame))
    print("  shopping events:", int(np.sum(frame["Shopping Event?"])))
    print("  mean profit:", float(np.mean(frame["Profit"])))
    print("  mean page views:", float(np.mean(frame["Page Views"])))
    print("  mean sold units:", float(np.mean(frame["Sold Units"])))
    print("  mean ad spend:", float(np.mean(frame["Ad Spend"])))
    print("  mean unit price:", float(np.mean(frame["Unit Price"])))
    print("  mean revenue:", float(np.mean(frame["Revenue"])))
    print("  mean operational cost:", float(np.mean(frame["Operational Cost"])))


def main() -> None:
    print("=== the fixture of the upstream test ===")
    for seed in (2024, 2025, 2026):
        np.random.seed(seed)
        print(f"--- seed {seed}")
        first = sales_dataset("2021-01-01", "2021-12-31", num_shopping_events=10)
        second = sales_dataset(
            "2021-01-01",
            "2021-12-31",
            num_shopping_events=10,
            change_of_price=0.9,
            page_visitor_factor=0.85,
        )
        print("  first:")
        describe(first)
        print("  second:")
        describe(second)
        print("  profit first > second:", bool(np.mean(first["Profit"]) > np.mean(second["Profit"])))
        print(
            "  page views first > second:",
            bool(np.mean(first["Page Views"]) > np.mean(second["Page Views"])),
        )
        print(
            "  sold units first < second:",
            bool(np.mean(first["Sold Units"]) < np.mean(second["Sold Units"])),
        )

    print()
    print("=== the draws of the upstream, for the sampler of the port ===")
    np.random.seed(2024)
    draws = {
        "poisson(10000)": ss.poisson.rvs(mu=10000, size=200000),
        "poisson(2500)": ss.poisson.rvs(mu=2500, size=200000),
        "poisson(1.5)": ss.poisson.rvs(mu=1.5, size=200000),
        "halfnorm(0.5, 0.01)": ss.halfnorm.rvs(loc=0.5, scale=0.01, size=200000),
        "halfnorm(1000, 100)": ss.halfnorm.rvs(loc=1000, scale=100, size=200000),
        "halfnorm(500000, 10)": ss.halfnorm.rvs(loc=500000, scale=10, size=200000),
        "uniform(100, 1100)": ss.uniform.rvs(loc=100, scale=1000, size=200000),
    }
    for name, values in draws.items():
        print(f"  {name}: mean {float(np.mean(values)):.6f} variance {float(np.var(values)):.6f}")

    print()
    print("=== the shape of the demand of the upstream ===")
    # The upstream replaces a price change of zero by one, so the ratio of the
    # demand and of the price change is the elasticity on the days whose price
    # is the original one.
    for change_of_price in (1.0, 0.9):
        base_price = 1000 * change_of_price
        price_changes = 1 - base_price / 1000
        demand_changes = price_changes * 1.25 * (1 + price_changes)
        if price_changes == 0:
            demand_changes = 1.0
            price_changes = 1.0
        print(
            f"  change_of_price {change_of_price}: price change {price_changes}"
            f" demand change {demand_changes} ratio {demand_changes / price_changes}"
        )


if __name__ == "__main__":
    main()
