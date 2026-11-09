"""Map the test files of the port to the test files of the upstream.

The header of every test file of the port names the upstream file it mirrors,
so the two lists can be compared.  The files of the port are the ones whose
name ends with `_test.mbt`, in every package of the module.

A name of the header is read in three ways:

- a path, `tests/causal_identifiers/test_id_identifier.py`;
- a bare file name, `test_id_identifier.py`, which is matched against the file
  name of every upstream test file;
- a glob, `tests/causal_estimators/test_*_estimator.py`, which is matched
  against the path of every upstream test file.

The file name of the upstream is not unique, so a bare name is only counted
when it matches one file of the upstream; the script reports the names that
match more than one.

Usage:

    python _verify/upstream_test_coverage.py
"""

from __future__ import annotations

import fnmatch
import os
import re
from collections import defaultdict
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
by_name: dict[str, list[str]] = defaultdict(list)
for path in upstream:
    by_name[path.rsplit("/", 1)[-1]].append(path)

covered: set[str] = set()
ambiguous: set[str] = set()
mentioned: dict[str, list[str]] = {}
# The files of the port are the ones that hold a test block: the files whose
# name ends with `_test.mbt` and the files of the `tests` package, whose name
# does not follow that pattern.
port_files = [p for p in sorted(PORT.rglob("*.mbt")) if "test \"" in p.read_text(encoding="utf-8")]
for path in port_files:
    head = path.read_text(encoding="utf-8")[:4000]
    names = sorted(set(re.findall(r"tests/[-A-Za-z0-9_/\.\*]+\.py", head)))
    names += sorted(set(re.findall(r"`(test_[A-Za-z0-9_]+\.py)`", head)))
    mentioned[str(path.relative_to(PORT)).replace("\\", "/")] = names
    for name in names:
        if "*" in name:
            pattern = name.split("tests/")[-1]
            for candidate in upstream:
                if fnmatch.fnmatch(candidate, pattern) or fnmatch.fnmatch(
                    candidate.rsplit("/", 1)[-1], pattern
                ):
                    covered.add(candidate)
        elif "/" in name:
            for candidate in upstream:
                if candidate.endswith(name.split("tests/")[-1]):
                    covered.add(candidate)
        else:
            matches = by_name.get(name, [])
            if len(matches) == 1:
                covered.add(matches[0])
            elif len(matches) > 1:
                ambiguous.add(name)

print(f"the upstream holds {len(upstream)} test files")
print(f"the port holds {len(mentioned)} test files")
print(f"the port names {len(covered)} of them")
print()
if ambiguous:
    print("--- the names the port uses that match more than one upstream file")
    for name in sorted(ambiguous):
        print("   ", name)
    print()
print("--- the upstream files the port does not name")
for name in upstream:
    if name not in covered:
        print("   ", name)
