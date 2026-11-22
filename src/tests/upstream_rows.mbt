/// The estimator of the port on the rows of the upstream.
///
/// The file mirrors the test file
/// `tests/causal_estimators/test_linear_regression_estimator.py` of the
/// upstream. Its case `test_average_treatment_effect` asserts that the
/// estimate of the linear regression estimator recovers the true average
/// treatment effect of a generated data set within a tolerance of ten
/// percent, and the data set is the one of the generator
/// `dowhy.datasets.linear_dataset`.
///
/// The port runs on the rows of the upstream here, so the assertion is the
/// stronger one: the estimate of the port and the estimate of the upstream are
/// the same number, and not two numbers that are near each other. The rows and
/// the numbers of the upstream are the ones
/// `_verify/gen_upstream_estimator_testdata.py` writes into
/// `src/tests/upstream_estimator_testdata.mbt`.
///
/// The tolerance is the one the other tests of the port use for the numbers of
/// the upstream: the two implementations solve the same least squares problem
/// on the same rows, and they differ in the last bits of the double.

///|
/// The tolerance the numbers of the upstream are compared with.
const UPSTREAM_ROWS_TOLERANCE : Double = 0.000000000001

///|
/// The model of the rows of the upstream.
fn upstream_model() -> @moonbit_dowhy.CausalModel {
  @moonbit_dowhy.CausalModel::new(
    upstream_frame(),
    ["v0"],
    ["y"],
    None,
    ["W0"],
    ["Z0"],
    [],
    [],
  )
}

///|
test "the linear regression estimator of the port gives the number of the upstream" {
  let model = upstream_model()
  let _ = model.identify_effect("backdoor")
  let estimate = model.estimate_effect(
    "backdoor.linear_regression", 1.0, 0.0, "ate",
  )
  assert_true(
    (estimate.estimate() - UPSTREAM_ATE).abs() < UPSTREAM_ROWS_TOLERANCE,
  )
}

///|
test "the confidence interval of the port is the interval of the upstream" {
  let model = upstream_model()
  let _ = model.identify_effect("backdoor")
  let estimate = model.estimate_effect(
    "backdoor.linear_regression", 1.0, 0.0, "ate",
  )
  assert_true(
    (estimate.confidence_interval_lower() - UPSTREAM_CI_LOWER).abs() <
    UPSTREAM_ROWS_TOLERANCE,
  )
  assert_true(
    (estimate.confidence_interval_upper() - UPSTREAM_CI_UPPER).abs() <
    UPSTREAM_ROWS_TOLERANCE,
  )
}

///|
test "the standard error of the port is the standard error of the upstream" {
  let model = upstream_model()
  let _ = model.identify_effect("backdoor")
  let estimate = model.estimate_effect(
    "backdoor.linear_regression", 1.0, 0.0, "ate",
  )
  assert_true(
    (estimate.standard_error() - UPSTREAM_STANDARD_ERROR).abs() <
    UPSTREAM_ROWS_TOLERANCE,
  )
}

///|
test "the adjustment set of the port is the adjustment set of the upstream" {
  let model = upstream_model()
  let estimand = model.identify_effect("backdoor")
  let adjustment = estimand.get_adjustment_set(estimand.identifier_method())
  assert_eq(adjustment.length(), 1)
  assert_eq(adjustment[0], "W0")
}

///|
test "the estimate of the port on the rows of the upstream is near the true effect" {
  let model = upstream_model()
  let _ = model.identify_effect("backdoor")
  let estimate = model.estimate_effect(
    "backdoor.linear_regression", 1.0, 0.0, "ate",
  )
  // The upstream test allows a tolerance of ten percent of the true effect,
  // and the port is inside it on the rows of the upstream as well.
  let error = (estimate.estimate() - UPSTREAM_TRUE_ATE).abs()
  assert_true(error < UPSTREAM_TRUE_ATE.abs() * 0.1)
}
