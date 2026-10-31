///|
/// The tests of the statistics of the `gcm` package.
///
/// The fixtures are generated with the deterministic generator of the `utils`
/// package, and the expected numbers are the ones the upstream
/// `dowhy.gcm.stats` produces on the very same rows, which
/// `_verify/gcm_stats_reference.py` prints.

///|
/// The seed of the fixture of the F-test.
const STATS_SEED_FTEST : UInt64 = 2024UL

///|
/// The seed of the fixture of the marginal expectation.
const STATS_SEED_MARGINAL : UInt64 = 2025UL

///|
/// The number of rows of the fixtures.
const STATS_FTEST_ROWS : Int32 = 200

///|
const STATS_MARGINAL_ROWS : Int32 = 200

///|
/// The size of the noise of the F-test fixtures.
///
/// The upstream test uses a noise of 0.05, which makes the p-value of the
/// dependent data so small that it underflows to zero and cannot be compared
/// with the port. The noise of 4.0 keeps the p-value a number of a moderate
/// size, while the dependency of the data is still strong enough for the
/// p-value to be below 0.05.
const STATS_FTEST_NOISE : Double = 4.0

///|
/// The size of the noise of the multivariate F-test fixtures.
///
/// The model with two features is compared with a model with one feature, so
/// the extra parameter buys less than the extra feature of the univariate case
/// and the noise has to be smaller for the p-value to be below 0.05.
const STATS_FTEST_NOISE_MULTIVARIATE : Double = 3.0

///|
/// The number of rows of the samples of the marginal expectation.
const STATS_SHAPE_BASELINE_ROWS : Int32 = 34

///|
const STATS_SHAPE_FEATURE_ROWS : Int32 = 123

///|
/// Whether two numbers agree to the tolerance of the comparison.
fn stats_near(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-9
}

///|
/// A column of standard normal draws.
fn stats_normal_column(rng : @utils.Random, count : Int32) -> @utils.Matrix {
  let values : Array[Double] = []
  for _ in 0..<count {
    values.push(rng.next_normal())
  }
  @gcm.column_vector(values)
}

///|
/// The sums of two samples, the second one scaled.
fn stats_scaled_sum(
  a : Array[Double],
  b : Array[Double],
  scale : Double,
) -> Array[Double] {
  let out : Array[Double] = []
  for i = 0; i < a.length(); i = i + 1 {
    out.push(a[i] + scale * b[i])
  }
  out
}

///|
/// A sample of zeros.
fn stats_zeros(count : Int32) -> Array[Double] {
  let out : Array[Double] = []
  for _ in 0..<count {
    out.push(0.0)
  }
  out
}

///|
/// The dependent fixture of the F-test.
///
/// The target is the feature plus a small noise, so the model with the feature
/// is much better than the model without it.
fn ftest_dependent_fixture() -> (
  @utils.Matrix,
  Array[Double],
  @utils.Matrix,
  Array[Double],
) {
  let rng = @utils.Random::new(STATS_SEED_FTEST)
  let x_training = stats_normal_column(rng, STATS_FTEST_ROWS)
  let noise = stats_normal_column(rng, STATS_FTEST_ROWS)
  let y_training = stats_scaled_sum(
    @gcm.matrix_to_vector(x_training),
    @gcm.matrix_to_vector(noise),
    STATS_FTEST_NOISE,
  )
  let x_test = stats_normal_column(rng, STATS_FTEST_ROWS)
  let noise = stats_normal_column(rng, STATS_FTEST_ROWS)
  let y_test = stats_scaled_sum(
    @gcm.matrix_to_vector(x_test),
    @gcm.matrix_to_vector(noise),
    STATS_FTEST_NOISE,
  )
  (x_training, y_training, x_test, y_test)
}

///|
/// The independent fixture of the F-test.
///
/// The target is pure noise, so the feature does not help at all.
fn ftest_independent_fixture() -> (
  @utils.Matrix,
  Array[Double],
  @utils.Matrix,
  Array[Double],
) {
  let rng = @utils.Random::new(STATS_SEED_FTEST)
  let x_training = stats_normal_column(rng, STATS_FTEST_ROWS)
  let noise = stats_normal_column(rng, STATS_FTEST_ROWS)
  let y_training = stats_scaled_sum(
    stats_zeros(STATS_FTEST_ROWS),
    @gcm.matrix_to_vector(noise),
    STATS_FTEST_NOISE,
  )
  let x_test = stats_normal_column(rng, STATS_FTEST_ROWS)
  let noise = stats_normal_column(rng, STATS_FTEST_ROWS)
  let y_test = stats_scaled_sum(
    stats_zeros(STATS_FTEST_ROWS),
    @gcm.matrix_to_vector(noise),
    STATS_FTEST_NOISE,
  )
  (x_training, y_training, x_test, y_test)
}

///|
/// The dependent fixture of the F-test with two features.
///
/// The model with the two features is compared with the model with the one
/// feature, so the error of the smaller model comes from a fit and not from
/// the mean of the target.
fn ftest_multivariate_dependent_fixture() -> (
  @utils.Matrix,
  @utils.Matrix,
  Array[Double],
  @utils.Matrix,
  @utils.Matrix,
  Array[Double],
) {
  let rng = @utils.Random::new(STATS_SEED_FTEST)
  let x1_training = stats_normal_column(rng, STATS_FTEST_ROWS)
  let x2_training = stats_normal_column(rng, STATS_FTEST_ROWS)
  let noise = stats_normal_column(rng, STATS_FTEST_ROWS)
  let y_training = stats_scaled_sum(
    stats_scaled_sum(
      @gcm.matrix_to_vector(x1_training),
      @gcm.matrix_to_vector(x2_training),
      1.0,
    ),
    @gcm.matrix_to_vector(noise),
    STATS_FTEST_NOISE_MULTIVARIATE,
  )
  let x1_test = stats_normal_column(rng, STATS_FTEST_ROWS)
  let x2_test = stats_normal_column(rng, STATS_FTEST_ROWS)
  let noise = stats_normal_column(rng, STATS_FTEST_ROWS)
  let y_test = stats_scaled_sum(
    stats_scaled_sum(
      @gcm.matrix_to_vector(x1_test),
      @gcm.matrix_to_vector(x2_test),
      1.0,
    ),
    @gcm.matrix_to_vector(noise),
    STATS_FTEST_NOISE_MULTIVARIATE,
  )
  (
    stats_two_columns(x1_training, x2_training),
    x1_training,
    y_training,
    stats_two_columns(x1_test, x2_test),
    x1_test,
    y_test,
  )
}

///|
/// The independent fixture of the F-test with two features.
fn ftest_multivariate_independent_fixture() -> (
  @utils.Matrix,
  @utils.Matrix,
  Array[Double],
  @utils.Matrix,
  @utils.Matrix,
  Array[Double],
) {
  let rng = @utils.Random::new(STATS_SEED_FTEST)
  let x1_training = stats_normal_column(rng, STATS_FTEST_ROWS)
  let x2_training = stats_normal_column(rng, STATS_FTEST_ROWS)
  let noise = stats_normal_column(rng, STATS_FTEST_ROWS)
  let y_training = stats_scaled_sum(
    stats_zeros(STATS_FTEST_ROWS),
    @gcm.matrix_to_vector(noise),
    STATS_FTEST_NOISE_MULTIVARIATE,
  )
  let x1_test = stats_normal_column(rng, STATS_FTEST_ROWS)
  let x2_test = stats_normal_column(rng, STATS_FTEST_ROWS)
  let noise = stats_normal_column(rng, STATS_FTEST_ROWS)
  let y_test = stats_scaled_sum(
    stats_zeros(STATS_FTEST_ROWS),
    @gcm.matrix_to_vector(noise),
    STATS_FTEST_NOISE_MULTIVARIATE,
  )
  (
    stats_two_columns(x1_training, x2_training),
    x1_training,
    y_training,
    stats_two_columns(x1_test, x2_test),
    x1_test,
    y_test,
  )
}

///|
/// The matrix of the two given columns.
fn stats_two_columns(a : @utils.Matrix, b : @utils.Matrix) -> @utils.Matrix {
  let out = @utils.Matrix::zeros(a.nrows(), 2)
  for i = 0; i < a.nrows(); i = i + 1 {
    out.set(i, 0, a.get(i, 0))
    out.set(i, 1, b.get(i, 0))
  }
  out
}

///|
/// The fixture of the marginal expectation.
///
/// The features are standard normal and the target is a linear combination of
/// them, like the fixture of the upstream test.
fn marginal_fixture() -> (@utils.Matrix, Array[Double]) {
  let rng = @utils.Random::new(STATS_SEED_MARGINAL)
  let rows : Array[Array[Double]] = []
  for _ in 0..<STATS_MARGINAL_ROWS {
    let row : Array[Double] = []
    for _ in 0..<3 {
      row.push(rng.next_normal())
    }
    rows.push(row)
  }
  let x = @utils.Matrix::from_rows(rows)
  let y : Array[Double] = []
  for i = 0; i < STATS_MARGINAL_ROWS; i = i + 1 {
    y.push(3.0 * x.get(i, 0) + 2.0 * x.get(i, 1) - x.get(i, 2))
  }
  (x, y)
}

///|
/// The matrix with a column of ones in front of its columns.
fn stats_with_intercept(m : @utils.Matrix) -> @utils.Matrix {
  let out = @utils.Matrix::zeros(m.nrows(), m.ncols() + 1)
  for i = 0; i < m.nrows(); i = i + 1 {
    out.set(i, 0, 1.0)
    for j = 0; j < m.ncols(); j = j + 1 {
      out.set(i, j + 1, m.get(i, j))
    }
  }
  out
}

///|
/// The predictions of a linear model whose coefficients start with the
/// intercept.
fn stats_predict_with(
  beta : Array[Double],
  samples : @utils.Matrix,
) -> Array[Double] {
  let out : Array[Double] = []
  for i = 0; i < samples.nrows(); i = i + 1 {
    let mut value = beta[0]
    for j = 0; j < samples.ncols(); j = j + 1 {
      value = value + beta[j + 1] * samples.get(i, j)
    }
    out.push(value)
  }
  out
}

///|
/// The first column of every row of the matrix.
fn stats_first_column(m : @utils.Matrix) -> Array[Double] {
  let out : Array[Double] = []
  for i = 0; i < m.nrows(); i = i + 1 {
    out.push(m.get(i, 0))
  }
  out
}

///|
/// test "the quantile merge returns the adjusted p-value"
test "the quantile merge returns the adjusted p-value" {
  let p_values = [0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.09, 0.1]
  assert_true(stats_near(@gcm.merge_p_values_quantile(p_values, [], 0.5), 0.11))
  assert_true(
    stats_near(@gcm.merge_p_values_quantile(p_values, [], 0.25), 0.13),
  )
  assert_true(
    stats_near(@gcm.merge_p_values_quantile(p_values, [], 0.75), 0.103333333333),
  )
  let with_one = [
    0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.09, 0.1, 1.0,
  ]
  assert_true(stats_near(@gcm.merge_p_values_quantile(with_one, [], 0.5), 0.12))
  assert_true(
    stats_near(@gcm.merge_p_values_quantile([0.9, 0.95, 1.0], [], 0.5), 1.0),
  )
  assert_true(
    stats_near(@gcm.merge_p_values_quantile([0.0, 0.0, 0.0], [], 0.5), 0.0),
  )
  assert_true(stats_near(@gcm.merge_p_values_quantile([0.33], [], 0.5), 0.33))
}

///|
/// test "the quantile merge ignores the values that are not a number"
test "the quantile merge ignores the values that are not a number" {
  let p_values = [
    0.01,
    @utils.nan(),
    0.02,
    0.03,
    0.04,
    0.05,
    @utils.nan(),
    0.06,
    0.07,
    0.08,
    0.09,
    0.1,
  ]
  assert_true(stats_near(@gcm.merge_p_values_quantile(p_values, [], 0.5), 0.11))
}

///|
/// test "the quantile merge applies the scaling"
test "the quantile merge applies the scaling" {
  let p_values = [0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.09, 0.1]
  let scaling = [2.0, 2.0, 1.0, 2.0, 1.0, 3.0, 1.0, 2.0, 4.0, 1.0]
  assert_true(
    stats_near(@gcm.merge_p_values_quantile(p_values, scaling, 0.5), 0.15),
  )
  assert_true(
    stats_near(@gcm.merge_p_values_quantile(p_values, scaling, 0.25), 0.17),
  )
  assert_true(
    stats_near(
      @gcm.merge_p_values_quantile(p_values, scaling, 0.75),
      0.193333333333,
    ),
  )
}

///|
/// test "the quantile merge rejects the invalid inputs"
///
/// MoonBit cannot catch an abort, so the test checks the conditions that make
/// the merging abort: a quantile outside of `(0, 1]`, an empty list of p-values
/// and a scaling of the wrong length.
test "the quantile merge rejects the invalid inputs" {
  assert_true(@gcm.merge_p_values_quantile_is_valid(3, 0, 0.5))
  assert_true(@gcm.merge_p_values_quantile_is_valid(3, 3, 0.5))
  assert_true(@gcm.merge_p_values_quantile_is_valid(3, 3, 1.0))
  assert_false(@gcm.merge_p_values_quantile_is_valid(0, 0, 0.5))
  assert_false(@gcm.merge_p_values_quantile_is_valid(3, 2, 0.5))
  assert_false(@gcm.merge_p_values_quantile_is_valid(3, 0, 0.0))
  assert_false(@gcm.merge_p_values_quantile_is_valid(3, 0, 1.1))
  assert_false(@gcm.merge_p_values_quantile_is_valid(3, 0, -0.5))
}

///|
/// test "the FDR merge returns the expected p-value"
test "the FDR merge returns the expected p-value" {
  assert_true(stats_near(@gcm.merge_p_values_fdr([0.0]), 0.0))
  assert_true(stats_near(@gcm.merge_p_values_fdr([1.0]), 1.0))
  assert_true(stats_near(@gcm.merge_p_values_fdr([0.3]), 0.3))
  assert_true(stats_near(@gcm.merge_p_values_fdr([0.0, 1.0]), 0.0))
  assert_true(stats_near(@gcm.merge_p_values_fdr([0.1, 0.2, 0.5]), 0.3))
  assert_true(
    stats_near(
      @gcm.merge_p_values_fdr([0.1, @utils.nan(), 0.2, 0.5, @utils.nan()]),
      0.3,
    ),
  )
}

///|
/// test "the average merge without randomization returns the expected p-value"
test "the average merge without randomization returns the expected p-value" {
  let rng = @utils.Random::new(STATS_SEED_FTEST)
  assert_true(stats_near(@gcm.merge_p_values_average([0.0], false, rng), 0.0))
  assert_true(stats_near(@gcm.merge_p_values_average([1.0], false, rng), 1.0))
  assert_true(stats_near(@gcm.merge_p_values_average([0.3], false, rng), 0.3))
  assert_true(
    stats_near(@gcm.merge_p_values_average([0.0, 1.0], false, rng), 1.0),
  )
  assert_true(
    stats_near(@gcm.merge_p_values_average([0.0, 0.0, 1.0], false, rng), 0.0),
  )
  assert_true(
    stats_near(
      @gcm.merge_p_values_average(
        [0.0, 0.5, 0.5, @utils.nan(), 1.0, @utils.nan()],
        false,
        rng,
      ),
      1.0,
    ),
  )
  assert_true(
    stats_near(
      @gcm.merge_p_values_average([0.0, 0.0, 1.0, 1.0, 1.0], false, rng),
      1.0,
    ),
  )
}

///|
/// test "the average merge with randomization returns the expected p-value"
///
/// The randomization draws the value of `u` from the generator, which only
/// makes the result of the test with the two p-values `0` and `1` smaller: the
/// smallest p-value is then the only candidate and the merged p-value is `0`.
test "the average merge with randomization returns the expected p-value" {
  let rng = @utils.Random::new(STATS_SEED_FTEST)
  assert_true(stats_near(@gcm.merge_p_values_average([0.0], true, rng), 0.0))
  assert_true(stats_near(@gcm.merge_p_values_average([1.0], true, rng), 1.0))
  assert_true(stats_near(@gcm.merge_p_values_average([0.3], true, rng), 0.3))
  assert_true(
    stats_near(@gcm.merge_p_values_average([0.0, 1.0], true, rng), 0.0),
  )
  assert_true(
    stats_near(@gcm.merge_p_values_average([0.0, 0.0, 1.0], true, rng), 0.0),
  )
  assert_true(
    stats_near(
      @gcm.merge_p_values_average(
        [0.0, @utils.nan(), 0.0, @utils.nan(), 1.0, 1.0],
        true,
        rng,
      ),
      0.0,
    ),
  )
}

///|
/// test "the F-test p-value is small on dependent data"
test "the F-test p-value is small on dependent data" {
  let (x_training, y_training, x_test, y_test) = ftest_dependent_fixture()
  let p_value = @gcm.estimate_ftest_pvalue(
    x_training,
    @utils.Matrix::zeros(0, 0),
    y_training,
    x_test,
    @utils.Matrix::zeros(0, 0),
    y_test,
  )
  assert_true(stats_near(p_value, 0.004651895397))
  assert_true(p_value < 0.05)
}

///|
/// test "the F-test p-value is large on independent data"
test "the F-test p-value is large on independent data" {
  let (x_training, y_training, x_test, y_test) = ftest_independent_fixture()
  let p_value = @gcm.estimate_ftest_pvalue(
    x_training,
    @utils.Matrix::zeros(0, 0),
    y_training,
    x_test,
    @utils.Matrix::zeros(0, 0),
    y_test,
  )
  assert_true(stats_near(p_value, 1.0))
  assert_true(p_value >= 0.05)
}

///|
/// test "the F-test p-value of two models is small on dependent data"
test "the F-test p-value of two models is small on dependent data" {
  let (x_training_a, x_training_b, y_training, x_test_a, x_test_b, y_test) = ftest_multivariate_dependent_fixture()
  let p_value = @gcm.estimate_ftest_pvalue(
    x_training_a, x_training_b, y_training, x_test_a, x_test_b, y_test,
  )
  assert_true(stats_near(p_value, 0.002008251674))
  assert_true(p_value < 0.05)
}

///|
/// test "the F-test p-value of two models is large on independent data"
test "the F-test p-value of two models is large on independent data" {
  let (x_training_a, x_training_b, y_training, x_test_a, x_test_b, y_test) = ftest_multivariate_independent_fixture()
  let p_value = @gcm.estimate_ftest_pvalue(
    x_training_a, x_training_b, y_training, x_test_a, x_test_b, y_test,
  )
  assert_true(stats_near(p_value, 1.0))
  assert_true(p_value >= 0.05)
}

///|
/// test "the marginal expectation of a linear model matches the one feature model"
///
/// The marginal expectation of the first feature averages the other features
/// away, so it is the model that uses the first feature alone, up to the mean
/// of the other features.
test "the marginal expectation of a linear model matches the one feature model" {
  let (x, y) = marginal_fixture()
  let fit = @utils.ols_fit(stats_with_intercept(x), y)
  let prediction = fn(samples : @utils.Matrix) -> Array[Double] {
    stats_predict_with(fit.beta, samples)
  }
  let expectation = @gcm.marginal_expectation(
    prediction,
    x,
    x,
    [0],
    true,
    @gcm.FeaturePerturbation::independently(),
    @utils.Random::new(STATS_SEED_MARGINAL),
  )
  assert_eq(expectation.nrows(), STATS_MARGINAL_ROWS)
  assert_eq(expectation.ncols(), 1)
  // The model that uses the first feature alone.
  let first = @gcm.column_vector(x.col(0))
  let fit_first = @utils.ols_fit(stats_with_intercept(first), y)
  let predictions = stats_predict_with(fit_first.beta, first)
  let mut difference = 0.0
  for i = 0; i < STATS_MARGINAL_ROWS; i = i + 1 {
    difference = difference + (predictions[i] - expectation.get(i, 0)).abs()
  }
  difference = difference / STATS_MARGINAL_ROWS.to_double()
  assert_true(stats_near(difference, 0.134247379414))
}

///|
/// test "the marginal expectation has the expected shape"
///
/// The upstream code returns a three dimensional array when the results are
/// not averaged and a two dimensional one when they are. The port returns a
/// matrix in both cases: one row per baseline sample and one column per
/// prediction.
test "the marginal expectation has the expected shape" {
  let (x, y) = marginal_fixture()
  let fit = @utils.ols_fit(stats_with_intercept(x), y)
  let prediction = fn(samples : @utils.Matrix) -> Array[Double] {
    stats_predict_with(fit.beta, samples)
  }
  let not_averaged = @gcm.marginal_expectation(
    prediction,
    x,
    x,
    [0],
    false,
    @gcm.FeaturePerturbation::independently(),
    @utils.Random::new(STATS_SEED_MARGINAL),
  )
  assert_eq(not_averaged.nrows(), STATS_MARGINAL_ROWS)
  assert_eq(not_averaged.ncols(), STATS_MARGINAL_ROWS)
  let averaged = @gcm.marginal_expectation(
    prediction,
    x,
    x,
    [0],
    true,
    @gcm.FeaturePerturbation::independently(),
    @utils.Random::new(STATS_SEED_MARGINAL),
  )
  assert_eq(averaged.nrows(), STATS_MARGINAL_ROWS)
  assert_eq(averaged.ncols(), 1)
}

///|
/// test "the marginal expectation of a baseline that holds every feature returns the baseline"
///
/// The upstream test evaluates a prediction method that returns its input, so
/// the result of every baseline sample is the sample itself. The prediction
/// method of the port returns one value per row, so it returns the first
/// feature of every row.
test "the marginal expectation of a baseline that holds every feature returns the baseline" {
  let rng = @utils.Random::new(STATS_SEED_MARGINAL)
  let baseline_rows : Array[Array[Double]] = []
  for _ in 0..<STATS_SHAPE_BASELINE_ROWS {
    let row : Array[Double] = []
    for _ in 0..<3 {
      row.push(rng.next_normal())
    }
    baseline_rows.push(row)
  }
  let baseline = @utils.Matrix::from_rows(baseline_rows)
  // The first row of the fixture, as the reference script prints it.
  assert_true(stats_near(baseline.get(0, 0), -5.107830819658))
  assert_true(stats_near(baseline.get(0, 1), 0.594229867845))
  assert_true(stats_near(baseline.get(0, 2), 1.003398287654))
  let feature_rows : Array[Array[Double]] = []
  for _ in 0..<STATS_SHAPE_FEATURE_ROWS {
    let row : Array[Double] = []
    for _ in 0..<3 {
      row.push(rng.next_normal())
    }
    feature_rows.push(row)
  }
  let feature_samples = @utils.Matrix::from_rows(feature_rows)
  let prediction = fn(samples : @utils.Matrix) -> Array[Double] {
    stats_first_column(samples)
  }
  let averaged = @gcm.marginal_expectation(
    prediction,
    feature_samples,
    baseline,
    [0, 1, 2],
    true,
    @gcm.FeaturePerturbation::independently(),
    @utils.Random::new(STATS_SEED_MARGINAL),
  )
  assert_eq(averaged.nrows(), STATS_SHAPE_BASELINE_ROWS)
  assert_eq(averaged.ncols(), 1)
  for i = 0; i < STATS_SHAPE_BASELINE_ROWS; i = i + 1 {
    assert_true(stats_near(averaged.get(i, 0), baseline.get(i, 0)))
  }
  let not_averaged = @gcm.marginal_expectation(
    prediction,
    feature_samples,
    baseline,
    [0, 1, 2],
    false,
    @gcm.FeaturePerturbation::independently(),
    @utils.Random::new(STATS_SEED_MARGINAL),
  )
  assert_eq(not_averaged.nrows(), STATS_SHAPE_BASELINE_ROWS)
  assert_eq(not_averaged.ncols(), STATS_SHAPE_FEATURE_ROWS)
  for i = 0; i < STATS_SHAPE_BASELINE_ROWS; i = i + 1 {
    for j = 0; j < STATS_SHAPE_FEATURE_ROWS; j = j + 1 {
      assert_true(stats_near(not_averaged.get(i, j), baseline.get(i, 0)))
    }
  }
}
