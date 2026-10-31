"""Generates the fixtures of the validation tests.

The script writes `src/gcm/validation_testdata.mbt`, the data the tests of the
validation layer of the `gcm` package use. The rows are drawn from a fixed
seed, so the MoonBit test and the upstream reference see the very same rows.

The rows are the ones of the upstream tests of `tests/gcm/test_validation.py`,
with the random draws of the upstream replaced by the draws of a fixed seed:
the upstream draws its rows from the global generator of numpy, which gives a
different sample on every run, while the port needs the same rows in every
run to be able to compare its numbers with the ones of the upstream.

The script also prints the numbers the upstream computes on the fixtures, which
is the evidence the tests of the port are compared against:

  * the p-values of the kernel based independence test for every pair of the
    variables of a fixture, with and without a conditioning variable,
  * the outcome of the validation of the causal structure of every fixture.

Usage:
    python _verify/gen_validation_testdata.py
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# The seed of the generator of the fixtures.
SEED = 2024

# The number of rows of every fixture.
NUM_ROWS = 60

# The root of the repository.
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The path of the generated file, relative to the root of the repository.
OUT = os.path.join(
    REPO_ROOT,
    "src",
    "gcm",
    "validation_testdata.mbt",
)


def normal(rng: np.random.Generator) -> np.ndarray:
    """A column of the standard normal distribution."""
    return rng.normal(0.0, 1.0, NUM_ROWS)


def build_fixtures() -> dict[str, np.ndarray]:
    """The fixtures of the validation tests.

    Every fixture holds the columns `X`, `Y` and `Z`, in that order, and the
    draws are made in the order the fixtures are built, so the whole set of
    fixtures follows from the seed alone.
    """
    rng = np.random.default_rng(SEED)
    fixtures: dict[str, np.ndarray] = {}

    # The collider: X -> Z <- Y.
    x = normal(rng)
    y = normal(rng)
    z = 2 * x + 3 * y + normal(rng)
    fixtures["collider"] = np.column_stack([x, y, z])

    # The chain: X -> Z -> Y.
    x = normal(rng)
    z = 2 * x + normal(rng)
    y = 3 * z + normal(rng)
    fixtures["chain"] = np.column_stack([x, y, z])

    # The fork: Z -> X and Z -> Y.
    z = normal(rng)
    x = 2 * z + normal(rng)
    y = 3 * z + normal(rng)
    fixtures["fork"] = np.column_stack([x, y, z])

    # The general graph: Z -> X, Z -> Y and X -> Y.
    z = normal(rng)
    x = 2 * z + normal(rng)
    y = 2 * z + 3 * x + normal(rng)
    fixtures["general"] = np.column_stack([x, y, z])

    # The non-linear data: X -> Y -> Z.
    x = normal(rng)
    y = x**2 + normal(rng)
    z = np.exp(-y) + normal(rng)
    fixtures["nonlinear"] = np.column_stack([x, y, z])

    return fixtures


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
        "collider": "collider fixture, whose graph is `X -> Z <- Y`",
        "chain": "chain fixture, whose graph is `X -> Z -> Y`",
        "fork": "fork fixture, whose graph is `Z -> X` and `Z -> Y`",
        "general": "general fixture, whose graph is `Z -> X`, `Z -> Y` and `X -> Y`",
        "nonlinear": "non-linear fixture, whose graph is `X -> Y -> Z`",
    }
    parts: list[str] = []
    parts.append("/// The fixtures of the validation tests.")
    parts.append("///")
    parts.append("/// The rows come from the upstream reference of the validation layer, which")
    parts.append("/// `_verify/gen_validation_testdata.py` generates; do not edit the file by")
    parts.append("/// hand.")
    parts.append("")
    for name in ("collider", "chain", "fork", "general", "nonlinear"):
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
