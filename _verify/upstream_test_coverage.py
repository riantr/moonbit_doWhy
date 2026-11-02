"""Map the test files of the port to the test files of the upstream.

The header of every test file of the port names the upstream file it mirrors,
so the two lists can be compared.  The files of the port are the ones whose
name ends with `_test.mbt`, in every package of the module.

The detector only recognises the upstream files that a test file names one by
one.  A test file that names a glob, the way the suite of the estimators names
`tests/causal_estimators/test_*_estimator.py`, is therefore counted as
naming none of them, and the files of the glob show up in the list of the
files the port does not name.

Usage:

    python _verify/upstream_test_coverage.py
"""

from __future__ import annotations

import os
import re
from pathlib import Path

ROOT = Path(
    os.environ.get(
        "DOWHY_UPSTREAM_ROOT",
        r"D:\src\MiniMax\git\dowhy\dowhy-0.14",
    )
)
TESTS = ROOT / "tests"
PORT = Path(
    os.environ.get(
        "MOONBIT_DOWHY_ROOT",
        r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy",
    )
) / "src"

upstream = sorted(
    str(p.relative_to(TESTS)).replace("\\", "/")
    for p in TESTS.rglob("test_*.py")
)

# The upstream file every test file of the port names.
mentioned: dict[str, list[str]] = {}
for path in sorted(PORT.rglob("*_test.mbt")):
    head = path.read_text(encoding="utf-8")[:4000]
    names = sorted(set(re.findall(r"tests/[A-Za-z0-9_/\.]+\.py", head)))
    mentioned[str(path.relative_to(PORT)).replace("\\", "/")] = names

covered: set[str] = set()
for names in mentioned.values():
    for name in names:
        for candidate in upstream:
            if candidate.endswith(name.split("tests/")[-1]):
                covered.add(candidate)

print(f"the upstream holds {len(upstream)} test files")
print(f"the port holds {len(mentioned)} test files")
print()
print("--- the upstream files the port names")
for name in sorted(covered):
    print("   ", name)
print()
print("--- the upstream files the port does not name")
for name in upstream:
    if name not in covered:
        print("   ", name)
