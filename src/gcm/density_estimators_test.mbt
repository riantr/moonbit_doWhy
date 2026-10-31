///|
/// The tests of the density estimators of the `gcm` package.
///
/// The fixture is the one of the upstream test, and the expected numbers are
/// the ones the upstream `dowhy.gcm.density_estimators` produces on the very
/// same rows, which `_verify/gcm_divergence_reference.py` prints.

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
