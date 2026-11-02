"""Generates the fixture of the integration test of the book.

The script writes `src/tests/book_testdata.mbt`, the data the integration test
of the two stage regression estimator runs on. The rows are the ones of the
upstream test `test_dowhy_chapter_7` of the file
`tests/causal-inference-discovery-book/test_causal_inference_discovery_book.py`,
the one of the chapter 7 of the book "Causal Inference and Discovery in
Python".

The upstream test class has the fixture `fixed_seed`, which seeds the generator
of NumPy with zero before the test runs, so the rows of the data set are the
same on every run. The fixture is reproduced here by the seed of
`book_scm.sample_rows`, so the MoonBit test and the upstream reference see the
very same rows.

The numbers of the two stage regression estimator on these rows are the ones
`_verify/two_stage_reference.py` prints with the upstream.

Usage:
    python _verify/gen_two_stage_testdata.py
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from book_scm import NUM_ROWS, sample_rows  # noqa: E402

# The root of the repository.
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The path of the generated file, relative to the root of the repository.
OUT = os.path.join(
    REPO_ROOT,
    "src",
    "tests",
    "book_testdata.mbt",
)

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


def write_source(columns: dict[str, np.ndarray]) -> None:
    """Writes the generated file."""
    parts: list[str] = []
    parts.append("/// The data set of the integration test of the book.")
    parts.append("///")
    parts.append("/// The rows are the ones of the upstream test `test_dowhy_chapter_7` of")
    parts.append("/// the file `tests/causal-inference-discovery-book/test_causal_inference_discovery_book.py`,")
    parts.append("/// the one of the chapter 7 of the book \"Causal Inference and Discovery in")
    parts.append("/// Python\". The upstream test class has the fixture `fixed_seed`, which seeds")
    parts.append("/// the generator of NumPy with zero, so the rows are the same on every run.")
    parts.append("///")
    parts.append("/// The file comes from the upstream reference of the two stage regression")
    parts.append("/// estimator, which `_verify/gen_two_stage_testdata.py` generates; do not edit")
    parts.append("/// it by hand.")
    parts.append("")
    parts.append("///|")
    parts.append("/// The data set of the integration test of the book.")
    parts.append("pub fn book_memory_frame() -> @api.DataFrame {")
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
    columns = sample_rows()
    write_source(columns)
    for name in ("X", "Z", "Y"):
        print(f"  {name}: {NUM_ROWS} rows")


if __name__ == "__main__":
    main()
