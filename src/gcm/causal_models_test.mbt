///|
/// The tests of the model pieces of the graphical causal model package.
///
/// The cases mirror the upstream test file `tests/gcm/test_graph.py`: the
/// samples of a probabilistic causal model have the mean and the standard
/// deviation of the data it was fitted on, the mechanism of the model can be
/// read back, and a node is a root exactly when it has no parents.
///
/// The upstream test `test_when_trying_to_set_causal_mechanism_of_non_existing_node_then_raises_error`
/// asks for a `ValueError` when a mechanism is assigned to a node that is not
/// in the graph. MoonBit has no exception, so the port aborts with a message
/// and the test asserts the predicate that reports the same situation:
/// `has_valid_causal_model_assignment` is false for such a node.
///
/// The upstream marks its sampling test as flaky, because it draws its rows
/// with the global generator of numpy and the means of a thousand samples move
/// with the draw. The port draws its rows with the generator of the `utils`
/// package and asserts the same tolerances, which is the behaviour the upstream
/// test asserts.

///|
/// The number of rows of the fixture.
const MODEL_NUM_ROWS : Int32 = 1000

///|
/// The number of samples drawn from the fitted model.
const MODEL_NUM_SAMPLES : Int32 = 1000

///|
/// The seed of the fixture.
const MODEL_SEED : UInt64 = 2026UL

///|
/// The data of the fixture, whose columns are the ones of the upstream test.
///
/// `X0` is uniform on `[-1, 1]`, `X1` is twice `X0`, `X2` is half of `X0` and
/// `X3` is half of `X2`, every one of the three with a Gaussian noise of the
/// standard deviation of a tenth.
fn model_data() -> @api.DataFrame {
  let rng = @utils.Random::new(MODEL_SEED)
  let x0 : Array[Double] = []
  for i = 0; i < MODEL_NUM_ROWS; i = i + 1 {
    x0.push(2.0 * rng.next_double() - 1.0)
  }
  let x1 : Array[Double] = []
  let x2 : Array[Double] = []
  let x3 : Array[Double] = []
  for i = 0; i < MODEL_NUM_ROWS; i = i + 1 {
    x1.push(2.0 * x0[i] + 0.1 * rng.next_normal())
    x2.push(0.5 * x0[i] + 0.1 * rng.next_normal())
  }
  for i = 0; i < MODEL_NUM_ROWS; i = i + 1 {
    x3.push(0.5 * x2[i] + 0.1 * rng.next_normal())
  }
  @api.DataFrame::from_numeric(
    ["X0", "X1", "X2", "X3"],
    Map([("X0", x0), ("X1", x1), ("X2", x2), ("X3", x3)]),
  )
}

///|
/// The model of the fixture: `X0 -> X1`, `X0 -> X2` and `X2 -> X3`.
fn model_of_the_fixture() -> @gcm.ProbabilisticCausalModel {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "X1")
  graph.add_edge("X0", "X2")
  graph.add_edge("X2", "X3")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  model.set_root_model("X0", @gcm.StochasticModel::empirical())
  for node in ["X1", "X2", "X3"] {
    model.set_causal_mechanism(
      node,
      @gcm.CausalMechanism::additive_noise(@gcm.PredictionModel::linear()),
    )
  }
  model
}

///|
/// The standard deviation of the values, with the degrees of freedom of numpy.
fn model_std(values : Array[Double]) -> Double {
  @utils.variance(values, 0).sqrt()
}

///|
test "the samples of a fitted model have the mean and the deviation of the data" {
  let data = model_data()
  let model = model_of_the_fixture()
  @gcm.fit(model, data)
  let drawn = @gcm.draw_samples(
    model,
    MODEL_NUM_SAMPLES,
    @utils.Random::new(MODEL_SEED + 1),
  )
  // The tolerances of the upstream test.
  for node in ["X0", "X1", "X2", "X3"] {
    let observed = data.numeric(node)
    let sampled = drawn.numeric(node)
    assert_true((@utils.mean(sampled) - @utils.mean(observed)).abs() <= 0.1)
    assert_true((model_std(sampled) - model_std(observed)).abs() <= 0.2)
  }
}

///|
test "the mechanism that is assigned to a node is the one that is read back" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "X1")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  let mechanism = @gcm.CausalMechanism::additive_noise(
    @gcm.PredictionModel::linear(),
  )
  model.set_causal_mechanism("X1", mechanism)
  // The model hands back the mechanism it was given, the way the upstream
  // compares the two objects.
  match model.causal_mechanism("X1") {
    Some(found) =>
      match found.kind() {
        @gcm.AdditiveNoise => assert_true(true)
        _ => abort("the mechanism of X1 is not the additive noise model")
      }
    None => abort("the mechanism of X1 is not there")
  }
}

///|
test "a node is a root exactly when it has no parents" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X", "Z")
  graph.add_edge("Y", "Z")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  assert_true(@gcm.is_root_node(model, "X"))
  assert_true(@gcm.is_root_node(model, "Y"))
  assert_false(@gcm.is_root_node(model, "Z"))
}

///|
test "a node that is not in the graph carries no valid assignment" {
  // The upstream assigns a mechanism to a node of an empty graph and asks for
  // a `ValueError`. The port aborts, and the predicate reports the same
  // situation without stopping the program.
  let model = @gcm.ProbabilisticCausalModel::new(@graph.DirectedGraph::new())
  assert_false(@gcm.has_valid_causal_model_assignment(model, "X0"))
  // A root without a distribution and a node with parents without a mechanism
  // are just as invalid.
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("A", "B")
  let half = @gcm.ProbabilisticCausalModel::new(graph)
  assert_false(@gcm.has_valid_causal_model_assignment(half, "A"))
  assert_false(@gcm.has_valid_causal_model_assignment(half, "B"))
  half.set_root_model("A", @gcm.StochasticModel::normal(0.0, 1.0))
  assert_true(@gcm.has_valid_causal_model_assignment(half, "A"))
  assert_false(@gcm.has_valid_causal_model_assignment(half, "B"))
  half.set_causal_mechanism(
    "B",
    @gcm.CausalMechanism::additive_noise(@gcm.PredictionModel::linear()),
  )
  assert_true(@gcm.has_valid_causal_model_assignment(half, "B"))
}
