///|
/// The tests of the independence tests.
///
/// The cases mirror the upstream test files
/// `tests/gcm/independence_test/test_generalised_cov_measure.py` and
/// `tests/gcm/independence_test/test_regression.py`: the marginal and the
/// conditional test of independent and of dependent data, for both the
/// regression based test and the generalised covariance measure.
///
/// The upstream case `test_given_categorical_X_or_Y_when_perform_generalised_cov_based_independence_test_then_raise_error`
/// asks for a `ValueError` when X or Y holds categories. MoonBit has no
/// exception, so the port aborts with a message and there is nothing to assert;
/// the check itself is the `is_discrete` test at the top of
/// `generalised_cov_based`.
///
/// The fixture is generated with the deterministic generator of the `utils`
/// package, and the expected numbers are the p-values the upstream
/// `dowhy.gcm.independence_test` produces on the very same rows, which
/// `_verify/gcm_shapley_reference.py` prints.
///
/// The upstream draws its folds and its basis points from the global numpy
/// generator, and the port draws them from its own generator, so the p-values
/// of the regression based test differ in their details. The tests therefore
/// assert the decision of the upstream code, and the value of the p-value
/// with a tolerance that covers the difference.

///|
/// The seed of the fixture.
const INDEPENDENCE_SEED : UInt64 = 2024UL

///|
/// The number of samples of the fixture.
const INDEPENDENCE_NUM_SAMPLES : Int32 = 1000

///|
/// The samples of the independence test: the conditioning variable z, the
/// irrelevant variable w and the two variables x and y.
///
/// The draws happen in the order of the reference script: the two normal
/// vectors first, and then the two uniform vectors that shift z into x and y.
fn independence_fixture() -> (
  @utils.Matrix,
  @utils.Matrix,
  @utils.Matrix,
  @utils.Matrix,
) {
  let rng = @utils.Random::new(INDEPENDENCE_SEED)
  let z = normal_column(rng, INDEPENDENCE_NUM_SAMPLES)
  let w = normal_column(rng, INDEPENDENCE_NUM_SAMPLES)
  let x = exponential_column(z, rng)
  let y = exponential_column(z, rng)
  (z, w, x, y)
}

///|
/// A column of standard normal samples.
fn normal_column(rng : @utils.Random, count : Int32) -> @utils.Matrix {
  let values : Array[Double] = []
  for _ in 0..<count {
    values.push(rng.next_normal())
  }
  @utils.Matrix::from_columns([values])
}

///|
/// The column of the exponential of the given values shifted by a uniform
/// sample.
fn exponential_column(
  base : @utils.Matrix,
  rng : @utils.Random,
) -> @utils.Matrix {
  let values = base.col(0)
  let out : Array[Double] = []
  for i = 0; i < values.length(); i = i + 1 {
    out.push(@utils.exp(values[i] + rng.next_double()))
  }
  @utils.Matrix::from_columns([out])
}

///|
/// The p-value of the regression based test with the average of the p-values
/// of the folds, which is the adjustment the upstream code uses.
fn average_p_value(p_values : Array[Double]) -> Double {
  @gcm.merge_p_values_average(p_values, false, @utils.Random::new(0UL))
}

///|
/// test "the regression based test finds independent variables independent"
///
/// The variables x and y are independent given z, because they only share the
/// variable z.
test "the regression based test finds independent variables independent" {
  let (z, _, x, y) = independence_fixture()
  let p_value = @gcm.regression_based(
    x,
    y,
    Some(z),
    40,
    3,
    average_p_value,
    -1,
    @utils.Random::new(INDEPENDENCE_SEED),
  )
  assert_true(p_value > 0.05)
  assert_true((p_value - 1.0).abs() < 0.05)
}

///|
/// test "the regression based test finds dependent variables dependent"
///
/// The variables x and y are dependent when the conditioning variable is the
/// irrelevant variable w.
test "the regression based test finds dependent variables dependent" {
  let (_, w, x, y) = independence_fixture()
  let p_value = @gcm.regression_based(
    x,
    y,
    Some(w),
    40,
    3,
    average_p_value,
    -1,
    @utils.Random::new(INDEPENDENCE_SEED),
  )
  assert_true(p_value < 0.05)
}

///|
/// test "the regression based test finds independent variables independent without a conditioning variable"
test "the regression based test finds independent variables independent without a conditioning variable" {
  let (_, w, x, _) = independence_fixture()
  let p_value = @gcm.regression_based(
    x,
    w,
    None,
    40,
    3,
    average_p_value,
    -1,
    @utils.Random::new(INDEPENDENCE_SEED),
  )
  assert_true(p_value > 0.05)
  assert_true((p_value - 1.0).abs() < 0.05)
}

///|
/// test "the regression based test finds dependent variables dependent without a conditioning variable"
test "the regression based test finds dependent variables dependent without a conditioning variable" {
  let (_, _, x, y) = independence_fixture()
  let p_value = @gcm.regression_based(
    x,
    y,
    None,
    40,
    3,
    average_p_value,
    -1,
    @utils.Random::new(INDEPENDENCE_SEED),
  )
  assert_true(p_value < 0.05)
}

///|
/// test "the generalised covariance measure finds independent variables independent"
///
/// The variables x and y are independent given z, because they only share the
/// variable z. The upstream code picks the prediction model automatically and
/// the port uses the ordinary least squares fit, so the p-values differ; the
/// decision is the same.
test "the generalised covariance measure finds independent variables independent" {
  let (z, _, x, y) = independence_fixture()
  let p_value = @gcm.generalised_cov_based(x, y, Some(z))
  assert_true(p_value > 0.05)
  assert_true((p_value - 0.306445802815).abs() < 0.3)
}

///|
/// test "the generalised covariance measure finds dependent variables dependent"
test "the generalised covariance measure finds dependent variables dependent" {
  let (_, w, x, y) = independence_fixture()
  let p_value = @gcm.generalised_cov_based(x, y, Some(w))
  assert_true(p_value < 0.05)
  assert_true((p_value - 0.014678091031).abs() < 0.005)
}

///|
/// test "the generalised covariance measure finds independent variables independent without a conditioning variable"
test "the generalised covariance measure finds independent variables independent without a conditioning variable" {
  let (_, w, x, _) = independence_fixture()
  let p_value = @gcm.generalised_cov_based(x, w, None)
  assert_true(p_value > 0.05)
  assert_true((p_value - 0.752364981838).abs() < 1.0e-9)
}

///|
/// test "the generalised covariance measure finds dependent variables dependent without a conditioning variable"
test "the generalised covariance measure finds dependent variables dependent without a conditioning variable" {
  let (_, _, x, y) = independence_fixture()
  let p_value = @gcm.generalised_cov_based(x, y, None)
  assert_true(p_value < 0.05)
  assert_true((p_value - 0.014764335517).abs() < 1.0e-9)
}

///|
/// The seed of the categorical fixture.
///
/// The upstream draws this fixture from the global generator of numpy and marks
/// its two cases as flaky, because the p-value of the conditional test moves
/// with the draw. The port draws its rows from its own generator, so the seed
/// is the one the port settles on.
const INDEPENDENCE_CATEGORICAL_SEED : UInt64 = 2024UL

///|
/// The categorical fixture of the upstream test.
///
/// The upstream draws `x` from the normal distribution, turns it into the
/// binary category `z`, which is a zero for a positive `x` and a one for a
/// negative one, and builds `y` as the category plus a Gaussian noise. The
/// variable `x` and the variable `y` are therefore independent given `z`, and
/// they are dependent once `z` is permuted.
///
/// The draws happen in the order of the upstream: the whole column of `x`
/// first, and then the whole column of the noise of `y`.
fn independence_categorical_fixture() -> (
  @utils.Matrix,
  @utils.Matrix,
  @api.DataFrame,
) {
  let rng = @utils.Random::new(INDEPENDENCE_CATEGORICAL_SEED)
  let x : Array[Double] = []
  let labels : Array[String] = []
  for i = 0; i < INDEPENDENCE_NUM_SAMPLES; i = i + 1 {
    let value = rng.next_normal()
    x.push(value)
    // The upstream labels the zero with `Class 1` and the one with `Class 2`.
    labels.push(if value > 0.0 { "Class 1" } else { "Class 2" })
  }
  let y : Array[Double] = []
  for i = 0; i < INDEPENDENCE_NUM_SAMPLES; i = i + 1 {
    let category = if x[i] > 0.0 { 0.0 } else { 1.0 }
    y.push(category + rng.next_normal())
  }
  let frame = @api.DataFrame::new(
    ["Z"],
    Map([("Z", @api.Column::discrete(labels))]),
  )
  (@utils.Matrix::from_columns([x]), @utils.Matrix::from_columns([y]), frame)
}

///|
/// A permutation of the labels, drawn with the given generator.
///
/// This is the port of the `np.random.choice(..., replace=False)` of the
/// upstream, which draws a permutation of the rows.
fn shuffled_labels(
  rng : @utils.Random,
  labels : Array[String],
) -> Array[String] {
  let out = labels.copy()
  let n = out.length()
  for i = n - 1; i > 0; i = i - 1 {
    let j = rng.next_int(i + 1)
    let held = out[i]
    out[i] = out[j]
    out[j] = held
  }
  out
}

///|
/// The generalised covariance measure finds the categorical fixture independent
/// given the category.
test "the generalised covariance measure finds independent variables independent with a categorical conditioning variable" {
  let (x, y, z) = independence_categorical_fixture()
  let p_value = @gcm.generalised_cov_based_with_categorical(x, y, Some(z))
  assert_true(p_value > 0.05)
}

///|
/// The generalised covariance measure finds the categorical fixture dependent
/// once the category is permuted.
test "the generalised covariance measure finds dependent variables dependent with a permuted categorical conditioning variable" {
  let (x, y, z) = independence_categorical_fixture()
  let rng = @utils.Random::new(INDEPENDENCE_CATEGORICAL_SEED + 1)
  let permuted = @api.DataFrame::new(
    ["Z"],
    Map([("Z", @api.Column::discrete(shuffled_labels(rng, z.discrete("Z"))))]),
  )
  let p_value = @gcm.generalised_cov_based_with_categorical(
    x,
    y,
    Some(permuted),
  )
  assert_true(p_value < 0.05)
}
