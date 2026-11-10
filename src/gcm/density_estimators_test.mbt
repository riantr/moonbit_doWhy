///|
/// The tests of the density estimators of the `gcm` package.
///
/// The cases mirror the upstream test file `tests/gcm/test_density_estimators.py`:
/// the kernel based estimator of one dimension and the Gaussian mixture.  The
/// fixture is the one of the upstream test, and the expected numbers are the
/// ones the upstream `dowhy.gcm.density_estimators` produces on the very same
/// rows, which `_verify/gcm_divergence_reference.py` and
/// `_verify/gcm_density_estimators_reference.py` print.

///|
/// Whether two numbers agree to the tolerance of the comparison.
fn same_density(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-9
}

///|
/// The data of the density estimator: four samples of one column.
fn density_fixture() -> @utils.Matrix {
  @utils.Matrix::from_rows([[0.0], [2.0], [1.0], [3.0]])
}

///|
/// test "the kernel density estimator gives one density per row"
///
/// The expected numbers are the ones the upstream estimator produces on the very
/// same rows, which the reference script prints under `KERNEL_DENSITY`.
test "the kernel density estimator gives one density per row" {
  let data = density_fixture()
  let estimator = @gcm.KernelDensityEstimator1D::new()
  estimator.fit(data)
  let densities = estimator.density(data)
  assert_eq(densities.length(), 4)
  assert_true(same_density(densities[0], 0.180558074950))
  assert_true(same_density(densities[1], 0.239877616517))
  assert_true(same_density(densities[2], 0.239877616517))
  assert_true(same_density(densities[3], 0.180558074950))
}

///|
/// test "the kernel density estimator refuses data with more than one column"
///
/// The upstream estimator raises an error when the data has more than one
/// column. MoonBit has no exceptions, so the estimator aborts and the check
/// that tells whether the data is supported is public.
test "the kernel density estimator refuses data with more than one column" {
  let wide = @utils.Matrix::from_rows([[0.0, 1.0], [0.0, 2.0], [1.0, 0.0]])
  assert_false(@gcm.KernelDensityEstimator1D::supports(wide))
  assert_true(@gcm.KernelDensityEstimator1D::supports(density_fixture()))
}

///|
/// The data of the Gaussian mixture: the four rows of the fixture of the
/// upstream test.
fn mixture_fixture() -> @utils.Matrix {
  @utils.Matrix::from_rows([[0.0, 1.0], [0.0, 2.0], [1.0, 0.0], [2.0, 3.0]])
}

///|
/// test "the gaussian mixture gives one density per row"
///
/// The upstream draws the centres of the components of its mixture at random
/// and does not seed its generator, so its own fit is not reproducible and its
/// case asserts the length of the result and not its values.  The port draws
/// the centres from the data, so its fit is reproducible; the numbers of the
/// port are the ones the reference script prints.
test "the gaussian mixture gives one density per row" {
  let data = mixture_fixture()
  let estimator = @gcm.GaussianMixtureDensityEstimator::new()
  estimator.fit(data)
  let densities = estimator.density(data)
  assert_eq(densities.length(), 4)
  // The number of the components is the one of the upstream: the ceiling of
  // the square root of half of the number of the samples.
  assert_eq(estimator.components(), 2)
  // The weights of the components add up to one.
  let weights = estimator.component_weights()
  let mut total = 0.0
  for weight in weights {
    total = total + weight
  }
  assert_true((total - 1.0).abs() < 1.0e-12)
  // The densities of the port, the reference script prints them.
  assert_true((densities[0] - 0.04485297787416676).abs() < 1.0e-9)
  assert_true((densities[1] - 0.04298990580763077).abs() < 1.0e-9)
  assert_true((densities[2] - 0.0281508381960412).abs() < 1.0e-9)
  assert_true((densities[3] - 0.024929383117049755).abs() < 1.0e-9)
}

///|
/// test "the gaussian mixture refuses more components than samples"
///
/// The upstream raises a `ValueError` when the number of the components is
/// larger than the number of the samples. MoonBit has no exceptions, so the
/// estimator aborts.
test "the gaussian mixture refuses more components than samples" {
  let data = mixture_fixture()
  let estimator = @gcm.GaussianMixtureDensityEstimator::new(num_components=5)
  assert_false(@gcm.GaussianMixtureDensityEstimator::supports(estimator, data))
  let fitted = @gcm.GaussianMixtureDensityEstimator::new()
  assert_true(@gcm.GaussianMixtureDensityEstimator::supports(fitted, data))
}

///|
/// test "the gaussian mixture has to be fitted before its density is computed"
///
/// The upstream raises an error when the density of an estimator that was not
/// fitted is computed. MoonBit has no exceptions, so the estimator aborts and
/// the check that tells whether it was fitted is public.
test "the gaussian mixture has to be fitted before its density is computed" {
  let estimator = @gcm.GaussianMixtureDensityEstimator::new()
  assert_false(estimator.is_fitted())
  estimator.fit(mixture_fixture())
  assert_true(estimator.is_fitted())
}
