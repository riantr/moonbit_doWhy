/// Tests for the estimators.
///
/// The cases mirror the upstream test suite
/// (`tests/causal_estimators/test_*_estimator.py`): every estimator has to
/// recover the true average treatment effect of a generated data set within
/// the same ten percent tolerance that the upstream tests use.

///|
/// The tolerance the upstream estimator tests use.
const ERROR_TOLERANCE : Double = 0.1

///|
/// Whether the estimate is within the tolerance of the true effect.
fn close_enough(estimate : Double, truth : Double) -> Bool {
  let error = (estimate - truth).abs()
  error < truth.abs() * ERROR_TOLERANCE
}

///|
/// The data set without a confounder.
fn no_confounding() -> @datasets.Dataset {
  @datasets.linear_dataset(
    SEED,
    NUM_SAMPLES,
    @datasets.LinearConfig::no_confounding(),
  )
}

///|
/// The data set with an effect modifier.
fn with_effect_modifier() -> @datasets.Dataset {
  @datasets.linear_dataset(
    SEED,
    NUM_SAMPLES,
    @datasets.LinearConfig::effect_modifier(),
  )
}

///|
/// The data set with an instrument.
fn with_instrument() -> @datasets.Dataset {
  @datasets.linear_dataset(
    SEED,
    NUM_SAMPLES,
    @datasets.LinearConfig::instrumental_variable(),
  )
}

///|
/// The confounded data set with two common causes.
fn two_common_causes() -> @datasets.Dataset {
  @datasets.linear_dataset(
    SEED,
    NUM_SAMPLES,
    @datasets.LinearConfig::two_common_causes(),
  )
}

///|
test "the linear regression estimator recovers the true effect" {
  let dataset = confounded()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::linear_regression(estimand)
  estimator.fit(dataset.frame(), [])
  let estimate = estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
  assert_true(close_enough(estimate.value, dataset.average_treatment_effect()))
}

///|
test "the linear regression estimator recovers the effect without a confounder" {
  let dataset = no_confounding()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::linear_regression(estimand)
  estimator.fit(dataset.frame(), [])
  let estimate = estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
  assert_true(close_enough(estimate.value, dataset.average_treatment_effect()))
}

///|
test "the linear regression estimator recovers the effect with two confounders" {
  let dataset = two_common_causes()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::linear_regression(estimand)
  estimator.fit(dataset.frame(), [])
  let estimate = estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
  assert_true(close_enough(estimate.value, dataset.average_treatment_effect()))
}

///|
test "the propensity score weighting estimator recovers the true effect" {
  let dataset = confounded()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::propensity_score_weighting(
    estimand,
    0.05,
    0.95,
    @estimators.WeightingScheme::ips_weight(),
  )
  estimator.fit(dataset.frame(), [])
  let estimate = estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
  assert_true(close_enough(estimate.value, dataset.average_treatment_effect()))
}

///|
test "the normalised propensity score weighting estimator recovers the true effect" {
  let dataset = confounded()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::propensity_score_weighting(
    estimand,
    0.05,
    0.95,
    @estimators.WeightingScheme::ips_normalized_weight(),
  )
  estimator.fit(dataset.frame(), [])
  let estimate = estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
  assert_true(close_enough(estimate.value, dataset.average_treatment_effect()))
}

///|
test "the stabilised propensity score weighting estimator recovers the true effect" {
  let dataset = confounded()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::propensity_score_weighting(
    estimand,
    0.05,
    0.95,
    @estimators.WeightingScheme::ips_stabilized_weight(),
  )
  estimator.fit(dataset.frame(), [])
  let estimate = estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
  assert_true(close_enough(estimate.value, dataset.average_treatment_effect()))
}

///|
test "the propensity score matching estimator recovers the true effect" {
  let dataset = confounded()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::propensity_score_matching(
    estimand,
  )
  estimator.fit(dataset.frame(), [])
  let estimate = estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
  assert_true(close_enough(estimate.value, dataset.average_treatment_effect()))
}

///|
test "the propensity score stratification estimator recovers the true effect" {
  let dataset = confounded()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::propensity_score_stratification(
    estimand, 5, 10,
  )
  estimator.fit(dataset.frame(), [])
  let estimate = estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
  assert_true(close_enough(estimate.value, dataset.average_treatment_effect()))
}

///|
test "the doubly robust estimator recovers the true effect" {
  let dataset = confounded()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::doubly_robust(
    estimand, 0.01, 0.99,
  )
  estimator.fit(dataset.frame(), [])
  let estimate = estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
  assert_true(close_enough(estimate.value, dataset.average_treatment_effect()))
}

///|
test "the instrumental variable estimator recovers the true effect" {
  let dataset = with_instrument()
  let graph = @graph.build_graph(
    dataset.treatments(),
    [dataset.outcome()],
    dataset.common_causes(),
    dataset.instruments(),
    dataset.effect_modifiers(),
    dataset.frontdoor_variables(),
  )
  let estimand = @identifiers.identify_effect_auto(
    graph,
    dataset.treatments(),
    [dataset.outcome()],
    dataset.observed_nodes(),
    "nonparametric-ate",
    @identifiers.BACKDOOR_DEFAULT,
  )
  let estimator = @estimators.CausalEstimator::instrumental_variable(
    estimand, "Z0",
  )
  estimator.fit(dataset.frame(), [])
  let estimate = estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
  assert_true(close_enough(estimate.value, dataset.average_treatment_effect()))
}

///|
test "the regression with an effect modifier recovers the true effect" {
  let dataset = with_effect_modifier()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::linear_regression(estimand)
  estimator.fit(dataset.frame(), dataset.effect_modifiers())
  let estimate = estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
  assert_true(close_enough(estimate.value, dataset.average_treatment_effect()))
}

///|
test "the estimate reports a confidence interval that covers the truth" {
  let dataset = confounded()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::linear_regression(estimand)
  estimator.set_compute_confidence_intervals(true)
  estimator.fit(dataset.frame(), [])
  let estimate = estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
  let lower = estimate.confidence_interval_lower()
  let upper = estimate.confidence_interval_upper()
  assert_true(lower < dataset.average_treatment_effect())
  assert_true(upper > dataset.average_treatment_effect())
}

///|
test "the estimate reports a significant p value" {
  let dataset = confounded()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::linear_regression(estimand)
  estimator.set_test_significance(true)
  estimator.fit(dataset.frame(), [])
  let estimate = estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
  assert_true(estimate.p_value() < 0.05)
  assert_true(estimate.standard_error() > 0.0)
}

///|
test "the propensity scores stay inside the configured bounds" {
  let dataset = confounded()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::propensity_score_weighting(
    estimand,
    0.05,
    0.95,
    @estimators.WeightingScheme::ips_weight(),
  )
  estimator.fit(dataset.frame(), [])
  let estimate = estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
  let scores = estimate.propensity_scores()
  assert_true(scores.length() > 0)
  for score in scores {
    assert_true(score >= 0.05)
    assert_true(score <= 0.95)
  }
}

///|
test "the estimator remembers its adjustment variables" {
  let dataset = confounded()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::linear_regression(estimand)
  estimator.fit(dataset.frame(), [])
  assert_true(estimator.adjustment_set().contains("W0"))
  assert_eq(estimator.treatment(), "v0")
  assert_eq(estimator.outcome(), "y")
}
