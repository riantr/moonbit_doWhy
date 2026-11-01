///|
/// The influence layer of the `gcm` package.
///
/// This is the port of `dowhy.gcm.influence`. The layer computes the causal
/// strength of every edge that points at a target node: the strength of an edge
/// is the distance between the conditional distribution of the target under the
/// mechanism of the model and the conditional distribution under the same
/// mechanism with the parent of the edge randomised.
///
/// The method is described in the research paper *Quantifying Causal Influences*
/// of Dominik Janzing, David Balduzzi, Moritz Grosse-Wentrup and Bernhard
/// Schölkopf.

///|
/// The configuration of the influence layer.
pub struct ArrowStrengthConfig {
  num_samples_conditional : Int32
  max_num_runs : Int32
  tolerance : Double
  difference_estimation_func : ((@utils.Matrix, @utils.Matrix) -> Double)?
}

///|
/// The configuration with the defaults of the upstream.
///
/// The upstream draws two thousand samples of the conditional distribution,
/// runs the estimate at most five thousand times and stops when the estimate
/// changed by less than one percent in three consecutive runs.
pub fn ArrowStrengthConfig::new() -> ArrowStrengthConfig {
  {
    num_samples_conditional: 2000,
    max_num_runs: 5000,
    tolerance: 0.01,
    difference_estimation_func: None,
  }
}

///|
/// A copy of the configuration with the given number of the samples.
pub fn ArrowStrengthConfig::with_num_samples_conditional(
  self : ArrowStrengthConfig,
  value : Int32,
) -> ArrowStrengthConfig {
  {
    num_samples_conditional: value,
    max_num_runs: self.max_num_runs,
    tolerance: self.tolerance,
    difference_estimation_func: self.difference_estimation_func,
  }
}

///|
/// A copy of the configuration with the given number of the runs.
pub fn ArrowStrengthConfig::with_max_num_runs(
  self : ArrowStrengthConfig,
  value : Int32,
) -> ArrowStrengthConfig {
  {
    num_samples_conditional: self.num_samples_conditional,
    max_num_runs: value,
    tolerance: self.tolerance,
    difference_estimation_func: self.difference_estimation_func,
  }
}

///|
/// A copy of the configuration with the given threshold of the early stopping.
pub fn ArrowStrengthConfig::with_tolerance(
  self : ArrowStrengthConfig,
  value : Double,
) -> ArrowStrengthConfig {
  {
    num_samples_conditional: self.num_samples_conditional,
    max_num_runs: self.max_num_runs,
    tolerance: value,
    difference_estimation_func: self.difference_estimation_func,
  }
}

///|
/// A copy of the configuration with the given measure of the difference of two
/// distributions.
///
/// The measure takes the samples of the old and of the new distribution of the
/// target and returns a number that is large when the two distributions differ.
pub fn ArrowStrengthConfig::with_difference_estimation_func(
  self : ArrowStrengthConfig,
  value : (@utils.Matrix, @utils.Matrix) -> Double,
) -> ArrowStrengthConfig {
  {
    num_samples_conditional: self.num_samples_conditional,
    max_num_runs: self.max_num_runs,
    tolerance: self.tolerance,
    difference_estimation_func: Some(value),
  }
}

///|
/// The causal strength of every edge that points at the target node.
///
/// This is the port of `dowhy.gcm.influence.arrow_strength`. The strength of an
/// edge is the distance between the conditional distribution of the target under
/// the mechanism of the model and the conditional distribution under the same
/// mechanism with the parent of the edge randomised. The larger the strength,
/// the more the parent moves the distribution of the target.
///
/// The `parent_samples` are the samples of the parents of the target node. When
/// they are not given, they are drawn from the model. Giving the observed data
/// mitigates a misspecified graph, because the observed samples of the parents
/// hold the relations that the graph does not.
///
/// The target node has to be in the graph and it must not be a root node, since
/// a root node has no parent whose edge could have a strength.
pub fn arrow_strength(
  causal_model : ProbabilisticCausalModel,
  target_node : String,
  parent_samples : @api.DataFrame?,
  config : ArrowStrengthConfig,
  rng : @utils.Random,
) -> Map[(String, String), Double] {
  if !causal_model.graph.has_node(target_node) {
    abort("the target node " + target_node + " is not in the graph")
  }
  if is_root_node(causal_model, target_node) {
    abort(
      "the target node " +
      target_node +
      " is a root node, but it needs to have ancestors",
    )
  }
  // The sub graph of the nodes that are connected to the target node. The
  // upstream keeps the mechanisms in the attributes of the nodes of the graph,
  // so the view of the graph keeps them; the port keeps them in the model, so
  // they have to be copied.
  let sub_model = ProbabilisticCausalModel::new(
    causal_model.graph.node_connected_subgraph_view(target_node),
  )
  copy_mechanisms_into(causal_model, sub_model)
  let predecessors = sub_model.graph.ordered_predecessors(target_node)
  let samples = match parent_samples {
    Some(frame) => frame.design_matrix(predecessors)
    None => {
      let drawn = draw_samples(
        sub_model,
        config.num_samples_conditional * 20,
        rng,
      )
      drawn.design_matrix(predecessors)
    }
  }
  let mechanism = match sub_model.causal_mechanism(target_node) {
    Some(value) => value
    None => abort("the node " + target_node + " has no causal mechanism")
  }
  let influences = arrow_strength_of_model(mechanism, samples, config, rng)
  let strengths : Map[(String, String), Double] = Map([])
  for i in 0..<predecessors.length() {
    strengths.set((predecessors[i], target_node), influences[i])
  }
  strengths
}

///|
/// The strength of every input of the given mechanism.
///
/// This is the port of
/// `dowhy.gcm.influence.arrow_strength_of_model`. The strength of an input is
/// the distance between the distribution of the target under the mechanism and
/// the distribution under the mechanism with that input randomised.
///
/// The measure of the difference of the two distributions is the difference of
/// their variances, like the upstream does for a continuous target. For a
/// categorical target it is the Kullback-Leibler divergence of the class
/// probabilities, because the variance of the classes says nothing about the
/// change of the distribution.
pub fn arrow_strength_of_model(
  mechanism : CausalMechanism,
  input_samples : @utils.Matrix,
  config : ArrowStrengthConfig,
  rng : @utils.Random,
) -> Array[Double] {
  let difference = match config.difference_estimation_func {
    Some(func) => func
    None =>
      if is_classifier_kind(mechanism.kind()) {
        difference_of_probabilities
      } else {
        difference_of_variances
      }
  }
  let strengths : Array[Double] = []
  for parent in 0..<input_samples.ncols() {
    strengths.push(
      estimate_direct_strength(
        mechanism,
        input_samples,
        [parent],
        difference,
        config,
        rng,
      ),
    )
  }
  strengths
}

///|
/// The difference of the variances of two samples of the target.
///
/// This is the measure the upstream uses by default for a continuous target.
fn difference_of_variances(
  old_samples : @utils.Matrix,
  new_samples : @utils.Matrix,
) -> Double {
  @utils.var_pop(new_samples.col(0)) - @utils.var_pop(old_samples.col(0))
}

///|
/// The Kullback-Leibler divergence of the class probabilities of two samples of
/// the target.
///
/// This is the measure the upstream uses by default for a categorical target.
fn difference_of_probabilities(
  old_samples : @utils.Matrix,
  new_samples : @utils.Matrix,
) -> Double {
  estimate_kl_divergence_of_probabilities(old_samples, new_samples)
}

///|
/// The strength of the given inputs of the mechanism.
///
/// This is the port of
/// `dowhy.gcm.influence._estimate_direct_strength`. Every run of the estimate
/// takes one row of the samples of the parents, draws the conditional
/// distribution of the target for it, and draws the conditional distribution
/// again with the parents of the subset randomised. The strength is the mean of
/// the differences of the two distributions.
///
/// The rows of the samples of the parents are permuted without replacement, the
/// way the upstream permutes them, so that the randomised parents are the
/// parents of the sample itself and not the parents of the run.
fn estimate_direct_strength(
  mechanism : CausalMechanism,
  distribution_samples : @utils.Matrix,
  parents_subset : Array[Int32],
  difference_estimation_func : (@utils.Matrix, @utils.Matrix) -> Double,
  config : ArrowStrengthConfig,
  rng : @utils.Random,
) -> Double {
  let num_rows = distribution_samples.nrows()
  let num_samples = if config.num_samples_conditional < num_rows {
    config.num_samples_conditional
  } else {
    num_rows
  }
  // The indices of the rows of the samples of the parents, in a random order.
  let candidates : Array[Double] = []
  for i in 0..<num_rows {
    candidates.push(i.to_double())
  }
  let shuffled = rng.shuffle(candidates)
  let mut aggregated = 0.0
  let mut average = 0.0
  let mut converged_run = 0
  for run in 0..<num_rows {
    // The sample of the parents of this run, repeated for every sample of the
    // conditional distribution.
    let repeated = @utils.Matrix::zeros(
      num_samples,
      distribution_samples.ncols(),
    )
    for i in 0..<num_samples {
      for j in 0..<distribution_samples.ncols() {
        repeated.set(i, j, distribution_samples.get(run, j))
      }
    }
    let conditional = arrow_strength_samples(mechanism, repeated, rng)
    // The same sample, with the parents of the subset randomised.
    for column in parents_subset {
      for i in 0..<num_samples {
        repeated.set(
          i,
          column,
          distribution_samples.get(shuffled[i].to_int(), column),
        )
      }
    }
    let randomised = arrow_strength_samples(mechanism, repeated, rng)
    let old_average = average
    aggregated = aggregated +
      difference_estimation_func(conditional, randomised)
    average = aggregated / (run + 1).to_double()
    if run >= config.max_num_runs {
      break
    } else if run > 0 {
      let converging = if old_average == 0.0 {
        average == 0.0
      } else {
        (1.0 - average / old_average).abs() < config.tolerance
      }
      if converging {
        converged_run = converged_run + 1
        if converged_run >= 3 {
          break
        }
      } else {
        converged_run = 0
      }
    }
  }
  average
}

///|
/// The samples of the target that the mechanism draws for the given parents.
///
/// A categorical mechanism returns the class probabilities of every row, like
/// the upstream does for a `ProbabilityEstimatorModel`.
fn arrow_strength_samples(
  mechanism : CausalMechanism,
  parents : @utils.Matrix,
  rng : @utils.Random,
) -> @utils.Matrix {
  if is_classifier_kind(mechanism.kind()) {
    let probabilities = mechanism
      .classifier_model()
      .predict_probabilities(parents)
    @utils.Matrix::from_rows(probabilities)
  } else {
    let samples = mechanism.draw_samples(parents, rng)
    @utils.Matrix::from_columns([samples])
  }
}

///|
/// The copy of the mechanisms of the source model into the destination model.
///
/// The upstream keeps the mechanisms of a node in the attributes of the node of
/// the graph, so the view of the graph that holds the nodes connected to the
/// target keeps the mechanisms and their fit. The port keeps the mechanisms in
/// the model, so they have to be copied.
fn copy_mechanisms_into(
  source : ProbabilisticCausalModel,
  destination : ProbabilisticCausalModel,
) -> Unit {
  for node in destination.graph.node_list() {
    match source.causal_mechanism(node) {
      Some(mechanism) => destination.set_causal_mechanism(node, mechanism)
      None => ()
    }
    match source.root_model(node) {
      Some(model) => destination.set_root_model(node, model)
      None => ()
    }
    match source.encoder_of(node) {
      Some(encoder) => destination.set_encoder(node, encoder)
      None => ()
    }
  }
}
