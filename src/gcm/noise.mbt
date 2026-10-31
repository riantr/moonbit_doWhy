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
      let parents = causal_model.graph.predecessors(node)
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
      let parents = causal_model.graph.predecessors(node)
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
