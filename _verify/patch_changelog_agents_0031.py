"""Records the multiply-robust change attribution in the changelog and in the notes.

The changelog of the repository lists its releases in ascending order, so the
entry of the new release is appended at the end of the file.  The notes of the
repository hold the conventions of the port; the three details of the
multiply-robust change attribution that decide whether the attribution is the
one of the upstream are added to them.
"""

from __future__ import annotations

import io
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHANGELOG = os.path.join(ROOT, "CHANGELOG.md")
AGENTS = os.path.join(ROOT, "AGENTS.md")

CHANGELOG_ENTRY = """
## [0.0.31] - 2026-11-02

The multiply-robust causal change attribution of the upstream, with the test
file of the upstream and the two bugs the test file found.

### Added

- `gcm` -- the port of `dowhy.gcm.distribution_change_robust`, the estimator of
  the paper "Multiply-Robust Causal Change Attribution" of Quintas-Martinez,
  Bahadori, Santiago, Mu, Janzing and Heckerman (ICML 2024): the attribution of
  the change of the mean or of the variance of a target node to the variables
  upstream of it, with the regression method, the re-weighting method and the
  multiply-robust method, and with the cross-fitting of the nuisance
  parameters.
- `gcm` -- the nearest neighbour regression of `dowhy.gcm.ml.regression`, which
  is the `KNeighborsRegressor` of scikit-learn with its default parameters:
  five neighbours and the uniform weights. The neighbours of a row are found
  with a walk over the rows that are sorted by their first column, which finds
  the same neighbours as a scan over every row and costs `O(n log n)` instead
  of the `O(n^2)` of the scan.
- the tests of the upstream file
  `tests/gcm/test_distribution_change_robust.py`: the two cases it holds, on
  the ten thousand rows of the upstream test, with the nearest neighbour
  regressor and with ten folds of the cross-fitting.
- `_verify/gcm_distribution_change_robust_reference.py` -- the upstream runs on
  the very rows the port works on. The port and the upstream agree to `0.004`
  on the attribution of the mean and to `0.05` on the attribution of the
  variance. The difference is the split of the rows of the cross-fitting: the
  port splits them with its own shuffle and the upstream with the
  `StratifiedKFold` of scikit-learn.

### Fixed

- **The functional of the variance of the port was the square of the difference
  of the two moments, and the functional of the upstream is the second moment
  of the target minus the square of the first moment of the target.** The
  upstream writes the functional as `(theta(y²) - theta(y)) ** 2`, but the
  exponent of Python binds tighter than the subtraction, so the upstream
  computes `theta(y²) - theta(y) ** 2`. The attribution of the port was about
  twenty times the attribution of the upstream: `17.66`, `-40.72` and `-54.71`
  for the three variables of the test, where the upstream gives `0.91`, `-1.38`
  and `-1.35`.
- **The port standardised the weights of every group of the multiply-robust
  estimator, and the upstream standardises the weights of the last group
  alone.** The statement that standardises the weights is outside the loop over
  the groups in the upstream, so the weights of the other groups keep their
  scale and are used with that scale.

### Notes

- The rows of the test of the upstream are drawn with the global generator of
  numpy, which is not seeded, so the numbers of the upstream move from one run
  to the other; the upstream marks its test file as flaky for that reason. The
  rows of the port are drawn with the generator of the `utils` package, so the
  numbers of the port are the same on every run, and they are the numbers the
  reference script measures on the upstream.
- The port has neither a calibrator nor sample weights for the multiply-robust
  change attribution. The upstream can calibrate the probabilities of its
  classifier on a calibration set and can weigh the samples; the models of the
  upstream mostly do not support the weights either, and the port has neither.
- The upstream evaluates the set function of its Shapley estimator in a
  process pool, so the values it computes are invisible to an instrumentation of
  the process of the caller. The diagnosis of the functional of the variance
  needed a Shapley configuration with a single job.

[0.0.31]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.31
"""

AGENTS_CONVENTIONS_OLD = """- The rows of the data sets of the upstream test suites are drawn by the
  upstream with the global generator of numpy, so the upstream runs its
  estimator and refuter test suites on a random draw of the rows. The rows of
  the port are fixed, and the seed of every suite is the one for which the
  **upstream** stays inside the tolerances of its own test files on the very
  same rows: `_verify/estimator_suite_reference.py` runs the upstream on the
  rows of the port. Two of the eighteen cases of the estimator suite are
  decided by the draw: the inverse propensity score weighting estimator with
  two common causes and the doubly robust estimator with two common causes and
  a binary outcome are both outside the tolerance of the upstream on the rows
  of the seed 42, and the upstream is outside it as well.
"""

AGENTS_CONVENTIONS_NEW = """- The rows of the data sets of the upstream test suites are drawn by the
  upstream with the global generator of numpy, so the upstream runs its
  estimator and refuter test suites on a random draw of the rows. The rows of
  the port are fixed, and the seed of every suite is the one for which the
  **upstream** stays inside the tolerances of its own test files on the very
  same rows: `_verify/estimator_suite_reference.py` runs the upstream on the
  rows of the port. Two of the eighteen cases of the estimator suite are
  decided by the draw: the inverse propensity score weighting estimator with
  two common causes and the doubly robust estimator with two common causes and
  a binary outcome are both outside the tolerance of the upstream on the rows
  of the seed 42, and the upstream is outside it as well.
- The multiply-robust causal change attribution of the `gcm` package is the port
  of `dowhy.gcm.distribution_change_robust`, and three details of it decide
  whether the attribution is the one of the upstream:
  - **the functional of the variance is the second moment of the target minus
    the square of the first moment of the target.** The upstream writes it as
    `(theta(y²) - theta(y)) ** 2`, but the exponent of Python binds tighter
    than the subtraction, so the upstream computes `theta(y²) - theta(y) ** 2`.
    The port computes the functional of the upstream, and the attribution of the
    variance is about twenty times smaller than the square of the difference
    would give.
  - **only the weights of the last group of the estimator are standardised.**
    The upstream standardises the weights outside its loop over the groups, so
    the weights of the other groups keep their scale. The port standardises the
    last weight alone, the way the upstream does.
  - **the estimate of the change is the mean of the scores of the estimator,
    and its standard error is the one of
    `statsmodels.stats.weightstats.DescrStatsW` with the weights of one**, so
    the standard error is the standard deviation of the scores with `ddof = 0`
    divided by the square root of the number of the scores less one.
- The nearest neighbour regression of the `gcm` package finds the neighbours of
  a row with a walk over the rows that are sorted by their first column. The
  walk stops as soon as the rows that are left are further away than the
  neighbours that were found already, which is the exact rule of a scan over
  every row, and it costs `O(n log n)` instead of the `O(n^2)` of the scan.
- The rows of the cross-fitting of the multiply-robust change attribution are
  split by the port with its own shuffle and by the upstream with the
  `StratifiedKFold` of scikit-learn. The two splits differ, so the attribution
  of the port and the attribution of the upstream are close to each other and
  not equal to each other: on the ten thousand rows of the upstream test file
  they agree to `0.004` for the mean and to `0.05` for the variance.
"""

AGENTS_LAYOUT_OLD = (
    "| `gcm` | the portable core of `dowhy.gcm`: the statistics, the confidence "
    "intervals, the divergences, the density estimators, the Shapley values, the "
    "independence tests, the prediction models, the causal mechanisms, the "
    "feature relevance, the intrinsic causal influence, the equation parser, the "
    "fitting of a causal model, the what-if queries, the validation layer, the "
    "falsification layer, the model evaluation layer, the anomaly detection "
    "layer, the unit change layer, the uncertainty estimates, the distribution "
    "change layer and the arrow strength layer |"
)
AGENTS_LAYOUT_NEW = (
    "| `gcm` | the portable core of `dowhy.gcm`: the statistics, the confidence "
    "intervals, the divergences, the density estimators, the Shapley values, the "
    "independence tests, the prediction models, the causal mechanisms, the "
    "feature relevance, the intrinsic causal influence, the equation parser, the "
    "fitting of a causal model, the what-if queries, the validation layer, the "
    "falsification layer, the model evaluation layer, the anomaly detection "
    "layer, the unit change layer, the uncertainty estimates, the distribution "
    "change layer -- the plain one and the multiply-robust one -- and the arrow "
    "strength layer |"
)

AGENTS_TESTS_OLD = (
    "| `tests` | the cross-package integration tests, including the cases of the "
    "upstream test files of the causal model, of the estimators, of the two "
    "stage regression estimator, of the placebo treatment refuter, of the "
    "bootstrap refuter and of the data subset refuter |"
)
AGENTS_TESTS_NEW = (
    "| `tests` | the cross-package integration tests, including the cases of the "
    "upstream test files of the causal model, of the estimators, of the two "
    "stage regression estimator, of the placebo treatment refuter, of the "
    "bootstrap refuter and of the data subset refuter |"
)


def append(path: str, text: str) -> None:
    with io.open(path, encoding="utf-8", newline="") as handle:
        source = handle.read()
    if not source.endswith("\n"):
        source = source + "\n"
    with io.open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write(source + text)
    print("appended", path)


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


patch(
    AGENTS,
    [
        (AGENTS_CONVENTIONS_OLD, AGENTS_CONVENTIONS_NEW),
        (AGENTS_LAYOUT_OLD, AGENTS_LAYOUT_NEW),
        (AGENTS_TESTS_OLD, AGENTS_TESTS_NEW),
    ],
)

append(CHANGELOG, CHANGELOG_ENTRY)
