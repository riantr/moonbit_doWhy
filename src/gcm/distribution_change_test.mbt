///|
/// The tests of the distribution change layer of the `gcm` package.
///
/// The upstream reference of the layer is
/// `_verify/gcm_distribution_change_reference.py`, which runs the upstream
/// `dowhy.gcm.distribution_change` on the fixtures of the layer. The fixtures of
/// the port are drawn from the generator of the `utils` package, and the
/// reference script reproduces that generator in Python, so that the fixtures of
/// the port and the fixtures of the reference are the same numbers.
///
/// The p-values of the test of the change of a mechanism depend on the
/// permutation of the rows that the test draws, and the upstream draws it from
/// the global generator of numpy while the port draws it from the generator it
/// is given. The p-values are therefore the same numbers up to the permutation,
/// and the tests of the layer assert the relations the upstream test file
/// `tests/gcm/test_distribution_change.py` asserts.
///
/// The attributions depend on the samples that the models draw, which the
/// upstream draws from the global generator of numpy and the port from the
/// generator it is given. The attributions of the port and of the upstream are
/// therefore close to each other and not equal, and the tests of the layer
/// assert the order of the attributions and the size of the contribution of the
/// node whose mechanism did not change.
///
/// The fixtures of the layer are a fifth of the size of the ones of the
/// upstream. The kernel based test of the change of a mechanism inverts a
/// kernel matrix whose size is the number of the rows of the joint sample, and
/// the port does the same with its own inversion, so the smaller fixtures keep
/// the gate of the port within the time it needs on every backend.

///|
/// The seed of the generators of the fixtures.
const DISTRIBUTION_CHANGE_SEED : UInt64 = 2025

///|
/// The number of the rows of the fixtures of the test of the change of a
/// mechanism.
const DISTRIBUTION_CHANGE_NUM_ROWS_TEST : Int32 = 100

///|
/// The number of the rows of the fixtures of the change of the distribution.
const DISTRIBUTION_CHANGE_NUM_ROWS_DATA : Int32 = 100

///|
/// The generator of the fixture with the given index.
fn distribution_change_rng(index : UInt64) -> @utils.Random {
  @utils.Random::new(DISTRIBUTION_CHANGE_SEED + index)
}

///|
/// The given number of the samples of the uniform distribution on the given
/// interval.
fn distribution_change_uniforms(
  rng : @utils.Random,
  count : Int32,
  low : Double,
  high : Double,
) -> Array[Double] {
  let out : Array[Double] = []
  for _ in 0..<count {
    out.push(low + (high - low) * rng.next_double())
  }
  out
}

///|
/// The given number of the samples of the normal distribution with the given
/// scale.
fn distribution_change_normals(
  rng : @utils.Random,
  count : Int32,
  scale : Double,
) -> Array[Double] {
  let out : Array[Double] = []
  for _ in 0..<count {
    out.push(scale * rng.next_normal())
  }
  out
}

///|
/// The values of the given samples, plus the given noise.
fn distribution_change_add(
  values : Array[Double],
  noise : Array[Double],
) -> Array[Double] {
  let out : Array[Double] = []
  for i in 0..<values.length() {
    out.push(values[i] + noise[i])
  }
  out
}

///|
/// The values of the given samples, multiplied by the given factor.
fn distribution_change_scaled(
  values : Array[Double],
  factor : Double,
) -> Array[Double] {
  let out : Array[Double] = []
  for value in values {
    out.push(factor * value)
  }
  out
}

///|
/// The data frame of the given columns.
fn distribution_change_frame(
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
/// The fixture of the change of a mechanism.
///
/// The relation of the original data is `X1 = 0.5 X0` and the relation of the
/// new data is `X1 = 2 X0`.
fn distribution_change_mechanism_fixture() -> (
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let rng = distribution_change_rng(1)
  let x0_org = distribution_change_uniforms(
    rng,
    DISTRIBUTION_CHANGE_NUM_ROWS_TEST,
    -1.0,
    1.0,
  )
  let x1_org = distribution_change_add(
    distribution_change_scaled(x0_org, 0.5),
    distribution_change_normals(rng, DISTRIBUTION_CHANGE_NUM_ROWS_TEST, 0.1),
  )
  let x0_new = distribution_change_uniforms(
    rng,
    DISTRIBUTION_CHANGE_NUM_ROWS_TEST,
    -1.0,
    1.0,
  )
  let x1_new = distribution_change_add(
    distribution_change_scaled(x0_new, 2.0),
    distribution_change_normals(rng, DISTRIBUTION_CHANGE_NUM_ROWS_TEST, 0.1),
  )
  (x0_org, x1_org, x0_new, x1_new)
}

///|
/// The fixture of the change of the distribution.
///
/// The relation of the original data is `X2 = 0.5 X0` and the relation of the
/// new data is `X2 = 2 X0`, and the relation of the target changed as well.
fn distribution_change_data_fixture() -> (@api.DataFrame, @api.DataFrame) {
  let rng = distribution_change_rng(4)
  let x0 = distribution_change_uniforms(
    rng,
    DISTRIBUTION_CHANGE_NUM_ROWS_DATA,
    -1.0,
    1.0,
  )
  let x1 = distribution_change_add(
    distribution_change_scaled(x0, 2.0),
    distribution_change_normals(rng, DISTRIBUTION_CHANGE_NUM_ROWS_DATA, 0.1),
  )
  let x2 = distribution_change_add(
    distribution_change_scaled(x0, 0.5),
    distribution_change_normals(rng, DISTRIBUTION_CHANGE_NUM_ROWS_DATA, 0.1),
  )
  let x3 = distribution_change_add(
    distribution_change_scaled(x2, 0.5),
    distribution_change_normals(rng, DISTRIBUTION_CHANGE_NUM_ROWS_DATA, 0.1),
  )
  let original = distribution_change_frame([
    ("X0", x0),
    ("X1", x1),
    ("X2", x2),
    ("X3", x3),
  ])
  let x0 = distribution_change_uniforms(
    rng,
    DISTRIBUTION_CHANGE_NUM_ROWS_DATA,
    -1.0,
    1.0,
  )
  let x1 = distribution_change_add(
    distribution_change_scaled(x0, 2.0),
    distribution_change_normals(rng, DISTRIBUTION_CHANGE_NUM_ROWS_DATA, 0.1),
  )
  let x2 = distribution_change_add(
    distribution_change_scaled(x0, 2.0),
    distribution_change_normals(rng, DISTRIBUTION_CHANGE_NUM_ROWS_DATA, 0.1),
  )
  let x3 = distribution_change_add(
    distribution_change_scaled(x2, 3.0),
    distribution_change_normals(rng, DISTRIBUTION_CHANGE_NUM_ROWS_DATA, 0.1),
  )
  let new = distribution_change_frame([
    ("X0", x0),
    ("X1", x1),
    ("X2", x2),
    ("X3", x3),
  ])
  (original, new)
}

///|
/// The causal model of the fixture of the change of the distribution.
fn distribution_change_model() -> @gcm.ProbabilisticCausalModel {
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
  model
}

///|
/// The configuration of the layer, with the defaults of the upstream.
fn distribution_change_config() -> @gcm.DistributionChangeConfig {
  @gcm.DistributionChangeConfig::new(
    @gcm.ShapleyConfig::new(@gcm.ShapleyApproximationMethod::auto()),
  )
}

///|
/// The contribution of the given node of the given attribution.
fn distribution_change_attribution(
  attributions : Map[String, Double],
  node : String,
) -> Double {
  match attributions.get(node) {
    Some(value) => value
    None => 0.0
  }
}

///|
test "given two data sets with different mechanisms when evaluating the change of the distribution then report the contribution of every node" {
  let (original, new) = distribution_change_data_fixture()
  let model = distribution_change_model()
  let result = @gcm.distribution_change(
    model,
    original,
    new,
    "X3",
    [],
    distribution_change_config(),
    distribution_change_rng(10),
  )
  let attributions = result.attributions()
  // The node X1 is not connected to the target, so it is not in the attribution.
  assert_false(attributions.contains("X1"))
  // The mechanism of the target changed the most, and the mechanism of the root
  // node did not change at all.
  let x3 = distribution_change_attribution(attributions, "X3")
  let x2 = distribution_change_attribution(attributions, "X2")
  let x0 = distribution_change_attribution(attributions, "X0")
  assert_true(x3 > x2)
  assert_true(x2 > x0)
  // The attributions are the numbers of the upstream reference, up to the
  // samples that the two draw from their own generators.
  assert_true((x3 - 1.4728675570845775).abs() <= 0.4)
  assert_true((x2 - 1.178768630016403).abs() <= 0.4)
  assert_true((x0 - -0.02812262830348538).abs() <= 0.3)
  // The mechanism of the root node did not change, and the mechanisms of the
  // other two nodes did.
  let changes = result.mechanism_changes()
  assert_false(changes.get("X0").unwrap())
  assert_true(changes.get("X2").unwrap())
  assert_true(changes.get("X3").unwrap())
  // The models of the result hold the nodes that are connected to the target.
  let old_nodes = result.causal_model_old().graph.node_list()
  assert_false(old_nodes.contains("X1"))
  assert_true(old_nodes.contains("X0"))
  assert_true(old_nodes.contains("X2"))
  assert_true(old_nodes.contains("X3"))
}

///|
test "given two models fitted on data sets with different mechanisms when evaluating the change of the distribution of two graphs then report the contribution of every node" {
  let (original, new) = distribution_change_data_fixture()
  let model_old = distribution_change_model()
  let model_new = distribution_change_model()
  @gcm.fit(model_old, original)
  @gcm.fit(model_new, new)
  let attributions = @gcm.distribution_change_of_graphs(
    model_old,
    model_new,
    "X3",
    distribution_change_config(),
    distribution_change_rng(11),
  )
  assert_false(attributions.contains("X1"))
  let x3 = distribution_change_attribution(attributions, "X3")
  let x2 = distribution_change_attribution(attributions, "X2")
  let x0 = distribution_change_attribution(attributions, "X0")
  assert_true(x3 > x2)
  assert_true(x2 > x0)
  assert_true(x3 > 1.0)
}

///|
test "given a list of invariant nodes when evaluating the change of the distribution then report no contribution of the invariant nodes" {
  let (original, new) = distribution_change_data_fixture()
  let model = distribution_change_model()
  let result = @gcm.distribution_change(
    model,
    original,
    new,
    "X3",
    ["X0", "X1"],
    distribution_change_config(),
    distribution_change_rng(12),
  )
  let attributions = result.attributions()
  assert_true(
    distribution_change_attribution(attributions, "X3") >
    distribution_change_attribution(attributions, "X2"),
  )
  assert_true(distribution_change_attribution(attributions, "X0") == 0.0)
}

///|
test "given two data sets with different mechanisms when evaluating the change of the distribution without the control of the false discovery rate then report the contribution of every node" {
  let (original, new) = distribution_change_data_fixture()
  let model = distribution_change_model()
  let config = distribution_change_config().with_fdr_control_method(None)
  let result = @gcm.distribution_change(
    model,
    original,
    new,
    "X3",
    [],
    config,
    distribution_change_rng(13),
  )
  let attributions = result.attributions()
  assert_false(attributions.contains("X1"))
  let x3 = distribution_change_attribution(attributions, "X3")
  let x2 = distribution_change_attribution(attributions, "X2")
  let x0 = distribution_change_attribution(attributions, "X0")
  assert_true(x3 > x2)
  assert_true(x2 > x0)
}

///|
test "given two data sets with different mechanisms when evaluating the change of the distribution then report the change of every mechanism" {
  let (original, new) = distribution_change_data_fixture()
  let model = distribution_change_model()
  let result = @gcm.distribution_change(
    model,
    original,
    new,
    "X3",
    [],
    distribution_change_config(),
    distribution_change_rng(14),
  )
  let changes = result.mechanism_changes()
  assert_false(changes.get("X0").unwrap())
  assert_true(changes.get("X2").unwrap())
  assert_true(changes.get("X3").unwrap())
  // The two models of the result hold the same mechanisms.
  let old_nodes = result.causal_model_old().graph.node_list()
  let new_nodes = result.causal_model_new().graph.node_list()
  assert_true(old_nodes.length() == new_nodes.length())
  for node in old_nodes {
    assert_true(new_nodes.contains(node))
    assert_true(
      result.causal_model_old().has_causal_mechanism(node) ==
      result.causal_model_new().has_causal_mechanism(node),
    )
  }
}

///|
test "given non linear data when evaluating the change of the distribution with the difference of the means then report the difference of the means" {
  let rng = distribution_change_rng(15)
  let x0 = distribution_change_uniforms(
    rng,
    DISTRIBUTION_CHANGE_NUM_ROWS_DATA,
    -1.0,
    1.0,
  )
  let x1 = distribution_change_add(
    distribution_change_scaled(x0, 2.0),
    distribution_change_normals(rng, DISTRIBUTION_CHANGE_NUM_ROWS_DATA, 0.1),
  )
  let x2 = distribution_change_add(
    distribution_change_exp(distribution_change_scaled(x0, 0.5)),
    distribution_change_normals(rng, DISTRIBUTION_CHANGE_NUM_ROWS_DATA, 0.1),
  )
  let x3 = distribution_change_add(
    distribution_change_scaled(x2, 0.5),
    distribution_change_normals(rng, DISTRIBUTION_CHANGE_NUM_ROWS_DATA, 0.1),
  )
  let original = distribution_change_frame([
    ("X0", x0),
    ("X1", x1),
    ("X2", x2),
    ("X3", x3),
  ])
  let x0 = distribution_change_uniforms(
    rng,
    DISTRIBUTION_CHANGE_NUM_ROWS_DATA,
    -1.0,
    1.0,
  )
  let x1 = distribution_change_add(
    distribution_change_scaled(x0, 2.0),
    distribution_change_normals(rng, DISTRIBUTION_CHANGE_NUM_ROWS_DATA, 0.1),
  )
  let x2 = distribution_change_add(
    distribution_change_add(
      distribution_change_exp(distribution_change_scaled(x0, 0.5)),
      distribution_change_four(),
    ),
    distribution_change_normals(rng, DISTRIBUTION_CHANGE_NUM_ROWS_DATA, 0.1),
  )
  let x3 = distribution_change_add(
    distribution_change_scaled(x2, 0.5),
    distribution_change_normals(rng, DISTRIBUTION_CHANGE_NUM_ROWS_DATA, 0.1),
  )
  let new = distribution_change_frame([
    ("X0", x0),
    ("X1", x1),
    ("X2", x2),
    ("X3", x3),
  ])
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "X1")
  graph.add_edge("X0", "X2")
  graph.add_edge("X2", "X3")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  let _ = @gcm.assign_causal_mechanisms(
    model,
    original,
    @gcm.AssignmentQuality::good(),
    true,
  )
  let config = distribution_change_config().with_difference_estimation_func(fn(
    old_samples,
    new_samples,
  ) {
    @utils.mean(new_samples) - @utils.mean(old_samples)
  })
  let result = @gcm.distribution_change(
    model,
    original,
    new,
    "X3",
    [],
    config,
    distribution_change_rng(16),
  )
  let attributions = result.attributions()
  // The mechanism of X2 changed by four, and the mechanism of the target turns
  // it into a difference of two.
  assert_true(
    (distribution_change_attribution(attributions, "X2") - 2.0).abs() <= 0.3,
  )
  assert_true(distribution_change_attribution(attributions, "X3").abs() <= 0.3)
  assert_true(distribution_change_attribution(attributions, "X0").abs() <= 0.3)
  assert_false(attributions.contains("X1"))
}

///|
test "given data where the mechanism changed when testing the change of the mechanism then report a small p-value" {
  let (x0_org, x1_org, x0_new, x1_new) = distribution_change_mechanism_fixture()
  let parents_org = @utils.Matrix::from_columns([x0_org])
  let parents_new = @utils.Matrix::from_columns([x0_new])
  let changed = @gcm.mechanism_change_test(
    x1_org,
    x1_new,
    Some(parents_org),
    Some(parents_new),
    distribution_change_rng(20),
  )
  assert_true(changed <= 0.05)
  let unchanged = @gcm.mechanism_change_test(
    x1_org,
    x1_org,
    Some(parents_org),
    Some(parents_new),
    distribution_change_rng(21),
  )
  assert_true(unchanged > 0.05)
}

///|
test "given data where the root node changed when testing the change of the mechanism then report a small p-value" {
  let rng = distribution_change_rng(2)
  let x0_org = distribution_change_uniforms(
    rng,
    DISTRIBUTION_CHANGE_NUM_ROWS_TEST,
    -1.0,
    1.0,
  )
  let x0_new = distribution_change_uniforms(
    rng,
    DISTRIBUTION_CHANGE_NUM_ROWS_TEST,
    -2.0,
    2.0,
  )
  let changed = @gcm.mechanism_change_test(
    x0_org,
    x0_new,
    None,
    None,
    distribution_change_rng(22),
  )
  assert_true(changed <= 0.05)
  let unchanged = @gcm.mechanism_change_test(
    x0_org,
    x0_org,
    None,
    None,
    distribution_change_rng(23),
  )
  assert_true(unchanged > 0.05)
}

///|
test "given data where the noise changed when testing the change of the mechanism then report a small p-value" {
  let rng = distribution_change_rng(3)
  let x0_org = distribution_change_uniforms(
    rng,
    DISTRIBUTION_CHANGE_NUM_ROWS_TEST,
    -1.0,
    1.0,
  )
  let x1_org = distribution_change_add(
    distribution_change_scaled(x0_org, 2.0),
    distribution_change_normals(rng, DISTRIBUTION_CHANGE_NUM_ROWS_TEST, 0.1),
  )
  let x0_new = distribution_change_uniforms(
    rng,
    DISTRIBUTION_CHANGE_NUM_ROWS_TEST,
    -1.0,
    1.0,
  )
  let x1_new = distribution_change_add(
    distribution_change_scaled(x0_new, 2.0),
    distribution_change_normals(rng, DISTRIBUTION_CHANGE_NUM_ROWS_TEST, 1.0),
  )
  let parents_org = @utils.Matrix::from_columns([x0_org])
  let parents_new = @utils.Matrix::from_columns([x0_new])
  let changed = @gcm.mechanism_change_test(
    x1_org,
    x1_new,
    Some(parents_org),
    Some(parents_new),
    distribution_change_rng(24),
  )
  assert_true(changed <= 0.05)
  let unchanged = @gcm.mechanism_change_test(
    x1_org,
    x1_org,
    Some(parents_org),
    Some(parents_new),
    distribution_change_rng(25),
  )
  assert_true(unchanged > 0.05)
}

///|
/// The exponent of every one of the given values.
fn distribution_change_exp(values : Array[Double]) -> Array[Double] {
  let out : Array[Double] = []
  for value in values {
    out.push(@math.exp(value))
  }
  out
}

///|
/// The given number of the samples of the value four.
fn distribution_change_four() -> Array[Double] {
  let out : Array[Double] = []
  for _ in 0..<DISTRIBUTION_CHANGE_NUM_ROWS_DATA {
    out.push(4.0)
  }
  out
}
