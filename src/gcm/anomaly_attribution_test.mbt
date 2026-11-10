///|
/// The tests of the attribution of the anomalies of the `gcm` package.
///
/// The upstream reference of the layer is
/// `_verify/gcm_anomaly_attribution_reference.py`, which runs the upstream
/// `dowhy.gcm.anomaly.attribute_anomalies` on the fixtures of the layer. The
/// fixtures of the port are drawn from the generator of the `utils` package, and
/// the reference script reproduces that generator in Python, so that the
/// fixtures of the port and the fixtures of the reference are the same numbers.
///
/// The contributions depend on the noise the mechanisms draw and on the
/// permutations the set function uses, which the upstream draws from the global
/// generator of numpy and the port draws from the generator it is given, so the
/// contributions of the port and of the upstream are close to each other and not
/// equal. The tests of the layer assert the relations the upstream test file
/// `tests/gcm/test_anomaly_attribution.py` asserts and the numbers of the
/// upstream reference, with a tolerance that covers the difference of the two
/// generators.
///
/// The cases the port does not mirror are the two of the upstream that
/// attribute the anomalies of a sample without a causal model, because the
/// scorer of the port scores one variable at a time and the scorer of the
/// upstream scores a sample of several variables at once.

///|
/// The number of the rows of the fixture of the causal chain.
const ANOMALY_NUM_ROWS_CHAIN : Int32 = 5000

///|
/// The training data, the anomaly data and the causal model of the fixture of
/// the causal chain.
///
/// The fixture is the one of the upstream test file
/// `tests/gcm/test_anomaly_attribution.py`: a chain of four nodes, where the
/// anomaly of the first sample is in X1, the anomaly of the second sample is
/// in X0 and the anomaly of the third sample is in X0 and in X3.
fn anomaly_chain_fixture() -> (
  @api.DataFrame,
  @api.DataFrame,
  @gcm.ProbabilisticCausalModel,
) {
  let rng = anomaly_rng(1)
  let x0 = anomaly_normals(rng, ANOMALY_NUM_ROWS_CHAIN)
  let x1 = anomaly_sum(x0, anomaly_normals(rng, ANOMALY_NUM_ROWS_CHAIN))
  let x2 = anomaly_sum(x1, anomaly_normals(rng, ANOMALY_NUM_ROWS_CHAIN))
  let x3 = anomaly_sum(x2, anomaly_normals(rng, ANOMALY_NUM_ROWS_CHAIN))
  let training_data = anomaly_frame([
    ("X0", x0),
    ("X1", x1),
    ("X2", x2),
    ("X3", x3),
  ])
  let anomaly_data = anomaly_frame([
    ("X0", [0.0, 10.0, 10.0]),
    ("X1", [10.0, 10.0, 10.0]),
    ("X2", [10.0, 10.0, 10.0]),
    ("X3", [10.0, 10.0, 20.0]),
  ])
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "X1")
  graph.add_edge("X1", "X2")
  graph.add_edge("X2", "X3")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  let _ = @gcm.assign_causal_mechanisms(
    model,
    training_data,
    @gcm.AssignmentQuality::good(),
    true,
  )
  @gcm.fit(model, training_data)
  (training_data, anomaly_data, model)
}

///|
/// The anomaly score of the target, like the upstream test computes it.
fn anomaly_total_score(
  training_data : @api.DataFrame,
  anomaly_sample : Double,
) -> Double {
  let distribution = training_data.numeric("X3")
  let scorer = @gcm.AnomalyScorer::median_cdf_quantile().fit(distribution)
  let scores = scorer.score(distribution)
  let sample_score = scorer.score([anomaly_sample])[0]
  let mut count = 0.0
  for score in scores {
    if score >= sample_score {
      count = count + 1.0
    }
  }
  -@math.ln((count + 0.5) / (scores.length().to_double() + 0.5))
}

///|
/// The deviation of the anomaly score of the target from its expectation,
/// like the upstream test computes it.
fn anomaly_total_relevance(
  training_data : @api.DataFrame,
  anomaly_sample : Double,
) -> Double {
  let distribution = training_data.numeric("X3")
  let scorer = @gcm.AnomalyScorer::median_cdf_quantile().fit(distribution)
  scorer.score([anomaly_sample])[0] - @utils.mean(scorer.score(distribution))
}

///|
/// The sum of the contributions of every node of the given attribution.
fn anomaly_sum_of(
  attribution : Map[String, Array[Double]],
  index : Int32,
) -> Double {
  let mut total = 0.0
  for node in attribution.keys() {
    total = total + attribution.get(node).unwrap()[index]
  }
  total
}

///|
/// The contribution of the given node of the given attribution, compared with
/// the expected number of the upstream reference.
fn anomaly_assert_contribution(
  attribution : Map[String, Array[Double]],
  node : String,
  index : Int32,
  expected : Double,
) -> Unit raise {
  anomaly_assert_contribution_within(attribution, node, index, expected, 0.05)
}

///|
/// The contribution of the given node of the given attribution, compared with
/// the expected number of the upstream reference, with the given tolerance.
///
/// The tolerance is wider for the case of the non-trivial graph, because the
/// contributions of that case depend on the permutations of the noise of the
/// distribution, which the port draws with its own generator and the upstream
/// draws with the global generator of numpy.
fn anomaly_assert_contribution_within(
  attribution : Map[String, Array[Double]],
  node : String,
  index : Int32,
  expected : Double,
  tolerance : Double,
) -> Unit raise {
  let actual = attribution.get(node).unwrap()[index]
  assert_true((actual - expected).abs() <= tolerance)
}

///|
/// The configuration of the Shapley estimator of the attribution.
fn anomaly_shapley_config() -> @gcm.ShapleyConfig {
  @gcm.ShapleyConfig::new(@gcm.ShapleyApproximationMethod::auto())
}

///|
test "given a causal chain with linear relationships when attributing the anomalies with the information theoretic score then report the root cause" {
  let (training_data, anomaly_data, model) = anomaly_chain_fixture()
  let attribution = @gcm.attribute_anomalies(
    model,
    "X3",
    anomaly_data,
    @gcm.AnomalyScorer::median_cdf_quantile(),
    false,
    ANOMALY_NUM_ROWS_CHAIN,
    anomaly_shapley_config(),
    anomaly_rng(5),
  )
  // The first sample is anomalous in X1 only.
  assert_true(attribution.get("X0").unwrap()[0] < 0.5)
  assert_true(attribution.get("X1").unwrap()[0] > 8.0)
  assert_true(attribution.get("X2").unwrap()[0] < 0.5)
  assert_true(attribution.get("X3").unwrap()[0] < 0.5)
  // The second sample is anomalous in X0 only.
  assert_true(attribution.get("X0").unwrap()[1] > 8.0)
  assert_true(attribution.get("X1").unwrap()[1] < 0.5)
  assert_true(attribution.get("X2").unwrap()[1] < 0.5)
  assert_true(attribution.get("X3").unwrap()[1] < 0.5)
  // The third sample is anomalous in X0 and in X3.
  assert_true(attribution.get("X0").unwrap()[2] > 4.0)
  assert_true(attribution.get("X1").unwrap()[2] < 0.5)
  assert_true(attribution.get("X2").unwrap()[2] < 0.5)
  assert_true(attribution.get("X3").unwrap()[2] > 4.0)
  // The contributions of the two root causes of the third sample are the same.
  assert_true(
    (attribution.get("X0").unwrap()[2] - attribution.get("X3").unwrap()[2]).abs() <=
    0.5,
  )
  // The sum of the contributions is the anomaly score of the target.
  for i in 0..<3 {
    let expected = anomaly_total_score(
      training_data,
      anomaly_data.numeric("X3")[i],
    )
    assert_true((anomaly_sum_of(attribution, i) - expected).abs() <= 0.001)
  }
  // The contributions are the numbers of the upstream reference.
  anomaly_assert_contribution(attribution, "X0", 0, 0.005084005184103595)
  anomaly_assert_contribution(attribution, "X0", 1, 9.193448408174543)
  anomaly_assert_contribution(attribution, "X0", 2, 4.597710771683557)
  anomaly_assert_contribution(attribution, "X1", 0, 9.19531575109423)
  anomaly_assert_contribution(attribution, "X1", 1, 0.005981160338423699)
  anomaly_assert_contribution(attribution, "X1", 2, 0.008877243166975562)
  anomaly_assert_contribution(attribution, "X2", 0, 0.004648571945696854)
  anomaly_assert_contribution(attribution, "X2", 1, 0.005370637274063876)
  anomaly_assert_contribution(attribution, "X2", 2, 0.006906144045475496)
  anomaly_assert_contribution(attribution, "X3", 0, 0.005392038752486179)
  anomaly_assert_contribution(attribution, "X3", 1, 0.005640161189485544)
  anomaly_assert_contribution(attribution, "X3", 2, 4.596946208080507)
  // The sum of the contributions is the score of the upstream reference.
  for i in 0..<3 {
    assert_true(
      (anomaly_sum_of(attribution, i) - 9.210440366976515).abs() <= 1.0e-9,
    )
  }
}

///|
test "given a causal chain with linear relationships when attributing the anomalies with the feature relevance then report the root cause" {
  let (training_data, anomaly_data, model) = anomaly_chain_fixture()
  let attribution = @gcm.attribute_anomalies(
    model,
    "X3",
    anomaly_data,
    @gcm.AnomalyScorer::median_cdf_quantile(),
    true,
    ANOMALY_NUM_ROWS_CHAIN,
    anomaly_shapley_config(),
    anomaly_rng(6),
  )
  // The first sample is anomalous in X1 only.
  assert_true((attribution.get("X0").unwrap()[0] - 0.0).abs() <= 0.1)
  assert_true(attribution.get("X1").unwrap()[0] > 0.4)
  assert_true((attribution.get("X2").unwrap()[0] - 0.0).abs() <= 0.1)
  assert_true((attribution.get("X3").unwrap()[0] - 0.0).abs() <= 0.1)
  // The second sample is anomalous in X0 only.
  assert_true(attribution.get("X0").unwrap()[1] > 0.4)
  assert_true((attribution.get("X1").unwrap()[1] - 0.0).abs() <= 0.1)
  assert_true((attribution.get("X2").unwrap()[1] - 0.0).abs() <= 0.1)
  assert_true((attribution.get("X3").unwrap()[1] - 0.0).abs() <= 0.1)
  // The third sample is anomalous in X0 and in X3.
  assert_true(attribution.get("X0").unwrap()[2] > 0.2)
  assert_true((attribution.get("X1").unwrap()[2] - 0.0).abs() <= 0.1)
  assert_true((attribution.get("X2").unwrap()[2] - 0.0).abs() <= 0.1)
  assert_true(attribution.get("X3").unwrap()[2] > 0.2)
  // The sum of the contributions is the deviation of the score of the target.
  for i in 0..<3 {
    let expected = anomaly_total_relevance(
      training_data,
      anomaly_data.numeric("X3")[i],
    )
    assert_true((anomaly_sum_of(attribution, i) - expected).abs() <= 0.001)
  }
  // The contributions are the numbers of the upstream reference.
  anomaly_assert_contribution(attribution, "X0", 0, -0.02692802106245425)
  anomaly_assert_contribution(attribution, "X0", 1, 0.5916778111044456)
  anomaly_assert_contribution(attribution, "X0", 2, 0.2671148370325934)
  anomaly_assert_contribution(attribution, "X1", 0, 0.5875866226754648)
  anomaly_assert_contribution(attribution, "X1", 1, -0.030623621942278224)
  anomaly_assert_contribution(attribution, "X1", 2, -0.01717307871758983)
  anomaly_assert_contribution(attribution, "X2", 0, -0.029815696860627867)
  anomaly_assert_contribution(attribution, "X2", 1, -0.030460961141105133)
  anomaly_assert_contribution(attribution, "X2", 2, -0.01714492434846365)
  anomaly_assert_contribution(attribution, "X3", 0, -0.03094288475638207)
  anomaly_assert_contribution(attribution, "X3", 1, -0.03069320802506173)
  anomaly_assert_contribution(attribution, "X3", 2, 0.2671031860294607)
  // The sum of the contributions is the sum of the upstream reference.
  for i in 0..<3 {
    assert_true(
      (anomaly_sum_of(attribution, i) - 0.49990001999600053).abs() <= 0.001,
    )
  }
}

///|
/// The number of the rows of the fixture of the non-trivial graph.
const ANOMALY_NUM_ROWS_NON_LINEAR : Int32 = 10000

///|
/// The squares of the given samples.
fn anomaly_squared(values : Array[Double]) -> Array[Double] {
  let out : Array[Double] = []
  for value in values {
    out.push(value * value)
  }
  out
}

///|
/// The given number of the samples of the uniform distribution on `[-5, 5)`.
fn anomaly_uniforms_five(rng : @utils.Random, count : Int32) -> Array[Double] {
  let out : Array[Double] = []
  for _ in 0..<count {
    out.push(-5.0 + 10.0 * rng.next_double())
  }
  out
}

///|
/// The training data, the anomaly data and the causal model of the fixture of
/// the non-trivial graph.
///
/// The fixture is the one of the upstream test file
/// `tests/gcm/test_anomaly_attribution.py`: the node `X1` is the square of
/// `X0` with a noise, the node `X2` is uniform and the node `X3` is the square
/// of the sum of `X1` and `X2` with a noise.
///
/// The upstream sets the mechanisms of the two nodes whose relation is
/// non-linear to a model that computes the square of the sum of the parents,
/// and it assigns the mechanisms of the other two nodes. The port expresses
/// the same model with its equation parser, so that the mechanism of a node is
/// the relation of the fixture and not a fit of it.
fn anomaly_non_linear_fixture() -> (
  @api.DataFrame,
  @api.DataFrame,
  @gcm.ProbabilisticCausalModel,
) {
  let rng = anomaly_rng(2)
  let x0 = anomaly_normals(rng, ANOMALY_NUM_ROWS_NON_LINEAR)
  let noise_one = anomaly_normals(rng, ANOMALY_NUM_ROWS_NON_LINEAR)
  let x1 = anomaly_sum(anomaly_squared(x0), noise_one)
  let x2 = anomaly_uniforms_five(rng, ANOMALY_NUM_ROWS_NON_LINEAR)
  let noise_three = anomaly_normals(rng, ANOMALY_NUM_ROWS_NON_LINEAR)
  let x3 = anomaly_sum(anomaly_squared(anomaly_sum(x1, x2)), noise_three)
  let training_data = anomaly_frame([
    ("X0", x0),
    ("X1", x1),
    ("X2", x2),
    ("X3", x3),
  ])
  let anomaly_data = anomaly_frame([
    ("X0", [10.0, 10.0, 0.0]),
    ("X1", [100.0, 110.0, 0.0]),
    ("X2", [0.0, 0.0, 10.0]),
    ("X3", [10000.0, 12100.0, 110.0]),
  ])
  // The mechanism of the node `X1` is the square of its parent, and the
  // mechanism of the node `X3` is the square of the sum of its parents. The
  // upstream sets them to a model that computes the square of the sum of the
  // parents, and the port expresses the same model with its equation parser.
  let model = @gcm.create_causal_model_from_equations(
    "X0 = empirical()\n" +
    "X1 = X0 * X0 + empirical()\n" +
    "X2 = empirical()\n" +
    "X3 = (X1 + X2) * (X1 + X2) + empirical()\n",
  )
  let _ = @gcm.assign_causal_mechanisms(
    model,
    training_data,
    @gcm.AssignmentQuality::good(),
    false,
  )
  @gcm.fit(model, training_data)
  (training_data, anomaly_data, model)
}

///|
/// test "given a non-trivial graph with non-linear relationships when attributing the anomalies with the information theoretic score then report the root cause"
///
/// This is the case of the upstream
/// `test_given_non_trivial_graph_with_nonlinear_relationships_when_attribute_anomaly_scores_with_it_score_then_returns_qualitatively_correct_results`.
test "given a non-trivial graph with non-linear relationships when attributing the anomalies with the information theoretic score then report the root cause" {
  let (training_data, anomaly_data, model) = anomaly_non_linear_fixture()
  let attribution = @gcm.attribute_anomalies(
    model,
    "X3",
    anomaly_data,
    @gcm.AnomalyScorer::median_cdf_quantile(),
    false,
    ANOMALY_NUM_ROWS_NON_LINEAR,
    anomaly_shapley_config(),
    anomaly_rng(8),
  )
  // The first sample is anomalous in X0 only.
  assert_true(attribution.get("X0").unwrap()[0] > 8.0)
  assert_true(attribution.get("X1").unwrap()[0] < 1.0)
  assert_true(attribution.get("X2").unwrap()[0] < 1.0)
  assert_true(attribution.get("X3").unwrap()[0] < 1.0)
  // The second sample is anomalous in X0 and in X1.
  assert_true(attribution.get("X0").unwrap()[1] > 4.0)
  assert_true(attribution.get("X1").unwrap()[1] > 1.0)
  assert_true(attribution.get("X2").unwrap()[1] < 1.0)
  assert_true(attribution.get("X3").unwrap()[1] < 1.0)
  // The third sample is anomalous in X2 and in X3.
  assert_true(attribution.get("X0").unwrap()[2] < 1.0)
  assert_true(attribution.get("X1").unwrap()[2] < 1.0)
  assert_true(attribution.get("X2").unwrap()[2] > 1.0)
  assert_true(attribution.get("X3").unwrap()[2] > 1.0)
  // The sum of the contributions is the anomaly score of the target. The
  // tolerance is the one of the upstream, because the port and the upstream
  // reconstruct the distribution of the target from the noise of its
  // mechanisms, and the noise of the distribution is drawn from the empirical
  // distribution of the residuals.
  for i in 0..<3 {
    let expected = anomaly_total_score(
      training_data,
      anomaly_data.numeric("X3")[i],
    )
    assert_true((anomaly_sum_of(attribution, i) - expected).abs() <= 0.6)
  }
  // The contributions are the numbers of the upstream reference.
  anomaly_assert_contribution_within(
    attribution, "X0", 0, 9.628884479119142, 0.6,
  )
  anomaly_assert_contribution_within(
    attribution, "X0", 1, 7.61613130313375, 0.6,
  )
  anomaly_assert_contribution_within(
    attribution, "X0", 2, -1.788514155267602, 0.6,
  )
  anomaly_assert_contribution_within(
    attribution, "X1", 0, -0.0915510240556759, 0.6,
  )
  anomaly_assert_contribution_within(
    attribution, "X1", 1, 2.0595935356086215, 0.6,
  )
  anomaly_assert_contribution_within(
    attribution, "X1", 2, -0.5465142067199505, 0.6,
  )
  anomaly_assert_contribution_within(
    attribution, "X2", 0, 0.2746530721670277, 0.6,
  )
  anomaly_assert_contribution_within(
    attribution, "X2", 1, 0.04471066443244667, 0.6,
  )
  anomaly_assert_contribution_within(
    attribution, "X2", 2, 5.534849931917564, 0.6,
  )
  anomaly_assert_contribution_within(
    attribution, "X3", 0, 0.09155102405567593, 0.6,
  )
  anomaly_assert_contribution_within(
    attribution, "X3", 1, 0.18310204811135183, 0.6,
  )
  anomaly_assert_contribution_within(
    attribution, "X3", 2, 1.6997696754106988, 0.6,
  )
  // The sum of the contributions is the total of the upstream reference. The
  // first two samples are in the tail of the distribution of the target, and
  // the third one is not, so their totals are different.
  for i in 0..<2 {
    assert_true(
      (anomaly_sum_of(attribution, i) - 9.90353755128617).abs() <= 0.4,
    )
  }
  assert_true((anomaly_sum_of(attribution, 2) - 4.89959124534071).abs() <= 0.6)
}
