"""The data set of the integration test of the book.

The rows are the ones of the test `test_dowhy_chapter_7` of the upstream file
`tests/causal-inference-discovery-book/test_causal_inference_discovery_book.py`,
the one of the chapter 7 of the book "Causal Inference and Discovery in
Python" (https://www.packtpub.com/product/causal-inference-and-discovery-in-python/9781804612989)
by Aleksander Molak.

The test class of the upstream has the fixture `fixed_seed`, which seeds the
generator of NumPy with zero before the test runs, so the rows of the data set
are the same on every run. The fixture is reproduced here by the seed of
`sample_rows`.

The graph of the test is the one of the upstream as well: the treatment `X`
has the mediator `Z` and the outcome `Y`, and the unobserved variable `U` is
a common cause of the treatment and of the outcome.

Usage:
    from book_scm import GML_GRAPH, sample_rows
"""

from __future__ import annotations

import numpy as np
from scipy import stats

# The seed of the fixture `fixed_seed` of the upstream test.
SEED = 0

# The number of rows the upstream test draws.
NUM_ROWS = 1000

# The graph of the upstream test, character for character.
GML_GRAPH = """
        graph [
            directed 1
            
            node [
                id "X" 
                label "X"
            ]     
            node [
                id "Z"
                label "Z"
            ]
            node [
                id "Y"
                label "Y"
            ]
            node [
                id "U"
                label "U"
            ]
            
            edge [
                source "X"
                target "Z"
            ]
            edge [
                source "Z"
                target "Y"
            ]
            edge [
                source "U"
                target "X"
            ]
            edge [
                source "U"
                target "Y"
            ]
        ]
        """


class GPSMemorySCM:
    """The structural causal model of the upstream test.

    The model is the one of the upstream test file; it is reproduced here
    because the upstream test file is not a module of the package.
    """

    def __init__(self, random_seed=None):
        self.random_seed = random_seed
        self.u_x = stats.truncnorm(0, np.inf, scale=5)
        self.u_y = stats.norm(scale=2)
        self.u_z = stats.norm(scale=2)
        self.u = stats.truncnorm(0, np.inf, scale=4)

    def sample(self, sample_size=100, treatment_value=None):
        """Samples from the SCM"""
        if self.random_seed:
            np.random.seed(self.random_seed)

        u_x = self.u_x.rvs(sample_size)
        u_y = self.u_y.rvs(sample_size)
        u_z = self.u_z.rvs(sample_size)
        u = self.u.rvs(sample_size)

        if treatment_value:
            gps = np.array([treatment_value] * sample_size)
        else:
            gps = u_x + 0.7 * u

        hippocampus = -0.6 * gps + 0.25 * u_z
        memory = 0.7 * hippocampus + 0.25 * u

        return gps, hippocampus, memory

    def intervene(self, treatment_value, sample_size=100):
        """Intervenes on the SCM"""
        return self.sample(treatment_value=treatment_value, sample_size=sample_size)


def sample_rows(seed: int = SEED, num_rows: int = NUM_ROWS) -> dict[str, np.ndarray]:
    """The rows of the data set of the upstream test.

    The seed of the fixture `fixed_seed` of the upstream is set before the
    model draws, so the rows are the same on every run.
    """
    np.random.seed(seed)
    scm = GPSMemorySCM()
    gps, hippocampus, memory = scm.sample(num_rows)
    return {"X": gps, "Z": hippocampus, "Y": memory}
