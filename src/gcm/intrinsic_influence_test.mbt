///|
/// The tests of the intrinsic causal influence of the `gcm` package.
///
/// The expectations are the ones of the upstream tests of
/// `dowhy.gcm.influence`, which are in `tests/gcm/test_intrinsic_influence.py`.
/// The three tests of the upstream that use a categorical target have no
/// counterpart here, because the prediction method of the port returns one
/// number per row and the predictions of a classifier are a probability per
/// class.
///
/// The fixtures are drawn with the deterministic generator of the `utils`
/// package. The upstream draws its samples with the global generator of numpy
/// and with a number of samples that the port cannot afford, so the fixtures
/// of the port are smaller; the contributions the upstream asserts are the
/// variances of the noise terms of the model, which hold for every size of the
/// fixture.

///|
/// The seed of the fixture of the intrinsic causal influence.
const ICC_SEED : UInt64 = 2060UL

///|
/// The number of rows of the fixture of the intrinsic causal influence.
const ICC_ROWS : Int32 = 1000

///|
/// The number of the samples the model is trained on.
const ICC_TRAINING_SAMPLES : Int32 = 2000

///|
/// The number of the samples the noise terms are randomized with.
const ICC_RANDOMIZATION_SAMPLES : Int32 = 250

///|
/// The number of the samples of the baseline.
const ICC_BASELINE_SAMPLES : Int32 = 500

///|
/// The number of the noise samples of the sample wise influence.
const ICC_NOISE_SAMPLES : Int32 = 2000

///|
/// The graph of the fixture of the intrinsic causal influence.
fn icc_graph() -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "X1")
  graph.add_edge("X1", "X2")
  graph.add_edge("X2", "X3")
  graph
}

///|
/// The data of the fixture of the intrinsic causal influence.
///
/// The noise of `X1` is small, the noise of `X2` is large and the noise of
/// `X3` is of the size of the noise of `X0`, so that every noise term has a
/// contribution of its own.
fn icc_data() -> @api.DataFrame {
  let rng = @utils.Random::new(ICC_SEED)
  let x0 : Array[Double] = []
  for _ in 0..<ICC_ROWS {
    x0.push(rng.next_normal())
  }
  let x1 : Array[Double] = []
  for i in 0..<ICC_ROWS {
    x1.push(x0[i] + 0.001 * rng.next_normal())
  }
  let x2 : Array[Double] = []
  for i in 0..<ICC_ROWS {
    x2.push(x1[i] + 2.0 * rng.next_normal())
  }
  let x3 : Array[Double] = []
  for i in 0..<ICC_ROWS {
    x3.push(x2[i] + rng.next_normal())
  }
  @api.DataFrame::from_numeric(
    ["X0", "X1", "X2", "X3"],
    Map([("X0", x0), ("X1", x1), ("X2", x2), ("X3", x3)]),
  )
}

///|
/// The influence of a node of the target.
fn icc_of(influence : Array[(String, Double)], node : String) -> Double {
  for entry in influence {
    let (name, value) = entry
    if name == node {
      return value
    }
  }
  abort("the node " + node + " has no influence")
}

///|
test "the intrinsic causal influence of a chain is the variance of the noise of every node" {
  let data = icc_data()
  let model = @gcm.ProbabilisticCausalModel::new(icc_graph())
  let _ = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
  )
  @gcm.fit(model, data)
  let influence = @gcm.intrinsic_causal_influence(
    model,
    "X3",
    @gcm.IccPrediction::exact(),
    None,
    ICC_TRAINING_SAMPLES,
    ICC_RANDOMIZATION_SAMPLES,
    ICC_BASELINE_SAMPLES,
    100,
    @gcm.AssignmentQuality::good(),
    @gcm.ShapleyConfig::new(@gcm.ShapleyApproximationMethod::auto()).with_seed(
      ICC_SEED,
    ),
    @utils.Random::new(ICC_SEED),
  )
  let of_x0 = icc_of(influence, "X0")
  let of_x1 = icc_of(influence, "X1")
  let of_x2 = icc_of(influence, "X2")
  let of_x3 = icc_of(influence, "X3")
  // The contribution of a node is the variance of the noise of that node.
  assert_true((of_x0 - 1.0).abs() <= 0.3)
  assert_true(of_x1.abs() <= 0.05)
  assert_true((of_x2 - 4.0).abs() <= 0.5)
  assert_true((of_x3 - 1.0).abs() <= 0.25)
  // The contributions add up to the variance of the target.
  let variance = @utils.var_pop(data.numeric("X3"))
  assert_true((of_x0 + of_x1 + of_x2 + of_x3 - variance).abs() <= 0.5)
}

///|
test "the intrinsic causal influence of a chain with an approximate model is the variance of the noise of every node" {
  let data = icc_data()
  let model = @gcm.ProbabilisticCausalModel::new(icc_graph())
  let _ = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
  )
  @gcm.fit(model, data)
  let influence = @gcm.intrinsic_causal_influence(
    model,
    "X3",
    @gcm.IccPrediction::approx(),
    None,
    ICC_TRAINING_SAMPLES,
    ICC_RANDOMIZATION_SAMPLES,
    ICC_BASELINE_SAMPLES,
    100,
    @gcm.AssignmentQuality::good(),
    @gcm.ShapleyConfig::new(@gcm.ShapleyApproximationMethod::auto()).with_seed(
      ICC_SEED,
    ),
    @utils.Random::new(ICC_SEED),
  )
  let of_x0 = icc_of(influence, "X0")
  let of_x1 = icc_of(influence, "X1")
  let of_x2 = icc_of(influence, "X2")
  let of_x3 = icc_of(influence, "X3")
  assert_true((of_x0 - 1.0).abs() <= 0.3)
  assert_true(of_x1.abs() <= 0.05)
  assert_true((of_x2 - 4.0).abs() <= 0.5)
  assert_true((of_x3 - 1.0).abs() <= 0.25)
}

///|
/// The recorder of the shapes of the inputs of the attribution function.
///
/// The upstream asserts the equality of the two shapes inside the attribution
/// function, which raises an error when they differ. The port records the
/// difference of the two lengths instead, because the function of the upstream
/// is a plain function here and cannot raise.
struct IccShapeRecorder {
  mut difference : Int32
}

///|
test "the attribution function of the intrinsic causal influence gets the predictions of the same shape" {
  let data = icc_data()
  let model = @gcm.ProbabilisticCausalModel::new(icc_graph())
  let _ = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
  )
  @gcm.fit(model, data)
  let recorder = { difference: 0, }
  let attribution = fn(
    predictions : Array[Double],
    baseline : Array[Double],
  ) -> Double {
    recorder.difference = recorder.difference +
      predictions.length() -
      baseline.length()
    0.0
  }
  let _ = @gcm.intrinsic_causal_influence(
    model,
    "X1",
    @gcm.IccPrediction::exact(),
    Some(attribution),
    ICC_TRAINING_SAMPLES,
    ICC_RANDOMIZATION_SAMPLES,
    ICC_BASELINE_SAMPLES,
    100,
    @gcm.AssignmentQuality::good(),
    @gcm.ShapleyConfig::new(@gcm.ShapleyApproximationMethod::auto()).with_seed(
      ICC_SEED,
    ),
    @utils.Random::new(ICC_SEED),
  )
  assert_eq(recorder.difference, 0)
}

///|
/// The linear model of the sample wise intrinsic causal influence.
///
/// The upstream stores the parents of every node with its `_persist_parents`
/// helper; the port stores them with `set_parents_during_fit` and needs the
/// encoder of the parents of every node as well.
fn icc_sample_model() -> @gcm.ProbabilisticCausalModel {
  let model = @gcm.ProbabilisticCausalModel::new(icc_graph())
  model.set_root_model("X0", @gcm.StochasticModel::normal(0.0, 1.0))
  model.set_causal_mechanism(
    "X1",
    @gcm.CausalMechanism::additive_noise_with(
      @gcm.PredictionModel::with_fixed_parameters([2.0], 0.0),
      @gcm.StochasticModel::normal(0.0, 1.0),
    ),
  )
  model.set_causal_mechanism(
    "X2",
    @gcm.CausalMechanism::additive_noise_with(
      @gcm.PredictionModel::with_fixed_parameters([1.0], 0.0),
      @gcm.StochasticModel::normal(0.0, 1.0),
    ),
  )
  model.set_causal_mechanism(
    "X3",
    @gcm.CausalMechanism::additive_noise_with(
      @gcm.PredictionModel::with_fixed_parameters([1.0], 0.0),
      @gcm.StochasticModel::normal(0.0, 1.0),
    ),
  )
  model.set_parents_during_fit("X1", ["X0"])
  model.set_parents_during_fit("X2", ["X1"])
  model.set_parents_during_fit("X3", ["X2"])
  model
}

///|
/// The baseline of the sample wise intrinsic causal influence.
fn icc_sample_baseline() -> @api.DataFrame {
  @api.DataFrame::from_numeric(
    ["X0", "X1", "X2", "X3"],
    Map([
      ("X0", [0.0, 1.0]),
      ("X1", [0.5, 2.5]),
      ("X2", [1.5, 4.5]),
      ("X3", [1.5, 5.5]),
    ]),
  )
}

///|
/// The relevance of the noise terms of the sample wise intrinsic causal
/// influence of a linear model.
///
/// The contribution of a noise term is its value times the coefficient of the
/// term in the target, so the noise of `X1` contributes half, the noise of `X2`
/// contributes its own value and the noise of `X0` contributes twice its own
/// value, because the coefficient of `X0` in `X3` is two.
fn icc_assert_sample_relevance(relevance : @utils.Matrix) -> Unit raise {
  assert_eq(relevance.nrows(), 2)
  assert_eq(relevance.ncols(), 4)
  assert_true(relevance.get(0, 0).abs() <= 0.1)
  assert_true((relevance.get(0, 1) - 0.5).abs() <= 0.1)
  assert_true((relevance.get(0, 2) - 1.0).abs() <= 0.1)
  assert_true(relevance.get(0, 3).abs() <= 0.1)
  assert_true((relevance.get(1, 0) - 2.0).abs() <= 0.1)
  assert_true((relevance.get(1, 1) - 0.5).abs() <= 0.1)
  assert_true((relevance.get(1, 2) - 2.0).abs() <= 0.1)
  assert_true((relevance.get(1, 3) - 1.0).abs() <= 0.1)
}

///|
test "the sample wise intrinsic causal influence of a linear model with the exact prediction is the contribution of every noise term" {
  let model = icc_sample_model()
  let baseline = icc_sample_baseline()
  model.set_encoder("X1", @gcm.ParentEncoder::fit(baseline, ["X0"]))
  model.set_encoder("X2", @gcm.ParentEncoder::fit(baseline, ["X1"]))
  model.set_encoder("X3", @gcm.ParentEncoder::fit(baseline, ["X2"]))
  let (relevance, names) = @gcm.intrinsic_causal_influence_sample(
    model,
    "X3",
    baseline,
    None,
    @gcm.IccPrediction::exact(),
    None,
    ICC_NOISE_SAMPLES,
    100,
    @gcm.AssignmentQuality::good(),
    @gcm.ShapleyConfig::new(@gcm.ShapleyApproximationMethod::auto()).with_seed(
      ICC_SEED,
    ),
    @utils.Random::new(ICC_SEED),
  )
  assert_eq(names.length(), 4)
  assert_eq(names[0], "X0")
  assert_eq(names[1], "X1")
  assert_eq(names[2], "X2")
  assert_eq(names[3], "X3")
  icc_assert_sample_relevance(relevance)
}

///|
test "the sample wise intrinsic causal influence of a linear model with the approximate prediction is the contribution of every noise term" {
  let model = icc_sample_model()
  let baseline = icc_sample_baseline()
  model.set_encoder("X1", @gcm.ParentEncoder::fit(baseline, ["X0"]))
  model.set_encoder("X2", @gcm.ParentEncoder::fit(baseline, ["X1"]))
  model.set_encoder("X3", @gcm.ParentEncoder::fit(baseline, ["X2"]))
  let (relevance, names) = @gcm.intrinsic_causal_influence_sample(
    model,
    "X3",
    baseline,
    None,
    @gcm.IccPrediction::approx(),
    None,
    ICC_NOISE_SAMPLES,
    100,
    @gcm.AssignmentQuality::good(),
    @gcm.ShapleyConfig::new(@gcm.ShapleyApproximationMethod::auto()).with_seed(
      ICC_SEED,
    ),
    @utils.Random::new(ICC_SEED),
  )
  assert_eq(names.length(), 4)
  icc_assert_sample_relevance(relevance)
}
