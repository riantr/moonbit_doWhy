///|
/// The tests of the kernel based independence test of the `gcm` package.
///
/// The cases mirror the upstream test file
/// `tests/gcm/independence_test/test_kernel.py`: the marginal and the
/// conditional test of independent and of dependent data, the tests of the
/// categorical data, the determinism of the test for a given seed, the
/// constant inputs, which the test removes before it runs, and the almost
/// constant ones.
///
/// The cases the port does not mirror are the ones of the approximate test of
/// the upstream, which is the randomised independence test of Strobl et al.
/// and which the port does not have, and the one of the data of a numpy dtype
/// of an object, which the frame of the port does not hold.
///
/// The expectations are the numbers the upstream `dowhy.gcm` computes on the
/// very fixtures of this file, with the kernel conditional independence test
/// of the `causal-learn` package. The reference script
/// `_verify/gcm_validation_reference.py` prints them.
///
/// The upstream draws a random permutation of the rows before it computes the
/// test, and its p-value moves with that permutation in its last digits. The
/// port draws the rows in the order of the data, so its p-values are the ones
/// of the upstream in the canonical order of the rows; the difference between
/// the two is of the order of `1e-11`, which is the noise of the upstream
/// itself.

///|
/// The seed of the generator of the tests.
const KERNEL_SEED : UInt64 = 2024UL

///|
/// The relative tolerance of the assertions.
///
/// The port computes the p-values with the Gauss-Jordan elimination for the
/// inverse of the regressor of the conditional test, where the upstream uses
/// the singular value decomposition, and the two differ by about `8e-12` in
/// their last digits. That is the noise floor of the upstream itself: the
/// p-value the upstream computes moves by about `1e-11` with the permutation
/// of the rows that its kernel test draws.
///
/// The tolerance has to be wider than that and narrower than the difference
/// the port would have if it made a mistake. The tolerance of `1e-09` that
/// the port used before the eigen decomposition was made accurate enough
/// caught a difference of `1.6e-09`, which is the order of magnitude of the
/// mistake it was meant to catch.
const KERNEL_TOLERANCE : Double = 1.0e-10

///|
/// The columns of a fixture as a matrix.
fn kernel_column(frame : @api.DataFrame, name : String) -> @utils.Matrix {
  @utils.Matrix::from_columns([frame.numeric(name)])
}

///|
/// A column of the given length that holds a single value.
fn kernel_constant(length : Int32) -> @utils.Matrix {
  let values : Array[Double] = []
  for _ in 0..<length {
    values.push(1.0)
  }
  @utils.Matrix::from_columns([values])
}

///|
/// The p-value of the test of two columns, without a conditioning variable.
fn kernel_pair(
  frame : @api.DataFrame,
  first : String,
  second : String,
) -> Double {
  @gcm.kernel_based(
    kernel_column(frame, first),
    kernel_column(frame, second),
    None,
    false,
    1,
    2000,
    kernel_first_p_value,
    @utils.Random::new(KERNEL_SEED),
  )
}

///|
/// The p-value of the test of two columns, with a conditioning variable.
fn kernel_conditional(
  frame : @api.DataFrame,
  first : String,
  second : String,
  conditioning : String,
) -> Double {
  @gcm.kernel_based(
    kernel_column(frame, first),
    kernel_column(frame, second),
    Some(kernel_column(frame, conditioning)),
    false,
    1,
    2000,
    kernel_first_p_value,
    @utils.Random::new(KERNEL_SEED),
  )
}

///|
/// The p-value of the first run of the bootstrap.
fn kernel_first_p_value(p_values : Array[Double]) -> Double {
  p_values[0]
}

///|
/// The smallest p-value of the runs of the bootstrap.
fn kernel_smallest_p_value(p_values : Array[Double]) -> Double {
  let mut smallest = p_values[0]
  for p_value in p_values {
    if p_value < smallest {
      smallest = p_value
    }
  }
  smallest
}

///|
/// Whether two p-values agree.
fn kernel_same(a : Double, b : Double) -> Bool {
  (a - b).abs() <= KERNEL_TOLERANCE * b.abs()
}

///|
/// The p-values of the collider fixture, whose graph is `X -> Z <- Y`.
fn kernel_collider_p_values() -> (
  Double,
  Double,
  Double,
  Double,
  Double,
  Double,
) {
  let frame = @gcm.validation_collider_frame()
  (
    kernel_pair(frame, "X", "Y"),
    kernel_pair(frame, "X", "Z"),
    kernel_pair(frame, "Y", "Z"),
    kernel_conditional(frame, "X", "Y", "Z"),
    kernel_conditional(frame, "X", "Z", "Y"),
    kernel_conditional(frame, "Y", "Z", "X"),
  )
}

///|
/// The p-values of the chain fixture, whose graph is `X -> Z -> Y`.
fn kernel_chain_p_values() -> (Double, Double, Double, Double, Double, Double) {
  let frame = @gcm.validation_chain_frame()
  (
    kernel_pair(frame, "X", "Y"),
    kernel_pair(frame, "X", "Z"),
    kernel_pair(frame, "Y", "Z"),
    kernel_conditional(frame, "X", "Y", "Z"),
    kernel_conditional(frame, "X", "Z", "Y"),
    kernel_conditional(frame, "Y", "Z", "X"),
  )
}

///|
/// The p-values of the fork fixture, whose graph is `Z -> X` and `Z -> Y`.
fn kernel_fork_p_values() -> (Double, Double, Double, Double, Double, Double) {
  let frame = @gcm.validation_fork_frame()
  (
    kernel_pair(frame, "X", "Y"),
    kernel_pair(frame, "X", "Z"),
    kernel_pair(frame, "Y", "Z"),
    kernel_conditional(frame, "X", "Y", "Z"),
    kernel_conditional(frame, "X", "Z", "Y"),
    kernel_conditional(frame, "Y", "Z", "X"),
  )
}

///|
/// The p-values of the general fixture, whose graph is `Z -> X`, `Z -> Y` and
/// `X -> Y`.
fn kernel_general_p_values() -> (Double, Double, Double, Double, Double, Double) {
  let frame = @gcm.validation_general_frame()
  (
    kernel_pair(frame, "X", "Y"),
    kernel_pair(frame, "X", "Z"),
    kernel_pair(frame, "Y", "Z"),
    kernel_conditional(frame, "X", "Y", "Z"),
    kernel_conditional(frame, "X", "Z", "Y"),
    kernel_conditional(frame, "Y", "Z", "X"),
  )
}

///|
/// The p-values of the non-linear fixture, whose graph is `X -> Y -> Z`.
fn kernel_nonlinear_p_values() -> (
  Double,
  Double,
  Double,
  Double,
  Double,
  Double,
) {
  let frame = @gcm.validation_nonlinear_frame()
  (
    kernel_pair(frame, "X", "Y"),
    kernel_pair(frame, "X", "Z"),
    kernel_pair(frame, "Y", "Z"),
    kernel_conditional(frame, "X", "Y", "Z"),
    kernel_conditional(frame, "X", "Z", "Y"),
    kernel_conditional(frame, "Y", "Z", "X"),
  )
}

///|
/// The p-values of the collider fixture agree with the upstream.
test "the p-values of the collider fixture agree with the upstream" {
  let (xy, xz, yz, xy_z, xz_y, yz_x) = kernel_collider_p_values()
  assert_true(kernel_same(xy, 5.49487901344578811e-01))
  assert_true(kernel_same(xz, 7.86620205069921141e-05))
  assert_true(kernel_same(yz, 4.80876649611161611e-09))
  assert_true(kernel_same(xy_z, 1.32496725281927574e-04))
  assert_true(kernel_same(xz_y, 4.10928129301879608e-07))
  assert_true(kernel_same(yz_x, 9.54707236888729938e-06))
}

///|
/// The p-values of the chain fixture agree with the upstream.
test "the p-values of the chain fixture agree with the upstream" {
  let (xy, xz, yz, xy_z, xz_y, yz_x) = kernel_chain_p_values()
  assert_true(kernel_same(xy, 5.26456656047002980e-12))
  assert_true(kernel_same(xz, 2.07611705604904273e-14))
  assert_true(kernel_same(yz, 4.44089209850062616e-16))
  assert_true(kernel_same(xy_z, 4.24506187907425225e-01))
  assert_true(kernel_same(xz_y, 9.90656096298347943e-02))
  assert_true(kernel_same(yz_x, 1.15180818437010668e-03))
}

///|
/// The p-values of the fork fixture agree with the upstream.
test "the p-values of the fork fixture agree with the upstream" {
  let (xy, xz, yz, xy_z, xz_y, yz_x) = kernel_fork_p_values()
  assert_true(kernel_same(xy, 5.41788836017076392e-14))
  assert_true(kernel_same(xz, 1.22124532708767219e-15))
  assert_true(kernel_same(yz, 1.88737914186276612e-15))
  assert_true(kernel_same(xy_z, 1.77488509791884352e-01))
  assert_true(kernel_same(xz_y, 3.39846697388468399e-03))
  assert_true(kernel_same(yz_x, 2.28393074119814798e-05))
}

///|
/// The p-values of the general fixture agree with the upstream.
test "the p-values of the general fixture agree with the upstream" {
  let (xy, xz, yz, xy_z, xz_y, yz_x) = kernel_general_p_values()
  assert_true(kernel_same(xy, 1.66533453693773481e-15))
  assert_true(kernel_same(xz, 2.67563748934662726e-14))
  assert_true(kernel_same(yz, 2.20823359597943636e-13))
  assert_true(kernel_same(xy_z, 2.40686851360472076e-06))
  assert_true(kernel_same(xz_y, 1.66531139264569084e-01))
  assert_true(kernel_same(yz_x, 2.68093856908624417e-03))
}

///|
/// The p-values of the non-linear fixture agree with the upstream.
test "the p-values of the non-linear fixture agree with the upstream" {
  let (xy, xz, yz, xy_z, xz_y, yz_x) = kernel_nonlinear_p_values()
  assert_true(kernel_same(xy, 7.76214500481930969e-05))
  assert_true(kernel_same(xz, 4.81223556144090292e-02))
  assert_true(kernel_same(yz, 6.23164186919211716e-10))
  assert_true(kernel_same(xy_z, 1.81800323370263528e-01))
  assert_true(kernel_same(xz_y, 8.02657478986116280e-02))
  assert_true(kernel_same(yz_x, 7.89089585763180779e-05))
}

///|
/// The p-value of the conditional test is not symmetric in its two variables.
///
/// The kernel of the first variable is built from that variable and from half
/// of the conditioning variable, and the kernel of the second one is not, so
/// the two orders of the arguments give two different p-values.
test "the p-value of the conditional test is not symmetric in its two variables" {
  let chain = @gcm.validation_chain_frame()
  let fork = @gcm.validation_fork_frame()
  let chain_xy = kernel_conditional(chain, "X", "Y", "Z")
  let chain_yx = kernel_conditional(chain, "Y", "X", "Z")
  assert_true(kernel_same(chain_xy, 4.24506187907425225e-01))
  assert_true(kernel_same(chain_yx, 4.66289432601723397e-01))
  assert_false(kernel_same(chain_xy, chain_yx))
  let fork_xy = kernel_conditional(fork, "X", "Y", "Z")
  let fork_yx = kernel_conditional(fork, "Y", "X", "Z")
  assert_true(kernel_same(fork_xy, 1.77488509791884352e-01))
  assert_true(kernel_same(fork_yx, 1.82808519054147744e-01))
  assert_false(kernel_same(fork_xy, fork_yx))
}

///|
/// The p-value of the unconditional test is symmetric in its two variables.
test "the p-value of the unconditional test is symmetric in its two variables" {
  let frame = @gcm.validation_chain_frame()
  let xy = kernel_pair(frame, "X", "Y")
  let yx = kernel_pair(frame, "Y", "X")
  assert_true(kernel_same(xy, yx))
  assert_true(kernel_same(xy, 5.26456656047002980e-12))
}

///|
/// A constant variable makes the test return the p-value of one.
test "a constant variable makes the test return the p-value of one" {
  let frame = @gcm.validation_chain_frame()
  let constant = kernel_constant(frame.nrows())
  let constant_x = @gcm.kernel_based(
    constant,
    kernel_column(frame, "X"),
    None,
    false,
    1,
    2000,
    kernel_first_p_value,
    @utils.Random::new(KERNEL_SEED),
  )
  assert_eq(constant_x, 1.0)
  let constant_y = @gcm.kernel_based(
    kernel_column(frame, "X"),
    constant,
    None,
    false,
    1,
    2000,
    kernel_first_p_value,
    @utils.Random::new(KERNEL_SEED),
  )
  assert_eq(constant_y, 1.0)
}

///|
/// A conditioning variable that holds a single value makes the test the
/// unconditional one.
test "a conditioning variable that holds a single value makes the test the unconditional one" {
  let frame = @gcm.validation_chain_frame()
  let constant = kernel_constant(frame.nrows())
  let conditional = @gcm.kernel_based(
    kernel_column(frame, "X"),
    kernel_column(frame, "Y"),
    Some(constant),
    false,
    1,
    2000,
    kernel_first_p_value,
    @utils.Random::new(KERNEL_SEED),
  )
  let unconditional = kernel_pair(frame, "X", "Y")
  assert_true(kernel_same(conditional, unconditional))
}

///|
/// A constant column of a variable is removed before the test.
test "a constant column of a variable is removed before the test" {
  let frame = @gcm.validation_chain_frame()
  // The matrix of X holds the column of X and a column that holds a single
  // value, so the test has to remove the second one and give the p-value of
  // the pair of X and Y.
  let with_constant = @utils.Matrix::from_columns([
    kernel_column(frame, "X").col(0),
    kernel_constant(frame.nrows()).col(0),
  ])
  let p_value = @gcm.kernel_based(
    with_constant,
    kernel_column(frame, "Y"),
    None,
    false,
    1,
    2000,
    kernel_first_p_value,
    @utils.Random::new(KERNEL_SEED),
  )
  assert_true(kernel_same(p_value, kernel_pair(frame, "X", "Y")))
}

///|
/// The bootstrap of the test merges the p-values of its runs.
test "the bootstrap of the test merges the p-values of its runs" {
  let frame = @gcm.validation_chain_frame()
  let x = kernel_column(frame, "X")
  let y = kernel_column(frame, "Y")
  let z = kernel_column(frame, "Z")
  // The p-values of the runs are collected, so that the result of the
  // adjustment can be compared with them.
  let runs : Array[Double] = []
  let smallest = @gcm.kernel_based(
    x,
    y,
    Some(z),
    true,
    3,
    2000,
    fn(p_values) {
      for p_value in p_values {
        runs.push(p_value)
      }
      kernel_smallest_p_value(p_values)
    },
    @utils.Random::new(KERNEL_SEED),
  )
  assert_eq(runs.length(), 3)
  assert_true(smallest >= 0.0)
  assert_true(smallest <= 1.0)
  // The result of the adjustment is the smallest of the p-values of the runs.
  let mut minimum = runs[0]
  for p_value in runs {
    if p_value < minimum {
      minimum = p_value
    }
  }
  assert_eq(smallest, minimum)
  // The smallest of the three runs is not larger than the p-value of a single
  // run of the test.
  let single = kernel_conditional(frame, "X", "Y", "Z")
  assert_true(smallest <= single + KERNEL_TOLERANCE)
}

///|
/// The test tells a dependent pair of variables from an independent one.
test "the test tells a dependent pair of variables from an independent one" {
  let frame = @gcm.validation_chain_frame()
  // Z is a child of X in the fixture, so the pair is dependent and the p-value
  // is tiny.
  let dependent = kernel_pair(frame, "X", "Z")
  assert_true(dependent < 1.0e-10)
  // The rows of Z are shuffled, which breaks the dependence of the pair: the
  // two columns hold then the draws of two independent samples.
  let rng = @utils.Random::new(KERNEL_SEED)
  let shuffled = @utils.Random::shuffle(rng, kernel_column(frame, "Z").col(0))
  let independent = @gcm.kernel_based(
    kernel_column(frame, "X"),
    @utils.Matrix::from_columns([shuffled]),
    None,
    false,
    1,
    2000,
    kernel_first_p_value,
    @utils.Random::new(KERNEL_SEED),
  )
  assert_true(independent > dependent)
  assert_true(independent > 1.0e-3)
}

///|
/// The mean of the p-values of the runs of the bootstrap.
///
/// This is the adjustment of the upstream test file, which merges the p-values
/// of the runs of its bootstrap with the mean of numpy.
fn kernel_mean_p_value(p_values : Array[Double]) -> Double {
  let mut total = 0.0
  for p_value in p_values {
    total = total + p_value
  }
  total / p_values.length().to_double()
}

///|
/// The column of the frame as a matrix, with the encoding of the upstream.
///
/// The upstream encodes every matrix of its test on its own, with the one-hot
/// encoder of a column that holds categories, and the port does the same.
fn kernel_encoded_column(
  frame : @api.DataFrame,
  name : String,
) -> @utils.Matrix {
  if frame.is_discrete(name) {
    @gcm.one_hot_encode_frame(frame.select([name]))
  } else {
    kernel_column(frame, name)
  }
}

///|
/// The p-value of the test of two columns, with an optional conditioning
/// variable.
///
/// The columns that hold categories are encoded with the one-hot encoder, the
/// way the upstream encodes the data of its test.
fn kernel_encoded(
  frame : @api.DataFrame,
  first : String,
  second : String,
  conditioning : String?,
) -> Double {
  let x = kernel_encoded_column(frame, first)
  let y = kernel_encoded_column(frame, second)
  let z = match conditioning {
    Some(name) => Some(kernel_encoded_column(frame, name))
    None => None
  }
  @gcm.kernel_based(
    x,
    y,
    z,
    false,
    1,
    2000,
    kernel_first_p_value,
    @utils.Random::new(KERNEL_SEED),
  )
}

///|
/// A categorical conditioning variable does not hide the independence of the
/// other two columns.
///
/// This is the case of the upstream
/// `test_given_categorical_conditionally_independent_data_when_perform_kernel_based_test_then_not_reject`.
test "a categorical conditioning variable does not hide the independence of the other two columns" {
  let frame = @gcm.kernel_categorical_frame()
  let p_value = kernel_encoded(frame, "X", "Y", Some("Z"))
  assert_true(kernel_same(p_value, 6.78864398589645e-01))
  assert_true(p_value > 0.05)
}

///|
/// A categorical column is dependent on the column that gives its class.
///
/// This is the case of the upstream
/// `test_given_categorical_conditionally_dependent_data_when_perform_kernel_based_test_then_reject`.
test "a categorical column is dependent on the column that gives its class" {
  let frame = @gcm.kernel_categorical_frame()
  let p_value = kernel_encoded(frame, "X", "Z", Some("Y"))
  assert_true(p_value < 0.05)
}

///|
/// A categorical column that does not depend on the other one is independent of
/// it.
///
/// This is the case of the upstream
/// `test_given_categorical_independent_data_when_perform_kernel_based_test_then_not_reject`.
test "a categorical column that does not depend on the other one is independent of it" {
  let frame = @gcm.kernel_categorical_frame()
  let p_value = kernel_encoded(frame, "X", "R", None)
  assert_true(kernel_same(p_value, 7.793246146472628e-01))
  assert_true(p_value > 0.05)
}

///|
/// A categorical column that holds the class of the sign of the other one is
/// dependent on it.
///
/// This is the case of the upstream
/// `test_given_categorical_dependent_data_when_perform_kernel_based_test_then_reject`.
test "a categorical column that holds the class of the sign of the other one is dependent on it" {
  let frame = @gcm.kernel_categorical_frame()
  let p_value = kernel_encoded(frame, "X", "Z", None)
  assert_true(p_value < 0.05)
}

///|
/// The test of the same data with the same seed gives the same p-value.
///
/// This is the case of the upstream
/// `test_given_random_seed_when_perform_pairwise_kernel_based_test_then_return_deterministic_result`,
/// which asserts that two runs of the generator of the upstream with the same
/// seed give the same p-value. The number of the p-value is not a number of
/// the upstream, because the upstream draws the rows of its sample with the
/// global generator of numpy, which is not seeded when it draws the fixture.
test "the test of the same data with the same seed gives the same p-value" {
  let frame = @gcm.kernel_determinism_frame()
  let x = kernel_column(frame, "X")
  let y = kernel_column(frame, "Y")
  let first = @gcm.kernel_based(
    x,
    y,
    None,
    true,
    2,
    10,
    kernel_mean_p_value,
    @utils.Random::new(KERNEL_SEED),
  )
  let second = @gcm.kernel_based(
    x,
    y,
    None,
    true,
    2,
    10,
    kernel_mean_p_value,
    @utils.Random::new(KERNEL_SEED),
  )
  assert_eq(first, second)
}

///|
/// The test of the same data with another seed gives another p-value.
///
/// This is the case of the upstream
/// `test_given_random_seed_when_perform_pairwise_kernel_based_test_then_return_deterministic_result`,
/// which asserts that two runs of the generator of the upstream without a seed
/// give different p-values.
test "the test of the same data with another seed gives another p-value" {
  let frame = @gcm.kernel_determinism_frame()
  let x = kernel_column(frame, "X")
  let y = kernel_column(frame, "Y")
  let first = @gcm.kernel_based(
    x,
    y,
    None,
    true,
    2,
    10,
    kernel_mean_p_value,
    @utils.Random::new(KERNEL_SEED),
  )
  let second = @gcm.kernel_based(
    x,
    y,
    None,
    true,
    2,
    10,
    kernel_mean_p_value,
    @utils.Random::new(KERNEL_SEED + 1UL),
  )
  assert_true(first != second)
}

///|
/// The test of the same data with the same seed gives the same p-value, with a
/// conditioning variable.
///
/// This is the case of the upstream
/// `test_given_random_seed_when_perform_conditional_kernel_based_test_then_return_deterministic_result`.
test "the test of the same data with the same seed gives the same p-value, with a conditioning variable" {
  let frame = @gcm.kernel_conditional_determinism_frame()
  let x = kernel_column(frame, "X")
  let y = kernel_column(frame, "Y")
  let z = kernel_column(frame, "Z")
  let first = @gcm.kernel_based(
    x,
    z,
    Some(y),
    true,
    2,
    5,
    kernel_mean_p_value,
    @utils.Random::new(KERNEL_SEED),
  )
  let second = @gcm.kernel_based(
    x,
    z,
    Some(y),
    true,
    2,
    5,
    kernel_mean_p_value,
    @utils.Random::new(KERNEL_SEED),
  )
  assert_eq(first, second)
}

///|
/// The test of the same data with another seed gives another p-value, with a
/// conditioning variable.
///
/// This is the case of the upstream
/// `test_given_random_seed_when_perform_conditional_kernel_based_test_then_return_deterministic_result`,
/// which asserts that two runs of the generator of the upstream without a seed
/// give different p-values.
test "the test of the same data with another seed gives another p-value, with a conditioning variable" {
  let frame = @gcm.kernel_conditional_determinism_frame()
  let x = kernel_column(frame, "X")
  let y = kernel_column(frame, "Y")
  let z = kernel_column(frame, "Z")
  let first = @gcm.kernel_based(
    x,
    z,
    Some(y),
    true,
    2,
    5,
    kernel_mean_p_value,
    @utils.Random::new(KERNEL_SEED),
  )
  let second = @gcm.kernel_based(
    x,
    z,
    Some(y),
    true,
    2,
    5,
    kernel_mean_p_value,
    @utils.Random::new(KERNEL_SEED + 1UL),
  )
  assert_true(first != second)
}

///|
/// An almost constant column does not make the test return a number that is
/// not a number.
///
/// This is the case of the upstream
/// `test_given_almost_constant_data_when_perform_kernel_based_test_then_does_not_return_nans`.
///
/// The upstream draws ten of the hundred rows of its sample, and the port
/// draws another ten of them, so the two p-values are not the same numbers.
/// Only the property the upstream asserts is mirrored here.
test "an almost constant column does not make the test return a number that is not a number" {
  let frame = @gcm.kernel_almost_constant_frame()
  let constant = kernel_column(frame, "C")
  let noise = kernel_column(frame, "N")
  let other = kernel_column(frame, "M")
  let pair = @gcm.kernel_based(
    constant,
    noise,
    None,
    false,
    1,
    10,
    kernel_first_p_value,
    @utils.Random::new(KERNEL_SEED),
  )
  let conditional = @gcm.kernel_based(
    constant,
    noise,
    Some(other),
    false,
    1,
    10,
    kernel_first_p_value,
    @utils.Random::new(KERNEL_SEED),
  )
  let conditioning = @gcm.kernel_based(
    noise,
    other,
    Some(constant),
    false,
    1,
    10,
    kernel_first_p_value,
    @utils.Random::new(KERNEL_SEED),
  )
  // A number that is not a number is the only value that differs from itself.
  assert_false(pair != pair)
  assert_false(conditional != conditional)
  assert_false(conditioning != conditioning)
}
