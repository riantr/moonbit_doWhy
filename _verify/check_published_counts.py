"""The counts the README and the AGENTS file publish, measured against the port.

The README of the port and its `AGENTS.md` publish a number of counts: the
number of the cases pytest collects in the upstream, the number of the
notebooks, the number of the notebooks the port mirrors, the number of the
verdicts of the run of the upstream, and the number of the graphs of a table
of the port. Every one of those counts is a **measurement**, and a measurement
that is written in a document and never checked is a number that drifts the
moment the upstream or the port changes.

This script measures every count again, from the artefact that holds it, and
requires the document to state the measured number. It never repeats a count
of its own: every number it compares comes from a file of the repository or
from the tree of the port, so the check fails as soon as the measurement
changes and the document does not follow.

The artefacts are:

- `_verify/upstream_collected_cases.json` -- the cases pytest collects in the
  upstream. It holds the total (635), the number of the cases the task `test`
  of the upstream runs (620) and the number of the deselected cases (15).
- `_verify/upstream_notebook_verdicts.json` -- the verdict of the run of the
  upstream for every one of its notebooks. It holds the three verdicts the
  README names: 23 notebooks run as they are, 10 run once the repairs are
  applied and 12 fail.
- the tree of the port itself -- the number of the notebooks the headers of
  the test files name, and the number of the rows of the table of the graphs
  of the backdoor identifier.

The count of the notebooks the port does not mirror is the length of the
table `NOTEBOOKS` of the coverage script, which is the only place that names
them and the reason why.

The count of the files of the upstream that fail with the numpy-2 error is
the length of the table `BINARY_TREATMENT_FILES` of the script
`_verify/upstream_verdicts.py`, which names them one by one. The count of the
cases of the upstream that fail that way needs the run of the suite of the
upstream, which the script produces; the script writes the verdict of every
one of its cases into `_verify/upstream_suite_verdicts.json`, and this script
reads that file.

The numbers of the documents are written in two ways: as digits ("the 635
cases") and as words ("the **twenty** notebooks"). Both are read here, so a
sentence that changes the spelling of its count is caught as well.

Usage:

    python _verify/check_published_counts.py
    python _verify/check_published_counts.py --falsify
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
PORT = ROOT / "src"
README = ROOT / "README.mbt.md"
AGENTS = ROOT / "AGENTS.md"
COLLECTED = HERE / "upstream_collected_cases.json"
VERDICTS = HERE / "upstream_notebook_verdicts.json"
SUITE_VERDICTS = HERE / "upstream_suite_verdicts.json"

# The documents that publish the counts.
DOCUMENTS = {"README.mbt.md": README, "AGENTS.md": AGENTS}

# The numbers the documents write as words.
WORDS = {
    "one": 1,
    "two": 2,
    "three": 3,
    "four": 4,
    "five": 5,
    "six": 6,
    "seven": 7,
    "eight": 8,
    "nine": 9,
    "ten": 10,
    "eleven": 11,
    "twelve": 12,
    "thirteen": 13,
    "fourteen": 14,
    "fifteen": 15,
    "sixteen": 16,
    "seventeen": 17,
    "eighteen": 18,
    "nineteen": 19,
    "twenty": 20,
    "thirty": 30,
    "forty": 40,
    "fifty": 50,
    "sixty": 60,
    "seventy": 70,
    "eighty": 80,
    "ninety": 90,
}


def number_of(word: str) -> int:
    """The number a word spells, with the compound words of two words."""
    if "-" in word:
        head, _, tail = word.partition("-")
        return WORDS[head] + WORDS[tail]
    return WORDS[word]


# A number of a document: either digits or the words of the numbers.
NUMBER = r"(?:\d+|[a-z]+(?:-[a-z]+)?)"


def collected() -> dict:
    """The file of the collected cases of the upstream."""
    if not COLLECTED.exists():
        raise SystemExit(
            f"the file {COLLECTED} is missing: run "
            "`python _verify/collect_upstream_cases.py`"
        )
    return json.loads(COLLECTED.read_text(encoding="utf-8"))


def verdicts() -> dict[str, str]:
    """The verdict of the run of the upstream for every notebook."""
    if not VERDICTS.exists():
        raise SystemExit(
            f"the file {VERDICTS} is missing: run "
            "`python _verify/upstream_notebook_verdicts.py`"
        )
    data = json.loads(VERDICTS.read_text(encoding="utf-8"))
    return {
        record["notebook"]: record.get("verdict", "")
        for record in data.get("notebooks", [])
    }


def notebooks_of_the_upstream() -> list[str]:
    """The notebooks the file of the notebooks of the upstream collects."""
    data = collected()
    names = data.get("cases", {}).get("tests/test_notebooks.py", [])
    found = []
    for case in names:
        if "[" in case and case.endswith("]"):
            found.append(case[case.index("[") + 1 : -1])
    return sorted(set(found))


def notebooks_of_the_port() -> set[str]:
    """The notebooks the headers of the test files of the port name."""
    found: set[str] = set()
    for path in sorted(PORT.rglob("*.mbt")):
        text = path.read_text(encoding="utf-8")
        if 'test "' not in text:
            continue
        for name in re.findall(r"`([A-Za-z0-9_ .\-]+\.ipynb)`", text[:4000]):
            found.add(name)
    return found


def rows_of_the_table_of_the_graphs() -> int:
    """The number of the rows of the table of the graphs of the port."""
    path = PORT / "identifiers" / "test_graphs.mbt"
    if not path.exists():
        raise SystemExit(f"the file {path} is missing")
    text = path.read_text(encoding="utf-8")
    marker = "pub fn backdoor_cases("
    if marker not in text:
        raise SystemExit(f"the file {path} holds no table backdoor_cases")
    body = text[text.index(marker) :]
    body = body[body.index("{") :]
    start = body.index("[")
    end = body.index("]", start)
    inner = body[start + 1 : end]
    depth = 0
    rows = 0
    for character in inner:
        if character in "{[":
            depth += 1
        elif character in "}]":
            depth -= 1
        elif character == "," and depth == 0:
            rows += 1
    # The last row of the table has no comma behind it.
    if inner.strip() and not inner.strip().endswith(","):
        rows += 1
    return rows


def entries_of_a_table_of_the_script(script: str, table: str) -> int:
    """The number of the entries of a table of a script of the repository.

    The table is a list of tuples, and every entry of it starts with an open
    parenthesis on a line of its own. The table of the files of the upstream
    is a list of strings, and every entry of it starts with a quote.
    """
    path = HERE / script
    if not path.exists():
        raise SystemExit(f"the file {path} is missing")
    text = path.read_text(encoding="utf-8")
    marker = None
    for candidate in (
        table + ": list[tuple[str, str]] = [",
        table + ": list[tuple[str, str, str]] = [",
        table + ": list[str] = [",
        table + " = [",
    ):
        if candidate in text:
            marker = candidate
            break
    if marker is None:
        raise SystemExit(f"the file {path} holds no table {table}")
    body = text[text.index(marker) + len(marker) :]
    body = body[: body.index("\n]\n")]
    tuples = len(re.findall(r"^\s*\($", body, re.MULTILINE))
    if tuples:
        return tuples
    return len(re.findall(r'^\s{4}"', body, re.MULTILINE))


def suite_verdicts() -> dict:
    """The verdicts of the run of the suite of the upstream."""
    if not SUITE_VERDICTS.exists():
        raise SystemExit(
            f"the file {SUITE_VERDICTS} is missing: run "
            "`python _verify/upstream_verdicts.py`"
        )
    return json.loads(SUITE_VERDICTS.read_text(encoding="utf-8"))


def measurements() -> dict[str, int]:
    """Every count the documents publish, measured again."""
    data = collected()
    verdict_of = verdicts()
    upstream_notebooks = notebooks_of_the_upstream()
    mirrored = sorted(notebooks_of_the_port() & set(upstream_notebooks))
    measured = {
        "the cases pytest collects in the upstream": data["total"],
        "the cases the task `test` of the upstream runs": data.get(
            "default_total", data["total"]
        ),
        "the deselected cases of the upstream": len(
            data.get("deselected", [])
        ),
        "the notebooks of the upstream": len(upstream_notebooks),
        "the notebooks the port mirrors": len(mirrored),
        "the notebooks the port does not mirror": entries_of_a_table_of_the_script(
            "upstream_test_coverage.py", "NOTEBOOKS"
        ),
        "the notebooks that run as they are": sum(
            1 for value in verdict_of.values() if value == "ok"
        ),
        "the notebooks that run once the repairs are applied": sum(
            1 for value in verdict_of.values() if value == "ok_with_the_repair"
        ),
        "the notebooks that fail": sum(
            1 for value in verdict_of.values() if value == "failed"
        ),
        "the graphs of the table of the backdoor identifier": rows_of_the_table_of_the_graphs(),
        "the files of the upstream that fail with the numpy-2 error": entries_of_a_table_of_the_script(
            "upstream_verdicts.py", "BINARY_TREATMENT_FILES"
        ),
    }
    suite = suite_verdicts()
    measured["the cases of the upstream that fail with the numpy-2 error"] = suite[
        "numpy-2 binary treatment"
    ]
    return measured


# The sentences of the documents that publish a count.
#
# Every entry names the document, the count it publishes and the pattern that
# finds the sentence and the number inside it. The pattern is per document,
# because the two documents word the same count differently.
CLAIMS: list[tuple[str, str, str]] = [
    (
        "README.mbt.md",
        "the cases pytest collects in the upstream",
        r"holds the (\d+) cases pytest collects",
    ),
    (
        "README.mbt.md",
        "the cases pytest collects in the upstream",
        r"Every one of the (\d+) cases of the upstream",
    ),
    (
        "README.mbt.md",
        "the cases the task `test` of the upstream runs",
        r"it runs (\d+) of the \d+ cases",
    ),
    (
        "README.mbt.md",
        "the deselected cases of the upstream",
        r"holds the (\d+) deselected cases",
    ),
    (
        "README.mbt.md",
        "the notebooks of the upstream",
        r"The (\d+) cases of the file of the notebooks are the \d+ notebooks",
    ),
    (
        "README.mbt.md",
        "the notebooks of the upstream",
        r"The port mirrors \d+ of the (\d+) notebooks",
    ),
    (
        "README.mbt.md",
        "the notebooks of the upstream",
        r"runs the (\d+) notebooks with the runner",
    ),
    (
        "README.mbt.md",
        "the notebooks of the upstream",
        r"The verdicts of the (\d+) notebooks are",
    ),
    (
        "README.mbt.md",
        "the notebooks the port mirrors",
        r"The port mirrors (\d+) of the \d+ notebooks",
    ),
    (
        "README.mbt.md",
        "the notebooks the port mirrors",
        r"the scenarios of \*\*(" + NUMBER + r")\*\* of the notebooks run as test cases",
    ),
    (
        "README.mbt.md",
        "the notebooks the port does not mirror",
        r"names the (\d+) it does not mirror",
    ),
    (
        "README.mbt.md",
        "the notebooks the port does not mirror",
        r"the \*\*(" + NUMBER + r")\*\* notebooks the port does not mirror",
    ),
    (
        "README.mbt.md",
        "the notebooks that run as they are",
        r"\*\*(\d+)\*\* of them run as they are",
    ),
    (
        "README.mbt.md",
        "the notebooks that run once the repairs are applied",
        r"\*\*(\d+)\*\* run once the repairs are applied",
    ),
    (
        "README.mbt.md",
        "the notebooks that fail",
        r"\*\*(\d+)\*\* fail for a reason of the",
    ),
    (
        "README.mbt.md",
        "the graphs of the table of the backdoor identifier",
        r"a table that holds the same (\d+) graphs",
    ),
    (
        "README.mbt.md",
        "the files of the upstream that fail with the numpy-2 error",
        r"\*\*(" + NUMBER + r")\*\* of its test files fail that way",
    ),
    (
        "README.mbt.md",
        "the cases of the upstream that fail with the numpy-2 error",
        r"\*\*(\d+)\*\* of its cases do",
    ),
    (
        "AGENTS.md",
        "the cases pytest collects in the upstream",
        r"holds the (\d+) collected cases",
    ),
    (
        "AGENTS.md",
        "the cases pytest collects in the upstream",
        r"the suite then collects all (\d+) of its\s+cases",
    ),
    (
        "AGENTS.md",
        "the cases pytest collects in the upstream",
        r"the \*\*(\d+)\*\* are the cases the port\s+has to mirror",
    ),
    (
        "AGENTS.md",
        "the cases the task `test` of the upstream runs",
        r"it runs \*\*(\d+)\*\* of the \d+ cases",
    ),
    (
        "AGENTS.md",
        "the deselected cases of the upstream",
        r"holds the (\d+) deselected\s+cases",
    ),
    (
        "AGENTS.md",
        "the notebooks of the upstream",
        r"the (\d+) notebooks, so that the claims",
    ),
    (
        "AGENTS.md",
        "the notebooks of the upstream",
        r"The notebooks of the upstream are the (\d+) cases of the file",
    ),
    (
        "AGENTS.md",
        "the notebooks the port does not mirror",
        r"names the (\d+) notebooks the port does not mirror",
    ),
    (
        "AGENTS.md",
        "the files of the upstream that fail with the numpy-2 error",
        r"in \*\*(" + NUMBER + r")\*\* files: the linear",
    ),
    (
        "AGENTS.md",
        "the files of the upstream that fail with the numpy-2 error",
        r"it breaks in (" + NUMBER + r")\s+of its files",
    ),
    (
        "AGENTS.md",
        "the cases of the upstream that fail with the numpy-2 error",
        r"gives \*\*(\d+)\*\* cases\s+that fail with the numpy 2 error",
    ),
]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--falsify",
        action="store_true",
        help="require the documents to state a wrong number, to prove that the "
        "check fails when the documents drift",
    )
    arguments = parser.parse_args()

    measured = measurements()
    failures: list[str] = []
    checked = 0

    for name, key, pattern in CLAIMS:
        path = DOCUMENTS[name]
        text = path.read_text(encoding="utf-8")
        # The documents are wrapped, so a sentence is broken over several
        # lines. The text is read as one line, so that a pattern finds the
        # sentence wherever the wrap falls.
        found = re.findall(pattern, " ".join(text.split()))
        if not found:
            failures.append(
                f"{name}: the sentence that publishes the number of {key} is "
                f"gone: {pattern}"
            )
            continue
        for value in found:
            checked += 1
            stated = int(value) if value.isdigit() else number_of(value)
            expected = measured[key]
            if arguments.falsify:
                if stated == expected:
                    failures.append(
                        f"{name}: the sentence that publishes the number of "
                        f"{key} states the measured number {expected}, and the "
                        "falsifying run requires a wrong one"
                    )
            elif stated != expected:
                failures.append(
                    f"{name}: the document states {value} for {key}, and the "
                    f"measurement is {expected}"
                )

    print(f"the documents publish {checked} count(s)")
    for key, value in measured.items():
        print(f"  {value:>5}  {key}")
    print()

    if failures:
        print(f"--- {len(failures)} failure(s)")
        for failure in failures:
            print("   ", failure)
        return 1
    print("every count the documents publish is the measured one")
    return 0


if __name__ == "__main__":
    sys.exit(main())
