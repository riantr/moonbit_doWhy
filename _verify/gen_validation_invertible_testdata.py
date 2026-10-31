"""Generates the fixture of the invertible model tests.

The script writes `src/gcm/validation_invertible_testdata.mbt`, the data the
tests of `refute_invertible_model` of the `gcm` package use. The rows are drawn
from a fixed seed, so the MoonBit test and the upstream reference see the very
same rows.

The fixture is a linear chain `X -> Y -> Z`: the relation of every link is
linear, so the invertible model assumption of the upstream holds for the right
graph and fails for the wrong ones. The non-linear fixture of
`gen_validation_testdata.py` cannot be used for that, because the automatic
assignment of the port has one model per kind of data and therefore always
picks a linear regressor, which cannot capture the non-linear relation of the
fixture. The upstream picks its model by cross validation out of a zoo of
estimators, so it can capture the relation, and the two answer the validation
of the non-linear fixture differently.

The script also prints the numbers the upstream computes on the fixture, which
is the evidence the test of the port is compared against.

Usage:
    python _verify/gen_validation_invertible_testdata.py
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# The seed of the generator of the fixture.
SEED = 2024

# The number of rows of the fixture.
NUM_ROWS = 200

# The root of the repository.
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The path of the generated file, relative to the root of the repository.
OUT = os.path.join(
    REPO_ROOT,
    "src",
    "gcm",
    "validation_invertible_testdata.mbt",
)


def build_fixtures() -> dict[str, np.ndarray]:
    """The fixture of the invertible model tests.

    The fixture holds the columns `X`, `Y` and `Z`, in that order. The chain is
    linear: `Y` is `2 * X` plus noise and `Z` is `3 * Y` plus noise.
    """
    rng = np.random.default_rng(SEED)
    x = rng.normal(0.0, 1.0, NUM_ROWS)
    y = 2.0 * x + rng.normal(0.0, 1.0, NUM_ROWS)
    z = 3.0 * y + rng.normal(0.0, 1.0, NUM_ROWS)
    return {"linear": np.column_stack([x, y, z])}


# The width the formatter of the toolchain breaks the lines of an array at.
MAX_WIDTH = 90


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


def moonbit_frame(name: str, description: str, data: np.ndarray) -> list[str]:
    """The MoonBit source of one fixture."""
    lines: list[str] = []
    lines.append("///|")
    lines.append(f"/// The data of the {description}.")
    lines.append("pub fn validation_%s_frame() -> @api.DataFrame {" % name)
    for index, column in enumerate(("X", "Y", "Z")):
        lines.extend(moonbit_array(column.lower(), data[:, index]))
    lines.append('  @api.DataFrame::from_numeric(')
    lines.append('    ["X", "Y", "Z"],')
    lines.append('    Map([("X", x), ("Y", y), ("Z", z)]),')
    lines.append("  )")
    lines.append("}")
    lines.append("")
    return lines


def write_source(fixtures: dict[str, np.ndarray]) -> None:
    """Writes the generated file."""
    descriptions = {
        "linear": "linear fixture, whose graph is `X -> Y -> Z`",
    }
    parts: list[str] = []
    parts.append("/// The fixtures of the invertible model tests.")
    parts.append("///")
    parts.append("/// The rows come from the upstream reference of the validation layer, which")
    parts.append("/// `_verify/gen_validation_invertible_testdata.py` generates; do not edit the")
    parts.append("/// file by hand.")
    parts.append("")
    for name in ("linear",):
        parts.extend(moonbit_frame(name, descriptions[name], fixtures[name]))
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
    fixtures = build_fixtures()
    write_source(fixtures)
    for name, data in fixtures.items():
        print(f"  {name}: {data.shape[0]} rows")


if __name__ == "__main__":
    main()
