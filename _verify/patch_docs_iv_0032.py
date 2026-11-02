"""Records the cases of the upstream IV estimator test file in the documentation.

The changelog gains the entry of the new release, the notes of the repository
gain the two upstream test files that cannot run with the numpy of today, and
the version of the manifest and of the badge of the readme moves to the next
one.
"""

from __future__ import annotations

import io
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHANGELOG = os.path.join(ROOT, "CHANGELOG.md")
README = os.path.join(ROOT, "README.mbt.md")
AGENTS = os.path.join(ROOT, "AGENTS.md")
MANIFEST = os.path.join(ROOT, "moon.mod")


def patch(path: str, replacements: list) -> None:
    with io.open(path, encoding="utf-8", newline="") as handle:
        source = handle.read()
    for old, new in replacements:
        count = source.count(old)
        if count != 1:
            raise SystemExit(
                "the anchor is present %d times in %s:\n%s" % (count, path, old[:200])
            )
        source = source.replace(old, new)
    with io.open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write(source)
    print("patched", path)


def append(path: str, text: str) -> None:
    with io.open(path, encoding="utf-8", newline="") as handle:
        source = handle.read()
    if not source.endswith("\n"):
        source = source + "\n"
    with io.open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write(source + text)
    print("appended", path)


CHANGELOG_ENTRY = """
## [0.0.32] - 2026-11-02

The cases of the upstream test file of the automatic identification and of the
instrumental variable estimator, and the two upstream test files that cannot
run with the numpy of today.

### Added

- the tests of the upstream file
  `tests/causal_identifiers/test_auto_identifier.py`: its case with two action
  nodes, in both orders.
- the tests of the upstream file
  `tests/causal_estimators/test_instrumental_variable_estimator.py`: the four
  of its sixteen configurations that the estimators of the port can reach --
  one treatment, one instrument, no or one common cause, a continuous or a
  binary treatment -- with the tolerance of the upstream test file.
- `_verify/estimator_iv_reference.py` -- the upstream runs on the very rows the
  port works on. The port and the upstream agree to `2e-13` on the four
  configurations.

### Notes

- The upstream cannot run its own test file of the instrumental variable
  estimator with the numpy of today. Its generator of the data sets converts
  the treatment with `numpy.vectorize(convert_to_binary)`, and
  `convert_to_binary` returns an array of one element, which numpy 2 refuses
  with `ValueError: setting an array element with a sequence`. The upstream
  0.14 predates numpy 2. The port draws its rows with its own generator, so
  the port runs the cases, and the reference script hands the upstream the rows
  of the port, so the upstream runs on them as well.
- The upstream test file of the regression discontinuity estimator cannot run
  either, for two reasons. Its data set has a binary treatment, so the
  generator of the upstream fails the way it fails above, and the estimator
  keeps the name of the running variable, the threshold and the bandwidth at
  `None` when the caller does not give them, so its fit reads the column
  `None` of the data frame, which does not exist. The estimator of the port
  takes the three values as arguments.
- The eight configurations of the upstream test file of the instrumental
  variable estimator with two treatments are out of reach, because the
  estimators of the port are univariate, and the four with two instruments are
  out of reach as well, because the upstream estimates them with the two stage
  least squares of `linearmodels`.

[0.0.32]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.32
"""

README_ANCHOR = """- `gcm` has neither a calibrator nor sample weights for the multiply-robust
  change attribution. The upstream can calibrate the probabilities of its
  classifier on a calibration set and can weigh the samples; the models of the
  upstream mostly do not support the weights either, and the port has neither.
"""

README_NEW = """- `gcm` has neither a calibrator nor sample weights for the multiply-robust
  change attribution. The upstream can calibrate the probabilities of its
  classifier on a calibration set and can weigh the samples; the models of the
  upstream mostly do not support the weights either, and the port has neither.
- The upstream cannot build a data set with a binary treatment with the numpy
  of today. Its `dowhy.datasets.linear_dataset` converts the treatment with
  `numpy.vectorize(convert_to_binary)`, and `convert_to_binary` returns an
  array of one element, which numpy 2 refuses with `ValueError: setting an
  array element with a sequence`. The upstream 0.14 predates numpy 2. Every
  upstream test file that uses a binary treatment therefore fails in the
  upstream itself: the test file of the instrumental variable estimator for
  its eight binary configurations, and the test file of the regression
  discontinuity estimator for its only configuration. The port draws its rows
  with its own generator, so the port runs the cases; the reference scripts
  hand the upstream the rows of the port, so the upstream runs on them as
  well.
- The upstream test file of the regression discontinuity estimator is broken a
  second time. The estimator of the upstream keeps the name of the running
  variable, the threshold and the bandwidth at `None` when the caller does not
  give them, and its fit reads `data[None]`, which is a column of the data
  frame that does not exist. The estimator of the port takes the three values
  as arguments.
"""

AGENTS_ANCHOR = """- The nearest neighbour regression of the `gcm` package finds the neighbours of
  a row with a walk over the rows that are sorted by their first column. The
  walk stops as soon as the rows that are left are further away than the
  neighbours that were found already, which is the exact rule of a scan over
  every row, and it costs `O(n log n)` instead of the `O(n^2)` of the scan.
"""

AGENTS_NEW = """- The nearest neighbour regression of the `gcm` package finds the neighbours of
  a row with a walk over the rows that are sorted by their first column. The
  walk stops as soon as the rows that are left are further away than the
  neighbours that were found already, which is the exact rule of a scan over
  every row, and it costs `O(n log n)` instead of the `O(n^2)` of the scan.
- **The upstream cannot build a data set with a binary treatment with the
  numpy of today.** Its `dowhy.datasets.linear_dataset` converts the treatment
  with `numpy.vectorize(convert_to_binary)`, and `convert_to_binary` returns
  an array of one element, which numpy 2 refuses with `ValueError: setting an
  array element with a sequence`. The upstream 0.14 predates numpy 2. Every
  upstream test file that uses a binary treatment therefore fails in the
  upstream itself: the test file of the instrumental variable estimator for
  its eight binary configurations, and the test file of the regression
  discontinuity estimator for its only configuration. The port draws its rows
  with its own generator, so the port runs the cases, and the reference
  scripts hand the upstream the rows of the port, so the upstream runs on them
  as well.
- **The upstream test file of the regression discontinuity estimator is broken
  a second time.** The estimator of the upstream keeps the name of the running
  variable, the threshold and the bandwidth at `None` when the caller does not
  give them, and its fit reads `data[None]`, which is a column of the data
  frame that does not exist. The estimator of the port takes the three values
  as arguments.
"""

patch(README, [(README_ANCHOR, README_NEW)])
patch(AGENTS, [(AGENTS_ANCHOR, AGENTS_NEW)])
patch(
    MANIFEST,
    [('version = "0.0.31"', 'version = "0.0.32"')],
)
patch(
    README,
    [
        (
            "riantr/moonbit_dowhy-v0.0.31.svg",
            "riantr/moonbit_dowhy-v0.0.32.svg",
        )
    ],
)
append(CHANGELOG, CHANGELOG_ENTRY)
