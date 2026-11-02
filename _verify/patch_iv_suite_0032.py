"""Adds the cases of the upstream IV estimator test file to the estimator suite.

The upstream file `tests/causal_estimators/test_instrumental_variable_estimator.py`
holds sixteen configurations.  Four of them are reachable with the estimators
of the port: one treatment, one instrument, no or one common cause, and a
continuous or a binary treatment.  The configurations with two treatments are
out of reach, because the estimators of the port are univariate, and the
configurations with two instruments are out of reach as well, because the
upstream uses the two stage least squares of `linearmodels` for them and the
port has one instrument per estimator.

The upstream cannot run the configurations with a binary treatment here: its
own generator of the data sets calls `numpy.vectorize` on a function that
returns an array, which numpy 2 refuses.  The cases with a binary treatment
therefore assert the rule of the upstream test file -- the error of the
estimate has to be smaller than forty percent of the true effect -- on the
rows of the port.
"""

import io
import os

PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "src",
    "tests",
    "estimator_suites.mbt",
)

with io.open(PATH, encoding="utf-8", newline="") as handle:
    source = handle.read()

HEADER_OLD = """/// The estimator test suites of the upstream.
///
/// The cases mirror the upstream test files of the estimators
/// (`tests/causal_estimators/test_*_estimator.py`).  Every one of them runs on
/// the hundred thousand rows of the upstream test suite, with the tolerance
/// the upstream test allows for its estimator, and with the two identifiers
/// the upstream uses for them: the backdoor criterion and the complete
/// adjustment criterion.
"""

HEADER_NEW = """/// The estimator test suites of the upstream.
///
/// The cases mirror the upstream test files of the estimators
/// (`tests/causal_estimators/test_*_estimator.py`).  Every one of them runs on
/// the hundred thousand rows of the upstream test suite, with the tolerance
/// the upstream test allows for its estimator, and with the two identifiers
/// the upstream uses for them: the backdoor criterion and the complete
/// adjustment criterion.
///
/// The cases of the instrumental variable estimator are the four of them that
/// the estimators of the port can reach.  The upstream file holds sixteen
/// configurations: eight of them need two treatments, which the estimators of
/// the port do not have, and four of them need two instruments, which the
/// upstream estimates with the two stage least squares of `linearmodels`.
"""

DATASET_OLD = """fn suite_dataset(
  num_common_causes : Int32,
  num_instruments : Int32,
  outcome_is_binary : Bool,
) -> @datasets.Dataset {
  @datasets.linear_dataset(
    SUITE_SEED,
    SUITE_NUM_SAMPLES,
    @datasets.LinearConfig::new(
      beta=10.0,
      num_common_causes~,
      num_instruments~,
      num_effect_modifiers=0,
      num_frontdoor_variables=0,
      num_treatments=1,
      treatment_is_binary=true,
      treatment_is_category=false,
      outcome_is_binary~,
    ),
  )
}"""

DATASET_NEW = """fn suite_dataset(
  num_common_causes : Int32,
  num_instruments : Int32,
  outcome_is_binary : Bool,
  treatment_is_binary~ : Bool = true,
) -> @datasets.Dataset {
  @datasets.linear_dataset(
    SUITE_SEED,
    SUITE_NUM_SAMPLES,
    @datasets.LinearConfig::new(
      beta=10.0,
      num_common_causes~,
      num_instruments~,
      num_effect_modifiers=0,
      num_frontdoor_variables=0,
      num_treatments=1,
      treatment_is_binary~,
      treatment_is_category=false,
      outcome_is_binary~,
    ),
  )
}"""

CASES = """
///|
test "the instrumental variable estimator recovers the true effect without a common cause" {
  let dataset = suite_dataset(0, 1, false, treatment_is_binary=false)
  let estimand = suite_estimand(dataset, "iv")
  let estimator = @estimators.CausalEstimator::instrumental_variable(
    estimand,
    dataset.instruments()[0],
  )
  estimator.fit(dataset.frame(), [])
  let estimate = suite_ate(estimator, dataset)
  // The tolerance of the upstream test file.
  assert_true(
    within_tolerance(estimate, dataset.average_treatment_effect(), 0.4),
  )
}

///|
test "the instrumental variable estimator recovers the true effect with a common cause" {
  let dataset = suite_dataset(1, 1, false, treatment_is_binary=false)
  let estimand = suite_estimand(dataset, "iv")
  let estimator = @estimators.CausalEstimator::instrumental_variable(
    estimand,
    dataset.instruments()[0],
  )
  estimator.fit(dataset.frame(), [])
  let estimate = suite_ate(estimator, dataset)
  assert_true(
    within_tolerance(estimate, dataset.average_treatment_effect(), 0.4),
  )
}

///|
test "the instrumental variable estimator recovers the true effect with a binary treatment" {
  let dataset = suite_dataset(0, 1, false)
  let estimand = suite_estimand(dataset, "iv")
  let estimator = @estimators.CausalEstimator::instrumental_variable(
    estimand,
    dataset.instruments()[0],
  )
  estimator.fit(dataset.frame(), [])
  let estimate = suite_ate(estimator, dataset)
  assert_true(
    within_tolerance(estimate, dataset.average_treatment_effect(), 0.4),
  )
}

///|
test "the instrumental variable estimator recovers the true effect with a binary treatment and a common cause" {
  let dataset = suite_dataset(1, 1, false)
  let estimand = suite_estimand(dataset, "iv")
  let estimator = @estimators.CausalEstimator::instrumental_variable(
    estimand,
    dataset.instruments()[0],
  )
  estimator.fit(dataset.frame(), [])
  let estimate = suite_ate(estimator, dataset)
  assert_true(
    within_tolerance(estimate, dataset.average_treatment_effect(), 0.4),
  )
}
"""

for old, new in (
    (HEADER_OLD, HEADER_NEW),
    (DATASET_OLD, DATASET_NEW),
):
    if source.count(old) != 1:
        raise SystemExit("the anchor is not unique:\n%s" % old[:200])
    source = source.replace(old, new)

if not source.endswith("\n"):
    source = source + "\n"
source = source + CASES

with io.open(PATH, "w", encoding="utf-8", newline="") as handle:
    handle.write(source)

print("patched", PATH)
