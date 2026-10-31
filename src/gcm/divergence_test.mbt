///|
/// The tests of the divergence estimators of the `gcm` package.
///
/// The fixture is generated with the deterministic generator of the `utils`
/// package, and the expected numbers are the ones the upstream
/// `dowhy.gcm.divergence` produces on the very same rows, which
/// `_verify/gcm_divergence_reference.py` prints.

///|
/// The seed of the gaussian fixture.
const GAUSSIAN_SEED : UInt64 = 2024UL

///|
/// The seed of the two dimensional gaussian fixture.
const MULTI_SEED : UInt64 = 2025UL

///|
/// The seed of the exponential fixture.
const EXPONENTIAL_SEED : UInt64 = 2026UL

///|
/// The seed of the categorical fixture.
const CATEGORICAL_SEED : UInt64 = 2027UL

///|
/// The seed of the generator that draws the folds of the classifier estimator.
const SPLIT_SEED : UInt64 = 99UL

///|
/// Whether two numbers agree to the tolerance of the comparison.
fn nearly_equal(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-9
}

///|
/// `count` standard normal draws around `mean`.
fn normal_sample(
  rng : @utils.Random,
  mean : Double,
  count : Int32,
) -> Array[Double] {
  let values : Array[Double] = []
  for _ in 0..<count {
    values.push(mean + rng.next_normal())
  }
  values
}

///|
/// `count` exponential draws with the given scale.
///
/// The draws are the inverse transform of the uniform draws of the generator.
fn exponential_sample(
  rng : @utils.Random,
  scale : Double,
  count : Int32,
) -> Array[Double] {
  let values : Array[Double] = []
  for _ in 0..<count {
    let u = rng.next_double()
    let u = if u < 1.0e-12 { 1.0e-12 } else { u }
    values.push(-@utils.ln(u) / scale)
  }
  values
}

///|
/// `count` draws of the categories with the given probabilities.
///
/// The categories are the numbers zero, one, two and three, which stand for the
/// strings of the upstream fixture.
fn categorical_sample(
  rng : @utils.Random,
  probabilities : Array[Double],
  count : Int32,
) -> Array[Double] {
  let values : Array[Double] = []
  for _ in 0..<count {
    let u = rng.next_double()
    let mut cumulative = 0.0
    let mut category = probabilities.length() - 1
    for i = 0; i < probabilities.length(); i = i + 1 {
      cumulative = cumulative + probabilities[i]
      if u < cumulative {
        category = i
        break
      }
    }
    values.push(category.to_double())
  }
  values
}

///|
/// The gaussian fixture: two thousand normal draws around zero and around one.
fn gaussian_fixture() -> (@utils.Matrix, @utils.Matrix) {
  let rng = @utils.Random::new(GAUSSIAN_SEED)
  let x = normal_sample(rng, 0.0, 2000)
  let y = normal_sample(rng, 1.0, 2000)
  (@gcm.column_vector(x), @gcm.column_vector(y))
}

///|
/// The two dimensional gaussian fixture.
fn gaussian_2d_fixture() -> (@utils.Matrix, @utils.Matrix) {
  let rng = @utils.Random::new(MULTI_SEED)
  let x = @utils.Matrix::from_columns([
    normal_sample(rng, 0.0, 2000),
    normal_sample(rng, 0.0, 2000),
  ])
  let y = @utils.Matrix::from_columns([
    normal_sample(rng, 1.0, 2000),
    normal_sample(rng, 1.0, 2000),
  ])
  (x, y)
}

///|
/// The exponential fixture: two thousand draws of the scales one and a half.
fn exponential_fixture() -> (@utils.Matrix, @utils.Matrix) {
  let rng = @utils.Random::new(EXPONENTIAL_SEED)
  let x = exponential_sample(rng, 1.0, 2000)
  let y = exponential_sample(rng, 0.5, 2000)
  (@gcm.column_vector(x), @gcm.column_vector(y))
}

///|
/// The categorical fixture: a thousand draws of four categories.
fn categorical_fixture() -> (@utils.Matrix, @utils.Matrix) {
  let rng = @utils.Random::new(CATEGORICAL_SEED)
  let x = categorical_sample(rng, [0.25, 0.5, 0.125, 0.125], 1000)
  let y = categorical_sample(rng, [0.5, 0.25, 0.125, 0.125], 1000)
  (@gcm.column_vector(x), @gcm.column_vector(y))
}

///|
/// The gaussian fixture, with the first ten rows of X in Y as well.
fn overlapping_fixture() -> (@utils.Matrix, @utils.Matrix) {
  let (x, y) = gaussian_fixture()
  let x_values = @gcm.matrix_to_vector(x)
  let y_values = @gcm.matrix_to_vector(y)
  for i = 0; i < 10; i = i + 1 {
    y_values[i] = x_values[i]
  }
  (x, @gcm.column_vector(y_values))
}

///|
/// Two rows of probabilities and the same two rows with the first two swapped.
fn probability_fixture() -> (@utils.Matrix, @utils.Matrix) {
  (
    @utils.Matrix::from_rows([
      [0.25, 0.5, 0.125, 0.125],
      [0.5, 0.25, 0.125, 0.125],
    ]),
    @utils.Matrix::from_rows([
      [0.5, 0.25, 0.125, 0.125],
      [0.25, 0.5, 0.125, 0.125],
    ]),
  )
}

///|
/// test "the nearest neighbour divergence of two gaussian samples"
///
/// The expected numbers are the ones the upstream estimator produces on the very
/// same rows, which the reference script prints under `GAUSSIAN_KNN`. The
/// estimate of two samples of the same distribution is zero, because the rows
/// that the two samples share are removed first.
test "the nearest neighbour divergence of two gaussian samples" {
  let (x, y) = gaussian_fixture()
  let same = @gcm.estimate_kl_divergence_continuous_knn(x, x, 1, true)
  assert_true(nearly_equal(same, 0.0))
  let different = @gcm.estimate_kl_divergence_continuous_knn(x, y, 1, true)
  assert_true(nearly_equal(different, 0.478172898070))
}

///|
/// test "the categorical divergence of two samples of categories"
///
/// The expected numbers are the ones the upstream estimator produces on the very
/// same rows, which the reference script prints under `CATEGORICAL`. The
/// divergence of the two distributions is close to the one of the probabilities
/// the fixture draws from.
test "the categorical divergence of two samples of categories" {
  let (x, y) = categorical_fixture()
  let same = @gcm.estimate_kl_divergence_categorical(x, x)
  assert_true(nearly_equal(same, 0.0))
  let different = @gcm.estimate_kl_divergence_categorical(x, y)
  assert_true(nearly_equal(different, 0.174594974723))
}

///|
/// test "the divergence of two rows of probabilities"
///
/// The expected number is the one the upstream estimator produces on the very
/// same rows, which the reference script prints under `PROBABILITIES`.
test "the divergence of two rows of probabilities" {
  let (x, y) = probability_fixture()
  let value = @gcm.estimate_kl_divergence_of_probabilities(x, y)
  assert_true(nearly_equal(value, 0.173286795140))
}

///|
/// test "the automatic estimate sends the probability vectors to the probability estimator"
test "the automatic estimate sends the probability vectors to the probability estimator" {
  let (x, y) = probability_fixture()
  let value = @gcm.auto_estimate_kl_divergence(
    x,
    y,
    @utils.Random::new(SPLIT_SEED),
  )
  assert_true(nearly_equal(value, 0.173286795140))
}

///|
/// test "the automatic estimate sends a single column to the nearest neighbour estimator"
test "the automatic estimate sends a single column to the nearest neighbour estimator" {
  let (x, y) = gaussian_fixture()
  let value = @gcm.auto_estimate_kl_divergence(
    x,
    y,
    @utils.Random::new(SPLIT_SEED),
  )
  assert_true(nearly_equal(value, 0.478172898070))
}

///|
/// test "the probability matrix check accepts the valid and rejects the invalid inputs"
test "the probability matrix check accepts the valid and rejects the invalid inputs" {
  assert_true(
    @gcm.is_probability_matrix(@utils.Matrix::from_rows([[0.5, 0.3, 0.2]])),
  )
  assert_false(
    @gcm.is_probability_matrix(@utils.Matrix::from_rows([[0.1, 0.3, 0.2]])),
  )
  assert_true(
    @gcm.is_probability_matrix(
      @utils.Matrix::from_rows([[0.5, 0.3, 0.2], [0.1, 0.2, 0.7]]),
    ),
  )
  assert_false(
    @gcm.is_probability_matrix(
      @utils.Matrix::from_rows([[1.0, 2.0, 3.0], [-1.0, 0.5, 2.0]]),
    ),
  )
  // A matrix with one column is never a matrix of probabilities.
  assert_false(
    @gcm.is_probability_matrix(@utils.Matrix::from_rows([[0.0], [1.0], [2.0]])),
  )
}

///|
/// test "the nearest neighbour divergence of two samples that share rows"
///
/// The rows that the two samples share are removed first, so the estimate stays
/// finite. The expected number is the one the upstream estimator produces on the
/// very same rows, which the reference script prints under `OVERLAPPING_KNN`.
test "the nearest neighbour divergence of two samples that share rows" {
  let (x, y) = overlapping_fixture()
  let value = @gcm.estimate_kl_divergence_continuous_knn(x, y, 1, true)
  assert_true(nearly_equal(value, 0.474474884954))
}

///|
/// test "the classifier divergence of one column"
///
/// The upstream estimator draws the folds of its cross validation with the
/// global numpy random state, while the port draws them with its own
/// generator, so the two estimates only agree up to the tolerance of the
/// comparison. The expected number is the one the upstream estimator produces
/// on the very same rows, which the reference script prints under
/// `GAUSSIAN_CLF`.
test "the classifier divergence of one column" {
  let (x, y) = gaussian_fixture()
  let same = @gcm.estimate_kl_divergence_continuous_clf(
    x,
    x,
    5,
    @gcm.EPS,
    @utils.Random::new(SPLIT_SEED),
  )
  assert_true(nearly_equal(same, 0.0))
  let different = @gcm.estimate_kl_divergence_continuous_clf(
    x,
    y,
    5,
    @gcm.EPS,
    @utils.Random::new(SPLIT_SEED),
  )
  assert_true((different - 0.507958598473).abs() < 0.05)
}

///|
/// test "the classifier divergence of several columns"
///
/// The estimate is the one of the upstream estimator, up to the tolerance of
/// the comparison, which the reference script prints under `MULTI_CLF`.
test "the classifier divergence of several columns" {
  let (x, y) = gaussian_2d_fixture()
  let same = @gcm.estimate_kl_divergence_continuous_clf(
    x,
    x,
    5,
    @gcm.EPS,
    @utils.Random::new(SPLIT_SEED),
  )
  assert_true(nearly_equal(same, 0.0))
  let different = @gcm.estimate_kl_divergence_continuous_clf(
    x,
    y,
    5,
    @gcm.EPS,
    @utils.Random::new(SPLIT_SEED),
  )
  assert_true((different - 1.038373424250).abs() < 0.05)
}

///|
/// test "the classifier divergence of an exponential sample"
///
/// The estimate of the upstream estimator, up to the tolerance of the
/// comparison, which the reference script prints under `EXPONENTIAL`. The
/// nearest neighbour estimator of the same sample does not depend on a random
/// split, so it agrees with the upstream one exactly.
test "the classifier divergence of an exponential sample" {
  let (x, y) = exponential_fixture()
  let different = @gcm.estimate_kl_divergence_continuous_clf(
    x,
    y,
    5,
    @gcm.EPS,
    @utils.Random::new(SPLIT_SEED),
  )
  assert_true((different - 0.179842361671).abs() < 0.05)
  let nearest = @gcm.estimate_kl_divergence_continuous_knn(x, y, 1, true)
  assert_true(nearly_equal(nearest, 0.188760628415))
}
