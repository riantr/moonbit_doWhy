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


def main() -> int:
    env = dict(os.environ)
    env["PYTHONPATH"] = str(ROOT)
    proc = subprocess.run(
        [
            sys.executable,
            "-m",
            "pytest",
            "tests",
            "--collect-only",
            "-q",
            "-p",
            "no:randomly",
        ],
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
    if not cases:
        print("pytest collected no case")
        print(proc.stdout[-2000:])
        print(proc.stderr[-2000:])
        return 1
    data = {
        "upstream": str(ROOT),
        "total": sum(len(names) for names in cases.values()),
        "files": len(cases),
        "cases": {path: sorted(names) for path, names in sorted(cases.items())},
    }
    OUT.write_text(
        json.dumps(data, ensure_ascii=False, indent=1, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="",
    )
    print("collected", data["total"], "cases in", data["files"], "files")
    print("wrote", OUT)
    if proc.returncode != 0:
        # A file whose import fails is a collection error: the script reports it
        # and the file is not part of the result.
        print("--- the collection errors of pytest ---")
        print(proc.stdout[-3000:])
    return 0


if __name__ == "__main__":
    sys.exit(main())
