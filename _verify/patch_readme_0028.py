"""The README of the v0.0.28 release.

The release adds the placebo treatment refuter of the upstream and the
significance test of the refutations, so the README states the conventions of
the two and the places where the port differs from the upstream.
"""

import io
import sys

PATH = r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\README.mbt.md"


def replace(text, old, new):
    if text.count(old) != 1:
        sys.exit("marker not found exactly once:\n" + old[:300])
    return text.replace(old, new)


OLD_BADGE = "moonbit_dowhy-v0.0.27.svg"
NEW_BADGE = "moonbit_dowhy-v0.0.28.svg"

OLD_STATUS = (
    "| Refutation | `dowhy.causal_refuters` | ported (bootstrap, placebo treatment, "
    "data subset, dummy outcome, random common cause, unobserved common cause) |"
)
NEW_STATUS = (
    "| Refutation | `dowhy.causal_refuters` | ported (bootstrap, placebo treatment, "
    "data subset, dummy outcome, random common cause, unobserved common cause, and "
    "the **significance test** of the refutations) |"
)

OLD_TESTS_ROW = (
    "| `tests` | `riantr/moonbit_dowhy/tests` | the cross-package integration tests, "
    "including the cases of the upstream test files of the causal model, of the "
    "estimators and of the two stage regression estimator |"
)
NEW_TESTS_ROW = (
    "| `tests` | `riantr/moonbit_dowhy/tests` | the cross-package integration tests, "
    "including the cases of the upstream test files of the causal model, of the "
    "estimators, of the two stage regression estimator and of the placebo treatment "
    "refuter |"
)

OLD_CONVENTIONS_TAIL = """- The estimator of Kozachenko-Leonenko of the `gcm` package uses the distance
  from every row of the sample to its `k`-th nearest neighbour, where `k` is the
  square root of the number of the rows. The upstream asks
  `sklearn.neighbors.NearestNeighbors` for the `k + 1` nearest neighbours of
  every row and keeps the largest of the distances, which is the distance to
  the `k`-th nearest neighbour that is not the row itself. The port computes
  the same distances: for one column it sorts the values and walks the two
  sides of every value, and for more columns it compares every pair of rows.
"""

NEW_CONVENTIONS_TAIL = OLD_CONVENTIONS_TAIL + """- The placebo of the placebo treatment refuter is built the way the upstream
  builds it: a continuous treatment becomes the constant zero, a binary
  treatment becomes a random Bernoulli variable with the probability of a half,
  and a categorical treatment becomes a random draw of one of the distinct
  categories of the column. The permuted placebo takes the rows of the
  treatment and permutes them.
- The significance test of a refutation is the port of
  `dowhy.causal_refuter.test_significance`: the automatic test uses the two
  sided percentile test of the bootstrap for a hundred simulations and more and
  the test of the normal distribution below that. The bootstrap test counts the
  estimates that are above the estimate and the half of the ones that are equal
  to it, and the normal test takes the z-score of the estimate against the mean
  and the standard deviation of the simulations, with `ddof = 0`.
"""

OLD_DIFFERENCES_ANCHOR = """The `do_samplers`, `timeseries` and `gcm` packages differ from upstream in the
following ways:
"""

NEW_DIFFERENCES_ANCHOR = """The `refuters` package differs from upstream in the following ways:

- The placebo of the placebo treatment refuter is drawn with the generator of
  the port, which is a hand written xorshift64, and not with the global
  generator of numpy, so the refuted estimates of the port are not the
  estimates of the upstream. The behaviour the upstream test asserts is the
  same: the effect of the placebo is close to zero.
- The kind of the treatment is taken from the column itself, because the frame
  of the port holds no dtype. A discrete column is a categorical treatment, a
  numeric column whose values are all zero and one is a binary treatment, and
  every other numeric column is a continuous one. The upstream takes the kind
  from the dtype of the column.
- The upstream raises an error when the placebo of an instrumental variable
  method is not the permuted one. The port aborts with the message of the
  upstream, because MoonBit cannot catch an error.
- A refuter that ran no simulation has no distribution to test the estimate
  against, so its p-value is one. The upstream computes the mean of the
  simulations with numpy, which returns `nan` for an empty array, so its
  p-value is `nan`.

""" + OLD_DIFFERENCES_ANCHOR

text = io.open(PATH, encoding="utf-8").read()
text = replace(text, OLD_BADGE, NEW_BADGE)
text = replace(text, OLD_STATUS, NEW_STATUS)
text = replace(text, OLD_TESTS_ROW, NEW_TESTS_ROW)
text = replace(text, OLD_CONVENTIONS_TAIL, NEW_CONVENTIONS_TAIL)
text = replace(text, OLD_DIFFERENCES_ANCHOR, NEW_DIFFERENCES_ANCHOR)
io.open(PATH, "w", encoding="utf-8", newline="\n").write(text)
print("patched")
