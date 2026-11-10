"""An independent reference for the density estimators of the port.

The script runs the upstream `dowhy.gcm.density_estimators` on the fixtures of
the tests of the port and prints the numbers it produces, so that the
expectations of the MoonBit tests can be checked against the Python fixture.

The upstream draws the centres of the components of its Gaussian mixture at
random and does not seed its generator, so its own fit is not reproducible:
the script prints the densities of several seeds and the range they live in.
The case of the upstream asserts the length of the result and not its values,
and the test of the port asserts the same relation.

Usage:
    python _verify/gcm_density_estimators_reference.py
"""

from __future__ import annotations

import sys

import numpy as np

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

from dowhy.gcm.density_estimators import (  # noqa: E402
    GaussianMixtureDensityEstimator,
    KernelDensityEstimator1D,
)


def mixture_fixture() -> np.ndarray:
    """The fixture of the Gaussian mixture of the upstream test."""
    return np.array([[0, 1], [0, 2], [1, 0], [2, 3]], dtype=float)


def kernel_fixture() -> np.ndarray:
    """The fixture of the kernel density estimator of the upstream test."""
    return np.array([[0], [2], [1], [3]], dtype=float)


def main() -> None:
    print("=== the Gaussian mixture")
    data = mixture_fixture()
    print(f"  the number of the components: {int(np.ceil(np.sqrt(data.shape[0] / 2)))}")
    for seed in range(5):
        np.random.seed(seed)
        estimator = GaussianMixtureDensityEstimator()
        estimator.fit(data)
        densities = estimator.density(data)
        print(f"  seed {seed}: {len(densities)} densities {densities.tolist()}")

    print()
    print("=== the kernel density estimator of one dimension")
    rows = kernel_fixture()
    estimator = KernelDensityEstimator1D()
    estimator.fit(rows)
    densities = estimator.density(rows)
    print(f"  {len(densities)} densities {densities.tolist()}")

    print()
    print("=== the Gaussian mixture with a given number of the components")
    np.random.seed(0)
    estimator = GaussianMixtureDensityEstimator(num_components=5)
    try:
        estimator.fit(data)
        densities = estimator.density(data)
        print(f"  {len(densities)} densities {densities.tolist()}")
    except ValueError as error:
        print("  the upstream refuses the fit:", error)


if __name__ == "__main__":
    main()
