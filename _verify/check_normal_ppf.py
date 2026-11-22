"""The check of the quantile function of the normal distribution.

The port computes the quantile of the normal distribution with Acklam's
inverse normal CDF and one Halley step, and scipy computes it with Wichura's
AS241, so the two agree to the tolerance of the port in the middle of the
distribution and drift apart in the far tails.  The values below are the ones
the port produced before the dead store of `normal_ppf` was removed, and the
check requires the port to produce the very same numbers after the change, so
that the change of the shape of the function does not move a single bit of
its result.

The check also requires the values to be the ones of scipy, so that they are
the numbers of the upstream and not numbers the port made up.

The check writes a probe package into `src/examples/`, runs the port in a
process of its own and removes the probe again: a package outside `src/`
cannot be built, and everything under `src/` is published.

Usage:
    python _verify/check_normal_ppf.py
    python _verify/check_normal_ppf.py --falsify
"""

from __future__ import annotations

import argparse
import io
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
PROBE = ROOT / "src" / "examples" / "normal_ppf_probe"
ARTEFACT = HERE / "normal_ppf.json"

# The arguments and the values the port produced before the change: the three
# regions of Acklam's inverse normal CDF and their borders.
EXPECTED = [
    (0.000001, -4.7534243088229),
    (0.0001, -3.719016485455681),
    (0.001, -3.0902323061678136),
    (0.01, -2.326347874040841),
    (0.02, -2.053748910631823),
    (0.024, -1.9773684281819468),
    (0.0242, -1.9738394633132004),
    (0.02424, -1.9731366119445448),
    (0.02425, -1.972961051311886),
    (0.02426, -1.9727855514678607),
    (0.0243, -1.9720841590292875),
    (0.025, -1.9599639845400563),
    (0.03, -1.8807936081512517),
    (0.05, -1.64485362695147),
    (0.1, -1.2815515655445988),
    (0.2, -0.8416212335729134),
    (0.25, -0.6744897501960812),
    (0.3, -0.5244005127080404),
    (0.4, -0.2533471031357996),
    (0.49, -0.025068908258711033),
    (0.5, 0.0),
    (0.51, 0.025068908258710894),
    (0.6, 0.2533471031357996),
    (0.7, 0.5244005127080402),
    (0.75, 0.6744897501960814),
    (0.8, 0.841621233572914),
    (0.9, 1.2815515655445993),
    (0.95, 1.6448536269514684),
    (0.97, 1.8807936081512506),
    (0.975, 1.9599639845400556),
    (0.9757, 1.9720841590292884),
    (0.97574, 1.9727855514678632),
    (0.97575, 1.972961051311887),
    (0.97576, 1.9731366119445441),
    (0.9758, 1.973839463313201),
    (0.98, 2.0537489106318225),
    (0.99, 2.326347874040841),
    (0.995, 2.575829303548903),
    (0.999, 3.0902323061678225),
    (0.9999, 3.719016485455677),
    (0.999999, 4.753424308827578),
]

# The relative distance the port and scipy are allowed to keep.  MEASURED:
# the largest one is 2.207e-12, at the argument 0.999999.
TOLERANCE = 1e-11

MANIFEST = """import {
  "riantr/moonbit_dowhy/utils",
}

pkgtype(kind: "executable")
"""

PROGRAM = """/// A probe of the quantile function of the normal distribution.
fn main {
  let arguments = __ARGUMENTS__
  for p in arguments {
    let value = @utils.normal_ppf(p)
    println("normal_ppf(" + p.to_string() + ") = " + value.to_string())
  }
}
"""

PATTERN = re.compile(r"normal_ppf\(([0-9.]+)\) = ([-0-9.eE+]+)")


def write_the_probe() -> None:
    """Write the probe package with the arguments of the check."""
    PROBE.mkdir(parents=True, exist_ok=True)
    with io.open(PROBE / "moon.pkg", "w", encoding="utf-8", newline="") as fh:
        fh.write(MANIFEST)
    # A float literal of MoonBit has no exponent, so the arguments are
    # written in plain decimal notation.
    arguments = ", ".join("%.17f" % p for p, _ in EXPECTED)
    program = PROGRAM.replace("__ARGUMENTS__", "[" + arguments + "]")
    with io.open(PROBE / "main.mbt", "w", encoding="utf-8", newline="") as fh:
        fh.write(program)


def run_the_probe() -> dict[float, float]:
    """Run the probe of the port and return the values it printed."""
    write_the_probe()
    result = subprocess.run(
        ["moon", "run", "src/examples/normal_ppf_probe"],
        cwd=str(ROOT),
        capture_output=True,
        encoding="utf-8",
        errors="replace",
        timeout=900,
    )
    if result.returncode != 0:
        raise SystemExit(
            "the probe of the port failed: %s"
            % ((result.stdout or "") + (result.stderr or ""))[-2000:]
        )
    values: dict[float, float] = {}
    for line in (result.stdout or "").splitlines():
        found = PATTERN.search(line)
        if found:
            values[float(found.group(1))] = float(found.group(2))
    return values


def scipy_values() -> dict[float, float]:
    """The values of the upstream, which is scipy."""
    from scipy import stats

    return {p: float(stats.norm.ppf(p)) for p, _ in EXPECTED}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--falsify",
        action="store_true",
        help="require the port to state a wrong number, to prove that the "
        "check fails when the port drifts",
    )
    args = parser.parse_args()
    failures: list[str] = []
    checked = 0
    largest_absolute = 0.0
    largest_relative = 0.0
    try:
        values = run_the_probe()
        upstream = scipy_values()
        for p, expected in EXPECTED:
            if p not in values:
                failures.append("the port did not print the argument %s" % p)
                continue
            checked += 1
            value = values[p]
            if args.falsify:
                if value == expected:
                    failures.append(
                        "the port states the measured number %s for the "
                        "argument %s, and the falsifying run requires a "
                        "wrong one" % (value, p)
                    )
            elif value != expected:
                failures.append(
                    "the port states %s for the argument %s, and the "
                    "measured number is %s" % (value, p, expected)
                )
            absolute = abs(expected - upstream[p])
            relative = absolute / max(abs(upstream[p]), 1.0)
            largest_absolute = max(largest_absolute, absolute)
            largest_relative = max(largest_relative, relative)
            if relative > TOLERANCE:
                failures.append(
                    "the measured number %s for the argument %s is %s away "
                    "from the number of the upstream %s"
                    % (expected, p, relative, upstream[p])
                )
    finally:
        if PROBE.exists():
            shutil.rmtree(PROBE)
    # the measurement of the check, so that the documents state it
    with io.open(ARTEFACT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(
            json.dumps(
                {
                    "arguments": len(EXPECTED),
                    "largest_absolute_distance": largest_absolute,
                    "largest_relative_distance": largest_relative,
                    "tolerance": TOLERANCE,
                },
                indent=1,
                sort_keys=True,
            )
        )
        fh.write("\n")
    print("the check compares %d argument(s) with the upstream" % checked)
    print("the largest relative distance is %.3e" % largest_relative)
    if failures:
        print("--- %d failure(s)" % len(failures))
        for failure in failures:
            print("   ", failure)
        return 1
    print("every argument is the measured number and the number of the upstream")
    return 0


if __name__ == "__main__":
    sys.exit(main())
