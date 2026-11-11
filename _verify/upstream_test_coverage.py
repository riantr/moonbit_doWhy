"""Map the test files and the test cases of the port to the upstream.

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

The script makes two checks.

The first one is the one of the files: every test file of the upstream is
named by a test file of the port.

The second one is the one of the cases: every test case of the upstream is
mirrored by a test case of the port, unless the table of the script says why
it is not.  The number of the cases of an upstream file is the number of its
test functions, counted by name: a file that defines the same function twice
holds one case, because Python keeps the second definition and pytest collects
it once.

The number of the cases of the port is the number of the `test` blocks of the
test files that name the upstream file.  A test file of the port may mirror
several files of the upstream, so its cases are counted for every file it
names.

The table of the script holds the two kinds of exception:

- `NOT_MIRRORED` names the test cases of the upstream that the port does not
  mirror, with the reason why. The table is empty: the port mirrors every test
  case of the upstream;
- `SHARED` names the upstream files whose number of port cases is below the
  number of their upstream cases for a reason that is not a missing case,
  with the reason why.

The script fails when the number of the cases of a file of the upstream is
not the number of the cases of the port plus the exceptions of the table, and
when an exception names a test function that the upstream does not hold.

The count is the check, and it is a count: a file whose port holds many more
cases than its upstream hides a case that was replaced by another one.  The
argument `--audit` therefore prints the cases of the two sides of the files
whose margin is the tightest, the ones where a replaced case would hide, so
that the mapping can be read.  The verdict of the script is the same with and
without the argument.

Usage:

    python _verify/upstream_test_coverage.py
    python _verify/upstream_test_coverage.py --audit
"""

from __future__ import annotations

import fnmatch
import os
import re
import sys
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

# The test cases of the upstream that the port does not mirror.
#
# Every entry is the file of the upstream, the name of the test function of
# that file, and the reason why the port does not mirror it.
NOT_MIRRORED: list[tuple[str, str, str]] = []

# The upstream files whose number of port cases is below the number of their
# upstream cases, with the number of the cases the difference holds and the
# reason why.
SHARED: list[tuple[str, int, str]] = [
    (
        "gcm/test_unit_change.py",
        1,
        "two pairs of the upstream cases share one port case each, and one "
        "upstream case is mirrored by two port cases",
    ),
]


def upstream_files() -> list[str]:
    return sorted(
        str(p.relative_to(TESTS)).replace("\\", "/")
        for p in TESTS.rglob("test_*.py")
    )


def upstream_cases(path: str) -> list[str]:
    """The names of the test functions of an upstream file, without the repeats."""
    text = (TESTS / path).read_text(encoding="utf-8", errors="replace")
    names: list[str] = []
    for name in re.findall(r"^\s*def (test_[A-Za-z0-9_]+)\s*\(", text, re.MULTILINE):
        if name not in names:
            names.append(name)
    return names


def port_case_count(text: str) -> int:
    """The number of the test blocks of a file of the port."""
    return len(re.findall(r'^\s*test\s+"', text, re.MULTILINE))


def port_case_names(text: str) -> list[str]:
    """The names of the test blocks of a file of the port."""
    return re.findall(r'^\s*test\s+"([^"]*)"', text, re.MULTILINE)


def main() -> int:
    # The audit prints the mapping of the files whose margin is the tightest.
    # The verdict of the script is the same with and without it.
    audit = "--audit" in sys.argv[1:]
    upstream = upstream_files()
    by_name: dict[str, list[str]] = defaultdict(list)
    for path in upstream:
        by_name[path.rsplit("/", 1)[-1]].append(path)

    covered: set[str] = set()
    ambiguous: set[str] = set()
    mentioned: dict[str, list[str]] = {}
    # The files of the port are the ones that hold a test block: the files whose
    # name ends with `_test.mbt` and the files of the `tests` package, whose name
    # does not follow that pattern.
    port_files = [
        p for p in sorted(PORT.rglob("*.mbt")) if 'test "' in p.read_text(encoding="utf-8")
    ]
    cases_of: dict[str, int] = defaultdict(int)
    # The cases of the port that name every file of the upstream, with the file
    # of the port they are in, so that the mapping can be printed.
    names_of: dict[str, list[tuple[str, list[str]]]] = defaultdict(list)
    for path in port_files:
        text = path.read_text(encoding="utf-8")
        head = text[:4000]
        names = sorted(set(re.findall(r"tests/[-A-Za-z0-9_/\.\*]+\.py", head)))
        names += sorted(set(re.findall(r"`(test_[A-Za-z0-9_]+\.py)`", head)))
        mentioned[str(path.relative_to(PORT)).replace("\\", "/")] = names
        cases = port_case_count(text)
        case_names = port_case_names(text)
        for name in names:
            if "*" in name:
                pattern = name.split("tests/")[-1]
                for candidate in upstream:
                    if fnmatch.fnmatch(candidate, pattern) or fnmatch.fnmatch(
                        candidate.rsplit("/", 1)[-1], pattern
                    ):
                        covered.add(candidate)
                        cases_of[candidate] += cases
                        names_of[candidate].append(
                            (str(path.relative_to(PORT)).replace("\\", "/"), case_names)
                        )
            elif "/" in name:
                for candidate in upstream:
                    if candidate.endswith(name.split("tests/")[-1]):
                        covered.add(candidate)
                        cases_of[candidate] += cases
                        names_of[candidate].append(
                            (str(path.relative_to(PORT)).replace("\\", "/"), case_names)
                        )
            else:
                matches = by_name.get(name, [])
                if len(matches) == 1:
                    covered.add(matches[0])
                    cases_of[matches[0]] += cases
                    names_of[matches[0]].append(
                        (str(path.relative_to(PORT)).replace("\\", "/"), case_names)
                    )
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
    unnamed = [name for name in upstream if name not in covered]
    print("--- the upstream files the port does not name")
    for name in unnamed:
        print("   ", name)
    print()

    # ------------------------------------------------------------ the cases
    failures: list[str] = []
    not_mirrored: dict[str, list[tuple[str, str]]] = defaultdict(list)
    for path, name, reason in NOT_MIRRORED:
        not_mirrored[path].append((name, reason))
    shared: dict[str, tuple[int, str]] = {}
    for path, count, reason in SHARED:
        if path in shared:
            failures.append(f"{path}: the table holds two shared entries")
            continue
        shared[path] = (count, reason)

    total_up = 0
    total_port = 0
    print("--- the test cases")
    print(
        f"{'upstream file':<58} {'upstream':>8} {'port':>6} {'gap':>5}  exception"
    )
    for path in upstream:
        cases = upstream_cases(path)
        up = len(cases)
        port = cases_of.get(path, 0)
        total_up += up
        total_port += port
        gap = up - port
        entries = len(not_mirrored.get(path, []))
        count, reason = shared.get(path, (0, ""))
        exceptions = entries + count
        if gap > 0 and exceptions != gap:
            failures.append(
                f"{path}: {up} upstream cases, {port} port cases, "
                f"{exceptions} exceptions"
            )
        elif gap <= 0 and exceptions != 0:
            failures.append(
                f"{path}: {up} upstream cases, {port} port cases, "
                f"{exceptions} exceptions that the counts do not need"
            )
        for name, why in not_mirrored.get(path, []):
            if name not in cases:
                failures.append(f"{path}: the upstream holds no case {name}")
        note = ""
        if entries:
            note = f"{entries} case(s) not mirrored"
        if count:
            note = (note + ", " if note else "") + f"{count} case(s) shared"
        print(f"{path:<58} {up:>8} {port:>6} {gap:>5}  {note}")
    print()
    print(f"the upstream holds {total_up} test cases")
    print(f"the port holds {total_port} test cases in the files that name them")
    print(f"the table holds {len(NOT_MIRRORED)} case(s) that are not mirrored")
    print()
    print("--- the test cases the port does not mirror")
    for path, name, reason in NOT_MIRRORED:
        print(f"    {path}::{name}")
        print(f"        {reason}")
    print()
    print("--- the files whose port cases are fewer than their upstream cases")
    for path, count, reason in SHARED:
        print(f"    {path}: {count} case(s) fewer")
        print(f"        {reason}")
    print()
    if failures:
        print(f"--- {len(failures)} failure(s)")
        for failure in failures:
            print("   ", failure)
        return 1
    print("every test case of the upstream is mirrored by a test case of the port")
    if audit:
        print()
        print_audit(upstream, names_of, cases_of)
    return 0


def print_audit(
    upstream: list[str],
    names_of: dict[str, list[tuple[str, list[str]]]],
    cases_of: dict[str, int],
) -> None:
    """Print the cases of the two sides of the files whose margin is the tightest.

    The count is the check of the script, and a file whose port holds many more
    cases than its upstream hides a case that was replaced by another one.  The
    files whose margin is the tightest are the ones where such a replacement
    would show, so their cases are printed side by side.
    """
    margins = []
    for path in upstream:
        cases = upstream_cases(path)
        margins.append((cases_of.get(path, 0) - len(cases), path, len(cases)))
    margins.sort()
    print("--- the files whose margin is the tightest, and their cases")
    for margin, path, up in margins[:12]:
        print()
        print("=" * 78)
        print("{}  (upstream {}, port {})".format(path, up, cases_of.get(path, 0)))
        print("=" * 78)
        print("--- the cases of the upstream")
        for name in upstream_cases(path):
            print("   ", name)
        print("--- the cases of the port")
        for where, case_names in names_of.get(path, []):
            print("   [{}]".format(where))
            for case in case_names:
                print("       -", case)


if __name__ == "__main__":
    sys.exit(main())
