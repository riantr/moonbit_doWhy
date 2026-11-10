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
/// The frame of the fixture of the do operator.
///
/// This is the frame of the script `_verify/do_operator_reference.py`: sixty
/// rows of a treatment, of a common cause and of an outcome.
fn do_operator_frame() -> @api.DataFrame {
  let v : Array[Double] = []
  let w : Array[Double] = []
  let y : Array[Double] = []
  for i in 0..<60 {
    let w_value = (i % 7).to_double() - 3.0
    let v_value = (i % 2).to_double()
    let noise = ((i % 5).to_double() - 2.0) * 0.25
    v.push(v_value)
    w.push(w_value)
    y.push(2.0 * v_value + 0.5 * w_value + noise)
  }
  @api.DataFrame::from_numeric(
    ["v0", "W0", "y"],
    Map([("v0", v), ("W0", w), ("y", y)]),
  )
}

///|
/// The frame with its first two rows swapped.
///
/// This is the frame the upstream builds for its second test of the
/// estimators: the rows of the data are permuted, and the value of the do
/// operator must not move.
fn swap_first_two_rows(frame : @api.DataFrame) -> @api.DataFrame {
  let columns : Map[String, @api.Column] = Map([])
  let order : Array[String] = []
  for name in frame.column_names() {
    order.push(name)
    match frame.column(name) {
      Some(@api.Column::Numeric(values)) => {
        let swapped = values.copy()
        let first = swapped[0]
        swapped[0] = swapped[1]
        swapped[1] = first
        columns.set(name, @api.Column::numeric(swapped))
      }
      Some(@api.Column::Discrete(values)) => {
        let swapped = values.copy()
        let first = swapped[0]
        swapped[0] = swapped[1]
        swapped[1] = first
        columns.set(name, @api.Column::discrete(swapped))
      }
      None => ()
    }
  }
  @api.DataFrame::new(order, columns)
}

///|
/// A copy of the frame whose column holds a random draw of its own values.
///
/// This is the frame the upstream builds for its second test of the
/// estimators: the values of the encoded columns are randomised, and the value
/// of the do operator must move, because the encoding of the columns changed.
fn randomise_column(
  frame : @api.DataFrame,
  name : String,
  random : @utils.Random,
) -> @api.DataFrame {
  let columns : Map[String, @api.Column] = Map([])
  let order : Array[String] = []
  for column_name in frame.column_names() {
    order.push(column_name)
    if column_name != name {
      match frame.column(column_name) {
        Some(@api.Column::Numeric(values)) =>
          columns.set(column_name, @api.Column::numeric(values))
        Some(@api.Column::Discrete(values)) =>
          columns.set(column_name, @api.Column::discrete(values))
        None => ()
      }
      continue
    }
    match frame.column(column_name) {
      Some(@api.Column::Numeric(values)) => {
        let drawn = random.sample_with_replacement(values, values.length())
        columns.set(column_name, @api.Column::numeric(drawn))
      }
      Some(@api.Column::Discrete(values)) => {
        let drawn = sample_text_with_replacement(
          values,
          values.length(),
          random,
        )
        columns.set(column_name, @api.Column::discrete(drawn))
      }
      None => ()
    }
  }
  @api.DataFrame::new(order, columns)
}

///|
/// A sample of the given number of values drawn with replacement.
fn sample_text_with_replacement(
  values : Array[String],
  size : Int32,
  random : @utils.Random,
) -> Array[String] {
  let out : Array[String] = []
  for _ in 0..<size {
    out.push(values[random.next_int(values.length())])
  }
  out
}

///|
test "the do operator of the estimator does not move when the rows are permuted" {
  let dataset = confounded()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::linear_regression(estimand)
  estimator.fit(dataset.frame(), [])
  let first = estimator.do_operator(1.0, dataset.frame())
  let second = estimator.do_operator(1.0, swap_first_two_rows(dataset.frame()))
  // The upstream checks that the value of the do operator does not move when
  // the rows of the data are permuted.
  assert_true((first - second).abs() < 0.000001)
}

///|
test "the do operator of the estimator moves when the encoded columns move" {
  let dataset = @datasets.linear_dataset(
    SEED,
    NUM_SAMPLES,
    @datasets.LinearConfig::discrete_common_causes(),
  )
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::linear_regression(estimand)
  estimator.fit(dataset.frame(), [])
  let first = estimator.do_operator(1.0, dataset.frame())
  let random = @utils.Random::new(11)
  let randomised = randomise_column(
    dataset.frame(),
    dataset.common_causes()[0],
    random,
  )
  let second = estimator.do_operator(1.0, randomised)
  // The upstream checks that the value of the do operator moves when the
  // values of the encoded columns move, because the encoding of the columns
  // changed.
  assert_true((first - second).abs() > 0.000001)
}

///|
test "the do operator of the model is the number of the upstream" {
  let frame = do_operator_frame()
  let model = @moonbit_dowhy.CausalModel::new(
    frame,
    ["v0"],
    ["y"],
    None,
    ["W0"],
    [],
    [],
    [],
  )
  let estimand = model.identify_effect("backdoor")
  let zero = model.do_operator(0.0, estimand, "backdoor.linear_regression")
  let one = model.do_operator(1.0, estimand, "backdoor.linear_regression")
  assert_true((zero - -0.04996488764044996).abs() < 0.000000001)
  assert_true((one - 1.94996488764045).abs() < 0.000000001)
}

///|
test "the do operator of the model is the value of the outcome under the intervention" {
  let dataset = confounded()
  let model = @moonbit_dowhy.CausalModel::new(
    dataset.frame(),
    dataset.treatments(),
    [dataset.outcome()],
    None,
    dataset.common_causes(),
    [],
    [],
    [],
  )
  let estimand = model.identify_effect("backdoor")
  let value = model.do_operator(1.0, estimand, "backdoor.linear_regression")
  let estimator = @estimators.CausalEstimator::linear_regression(estimand)
  estimator.fit(dataset.frame(), [])
  let expected = estimator.do_operator(1.0, dataset.frame())
  assert_true((value - expected).abs() < 0.000000001)
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
    estimand,
    @estimators.NumStrata::fixed(5),
    10,
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
