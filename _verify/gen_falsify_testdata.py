"""Generates the fixtures of the falsification tests.

The script writes `src/gcm/falsify_testdata.mbt`, the data the tests of the
falsification layer of the `gcm` package use. The rows are drawn from a fixed
seed, so the MoonBit test and the upstream reference see the very same rows.

The rows are the ones of the upstream tests of `tests/gcm/test_falsify.py`,
with the random draws of the upstream replaced by the draws of a fixed seed:
the upstream draws its rows from the global generator of numpy, which gives a
different sample on every run, while the port needs the same rows in every
run to be able to compare its numbers with the ones of the upstream.

Every fixture holds the columns of the upstream test it belongs to, and the
graphs of the fixtures are the ones of the upstream tests as well:

  * the collider fixture belongs to the graph `X -> Z <- Y` and to the wrong
    graph `X -> Y <- Z`,
  * the chain fixture belongs to the graph `X -> Y -> Z` and to the wrong
    graph `X -> Z -> Y`,
  * the full data frame fixture belongs to the full graph of the upstream,
  * the single node fixture belongs to the graph with a single node,
  * the single edge fixture belongs to the graph `X0 -> X1` and to the wrong
    graph without any edge,
  * the causal minimality fixture belongs to the graphs `X0 -> Y <- X1` and
    `X2 -> Y <- X0 <- X1`.

Usage:
    python _verify/gen_falsify_testdata.py
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# The seed of the generator of the fixtures.
SEED = 2025

# The number of rows of every fixture. The upstream tests use five hundred
# rows, and the outcome of the tests depends on that number.
NUM_ROWS = 500

# The root of the repository.
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The path of the generated file, relative to the root of the repository.
OUT = os.path.join(
    REPO_ROOT,
    "src",
    "gcm",
    "falsify_testdata.mbt",
)


def normal(rng: np.random.Generator) -> np.ndarray:
    """A column of the standard normal distribution."""
    return rng.normal(0.0, 1.0, NUM_ROWS)


def build_fixtures() -> dict[str, dict[str, np.ndarray]]:
    """The fixtures of the falsification tests.

    Every fixture holds the columns of the upstream test it belongs to, and the
    draws are made in the order the fixtures are built, so the whole set of
    fixtures follows from the seed alone.
    """
    rng = np.random.default_rng(SEED)
    fixtures: dict[str, dict[str, np.ndarray]] = {}

    # The collider: X -> Z <- Y.
    x = normal(rng)
    y = normal(rng)
    z = 2 * x + 3 * y + normal(rng)
    fixtures["collider"] = {"X": x, "Y": y, "Z": z}

    # The chain: X -> Y -> Z.
    x = normal(rng)
    y = 0.6 * x + normal(rng)
    z = y + normal(rng)
    fixtures["chain"] = {"X": x, "Y": y, "Z": z}

    # The full graph of the upstream.
    x0 = normal(rng)
    x1 = 0.5 * x0 + normal(rng)
    x2 = 1.2 * x0 + 0.7 * x1 + normal(rng)
    x3 = 0.6 * x0 + 0.8 * x1 + 1.3 * x2 + normal(rng)
    fixtures["full_dag"] = {"X0": x0, "X1": x1, "X2": x2, "X3": x3}

    # The graph with a single node.
    fixtures["single_node"] = {"X": normal(rng)}

    # The graph with a single edge: X0 -> X1.
    x0 = normal(rng)
    x1 = 2 * x0 + normal(rng)
    fixtures["single_edge"] = {"X0": x0, "X1": x1}

    # The graphs of the causal minimality: X0 -> Y <- X1 and X2 -> Y.
    x0 = normal(rng)
    x1 = normal(rng)
    x2 = normal(rng)
    y = 2 * x0 + 3 * x1 + normal(rng)
    fixtures["causal_minimality"] = {"X0": x0, "X1": x1, "X2": x2, "Y": y}

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


def moonbit_frame(
    name: str,
    description: str,
    columns: dict[str, np.ndarray],
) -> list[str]:
    """The MoonBit source of one fixture."""
    lines: list[str] = []
    lines.append("///|")
    lines.append(f"/// The data of the {description}.")
    lines.append(f"pub fn falsify_{name}_frame() -> @api.DataFrame {{")
    names = list(columns.keys())
    for column in names:
        lines.extend(moonbit_array(column.lower(), columns[column]))
    entries = ", ".join('("%s", %s)' % (column, column.lower()) for column in names)
    lines.append("  @api.DataFrame::from_numeric(")
    lines.append("    [%s]," % ", ".join('"%s"' % column for column in names))
    lines.append("    Map([%s])," % entries)
    lines.append("  )")
    lines.append("}")
    lines.append("")
    return lines


def write_source(fixtures: dict[str, dict[str, np.ndarray]]) -> None:
    """Writes the generated file."""
    descriptions = {
        "collider": "collider fixture, whose graph is `X -> Z <- Y`",
        "chain": "chain fixture, whose graph is `X -> Y -> Z`",
        "full_dag": "full graph fixture, whose graph has the four nodes `X0`, `X1`, `X2` and `X3`",
        "single_node": "single node fixture, whose graph has the single node `X`",
        "single_edge": "single edge fixture, whose graph is `X0 -> X1`",
        "causal_minimality": "causal minimality fixture, whose graph is `X0 -> Y <- X1`",
    }
    parts: list[str] = []
    parts.append("/// The fixtures of the falsification tests.")
    parts.append("///")
    parts.append("/// The rows come from the upstream reference of the falsification layer,")
    parts.append("/// which `_verify/gen_falsify_testdata.py` generates; do not edit the file")
    parts.append("/// by hand.")
    parts.append("")
    for name in (
        "collider",
        "chain",
        "full_dag",
        "single_node",
        "single_edge",
        "causal_minimality",
    ):
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
    for name, columns in fixtures.items():
        print(f"  {name}: {len(columns)} columns, {NUM_ROWS} rows")


if __name__ == "__main__":
    main()
