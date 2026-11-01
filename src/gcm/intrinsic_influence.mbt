///|
/// The intrinsic causal influence of the noise of the ancestors of a node.
///
/// This is the port of the intrinsic causal influence of `dowhy.gcm.influence`.
/// The intrinsic causal influence of a node is the contribution of the noise of
/// that node to a statistical property of the target node. A noise term does
/// not inherit the properties of the observed parents, so the influence it has
/// is the intrinsic one.
///
/// The method is described in the research paper *Quantifying causal
/// contributions via structure preserving interventions* of Dominik Janzing,
/// Dominik K. and Bernhard Schölkopf (arXiv:2007.00714, 2021).

///|
/// The way the target is predicted from the noise of its ancestors.
pub enum IccPrediction {
  ///
  /// The noise is propagated through the graph, so that the predictions follow
  /// the fitted models of the graph.
  Exact
  ///
  /// A linear regression is fitted on the noise samples of the ancestors and on
  /// the samples of the target.
  Approx
}

///|
/// The prediction that propagates the noise through the graph.
pub fn IccPrediction::exact() -> IccPrediction {
  Exact
}

///|
/// The prediction that fits a linear regression on the noise samples.
pub fn IccPrediction::approx() -> IccPrediction {
  Approx
}

///|
/// The attribution function that measures the statistical property of the
/// target.
///
/// This is the port of the attribution function of the upstream. The first
/// argument holds the predictions of the target when some of the noise terms
/// are randomized, and the second one holds the predictions of the target when
/// none of them is.
pub type IccAttributionFunc = (Array[Double], Array[Double]) -> Double

///|
/// The variance of the predictions, which is the attribution function of the
/// upstream for a continuous target.
pub fn icc_variance_attribution(
  predictions : Array[Double],
  baseline : Array[Double],
) -> Double {
  let _ = baseline
  estimate_variance(@utils.Matrix::from_columns([predictions]))
}

///|
/// The intrinsic causal influence of every ancestor of the target node.
///
/// This is the port of `dowhy.gcm.influence.intrinsic_causal_influence`. The
/// contribution of a node is the Shapley value of the set function that
/// measures the statistical property of the target when the noise of the node
/// is randomized.
///
/// The result holds the influence of every ancestor of the target, in the
/// order of the nodes of the graph.
///
/// The upstream draws its randomness from the global numpy generator; the port
/// draws it from the generator it is given.
///
/// The upstream selects the model of the approximate prediction with the model
/// selection of `dowhy.gcm.auto`; the port fits a linear regression, which is
/// the model the upstream selects for a linear relation. The quality of the
/// assignment therefore has no effect on the result.
pub fn intrinsic_causal_influence(
  causal_model : ProbabilisticCausalModel,
  target_node : String,
  prediction : IccPrediction,
  attribution_func : IccAttributionFunc?,
  num_training_samples : Int32,
  num_samples_randomization : Int32,
  num_samples_baseline : Int32,
  max_batch_size : Int32,
  auto_assign_quality : AssignmentQuality,
  shapley_config : ShapleyConfig,
  rng : @utils.Random,
) -> Array[(String, Double)] {
  let _ = auto_assign_quality
  let _ = max_batch_size
  validate_causal_dag(causal_model)
  let sub_model = subgraph_of(causal_model, target_node)
  let (data_samples, noise_samples) = noise_samples_of_ancestors(
    sub_model, target_node, num_training_samples, rng,
  )
  let node_names = noise_samples.column_names()
  let prediction_method = prediction_method_of(
    sub_model, target_node, prediction, noise_samples, data_samples, node_names,
  )
  let attribution = match attribution_func {
    Some(func) => func
    None => icc_variance_attribution
  }
  let (_, drawn) = noise_samples_of_ancestors(
    sub_model,
    target_node,
    num_samples_randomization + num_samples_baseline,
    rng,
  )
  let noise = drawn.design_matrix(node_names)
  let randomization = first_rows(noise, num_samples_randomization)
  let baseline = @utils.Matrix::from_rows(
    rows_between(noise, num_samples_randomization, num_samples_baseline),
  )
  let target_values = prediction_method(baseline)
  let set_func = fn(subset : Array[Bool]) -> Double {
    let predictions = predictions_of_subset(
      prediction_method, randomization, baseline, subset, target_values, rng,
    )
    attribution(predictions, target_values)
  }
  let values = estimate_shapley_values(
    set_func,
    node_names.length(),
    shapley_config,
  )
  let result : Array[(String, Double)] = []
  for i in 0..<node_names.length() {
    result.push((node_names[i], values[i]))
  }
  result
}

///|
/// The intrinsic causal influence of every ancestor of the target node for
/// every sample of the baseline.
///
/// This is the port of
/// `dowhy.gcm.influence.intrinsic_causal_influence_sample`. The noise of the
/// observed samples is reconstructed, and the relevance of every noise term is
/// the contribution of that term to the target.
///
/// The result holds one row per sample of the baseline and one column per
/// ancestor of the target, in the order of the nodes of the graph.
pub fn intrinsic_causal_influence_sample(
  causal_model : ProbabilisticCausalModel,
  target_node : String,
  baseline_samples : @api.DataFrame,
  noise_feature_samples : @api.DataFrame?,
  prediction : IccPrediction,
  subset_scoring_func : SubsetScoringFunc?,
  num_noise_feature_samples : Int32,
  max_batch_size : Int32,
  auto_assign_quality : AssignmentQuality,
  shapley_config : ShapleyConfig,
  rng : @utils.Random,
) -> (@utils.Matrix, Array[String]) {
  let _ = auto_assign_quality
  validate_causal_dag(causal_model)
  let sub_model = subgraph_of(causal_model, target_node)
  let (feature_samples, drawn) = noise_samples_of_ancestors(
    sub_model, target_node, num_noise_feature_samples, rng,
  )
  let node_names = match noise_feature_samples {
    Some(frame) => frame.column_names()
    None => drawn.column_names()
  }
  let scoring = match subset_scoring_func {
    Some(func) => func
    None => means_difference
  }
  let noise_features = match noise_feature_samples {
    Some(frame) => frame.design_matrix(node_names)
    None => drawn.design_matrix(node_names)
  }
  let prediction_method = prediction_method_of(
    sub_model,
    target_node,
    prediction,
    noise_features_frame(noise_features, node_names),
    feature_samples,
    node_names,
  )
  let baseline_noise = compute_noise_from_data(sub_model, baseline_samples)
  let relevance = feature_relevance_sample(
    prediction_method,
    noise_features,
    baseline_noise.design_matrix(node_names),
    scoring,
    None,
    false,
    max_batch_size,
    true,
    shapley_config,
    rng,
  )
  (relevance, node_names)
}

///|
/// The model of the nodes that can reach the target node.
fn subgraph_of(
  causal_model : ProbabilisticCausalModel,
  target_node : String,
) -> ProbabilisticCausalModel {
  let sub_model = ProbabilisticCausalModel::new(
    causal_model.graph.node_connected_subgraph_view(target_node),
  )
  copy_mechanisms_into(causal_model, sub_model)
  sub_model
}

///|
/// The way the target is predicted from the noise of its ancestors.
fn prediction_method_of(
  causal_model : ProbabilisticCausalModel,
  target_node : String,
  prediction : IccPrediction,
  noise_samples : @api.DataFrame,
  data_samples : @api.DataFrame,
  node_names : Array[String],
) -> (@utils.Matrix) -> Array[Double] {
  match prediction {
    Exact =>
      fn(inputs : @utils.Matrix) -> Array[Double] {
        let frame = noise_features_frame(inputs, node_names)
        compute_data_from_noise(causal_model, frame).numeric(target_node)
      }
    Approx => {
      let x = noise_samples.design_matrix(node_names)
      let y = data_samples.numeric(target_node)
      let fitted = PredictionModel::linear().fit(x, y)
      fn(inputs : @utils.Matrix) -> Array[Double] { fitted.predict(inputs) }
    }
  }
}

///|
/// The frame of the noise samples of the given nodes.
fn noise_features_frame(
  noise : @utils.Matrix,
  node_names : Array[String],
) -> @api.DataFrame {
  let columns : Map[String, Array[Double]] = Map([])
  for j in 0..<node_names.length() {
    columns.set(node_names[j], noise.col(j))
  }
  @api.DataFrame::from_numeric(node_names, columns)
}

///|
/// The predictions of the target when the noise terms of the subset are kept
/// and the other ones are randomized.
fn predictions_of_subset(
  prediction_method : (@utils.Matrix) -> Array[Double],
  randomization : @utils.Matrix,
  baseline : @utils.Matrix,
  subset : Array[Bool],
  target_values : Array[Double],
  rng : @utils.Random,
) -> Array[Double] {
  let num_features = randomization.ncols()
  let mut all = true
  let mut none = true
  for flag in subset {
    if flag {
      none = false
    } else {
      all = false
    }
  }
  if all {
    // Every noise term is kept, so the predictions are the ones of the
    // baseline.
    return target_values.copy()
  }
  if none {
    // Every noise term is randomized, so the predictions are the same for
    // every sample of the baseline.
    let randomized = prediction_method(randomization)
    let mean = @utils.mean(randomized)
    let out : Array[Double] = []
    for _ in 0..<baseline.nrows() {
      out.push(mean)
    }
    return out
  }
  let indices : Array[Int32] = []
  for j in 0..<num_features {
    if subset[j] {
      indices.push(j)
    }
  }
  let predictions = marginal_expectation(
    prediction_method,
    randomization,
    baseline,
    indices,
    true,
    RandomizeColumnsJointly,
    rng,
  )
  predictions.col(0)
}

///|
/// The first rows of the matrix.
fn first_rows(m : @utils.Matrix, count : Int32) -> @utils.Matrix {
  @utils.Matrix::from_rows(rows_between(m, 0, count))
}

///|
/// The rows of the matrix between the two positions.
fn rows_between(
  m : @utils.Matrix,
  start : Int32,
  count : Int32,
) -> Array[Array[Double]] {
  let rows : Array[Array[Double]] = []
  let mut i = start
  let mut remaining = count
  while i < m.nrows() && remaining > 0 {
    rows.push(m.row(i))
    i = i + 1
    remaining = remaining - 1
  }
  rows
}
