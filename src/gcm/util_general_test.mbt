///|
/// The tests of the general helpers of the `gcm` package.
///
/// The fixture is generated with the deterministic generator of the `utils`
/// package, and the expected numbers are the ones the upstream
/// `dowhy.gcm.util.general` produces on the very same rows, which
/// `_verify/gcm_general_reference.py` prints.

///|
/// The seed of the fixture.
const SEED : UInt64 = 2024UL

///|
/// Whether two numbers agree to the tolerance of the comparison.
fn near(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-10
}

///|
/// `count` standard normal draws around `mean`.
fn normal_around(
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
/// The fixture of the geometric median: a hundred points around `(10, -5)` and
/// twenty points around `(10000, -10000)`.
///
/// The draws happen in the order of the reference script: the first column,
/// then the second one, and the twenty far away points of each column after
/// the hundred near ones.
fn median_fixture() -> @utils.Matrix {
  let rng = @utils.Random::new(SEED)
  let a = normal_around(rng, 10.0, 100)
  for value in normal_around(rng, 10000.0, 20) {
    a.push(value)
  }
  let b = normal_around(rng, -5.0, 100)
  for value in normal_around(rng, -10000.0, 20) {
    b.push(value)
  }
  let rows : Array[Array[Double]] = []
  for j = 0; j < a.length(); j = j + 1 {
    rows.push([a[j], b[j]])
  }
  @utils.Matrix::from_rows(rows)
}

///|
/// The rows of the set difference fixture.
fn difference_fixture() -> @utils.Matrix {
  @utils.Matrix::from_rows([[1.0, 2.0], [3.0, 4.0], [1.0, 2.0], [5.0, 6.0]])
}

///|
/// test "the geometric median finds the centre of the larger cluster"
///
/// The expected numbers are the optimum of the sum of the distances, which
/// the reference script computes with a tight tolerance. The upstream code
/// stops about 1e-5 short of it, because the default settings of its
/// optimiser stop there.
test "the geometric median finds the centre of the larger cluster" {
  let median = @gcm.geometric_median(median_fixture())
  assert_eq(median.length(), 2)
  assert_true((median[0] - 10.198583199864).abs() < 1.0e-6)
  assert_true((median[1] - -5.389777024732).abs() < 1.0e-6)
}

///|
/// test "the set difference drops the shared rows and sorts the rest"
test "the set difference drops the shared rows and sorts the rest" {
  let difference = @gcm.setdiff2d(
    difference_fixture(),
    @utils.Matrix::from_rows([[3.0, 4.0]]),
  )
  assert_eq(difference.nrows(), 2)
  assert_true(near(difference.get(0, 0), 1.0))
  assert_true(near(difference.get(0, 1), 2.0))
  assert_true(near(difference.get(1, 0), 5.0))
  assert_true(near(difference.get(1, 1), 6.0))
}

///|
/// test "the set difference of a matrix with itself is empty"
test "the set difference of a matrix with itself is empty" {
  let difference = @gcm.setdiff2d(difference_fixture(), difference_fixture())
  assert_eq(difference.nrows(), 0)
}

///|
/// test "the scaled columns have zero mean and unit variance"
test "the scaled columns have zero mean and unit variance" {
  let scaled = @gcm.scale_columns(median_fixture())
  assert_true(near(@utils.mean(scaled.col(0)), 0.0))
  assert_true(near(@utils.std(scaled.col(0)), 1.0))
  assert_true(near(@utils.mean(scaled.col(1)), 0.0))
  assert_true(near(@utils.std(scaled.col(1)), 1.0))
}

///|
/// test "the difference of the means and the variances of the deviations"
test "the difference of the means and the variances of the deviations" {
  let randomized = [1.0, 2.0, 3.0, 4.0]
  let baseline = [2.0, 2.0, 2.0, 2.0]
  assert_true(near(@gcm.means_difference(randomized, baseline), 0.5))
  assert_true(near(@gcm.variance_of_deviations(randomized, baseline), -1.25))
  assert_true(
    near(@gcm.variance_of_matching_values(randomized, baseline), -0.1875),
  )
}

///|
/// test "the discrete check follows the whole numbers"
test "the discrete check follows the whole numbers" {
  assert_true(@gcm.is_discrete([1.0, 2.0, 3.0]))
  assert_false(@gcm.is_discrete([1.0, 2.5]))
  assert_true(@gcm.is_discrete([]))
}

///|
/// test "the random permutation holds every index once"
test "the random permutation holds every index once" {
  let order = @gcm.random_permutation(@utils.Random::new(SEED), 10)
  assert_eq(order.length(), 10)
  let seen : Array[Bool] = []
  for _ in 0..<10 {
    seen.push(false)
  }
  for index in order {
    assert_true(index >= 0 && index < 10)
    assert_false(seen[index])
    seen[index] = true
  }
}

///|
/// test "the column vector and its values are the same data"
test "the column vector and its values are the same data" {
  let values = [1.0, 2.0, 3.0]
  let matrix = @gcm.column_vector(values)
  assert_eq(matrix.nrows(), 3)
  assert_eq(matrix.ncols(), 1)
  let back = @gcm.matrix_to_vector(matrix)
  assert_eq(back.length(), 3)
  assert_true(near(back[1], 2.0))
}
