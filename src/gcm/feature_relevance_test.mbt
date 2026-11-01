///|
/// The tests of the feature relevance of the `gcm` package.
///
/// The expectations are the ones of the upstream tests of
/// `dowhy.gcm.feature_relevance`, which are in
/// `tests/gcm/test_feature_relevance.py`. The two tests of the upstream that
/// use a classifier as the model have no counterpart here, because the
/// predictions of a classifier are a probability per class and the port's
/// prediction method returns one number per row.
///
/// The fixtures are drawn with the deterministic generator of the `utils`
/// package. The upstream draws its samples with the global generator of numpy
/// and with a number of players and of samples that the exact method of the
/// Shapley values cannot afford, so the fixtures of the port are smaller; the
/// relations the upstream asserts hold for every size of the fixture.

///|
/// The seed of the fixture of the feature relevance of a linear model.
const FEATURE_RELEVANCE_SEED : UInt64 = 2050UL

///|
/// The seed of the fixture of the coefficients of the linear model.
const FEATURE_RELEVANCE_COEFFICIENT_SEED : UInt64 = 2051UL

///|
/// The seed of the fixture of the parent relevance.
const FEATURE_RELEVANCE_PARENT_SEED : UInt64 = 2052UL

///|
/// The number of rows of the fixture of the linear model.
const FEATURE_RELEVANCE_ROWS : Int32 = 200

///|
/// The number of the inputs of the linear model.
const FEATURE_RELEVANCE_INPUTS : Int32 = 5

///|
/// The number of the samples of the baseline.
const FEATURE_RELEVANCE_BASELINE : Int32 = 20

///|
/// The tolerance of the comparison of the numbers of the reference script.
const FEATURE_RELEVANCE_TOLERANCE : Double = 1.0e-9

///|
/// Whether two numbers agree to the tolerance of the comparison.
fn feature_relevance_near(a : Double, b : Double, tolerance : Double) -> Bool {
  (a - b).abs() <= tolerance
}

///|
/// A matrix of standard normal draws.
fn feature_relevance_normal_matrix(
  seed : UInt64,
  rows : Int32,
  columns : Int32,
) -> @utils.Matrix {
  let rng = @utils.Random::new(seed)
  let values : Array[Array[Double]] = []
  for _ in 0..<rows {
    let row : Array[Double] = []
    for _ in 0..<columns {
      row.push(rng.next_normal())
    }
    values.push(row)
  }
  @utils.Matrix::from_rows(values)
}

///|
/// The coefficients of a linear model, whole numbers between minus ten and
/// nine.
fn feature_relevance_coefficients(
  seed : UInt64,
  count : Int32,
) -> Array[Double] {
  let rng = @utils.Random::new(seed)
  let coefficients : Array[Double] = []
  for _ in 0..<count {
    coefficients.push((rng.next_int(20) - 10).to_double())
  }
  coefficients
}

///|
/// The linear model of the given coefficients.
fn feature_relevance_linear_model(
  coefficients : Array[Double],
) -> (@utils.Matrix) -> Array[Double] {
  fn(inputs : @utils.Matrix) -> Array[Double] {
    let out : Array[Double] = []
    for i in 0..<inputs.nrows() {
      let mut total = 0.0
      for j in 0..<coefficients.length() {
        total = total + coefficients[j] * inputs.get(i, j)
      }
      out.push(total)
    }
    out
  }
}

///|
/// The mean of every column of the matrix.
fn feature_relevance_column_means(m : @utils.Matrix) -> Array[Double] {
  let means : Array[Double] = []
  for j in 0..<m.ncols() {
    means.push(@utils.mean(m.col(j)))
  }
  means
}

///|
/// The first rows of the matrix.
fn feature_relevance_first_rows(
  m : @utils.Matrix,
  count : Int32,
) -> @utils.Matrix {
  let rows : Array[Array[Double]] = []
  for i in 0..<count {
    rows.push(m.row(i))
  }
  @utils.Matrix::from_rows(rows)
}

///|
/// The number of the samples of the parents of the parent relevance.
const FEATURE_RELEVANCE_PARENT_SAMPLES : Int32 = 1000

///|
/// The number of the samples of the baseline of the parent relevance.
const FEATURE_RELEVANCE_PARENT_BASELINE : Int32 = 200

///|
/// The graph of the parent relevance, whose node has the parents `X0` and
/// `X1`.
fn feature_relevance_parent_graph() -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X1", "X2")
  graph.add_edge("X0", "X2")
  graph
}

///|
/// The model of the parent relevance, whose target is `X2 = 3 * X0 + X1`.
fn feature_relevance_parent_model(
  data : @api.DataFrame,
) -> @gcm.ProbabilisticCausalModel {
  let model = @gcm.ProbabilisticCausalModel::new(
    feature_relevance_parent_graph(),
  )
  model.set_root_model("X0", @gcm.StochasticModel::normal(0.0, 1.0))
  model.set_root_model("X1", @gcm.StochasticModel::normal(0.0, 1.0))
  model.set_causal_mechanism(
    "X2",
    @gcm.CausalMechanism::additive_noise(@gcm.PredictionModel::linear()),
  )
  @gcm.fit(model, data)
  model
}

///|
/// The data of the parent relevance, whose target is `X2 = 3 * X0 + X1`.
fn feature_relevance_parent_data() -> @api.DataFrame {
  let rng = @utils.Random::new(FEATURE_RELEVANCE_PARENT_SEED)
  let x0 : Array[Double] = []
  for _ in 0..<FEATURE_RELEVANCE_PARENT_SAMPLES {
    x0.push(rng.next_normal())
  }
  let x1 : Array[Double] = []
  for _ in 0..<FEATURE_RELEVANCE_PARENT_SAMPLES {
    x1.push(rng.next_normal())
  }
  let x2 : Array[Double] = []
  for i in 0..<FEATURE_RELEVANCE_PARENT_SAMPLES {
    x2.push(3.0 * x0[i] + x1[i])
  }
  @api.DataFrame::from_numeric(
    ["X0", "X1", "X2"],
    Map([("X0", x0), ("X1", x1), ("X2", x2)]),
  )
}

///|
/// The relevance of a parent of the target node.
fn feature_relevance_of_parent(
  relevance : Array[(String, Double)],
  parent : String,
) -> Double {
  for entry in relevance {
    let (name, value) = entry
    if name == parent {
      return value
    }
  }
  abort("the parent " + parent + " has no relevance")
}

///|
test "the feature relevance of the parents of a node is the variance of its contribution" {
  let data = feature_relevance_parent_data()
  let model = feature_relevance_parent_model(data)
  let (relevance, noise) = @gcm.parent_relevance(
    model,
    "X2",
    None,
    None,
    FEATURE_RELEVANCE_PARENT_SAMPLES,
    FEATURE_RELEVANCE_PARENT_BASELINE,
    100,
    @gcm.ShapleyConfig::new(@gcm.ShapleyApproximationMethod::auto()).with_seed(
      FEATURE_RELEVANCE_PARENT_SEED,
    ),
    @utils.Random::new(FEATURE_RELEVANCE_PARENT_SEED),
  )
  let of_x0 = feature_relevance_of_parent(relevance, "X0")
  let of_x1 = feature_relevance_of_parent(relevance, "X1")
  // The contribution of `X0` is the variance of three times `X0` and the
  // contribution of `X1` is the variance of `X1`.
  assert_true((of_x0 - 9.0).abs() <= 1.0)
  assert_true((of_x1 - 1.0).abs() <= 0.3)
  assert_true(noise[0].abs() <= 0.5)
  // The contributions add up to the variance of the target.
  let variance = @utils.var_pop(data.numeric("X2"))
  assert_true((of_x0 + of_x1 + noise[0] - variance).abs() <= 1.5)
}

///|
test "the feature relevance of the parents of a node does not depend on a missing edge" {
  let data = feature_relevance_parent_data()
  // The model without the edge between `X0` and `X1`.
  let without_edge = @gcm.ProbabilisticCausalModel::new(
    feature_relevance_parent_graph(),
  )
  let _ = @gcm.assign_causal_mechanisms(
    without_edge,
    data,
    @gcm.AssignmentQuality::good(),
    false,
  )
  @gcm.fit(without_edge, data)
  // The model with the edge between `X0` and `X1`.
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "X1")
  graph.add_edge("X0", "X2")
  graph.add_edge("X1", "X2")
  let with_edge_model = @gcm.ProbabilisticCausalModel::new(graph)
  let _ = @gcm.assign_causal_mechanisms(
    with_edge_model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
  )
  @gcm.fit(with_edge_model, data)
  let config = @gcm.ShapleyConfig::new(@gcm.ShapleyApproximationMethod::auto()).with_seed(
    FEATURE_RELEVANCE_PARENT_SEED,
  )
  let (missing_edge, _) = @gcm.parent_relevance(
    without_edge,
    "X2",
    Some(data),
    None,
    FEATURE_RELEVANCE_PARENT_SAMPLES,
    FEATURE_RELEVANCE_PARENT_BASELINE,
    100,
    config,
    @utils.Random::new(FEATURE_RELEVANCE_PARENT_SEED),
  )
  let (with_edge, _) = @gcm.parent_relevance(
    with_edge_model,
    "X2",
    None,
    None,
    FEATURE_RELEVANCE_PARENT_SAMPLES,
    FEATURE_RELEVANCE_PARENT_BASELINE,
    100,
    config,
    @utils.Random::new(FEATURE_RELEVANCE_PARENT_SEED),
  )
  let missing_x0 = feature_relevance_of_parent(missing_edge, "X0")
  let missing_x1 = feature_relevance_of_parent(missing_edge, "X1")
  let present_x0 = feature_relevance_of_parent(with_edge, "X0")
  let present_x1 = feature_relevance_of_parent(with_edge, "X1")
  // The upstream compares the two numbers with an absolute tolerance of 0.15,
  // which is less than two percent of the relevance of `X0` and seven percent
  // of the relevance of `X1`; the port compares them with a relative tolerance
  // of ten percent, because the fixture of the port holds fewer samples than
  // the one of the upstream.
  assert_true((missing_x0 - present_x0).abs() <= 0.1 * present_x0.abs())
  assert_true((missing_x1 - present_x1).abs() <= 0.1 * present_x1.abs())
}

///|
test "the feature relevance of a linear model is the contribution of every input" {
  let samples = feature_relevance_normal_matrix(
    FEATURE_RELEVANCE_SEED,
    FEATURE_RELEVANCE_ROWS,
    FEATURE_RELEVANCE_INPUTS,
  )
  let coefficients = feature_relevance_coefficients(
    FEATURE_RELEVANCE_COEFFICIENT_SEED,
    FEATURE_RELEVANCE_INPUTS,
  )
  let baseline = feature_relevance_first_rows(
    samples,
    FEATURE_RELEVANCE_BASELINE,
  )
  let relevance = @gcm.feature_relevance_sample(
    feature_relevance_linear_model(coefficients),
    samples,
    baseline,
    @gcm.means_difference,
    None,
    false,
    100,
    true,
    @gcm.ShapleyConfig::new(@gcm.ShapleyApproximationMethod::auto()).with_seed(
      FEATURE_RELEVANCE_SEED,
    ),
    @utils.Random::new(FEATURE_RELEVANCE_SEED),
  )
  assert_eq(relevance.nrows(), FEATURE_RELEVANCE_BASELINE)
  assert_eq(relevance.ncols(), FEATURE_RELEVANCE_INPUTS)
  // The relevance of an input of a linear model is its coefficient times the
  // difference of the sample and the mean of the column.
  let means = feature_relevance_column_means(samples)
  for i in 0..<FEATURE_RELEVANCE_BASELINE {
    for j in 0..<FEATURE_RELEVANCE_INPUTS {
      let expected = coefficients[j] * (samples.get(i, j) - means[j])
      assert_true(
        feature_relevance_near(
          relevance.get(i, j),
          expected,
          FEATURE_RELEVANCE_TOLERANCE,
        ),
      )
    }
  }
}

///|
test "the feature relevance of a linear model with given baseline values scales with the baseline" {
  let samples = feature_relevance_normal_matrix(
    FEATURE_RELEVANCE_SEED,
    FEATURE_RELEVANCE_ROWS,
    FEATURE_RELEVANCE_INPUTS,
  )
  let coefficients = feature_relevance_coefficients(
    FEATURE_RELEVANCE_COEFFICIENT_SEED,
    FEATURE_RELEVANCE_INPUTS,
  )
  let baseline = feature_relevance_first_rows(
    samples,
    FEATURE_RELEVANCE_BASELINE,
  )
  let scoring = fn(randomized : Array[Double], base : Array[Double]) -> Double {
    @utils.mean(randomized) * base[0]
  }
  let zeros : Array[Double] = []
  let ones : Array[Double] = []
  let twos : Array[Double] = []
  for _ in 0..<FEATURE_RELEVANCE_BASELINE {
    zeros.push(0.0)
    ones.push(1.0)
    twos.push(2.0)
  }
  let with_zeros = @gcm.feature_relevance_sample(
    feature_relevance_linear_model(coefficients),
    samples,
    baseline,
    scoring,
    Some(zeros),
    false,
    100,
    true,
    @gcm.ShapleyConfig::new(@gcm.ShapleyApproximationMethod::exact()).with_seed(
      FEATURE_RELEVANCE_SEED,
    ),
    @utils.Random::new(FEATURE_RELEVANCE_SEED),
  )
  let with_ones = @gcm.feature_relevance_sample(
    feature_relevance_linear_model(coefficients),
    samples,
    baseline,
    scoring,
    Some(ones),
    false,
    100,
    true,
    @gcm.ShapleyConfig::new(@gcm.ShapleyApproximationMethod::exact()).with_seed(
      FEATURE_RELEVANCE_SEED,
    ),
    @utils.Random::new(FEATURE_RELEVANCE_SEED),
  )
  let with_twos = @gcm.feature_relevance_sample(
    feature_relevance_linear_model(coefficients),
    samples,
    baseline,
    scoring,
    Some(twos),
    false,
    100,
    true,
    @gcm.ShapleyConfig::new(@gcm.ShapleyApproximationMethod::exact()).with_seed(
      FEATURE_RELEVANCE_SEED,
    ),
    @utils.Random::new(FEATURE_RELEVANCE_SEED),
  )
  for i in 0..<FEATURE_RELEVANCE_BASELINE {
    for j in 0..<FEATURE_RELEVANCE_INPUTS {
      assert_true(
        feature_relevance_near(
          with_zeros.get(i, j),
          0.0,
          FEATURE_RELEVANCE_TOLERANCE,
        ),
      )
      assert_true(
        feature_relevance_near(
          with_twos.get(i, j),
          2.0 * with_ones.get(i, j),
          FEATURE_RELEVANCE_TOLERANCE,
        ),
      )
    }
  }
}

///|
test "the feature relevance of a linear model does not depend on the batch size" {
  let samples = feature_relevance_normal_matrix(
    FEATURE_RELEVANCE_SEED,
    FEATURE_RELEVANCE_ROWS,
    3,
  )
  let coefficients = feature_relevance_coefficients(
    FEATURE_RELEVANCE_COEFFICIENT_SEED,
    3,
  )
  let relevance = @gcm.feature_relevance_sample(
    feature_relevance_linear_model(coefficients),
    samples,
    samples,
    @gcm.means_difference,
    None,
    false,
    123,
    true,
    @gcm.ShapleyConfig::new(@gcm.ShapleyApproximationMethod::auto()).with_seed(
      FEATURE_RELEVANCE_SEED,
    ),
    @utils.Random::new(FEATURE_RELEVANCE_SEED),
  )
  assert_eq(relevance.nrows(), FEATURE_RELEVANCE_ROWS)
  assert_eq(relevance.ncols(), 3)
  let means = feature_relevance_column_means(samples)
  for i in 0..<FEATURE_RELEVANCE_ROWS {
    for j in 0..<3 {
      let expected = coefficients[j] * (samples.get(i, j) - means[j])
      assert_true(
        feature_relevance_near(
          relevance.get(i, j),
          expected,
          FEATURE_RELEVANCE_TOLERANCE,
        ),
      )
    }
  }
}

///|
test "the feature relevance of the whole distribution of a linear model is the average of the relevance of its samples" {
  let samples = feature_relevance_normal_matrix(
    FEATURE_RELEVANCE_SEED,
    FEATURE_RELEVANCE_ROWS,
    FEATURE_RELEVANCE_INPUTS,
  )
  let coefficients = feature_relevance_coefficients(
    FEATURE_RELEVANCE_COEFFICIENT_SEED,
    FEATURE_RELEVANCE_INPUTS,
  )
  let relevance = @gcm.feature_relevance_distribution(
    feature_relevance_linear_model(coefficients),
    samples,
    @gcm.means_difference,
    FEATURE_RELEVANCE_ROWS,
    FEATURE_RELEVANCE_ROWS,
    100,
    true,
    @gcm.ShapleyConfig::new(@gcm.ShapleyApproximationMethod::auto()).with_seed(
      FEATURE_RELEVANCE_SEED,
    ),
    @utils.Random::new(FEATURE_RELEVANCE_SEED),
  )
  assert_eq(relevance.nrows(), 1)
  assert_eq(relevance.ncols(), FEATURE_RELEVANCE_INPUTS)
  // The relevance of an input of a linear model is its coefficient times the
  // difference of the mean of the column and the mean of the samples, and the
  // baseline holds every sample of the column here.
  let means = feature_relevance_column_means(samples)
  for j in 0..<FEATURE_RELEVANCE_INPUTS {
    assert_true(
      feature_relevance_near(
        relevance.get(0, j),
        0.0,
        FEATURE_RELEVANCE_TOLERANCE,
      ),
    )
    assert_true(means[j].abs() < 1.0)
  }
}
