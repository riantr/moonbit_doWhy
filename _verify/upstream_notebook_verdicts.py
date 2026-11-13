"""Run the notebooks of the upstream with the runner of the upstream.

The upstream executes every notebook of its documentation with
`jupyter nbconvert --to notebook --execute` and asserts that no cell of it
fails; that is the test file `tests/test_notebooks.py` of the upstream, and it
holds one case per notebook.

This script runs the notebooks the same way and records what happened, so
that the claims of the port about the notebooks are checked against the run of
the upstream and not against a reading of the notebooks. The result is written
to `_verify/upstream_notebook_verdicts.json`.

Every notebook is run twice:

* as it is, which is the verdict of the upstream in this environment, and
* with the repairs of the second section below, which shows whether the
  notebook fails because of the upstream itself or because of the versions of
  the libraries of this machine.

The repairs, all of them of the upstream and not of the port:

1. The root of the package is put on `sys.path` of the kernel, because the
   upstream does it with `PYTHONPATH` and the interpreter of this machine
   runs in the isolated mode of the file `python313._pth`, which ignores
   `PYTHONPATH`.
2. `convert_to_binary` and `stochastically_convert_to_three_level_categorical`
   of `dowhy.datasets` return the one element array of `numpy.random.choice`,
   and `numpy.vectorize` cannot broadcast it under numpy 2. The repairs make
   them return the scalar the upstream means.
3. `dowhy.causal_refuters.add_unobserved_common_cause` indexes the result of
   `numpy.std` as if it were an array, and numpy returns a scalar for it. The
   repair gives the module a `numpy` of its own whose `std` returns the one
   element array the upstream indexes.
4. pandas 3 refuses to cast an object column of zeroes and ones to `bool`,
   which the refuter of the unobserved common cause needs for the column of
   the treatment. The repair casts such a column with `!= 0`.
5. pandas 3 refuses the zeroes and the ones of a boolean column of the
   helper `_include_confounders_effect` of the same refuter as well, and the
   helper puts `1 - treatment` into the column of the treatment. The repair
   turns the boolean columns into objects for the assignment, and the helper
   of the upstream casts them back to `bool` itself.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import nbformat
from nbclient import NotebookClient

UPSTREAM = Path(r"D:\src\MiniMax\git\dowhy\dowhy-0.14")
NOTEBOOKS = UPSTREAM / "docs" / "source" / "example_notebooks"
OUT = Path(__file__).resolve().parent / "upstream_notebook_verdicts.json"

# The seconds one cell of a notebook may run, and the seconds one notebook
# may take. The upstream gives no timeout to its cells, and the notebooks
# that read the standard input would wait for ever.
CELL_TIMEOUT = 240
NOTEBOOK_BUDGET = 900

# The notebook the upstream itself ignores: it is tested as a part of the
# generation of the documentation.
IGNORED = "dowhy_causal_discovery_example.ipynb"

SHIM = """
import sys

if __UPSTREAM__ not in sys.path:
    sys.path.insert(0, __UPSTREAM__)

import numpy as np
import dowhy.datasets as _dowhy_datasets


def _dowhy_scalar(value):
    # `numpy.random.choice` with one draw returns a one element array, and
    # `numpy.vectorize` cannot broadcast it under numpy 2.
    if isinstance(value, np.ndarray) and value.shape == (1,):
        return int(value[0])
    return value


_orig_binary = _dowhy_datasets.convert_to_binary
_orig_three_level = _dowhy_datasets.stochastically_convert_to_three_level_categorical


def _dowhy_convert_to_binary(x, stochastic=True):
    return _dowhy_scalar(_orig_binary(x, stochastic))


def _dowhy_convert_to_three_level(x):
    return _dowhy_scalar(_orig_three_level(x))


if not getattr(_dowhy_datasets, "_dowhy_numpy2_shim", False):
    _dowhy_datasets.convert_to_binary = _dowhy_convert_to_binary
    _dowhy_datasets.stochastically_convert_to_three_level_categorical = _dowhy_convert_to_three_level
    _dowhy_datasets._dowhy_numpy2_shim = True


class _dowhy_numpy_proxy:
    \"\"\"The `numpy` of the module of the refuter, whose `std` is indexed.\"\"\"

    def __init__(self, module):
        self._module = module

    def __getattr__(self, name):
        return getattr(self._module, name)

    def std(self, *args, **kwargs):
        value = self._module.std(*args, **kwargs)
        if np.ndim(value) == 0:
            return np.array([value])
        return value


import dowhy.causal_refuters.add_unobserved_common_cause as _dowhy_refuter

if not getattr(_dowhy_refuter, "_dowhy_numpy2_shim", False):
    _dowhy_refuter.np = _dowhy_numpy_proxy(np)
    _dowhy_refuter._dowhy_numpy2_shim = True


import pandas as pd

_dowhy_astype = pd.DataFrame.astype


def _dowhy_astype_with_object_bool(self, dtype=None, copy=None, **kwargs):
    \"\"\"The `astype` of pandas 3, which refuses the cast of an object column.

    The upstream casts the columns of the treatment to `bool`, and the column
    of the treatment is an object column of zeroes and ones after the refuter
    of the unobserved common cause built its data. pandas 1 and 2 cast it,
    pandas 3 refuses it, and the upstream needs the cast.
    \"\"\"
    try:
        return _dowhy_astype(self, dtype, copy=copy, **kwargs)
    except TypeError:
        if not isinstance(dtype, dict):
            raise
        plain = {
            name: kind
            for name, kind in dtype.items()
            if not (kind == "bool" and name in self.columns and self[name].dtype == object)
        }
        out = _dowhy_astype(self, plain, copy=copy, **kwargs)
        for name, kind in dtype.items():
            if kind == "bool" and name in self.columns and self[name].dtype == object:
                out[name] = (out[name] != 0).astype(bool)
        return out


if not getattr(pd.DataFrame, "_dowhy_numpy2_shim", False):
    pd.DataFrame.astype = _dowhy_astype_with_object_bool
    pd.DataFrame._dowhy_numpy2_shim = True


_dowhy_include_confounders_effect = _dowhy_refuter._include_confounders_effect


def _dowhy_include_confounders_effect_with_objects(data, new_data, *args, **kwargs):
    \"\"\"The helper of the upstream, with the boolean columns as objects.

    The helper puts `1 - treatment` into the column of the treatment, and
    pandas 3 refuses the zeroes and the ones of that column in a boolean
    column. The columns become objects for the assignment, and the helper of
    the upstream casts them back to `bool` itself.
    \"\"\"
    for name in list(new_data.columns):
        if pd.api.types.is_bool_dtype(new_data[name]):
            new_data = new_data.astype({name: "object"})
    return _dowhy_include_confounders_effect(data, new_data, *args, **kwargs)


if not getattr(_dowhy_refuter, "_dowhy_pandas3_shim", False):
    _dowhy_refuter._include_confounders_effect = _dowhy_include_confounders_effect_with_objects
    _dowhy_refuter._dowhy_pandas3_shim = True
"""

# The root of the package of the upstream, in the form of a python literal.
SHIM = SHIM.replace("__UPSTREAM__", repr(str(UPSTREAM)))


def notebook_list() -> list[str]:
    names = sorted(p.name for p in NOTEBOOKS.iterdir() if p.name.endswith(".ipynb"))
    return [n for n in names if n != IGNORED]


def without_colours(line: str) -> str:
    """A line of a traceback without the escape sequences of the colours.

    The escape sequences of the colours hold words that the tool `typos` reads
    as typos, so they are removed before the traceback is written.
    """
    return re.sub(r"\x1b\[[0-9;]*m", "", line)


def _errors_of(nb) -> list[dict]:
    """The error outputs of the cells, the way the upstream collects them."""
    errors = []
    for index, cell in enumerate(nb.cells):
        for output in cell.get("outputs", []):
            if output.get("output_type") == "error":
                errors.append(
                    {
                        "cell": index,
                        "ename": output.get("ename"),
                        "evalue": str(output.get("evalue"))[:400],
                        "traceback": [
                            without_colours(line)
                            for line in output.get("traceback", [])
                            if line.strip()
                        ][-8:],
                    }
                )
    return errors


def run_notebook(name: str, repair: bool) -> dict:
    """Execute one notebook and collect the errors of its cells.

    The kernel runs in the directory of the notebook, the way the runner of
    the upstream runs it.
    """
    path = NOTEBOOKS / name
    with open(path, encoding="utf-8") as handle:
        nb = nbformat.read(handle, nbformat.current_nbformat)
    if repair:
        nb.cells.insert(0, nbformat.v4.new_code_cell(source=SHIM))

    client = NotebookClient(
        nb,
        timeout=CELL_TIMEOUT,
        kernel_name="python3",
        allow_errors=True,
        resources={"metadata": {"path": str(path.parent)}},
    )
    failure = ""
    try:
        client.execute()
    except Exception as exc:  # a kernel that dies, a timeout, a broken notebook
        failure = f"{type(exc).__name__}: {exc}"[:400]
    errors = _errors_of(nb)
    return {"errors": errors, "failure": failure}


def verdict_of(record: dict) -> str:
    if record["failure"] or record["errors"]:
        return "failed"
    return "ok"


def run_one(name: str, repair_only: bool) -> dict:
    """Run one notebook, as it is and, when it fails, with the repairs."""
    started = time.time()
    as_is = run_notebook(name, repair=False)
    as_is_verdict = verdict_of(as_is)

    repaired = None
    repaired_verdict = ""
    if as_is_verdict == "failed" and not repair_only:
        repaired = run_notebook(name, repair=True)
        repaired_verdict = verdict_of(repaired)

    if repair_only:
        verdict = repaired_verdict or as_is_verdict
    elif as_is_verdict == "ok":
        verdict = "ok"
    elif repaired_verdict == "ok":
        verdict = "ok_with_the_repair"
    else:
        verdict = "failed"

    return {
        "notebook": name,
        "verdict": verdict,
        "as_is": {
            "verdict": as_is_verdict,
            "errors": as_is["errors"][:2],
            "failure": as_is["failure"],
        },
        "with_the_repair": (
            None
            if repaired is None
            else {
                "verdict": repaired_verdict,
                "errors": repaired["errors"][:2],
                "failure": repaired["failure"],
            }
        ),
        "elapsed_seconds": round(time.time() - started, 1),
    }


def detail_of(record: dict) -> str:
    """The first error of a notebook, for the report of the run."""
    if record["verdict"] == "ok":
        return ""
    source = record.get("with_the_repair") or record.get("as_is") or {}
    if source.get("errors"):
        first = source["errors"][0]
        return f"{first['ename']}: {first['evalue']}"[:140]
    return (source.get("failure") or "")[:140]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", default="", help="run only the notebooks whose name holds this text")
    parser.add_argument("--out", default=str(OUT), help="the file the result is written to")
    parser.add_argument(
        "--single",
        default="",
        help="run one notebook and write its record to the file of --out",
    )
    parser.add_argument(
        "--repair-only",
        action="store_true",
        help="run the notebooks only with the repairs of the upstream",
    )
    parser.add_argument(
        "--budget",
        type=int,
        default=NOTEBOOK_BUDGET,
        help="the seconds one notebook may take before it is given up",
    )
    args = parser.parse_args()

    if args.single:
        record = run_one(args.single, args.repair_only)
        Path(args.out).write_text(json.dumps(record, indent=1), encoding="utf-8", newline="\n")
        print(f"{record['verdict']} {record['notebook']}")
        return 0

    names = [n for n in notebook_list() if args.only in n]
    print(f"the upstream holds {len(notebook_list())} notebooks it executes; running {len(names)}", flush=True)

    results = []
    for index, name in enumerate(names, start=1):
        started = time.time()
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / "record.json"
            command = [
                sys.executable,
                str(Path(__file__).resolve()),
                "--single",
                name,
                "--out",
                str(target),
            ]
            if args.repair_only:
                command.append("--repair-only")
            try:
                completed = subprocess.run(command, capture_output=True, text=True, timeout=args.budget)
                if target.exists():
                    record = json.loads(target.read_text(encoding="utf-8"))
                else:
                    record = {
                        "notebook": name,
                        "verdict": "failed",
                        "as_is": {"verdict": "failed", "errors": [], "failure": "the runner wrote no record"},
                        "with_the_repair": None,
                    }
            except subprocess.TimeoutExpired:
                record = {
                    "notebook": name,
                    "verdict": "timeout",
                    "as_is": {
                        "verdict": "timeout",
                        "errors": [],
                        "failure": f"the notebook took more than {args.budget} seconds",
                    },
                    "with_the_repair": None,
                }
        record["elapsed_seconds"] = round(time.time() - started, 1)
        results.append(record)
        print(
            f"[{index}/{len(names)}] {record['verdict']:20s} {record['elapsed_seconds']:7.1f}s "
            f"{name} {detail_of(record)}",
            flush=True,
        )

    Path(args.out).write_text(
        json.dumps(
            {
                "upstream": str(UPSTREAM),
                "runner": "nbclient.NotebookClient, the engine of `jupyter nbconvert --execute`",
                "repairs_of_the_upstream": [
                    "the root of the package is put on `sys.path` of the kernel, because the "
                    "interpreter of this machine ignores `PYTHONPATH`",
                    "`convert_to_binary` and `stochastically_convert_to_three_level_categorical` "
                    "of `dowhy.datasets` return a scalar instead of the one element array of "
                    "`numpy.random.choice`, which `numpy.vectorize` cannot broadcast under numpy 2",
                    "the `numpy` of `dowhy.causal_refuters.add_unobserved_common_cause` returns the "
                    "one element array of `numpy.std` that the module indexes",
                    "the `astype` of pandas 3 casts an object column of zeroes and ones to `bool`, "
                    "which the refuter of the unobserved common cause needs",
                    "the helper of the refuter of the unobserved common cause puts the columns of "
                    "the treatment and of the outcome as objects, because pandas 3 refuses the "
                    "zeroes and the ones in a boolean column",
                ],
                "notebooks": [
                    {key: value for key, value in record.items() if key != "elapsed_seconds"}
                    for record in results
                ],
            },
            indent=1,
        ),
        encoding="utf-8",
        newline="\n",
    )
    counts: dict[str, int] = {}
    for record in results:
        counts[record["verdict"]] = counts.get(record["verdict"], 0) + 1
    print("the verdicts: " + ", ".join(f"{k} {v}" for k, v in sorted(counts.items())))
    print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
