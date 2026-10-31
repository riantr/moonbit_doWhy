///|
/// The tests of the independence tests.
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
