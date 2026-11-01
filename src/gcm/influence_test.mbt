///|
/// The tests of the influence layer of the `gcm` package.
///
/// This is the port of the test file `tests/gcm/test_arrow_strength.py` of the
/// upstream. The upstream test file computes the causal strength of the edges
/// that point at a target node and compares the numbers with the ones the
/// upstream produces; the tests of the port assert the relations the upstream
/// test file asserts, with a tolerance around the numbers the reference script
/// `_verify/gcm_influence_reference.py` prints.
///
/// The upstream draws the permutations and the noise of the estimate from the
/// global generator of numpy, and the port draws them from the generator it is
/// given, so the two numbers are close to each other and not equal.
///
/// The samples of the conditional distribution and the number of the runs of
/// the estimate are smaller than the ones of the upstream, the way they are in
/// the other layers of the port: the upstream draws two thousand samples of the
/// conditional distribution and runs the estimate up to five thousand times,
/// and the tests of the port have to stay within the time the gate of the port
/// needs on every backend.

///|
/// The seed of the generators of the fixtures.
const INFLUENCE_SEED : UInt64 = 2025

///|
/// The number of the rows of the fixture of the causal model.
const INFLUENCE_NUM_ROWS : Int32 = 300

///|
/// The number of the samples of the conditional distribution.
const INFLUENCE_NUM_SAMPLES_CONDITIONAL : Int32 = 200

///|
/// The number of the runs of the estimate.
const INFLUENCE_MAX_NUM_RUNS : Int32 = 20

///|
/// The data frame of the given columns.
fn influence_frame(columns : Array[(String, Array[Double])]) -> @api.DataFrame {
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
/// The generator of the fixture with the given index.
fn influence_rng(index : UInt64) -> @utils.Random {
  @utils.Random::new(INFLUENCE_SEED + index)
}

///|
/// The given number of the samples of the normal distribution with the given
/// scale.
fn influence_normals(
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
/// The given number of the samples of the uniform distribution on the given
/// interval.
fn influence_uniforms(
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
/// The values of the given samples, multiplied by the given factor.
fn influence_scaled(values : Array[Double], factor : Double) -> Array[Double] {
  let out : Array[Double] = []
  for value in values {
    out.push(factor * value)
  }
  out
}

///|
/// The values of the two given samples, added.
fn influence_add(
  values : Array[Double],
  other : Array[Double],
) -> Array[Double] {
  let out : Array[Double] = []
  for i in 0..<values.length() {
    out.push(values[i] + other[i])
  }
  out
}

///|
/// The data of the fixture of the causal model.
fn influence_data_fixture() -> @api.DataFrame {
  let rng = influence_rng(30)
  let x0 = influence_normals(rng, INFLUENCE_NUM_ROWS, 1.0)
  let x1 = influence_normals(rng, INFLUENCE_NUM_ROWS, 1.0)
  let noise = influence_normals(rng, INFLUENCE_NUM_ROWS, 1.0)
  let x2 = influence_add(influence_add(influence_scaled(x0, 3.0), x1), noise)
  influence_frame([("X0", x0), ("X1", x1), ("X2", x2)])
}

///|
/// The causal model of the fixture, fitted on the data of the fixture.
///
/// The mechanism of the target is `X2 = 3 X0 + X1 + N`, the way the upstream
/// fixture of the test file is built.
fn influence_model_fixture(
  data : @api.DataFrame,
) -> @gcm.ProbabilisticCausalModel {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "X2")
  graph.add_edge("X1", "X2")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  model.set_root_model("X0", @gcm.StochasticModel::normal(0.0, 1.0))
  model.set_root_model("X1", @gcm.StochasticModel::normal(0.0, 1.0))
  model.set_causal_mechanism(
    "X2",
    @gcm.CausalMechanism::additive_noise_with(
      @gcm.PredictionModel::linear(),
      @gcm.StochasticModel::normal(0.0, 1.0),
    ),
  )
  @gcm.fit(model, data)
  model
}

///|
/// The configuration of the layer, with the samples of the port.
fn influence_config() -> @gcm.ArrowStrengthConfig {
  @gcm.ArrowStrengthConfig::new()
  .with_num_samples_conditional(INFLUENCE_NUM_SAMPLES_CONDITIONAL)
  .with_max_num_runs(INFLUENCE_MAX_NUM_RUNS)
}

///|
/// The strength of the edge that points at the target node.
fn influence_strength(
  strengths : Map[(String, String), Double],
  parent : String,
  target : String,
) -> Double {
  match strengths.get((parent, target)) {
    Some(value) => value
    None => 0.0
  }
}

///|
test "given a continuous target when estimating the arrow strength then report the strength of every edge" {
  let data = influence_data_fixture()
  let model = influence_model_fixture(data)
  let strengths = @gcm.arrow_strength(
    model,
    "X2",
    None,
    influence_config(),
    influence_rng(40),
  )
  // The mechanism of the target is `X2 = 3 X0 + X1 + N`, so the strength of the
  // edge of X0 is the variance of `3 X0` and the strength of the edge of X1 is
  // the variance of `X1`. The numbers of the upstream reference are 8.663170
  // and 0.924761.
  let x0 = influence_strength(strengths, "X0", "X2")
  let x1 = influence_strength(strengths, "X1", "X2")
  assert_true((x0 - 8.663170472449108).abs() <= 0.6)
  assert_true((x1 - 0.9247614540771657).abs() <= 0.3)
  assert_true(x0 > x1)
}

///|
test "given the divergence of the distributions as the measure when estimating the arrow strength then report the strength of every edge" {
  let data = influence_data_fixture()
  let model = influence_model_fixture(data)
  let config = influence_config().with_difference_estimation_func(fn(
    old_samples,
    new_samples,
  ) {
    @gcm.estimate_kl_divergence_continuous_knn(
      old_samples, new_samples, 1, true,
    )
  })
  let strengths = @gcm.arrow_strength(
    model,
    "X2",
    None,
    config,
    influence_rng(41),
  )
  // The numbers of the upstream reference are 1.127370 and 0.287371.
  let x0 = influence_strength(strengths, "X0", "X2")
  let x1 = influence_strength(strengths, "X1", "X2")
  assert_true((x0 - 1.1273704375133893).abs() <= 0.3)
  assert_true((x1 - 0.2873708742519612).abs() <= 0.2)
  assert_true(x0 > x1)
}

///|
test "given the observed samples of the parents when estimating the arrow strength then report the strength of every edge" {
  let data = influence_data_fixture()
  let model = influence_model_fixture(data)
  let strengths = @gcm.arrow_strength(
    model,
    "X2",
    Some(data),
    influence_config(),
    influence_rng(42),
  )
  // The numbers of the upstream reference are 10.324282 and 1.081782.
  let x0 = influence_strength(strengths, "X0", "X2")
  let x1 = influence_strength(strengths, "X1", "X2")
  assert_true((x0 - 10.32428223092686).abs() <= 0.8)
  assert_true((x1 - 1.081781776976977).abs() <= 0.3)
  assert_true(x0 > x1)
}

///|
test "given a classifier when estimating the strength of the model then report the strength of every input" {
  let rng = influence_rng(31)
  let values = influence_uniforms(rng, 5000, 0.0, 1.0)
  let inputs = @utils.Matrix::zeros(1000, 5)
  let labels : Array[String] = []
  for i in 0..<1000 {
    for j in 0..<5 {
      inputs.set(i, j, values[i * 5 + j])
    }
    if values[i * 5] + values[i * 5 + 1] + rng.next_double() > 1.5 {
      labels.push("0")
    } else {
      labels.push("1")
    }
  }
  let classifier = @gcm.ClassificationModel::logistic().fit(inputs, labels)
  let mechanism = @gcm.CausalMechanism::classifier(classifier)
  let strengths = @gcm.arrow_strength_of_model(
    mechanism,
    inputs,
    influence_config(),
    influence_rng(43),
  )
  // The first two inputs are the ones the label depends on, and the other
  // three do not move the distribution of the target at all. The numbers of
  // the upstream reference are 0.345292, 0.297614 and 0.000405, 0.000069 and
  // 0.000022.
  assert_true(strengths.length() == 5)
  assert_true((strengths[0] - 0.3452918448037002).abs() <= 0.15)
  assert_true((strengths[1] - 0.29761382417635157).abs() <= 0.15)
  assert_true(strengths[2].abs() <= 0.05)
  assert_true(strengths[3].abs() <= 0.05)
  assert_true(strengths[4].abs() <= 0.05)
}

///|
test "given a fixed seed when estimating the arrow strength then report the same strength twice" {
  let data = influence_data_fixture()
  let model = influence_model_fixture(data)
  let first = @gcm.arrow_strength(
    model,
    "X2",
    None,
    influence_config(),
    influence_rng(44),
  )
  let second = @gcm.arrow_strength(
    model,
    "X2",
    None,
    influence_config(),
    influence_rng(44),
  )
  assert_true(
    influence_strength(first, "X0", "X2") ==
    influence_strength(second, "X0", "X2"),
  )
  assert_true(
    influence_strength(first, "X1", "X2") ==
    influence_strength(second, "X1", "X2"),
  )
}

///|
test "given a graph without the edge of the parents when estimating the arrow strength with the observed data then report the strength of the edge" {
  // The graph of the upstream test misses the edge between X0 and X1, and the
  // strength of the edge of X0 is then about the strength it has when the
  // edge is in the graph.
  let rng = influence_rng(45)
  let z = influence_normals(rng, INFLUENCE_NUM_ROWS, 1.0)
  let noise0 = influence_normals(rng, INFLUENCE_NUM_ROWS, 1.0)
  let x0 = influence_add(z, noise0)
  let noise1 = influence_normals(rng, INFLUENCE_NUM_ROWS, 1.0)
  let x1 = influence_add(influence_add(influence_scaled(x0, 2.0), z), noise1)
  let x2 = influence_add(x0, x1)
  let data = influence_frame([("Z", z), ("X0", x0), ("X1", x1), ("X2", x2)])
  let without = @graph.DirectedGraph::new()
  without.add_edge("Z", "X0")
  without.add_edge("Z", "X1")
  without.add_edge("X0", "X2")
  without.add_edge("X1", "X2")
  let model_without = @gcm.ProbabilisticCausalModel::new(without)
  model_without.set_causal_mechanism(
    "X0",
    @gcm.CausalMechanism::additive_noise_with(
      @gcm.PredictionModel::linear(),
      @gcm.StochasticModel::normal(0.0, 1.0),
    ),
  )
  model_without.set_causal_mechanism(
    "X1",
    @gcm.CausalMechanism::additive_noise_with(
      @gcm.PredictionModel::linear(),
      @gcm.StochasticModel::normal(0.0, 1.0),
    ),
  )
  let _ = @gcm.assign_causal_mechanisms(
    model_without,
    data,
    @gcm.AssignmentQuality::good(),
    true,
  )
  @gcm.fit(model_without, data)
  let strengths_without = @gcm.arrow_strength(
    model_without,
    "X2",
    Some(data),
    influence_config(),
    influence_rng(46),
  )
  // The edge of X0 is as strong without the edge between X0 and X1 as it is
  // with it, the way the upstream test file asserts.
  let x0 = influence_strength(strengths_without, "X0", "X2")
  assert_true(x0 > 0.0)
  assert_true(x0 <= 10.0)
}

///|
test "given fewer samples than the number of the conditional samples when estimating the arrow strength then do not fail" {
  let rng = influence_rng(47)
  let x0 = influence_normals(rng, 10, 1.0)
  let x1 = influence_normals(rng, 10, 1.0)
  let data = influence_frame([("X0", x0), ("X1", x1)])
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "X1")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  model.set_root_model("X0", @gcm.StochasticModel::normal(0.0, 1.0))
  model.set_causal_mechanism(
    "X1",
    @gcm.CausalMechanism::additive_noise(@gcm.PredictionModel::linear()),
  )
  @gcm.fit(model, data)
  let config = influence_config().with_num_samples_conditional(10000)
  let strengths = @gcm.arrow_strength(
    model,
    "X1",
    Some(data),
    config,
    influence_rng(48),
  )
  assert_true(strengths.length() == 1)
}
