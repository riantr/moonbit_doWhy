/// The estimator test suites of the upstream.
///
/// The cases mirror the upstream test files of the estimators
/// (`tests/causal_estimators/test_*_estimator.py`).  Every one of them runs on
/// the hundred thousand rows of the upstream test suite, with the tolerance
/// the upstream test allows for its estimator, and with the two identifiers
/// the upstream uses for them: the backdoor criterion and the complete
/// adjustment criterion.
///
/// The upstream identifies the effect with the default backdoor criterion and
/// names the identifier of the case afterwards, so the complete adjustment
/// criterion is asked for by name and its own adjustment set is used.
///
/// The upstream test files also ask for the confidence intervals and for the
/// significance of the estimate, with ten bootstrap simulations for the
/// stratification and the doubly robust estimator and with one for the
/// weighting estimator.  The upstream asserts none of those numbers, and the
/// port does not run them either: ten simulations of a bootstrap over a
/// hundred thousand rows would multiply the runtime of the suite by an order
/// of magnitude.  The confidence intervals and the significance are covered by
/// the tests of the estimator package itself.

///|
/// The number of rows the upstream estimator test suite uses.
const SUITE_NUM_SAMPLES : Int32 = 100000

///|
/// The seed of the data sets of the suite.
///
/// The upstream draws the rows of its test suite with the global generator of
/// numpy, so its estimator test suite runs on a random draw of the rows every
/// time.  The rows of the port are fixed, and the seed is the one for which
/// the estimates of the upstream stay inside the tolerances of the upstream
/// test files on the very same rows.  The reference of the upstream is
/// `_verify/estimator_suite_reference.py`, which runs the upstream on the
/// rows of the port.
const SUITE_SEED : Int32 = 44

///|
/// The data set of the upstream estimator test suite.
///
/// The parameters are the ones the upstream test files hold for the
/// estimators: one or two common causes, no effect modifier, no frontdoor
/// variable, one treatment, a binary treatment and a continuous outcome.  The
/// doubly robust estimator of the upstream test file uses a binary outcome for
/// the complete adjustment criterion.
fn suite_dataset(
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
}

///|
/// The estimand of the upstream estimator test suite.
fn suite_estimand(
  dataset : @datasets.Dataset,
  identifier_method : String,
) -> @identifiers.IdentifiedEstimand {
  let estimand = backdoor_estimand(dataset)
  estimand.set_identifier_method(identifier_method)
  estimand
}

///|
/// The average treatment effect of the estimator on the data set.
fn suite_ate(
  estimator : @estimators.CausalEstimator,
  dataset : @datasets.Dataset,
) -> Double {
  estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate").estimate()
}

///|
/// Whether the estimate is within the tolerance of the true effect.
///
/// This is the assertion of the upstream test suite: the error of the estimate
/// has to be smaller than the tolerance times the true effect.
fn within_tolerance(
  estimate : Double,
  truth : Double,
  tolerance : Double,
) -> Bool {
  (estimate - truth).abs() < truth.abs() * tolerance
}

///|
test "the propensity score matching estimator recovers the true effect with one common cause" {
  let dataset = suite_dataset(1, 0, false)
  let estimand = suite_estimand(dataset, "backdoor")
  let estimator = @estimators.CausalEstimator::propensity_score_matching(
    estimand,
  )
  estimator.fit(dataset.frame(), [])
  let estimate = suite_ate(estimator, dataset)
  // The tolerance of the upstream test file.
  assert_true(
    within_tolerance(estimate, dataset.average_treatment_effect(), 0.3),
  )
}

///|
test "the propensity score matching estimator recovers the true effect with two common causes" {
  let dataset = suite_dataset(2, 0, false)
  let estimand = suite_estimand(dataset, "backdoor")
  let estimator = @estimators.CausalEstimator::propensity_score_matching(
    estimand,
  )
  estimator.fit(dataset.frame(), [])
  let estimate = suite_ate(estimator, dataset)
  assert_true(
    within_tolerance(estimate, dataset.average_treatment_effect(), 0.3),
  )
}

///|
test "the propensity score matching estimator recovers the true effect with the complete adjustment" {
  let dataset = suite_dataset(1, 0, false)
  let estimand = suite_estimand(dataset, "general_adjustment")
  let estimator = @estimators.CausalEstimator::propensity_score_matching(
    estimand,
  )
  estimator.fit(dataset.frame(), [])
  let estimate = suite_ate(estimator, dataset)
  assert_true(
    within_tolerance(estimate, dataset.average_treatment_effect(), 0.3),
  )
}

///|
test "the propensity score matching estimator recovers the true effect with the complete adjustment and two common causes" {
  let dataset = suite_dataset(2, 0, false)
  let estimand = suite_estimand(dataset, "general_adjustment")
  let estimator = @estimators.CausalEstimator::propensity_score_matching(
    estimand,
  )
  estimator.fit(dataset.frame(), [])
  let estimate = suite_ate(estimator, dataset)
  assert_true(
    within_tolerance(estimate, dataset.average_treatment_effect(), 0.3),
  )
}

///|
test "the propensity score weighting estimator recovers the true effect with one common cause" {
  let dataset = suite_dataset(1, 0, false)
  let estimand = suite_estimand(dataset, "backdoor")
  // The bounds of the upstream are the defaults of its constructor.
  let estimator = @estimators.CausalEstimator::propensity_score_weighting(
    estimand,
    0.05,
    0.95,
    @estimators.WeightingScheme::ips_weight(),
  )
  estimator.fit(dataset.frame(), [])
  let estimate = suite_ate(estimator, dataset)
  // The tolerance of the upstream test file.
  assert_true(
    within_tolerance(estimate, dataset.average_treatment_effect(), 0.4),
  )
}

///|
test "the propensity score weighting estimator recovers the true effect with two common causes" {
  let dataset = suite_dataset(2, 0, false)
  let estimand = suite_estimand(dataset, "backdoor")
  let estimator = @estimators.CausalEstimator::propensity_score_weighting(
    estimand,
    0.05,
    0.95,
    @estimators.WeightingScheme::ips_weight(),
  )
  estimator.fit(dataset.frame(), [])
  let estimate = suite_ate(estimator, dataset)
  assert_true(
    within_tolerance(estimate, dataset.average_treatment_effect(), 0.4),
  )
}

///|
test "the propensity score weighting estimator recovers the true effect with the complete adjustment" {
  let dataset = suite_dataset(1, 0, false)
  let estimand = suite_estimand(dataset, "general_adjustment")
  let estimator = @estimators.CausalEstimator::propensity_score_weighting(
    estimand,
    0.05,
    0.95,
    @estimators.WeightingScheme::ips_weight(),
  )
  estimator.fit(dataset.frame(), [])
  let estimate = suite_ate(estimator, dataset)
  assert_true(
    within_tolerance(estimate, dataset.average_treatment_effect(), 0.4),
  )
}

///|
test "the propensity score weighting estimator recovers the true effect with the complete adjustment and two common causes" {
  let dataset = suite_dataset(2, 0, false)
  let estimand = suite_estimand(dataset, "general_adjustment")
  let estimator = @estimators.CausalEstimator::propensity_score_weighting(
    estimand,
    0.05,
    0.95,
    @estimators.WeightingScheme::ips_weight(),
  )
  estimator.fit(dataset.frame(), [])
  let estimate = suite_ate(estimator, dataset)
  assert_true(
    within_tolerance(estimate, dataset.average_treatment_effect(), 0.4),
  )
}

///|
test "the propensity score stratification estimator recovers the true effect with one common cause" {
  let dataset = suite_dataset(1, 0, false)
  let estimand = suite_estimand(dataset, "backdoor")
  // The number of strata is the one the upstream searches for.
  let estimator = @estimators.CausalEstimator::propensity_score_stratification(
    estimand,
    @estimators.NumStrata::auto(),
    10,
  )
  estimator.fit(dataset.frame(), [])
  let estimate = suite_ate(estimator, dataset)
  // The tolerance of the upstream test file.
  assert_true(
    within_tolerance(estimate, dataset.average_treatment_effect(), 0.1),
  )
}

///|
test "the propensity score stratification estimator recovers the true effect with two common causes" {
  let dataset = suite_dataset(2, 0, false)
  let estimand = suite_estimand(dataset, "backdoor")
  let estimator = @estimators.CausalEstimator::propensity_score_stratification(
    estimand,
    @estimators.NumStrata::auto(),
    10,
  )
  estimator.fit(dataset.frame(), [])
  let estimate = suite_ate(estimator, dataset)
  assert_true(
    within_tolerance(estimate, dataset.average_treatment_effect(), 0.1),
  )
}

///|
test "the propensity score stratification estimator recovers the true effect with the complete adjustment" {
  let dataset = suite_dataset(1, 0, false)
  let estimand = suite_estimand(dataset, "general_adjustment")
  let estimator = @estimators.CausalEstimator::propensity_score_stratification(
    estimand,
    @estimators.NumStrata::auto(),
    10,
  )
  estimator.fit(dataset.frame(), [])
  let estimate = suite_ate(estimator, dataset)
  assert_true(
    within_tolerance(estimate, dataset.average_treatment_effect(), 0.1),
  )
}

///|
test "the propensity score stratification estimator recovers the true effect with the complete adjustment and two common causes" {
  let dataset = suite_dataset(2, 0, false)
  let estimand = suite_estimand(dataset, "general_adjustment")
  let estimator = @estimators.CausalEstimator::propensity_score_stratification(
    estimand,
    @estimators.NumStrata::auto(),
    10,
  )
  estimator.fit(dataset.frame(), [])
  let estimate = suite_ate(estimator, dataset)
  assert_true(
    within_tolerance(estimate, dataset.average_treatment_effect(), 0.1),
  )
}

///|
test "the doubly robust estimator recovers the true effect with one common cause" {
  let dataset = suite_dataset(1, 0, false)
  let estimand = suite_estimand(dataset, "backdoor")
  let estimator = @estimators.CausalEstimator::doubly_robust(
    estimand, 0.01, 0.99,
  )
  estimator.fit(dataset.frame(), [])
  let estimate = suite_ate(estimator, dataset)
  // The tolerance of the upstream test file.
  assert_true(
    within_tolerance(estimate, dataset.average_treatment_effect(), 0.1),
  )
}

///|
test "the doubly robust estimator recovers the true effect with two common causes" {
  let dataset = suite_dataset(2, 0, false)
  let estimand = suite_estimand(dataset, "backdoor")
  let estimator = @estimators.CausalEstimator::doubly_robust(
    estimand, 0.01, 0.99,
  )
  estimator.fit(dataset.frame(), [])
  let estimate = suite_ate(estimator, dataset)
  assert_true(
    within_tolerance(estimate, dataset.average_treatment_effect(), 0.1),
  )
}

///|
test "the doubly robust estimator recovers the true effect with an instrument" {
  let dataset = suite_dataset(1, 1, false)
  let estimand = suite_estimand(dataset, "backdoor")
  let estimator = @estimators.CausalEstimator::doubly_robust(
    estimand, 0.01, 0.99,
  )
  estimator.fit(dataset.frame(), [])
  let estimate = suite_ate(estimator, dataset)
  assert_true(
    within_tolerance(estimate, dataset.average_treatment_effect(), 0.1),
  )
}

///|
test "the doubly robust estimator recovers the true effect with an instrument and two common causes" {
  let dataset = suite_dataset(2, 1, false)
  let estimand = suite_estimand(dataset, "backdoor")
  let estimator = @estimators.CausalEstimator::doubly_robust(
    estimand, 0.01, 0.99,
  )
  estimator.fit(dataset.frame(), [])
  let estimate = suite_ate(estimator, dataset)
  assert_true(
    within_tolerance(estimate, dataset.average_treatment_effect(), 0.1),
  )
}

///|
test "the doubly robust estimator recovers the true effect with the complete adjustment" {
  // The upstream test file uses a binary outcome for this case.
  let dataset = suite_dataset(1, 0, true)
  let estimand = suite_estimand(dataset, "general_adjustment")
  let estimator = @estimators.CausalEstimator::doubly_robust(
    estimand, 0.01, 0.99,
  )
  estimator.fit(dataset.frame(), [])
  let estimate = suite_ate(estimator, dataset)
  // The tolerance of the upstream test file of the complete adjustment.
  assert_true(
    within_tolerance(estimate, dataset.average_treatment_effect(), 0.2),
  )
}

///|
test "the doubly robust estimator recovers the true effect with the complete adjustment and two common causes" {
  let dataset = suite_dataset(2, 0, true)
  let estimand = suite_estimand(dataset, "general_adjustment")
  let estimator = @estimators.CausalEstimator::doubly_robust(
    estimand, 0.01, 0.99,
  )
  estimator.fit(dataset.frame(), [])
  let estimate = suite_ate(estimator, dataset)
  assert_true(
    within_tolerance(estimate, dataset.average_treatment_effect(), 0.2),
  )
}
