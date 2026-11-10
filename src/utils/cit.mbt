///|
/// The tests of the conditional independence of the columns of a table.
///
/// This is the port of `dowhy.utils.cit`, the module of the upstream that the
/// graph refuter of the upstream builds on.
///
/// The upstream takes a `pandas.DataFrame` and the names of its columns. The
/// port takes the columns themselves and the index of every one of them,
/// because the `utils` package is below the `api` package, which owns the
/// frame of the library.

///|
/// The partial correlation of two columns, given the other columns.
///
/// This is the port of the dictionary `dowhy.utils.cit.partial_corr` returns.
pub struct PartialCorrelation {
  /// The number of the rows the correlation was computed on.
  n : Int32
  /// The partial correlation coefficient.
  r : Double
  /// The lower bound of the confidence interval of the coefficient.
  ci_lower : Double
  /// The upper bound of the confidence interval of the coefficient.
  ci_upper : Double
  /// The p-value of the test of the independence of the two columns.
  p_value : Double
}

///|
/// The confidence interval of a correlation coefficient.
///
/// This is the port of `dowhy.utils.cit.compute_ci`. The interval is the one
/// of the Fisher z transform: the coefficient is transformed, the interval is
/// computed around it and it is transformed back.
///
/// The upstream takes the number of the rows of the two columns, but it only
/// uses the number of the rows of the first one, so the port takes one number.
pub fn compute_ci(
  r : Double,
  nx : Int32,
  confidence : Double,
) -> (Double, Double) {
  let z = @math.atanh(r)
  let se = 1.0 / (nx.to_double() - 3.0).sqrt()
  let crit = normal_ppf((1.0 - confidence) / 2.0).abs()
  let lower = @math.tanh(z - crit * se)
  let upper = @math.tanh(z + crit * se)
  (lower, upper)
}

///|
/// The partial correlation of two columns, given the other columns.
///
/// This is the port of `dowhy.utils.cit.partial_corr`. The correlation is the
/// correlation of the residuals of the two regressions of the columns on the
/// other ones, and the upstream computes it with the pseudo inverse of the
/// covariance matrix of the columns.
///
/// The `correlation` is `"spearman"` for the correlation of the ranks of the
/// columns and `"pearson"` for the correlation of the columns themselves.
/// The upstream treats every kind of correlation but `"spearman"` as the
/// Pearson correlation.
///
/// The rows that hold a missing value in one of the columns are dropped, like
/// the upstream drops them.
pub fn partial_corr(
  columns : Array[Array[Double]],
  x : Int32,
  y : Int32,
  z : Array[Int32],
  correlation : String,
) -> PartialCorrelation {
  let selected = selected_columns(x, y, z)
  let kept = complete_columns(columns, selected)
  let n = if kept.length() > 0 { kept[0].length() } else { 0 }
  let k = selected.length() - 2
  let values = if correlation == "spearman" {
    let ranked : Array[Array[Double]] = []
    for column in kept {
      ranked.push(average_rank(column))
    }
    ranked
  } else {
    kept
  }
  let covariance = covariance_matrix(values)
  let inverse = hermitian_pinv(covariance)
  let scale : Array[Double] = []
  for i in 0..<inverse.nrows() {
    scale.push((1.0 / inverse.get(i, i)).sqrt())
  }
  let mut r = 0.0
  for i in 0..<inverse.nrows() {
    for j in 0..<inverse.ncols() {
      let value = -scale[i] * inverse.get(i, j) * scale[j]
      if i == 0 && j == 1 {
        r = value
      }
    }
  }
  if is_nan(r) {
    return { n, r, ci_lower: r, ci_upper: r, p_value: r, }
  }
  let dof = n - k - 2
  let tval = r * (dof.to_double() / (1.0 - r * r)).sqrt()
  let pval = t_pvalue(tval, dof.to_double())
  let (lower, upper) = compute_ci(r, n - k, 0.95)
  {
    n,
    r,
    ci_lower: round_half_even(lower * 1000.0) / 1000.0,
    ci_upper: round_half_even(upper * 1000.0) / 1000.0,
    p_value: round_half_even(pval * 100000.0) / 100000.0,
  }
}

///|
/// The entropy of the values of a categorical variable.
///
/// This is the port of `dowhy.utils.cit.entropy`. The entropy is measured in
/// bits, like the entropy of the upstream, which uses the base two logarithm.
pub fn entropy(values : Array[String]) -> Double {
  let counts : Map[String, Int32] = Map([])
  for value in values {
    let count = match counts.get(value) {
      Some(number) => number
      None => 0
    }
    counts.set(value, count + 1)
  }
  let total = values.length().to_double()
  let mut result = 0.0
  for value in counts.keys() {
    let count = match counts.get(value) {
      Some(number) => number
      None => 0
    }
    let probability = count.to_double() / total
    result = result - probability * (ln(probability) / ln(2.0))
  }
  result
}

///|
/// The conditional mutual information of the upstream.
///
/// This is the port of `dowhy.utils.cit.conditional_MI`.
///
/// The upstream reads the *names* of the columns of the two variables and not
/// their values: it indexes the frame with a list, which gives a frame and not
/// a column, and it walks the names of that frame. The entropy of the pairs
/// and of the triples is therefore the entropy of a single category, which is
/// zero, and the conditional mutual information of the upstream is the
/// negative entropy of the conditioning columns.
///
/// The port reproduces that number, because the decision of the graph refuter
/// of the upstream depends on it: the conditional independence of the discrete
/// data is always satisfied. The upstream also takes the two variables, but
/// its number does not depend on them, so the port takes the conditioning
/// columns alone.
pub fn conditional_mi(z : Array[Array[String]]) -> Double {
  let h_xz = entropy([""])
  let h_yz = entropy([""])
  let h_xyz = entropy([""])
  let keys : Array[String] = []
  let rows = if z.length() > 0 { z[0].length() } else { 0 }
  for row in 0..<rows {
    keys.push(join_values(z, row))
  }
  let h_z = entropy(keys)
  h_xz + h_yz - h_xyz - h_z
}

///|
/// The key of the row of the given columns.
///
/// The upstream builds the key of a row with the text of the values of
/// the row, and the port does the same.
fn join_values(columns : Array[Array[String]], row : Int32) -> String {
  let mut key = ""
  for i in 0..<columns.length() {
    if i > 0 {
      key = key + "/"
    }
    key = key + columns[i][row]
  }
  key
}

///|
/// The columns of the partial correlation, the two of them first.
fn selected_columns(x : Int32, y : Int32, z : Array[Int32]) -> Array[Int32] {
  let selected = [x, y]
  for index in z {
    selected.push(index)
  }
  selected
}

///|
/// The given columns, without the rows that hold a missing value in one
/// of them.
fn complete_columns(
  columns : Array[Array[Double]],
  selected : Array[Int32],
) -> Array[Array[Double]] {
  let rows = if selected.length() > 0 {
    columns[selected[0]].length()
  } else {
    0
  }
  let mut complete = true
  for index in selected {
    let column = columns[index]
    for row in 0..<rows {
      if is_nan(column[row]) {
        complete = false
        break
      }
    }
    if !complete {
      break
    }
  }
  if complete {
    let result : Array[Array[Double]] = []
    for index in selected {
      result.push(columns[index])
    }
    return result
  }
  let kept : Array[Int32] = []
  for row in 0..<rows {
    let mut complete = true
    for index in selected {
      if is_nan(columns[index][row]) {
        complete = false
      }
    }
    if complete {
      kept.push(row)
    }
  }
  let result : Array[Array[Double]] = []
  for index in selected {
    let values : Array[Double] = []
    for row in kept {
      values.push(columns[index][row])
    }
    result.push(values)
  }
  result
}

///|
/// The covariance matrix of the given columns.
///
/// The covariance is the one of pandas, which drops the degree of freedom.
fn covariance_matrix(columns : Array[Array[Double]]) -> Matrix {
  let n = columns.length()
  let matrix = Matrix::zeros(n, n)
  let means : Array[Double] = []
  for column in columns {
    means.push(mean(column))
  }
  for i in 0..<n {
    for j in i..<n {
      let value = centred_covariance(columns[i], columns[j], means[i], means[j])
      matrix.set(i, j, value)
      matrix.set(j, i, value)
    }
  }
  matrix
}

///|
/// The covariance of two columns, given their means.
///
/// This is the port of the covariance of `pandas.DataFrame.cov`, which drops
/// the degree of freedom.
fn centred_covariance(
  x : Array[Double],
  y : Array[Double],
  mx : Double,
  my : Double,
) -> Double {
  let n = x.length()
  if n < 2 {
    return 0.0
  }
  let mut s = 0.0
  for i in 0..<n {
    s = s + (x[i] - mx) * (y[i] - my)
  }
  s / (n - 1).to_double()
}

///|
/// The pseudo inverse of a symmetric matrix.
///
/// This is the port of `numpy.linalg.pinv(matrix, hermitian=True)`, which the
/// upstream uses in the partial correlation. The pseudo inverse of the `utils`
/// package works on the Gram matrix of the matrix, and its cut-off acts on
/// the square of the eigenvalues, so the port keeps the two apart.
fn hermitian_pinv(a : Matrix) -> Matrix {
  let (values, vectors) = jacobi_eigen(a)
  let n = values.length()
  let mut largest = 0.0
  for i in 0..<n {
    let value = values[i].abs()
    if value > largest {
      largest = value
    }
  }
  let tolerance = 1.0e-15 * largest
  let inverse = Matrix::zeros(n, n)
  for k in 0..<n {
    let value = values[k]
    if value <= tolerance {
      continue
    }
    let scale = 1.0 / value
    for i in 0..<n {
      for j in 0..<n {
        inverse.set(
          i,
          j,
          inverse.get(i, j) + scale * vectors.get(i, k) * vectors.get(j, k),
        )
      }
    }
  }
  inverse
}
