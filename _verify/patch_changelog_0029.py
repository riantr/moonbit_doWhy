"""Append the changelog entry of the release 0.0.29."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "CHANGELOG.md"

ENTRY = """
## [0.0.29] - 2026-11-02

The bootstrap refuter and the data subset refuter of the upstream, with their
test files.

### Added

- `refuters` -- the perturbation of the variables of interest of the bootstrap
  refuter: a numeric column gets a Gaussian noise whose standard deviation is
  the given fraction of the standard deviation of the column, a column of zeros
  and ones is flipped and a discrete column gets another category, both with
  the given probability of the change. The variables the refuter perturbs are
  named with the enumeration `RequiredVariables`.
- the tests of the upstream file
  `tests/causal_refuters/test_bootstrap_refuter.py`: the thirteen cases it
  holds, with the tolerances of the upstream test.
- the tests of the upstream file
  `tests/causal_refuters/test_data_subset_refuter.py`: the continuous
  treatment with one common cause and without one, and the binary treatment
  with one common cause, on the hundred thousand rows of the upstream test.
- the tests of the match rule of the propensity score matching estimator: the
  sorted search has to pick the same units as a scan over every unit of the
  other group, also when the scores are tied.

### Fixed

- **The logistic regression of the `utils` package built the diagonal weight
  matrix of its iteratively reweighted least squares step.** The matrix held
  `n * n` doubles, so the fit of a hundred thousand rows asked the allocator
  for eighty gigabytes, and the fit of the upstream data subset test aborted
  the allocator instead of converging. The weighted normal equations are now
  accumulated over the rows of the design matrix, so the fit needs a matrix of
  the size of the number of the columns.
- **The propensity score matching estimator scanned every unit of the other
  group for every match.** The scan costs `O(n * m)` comparisons, which is two
  and a half billion of them for the hundred thousand rows of the upstream test
  suite. The search is now a binary search over the sorted scores, and it picks
  the same unit: a tie is broken with the index of the unit, which is the rule
  of the scan.
- **The adjustment set of an estimand was shared with the estimator that was
  fitted on it.** `IdentifiedEstimand::get_adjustment_set` hands out the array
  that the estimand keeps, so the bootstrap refuter, which pushes the
  instruments onto that array, grew the adjustment set of the estimator that
  was fitted before the refutation ran. The design matrix of the estimate then
  held more columns than the fitted coefficients, and the estimate read past
  the end of the coefficients. The estimator and the refuters copy the
  adjustment set now.
- The data subset refuter sampled its subset **with** replacement. The upstream
  samples it without replacement, with `data.sample(frac=subset_fraction)`.

### Notes

- The category branch of the bootstrap refuter of the upstream is broken: it
  reads a variable that it never defines and it writes the integer zero into
  the rows it does not change. The port perturbs a discrete column with
  another category and leaves the rows it does not change alone.
- The upstream takes the variables the bootstrap refuter perturbs as a
  `bool | int | list`. The port takes an enumeration, because the enumeration
  cannot express a list that names both the variables to keep and the
  variables to leave out, which is the list the upstream raises an error for.
- The refutations of the port are drawn with the generator of the port and the
  refutations of the upstream are drawn with the global generator of numpy, so
  the numbers of the two are not the same numbers. What the two share is the
  behaviour the upstream tests assert: the effect of a subset of the data and
  the effect of a bootstrap sample stay close to the effect of the data.

[0.0.29]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.29
"""


def main() -> None:
    text = TARGET.read_text(encoding="utf-8")
    if "[0.0.29]" in text:
        raise SystemExit("the entry of 0.0.29 is already there")
    if not text.endswith("\n"):
        text += "\n"
    TARGET.write_text(text + ENTRY, encoding="utf-8", newline="")
    print("appended the entry of 0.0.29 to", TARGET)


if __name__ == "__main__":
    main()
