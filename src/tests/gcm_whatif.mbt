/// Tests for the what-if layer of the graphical causal model package.
///
/// The tests of the package itself live inside it. These ones check that the
/// what-if queries are usable from the outside, the way a consumer of the
/// published package uses them, and that the numbers they produce are the ones
/// the upstream produces. The expectations are the ones of the upstream tests of
/// `tests/gcm/test_whatif.py`, whose numbers are computed by
/// `_verify/gcm_whatif_reference.py`.

///|
/// The seed of the fixtures.
const WFX_SEED : UInt64 = 20260901UL

///|
/// The number of the rows of the fixture of the simple model.
const WFX_ROWS : Int32 = 64

///|
/// The number of the rows of the fixture of the treatment model.
const WFX_TREATMENT_ROWS : Int32 = 1000

///|
/// Whether two numbers are close to each other.
fn wfx_near(a : Double, b : Double, tolerance : Double) -> Bool {
  (a - b).abs() <= tolerance
}

///|
/// The data of the simple model.
///
/// The relations are the ones of the upstream test: `X1 = 2 * X0 + noise`,
/// `X2 = 0.5 * X0 + noise` and `X3 = 0.5 * X2 + noise`. The values of `X0` and
/// the three patterns of the noise are fixed, so the fit recovers the
/// coefficients of the relations exactly and the numbers of the tests do not
/// depend on a seed.
fn wfx_frame() -> @api.DataFrame {
  let bases = [-1.0, -0.75, -0.5, -0.25, 0.25, 0.5, 0.75, 1.0]
  let first = [1.0, -1.0, -1.0, 1.0, 1.0, -1.0, -1.0, 1.0]
  let second = [1.0, -1.0, 1.0, -1.0, -1.0, 1.0, -1.0, 1.0]
  let third = [1.0, 1.0, -1.0, -1.0, -1.0, -1.0, 1.0, 1.0]
  let x0 : Array[Double] = []
  let x1 : Array[Double] = []
  let x2 : Array[Double] = []
  let x3 : Array[Double] = []
  for i in 0..<WFX_ROWS {
    let r = i % 8
    let value = bases[r]
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
/// The model of the simple model, whose graph is `X0 -> X1`, `X0 -> X2` and
/// `X2 -> X3`.
fn wfx_model() -> @gcm.ProbabilisticCausalModel {
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
  @gcm.fit(model, wfx_frame())
  model
}

///|
/// The observed row of the upstream tests, the single row `X0 = 0`, `X1 = 1`,
/// `X2 = 2` and `X3 = 3`.
fn wfx_observed_row() -> @api.DataFrame {
  @api.DataFrame::from_numeric(
    ["X0", "X1", "X2", "X3"],
    Map([("X0", [0.0]), ("X1", [1.0]), ("X2", [2.0]), ("X3", [3.0])]),
  )
}

///|
/// The values of the given array, with their mean subtracted.
fn wfx_centered(values : Array[Double]) -> Array[Double] {
  let mean = @utils.mean(values)
  let out = values.copy()
  for i in 0..<out.length() {
    out[i] = out[i] - mean
  }
  out
}

///|
/// The inner product of two arrays.
fn wfx_dot(a : Array[Double], b : Array[Double]) -> Double {
  let mut sum = 0.0
  for i in 0..<a.length() {
    sum = sum + a[i] * b[i]
  }
  sum
}

///|
/// A noise of the fixture of the treatment model.
///
/// The noise is drawn from the generator of the package, centred, and
/// orthogonal to the treatment and to the noise of the other variables, so that
/// the fitted mechanisms recover the coefficients of the relations of the
/// fixture.
fn wfx_noise(
  rng : @utils.Random,
  scale : Double,
  against : Array[Array[Double]],
) -> Array[Double] {
  let values : Array[Double] = []
  for _ in 0..<WFX_TREATMENT_ROWS {
    values.push(rng.next_normal() * scale)
  }
  let mean = @utils.mean(values)
  for i in 0..<WFX_TREATMENT_ROWS {
    values[i] = values[i] - mean
  }
  for other in against {
    let factor = wfx_dot(values, other) / wfx_dot(other, other)
    for i in 0..<WFX_TREATMENT_ROWS {
      values[i] = values[i] - factor * other[i]
    }
  }
  values
}

///|
/// The treatment of the fixture of the treatment model, which alternates
/// between zero and one.
fn wfx_treatment() -> Array[Double] {
  let values : Array[Double] = []
  for i in 0..<WFX_TREATMENT_ROWS {
    values.push((i % 2).to_double())
  }
  values
}

///|
/// The data of the fixture of the treatment model.
///
/// The relations are the ones of the upstream test: `X0 = T + noise`,
/// `X1 = 0.5 * T + noise` and `Y = X0 + X1 + noise`. The target is a continuous
/// variable, or the comparison of the relation with `1.5`, which is the binary
/// target of the upstream test.
fn wfx_treatment_frame(binary : Bool) -> @api.DataFrame {
  let rng = @utils.Random::new(WFX_SEED)
  let treatment = wfx_treatment()
  let centered = wfx_centered(treatment)
  let first = wfx_noise(rng, 0.2, [centered])
  let second = wfx_noise(rng, 0.2, [centered, first])
  let third = wfx_noise(rng, 0.1, [centered, first, second])
  let x0 : Array[Double] = []
  let x1 : Array[Double] = []
  let y : Array[Double] = []
  let labels : Array[String] = []
  for i in 0..<WFX_TREATMENT_ROWS {
    let value0 = treatment[i] + first[i]
    let value1 = 0.5 * treatment[i] + second[i]
    let value2 = value0 + value1 + third[i]
    x0.push(value0)
    x1.push(value1)
    y.push(value2)
    labels.push(if value2 >= 1.5 { "True" } else { "False" })
  }
  if binary {
    let columns : Map[String, @api.Column] = Map([
      ("T", @api.Column::numeric(treatment)),
      ("X0", @api.Column::numeric(x0)),
      ("X1", @api.Column::numeric(x1)),
      ("Y", @api.Column::discrete(labels)),
    ])
    @api.DataFrame::new(["T", "X0", "X1", "Y"], columns)
  } else {
    @api.DataFrame::from_numeric(
      ["T", "X0", "X1", "Y"],
      Map([("T", treatment), ("X0", x0), ("X1", x1), ("Y", y)]),
    )
  }
}

///|
/// The model of the fixture of the treatment model, whose graph is `T -> X0`,
/// `T -> X1`, `X0 -> Y` and `X1 -> Y`.
fn wfx_treatment_model(binary : Bool) -> @gcm.ProbabilisticCausalModel {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("T", "X0")
  graph.add_edge("T", "X1")
  graph.add_edge("X0", "Y")
  graph.add_edge("X1", "Y")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  let data = wfx_treatment_frame(binary)
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
/// The number of the rows of the fixture of the categorical model.
const WFX_CATEGORICAL_ROWS : Int32 = 500

///|
/// The data of the fixture of the categorical model.
///
/// The relations are the ones of the upstream test: the numeric parent is
/// drawn from the normal distribution, the category of the categorical parent
/// alternates, and the target of the node is the comparison of the numeric
/// parent with minus two or with two, depending on the category of the
/// categorical parent. The target of the child is the other one.
fn wfx_categorical_frame() -> @api.DataFrame {
  let rng = @utils.Random::new(WFX_SEED)
  let values : Array[Double] = []
  let categories : Array[String] = []
  let targets : Array[String] = []
  let children : Array[String] = []
  for i in 0..<WFX_CATEGORICAL_ROWS {
    let value = rng.next_normal()
    let category = if i % 2 == 0 { "0" } else { "1" }
    let target = if category == "0" {
      value + 2.0 > 0.0
    } else {
      value - 2.0 > 0.0
    }
    values.push(value)
    categories.push(category)
    if target {
      targets.push("True")
      children.push("False")
    } else {
      targets.push("False")
      children.push("True")
    }
  }
  let columns : Map[String, @api.Column] = Map([
    ("X0", @api.Column::numeric(values)),
    ("X1", @api.Column::discrete(categories)),
    ("X2", @api.Column::discrete(targets)),
    ("X3", @api.Column::discrete(children)),
  ])
  @api.DataFrame::new(["X0", "X1", "X2", "X3"], columns)
}

///|
/// The model of the fixture of the categorical model, whose graph is
/// `X0 -> X2`, `X1 -> X2` and `X2 -> X3`.
fn wfx_categorical_model() -> @gcm.ProbabilisticCausalModel {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "X2")
  graph.add_edge("X1", "X2")
  graph.add_edge("X2", "X3")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  let data = wfx_categorical_frame()
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
/// The mean of the target of the interventional distribution of the simple
/// model.
///
/// This is the causal query of the bootstrap: it draws samples of the
/// interventional distribution of the node `X2` and returns the mean of the
/// node `X3` that follows it.
fn wfx_query(model : @gcm.ProbabilisticCausalModel) -> Array[Double] {
  let samples = @gcm.interventional_samples(
    model,
    Map([("X2", @gcm.set_number(10.0))]),
    None,
    Some(100),
    @utils.Random::new(WFX_SEED),
  )
  [@utils.mean(samples.numeric("X3"))]
}

///|
/// test "the interventional samples of a fitted model follow the intervention"
///
/// This is the port of the upstream test
/// `test_given_atomic_intervention_with_specific_input_when_draw_interventional_samples_then_return_correct_sample_values`,
/// which expects `0`, `1`, `10` and a value of about `5`.
test "the interventional samples of a fitted model follow the intervention" {
  let model = wfx_model()
  let samples = @gcm.interventional_samples(
    model,
    Map([("X2", @gcm.set_number(10.0))]),
    Some(wfx_observed_row()),
    None,
    @utils.Random::new(WFX_SEED),
  )
  assert_eq(samples.numeric("X0")[0], 0.0)
  assert_eq(samples.numeric("X1")[0], 1.0)
  assert_eq(samples.numeric("X2")[0], 10.0)
  // The relation of the node `X3` is `X3 = 0.5 * X2 + noise`.
  assert_true(wfx_near(samples.numeric("X3")[0], 5.0, 0.2))
}

///|
/// test "the interventional samples of a model without data follow the
/// intervention"
///
/// This is the port of the upstream test
/// `test_given_atomic_intervention_without_specific_input_when_draw_interventional_samples_then_return_correct_sample_values`,
/// which expects the ten values of the node to be the value of the
/// intervention.
test "the interventional samples of a model without data follow the intervention" {
  let model = wfx_model()
  let samples = @gcm.interventional_samples(
    model,
    Map([("X2", @gcm.set_number(10.0))]),
    None,
    Some(10),
    @utils.Random::new(WFX_SEED),
  )
  assert_eq(samples.numeric("X2").length(), 10)
  for value in samples.numeric("X2") {
    assert_eq(value, 10.0)
  }
}

///|
/// test "the counterfactual samples of an observed row follow the
/// intervention"
///
/// This is the port of the upstream test
/// `test_given_observed_sample_when_estimate_counterfactual_then_returns_correct_sample_values`,
/// which expects `1`, `3`, `2` and a value of about `3.5`.
test "the counterfactual samples of an observed row follow the intervention" {
  let model = wfx_model()
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
  assert_eq(samples.numeric("X0")[0], 1.0)
  assert_eq(samples.numeric("X1")[0], 3.0)
  assert_eq(samples.numeric("X2")[0], 2.0)
  // The noise of the node `X3` is `4 - 0.5 * 3`, so the counterfactual of the
  // node is `0.5 * 2 + 2.5`.
  assert_true(wfx_near(samples.numeric("X3")[0], 3.5, 0.05))
}

///|
/// test "the noise of a model and its data are each other's inverse"
///
/// This is the property the upstream relies on when it recovers the noise of a
/// model from the observed data: the data of the model follow from its noise
/// and its noise follows from its data.
test "the noise of a model and its data are each other's inverse" {
  let model = wfx_model()
  let data = wfx_frame()
  let noise = @gcm.compute_noise_from_data(model, data)
  let recovered = @gcm.compute_data_from_noise(model, noise)
  for name in ["X0", "X1", "X2", "X3"] {
    let expected = data.numeric(name)
    let actual = recovered.numeric(name)
    assert_eq(actual.length(), expected.length())
    for i in 0..<expected.length() {
      assert_true(wfx_near(actual[i], expected[i], 1.0e-9))
    }
  }
}

///|
/// test "the intervention of a categorical node sets its categories"
///
/// This is the port of the upstream test
/// `test_given_categorical_variables_when_draw_interventional_samples_then_return_correct_sample_values`,
/// which expects the categories of the node to be the ones of the intervention
/// and the target that follows them to be the expected one.
test "the intervention of a categorical node sets its categories" {
  let model = wfx_categorical_model()
  let samples = @gcm.interventional_samples(
    model,
    Map([("X0", @gcm.set_number(0.0)), ("X1", @gcm.set_category("0"))]),
    None,
    Some(100),
    @utils.Random::new(WFX_SEED),
  )
  let categories = samples.discrete("X1")
  assert_eq(categories.length(), 100)
  for category in categories {
    assert_eq(category, "0")
  }
  // The target of the node is "True" when the numeric parent is above minus
  // two and the category of the categorical parent is "0", which is the case
  // for the intervened row. The classifier of the node gives that target a
  // probability of about `0.95`, so the target of the samples is "True" for
  // about ninety five of them.
  let mut true_count = 0
  for target in samples.discrete("X2") {
    if target == "True" {
      true_count = true_count + 1
    }
  }
  assert_true(true_count > 90)
}

///|
/// test "the average causal effect of a continuous target is the expected
/// result"
///
/// This is the port of the upstream test
/// `test_given_continuous_target_when_estimate_average_causal_effect_then_return_expected_result`,
/// which expects a value of about `1.5`.
test "the average causal effect of a continuous target is the expected result" {
  let model = wfx_treatment_model(false)
  let effect = @gcm.average_causal_effect(
    model,
    "Y",
    Map([("T", @gcm.set_number(1.0))]),
    Map([("T", @gcm.set_number(0.0))]),
    None,
    Some(WFX_TREATMENT_ROWS),
    @utils.Random::new(WFX_SEED),
  )
  assert_true(wfx_near(effect, 1.5, 0.1))
}

///|
/// test "the average causal effect of a binary target is the expected result"
///
/// This is the port of the upstream test
/// `test_given_binary_target_when_estimate_average_causal_effect_then_return_expected_result`,
/// which expects a value of about `0.5`.
test "the average causal effect of a binary target is the expected result" {
  let model = wfx_treatment_model(true)
  let effect = @gcm.average_causal_effect(
    model,
    "Y",
    Map([("T", @gcm.set_number(1.0))]),
    Map([("T", @gcm.set_number(0.0))]),
    None,
    Some(WFX_TREATMENT_ROWS),
    @utils.Random::new(WFX_SEED),
  )
  assert_true(wfx_near(effect, 0.5, 0.1))
}

///|
/// test "the bootstrap of the interventional query gives an interval"
///
/// The query is evaluated on a model that is refitted on a subset of the
/// training data, so the interval of the bootstrap takes the uncertainty of the
/// fit into account.
test "the bootstrap of the interventional query gives an interval" {
  let model = wfx_model()
  let data = wfx_frame()
  let (summary, intervals) = @gcm.confidence_intervals(
    @gcm.fit_and_compute(wfx_query, model, data, 0.75, None),
    0.95,
    20,
    fn(results : @utils.Matrix) -> Array[Double] {
      @gcm.estimate_geometric_median(results)
    },
    @utils.Random::new(WFX_SEED),
  )
  assert_eq(summary.length(), 1)
  assert_eq(intervals.length(), 1)
  assert_eq(intervals[0].length(), 2)
  // The relation of the node `X3` is `X3 = 0.5 * X2 + noise` and the
  // intervention sets the node `X2` to ten.
  assert_true(wfx_near(summary[0], 5.0, 0.5))
  assert_true(intervals[0][0] <= summary[0])
  assert_true(summary[0] <= intervals[0][1])
}

///|
/// test "the clone of a causal model keeps its mechanisms untrained"
///
/// The clone of the upstream keeps the causal mechanisms untrained, so the
/// clone of the port does the same and has to be fitted again.
test "the clone of a causal model keeps its mechanisms untrained" {
  let model = wfx_model()
  let copy = model.clone()
  let mechanism = match copy.causal_mechanism("X2") {
    Some(mechanism) => mechanism
    None => abort("the node X2 has no causal mechanism")
  }
  assert_false(mechanism.prediction_model().is_fitted())
  // The model of the caller keeps its fit.
  let fitted = match model.causal_mechanism("X2") {
    Some(mechanism) => mechanism
    None => abort("the node X2 has no causal mechanism")
  }
  assert_true(fitted.prediction_model().is_fitted())
}
