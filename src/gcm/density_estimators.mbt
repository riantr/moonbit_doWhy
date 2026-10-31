///|
/// The density estimators of the `gcm` package.
///
/// This is the port of `dowhy.gcm.density_estimators`. The
/// `GaussianMixtureDensityEstimator` of the upstream code has no counterpart
/// here: it is based on `sklearn.mixture.BayesianGaussianMixture`, whose
/// variational inference the port does not have, and an estimator with
/// different numbers would not be a port of it.

///|
/// The normalisation of the gaussian kernel, `sqrt(2 * pi)`.
///
/// The version of scikit-learn that the reference environment uses divides the
/// gaussian kernel by it, so that the density it returns is a probability
/// density. The older versions left the factor out.
const GAUSSIAN_NORM : Double = 2.5066282746310002

///|
/// A kernel based density estimator for one dimensional data.
///
/// This is the port of `dowhy.gcm.density_estimators.KernelDensityEstimator1D`,
/// which uses a gaussian kernel with the bandwidth
/// `std(X) * (4 / 3 / n)^(1 / 5)`, the population standard deviation of the
/// samples.
///
/// The state of the estimator lives in mutable fields, so a copy of it shares
/// the samples it was fitted on.
pub struct KernelDensityEstimator1D {
  /// The samples the estimator was fitted on.
  mut samples : Array[Double]
  /// The bandwidth of the gaussian kernel.
  mut bandwidth : Double
  /// Whether the estimator has been fitted.
  mut fitted : Bool
}

///|
/// A kernel density estimator that has not been fitted yet.
pub fn KernelDensityEstimator1D::new() -> KernelDensityEstimator1D {
  { samples: [], bandwidth: 0.0, fitted: false, }
}

///|
/// Whether the estimator supports the given data.
///
/// The estimator only supports one dimensional data, so this is the check that
/// `fit` and `density` run before they abort. MoonBit has no exceptions, so the
/// check is public: a caller can ask whether the data is supported instead of
/// running into the abort.
pub fn KernelDensityEstimator1D::supports(x : @utils.Matrix) -> Bool {
  x.ncols() <= 1
}

///|
/// Fit the estimator on the given data.
///
/// The data has to have one column; the upstream code raises an error when it
/// has more than one.
pub fn KernelDensityEstimator1D::fit(
  self : KernelDensityEstimator1D,
  x : @utils.Matrix,
) -> Unit {
  if !KernelDensityEstimator1D::supports(x) {
    abort(
      "KernelDensityEstimator1D only supports one dimensional data, but the " +
      "data has " +
      x.ncols().to_string() +
      " columns",
    )
  }
  if x.ncols() == 0 {
    abort(
      "KernelDensityEstimator1D needs a column of data, but the data has none",
    )
  }
  let n = x.nrows()
  if n == 0 {
    abort(
      "KernelDensityEstimator1D needs at least one sample, but the data has none",
    )
  }
  let values = x.col(0)
  // The fifth root of the bandwidth factor, computed with the logarithm
  // because the `math` package of the toolchain is not imported here.
  let factor = @utils.exp(@utils.ln(4.0 / 3.0 / n.to_double()) / 5.0)
  self.samples = values
  self.bandwidth = @utils.std(values) * factor
  self.fitted = true
}

///|
/// The density of the given points.
///
/// The estimator has to be fitted before it can be used, and the data has to
/// have one column.
///
/// The density of a point is
/// `(1 / (n * bandwidth * sqrt(2 * pi))) * sum_i exp(-(x - x_i)^2 / (2 * bandwidth^2))`,
/// the gaussian kernel of scikit-learn with the normalisation it applies to it.
pub fn KernelDensityEstimator1D::density(
  self : KernelDensityEstimator1D,
  x : @utils.Matrix,
) -> Array[Double] {
  if !self.fitted {
    abort("KernelDensityEstimator1D has not been fitted")
  }
  if !KernelDensityEstimator1D::supports(x) {
    abort(
      "KernelDensityEstimator1D only supports one dimensional data, but the " +
      "data has " +
      x.ncols().to_string() +
      " columns",
    )
  }
  if x.ncols() == 0 {
    abort(
      "KernelDensityEstimator1D needs a column of data, but the data has none",
    )
  }
  let out : Array[Double] = []
  let n = self.samples.length().to_double()
  for i = 0; i < x.nrows(); i = i + 1 {
    let point = x.get(i, 0)
    let mut total = 0.0
    for sample in self.samples {
      let difference = point - sample
      total = total +
        @utils.exp(
          -(difference * difference) / (2.0 * self.bandwidth * self.bandwidth),
        )
    }
    out.push(total / (n * self.bandwidth * GAUSSIAN_NORM))
  }
  out
}
