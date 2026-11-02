"""The CHANGELOG entry of the v0.0.28 release."""

import io
import sys

PATH = r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\CHANGELOG.md"


def replace(text, old, new):
    if text.count(old) != 1:
        sys.exit("marker not found exactly once:\n" + old[:300])
    return text.replace(old, new)


ANCHOR = "[0.0.27]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.27\n"

ENTRY = """
## [0.0.28] - 2026-11-02

The placebo treatment refuter of the upstream and the significance test of the
refutations, with the test file of the upstream.

### Added

- `refuters` -- the significance test of the refutations, the port of
  `dowhy.causal_refuter.test_significance`: the automatic test uses the two
  sided percentile test of the bootstrap for a hundred simulations and more and
  the test of the normal distribution below that, and either of the two can be
  asked for by name. The refutations report the p-value and the decision of the
  test: the placebo and the dummy outcome refuters test the zero estimate
  against the estimates they produced, the bootstrap, the data subset and the
  random common cause refuters test the estimate of the data.
- `refuters` -- `PlaceboType`, the kind of the placebo the placebo treatment
  refuter builds: a random variable of the kind of the treatment, or the rows
  of the treatment, permuted. `CausalModel::refute_estimate` takes it as a
  labelled optional argument.
- `identifiers` -- `IdentifiedEstimand::with_treatment` and
  `IdentifiedEstimand::with_instrumental_variables`, the copies the placebo
  treatment refuter builds.
- `estimators` -- `CausalEstimator::instrument_name` and
  `CausalEstimator::with_instrument_name`, the copies the placebo treatment
  refuter builds for the instrumental variable method.
- the tests of the upstream file
  `tests/causal_refuters/test_placebo_refuter.py`: the continuous treatment
  case with one common cause and the case without one, the binary treatment
  case and the categorical treatment case, with the tolerances of the upstream
  test.
- the tests of the significance test of the refutations: the two kinds of test,
  the automatic choice between them, the ties and the level of the test.
- `_verify/placebo_reference.py` -- the upstream reference of the placebo
  treatment refuter.
- `_verify/significance_reference.py` -- the expected p-values of the
  significance test of the refutations.

### Fixed

- The permuted placebo of the placebo treatment refuter permutes the rows of
  the treatment, the way the upstream does with
  `data[treatment_names].iloc[permuted_idx].values`. The port drew a new random
  variable for every kind of treatment instead, so the permuted placebo of a
  continuous treatment was the constant zero and its estimate was exactly zero,
  like the estimate of the random data placebo.
- The random data placebo of a categorical treatment draws from the distinct
  categories of the column, the way the upstream does with
  `data[treatment].unique()`, and not from its rows, so a category that holds
  more rows is not drawn more often.

### Notes

- The placebo of the upstream is drawn with the global generator of numpy and
  the port draws it with its own generator, so the refuted estimates of the
  port are not the estimates of the upstream. What the two share is the
  behaviour the upstream test asserts: the effect of the placebo is close to
  zero.
- The upstream's fourth case, the one that gives a non consecutive index to
  the rows of the data, is not portable: the frame of the port holds no index.
- The upstream raises an error when the placebo of an instrumental variable
  method is not the permuted one. The port aborts with the message of the
  upstream, because MoonBit cannot catch an error.
- A refuter that ran no simulation has no distribution to test the estimate
  against, so its p-value is one. The upstream computes the mean of the
  simulations with numpy, which returns `nan` for an empty array, so its
  p-value is `nan`.

[0.0.28]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.28
"""

text = io.open(PATH, encoding="utf-8").read()
text = replace(text, ANCHOR, ANCHOR + ENTRY)
io.open(PATH, "w", encoding="utf-8", newline="\n").write(text)
print("patched")
