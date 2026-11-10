///|
/// The tests of the unit change layer of the `gcm` package.
///
/// The upstream reference of the layer is
/// `_verify/gcm_unit_change_reference.py`, which runs the upstream
/// `dowhy.gcm.unit_change` on the fixtures of the layer. The fixtures of the port
/// are drawn from the generator of the `utils` package, and the reference script
/// reproduces that generator in Python, so that the fixtures of the port and the
/// fixtures of the reference are the same numbers.
///
/// The upstream fits the mechanisms of the fixtures without an intercept, because
/// the relations of the fixtures are exactly linear. The port fits its model with
/// an intercept, like the fit of the `gcm` package does everywhere else. The
/// intercept of the fixtures of the layer is zero up to the rounding of the fit,
/// so the contributions of the port and of the upstream agree to the tolerance of
/// the tests.
///
/// The upstream has a random forest regressor next to its linear one, so that it
/// can tell the linear attribution from the non-linear one. The port has one
/// model, which is linear, so the tests of the layer use the non-linear
/// attribution with the linear model of the port, which is what the upstream test
/// file `tests/gcm/test_unit_change.py` compares against the linear attribution.

///|
/// The seed of the generators of the fixtures.
const UNIT_CHANGE_SEED : UInt64 = 2025

///|
/// The number of the rows of the fixtures.
const UNIT_CHANGE_NUM_ROWS : Int32 = 100

///|
/// The generator of the fixture with the given index.
fn unit_change_rng(index : UInt64) -> @utils.Random {
  @utils.Random::new(UNIT_CHANGE_SEED + index)
}

///|
/// The given number of the samples of the standard normal distribution.
fn unit_change_normals(rng : @utils.Random, count : Int32) -> Array[Double] {
  let out : Array[Double] = []
  for _ in 0..<count {
    out.push(rng.next_normal())
  }
  out
}

///|
/// The values of the given samples, multiplied by the given factor.
fn unit_change_scaled(values : Array[Double], factor : Double) -> Array[Double] {
  let out : Array[Double] = []
  for value in values {
    out.push(factor * value)
  }
  out
}

///|
/// The sum of the given samples.
fn unit_change_sum(
  left : Array[Double],
  right : Array[Double],
) -> Array[Double] {
  let out : Array[Double] = []
  for i in 0..<left.length() {
    out.push(left[i] + right[i])
  }
  out
}

///|
/// The data frame of the given columns.
fn unit_change_frame(
  columns : Array[(String, Array[Double])],
) -> @api.DataFrame {
  let order : Array[String] = []
  let payload : Map[String, Array[Double]] = Map([])
  for column in columns {
    let (name, values) = column
    order.push(name)
    payload.set(name, values)
  }
  @api.DataFrame::from_numeric(order, payload)
}

///|
/// The fixture of the layer.
///
/// The fixture is the one of the upstream test file
/// `tests/gcm/test_unit_change.py`: the relation of the background is
/// `C = 2A + 3B` and the relation of the foreground is `C = 3A + 2B`.
struct UnitChangeFixture {
  a1 : Array[Double]
  b1 : Array[Double]
  a2 : Array[Double]
  b2 : Array[Double]
  background_data : @api.DataFrame
  foreground_data : @api.DataFrame
  background_mechanism : @gcm.PredictionModel
  foreground_mechanism : @gcm.PredictionModel
}

///|
/// The fixture of the layer.
fn unit_change_fixture() -> UnitChangeFixture {
  let rng = unit_change_rng(1)
  let a1 = unit_change_normals(rng, UNIT_CHANGE_NUM_ROWS)
  let b1 = unit_change_normals(rng, UNIT_CHANGE_NUM_ROWS)
  let a2 = unit_change_normals(rng, UNIT_CHANGE_NUM_ROWS)
  let b2 = unit_change_normals(rng, UNIT_CHANGE_NUM_ROWS)
  let c1 = unit_change_sum(
    unit_change_scaled(a1, 2.0),
    unit_change_scaled(b1, 3.0),
  )
  let c2 = unit_change_sum(
    unit_change_scaled(a2, 3.0),
    unit_change_scaled(b2, 2.0),
  )
  let background_mechanism = @gcm.PredictionModel::linear().fit(
    @utils.Matrix::from_columns([a1, b1]),
    c1,
  )
  let foreground_mechanism = @gcm.PredictionModel::linear().fit(
    @utils.Matrix::from_columns([a2, b2]),
    c2,
  )
  {
    a1,
    b1,
    a2,
    b2,
    background_data: unit_change_frame([("A", a1), ("B", b1)]),
    foreground_data: unit_change_frame([("A", a2), ("B", b2)]),
    background_mechanism,
    foreground_mechanism,
  }
}

///|
/// The fixture of the input only attributions.
///
/// The fixture is the one of the upstream test file
/// `tests/gcm/test_unit_change.py`: the relation is `C = 3A + 2B` and the
/// mechanism of the upstream has the coefficients `[3, 2]` and no intercept.
struct UnitChangeInputOnlyFixture {
  a1 : Array[Double]
  b1 : Array[Double]
  a2 : Array[Double]
  b2 : Array[Double]
  background_data : @api.DataFrame
  foreground_data : @api.DataFrame
  mechanism : @gcm.PredictionModel
}

///|
/// The fixture of the input only attributions.
fn unit_change_input_only_fixture() -> UnitChangeInputOnlyFixture {
  let rng = unit_change_rng(2)
  let a1 = unit_change_normals(rng, UNIT_CHANGE_NUM_ROWS)
  let b1 = unit_change_normals(rng, UNIT_CHANGE_NUM_ROWS)
  let a2 = unit_change_normals(rng, UNIT_CHANGE_NUM_ROWS)
  let b2 = unit_change_normals(rng, UNIT_CHANGE_NUM_ROWS)
  {
    a1,
    b1,
    a2,
    b2,
    background_data: unit_change_frame([("A", a1), ("B", b1)]),
    foreground_data: unit_change_frame([("A", a2), ("B", b2)]),
    mechanism: @gcm.PredictionModel::with_fixed_parameters([3.0, 2.0], 0.0),
  }
}

///|
/// The fixture of the attributions without a change of the inputs.
///
/// The data of the fixture holds the relation `C = 3A + 2B` and the mechanism of
/// the upstream has the coefficients `[3, 2]` and no intercept.
fn unit_change_unchanged_fixture() -> (@api.DataFrame, @gcm.PredictionModel) {
  let rng = unit_change_rng(3)
  let a = unit_change_normals(rng, UNIT_CHANGE_NUM_ROWS)
  let b = unit_change_normals(rng, UNIT_CHANGE_NUM_ROWS)
  let c = unit_change_sum(
    unit_change_scaled(a, 3.0),
    unit_change_scaled(b, 2.0),
  )
  let data = unit_change_frame([("A", a), ("B", b), ("C", c)])
  (data, @gcm.PredictionModel::with_fixed_parameters([3.0, 2.0], 0.0))
}

///|
/// The configuration of the Shapley estimator of the layer.
fn unit_change_shapley_config() -> @gcm.ShapleyConfig {
  @gcm.ShapleyConfig::new(@gcm.ShapleyApproximationMethod::auto())
}

///|
/// The given column of the given frame, compared with the given values.
///
/// The reference prints only the first rows of its frames, so the comparison
/// covers the rows the reference prints and not the whole column.
fn unit_change_assert_column(
  frame : @api.DataFrame,
  name : String,
  expected : Array[Double],
  tolerance : Double,
) -> Unit raise {
  let actual = frame.numeric(name)
  assert_true(actual.length() >= expected.length())
  for i in 0..<expected.length() {
    assert_true((actual[i] - expected[i]).abs() <= tolerance)
  }
}

///|
/// The names of the columns of the given frame, compared with the given names.
fn unit_change_assert_columns(
  frame : @api.DataFrame,
  expected : Array[String],
) -> Unit raise {
  let actual = frame.column_names()
  assert_eq(actual.length(), expected.length())
  for i in 0..<expected.length() {
    assert_true(actual[i] == expected[i])
  }
}

///|
test "given two fitted linear mechanisms when attributing the change of the output with the linear method then report the contributions of the inputs and of the mechanism" {
  let fixture = unit_change_fixture()
  let contributions = @gcm.unit_change_linear(
    fixture.background_mechanism,
    fixture.background_data,
    fixture.foreground_mechanism,
    fixture.foreground_data,
    ["A", "B"],
  )
  unit_change_assert_columns(contributions, ["A", "B", "f"])
  let a = contributions.numeric("A")
  let b = contributions.numeric("B")
  let f = contributions.numeric("f")
  for k in 0..<UNIT_CHANGE_NUM_ROWS {
    // The contribution of an input is the half of the sum of the coefficients of
    // the two mechanisms times the change of the input.
    assert_true((a[k] - 2.5 * (fixture.a2[k] - fixture.a1[k])).abs() <= 1.0e-8)
    assert_true((b[k] - 2.5 * (fixture.b2[k] - fixture.b1[k])).abs() <= 1.0e-8)
    // The contribution of the mechanism is the half of the difference of the
    // coefficients times the sum of the inputs.
    let expected = 0.5 * (fixture.a1[k] + fixture.a2[k]) -
      0.5 * (fixture.b1[k] + fixture.b2[k])
    assert_true((f[k] - expected).abs() <= 1.0e-8)
  }
}

///|
test "given two fitted linear mechanisms when attributing the change of the output with the non-linear method then report the same contributions as the linear method" {
  let fixture = unit_change_fixture()
  let linear = @gcm.unit_change_linear(
    fixture.background_mechanism,
    fixture.background_data,
    fixture.foreground_mechanism,
    fixture.foreground_data,
    ["A", "B"],
  )
  let nonlinear = @gcm.unit_change_nonlinear(
    fixture.background_mechanism,
    fixture.background_data,
    fixture.foreground_mechanism,
    fixture.foreground_data,
    ["A", "B"],
    unit_change_shapley_config(),
  )
  unit_change_assert_columns(nonlinear, ["A", "B", "f"])
  for name in ["A", "B", "f"] {
    unit_change_assert_column(nonlinear, name, linear.numeric(name), 1.0e-8)
  }
}

///|
test "given two fitted linear mechanisms when attributing the change of the output then report the numbers of the upstream reference" {
  let fixture = unit_change_fixture()
  let linear = @gcm.unit_change_linear(
    fixture.background_mechanism,
    fixture.background_data,
    fixture.foreground_mechanism,
    fixture.foreground_data,
    ["A", "B"],
  )
  let nonlinear = @gcm.unit_change_nonlinear(
    fixture.background_mechanism,
    fixture.background_data,
    fixture.foreground_mechanism,
    fixture.foreground_data,
    ["A", "B"],
    unit_change_shapley_config(),
  )
  let linear_input_only = @gcm.unit_change_linear_input_only(
    fixture.background_mechanism,
    fixture.background_data,
    fixture.foreground_data,
    ["A", "B"],
  )
  let nonlinear_input_only = @gcm.unit_change_nonlinear_input_only(
    fixture.background_mechanism,
    fixture.background_data,
    fixture.foreground_data,
    ["A", "B"],
    unit_change_shapley_config(),
  )
  // The contributions of the linear attribution of the upstream reference.
  unit_change_assert_column(
    linear,
    "A",
    [8.178934740204204, 5.176376295173005, 0.5824461613874098],
    1.0e-8,
  )
  unit_change_assert_column(
    linear,
    "B",
    [-4.046484780315998, -7.538394353298912, 4.349100314169433],
    1.0e-8,
  )
  unit_change_assert_column(
    linear,
    "f",
    [-3.3816118036422926, 0.5962218562670284, -0.7839132579057844],
    1.0e-8,
  )
  assert_true((linear.sum("A") - 54.3616729812026).abs() <= 1.0e-8)
  assert_true((linear.sum("B") - -28.57353649274526).abs() <= 1.0e-8)
  assert_true((linear.sum("f") - -18.24672131712161).abs() <= 1.0e-8)
  // The contributions of the non-linear attribution of the upstream reference.
  unit_change_assert_column(
    nonlinear,
    "A",
    [8.178934740204202, 5.176376295173003, 0.5824461613874097],
    1.0e-8,
  )
  unit_change_assert_column(
    nonlinear,
    "B",
    [-4.046484780315997, -7.5383943532989095, 4.349100314169433],
    1.0e-8,
  )
  unit_change_assert_column(
    nonlinear,
    "f",
    [-3.3816118036422926, 0.5962218562670286, -0.7839132579057844],
    1.0e-8,
  )
  assert_true((nonlinear.sum("A") - 54.3616729812026).abs() <= 1.0e-8)
  assert_true((nonlinear.sum("B") - -28.57353649274524).abs() <= 1.0e-8)
  assert_true((nonlinear.sum("f") - -18.24672131712161).abs() <= 1.0e-8)
  // The contributions of the input only attributions of the upstream reference.
  unit_change_assert_column(
    linear_input_only,
    "A",
    [6.5431477921633645, 4.141101036138404, 0.4659569291099279],
    1.0e-8,
  )
  unit_change_assert_column(
    linear_input_only,
    "B",
    [-4.855781736379197, -9.046073223958693, 5.21892037700332],
    1.0e-8,
  )
  assert_true((linear_input_only.sum("A") - 43.489338384962096).abs() <= 1.0e-8)
  assert_true((linear_input_only.sum("B") - -34.2882437912943).abs() <= 1.0e-8)
  unit_change_assert_column(
    nonlinear_input_only,
    "A",
    [6.5431477921633645, 4.141101036138403, 0.4659569291099279],
    1.0e-8,
  )
  unit_change_assert_column(
    nonlinear_input_only,
    "B",
    [-4.855781736379197, -9.046073223958693, 5.21892037700332],
    1.0e-8,
  )
  assert_true(
    (nonlinear_input_only.sum("A") - 43.48933838496211).abs() <= 1.0e-8,
  )
  assert_true(
    (nonlinear_input_only.sum("B") - -34.2882437912943).abs() <= 1.0e-8,
  )
}

///|
test "given a fitted linear mechanism when attributing the change of the output with the linear input only method then report the contributions of the inputs" {
  let fixture = unit_change_input_only_fixture()
  let contributions = @gcm.unit_change_linear_input_only(
    fixture.mechanism,
    fixture.background_data,
    fixture.foreground_data,
    ["A", "B"],
  )
  unit_change_assert_columns(contributions, ["A", "B"])
  let a = contributions.numeric("A")
  let b = contributions.numeric("B")
  for k in 0..<UNIT_CHANGE_NUM_ROWS {
    // The contribution of an input is the coefficient of the mechanism times the
    // change of the input.
    assert_true((a[k] - 3.0 * (fixture.a2[k] - fixture.a1[k])).abs() <= 1.0e-8)
    assert_true((b[k] - 2.0 * (fixture.b2[k] - fixture.b1[k])).abs() <= 1.0e-8)
  }
}

///|
test "given a fitted linear mechanism when attributing the change of the output with the input only methods then report the same contributions" {
  let fixture = unit_change_input_only_fixture()
  let linear = @gcm.unit_change_linear_input_only(
    fixture.mechanism,
    fixture.background_data,
    fixture.foreground_data,
    ["A", "B"],
  )
  let nonlinear = @gcm.unit_change_nonlinear_input_only(
    fixture.mechanism,
    fixture.background_data,
    fixture.foreground_data,
    ["A", "B"],
    unit_change_shapley_config(),
  )
  unit_change_assert_columns(nonlinear, ["A", "B"])
  for name in ["A", "B"] {
    unit_change_assert_column(nonlinear, name, linear.numeric(name), 1.0e-8)
  }
}

///|
test "given a fitted mechanism and unchanged inputs when attributing the change of the output then report no contribution" {
  let (data, mechanism) = unit_change_unchanged_fixture()
  let contributions = @gcm.unit_change_nonlinear_input_only(
    mechanism,
    data,
    data,
    ["A", "B"],
    unit_change_shapley_config(),
  )
  for name in ["A", "B"] {
    for value in contributions.numeric(name) {
      assert_true(value == 0.0)
    }
  }
}

///|
/// test "given an unfitted mechanism when attributing the change of the output then the attribution is not possible"
///
/// This is the port of the upstream tests
/// `test_given_unfitted_mechanisms_when_evaluate_unit_change_methods_then_raises_exception` and
/// `test_given_unfitted_mechanisms_when_evaluate_unit_change_input_only_methods_then_raises_exception`.
/// The upstream raises a `NotFittedError`, which MoonBit cannot catch, so the
/// check of the mechanism is asserted on its own.
test "given an unfitted mechanism when attributing the change of the output then the attribution is not possible" {
  let unfitted = @gcm.PredictionModel::linear()
  assert_false(@gcm.can_evaluate_unit_change_linear(unfitted))
  assert_false(@gcm.can_evaluate_unit_change_nonlinear(unfitted))
}

///|
/// test "given a non-linear mechanism when attributing the change of the output with the linear method then the attribution is not possible"
///
/// This is the port of the upstream tests
/// `test_given_fitted_nonlinnear_mechanisms_when_evaluate_unit_change_linear_method_then_raises_exception` and
/// `test_given_fitted_nonlinnear_mechanism_when_evaluate_unit_change_linear_input_only_method_then_raises_exception`.
/// The upstream raises an `AttributeError`, because it reads the coefficients of
/// the model of scikit-learn, and MoonBit cannot catch it, so the check of the
/// mechanism is asserted on its own. The upstream uses a random forest for its
/// non-linear model; the port uses the nearest neighbour regression, which is
/// the non-linear model of the port.
test "given a non-linear mechanism when attributing the change of the output with the linear method then the attribution is not possible" {
  let fixture = unit_change_fixture()
  let target = unit_change_sum(
    unit_change_scaled(fixture.a1, 2.0),
    unit_change_scaled(fixture.b1, 3.0),
  )
  let non_linear = @gcm.PredictionModel::nearest_neighbour(k=5).fit(
    @utils.Matrix::from_columns([fixture.a1, fixture.b1]),
    target,
  )
  assert_false(@gcm.can_evaluate_unit_change_linear(non_linear))
  assert_true(@gcm.can_evaluate_unit_change_nonlinear(non_linear))
  assert_true(
    @gcm.can_evaluate_unit_change_linear(fixture.background_mechanism),
  )
  assert_true(
    @gcm.can_evaluate_unit_change_nonlinear(fixture.background_mechanism),
  )
}
