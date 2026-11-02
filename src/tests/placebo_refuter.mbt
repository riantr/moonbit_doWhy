/// Tests for the placebo treatment refuter.
///
/// The cases mirror the upstream test file
/// (`tests/causal_refuters/test_placebo_refuter.py`): the placebo treatment
/// has to drive the effect of a continuous treatment, of a binary treatment
/// and of a categorical treatment to zero, and the permuted placebo has to
/// permute the rows of the treatment instead of drawing a new variable.
///
/// The placebo of the upstream is drawn with the global generator of numpy and
/// the port draws it with its own generator, so the two do not produce the same
/// numbers.  What the two share is the behaviour the upstream test asserts:
/// the effect of the placebo is close to zero.

///|
/// The seed of the generator of the placebo refuter.
///
/// The upstream seeds the global generator of numpy once for its whole test
/// class, and the port seeds its own generator once for every case.
const PLACEBO_SEED : UInt64 = 23

///|
/// The data set of the placebo refuter.
///
/// The configuration is the one of the upstream test file: a treatment effect
/// of ten, one common cause and one instrument.
fn placebo_dataset(
  num_common_causes : Int32,
  treatment_is_binary : Bool,
  treatment_is_category : Bool,
  num_samples : Int32,
) -> @datasets.Dataset {
  @datasets.linear_dataset(
    SEED,
    num_samples,
    @datasets.LinearConfig::new(
      beta=10.0,
      num_common_causes~,
      num_instruments=1,
      num_effect_modifiers=0,
      num_frontdoor_variables=0,
      num_treatments=1,
      treatment_is_binary~,
      treatment_is_category~,
      outcome_is_binary=false,
    ),
  )
}

///|
/// The estimator of the upstream test, fitted on the data set.
///
/// The upstream uses a linear regression for a continuous and for a
/// categorical treatment and a propensity score matching for a binary one.
fn placebo_estimator(
  dataset : @datasets.Dataset,
  binary_estimator : Bool,
) -> @estimators.CausalEstimator {
  let estimand = exhaustive_estimand(dataset, "backdoor")
  let estimator = if binary_estimator {
    @estimators.CausalEstimator::propensity_score_matching(estimand)
  } else {
    @estimators.CausalEstimator::linear_regression(estimand)
  }
  estimator.fit(dataset.frame(), [])
  estimator
}

///|
/// The refutation of the placebo treatment of the given data set.
fn placebo_refutation(
  dataset : @datasets.Dataset,
  binary_estimator : Bool,
  num_simulations : Int32,
  placebo_type : @refuters.PlaceboType,
) -> @refuters.CausalRefutation {
  let estimand = exhaustive_estimand(dataset, "backdoor")
  let estimator = placebo_estimator(dataset, binary_estimator)
  @refuters.refute_placebo_treatment(
    estimator,
    estimand,
    dataset.frame(),
    "v0",
    num_simulations,
    1.0,
    0.0,
    "ate",
    @utils.Random::new(PLACEBO_SEED),
    placebo_type~,
  )
}

///|
/// The estimate of the data set itself.
fn placebo_estimate(
  dataset : @datasets.Dataset,
  binary_estimator : Bool,
) -> Double {
  let estimator = placebo_estimator(dataset, binary_estimator)
  estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate").estimate()
}

///|
test "the placebo treatment refuter drives the effect of a continuous treatment to zero" {
  let dataset = placebo_dataset(1, false, false, 1000)
  let refutation = placebo_refutation(
    dataset,
    false,
    100,
    @refuters.PlaceboType::random_data(),
  )
  // The tolerance of the upstream test file.
  assert_true(refutation.new_effect().abs() < 0.03)
  assert_eq(refutation.refutation_type(), "Refute: Use a Placebo Treatment")
  assert_true(refutation.new_effect_lower() <= refutation.new_effect_upper())
  // The zero estimate is in the distribution of the refuted estimates, so the
  // refutation is not significant.
  assert_eq(refutation.p_value(), 1.0)
  assert_false(refutation.is_significant())
}

///|
test "the placebo treatment refuter drives the effect of a continuous treatment without a common cause to zero" {
  let dataset = placebo_dataset(0, false, false, 1000)
  let refutation = placebo_refutation(
    dataset,
    false,
    100,
    @refuters.PlaceboType::random_data(),
  )
  assert_true(refutation.new_effect().abs() < 0.03)
  assert_eq(refutation.p_value(), 1.0)
  assert_false(refutation.is_significant())
}

///|
test "the placebo treatment refuter drives the effect of a binary treatment to zero" {
  let dataset = placebo_dataset(1, true, false, 5000)
  // The upstream runs ten simulations for a binary treatment and the default
  // of a hundred for the other kinds.
  let refutation = placebo_refutation(
    dataset,
    true,
    10,
    @refuters.PlaceboType::random_data(),
  )
  assert_true(refutation.new_effect().abs() < 0.1)
  assert_eq(refutation.refutation_type(), "Refute: Use a Placebo Treatment")
  // The p-value of the test of the normal distribution, because the upstream
  // runs less than a hundred simulations.
  assert_true(refutation.p_value() > 0.05)
  assert_false(refutation.is_significant())
}

///|
test "the placebo treatment refuter drives the effect of a categorical treatment to zero" {
  let dataset = placebo_dataset(1, false, true, 5000)
  let refutation = placebo_refutation(
    dataset,
    false,
    100,
    @refuters.PlaceboType::random_data(),
  )
  assert_true(refutation.new_effect().abs() < 0.1)
  assert_eq(refutation.refutation_type(), "Refute: Use a Placebo Treatment")
  assert_true(refutation.p_value() > 0.05)
  assert_false(refutation.is_significant())
}

///|
test "the permuted placebo permutes the rows of a continuous treatment" {
  let dataset = placebo_dataset(1, false, false, 1000)
  let random_data = placebo_refutation(
    dataset,
    false,
    100,
    @refuters.PlaceboType::random_data(),
  )
  let permuted = placebo_refutation(
    dataset,
    false,
    100,
    @refuters.PlaceboType::permute(),
  )
  // The random data placebo of a continuous treatment is the constant zero, so
  // its estimate is the zero estimate; the permuted placebo holds the values
  // of the treatment, so its estimate is not the zero estimate.
  assert_eq(random_data.new_effect(), 0.0)
  assert_true(permuted.new_effect().abs() > 1.0e-6)
  // The permuted placebo breaks the causal relation as well, so its estimate
  // is far from the estimate of the data.
  let original = placebo_estimate(dataset, false)
  assert_true(original.abs() > 9.0)
  assert_true(permuted.new_effect().abs() < 1.0)
}

///|
test "the permuted placebo permutes the rows of a binary treatment" {
  let dataset = placebo_dataset(1, true, false, 5000)
  let permuted = placebo_refutation(
    dataset,
    true,
    10,
    @refuters.PlaceboType::permute(),
  )
  let original = placebo_estimate(dataset, true)
  assert_true(original.abs() > 9.0)
  assert_true(permuted.new_effect().abs() < 0.5)
}

///|
test "the permuted placebo permutes the rows of a categorical treatment" {
  let dataset = placebo_dataset(1, false, true, 5000)
  let permuted = placebo_refutation(
    dataset,
    false,
    100,
    @refuters.PlaceboType::permute(),
  )
  let original = placebo_estimate(dataset, false)
  assert_true(original.abs() > 9.0)
  assert_true(permuted.new_effect().abs() < 0.5)
}

///|
test "the permuted placebo of the instrumental variable method permutes the instrument as well" {
  let dataset = @datasets.linear_dataset(
    SEED,
    1000,
    @datasets.LinearConfig::instrumental_variable(),
  )
  let estimand = exhaustive_estimand(dataset, "backdoor")
  estimand.set_identifier_method("iv")
  let estimator = @estimators.CausalEstimator::instrumental_variable(
    estimand, "Z0",
  )
  estimator.fit(dataset.frame(), [])
  let refutation = @refuters.refute_placebo_treatment(
    estimator,
    estimand,
    dataset.frame(),
    "v0",
    10,
    1.0,
    0.0,
    "ate",
    @utils.Random::new(PLACEBO_SEED),
    placebo_type=@refuters.PlaceboType::permute(),
  )
  assert_eq(refutation.refutation_type(), "Refute: Use a Placebo Treatment")
  // The placebo breaks the causal relation, so the refuted effect is far from
  // the effect of the data.
  let original = estimator
    .estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
    .estimate()
  assert_true(original.abs() > 9.0)
  assert_true(refutation.new_effect().abs() < 1.0)
}
