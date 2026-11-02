"""Generates the fixture of the tests of the two stage regression estimator.

The script writes `src/tests/two_stage_testdata.mbt`, the data the test of the
frontdoor estimator of the upstream runs on. The rows are the ones of the
upstream test `test_frontdoor_estimator` of the file
`tests/causal_estimators/test_two_stage_regression_estimator.py`:

    U = np.random.randn(N_SAMPLES)
    X = np.random.randn(N_SAMPLES) + 0.3 * U
    Z = 0.7 * X + 0.3 * np.random.randn(N_SAMPLES)
    Y = 0.65 * Z + 0.2 * U

The test class of the upstream has the fixture `fixed_seed`, which seeds the
generator of numpy with zero before the test runs, so the rows are the same on
every run. The rows of the port are therefore the rows of the upstream, and the
estimate of the two stage regression estimator of the port and the estimate of
the upstream are the same number.

The numbers of the upstream are the ones
`_verify/two_stage_estimator_reference.py` prints.

Usage:
    python _verify/gen_two_stage_estimator_testdata.py
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# The number of rows the upstream test draws.
NUM_ROWS = 10000

# The seed of the fixture `fixed_seed` of the upstream test.
SEED = 0

# The root of the repository.
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The path of the generated file, relative to the root of the repository.
OUT = os.path.join(
    REPO_ROOT,
    "src",
    "tests",
    "two_stage_testdata.mbt",
)

# The width the formatter of the toolchain breaks the lines of an array at.
MAX_WIDTH = 90


def rows() -> dict[str, np.ndarray]:
    """The rows of the upstream test of the frontdoor estimator."""
    np.random.seed(SEED)
    u = np.random.randn(NUM_ROWS)
    x = np.random.randn(NUM_ROWS) + 0.3 * u
    z = 0.7 * x + 0.3 * np.random.randn(NUM_ROWS)
    y = 0.65 * z + 0.2 * u
    return {"X": x, "Z": z, "Y": y}


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


def write_source(columns: dict[str, np.ndarray]) -> None:
    """Writes the generated file."""
    parts: list[str] = []
    parts.append("/// The data set of the tests of the two stage regression estimator.")
    parts.append("///")
    parts.append("/// The rows are the ones of the upstream test `test_frontdoor_estimator` of")
    parts.append("/// the file `tests/causal_estimators/test_two_stage_regression_estimator.py`.")
    parts.append("/// The test class of the upstream has the fixture `fixed_seed`, which seeds the")
    parts.append("/// generator of numpy with zero, so the rows are the same on every run and they")
    parts.append("/// are the rows the upstream test runs on.")
    parts.append("///")
    parts.append("/// The file comes from the upstream reference of the two stage regression")
    parts.append("/// estimator, which `_verify/gen_two_stage_estimator_testdata.py` generates;")
    parts.append("/// do not edit it by hand.")
    parts.append("")
    parts.append("///|")
    parts.append("/// The data set of the tests of the two stage regression estimator.")
    parts.append("pub fn two_stage_frame() -> @api.DataFrame {")
    for name in ("X", "Z", "Y"):
        parts.extend(moonbit_array(name.lower(), columns[name]))
    parts.append("  @api.DataFrame::from_numeric(")
    parts.append("    [\"X\", \"Z\", \"Y\"],")
    parts.append("    Map([(\"X\", x), (\"Z\", z), (\"Y\", y)]),")
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
    columns = rows()
    write_source(columns)
    for name in ("X", "Z", "Y"):
        print(f"  {name}: {NUM_ROWS} rows")


if __name__ == "__main__":
    main()
