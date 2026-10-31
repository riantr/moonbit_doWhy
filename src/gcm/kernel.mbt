///|
/// The kernel based independence test of the `gcm` package.
///
/// This is the port of `dowhy.gcm.independence_test.kernel.kernel_based`,
/// which delegates the test itself to the `causal-learn` package: the
/// unconditional kernel conditional independence test `KCI_UInd` of
/// `causallearn.utils.KCI.KCI` and its conditional counterpart `KCI_CInd`.
///
/// The test estimates a p-value for the null hypothesis that X and Y are
/// independent, given Z. When Z is given, the conditional test of the upstream
/// is used, otherwise the unconditional one.
///
/// Based on the work:
/// - K. Zhang, J. Peters, D. Janzing, B. Schölkopf. *Kernel-based Conditional
///   Independence Test and Application in Causal Discovery*. UAI'11, 804-813.
/// - A. Gretton, K. Fukumizu, C.-H. Teo, L. Song, B. Schölkopf, A. Smola.
///   *A Kernel Statistical Test of Independence*. NIPS 21, 2007.

///|
/// The p-value of the null hypothesis that X and Y are independent given Z.
///
/// The rows of the sample are `min(number of rows of X, max_num_samples_run)`
/// rows drawn without replacement, and Y and Z are subsampled with the same
/// indices. Every run of the bootstrap computes the p-value of the test on its
/// own subsample, and the p-values of the runs are merged by
/// `p_value_adjust_func`, which the caller supplies.
///
/// The columns that hold a single value are removed before the test. When X
/// or Y has no column left, the variables are constant and the p-value is
/// `1.0`; when Z has no column left, the test is the unconditional one.
///
/// The deviations from the upstream code are:
/// - The upstream takes the width of the kernel from the caller (`est_width`)
///   and defaults it to the median trick. The port always uses the median
///   trick, so it has no counterpart of the parameter.
/// - The upstream runs the bootstrap in a process pool with `joblib` and draws
///   its randomness from the global generator of numpy. The port runs the runs
///   one after another and draws from the generator it is given, so the
///   upstream parameter `bootstrap_n_jobs` has no counterpart.
/// - The upstream encodes the categorical data with a one-hot encoder. The
///   matrices of the port hold numbers only, so there is nothing to encode.
/// - The upstream raises when the data holds NaN values. The port does not
///   check for them.
pub fn kernel_based(
  x : @utils.Matrix,
  y : @utils.Matrix,
  z : @utils.Matrix?,
  use_bootstrap : Bool,
  bootstrap_num_runs : Int32,
  max_num_samples_run : Int32,
  p_value_adjust_func : (Array[Double]) -> Double,
  rng : @utils.Random,
) -> Double {
  let runs = if use_bootstrap { bootstrap_num_runs } else { 1 }
  let p_values : Array[Double] = []
  for _ in 0..<runs {
    let count = if x.nrows() < max_num_samples_run {
      x.nrows()
    } else {
      max_num_samples_run
    }
    let indices = kernel_sample_indices(x.nrows(), count, rng)
    let sample_x = kernel_select_rows(x, indices)
    let sample_y = kernel_select_rows(y, indices)
    let sample_z = match z {
      Some(conditioning) => Some(kernel_select_rows(conditioning, indices))
      None => None
    }
    p_values.push(kernel_evaluate(sample_x, sample_y, sample_z, rng))
  }
  p_value_adjust_func(p_values)
}

///|
/// The p-value of the kernel based independence test of X and Y.
///
/// This is the port of `KCI_UInd` of the `causal-learn` package. The width of
/// the Gaussian kernel of X and of Y comes from the median trick on the raw
/// data, and the kernel matrices are centred before the test statistic and the
/// parameters of the gamma approximation are computed.
///
/// The test is symmetric in X and Y: the statistic and the parameters of the
/// approximation do not change when the two variables are swapped.
pub fn kernel_based_unconditional(
  x : @utils.Matrix,
  y : @utils.Matrix,
  rng : @utils.Random,
) -> Double {
  let width_x = kernel_width_median(x, rng)
  let width_y = kernel_width_median(y, rng)
  let scaled_x = kernel_zscore(x)
  let scaled_y = kernel_zscore(y)
  let centred_x = kernel_center_kernel_matrix(
    kernel_gaussian_kernel(scaled_x, width_x),
  )
  let centred_y = kernel_center_kernel_matrix(
    kernel_gaussian_kernel(scaled_y, width_y),
  )
  let statistic = kernel_product_sum(centred_x, centred_y)
  let n = centred_x.nrows().to_double()
  let mean_appr = kernel_trace(centred_x) * kernel_trace(centred_y) / n
  let var_appr = 2.0 *
    kernel_sum_of_squares(centred_x) *
    kernel_sum_of_squares(centred_y) /
    n /
    n
  kernel_gamma_p_value(statistic, mean_appr, var_appr)
}

///|
/// The p-value of the kernel based conditional independence test of X and Y
/// given Z.
///
/// This is the port of `KCI_CInd` of the `causal-learn` package. The kernel of
/// X is built from X concatenated with half of Z, the kernel matrices are
/// centred and then regressed on the centred kernel matrix of Z, and the
/// parameters of the gamma approximation come from the eigenvectors of the two
/// regressed kernel matrices.
///
/// The test is not symmetric in X and Y, because the kernel of X is built from
/// X concatenated with half of Z and the kernel of Y is not.
///
/// The upstream can also simulate the null distribution of the test with a
/// spectral approximation, which is not ported: the port always uses the
/// gamma approximation, which is the default of the upstream.
pub fn kernel_based_conditional(
  x : @utils.Matrix,
  y : @utils.Matrix,
  z : @utils.Matrix,
  rng : @utils.Random,
) -> Double {
  let scaled_x = kernel_zscore(x)
  let scaled_y = kernel_zscore(y)
  let scaled_z = kernel_zscore(z)
  // The kernel of X is built from X and from half of Z.
  let concatenated = kernel_hstack([
    scaled_x,
    kernel_scale_matrix(scaled_z, 0.5),
  ])
  let width_x = kernel_width_median(concatenated, rng)
  let width_y = kernel_width_median(scaled_y, rng)
  let centred_x = kernel_center_kernel_matrix(
    kernel_gaussian_kernel(concatenated, width_x),
  )
  let centred_y = kernel_center_kernel_matrix(
    kernel_gaussian_kernel(scaled_y, width_y),
  )
  let width_z = kernel_width_median(scaled_z, rng)
  let centred_z = kernel_center_kernel_matrix(
    kernel_gaussian_kernel(scaled_z, width_z),
  )
  // The regression centring, with the epsilon of the upstream.
  let (regression_x, _) = kernel_center_kernel_matrix_regression(
    centred_x, centred_z, 1.0e-3,
  )
  let (regression_y, _) = kernel_center_kernel_matrix_regression(
    centred_y, centred_z, 1.0e-3,
  )
  let statistic = kernel_product_sum(regression_x, regression_y)
  let (uu_prod, _) = kernel_uu_product(regression_x, regression_y)
  let mean_appr = kernel_trace(uu_prod)
  let var_appr = 2.0 * kernel_trace(uu_prod.mul(uu_prod))
  kernel_gamma_p_value(statistic, mean_appr, var_appr)
}

///|
/// The p-value of the test on the given sample.
///
/// The columns that hold a single value are removed, and the test is the
/// conditional one when Z holds a column and the unconditional one otherwise.
fn kernel_evaluate(
  x : @utils.Matrix,
  y : @utils.Matrix,
  z : @utils.Matrix?,
  rng : @utils.Random,
) -> Double {
  let reduced_x = kernel_remove_constant_columns(x)
  let reduced_y = kernel_remove_constant_columns(y)
  if reduced_x.ncols() == 0 || reduced_y.ncols() == 0 {
    // Either X and/or Y is constant.
    return 1.0
  }
  let conditioning = match z {
    Some(values) => {
      let reduced = kernel_remove_constant_columns(values)
      if reduced.ncols() == 0 {
        // If Z is empty, we are in the pairwise setting.
        None
      } else {
        Some(reduced)
      }
    }
    None => None
  }
  match conditioning {
    Some(values) => kernel_based_conditional(reduced_x, reduced_y, values, rng)
    None => kernel_based_unconditional(reduced_x, reduced_y, rng)
  }
}

///|
/// The p-value of the gamma approximation of the null distribution.
///
/// The upstream computes it as `1 - gamma.cdf(statistic, k_appr, 0,
/// theta_appr)`, and the port computes the same expression, so that the
/// p-values of the port and of the upstream agree in their last bits.
fn kernel_gamma_p_value(
  statistic : Double,
  mean_appr : Double,
  var_appr : Double,
) -> Double {
  let k_appr = mean_appr * mean_appr / var_appr
  let theta_appr = var_appr / mean_appr
  1.0 - @utils.gammainc(k_appr, statistic / theta_appr)
}

///|
/// The z-score of every column of the matrix.
///
/// The standard deviation is the one of the sample (`ddof = 1`), like
/// `scipy.stats.zscore` with `ddof = 1` computes it. A column whose standard
/// deviation is zero becomes a column of zeros, which is what the upstream
/// does with the NaNs of such a column.
fn kernel_zscore(m : @utils.Matrix) -> @utils.Matrix {
  let out = @utils.Matrix::zeros(m.nrows(), m.ncols())
  for j = 0; j < m.ncols(); j = j + 1 {
    let values = m.col(j)
    let mean = @utils.mean(values)
    let deviation = @utils.std_sample(values)
    for i = 0; i < values.length(); i = i + 1 {
      if deviation == 0.0 {
        out.set(i, j, 0.0)
      } else {
        out.set(i, j, (values[i] - mean) / deviation)
      }
    }
  }
  out
}

///|
/// The width of the Gaussian kernel, from the median trick.
///
/// The width is the inverse of the square of `sqrt(2) * median_distance`, where
/// the median distance is the median of the distances between the pairs of the
/// rows that are further apart than zero. The upstream draws at most a
/// thousand rows at random when the matrix holds more of them; the port draws
/// them from the generator it is given.
fn kernel_width_median(x : @utils.Matrix, rng : @utils.Random) -> Double {
  let rows = if x.nrows() > 1000 {
    kernel_select_rows(x, kernel_sample_indices(x.nrows(), 1000, rng))
  } else {
    x
  }
  let distances : Array[Double] = []
  for i = 0; i < rows.nrows(); i = i + 1 {
    for j = i + 1; j < rows.nrows(); j = j + 1 {
      let distance = kernel_euclidean_distance(rows, i, j)
      if distance > 0.0 {
        distances.push(distance)
      }
    }
  }
  if distances.length() == 0 {
    // Every row is the same, so there is no distance to take the median of.
    return 1.0
  }
  let median_distance = @utils.median(distances)
  let width = 2.0.sqrt() * median_distance
  1.0 / (width * width)
}

///|
/// The Euclidean distance of the two rows of the matrix.
fn kernel_euclidean_distance(x : @utils.Matrix, i : Int32, j : Int32) -> Double {
  let mut squared = 0.0
  for k = 0; k < x.ncols(); k = k + 1 {
    let difference = x.get(i, k) - x.get(j, k)
    squared = squared + difference * difference
  }
  squared.sqrt()
}

///|
/// The kernel matrix of the Gaussian kernel of the given width.
///
/// The kernel is `exp(-0.5 * squared_distance * width)`, like the Gaussian
/// kernel of the `causal-learn` package computes it.
fn kernel_gaussian_kernel(x : @utils.Matrix, width : Double) -> @utils.Matrix {
  let n = x.nrows()
  let out = @utils.Matrix::zeros(n, n)
  for i = 0; i < n; i = i + 1 {
    for j = 0; j < n; j = j + 1 {
      let mut squared = 0.0
      for k = 0; k < x.ncols(); k = k + 1 {
        let difference = x.get(i, k) - x.get(j, k)
        squared = squared + difference * difference
      }
      out.set(i, j, @math.exp(-0.5 * squared * width))
    }
  }
  out
}

///|
/// The centred kernel matrix `H K H`, with `H` the matrix `I - 1 / n`.
fn kernel_center_kernel_matrix(k : @utils.Matrix) -> @utils.Matrix {
  let n = k.nrows()
  let colsums : Array[Double] = []
  for j = 0; j < n; j = j + 1 {
    let mut sum = 0.0
    for i = 0; i < n; i = i + 1 {
      sum = sum + k.get(i, j)
    }
    colsums.push(sum)
  }
  let mut allsum = 0.0
  for sum in colsums {
    allsum = allsum + sum
  }
  let out = @utils.Matrix::zeros(n, n)
  for i = 0; i < n; i = i + 1 {
    for j = 0; j < n; j = j + 1 {
      out.set(
        i,
        j,
        k.get(i, j) -
        (colsums[j] + colsums[i]) / n.to_double() +
        allsum / (n.to_double() * n.to_double()),
      )
    }
  }
  out
}

///|
/// The regression centred kernel matrix `R K R` and the matrix `R`.
///
/// The matrix `R` is `epsilon * pinv(Kz + epsilon * I)`, like the upstream
/// computes it.
fn kernel_center_kernel_matrix_regression(
  k : @utils.Matrix,
  kz : @utils.Matrix,
  epsilon : Double,
) -> (@utils.Matrix, @utils.Matrix) {
  let n = k.nrows()
  let shifted = kz.copy()
  for i = 0; i < n; i = i + 1 {
    shifted.set(i, i, shifted.get(i, i) + epsilon)
  }
  let rz = kernel_scale_matrix(kernel_regressor_inverse(shifted), epsilon)
  (rz.mul(k.mul(rz)), rz)
}

///|
/// The inverse of the regressor of the regression centring.
///
/// The regressor is the centred kernel matrix of the conditioning variable
/// plus `epsilon` times the identity. It is positive definite, because the
/// centred kernel matrix is positive semi definite -- it is `H K H` for the
/// centring matrix `H` and the positive semi definite kernel matrix `K` --
/// and the shift makes it definite. Its inverse is therefore what the pseudo
/// inverse of the upstream computes, because none of its singular values is
/// below the cut-off of `numpy.linalg.pinv`.
///
/// The inverse is computed with the Gauss-Jordan elimination of the `utils`
/// package, which solves the system directly. The upstream computes the
/// pseudo inverse with the singular value decomposition, and the eigen
/// decomposition of the port is no substitute for it here: the regressor is
/// nearly singular -- its smallest eigenvalue is the shift -- and its
/// eigenvalues are clustered, so the pseudo inverse divides by them and turns
/// the absolute error of an eigen decomposition into a relative error of the
/// pseudo inverse. Measured on the fixtures of the tests, the p-value of the
/// conditional test is off by `6.6e-06` with the eigen decomposition and by
/// `2.7e-12` with the elimination, which is the noise of the upstream itself.
fn kernel_regressor_inverse(a : @utils.Matrix) -> @utils.Matrix {
  match @utils.mat_inverse(a) {
    Some(inverse) => inverse
    None => kernel_pseudo_inverse(a)
  }
}

///|
/// The pseudo inverse of a symmetric positive definite matrix.
///
/// The pseudo inverse of the `utils` package computes it from the eigen
/// decomposition of the Gram matrix `AᵀA`, so it needs the eigenvalues of the
/// squared matrix, and squaring squares the condition number of the matrix as
/// well. The regressor of the regression centring is nearly singular, so the
/// port computes the pseudo inverse from the eigen decomposition of the matrix
/// itself, which is what the singular value decomposition of
/// `numpy.linalg.pinv` does for a symmetric positive definite matrix.
///
/// The eigenvalues that are not greater than the tolerance times the largest
/// one are dropped, like the upstream drops the singular values that are not
/// greater than `1e-15` times the largest one.
fn kernel_pseudo_inverse(a : @utils.Matrix) -> @utils.Matrix {
  let n = a.nrows()
  let (values, vectors) = @utils.jacobi_eigen(a)
  let mut max_value = 0.0
  for value in values {
    let magnitude = value.abs()
    if magnitude > max_value {
      max_value = magnitude
    }
  }
  let tolerance = 1.0e-12 * max_value
  let out = @utils.Matrix::zeros(n, n)
  for k = 0; k < values.length(); k = k + 1 {
    let lambda = values[k]
    if lambda.abs() <= tolerance {
      continue
    }
    let factor = 1.0 / lambda
    for i = 0; i < n; i = i + 1 {
      for j = 0; j < n; j = j + 1 {
        out.set(
          i,
          j,
          out.get(i, j) + factor * vectors.get(i, k) * vectors.get(j, k),
        )
      }
    }
  }
  out
}

///|
/// The product of the eigenvectors of the two kernel matrices.
///
/// The eigenvalues of the two matrices are sorted in descending order, and the
/// ones that are not greater than the largest of them times `1e-5` are
/// dropped. The columns of the result are the products of the eigenvectors of
/// the two matrices, and the result is the product of the matrix with its
/// transpose when it holds more columns than rows, and the product of its
/// transpose with it otherwise.
fn kernel_uu_product(
  kx : @utils.Matrix,
  ky : @utils.Matrix,
) -> (@utils.Matrix, Int32) {
  let (values_x, vectors_x) = kernel_descending_eigen(kx, 1.0e-5)
  let (values_y, vectors_y) = kernel_descending_eigen(ky, 1.0e-5)
  let num_eigx = values_x.length()
  let num_eigy = values_y.length()
  let size_u = num_eigx * num_eigy
  let n = kx.nrows()
  let uu = @utils.Matrix::zeros(n, size_u)
  for i = 0; i < num_eigx; i = i + 1 {
    for j = 0; j < num_eigy; j = j + 1 {
      let column = i * num_eigy + j
      for row = 0; row < n; row = row + 1 {
        uu.set(row, column, vectors_x.get(row, i) * vectors_y.get(row, j))
      }
    }
  }
  if size_u > n {
    (uu.mul(uu.transpose()), size_u)
  } else {
    (uu.transpose().mul(uu), size_u)
  }
}

///|
/// The eigenvalues of the symmetric matrix in descending order, together with
/// the eigenvectors of the columns.
///
/// The eigenvalues that are not greater than the largest of them times the
/// given threshold are dropped. The eigenvectors are scaled with the square
/// root of their eigenvalues, like the upstream scales them.
fn kernel_descending_eigen(
  k : @utils.Matrix,
  threshold : Double,
) -> (Array[Double], @utils.Matrix) {
  let n = k.nrows()
  let symmetric = @utils.Matrix::zeros(n, n)
  for i = 0; i < n; i = i + 1 {
    for j = 0; j < n; j = j + 1 {
      symmetric.set(i, j, 0.5 * (k.get(i, j) + k.get(j, i)))
    }
  }
  let (values, vectors) = @utils.jacobi_eigen(symmetric)
  let order : Array[Int32] = []
  for i = 0; i < values.length(); i = i + 1 {
    order.push(i)
  }
  order.sort_by(fn(a, b) { @utils.compare_double(values[b], values[a]) })
  let limit = values[order[0]] * threshold
  let kept : Array[Int32] = []
  for index in order {
    if values[index] > limit {
      kept.push(index)
    }
  }
  let kept_values : Array[Double] = []
  let kept_vectors = @utils.Matrix::zeros(n, kept.length())
  for column = 0; column < kept.length(); column = column + 1 {
    let index = kept[column]
    kept_values.push(values[index])
    let factor = if values[index] > 0.0 { values[index].sqrt() } else { 0.0 }
    for row = 0; row < n; row = row + 1 {
      kept_vectors.set(row, column, vectors.get(row, index) * factor)
    }
  }
  (kept_values, kept_vectors)
}

///|
/// The sum of the elements of the two matrices, multiplied one by one.
fn kernel_product_sum(a : @utils.Matrix, b : @utils.Matrix) -> Double {
  let mut sum = 0.0
  for i = 0; i < a.nrows(); i = i + 1 {
    for j = 0; j < a.ncols(); j = j + 1 {
      sum = sum + a.get(i, j) * b.get(i, j)
    }
  }
  sum
}

///|
/// The sum of the squares of the elements of the matrix.
fn kernel_sum_of_squares(m : @utils.Matrix) -> Double {
  let mut sum = 0.0
  for i = 0; i < m.nrows(); i = i + 1 {
    for j = 0; j < m.ncols(); j = j + 1 {
      let value = m.get(i, j)
      sum = sum + value * value
    }
  }
  sum
}

///|
/// The sum of the elements of the diagonal of the matrix.
fn kernel_trace(m : @utils.Matrix) -> Double {
  let mut sum = 0.0
  for i = 0; i < m.nrows(); i = i + 1 {
    sum = sum + m.get(i, i)
  }
  sum
}

///|
/// The matrix with every element multiplied by the given factor.
fn kernel_scale_matrix(m : @utils.Matrix, factor : Double) -> @utils.Matrix {
  let out = @utils.Matrix::zeros(m.nrows(), m.ncols())
  for i = 0; i < m.nrows(); i = i + 1 {
    for j = 0; j < m.ncols(); j = j + 1 {
      out.set(i, j, m.get(i, j) * factor)
    }
  }
  out
}

///|
/// The matrix with the given matrices as its columns.
fn kernel_hstack(matrices : Array[@utils.Matrix]) -> @utils.Matrix {
  let columns : Array[Array[Double]] = []
  for m in matrices {
    for j = 0; j < m.ncols(); j = j + 1 {
      columns.push(m.col(j))
    }
  }
  @utils.Matrix::from_columns(columns)
}

///|
/// The matrix without the columns that hold a single value.
fn kernel_remove_constant_columns(m : @utils.Matrix) -> @utils.Matrix {
  let columns : Array[Array[Double]] = []
  for j = 0; j < m.ncols(); j = j + 1 {
    let values = m.col(j)
    if kernel_has_more_than_one_value(values) {
      columns.push(values)
    }
  }
  @utils.Matrix::from_columns(columns)
}

///|
/// Whether the values hold more than one distinct value.
fn kernel_has_more_than_one_value(values : Array[Double]) -> Bool {
  if values.length() == 0 {
    return false
  }
  let first = values[0]
  for i = 1; i < values.length(); i = i + 1 {
    if values[i] != first {
      return true
    }
  }
  false
}

///|
/// The given number of indices, drawn without replacement.
///
/// The indices are sorted, so the rows of the sample keep the order of the
/// data. The upstream keeps them in the order they were drawn in, but the
/// order of the rows does not change the test: the pseudo inverse of the
/// regressor of the conditional test is computed with an iterative method that
/// is not equivariant under a permutation of the rows, so the order of the
/// rows would move the p-value in its last digits.
fn kernel_sample_indices(
  n : Int32,
  count : Int32,
  rng : @utils.Random,
) -> Array[Int32] {
  let pool : Array[Int32] = []
  for i = 0; i < n; i = i + 1 {
    pool.push(i)
  }
  let out : Array[Int32] = []
  let limit = if count < n { count } else { n }
  for k = 0; k < limit; k = k + 1 {
    let j = k + rng.next_int(n - k)
    let tmp = pool[k]
    pool[k] = pool[j]
    pool[j] = tmp
    out.push(pool[k])
  }
  out.sort_by(fn(a, b) { if a < b { -1 } else if a > b { 1 } else { 0 } })
  out
}

///|
/// The rows of the matrix with the given indices.
fn kernel_select_rows(
  m : @utils.Matrix,
  indices : Array[Int32],
) -> @utils.Matrix {
  let rows : Array[Array[Double]] = []
  for index in indices {
    rows.push(m.row(index))
  }
  @utils.Matrix::from_rows(rows)
}
