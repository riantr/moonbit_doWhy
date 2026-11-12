"""The verdicts of the upstream's own suite, and the claims of the port about them.

The port documents, in `README.mbt.md` and `AGENTS.md`, the reasons it differs
from the upstream.  Every one of those reasons is a statement about the
upstream: the cases that fail on numpy 2, the cases that fail on pandas 3, the
cases the upstream marks `xfail`, and the case that fails on a scikit-learn
that removed an argument.  Those statements are the reasons the port is allowed
to differ, so they are checked against the upstream rather than asserted.

The upstream's suite was never run in this environment before this script: the
three modules its tests need and that were missing -- `flaky`, `cvxpy` and
`nbformat` -- are installed by it, and without them the suite does not even
collect.

The script runs the upstream's test files that use a binary treatment, plus the
file of the dummy outcome refuter, and it records the verdict of every case.
The cases are classified by the reason of their failure, and the claims of the
port are checked against the record.  The upstream's suite is slow and some of
its cases are flaky, so the script is a report and not a gate step.

Usage:

    python _verify/upstream_verdicts.py
    python _verify/upstream_verdicts.py --xml FILE   # read a JUnit XML instead
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
from pathlib import Path

UPSTREAM = Path(
    os.environ.get("DOWHY_UPSTREAM_ROOT", r"D:\src\MiniMax\git\dowhy\dowhy-0.14")
)

# The reason of every failure of the upstream, and the words that name it.
#
# The first one is the `np.vectorize(convert_to_binary)` of
# `dowhy.datasets.linear_dataset`, which numpy 2 refuses: the treatment of a
# binary data set cannot be built at all.
#
# The second one is the permutation of the outcome of the refuter, which writes
# into the column of the outcome of a frame of pandas, and a column of a frame
# of pandas 3 is read only.
#
# The third one is the `multi_class` argument of the `LogisticRegression` of
# scikit-learn, which scikit-learn 1.7 removed.
REASONS = {
    "numpy-2 binary treatment": "setting an array element with a sequence",
    "pandas-3 read-only outcome": "output array is read-only",
    "pandas-3 read-only assignment": "assignment destination is read-only",
    "scikit-learn without multi_class": "unexpected keyword argument 'multi_class'",
}

# The upstream files whose cases fail with the numpy-2 binary treatment.
#
# The README names every one of them, because every one of them is the reason
# the port draws its own rows instead of running the upstream on them.  The
# script fails when the measured list and this list differ, so the README
# cannot drift away from the upstream.
BINARY_TREATMENT_FILES = [
    "tests.causal_estimators.test_doubly_robust_estimator.TestDoublyRobustEstimator",
    "tests.causal_estimators.test_econml_estimator.TestEconMLEstimator",
    "tests.causal_estimators.test_generalized_linear_model_estimator.TestGeneralizedLinearModelEstimator",
    "tests.causal_estimators.test_instrumental_variable_estimator.TestInstrumentalVariableEstimator",
    "tests.causal_estimators.test_linear_regression_estimator.TestLinearRegressionEstimator",
    "tests.causal_estimators.test_propensity_score_matching_estimator.TestPropensityScoreMatchingEstimator",
    "tests.causal_estimators.test_propensity_score_stratification_estimator.TestPropensityScoreStratificationEstimator",
    "tests.causal_estimators.test_propensity_score_weighting_estimator.TestPropensityScoreWeightingEstimator",
    "tests.causal_estimators.test_regression_discontinuity_estimator.TestRegressionDiscontinuityEstimator",
    "tests.causal_refuters.test_add_unobserved_common_cause.TestAddUnobservedCommonCauseRefuter",
    "tests.causal_refuters.test_dummy_outcome_refuter.TestDummyOutcomeRefuter",
    "tests.causal_refuters.test_placebo_refuter.TestPlaceboRefuter",
    "tests.do_sampler.test_pandas_do_api.TestPandasDoAPI",
    "tests.test_causal_graph.TestCausalGraph",
    "tests.test_causal_model.TestCausalModel",
]

# The cases of the upstream that the README names one by one.
#
# The two cases of the permutation are the ones of a continuous treatment: the
# binary ones fail earlier, with the numpy-2 error, before they reach the
# permutation.
PANDAS_READ_ONLY_CASES = [
    (
        "tests.causal_refuters.test_dummy_outcome_refuter.TestDummyOutcomeRefuter",
        "test_refutation_dummy_outcome_refuter_permute_data_continuous_treatment"
        "[0.03-iv.instrumental_variable-transformations0]",
    ),
    (
        "tests.causal_refuters.test_dummy_outcome_refuter.TestDummyOutcomeRefuter",
        "test_refutation_dummy_outcome_refuter_custom_function_linear_regression_with_permute"
        "_continuous_treatment[0.2-backdoor.linear_regression-transformations0]",
    ),
]

# The two cases the upstream marks `xfail` itself.
XFAIL_CASES = [
    (
        "tests.causal_refuters.test_dummy_outcome_refuter.TestDummyOutcomeRefuter",
        "test_refutation_dummy_outcome_refuter_custom_function_linear_regression_with_noise"
        "_binary_treatment[0.2-backdoor.linear_regression-transformations0-1000]",
    ),
    (
        "tests.causal_refuters.test_dummy_outcome_refuter.TestDummyOutcomeRefuter",
        "test_refutation_dummy_outcome_refuter_custom_function_linear_regression_with_permute"
        "_binary_treatment[0.2-backdoor.propensity_score_matching-transformations0-1000]",
    ),
]

# The two cases of the do sampler that fail on the scikit-learn of today.
MULTI_CLASS_CASES = [
    (
        "tests.do_sampler.test_pandas_do_api.TestPandasDoAPI",
        "test_pandas_api_discrete_cause_continuous_confounder[10000-0.1]",
    ),
    (
        "tests.do_sampler.test_pandas_do_api.TestPandasDoAPI",
        "test_pandas_api_discrete_cause_discrete_confounder[10000-0.1]",
    ),
]

# The files of the upstream the script runs: every test file that names a binary
# treatment, and the file of the dummy outcome refuter, whose harness names one.
EXTRA_FILES = ["tests/causal_refuters/test_dummy_outcome_refuter.py"]


def upstream_files() -> list[str]:
    """The test files of the upstream that use a binary treatment."""
    found = []
    for path in sorted((UPSTREAM / "tests").rglob("test_*.py")):
        text = path.read_text(encoding="utf-8", errors="replace")
        if "treatment_is_binary" in text:
            found.append(str(path.relative_to(UPSTREAM)).replace("\\", "/"))
    for name in EXTRA_FILES:
        if name not in found:
            found.append(name)
    return sorted(found)


def install_the_dependencies() -> list[str]:
    """The modules of the upstream's tests that are missing, and their state."""
    missing = []
    for name, module in (
        ("flaky", "flaky"),
        ("cvxpy", "cvxpy"),
        ("nbformat", "nbformat"),
    ):
        try:
            __import__(module)
        except ImportError:
            missing.append(name)
    return missing


def run_the_suite(files: list[str], xml_path: Path) -> int:
    """Run the upstream's suite over the files and write its JUnit XML."""
    command = [
        sys.executable,
        "-m",
        "pytest",
        *files,
        "-q",
        "--tb=no",
        "-rf",
        "--junitxml={}".format(xml_path),
    ]
    environment = dict(os.environ, PYTHONIOENCODING="utf-8")
    result = subprocess.run(
        command,
        cwd=str(UPSTREAM),
        capture_output=True,
        encoding="utf-8",
        errors="replace",
        env=environment,
    )
    tail = result.stdout.strip().splitlines()
    for line in tail[-12:]:
        print("   ", line)
    return result.returncode


def read_the_xml(path: Path) -> dict[tuple[str, str], dict[str, str]]:
    """The verdict of every case, keyed by `(class, name)`."""
    tree = ET.parse(str(path))
    verdicts: dict[tuple[str, str], dict[str, str]] = {}
    for case in tree.iter("testcase"):
        klass = (case.get("classname") or "").split("::")[0]
        name = case.get("name") or ""
        outcome = "passed"
        reason = ""
        kind = ""
        for child in case:
            if child.tag in ("failure", "error"):
                outcome = "failed"
                reason = " ".join(
                    ((child.get("message") or "") + " " + (child.text or "")).split()
                )
            elif child.tag == "skipped":
                outcome = "skipped"
                # The type of the skip tells an `xfail` of the upstream apart
                # from a skip of a module that is not installed, and the message
                # of an `xfail` is empty.
                kind = child.get("type") or ""
                reason = " ".join((child.get("message") or "").split())
        verdicts[(klass, name)] = {
            "outcome": outcome,
            "reason": reason,
            "kind": kind,
        }
    return verdicts


def classify(reason: str) -> str:
    """The reason of a failure, by the words that name it."""
    for label, needle in REASONS.items():
        if needle in reason:
            return label
    return "another reason"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--xml", default="", help="the JUnit XML to read")
    arguments = parser.parse_args()

    missing = install_the_dependencies()
    if missing:
        print("the upstream's tests need {}, and they are not installed".format(
            ", ".join(missing)
        ))
        print("install them with: python -m pip install {}".format(" ".join(missing)))
        return 1

    files = upstream_files()
    if arguments.xml:
        xml_path = Path(arguments.xml)
    else:
        # The XML is written into the temporary directory of the machine and not
        # into the repository: the gate of the repository scans its working
        # directory, and a generated file of a run belongs to neither.
        xml_path = Path(tempfile.gettempdir()) / "upstream_verdicts.xml"
        print("running the upstream's suite over {} files".format(len(files)))
        print("the XML is written to {}".format(xml_path))
        code = run_the_suite(files, xml_path)
        print("the exit code of the upstream's suite:", code)
        print()

    verdicts = read_the_xml(xml_path)

    classes = Counter()
    by_file = defaultdict(list)
    for (klass, name), value in verdicts.items():
        label = ""
        if value["outcome"] == "failed":
            label = classify(value["reason"])
            classes[label] += 1
        elif value["outcome"] == "skipped":
            label = "skipped"
        by_file[klass].append((name, value["outcome"], label))

    print("=" * 78)
    print("the verdicts of the upstream's suite")
    print("=" * 78)
    totals = Counter()
    for klass in sorted(by_file):
        cases = by_file[klass]
        counts = Counter(case[1] for case in cases)
        totals.update(counts)
        print(
            "{:74s} {}".format(
                klass,
                ", ".join("{} {}".format(counts[name], name) for name in sorted(counts)),
            )
        )
    print()
    print(
        "the upstream's cases: {}, {} passed, {} failed, {} skipped".format(
            len(verdicts), totals["passed"], totals["failed"], totals["skipped"]
        )
    )
    print("the failures, by their reason:")
    for label, count in classes.most_common():
        print("   {:3d}  {}".format(count, label))
    print()

    failures: list[str] = []

    # -- the files that fail with the numpy-2 binary treatment ---------------
    measured = sorted(
        klass
        for klass in by_file
        if any(label == "numpy-2 binary treatment" for _, _, label in by_file[klass])
    )
    print("=" * 78)
    print("the claim: the files that fail with the numpy-2 binary treatment")
    print("=" * 78)
    if measured != sorted(BINARY_TREATMENT_FILES):
        failures.append(
            "the files that fail with the numpy-2 binary treatment are {} and the "
            "table of the script holds {}".format(
                ", ".join(measured) or "none", ", ".join(sorted(BINARY_TREATMENT_FILES))
            )
        )
    else:
        print(
            "OK   the {} files of the table are the files that fail with the "
            "numpy-2 binary treatment".format(len(measured))
        )
    print()

    # -- the cases the README names one by one -------------------------------
    for title, cases, wanted in (
        ("the cases that fail with the pandas-3 read-only outcome",
         PANDAS_READ_ONLY_CASES, "pandas-3"),
        ("the cases the upstream marks xfail", XFAIL_CASES, "xfail"),
        ("the cases that fail on the scikit-learn without multi_class",
         MULTI_CLASS_CASES, "multi_class"),
    ):
        print("=" * 78)
        print("the claim: {}".format(title))
        print("=" * 78)
        for klass, name in cases:
            value = verdicts.get((klass, name))
            if value is None:
                failures.append("{}: the upstream holds no case {}".format(klass, name))
                continue
            if wanted == "pandas-3":
                label = classify(value["reason"])
                good = value["outcome"] == "failed" and label.startswith("pandas-3")
            elif wanted == "xfail":
                good = (
                    value["outcome"] == "skipped"
                    and value["kind"] == "pytest.xfail"
                )
            else:
                label = classify(value["reason"])
                good = value["outcome"] == "failed" and label == "scikit-learn without multi_class"
            if not good:
                failures.append(
                    "{}: the case {} is {}, not {}".format(
                        klass, name, value["outcome"], wanted
                    )
                )
            else:
                print("OK   {}".format(name[:70]))
        print()

    if failures:
        print("--- {} failure(s)".format(len(failures)))
        for failure in failures:
            print("    ", failure)
        return 1
    print("every claim of the port about the upstream holds")
    return 0


if __name__ == "__main__":
    sys.exit(main())
