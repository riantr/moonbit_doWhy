"""Adds a temporary measurement of the instrumental variable estimator.

The helpers of the suite are private to the package, so the measurement has to
live in the file that holds them.  Run it with the argument `add` and undo it
with the argument `remove`.
"""

import io
import os
import sys

PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "src",
    "tests",
    "estimator_suites.mbt",
)

BLOCK = """
///|
test "measure the instrumental variable estimator of the port" {
  let cases = [
    (0, false),
    (0, true),
    (1, false),
    (1, true),
  ]
  for case in cases {
    let (num_common_causes, treatment_is_binary) = case
    let dataset = suite_dataset(
      num_common_causes,
      1,
      false,
      treatment_is_binary~,
    )
    let estimand = suite_estimand(dataset, "iv")
    let estimator = @estimators.CausalEstimator::instrumental_variable(
      estimand,
      dataset.instruments()[0],
    )
    estimator.fit(dataset.frame(), [])
    let estimate = suite_ate(estimator, dataset)
    println(
      "iv " +
      num_common_causes.to_string() +
      " common cause(s), binary treatment " +
      treatment_is_binary.to_string() +
      ": " +
      estimate.to_string() +
      " truth " +
      dataset.average_treatment_effect().to_string(),
    )
  }
}
"""

with io.open(PATH, encoding="utf-8", newline="") as handle:
    source = handle.read()

mode = sys.argv[1] if len(sys.argv) > 1 else "add"

if mode == "add":
    if "measure the instrumental variable estimator" in source:
        raise SystemExit("the measurement is already there")
    if not source.endswith("\n"):
        source = source + "\n"
    source = source + BLOCK
elif mode == "remove":
    if BLOCK not in source:
        raise SystemExit("the measurement is not there")
    source = source.replace(BLOCK, "")
else:
    raise SystemExit("the mode is add or remove")

with io.open(PATH, "w", encoding="utf-8", newline="") as handle:
    handle.write(source)

print(mode, "done")
