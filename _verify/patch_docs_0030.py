"""Update the documentation and the version of the port for v0.0.30."""

edits = []

# --- the version of the module ------------------------------------------------
edits.append(
    (
        r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\moon.mod",
        [
            (
                'version = "0.0.29"',
                'version = "0.0.30"',
            ),
        ],
    )
)

# --- the README ---------------------------------------------------------------
edits.append(
    (
        r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\README.mbt.md",
        [
            (
                "moonbit_dowhy-v0.0.29.svg",
                "moonbit_dowhy-v0.0.30.svg",
            ),
            (
                """- `round_half_even` reproduces `numpy.round` and `pandas.Series.round(0)`.
""",
                """- `round_half_even` reproduces `numpy.round` and `pandas.Series.round(0)`.
- The propensity score estimators trim the scores of the data only where the
  upstream trims them: the inverse propensity score weighting estimator trims
  them to `0.05` and `0.95` and the doubly robust estimator trims them to
  `0.01` and `0.99`, while the matching estimator and the stratification
  estimator use the raw scores. The trimming groups the scores of many rows
  together, which moves the matches of the matching estimator and the strata
  of the stratification estimator: on the hundred thousand rows of the upstream
  estimator test suite the estimate of the stratification estimator is
  `10.0001` with the raw scores and `10.308` with the trimmed ones, and the
  upstream gives `10.0001`.
- The number of strata of the propensity score stratification estimator is
  either given or searched for, the way the upstream searches for it: the
  search starts with `0.5 * rows / clipping_threshold` strata and halves the
  number until at least half of the strata hold more than `clipping_threshold`
  units of both arms. The upstream test file uses the search.
""",
            ),
            (
                """The `CausalModel` of the root package differs from upstream in the following
ways:
""",
                """The `estimators` package and the test suites of the port differ from upstream
in the following ways:

- The number of strata of the propensity score stratification estimator is an
  enumeration, `NumStrata`, with a case for a given number of strata and a
  case for the number of strata the upstream searches for. The upstream takes
  the string `"auto"` and an integer.
- The estimator test suite and the bootstrap refuter test suite of the port
  draw their rows with the generator of the port, and the upstream draws its
  rows with the global generator of numpy, which the fixture of the upstream
  test suite seeds with zero. The rows of the port are therefore fixed, and
  the seed of every suite is the one for which the **upstream** stays inside
  the tolerances of its own test files on the very same rows.
  `_verify/estimator_suite_reference.py` runs the upstream on the rows of the
  port. Two of the eighteen cases of the estimator suite are decided by the
  draw: the inverse propensity score weighting estimator with two common
  causes and the doubly robust estimator with two common causes and a binary
  outcome are outside the tolerance of the upstream on the rows of the seed
  42, and the upstream is outside it as well.
- The estimator test suite of the port asserts the estimates only. The upstream
  test files also ask for the confidence intervals and for the significance of
  the estimate, with ten bootstrap simulations for the stratification and the
  doubly robust estimator; the upstream asserts none of those numbers, and ten
  simulations of a bootstrap over a hundred thousand rows would multiply the
  runtime of the suite by an order of magnitude.

The `CausalModel` of the root package differs from upstream in the following
ways:
""",
            ),
        ],
    )
)

# --- the CHANGELOG -----------------------------------------------------------
edits.append(
    (
        r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\CHANGELOG.md",
        [
            (
                """## [0.0.29] - 2026-11-02""",
                """## [0.0.30] - 2026-11-02

The test suites of the four propensity score estimators of the upstream, and
the two fixes of the estimators they found.

### Added

- the tests of the upstream files `tests/causal_estimators/test_propensity_score_matching_estimator.py`,
  `test_propensity_score_weighting_estimator.py`,
  `test_propensity_score_stratification_estimator.py` and
  `test_doubly_robust_estimator.py`: the eighteen cases they hold, on the
  hundred thousand rows of the upstream test suite, with the tolerance the
  upstream test file allows for each of its estimators and with the two
  identifiers the upstream uses for them.
- `_verify/estimator_suite_reference.py` -- the upstream runs on the very rows
  the port works on, for the eighteen cases of the suite. The port and the
  upstream agree on every case: the matching estimator and the stratification
  estimator agree to `1e-14` on one common cause, the weighting estimator
  agrees to `3e-4` and the doubly robust estimator to `5e-7`.

### Fixed

- **The propensity score estimators trimmed the scores of the data, and the
  upstream trims them in two of the four of them.** The inverse propensity
  score weighting estimator trims the scores to `0.05` and `0.95` and the
  doubly robust estimator trims them to `0.01` and `0.99`, while the matching
  estimator and the stratification estimator use the raw scores. The trimming
  of the port moved the matches of the matching estimator and the strata of
  the stratification estimator: on the hundred thousand rows of the upstream
  estimator test suite the estimate of the stratification estimator was
  `10.308` with the trimmed scores and `10.0001` with the raw ones, and the
  upstream gives `10.0001`. The two estimators that trim them trim them
  themselves now, and the doubly robust estimator trims the scores of the two
  arms separately, the way the upstream does.
- **The propensity score stratification estimator always used five strata.** The
  upstream searches for the number of strata when it is not given: the search
  starts with `0.5 * rows / clipping_threshold` strata and halves the number
  until at least half of the strata hold more than `clipping_threshold` units
  of both arms. The upstream test file uses the search, and it is what makes
  the estimate of the estimator agree with the upstream. The number of strata
  is an enumeration now, `NumStrata`, with a case for a given number of strata
  and a case for the number of strata the upstream searches for.

### Notes

- The rows of the test suites of the upstream are drawn with the global
  generator of numpy, so the upstream runs its estimator and refuter test
  suites on a random draw of the rows. The rows of the port are fixed, and the
  seed of every suite is the one for which the **upstream** stays inside the
  tolerances of its own test files on the very same rows. Two of the
  eighteen cases of the estimator suite are decided by the draw: the inverse
  propensity score weighting estimator with two common causes and the doubly
  robust estimator with two common causes and a binary outcome are outside the
  tolerance of the upstream on the rows of the seed 42, and the upstream is
  outside it as well.
- The estimator test suite of the port asserts the estimates only. The
  upstream test files also ask for the confidence intervals and for the
  significance of the estimate, with ten bootstrap simulations for the
  stratification and the doubly robust estimator; the upstream asserts none of
  those numbers, and ten simulations of a bootstrap over a hundred thousand
  rows would multiply the runtime of the suite by an order of magnitude.
- The bootstrap refuter test suite of the port draws its own rows, with the
  seed 43. The rows of the seed 42 put the refuted effect of the binary
  treatment with three variables outside the tolerance of the upstream test
  file, and the rows of the seed 43 do not.

[0.0.30]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.30

## [0.0.29] - 2026-11-02""",
            ),
        ],
    )
)

# --- the working agreements --------------------------------------------------
edits.append(
    (
        r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\AGENTS.md",
        [
            (
                """- The logistic regression of the `utils` package is fitted with the iteratively
  reweighted least squares, and the weighted normal equations of a step are
  accumulated over the rows of the design matrix. The diagonal weight matrix
  would hold `n * n` doubles, which is eighty gigabytes for the hundred
  thousand rows of the upstream test suite, so it is never built.
""",
                """- The logistic regression of the `utils` package is fitted with the iteratively
  reweighted least squares, and the weighted normal equations of a step are
  accumulated over the rows of the design matrix. The diagonal weight matrix
  would hold `n * n` doubles, which is eighty gigabytes for the hundred
  thousand rows of the upstream test suite, so it is never built.
- The propensity scores of the `estimators` package are **not** trimmed by
  default. The upstream trims them in the inverse propensity score weighting
  estimator (to `0.05` and `0.95`) and in the doubly robust estimator (to
  `0.01` and `0.99`), and it does not trim them in the matching estimator and
  in the stratification estimator. The trimming creates huge groups of equal
  scores, which moves the strata of the stratification estimator and the
  matches of the matching estimator: on the hundred thousand rows of the
  upstream estimator test suite the estimate of the stratification estimator
  is `10.0001` with the raw scores and `10.308` with the trimmed ones, while
  the upstream gives `10.0001`. The two estimators that trim them trim them
  themselves, and the doubly robust estimator trims the scores of the two arms
  separately, the way the upstream does.
- The number of strata of the propensity score stratification estimator of the
  `estimators` package is either given or searched for, the way the upstream
  searches for it: the search starts with `0.5 * rows / clipping_threshold`
  strata and halves the number until at least half of the strata hold more
  than `clipping_threshold` units of both arms. The upstream test file uses
  the search, and it is what makes the estimate of the estimator agree with
  the upstream to `1e-14` on one common cause.
- The rows of the data sets of the upstream test suites are drawn by the
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
""",
            ),
        ],
    )
)

for path, replacements in edits:
    s = open(path, encoding="utf-8", newline="").read()
    for old, new in replacements:
        assert s.count(old) == 1, (path, s.count(old), old[:60])
        s = s.replace(old, new)
    open(path, "w", encoding="utf-8", newline="").write(s)
    print("patched", path)
