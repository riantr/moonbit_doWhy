///|
/// The tests of the mechanism evaluation layer of the `gcm` package.
///
/// The upstream reference of the layer is
/// `_verify/gcm_model_evaluation_reference.py`, which runs the upstream
/// `dowhy.gcm.model_evaluation` on the fixtures of the layer. The fixtures of
/// the port are drawn from the generator of the `utils` package, and the
/// reference script reproduces that generator, so that the fixtures of the port
/// and the fixtures of the reference are the same numbers.
///
/// The metrics of the layer are of two kinds. The normalised mean squared error
/// and the score of the continuous ranked probability score of a deterministic
/// mechanism are the same numbers as the ones of the upstream, and the tests
/// compare them with a tight tolerance. The scores of the mechanisms with a
/// noise and the scores of the mechanisms of the evaluation of a model depend
/// on the draws of the noise and on the folds of the cross validation, which
/// the upstream draws from the global generator of numpy and the port draws
/// from the generator of the `utils` package. The tests of these numbers use
/// the tolerances of the upstream test file
/// `tests/gcm/test_model_evaluation.py`.

///|
/// The seed of the generators of the fixtures.
const EVALUATION_SEED : UInt64 = 2025

///|
/// The number of the rows of the fixtures of the metrics.
const EVALUATION_NUM_ROWS : Int32 = 1000

///|
/// The number of the rows of the fixtures of the evaluation of a model.
const EVALUATION_NUM_ROWS_EVAL : Int32 = 500

///|
/// The number of the permutations of the falsification of the graph.
const EVALUATION_NUM_PERMUTATIONS : Int32 = 5

///|
/// The generator of the fixture with the given index.
fn evaluation_rng(index : UInt64) -> @utils.Random {
  @utils.Random::new(EVALUATION_SEED + index)
}

///|
/// The given number of the samples of the normal distribution.
fn evaluation_normals(rng : @utils.Random, count : Int32) -> Array[Double] {
  let out : Array[Double] = []
  for _ in 0..<count {
    out.push(rng.next_normal())
  }
  out
}

///|
/// The values of the given samples, multiplied by the given factor.
fn evaluation_scaled(values : Array[Double], factor : Double) -> Array[Double] {
  let out : Array[Double] = []
  for value in values {
    out.push(factor * value)
  }
  out
}

///|
/// The values of the given samples, shifted by the given offset.
fn evaluation_offset(values : Array[Double], offset : Double) -> Array[Double] {
  let out : Array[Double] = []
  for value in values {
    out.push(value + offset)
  }
  out
}

///|
/// The sum of the given samples and of the given noise.
fn evaluation_sum(
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
/// The labels of the given samples, which are positive when the sample is
/// positive.
fn evaluation_labels(values : Array[Double]) -> Array[String] {
  let out : Array[String] = []
  for value in values {
    if value > 0.0 {
      out.push("True")
    } else {
      out.push("False")
    }
  }
  out
}

///|
/// Whether two numbers are close to each other.
///
/// The comparison is relative, because the numbers of the layer span many
/// orders of magnitude.
fn evaluation_close(
  actual : Double,
  expected : Double,
  tolerance : Double,
) -> Bool {
  let scale = expected.abs()
  if scale < 1.0e-300 {
    (actual - expected).abs() <= 1.0e-300
  } else {
    (actual - expected).abs() <= tolerance * scale
  }
}

///|
/// The matrix of the given values.
fn evaluation_matrix(values : Array[Double]) -> @utils.Matrix {
  @utils.Matrix::from_columns([values])
}

///|
/// The additive noise mechanism with the given coefficient and noise.
fn evaluation_mechanism(
  coefficient : Double,
  scale : Double,
) -> @gcm.CausalMechanism {
  @gcm.CausalMechanism::additive_noise_with(
    @gcm.PredictionModel::with_fixed_parameters([coefficient], 0.0),
    @gcm.StochasticModel::normal(0.0, scale),
  )
}

///|
/// The data frame of the given columns.
fn evaluation_frame(columns : Array[(String, Array[Double])]) -> @api.DataFrame {
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
/// The causal model of the evaluation of a model, with the given data.
fn evaluation_model(frame : @api.DataFrame) -> @gcm.ProbabilisticCausalModel {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "Y")
  graph.add_edge("X1", "Y")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  let _ = @gcm.assign_causal_mechanisms(
    model,
    frame,
    @gcm.AssignmentQuality::better(),
    true,
  )
  @gcm.fit(model, frame)
  model
}

///|
/// The causal model of a chain with one parent, with the given data.
fn evaluation_chain_model(
  frame : @api.DataFrame,
) -> @gcm.ProbabilisticCausalModel {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "Y")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  let _ = @gcm.assign_causal_mechanisms(
    model,
    frame,
    @gcm.AssignmentQuality::better(),
    true,
  )
  @gcm.fit(model, frame)
  model
}

///|
/// The configuration of the evaluation of a model.
///
/// The test of the invertibility assumption is the kernel based test of the
/// package, which is the test of the upstream, because the node of the model
/// has two parents and the generalised covariance measure of the package needs
/// one dimensional variables only.
fn evaluation_config(rng : @utils.Random) -> @gcm.EvaluationConfig {
  @gcm.EvaluationConfig::new()
  .with_independence_test_invertible(@gcm.kernel_independence_test(rng, 2000))
  .with_max_num_permutations_falsify(Some(EVALUATION_NUM_PERMUTATIONS))
}

///|
/// The options of the evaluation of a model.
fn evaluation_options() -> @gcm.EvaluationOptions {
  @gcm.EvaluationOptions::new().with_compare_mechanism_baselines(true)
}

///|
test "given a good fit when estimating the normalised mean squared error then report zero" {
  let rng = evaluation_rng(0)
  let x = evaluation_normals(rng, EVALUATION_NUM_ROWS)
  let y = evaluation_scaled(x, 2.0)
  let mechanism = evaluation_mechanism(2.0, 0.0)
  let conditional = @gcm.estimate_conditional_expectations(
    mechanism,
    evaluation_matrix(x),
  )
  assert_true(evaluation_close(@gcm.nmse(y, conditional, true), 0.0, 1.0e-12))
  assert_true(evaluation_close(@gcm.nmse(y, conditional, false), 0.0, 1.0e-12))
}

///|
test "given a bad fit when estimating the normalised mean squared error then report a high value" {
  let rng = evaluation_rng(1)
  let x = evaluation_normals(rng, EVALUATION_NUM_ROWS)
  let y = evaluation_scaled(x, 2.0)
  let mechanism = evaluation_mechanism(20.0, 0.0)
  let conditional = @gcm.estimate_conditional_expectations(
    mechanism,
    evaluation_matrix(x),
  )
  let squared = @gcm.nmse(y, conditional, true)
  let root = @gcm.nmse(y, conditional, false)
  assert_true(squared > 1.0)
  assert_true(root > 1.0)
  assert_true(evaluation_close(squared, 81.06098605097587, 1.0e-9))
  assert_true(evaluation_close(root, 9.003387476443288, 1.0e-9))
}

///|
test "given a good fit with noisy data when estimating the normalised mean squared error then report the noise" {
  let rng = evaluation_rng(2)
  let x = evaluation_normals(rng, EVALUATION_NUM_ROWS)
  let noise = evaluation_scaled(
    evaluation_normals(rng, EVALUATION_NUM_ROWS),
    2.0,
  )
  let y = evaluation_sum(evaluation_scaled(x, 2.0), noise)
  let mechanism = evaluation_mechanism(2.0, 2.0)
  let conditional = @gcm.estimate_conditional_expectations(
    mechanism,
    evaluation_matrix(x),
  )
  let squared = @gcm.nmse(y, conditional, true)
  let root = @gcm.nmse(y, conditional, false)
  // The mean squared error is the variance of the noise and the root mean
  // squared error is the standard deviation of the noise.
  let variance = @utils.var_pop(y)
  let deviation = @utils.std(y)
  assert_true((squared - 4.0 / variance).abs() <= 0.05)
  assert_true((root - 2.0 / deviation).abs() <= 0.05)
  assert_true(evaluation_close(squared, 0.4991171464953086, 1.0e-9))
  assert_true(evaluation_close(root, 0.7064822336727998, 1.0e-9))
}

///|
test "given a good fit with a deterministic mechanism when estimating the score then report zero" {
  let rng = evaluation_rng(3)
  let x = evaluation_normals(rng, EVALUATION_NUM_ROWS)
  let y = evaluation_scaled(x, 2.0)
  let mechanism = evaluation_mechanism(2.0, 0.0)
  let score = @gcm.crps(
    evaluation_matrix(x),
    y,
    fn(inputs : @utils.Matrix, generator : @utils.Random) {
      mechanism.draw_samples(inputs, generator)
    },
    100,
    true,
    rng,
  )
  assert_true(score.abs() <= 1.0e-12)
}

///|
test "given a bad fit with a deterministic mechanism when estimating the score then report the expected value" {
  let rng = evaluation_rng(4)
  let x = evaluation_normals(rng, EVALUATION_NUM_ROWS)
  let y = x.copy()
  let mechanism = evaluation_mechanism(1.0, 2.0)
  let score = @gcm.crps(
    evaluation_matrix(x),
    y,
    fn(inputs : @utils.Matrix, generator : @utils.Random) {
      mechanism.draw_samples(inputs, generator)
    },
    100,
    true,
    rng,
  )
  assert_true((score - 0.47414353241783724).abs() <= 0.05)
  assert_true(evaluation_close(score, 0.47414353241783724, 0.05))
}

///|
test "given a good fit with noisy data when estimating the score then report the expected value" {
  let rng = evaluation_rng(5)
  let x = evaluation_normals(rng, EVALUATION_NUM_ROWS)
  let y = evaluation_sum(
    evaluation_scaled(x, 2.0),
    evaluation_normals(rng, EVALUATION_NUM_ROWS),
  )
  let mechanism = evaluation_mechanism(2.0, 1.0)
  let score = @gcm.crps(
    evaluation_matrix(x),
    y,
    fn(inputs : @utils.Matrix, generator : @utils.Random) {
      mechanism.draw_samples(inputs, generator)
    },
    100,
    true,
    rng,
  )
  assert_true((score - 0.248516681240651).abs() <= 0.05)
  assert_true(evaluation_close(score, 0.248516681240651, 0.05))
}

///|
test "given a very bad fit with a deterministic mechanism when estimating the score then report a high value" {
  let rng = evaluation_rng(6)
  let x = evaluation_normals(rng, EVALUATION_NUM_ROWS)
  let y = x.copy()
  let mechanism = evaluation_mechanism(100.0, 2.0)
  let score = @gcm.crps(
    evaluation_matrix(x),
    y,
    fn(inputs : @utils.Matrix, generator : @utils.Random) {
      mechanism.draw_samples(inputs, generator)
    },
    100,
    true,
    rng,
  )
  assert_true(score > 1.0)
  assert_true(evaluation_close(score, 76.03087903460342, 0.05))
}

///|
test "given categorical data and a good fit when estimating the score then report the expected value" {
  let rng = evaluation_rng(7)
  let x_fit = evaluation_normals(rng, EVALUATION_NUM_ROWS)
  let y_fit = evaluation_labels(x_fit)
  let classifier = @gcm.ClassificationModel::logistic()
  let mechanism = @gcm.CausalMechanism::classifier(classifier)
  let fitted = mechanism.fit_categorical(evaluation_matrix(x_fit), y_fit)
  let x = evaluation_normals(rng, EVALUATION_NUM_ROWS)
  let y = evaluation_labels(x)
  let score = @gcm.crps_categorical(
    evaluation_matrix(x),
    y,
    fn(inputs : @utils.Matrix, generator : @utils.Random) {
      fitted.draw_categorical_samples(inputs, generator)
    },
    100,
    rng,
  )
  assert_true((score - 0.0219926).abs() <= 0.02)
  assert_true(evaluation_close(score, 0.0219926, 0.02))
}

///|
test "given categorical data and a bad fit when estimating the score then report the expected value" {
  let rng = evaluation_rng(8)
  let x_fit = evaluation_normals(rng, EVALUATION_NUM_ROWS)
  let y_fit = evaluation_labels(x_fit)
  let classifier = @gcm.ClassificationModel::logistic()
  let mechanism = @gcm.CausalMechanism::classifier(classifier)
  let fitted = mechanism.fit_categorical(evaluation_matrix(x_fit), y_fit)
  let x = evaluation_normals(rng, EVALUATION_NUM_ROWS)
  let y = evaluation_labels(evaluation_offset(x, 1.0))
  let score = @gcm.crps_categorical(
    evaluation_matrix(x),
    y,
    fn(inputs : @utils.Matrix, generator : @utils.Random) {
      fitted.draw_categorical_samples(inputs, generator)
    },
    100,
    rng,
  )
  assert_true((score - 0.2822752).abs() <= 0.05)
  assert_true(evaluation_close(score, 0.2822752, 0.05))
}

///|
test "given multiplicative noise when evaluating the invertibility assumption then reject it" {
  let rng = evaluation_rng(9)
  let x0 = evaluation_normals(rng, EVALUATION_NUM_ROWS)
  let noise = evaluation_scaled(
    evaluation_normals(rng, EVALUATION_NUM_ROWS),
    0.1,
  )
  let multiplied : Array[Double] = []
  for i in 0..<x0.length() {
    multiplied.push(x0[i] * noise[i])
  }
  let frame = evaluation_frame([("X0", x0), ("Y", multiplied)])
  let model = evaluation_chain_model(frame)
  let assumptions = @gcm.evaluate_invertibility_assumptions(
    model,
    frame,
    evaluation_config(evaluation_rng(91)),
    evaluation_rng(92),
  )
  let assumption = match assumptions.get("Y") {
    Some(value) => value
    None => abort("the node Y has no assumption of the invertibility")
  }
  assert_true(assumption.rejected())
  assert_true(assumption.p_value() <= 0.05)
  assert_true(assumption.significance_level() == 0.05)
}

///|
test "given additive noise when evaluating the invertibility assumption then do not reject it" {
  let rng = evaluation_rng(10)
  let x0 = evaluation_normals(rng, EVALUATION_NUM_ROWS)
  let noise = evaluation_scaled(
    evaluation_normals(rng, EVALUATION_NUM_ROWS),
    0.1,
  )
  let y = evaluation_sum(x0, noise)
  let frame = evaluation_frame([("X0", x0), ("Y", y)])
  let model = evaluation_chain_model(frame)
  let assumptions = @gcm.evaluate_invertibility_assumptions(
    model,
    frame,
    evaluation_config(evaluation_rng(101)),
    evaluation_rng(102),
  )
  let assumption = match assumptions.get("Y") {
    Some(value) => value
    None => abort("the node Y has no assumption of the invertibility")
  }
  assert_false(assumption.rejected())
  assert_true(assumption.p_value() > 0.05)
  assert_true(assumption.significance_level() == 0.05)
}

///|
test "given continuous data when evaluating a model then report the performance of the mechanisms" {
  let rng = evaluation_rng(11)
  let x0 = evaluation_normals(rng, EVALUATION_NUM_ROWS_EVAL)
  let x1 = evaluation_normals(rng, EVALUATION_NUM_ROWS_EVAL)
  let noise = evaluation_scaled(
    evaluation_normals(rng, EVALUATION_NUM_ROWS_EVAL),
    0.1,
  )
  let y = evaluation_sum(evaluation_sum(x0, x1), noise)
  let frame = evaluation_frame([("X0", x0), ("X1", x1), ("Y", y)])
  let model = evaluation_model(frame)
  let summary = @gcm.evaluate_causal_model(
    model,
    frame,
    evaluation_config(evaluation_rng(111)),
    evaluation_options(),
    evaluation_rng(112),
  )
  // The divergence of the generated and of the observed distribution.
  let overall = match summary.overall_kl_divergence() {
    Some(value) => value
    None => abort("the evaluation has no overall divergence")
  }
  assert_true((overall - 0.025086416026934313).abs() <= 0.05)
  // The root nodes are measured by their divergence.
  let x0_performance = match summary.mechanism_performance("X0") {
    Some(value) => value
    None => abort("the evaluation has no performance of the node X0")
  }
  let x1_performance = match summary.mechanism_performance("X1") {
    Some(value) => value
    None => abort("the evaluation has no performance of the node X1")
  }
  let y_performance = match summary.mechanism_performance("Y") {
    Some(value) => value
    None => abort("the evaluation has no performance of the node Y")
  }
  assert_true(x0_performance.is_root())
  assert_true(x1_performance.is_root())
  assert_false(y_performance.is_root())
  assert_true(
    (x0_performance.kl_divergence().unwrap_or(0.0) - 0.08002527023828544).abs() <=
    0.2,
  )
  assert_true(
    (x1_performance.kl_divergence().unwrap_or(0.0) - 0.05607204536946164).abs() <=
    0.2,
  )
  assert_true(x0_performance.crps() is None)
  assert_true(x0_performance.nmse() is None)
  assert_true(x0_performance.r2() is None)
  assert_true(x0_performance.f1() is None)
  assert_true(x0_performance.total_number_baselines() == 0)
  assert_true(x1_performance.crps() is None)
  assert_true(x1_performance.nmse() is None)
  assert_true(x1_performance.r2() is None)
  assert_true(x1_performance.f1() is None)
  assert_true(x1_performance.total_number_baselines() == 0)
  // The node with the parents is measured by the score and by the error of the
  // conditional expectation.
  assert_true(y_performance.kl_divergence() is None)
  assert_true(
    (y_performance.crps().unwrap_or(0.0) - 0.042728502517577795).abs() <= 0.02,
  )
  assert_true(
    (y_performance.nmse().unwrap_or(0.0) - 0.07508369431198304).abs() <= 0.03,
  )
  assert_true(
    (y_performance.r2().unwrap_or(0.0) - 0.9942378490156086).abs() <= 0.05,
  )
  assert_true(y_performance.f1() is None)
  assert_true(y_performance.total_number_baselines() == 1)
  assert_true(y_performance.count_better_performance().unwrap_or(0) == 0)
  // The assumption of the invertible functional causal model.
  let assumptions = match summary.pnl_assumptions() {
    Some(value) => value
    None => abort("the evaluation has no assumption of the invertibility")
  }
  assert_false(assumptions.contains("X0"))
  assert_false(assumptions.contains("X1"))
  let assumption = match assumptions.get("Y") {
    Some(value) => value
    None => abort("the node Y has no assumption of the invertibility")
  }
  assert_false(assumption.rejected())
  assert_true(assumption.significance_level() == 0.05)
  // The report of the evaluation.
  let report = summary.to_string()
  assert_true(report.contains(evaluation_report_headline()))
  assert_true(report.contains("--- Node X0\n"))
  assert_true(
    report.contains(
      "- The KL divergence between generated and observed distribution is ",
    ),
  )
  assert_true(report.contains("--- Node X1\n"))
  assert_true(report.contains("--- Node Y\n"))
  assert_true(report.contains("- The MSE is "))
  assert_true(report.contains("- The NMSE is "))
  assert_true(report.contains("- The R2 coefficient is "))
  assert_true(report.contains("- The normalized CRPS is "))
  assert_true(
    report.contains(
      "The estimated CRPS indicates a very good model performance.",
    ),
  )
  assert_true(
    report.contains("The mechanism is better or equally good than all "),
  )
  assert_true(
    report.contains(
      "==== Evaluation of Invertible Functional Causal Model Assumption ====",
    ),
  )
  assert_true(report.contains("==== Evaluation of Generated Distribution ===="))
  assert_true(
    report.contains("==== Evaluation of the Causal Graph Structure ===="),
  )
  assert_true(report.contains("==== NOTE ===="))
}

///|
test "given categorical data when evaluating a model then report the performance of the mechanisms" {
  let rng = evaluation_rng(12)
  let x0 = evaluation_normals(rng, EVALUATION_NUM_ROWS_EVAL)
  let x1 = evaluation_normals(rng, EVALUATION_NUM_ROWS_EVAL)
  let noise = evaluation_scaled(
    evaluation_normals(rng, EVALUATION_NUM_ROWS_EVAL),
    0.1,
  )
  let y = evaluation_labels(evaluation_sum(evaluation_sum(x0, x1), noise))
  let frame = @api.DataFrame::from_numeric(
    ["X0", "X1"],
    Map([("X0", x0), ("X1", x1)]),
  ).with_discrete("Y", y)
  let model = evaluation_model(frame)
  // The falsification of the graph of the port needs the numeric data of every
  // node, so the evaluation of a model with a categorical node does not run it.
  let options = evaluation_options().with_evaluate_causal_structure(false)
  let summary = @gcm.evaluate_causal_model(
    model,
    frame,
    evaluation_config(evaluation_rng(121)),
    options,
    evaluation_rng(122),
  )
  let overall = match summary.overall_kl_divergence() {
    Some(value) => value
    None => abort("the evaluation has no overall divergence")
  }
  assert_true((overall - 0.010643107243437255).abs() <= 0.05)
  let x0_performance = match summary.mechanism_performance("X0") {
    Some(value) => value
    None => abort("the evaluation has no performance of the node X0")
  }
  let x1_performance = match summary.mechanism_performance("X1") {
    Some(value) => value
    None => abort("the evaluation has no performance of the node X1")
  }
  let y_performance = match summary.mechanism_performance("Y") {
    Some(value) => value
    None => abort("the evaluation has no performance of the node Y")
  }
  assert_true(
    (x0_performance.kl_divergence().unwrap_or(0.0) - 0.06370970879112671).abs() <=
    0.2,
  )
  assert_true(
    (x1_performance.kl_divergence().unwrap_or(0.0) - 0.0717759133994772).abs() <=
    0.2,
  )
  assert_true(x0_performance.crps() is None)
  assert_true(x0_performance.nmse() is None)
  assert_true(x0_performance.r2() is None)
  assert_true(x0_performance.f1() is None)
  assert_true(x0_performance.total_number_baselines() == 0)
  assert_true(x1_performance.crps() is None)
  assert_true(x1_performance.nmse() is None)
  assert_true(x1_performance.r2() is None)
  assert_true(x1_performance.f1() is None)
  assert_true(x1_performance.total_number_baselines() == 0)
  assert_true(y_performance.kl_divergence() is None)
  assert_true(
    (y_performance.crps().unwrap_or(0.0) - 0.031618400000000005).abs() <= 0.02,
  )
  assert_true(y_performance.nmse() is None)
  assert_true(y_performance.r2() is None)
  assert_true(
    (y_performance.f1().unwrap_or(0.0) - 0.9779624486647849).abs() <= 0.05,
  )
  assert_true(y_performance.total_number_baselines() == 1)
  assert_true(y_performance.count_better_performance().unwrap_or(0) == 0)
  // A categorical mechanism has no invertible functional causal model.
  let assumptions = match summary.pnl_assumptions() {
    Some(value) => value
    None => abort("the evaluation has no assumption of the invertibility")
  }
  assert_false(assumptions.contains("X0"))
  assert_false(assumptions.contains("X1"))
  assert_false(assumptions.contains("Y"))
  // The report of the evaluation.
  let report = summary.to_string()
  assert_true(report.contains(evaluation_report_headline_without_graph()))
  assert_true(report.contains("--- Node X0\n"))
  assert_true(
    report.contains(
      "- The KL divergence between generated and observed distribution is ",
    ),
  )
  assert_true(report.contains("--- Node X1\n"))
  assert_true(report.contains("--- Node Y\n"))
  assert_true(report.contains("- The F1 score is "))
  assert_true(report.contains("- The normalized CRPS is "))
  assert_true(
    report.contains(
      "The estimated CRPS indicates a very good model performance.",
    ),
  )
  assert_true(
    report.contains("The mechanism is better or equally good than all "),
  )
  assert_true(
    report.contains(
      "==== Evaluation of Invertible Functional Causal Model Assumption ====",
    ),
  )
  assert_true(
    report.contains("The causal model has no invertible causal models."),
  )
  assert_true(report.contains("==== Evaluation of Generated Distribution ===="))
  assert_true(report.contains("==== NOTE ===="))
}

///|
/// The headline of the report of the evaluation of a model.
///
/// This is the text of the report of the upstream, which names the parts of the
/// model that were evaluated.
fn evaluation_report_headline() -> String {
  "Evaluated the performance of the causal mechanisms and the invertibility assumption of the causal mechanisms and the overall average KL divergence between generated and observed distribution and the graph structure. The results are as follows:"
}

///|
/// The headline of the report of the evaluation of a model whose graph was not
/// falsified.
///
/// The falsification of the graph of the port needs the numeric data of every
/// node, so the evaluation of a model with a categorical node does not run it.
fn evaluation_report_headline_without_graph() -> String {
  "Evaluated the performance of the causal mechanisms and the invertibility assumption of the causal mechanisms and the overall average KL divergence between generated and observed distribution. The results are as follows:"
}
