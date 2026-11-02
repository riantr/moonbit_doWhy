"""Add the propensity score estimators to the loader of the upstream modules.

The loader of `_verify/upstream_gcm.py` reads the upstream modules straight
from their files, because the `dowhy` package cannot be imported as it is.
The propensity score estimators of the upstream were not among the modules it
knew, and the reference script of the estimator test suites needs them.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "_verify" / "upstream_gcm.py"

ANCHOR = """    ("dowhy.causal_refuters.placebo_treatment_refuter", "causal_refuters/placebo_treatment_refuter.py"),
]"""

NEW = """    ("dowhy.causal_refuters.placebo_treatment_refuter", "causal_refuters/placebo_treatment_refuter.py"),
    (
        "dowhy.causal_estimators.propensity_score_estimator",
        "causal_estimators/propensity_score_estimator.py",
    ),
    (
        "dowhy.causal_estimators.propensity_score_matching_estimator",
        "causal_estimators/propensity_score_matching_estimator.py",
    ),
    (
        "dowhy.causal_estimators.propensity_score_weighting_estimator",
        "causal_estimators/propensity_score_weighting_estimator.py",
    ),
    (
        "dowhy.causal_estimators.propensity_score_stratification_estimator",
        "causal_estimators/propensity_score_stratification_estimator.py",
    ),
    (
        "dowhy.causal_estimators.doubly_robust_estimator",
        "causal_estimators/doubly_robust_estimator.py",
    ),
]"""


def main() -> None:
    text = TARGET.read_text(encoding="utf-8")
    if "propensity_score_matching_estimator" in text:
        raise SystemExit("the modules are already there")
    if text.count(ANCHOR) != 1:
        raise SystemExit("the anchor is not unique")
    TARGET.write_text(text.replace(ANCHOR, NEW), encoding="utf-8", newline="")
    print("patched", TARGET)


if __name__ == "__main__":
    main()
