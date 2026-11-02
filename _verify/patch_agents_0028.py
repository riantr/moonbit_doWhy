"""The AGENTS.md of the v0.0.28 release.

The release adds the placebo treatment refuter of the upstream and the
significance test of the refutations, so the working agreements state the
conventions of the two, the layout names the new test files and the
verification section names the new reference scripts.
"""

import io
import sys

PATH = r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\AGENTS.md"


def replace(text, old, new):
    if text.count(old) != 1:
        sys.exit("marker not found exactly once:\n" + old[:300])
    return text.replace(old, new)


OLD_CONVENTIONS = """- The default adjustment set of the backdoor search of the `identifiers`
  package is the set with the fewest instruments, and the set with the fewest
  variables among those, the way `get_default_adjustment_set_id` of the upstream
  picks it. An instrument of the adjustment set lowers the variance of the
  treatment variable, which is the reason the upstream prefers it. The two
  rules agree on every graph whose adjustment sets hold no instrument.
"""

NEW_CONVENTIONS = OLD_CONVENTIONS + """- The placebo of the placebo treatment refuter of the `refuters` package is
  built the way the upstream builds it: a continuous treatment becomes the
  constant zero, a binary treatment becomes a random Bernoulli variable with
  the probability of a half, and a categorical treatment becomes a random draw
  of one of the **distinct** categories of the column. The permuted placebo
  takes the rows of the treatment and permutes them. The kind of the treatment
  follows the column and not a dtype, because the frame of the port holds no
  dtype: a discrete column is a categorical treatment, a numeric column whose
  values are all zero and one is a binary treatment and every other numeric
  column is a continuous one.
- The significance test of a refutation is the port of
  `dowhy.causal_refuter.test_significance`: the automatic test uses the two
  sided percentile test of the bootstrap for a hundred simulations and more and
  the test of the normal distribution below that. The bootstrap test counts the
  estimates that are above the estimate and the half of the ones that are equal
  to it, and the normal test takes the z-score of the estimate against the mean
  and the standard deviation of the simulations, with `ddof = 0`. The
  refutations that sever the causal relation -- the placebo and the dummy
  outcome -- test the **zero** estimate against the estimates they produced,
  the other ones test the estimate of the data.
"""

OLD_REFUTERS_ROW = "| `refuters` | `dowhy.causal_refuters` |"
NEW_REFUTERS_ROW = (
    "| `refuters` | `dowhy.causal_refuters`, with the significance test of the "
    "refutations |"
)

OLD_TESTS_ROW = (
    "| `tests` | the cross-package integration tests, including the cases of the "
    "upstream test files of the causal model, of the estimators and of the two "
    "stage regression estimator |"
)
NEW_TESTS_ROW = (
    "| `tests` | the cross-package integration tests, including the cases of the "
    "upstream test files of the causal model, of the estimators, of the two stage "
    "regression estimator and of the placebo treatment refuter |"
)

OLD_VERIFICATION_TAIL = """- `print_frontdoor_graph.py` prints the graph string of the upstream test as a
  MoonBit literal. The upstream removes the newlines of the string, so the
  graph it reads is one long line, and the literal is generated rather than
  transcribed."""

NEW_VERIFICATION_TAIL = OLD_VERIFICATION_TAIL + """
- `placebo_reference.py` runs the upstream placebo treatment refuter on the cases
  of the upstream test file `tests/causal_refuters/test_placebo_refuter.py` and
  prints the estimate, the refuted estimate, the p-value and the decision of the
  significance test, which is where the expectations of the tests of the port
  come from. The placebo of the upstream is drawn with the global generator of
  numpy and the port draws it with its own generator, so the numbers of the two
  are not the same numbers; what the two share is the behaviour the upstream
  test asserts, that the effect of the placebo is close to zero.
- `significance_reference.py` computes the p-values of the two kinds of the
  significance test of the refutations with the formulas of the upstream, so
  that the expectations of the tests of the port are written down and not
  transcribed."""

text = io.open(PATH, encoding="utf-8").read()
text = replace(text, OLD_CONVENTIONS, NEW_CONVENTIONS)
text = replace(text, OLD_REFUTERS_ROW, NEW_REFUTERS_ROW)
text = replace(text, OLD_TESTS_ROW, NEW_TESTS_ROW)
text = replace(text, OLD_VERIFICATION_TAIL, NEW_VERIFICATION_TAIL)
io.open(PATH, "w", encoding="utf-8", newline="\n").write(text)
print("patched")
