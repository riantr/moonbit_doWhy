"""The tree has to stay readable by the static analyzer of the registry.

The analyzer of the registry reads a tree of MoonBit and it stops at the first
construct its frontend does not know.  Two constructs of this tree stopped it:
a `for` loop whose variable is a tuple pattern, as `for (from, to) in edges`,
and a `for` header that the formatter has split over two lines, as a `for` on
a line of its own.  The release of 0.0.97 rewrote the loops and the headers of
that shape, so that the analyzer reads the whole tree.

The check is on the tree itself and not on the report of the analyzer, because
the analyzer is the package `riantr/moonbit_static_analysis@latest` and its
output drifts.  The script measures the shape of the loops of the tree and
requires that neither of the two constructs is there any more.  It measures the
same two counts in the tree of the release before, so that the number of the
loops that were rewritten is a measurement and not a number that was typed.

    python _verify/check_analyser_readable.py
    python _verify/check_analyser_readable.py --falsify
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
SRC = ROOT / "src"
ARTEFACT = HERE / "analyser_readable.json"

# the release whose tree holds the two constructs, and the commit of it
PREVIOUS_VERSION = "0.0.96"
PREVIOUS_REVISION = "9ae7c88"

# a loop whose variable is a tuple pattern
TUPLE_LOOP = re.compile(r"^\s*for\s*\(([^()]*)\)\s+in\s")

# a header of a loop that the formatter has split over two lines
SPLIT_HEADER = re.compile(r"^\s*for\s*$")

# a loop that takes a tuple and reads it by its index
INDEXED_LOOP = re.compile(r"^\s*for\s+(\w+)\s+in\s")

# the same two counts, as the patterns of `git grep`
TUPLE_LOOP_GREP = r"for\s*\(\s*\w+\s*,\s*\w+[^)]*\)\s+in\s"
SPLIT_HEADER_GREP = r"^\s*for\s*$"


def files_of_the_tree() -> list[Path]:
    """The files of the source of the tree."""
    return sorted(SRC.rglob("*.mbt"))


def measure() -> dict:
    """Measure the shape of the loops of the tree of the repository."""
    tuple_loops = []
    split_headers = []
    indexed_loops = []
    for path in files_of_the_tree():
        rel = path.relative_to(ROOT).as_posix()
        lines = io.open(path, "r", encoding="utf-8", newline="").read().split("\n")
        for number, line in enumerate(lines, start=1):
            if TUPLE_LOOP.search(line):
                tuple_loops.append("%s:%d" % (rel, number))
            if SPLIT_HEADER.search(line):
                split_headers.append("%s:%d" % (rel, number))
            found = INDEXED_LOOP.search(line)
            if not found:
                continue
            # the body of the loop binds the first name of the tuple by its index
            name = found.group(1)
            pattern = re.compile(r"^\s*let\s+\w+\s+=\s+%s\.0\b" % re.escape(name))
            for follow in lines[number:]:
                if pattern.search(follow):
                    indexed_loops.append("%s:%d" % (rel, number))
                    break
                if follow.strip() and not follow.startswith(" "):
                    break
    places = {}
    for place in indexed_loops:
        places[place.rsplit(":", 1)[0]] = True
    return {
        "files": len(files_of_the_tree()),
        "tuple_loops": len(tuple_loops),
        "split_headers": len(split_headers),
        "indexed_loops": len(indexed_loops),
        "files_with_an_indexed_loop": len(places),
        "tuple_loop_places": tuple_loops,
        "split_header_places": split_headers,
        "indexed_loop_places": indexed_loops,
    }


def grep_the_revision(revision: str, pattern: str) -> list[str]:
    """The lines of the tree of the revision that match the pattern."""
    result = subprocess.run(
        ["git", "grep", "-n", "-P", pattern, revision, "--", "src"],
        cwd=str(ROOT),
        capture_output=True,
        encoding="utf-8",
        errors="replace",
    )
    if result.returncode not in (0, 1):
        raise SystemExit(
            "the search of the revision %s failed: %s"
            % (revision, (result.stderr or "").strip())
        )
    lines = [line for line in (result.stdout or "").split("\n") if line.strip()]
    return lines


def measure_the_revision(revision: str) -> dict:
    """Measure the two constructs in the tree of the revision."""
    tuple_loops = grep_the_revision(revision, TUPLE_LOOP_GREP)
    split_headers = grep_the_revision(revision, SPLIT_HEADER_GREP)
    return {
        "revision": revision,
        "tuple_loops": len(tuple_loops),
        "split_headers": len(split_headers),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--falsify",
        action="store_true",
        help="require the two counts to be wrong, to show that the check goes red",
    )
    arguments = parser.parse_args()
    measured = measure()
    before = measure_the_revision(PREVIOUS_REVISION)
    measured["previous_version"] = PREVIOUS_VERSION
    measured["previous_revision"] = PREVIOUS_REVISION
    measured["before"] = before

    with io.open(ARTEFACT, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(measured, indent=1, sort_keys=True))
        handle.write("\n")

    # the falsifier requires the two counts to be wrong, to show that the check
    # goes red; the artefact keeps the measurement of the tree
    checked = dict(measured)
    if arguments.falsify:
        checked["tuple_loops"] = 1
        checked["split_headers"] = 1

    failures = []
    if checked["tuple_loops"] != 0:
        failures.append(
            "%d loop(s) of the tree have a tuple pattern as their variable: %s"
            % (checked["tuple_loops"], ", ".join(checked["tuple_loop_places"][:5]))
        )
    if checked["split_headers"] != 0:
        failures.append(
            "%d header(s) of the tree of a loop are split over two lines: %s"
            % (checked["split_headers"], ", ".join(checked["split_header_places"][:5]))
        )

    print("the tree of %d files holds:" % measured["files"])
    print("  %d loop(s) whose variable is a tuple pattern" % measured["tuple_loops"])
    print("  %d header(s) of a loop that are split over two lines" % measured["split_headers"])
    print("  %d loop(s) that read a tuple by its index" % measured["indexed_loops"])
    print("  in %d file(s)" % measured["files_with_an_indexed_loop"])
    print("the tree of the release %s held:" % PREVIOUS_VERSION)
    print("  %d loop(s) whose variable is a tuple pattern" % before["tuple_loops"])
    print("  %d header(s) of a loop that are split over two lines" % before["split_headers"])
    print("wrote %s" % ARTEFACT)

    if failures:
        for failure in failures:
            print("FAIL: %s" % failure)
        return 1
    print("the static analyzer of the registry reads the whole tree")
    return 0


if __name__ == "__main__":
    sys.exit(main())
