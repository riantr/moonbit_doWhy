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
  let rng = anomaly_rng(4)
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
  let actual = attribution.get(node).unwrap()[index]
  assert_true((actual - expected).abs() <= 0.05)
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
