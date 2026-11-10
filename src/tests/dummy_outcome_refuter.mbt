///| Tests for the dummy outcome refuter.
///
/// The cases mirror `tests/causal_refuters/test_dummy_outcome_refuter.py`, which
/// runs every case through the `SimpleRefuter` harness of
/// `tests/causal_refuters/base.py`: the refuted effect is compared against the
/// known effect of the simulated outcome, which is zero, and the tolerance of the
/// case decides whether the refutation passes.
///
/// The mirrored cases, with the tolerance and the estimator of the upstream:
///
/// * `default_continuous_treatment` — the default transformation list, the
///   instrumental variable estimator, tolerance 0.03.
/// * `default_binary_treatment` — the default list, the propensity score matching
///   estimator, tolerance 0.1.
/// * `randomly_generated_continuous_treatment` — `[zero, noise(1)]`, the
///   instrumental variable estimator, tolerance 0.05.
/// * `randomly_generated_binary_treatment` — `[zero, noise(1)]`, propensity score
///   matching, tolerance 0.05.
/// * `permute_data_continuous_treatment` — `[permute(1)]`, the instrumental
///   variable estimator, tolerance 0.03.
/// * `permute_data_binary_treatment` — `[permute(1)]`, the linear regression,
///   tolerance 0.1.
/// * `internal_linear_regression_continuous_treatment` —
///   `[linear_regression, zero, noise(1)]`, the instrumental variable estimator,
///   tolerance 0.01. The list carries an estimator, so the refuter buckets the
///   treatment and reports one refutation per bucket.
/// * `internal_knn_continuous_treatment` — `[knn(5), zero, noise(1)]`, the
///   instrumental variable estimator, tolerance 0.2.
/// * `custom_function_linear_regression_with_noise_continuous_treatment` —
///   `[simple_linear_outcome_model, noise(1)]`, the instrumental variable
///   estimator, tolerance 0.2.
/// * `custom_function_linear_regression_with_permute_continuous_treatment` —
///   `[permute(0.5), simple_linear_outcome_model, noise(1)]`, the linear
///   regression, tolerance 0.2.
/// * `internal_random_forest_continuous_treatment` —
///   `[random_forest(20), zero, noise(1)]`, the instrumental variable estimator,
///   tolerance 0.01. The list carries an estimator, so the refuter buckets the
///   treatment and reports one refutation per bucket.
///
/// The cases that are not mirrored:
///
/// * The four whose transformation list names an estimator the port does not have
///   — `svm` and `neural_network`, two treatments each.
/// * `custom_function_linear_regression_with_noise_binary_treatment` and
///   `custom_function_linear_regression_with_permute_binary_treatment`, which the
///   upstream marks `xfail` itself.
/// * The binary treatment cases whose transformation list carries an estimator.
///   The buckets of such a list are cut over the ranges of every column of the
///   frame, and a binary treatment spans one unit while the outcome of the same
///   frame spans tens, so the edges of `Z0, W0, v0, y` are `1.0, 5.5, 1.0, 24`
///   over the same divisor, which does not increase, and `pandas.cut` raises
///   `ValueError: bins must increase monotonically`. The port aborts with the same
///   message, so the case has no assertion to mirror.
///
/// Two values of the fixture differ from the upstream suite, and both are
/// deliberate:
///
/// * **The number of simulations is ten rather than two.** The refutation of a
///   case is the mean of the estimates of its simulations, and the estimator of
///   the port re-fits on a permuted or a noised outcome, whose estimate is
///   dominated by the sampling error of the estimator when a single simulation
///   decides it. The upstream suite fixes the numpy seed of its cases
///   (`tests/conftest.py`), so its two simulations are one draw that happens to
///   clear the tolerance; a port with another generator cannot rely on that, and
///   ten simulations bring the sampling error of the mean well below every
///   tolerance of the suite. Measured on the permutation case of the instrumental
///   variable estimator at 20000 rows: 0.0348 with two simulations, 0.0009 with
///   ten, 0.0041 with thirty and 0.0023 with a hundred, against a tolerance of
///   0.03.
/// * **The rows are 20000 rather than the 100000 of the upstream continuous
///   cases.** The assertions are tolerances on a near-zero effect, which the
///   smaller fixture decides the same way, and the four backends of the gate would
///   not finish the larger one. The columns and their order are the ones the port
///   generates, because the bucketing of the estimator branch reads them.

///|
/// The dataset of the upstream cases: a confounder, an instrument and one
/// treatment, in the column order the port generates (`Z0, W0, v0, y`).
fn dummy_outcome_dataset(
  continuous : Bool,
  num_samples : Int32,
) -> @datasets.Dataset {
  @datasets.linear_dataset(
    SEED,
    num_samples,
    @datasets.LinearConfig::new(
      num_common_causes=1,
      num_instruments=1,
      treatment_is_binary=!continuous,
    ),
  )
}

///|
/// The dataset of the upstream cases that have no instrument.
fn dummy_outcome_confounded_dataset(num_samples : Int32) -> @datasets.Dataset {
  @datasets.linear_dataset(
    SEED,
    num_samples,
    @datasets.LinearConfig::confounded(),
  )
}

///|
/// The instrumental variable estimator of the dataset, fitted on it.
fn dummy_outcome_iv(dataset : @datasets.Dataset) -> @estimators.CausalEstimator {
  let estimator = @estimators.CausalEstimator::instrumental_variable(
    backdoor_estimand(dataset),
    "Z0",
  )
  estimator.fit(dataset.frame(), [])
  estimator
}

///|
/// The propensity score matching estimator of the dataset, fitted on it.
fn dummy_outcome_psm(
  dataset : @datasets.Dataset,
) -> @estimators.CausalEstimator {
  let estimator = @estimators.CausalEstimator::propensity_score_matching(
    backdoor_estimand(dataset),
  )
  estimator.fit(dataset.frame(), [])
  estimator
}

///|
/// The linear regression estimator of the dataset, fitted on it.
fn dummy_outcome_linear(
  dataset : @datasets.Dataset,
) -> @estimators.CausalEstimator {
  let estimator = @estimators.CausalEstimator::linear_regression(
    backdoor_estimand(dataset),
  )
  estimator.fit(dataset.frame(), [])
  estimator
}

///|
/// The refutations of the case.
fn dummy_outcome_refute(
  dataset : @datasets.Dataset,
  estimator : @estimators.CausalEstimator,
  transformations : Array[@refuters.Transformation],
  seed : UInt64,
) -> Array[@refuters.CausalRefutation] {
  @refuters.refute_dummy_outcome(
    estimator,
    backdoor_estimand(dataset),
    dataset.frame(),
    dataset.outcome(),
    dataset.treatments()[0],
    10,
    1.0,
    0.0,
    "ate",
    @utils.Random::new(seed),
    transformations~,
  )
}

///|
/// The model of the upstream `simple_linear_outcome_model`, which predicts the
/// outcome from the first two covariates of the frame.
///
/// The upstream fits nothing: its callable returns a function that adds the first
/// column, twice the second one and three, so the port returns the same prediction
/// for the training rows and for the rows to predict.
fn simple_linear_outcome_model(
  x_train : @api.DataFrame,
  _outcome_train : Array[Double],
  x_validation : @api.DataFrame,
) -> (Array[Double], Array[Double]) {
  (simple_linear_prediction(x_train), simple_linear_prediction(x_validation))
}

///|
/// The prediction of the upstream `simple_linear_outcome_model` on the frame.
fn simple_linear_prediction(frame : @api.DataFrame) -> Array[Double] {
  let names = frame.numeric_column_names()
  let first = frame.numeric(names[0])
  let second = frame.numeric(names[1])
  let out : Array[Double] = []
  for i = 0; i < frame.nrows(); i = i + 1 {
    out.push(first[i] + 2.0 * second[i] + 3.0)
  }
  out
}

///|
test "the default transformation drives the effect of a continuous treatment to zero" {
  let dataset = dummy_outcome_dataset(true, 20000)
  let refutations = dummy_outcome_refute(
    dataset,
    dummy_outcome_iv(dataset),
    @refuters.dummy_outcome_default_transformations(),
    21UL,
  )
  assert_eq(refutations.length(), 1)
  assert_true(refutations[0].new_effect().abs() < 0.03)
  assert_eq(refutations[0].refutation_type(), "Refute: Use a Dummy Outcome")
  assert_eq(refutations[0].estimated_effect(), 0.0)
}

///|
test "the default transformation drives the effect of a binary treatment to zero" {
  let dataset = dummy_outcome_confounded_dataset(20000)
  let refutations = dummy_outcome_refute(
    dataset,
    dummy_outcome_psm(dataset),
    @refuters.dummy_outcome_default_transformations(),
    22UL,
  )
  assert_eq(refutations.length(), 1)
  assert_true(refutations[0].new_effect().abs() < 0.1)
}

///|
test "the noise transformation drives the effect of a continuous treatment to zero" {
  let dataset = dummy_outcome_dataset(true, 20000)
  let transformations = [
    @refuters.Transformation::zero(),
    @refuters.Transformation::noise(1.0),
  ]
  let refutations = dummy_outcome_refute(
    dataset,
    dummy_outcome_iv(dataset),
    transformations,
    23UL,
  )
  assert_eq(refutations.length(), 1)
  assert_true(refutations[0].new_effect().abs() < 0.05)
}

///|
test "the noise transformation drives the effect of a binary treatment to zero" {
  let dataset = dummy_outcome_confounded_dataset(20000)
  let transformations = [
    @refuters.Transformation::zero(),
    @refuters.Transformation::noise(1.0),
  ]
  let refutations = dummy_outcome_refute(
    dataset,
    dummy_outcome_psm(dataset),
    transformations,
    24UL,
  )
  assert_eq(refutations.length(), 1)
  assert_true(refutations[0].new_effect().abs() < 0.05)
}

///|
test "the permutation transformation drives the effect of a continuous treatment to zero" {
  let dataset = dummy_outcome_dataset(true, 20000)
  let refutations = dummy_outcome_refute(
    dataset,
    dummy_outcome_iv(dataset),
    [@refuters.Transformation::permute(1.0)],
    25UL,
  )
  assert_eq(refutations.length(), 1)
  assert_true(refutations[0].new_effect().abs() < 0.03)
}

///|
test "the permutation transformation drives the effect of a binary treatment to zero" {
  let dataset = dummy_outcome_confounded_dataset(20000)
  let refutations = dummy_outcome_refute(
    dataset,
    dummy_outcome_linear(dataset),
    [@refuters.Transformation::permute(1.0)],
    26UL,
  )
  assert_eq(refutations.length(), 1)
  assert_true(refutations[0].new_effect().abs() < 0.1)
}

///|
test "the inner linear regression reports one refutation per bucket of the treatment" {
  let dataset = dummy_outcome_dataset(true, 20000)
  let transformations = [
    @refuters.Transformation::linear_regression(),
    @refuters.Transformation::zero(),
    @refuters.Transformation::noise(1.0),
  ]
  let refutations = dummy_outcome_refute(
    dataset,
    dummy_outcome_iv(dataset),
    transformations,
    27UL,
  )
  // The frame holds four numeric columns, so the ranges of its columns are four
  // edges, which cut the treatment into three buckets.
  assert_eq(refutations.length(), 3)
  for refutation in refutations {
    assert_true(refutation.new_effect().abs() < 0.01)
    assert_eq(refutation.estimated_effect(), 0.0)
  }
}

///|
test "the inner nearest neighbours report one refutation per bucket of the treatment" {
  // The nearest neighbours cost the product of the training rows and the rows to
  // predict, so this case runs on a smaller fixture than the others. Its
  // assertion is the tolerance of the upstream case, which the smaller fixture
  // still decides: the prediction of the neighbours is replaced by zero and a
  // noise before the estimator is refitted, so it only reaches the rows the model
  // was fitted on.
  let dataset = dummy_outcome_dataset(true, 2000)
  let transformations = [
    @refuters.Transformation::nearest_neighbour(5),
    @refuters.Transformation::zero(),
    @refuters.Transformation::noise(1.0),
  ]
  let refutations = dummy_outcome_refute(
    dataset,
    dummy_outcome_iv(dataset),
    transformations,
    28UL,
  )
  assert_eq(refutations.length(), 3)
  for refutation in refutations {
    assert_true(refutation.new_effect().abs() < 0.2)
  }
}

///|
/// test "the inner random forest reports one refutation per bucket of the
/// treatment"
///
/// This is the port of the upstream test
/// `test_refutation_dummy_outcome_refuter_internal_random_forest_continuous_treatment`.
///
/// The assertion is the tolerance of the upstream case, which the fixture of
/// the port decides: the transformation list of the upstream replaces the
/// outcome by zero right after the forest, so the dummy outcome is a white
/// noise and the refuted effect is the sampling error of the estimator. That
/// tolerance is one hundredth, the tightest of the suite, so the case runs on
/// the same rows as the other ones of the continuous treatment: on a smaller
/// fixture the sampling error of the estimator of the last bucket is of the
/// order of the tolerance.
test "the inner random forest reports one refutation per bucket of the treatment" {
  let dataset = dummy_outcome_dataset(true, 20000)
  let transformations = [
    @refuters.Transformation::random_forest(20),
    @refuters.Transformation::zero(),
    @refuters.Transformation::noise(1.0),
  ]
  let refutations = dummy_outcome_refute(
    dataset,
    dummy_outcome_iv(dataset),
    transformations,
    31UL,
  )
  assert_eq(refutations.length(), 3)
  for refutation in refutations {
    assert_true(refutation.new_effect().abs() < 0.01)
  }
}

///|
test "the custom model with a noise drives the effect of a continuous treatment to zero" {
  let dataset = dummy_outcome_dataset(true, 20000)
  let transformations = [
    @refuters.Transformation::estimate(simple_linear_outcome_model),
    @refuters.Transformation::noise(1.0),
  ]
  let refutations = dummy_outcome_refute(
    dataset,
    dummy_outcome_iv(dataset),
    transformations,
    29UL,
  )
  assert_eq(refutations.length(), 3)
  for refutation in refutations {
    assert_true(refutation.new_effect().abs() < 0.2)
  }
}

///|
test "the permuted custom model with a noise drives the effect to zero" {
  let dataset = dummy_outcome_dataset(true, 20000)
  let transformations = [
    @refuters.Transformation::permute(0.5),
    @refuters.Transformation::estimate(simple_linear_outcome_model),
    @refuters.Transformation::noise(1.0),
  ]
  let refutations = dummy_outcome_refute(
    dataset,
    dummy_outcome_linear(dataset),
    transformations,
    30UL,
  )
  assert_eq(refutations.length(), 3)
  for refutation in refutations {
    assert_true(refutation.new_effect().abs() < 0.2)
  }
}
