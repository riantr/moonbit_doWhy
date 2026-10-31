/// Tests for the structural causal model layer of the graphical causal model
/// package.
///
/// The tests of the package itself live inside it. These ones check that the
/// layer is usable from the outside, the way a consumer of the published
/// package uses it, and that the numbers it produces are the ones the upstream
/// produces. The expectations are the ones of the upstream tests of
/// `tests/gcm/test_fcms.py`, computed by `_verify/gcm_scm_reference.py`.

///|
/// The seed of the fixtures.
const SCM_SEED : UInt64 = 20240UL

///|
/// The columns of a data frame, keyed by their name.
fn scm_columns(
  entries : Array[(String, @api.Column)],
) -> Map[String, @api.Column] {
  Map(entries)
}

///|
/// The linear fixture of the upstream test of the additive noise model.
///
/// The upstream draws `X0` from the normal distribution and adds a normal
/// noise; the port uses a fixed pattern, so that the numbers of the test do
/// not depend on a seed. The noise has a mean of zero and a spread of 0.1, and
/// it does not lean to one side of the relation, so the fit recovers the
/// coefficients of the relation.
fn scm_linear_frame() -> @api.DataFrame {
  let bases = [-2.0, -1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5, 2.0, 2.5]
  let noise = [0.1, -0.1, 0.1, -0.1, 0.1, -0.1, 0.1, -0.1, 0.1, -0.1]
  let targets : Array[Double] = []
  for i = 0; i < bases.length(); i = i + 1 {
    targets.push(2.0 * bases[i] + 2.0 + noise[i])
  }
  @api.DataFrame::new(
    ["X0", "X1"],
    scm_columns([
      ("X0", @api.Column::numeric(bases)),
      ("X1", @api.Column::numeric(targets)),
    ]),
  )
}

///|
/// The categorical fixture of the upstream test of the additive noise model.
///
/// The upstream draws `X0` from the normal distribution and the categories of
/// `X1` uniformly; the port uses a fixed pattern. The relation of the target
/// is the one of the upstream: `X2 = 2 * X0 + offset(X1)`, where the offset of
/// the category "0" is -5, the one of the category "1" is 10 and the one of
/// the category "2" is 5.
fn scm_categorical_frame() -> @api.DataFrame {
  let bases = [-1.5, -0.5, 0.5, 1.5, -1.0, 0.0, 1.0, -0.25, 0.75]
  let categories = ["0", "1", "2", "0", "1", "2", "0", "1", "2"]
  let offsets = [-5.0, 10.0, 5.0, -5.0, 10.0, 5.0, -5.0, 10.0, 5.0]
  let targets : Array[Double] = []
  for i = 0; i < bases.length(); i = i + 1 {
    targets.push(2.0 * bases[i] + offsets[i])
  }
  @api.DataFrame::new(
    ["X0", "X1", "X2"],
    scm_columns([
      ("X0", @api.Column::numeric(bases)),
      ("X1", @api.Column::discrete(categories)),
      ("X2", @api.Column::numeric(targets)),
    ]),
  )
}

///|
/// The graph of the linear fixture: `X0 -> X1`.
fn scm_linear_graph() -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  graph.add_node("X0")
  graph.add_node("X1")
  graph.add_edge("X0", "X1")
  graph
}

///|
/// The graph of the categorical fixture: `X0 -> X2` and `X1 -> X2`.
fn scm_categorical_graph() -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  graph.add_node("X0")
  graph.add_node("X1")
  graph.add_node("X2")
  graph.add_edge("X0", "X2")
  graph.add_edge("X1", "X2")
  graph
}

///|
/// The mechanism of a node of a model.
fn scm_mechanism(
  model : @gcm.ProbabilisticCausalModel,
  node : String,
) -> @gcm.CausalMechanism {
  match model.causal_mechanism(node) {
    Some(mechanism) => mechanism
    None => abort("the node " + node + " has no causal mechanism")
  }
}

///|
/// Whether two numbers are close to each other.
fn scm_near(a : Double, b : Double, tolerance : Double) -> Bool {
  (a - b).abs() <= tolerance
}

///|
/// test "the fit of a causal model learns the coefficients of a linear relation"
///
/// This is the port of the upstream test
/// `test_given_linear_data_when_fit_causal_graph_with_linear_anm_then_learns_correct_coefficients`.
/// The upstream gets the coefficient `2.0014` and the intercept `1.9967` on
/// its random data; the port gets the exact values on its fixed one.
test "the fit of a causal model learns the coefficients of a linear relation" {
  let model = @gcm.ProbabilisticCausalModel::new(scm_linear_graph())
  model.set_root_model("X0", @gcm.StochasticModel::normal(0.0, 1.0))
  model.set_causal_mechanism(
    "X1",
    @gcm.CausalMechanism::additive_noise(@gcm.PredictionModel::linear()),
  )
  @gcm.fit(model, scm_linear_frame())
  let mechanism = scm_mechanism(model, "X1")
  let coefficients = mechanism.prediction_model().coefficients()
  assert_eq(coefficients.length(), 1)
  assert_true(scm_near(coefficients[0], 2.0, 0.02))
  assert_true(scm_near(mechanism.prediction_model().intercept(), 2.0, 0.02))
}

///|
/// test "the fit of a causal model learns the coefficients of a relation with a categorical parent"
///
/// This is the port of the upstream test
/// `test_given_categorical_input_data_when_fit_causal_graph_with_linear_anm_then_learns_correct_coefficients`.
/// The upstream gets the coefficients `[2, -8.333333333333321, 6.666666666666658,
/// 1.6666666666666594]` and the intercept `3.333333333333334`; the port gets
/// the same numbers to within the rounding of the computation.
test "the fit of a causal model learns the coefficients of a relation with a categorical parent" {
  let model = @gcm.ProbabilisticCausalModel::new(scm_categorical_graph())
  model.set_root_model("X0", @gcm.StochasticModel::normal(0.0, 1.0))
  model.set_root_model("X1", @gcm.StochasticModel::empirical_categorical())
  model.set_causal_mechanism(
    "X2",
    @gcm.CausalMechanism::additive_noise(@gcm.PredictionModel::linear()),
  )
  @gcm.fit(model, scm_categorical_frame())
  let mechanism = scm_mechanism(model, "X2")
  let coefficients = mechanism.prediction_model().coefficients()
  assert_eq(coefficients.length(), 4)
  assert_true(scm_near(coefficients[0], 2.0, 1.0e-9))
  assert_true(scm_near(coefficients[1], -25.0 / 3.0, 1.0e-9))
  assert_true(scm_near(coefficients[2], 20.0 / 3.0, 1.0e-9))
  assert_true(scm_near(coefficients[3], 5.0 / 3.0, 1.0e-9))
  assert_true(
    scm_near(mechanism.prediction_model().intercept(), 10.0 / 3.0, 1.0e-9),
  )
}

///|
/// test "the mechanism of a causal model evaluates the target of a categorical parent"
///
/// This is the port of the upstream test
/// `test_given_categorical_input_data_when_draw_from_fitted_causal_graph_with_linear_anm_then_generates_correct_marginal_distribution`,
/// which gets `14` for the parent row `X0 = 2`, `X1 = "1"` and the noise `0`.
test "the mechanism of a causal model evaluates the target of a categorical parent" {
  let model = @gcm.ProbabilisticCausalModel::new(scm_categorical_graph())
  model.set_root_model("X0", @gcm.StochasticModel::normal(0.0, 1.0))
  model.set_root_model("X1", @gcm.StochasticModel::empirical_categorical())
  model.set_causal_mechanism(
    "X2",
    @gcm.CausalMechanism::additive_noise(@gcm.PredictionModel::linear()),
  )
  @gcm.fit(model, scm_categorical_frame())
  let mechanism = scm_mechanism(model, "X2")
  // The row is the value of `X0` and then the indicator of every category of
  // `X1` in lexicographic order.
  let evaluated = mechanism.evaluate(
    @utils.Matrix::from_columns([[2.0], [0.0], [1.0], [0.0]]),
    [0.0],
  )
  assert_true(scm_near(evaluated[0], 14.0, 1.0e-9))
}

///|
/// A design matrix with one column of the given value, one row per sample.
fn scm_constant_column(value : Double, count : Int32) -> @utils.Matrix {
  let column : Array[Double] = []
  for _ in 0..<count {
    column.push(value)
  }
  @utils.Matrix::from_columns([column])
}

///|
/// test "the samples drawn from a fitted causal model follow the relation"
///
/// This is the port of the upstream test
/// `test_given_linear_data_when_draw_samples_from_fitted_anm_then_generates_correct_marginal_distribution`,
/// which gets a mean of `4` and a spread of `0.1` for the parent `1` and a
/// mean of `6` and a spread of `0.1` for the parent `2`.
test "the samples drawn from a fitted causal model follow the relation" {
  let model = @gcm.ProbabilisticCausalModel::new(scm_linear_graph())
  model.set_root_model("X0", @gcm.StochasticModel::normal(0.0, 1.0))
  model.set_causal_mechanism(
    "X1",
    @gcm.CausalMechanism::additive_noise(@gcm.PredictionModel::linear()),
  )
  @gcm.fit(model, scm_linear_frame())
  let mechanism = scm_mechanism(model, "X1")
  let rng = @utils.Random::new(SCM_SEED)
  let at_one = mechanism.draw_samples(scm_constant_column(1.0, 1000), rng)
  assert_true(scm_near(@utils.mean(at_one), 4.0, 0.05))
  assert_true(scm_near(@utils.std(at_one), 0.1, 0.05))
  let at_two = mechanism.draw_samples(scm_constant_column(2.0, 1000), rng)
  assert_true(scm_near(@utils.mean(at_two), 6.0, 0.05))
  assert_true(scm_near(@utils.std(at_two), 0.1, 0.05))
}

///|
/// test "the samples of a causal model hold a column for every node"
test "the samples of a causal model hold a column for every node" {
  let model = @gcm.ProbabilisticCausalModel::new(scm_categorical_graph())
  model.set_root_model("X0", @gcm.StochasticModel::normal(0.0, 1.0))
  model.set_root_model("X1", @gcm.StochasticModel::empirical_categorical())
  model.set_causal_mechanism(
    "X2",
    @gcm.CausalMechanism::additive_noise(@gcm.PredictionModel::linear()),
  )
  @gcm.fit(model, scm_categorical_frame())
  let samples = @gcm.draw_samples(model, 50, @utils.Random::new(SCM_SEED))
  assert_eq(samples.nrows(), 50)
  assert_eq(samples.column_names().length(), 3)
  assert_true(samples.has_column("X0"))
  assert_true(samples.has_column("X1"))
  assert_true(samples.has_column("X2"))
  // The categories of the discrete root node are the ones it was fitted on.
  let categories = samples.discrete("X1")
  assert_eq(categories.length(), 50)
  for value in categories {
    assert_true(value == "0" || value == "1" || value == "2")
  }
}

///|
/// test "the automatic assignment picks the mechanism of every node of a model"
///
/// This is the port of the upstream test of the automatic assignment, which
/// gives an empirical distribution to a root node, the additive noise model to
/// a node with a continuous target and the classifier to a node with a
/// categorical one.
test "the automatic assignment picks the mechanism of every node of a model" {
  let model = @gcm.ProbabilisticCausalModel::new(scm_categorical_graph())
  let summary = @gcm.assign_causal_mechanisms(
    model,
    scm_categorical_frame(),
    @gcm.AssignmentQuality::good(),
    false,
  )
  assert_true(summary.messages().length() >= 3)
  assert_true(@gcm.has_valid_causal_model(model))
  // The root nodes get a distribution, the node with parents gets the
  // additive noise model of its continuous target.
  assert_true(model.root_model("X0") is Some(_))
  assert_true(model.root_model("X1") is Some(_))
  assert_true(
    @gcm.is_discrete_additive_noise_kind(scm_mechanism(model, "X2").kind()) ==
    false,
  )
}

///|
/// test "the automatic assignment gives a classifier to a node with a categorical target"
test "the automatic assignment gives a classifier to a node with a categorical target" {
  let frame = @api.DataFrame::new(
    ["X0", "X1"],
    scm_columns([
      ("X0", @api.Column::numeric([-1.5, -0.5, 0.5, 1.5])),
      ("X1", @api.Column::discrete(["a", "a", "b", "b"])),
    ]),
  )
  let graph = @graph.DirectedGraph::new()
  graph.add_node("X0")
  graph.add_node("X1")
  graph.add_edge("X0", "X1")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  let _ = @gcm.assign_causal_mechanisms(
    model,
    frame,
    @gcm.AssignmentQuality::good(),
    false,
  )
  assert_true(@gcm.is_classifier_kind(scm_mechanism(model, "X1").kind()))
}
