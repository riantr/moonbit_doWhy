///| Tests for the dummy outcome refuter.
///
/// The cases mirror `tests/causal_refuters/test_dummy_outcome_refuter.py`, which
/// runs every case through the `SimpleRefuter` harness of
/// `tests/causal_refuters/base.py`: the refuted effect is compared against the
/// known effect of the simulated outcome, which is zero, and the tolerance of the
/// case decides whether the refutation passes.
///
/// The upstream holds twenty cases, ten of them with a continuous treatment and
/// ten of them with a binary one. All twenty are mirrored here.
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
/// * `internal_linear_regression_binary_treatment` — the same list, the
///   propensity score matching estimator, tolerance 0.2.
/// * `internal_knn_continuous_treatment` — `[knn(5), zero, noise(1)]`, the
///   instrumental variable estimator, tolerance 0.2.
/// * `internal_knn_binary_treatment` — the same list, the propensity score
///   matching estimator, tolerance 0.2.
/// * `custom_function_linear_regression_with_noise_continuous_treatment` —
///   `[simple_linear_outcome_model, noise(1)]`, the instrumental variable
///   estimator, tolerance 0.2.
/// * `custom_function_linear_regression_with_noise_binary_treatment` — the same
///   list, the linear regression, tolerance 0.2. The upstream marks the case
///   `xfail`, and the port reproduces its failure.
/// * `custom_function_linear_regression_with_permute_continuous_treatment` —
///   `[permute(0.5), simple_linear_outcome_model, noise(1)]`, the linear
///   regression, tolerance 0.2.
/// * `custom_function_linear_regression_with_permute_binary_treatment` — the same
///   list, the propensity score matching estimator, tolerance 0.2. The upstream
///   marks the case `xfail` as well.
/// * `internal_random_forest_continuous_treatment` —
///   `[random_forest(20), zero, noise(1)]`, the instrumental variable estimator,
///   tolerance 0.01. The list carries an estimator, so the refuter buckets the
///   treatment and reports one refutation per bucket.
/// * `internal_random_forest_binary_treatment` — the same list, the propensity
///   score matching estimator, tolerance 0.1.
/// * `internal_neural_network_continuous_treatment` —
///   `[neural_network([5, 2], 1e-5), zero, noise(1)]`, the instrumental variable
///   estimator, tolerance 0.01. The list carries an estimator, so the refuter
///   buckets the treatment and reports one refutation per bucket.
/// * `internal_neural_network_binary_treatment` — the same list, the propensity
///   score matching estimator, tolerance 0.1.
/// * `internal_svm_continuous_treatment` — `[support_vector_machine(1, 0.2),
///   zero, noise(1)]`, the instrumental variable estimator, tolerance 0.01. The
///   list carries an estimator, so the refuter buckets the treatment and
///   reports one refutation per bucket. The case runs on the ten thousand rows
///   of the upstream case, because the regressor is expensive.
/// * `internal_svm_binary_treatment` — the same list, the propensity score
///   matching estimator, tolerance 0.1.
///
/// Four values of the fixture differ from the upstream suite, and all four are
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
///   cases and the 1000 of its binary cases.** The assertions are tolerances on a
///   near-zero effect, which the smaller fixture decides the same way, and the
///   four backends of the gate would not finish the larger one. The columns and
///   their order are the ones the port generates, because the bucketing of the
///   estimator branch reads them.
/// * **Every bucket of a case is checked, and not only the first one.** The
///   upstream takes the first refutation of the list of the case and compares it
///   with the tolerance, and the port compares every refutation with it. The
///   buckets of a binary treatment are two, the buckets of a continuous one are
///   three, and every one of them clears the tolerance of its case, so the two
///   ways of reading the result decide the same way.
/// * **The binary treatment is a numeric column of zeros and ones rather than a
///   column of booleans.** The upstream casts its binary treatment to the dtype
///   of a boolean and groups such a treatment by its values, so a binary
///   treatment has two buckets. The port has no dtype of its own for a column,
///   so it recognises a treatment of booleans by its values: a treatment whose
///   values are only zero and one is grouped by them.
///
/// The data set of the binary cases carries an instrument, like the data set of
/// the continuous cases, because the data set of the upstream carries one in
/// both cases. The covariates of a bucket are therefore the confounder and the
/// instrument, and the custom model of the upstream, which adds the first
/// covariate to twice the second one, needs the two of them.

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
  let dataset = dummy_outcome_dataset(false, 20000)
  let refutations = dummy_outcome_refute(
    dataset,
    dummy_outcome_psm(dataset),
    @refuters.dummy_outcome_default_transformations(),
    51UL,
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
  let dataset = dummy_outcome_dataset(false, 20000)
  let transformations = [
    @refuters.Transformation::zero(),
    @refuters.Transformation::noise(1.0),
  ]
  let refutations = dummy_outcome_refute(
    dataset,
    dummy_outcome_psm(dataset),
    transformations,
    52UL,
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
  let dataset = dummy_outcome_dataset(false, 20000)
  let refutations = dummy_outcome_refute(
    dataset,
    dummy_outcome_linear(dataset),
    [@refuters.Transformation::permute(1.0)],
    53UL,
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
/// test "the inner linear regression reports one refutation per bucket of a
/// binary treatment"
///
/// This is the port of the upstream test
/// `test_refutation_dummy_outcome_refuter_internal_linear_regression_binary_treatment`.
///
/// The treatment is binary, so its buckets are its two values, the way the
/// upstream groups a treatment of booleans. The measured effects are 0.0108 and
/// -0.0014, against the tolerance of 0.2 of the upstream case.
test "the inner linear regression reports one refutation per bucket of a binary treatment" {
  let dataset = dummy_outcome_dataset(false, 20000)
  let transformations = [
    @refuters.Transformation::linear_regression(),
    @refuters.Transformation::zero(),
    @refuters.Transformation::noise(1.0),
  ]
  let refutations = dummy_outcome_refute(
    dataset,
    dummy_outcome_psm(dataset),
    transformations,
    56UL,
  )
  assert_eq(refutations.length(), 2)
  for refutation in refutations {
    assert_true(refutation.new_effect().abs() < 0.2)
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
/// test "the inner nearest neighbours report one refutation per bucket of a
/// binary treatment"
///
/// This is the port of the upstream test
/// `test_refutation_dummy_outcome_refuter_internal_knn_binary_treatment`.
///
/// The case runs on the two thousand rows of the continuous case, because the
/// neighbours cost the product of the training rows and the rows to predict. The
/// measured effects are 0.0132 and -0.1100, against the tolerance of 0.2 of the
/// upstream case.
test "the inner nearest neighbours report one refutation per bucket of a binary treatment" {
  let dataset = dummy_outcome_dataset(false, 2000)
  let transformations = [
    @refuters.Transformation::nearest_neighbour(5),
    @refuters.Transformation::zero(),
    @refuters.Transformation::noise(1.0),
  ]
  let refutations = dummy_outcome_refute(
    dataset,
    dummy_outcome_psm(dataset),
    transformations,
    57UL,
  )
  assert_eq(refutations.length(), 2)
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
/// test "the inner random forest reports one refutation per bucket of a binary
/// treatment"
///
/// This is the port of the upstream test
/// `test_refutation_dummy_outcome_refuter_internal_random_forest_binary_treatment`.
///
/// The measured effects are 0.0007 and -0.0055, against the tolerance of 0.1 of
/// the upstream case.
test "the inner random forest reports one refutation per bucket of a binary treatment" {
  let dataset = dummy_outcome_dataset(false, 20000)
  let transformations = [
    @refuters.Transformation::random_forest(20),
    @refuters.Transformation::zero(),
    @refuters.Transformation::noise(1.0),
  ]
  let refutations = dummy_outcome_refute(
    dataset,
    dummy_outcome_psm(dataset),
    transformations,
    59UL,
  )
  assert_eq(refutations.length(), 2)
  for refutation in refutations {
    assert_true(refutation.new_effect().abs() < 0.1)
  }
}

///|
/// test "the inner neural network reports one refutation per bucket of the
/// treatment"
///
/// This is the port of the upstream test
/// `test_refutation_dummy_outcome_refuter_internal_neural_network_continuous_treatment`.
///
/// The network has the two hidden layers of the upstream case, of five and of two
/// units, and the penalty of its weights is a hundredth of a ten-thousandth, the
/// parameters the upstream gives to scikit-learn. The assertion is the tolerance
/// of the upstream case, which is one hundredth: the transformation list of the
/// upstream replaces the outcome by zero right after the network, so the dummy
/// outcome is a white noise and the refuted effect is the sampling error of the
/// estimator.
///
/// The case is the slowest of the suite, because the network is fitted once per
/// bucket and per simulation, the way the upstream fits it.
test "the inner neural network reports one refutation per bucket of the treatment" {
  let dataset = dummy_outcome_dataset(true, 20000)
  let transformations = [
    @refuters.Transformation::neural_network([5, 2], 0.00001),
    @refuters.Transformation::zero(),
    @refuters.Transformation::noise(1.0),
  ]
  let refutations = dummy_outcome_refute(
    dataset,
    dummy_outcome_iv(dataset),
    transformations,
    32UL,
  )
  assert_eq(refutations.length(), 3)
  for refutation in refutations {
    assert_true(refutation.new_effect().abs() < 0.01)
  }
}

///|
/// test "the inner neural network reports one refutation per bucket of a binary
/// treatment"
///
/// This is the port of the upstream test
/// `test_refutation_dummy_outcome_refuter_internal_neural_network_binary_treatment`.
///
/// The measured effects are 0.0040 and -0.0221, against the tolerance of 0.1 of
/// the upstream case.
test "the inner neural network reports one refutation per bucket of a binary treatment" {
  let dataset = dummy_outcome_dataset(false, 20000)
  let transformations = [
    @refuters.Transformation::neural_network([5, 2], 0.00001),
    @refuters.Transformation::zero(),
    @refuters.Transformation::noise(1.0),
  ]
  let refutations = dummy_outcome_refute(
    dataset,
    dummy_outcome_psm(dataset),
    transformations,
    60UL,
  )
  assert_eq(refutations.length(), 2)
  for refutation in refutations {
    assert_true(refutation.new_effect().abs() < 0.1)
  }
}

///|
/// test "the inner support vector regressor reports one refutation per bucket
/// of the treatment"
///
/// This is the port of the upstream test
/// `test_refutation_dummy_outcome_refuter_internal_svm_continuous_treatment`.
///
/// The regressor has the penalty and the width of the tube of the upstream
/// case, which gives them to scikit-learn. The assertion is the tolerance of
/// the upstream case, which is one hundredth: the transformation list of the
/// upstream replaces the outcome by zero right after the regressor, so the
/// dummy outcome is a white noise and the refuted effect is the sampling error
/// of the estimator.
///
/// The case runs on the ten thousand rows of the upstream case and not on the
/// rows of the other continuous cases, which are twenty thousand: the
/// regressor is fitted once per bucket and per simulation, and the fit of the
/// port costs about a third of a second on the rows of the upstream case.
test "the inner support vector regressor reports one refutation per bucket of the treatment" {
  let dataset = dummy_outcome_dataset(true, 10000)
  let transformations = [
    @refuters.Transformation::support_vector_machine(1.0, 0.2),
    @refuters.Transformation::zero(),
    @refuters.Transformation::noise(1.0),
  ]
  let refutations = dummy_outcome_refute(
    dataset,
    dummy_outcome_iv(dataset),
    transformations,
    33UL,
  )
  assert_eq(refutations.length(), 3)
  for refutation in refutations {
    assert_true(refutation.new_effect().abs() < 0.01)
  }
}

///|
/// test "the inner support vector regressor reports one refutation per bucket
/// of a binary treatment"
///
/// This is the port of the upstream test
/// `test_refutation_dummy_outcome_refuter_internal_svm_binary_treatment`.
///
/// The case runs on the ten thousand rows of the continuous case, because the
/// regressor is fitted once per bucket and per simulation. The measured effects
/// are -0.0225 and -0.0559, against the tolerance of 0.1 of the upstream case.
test "the inner support vector regressor reports one refutation per bucket of a binary treatment" {
  let dataset = dummy_outcome_dataset(false, 10000)
  let transformations = [
    @refuters.Transformation::support_vector_machine(1.0, 0.2),
    @refuters.Transformation::zero(),
    @refuters.Transformation::noise(1.0),
  ]
  let refutations = dummy_outcome_refute(
    dataset,
    dummy_outcome_psm(dataset),
    transformations,
    58UL,
  )
  assert_eq(refutations.length(), 2)
  for refutation in refutations {
    assert_true(refutation.new_effect().abs() < 0.1)
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
/// test "the custom model with a noise does not drive the effect of a binary
/// treatment to zero"
///
/// This is the port of the upstream test
/// `test_refutation_dummy_outcome_refuter_custom_function_linear_regression_with_noise_binary_treatment`,
/// which the upstream marks `xfail`.
///
/// The upstream's case fails its own assertion: its refuted effect is 0.513615
/// and its tolerance is 0.2, so the refutation does not clear the tolerance. The
/// port reproduces the failure: its effects are 0.5009 and 0.5001, so neither of
/// them clears the tolerance either. The case asserts the failure.
test "the custom model with a noise does not drive the effect of a binary treatment to zero" {
  let dataset = dummy_outcome_dataset(false, 20000)
  let transformations = [
    @refuters.Transformation::estimate(simple_linear_outcome_model),
    @refuters.Transformation::noise(1.0),
  ]
  let refutations = dummy_outcome_refute(
    dataset,
    dummy_outcome_linear(dataset),
    transformations,
    54UL,
  )
  assert_eq(refutations.length(), 2)
  for refutation in refutations {
    assert_true(refutation.new_effect().abs() >= 0.2)
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

///|
/// test "the permuted custom model with a noise does not drive the effect of a
/// binary treatment to zero"
///
/// This is the port of the upstream test
/// `test_refutation_dummy_outcome_refuter_custom_function_linear_regression_with_permute_binary_treatment`,
/// which the upstream marks `xfail` as well.
///
/// The upstream's case does not pass on numpy 2: its permutation writes the
/// values into the column of the outcome in place, and the column of a pandas
/// frame of pandas 3 is read only, so the case raises `ValueError: assignment
/// destination is read-only` before it reaches its assertion. The port
/// permutes its own copy of the outcome, so it reaches the number of the case,
/// which is 0.4982 and 0.4912, and neither of them clears the tolerance of 0.2
/// of the upstream case. The case asserts the failure the upstream expects.
test "the permuted custom model with a noise does not drive the effect of a binary treatment to zero" {
  let dataset = dummy_outcome_dataset(false, 20000)
  let transformations = [
    @refuters.Transformation::permute(0.5),
    @refuters.Transformation::estimate(simple_linear_outcome_model),
    @refuters.Transformation::noise(1.0),
  ]
  let refutations = dummy_outcome_refute(
    dataset,
    dummy_outcome_psm(dataset),
    transformations,
    55UL,
  )
  assert_eq(refutations.length(), 2)
  for refutation in refutations {
    assert_true(refutation.new_effect().abs() >= 0.2)
  }
}
