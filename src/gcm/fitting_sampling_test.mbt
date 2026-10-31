///|
/// The tests of the fitting and the sampling of the graphical causal models.
///
/// The expectations are the ones of the upstream tests of
/// `dowhy.gcm.fitting_sampling`, which are in `tests/gcm/test_fcms.py`. The
/// fixtures are deterministic: the numeric parent takes the values of a fixed
/// symmetric pattern and the noise takes the values of a fixed pattern, so
/// that the fit of the linear relation is exact and the tests do not depend on
/// any random draw. The only randomness of the tests comes from the
/// deterministic generator of the `utils` package.

///|
/// The number of rows of the fixtures.
const FITTING_NUM_ROWS : Int32 = 240

///|
/// The number of samples drawn from a fitted model.
const FITTING_NUM_SAMPLES : Int32 = 1000

///|
/// The seed of the generator of the tests.
const FITTING_SEED : UInt64 = 20240UL

///|
/// Whether two numbers are close to each other.
fn fitting_near(a : Double, b : Double, tolerance : Double) -> Bool {
  (a - b).abs() <= tolerance
}

///|
/// The values of the numeric parent of the fixtures.
///
/// The pattern is symmetric, so its mean is zero and the fit of the linear
/// relation recovers the coefficients of the relation exactly.
fn fitting_base_values() -> Array[Double] {
  [-3.5, -2.5, -1.5, -0.5, 0.5, 1.5, 2.5, 3.5]
}

///|
/// The noise of the linear fixture.
///
/// The pattern has a mean of zero and a spread of 0.1, and it does not lean to
/// one side of the linear relation.
fn fitting_base_noise() -> Array[Double] {
  [0.1, -0.1, 0.1, -0.1, -0.1, 0.1, -0.1, 0.1]
}

///|
/// An array of the given number of copies of the value.
fn fitting_repeated(value : Double, count : Int32) -> Array[Double] {
  let out : Array[Double] = []
  for _ in 0..<count {
    out.push(value)
  }
  out
}

///|
/// The data of the linear fixture, which follows `X1 = 2 * X0 + 2 + noise`.
fn fitting_linear_data() -> @api.DataFrame {
  let base = fitting_base_values()
  let noise = fitting_base_noise()
  let x0 : Array[Double] = []
  let x1 : Array[Double] = []
  for i in 0..<FITTING_NUM_ROWS {
    let value = base[i % 8]
    x0.push(value)
    x1.push(2.0 * value + 2.0 + noise[i % 8])
  }
  @api.DataFrame::from_numeric(["X0", "X1"], Map([("X0", x0), ("X1", x1)]))
}

///|
/// The data of the fixture with a categorical parent.
///
/// The target follows `X2 = 2 * X0 + offset`, where the offset of the category
/// is -5 for "0", 10 for "1" and 5 for "2". The three categories are equally
/// often in the data, like the categories of the upstream fixture.
fn fitting_categorical_data() -> @api.DataFrame {
  let base = fitting_base_values()
  let categories = ["0", "1", "2"]
  let offsets = [-5.0, 10.0, 5.0]
  let x0 : Array[Double] = []
  let x1 : Array[String] = []
  let x2 : Array[Double] = []
  for i in 0..<FITTING_NUM_ROWS {
    let value = base[i % 8]
    let category = i % 3
    x0.push(value)
    x1.push(categories[category])
    x2.push(2.0 * value + offsets[category])
  }
  let columns : Map[String, @api.Column] = Map([
    ("X0", @api.Column::numeric(x0)),
    ("X1", @api.Column::discrete(x1)),
    ("X2", @api.Column::numeric(x2)),
  ])
  @api.DataFrame::new(["X0", "X1", "X2"], columns)
}

///|
/// The model of the linear fixture, whose graph is `X0 -> X1`.
fn fitting_linear_model() -> @gcm.ProbabilisticCausalModel {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "X1")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  model.set_root_model("X0", @gcm.StochasticModel::normal(0.0, 1.0))
  model.set_causal_mechanism(
    "X1",
    @gcm.CausalMechanism::additive_noise(@gcm.PredictionModel::linear()),
  )
  model
}

///|
/// The model of the fixture with a categorical parent, whose graph is
/// `X0 -> X2` and `X1 -> X2`.
fn fitting_categorical_model() -> @gcm.ProbabilisticCausalModel {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "X2")
  graph.add_edge("X1", "X2")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  model.set_root_model("X0", @gcm.StochasticModel::normal(0.0, 1.0))
  model.set_root_model("X1", @gcm.StochasticModel::empirical_categorical())
  model.set_causal_mechanism(
    "X2",
    @gcm.CausalMechanism::additive_noise(@gcm.PredictionModel::linear()),
  )
  model
}

///|
/// The design matrix of the parents of a node, with a single row.
fn fitting_single_row(
  encoder : @gcm.ParentEncoder,
  parents : Array[String],
  values : Map[String, @api.Column],
) -> @utils.Matrix {
  let frame = @api.DataFrame::new(parents, values)
  encoder.design_matrix(frame, parents)
}

///|
/// The mechanism of a node of a model, when it has one.
fn fitting_mechanism(
  model : @gcm.ProbabilisticCausalModel,
  node : String,
) -> @gcm.CausalMechanism {
  match model.causal_mechanism(node) {
    Some(mechanism) => mechanism
    None => abort("the node " + node + " has no causal mechanism")
  }
}

///|
/// The encoder of a node of a model, when it has one.
fn fitting_encoder(
  model : @gcm.ProbabilisticCausalModel,
  node : String,
) -> @gcm.ParentEncoder {
  match model.encoder_of(node) {
    Some(encoder) => encoder
    None => abort("the node " + node + " has no encoder")
  }
}

///|
/// test "the fit of a linear model learns the coefficients of the relation"
///
/// This is the port of the upstream test
/// `test_given_linear_data_when_fit_causal_graph_with_linear_anm_then_learns_correct_coefficients`.
test "the fit of a linear model learns the coefficients of the relation" {
  let model = fitting_linear_model()
  @gcm.fit(model, fitting_linear_data())
  let mechanism = fitting_mechanism(model, "X1")
  let coefficients = mechanism.prediction_model().coefficients()
  assert_eq(coefficients.length(), 1)
  assert_true(fitting_near(coefficients[0], 2.0, 0.02))
  assert_true(fitting_near(mechanism.prediction_model().intercept(), 2.0, 0.02))
}

///|
/// test "the fit of a model with a categorical parent learns the coefficients of the relation"
///
/// This is the port of the upstream test
/// `test_given_categorical_input_data_when_fit_causal_graph_with_linear_anm_then_learns_correct_coefficients`.
///
/// The design of the node is rank deficient, because the intercept is the sum
/// of the three indicator columns of the categories. The upstream fits it with
/// the centred least squares of scikit-learn, which gives the sum-to-zero
/// parameterisation of the indicators, namely the coefficients
/// `[2, -5 - 10/3, 10 - 10/3, 5 - 10/3]` and the intercept `10/3`. The port
/// centres the design the same way, so it gets the very same numbers.
test "the fit of a model with a categorical parent learns the coefficients of the relation" {
  let model = fitting_categorical_model()
  @gcm.fit(model, fitting_categorical_data())
  let mechanism = fitting_mechanism(model, "X2")
  let intercept = mechanism.prediction_model().intercept()
  let coefficients = mechanism.prediction_model().coefficients()
  assert_eq(coefficients.length(), 4)
  assert_true(fitting_near(coefficients[0], 2.0, 0.02))
  assert_true(fitting_near(coefficients[1], -5.0 - 10.0 / 3.0, 0.02))
  assert_true(fitting_near(coefficients[2], 10.0 - 10.0 / 3.0, 0.02))
  assert_true(fitting_near(coefficients[3], 5.0 - 10.0 / 3.0, 0.02))
  assert_true(fitting_near(intercept, 10.0 / 3.0, 0.02))
  // The intercept and the indicator of a category add up to the offset of the
  // category, which is what the mechanism of the upstream reproduces as well.
  assert_true(fitting_near(intercept + coefficients[1], -5.0, 0.02))
  assert_true(fitting_near(intercept + coefficients[2], 10.0, 0.02))
  assert_true(fitting_near(intercept + coefficients[3], 5.0, 0.02))
}

///|
/// test "the fit of a model with a categorical parent reproduces the target of every row"
///
/// This is the second assertion of the upstream test
/// `test_given_categorical_input_data_when_draw_from_fitted_causal_graph_with_linear_anm_then_generates_correct_marginal_distribution`:
/// the mechanism of the node reproduces the target of every row of the
/// training data when the noise is zero.
test "the fit of a model with a categorical parent reproduces the target of every row" {
  let data = fitting_categorical_data()
  let model = fitting_categorical_model()
  @gcm.fit(model, data)
  let mechanism = fitting_mechanism(model, "X2")
  let encoder = fitting_encoder(model, "X2")
  let x = encoder.design_matrix(data, ["X0", "X1"])
  let noise : Array[Double] = []
  for _ in 0..<FITTING_NUM_ROWS {
    noise.push(0.0)
  }
  let evaluated = mechanism.evaluate(x, noise)
  let target = data.numeric("X2")
  for i = 0; i < FITTING_NUM_ROWS; i = i + 1 {
    assert_true(fitting_near(evaluated[i], target[i], 0.02))
  }
}

///|
/// test "the mechanism of a model with a categorical parent evaluates the target of a parent row"
///
/// This is the first assertion of the upstream test
/// `test_given_categorical_input_data_when_draw_from_fitted_causal_graph_with_linear_anm_then_generates_correct_marginal_distribution`:
/// the mechanism of the node evaluates the target of the parent row
/// `X0 = 2` and `X1 = "1"` with a noise of zero to 14.
test "the mechanism of a model with a categorical parent evaluates the target of a parent row" {
  let data = fitting_categorical_data()
  let model = fitting_categorical_model()
  @gcm.fit(model, data)
  let mechanism = fitting_mechanism(model, "X2")
  let encoder = fitting_encoder(model, "X2")
  // The row of the parent `X0 = 2` and the category `X1 = "1"` is the row
  // `[2, 0, 1, 0]`, which is the value of the numeric parent followed by the
  // indicator of every category of the discrete parent.
  let x = fitting_single_row(
    encoder,
    ["X0", "X1"],
    Map([
      ("X0", @api.Column::numeric([2.0])),
      ("X1", @api.Column::discrete(["1"])),
    ]),
  )
  assert_eq(x.nrows(), 1)
  assert_eq(x.ncols(), 4)
  assert_true(fitting_near(x.get(0, 0), 2.0, 1.0e-12))
  assert_true(fitting_near(x.get(0, 1), 0.0, 1.0e-12))
  assert_true(fitting_near(x.get(0, 2), 1.0, 1.0e-12))
  assert_true(fitting_near(x.get(0, 3), 0.0, 1.0e-12))
  let evaluated = mechanism.evaluate(x, [0.0])
  assert_true(fitting_near(evaluated[0], 14.0, 0.02))
}

///|
/// test "the samples of a fitted mechanism of a fixed parent have the mean and the spread of the relation"
///
/// This is the port of the upstream test
/// `test_given_linear_data_when_draw_samples_from_fitted_anm_then_generates_correct_marginal_distribution`.
test "the samples of a fitted mechanism of a fixed parent have the mean and the spread of the relation" {
  let model = fitting_linear_model()
  @gcm.fit(model, fitting_linear_data())
  let mechanism = fitting_mechanism(model, "X1")
  let rng = @utils.Random::new(FITTING_SEED)
  let with_one = mechanism.draw_samples(
    @utils.Matrix::from_columns([fitting_repeated(1.0, 1000)]),
    rng,
  )
  assert_eq(with_one.length(), 1000)
  assert_true(fitting_near(@utils.mean(with_one), 4.0, 0.05))
  assert_true(fitting_near(@utils.std(with_one), 0.1, 0.05))
  let with_two = mechanism.draw_samples(
    @utils.Matrix::from_columns([fitting_repeated(2.0, 1000)]),
    rng,
  )
  assert_eq(with_two.length(), 1000)
  assert_true(fitting_near(@utils.mean(with_two), 6.0, 0.05))
  assert_true(fitting_near(@utils.std(with_two), 0.1, 0.05))
}

///|
/// test "the samples of the whole model have a row per sample and a column per node"
test "the samples of the whole model have a row per sample and a column per node" {
  let model = fitting_linear_model()
  @gcm.fit(model, fitting_linear_data())
  let rng = @utils.Random::new(FITTING_SEED)
  let samples = @gcm.draw_samples(model, FITTING_NUM_SAMPLES, rng)
  assert_eq(samples.nrows(), FITTING_NUM_SAMPLES)
  assert_eq(samples.column_names().length(), 2)
  assert_eq(samples.column_names()[0], "X0")
  assert_eq(samples.column_names()[1], "X1")
  assert_eq(samples.numeric("X0").length(), FITTING_NUM_SAMPLES)
  assert_eq(samples.numeric("X1").length(), FITTING_NUM_SAMPLES)
  // The samples of the child follow the relation of the model, so the noise
  // of every sample is one of the residuals of the fit.
  let noise = fitting_base_noise()
  let parents = samples.numeric("X0")
  let children = samples.numeric("X1")
  for i = 0; i < FITTING_NUM_SAMPLES; i = i + 1 {
    let residual = children[i] - (2.0 * parents[i] + 2.0)
    let mut found = false
    for value in noise {
      if fitting_near(residual, value, 1.0e-9) {
        found = true
      }
    }
    assert_true(found)
  }
}

///|
/// test "the samples of a root node follow the distribution it was fitted on"
test "the samples of a root node follow the distribution it was fitted on" {
  let model = fitting_categorical_model()
  let data = fitting_categorical_data()
  @gcm.fit(model, data)
  let rng = @utils.Random::new(FITTING_SEED)
  let samples = @gcm.draw_samples(model, FITTING_NUM_SAMPLES, rng)
  assert_eq(samples.nrows(), FITTING_NUM_SAMPLES)
  assert_eq(samples.column_names().length(), 3)
  // The root node with the categorical distribution draws one of the
  // categories it was fitted on.
  let categories = data.discrete("X1")
  let drawn = samples.discrete("X1")
  assert_eq(drawn.length(), FITTING_NUM_SAMPLES)
  for value in drawn {
    assert_true(categories.contains(value))
  }
  // The root node with the normal distribution keeps the parameters it was
  // given, so its samples follow the normal distribution of mean zero and
  // spread one.
  let values = samples.numeric("X0")
  assert_eq(values.length(), FITTING_NUM_SAMPLES)
  assert_true(fitting_near(@utils.mean(values), 0.0, 0.15))
  assert_true(fitting_near(@utils.std(values), 1.0, 0.15))
}

///|
/// test "the fit records the parents of every node"
test "the fit records the parents of every node" {
  let model = fitting_categorical_model()
  @gcm.fit(model, fitting_categorical_data())
  for node in model.nodes() {
    assert_true(@gcm.has_valid_local_structure(model, node))
  }
  let parents = match model.parents_during_fit("X2") {
    Some(parents) => parents
    None => abort("the node X2 has no parents during the fit")
  }
  assert_eq(parents.length(), 2)
  assert_true(parents.contains("X0"))
  assert_true(parents.contains("X1"))
  let root_parents = match model.parents_during_fit("X0") {
    Some(parents) => parents
    None => abort("the node X0 has no parents during the fit")
  }
  assert_eq(root_parents.length(), 0)
}

///|
/// test "a second fit of the same model replaces the mechanisms"
test "a second fit of the same model replaces the mechanisms" {
  let model = fitting_linear_model()
  let data = fitting_linear_data()
  @gcm.fit(model, data)
  let mechanism = fitting_mechanism(model, "X1")
  let coefficients = mechanism.prediction_model().coefficients()
  let noise = mechanism.noise_model().samples()
  @gcm.fit(model, data)
  let refitted = fitting_mechanism(model, "X1")
  let refitted_coefficients = refitted.prediction_model().coefficients()
  assert_eq(refitted_coefficients.length(), coefficients.length())
  assert_true(fitting_near(refitted_coefficients[0], 2.0, 0.02))
  assert_true(fitting_near(refitted.prediction_model().intercept(), 2.0, 0.02))
  assert_eq(refitted.noise_model().samples().length(), noise.length())
  assert_true(@gcm.has_valid_local_structure(model, "X1"))
}

///|
/// test "the data of every node of the model is complete"
test "the data of every node of the model is complete" {
  let model = fitting_categorical_model()
  let data = fitting_categorical_data()
  assert_true(@gcm.has_data_for_every_node(model, data))
  let incomplete = data.select(["X0", "X2"])
  assert_false(@gcm.has_data_for_every_node(model, incomplete))
}
