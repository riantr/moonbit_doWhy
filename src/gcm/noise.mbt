///|
/// The data and the noise of a causal model.
///
/// This is the port of `dowhy.gcm._noise`. The two functions are the two
/// directions of the relation between the data of a causal model and the
/// noise of its nodes: the data follow from the noise, and the noise follows
/// from the data.

///|
/// The data of the model, computed from the noise of every node.
///
/// This is the port of `dowhy.gcm._noise.compute_data_from_noise`. The nodes
/// are visited in the topological order of the graph, so the data of a node
/// with parents are computed from the data of its parents. The noise of a root
/// node is its value.
pub fn compute_data_from_noise(
  causal_model : ProbabilisticCausalModel,
  noise_data : @api.DataFrame,
) -> @api.DataFrame {
  validate_causal_dag(causal_model)
  let mut frame = @api.DataFrame::new([], Map([]))
  for node in causal_model.graph.topological_order() {
    if is_root_node(causal_model, node) {
      frame = frame.with_numeric(node, noise_data.numeric(node))
    } else {
      let parents = causal_model.graph.ordered_predecessors(node)
      let x = design_matrix_of(causal_model, node, frame, parents)
      let mechanism = mechanism_of(causal_model, node)
      frame = frame.with_numeric(
        node,
        mechanism.evaluate(x, noise_data.numeric(node)),
      )
    }
  }
  frame
}

///|
/// The noise of every node of the model, computed from the observed data.
///
/// This is the port of `dowhy.gcm._noise.compute_noise_from_data`. The nodes
/// are visited in the topological order of the graph, so the noise of a node
/// with parents is computed from the observed data of its parents. The noise
/// of a root node is its value.
///
/// The model has to be invertible, which means that the mechanism of every
/// node with parents has to be able to reconstruct its noise from the target
/// and the parents.
pub fn compute_noise_from_data(
  causal_model : ProbabilisticCausalModel,
  observed_data : @api.DataFrame,
) -> @api.DataFrame {
  validate_causal_dag(causal_model)
  let mut frame = @api.DataFrame::new([], Map([]))
  for node in causal_model.graph.topological_order() {
    if is_root_node(causal_model, node) {
      frame = frame.with_numeric(node, observed_data.numeric(node))
    } else {
      let parents = causal_model.graph.ordered_predecessors(node)
      let x = design_matrix_of(causal_model, node, observed_data, parents)
      let mechanism = mechanism_of(causal_model, node)
      frame = frame.with_numeric(
        node,
        mechanism.estimate_noise(observed_data.numeric(node), x),
      )
    }
  }
  frame
}

///|
/// The samples of the ancestors of a node and of the node itself, and the
/// noise of those samples.
///
/// This is the port of `dowhy.gcm._noise.noise_samples_of_ancestors`. The nodes
/// are visited in the topological order of the graph, so the samples of a node
/// with parents are computed from the samples of its parents. The noise of a
/// root node is its value.
///
/// The upstream draws the samples from the global generator of numpy; the port
/// draws them from the given generator, so that the same generator always gives
/// the same samples.
pub fn noise_samples_of_ancestors(
  causal_model : ProbabilisticCausalModel,
  target_node : String,
  num_samples : Int32,
  rng : @utils.Random,
) -> (@api.DataFrame, @api.DataFrame) {
  validate_causal_dag(causal_model)
  let ancestors = causal_model.graph.ancestors_of([target_node])
  let mut samples = @api.DataFrame::new([], Map([]))
  let mut noise_samples = @api.DataFrame::new([], Map([]))
  for node in causal_model.graph.topological_order() {
    if node != target_node && !ancestors.contains(node) {
      continue
    }
    if is_root_node(causal_model, node) {
      let root_model = match causal_model.root_model(node) {
        Some(model) => model
        None =>
          abort(
            "the node " +
            node +
            " is a root and needs a distribution, but it has none",
          )
      }
      let values = root_model.draw_samples(num_samples, rng)
      samples = samples.with_numeric(node, values.copy())
      noise_samples = noise_samples.with_numeric(node, values.copy())
    } else {
      let parents = causal_model.graph.ordered_predecessors(node)
      let x = design_matrix_of(causal_model, node, samples, parents)
      let mechanism = mechanism_of(causal_model, node)
      let noise = mechanism.noise_model.draw_samples(num_samples, rng)
      noise_samples = noise_samples.with_numeric(node, noise.copy())
      samples = samples.with_numeric(node, mechanism.evaluate(x, noise))
    }
    if node == target_node {
      break
    }
  }
  (samples, noise_samples)
}

///|
/// The design matrix of the parents of a node.
fn design_matrix_of(
  causal_model : ProbabilisticCausalModel,
  node : String,
  data : @api.DataFrame,
  parents : Array[String],
) -> @utils.Matrix {
  match causal_model.encoder_of(node) {
    Some(encoder) => encoder.design_matrix(data, parents)
    None =>
      abort(
        "the node " +
        node +
        " has parents and needs an encoder, but it has none; fit the causal model first",
      )
  }
}

///|
/// The causal mechanism of a node.
fn mechanism_of(
  causal_model : ProbabilisticCausalModel,
  node : String,
) -> CausalMechanism {
  match causal_model.causal_mechanism(node) {
    Some(mechanism) => mechanism
    None =>
      abort(
        "the node " +
        node +
        " has parents and needs a causal mechanism, but it has none",
      )
  }
}
