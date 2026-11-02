/// Linear algebra helpers: inverse, pseudo-inverse, least squares, ordinary
/// least squares and iteratively reweighted least squares.
///
/// The implementations follow the numerical conventions that DoWhy relies on
/// through NumPy / statsmodels / scikit-learn:
/// - rank deficient designs are solved with the Moore-Penrose pseudo inverse
///   (minimum norm solution), matching `statsmodels.OLS` which uses `pinv`;
/// - the residual variance uses `df_resid = n - rank`;
/// - the generalised linear model uses IRLS with an L2 penalty whose strength
///   is `1 / C`, matching `sklearn.linear_model.LogisticRegression`.

///|
/// Invert a square matrix with Gauss-Jordan elimination and partial pivoting.
///
/// Returns `None` when the matrix is singular.
pub fn mat_inverse(m : Matrix) -> Matrix? {
  let n = m.nrows()
  if n != m.ncols() {
    return None
  }
  let a = m.copy()
  let inv = Matrix::identity(n)
  for col = 0; col < n; col = col + 1 {
    // Partial pivoting.
    let mut piv = col
    let mut piv_val = a.get(col, col).abs()
    for r = col + 1; r < n; r = r + 1 {
      let v = a.get(r, col).abs()
      if v > piv_val {
        piv_val = v
        piv = r
      }
    }
    if piv_val < 1.0e-300 {
      return None
    }
    if piv != col {
      for j = 0; j < n; j = j + 1 {
        let t = a.get(col, j)
        a.set(col, j, a.get(piv, j))
        a.set(piv, j, t)
        let t2 = inv.get(col, j)
        inv.set(col, j, inv.get(piv, j))
        inv.set(piv, j, t2)
      }
    }
    let d = a.get(col, col)
    for j = 0; j < n; j = j + 1 {
      a.set(col, j, a.get(col, j) / d)
      inv.set(col, j, inv.get(col, j) / d)
    }
    for r = 0; r < n; r = r + 1 {
      if r == col {
        continue
      }
      let factor = a.get(r, col)
      if factor == 0.0 {
        continue
      }
      for j = 0; j < n; j = j + 1 {
        a.set(r, j, a.get(r, j) - factor * a.get(col, j))
        inv.set(r, j, inv.get(r, j) - factor * inv.get(col, j))
      }
    }
  }
  Some(inv)
}

///|
/// The determinant of a square matrix, by Gaussian elimination with partial
/// pivoting.
///
/// The determinant of a matrix that is not square is zero. The elimination is the
/// one of `numpy.linalg.det`, so the result is the same number.
pub fn mat_determinant(m : Matrix) -> Double {
  let n = m.nrows()
  if n != m.ncols() {
    return 0.0
  }
  if n == 0 {
    return 1.0
  }
  let a = m.copy()
  let mut determinant = 1.0
  for col = 0; col < n; col = col + 1 {
    // Partial pivoting.
    let mut piv = col
    let mut piv_val = a.get(col, col).abs()
    for r = col + 1; r < n; r = r + 1 {
      let v = a.get(r, col).abs()
      if v > piv_val {
        piv_val = v
        piv = r
      }
    }
    if piv_val == 0.0 {
      // The matrix is singular, so its determinant is zero.
      return 0.0
    }
    if piv != col {
      for j = 0; j < n; j = j + 1 {
        let t = a.get(col, j)
        a.set(col, j, a.get(piv, j))
        a.set(piv, j, t)
      }
      // One row exchange, so the sign of the determinant flips.
      determinant = -determinant
    }
    let pivot = a.get(col, col)
    determinant = determinant * pivot
    for r = col + 1; r < n; r = r + 1 {
      let factor = a.get(r, col) / pivot
      if factor == 0.0 {
        continue
      }
      for j = col + 1; j < n; j = j + 1 {
        a.set(r, j, a.get(r, j) - factor * a.get(col, j))
      }
    }
  }
  determinant
}

///|
/// Symmetric eigen decomposition by the cyclic Jacobi method.
///
/// Returns the eigenvalues together with the eigenvectors stored as columns.
///
/// The iteration stops when the off-diagonal part of the matrix is negligible
/// against the matrix itself: the sum of the squares of the off-diagonal
/// elements has to be at most the square of the machine epsilon times the sum
/// of the squares of the elements of the matrix. The criterion is relative on
/// purpose. An absolute criterion leaves the off-diagonal elements of the
/// matrix at a size of about `3e-8`, which is enough for the eigenvalues of a
/// matrix with a well separated spectrum, but not for the eigenvalues of a
/// nearly degenerate one: those are then only accurate to about `1e-9`.
pub fn jacobi_eigen(a : Matrix) -> (Array[Double], Matrix) {
  let n = a.nrows()
  let m = a.copy()
  let v = Matrix::identity(n)
  // The machine epsilon of a double, and the limit the residual of the
  // iteration has to fall below.
  let epsilon = 2.220446049250313e-16
  let mut total = 0.0
  for i = 0; i < n; i = i + 1 {
    for j = 0; j < n; j = j + 1 {
      total = total + m.get(i, j) * m.get(i, j)
    }
  }
  let limit = epsilon * epsilon * total
  let mut sweep = 0
  let mut previous = 0.0
  while sweep < 100 {
    sweep = sweep + 1
    let mut off = 0.0
    for i = 0; i < n; i = i + 1 {
      for j = i + 1; j < n; j = j + 1 {
        off = off + m.get(i, j) * m.get(i, j)
      }
    }
    if off <= limit {
      break
    }
    if sweep > 1 && off > previous * 0.5 {
      // The iteration does not improve the residual any more, so it has
      // reached the floor of the method.
      break
    }
    previous = off
    for p = 0; p < n - 1; p = p + 1 {
      for q = p + 1; q < n; q = q + 1 {
        let apq = m.get(p, q)
        if apq.abs() < 1.0e-300 {
          continue
        }
        let app = m.get(p, p)
        let aqq = m.get(q, q)
        let theta = (aqq - app) / (2.0 * apq)
        let t = if theta >= 0.0 {
          1.0 / (theta + (1.0 + theta * theta).sqrt())
        } else {
          -1.0 / (-theta + (1.0 + theta * theta).sqrt())
        }
        let c = 1.0 / (1.0 + t * t).sqrt()
        let s = t * c
        for k = 0; k < n; k = k + 1 {
          let akp = m.get(k, p)
          let akq = m.get(k, q)
          m.set(k, p, c * akp - s * akq)
          m.set(k, q, s * akp + c * akq)
        }
        for k = 0; k < n; k = k + 1 {
          let apk = m.get(p, k)
          let aqk = m.get(q, k)
          m.set(p, k, c * apk - s * aqk)
          m.set(q, k, s * apk + c * aqk)
        }
        for k = 0; k < n; k = k + 1 {
          let vkp = v.get(k, p)
          let vkq = v.get(k, q)
          v.set(k, p, c * vkp - s * vkq)
          v.set(k, q, s * vkp + c * vkq)
        }
      }
    }
  }
  let values : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    values.push(m.get(i, i))
  }
  (values, v)
}

///|
/// Moore-Penrose pseudo inverse of a matrix.
///
/// The pseudo inverse is obtained from the eigen decomposition of `AᵀA`, so
/// rank deficient designs give the minimum norm least squares solution, the
/// same convention `statsmodels` uses for `OLS`.
pub fn mat_pinv(a : Matrix) -> Matrix {
  let at = a.transpose()
  let gram = at.mul(a)
  let (values, vectors) = jacobi_eigen(gram)
  let p = a.ncols()
  let mut max_val = 0.0
  for i = 0; i < values.length(); i = i + 1 {
    let v = values[i].abs()
    if v > max_val {
      max_val = v
    }
  }
  let tol = 1.0e-12 * max_val
  // (AᵀA)⁺ = V diag(1/λ) Vᵀ
  let inv_gram = Matrix::zeros(p, p)
  for k = 0; k < p; k = k + 1 {
    let lam = values[k]
    if lam.abs() <= tol {
      continue
    }
    let inv_lam = 1.0 / lam
    for i = 0; i < p; i = i + 1 {
      for j = 0; j < p; j = j + 1 {
        inv_gram.set(
          i,
          j,
          inv_gram.get(i, j) + inv_lam * vectors.get(i, k) * vectors.get(j, k),
        )
      }
    }
  }
  // P = (AᵀA)⁺ Aᵀ   -> shape (p, n)
  inv_gram.mul(at)
}

///|
/// Least squares solution of `A x ≈ b` (minimum norm when rank deficient).
pub fn lstsq(a : Matrix, b : Array[Double]) -> Array[Double] {
  let p_inv = mat_pinv(a)
  p_inv.matvec(b)
}

///|
/// Result of an ordinary least squares fit.
pub struct OlsFit {
  /// Fitted coefficients.
  beta : Array[Double]
  /// Fitted values.
  fitted : Array[Double]
  /// Residuals.
  residuals : Array[Double]
  /// Residual sum of squares.
  rss : Double
  /// Number of observations.
  n : Int32
  /// Numerical rank of the design matrix.
  rank : Int32
  /// Residual degrees of freedom (`n - rank`).
  df_resid : Int32
  /// Estimated residual variance.
  sigma2 : Double
  /// Covariance matrix of the coefficients.
  cov : Matrix
  /// Standard errors of the coefficients.
  se : Array[Double]
  /// t statistics of the coefficients.
  tstat : Array[Double]
}

///|
/// An ordinary least squares fit without any data.
pub fn OlsFit::empty() -> OlsFit {
  {
    beta: [],
    fitted: [],
    residuals: [],
    rss: 0.0,
    n: 0,
    rank: 0,
    df_resid: 0,
    sigma2: 0.0,
    cov: Matrix::zeros(0, 0),
    se: [],
    tstat: [],
  }
}

///|
/// Fit an ordinary least squares model.
///
/// `x` is the design matrix (already including the intercept column when one
/// is wanted) and `y` the response vector.
pub fn ols_fit(x : Matrix, y : Array[Double]) -> OlsFit {
  let n = x.nrows()
  let p = x.ncols()
  let beta = lstsq(x, y)
  let fitted = x.matvec(beta)
  let residuals : Array[Double] = []
  let mut rss = 0.0
  for i = 0; i < n; i = i + 1 {
    let r = y[i] - fitted[i]
    residuals.push(r)
    rss = rss + r * r
  }
  let xt = x.transpose()
  let gram = xt.mul(x)
  let (values, vectors) = jacobi_eigen(gram)
  let mut max_val = 0.0
  for i = 0; i < values.length(); i = i + 1 {
    let v = values[i].abs()
    if v > max_val {
      max_val = v
    }
  }
  let tol = 1.0e-12 * max_val
  let mut rank = 0
  for i = 0; i < values.length(); i = i + 1 {
    if values[i].abs() > tol {
      rank = rank + 1
    }
  }
  let df_resid = n - rank
  let sigma2 = if df_resid > 0 { rss / df_resid.to_double() } else { 0.0 }
  let inv_gram = Matrix::zeros(p, p)
  for k = 0; k < p; k = k + 1 {
    let lam = values[k]
    if lam.abs() <= tol {
      continue
    }
    let inv_lam = sigma2 / lam
    for i = 0; i < p; i = i + 1 {
      for j = 0; j < p; j = j + 1 {
        inv_gram.set(
          i,
          j,
          inv_gram.get(i, j) + inv_lam * vectors.get(i, k) * vectors.get(j, k),
        )
      }
    }
  }
  let se : Array[Double] = []
  let tstat : Array[Double] = []
  for i = 0; i < p; i = i + 1 {
    let v = inv_gram.get(i, i).abs()
    let s = if v > 0.0 { v.sqrt() } else { 0.0 }
    se.push(s)
    tstat.push(if s > 0.0 { beta[i] / s } else { 0.0 })
  }
  {
    beta,
    fitted,
    residuals,
    rss,
    n,
    rank,
    df_resid,
    sigma2,
    cov: inv_gram,
    se,
    tstat,
  }
}

///|
/// Result of a logistic regression fit.
pub struct LogisticFit {
  /// Fitted coefficients (intercept first).
  beta : Array[Double]
  /// Number of IRLS iterations that were performed.
  iterations : Int32
  /// Whether the solver converged.
  converged : Bool
}

///|
/// Fit a logistic regression with an L2 penalty.
///
/// The objective minimised is
/// `sum_i log_loss(y_i, p_i) + 1/(2C) * ||w||²`, which is the convention
/// used by `sklearn.linear_model.LogisticRegression` with the default
/// `penalty="l2"` and `C=1.0`.
pub fn logistic_fit(
  x : Matrix,
  y : Array[Double],
  c : Double,
  max_iter : Int32,
  tol : Double,
) -> LogisticFit {
  let n = x.nrows()
  let p = x.ncols()
  let beta : Array[Double] = []
  for j = 0; j < p; j = j + 1 {
    beta.push(0.0)
  }
  let lambda = 1.0 / c
  let mut converged = false
  let mut iter = 0
  while iter < max_iter {
    iter = iter + 1
    // Working response and weights for the IRLS step.
    let eta = x.matvec(beta)
    let w : Array[Double] = []
    let z : Array[Double] = []
    for i = 0; i < n; i = i + 1 {
      let e = eta[i]
      let m = sigmoid(e)
      let ww_raw = m * (1.0 - m)
      let ww = if ww_raw > 1.0e-10 { ww_raw } else { 1.0e-10 }
      w.push(ww)
      z.push(e + (y[i] - m) / ww)
    }
    // Weighted least squares step with the ridge term on the slopes.
    //
    // The weighted normal equations are accumulated over the rows of the
    // design matrix: `h` is `X^T W X` and `rhs` is `X^T W z`.  The diagonal
    // weight matrix would hold `n * n` doubles, which is eighty gigabytes for
    // the hundred thousand rows of the upstream test suite, so it is never
    // built.
    let h_data : Array[Double] = []
    for k = 0; k < p * p; k = k + 1 {
      h_data.push(0.0)
    }
    let rhs : Array[Double] = []
    for k = 0; k < p; k = k + 1 {
      rhs.push(0.0)
    }
    for i = 0; i < n; i = i + 1 {
      let wi = w[i]
      let zi = z[i]
      for k = 0; k < p; k = k + 1 {
        let xk = x.get(i, k)
        rhs[k] = rhs[k] + xk * wi * zi
        let xkw = xk * wi
        for j = 0; j < p; j = j + 1 {
          h_data[k * p + j] = h_data[k * p + j] + xkw * x.get(i, j)
        }
      }
    }
    let h = Matrix::from_flat(p, p, h_data)
    for j = 1; j < p; j = j + 1 {
      h.set(j, j, h.get(j, j) + lambda)
    }
    let new_beta = match mat_inverse(h) {
      Some(inv) => inv.matvec(rhs)
      None => lstsq(h, rhs)
    }
    let mut delta = 0.0
    for j = 0; j < p; j = j + 1 {
      let d = (new_beta[j] - beta[j]).abs()
      if d > delta {
        delta = d
      }
    }
    for j = 0; j < p; j = j + 1 {
      beta[j] = new_beta[j]
    }
    if delta < tol {
      converged = true
      break
    }
  }
  { beta, iterations: iter, converged, }
}

///|
/// Logistic function.
pub fn sigmoid(x : Double) -> Double {
  if x >= 0.0 {
    1.0 / (1.0 + @math.exp(-x))
  } else {
    let e = @math.exp(x)
    e / (1.0 + e)
  }
}

///|
/// Predicted probabilities of a logistic model.
pub fn logistic_predict(beta : Array[Double], x : Matrix) -> Array[Double] {
  let out : Array[Double] = []
  for i = 0; i < x.nrows(); i = i + 1 {
    let mut e = 0.0
    for j = 0; j < x.ncols(); j = j + 1 {
      e = e + beta[j] * x.get(i, j)
    }
    out.push(sigmoid(e))
  }
  out
}
