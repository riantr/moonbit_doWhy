///|
/// The tests of the Bayesian Gaussian mixture distribution of the `gcm`
/// package.
///
/// The expectations are the ones of the upstream test file
/// `tests/gcm/test_stochastic_models.py`, in the two cases
/// `test_when_fitting_bayesian_gaussian_mixture_distribution_then_samples_should_be_drawn_correctly`
/// and
/// `test_when_drawing_samples_from_unfitted_bayesian_gaussian_mixture_distribution_then_runtime_error_should_occur`.
///
/// The upstream draws the samples from the global generator of numpy and does
/// not seed it, and it draws the centres of the components of its mixture at
/// random as well, so the numbers of the upstream are not reproducible. The
/// case of the upstream therefore asserts the shape of the samples and not
/// their values, and the port asserts the same shape.

///|
/// The seed of the fixture.
const MIXTURE_SEED : UInt64 = 2080UL

///|
/// The samples of the fixture of the upstream test.
///
/// The fixture is the one of the upstream test file
/// `tests/gcm/test_stochastic_models.py` in the case
/// `test_when_fitting_bayesian_gaussian_mixture_distribution_then_samples_should_be_drawn_correctly`.
fn bayesian_mixture_fixture() -> @utils.Matrix {
  @utils.Matrix::from_rows([[0.0, 0.0], [0.0, 0.0], [1.0, 2.0], [1.0, 2.0]])
}

///|
/// test "when fitting bayesian gaussian mixture distribution then samples should be drawn correctly"
///
/// This is the port of the upstream test
/// `test_when_fitting_bayesian_gaussian_mixture_distribution_then_samples_should_be_drawn_correctly`.
/// The upstream asserts the shape of the samples and not their values.
test "when fitting bayesian gaussian mixture distribution then samples should be drawn correctly" {
  let distribution = @gcm.BayesianGaussianMixtureDistribution::new()
  distribution.fit(bayesian_mixture_fixture(), @utils.Random::new(MIXTURE_SEED))
  assert_true(distribution.is_fitted())
  // The number of the components is the one of the upstream: the loop over the
  // candidates of the upstream is empty for four samples, so the mixture has
  // one component.
  assert_eq(distribution.num_components(), 1)
  let samples = distribution.draw_samples(5, @utils.Random::new(MIXTURE_SEED))
  assert_eq(samples.nrows(), 5)
  assert_eq(samples.ncols(), 2)
}

///|
/// test "when drawing samples from unfitted bayesian gaussian mixture distribution then runtime error should occur"
///
/// This is the port of the upstream test
/// `test_when_drawing_samples_from_unfitted_bayesian_gaussian_mixture_distribution_then_runtime_error_should_occur`.
/// The upstream raises a `RuntimeError`; MoonBit cannot catch the abort of a
/// method, so the check that tells whether the distribution is fitted is
/// public.
test "when drawing samples from unfitted bayesian gaussian mixture distribution then runtime error should occur" {
  let distribution = @gcm.BayesianGaussianMixtureDistribution::new()
  assert_false(distribution.is_fitted())
  assert_eq(distribution.num_components(), 0)
  // The copy of a fitted distribution of the upstream is not fitted either.
  let fitted = @gcm.BayesianGaussianMixtureDistribution::new()
  fitted.fit(bayesian_mixture_fixture(), @utils.Random::new(MIXTURE_SEED))
  assert_false(fitted.clone().is_fitted())
}

///|
/// The number of the components of a mixture of two clusters.
///
/// The search over the number of the components of the upstream runs the
/// silhouette score of a k-means of the samples for every candidate, and the
/// port does the same. The candidates of a sample of two hundred rows run up
/// to the square root of half of the number of the rows.
test "the number of the components of a mixture of two clusters is two" {
  let rng = @utils.Random::new(MIXTURE_SEED)
  let rows : Array[Array[Double]] = []
  for i in 0..<200 {
    if i < 100 {
      rows.push([0.0, 0.0])
    } else {
      rows.push([10.0, 10.0])
    }
  }
  let data = @utils.Matrix::from_rows(rows)
  let distribution = @gcm.BayesianGaussianMixtureDistribution::new()
  distribution.fit(data, rng)
  assert_eq(distribution.num_components(), 2)
  let weights = distribution.component_weights()
  assert_eq(weights.length(), 2)
  let means = distribution.component_means()
  assert_eq(means.length(), 2)
}
