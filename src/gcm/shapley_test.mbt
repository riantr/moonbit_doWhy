///|
/// The tests of the Shapley values.
///
/// The fixture is generated with the deterministic generator of the `utils`
/// package, and the expected numbers are the ones the upstream
/// `dowhy.gcm.shapley` produces on the very same rows, which
/// `_verify/gcm_shapley_reference.py` prints.

///|
/// The seed of the fixture.
const SHAPLEY_SEED : UInt64 = 2024UL

///|
/// The number of samples of the linear model.
const SHAPLEY_NUM_SAMPLES : Int32 = 100

///|
/// The number of features of the linear model.
const SHAPLEY_NUM_FEATURES : Int32 = 8

///|
/// The number of features of the model with few players.
const SHAPLEY_NUM_FEATURES_FEW : Int32 = 4

///|
/// The samples and the coefficients of the linear model.
///
/// The draws happen in the order of the reference script: the whole matrix
/// row by row, and then the coefficients.
fn shapley_fixture() -> (@utils.Matrix, Array[Double]) {
  let rng = @utils.Random::new(SHAPLEY_SEED)
  let rows : Array[Array[Double]] = []
  for _ in 0..<SHAPLEY_NUM_SAMPLES {
    let row : Array[Double] = []
    for _ in 0..<SHAPLEY_NUM_FEATURES {
      row.push(rng.next_normal())
    }
    rows.push(row)
  }
  let coefficients : Array[Double] = []
  for _ in 0..<SHAPLEY_NUM_FEATURES {
    coefficients.push(rng.next_int(20).to_double() - 10.0)
  }
  (@utils.Matrix::from_rows(rows), coefficients)
}

///|
/// The samples and the coefficients of the model with the first features only.
///
/// This is the model of the automatic method with few players, which the
/// upstream code estimates with the exact method.
fn shapley_fixture_few() -> (@utils.Matrix, Array[Double]) {
  let (samples, coefficients) = shapley_fixture()
  let rows : Array[Array[Double]] = []
  for i = 0; i < samples.nrows(); i = i + 1 {
    let row : Array[Double] = []
    for j = 0; j < SHAPLEY_NUM_FEATURES_FEW; j = j + 1 {
      row.push(samples.get(i, j))
    }
    rows.push(row)
  }
  let few_coefficients : Array[Double] = []
  for j = 0; j < SHAPLEY_NUM_FEATURES_FEW; j = j + 1 {
    few_coefficients.push(coefficients[j])
  }
  (@utils.Matrix::from_rows(rows), few_coefficients)
}

///|
/// The set function of the tests.
///
/// This is the upstream `_set_function_for_aggregated_feature_attribution`:
/// the features of the subset keep the values of the first sample, the other
/// ones are permuted, and the difference of the means of the model is
/// returned.
fn shapley_set_function(
  samples : @utils.Matrix,
  coefficients : Array[Double],
  subset : Array[Bool],
  rng : @utils.Random,
) -> Double {
  let to_permute : Array[Int32] = []
  for j = 0; j < subset.length(); j = j + 1 {
    if !subset[j] {
      to_permute.push(j)
    }
  }
  let values = @gcm.permute_features(samples, to_permute, false, rng)
  for j = 0; j < subset.length(); j = j + 1 {
    if subset[j] {
      for i = 0; i < values.nrows(); i = i + 1 {
        values.set(i, j, samples.get(0, j))
      }
    }
  }
  let mut sum = 0.0
  for i = 0; i < values.nrows(); i = i + 1 {
    let mut model = 0.0
    for j = 0; j < values.ncols(); j = j + 1 {
      model = model + coefficients[j] * values.get(i, j)
    }
    sum = sum + model
  }
  sum / values.nrows().to_double() - @utils.mean(samples.row(0))
}

///|
/// The Shapley values of the linear model with the given method.
fn shapley_values_of_model(
  samples : @utils.Matrix,
  coefficients : Array[Double],
  approximation : @gcm.ShapleyApproximationMethod,
  seed : UInt64,
) -> Array[Double] {
  let rng = @utils.Random::new(seed)
  let set_func = fn(subset : Array[Bool]) -> Double {
    shapley_set_function(samples, coefficients, subset, rng)
  }
  let config = @gcm.ShapleyConfig::new(approximation).with_seed(seed)
  @gcm.estimate_shapley_values(set_func, samples.ncols(), config)
}

///|
/// A set function that is not additive, so that the estimation depends on the
/// random permutations.
fn nonlinear_set_function(subset : Array[Bool]) -> Double {
  let mut value = 0.0
  let mut size = 0
  for j = 0; j < subset.length(); j = j + 1 {
    if subset[j] {
      value = value + (j + 1).to_double()
      size = size + 1
    }
  }
  value + 0.5 * size.to_double() * (size.to_double() - 1.0)
}

///|
/// Whether the two sets of values agree to the given tolerance.
fn shapley_values_agree(
  values : Array[Double],
  expected : Array[Double],
  tolerance : Double,
) -> Bool {
  if values.length() != expected.length() {
    return false
  }
  for i = 0; i < values.length(); i = i + 1 {
    if (values[i] - expected[i]).abs() > tolerance {
      return false
    }
  }
  true
}

///|
/// test "the exact method gives the Shapley values of a linear model"
///
/// The values of a linear model are the coefficients times the deviations of
/// the first sample from the means of the features, which is what the
/// upstream code produces.
test "the exact method gives the Shapley values of a linear model" {
  let (samples, coefficients) = shapley_fixture()
  let values = shapley_values_of_model(
    samples,
    coefficients,
    @gcm.ShapleyApproximationMethod::exact(),
    SHAPLEY_SEED,
  )
  let expected = [
    11.205400559278, 2.532688795848, -6.658211192429, -2.482960043934, -3.152118362756,
    -3.054040774290, 23.660966366142, -0.679488248937,
  ]
  assert_true(shapley_values_agree(values, expected, 1.0e-3))
}

///|
/// test "the automatic method is the exact method for few players"
test "the automatic method is the exact method for few players" {
  let (samples, coefficients) = shapley_fixture_few()
  let values = shapley_values_of_model(
    samples,
    coefficients,
    @gcm.ShapleyApproximationMethod::auto(),
    SHAPLEY_SEED,
  )
  let expected = [
    11.205400559278, 2.532688795848, -6.658211192429, -2.482960043934,
  ]
  assert_true(shapley_values_agree(values, expected, 1.0e-3))
}

///|
/// test "the automatic method is the permutation method for many players"
test "the automatic method is the permutation method for many players" {
  let (samples, coefficients) = shapley_fixture()
  let values = shapley_values_of_model(
    samples,
    coefficients,
    @gcm.ShapleyApproximationMethod::auto(),
    SHAPLEY_SEED,
  )
  let expected = [
    11.205400559278, 2.532688795848, -6.658211192429, -2.482960043934, -3.152118362756,
    -3.054040774290, 23.660966366142, -0.679488248937,
  ]
  assert_true(shapley_values_agree(values, expected, 1.0e-3))
}

///|
/// test "the permutation method gives the Shapley values of a linear model"
test "the permutation method gives the Shapley values of a linear model" {
  let (samples, coefficients) = shapley_fixture()
  let values = shapley_values_of_model(
    samples,
    coefficients,
    @gcm.ShapleyApproximationMethod::permutation(),
    SHAPLEY_SEED,
  )
  let expected = [
    11.205400559278, 2.532688795848, -6.658211192429, -2.482960043934, -3.152118362756,
    -3.054040774290, 23.660966366142, -0.679488248937,
  ]
  assert_true(shapley_values_agree(values, expected, 1.0e-3))
}

///|
/// test "the early stopping method gives the Shapley values of a linear model"
test "the early stopping method gives the Shapley values of a linear model" {
  let (samples, coefficients) = shapley_fixture()
  let values = shapley_values_of_model(
    samples,
    coefficients,
    @gcm.ShapleyApproximationMethod::early_stopping(),
    SHAPLEY_SEED,
  )
  let expected = [
    11.205400559278, 2.532688795848, -6.658211192429, -2.482960043934, -3.152118362756,
    -3.054040774290, 23.660966366142, -0.679488248937,
  ]
  assert_true(shapley_values_agree(values, expected, 1.0e-3))
}

///|
/// test "the exact fast method is the least squares solution of the upstream"
///
/// The upstream fits the least squares regression with the sample weights,
/// whose two extreme weights are so large that the solution of the
/// regression is the same for every player. The port reproduces it.
test "the exact fast method is the least squares solution of the upstream" {
  let (samples, coefficients) = shapley_fixture()
  let values = shapley_values_of_model(
    samples,
    coefficients,
    @gcm.ShapleyApproximationMethod::exact_fast(),
    SHAPLEY_SEED,
  )
  let expected = [
    2.671529637365, 2.671529637365, 2.671529637365, 2.671529637365, 2.671529637365,
    2.671529637365, 2.671529637365, 2.671529637365,
  ]
  assert_true(shapley_values_agree(values, expected, 1.0e-3))
}

///|
/// test "the subset sampling method is the least squares solution of the upstream"
test "the subset sampling method is the least squares solution of the upstream" {
  let (samples, coefficients) = shapley_fixture()
  let values = shapley_values_of_model(
    samples,
    coefficients,
    @gcm.ShapleyApproximationMethod::subset_sampling(),
    SHAPLEY_SEED,
  )
  let expected = [
    2.671529637365, 2.671529637365, 2.671529637365, 2.671529637365, 2.671529637365,
    2.671529637365, 2.671529637365, 2.671529637365,
  ]
  assert_true(shapley_values_agree(values, expected, 1.0e-3))
}

///|
/// test "the random methods give the same result for the same seed"
///
/// The set function of this test is not additive, so the estimation depends on
/// the permutations that are drawn.
test "the random methods give the same result for the same seed" {
  let config = @gcm.ShapleyConfig::new(
    @gcm.ShapleyApproximationMethod::permutation(),
  ).with_seed(SHAPLEY_SEED)
  let first = @gcm.estimate_shapley_values(nonlinear_set_function, 5, config)
  let second = @gcm.estimate_shapley_values(nonlinear_set_function, 5, config)
  assert_true(shapley_values_agree(first, second, 0.0))
}

///|
/// test "the random methods depend on the seed"
test "the random methods depend on the seed" {
  let first_config = @gcm.ShapleyConfig::new(
    @gcm.ShapleyApproximationMethod::permutation(),
  ).with_seed(SHAPLEY_SEED)
  let second_config = @gcm.ShapleyConfig::new(
    @gcm.ShapleyApproximationMethod::permutation(),
  ).with_seed(SHAPLEY_SEED + 1UL)
  let first = @gcm.estimate_shapley_values(
    nonlinear_set_function, 5, first_config,
  )
  let second = @gcm.estimate_shapley_values(
    nonlinear_set_function, 5, second_config,
  )
  assert_false(shapley_values_agree(first, second, 0.0))
}

///|
/// test "the name of the methods is the name of the upstream enumeration"
test "the name of the methods is the name of the upstream enumeration" {
  assert_eq(@gcm.ShapleyApproximationMethod::auto().name(), "AUTO")
  assert_eq(@gcm.ShapleyApproximationMethod::exact().name(), "EXACT")
  assert_eq(@gcm.ShapleyApproximationMethod::exact_fast().name(), "EXACT_FAST")
  assert_eq(
    @gcm.ShapleyApproximationMethod::subset_sampling().name(),
    "SUBSET_SAMPLING",
  )
  assert_eq(
    @gcm.ShapleyApproximationMethod::permutation().name(),
    "PERMUTATION",
  )
  assert_eq(
    @gcm.ShapleyApproximationMethod::early_stopping().name(),
    "EARLY_STOPPING",
  )
}

///|
/// test "the configuration keeps its values in its copies"
test "the configuration keeps its values in its copies" {
  let config = @gcm.ShapleyConfig::new(
    @gcm.ShapleyApproximationMethod::permutation(),
  ).with_seed(SHAPLEY_SEED)
  let values = @gcm.estimate_shapley_values(nonlinear_set_function, 5, config)
  // The copy with another seed gives other values.
  let other = @gcm.estimate_shapley_values(
    nonlinear_set_function,
    5,
    config.with_seed(SHAPLEY_SEED + 1UL),
  )
  assert_false(shapley_values_agree(values, other, 0.0))
  // The configuration itself is not changed by the copy.
  let again = @gcm.estimate_shapley_values(nonlinear_set_function, 5, config)
  assert_true(shapley_values_agree(values, again, 0.0))
}
