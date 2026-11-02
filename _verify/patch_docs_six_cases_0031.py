"""Records the six cases of the robust change attribution in the documentation.

The test file of the layer holds the two cases of the upstream test file and
the four cases of the regression method and of the re-weighting method, so
that every branch of the estimator of the upstream is compared against the
numbers the upstream produces on the very same rows.  The changelog and the
notes of the repository are updated with that, and with the measured
difference between the port and the upstream.
"""

from __future__ import annotations

import io
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHANGELOG = os.path.join(ROOT, "CHANGELOG.md")
README = os.path.join(ROOT, "README.mbt.md")
AGENTS = os.path.join(ROOT, "AGENTS.md")


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


CHANGELOG_TESTS_OLD = """- the tests of the upstream file
  `tests/gcm/test_distribution_change_robust.py`: the two cases it holds, on
  the ten thousand rows of the upstream test, with the nearest neighbour
  regressor and with ten folds of the cross-fitting.
- `_verify/gcm_distribution_change_robust_reference.py` -- the upstream runs on
  the very rows the port works on. The port and the upstream agree to `0.004`
  on the attribution of the mean and to `0.05` on the attribution of the
  variance. The difference is the split of the rows of the cross-fitting: the
  port splits them with its own shuffle and the upstream with the
  `StratifiedKFold` of scikit-learn.
"""

CHANGELOG_TESTS_NEW = """- the tests of the upstream file
  `tests/gcm/test_distribution_change_robust.py`: the two cases it holds, on
  the ten thousand rows of the upstream test, with the nearest neighbour
  regressor and with ten folds of the cross-fitting, and the four cases of the
  regression method and of the re-weighting method, so that every branch of
  the estimator of the upstream is compared against the upstream.
- `_verify/gcm_distribution_change_robust_reference.py` -- the upstream runs on
  the very rows the port works on, for the three methods of the estimator and
  for the two functionals of the target. The port and the upstream agree to
  `0.004` on the attribution of the mean and to `0.05` on the attribution of
  the variance; the re-weighting method, which does not use the regressor,
  agrees to `0.001`. The difference is the split of the rows of the
  cross-fitting: the port splits them with its own shuffle and the upstream
  with the `StratifiedKFold` of scikit-learn.
"""

README_DIFFERENCES_OLD = """- `gcm` splits the rows of the cross-fitting of the multiply-robust change
  attribution with its own shuffle, and the upstream splits them with the
  `StratifiedKFold` of scikit-learn. The two splits differ, so the attribution
  of the port and the attribution of the upstream are close to each other and
  not equal to each other: on the ten thousand rows of the upstream test file
  they agree to `0.004` for the mean and to `0.05` for the variance.
"""

README_DIFFERENCES_NEW = """- `gcm` splits the rows of the cross-fitting of the multiply-robust change
  attribution with its own shuffle, and the upstream splits them with the
  `StratifiedKFold` of scikit-learn. The two splits differ, so the attribution
  of the port and the attribution of the upstream are close to each other and
  not equal to each other: on the ten thousand rows of the upstream test file
  they agree to `0.004` for the mean and to `0.05` for the variance.
"""

AGENTS_OLD = """- The rows of the cross-fitting of the multiply-robust change attribution are
  split by the port with its own shuffle and by the upstream with the
  `StratifiedKFold` of scikit-learn. The two splits differ, so the attribution
  of the port and the attribution of the upstream are close to each other and
  not equal to each other: on the ten thousand rows of the upstream test file
  they agree to `0.004` for the mean and to `0.05` for the variance.
"""

AGENTS_NEW = """- The rows of the cross-fitting of the multiply-robust change attribution are
  split by the port with its own shuffle and by the upstream with the
  `StratifiedKFold` of scikit-learn. The two splits differ, so the attribution
  of the port and the attribution of the upstream are close to each other and
  not equal to each other: on the ten thousand rows of the upstream test file
  they agree to `0.004` for the mean and to `0.05` for the variance. The
  re-weighting method, which does not use the regressor, agrees to `0.001`.
"""

patch(CHANGELOG, [(CHANGELOG_TESTS_OLD, CHANGELOG_TESTS_NEW)])
patch(README, [(README_DIFFERENCES_OLD, README_DIFFERENCES_NEW)])
patch(AGENTS, [(AGENTS_OLD, AGENTS_NEW)])
