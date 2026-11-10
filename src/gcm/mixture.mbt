///|
/// The Bayesian Gaussian mixture distribution of the `gcm` package.
///
/// This is the port of
/// `dowhy.gcm.stochastic_models.BayesianGaussianMixtureDistribution`. The
/// distribution is a mixture of gaussians, and the number of its components is
/// chosen before the fit.
///
/// The upstream fits the mixture with the variational inference of
/// `sklearn.mixture.BayesianGaussianMixture`, which draws the centres of the
/// components at random and does not seed its generator, so the fit of the
/// upstream is not reproducible. The port fits the same model with the mean
/// field variational update of the density estimator of the package, whose
/// centres are the samples of the data that are the farthest apart, so the fit
/// of the port is reproducible. The case of the upstream asserts the shape of
/// the samples and not their values.

///|
/// The number of the rows the silhouette score of the search of the number of
/// the components is computed on.
///
/// The upstream draws a random subsample of five thousand rows when there are
/// more rows than that. The port draws a random subsample of a thousand rows,
/// because the score costs a quadratic number of distance computations and the
/// search over the number of the components is a long one.
const MIXTURE_SILHOUETTE_ROWS : Int32 = 1000

///|
/// The number of the iterations of the k-means of the search of the number of
/// the components.
const MIXTURE_KMEANS_ITERATIONS : Int32 = 100

///|
/// A distribution that is a mixture of gaussians.
///
/// This is the port of
/// `dowhy.gcm.stochastic_models.BayesianGaussianMixtureDistribution`.
pub struct BayesianGaussianMixtureDistribution {
  /// The weight of every component.
  mut weights : Array[Double]
  /// The mean of every component.
  mut means : Array[Array[Double]]
  /// The expected precision of every component.
  mut precisions : Array[@utils.Matrix]
  /// Whether the distribution has been fitted.
  mut fitted : Bool
}

///|
/// A distribution that has not been fitted yet.
pub fn BayesianGaussianMixtureDistribution::new() -> BayesianGaussianMixtureDistribution {
  { weights: [], means: [], precisions: [], fitted: false, }
}

///|
/// Whether the distribution has been fitted.
///
/// The upstream raises a `RuntimeError` when the samples of an unfitted
/// distribution are drawn. MoonBit cannot catch the abort of a method, so the
/// check is public.
pub fn BayesianGaussianMixtureDistribution::is_fitted(
  self : BayesianGaussianMixtureDistribution,
) -> Bool {
  self.fitted
}

///|
/// The number of the components of the mixture.
pub fn BayesianGaussianMixtureDistribution::num_components(
  self : BayesianGaussianMixtureDistribution,
) -> Int32 {
  self.weights.length()
}

///|
/// The weights of the components of the mixture.
pub fn BayesianGaussianMixtureDistribution::component_weights(
  self : BayesianGaussianMixtureDistribution,
) -> Array[Double] {
  self.weights.copy()
}

///|
/// The means of the components of the mixture.
pub fn BayesianGaussianMixtureDistribution::component_means(
  self : BayesianGaussianMixtureDistribution,
) -> Array[Array[Double]] {
  self.means.copy()
}

///|
/// A copy of the distribution that has not been fitted.
///
/// This is the port of the `clone` of the upstream, whose copy of a fitted
/// distribution is not fitted either.
pub fn BayesianGaussianMixtureDistribution::clone(
  self : BayesianGaussianMixtureDistribution,
) -> BayesianGaussianMixtureDistribution {
  let _ = self
  BayesianGaussianMixtureDistribution::new()
}

///|
/// Fit the distribution on the given samples.
///
/// The number of the components of the mixture is the one of the upstream: it
/// is the number of the clusters of the k-means of the samples whose
/// silhouette score is the best one.
pub fn BayesianGaussianMixtureDistribution::fit(
  self : BayesianGaussianMixtureDistribution,
  x : @utils.Matrix,
  rng : @utils.Random,
) -> Unit {
  let samples = x.nrows()
  let features = x.ncols()
  if samples == 0 || features == 0 {
    abort("a Gaussian mixture cannot be fitted on an empty sample")
  }
  let components = optimal_number_of_components(x, rng)
  let fitted = fit_mixture(x, components)
  self.weights = fitted.weights
  self.means = fitted.means
  self.precisions = fitted.precisions
  self.fitted = true
}

///|
/// Draw samples from the distribution.
///
/// The upstream draws them from the global generator of numpy; the port draws
/// them from the given generator, so that the same generator always gives the
/// same samples.
///
/// The result holds one row per sample, like the two dimensional array the
/// upstream returns.
pub fn BayesianGaussianMixtureDistribution::draw_samples(
  self : BayesianGaussianMixtureDistribution,
  num_samples : Int32,
  rng : @utils.Random,
) -> @utils.Matrix {
  if !self.fitted {
    abort("BayesianGaussianMixtureDistribution has not been fitted")
  }
  let components = self.weights.length()
  let features = self.means[0].length()
  // The factor of every component, which turns a standard normal vector into
  // a sample of the component. The covariance of a component is the inverse of
  // its precision, and the inverse of a symmetric positive definite matrix is
  // the product of its eigenvectors with the inverse of the square roots of
  // its eigenvalues.
  let factors : Array[@utils.Matrix] = []
  for k in 0..<components {
    let (eigenvalues, eigenvectors) = @utils.jacobi_eigen(self.precisions[k])
    let factor = @utils.Matrix::zeros(features, features)
    for j in 0..<features {
      let value = if eigenvalues[j] > 0.0 {
        1.0 / eigenvalues[j].sqrt()
      } else {
        0.0
      }
      for i in 0..<features {
        factor.set(i, j, eigenvectors.get(i, j) * value)
      }
    }
    factors.push(factor)
  }
  let rows : Array[Array[Double]] = []
  for _ in 0..<num_samples {
    // The component of the sample, which is drawn with the weights of the
    // components.
    let mut chosen = 0
    let mut threshold = rng.next_double()
    for k in 0..<components {
      threshold = threshold - self.weights[k]
      if threshold <= 0.0 {
        chosen = k
        break
      }
    }
    // The standard normal vector of the sample.
    let noise : Array[Double] = []
    for _ in 0..<features {
      noise.push(rng.next_normal())
    }
    let mean = self.means[chosen]
    let row : Array[Double] = []
    for j in 0..<features {
      let mut value = mean[j]
      for i in 0..<features {
        value = value + factors[chosen].get(i, j) * noise[i]
      }
      row.push(value)
    }
    rows.push(row)
  }
  @utils.Matrix::from_rows(rows)
}

///|
/// The number of the components of the mixture of the given samples.
///
/// This is the port of
/// `dowhy.gcm.stochastic_models.BayesianGaussianMixtureDistribution._get_optimal_number_of_components`.
/// The candidates are the numbers of the clusters of a k-means of the samples,
/// the score of a candidate is the silhouette score of its clustering, and the
/// search keeps the candidate with the best score and stops after three
/// candidates in a row that do not improve it.
///
/// The upstream draws the centres of its k-means at random and does not seed
/// its generator, so the number of the components of the upstream is not
/// reproducible. The port draws the centres of its k-means from the samples
/// that are the farthest apart, so the number of the components of the port
/// is.
fn optimal_number_of_components(
  x : @utils.Matrix,
  rng : @utils.Random,
) -> Int32 {
  let samples = x.nrows()
  // The candidates run from two up to the square root of half of the number of
  // the samples, the way the loop of the upstream does.
  let limit = (samples.to_double() / 2.0).sqrt().floor().to_int()
  let mut best = 0.0
  let mut best_components = 1
  let mut without_improvement = 0
  let mut components = 2
  while components < limit {
    let labels = kmeans_labels(x, components)
    let score = silhouette_score(x, labels, rng)
    if score > best {
      best = score
      best_components = components
      without_improvement = 0
    } else {
      without_improvement = without_improvement + 1
    }
    if without_improvement >= 3 {
      break
    }
    components = components + 1
  }
  best_components
}

///|
/// The cluster of every sample of a k-means with the given number of clusters.
///
/// The port draws the centres of the clusters from the samples that are the
/// farthest apart and keeps them with the update of Lloyd.
fn kmeans_labels(x : @utils.Matrix, clusters : Int32) -> Array[Int32] {
  let samples = x.nrows()
  let features = x.ncols()
  let centres = initial_means(x, clusters)
  let labels : Array[Int32] = []
  for _ in 0..<samples {
    labels.push(0)
  }
  for _ in 0..<MIXTURE_KMEANS_ITERATIONS {
    // The cluster of every sample.
    let mut changed = false
    for i in 0..<samples {
      let mut nearest = 0
      let mut nearest_distance = -1.0
      for k in 0..<clusters {
        let distance = mixture_squared_distance(x, i, centres[k])
        if nearest_distance < 0.0 || distance < nearest_distance {
          nearest_distance = distance
          nearest = k
        }
      }
      if labels[i] != nearest {
        labels[i] = nearest
        changed = true
      }
    }
    if !changed {
      break
    }
    // The new centres of the clusters, which are the means of their samples.
    let sums : Array[Array[Double]] = []
    let counts : Array[Int32] = []
    for _ in 0..<clusters {
      let zero : Array[Double] = []
      for _ in 0..<features {
        zero.push(0.0)
      }
      sums.push(zero)
      counts.push(0)
    }
    for i in 0..<samples {
      let cluster = labels[i]
      counts[cluster] = counts[cluster] + 1
      for j in 0..<features {
        sums[cluster][j] = sums[cluster][j] + x.get(i, j)
      }
    }
    for k in 0..<clusters {
      if counts[k] == 0 {
        continue
      }
      for j in 0..<features {
        centres[k][j] = sums[k][j] / counts[k].to_double()
      }
    }
  }
  labels
}

///|
/// The silhouette score of a clustering of the given samples.
///
/// This is the port of the `silhouette_score` of scikit-learn. The score of a
/// sample is the difference between the mean distance to the samples of the
/// other clusters and the mean distance to the samples of its own cluster,
/// divided by the largest of the two, and the score of the clustering is the
/// mean of the scores of the samples.
///
/// The upstream draws a random subsample of the samples when there are more of
/// them than the size of the subsample; the port does the same.
fn silhouette_score(
  x : @utils.Matrix,
  labels : Array[Int32],
  rng : @utils.Random,
) -> Double {
  let clusters = number_of_clusters(labels)
  if clusters < 2 || x.nrows() < 2 {
    return 0.0
  }
  let rows = sampled_rows(x.nrows(), rng)
  let mut total = 0.0
  let mut counted = 0
  for index in rows {
    let cluster = labels[index]
    // The sum of the distances to the samples of its own cluster.
    let mut within = 0.0
    let mut within_count = 0
    // The sum of the distances to the samples of every other cluster.
    let between : Array[Double] = []
    let between_counts : Array[Int32] = []
    for _ in 0..<clusters {
      between.push(0.0)
      between_counts.push(0)
    }
    for other in rows {
      if other == index {
        continue
      }
      let distance = mixture_distance(x, index, other)
      if labels[other] == cluster {
        within = within + distance
        within_count = within_count + 1
      } else {
        let other_cluster = labels[other]
        between[other_cluster] = between[other_cluster] + distance
        between_counts[other_cluster] = between_counts[other_cluster] + 1
      }
    }
    if within_count == 0 {
      continue
    }
    let a = within / within_count.to_double()
    let mut b = -1.0
    for k in 0..<clusters {
      if k == cluster || between_counts[k] == 0 {
        continue
      }
      let mean = between[k] / between_counts[k].to_double()
      if b < 0.0 || mean < b {
        b = mean
      }
    }
    if b < 0.0 {
      continue
    }
    let largest = if a > b { a } else { b }
    let score = if largest == 0.0 { 0.0 } else { (b - a) / largest }
    total = total + score
    counted = counted + 1
  }
  if counted == 0 {
    return 0.0
  }
  total / counted.to_double()
}

///|
/// The rows of a sample of the given number of rows.
///
/// The rows are drawn without replacement from the given generator. Every row
/// is drawn, when there are fewer rows than the size of the sample.
fn sampled_rows(samples : Int32, rng : @utils.Random) -> Array[Int32] {
  if samples <= MIXTURE_SILHOUETTE_ROWS {
    let all : Array[Int32] = []
    for i in 0..<samples {
      all.push(i)
    }
    return all
  }
  let chosen : Array[Int32] = []
  let taken : Array[Bool] = []
  for _ in 0..<samples {
    taken.push(false)
  }
  while chosen.length() < MIXTURE_SILHOUETTE_ROWS {
    let index = rng.next_int(samples)
    if !taken[index] {
      taken[index] = true
      chosen.push(index)
    }
  }
  chosen
}

///|
/// The number of the clusters of a labelling.
fn number_of_clusters(labels : Array[Int32]) -> Int32 {
  let mut largest = -1
  for label in labels {
    if label > largest {
      largest = label
    }
  }
  largest + 1
}

///|
/// The euclidean distance of two rows of a matrix.
fn mixture_distance(x : @utils.Matrix, left : Int32, right : Int32) -> Double {
  let features = x.ncols()
  let mut sum = 0.0
  for j in 0..<features {
    let difference = x.get(left, j) - x.get(right, j)
    sum = sum + difference * difference
  }
  sum.sqrt()
}

///|
/// The squared euclidean distance of a row of a matrix and a point.
fn mixture_squared_distance(
  x : @utils.Matrix,
  index : Int32,
  point : Array[Double],
) -> Double {
  let features = x.ncols()
  let mut sum = 0.0
  for j in 0..<features {
    let difference = x.get(index, j) - point[j]
    sum = sum + difference * difference
  }
  sum
}
