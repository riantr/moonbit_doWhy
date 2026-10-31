/// Generalised linear models.
///
/// This is the port of the `statsmodels.api.GLM` models that DoWhy's
/// generalised linear model estimator uses. The coefficients are fitted with
/// iteratively reweighted least squares and without any penalty, which is what
/// `statsmodels` does, and the covariance of the coefficients is the pseudo
/// inverse of the weighted Gram matrix of the last step.
///
/// The three families of the upstream code are the ones DoWhy offers in its
/// tests: a normal response with the identity link, a binary response with the
/// logit link and a count response with the log link.

///|
/// The response distribution of a generalised linear model.
pub enum GlmFamily {
  /// A normal response with the identity link.
  Gaussian
  /// A binary response with the logit link.
  Binomial
  /// A count response with the log link.
  Poisson
}

///|
/// The normal family, with the identity link.
pub fn GlmFamily::gaussian() -> GlmFamily {
  Gaussian
}

///|
/// The binomial family, with the logit link.
pub fn GlmFamily::binomial() -> GlmFamily {
  Binomial
}

///|
/// The poisson family, with the log link.
pub fn GlmFamily::poisson() -> GlmFamily {
  Poisson
}

///|
/// The name of a generalised linear model family.
pub fn GlmFamily::name(self : GlmFamily) -> String {
  match self {
    Gaussian => "gaussian"
    Binomial => "binomial"
    Poisson => "poisson"
  }
}

///|
/// The result of a generalised linear model fit.
pub struct GlmFit {
  /// The fitted coefficients, the intercept first.
  beta : Array[Double]
  /// The fitted means of the response.
  mu : Array[Double]
  /// The linear predictor.
  eta : Array[Double]
  /// The covariance matrix of the coefficients.
  cov : Matrix
  /// The standard errors of the coefficients.
  se : Array[Double]
  /// The number of iterations that were performed.
  iterations : Int32
  /// Whether the solver converged.
  converged : Bool
  /// The family the model was fitted with.
  family : GlmFamily
}

///|
/// A generalised linear model without any data.
pub fn GlmFit::empty() -> GlmFit {
  {
    beta: [],
    mu: [],
    eta: [],
    cov: Matrix::zeros(0, 0),
    se: [],
    iterations: 0,
    converged: false,
    family: GlmFamily::Gaussian,
  }
}

///|
/// The derivative of the inverse link of a family, evaluated at the means of
/// the response.
///
/// The derivative is what the delta method needs to turn the covariance of the
/// coefficients into the variance of an estimate that is a function of them.
pub fn glm_link_derivative(
  family : GlmFamily,
  mu : Array[Double],
) -> Array[Double] {
  let derivative : Array[Double] = []
  for m in mu {
    match family {
      GlmFamily::Gaussian => derivative.push(1.0)
      GlmFamily::Binomial => derivative.push(m * (1.0 - m))
      GlmFamily::Poisson => derivative.push(m)
    }
  }
  derivative
}

///|
/// Fit a generalised linear model.
///
/// `x` is the design matrix, the intercept column included when one is
/// wanted, and `y` the response vector.
pub fn glm_fit(
  x : Matrix,
  y : Array[Double],
  family : GlmFamily,
  max_iter : Int32,
  tol : Double,
) -> GlmFit {
  match family {
    GlmFamily::Gaussian => gaussian_fit(x, y)
    GlmFamily::Binomial => irls_fit(x, y, family, max_iter, tol)
    GlmFamily::Poisson => irls_fit(x, y, family, max_iter, tol)
  }
}

///|
/// The predicted means of a generalised linear model.
pub fn glm_predict(fit : GlmFit, x : Matrix) -> Array[Double] {
  link_inverse(fit.family, x.matvec(fit.beta))
}

///|
/// Fit a normal response with the identity link.
///
/// The identity link turns the model into an ordinary least squares fit, and
/// the dispersion of the normal family is the one of the residual variance,
/// exactly like `statsmodels` computes it.
fn gaussian_fit(x : Matrix, y : Array[Double]) -> GlmFit {
  let ols = ols_fit(x, y)
  {
    beta: ols.beta.copy(),
    mu: ols.fitted.copy(),
    eta: ols.fitted.copy(),
    cov: ols.cov.copy(),
    se: ols.se.copy(),
    iterations: 1,
    converged: true,
    family: GlmFamily::Gaussian,
  }
}

///|
/// Fit a generalised linear model with iteratively reweighted least squares.
///
/// Every step of the iteration solves the weighted least squares problem of
/// the working response, which is the standard formulation of the fit and the
/// one `statsmodels` uses.
fn irls_fit(
  x : Matrix,
  y : Array[Double],
  family : GlmFamily,
  max_iter : Int32,
  tol : Double,
) -> GlmFit {
  let n = x.nrows()
  let p = x.ncols()
  let beta : Array[Double] = []
  for j = 0; j < p; j = j + 1 {
    beta.push(0.0)
  }
  let mut converged = false
  let mut iter = 0
  while iter < max_iter {
    iter = iter + 1
    let eta = x.matvec(beta)
    let mu = link_inverse(family, eta)
    let w = link_weights(family, mu)
    // The working response of the canonical link.
    let z : Array[Double] = []
    for i = 0; i < n; i = i + 1 {
      z.push(eta[i] + (y[i] - mu[i]) / w[i])
    }
    let new_beta = weighted_least_squares(x, w, z)
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
  let eta = x.matvec(beta)
  let mu = link_inverse(family, eta)
  let w = link_weights(family, mu)
  let cov = weighted_covariance(x, w)
  let se : Array[Double] = []
  for j = 0; j < p; j = j + 1 {
    let v = cov.get(j, j)
    se.push(if v > 0.0 { v.sqrt() } else { 0.0 })
  }
  { beta, mu, eta, cov, se, iterations: iter, converged, family, }
}

///|
/// The mean of the response for a linear predictor.
fn link_inverse(family : GlmFamily, eta : Array[Double]) -> Array[Double] {
  let mu : Array[Double] = []
  for e in eta {
    match family {
      GlmFamily::Gaussian => mu.push(e)
      GlmFamily::Binomial => mu.push(sigmoid(e))
      GlmFamily::Poisson => mu.push(@math.exp(e))
    }
  }
  mu
}

///|
/// The weight of an observation for a mean of the response.
fn link_weights(family : GlmFamily, mu : Array[Double]) -> Array[Double] {
  let w : Array[Double] = []
  for m in mu {
    match family {
      GlmFamily::Gaussian => w.push(1.0)
      GlmFamily::Binomial => w.push(m * (1.0 - m))
      GlmFamily::Poisson => w.push(m)
    }
  }
  w
}

///|
/// The weighted least squares solution of `X b ≈ z` with the weights `w`.
fn weighted_least_squares(
  x : Matrix,
  w : Array[Double],
  z : Array[Double],
) -> Array[Double] {
  let (scaled, scaled_z) = scale_rows(x, w, z)
  lstsq(scaled, scaled_z)
}

///|
/// The covariance of the coefficients of a weighted least squares fit.
///
/// It is the pseudo inverse of the weighted Gram matrix, which is what
/// `statsmodels` uses for the binomial and the poisson family, where the
/// dispersion is fixed at one.
fn weighted_covariance(x : Matrix, w : Array[Double]) -> Matrix {
  let (scaled, _) = scale_rows(x, w, [])
  let inv = mat_pinv(scaled)
  inv.mul(inv.transpose())
}

///|
/// Scale the rows of a design matrix by the square root of their weight.
fn scale_rows(
  x : Matrix,
  w : Array[Double],
  z : Array[Double],
) -> (Matrix, Array[Double]) {
  let n = x.nrows()
  let p = x.ncols()
  let scaled = Matrix::zeros(n, p)
  for i = 0; i < n; i = i + 1 {
    let root = w[i].sqrt()
    for j = 0; j < p; j = j + 1 {
      scaled.set(i, j, x.get(i, j) * root)
    }
  }
  let scaled_z : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    if z.length() > 0 {
      scaled_z.push(z[i] * w[i].sqrt())
    }
  }
  (scaled, scaled_z)
}
