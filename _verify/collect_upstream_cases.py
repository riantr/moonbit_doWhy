"""Collect the test cases pytest collects in the upstream test suite.

The number of the test functions of the upstream is not the number of its test
cases: pytest collects one case for every parameter of a parametrized test.
The file `tests/causal_identifiers/test_backdoor_identifier.py` holds five test
functions and pytest collects ninety five cases out of them, because its
fixture is parametrized with nineteen graphs.

The script writes the cases pytest collects, per file, into the file
`_verify/upstream_collected_cases.json`. The script
`_verify/upstream_test_coverage.py` reads that file, so that the number of the
test cases of the upstream it compares with the port is the number pytest
really collects.

The script collects the cases twice: once every case, and once the cases the
task `test` of the upstream runs, which leaves out the cases marked `advanced`
and the ones marked `econml`. The task `test_advanced` of the nightly run of
the upstream keeps them, so the file holds both numbers.

Usage:

    python _verify/collect_upstream_cases.py

The script needs the test suite of the upstream and the modules its test files
import: `flaky`, `cvxpy` and `nbformat` are three of them. A file whose
import fails is reported and is not part of the result.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(
    os.environ.get(
        "DOWHY_UPSTREAM_ROOT",
        r"D:\src\MiniMax\git\dowhy\dowhy-0.14",
    )
)
OUT = Path(
    os.environ.get(
        "MOONBIT_DOWHY_ROOT",
        r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy",
    )
) / "_verify" / "upstream_collected_cases.json"


def collect(env: dict, markers: str = "") -> dict[str, list[str]]:
    """The cases pytest collects, per file, with and without the markers."""
    command = [
        sys.executable,
        "-m",
        "pytest",
        "tests",
        "--collect-only",
        "-q",
        "-p",
        "no:randomly",
    ]
    if markers:
        command += ["-m", markers]
    proc = subprocess.run(
        command,
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    cases: dict[str, list[str]] = defaultdict(list)
    for line in proc.stdout.splitlines():
        line = line.strip()
        if "::" not in line:
            continue
        path = line.split("::", 1)[0]
        if not path.startswith("tests"):
            continue
        cases[path.replace("\\", "/")].append(line)
    return cases


def main() -> int:
    env = dict(os.environ)
    env["PYTHONPATH"] = str(ROOT)

    cases = collect(env)
    if not cases:
        print("pytest collected no case")
        return 1

    # The task `test` of the upstream, which its own gate runs, leaves out the
    # cases marked `advanced` and the ones marked `econml`; the task
    # `test_advanced` of the nightly run keeps them.
    default_cases = collect(env, markers="not advanced and not econml")
    default_names = {name for names in default_cases.values() for name in names}
    deselected = sorted(
        name for names in cases.values() for name in names if name not in default_names
    )

    data = {
        "upstream": str(ROOT),
        "total": sum(len(names) for names in cases.values()),
        "files": len(cases),
        "default_total": sum(len(names) for names in default_cases.values()),
        "default_files": len(default_cases),
        "deselected": deselected,
        "cases": {path: sorted(names) for path, names in sorted(cases.items())},
    }
    OUT.write_text(
        json.dumps(data, ensure_ascii=False, indent=1, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="",
    )
    print("collected", data["total"], "cases in", data["files"], "files")
    print(
        "the default task of the upstream runs",
        data["default_total"],
        "of them and leaves",
        len(deselected),
        "out",
    )
    print("wrote", OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
