"""Updates the documentation and the manifest for the robust change attribution.

The patch is a marker based patch: every anchor is checked to be present and
to be unique before the file is written, so that the patch fails loudly
instead of writing a file that is half patched.
"""

from __future__ import annotations

import io
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
README = os.path.join(ROOT, "README.mbt.md")
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


STATUS_OLD = (
    "the **uncertainty** estimates, the **distribution change** layer and the "
    "**arrow strength** layer are ported; the **robust** variant of the "
    "distribution change layer is **not ported** |"
)
STATUS_NEW = (
    "the **uncertainty** estimates, the **distribution change** layer -- the "
    "plain one and the **multiply-robust** one -- and the **arrow strength** "
    "layer are ported |"
)

LAYOUT_OLD = (
    "the uncertainty estimates, the distribution change layer and the arrow "
    "strength layer |"
)
LAYOUT_NEW = (
    "the uncertainty estimates, the distribution change layer -- the plain one "
    "and the multiply-robust one -- and the arrow strength layer |"
)

CONVENTIONS_OLD = """- The logistic regression of the `utils` package minimises
  `sum_i log_loss(y_i, p_i) + 1/(2C) ||w||²`, the convention of
  `sklearn.linear_model.LogisticRegression` with the default `penalty="l2"` and
  `C=1.0`, and it is fitted with the iteratively reweighted least squares. The
  weighted normal equations of a step are accumulated over the rows of the
  design matrix, so the fit of a hundred thousand rows needs a matrix of the
  size of the number of the columns and not one of the size of the square of
  the number of the rows.
"""

CONVENTIONS_NEW = """- The logistic regression of the `utils` package minimises
  `sum_i log_loss(y_i, p_i) + 1/(2C) ||w||²`, the convention of
  `sklearn.linear_model.LogisticRegression` with the default `penalty="l2"` and
  `C=1.0`, and it is fitted with the iteratively reweighted least squares. The
  weighted normal equations of a step are accumulated over the rows of the
  design matrix, so the fit of a hundred thousand rows needs a matrix of the
  size of the number of the columns and not one of the size of the square of
  the number of the rows.
- The multiply-robust causal change attribution of the `gcm` package is the port
  of `dowhy.gcm.distribution_change_robust`, the estimator of the paper
  "Multiply-Robust Causal Change Attribution" of Quintas-Martinez, Bahadori,
  Santiago, Mu, Janzing and Heckerman (ICML 2024). Three details of it decide
  whether the attribution is the one of the upstream:
  - **the functional of the variance is the second moment of the target minus
    the square of the first moment of the target.** The upstream writes it as
    `(theta(y²) - theta(y)) ** 2`, but the exponent of Python binds tighter
    than the subtraction, so the upstream computes `theta(y²) - theta(y) ** 2`.
    The port computes the functional of the upstream: the attribution of the
    variance is about twenty times smaller than the square of the difference
    would give.
  - **only the weights of the last group of the estimator are standardised.**
    The upstream standardises the weights outside its loop over the groups, so
    the weights of the other groups keep their scale. The port standardises the
    last weight alone, the way the upstream does.
  - **the estimate of the change is the mean of the scores of the estimator,
    and its standard error is the one of
    `statsmodels.stats.weightstats.DescrStatsW` with the weights of one.** The
    standard error is therefore the standard deviation of the scores with
    `ddof = 0` divided by the square root of the number of the scores less one.
"""

DIFFERENCES_OLD = """- `gcm` runs the estimate of the strength of an edge for one edge at a time,
  while the upstream runs it for every edge in a process pool. The estimate of
  one edge does not depend on the others, so the strengths are the same numbers.
"""

DIFFERENCES_NEW = """- `gcm` runs the estimate of the strength of an edge for one edge at a time,
  while the upstream runs it for every edge in a process pool. The estimate of
  one edge does not depend on the others, so the strengths are the same numbers.
- `gcm` has neither a calibrator nor sample weights for the multiply-robust
  change attribution. The upstream can calibrate the probabilities of its
  classifier on a calibration set and can weigh the samples; the models of the
  upstream mostly do not support the weights either, and the port has neither.
- `gcm` splits the rows of the cross-fitting of the multiply-robust change
  attribution with its own shuffle, and the upstream splits them with the
  `StratifiedKFold` of scikit-learn. The two splits differ, so the attribution
  of the port and the attribution of the upstream are close to each other and
  not equal to each other: on the ten thousand rows of the upstream test file
  they agree to `0.004` for the mean and to `0.05` for the variance.
"""

DESCRIPTION_OLD = (
    "and the distribution change layer (the test of the change of a mechanism, "
    "the attribution of the change of the distribution of a target node and the "
    "scores of the change of the distribution of every node)"
)
DESCRIPTION_NEW = (
    "and the distribution change layer (the test of the change of a mechanism, "
    "the attribution of the change of the distribution of a target node, the "
    "multiply-robust attribution of the change of the mean or of the variance "
    "of a target node and the scores of the change of the distribution of "
    "every node)"
)

patch(
    README,
    [
        (STATUS_OLD, STATUS_NEW),
        (LAYOUT_OLD, LAYOUT_NEW),
        (CONVENTIONS_OLD, CONVENTIONS_NEW),
        (DIFFERENCES_OLD, DIFFERENCES_NEW),
    ],
)

patch(
    MANIFEST,
    [
        ('version = "0.0.30"', 'version = "0.0.31"'),
        (DESCRIPTION_OLD, DESCRIPTION_NEW),
    ],
)
