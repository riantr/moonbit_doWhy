///|
/// The density estimators of the `gcm` package.
///
/// This is the port of `dowhy.gcm.density_estimators`. The upstream has a
/// kernel based estimator for one dimensional data and a Bayesian Gaussian
/// mixture; the port has both of them, the mixture in the file of the density
/// estimators of the package.

///|
/// A density estimator of a one dimensional distribution.
///
/// This is the port of `dowhy.gcm.density_estimator.DensityEstimator`. The
/// upstream is an abstract class with a Bayesian Gaussian mixture and a kernel
/// based estimator; the port is a single struct, because MoonBit has no
/// inheritance.
pub struct DensityEstimator {
  /// The samples of the distribution the estimator was fitted with.
  samples : Array[Double]
  /// The bandwidth of the kernel.
  bandwidth : Double
}

///|
/// A kernel based density estimator of a one dimensional distribution.
///
/// This is the port of `dowhy.gcm.density_estimators.KernelDensityEstimator1D`.
pub fn DensityEstimator::kernel_1d() -> DensityEstimator {
  { samples: [], bandwidth: 1.0, }
}

///|
/// Fit the estimator on the given samples.
///
/// This is the port of `dowhy.gcm.density_estimators.KernelDensityEstimator1D.fit`.
/// The bandwidth is the one of Silverman, which is the one of the upstream: it
/// is the standard deviation of the samples times the fifth root of four thirds
/// of the inverse of their number.
pub fn DensityEstimator::fit(
  self : DensityEstimator,
  x : Array[Double],
) -> DensityEstimator {
  let _ = self
  if x.length() == 0 {
    abort("a density estimator cannot be fitted on an empty sample")
  }
  let n = x.length().to_double()
  let bandwidth = @utils.std(x) * @math.pow(4.0 / 3.0 / n, 1.0 / 5.0)
  { samples: x.copy(), bandwidth, }
}

///|
/// The density of the given samples.
///
/// This is the port of
/// `dowhy.gcm.density_estimators.KernelDensityEstimator1D.density`. The density
/// is the one of the Gaussian kernel, which is the one of the estimator of the
/// upstream: every sample of the distribution contributes a Gaussian of the
/// bandwidth of the estimator, and the sum of the contributions is normalised by
/// the number of the samples and by the bandwidth.
pub fn DensityEstimator::density(
  self : DensityEstimator,
  x : Array[Double],
) -> Array[Double] {
  if self.samples.length() == 0 {
    abort("the density estimator has not been fitted")
  }
  let n = self.samples.length().to_double()
  let normalisation = 1.0 / (n * self.bandwidth * (2.0 * @math.PI).sqrt())
  let out : Array[Double] = []
  for value in x {
    let mut sum = 0.0
    for sample in self.samples {
      let distance = (value - sample) / self.bandwidth
      sum = sum + @math.exp(-0.5 * distance * distance)
    }
    out.push(normalisation * sum)
  }
  out
}
