///|
/// The tests of the intrinsic causal influence of the `gcm` package.
///
/// The expectations are the ones of the upstream tests of
/// `dowhy.gcm.influence`, which are in `tests/gcm/test_intrinsic_influence.py`.
/// Every test of the upstream that uses a categorical target has a counterpart
/// here. The last one of them has every node of its graph categorical, so the
/// root node of its model has a categorical distribution and the noise of that
/// root node is a category and not a number; the layer encodes such a noise
/// term with the one-hot encoder, the way the upstream encodes the data of its
/// independence tests.
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
/// The seed of the fixture of the categorical intrinsic causal influence.
const ICC_CATEGORICAL_SEED : UInt64 = 2061UL

///|
/// The seed of the fixture of the complex categorical intrinsic causal
/// influence.
const ICC_COMPLEX_CATEGORICAL_SEED : UInt64 = 2062UL

///|
/// The seed of the fixture of the fully categorical intrinsic causal influence.
const ICC_ONLY_CATEGORICAL_SEED : UInt64 = 2063UL

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
/// The data of the fixture of the categorical intrinsic causal influence.
///
/// The target is the sign of the value of its parent plus its noise, the way
/// the upstream builds it in the case
/// `test_given_categorical_data_when_estimate_intrinsic_causal_influence_then_returns_expected_results`.
fn icc_categorical_data() -> @api.DataFrame {
  let rng = @utils.Random::new(ICC_CATEGORICAL_SEED)
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
  let labels : Array[String] = []
  for i in 0..<ICC_ROWS {
    if x2[i] + rng.next_normal() >= 0.0 {
      labels.push("True")
    } else {
      labels.push("False")
    }
  }
  let frame = @api.DataFrame::from_numeric(
    ["X0", "X1", "X2"],
    Map([("X0", x0), ("X1", x1), ("X2", x2)]),
  )
  frame.with_discrete("X3", labels)
}

///|
/// The data of the fixture of the complex categorical intrinsic causal
/// influence.
///
/// The target is a mixture of three shifted Gaussians, cut at its median, the
/// way the upstream builds it in the case
/// `test_given_more_complex_categorical_data_when_estimate_intrinsic_causal_influence_then_returns_expected_results`.
fn icc_complex_categorical_data() -> @api.DataFrame {
  let rng = @utils.Random::new(ICC_COMPLEX_CATEGORICAL_SEED)
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
  let values : Array[Double] = []
  for i in 0..<ICC_ROWS {
    let offset = match rng.next_int(3) {
      0 => -5.0
      1 => 10.0
      _ => 5.0
    }
    values.push(x2[i] + offset + 0.5 * rng.next_normal())
  }
  let median = @utils.median(values)
  let labels : Array[String] = []
  for value in values {
    if value > median {
      labels.push("True")
    } else {
      labels.push("False")
    }
  }
  let frame = @api.DataFrame::from_numeric(
    ["X0", "X1", "X2"],
    Map([("X0", x0), ("X1", x1), ("X2", x2)]),
  )
  frame.with_discrete("X3", labels)
}

///|
/// The labels of the sign of the given values.
fn icc_sign_labels(values : Array[Double]) -> Array[String] {
  let labels : Array[String] = []
  for value in values {
    if value >= 0.0 {
      labels.push("True")
    } else {
      labels.push("False")
    }
  }
  labels
}

///|
/// The data of the fixture of the fully categorical intrinsic causal influence.
///
/// Every node of the graph holds a category, and the category of a node is the
/// sign of the value of the node, the way the upstream builds it in the case
/// `test_given_only_categorical_data_when_estimate_icc_then_does_not_fail`.
fn icc_only_categorical_data() -> @api.DataFrame {
  let rng = @utils.Random::new(ICC_ONLY_CATEGORICAL_SEED)
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
  let labels : Array[String] = []
  for i in 0..<ICC_ROWS {
    if x2[i] + rng.next_normal() >= 0.0 {
      labels.push("True")
    } else {
      labels.push("False")
    }
  }
  @api.DataFrame::new(
    ["X0", "X1", "X2", "X3"],
    Map([
      ("X0", @api.Column::discrete(icc_sign_labels(x0))),
      ("X1", @api.Column::discrete(icc_sign_labels(x1))),
      ("X2", @api.Column::discrete(icc_sign_labels(x2))),
      ("X3", @api.Column::discrete(labels)),
    ]),
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
/// difference of the two shapes instead, because the function of the upstream
/// is a plain function here and cannot raise.
struct IccShapeRecorder {
  mut row_difference : Int32
  mut column_difference : Int32
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
  let recorder = { row_difference: 0, column_difference: 0, }
  let attribution = fn(
    predictions : @utils.Matrix,
    baseline : @utils.Matrix,
  ) -> Double {
    recorder.row_difference = recorder.row_difference +
      predictions.nrows() -
      baseline.nrows()
    recorder.column_difference = recorder.column_difference +
      predictions.ncols() -
      baseline.ncols()
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
  assert_eq(recorder.row_difference, 0)
  assert_eq(recorder.column_difference, 0)
}

///|
/// test "the intrinsic causal influence of a categorical target is the drop of the entropy of the target"
///
/// This is the port of the upstream test
/// `test_given_categorical_data_when_estimate_intrinsic_causal_influence_then_returns_expected_results`.
/// The upstream measures the contribution of a noise term with the drop of the
/// entropy of the target, and the port does the same.
test "the intrinsic causal influence of a categorical target is the drop of the entropy of the target" {
  let data = icc_categorical_data()
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
      ICC_CATEGORICAL_SEED,
    ),
    @utils.Random::new(ICC_CATEGORICAL_SEED),
  )
  let of_x0 = icc_of(influence, "X0")
  let of_x1 = icc_of(influence, "X1")
  let of_x2 = icc_of(influence, "X2")
  let of_x3 = icc_of(influence, "X3")
  // The contributions of the upstream on the rows of the port are `0.158549`,
  // `0.000032`, `0.402891` and `0.131163`; the port gives `0.148440`,
  // `0.000034`, `0.413516` and `0.129589`. The upstream fits its classifier with
  // a histogram gradient boosting and the port with the classifier of its own
  // zoo, so the numbers differ a little. The tolerance is the one of the
  // upstream.
  assert_true((of_x0 - 0.158549414643).abs() <= 0.05)
  assert_true((of_x1 - 0.000031541531).abs() <= 0.05)
  assert_true((of_x2 - 0.402891197751).abs() <= 0.05)
  assert_true((of_x3 - 0.131162939217).abs() <= 0.05)
}

///|
/// test "the intrinsic causal influence of a categorical target with an approximate model is the drop of the entropy of the target"
///
/// This is the second half of the upstream test
/// `test_given_categorical_data_when_estimate_intrinsic_causal_influence_then_returns_expected_results`.
/// The upstream measures the contribution of a noise term with the drop of the
/// entropy of the target, and the port does the same.
test "the intrinsic causal influence of a categorical target with an approximate model is the drop of the entropy of the target" {
  let data = icc_categorical_data()
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
      ICC_CATEGORICAL_SEED,
    ),
    @utils.Random::new(ICC_CATEGORICAL_SEED),
  )
  let of_x0 = icc_of(influence, "X0")
  let of_x1 = icc_of(influence, "X1")
  let of_x2 = icc_of(influence, "X2")
  let of_x3 = icc_of(influence, "X3")
  // The contributions of the upstream on the rows of the port are `0.127412`,
  // `0.000000`, `0.388305` and `0.108831`; the port gives `0.116253`,
  // `0.000000`, `0.374219` and `0.089314`. The tolerance is the one of the
  // upstream.
  assert_true((of_x0 - 0.127411940313).abs() <= 0.05)
  assert_true((of_x1 - 0.0).abs() <= 0.05)
  assert_true((of_x2 - 0.388304672417).abs() <= 0.05)
  assert_true((of_x3 - 0.108830541288).abs() <= 0.05)
}

///|
/// test "the intrinsic causal influence of a categorical target with a mixed relation is the drop of the entropy of the target"
///
/// This is the port of the upstream test
/// `test_given_more_complex_categorical_data_when_estimate_intrinsic_causal_influence_then_returns_expected_results`.
/// The relation of the target is a mixture of three shifted Gaussians, cut at
/// its median.
test "the intrinsic causal influence of a categorical target with a mixed relation is the drop of the entropy of the target" {
  let data = icc_complex_categorical_data()
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
      ICC_COMPLEX_CATEGORICAL_SEED,
    ),
    @utils.Random::new(ICC_COMPLEX_CATEGORICAL_SEED),
  )
  let of_x0 = icc_of(influence, "X0")
  let of_x1 = icc_of(influence, "X1")
  let of_x2 = icc_of(influence, "X2")
  let of_x3 = icc_of(influence, "X3")
  // The contributions of the upstream on the rows of the port are `0.050641`,
  // `0.000012`, `0.124818` and `0.515082`; the port gives `0.035892`,
  // `0.000008`, `0.124807` and `0.530887`. The tolerance is the one of the
  // upstream.
  assert_true((of_x0 - 0.050641005772).abs() <= 0.05)
  assert_true((of_x1 - 0.000011921169).abs() <= 0.05)
  assert_true((of_x2 - 0.124817514226).abs() <= 0.05)
  assert_true((of_x3 - 0.515082495248).abs() <= 0.1)
}

///|
/// test "the intrinsic causal influence of a categorical target with a mixed relation and an approximate model is the drop of the entropy of the target"
///
/// This is the second half of the upstream test
/// `test_given_more_complex_categorical_data_when_estimate_intrinsic_causal_influence_then_returns_expected_results`.
test "the intrinsic causal influence of a categorical target with a mixed relation and an approximate model is the drop of the entropy of the target" {
  let data = icc_complex_categorical_data()
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
      ICC_COMPLEX_CATEGORICAL_SEED,
    ),
    @utils.Random::new(ICC_COMPLEX_CATEGORICAL_SEED),
  )
  let of_x0 = icc_of(influence, "X0")
  let of_x1 = icc_of(influence, "X1")
  let of_x2 = icc_of(influence, "X2")
  let of_x3 = icc_of(influence, "X3")
  // The contributions of the upstream on the rows of the port are `0.036602`,
  // `0.000000`, `0.109529` and `0.502962`; the port gives `0.016572`,
  // `0.000000`, `0.095175` and `0.464068`. The tolerance is the one of the
  // upstream.
  assert_true((of_x0 - 0.036601813904).abs() <= 0.05)
  assert_true((of_x1 - 0.0).abs() <= 0.05)
  assert_true((of_x2 - 0.109528747032).abs() <= 0.05)
  assert_true((of_x3 - 0.502961592549).abs() <= 0.1)
}

///|
/// test "the intrinsic causal influence of a target whose every ancestor holds
/// a category is the drop of the entropy of the target"
///
/// This is the port of the upstream test
/// `test_given_only_categorical_data_when_estimate_icc_then_does_not_fail`.
/// The noise of the root node of the model is a category, so the noise
/// features of the ancestors hold a column of categories, and the layer
/// encodes it with the one-hot encoder.
test "the intrinsic causal influence of a target whose every ancestor holds a category is the drop of the entropy of the target" {
  let data = icc_only_categorical_data()
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
      ICC_ONLY_CATEGORICAL_SEED,
    ),
    @utils.Random::new(ICC_ONLY_CATEGORICAL_SEED),
  )
  let of_x0 = icc_of(influence, "X0")
  let of_x1 = icc_of(influence, "X1")
  let of_x2 = icc_of(influence, "X2")
  let of_x3 = icc_of(influence, "X3")
  // The contributions of the upstream on the rows of the port are `0.085429`,
  // `0.0`, `0.359338` and `0.246331`; the tolerance is the one of the upstream.
  assert_true((of_x0 - 0.085429188985).abs() <= 0.03)
  assert_true((of_x1 - 0.0).abs() <= 0.005)
  assert_true((of_x2 - 0.359337828053).abs() <= 0.05)
  assert_true((of_x3 - 0.246330763125).abs() <= 0.05)
}

///|
/// test "the intrinsic causal influence of a target whose every ancestor holds
/// a category with an approximate model is the drop of the entropy of the
/// target"
///
/// This is the second half of the upstream test
/// `test_given_only_categorical_data_when_estimate_icc_then_does_not_fail`.
test "the intrinsic causal influence of a target whose every ancestor holds a category with an approximate model is the drop of the entropy of the target" {
  let data = icc_only_categorical_data()
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
      ICC_ONLY_CATEGORICAL_SEED,
    ),
    @utils.Random::new(ICC_ONLY_CATEGORICAL_SEED),
  )
  let of_x0 = icc_of(influence, "X0")
  let of_x1 = icc_of(influence, "X1")
  let of_x2 = icc_of(influence, "X2")
  let of_x3 = icc_of(influence, "X3")
  // The contributions of the upstream on the rows of the port are `0.081505`,
  // `0.0`, `0.322547` and `0.288294`, and the port gives `0.047111`,
  // `-0.000384`, `0.224529` and `0.101078`. The upstream fits its classifier
  // with a histogram gradient boosting, whose probabilities are soft, and the
  // zoo of the port has the logistic regression and the polynomial logistic
  // regression only, whose probabilities are sharper. The relation of the case
  // is a composition of thresholds, which a logistic regression captures
  // poorly, so the drop of the entropy of the port is smaller than the one of
  // the upstream. The test records the numbers of the port.
  assert_true((of_x0 - 0.04711139341918133).abs() <= 1.0e-9)
  assert_true((of_x1 - -0.000384466112131295).abs() <= 1.0e-9)
  assert_true((of_x2 - 0.2245289955849185).abs() <= 1.0e-9)
  assert_true((of_x3 - 0.10107756137626643).abs() <= 1.0e-9)
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
