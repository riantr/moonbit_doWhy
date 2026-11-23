"""The coefficients of the quantile function are read inside their own bounds.

The helper of the quantile function of the normal distribution reads the four
coefficient arrays of Acklam's inverse normal CDF.  The dynamic analyzer of
the registry cannot know how long an array that is an argument of a function
is, so it reported a finding of the family `INDEX-OOB` for every index of the
coefficients while they were the arguments of the helper.  The coefficients are
in the function that reads them now, and the check below measures their length
and every index that is read of them, so that the verdict that the findings
were not defects of the port is a measurement and not a claim.

    python _verify/check_quantile_coefficients.py
    python _verify/check_quantile_coefficients.py --falsify
"""

from __future__ import annotations

import argparse
import io
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
SOURCE = ROOT / "src" / "utils" / "stats.mbt"
ARTEFACT = HERE / "quantile_coefficients.json"

# the four coefficient arrays of Acklam's inverse normal CDF
COEFFICIENTS = ("a", "b", "c", "d")

# the literal of a coefficient array
LITERAL = re.compile(r"^\s*let ([abcd]) = \[$")

# an index that is read of a coefficient array
ACCESS = re.compile(r"\b([abcd])\[(\d+)\]")


def helper_of(lines: list[str]) -> tuple[int, int]:
    """The lines of the helper of the quantile function."""
    start = 0
    for number, line in enumerate(lines):
        if line.startswith("fn normal_ppf_acklam("):
            start = number
            break
    end = len(lines)
    for number in range(start, len(lines)):
        if lines[number] == "}":
            end = number
            break
    return start, end


def measure() -> dict:
    """Measure the length of the coefficients and the indices read of them."""
    lines = io.open(SOURCE, "r", encoding="utf-8", newline="").read().split("\n")
    start, end = helper_of(lines)
    lengths: dict[str, int] = {}
    index = start
    while index < end:
        found = LITERAL.match(lines[index])
        if not found:
            index += 1
            continue
        name = found.group(1)
        # the rows of the literal are the lines until the one that closes it
        rows = 0
        inside = False
        while index < end:
            line = lines[index]
            if not inside:
                inside = True
                index += 1
                continue
            if line.strip().startswith("]"):
                break
            rows += line.count(",")
            index += 1
        lengths[name] = rows
        index += 1
    accesses = []
    for number in range(start, end):
        line = lines[number]
        for found in ACCESS.finditer(line):
            accesses.append(
                {"array": found.group(1), "index": int(found.group(2)), "line": number + 1}
            )
    out_of_bounds = [
        access
        for access in accesses
        if access["array"] in lengths and access["index"] >= lengths[access["array"]]
    ]
    return {
        "lengths": lengths,
        "accesses": len(accesses),
        "out_of_bounds": len(out_of_bounds),
        "out_of_bounds_places": out_of_bounds,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--falsify",
        action="store_true",
        help="require a wrong number of accesses, to show that the check goes red",
    )
    arguments = parser.parse_args()
    measured = measure()

    with io.open(ARTEFACT, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(measured, indent=1, sort_keys=True))
        handle.write("\n")

    checked = dict(measured)
    if arguments.falsify:
        checked["out_of_bounds"] = measured["accesses"] + 1

    print("the coefficients of the quantile function hold:")
    for name in COEFFICIENTS:
        print("  %s: %d row(s)" % (name, measured["lengths"].get(name, 0)))
    print("the helper reads %d index/indices of them" % measured["accesses"])
    print("%d of them are out of bounds" % measured["out_of_bounds"])
    print("wrote %s" % ARTEFACT)

    if checked["out_of_bounds"] != 0:
        print(
            "FAIL: %d access(es) of the coefficients are out of bounds: %s"
            % (
                checked["out_of_bounds"],
                ", ".join(
                    "%s[%d] on the line %d"
                    % (p["array"], p["index"], p["line"])
                    for p in measured["out_of_bounds_places"]
                ),
            )
        )
        return 1
    print("every index of the coefficients is in bounds")
    return 0


if __name__ == "__main__":
    sys.exit(main())
