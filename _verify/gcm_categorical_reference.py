"""Runs the upstream on the categorical fixture of its own independence test.

The upstream file `tests/gcm/independence_test/test_generalised_cov_measure.py`
holds two cases with a categorical conditioning variable: the fixture is
independent given its category, and dependent once the category is permuted.

The upstream passes the conditioning variable to `generalised_cov_based`, which
hands it to the automatic model selection of `dowhy.gcm.auto`; that selection
encodes the categorical column before it fits the prediction models. The port
has no model selection, so `generalised_cov_based_with_categorical` encodes the
column itself with the one-hot encoding of the `gcm` package.

This script checks that the two routes lead to the same answer: it computes the
p-value of the case through the upstream's own function and, on the very same
rows, through the upstream's function on an explicitly one-hot encoded
conditioning variable. The two agree to about `1e-3`, which is the spread of the
automatic model selection, and the decision is the same on every seed.

The upstream marks both cases as flaky and draws the fixture from the global
generator of numpy; the port draws its own rows from its own generator, so its
fixture is fixed and its p-value is not one of the numbers below.

Usage:
    python _verify/gcm_categorical_reference.py
"""

from __future__ import annotations

import os
import sys

UPSTREAM_ROOT = os.environ.get(
    "DOWHY_UPSTREAM_ROOT",
    r"D:\src\MiniMax\git\dowhy\dowhy-0.14",
)
if UPSTREAM_ROOT not in sys.path:
    sys.path.insert(0, UPSTREAM_ROOT)

import numpy as np  # noqa: E402

from dowhy.gcm import generalised_cov_based  # noqa: E402

NUM_SAMPLES = 1000
NUM_SEEDS = 6


def categorical_fixture(seed: int):
    """The fixture of the upstream test file, drawn from the given seed."""
    np.random.seed(seed)
    x = np.random.normal(0, 1, NUM_SAMPLES)
    z = [0 if value > 0 else 1 for value in x]
    y = np.array(z) + np.random.randn(len(z))
    labels = np.array(z).astype(str)
    labels[labels == "0"] = "Class 1"
    labels[labels == "1"] = "Class 2"
    return x, y, labels


def one_hot(labels: np.ndarray) -> np.ndarray:
    """The one-hot encoding the port applies, with its categories in order."""
    categories = sorted(set(labels))
    return np.array(
        [[1.0 if value == category else 0.0 for category in categories] for value in labels]
    )


def main() -> None:
    print("seed   upstream(indep)  one-hot(indep)  upstream(perm)  one-hot(perm)")
    for seed in range(NUM_SEEDS):
        x, y, labels = categorical_fixture(seed)
        permuted = labels[np.random.choice(labels.shape[0], labels.shape[0], replace=False)]

        upstream_independent = generalised_cov_based(x, y, labels)
        encoded_independent = generalised_cov_based(x, y, one_hot(labels))
        upstream_permuted = generalised_cov_based(x, y, permuted)
        encoded_permuted = generalised_cov_based(x, y, one_hot(permuted))

        print(
            "%-6d %-16.6f %-16.6f %-16.6f %-16.6f"
            % (
                seed,
                upstream_independent,
                encoded_independent,
                upstream_permuted,
                encoded_permuted,
            )
        )

        # The decision of the two routes has to be the same.
        assert (upstream_independent > 0.05) == (encoded_independent > 0.05)
        assert (upstream_permuted > 0.05) == (encoded_permuted > 0.05)


if __name__ == "__main__":
    main()
