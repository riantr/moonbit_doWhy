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
LUNAFLOW = HERE / "lunaflow_qa.json"
STATIC_ANALYSIS = HERE / "static_analysis.json"
ANALYSER_READABLE = HERE / "analyser_readable.json"
QUANTILE_COEFFICIENTS = HERE / "quantile_coefficients.json"
NORMAL_PPF = HERE / "normal_ppf.json"

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


def lunaflow_qa() -> dict:
    """The measurement of the audit of the tree with the dynamic analyzer."""
    if not LUNAFLOW.exists():
        raise SystemExit(
            f"the file {LUNAFLOW} is missing: the audit of the tree is a "
            "measurement that is committed with the repository"
        )
    return json.loads(LUNAFLOW.read_text(encoding="utf-8"))


def static_analysis() -> dict:
    """The measurement of the audit of the tree with the static analyzer."""
    if not STATIC_ANALYSIS.exists():
        raise SystemExit(
            "the file %s is missing: the audit of the tree is a measurement "
            "that is committed with the repository" % STATIC_ANALYSIS
        )
    return json.loads(STATIC_ANALYSIS.read_text(encoding="utf-8"))


def analyser_readable() -> dict:
    """The measurement of the shape of the loops of the tree."""
    if not ANALYSER_READABLE.exists():
        raise SystemExit(
            "the file %s is missing: run `python _verify/check_analyser_readable.py`"
            % ANALYSER_READABLE
        )
    return json.loads(ANALYSER_READABLE.read_text(encoding="utf-8"))


def normal_ppf() -> dict:
    """The measurement of the check of the quantile function."""
    if not NORMAL_PPF.exists():
        raise SystemExit(
            "the file %s is missing: run `python _verify/check_normal_ppf.py`"
            % NORMAL_PPF
        )
    return json.loads(NORMAL_PPF.read_text(encoding="utf-8"))


def quantile_coefficients() -> dict:
    """The measurement of the bounds of the coefficients of the quantile."""
    if not QUANTILE_COEFFICIENTS.exists():
        raise SystemExit(
            "the file %s is missing: run "
            "`python _verify/check_quantile_coefficients.py`" % QUANTILE_COEFFICIENTS
        )
    return json.loads(QUANTILE_COEFFICIENTS.read_text(encoding="utf-8"))


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
    audit = lunaflow_qa()
    level1 = audit["level1"]
    level2 = audit["level2"]
    before = audit["scans_before"]["0.0.95"]
    tables = level1["by_rule_in_the_tables"]
    measured["the files the audit of the tree reads"] = level1["files"]
    measured["the functions the audit of the tree holds"] = level1["functions"]
    measured[
        "the statements the audit of the tree understands"
    ] = level1["statements_understood"]
    measured["the functions the audit of the tree enters"] = level1[
        "functions_entered"
    ]
    measured["the findings the audit of the tree reports"] = level1[
        "findings_in_the_tables"
    ]
    measured[
        "the findings of the family TAINT-INDEX of the audit"
    ] = tables["TAINT-INDEX"]
    measured[
        "the findings of the family BUDGET-EXCEEDED of the audit"
    ] = tables["BUDGET-EXCEEDED"]
    measured[
        "the findings of the family TAINT-INDEX-RANGE of the audit"
    ] = tables["TAINT-INDEX-RANGE"]
    measured[
        "the findings the sidecar of the audit holds"
    ] = level1["findings_in_the_sidecar"]
    measured[
        "the accesses the audit watches go out of bounds"
    ] = len(level1["out_of_bounds_observed"])
    measured[
        "the findings of the abstract interpretation of the audit"
    ] = level2["findings_in_the_sidecar"]
    measured[
        "the findings of the family INDEX-OOB of the audit"
    ] = level2["by_rule"]["INDEX-OOB"]
    measured[
        "the findings of the family INDEX-OOB of the second level of the audit"
    ] = level2["by_rule"]["INDEX-OOB"]
    measured[
        "the findings of the family TAINT-INDEX of the second level of the audit"
    ] = level2["by_rule"]["TAINT-INDEX"]
    measured[
        "the findings of the family UNSUPPORTED of the second level of the audit"
    ] = level2["by_rule"]["UNSUPPORTED"]
    measured[
        "the findings of the family RANGE-VIOLATION of the second level of the audit"
    ] = level2["by_rule"]["RANGE-VIOLATION"]
    measured[
        "the findings of the family BUDGET-EXCEEDED of the second level of the audit"
    ] = level2["by_rule"]["BUDGET-EXCEEDED"]
    measured[
        "the findings of the family INTEGER-OVERFLOW of the second level of the audit"
    ] = level2["by_rule"]["INTEGER-OVERFLOW"]
    measured[
        "the findings of the family DIVISION-BY-ZERO of the second level of the audit"
    ] = level2["by_rule"]["DIVISION-BY-ZERO"]
    measured[
        "the findings of the family INFINITE-LOOP of the second level of the audit"
    ] = level2["by_rule"]["INFINITE-LOOP"]
    measured[
        "the findings of the family UNREACHABLE of the second level of the audit"
    ] = level2["by_rule"]["UNREACHABLE"]
    packages = audit["per_package"]
    calibration = audit["calibration"]
    measured[
        "the functions the audit of the tree holds in the release of 0.0.95"
    ] = before["level1"]["functions"]
    measured[
        "the statements the audit of the tree understands in the release of 0.0.95"
    ] = before["level1"]["statements_understood"]
    measured[
        "the functions the audit of the tree enters when it scans the packages "
        "one by one in the release of 0.0.95"
    ] = before["per_package"]["functions_entered"]
    measured[
        "the packages the audit of the tree scans one by one"
    ] = packages["packages"]
    measured[
        "the functions the audit of the tree enters when it scans the packages one by one"
    ] = packages["functions_entered"]
    measured[
        "the findings the audit of the tree reports when it scans the packages one by one"
    ] = packages["findings_in_the_tables"]
    measured[
        "the findings the sidecar of the audit holds when it scans the packages one by one"
    ] = packages["findings_in_the_sidecar"]
    measured[
        "the findings of the family TAINT-INDEX of the audit of the packages"
    ] = packages["by_rule"]["TAINT-INDEX"]
    measured[
        "the findings of the family TAINT-INDEX-RANGE of the audit of the packages"
    ] = packages["by_rule"]["TAINT-INDEX-RANGE"]
    measured[
        "the findings of the family BUDGET-EXCEEDED of the audit of the packages"
    ] = packages["by_rule"]["BUDGET-EXCEEDED"]
    measured[
        "the findings of the family INFINITE-LOOP of the audit of the packages"
    ] = packages["by_rule"]["INFINITE-LOOP"]
    measured[
        "the shapes of the calibration of the audit"
    ] = calibration["shapes"]
    measured[
        "the findings of the calibration of the audit"
    ] = calibration["findings"]
    measured[
        "the findings of the family TAINT-INDEX of the calibration of the audit"
    ] = calibration["by_rule"]["TAINT-INDEX"]
    measured[
        "the findings of the family TAINT-INDEX-RANGE of the calibration of the audit"
    ] = calibration["by_rule"]["TAINT-INDEX-RANGE"]
    measured[
        "the shapes of the calibration of the audit without a finding"
    ] = calibration["shapes_without_a_finding"]
    measured[
        "the shapes the calibration of the audit reports as an error that are safe"
    ] = calibration["shapes_reported_as_an_error_that_are_safe"]
    measured[
        "the shapes of the calibration of the audit that are holes"
    ] = calibration["shapes_that_are_holes"]
    measured[
        "the shapes of the calibration of the audit that are holes and are reported as an error"
    ] = calibration["shapes_reported_as_an_error_that_are_holes"]
    measured[
        "the places of the port that refuse a number of neighbours below one"
    ] = audit["knn_guard"]["places"]
    measured["the entry points the audit can enter"] = audit["capacity"][
        "entry_points_that_survive"
    ]
    measured["the entry points the audit cannot enter"] = audit["capacity"][
        "entry_points_that_trap"
    ]
    analysis = static_analysis()
    scans = analysis["scans"]
    current = scans[
        max(scans, key=lambda version: tuple(int(p) for p in version.split(".")))
    ]
    measured["the files the static analyzer reads"] = current["files"]
    measured["the files the static analyzer understands"] = current["parsed"]
    measured["the actionable findings of the static analyzer"] = current[
        "actionable"
    ]
    measured["the notices of the static analyzer"] = current["notices"]
    measured["the unreliable regions of the static analyzer"] = current[
        "unreliable"
    ]
    measured["the findings the static analyzer withholds"] = current["withheld"]
    measured["the unchecked calls of the static analyzer"] = current["unchecked"]
    measured["the files the static analyzer does not finish"] = len(
        current["files_not_finished"]
    )
    delta = current.get("printed_findings_delta") or {}
    measured[
        "the findings the scan after the change holds and the scan before does not"
    ] = delta.get("new", 0)
    measured[
        "the findings the scan before the change holds and the scan after does not"
    ] = delta.get("gone", 0)
    measured[
        "the findings of the family MSA-001 that the scan after the change holds"
    ] = (delta.get("new_by_family") or {}).get("MSA-001", 0)
    measured[
        "the actionable findings of the static analyzer of the release of 0.0.95"
    ] = scans["0.0.95"]["actionable"]
    measured[
        "the files the scan of the release of 0.0.96 does not finish"
    ] = scans["0.0.96"]["not_parsed_reasons"].get("files", 0)
    measured["the printed findings of the scan before the change"] = delta.get(
        "printed_before", 0
    )
    measured["the printed findings of the scan after the change"] = delta.get(
        "printed_after", 0
    )
    readable = analyser_readable()
    measured[
        "the loops of the tree that read a tuple by its index"
    ] = readable["indexed_loops"]
    measured[
        "the files of the tree that hold a loop that reads a tuple by its index"
    ] = readable["files_with_an_indexed_loop"]
    measured[
        "the loops of the tree of the release of 0.0.96 whose variable is a tuple"
    ] = readable["before"]["tuple_loops"]
    measured[
        "the headers of the tree of the release of 0.0.96 that the formatter split"
    ] = readable["before"]["split_headers"]
    quantile = normal_ppf()
    coefficients = quantile_coefficients()
    measured[
        "the accesses of the coefficients of the quantile function"
    ] = coefficients["accesses"]
    measured[
        "the accesses of the coefficients that are out of bounds"
    ] = coefficients["out_of_bounds"]
    measured[
        "the arguments of the check of the quantile function"
    ] = quantile["arguments"]
    measured[
        "the largest relative distance of the quantile function to the upstream"
    ] = quantile["largest_relative_distance"]
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
    (
        "AGENTS.md",
        "the files the audit of the tree reads",
        r"the scan reads the \*\*(\d+)\*\* files of the tree",
    ),
    (
        "AGENTS.md",
        "the functions the audit of the tree holds",
        r"holds the \*\*(\d+)\*\* functions and the",
    ),
    (
        "AGENTS.md",
        "the statements the audit of the tree understands",
        r"holds the \*\*\d+\*\* functions and the \*\*(\d+)\*\* statements it\s+"
        r"understands",
    ),
    (
        "AGENTS.md",
        "the functions the audit of the tree holds in the release of 0.0.95",
        r"held the \*\*(\d+)\*\* functions and the",
    ),
    (
        "AGENTS.md",
        "the statements the audit of the tree understands in the release of 0.0.95",
        r"held the \*\*\d+\*\* functions and the \*\*(\d+)\*\* statements it\s+"
        r"understands",
    ),
    (
        "AGENTS.md",
        "the functions the audit of the tree enters when it scans the packages "
        "one by one in the release of 0.0.95",
        r"entered the \*\*(\d+)\*\* of them",
    ),
    (
        "AGENTS.md",
        "the functions the audit of the tree enters",
        r"enters the \*\*(\d+)\*\* of them of the cap",
    ),
    (
        "AGENTS.md",
        "the findings the audit of the tree reports",
        r"reports the \*\*(\d+)\*\* findings of its tables",
    ),
    (
        "AGENTS.md",
        "the findings of the family TAINT-INDEX of the audit",
        r"\*\*(\d+)\*\* are of the family `TAINT-INDEX`",
    ),
    (
        "AGENTS.md",
        "the findings of the family BUDGET-EXCEEDED of the audit",
        r"\*\*(\d+)\*\* are of the family `BUDGET-EXCEEDED`",
    ),
    (
        "AGENTS.md",
        "the accesses the audit watches go out of bounds",
        r"The (\w+) accesses that the scan watched go out of bounds",
    ),
    (
        "AGENTS.md",
        "the findings of the family INDEX-OOB of the audit",
        r"\*\*(\d+)\*\* are of the family `INDEX-OOB`",
    ),
    (
        "AGENTS.md",
        "the findings of the abstract interpretation of the audit",
        r"the run with `--level 2` holds the \*\*(\d+)\*\*\s+findings",
    ),
    (
        "AGENTS.md",
        "the findings of the family INDEX-OOB of the second level of the audit",
        r"\*\*(\d+)\*\* are of the family `INDEX-OOB`",
    ),
    (
        "AGENTS.md",
        "the findings of the family TAINT-INDEX of the second level of the audit",
        r"\*\*(\d+)\*\* of the family `TAINT-INDEX`,",
    ),
    (
        "AGENTS.md",
        "the findings of the family UNSUPPORTED of the second level of the audit",
        r"\*\*(\d+)\*\* of the family `UNSUPPORTED`",
    ),
    (
        "AGENTS.md",
        "the findings of the family RANGE-VIOLATION of the second level of the audit",
        r"\*\*(\d+)\*\* of the family `RANGE-VIOLATION`",
    ),
    (
        "AGENTS.md",
        "the findings of the family BUDGET-EXCEEDED of the second level of the audit",
        r"\*\*(\d+)\*\* of the family `BUDGET-EXCEEDED`,",
    ),
    (
        "AGENTS.md",
        "the findings of the family INTEGER-OVERFLOW of the second level of the audit",
        r"\*\*(\d+)\*\* of the family `INTEGER-OVERFLOW`",
    ),
    (
        "AGENTS.md",
        "the findings of the family DIVISION-BY-ZERO of the second level of the audit",
        r"\*\*(\d+)\*\* of the family `DIVISION-BY-ZERO`",
    ),
    (
        "AGENTS.md",
        "the findings of the family INFINITE-LOOP of the second level of the audit",
        r"\*\*(\d+)\*\* of the family `INFINITE-LOOP`",
    ),
    (
        "AGENTS.md",
        "the findings of the family UNREACHABLE of the second level of the audit",
        r"\*\*(\d+)\*\* of the family `UNREACHABLE`",
    ),
    (
        "AGENTS.md",
        "the findings of the family TAINT-INDEX-RANGE of the audit",
        r"\*\*(\d+)\*\* are of the family `TAINT-INDEX-RANGE`",
    ),
    (
        "AGENTS.md",
        "the findings the sidecar of the audit holds",
        r"The sidecar of the findings holds \*\*(\d+)\*\* of them",
    ),
    (
        "AGENTS.md",
        "the packages the audit of the tree scans one by one",
        r"the scan of the \*\*(\d+)\*\* packages of the tree",
    ),
    (
        "AGENTS.md",
        "the functions the audit of the tree enters when it scans the packages one by one",
        r"packages of the tree enters the \*\*(\d+)\*\* functions",
    ),
    (
        "AGENTS.md",
        "the findings the audit of the tree reports when it scans the packages one by one",
        r"The tables of the scan of the packages hold the \*\*(\d+)\*\* findings",
    ),
    (
        "AGENTS.md",
        "the findings the sidecar of the audit holds when it scans the packages one by one",
        r"its sidecar holds the \*\*(\d+)\*\* of them",
    ),
    (
        "AGENTS.md",
        "the findings of the family TAINT-INDEX of the audit of the packages",
        r"The family `TAINT-INDEX` holds the \*\*(\d+)\*\* of them",
    ),
    (
        "AGENTS.md",
        "the findings of the family TAINT-INDEX-RANGE of the audit of the packages",
        r"the family `TAINT-INDEX-RANGE` holds the \*\*(\d+)\*\*",
    ),
    (
        "AGENTS.md",
        "the findings of the family BUDGET-EXCEEDED of the audit of the packages",
        r"the family `BUDGET-EXCEEDED` holds\s+the \*\*(\d+)\*\*",
    ),
    (
        "AGENTS.md",
        "the findings of the family INFINITE-LOOP of the audit of the packages",
        r"the family `INFINITE-LOOP` holds the \*\*(\d+)\*\*",
    ),
    (
        "AGENTS.md",
        "the shapes of the calibration of the audit",
        r"a package of\s+\*\*(\d+)\*\* known shapes of the guard",
    ),
    (
        "AGENTS.md",
        "the findings of the calibration of the audit",
        r"the analyzer reports the \*\*(\d+)\*\* findings of them",
    ),
    (
        "AGENTS.md",
        "the findings of the family TAINT-INDEX of the calibration of the audit",
        r"the family `TAINT-INDEX` holds \*\*(\d+)\*\* of them",
    ),
    (
        "AGENTS.md",
        "the findings of the family TAINT-INDEX-RANGE of the calibration of the audit",
        r"the family `TAINT-INDEX-RANGE` holds \*\*(\d+)\*\* of them",
    ),
    (
        "AGENTS.md",
        "the shapes of the calibration of the audit without a finding",
        r"the \*\*(\d+)\*\* shape of the clamped index gets no finding",
    ),
    (
        "AGENTS.md",
        "the shapes the calibration of the audit reports as an error that are safe",
        r"reports an error for\s+(\w+) of the shapes that are safe code",
    ),
    (
        "AGENTS.md",
        "the shapes of the calibration of the audit that are holes",
        r"of the (\w+) shapes that are holes",
    ),
    (
        "AGENTS.md",
        "the shapes of the calibration of the audit that are holes and are reported as an error",
        r"it reports \*\*(\w+)\*\* of the",
    ),
    (
        "AGENTS.md",
        "the places of the port that refuse a number of neighbours below one",
        r"refuse[s]? the number of neighbours in \*\*(\w+)\*\* places",
    ),
    (
        "AGENTS.md",
        "the files the static analyzer reads",
        r"the static analyzer reads \*\*(\d+)\*\* files",
    ),
    (
        "AGENTS.md",
        "the files the static analyzer understands",
        r"the static analyzer reads \*\*\d+\*\* files, "
        r"understands \*\*(\d+)\*\* of them",
    ),
    (
        "AGENTS.md",
        "the actionable findings of the static analyzer",
        r"reports \*\*(\d+)\*\* actionable findings",
    ),
    (
        "AGENTS.md",
        "the notices of the static analyzer",
        r"The rest is \*\*(\d+)\*\* notices",
    ),
    (
        "AGENTS.md",
        "the unreliable regions of the static analyzer",
        r"holds \*\*(\d+)\*\* unreliable regions",
    ),
    (
        "AGENTS.md",
        "the findings the static analyzer withholds",
        r"of which \*\*(\d+)\*\* withhold a finding",
    ),
    (
        "AGENTS.md",
        "the unchecked calls of the static analyzer",
        r"and \*\*(\d+)\*\* unchecked calls",
    ),
    (
        "AGENTS.md",
        "the files the static analyzer does not finish",
        r"the \*\*(\d+)\*\* files the analyzer does not finish",
    ),
    (
        "AGENTS.md",
        "the actionable findings of the static analyzer of the release of 0.0.95",
        r"The scan of the release of 0\.0\.95 reported \*\*(\d+)\*\* "
        r"actionable finding",
    ),
    (
        "AGENTS.md",
        "the files the scan of the release of 0.0.96 does not finish",
        r"[Tt]he scan of the release of 0\.0\.96 did not finish \*\*(\d+)\*\* files",
    ),
    (
        "AGENTS.md",
        "the printed findings of the scan before the change",
        r"the scan before holds \*\*(\d+)\*\* printed findings",
    ),
    (
        "AGENTS.md",
        "the printed findings of the scan after the change",
        r"the scan after holds \*\*(\d+)\*\* printed findings",
    ),
    (
        "AGENTS.md",
        "the findings the scan after the change holds and the scan before does not",
        r"the \*\*(\d+)\*\* findings of the second report that the first one "
        r"does not hold",
    ),
    (
        "AGENTS.md",
        "the findings the scan before the change holds and the scan after does not",
        r"the \*\*(\d+)\*\* findings of the first report that the second one "
        r"does not hold",
    ),
    (
        "AGENTS.md",
        "the findings of the family MSA-001 that the scan after the change holds",
        r"all \*\*(\d+)\*\* of them of the family `MSA-001`",
    ),
    (
        "AGENTS.md",
        "the loops of the tree of the release of 0.0.96 whose variable is a tuple",
        r"held \*\*(\d+)\*\* loops whose\s+variable is a tuple pattern",
    ),
    (
        "AGENTS.md",
        "the headers of the tree of the release of 0.0.96 that the formatter split",
        r"\*\*(\d+)\*\* headers of a loop that the formatter\s+had split",
    ),
    (
        "AGENTS.md",
        "the loops of the tree that read a tuple by its index",
        r"holds \*\*(\d+)\*\* loops that read a tuple by its\s+index",
    ),
    (
        "AGENTS.md",
        "the files of the tree that hold a loop that reads a tuple by its index",
        r"index, in \*\*(\d+)\*\* of its files",
    ),
    (
        "AGENTS.md",
        "the arguments of the check of the quantile function",
        r"prints the quantile of the normal\s+distribution for "
        r"\*\*(\d+)\*\* arguments",
    ),
    (
        "AGENTS.md",
        "the accesses of the coefficients of the quantile function",
        r"every index that is read of them -- \*\*(\d+)\*\* of them --",
    ),
    (
        "AGENTS.md",
        "the accesses of the coefficients that are out of bounds",
        r"requires that\s+\*\*(\d+)\*\* of them is out of bounds",
    ),
    (
        "AGENTS.md",
        "the largest relative distance of the quantile function to the upstream",
        r"to a relative distance of \*\*([0-9.]+e-[0-9]+)\*\* at worst",
    ),
    (
        "AGENTS.md",
        "the entry points the audit can enter",
        r"between \*\*(\d+)\*\* and \*\*\d+\*\* entry\s+points",
    ),
    (
        "AGENTS.md",
        "the entry points the audit cannot enter",
        r"between \*\*\d+\*\* and \*\*(\d+)\*\* entry\s+points",
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
            expected = measured[key]
            if isinstance(expected, float):
                # a floating point measurement is compared with a relative
                # distance of a thousandth, which is the rounding of the
                # number in the document
                tolerance = abs(expected) * 0.001
                try:
                    stated = float(value)
                except ValueError:
                    failures.append(
                        f"{name}: the document states {value} for {key}, and "
                        "the measurement is a number"
                    )
                    continue
                checked += 1
                if arguments.falsify:
                    if abs(stated - expected) <= tolerance:
                        failures.append(
                            f"{name}: the document states the measured number "
                            f"{expected} for {key}, and the falsifying run "
                            "requires a wrong one"
                        )
                elif abs(stated - expected) > tolerance:
                    failures.append(
                        f"{name}: the document states {value} for {key}, and "
                        f"the measurement is {expected}"
                    )
                continue
            stated = int(value) if value.isdigit() else number_of(value)
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
