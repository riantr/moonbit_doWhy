"""The measurements of the static analyzer of the registry.

The analyzer is the package `riantr/moonbit_static_analysis` of the registry
and it reads a tree without touching it:

    moonx riantr/moonbit_static_analysis@latest <the path of the tree>

The script runs the analyzer on the tree of the repository, parses its report
and writes the measurements into the file `_verify/static_analysis.json`.  The
checker `_verify/check_published_counts.py` requires the documents to state
the measured numbers, so a count that drifts away from its measurement fails
the check.

The report of a scan that was taken before can be recorded as well, so that
the measurement of two releases of the tree sit next to each other:

    python _verify/static_analysis_report.py --scan <the report> --version <the version>

The report of the tree before can be given as well, and then the script
measures the difference between the two reports -- the findings of the first
report that the second one does not hold, and the findings of the second one
that the first one does not hold:

    python _verify/static_analysis_report.py --scan <the report> --version <the version> \
        --scan-before <the report before> --version-before <the version before>

Usage:
    python _verify/static_analysis_report.py
    python _verify/static_analysis_report.py --scan report.txt --version 0.0.95
"""

from __future__ import annotations

import argparse
import io
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
ARTEFACT = HERE / "static_analysis.json"
MOON_MOD = ROOT / "moon.mod"

COMMAND = "moonx riantr/moonbit_static_analysis@latest <the path of the tree>"
TOOL = "riantr/moonbit_static_analysis"

# The line of a file of the tree.
FILE_LINE = re.compile(
    r"^(CLEAN|FOUND|PARTIAL)\t(\S+)\tdefects=(\d+)\tnotices=(\d+)\tunchecked=(\d+)"
    r"(?:\tread up to line (\d+), (\d+) after it not shown)?\t(.+)$"
)

# The line of a finding.
FINDING_LINE = re.compile(r"^(\d+):(\d+) - (notice|warning|defect|error): (.+)$")

# The family and the confidence of a finding.
FAMILY = re.compile(r"\[([^\]]*)\]\s*$")


def version_of_the_tree() -> str:
    """The version of the tree, which the manifest of the module holds."""
    with io.open(MOON_MOD, "r", encoding="utf-8", newline="") as handle:
        for line in handle:
            if line.startswith("version"):
                return line.split('"')[1]
    raise SystemExit("the manifest of the module has no version")


def files_of_the_tree() -> list[str]:
    """The files of the tree that the analyzer reads."""
    found = []
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file():
            continue
        if "_build" in path.parts or ".git" in path.parts:
            continue
        if path.suffix in (".mbt", ".mbti") or path.name.endswith(".mbt.md"):
            found.append("./" + path.relative_to(ROOT).as_posix())
    return found


def parse(report: str) -> dict:
    """Parse the report of the analyzer into the measurements."""
    measurements: dict = {
        "files": 0,
        "parsed": 0,
        "parsed_share": "",
        "actionable": 0,
        "notices": 0,
        "unreliable": 0,
        "withheld": 0,
        "unchecked": 0,
        "total": 0,
        "notices_printed": 0,
        "notices_aggregated": 0,
        "by_kind": {},
        "notices_by_shape": {},
        "not_parsed_reasons": {},
        "interface": {},
        "package_private": {},
        "actionable_findings": [],
        "files_not_finished": [],
    }
    finished: list[str] = []
    current_file = ""
    reasons: dict[str, dict] = {}
    for line in report.splitlines():
        if not line.strip():
            continue
        if line.startswith("IFACE\t"):
            parts = line.split("\t")
            values = {}
            for part in parts[1:]:
                if "=" in part:
                    key, _, value = part.partition("=")
                    key = re.sub(r"\W", "", key)
                    values[key] = value
            measurements["interface"] = {
                "types": int(values.get("types", 0)),
                "values": int(values.get("values", 0)),
                "dirs": int(re.sub(r"\D", "", values.get("dirs", "0")) or 0),
            }
            continue
        if line.startswith("PRIVTAB\t"):
            parts = line.split("\t")
            values = {}
            for part in parts[1:]:
                if "=" in part:
                    key, _, value = part.partition("=")
                    values[key] = value
            measurements["package_private"] = {
                "packages": int(values.get("packages", 0)),
                "names": int(values.get("names", 0)),
            }
            continue
        parts = line.split("\t")
        if parts[0] in ("CLEAN", "FOUND", "PARTIAL") and len(parts) >= 2:
            current_file = parts[-1].strip()
            if parts[0] in ("CLEAN", "FOUND"):
                finished.append(current_file)
            continue
        found = FINDING_LINE.match(line)
        if found:
            kind = found.group(3)
            if kind == "notice":
                continue
            message = found.group(4)
            tags = FAMILY.search(message)
            family = ""
            confidence = ""
            if tags:
                parts = [p.strip() for p in tags.group(1).split(",")]
                for part in parts:
                    if part.startswith("MSA-"):
                        family = part
                    elif part in ("high", "medium", "low", "undecided"):
                        confidence = part
            measurements["actionable_findings"].append(
                {
                    "file": current_file,
                    "line": int(found.group(1)),
                    "column": int(found.group(2)),
                    "kind": kind,
                    "family": family,
                    "confidence": confidence,
                    "message": message,
                }
            )
            continue
        if line.startswith("NOTICES\tTOTAL\t"):
            parts = line.split("\t")
            values = {}
            for part in parts[2:]:
                if "=" in part:
                    key, _, value = part.partition("=")
                    values[key] = value
            measurements["notices_printed"] = int(values.get("printed", 0))
            measurements["notices_aggregated"] = int(values.get("aggregated", 0))
            continue
        if line.startswith("NOTICES\tcount="):
            parts = line.split("\t")
            count = int(parts[1].split("=")[1])
            measurements["notices_by_shape"][parts[2].strip()] = count
            continue
        if line.startswith("PARSED\t"):
            parts = line.split("\t")
            head = parts[1]
            numbers = re.findall(r"\d+", head)
            measurements["parsed"] = int(numbers[0])
            measurements["files"] = int(numbers[1])
            share = re.search(r"\(([^)]*)\)", head)
            if share:
                measurements["parsed_share"] = share.group(1)
            continue
        if line.startswith("BYKIND\t"):
            parts = line.split("\t")
            kind = parts[1]
            values = {}
            for part in parts[2:]:
                if "=" in part:
                    key, _, value = part.partition("=")
                    values[key] = value
            measurements["by_kind"][kind] = {
                "files": int(values.get("files", 0)),
                "parsed": int(values.get("parsed", 0)),
                "defects": int(values.get("defects", 0)),
                "notices": int(values.get("notices", 0)),
            }
            continue
        if line.startswith("NOTPARSE\t"):
            head = line.split("\t")[1]
            numbers = re.findall(r"\d+", head)
            measurements["not_parsed_reasons"]["files"] = int(numbers[0])
            measurements["not_parsed_reasons"]["withheld"] = int(numbers[1])
            continue
        reason_line = re.match(r"^\s+(\d+)x\s+(.*)$", line)
        if reason_line:
            reason = reason_line.group(2).strip()
            reasons.setdefault(reason, {"count": 0, "examples": []})
            reasons[reason]["count"] = int(reason_line.group(1))
            continue
        if line.strip().startswith("e.g. ") and reasons:
            reason = list(reasons)[-1]
            reasons[reason]["examples"].append(line.strip()[5:].strip())
            continue
        if line.startswith("SUMMARY\t"):
            parts = line.split("\t")
            values = {}
            for part in parts[1:]:
                if "=" in part:
                    key, _, value = part.partition("=")
                    values[key] = value
            for key in (
                "files",
                "parsed",
                "actionable",
                "notices",
                "unreliable",
                "withheld",
                "unchecked",
                "total",
            ):
                measurements[key] = int(values.get(key, 0))
            continue
    # the files the analyzer did not finish are the ones of the tree that it
    # did not read to the end
    unfinished = []
    for path in files_of_the_tree():
        if path not in finished:
            unfinished.append(path)
    measurements["files_not_finished"] = unfinished
    shapes = {}
    for reason, entry in reasons.items():
        shapes[reason] = entry["count"]
    measurements["not_parsed_reasons"].update(shapes)
    return measurements


def printed_findings(report: str) -> list[tuple[str, str, str]]:
    """The findings the report prints, one per line, with their place."""
    findings = []
    current_file = ""
    for line in report.splitlines():
        if not line.strip():
            continue
        parts = line.split("\t")
        if parts[0] in ("CLEAN", "FOUND", "PARTIAL") and len(parts) >= 2:
            current_file = parts[-1].strip()
            continue
        found = FINDING_LINE.match(line)
        if found:
            findings.append((current_file, found.group(3), found.group(4)))
    return findings


def delta_of_the_printed_findings(before: str, after: str) -> dict:
    """The findings of the report of the tree before that the one after lacks,
    and the findings of the report of the tree after that the one before lacks.

    A finding is named by its file, its kind and its message, so that a change
    of the line numbers of a file does not make a finding look new.
    """
    old = {}
    for place, kind, message in printed_findings(before):
        old[(place, kind, message)] = old.get((place, kind, message), 0) + 1
    new = {}
    for place, kind, message in printed_findings(after):
        new[(place, kind, message)] = new.get((place, kind, message), 0) + 1
    gone = 0
    for key, count in old.items():
        gone += max(0, count - new.get(key, 0))
    grew = 0
    families: dict[str, int] = {}
    for key, count in new.items():
        extra = max(0, count - old.get(key, 0))
        grew += extra
        if extra:
            family = ""
            tags = FAMILY.search(key[2])
            if tags:
                for part in tags.group(1).split(","):
                    if part.strip().startswith("MSA-"):
                        family = part.strip()
            name = family or "no family"
            families[name] = families.get(name, 0) + extra
    return {
        "gone": gone,
        "new": grew,
        "new_by_family": families,
        "printed_before": len(printed_findings(before)),
        "printed_after": len(printed_findings(after)),
    }


def run_the_analyzer() -> str:
    """Run the analyzer on the tree and return its report."""
    result = subprocess.run(
        ["moonx", TOOL + "@latest", "."],
        cwd=str(ROOT),
        capture_output=True,
        encoding="utf-8",
        errors="replace",
        timeout=3600,
    )
    return (result.stdout or "") + (result.stderr or "")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--scan",
        help="the report of a scan that was taken before, instead of a new one",
    )
    parser.add_argument(
        "--version",
        help="the version of the tree the scan was taken of",
    )
    parser.add_argument(
        "--scan-before",
        help="the report of the scan of the tree before, to measure the "
        "difference between the two reports",
    )
    parser.add_argument(
        "--version-before",
        help="the version of the tree the scan before was taken of",
    )
    arguments = parser.parse_args()
    if arguments.scan:
        with io.open(arguments.scan, "r", encoding="utf-8", errors="replace") as fh:
            report = fh.read()
        version = arguments.version or version_of_the_tree()
    else:
        report = run_the_analyzer()
        version = version_of_the_tree()
    measurements = parse(report)
    measurements["tree_version"] = version
    if arguments.scan_before:
        with io.open(
            arguments.scan_before, "r", encoding="utf-8", errors="replace"
        ) as fh:
            before = fh.read()
        measurements["printed_findings_delta"] = delta_of_the_printed_findings(
            before, report
        )
        measurements["printed_findings_delta"]["version_before"] = (
            arguments.version_before or ""
        )
    artefact = {"tool": TOOL, "command": COMMAND, "scans": {}}
    if ARTEFACT.exists():
        with io.open(ARTEFACT, "r", encoding="utf-8") as handle:
            artefact = json.load(handle)
    artefact.setdefault("scans", {})[version] = measurements
    with io.open(ARTEFACT, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(artefact, indent=1, sort_keys=True))
        handle.write("\n")
    print("the scan of the release %s:" % version)
    for key in (
        "files",
        "parsed",
        "actionable",
        "notices",
        "unreliable",
        "withheld",
        "unchecked",
        "total",
    ):
        print("  %s = %s" % (key, measurements[key]))
    print("wrote %s" % ARTEFACT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
