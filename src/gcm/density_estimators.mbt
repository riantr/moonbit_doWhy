///|
/// The density estimators of the `gcm` package.
///
/// This is the port of `dowhy.gcm.density_estimators`: the kernel based
/// estimator of one dimension and the Gaussian mixture.  The mixture of the
/// upstream is fitted with the variational inference of
/// `sklearn.mixture.BayesianGaussianMixture`; the port fits the same model
/// with the mean field variational update, and it draws the centres of the
/// components from the data, where the upstream draws them at random and does
/// not seed its generator.

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

// ---------------------------------------------------------------------------
// The Gaussian mixture
// ---------------------------------------------------------------------------

///|
/// The number of the iterations of the variational update of the mixture.
const MIXTURE_MAX_ITERATIONS : Int32 = 100

///|
/// The change of the responsibilities that stops the variational update.
const MIXTURE_TOLERANCE : Double = 1.0e-8

///|
/// A density estimator based on a Gaussian mixture.
///
/// This is the port of
/// `dowhy.gcm.density_estimators.GaussianMixtureDensityEstimator`, whose fit
/// is a variational Bayesian Gaussian mixture.  The port fits the same model
/// with the mean field variational update, so a component of the mixture has
/// the same meaning on both sides: a weight, a mean and a covariance.
///
/// The numbers of the port are not the numbers of the upstream.  The upstream
/// draws the centres of its components at random and does not seed its
/// generator, so its own fit is not reproducible; the case of the upstream
/// asserts the length of the result and not its values.
pub struct GaussianMixtureDensityEstimator {
  /// The number of the components of the mixture, zero when the estimator
  /// takes it from the number of the samples.
  num_components : Int32
  /// The weights of the components.
  mut weights : Array[Double]
  /// The means of the components.
  mut means : Array[Array[Double]]
  /// The expected precisions of the components.
  mut precisions : Array[@utils.Matrix]
  /// Whether the estimator has been fitted.
  mut fitted : Bool
}

///|
/// A density estimator that has not been fitted yet.
///
/// The number of the components is zero, which means that the estimator takes
/// the number of the components of the upstream: the ceiling of the square
/// root of half of the number of the samples.
pub fn GaussianMixtureDensityEstimator::new(
  num_components~ : Int32 = 0,
) -> GaussianMixtureDensityEstimator {
  { num_components, weights: [], means: [], precisions: [], fitted: false, }
}

///|
/// Whether the estimator has been fitted.
///
/// The estimator has to be fitted before its density can be computed.  The
/// upstream raises an error when it is not, and MoonBit cannot catch the
/// abort of a method, so the check is public.
pub fn GaussianMixtureDensityEstimator::is_fitted(
  self : GaussianMixtureDensityEstimator,
) -> Bool {
  self.fitted
}

///|
/// Whether the estimator supports the given data.
///
/// The upstream refuses a mixture with more components than samples, so the
/// estimator refuses it as well.  MoonBit has no exceptions, so the estimator
/// aborts and the check that tells whether the data is supported is public.
pub fn GaussianMixtureDensityEstimator::supports(
  self : GaussianMixtureDensityEstimator,
  x : @utils.Matrix,
) -> Bool {
  let samples = x.nrows()
  if samples == 0 || x.ncols() == 0 {
    return false
  }
  let requested = if self.num_components > 0 {
    self.num_components
  } else {
    (samples.to_double() / 2.0).sqrt().ceil().to_int()
  }
  requested <= samples
}

///|
/// The number of the components of the mixture.
pub fn GaussianMixtureDensityEstimator::components(
  self : GaussianMixtureDensityEstimator,
) -> Int32 {
  self.weights.length()
}

///|
/// The weights of the components of the mixture.
pub fn GaussianMixtureDensityEstimator::component_weights(
  self : GaussianMixtureDensityEstimator,
) -> Array[Double] {
  self.weights.copy()
}

///|
/// The means of the components of the mixture.
pub fn GaussianMixtureDensityEstimator::component_means(
  self : GaussianMixtureDensityEstimator,
) -> Array[Array[Double]] {
  self.means.copy()
}

///|
/// Fit the estimator on the given data.
///
/// The fit is the mean field variational update of a Gaussian mixture: the
/// responsibilities of the components are updated with the expectations of the
/// log weights, of the log determinant of the precisions and of the quadratic
/// form of the precisions, and the parameters of the components are updated
/// with the responsibilities.
///
/// The number of the components is the one of the upstream when the estimator
/// was not given one: the ceiling of the square root of half of the number of
/// the samples.
pub fn GaussianMixtureDensityEstimator::fit(
  self : GaussianMixtureDensityEstimator,
  x : @utils.Matrix,
) -> Unit {
  let samples = x.nrows()
  let features = x.ncols()
  if samples == 0 || features == 0 {
    abort("a Gaussian mixture cannot be fitted on an empty sample")
  }
  let requested = if self.num_components > 0 {
    self.num_components
  } else {
    (samples.to_double() / 2.0).sqrt().ceil().to_int()
  }
  if requested > samples {
    // The upstream refuses a mixture with more components than samples.
    abort(
      "Expected n_samples >= n_components but got n_components = " +
      requested.to_string() +
      ", n_samples = " +
      samples.to_string(),
    )
  }
  let components = if requested < 1 { 1 } else { requested }
  let fitted = fit_mixture(x, components)
  self.weights = fitted.weights
  self.means = fitted.means
  self.precisions = fitted.precisions
  self.fitted = true
}

///|
/// The density of the given points.
///
/// The estimator has to be fitted before its density can be computed.  The
/// density is the density of the mixture: the sum of the weighted densities of
/// the gaussians of the components.
pub fn GaussianMixtureDensityEstimator::density(
  self : GaussianMixtureDensityEstimator,
  x : @utils.Matrix,
) -> Array[Double] {
  if !self.fitted {
    abort("GaussianMixtureDensityEstimator has not been fitted")
  }
  let samples = x.nrows()
  let features = x.ncols()
  let components = self.weights.length()
  // The log determinants of the precisions of the components.
  let log_determinants : Array[Double] = []
  for k in 0..<components {
    log_determinants.push(log_determinant(self.precisions[k]))
  }
  let out : Array[Double] = []
  for i in 0..<samples {
    let values : Array[Double] = []
    let mut largest = 0.0
    for k in 0..<components {
      let mean = self.means[k]
      let difference : Array[Double] = []
      for j in 0..<features {
        difference.push(x.get(i, j) - mean[j])
      }
      let product = self.precisions[k].matvec(difference)
      let quadratic = dot(difference, product)
      let value = @math.ln(self.weights[k]) -
        0.5 *
        (
          features.to_double() * @math.ln(2.0 * @math.PI) -
          log_determinants[k] +
          quadratic
        )
      values.push(value)
      if k == 0 || value > largest {
        largest = value
      }
    }
    // The sum of the exponentials, computed with the largest one in the
    // exponent so that the sum does not overflow.
    let mut sum = 0.0
    for value in values {
      sum = sum + @math.exp(value - largest)
    }
    out.push(@math.exp(largest + @math.ln(sum)))
  }
  out
}

///|
/// The parameters of the components of a mixture.
priv struct MixtureParameters {
  /// The weight of every component.
  weights : Array[Double]
  /// The mean of every component.
  means : Array[Array[Double]]
  /// The scatter of every component.
  scatters : Array[@utils.Matrix]
  /// The number of the samples of every component.
  counts : Array[Double]
  /// The degrees of freedom of every component.
  degrees : Array[Double]
}

///|
/// A fitted mixture: the weights, the means and the expected precisions of the
/// components.
priv struct FittedMixture {
  weights : Array[Double]
  means : Array[Array[Double]]
  precisions : Array[@utils.Matrix]
}

///|
/// Fit a Gaussian mixture on the given data with the mean field variational
/// update of Bishop.
fn fit_mixture(x : @utils.Matrix, components : Int32) -> FittedMixture {
  let mut previous_means = initial_means(x, components)
  let mut parameters = m_step(
    x,
    initial_responsibilities(x, components),
    previous_means,
    components,
  )
  let mut responsibilities = e_step(x, parameters)
  for _ in 1..<MIXTURE_MAX_ITERATIONS {
    previous_means = parameters.means
    parameters = m_step(x, responsibilities, previous_means, components)
    let updated = e_step(x, parameters)
    // The update stops when the responsibilities hardly move.
    if change_of_responsibilities(responsibilities, updated) < MIXTURE_TOLERANCE {
      break
    }
    responsibilities = updated
  }
  // The expected precisions of the components.
  let precisions : Array[@utils.Matrix] = []
  for k in 0..<components {
    precisions.push(expected_precision(parameters, k))
  }
  { weights: parameters.weights, means: parameters.means, precisions, }
}

///|
/// The parameters of the components after one step of the update.
fn m_step(
  x : @utils.Matrix,
  responsibilities : Array[Array[Double]],
  previous_means : Array[Array[Double]],
  components : Int32,
) -> MixtureParameters {
  let samples = x.nrows()
  let features = x.ncols()
  let weights : Array[Double] = []
  let means : Array[Array[Double]] = []
  let scatters : Array[@utils.Matrix] = []
  let counts : Array[Double] = []
  let degrees : Array[Double] = []
  for k in 0..<components {
    let mut count = 0.0
    for i in 0..<samples {
      count = count + responsibilities[i][k]
    }
    counts.push(count)
    degrees.push(count + features.to_double() + 2.0)
    // The mean of the component.
    let mean : Array[Double] = []
    for _ in 0..<features {
      mean.push(0.0)
    }
    if count > 1.0e-10 {
      for j in 0..<features {
        let mut sum = 0.0
        for i in 0..<samples {
          sum = sum + responsibilities[i][k] * x.get(i, j)
        }
        mean[j] = sum / count
      }
    } else {
      // A component without a sample keeps the mean it had.
      for j in 0..<features {
        mean[j] = previous_means[k][j]
      }
    }
    means.push(mean)
    // The scatter of the component.
    let scatter = @utils.Matrix::zeros(features, features)
    for i in 0..<samples {
      let weight = responsibilities[i][k]
      if weight == 0.0 {
        continue
      }
      for a in 0..<features {
        for b in 0..<features {
          let first = x.get(i, a) - mean[a]
          let second = x.get(i, b) - mean[b]
          scatter.set(a, b, scatter.get(a, b) + weight * first * second)
        }
      }
    }
    // The prior pulls the mean of the component back to the prior mean, which
    // is the zero vector.
    if count > 1.0e-10 {
      for a in 0..<features {
        for b in 0..<features {
          scatter.set(
            a,
            b,
            scatter.get(a, b) + mean[a] * mean[b] * (1.0 - 1.0 / count),
          )
        }
      }
    }
    scatters.push(scatter)
  }
  // The weights are the means of the Dirichlet posteriors of the weights.
  let mut total = 0.0
  for count in counts {
    total = total + 1.0 + count
  }
  for count in counts {
    weights.push((1.0 + count) / total)
  }
  { weights, means, scatters, counts, degrees, }
}

///|
/// The responsibilities of the components after one step of the update.
fn e_step(
  x : @utils.Matrix,
  parameters : MixtureParameters,
) -> Array[Array[Double]] {
  let samples = x.nrows()
  let features = x.ncols()
  let components = parameters.weights.length()
  // The expectations of the log weights.
  let mut total_concentration = 0.0
  for count in parameters.counts {
    total_concentration = total_concentration + 1.0 + count
  }
  let log_weights : Array[Double] = []
  for k in 0..<components {
    let concentration = 1.0 + parameters.counts[k]
    log_weights.push(
      @utils.digamma(concentration) - @utils.digamma(total_concentration),
    )
  }
  // The expectations of the log determinants of the precisions and the
  // inverses of the scatters.
  let log_determinants : Array[Double] = []
  let inverse_scatters : Array[@utils.Matrix] = []
  for k in 0..<components {
    let degrees = parameters.degrees[k]
    let mut expectation = 0.0
    for i in 1..<=features {
      expectation = expectation +
        @utils.digamma((degrees + 1.0 - i.to_double()) / 2.0)
    }
    expectation = expectation +
      features.to_double() * @math.ln(2.0) +
      log_determinant(parameters.scatters[k])
    log_determinants.push(expectation)
    inverse_scatters.push(inverse_scatter(parameters, k))
  }
  let responsibilities : Array[Array[Double]] = []
  for i in 0..<samples {
    let values : Array[Double] = []
    let mut largest = 0.0
    for k in 0..<components {
      let mean = parameters.means[k]
      let difference : Array[Double] = []
      for j in 0..<features {
        difference.push(x.get(i, j) - mean[j])
      }
      // The quadratic form of the inverse of the scatter.
      let product = inverse_scatters[k].matvec(difference)
      let first = dot(difference, product)
      // The quadratic form of the scatter.
      let product2 = parameters.scatters[k].matvec(mean)
      let second = dot(mean, product2)
      let degrees = parameters.degrees[k]
      let factor = (degrees + features.to_double()) / degrees
      let scale = (degrees + 1.0 - features.to_double()) / degrees
      // The expectation of the quadratic form of the precision.
      let expected = factor * first + second / (scale * degrees)
      let value = log_weights[k] +
        0.5 * log_determinants[k] -
        0.5 * features.to_double() * @math.ln(2.0 * @math.PI) -
        0.5 * expected
      values.push(value)
      if k == 0 || value > largest {
        largest = value
      }
    }
    // The normalisation of the responsibilities.
    let mut sum = 0.0
    for value in values {
      sum = sum + @math.exp(value - largest)
    }
    let row : Array[Double] = []
    for value in values {
      row.push(@math.exp(value - largest) / sum)
    }
    responsibilities.push(row)
  }
  responsibilities
}

///|
/// The expected precision of a component of the mixture.
///
/// The precision is the inverse of the scatter, scaled by the factor of the
/// degrees of freedom of the component.
fn expected_precision(
  parameters : MixtureParameters,
  k : Int32,
) -> @utils.Matrix {
  let inverse = inverse_scatter(parameters, k)
  let degrees = parameters.degrees[k]
  let features = inverse.ncols()
  let scale = (degrees + 1.0 - features.to_double()) / degrees
  for a in 0..<features {
    for b in 0..<features {
      inverse.set(a, b, inverse.get(a, b) * scale)
    }
  }
  inverse
}

///|
/// The inverse of the scatter of a component of the mixture.
///
/// The inverse of a singular scatter does not exist; the identity is the
/// inverse of the scatter of a component that holds a single sample.
fn inverse_scatter(parameters : MixtureParameters, k : Int32) -> @utils.Matrix {
  let features = parameters.scatters[k].ncols()
  match @utils.mat_inverse(parameters.scatters[k]) {
    Some(inverse) => inverse
    None => @utils.Matrix::identity(features)
  }
}

///|
/// The responsibilities of the components before the first step of the update:
/// every sample belongs to the component whose centre is the nearest.
fn initial_responsibilities(
  x : @utils.Matrix,
  components : Int32,
) -> Array[Array[Double]] {
  let samples = x.nrows()
  let features = x.ncols()
  let centres = initial_means(x, components)
  // The scale of the assignment is the standard deviation of the data.
  let mut variance = 0.0
  for j in 0..<features {
    variance = variance + @utils.variance(x.col(j), 0)
  }
  let mut scale = (variance / features.to_double()).sqrt()
  if scale <= 0.0 {
    scale = 1.0
  }
  let responsibilities : Array[Array[Double]] = []
  for i in 0..<samples {
    let values : Array[Double] = []
    let mut largest = 0.0
    for k in 0..<components {
      let mut distance = 0.0
      for j in 0..<features {
        let difference = x.get(i, j) - centres[k][j]
        distance = distance + difference * difference
      }
      let value = -0.5 * distance / (scale * scale)
      values.push(value)
      if k == 0 || value > largest {
        largest = value
      }
    }
    let mut sum = 0.0
    for value in values {
      sum = sum + @math.exp(value - largest)
    }
    let row : Array[Double] = []
    for value in values {
      row.push(@math.exp(value - largest) / sum)
    }
    responsibilities.push(row)
  }
  responsibilities
}

///|
/// The centres of the components of the mixture: the samples of the data that
/// are the farthest apart.
///
/// The upstream draws the centres of its components at random; the port draws
/// them from the data, so that the fit of the port is reproducible.
fn initial_means(x : @utils.Matrix, components : Int32) -> Array[Array[Double]] {
  let samples = x.nrows()
  let features = x.ncols()
  let centres : Array[Array[Double]] = []
  centres.push(x.row(0))
  while centres.length() < components {
    let mut best = 0
    let mut best_distance = -1.0
    for i in 0..<samples {
      let mut distance = -1.0
      for centre in centres {
        let mut sum = 0.0
        for j in 0..<features {
          let difference = x.get(i, j) - centre[j]
          sum = sum + difference * difference
        }
        if distance < 0.0 || sum < distance {
          distance = sum
        }
      }
      if distance > best_distance {
        best_distance = distance
        best = i
      }
    }
    centres.push(x.row(best))
  }
  centres
}

///|
/// The largest change of the responsibilities of two steps of the update.
fn change_of_responsibilities(
  before : Array[Array[Double]],
  after : Array[Array[Double]],
) -> Double {
  let mut change = 0.0
  for i in 0..<before.length() {
    for k in 0..<before[i].length() {
      let difference = (after[i][k] - before[i][k]).abs()
      if difference > change {
        change = difference
      }
    }
  }
  change
}

///|
/// The dot product of two vectors.
fn dot(a : Array[Double], b : Array[Double]) -> Double {
  let mut sum = 0.0
  for i in 0..<a.length() {
    sum = sum + a[i] * b[i]
  }
  sum
}

///|
/// The logarithm of the determinant of a matrix.
///
/// The determinant of a singular matrix is zero, so the logarithm of it does
/// not exist; the logarithm of the determinant of a singular matrix is zero
/// here.
fn log_determinant(m : @utils.Matrix) -> Double {
  let determinant = @utils.mat_determinant(m)
  if determinant > 0.0 {
    @math.ln(determinant)
  } else {
    0.0
  }
}
