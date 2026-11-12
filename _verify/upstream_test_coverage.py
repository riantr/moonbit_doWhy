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

The second one is the one of the cases.  The number of the cases of an upstream
file is the number of the cases pytest collects in it, which is **not** the
number of its test functions: a parametrized test collects one case for every
parameter of its fixture.  The file `_verify/upstream_collected_cases.json`
holds the cases pytest collects, and the script
`_verify/collect_upstream_cases.py` writes it.

The number of the cases of the port is the number of the `test` blocks of the
test files that name the upstream file.  A test file of the port may mirror
several files of the upstream, so its cases are counted for every file it
names.

Two tables of the script hold the exceptions.

`NOT_MIRRORED` names the test cases of the upstream that the port does not
mirror, with the reason why.

`SHARED` names the upstream files whose number of port cases is below the
number of their upstream cases for a reason that is not a missing case, with
the reason why.

`LOOPED` names the upstream files whose cases pytest collects out of a
parametrized fixture, and the port that covers those cases with a loop over a
table of cases.  Every entry names the upstream file, the file of the port
that holds the table, the name of the function that builds the table and the
number of the test functions of the upstream that the loops of the port
mirror.  The script counts the rows of the table of the port and the
parameters of the fixture of the upstream, and checks that the two numbers are
the same, so that a fixture of the upstream that grows has to be mirrored by
the table of the port.

The notebooks of the upstream are the cases of the file `tests/test_notebooks.py`,
one case per notebook: the upstream executes every notebook of its
documentation and asserts that no cell of it fails.  A notebook is **mirrored**
when a test case of the port runs its scenario and asserts the conclusion the
notebook demonstrates; the header of the test file of the port names the
notebook it mirrors.  The table `NOTEBOOKS` names the notebooks the port does
not mirror, with the reason why.

The script fails when the number of the cases of a file of the upstream is
not the number of the cases of the port plus the exceptions of the tables, and
when an exception names a test case that the upstream does not hold.

The count is the check, and a count: a file whose port holds many more cases
than its upstream hides a case that was replaced by another one.  The argument
`--audit` therefore prints the cases of the two sides of the files whose margin
is the tightest, the ones where a replaced case would hide, so that the
mapping can be read.  The verdict of the script is the same with and without
the argument.

The script also counts the test blocks the port declares and checks that no file
holds two of them with the same name, and it prints the count, because the test
runner of the toolchain reports how many tests it executed: the two numbers have
to be the same, or a declared case never runs.

Usage:

    python _verify/upstream_test_coverage.py
    python _verify/upstream_test_coverage.py --audit
"""

from __future__ import annotations

import fnmatch
import json
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
HERE = Path(__file__).resolve().parent
COLLECTED = HERE / "upstream_collected_cases.json"

# The file of the upstream whose cases are the notebooks of its documentation.
NOTEBOOKS_FILE = "test_notebooks.py"

# The test cases of the upstream that the port does not mirror.
#
# Every entry is the file of the upstream, the name of the test case of that
# file, and the reason why the port does not mirror it.
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

# The upstream files whose cases pytest collects out of a parametrized fixture,
# and the port that covers those cases with a loop over a table of cases.
#
# Every entry holds the upstream file, the file of the port that holds the
# table of the cases, the name of the function that builds the table and the
# number of the test functions of the upstream that the loops of the port
# mirror.  The script checks that the table of the port holds as many rows as
# the fixture of the upstream holds parameters.
LOOPED: list[tuple[str, str, str, int]] = [
    (
        "causal_identifiers/test_backdoor_identifier.py",
        "identifiers/test_graphs.mbt",
        "backdoor_cases",
        5,
    ),
]

# The notebooks of the upstream the port does not mirror, with the reason why.
#
# The notebooks the port mirrors are the ones the header of a test file of the
# port names.
NOTEBOOKS: list[tuple[str, str]] = [
    (
        "counterfactual_fairness_dowhy.ipynb",
        "the notebook estimates the counterfactual fairness of a policy, and the "
        "port does not port `dowhy.causal_prediction`, which depends on "
        "PyTorch",
    ),
    (
        "dowhy-conditional-treatment-effects.ipynb",
        "the notebook estimates the conditional treatment effects with the "
        "estimators of `econml`, which this dependency-free port does not wrap",
    ),
    (
        "dowhy_doubly_robust_estimator.ipynb",        "the notebook fits the propensity score of the doubly robust estimator "
        "with a decision tree of scikit-learn, and the estimators of the port "
        "fit it with the logistic regression of the upstream",
    ),
    (
        "dowhy_example_effect_of_memberrewards_program.ipynb",
        "the notebook groups a table of one row per user and per month, and the "
        "port has no group by",
    ),
    (
        "dowhy_functional_api.ipynb",
        "the notebook estimates with the estimators of `econml`, which this "
        "dependency-free port does not wrap",
    ),
    (
        "dowhy_generalized_covariate_adjustment_estimation_example.ipynb",
        "the notebook draws its data set with `linear_dataset_from_graph` and "
        "two binary treatments, and the estimators of the port estimate one "
        "treatment at a time",
    ),
    (
        "dowhy_ihdp_data_example.ipynb",
        "the notebook downloads the data set of the IHDP experiment from the "
        "network, and the port carries no copy of it",
    ),
    (
        "dowhy_lalonde_example.ipynb",
        "the notebook downloads the Lalonde data set from the network, and the "
        "port carries no copy of it",
    ),
    (
        "dowhy_multiple_treatments.ipynb",
        "the notebook estimates the effect of two treatments at once, with a "
        "tuple of the treatment values, and the estimators of the port estimate "
        "one treatment at a time",
    ),
    (
        "dowhy_optimize_backdoor_example.ipynb",
        "the notebook draws a random graph with `networkx` and identifies it "
        "with the flag `optimize_backdoor` of the upstream, which the port does "
        "not have",
    ),
    (
        "dowhy_ranking_methods.ipynb",
        "the notebook ranks the units with the partial identification of the "
        "upstream, which the port does not port, and it fits a model with "
        "`xgboost`",
    ),
    (
        "dowhy_refutation_testing.ipynb",
        "the notebook refutes an estimate on the Lalonde data set and on the "
        "IHDP experiment, both of which the port carries no copy of",
    ),
    (
        "dowhy_refuter_assess_overlap.ipynb",
        "the notebook assesses the overlap on the Lalonde and on the PSID data "
        "sets, both of which the port carries no copy of",
    ),
    (
        "dowhy_refuter_notebook.ipynb",
        "the notebook refutes an estimate of `econml`, which this "
        "dependency-free port does not wrap",
    ),
    (
        "dowhy_twins_example.ipynb",
        "the notebook downloads the data set of the twins experiment from the "
        "network, and the port carries no copy of it",
    ),
    (
        "DoWhy-The Causal Story Behind Hotel Booking Cancellations.ipynb",
        "the notebook downloads the data set of the hotel bookings from the "
        "network and draws its graph with `pygraphviz`, which the port does "
        "not have",
    ),
    (
        "gcm_401k_analysis.ipynb",
        "the notebook reads the data set of the 401k pension, and the port "
        "carries no copy of it",
    ),
    (
        "gcm_counterfactual_medical_dry_eyes.ipynb",
        "the notebook reads the data set of the patients of the dry eyes "
        "study, and the port carries no copy of it",
    ),
    (
        "gcm_cps2015_dist_change_robust.ipynb",
        "the notebook reads the data set of the CPS 2015 survey, and the port "
        "carries no copy of it",
    ),
    (
        "gcm_icc.ipynb",
        "the notebook reads the data set of the river and the data set of the "
        "cars, and the port carries no copy of them",
    ),
    (
        "gcm_online_shop.ipynb",
        "the notebook reads the three data sets of the online shop, and the "
        "port carries no copy of them",
    ),
    (
        "gcm_rca_microservice_architecture.ipynb",
        "the notebook reads the three data sets of the microservice "
        "architecture, and the port carries no copy of them",
    ),
    (
        "gcm_supply_chain_dist_change.ipynb",
        "the notebook reads the data set of the supply chain, and the port "
        "carries no copy of it",
    ),
    (
        "lalonde_pandas_api.ipynb",
        "the notebook reads the Lalonde data set, and the port carries no copy "
        "of it",
    ),
    (
        "sensitivity_analysis_nonparametric_estimators.ipynb",
        "the notebook estimates with the estimators of `econml` and draws its "
        "data set with `partially_linear_dataset`, which the port does not port",
    ),
    (
        "tutorial-causalinference-machinelearning-using-dowhy-econml.ipynb",
        "the notebook estimates with the estimators of `econml`, which this "
        "dependency-free port does not wrap",
    ),
]

# The notebooks of the upstream that its own test file ignores, with the reason
# why the upstream ignores them.
#
# The upstream does not collect a case for these notebooks, so they are not
# part of the count of the cases.  The script checks that the tree of the
# upstream holds them and that pytest collects no case for them.
IGNORED_BY_UPSTREAM: list[tuple[str, str]] = [
    (
        "dowhy_causal_discovery_example.ipynb",
        "the upstream ignores it: it is tested as a part of the generation of "
        "the documentation",
    ),
]


def upstream_files() -> list[str]:
    return sorted(
        str(p.relative_to(TESTS)).replace("\\", "/")
        for p in TESTS.rglob("test_*.py")
    )


def collected_cases() -> dict[str, list[str]]:
    """The test cases pytest collects, per file of the upstream."""
    if not COLLECTED.exists():
        raise SystemExit(
            "the file {} is missing: run `python _verify/collect_upstream_cases.py`"
            .format(COLLECTED)
        )
    data = json.loads(COLLECTED.read_text(encoding="utf-8"))
    return {
        path[len("tests/"):]: names
        for path, names in data["cases"].items()
        if path.startswith("tests/")
    }


def upstream_cases(path: str, collected: dict[str, list[str]]) -> list[str]:
    """The test cases pytest collects in an upstream file."""
    return collected.get(path, [])


def port_case_count(text: str) -> int:
    """The number of the test blocks of a file of the port."""
    return len(re.findall(r'^\s*test\s+"', text, re.MULTILINE))


def port_case_names(text: str) -> list[str]:
    """The names of the test blocks of a file of the port."""
    return re.findall(r'^\s*test\s+"([^"]*)"', text, re.MULTILINE)


def split_top_level(text: str, opener: str, closer: str) -> list[str]:
    """The elements of a bracketed list, the commas of the nested ones ignored."""
    start = text.index(opener)
    depth = 0
    elements: list[str] = []
    current: list[str] = []
    in_string: str | None = None
    index = start
    while index < len(text):
        char = text[index]
        if in_string is not None:
            current.append(char)
            if char == in_string:
                in_string = None
            index += 1
            continue
        if char in "\"'":
            in_string = char
            current.append(char)
            index += 1
            continue
        if char in "([{":
            depth += 1
            if depth == 1:
                index += 1
                continue
            current.append(char)
            index += 1
            continue
        if char in ")]}":
            depth -= 1
            if depth == 0:
                elements.append("".join(current))
                return elements
            current.append(char)
            index += 1
            continue
        if char == "," and depth == 1:
            elements.append("".join(current))
            current = []
            index += 1
            continue
        current.append(char)
        index += 1
    return elements


def port_table_rows(port_file: str, function: str) -> int:
    """The number of the rows of the table of the port."""
    path = PORT / port_file
    if not path.exists():
        return -1
    text = path.read_text(encoding="utf-8")
    marker = "pub fn " + function + "("
    if marker not in text:
        return -1
    body = text[text.index(marker):]
    # The body of the function starts at its brace: the square brackets of the
    # type of the return value come before it.
    brace = body.index("{")
    start = body.index("[", brace)
    elements = split_top_level(body[start:], "[", "]")
    return len([element for element in elements if element.strip()])


def upstream_fixture_params(fixture: str) -> int:
    """The number of the parameters of a fixture of the upstream."""
    path = TESTS / "causal_identifiers" / "example_graphs.py"
    if not path.exists():
        return -1
    text = path.read_text(encoding="utf-8", errors="replace")
    marker = fixture + " = {"
    if marker not in text:
        return -1
    body = text[text.index(marker) + len(fixture) + 2:]
    elements = split_top_level(body, "{", "}")
    return len([element for element in elements if element.strip()])


def notebooks_of(text: str) -> list[str]:
    """The names of the notebooks the header of a file of the port names."""
    return sorted(set(re.findall(r"`([A-Za-z0-9_ .\-]+\.ipynb)`", text[:4000])))


def main() -> int:
    # The audit prints the mapping of the files whose margin is the tightest.
    # The verdict of the script is the same with and without it.
    audit = "--audit" in sys.argv[1:]
    upstream = upstream_files()
    collected = collected_cases()
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
    # The number of the test blocks the port declares, and the names they carry.
    declared = 0
    duplicates: list[str] = []
    for path in port_files:
        text = path.read_text(encoding="utf-8")
        names = port_case_names(text)
        declared += len(names)
        seen: set[str] = set()
        for name in names:
            if name in seen:
                duplicates.append(
                    '{}: the case "{}" is declared twice'.format(
                        str(path.relative_to(PORT)).replace("\\", "/"), name
                    )
                )
            seen.add(name)
    cases_of: dict[str, int] = defaultdict(int)
    # The cases of the port that name every file of the upstream, with the file
    # of the port they are in, so that the mapping can be printed.
    names_of: dict[str, list[tuple[str, list[str]]]] = defaultdict(list)
    # The notebooks the port mirrors, with the files of the port that mirror them.
    notebooks_of_port: dict[str, list[str]] = defaultdict(list)
    for path in port_files:
        text = path.read_text(encoding="utf-8")
        head = text[:4000]
        names = sorted(set(re.findall(r"tests/[-A-Za-z0-9_/\.\*]+\.py", head)))
        names += sorted(set(re.findall(r"`(test_[A-Za-z0-9_]+\.py)`", head)))
        mentioned[str(path.relative_to(PORT)).replace("\\", "/")] = names
        cases = port_case_count(text)
        case_names = port_case_names(text)
        where = str(path.relative_to(PORT)).replace("\\", "/")
        for notebook in notebooks_of(text):
            notebooks_of_port[notebook].append(where)
        for name in names:
            if "*" in name:
                pattern = name.split("tests/")[-1]
                for candidate in upstream:
                    if fnmatch.fnmatch(candidate, pattern) or fnmatch.fnmatch(
                        candidate.rsplit("/", 1)[-1], pattern
                    ):
                        covered.add(candidate)
                        cases_of[candidate] += cases
                        names_of[candidate].append((where, case_names))
            elif "/" in name:
                for candidate in upstream:
                    if candidate.endswith(name.split("tests/")[-1]):
                        covered.add(candidate)
                        cases_of[candidate] += cases
                        names_of[candidate].append((where, case_names))
            else:
                matches = by_name.get(name, [])
                if len(matches) == 1:
                    covered.add(matches[0])
                    cases_of[matches[0]] += cases
                    names_of[matches[0]].append((where, case_names))
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
    failures: list[str] = list(duplicates)
    not_mirrored: dict[str, list[tuple[str, str]]] = defaultdict(list)
    for path, name, reason in NOT_MIRRORED:
        not_mirrored[path].append((name, reason))
    shared: dict[str, tuple[int, str]] = {}
    for path, count, reason in SHARED:
        if path in shared:
            failures.append(f"{path}: the table holds two shared entries")
            continue
        shared[path] = (count, reason)
    looped: dict[str, tuple[int, str, int]] = {}
    for path, port_file, function, assertions in LOOPED:
        if path in looped:
            failures.append(f"{path}: the table holds two looped entries")
            continue
        rows = port_table_rows(port_file, function)
        params = upstream_fixture_params(function)
        if rows < 0:
            failures.append(
                f"{path}: the port holds no table {function} in {port_file}"
            )
            continue
        if params >= 0 and rows != params:
            failures.append(
                f"{path}: the table {function} of the port holds {rows} rows and "
                f"the fixture of the upstream holds {params} parameters"
            )
        looped[path] = (rows * assertions, port_file + ":" + function, assertions)

    total_up = 0
    total_port = 0
    print("--- the test cases")
    print(
        f"{'upstream file':<58} {'upstream':>8} {'port':>6} {'gap':>5}  exception"
    )
    for path in upstream:
        cases = upstream_cases(path, collected)
        up = len(cases)
        port = cases_of.get(path, 0)
        total_up += up
        total_port += port
        gap = up - port
        entries = len(not_mirrored.get(path, []))
        count, reason = shared.get(path, (0, ""))
        exceptions = entries + count
        note = ""
        if entries:
            note = f"{entries} case(s) not mirrored"
        if count:
            note = (note + ", " if note else "") + f"{count} case(s) shared"
        if path in looped:
            covered_by_loop, where, assertions = looped[path]
            port += covered_by_loop
            gap = up - port
            note = (note + ", " if note else "") + f"{covered_by_loop} case(s) by a loop"
        elif path == NOTEBOOKS_FILE:
            # The cases of the notebooks are counted by the notebook table below.
            pass
        elif gap > 0 and exceptions != gap:
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
        print(f"{path:<58} {up:>8} {port:>6} {gap:>5}  {note}")
    print()
    print(f"the upstream holds {total_up} test cases")
    print(f"the port holds {total_port} test cases in the files that name them")
    print(f"the table holds {len(NOT_MIRRORED)} case(s) that are not mirrored")
    print(f"the port declares {declared} test blocks; the runner has to report the same number")
    print()

    # ---------------------------------------------------------- the notebooks
    notebook_cases = collected.get("test_notebooks.py", [])
    upstream_notebooks: list[str] = []
    for case in notebook_cases:
        if "[" in case and case.endswith("]"):
            upstream_notebooks.append(case[case.index("[") + 1:-1])
    upstream_notebooks = sorted(set(upstream_notebooks))
    exceptions = {name: reason for name, reason in NOTEBOOKS}
    for name, reason in NOTEBOOKS:
        if name not in upstream_notebooks:
            failures.append(
                f"test_notebooks.py: the upstream holds no notebook {name}"
            )
    for name, reason in IGNORED_BY_UPSTREAM:
        notebook = (
            ROOT / "docs" / "source" / "example_notebooks" / name
        )
        if not notebook.exists():
            failures.append(
                f"test_notebooks.py: the tree of the upstream holds no notebook {name}"
            )
        if name in upstream_notebooks:
            failures.append(
                f"test_notebooks.py: the upstream collects a case for the "
                f"notebook {name}, which the table holds as ignored"
            )
    mirrored = sorted(set(notebooks_of_port) & set(upstream_notebooks))
    for name in sorted(set(notebooks_of_port) - set(upstream_notebooks)):
        failures.append(f"test_notebooks.py: the upstream holds no notebook {name}")
    for name, where in sorted(notebooks_of_port.items()):
        if name not in upstream_notebooks:
            continue
        for file in where:
            path = PORT / file
            text = path.read_text(encoding="utf-8")
            if port_case_count(text) == 0:
                failures.append(
                    f"test_notebooks.py: the notebook {name} is named by {file}, "
                    "which holds no test case"
                )
    for name in upstream_notebooks:
        if name not in mirrored and name not in exceptions:
            failures.append(
                f"test_notebooks.py: the notebook {name} is neither mirrored by "
                "a test case of the port nor named by the table of the notebooks"
            )
        if name in mirrored and name in exceptions:
            failures.append(
                f"test_notebooks.py: the notebook {name} is mirrored by a test "
                "case of the port and named by the table of the notebooks"
            )
    print("--- the notebooks")
    print(f"the upstream collects {len(upstream_notebooks)} notebooks")
    print(f"the port mirrors {len(mirrored)} of them")
    print(f"the table holds {len(exceptions)} notebook(s) that are not mirrored")
    print()
    for name in mirrored:
        print(f"    mirrored   {name}")
        for file in notebooks_of_port[name]:
            print(f"        {file}")
    print()
    for name, reason in NOTEBOOKS:
        print(f"    not mirrored   {name}")
        print(f"        {reason}")
    print()
    print("--- the notebooks the upstream itself ignores")
    for name, reason in IGNORED_BY_UPSTREAM:
        print(f"    ignored   {name}")
        print(f"        {reason}")
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
        print_audit(upstream, names_of, cases_of, collected)
    return 0


def print_audit(
    upstream: list[str],
    names_of: dict[str, list[tuple[str, list[str]]]],
    cases_of: dict[str, int],
    collected: dict[str, list[str]],
) -> None:
    """Print the cases of the two sides of the files whose margin is the tightest.

    The count is the check of the script, and a file whose port holds many more
    cases than its upstream hides a case that was replaced by another one.  The
    files whose margin is the tightest are the ones where such a replacement
    would show, so their cases are printed side by side.
    """
    margins = []
    for path in upstream:
        cases = upstream_cases(path, collected)
        margins.append((cases_of.get(path, 0) - len(cases), path, len(cases)))
    margins.sort()
    print("--- the files whose margin is the tightest, and their cases")
    for margin, path, up in margins[:12]:
        print()
        print("=" * 78)
        print("{}  (upstream {}, port {})".format(path, up, cases_of.get(path, 0)))
        print("=" * 78)
        print("--- the cases of the upstream")
        for name in upstream_cases(path, collected):
            print("   ", name)
        print("--- the cases of the port")
        for where, case_names in names_of.get(path, []):
            print("   [{}]".format(where))
            for case in case_names:
                print("       -", case)


if __name__ == "__main__":
    sys.exit(main())
