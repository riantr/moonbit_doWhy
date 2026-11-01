///|
/// The tests of the equation parser of the `gcm` package.
///
/// The expectations are the ones of the upstream tests of
/// `dowhy.gcm.equation_parser`, which are in `tests/gcm/test_equation_parser.py`.
///
/// The fixtures are drawn with the deterministic generator of the `utils`
/// package. The upstream draws its samples with the global generator of numpy,
/// so the samples of the upstream and of the port are different numbers; the
/// relations the upstream asserts hold for every sample.

///|
/// The seed of the fixture of the equation parser.
const EQP_SEED : UInt64 = 2070UL

///|
/// The number of rows of the fixture of the equation parser.
const EQP_ROWS : Int32 = 100

///|
/// The data of the fixture of the equation parser.
///
/// The upstream draws `X0` from a normal distribution with a location of zero
/// and a scale of `0.1`, and derives the other columns from it.
fn eqp_data() -> @api.DataFrame {
  let rng = @utils.Random::new(EQP_SEED)
  let x0 : Array[Double] = []
  for _ in 0..<EQP_ROWS {
    x0.push(0.1 * rng.next_normal())
  }
  let x1 : Array[Double] = []
  let x2 : Array[Double] = []
  let x3 : Array[Double] = []
  for i in 0..<EQP_ROWS {
    x1.push(2.0 * x0[i])
    x2.push(0.5 * x0[i])
    x3.push(0.5 * x2[i])
  }
  @api.DataFrame::from_numeric(
    ["X0", "X1", "X2", "X3"],
    Map([("X0", x0), ("X1", x1), ("X2", x2), ("X3", x3)]),
  )
}

///|
/// The predictions of the mechanism of a node over the given design matrix.
fn eqp_predictions(
  model : @gcm.ProbabilisticCausalModel,
  node : String,
  x : @utils.Matrix,
) -> Array[Double] {
  let mechanism = match model.causal_mechanism(node) {
    Some(mechanism) => mechanism
    None => abort("the node " + node + " has no causal mechanism")
  }
  mechanism.prediction_model().predict(x)
}

///|
/// The equations of the chain of the fixture.
fn eqp_chain_equations() -> String {
  "X0 = norm(loc=0,scale=0.1)\n" +
  "X1 = 2*X0 + norm(loc=0, scale=0.1)\n" +
  "X2 = 0.5*X0 + norm(loc=0, scale=0.1)\n" +
  "X3 = 0.5*X2 + norm(loc=0, scale=0.1)\n"
}

///|
/// The model with the explicit mechanisms of the chain of the fixture.
fn eqp_chain_model() -> @gcm.ProbabilisticCausalModel {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "X1")
  graph.add_edge("X0", "X2")
  graph.add_edge("X2", "X3")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  model.set_root_model("X0", @gcm.StochasticModel::empirical())
  model.set_causal_mechanism(
    "X1",
    @gcm.CausalMechanism::additive_noise_with(
      @gcm.PredictionModel::with_fixed_parameters([2.0], 0.0),
      @gcm.StochasticModel::normal(0.0, 0.1),
    ),
  )
  model.set_causal_mechanism(
    "X2",
    @gcm.CausalMechanism::additive_noise_with(
      @gcm.PredictionModel::with_fixed_parameters([0.5], 0.0),
      @gcm.StochasticModel::normal(0.0, 0.1),
    ),
  )
  model.set_causal_mechanism(
    "X3",
    @gcm.CausalMechanism::additive_noise_with(
      @gcm.PredictionModel::with_fixed_parameters([0.5], 0.0),
      @gcm.StochasticModel::normal(0.0, 0.1),
    ),
  )
  model
}

///|
test "the equation parser fits the same function as the explicit mechanisms" {
  let data = eqp_data()
  let model = eqp_chain_model()
  @gcm.fit(model, data)
  let from_equations = @gcm.create_causal_model_from_equations(
    eqp_chain_equations(),
  )
  @gcm.fit(from_equations, data)
  let x = @utils.Matrix::from_columns([data.numeric("X0")])
  let explicit = eqp_predictions(model, "X1", x)
  let parsed = eqp_predictions(from_equations, "X1", x)
  assert_eq(explicit.length(), parsed.length())
  for i in 0..<explicit.length() {
    assert_true((explicit[i] - parsed[i]).abs() <= 0.000000000001)
  }
  // The explicit model predicts twice the value of the parent.
  for i in 0..<explicit.length() {
    assert_true(
      (explicit[i] - 2.0 * data.numeric("X0")[i]).abs() <= 0.000000000001,
    )
  }
}

///|
test "the variables of the custom function are sorted alphabetically" {
  let model = @gcm.create_causal_model_from_equations(
    "A = norm(loc=0,scale=0.1)\n" +
    "B = norm(loc=0, scale=0.1)\n" +
    "Y = 0.5*B + 2*A+ norm(loc=0, scale=0.1)\n",
  )
  let rng = @utils.Random::new(EQP_SEED)
  let a : Array[Double] = []
  let b : Array[Double] = []
  for _ in 0..<EQP_ROWS {
    a.push(0.1 * rng.next_normal())
    b.push(0.1 * rng.next_normal())
  }
  let data = @api.DataFrame::from_numeric(
    ["A", "B", "Y"],
    Map([("A", a), ("B", b), ("Y", [])]),
  )
  // The columns of the design matrix are the parents in the sorted order.
  let x = @utils.Matrix::from_columns([data.numeric("A"), data.numeric("B")])
  let predictions = eqp_predictions(model, "Y", x)
  assert_eq(predictions.length(), EQP_ROWS)
  for i in 0..<predictions.length() {
    assert_true(
      (predictions[i] - (0.5 * b[i] + 2.0 * a[i])).abs() <= 0.000000000001,
    )
  }
  // The graph holds the same parents.
  let parents = model.graph.ordered_predecessors("Y")
  assert_eq(parents.length(), 2)
  assert_eq(parents[0], "A")
  assert_eq(parents[1], "B")
}

///|
test "the causal model of an unknown relation is undefined" {
  let model = @gcm.create_causal_model_from_equations(
    "A = norm(loc=0,scale=0.1)\n" +
    "B = norm(loc=0, scale=0.1)\n" +
    "Y = 0.5*B + 2*A+ norm(loc=0, scale=0.1)\n" +
    "Z->Y,A\n",
  )
  assert_true(model.graph.has_node("Z"))
  // The node with the unknown relation has no causal mechanism.
  assert_true(model.causal_mechanism("Z") is None)
  // Its parents are the ones of the equation.
  let parents = model.graph.ordered_predecessors("Z")
  assert_eq(parents.length(), 2)
  assert_eq(parents[0], "A")
  assert_eq(parents[1], "Y")
}

///|
test "the nodes of a model of equations are correctly identified" {
  let model = @gcm.create_causal_model_from_equations(
    "A = norm(loc=0,scale=0.1)\n" +
    "B = norm(loc=0, scale=0.1)\n" +
    "Y = 0.5*B + 2*A+ norm(loc=0, scale=0.1)\n" +
    "Z->Y,A\n" +
    "C = exp(A) + 5 * Z + parametric()\n",
  )
  let nodes = model.graph.node_list()
  assert_eq(nodes.length(), 5)
  for node in ["A", "B", "C", "Z", "Y"] {
    assert_true(model.graph.has_node(node))
  }
  // The node `C` has parents, so its mechanism is a conditional one.
  let mechanism = match model.causal_mechanism("C") {
    Some(mechanism) => mechanism
    None => abort("the node C has no causal mechanism")
  }
  match mechanism.kind() {
    @gcm.CausalMechanismKind::AdditiveNoise => ()
    _ => abort("the mechanism of the node C is not an additive noise model")
  } // The parents of `C` are the ones of the custom function, and the name of
  // the function is not one of them.
  let parents = model.graph.ordered_predecessors("C")
  assert_eq(parents.length(), 2)
  assert_eq(parents[0], "A")
  assert_eq(parents[1], "Z")
}

///|
test "the custom function of an equation evaluates its expression" {
  let model = @gcm.create_causal_model_from_equations(
    "A = norm(loc=0,scale=0.1)\n" +
    "B = norm(loc=0, scale=0.1)\n" +
    "Y = 0.5*B + 2*A+ norm(loc=0, scale=0.1)\n",
  )
  let x = @utils.Matrix::from_columns([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]])
  let predictions = eqp_predictions(model, "Y", x)
  assert_eq(predictions.length(), 3)
  // The expression is `0.5 * B + 2 * A`.
  assert_true(
    (predictions[0] - (0.5 * 4.0 + 2.0 * 1.0)).abs() <= 0.000000000001,
  )
  assert_true(
    (predictions[1] - (0.5 * 5.0 + 2.0 * 2.0)).abs() <= 0.000000000001,
  )
  assert_true(
    (predictions[2] - (0.5 * 6.0 + 2.0 * 3.0)).abs() <= 0.000000000001,
  )
}
