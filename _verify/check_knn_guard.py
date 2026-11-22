"""The check that the nearest neighbour estimators of the port refuse a number
of neighbours below one.

The upstream builds its nearest neighbour estimators with scikit-learn, which
refuses a number of neighbours below one: the script
`_verify/knn_neighbours_reference.py` prints the errors it raises.  The port
refuses it as well, so that a number of neighbours below one does not read
outside the array of the neighbours.

MoonBit cannot catch the abort of a function, so a test of the port cannot
assert the refusal itself: the compiler even warns that the body of a `try`
never raises an error.  The check therefore runs the port in a process of its
own and reads the message of the refusal from its output.

The check writes a probe package into `src/examples/`, runs it once for every
site of the port, and removes the probe again.  The probe lives inside `src/`
because a package outside it cannot be built, and it is removed because
everything under `src/` is published.

Usage:
    python _verify/check_knn_guard.py
    python _verify/check_knn_guard.py --falsify
"""

from __future__ import annotations

import argparse
import io
import os
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
PROBE = ROOT / "src" / "examples" / "knn_guard_probe"

MESSAGE = "The number of neighbours has to be at least one"

MANIFEST = """import {
  "riantr/moonbit_dowhy/api",
  "riantr/moonbit_dowhy/estimators",
  "riantr/moonbit_dowhy/gcm",
  "riantr/moonbit_dowhy/graph",
  "riantr/moonbit_dowhy/identifiers",
  "riantr/moonbit_dowhy/utils",
}

pkgtype(kind: "executable")
"""

# The program of the probe.  The site is a constant of the file, because the
# refusal of the port ends the process and every site needs a run of its own.
PROGRAM = """/// A probe for the refusal of a number of neighbours below one.
///
/// The upstream builds its nearest neighbour estimators with scikit-learn,
/// which refuses a number of neighbours below one.  The probe runs one site
/// of the port and the message of the refusal ends the process.

const SITE : Int = __SITE__

fn main {
  let x = @utils.Matrix::from_rows([[0.0], [1.0], [2.0], [3.0]])
  let y = [0.0, 1.0, 2.0, 3.0]
  let query = @utils.Matrix::from_rows([[0.5]])
  if SITE == 1 {
    let model = @gcm.KnnModel::new(0).fit(x, y)
    println("prediction " + model.predict(query)[0].to_string())
  } else if SITE == 2 {
    let classifier = @gcm.KnnClassifier::new(0).fit(x, ["a", "b", "a", "b"])
    println("prediction " + classifier.predict(query)[0].to_string())
  } else if SITE == 3 {
    let y_matrix = @utils.Matrix::from_rows([[0.5], [1.5], [2.5]])
    let value = @gcm.estimate_kl_divergence_continuous_knn(x, y_matrix, 0, false)
    println("divergence " + value.to_string())
  } else if SITE == 4 {
    let treatment : Array[Double] = []
    let common_cause : Array[Double] = []
    let outcome : Array[Double] = []
    let mut state : Int64 = 42
    for index in 0..<30 {
      state = (1103515245L * state + 12345L) % 2147483648L
      let w = state.to_double() / 2147483648.0 * 4.0 - 2.0
      state = (1103515245L * state + 12345L) % 2147483648L
      let noise = state.to_double() / 2147483648.0 - 0.5
      let t = if index % 3 == 0 { 1.0 } else { 0.0 }
      treatment.push(t)
      common_cause.push(w)
      outcome.push(2.0 * t + 0.5 * w + noise)
    }
    let frame = @api.DataFrame::from_numeric(
      ["v0", "W0", "y"],
      Map([("v0", treatment), ("W0", common_cause), ("y", outcome)]),
    )
    let graph = @graph.build_graph(["v0"], ["y"], ["W0"], [], [], [])
    let estimand = @identifiers.identify_effect_auto(
      graph,
      ["v0"],
      ["y"],
      ["v0", "W0", "y"],
      "nonparametric-ate",
      @identifiers.BACKDOOR_DEFAULT,
    )
    let estimator = @estimators.CausalEstimator::distance_matching(
      estimand,
      num_matches_per_unit=0,
    )
    estimator.fit(frame, [])
    let estimate = estimator.estimate_effect(frame, 1.0, 0.0, "att")
    println("estimate " + estimate.value.to_string())
  }
}
"""

# The sites of the port that build a nearest neighbour estimator.
SITES = {
    1: "KnnModel::new",
    2: "KnnClassifier::new",
    3: "estimate_kl_divergence_continuous_knn",
    4: "CausalEstimator::distance_matching",
}

# The guard of the first site, which the falsification removes.
GUARD = """  if !@utils.has_valid_neighbour_count(k) {
    abort(@utils.NEIGHBOUR_COUNT_ERROR)
  }
"""


def write_the_probe(site: int) -> None:
    """Write the probe package with the site of this run."""
    PROBE.mkdir(parents=True, exist_ok=True)
    (PROBE / "moon.pkg").write_text(MANIFEST, encoding="utf-8", newline="")
    (PROBE / "main.mbt").write_text(
        PROGRAM.replace("__SITE__", str(site)),
        encoding="utf-8",
        newline="",
    )


def run_the_probe(site: int) -> tuple[int, str]:
    """Run the probe of one site and return its exit code and its output."""
    write_the_probe(site)
    result = subprocess.run(
        ["moon", "run", "src/examples/knn_guard_probe"],
        cwd=str(ROOT),
        capture_output=True,
        encoding="utf-8",
        errors="replace",
        timeout=900,
    )
    return result.returncode, (result.stdout or "") + (result.stderr or "")


def sites_of_the_port() -> int:
    """The places of the port that refuse a number of neighbours below one.

    The places are the ones that call the check of the `utils` package, so the
    number is counted from the source of the port and not written here.
    """
    count = 0
    for root, dirs, files in os.walk(ROOT / "src"):
        dirs[:] = [d for d in dirs if d != "_build"]
        for name in sorted(files):
            if not name.endswith(".mbt") or name.endswith("_test.mbt"):
                continue
            path = os.path.join(root, name)
            with io.open(path, "r", encoding="utf-8", errors="replace") as fh:
                count += fh.read().count("has_valid_neighbour_count(")
    # The count holds the definition of the check as well.
    return count - 1


def check(site: int) -> bool:
    """Whether the port refuses the number of neighbours of this site."""
    code, output = run_the_probe(site)
    refused = code != 0 and MESSAGE in output
    print(
        "site %d (%s): exit=%d refused=%s"
        % (site, SITES[site], code, "yes" if refused else "no")
    )
    if not refused:
        print("  the output was: %s" % output.strip()[:600])
    return refused


def falsify() -> int:
    """Remove the guard of the first site and check that the check goes red."""
    path = ROOT / "src" / "gcm" / "ml.mbt"
    original = path.read_text(encoding="utf-8", newline="")
    if original.count(GUARD) < 1:
        print("FAIL: the guard of the first site was not found")
        return 1
    try:
        # The guard of the first site is the first one of the file; the second
        # one belongs to the classifier, whose site is checked on its own.
        path.write_text(
            original.replace(GUARD, "", 1), encoding="utf-8", newline=""
        )
        if check(1):
            print("FAIL: the check is still green without the guard")
            return 1
        print("the check goes red without the guard")
        return 0
    finally:
        path.write_text(original, encoding="utf-8", newline="")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--falsify",
        action="store_true",
        help="remove the guard of the first site and check that the check goes red",
    )
    args = parser.parse_args()
    try:
        if args.falsify:
            return falsify()
        failures = 0
        for site in sorted(SITES):
            if not check(site):
                failures += 1
        sites = sites_of_the_port()
        print("the places of the port that refuse the number: %d" % sites)
        if sites != len(SITES) + 1:
            # The four sites of the check and the one of the check itself.
            print("FAIL: the port refuses the number in %d places" % sites)
            failures += 1
        if failures:
            print("FAIL: %d site(s) did not refuse the number of neighbours" % failures)
            return 1
        print("every site refuses a number of neighbours below one")
        return 0
    finally:
        if PROBE.exists():
            shutil.rmtree(PROBE)


if __name__ == "__main__":
    sys.exit(main())
