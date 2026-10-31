///|
/// The tests of the dimensionality reducers.
///
/// The fixture is the one of the upstream test
/// (`tests/data_transformers/test_pca_reducer.py`): two correlated features
/// with a covariance of `[[1, 0.5], [0.5, 1]]` and a mean drawn from the
/// uniform distribution on `[-1, 1]`. The upstream assertion is that the
/// reduction preserves the distance of every row from the centre of the
/// data.
fn feature_matrix(rows : Int32, seed : UInt64) -> @utils.Matrix {
  let rng = @utils.Random::new(seed)
  let mean0 = -1.0 + 2.0 * rng.next_double()
  let mean1 = -1.0 + 2.0 * rng.next_double()
  let first : Array[Double] = []
  let second : Array[Double] = []
  for i = 0; i < rows; i = i + 1 {
    let z0 = rng.next_normal()
    let z1 = rng.next_normal()
    first.push(mean0 + z0)
    // The Cholesky factor of [[1, 0.5], [0.5, 1]] is [[1, 0], [0.5, 0.866]].
    second.push(mean1 + 0.5 * z0 + 0.8660254037844386 * z1)
  }
  @utils.Matrix::from_columns([first, second])
}

///|
/// The squared distance of every row from the centre of the data.
///
/// This is the quantity the upstream test compares: the sum of the squared
/// deviations of a row, not of a column.
fn squared_distance(matrix : @utils.Matrix) -> Array[Double] {
  let means : Array[Double] = []
  for j = 0; j < matrix.ncols(); j = j + 1 {
    means.push(@utils.mean(matrix.col(j)))
  }
  let distances : Array[Double] = []
  for i = 0; i < matrix.nrows(); i = i + 1 {
    let mut total = 0.0
    for j = 0; j < matrix.ncols(); j = j + 1 {
      let difference = matrix.get(i, j) - means[j]
      total = total + difference * difference
    }
    distances.push(total)
  }
  distances
}

///|
test "the pca reducer keeps the distance of every row from the centre" {
  let data = feature_matrix(10000, 42UL)
  let reducer = @data_transformers.DimensionalityReducer::pca(data, 2, false)
  let reduced = reducer.reduce()
  assert_eq(reduced.nrows(), 10000)
  assert_eq(reduced.ncols(), 2)
  // The upstream assertion: the distance of a row from the centre survives
  // the rotation, because a principal component analysis is orthogonal.
  let before = squared_distance(data)
  let after = squared_distance(reduced)
  assert_eq(before.length(), after.length())
  let mut worst = 0.0
  for i = 0; i < before.length(); i = i + 1 {
    let difference = (after[i] - before[i]).abs()
    if difference > worst {
      worst = difference
    }
  }
  assert_true(worst < 0.001)
}

///|
test "the pca reducer preserves the total variance of the data" {
  let data = feature_matrix(1000, 7UL)
  let reducer = @data_transformers.DimensionalityReducer::pca(data, 2, false)
  let reduced = reducer.reduce()
  let total_before = total_variance(data)
  let total_after = total_variance(reduced)
  assert_true((total_before - total_after).abs() < 1.0e-8)
}

///|
test "the pca reducer produces orthonormal components" {
  let data = feature_matrix(500, 11UL)
  let reducer = @data_transformers.DimensionalityReducer::pca(data, 2, false)
  let components = reducer.components()
  assert_eq(components.nrows(), 2)
  assert_eq(components.ncols(), 2)
  for j = 0; j < components.ncols(); j = j + 1 {
    let column = components.col(j)
    let mut norm = 0.0
    for value in column {
      norm = norm + value * value
    }
    assert_true((norm.sqrt() - 1.0).abs() < 1.0e-9)
  }
  // The two components are orthogonal.
  let first = components.col(0)
  let second = components.col(1)
  let mut product = 0.0
  for i = 0; i < first.length(); i = i + 1 {
    product = product + first[i] * second[i]
  }
  assert_true(product.abs() < 1.0e-9)
}

///|
test "the pca reducer standardises the columns when it is asked to" {
  let data = feature_matrix(500, 13UL)
  let standardised = @data_transformers.DimensionalityReducer::pca(
    data, 2, true,
  )
  assert_true(standardised.is_standardized())
  let reduced = standardised.reduce()
  // The standardised data has a total variance of one per column, and the
  // reduction keeps that total. The standardisation divides by the POPULATION
  // standard deviation while the covariance divides by `n - 1`, so the total
  // is `n / (n - 1)` per column -- the same convention `sklearn` has.
  let expected = 2.0 * 500.0 / 499.0
  assert_true((total_variance(reduced) - expected).abs() < 1.0e-8)
  // The variance of a component is the eigenvalue it belongs to, so the
  // explained variance ratios add up to one.
  let ratios = standardised.explained_variance_ratio()
  let mut total = 0.0
  for ratio in ratios {
    total = total + ratio
  }
  assert_true((total - 1.0).abs() < 1.0e-9)
}

///|
test "the explained variance of the reducer adds up to one" {
  let data = feature_matrix(500, 17UL)
  let reducer = @data_transformers.DimensionalityReducer::pca(data, 2, false)
  let ratios = reducer.explained_variance_ratio()
  assert_eq(ratios.length(), 2)
  let mut total = 0.0
  for ratio in ratios {
    total = total + ratio
  }
  assert_true((total - 1.0).abs() < 1.0e-9)
  // The first component explains at least as much as the second one.
  assert_true(ratios[0] >= ratios[1])
}

///|
test "the reducer keeps at most as many dimensions as the data has columns" {
  let data = feature_matrix(100, 19UL)
  let reducer = @data_transformers.DimensionalityReducer::pca(data, 5, false)
  assert_eq(reducer.dimensions(), 2)
  let reduced = reducer.reduce()
  assert_eq(reduced.ncols(), 2)
}

///|
/// The sum of the variances of the columns of a matrix.
fn total_variance(matrix : @utils.Matrix) -> Double {
  let mut total = 0.0
  for j = 0; j < matrix.ncols(); j = j + 1 {
    total = total + @utils.variance(matrix.col(j), 1)
  }
  total
}
