///|
/// The probabilistic causal model of the `gcm` package.
///
/// This is the port of `dowhy.gcm.causal_models.ProbabilisticCausalModel` and
/// of `StructuralCausalModel`. The upstream model is a class that holds a
/// networkx graph and stores the causal mechanism of every node in an
/// attribute of that node; the port holds the graph and a map of mechanisms.
///
/// The model is mutable, like the upstream one: a mechanism is assigned to a
/// node and is then fitted in place. A copy of the model shares the maps of
/// the original, so `clone` is the way to get a model that can be changed
/// without changing the original.

///|
/// A probabilistic causal model, which combines a graph of causal
/// relationships with the causal mechanism of every node.
pub struct ProbabilisticCausalModel {
  graph : @graph.DirectedGraph
  root_models : Map[String, StochasticModel]
  mechanisms : Map[String, CausalMechanism]
  parents_during_fit : Map[String, Array[String]]
  encoders : Map[String, ParentEncoder]
}

///|
/// A causal model of the given graph.
///
/// This is the port of `dowhy.gcm.causal_models.ProbabilisticCausalModel`.
pub fn ProbabilisticCausalModel::new(
  graph : @graph.DirectedGraph,
) -> ProbabilisticCausalModel {
  {
    graph,
    root_models: Map([]),
    mechanisms: Map([]),
    parents_during_fit: Map([]),
    encoders: Map([]),
  }
}

///|
/// A causal model whose non-root nodes have functional causal mechanisms.
///
/// This is the port of `dowhy.gcm.causal_models.StructuralCausalModel`. Every
/// mechanism of the port is a functional causal model, so the structural model
/// of the upstream is the model of the port, and `StructuralCausalModel::new`
/// is the constructor of the model.
pub type StructuralCausalModel = ProbabilisticCausalModel

///|
/// The graph of the causal relationships.
pub fn ProbabilisticCausalModel::graph(
  self : ProbabilisticCausalModel,
) -> @graph.DirectedGraph {
  self.graph
}

///|
/// The nodes of the graph.
pub fn ProbabilisticCausalModel::nodes(
  self : ProbabilisticCausalModel,
) -> Array[String] {
  self.graph.node_list()
}

///|
/// Assign the causal mechanism of a node that has parents.
///
/// This is the port of
/// `dowhy.gcm.causal_models.ProbabilisticCausalModel.set_causal_mechanism` for
/// the nodes that are not roots.
pub fn ProbabilisticCausalModel::set_causal_mechanism(
  self : ProbabilisticCausalModel,
  node : String,
  mechanism : CausalMechanism,
) -> Unit {
  if !self.graph.has_node(node) {
    abort("the node " + node + " is not in the graph of the causal model")
  }
  self.mechanisms.set(node, mechanism)
}

///|
/// Assign the distribution of a root node.
///
/// This is the port of
/// `dowhy.gcm.causal_models.ProbabilisticCausalModel.set_causal_mechanism` for
/// the nodes that are roots.
pub fn ProbabilisticCausalModel::set_root_model(
  self : ProbabilisticCausalModel,
  node : String,
  model : StochasticModel,
) -> Unit {
  if !self.graph.has_node(node) {
    abort("the node " + node + " is not in the graph of the causal model")
  }
  self.root_models.set(node, model)
}

///|
/// The causal mechanism of a node, when it has one.
pub fn ProbabilisticCausalModel::causal_mechanism(
  self : ProbabilisticCausalModel,
  node : String,
) -> CausalMechanism? {
  self.mechanisms.get(node)
}

///|
/// The distribution of a root node, when it has one.
pub fn ProbabilisticCausalModel::root_model(
  self : ProbabilisticCausalModel,
  node : String,
) -> StochasticModel? {
  self.root_models.get(node)
}

///|
/// Whether a node has a causal mechanism or a distribution assigned.
pub fn ProbabilisticCausalModel::has_causal_mechanism(
  self : ProbabilisticCausalModel,
  node : String,
) -> Bool {
  self.mechanisms.contains(node) || self.root_models.contains(node)
}

///|
/// The parents a node was fitted with, when it has been fitted.
pub fn ProbabilisticCausalModel::parents_during_fit(
  self : ProbabilisticCausalModel,
  node : String,
) -> Array[String]? {
  match self.parents_during_fit.get(node) {
    Some(parents) => Some(parents.copy())
    None => None
  }
}

///|
/// Record the parents a node is fitted with.
pub fn ProbabilisticCausalModel::set_parents_during_fit(
  self : ProbabilisticCausalModel,
  node : String,
  parents : Array[String],
) -> Unit {
  self.parents_during_fit.set(node, parents.copy())
}

///|
/// The encoder of the discrete parents of a node, when it has been fitted.
pub fn ProbabilisticCausalModel::encoder_of(
  self : ProbabilisticCausalModel,
  node : String,
) -> ParentEncoder? {
  self.encoders.get(node)
}

///|
/// Record the encoder of the discrete parents of a node.
pub fn ProbabilisticCausalModel::set_encoder(
  self : ProbabilisticCausalModel,
  node : String,
  encoder : ParentEncoder,
) -> Unit {
  self.encoders.set(node, encoder)
}

///|
/// A copy of the model whose mechanisms and graph can be changed without
/// changing the original.
pub fn ProbabilisticCausalModel::clone(
  self : ProbabilisticCausalModel,
) -> ProbabilisticCausalModel {
  let mechanisms : Map[String, CausalMechanism] = Map([])
  for node in self.mechanisms.keys() {
    match self.mechanisms.get(node) {
      Some(mechanism) => mechanisms.set(node, mechanism.clone())
      None => ()
    }
  }
  let root_models : Map[String, StochasticModel] = Map([])
  for node in self.root_models.keys() {
    match self.root_models.get(node) {
      Some(model) => root_models.set(node, model.clone())
      None => ()
    }
  }
  let parents_during_fit : Map[String, Array[String]] = Map([])
  for node in self.parents_during_fit.keys() {
    match self.parents_during_fit.get(node) {
      Some(parents) => parents_during_fit.set(node, parents.copy())
      None => ()
    }
  }
  let encoders : Map[String, ParentEncoder] = Map([])
  for node in self.encoders.keys() {
    match self.encoders.get(node) {
      Some(encoder) => encoders.set(node, encoder)
      None => ()
    }
  }
  {
    graph: self.graph.copy(),
    root_models,
    mechanisms,
    parents_during_fit,
    encoders,
  }
}

///|
/// Whether the node is a root of the graph, which means that it has no
/// parents.
pub fn is_root_node(model : ProbabilisticCausalModel, node : String) -> Bool {
  model.graph.predecessors(node).length() == 0
}

///|
/// Whether the causal mechanism of the node matches the graph.
///
/// This is the port of
/// `dowhy.gcm.causal_models.validate_causal_model_assignment`. A root node
/// needs a distribution and a node with parents needs a causal mechanism.
pub fn has_valid_causal_model_assignment(
  model : ProbabilisticCausalModel,
  node : String,
) -> Bool {
  if !model.graph.has_node(node) {
    return false
  }
  if is_root_node(model, node) {
    model.root_models.contains(node)
  } else {
    model.mechanisms.contains(node)
  }
}

///|
/// Check that the causal mechanism of the node matches the graph.
///
/// This is the port of
/// `dowhy.gcm.causal_models.validate_causal_model_assignment`.
pub fn validate_causal_model_assignment(
  model : ProbabilisticCausalModel,
  node : String,
) -> Unit {
  if !model.graph.has_node(node) {
    abort("the node " + node + " is not in the graph of the causal model")
  }
  if !has_valid_causal_model_assignment(model, node) {
    if is_root_node(model, node) {
      abort(
        "the node " +
        node +
        " is a root and needs a distribution, but it has none",
      )
    }
    abort(
      "the node " +
      node +
      " has parents and needs a causal mechanism, but it has none",
    )
  }
}

///|
/// Whether the mechanism of the node was fitted to the parents the graph has
/// now.
///
/// This is the port of `dowhy.gcm.causal_models.validate_local_structure`.
pub fn has_valid_local_structure(
  model : ProbabilisticCausalModel,
  node : String,
) -> Bool {
  match model.parents_during_fit.get(node) {
    Some(parents) => parents == model.graph.predecessors(node)
    None => false
  }
}

///|
/// Check that the mechanism of the node was fitted to the parents the graph
/// has now.
///
/// This is the port of `dowhy.gcm.causal_models.validate_local_structure`.
pub fn validate_local_structure(
  model : ProbabilisticCausalModel,
  node : String,
) -> Unit {
  if !has_valid_local_structure(model, node) {
    abort(
      "the causal mechanism of the node " +
      node +
      " is not fitted to the graphical structure; fit the causal model first",
    )
  }
}

///|
/// Whether every node of the model has a mechanism that matches the graph.
pub fn has_valid_causal_model(model : ProbabilisticCausalModel) -> Bool {
  if !model.graph.is_dag() {
    return false
  }
  for node in model.graph.node_list() {
    if !has_valid_causal_model_assignment(model, node) {
      return false
    }
  }
  true
}

///|
/// Check that the model is a directed acyclic graph whose nodes all have a
/// mechanism that matches the graph.
///
/// This is the port of `dowhy.gcm.causal_models.validate_causal_dag`.
pub fn validate_causal_dag(model : ProbabilisticCausalModel) -> Unit {
  if !model.graph.is_dag() {
    abort("the graph of the causal model is not acyclic")
  }
  for node in model.graph.node_list() {
    validate_causal_model_assignment(model, node)
  }
}
