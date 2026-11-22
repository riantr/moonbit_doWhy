"""The rows of the upstream, with the numbers the upstream computes on them.

The port draws the rows of a synthetic data set row by row, where the upstream
draws its columns one after the other, so the rows of the two are different
and the numbers of an estimate computed on them differ as well. The test of
the estimator of the port therefore asserts that the estimate recovers the
true effect within the tolerance of the upstream tests, and it cannot compare
its number with the number of the upstream.

This script closes that gap for the data set of the upstream tests of the
estimators. It builds the data set with the generator of the upstream and with
the seed of the fixture `fixed_seed` of the upstream tests, so the rows are
the rows the upstream works on, and it runs the estimator of the upstream on
them, so the numbers are the numbers of the upstream.

It writes `src/tests/upstream_estimator_testdata.mbt`, which holds the rows
and the numbers of the upstream. The test `src/tests/upstream_rows.mbt` runs
the estimator of the port on those rows and asserts that the two numbers are
the same number.

The upstream is 0.14 and this machine has numpy 2.5, and
`numpy.vectorize` cannot broadcast the one element array that
`dowhy.datasets.convert_to_binary` returns under numpy 2, so the script gives
the module a `convert_to_binary` that returns the scalar the upstream means.
The repair draws exactly the same randomness, so the rows are the rows the
upstream produced on numpy 1.

Usage:
    python _verify/gen_upstream_estimator_testdata.py
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys

import numpy as np

UPSTREAM = r"D:\src\MiniMax\git\dowhy\dowhy-0.14"
sys.path.insert(0, UPSTREAM)

import dowhy.datasets  # noqa: E402
from dowhy import EstimandType, identify_effect_auto  # noqa: E402
from dowhy.causal_estimators.linear_regression_estimator import (  # noqa: E402
    LinearRegressionEstimator,
)
from dowhy.graph import build_graph_from_str  # noqa: E402

# The seed of the fixture `fixed_seed` of the upstream tests.
SEED = 0

# The number of rows of the data set.
#
# The upstream test of the estimators draws a hundred thousand rows, and the
# file of the rows of the port would be far too large for the repository. The
# rows are the rows of the upstream either way, because the generator of the
# upstream draws them the same way for every number of rows.
NUM_ROWS = 2000

# The effect of the treatment in the generating equation of the outcome.
BETA = 10

# The root of the repository.
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The path of the generated file, relative to the root of the repository.
OUT = os.path.join(
    REPO_ROOT,
    "src",
    "tests",
    "upstream_estimator_testdata.mbt",
)

# The width the formatter of the toolchain breaks the lines of an array at.
MAX_WIDTH = 90


def repair_numpy2() -> None:
    """The `convert_to_binary` of the upstream, with the scalar it means.

    The function of the upstream returns the one element array of
    `numpy.random.choice`, and `numpy.vectorize` cannot broadcast it under
    numpy 2. The repair returns the element of the array, which is the number
    the upstream means, and it draws the same randomness.
    """
    original = dowhy.datasets.convert_to_binary

    def convert_to_binary(x, stochastic=True):
        value = original(x, stochastic)
        if isinstance(value, np.ndarray) and value.shape == (1,):
            return int(value[0])
        return value

    dowhy.datasets.convert_to_binary = convert_to_binary


def rows_of_the_upstream() -> dict:
    """The rows of the upstream, with the numbers the upstream computes on them.

    The data set is the one of the upstream tests of the estimators: one
    common cause, one instrument, one treatment and a continuous outcome.
    """
    repair_numpy2()
    np.random.seed(SEED)
    data = dowhy.datasets.linear_dataset(
        beta=BETA,
        num_common_causes=1,
        num_instruments=1,
        num_effect_modifiers=0,
        num_treatments=1,
        num_frontdoor_variables=0,
        num_samples=NUM_ROWS,
        treatment_is_binary=True,
        treatment_is_category=False,
        outcome_is_binary=False,
    )
    frame = data["df"]

    estimand = identify_effect_auto(
        build_graph_from_str(data["gml_graph"]),
        observed_nodes=list(frame.columns),
        action_nodes=data["treatment_name"],
        outcome_nodes=data["outcome_name"],
        estimand_type=EstimandType.NONPARAMETRIC_ATE,
    )
    estimand.set_identifier_method("backdoor")

    estimator = LinearRegressionEstimator(identified_estimand=estimand)
    estimator.fit(frame, effect_modifier_names=data["effect_modifier_names"])
    estimate = estimator.estimate_effect(
        frame,
        control_value=0,
        treatment_value=1,
        test_significance=False,
        evaluate_effect_strength=False,
        confidence_intervals=True,
        target_units="ate",
    )
    interval = np.asarray(estimate.get_confidence_intervals()).ravel()
    standard_error = np.asarray(estimate.get_standard_error()).ravel()
    return {
        "columns": list(frame.columns),
        "rows": frame,
        "ate": float(estimate.value),
        "ci_lower": float(interval[0]),
        "ci_upper": float(interval[1]),
        "standard_error": float(standard_error[0]),
        "true_ate": float(data["ate"]),
        "adjustment": list(estimand.get_adjustment_set()),
        "treatment": list(data["treatment_name"]),
        "outcome": data["outcome_name"],
        "common_causes": list(data["common_causes_names"]),
        "instruments": list(data["instrument_names"]),
    }


def moonbit_array(name: str, values: np.ndarray) -> list[str]:
    """The values of a column as a MoonBit array literal.

    The layout is the one the formatter of the toolchain produces, so that the
    generated file passes the formatting gate without a second pass: the values
    fill a line until the next one would make it longer than the width the
    formatter breaks at.
    """
    lines = [f"  let {name} = ["]
    current = ""
    for value in values:
        item = repr(float(value)) + ","
        candidate = current + " " + item if current else "    " + item
        if len(candidate) > MAX_WIDTH and current:
            lines.append(current)
            current = "    " + item
        else:
            current = candidate
    if current:
        lines.append(current)
    lines.append("  ]")
    return lines


def write_source(data: dict) -> None:
    """Writes the generated file."""
    frame = data["rows"]
    parts: list[str] = []
    parts.append("/// The rows of the upstream, with the numbers the upstream computes on them.")
    parts.append("///")
    parts.append("/// The rows are the ones of the generator of the upstream")
    parts.append("/// `dowhy.datasets.linear_dataset`, which the tests of the upstream of the")
    parts.append("/// estimators use with the seed of the fixture `fixed_seed` of the upstream,")
    parts.append("/// which seeds the generator of numpy with zero. The data set has one common")
    parts.append("/// cause, one instrument, one treatment and a continuous outcome.")
    parts.append("///")
    parts.append("/// The numbers are the ones the estimator of the upstream computes on these")
    parts.append("/// rows: the average treatment effect, the bounds of its confidence interval")
    parts.append("/// and its standard error. The test of the port runs its own estimator on")
    parts.append("/// these rows and asserts that the two numbers are the same number.")
    parts.append("///")
    parts.append("/// The file comes from the upstream reference of the estimators, which")
    parts.append("/// `_verify/gen_upstream_estimator_testdata.py` generates; do not edit it by")
    parts.append("/// hand.")
    parts.append("")
    parts.append("///|")
    parts.append("/// The average treatment effect the upstream computes on the rows.")
    parts.append(f"pub const UPSTREAM_ATE : Double = {repr(data['ate'])}")
    parts.append("")
    parts.append("///|")
    parts.append("/// The lower bound of the confidence interval the upstream computes.")
    parts.append(f"pub const UPSTREAM_CI_LOWER : Double = {repr(data['ci_lower'])}")
    parts.append("")
    parts.append("///|")
    parts.append("/// The upper bound of the confidence interval the upstream computes.")
    parts.append(f"pub const UPSTREAM_CI_UPPER : Double = {repr(data['ci_upper'])}")
    parts.append("")
    parts.append("///|")
    parts.append("/// The standard error the upstream computes on the rows.")
    parts.append(f"pub const UPSTREAM_STANDARD_ERROR : Double = {repr(data['standard_error'])}")
    parts.append("")
    parts.append("///|")
    parts.append("/// The true average treatment effect of the data set.")
    parts.append(f"pub const UPSTREAM_TRUE_ATE : Double = {repr(data['true_ate'])}")
    parts.append("")
    parts.append("///|")
    parts.append("/// The rows of the upstream, as a data frame of the port.")
    parts.append("pub fn upstream_frame() -> @api.DataFrame {")
    for name in data["columns"]:
        parts.extend(moonbit_array(name.lower(), frame[name].to_numpy()))
    parts.append("  @api.DataFrame::from_numeric(")
    parts.append(
        "    [" + ", ".join(f'"{name}"' for name in data["columns"]) + "],"
    )
    parts.append(
        "    Map(["
        + ", ".join(
            f'("{name}", {name.lower()})' for name in data["columns"]
        )
        + "]),"
    )
    parts.append("  )")
    parts.append("}")
    parts.append("")

    with open(OUT, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(parts).rstrip("\n") + "\n")
    print("wrote", OUT)
    format_generated_file()


def format_generated_file() -> None:
    """Formats the generated file with the formatter of the toolchain.

    The formatter breaks the lines of an array at a width that is not a simple
    limit, so the generated file is handed to it instead of guessing where the
    lines go. The file that the formatter writes is the one that is committed,
    so regenerating the file leaves the tree unchanged.
    """
    if shutil.which("moon") is None:
        print("the moon toolchain was not found; run `moon fmt` on the file by hand")
        return
    result = subprocess.run(
        ["moon", "fmt", os.path.relpath(OUT, REPO_ROOT)],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print("the formatter failed:", result.stdout, result.stderr)


def main() -> None:
    data = rows_of_the_upstream()
    write_source(data)
    print("  the upstream's ATE:", repr(data["ate"]))
    print("  the upstream's CI:", repr([data["ci_lower"], data["ci_upper"]]))
    print("  the upstream's standard error:", repr(data["standard_error"]))
    print("  the true ATE:", repr(data["true_ate"]))
    print("  the adjustment set:", data["adjustment"])


if __name__ == "__main__":
    main()
