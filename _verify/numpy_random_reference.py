"""The numbers of the generator of numpy.

The upstream of DoWhy draws its randomness from the global generator of numpy,
so a data set of the upstream is only reproducible with the seed it was drawn
with.  This script prints the numbers of numpy for the seeds the tests of the
port use, so that the numbers of the port can be compared with them.

Usage:

    python _verify/numpy_random_reference.py
"""

from __future__ import annotations

import numpy as np


def show(seed: int) -> None:
    print("=" * 70)
    print("the seed %d" % seed)
    print("=" * 70)

    np.random.seed(seed)
    print("the doubles of numpy:")
    print("   ", list(np.random.random_sample(6)))
    print("the uniforms of numpy on [-1, 1]:")
    print("   ", list(np.random.uniform(-1, 1, 5)))
    print("the normals of numpy on [0, 1]:")
    print("   ", list(np.random.normal(0.0, 1.0, 5)))
    print("the normals of numpy on [2, 0.5]:")
    print("   ", list(np.random.normal(2.0, 0.5, 5)))
    print("the Bernoulli of numpy with the probability 0.3:")
    print("   ", list(np.random.binomial(1, 0.3, 10)))
    print("the integers of numpy on [0, 10):")
    print("   ", list(np.random.randint(0, 10, 10)))
    print("the permutation of numpy of ten numbers:")
    print("   ", list(np.random.permutation(10)))
    print()


def show_multivariate(seed: int) -> None:
    print("=" * 70)
    print("the multivariate normal of numpy with the seed %d" % seed)
    print("=" * 70)
    np.random.seed(seed)
    means = np.random.uniform(-1, 1, 3)
    print("the means :", list(means))
    values = np.random.multivariate_normal(means, np.eye(3), 4)
    print("the values:")
    for row in values:
        print("   ", list(row))
    print()


def main() -> None:
    for seed in (42, 7):
        show(seed)
    show_multivariate(42)


if __name__ == "__main__":
    main()
