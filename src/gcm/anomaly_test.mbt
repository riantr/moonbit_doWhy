///|
/// The tests of the anomaly detection layer of the `gcm` package.
///
/// The upstream reference of the layer is `_verify/gcm_anomaly_reference.py`,
/// which runs the upstream `dowhy.gcm.anomaly_scorers` and the upstream
/// `dowhy.gcm.anomaly` on the fixtures of the layer. The fixtures of the port
/// are drawn from the generator of the `utils` package, and the reference script
/// reproduces that generator, so that the fixtures of the port and the fixtures
/// of the reference are the same numbers.
///
/// The scores of the scorers on the toy fixtures of the upstream test file
/// `tests/gcm/test_anomaly_scorers.py` are deterministic, so the tests compare
/// them with a tight tolerance. The anomaly scores of a causal model depend on
/// the samples the mechanisms draw, which the upstream draws from the global
/// generator of numpy and the port draws from the generator of the `utils`
/// package, so the tests of the layer compare the node with the largest score,
/// which is what the upstream test file `tests/gcm/test_anomaly.py` asserts.

///|
/// The seed of the generators of the fixtures.
const ANOMALY_SEED : UInt64 = 2025

///|
/// The number of the rows of the fixtures.
const ANOMALY_NUM_ROWS : Int32 = 1000

///|
/// The number of the samples the scores of the model are estimated with.
const ANOMALY_NUM_SAMPLES : Int32 = 10000

///|
/// The generator of the fixture with the given index.
fn anomaly_rng(index : UInt64) -> @utils.Random {
  @utils.Random::new(ANOMALY_SEED + index)
}

///|
/// The given number of the samples of the uniform distribution on `[-1, 1)`.
fn anomaly_uniforms(rng : @utils.Random, count : Int32) -> Array[Double] {
  let out : Array[Double] = []
  for _ in 0..<count {
    out.push(-1.0 + 2.0 * rng.next_double())
  }
  out
}

///|
/// The given number of the samples of the standard normal distribution.
fn anomaly_normals(rng : @utils.Random, count : Int32) -> Array[Double] {
  let out : Array[Double] = []
  for _ in 0..<count {
    out.push(rng.next_normal())
  }
  out
}

///|
/// The values of the given samples, multiplied by the given factor.
fn anomaly_scaled(values : Array[Double], factor : Double) -> Array[Double] {
  let out : Array[Double] = []
  for value in values {
    out.push(factor * value)
  }
  out
}

///|
/// The sum of the given samples and of the given noise.
fn anomaly_sum(values : Array[Double], noise : Array[Double]) -> Array[Double] {
  let out : Array[Double] = []
  for i in 0..<values.length() {
    out.push(values[i] + noise[i])
  }
  out
}

///|
/// The data frame of the given columns.
fn anomaly_frame(columns : Array[(String, Array[Double])]) -> @api.DataFrame {
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
/// The observations and the outlier observation of the fixture.
///
/// The outlier is the observation of X1 that is three standard deviations above
/// the observation of the first row, which is the fixture of the upstream test
/// file `tests/gcm/test_anomaly.py`.
fn anomaly_fixture() -> (@api.DataFrame, @api.DataFrame) {
  let rng = anomaly_rng(1)
  let x0 = anomaly_uniforms(rng, ANOMALY_NUM_ROWS)
  let x1 = anomaly_sum(
    anomaly_scaled(x0, 2.0),
    anomaly_scaled(anomaly_normals(rng, ANOMALY_NUM_ROWS), 0.1),
  )
  let x2 = anomaly_sum(
    anomaly_scaled(x0, 0.5),
    anomaly_scaled(anomaly_normals(rng, ANOMALY_NUM_ROWS), 0.1),
  )
  let x3 = anomaly_sum(
    anomaly_scaled(x2, 0.5),
    anomaly_scaled(anomaly_normals(rng, ANOMALY_NUM_ROWS), 0.1),
  )
  let observations = anomaly_frame([
    ("X0", x0),
    ("X1", x1),
    ("X2", x2),
    ("X3", x3),
  ])
  let outlier = anomaly_frame([
    ("X0", [x0[0]]),
    ("X1", [x1[0] + 3.0 * @utils.std(x1)]),
    ("X2", [x2[0]]),
    ("X3", [x3[0]]),
  ])
  (observations, outlier)
}

///|
/// The causal model of the fixture.
fn anomaly_model(frame : @api.DataFrame) -> @gcm.ProbabilisticCausalModel {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "X1")
  graph.add_edge("X0", "X2")
  graph.add_edge("X2", "X3")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  let _ = @gcm.assign_causal_mechanisms(
    model,
    frame,
    @gcm.AssignmentQuality::good(),
    true,
  )
  @gcm.fit(model, frame)
  model
}

///|
/// The node with the largest anomaly score.
fn anomaly_largest(scores : Map[String, Array[Double]]) -> String {
  let mut largest = ""
  let mut best = -1.0e308
  for node in scores.keys() {
    let score = scores.get(node).unwrap()[0]
    if score > best {
      largest = node
      best = score
    }
  }
  largest
}

///|
/// Whether two numbers are close to each other.
fn anomaly_close(
  actual : Double,
  expected : Double,
  tolerance : Double,
) -> Bool {
  (actual - expected).abs() <= tolerance * expected.abs().max(1.0)
}

///|
/// The samples of the toy fixture of the upstream test file of the scorers,
/// which holds the values one to eight and two values that are not a number.
fn anomaly_toy_samples() -> Array[Double] {
  [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, @utils.nan(), @utils.nan()]
}

///|
/// The samples of the toy fixture of the upstream test file of the scorers,
/// which holds the values zero to nineteen.
fn anomaly_range_samples() -> Array[Double] {
  let out : Array[Double] = []
  for i in 0..<20 {
    out.push(i.to_double())
  }
  out
}

///|
/// The samples of the toy fixture of the upstream test file of the scorers,
/// which holds the values zero to nineteen divided by ten.
fn anomaly_tenth_samples() -> Array[Double] {
  let out : Array[Double] = []
  for i in 0..<20 {
    out.push(i.to_double() / 10.0)
  }
  out
}

///|
/// The scores of the given samples of the given scorer.
fn anomaly_scores_of(
  scorer : @gcm.AnomalyScorer,
  distribution_samples : Array[Double],
  samples : Array[Double],
) -> Array[Double] {
  scorer.fit(distribution_samples).score(samples)
}

///|
/// The scores of the given samples of the given scorer, compared with the
/// expected ones.
fn anomaly_assert_scores(
  actual : Array[Double],
  expected : Array[Double],
  tolerance : Double,
) -> Unit raise {
  assert_eq(actual.length(), expected.length())
  for i in 0..<actual.length() {
    assert_true(anomaly_close(actual[i], expected[i], tolerance))
  }
}

///|
/// The scores of the model of the fixture, with the given scorer.
fn anomaly_scores_of_model(
  scorer_factory : @gcm.AnomalyScorerFactory,
  index : UInt64,
) -> Map[String, Array[Double]] {
  let (observations, outlier) = anomaly_fixture()
  let model = anomaly_model(observations)
  @gcm.anomaly_scores(
    model,
    outlier,
    ANOMALY_NUM_SAMPLES,
    ANOMALY_NUM_SAMPLES,
    scorer_factory,
    anomaly_rng(index),
  )
}

///|
test "given simple toy data when using the median cdf quantile scorer then return the expected scores" {
  let scorer = @gcm.AnomalyScorer::median_cdf_quantile()
  let scores = anomaly_scores_of(scorer, anomaly_range_samples(), [8.0, 17.0])
  anomaly_assert_scores(
    scores,
    [0.1428571428571429, 0.7142857142857143],
    1.0e-12,
  )
  let scores = anomaly_scores_of(scorer, anomaly_range_samples(), [0.0])
  anomaly_assert_scores(scores, [0.9047619047619048], 1.0e-12)
  let constant : Array[Double] = []
  for _ in 0..<200 {
    constant.push(4.0)
  }
  let scores = anomaly_scores_of(scorer, constant, [4.0])
  anomaly_assert_scores(scores, [0.0], 1.0e-12)
}

///|
test "given data with nans when using the median quantile scorer with nan support then return the expected scores" {
  let scorer = @gcm.AnomalyScorer::rescaled_median_cdf_quantile()
  let scores = anomaly_scores_of(scorer, anomaly_toy_samples(), [
    1.0,
    4.0,
    8.0,
    @utils.nan(),
  ])
  anomaly_assert_scores(
    scores,
    [
      1.7047480922384248, 0.3184537311185346, 1.7047480922384248, 1.2992829841302609,
    ],
    1.0e-12,
  )
}

///|
test "when using the rank based anomaly scorer then return the expected scores" {
  let scorer = @gcm.AnomalyScorer::rank_based()
  let scores = anomaly_scores_of(scorer, anomaly_toy_samples(), [
    1.0,
    4.0,
    9.0,
    @utils.nan(),
  ])
  anomaly_assert_scores(
    scores,
    [
      1.0116009116784799, 0.0953101798043249, 1.7047480922384253, 0.6061358035703156,
    ],
    1.0e-12,
  )
  let scores = anomaly_scores_of(
    scorer,
    [@utils.nan(), @utils.nan(), @utils.nan(), @utils.nan()],
    [1.0, @utils.nan()],
  )
  anomaly_assert_scores(scores, [0.916290731874155, 0.0], 1.0e-12)
}

///|
test "given simple toy data when using the median deviation scorer then return the expected scores" {
  let scorer = @gcm.AnomalyScorer::median_deviation()
  let scores = anomaly_scores_of(scorer, anomaly_tenth_samples(), [0.8, 1.7])
  anomaly_assert_scores(
    scores,
    [0.2023469250588244, 1.0117346252941226],
    1.0e-12,
  )
}

///|
test "given simple toy data when using the mean deviation scorer then return the expected scores" {
  let scorer = @gcm.AnomalyScorer::mean_deviation()
  let scores = anomaly_scores_of(scorer, anomaly_tenth_samples(), [0.8, 1.7])
  anomaly_assert_scores(
    scores,
    [0.2601329908572357, 1.3006649542861803],
    1.0e-12,
  )
}

///|
test "given simple toy data when using the information theoretic scorer then return the expected scores" {
  let scorer = @gcm.AnomalyScorer::information_theoretic(
    @gcm.AnomalyScorer::median_cdf_quantile(),
  )
  let scores = anomaly_scores_of(scorer, anomaly_toy_samples(), [
    1.0,
    4.0,
    8.0,
    @utils.nan(),
  ])
  anomaly_assert_scores(
    scores,
    [1.4350845252893227, 0.0, 1.4350845252893227, 0.8472978603872037],
    1.0e-12,
  )
}

///|
test "given simple toy data when using the inverse density scorer then return the expected scores" {
  let scorer = @gcm.AnomalyScorer::inverse_density()
  let scores = anomaly_scores_of(scorer, anomaly_range_samples(), [8.0, 17.0])
  anomaly_assert_scores(
    scores,
    [20.116376253954485, 25.881318130476988],
    1.0e-12,
  )
}

///|
test "given an outlier observation when estimating the anomaly scores with the median cdf quantile scorer then report the outlier node" {
  let scores = anomaly_scores_of_model(
    fn() { @gcm.AnomalyScorer::median_cdf_quantile() },
    10,
  )
  assert_eq(anomaly_largest(scores), "X1")
}

///|
test "given an outlier observation when estimating the anomaly scores with the rescaled median cdf quantile scorer then report the outlier node" {
  let scores = anomaly_scores_of_model(
    fn() { @gcm.AnomalyScorer::rescaled_median_cdf_quantile() },
    11,
  )
  assert_eq(anomaly_largest(scores), "X1")
}

///|
test "given an outlier observation when estimating the anomaly scores with the rank based scorer then report the outlier node" {
  let scores = anomaly_scores_of_model(
    fn() { @gcm.AnomalyScorer::rank_based() },
    12,
  )
  assert_eq(anomaly_largest(scores), "X1")
}

///|
test "given an outlier observation when estimating the anomaly scores with the mean deviation scorer then report the outlier node" {
  let scores = anomaly_scores_of_model(
    fn() { @gcm.AnomalyScorer::mean_deviation() },
    13,
  )
  assert_eq(anomaly_largest(scores), "X1")
}

///|
test "given an outlier observation when estimating the anomaly scores with the median deviation scorer then report the outlier node" {
  let scores = anomaly_scores_of_model(
    fn() { @gcm.AnomalyScorer::median_deviation() },
    14,
  )
  assert_eq(anomaly_largest(scores), "X1")
}

///|
test "given an outlier observation when estimating the anomaly scores with the inverse density scorer then report the outlier node" {
  let scores = anomaly_scores_of_model(
    fn() { @gcm.AnomalyScorer::inverse_density() },
    15,
  )
  assert_eq(anomaly_largest(scores), "X1")
}

///|
test "given an outlier observation when estimating the anomaly scores with the information theoretic scorer then report the outlier node" {
  let scores = anomaly_scores_of_model(
    fn() {
      @gcm.AnomalyScorer::information_theoretic(
        @gcm.AnomalyScorer::median_cdf_quantile(),
      )
    },
    16,
  )
  assert_eq(anomaly_largest(scores), "X1")
}

///|
test "given an outlier observation when estimating the anomaly scores with the information theoretic scorer of the rescaled scorer then report the outlier node" {
  let scores = anomaly_scores_of_model(
    fn() {
      @gcm.AnomalyScorer::information_theoretic(
        @gcm.AnomalyScorer::rescaled_median_cdf_quantile(),
      )
    },
    17,
  )
  assert_eq(anomaly_largest(scores), "X1")
}

///|
test "given an outlier observation when estimating the anomaly scores with the information theoretic scorer of the mean deviation scorer then report the outlier node" {
  let scores = anomaly_scores_of_model(
    fn() {
      @gcm.AnomalyScorer::information_theoretic(
        @gcm.AnomalyScorer::mean_deviation(),
      )
    },
    18,
  )
  assert_eq(anomaly_largest(scores), "X1")
}

///|
test "given an outlier observation when estimating the anomaly scores with the information theoretic scorer of the median deviation scorer then report the outlier node" {
  let scores = anomaly_scores_of_model(
    fn() {
      @gcm.AnomalyScorer::information_theoretic(
        @gcm.AnomalyScorer::median_deviation(),
      )
    },
    19,
  )
  assert_eq(anomaly_largest(scores), "X1")
}

///|
test "given simple linear data when estimating the conditional anomaly scores then return the expected result" {
  let rng = anomaly_rng(2)
  let x = anomaly_normals(rng, ANOMALY_NUM_ROWS)
  let noise = anomaly_normals(rng, ANOMALY_NUM_ROWS)
  let y = anomaly_sum(anomaly_scaled(x, 2.0), noise)
  let mechanism = @gcm.CausalMechanism::additive_noise(
    @gcm.PredictionModel::linear(),
  ).fit(@utils.Matrix::from_columns([x]), y)
  let parents : Array[Double] = []
  let targets : Array[Double] = []
  for i in 0..<5 {
    parents.push(x[i])
    targets.push(y[i])
  }
  let scores = @gcm.conditional_anomaly_scores(
    @utils.Matrix::from_columns([parents]),
    targets,
    mechanism,
    fn() { @gcm.AnomalyScorer::mean_deviation() },
    ANOMALY_NUM_SAMPLES,
    anomaly_rng(3),
  )
  let residuals : Array[Double] = []
  for i in 0..<5 {
    residuals.push(noise[i])
  }
  let expected = anomaly_scores_of(
    @gcm.AnomalyScorer::mean_deviation(),
    noise,
    residuals,
  )
  assert_eq(scores.length(), expected.length())
  for i in 0..<scores.length() {
    assert_true((scores[i] - expected[i]).abs() <= 0.1)
  }
}
