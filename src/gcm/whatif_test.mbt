///|
/// The tests of the what-if questions of a fitted causal model.
///
/// The expectations are the ones of the upstream tests of
/// `dowhy.gcm.whatif`, which are in `tests/gcm/test_whatif.py`; every case of
/// that file has a counterpart here. The fixtures are deterministic: the simple
/// fixture takes the values of a fixed symmetric grid and the values of a fixed
/// noise pattern, the fixture of the average causal effect takes the values of a
/// fixed pseudo random noise that is centred and orthogonal to the treatment,
/// and the fixtures with the categorical variables and with the discrete data
/// are drawn with a fixed seed. The only randomness of the tests comes from the
/// deterministic generator of the `utils` package.

///|
/// The number of rows of the fixtures.
const WHATIF_NUM_ROWS : Int32 = 1000

///|
/// The number of samples that are drawn from a model.
const WHATIF_NUM_SAMPLES : Int32 = 1000

///|
/// The seed of the generator of the tests.
const WHATIF_SEED : UInt64 = 20261031UL

///|
/// The number of rows of the fixture with the categorical variables.
const WHATIF_CATEGORICAL_ROWS : Int32 = 5000

///|
/// The number of samples of the intervention with the categorical variables.
const WHATIF_CATEGORICAL_SAMPLES : Int32 = 100

///|
/// The seed of the generator of the fixture with the categorical variables.
const WHATIF_CATEGORICAL_SEED : UInt64 = 20261032UL

///|
/// The seed of the generator of the fixture with the discrete data.
const WHATIF_DISCRETE_SEED : UInt64 = 20261033UL

///|
/// Whether two numbers are close to each other.
fn whatif_near(a : Double, b : Double, tolerance : Double) -> Bool {
  (a - b).abs() <= tolerance
}

///|
/// The values of `X0` of the simple fixture.
///
/// The pattern is symmetric, so its mean is zero and the fit of the linear
/// relations recovers the coefficients of the relations exactly.
fn whatif_base_values() -> Array[Double] {
  [-1.0, -0.75, -0.5, -0.25, 0.25, 0.5, 0.75, 1.0]
}

///|
/// The noise patterns of the simple fixture.
///
/// The three patterns are the rows three, five and six of the Hadamard matrix
/// of order eight, so they have a mean of zero, they do not lean to one side
/// and they are orthogonal to each other and to the values of `X0`.
fn whatif_noise_patterns() -> (Array[Double], Array[Double], Array[Double]) {
  (
    [1.0, -1.0, -1.0, 1.0, 1.0, -1.0, -1.0, 1.0],
    [1.0, -1.0, 1.0, -1.0, -1.0, 1.0, -1.0, 1.0],
    [1.0, 1.0, -1.0, -1.0, -1.0, -1.0, 1.0, 1.0],
  )
}

///|
/// The data of the simple fixture.
///
/// The fixture is the deterministic version of the fixture of the upstream
/// tests: `X1 = 2 * X0 + noise`, `X2 = 0.5 * X0 + noise` and
/// `X3 = 0.5 * X2 + noise`.
fn whatif_simple_data() -> @api.DataFrame {
  let base = whatif_base_values()
  let (first, second, third) = whatif_noise_patterns()
  let x0 : Array[Double] = []
  let x1 : Array[Double] = []
  let x2 : Array[Double] = []
  let x3 : Array[Double] = []
  for i in 0..<WHATIF_NUM_ROWS {
    let r = i % 8
    let value = base[r]
    let child = 0.5 * value + 0.1 * second[r]
    x0.push(value)
    x1.push(2.0 * value + 0.1 * first[r])
    x2.push(child)
    x3.push(0.5 * child + 0.1 * third[r])
  }
  @api.DataFrame::from_numeric(
    ["X0", "X1", "X2", "X3"],
    Map([("X0", x0), ("X1", x1), ("X2", x2), ("X3", x3)]),
  )
}

///|
/// The model of the simple fixture, whose graph is `X0 -> X1`, `X0 -> X2` and
/// `X2 -> X3`.
fn whatif_simple_model() -> @gcm.ProbabilisticCausalModel {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "X1")
  graph.add_edge("X0", "X2")
  graph.add_edge("X2", "X3")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  model.set_root_model("X0", @gcm.StochasticModel::empirical())
  model.set_causal_mechanism(
    "X1",
    @gcm.CausalMechanism::additive_noise(@gcm.PredictionModel::linear()),
  )
  model.set_causal_mechanism(
    "X2",
    @gcm.CausalMechanism::additive_noise(@gcm.PredictionModel::linear()),
  )
  model.set_causal_mechanism(
    "X3",
    @gcm.CausalMechanism::additive_noise(@gcm.PredictionModel::linear()),
  )
  @gcm.fit(model, whatif_simple_data())
  model
}

///|
/// The observed data of the upstream tests, the single row
/// `X0 = 0`, `X1 = 1`, `X2 = 2` and `X3 = 3`.
fn whatif_observed_row() -> @api.DataFrame {
  @api.DataFrame::from_numeric(
    ["X0", "X1", "X2", "X3"],
    Map([("X0", [0.0]), ("X1", [1.0]), ("X2", [2.0]), ("X3", [3.0])]),
  )
}

///|
/// The treatment of the fixture of the average causal effect.
fn whatif_treatment() -> Array[Double] {
  let values : Array[Double] = []
  for i in 0..<WHATIF_NUM_ROWS {
    values.push((i % 2).to_double())
  }
  values
}

///|
/// The values of the given array, with their mean subtracted.
fn whatif_centered(values : Array[Double]) -> Array[Double] {
  let mean = @utils.mean(values)
  let out = values.copy()
  for i in 0..<out.length() {
    out[i] = out[i] - mean
  }
  out
}

///|
/// The inner product of two arrays.
fn whatif_dot(a : Array[Double], b : Array[Double]) -> Double {
  let mut sum = 0.0
  for i in 0..<a.length() {
    sum = sum + a[i] * b[i]
  }
  sum
}

///|
/// A noise of the fixture of the average causal effect.
///
/// The noise is drawn from the deterministic generator of the `utils` package,
/// centred, and orthogonal to the treatment and to the noise of the other
/// variables, so that the fitted mechanisms recover the coefficients of the
/// relations of the fixture.
fn whatif_ace_noise(
  rng : @utils.Random,
  scale : Double,
  against : Array[Array[Double]],
) -> Array[Double] {
  let values : Array[Double] = []
  for _ in 0..<WHATIF_NUM_ROWS {
    values.push(rng.next_normal() * scale)
  }
  let mean = @utils.mean(values)
  for i in 0..<WHATIF_NUM_ROWS {
    values[i] = values[i] - mean
  }
  for other in against {
    let factor = whatif_dot(values, other) / whatif_dot(other, other)
    for i in 0..<WHATIF_NUM_ROWS {
      values[i] = values[i] - factor * other[i]
    }
  }
  values
}

///|
/// The data of the fixture of the average causal effect with a continuous
/// target.
///
/// The fixture is the deterministic version of the fixture of the upstream
/// tests: `X0 = noise + T`, `X1 = noise + 0.5 * T` and
/// `Y = X0 + X1 + noise`.
fn whatif_ace_data() -> @api.DataFrame {
  let rng = @utils.Random::new(WHATIF_SEED)
  let treatment = whatif_treatment()
  let centered = whatif_centered(treatment)
  let first = whatif_ace_noise(rng, 0.2, [centered])
  let second = whatif_ace_noise(rng, 0.2, [centered, first])
  let third = whatif_ace_noise(rng, 0.1, [centered, first, second])
  let x0 : Array[Double] = []
  let x1 : Array[Double] = []
  let y : Array[Double] = []
  for i in 0..<WHATIF_NUM_ROWS {
    let value0 = treatment[i] + first[i]
    let value1 = 0.5 * treatment[i] + second[i]
    x0.push(value0)
    x1.push(value1)
    y.push(value0 + value1 + third[i])
  }
  @api.DataFrame::from_numeric(
    ["T", "X0", "X1", "Y"],
    Map([("T", treatment), ("X0", x0), ("X1", x1), ("Y", y)]),
  )
}

///|
/// The data of the fixture of the average causal effect with a binary target.
///
/// The target is the string of the comparison `Y = (X0 + X1 + noise) >= 1.5`,
/// which is the target of the upstream test.
fn whatif_ace_binary_data() -> @api.DataFrame {
  let rng = @utils.Random::new(WHATIF_SEED)
  let treatment = whatif_treatment()
  let centered = whatif_centered(treatment)
  let first = whatif_ace_noise(rng, 0.1, [centered])
  let second = whatif_ace_noise(rng, 0.1, [centered, first])
  let third = whatif_ace_noise(rng, 0.1, [centered, first, second])
  let x0 : Array[Double] = []
  let x1 : Array[Double] = []
  let y : Array[String] = []
  for i in 0..<WHATIF_NUM_ROWS {
    let value0 = treatment[i] + first[i]
    let value1 = 0.5 * treatment[i] + second[i]
    x0.push(value0)
    x1.push(value1)
    y.push(if value0 + value1 + third[i] >= 1.5 { "True" } else { "False" })
  }
  let columns : Map[String, @api.Column] = Map([
    ("T", @api.Column::numeric(treatment)),
    ("X0", @api.Column::numeric(x0)),
    ("X1", @api.Column::numeric(x1)),
    ("Y", @api.Column::discrete(y)),
  ])
  @api.DataFrame::new(["T", "X0", "X1", "Y"], columns)
}

///|
/// The number of the values of the array that are the given label.
fn whatif_count_of(labels : Array[String], label : String) -> Int32 {
  let mut count = 0
  for value in labels {
    if value == label {
      count = count + 1
    }
  }
  count
}

///|
/// The data of the fixture with the categorical variables.
///
/// The fixture is the deterministic version of the fixture of the upstream
/// test: `X0` is a normal variable, `X1` holds the categories "0" and "1",
/// `X2` holds the classes "True" and "False" and `X3` holds the classes
/// "False" and "True".
fn whatif_categorical_data() -> @api.DataFrame {
  let rng = @utils.Random::new(WHATIF_CATEGORICAL_SEED)
  let x0 : Array[Double] = []
  for _ in 0..<WHATIF_CATEGORICAL_ROWS {
    x0.push(rng.next_normal())
  }
  let x1 : Array[String] = []
  for _ in 0..<WHATIF_CATEGORICAL_ROWS {
    x1.push(if rng.next_int(2) == 0 { "0" } else { "1" })
  }
  let x2 : Array[String] = []
  let x3 : Array[String] = []
  for i in 0..<WHATIF_CATEGORICAL_ROWS {
    let value = if x1[i] == "0" { x0[i] + 2.0 > 0.0 } else { x0[i] - 2.0 > 0.0 }
    x2.push(if value { "True" } else { "False" })
    x3.push(if value { "False" } else { "True" })
  }
  let columns : Map[String, @api.Column] = Map([
    ("X0", @api.Column::numeric(x0)),
    ("X1", @api.Column::discrete(x1)),
    ("X2", @api.Column::discrete(x2)),
    ("X3", @api.Column::discrete(x3)),
  ])
  @api.DataFrame::new(["X0", "X1", "X2", "X3"], columns)
}

///|
/// The model of the fixture with the categorical variables, whose graph is
/// `X0 -> X2`, `X1 -> X2` and `X2 -> X3`.
fn whatif_categorical_model() -> @gcm.ProbabilisticCausalModel {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "X2")
  graph.add_edge("X1", "X2")
  graph.add_edge("X2", "X3")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  model.set_root_model("X0", @gcm.StochasticModel::empirical())
  model.set_root_model("X1", @gcm.StochasticModel::empirical_categorical())
  model.set_causal_mechanism(
    "X2",
    @gcm.CausalMechanism::classifier(@gcm.ClassificationModel::logistic()),
  )
  model.set_causal_mechanism(
    "X3",
    @gcm.CausalMechanism::classifier(@gcm.ClassificationModel::logistic()),
  )
  @gcm.fit(model, whatif_categorical_data())
  model
}

///|
/// The data of the fixture with the discrete data.
///
/// The fixture is the deterministic version of the fixture of the upstream
/// test: `X` is a normal variable, `Y` holds the values -1, 0 and 1 and `Z`
/// follows `Z = 2 * Y + noise`.
fn whatif_discrete_data() -> @api.DataFrame {
  let rng = @utils.Random::new(WHATIF_DISCRETE_SEED)
  let x : Array[Double] = []
  for _ in 0..<WHATIF_NUM_ROWS {
    x.push(rng.next_normal())
  }
  let noise : Array[Double] = []
  for _ in 0..<WHATIF_NUM_ROWS {
    noise.push(0.1 * rng.next_normal())
  }
  let y : Array[Double] = []
  let z : Array[Double] = []
  for i in 0..<WHATIF_NUM_ROWS {
    let label = if x[i] < -1.5 { -1.0 } else if x[i] <= 1.5 { 0.0 } else { 1.0 }
    y.push(label)
    z.push(2.0 * label + noise[i])
  }
  @api.DataFrame::from_numeric(
    ["X", "Y", "Z"],
    Map([("X", x), ("Y", y), ("Z", z)]),
  )
}

///|
/// The model of the fixture with the discrete data, whose graph is `X -> Y`
/// and `Y -> Z`.
fn whatif_discrete_model() -> @gcm.ProbabilisticCausalModel {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X", "Y")
  graph.add_edge("Y", "Z")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  model.set_root_model("X", @gcm.StochasticModel::empirical())
  model.set_causal_mechanism(
    "Y",
    @gcm.CausalMechanism::discrete_additive_noise(
      @gcm.PredictionModel::nearest_neighbour(k=5),
    ),
  )
  model.set_causal_mechanism(
    "Z",
    @gcm.CausalMechanism::additive_noise(@gcm.PredictionModel::linear()),
  )
  @gcm.fit(model, whatif_discrete_data())
  model
}

///|
/// The model of the fixture of the average causal effect, whose graph is
/// `T -> X0`, `T -> X1`, `X0 -> Y` and `X1 -> Y`.
fn whatif_ace_model(binary : Bool) -> @gcm.ProbabilisticCausalModel {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("T", "X0")
  graph.add_edge("T", "X1")
  graph.add_edge("X0", "Y")
  graph.add_edge("X1", "Y")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  let data = if binary { whatif_ace_binary_data() } else { whatif_ace_data() }
  let _ = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
  )
  @gcm.fit(model, data)
  model
}

///|
/// test "an atomic intervention with a specific input returns the correct sample values"
///
/// This is the port of the upstream test
/// `test_given_atomic_intervention_with_specific_input_when_draw_interventional_samples_then_return_correct_sample_values`.
test "an atomic intervention with a specific input returns the correct sample values" {
  let model = whatif_simple_model()
  let samples = @gcm.interventional_samples(
    model,
    Map([("X2", @gcm.set_number(10.0))]),
    Some(whatif_observed_row()),
    None,
    @utils.Random::new(WHATIF_SEED),
  )
  assert_eq(samples.numeric("X0")[0], 0.0)
  assert_eq(samples.numeric("X1")[0], 1.0)
  assert_eq(samples.numeric("X2")[0], 10.0)
  assert_true(whatif_near(samples.numeric("X3")[0], 5.0, 0.2))
}

///|
/// test "a conditional intervention with a specific input returns the correct sample values"
///
/// This is the port of the upstream test
/// `test_given_conditional_intervention_with_specific_input_when_draw_interventional_samples_then_return_correct_sample_values`.
test "a conditional intervention with a specific input returns the correct sample values" {
  let model = whatif_simple_model()
  let samples = @gcm.interventional_samples(
    model,
    Map([("X2", @gcm.add_number(10.0))]),
    Some(whatif_observed_row()),
    None,
    @utils.Random::new(WHATIF_SEED),
  )
  assert_eq(samples.numeric("X0")[0], 0.0)
  assert_eq(samples.numeric("X1")[0], 1.0)
  assert_true(whatif_near(samples.numeric("X2")[0], 10.0, 0.5))
  assert_true(whatif_near(samples.numeric("X3")[0], 5.0, 0.25))
}

///|
/// test "multiple atomic interventions with a specific input return the correct sample values"
///
/// This is the port of the upstream test
/// `test_given_multiple_atomic_intervention_with_specific_input_when_draw_interventional_samples_then_return_correct_sample_values`.
test "multiple atomic interventions with a specific input return the correct sample values" {
  let model = whatif_simple_model()
  let samples = @gcm.interventional_samples(
    model,
    Map([("X0", @gcm.set_number(10.0)), ("X2", @gcm.add_number(5.0))]),
    Some(whatif_observed_row()),
    None,
    @utils.Random::new(WHATIF_SEED),
  )
  assert_eq(samples.numeric("X0")[0], 10.0)
  assert_true(whatif_near(samples.numeric("X1")[0], 20.0, 0.3))
  assert_true(whatif_near(samples.numeric("X2")[0], 10.0, 0.3))
  assert_true(whatif_near(samples.numeric("X3")[0], 5.0, 0.3))
}

///|
/// test "an atomic intervention without a specific input returns the correct sample values"
///
/// This is the port of the upstream test
/// `test_given_atomic_intervention_without_specific_input_when_draw_interventional_samples_then_return_correct_sample_values`.
test "an atomic intervention without a specific input returns the correct sample values" {
  let model = whatif_simple_model()
  let samples = @gcm.interventional_samples(
    model,
    Map([("X2", @gcm.set_number(10.0))]),
    None,
    Some(10),
    @utils.Random::new(WHATIF_SEED),
  )
  let values = samples.numeric("X2")
  assert_eq(values.length(), 10)
  for value in values {
    assert_eq(value, 10.0)
  }
}

///|
/// test "a conditional intervention without a specific input returns the correct sample values"
///
/// This is the port of the upstream test
/// `test_given_conditional_intervention_without_specific_input_when_draw_interventional_samples_then_return_correct_sample_values`.
test "a conditional intervention without a specific input returns the correct sample values" {
  let model = whatif_simple_model()
  let samples = @gcm.interventional_samples(
    model,
    Map([("X2", @gcm.add_number(10.0))]),
    None,
    Some(10),
    @utils.Random::new(WHATIF_SEED),
  )
  let expected = @utils.mean(whatif_simple_data().numeric("X2")) + 10.0
  assert_true(whatif_near(@utils.mean(samples.numeric("X2")), expected, 1.0))
}

///|
/// test "the counterfactual of an observed sample has the correct sample values"
///
/// This is the port of the upstream test
/// `test_given_observed_sample_when_estimate_counterfactual_then_returns_correct_sample_values`.
test "the counterfactual of an observed sample has the correct sample values" {
  let model = whatif_simple_model()
  let observed = @api.DataFrame::from_numeric(
    ["X0", "X1", "X2", "X3"],
    Map([("X0", [1.0]), ("X1", [3.0]), ("X2", [3.0]), ("X3", [4.0])]),
  )
  let samples = @gcm.counterfactual_samples(
    model,
    Map([("X2", @gcm.set_number(2.0))]),
    Some(observed),
    None,
  )
  assert_true(whatif_near(samples.numeric("X0")[0], 1.0, 1.0e-9))
  assert_true(whatif_near(samples.numeric("X1")[0], 3.0, 1.0e-9))
  assert_eq(samples.numeric("X2")[0], 2.0)
  assert_true(whatif_near(samples.numeric("X3")[0], 3.5, 0.05))
}

///|
/// test "the counterfactual of a noise sample has the correct sample values"
///
/// This is the port of the upstream test
/// `test_given_noise_sample_when_estimate_counterfactual_then_returns_correct_sample_values`.
test "the counterfactual of a noise sample has the correct sample values" {
  let model = whatif_simple_model()
  let noise = @api.DataFrame::from_numeric(
    ["X0", "X1", "X2", "X3"],
    Map([("X0", [1.0]), ("X1", [2.0]), ("X2", [3.0]), ("X3", [4.0])]),
  )
  let samples = @gcm.counterfactual_samples(
    model,
    Map([("X2", @gcm.set_number(2.0))]),
    None,
    Some(noise),
  )
  assert_true(whatif_near(samples.numeric("X0")[0], 1.0, 1.0e-9))
  assert_true(whatif_near(samples.numeric("X1")[0], 4.0, 1.0e-9))
  assert_eq(samples.numeric("X2")[0], 2.0)
  assert_true(whatif_near(samples.numeric("X3")[0], 5.0, 0.05))
}

///|
/// test "the arguments of a what-if query are exclusive"
///
/// This is the port of the upstream tests
/// `test_when_draw_interventional_samples_without_observed_data_or_num_samples_parameter_then_raise_error`,
/// `test_when_draw_interventional_samples_with_observed_data_and_num_samples_parameter_then_raise_error`,
/// `test_when_estimate_counterfactual_without_observed_or_noise_data_then_raise_error` and
/// `test_when_estimate_counterfactual_with_observed_and_noise_data_then_raise_error`.
/// The upstream raises a `ValueError`, which MoonBit cannot catch, so the
/// check of the arguments is asserted on its own.
test "the arguments of a what-if query are exclusive" {
  assert_false(@gcm.has_valid_query_arguments(false, false))
  assert_false(@gcm.has_valid_query_arguments(true, true))
  assert_true(@gcm.has_valid_query_arguments(true, false))
  assert_true(@gcm.has_valid_query_arguments(false, true))
}

///|
/// test "the average causal effect of a continuous target is the expected result"
///
/// This is the port of the upstream test
/// `test_given_continuous_target_when_estimate_average_causal_effect_then_return_expected_result`.
test "the average causal effect of a continuous target is the expected result" {
  let model = whatif_ace_model(false)
  let effect = @gcm.average_causal_effect(
    model,
    "Y",
    Map([("T", @gcm.set_number(1.0))]),
    Map([("T", @gcm.set_number(0.0))]),
    None,
    Some(WHATIF_NUM_SAMPLES),
    @utils.Random::new(WHATIF_SEED),
  )
  assert_true(whatif_near(effect, 1.5, 0.1))
}

///|
/// test "the average causal effect of a binary target is the expected result"
///
/// This is the port of the upstream test
/// `test_given_binary_target_when_estimate_average_causal_effect_then_return_expected_result`.
test "the average causal effect of a binary target is the expected result" {
  let model = whatif_ace_model(true)
  let effect = @gcm.average_causal_effect(
    model,
    "Y",
    Map([("T", @gcm.set_number(1.0))]),
    Map([("T", @gcm.set_number(0.0))]),
    None,
    Some(WHATIF_NUM_SAMPLES),
    @utils.Random::new(WHATIF_SEED),
  )
  assert_true(whatif_near(effect, 0.5, 0.1))
}

///|
/// test "an intervention on the categorical variables returns the correct sample values"
///
/// This is the port of the upstream test
/// `test_given_categorical_variables_when_draw_interventional_samples_then_return_correct_sample_values`.
/// The upstream draws the classes of the two targets with a uniform noise, so
/// the number of the samples that hold the expected class is a random number;
/// the generator of the `utils` package is seeded, so the number is the same
/// number at every run.
test "an intervention on the categorical variables returns the correct sample values" {
  let model = whatif_categorical_model()
  let samples = @gcm.interventional_samples(
    model,
    Map([("X0", @gcm.set_number(0.0)), ("X1", @gcm.set_category("0"))]),
    None,
    Some(WHATIF_CATEGORICAL_SAMPLES),
    @utils.Random::new(WHATIF_CATEGORICAL_SEED),
  )
  for value in samples.numeric("X0") {
    assert_true(whatif_near(value, 0.0, 0.0))
  }
  for value in samples.discrete("X1") {
    assert_eq(value, "0")
  }
  assert_true(whatif_count_of(samples.discrete("X2"), "True") > 95)
  assert_true(whatif_count_of(samples.discrete("X3"), "False") > 95)
}

///|
/// test "an intervention on the discrete data returns the correct samples"
///
/// This is the port of the upstream test
/// `test_given_discrete_data_when_performing_interventions_then_returns_correct_samples`.
/// The upstream fits the histogram gradient boosting regression on the target
/// of the discrete additive noise model; the port fits the nearest neighbour
/// regression, which is the non-linear model of the port.
test "an intervention on the discrete data returns the correct samples" {
  let model = whatif_discrete_model()
  let samples = @gcm.interventional_samples(
    model,
    Map([("X", @gcm.set_number(-2.0))]),
    None,
    Some(WHATIF_NUM_SAMPLES),
    @utils.Random::new(WHATIF_DISCRETE_SEED),
  )
  for value in samples.numeric("X") {
    assert_true(whatif_near(value, -2.0, 0.0))
  }
  assert_true(whatif_near(@utils.median(samples.numeric("Y")), -1.0, 0.0))
  assert_true(whatif_near(@utils.mean(samples.numeric("Z")), -2.0, 0.05))
}
