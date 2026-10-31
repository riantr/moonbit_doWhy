/// Tests for the generalised linear model estimator and for the encoding of
/// the discrete columns.
///
/// The cases mirror the upstream test suite
/// (`tests/causal_estimators/test_generalized_linear_model_estimator.py` and
/// `tests/causal_estimators/test_estimator_consistency.py`): the generalised
/// linear model estimator has to recover the true average treatment effect of
/// a generated data set, and every estimator has to encode the discrete
/// columns of the data in the same way when it is fitted and when it is used.

///|
/// The data set with a binary outcome.
fn binary_outcome() -> @datasets.Dataset {
  @datasets.linear_dataset(
    SEED,
    NUM_SAMPLES,
    @datasets.LinearConfig::binary_outcome(),
  )
}

///|
/// The data set with a binary outcome and without a confounder.
fn binary_outcome_no_confounding() -> @datasets.Dataset {
  @datasets.linear_dataset(
    SEED,
    NUM_SAMPLES,
    @datasets.LinearConfig::no_confounding_binary_outcome(),
  )
}

///|
/// The data set with two discrete common causes.
fn discrete_causes() -> @datasets.Dataset {
  @datasets.linear_dataset(
    SEED,
    NUM_SAMPLES,
    @datasets.LinearConfig::discrete_common_causes(),
  )
}

///|
/// A frame whose first row is the row of another frame.
///
/// The upstream test swaps the first row of the data with a row whose values
/// differ in every encoded column, because the order in which the values of a
/// categorical column are encountered decides the encoding of the column.
fn swap_first_row(
  data : @api.DataFrame,
  columns : Array[String],
) -> @api.DataFrame {
  let n = data.nrows()
  let first = data.discrete(columns[0])
  let second = data.discrete(columns[1])
  let mut target = -1
  let mut i = 1
  while i < n {
    if first[i] != first[0] && second[i] != second[0] {
      target = i
      break
    }
    i = i + 1
  }
  if target < 0 {
    return data
  }
  let order : Array[Int32] = [target]
  let mut j = 1
  while j < n {
    if j != target {
      order.push(j)
    }
    j = j + 1
  }
  order.push(0)
  data.take_rows(order)
}

///|
/// A frame whose discrete column holds fresh random values.
///
/// The upstream test randomises the values of the encoded columns, which
/// breaks the association between the column and the outcome. A permutation
/// of the column would not do, because the confounders are independent of each
/// other and a permutation leaves the mean prediction unchanged.
fn randomize_discrete_column(
  data : @api.DataFrame,
  column : String,
  seed : UInt64,
) -> @api.DataFrame {
  let values = data.discrete(column)
  let categories : Array[String] = []
  for value in values {
    if !categories.contains(value) {
      categories.push(value)
    }
  }
  let rng = @utils.Random::new(seed)
  let randomized : Array[String] = []
  for i = 0; i < values.length(); i = i + 1 {
    randomized.push(categories[rng.next_int(categories.length())])
  }
  data.with_discrete(column, randomized)
}

///|
/// The tolerance the upstream estimator consistency test uses.
const CONSISTENCY_TOLERANCE : Double = 1.0e-6

///|
test "the generalised linear model estimator recovers the true effect" {
  let dataset = binary_outcome()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::generalized_linear_model(
    estimand,
    @utils.GlmFamily::binomial(),
  )
  estimator.fit(dataset.frame(), [])
  let estimate = estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
  assert_true(close_enough(estimate.value, dataset.average_treatment_effect()))
}

///|
test "the generalised linear model estimator recovers the true effect without a confounder" {
  let dataset = binary_outcome_no_confounding()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::generalized_linear_model(
    estimand,
    @utils.GlmFamily::binomial(),
  )
  estimator.fit(dataset.frame(), [])
  let estimate = estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
  assert_true(close_enough(estimate.value, dataset.average_treatment_effect()))
}

///|
test "the gaussian generalised linear model agrees with the linear regression estimator" {
  let dataset = confounded()
  let estimand = backdoor_estimand(dataset)
  let glm = @estimators.CausalEstimator::generalized_linear_model(
    estimand,
    @utils.GlmFamily::gaussian(),
  )
  glm.fit(dataset.frame(), [])
  let glm_estimate = glm.estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
  let regression = @estimators.CausalEstimator::linear_regression(estimand)
  regression.fit(dataset.frame(), [])
  let regression_estimate = regression.estimate_effect(
    dataset.frame(),
    1.0,
    0.0,
    "ate",
  )
  assert_true((glm_estimate.value - regression_estimate.value).abs() < 1.0e-8)
}

///|
test "the estimator reports the confidence interval of the generalised linear model" {
  let dataset = binary_outcome()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::generalized_linear_model(
    estimand,
    @utils.GlmFamily::binomial(),
  )
  estimator.set_compute_confidence_intervals(true)
  estimator.fit(dataset.frame(), [])
  let estimate = estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
  assert_true(estimate.confidence_interval_lower() < estimate.value)
  assert_true(estimate.confidence_interval_upper() > estimate.value)
  assert_true(estimate.standard_error() > 0.0)
  assert_true(estimate.p_value() < 0.05)
}

///|
test "the order of the rows does not change the estimate of the estimator" {
  let dataset = discrete_causes()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::linear_regression(estimand)
  estimator.fit(dataset.frame(), [])
  let first = estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
  let swapped = swap_first_row(dataset.frame(), ["W1", "W2"])
  let second = estimator.estimate_effect(swapped, 1.0, 0.0, "ate")
  assert_true((first.value - second.value).abs() < CONSISTENCY_TOLERANCE)
}

///|
test "the order of the rows does not change the intervention of the estimator" {
  let dataset = discrete_causes()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::linear_regression(estimand)
  estimator.fit(dataset.frame(), [])
  let first = estimator.intervene(1.0, dataset.frame())
  let swapped = swap_first_row(dataset.frame(), ["W1", "W2"])
  let second = estimator.intervene(1.0, swapped)
  assert_true((first - second).abs() < CONSISTENCY_TOLERANCE)
}

///|
test "the intervention of the estimator reacts to the encoded columns" {
  let dataset = discrete_causes()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::linear_regression(estimand)
  estimator.fit(dataset.frame(), [])
  let first = estimator.intervene(1.0, dataset.frame())
  // The same rows, but the values of the encoded column are drawn again, so
  // the column no longer describes the same units.
  let randomized = randomize_discrete_column(dataset.frame(), "W1", 99UL)
  let second = estimator.intervene(1.0, randomized)
  assert_true((first - second).abs() > CONSISTENCY_TOLERANCE)
}

///|
test "the propensity score estimator encodes the discrete common causes" {
  let dataset = discrete_causes()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::propensity_score_weighting(
    estimand,
    0.05,
    0.95,
    @estimators.WeightingScheme::ips_weight(),
  )
  estimator.fit(dataset.frame(), [])
  let first = estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
  // The rows are permuted, but the encoding of the discrete columns does not
  // change, so the estimate does not change either.
  let swapped = swap_first_row(dataset.frame(), ["W1", "W2"])
  let second = estimator.estimate_effect(swapped, 1.0, 0.0, "ate")
  assert_true((first.value - second.value).abs() < CONSISTENCY_TOLERANCE)
  // The propensity scores of the estimate stay inside the configured bounds.
  let scores = first.propensity_scores()
  assert_true(scores.length() > 0)
  for score in scores {
    assert_true(score >= 0.05)
    assert_true(score <= 0.95)
  }
}
