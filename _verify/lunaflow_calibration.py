"""The calibration of the dynamic analyzer of the registry.

The analyzer of the registry, the package `riantr/LunaFlow`, reports a finding
of the family `TAINT-INDEX` when a tainted value may reach an array index.  Its
verdict is **not** evidence of a defect of the port: it reports the very same
verdict for a function whose index is guarded and cannot read out of bounds.

The script therefore builds a package of **known shapes** -- one function per
shape of the guard around one array index -- runs the analyzer on it and prints
the verdict of every shape.  The shapes mirror the ones the port uses:

  A  no guard at all
  B  a disjunction guard that aborts
  C  two separate guards that abort
  D  a conjunction guard
  E  a one sided guard
  F  a loop index into a parallel array
  G  an index that is clamped before the access
  H  a disjunction guard with a constant bound
  I  an index that a lookup returns, where a miss gives -1
  J  the same lookup, where the miss is checked

The package is built in a directory outside the repository, and it is removed
again.  The script needs the network and the `moonx` of the toolchain, so it is
not a step of the gate: its numbers are committed in `_verify/lunaflow_qa.json`
and the checker of the published counts asserts the documents against them.

Usage:
    python _verify/lunaflow_calibration.py
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))

# The shapes of the calibration: the name of the function, whether the shape is
# a hole of the port or safe code, and the text of the shape.
SHAPES = {
    "a_unguarded": ("hole", "no guard at all"),
    "b_disjunction_guard": ("safe", "a disjunction guard that aborts"),
    "c_two_guards": ("safe", "two separate guards that abort"),
    "d_conjunction_guard": ("safe", "a conjunction guard"),
    "e_one_sided_guard": ("hole", "a one sided guard"),
    "f_loop_index": ("safe", "a loop index into a parallel array"),
    "g_clamped": ("safe", "an index that is clamped"),
    "h_constant_guard": ("safe", "a disjunction guard with a constant bound"),
    "i_lookup_unchecked": ("hole", "a lookup whose miss gives -1, unchecked"),
    "j_lookup_checked": ("safe", "the same lookup, with the miss checked"),
}

MANIFEST = """import {
}
"""

MODULE = """name = "calib/moonbit_lunaflow_calibration"

version = "0.0.1"

source = "src"
"""

PROGRAM = '''///|
/// A calibration harness for the LunaFlow analyser.
///
/// Every function here has a different *guard shape* around one array index.
/// The analyser reports one `TAINT-INDEX` finding per shape it cannot rule out,
/// so the set of shapes that produce a finding says exactly what the tool can
/// and cannot prove.

///| A: no guard at all.
pub fn a_unguarded(index : Int) -> Int {
  let arr = [10, 20, 30]
  arr[index]
}

///| B: a disjunction guard that aborts.
pub fn b_disjunction_guard(index : Int) -> Int {
  let arr = [10, 20, 30]
  if index < 0 || index >= arr.length() {
    abort("out of range")
  }
  arr[index]
}

///| C: two separate guards that abort.
pub fn c_two_guards(index : Int) -> Int {
  let arr = [10, 20, 30]
  if index < 0 {
    abort("negative")
  }
  if index >= arr.length() {
    abort("too large")
  }
  arr[index]
}

///| D: a conjunction guard.
pub fn d_conjunction_guard(index : Int) -> Int {
  let arr = [10, 20, 30]
  if index >= 0 && index < arr.length() {
    return arr[index]
  }
  abort("out of range")
}

///| E: a one sided guard.
pub fn e_one_sided_guard(index : Int) -> Int {
  let arr = [10, 20, 30]
  if index < arr.length() {
    arr[index]
  } else {
    arr[arr.length() - 1]
  }
}

///| F: a loop index into a parallel array.
pub fn f_loop_index(
  columns : Array[String],
  categories : Array[Array[String]],
) -> Int {
  for i = 0; i < columns.length(); i = i + 1 {
    if columns[i] == "x" {
      return categories[i].length()
    }
  }
  0
}

///| G: an index that is clamped before the access.
pub fn g_clamped(index : Int) -> Int {
  let arr = [10, 20, 30]
  let j = if index < 0 {
    0
  } else if index >= arr.length() {
    arr.length() - 1
  } else {
    index
  }
  arr[j]
}

///| H: a disjunction guard with a constant bound.
pub fn h_constant_guard(index : Int) -> Int {
  let arr = [10, 20, 30]
  if index < 0 || index > 2 {
    abort("bad")
  }
  arr[index]
}

///| I: an index that a lookup returns, where a miss gives -1.
pub fn i_lookup_unchecked(arr : Array[Int], name : String) -> Int {
  let index = lookup(arr, name)
  arr[index]
}

///| J: an index that a lookup returns, where a miss gives -1 and is checked.
pub fn j_lookup_checked(arr : Array[Int], name : String) -> Int {
  let index = lookup(arr, name)
  if index < 0 {
    return 0
  }
  arr[index]
}

///| The lookup that I and J share: a miss gives -1.
fn lookup(arr : Array[Int], name : String) -> Int {
  for i = 0; i < arr.length(); i = i + 1 {
    if arr[i] == name.length() {
      return i
    }
  }
  -1
}
'''


def build(directory: str) -> None:
    """Write the calibration package."""
    package = os.path.join(directory, "src", "calib")
    os.makedirs(package, exist_ok=True)
    with open(os.path.join(directory, "moon.mod"), "w", encoding="utf-8", newline="") as fh:
        fh.write(MODULE)
    with open(os.path.join(package, "moon.pkg"), "w", encoding="utf-8", newline="") as fh:
        fh.write(MANIFEST)
    with open(os.path.join(package, "calib.mbt"), "w", encoding="utf-8", newline="") as fh:
        fh.write(PROGRAM)


def scan(directory: str) -> list[dict]:
    """Run the analyzer on the calibration package and return its findings."""
    out = os.path.join(directory, "report")
    subprocess.run(
        [
            "moonx",
            "riantr/LunaFlow@latest",
            directory,
            "--out",
            out,
            "--metrics",
            "--per-function",
        ],
        cwd=directory,
        capture_output=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    findings = []
    for name in sorted(os.listdir(out)):
        if not name.endswith("_findings.jsonl"):
            continue
        with open(os.path.join(out, name), "r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if line:
                    findings.append(json.loads(line))
    return findings


def main() -> int:
    directory = tempfile.mkdtemp(prefix="lunaflow-calibration-")
    try:
        build(directory)
        findings = scan(directory)
        by_shape: dict[str, list[dict]] = {}
        for finding in findings:
            by_shape.setdefault(finding.get("fn") or "?", []).append(finding)
        print("the shapes of the calibration: %d" % len(SHAPES))
        print("the findings of the analyzer: %d" % len(findings))
        rules = {}
        without = 0
        error_safe = 0
        holes = 0
        error_holes = 0
        for shape, (kind, what) in SHAPES.items():
            rows = by_shape.get(shape, [])
            if not rows:
                without += 1
                print("  %-24s %-46s no finding" % (shape, what))
            for row in rows:
                rule = row.get("rule")
                rules[rule] = rules.get(rule, 0) + 1
                if rule == "TAINT-INDEX":
                    if kind == "safe":
                        error_safe += 1
                    else:
                        error_holes += 1
                print(
                    "  %-24s %-46s %-18s %s"
                    % (shape, what, rule, row.get("evidence"))
                )
            if kind == "hole":
                holes += 1
        print()
        print("CALIBRATION")
        measurement = {
            "shapes": len(SHAPES),
            "findings": len(findings),
            "by_rule": rules,
            "shapes_without_a_finding": without,
            "shapes_reported_as_an_error_that_are_safe": error_safe,
            "shapes_that_are_holes": holes,
            "shapes_reported_as_an_error_that_are_holes": error_holes,
        }
        print(json.dumps(measurement, indent=1))
        return 0
    finally:
        shutil.rmtree(directory, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
