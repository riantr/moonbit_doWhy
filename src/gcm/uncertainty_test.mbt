///|
/// The tests of the uncertainty estimates of the `gcm` package.
///
/// The upstream reference of the layer is `_verify/gcm_uncertainty_reference.py`,
/// which runs the upstream `dowhy.gcm.uncertainty` on the fixtures of the layer.
/// The fixtures of the port are drawn from the generator of the `utils` package,
/// and the reference script reproduces that generator in Python, so that the
/// fixtures of the port and the fixtures of the reference are the same numbers.
///
/// The upstream test file `tests/gcm/test_uncertainty.py` asserts the
/// approximate values of the estimates, because they are estimates of a
/// statistical quantity. The tests of the port assert those values as well and
/// the numbers of the upstream reference, which are the numbers of the upstream
/// on the very same rows.

///|
/// The seed of the generators of the fixtures.
const UNCERTAINTY_SEED : UInt64 = 2025

///|
/// The number of the rows of the Gaussian fixtures.
const UNCERTAINTY_NUM_ROWS : Int32 = 10000

///|
/// The number of the rows of the multivariate Gaussian fixtures.
const UNCERTAINTY_NUM_ROWS_MULTIVARIATE : Int32 = 100000

///|
/// The number of the columns of the multivariate Gaussian fixtures.
const UNCERTAINTY_NUM_COLUMNS_MULTIVARIATE : Int32 = 3

///|
/// The number of the rows of the discrete fixtures.
const UNCERTAINTY_NUM_ROWS_DISCRETE : Int32 = 1000

///|
/// The generator of the fixture with the given index.
fn uncertainty_rng(index : UInt64) -> @utils.Random {
  @utils.Random::new(UNCERTAINTY_SEED + index)
}

///|
/// The given number of the samples of the standard normal distribution.
fn uncertainty_normals(rng : @utils.Random, count : Int32) -> Array[Double] {
  let out : Array[Double] = []
  for _ in 0..<count {
    out.push(rng.next_normal())
  }
  out
}

///|
/// The values of the given samples, multiplied by the given factor.
fn uncertainty_scaled(values : Array[Double], factor : Double) -> Array[Double] {
  let out : Array[Double] = []
  for value in values {
    out.push(factor * value)
  }
  out
}

///|
/// The Gaussian fixture with the given index, number of rows and scale.
fn uncertainty_gaussian_fixture(
  index : UInt64,
  rows : Int32,
  scale : Double,
) -> @utils.Matrix {
  let rng = uncertainty_rng(index)
  let values = uncertainty_scaled(uncertainty_normals(rng, rows), scale)
  @utils.Matrix::from_columns([values])
}

///|
/// The multivariate Gaussian fixture with the given index.
fn uncertainty_multivariate_fixture(
  index : UInt64,
  rows : Int32,
  columns : Int32,
  scale : Double,
) -> @utils.Matrix {
  let rng = uncertainty_rng(index)
  let values = uncertainty_scaled(
    uncertainty_normals(rng, rows * columns),
    scale,
  )
  let out = @utils.Matrix::zeros(rows, columns)
  for i in 0..<rows {
    for j in 0..<columns {
      out.set(i, j, values[i * columns + j])
    }
  }
  out
}

///|
/// The discrete fixture with the given index.
///
/// The upstream draws the values with `numpy.random.choice(2, ...)`, which
/// draws a coin flip for every value; the port draws the same coin flips from
/// its own generator.
fn uncertainty_discrete_fixture(
  index : UInt64,
  rows : Int32,
  columns : Int32,
) -> @utils.Matrix {
  let rng = uncertainty_rng(index)
  let out = @utils.Matrix::zeros(rows, columns)
  for i in 0..<(rows * columns) {
    let value = if rng.next_double() < 0.5 { 1.0 } else { 0.0 }
    out.set(i / columns, i % columns, value)
  }
  out
}

///|
test "given gaussian data when estimating the entropy with a discretisation then report the entropy of the upstream reference" {
  let x = uncertainty_gaussian_fixture(1, UNCERTAINTY_NUM_ROWS, 1.0)
  let y = uncertainty_gaussian_fixture(2, UNCERTAINTY_NUM_ROWS, 3.0)
  let entropy_x = @gcm.estimate_entropy_using_discretization(x, 1.0)
  let entropy_y = @gcm.estimate_entropy_using_discretization(y, 1.0)
  // The numbers of the upstream reference.
  assert_true((entropy_x - 1.2542989299918652).abs() <= 1.0e-9)
  assert_true((entropy_y - 2.438487975579602).abs() <= 1.0e-9)
  // The approximate values of the upstream test file.
  assert_true((entropy_x - 1.25).abs() <= 0.2)
  assert_true((entropy_y - 2.45).abs() <= 0.2)
}

///|
test "given gaussian data when estimating the entropy with the kmeans estimator then report the entropy of the upstream reference" {
  let x = uncertainty_gaussian_fixture(1, UNCERTAINTY_NUM_ROWS, 1.0)
  let y = uncertainty_gaussian_fixture(2, UNCERTAINTY_NUM_ROWS, 3.0)
  let entropy_x = @gcm.estimate_entropy_kmeans(x)
  let entropy_y = @gcm.estimate_entropy_kmeans(y)
  // The numbers of the upstream reference.
  assert_true((entropy_x - 1.4010812015398537).abs() <= 1.0e-9)
  assert_true((entropy_y - 2.50866742754989).abs() <= 1.0e-9)
  // The approximate values of the upstream test file.
  assert_true((entropy_x - 1.4).abs() <= 0.2)
  assert_true((entropy_y - 2.5).abs() <= 0.2)
}

///|
test "given gaussian data when estimating the gaussian entropy then report the entropy of the upstream reference" {
  let x = uncertainty_gaussian_fixture(1, UNCERTAINTY_NUM_ROWS, 1.0)
  let y = uncertainty_gaussian_fixture(2, UNCERTAINTY_NUM_ROWS, 3.0)
  let entropy_x = @gcm.estimate_gaussian_entropy(x)
  let entropy_y = @gcm.estimate_gaussian_entropy(y)
  // The numbers of the upstream reference.
  assert_true((entropy_x - 1.406167477599538).abs() <= 1.0e-12)
  assert_true((entropy_y - 2.5150297688833416).abs() <= 1.0e-12)
  // The approximate values of the upstream test file.
  assert_true((entropy_x - 1.4).abs() <= 0.2)
  assert_true((entropy_y - 2.5).abs() <= 0.2)
}

///|
test "given gaussian data when estimating the variance then report the variance of the upstream reference" {
  let x = uncertainty_gaussian_fixture(1, UNCERTAINTY_NUM_ROWS, 1.0)
  let y = uncertainty_gaussian_fixture(2, UNCERTAINTY_NUM_ROWS, 3.0)
  // The numbers of the upstream reference.
  assert_true((@gcm.estimate_variance(x) - 0.9747813288799058).abs() <= 1.0e-12)
  assert_true((@gcm.estimate_variance(y) - 8.954735256902431).abs() <= 1.0e-12)
  // The approximate values of the upstream test file.
  assert_true((@gcm.estimate_variance(x) - 1.0).abs() <= 0.2)
  assert_true((@gcm.estimate_variance(y) - 9.0).abs() <= 0.2)
  // The variance of a sample with several columns is the determinant of its
  // sample covariance matrix.
  let x_multi = uncertainty_multivariate_fixture(
    3,
    UNCERTAINTY_NUM_ROWS_MULTIVARIATE,
    UNCERTAINTY_NUM_COLUMNS_MULTIVARIATE,
    1.0,
  )
  let y_multi = uncertainty_multivariate_fixture(
    4,
    UNCERTAINTY_NUM_ROWS_MULTIVARIATE,
    UNCERTAINTY_NUM_COLUMNS_MULTIVARIATE,
    3.0,
  )
  assert_true(
    (@gcm.estimate_variance(x_multi) - 0.9974188526569719).abs() <= 1.0e-9,
  )
  assert_true(
    (@gcm.estimate_variance(y_multi) - 723.3625912714346).abs() <= 1.0e-9,
  )
  assert_true((@gcm.estimate_variance(x_multi) - 1.0).abs() <= 1.0)
  assert_true((@gcm.estimate_variance(y_multi) - 729.0).abs() <= 15.0)
  // The gaussian entropy of a sample with several columns.
  assert_true(
    (@gcm.estimate_gaussian_entropy(x_multi) - 4.25552335749047).abs() <=
    1.0e-12,
  )
  assert_true(
    (@gcm.estimate_gaussian_entropy(y_multi) - 7.548770902519377).abs() <=
    1.0e-12,
  )
}

///|
test "given probabilities when estimating the entropy of the probabilities then report the entropy of the upstream reference" {
  let probabilities = @utils.Matrix::from_rows([
    [0.25, 0.25, 0.25, 0.25],
    [1.0, 0.0, 0.0, 0.0],
    [0.5, 0.0, 0.0, 0.5],
    [0.0, 0.5, 0.5, 0.0],
    [0.5, 0.0, 0.0, 0.5],
    [1.0, 0.0, 0.0, 0.0],
    [1.0, 0.0, 0.0, 0.0],
  ])
  // The number of the upstream reference.
  assert_true(
    (@gcm.estimate_entropy_of_probabilities(probabilities) - 0.49510512897138953).abs() <=
    1.0e-12,
  )
  // The approximate values of the upstream test file.
  let uniform = @utils.Matrix::from_rows([[0.25, 0.25, 0.25, 0.25]])
  let degenerate = @utils.Matrix::from_rows([[1.0, 0.0, 0.0, 0.0]])
  let half = @utils.Matrix::from_rows([[0.5, 0.0, 0.0, 0.5]])
  let two_rows = @utils.Matrix::from_rows([
    [0.0, 0.5, 0.5, 0.0],
    [0.5, 0.0, 0.0, 0.5],
  ])
  let two_degenerate = @utils.Matrix::from_rows([
    [1.0, 0.0, 0.0, 0.0],
    [1.0, 0.0, 0.0, 0.0],
  ])
  assert_true(
    (@gcm.estimate_entropy_of_probabilities(uniform) - 1.38).abs() <= 0.05,
  )
  assert_true(
    (@gcm.estimate_entropy_of_probabilities(degenerate) - 0.0).abs() <= 0.05,
  )
  assert_true(
    (@gcm.estimate_entropy_of_probabilities(half) - 0.69).abs() <= 0.05,
  )
  assert_true(
    (@gcm.estimate_entropy_of_probabilities(two_rows) - 0.69).abs() <= 0.05,
  )
  assert_true(
    (@gcm.estimate_entropy_of_probabilities(two_degenerate) - 0.0).abs() <= 0.05,
  )
}

///|
test "given discrete data when estimating the entropy of the discrete data then report the entropy of the upstream reference" {
  let one_column = uncertainty_discrete_fixture(
    5,
    UNCERTAINTY_NUM_ROWS_DISCRETE,
    1,
  )
  let two_columns = uncertainty_discrete_fixture(
    6,
    UNCERTAINTY_NUM_ROWS_DISCRETE,
    2,
  )
  // The numbers of the upstream reference.
  assert_true(
    (@gcm.estimate_entropy_discrete(one_column) - 0.6906951757946529).abs() <=
    1.0e-12,
  )
  assert_true(
    (@gcm.estimate_entropy_discrete(two_columns) - 1.3822625025496267).abs() <=
    1.0e-12,
  )
  // The approximate values of the upstream test file, which are the entropies
  // of the uniform distributions of two and of four outcomes.
  let uniform_two = @math.ln(2.0)
  let uniform_four = @math.ln(4.0)
  assert_true(
    (@gcm.estimate_entropy_discrete(one_column) - uniform_two).abs() <=
    0.05 * uniform_two,
  )
  assert_true(
    (@gcm.estimate_entropy_discrete(two_columns) - uniform_four).abs() <=
    0.05 * uniform_four,
  )
}
