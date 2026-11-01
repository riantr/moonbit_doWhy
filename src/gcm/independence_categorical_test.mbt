///|
/// The tests of the regression based independence test with categorical data.
///
/// The expectations are the ones of the upstream tests of
/// `dowhy.gcm.independence_test.regression`, which are in
/// `tests/gcm/independence_test/test_regression.py`. The four tests of the
/// upstream that use categorical data have their counterpart here; the five
/// tests that use continuous data are the ones of `independence_test.mbt`.
///
/// The fixtures are drawn with the deterministic generator of the `utils`
/// package. The upstream draws its samples with the global generator of numpy,
/// so the samples of the upstream and of the port are different numbers; the
/// decision the upstream asserts holds for every sample.

///|
/// The seed of the fixture of the categorical independence test.
const CATEGORICAL_INDEPENDENCE_SEED : UInt64 = 2080UL

///|
/// The number of samples of the fixture of the categorical independence test.
const CATEGORICAL_INDEPENDENCE_NUM_SAMPLES : Int32 = 5000

///|
/// A frame with one discrete column.
///
/// The constructor of the variant of the column of the `api` package is not
/// reachable from another package, so the frame is built with the method that
/// adds a discrete column.
fn discrete_frame(name : String, values : Array[String]) -> @api.DataFrame {
  @api.DataFrame::new([], Map([])).with_discrete(name, values)
}

///|
/// The samples of the categorical independence test.
///
/// The upstream draws `x` from a normal distribution, turns it into the two
/// categories `Class 1` and `Class 2`, and adds noise to the class of every
/// sample to get `y`. The draws happen in the order of the upstream: the
/// normal samples of `x` first, and then the noise of `y`.
fn categorical_independence_fixture() -> (
  @api.DataFrame,
  @api.DataFrame,
  @api.DataFrame,
) {
  let rng = @utils.Random::new(CATEGORICAL_INDEPENDENCE_SEED)
  let x_values : Array[Double] = []
  for _ in 0..<CATEGORICAL_INDEPENDENCE_NUM_SAMPLES {
    x_values.push(rng.next_normal())
  }
  let classes : Array[String] = []
  for value in x_values {
    classes.push(if value > 0.0 { "Class 1" } else { "Class 2" })
  }
  let noise : Array[Double] = []
  for _ in 0..<CATEGORICAL_INDEPENDENCE_NUM_SAMPLES {
    noise.push(rng.next_normal())
  }
  let y_values : Array[Double] = []
  for i in 0..<CATEGORICAL_INDEPENDENCE_NUM_SAMPLES {
    let class_value = if x_values[i] > 0.0 { 1.0 } else { 0.0 }
    y_values.push(class_value + noise[i])
  }
  (
    @api.DataFrame::from_numeric(["X"], Map([("X", x_values)])),
    discrete_frame("Z", classes),
    @api.DataFrame::from_numeric(["Y"], Map([("Y", y_values)])),
  )
}

///|
/// The samples of the categorical independence test without a relation
/// between the two variables.
///
/// The upstream draws the categories of the second variable from the uniform
/// distribution, so the two variables are independent.
fn independent_categorical_independence_fixture() -> (
  @api.DataFrame,
  @api.DataFrame,
) {
  let rng = @utils.Random::new(CATEGORICAL_INDEPENDENCE_SEED)
  let x_values : Array[Double] = []
  for _ in 0..<CATEGORICAL_INDEPENDENCE_NUM_SAMPLES {
    x_values.push(rng.next_normal())
  }
  let classes : Array[String] = []
  for _ in 0..<CATEGORICAL_INDEPENDENCE_NUM_SAMPLES {
    classes.push(if rng.next_double() < 0.5 { "Class 1" } else { "Class 2" })
  }
  (
    @api.DataFrame::from_numeric(["X"], Map([("X", x_values)])),
    discrete_frame("Y", classes),
  )
}

///|
test "the regression based test finds independent categorical variables independent" {
  let (x, classes, y) = categorical_independence_fixture()
  let p_value = @gcm.regression_based_with_categorical(
    x,
    y,
    Some(classes),
    40,
    3,
    average_p_value,
    -1,
    @utils.Random::new(CATEGORICAL_INDEPENDENCE_SEED),
  )
  assert_true(p_value > 0.05)
}

///|
test "the regression based test finds dependent categorical variables dependent" {
  let (x, classes, y) = categorical_independence_fixture()
  // The conditioning variable is the numeric one, and the categorical variable
  // is the target of the test.
  let p_value = @gcm.regression_based_with_categorical(
    x,
    classes,
    Some(y),
    40,
    3,
    average_p_value,
    -1,
    @utils.Random::new(CATEGORICAL_INDEPENDENCE_SEED),
  )
  assert_true(p_value < 0.05)
}

///|
test "the regression based test finds independent categorical variables independent without a conditioning variable" {
  let (x, classes) = independent_categorical_independence_fixture()
  let p_value = @gcm.regression_based_with_categorical(
    x,
    classes,
    None,
    40,
    3,
    average_p_value,
    -1,
    @utils.Random::new(CATEGORICAL_INDEPENDENCE_SEED),
  )
  assert_true(p_value > 0.05)
}

///|
test "the regression based test finds dependent categorical variables dependent without a conditioning variable" {
  let (x, classes, _) = categorical_independence_fixture()
  let p_value = @gcm.regression_based_with_categorical(
    x,
    classes,
    None,
    40,
    3,
    average_p_value,
    -1,
    @utils.Random::new(CATEGORICAL_INDEPENDENCE_SEED),
  )
  assert_true(p_value < 0.05)
}
