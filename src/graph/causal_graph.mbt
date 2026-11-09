/// The causal graph, the entry point for every causal analysis.
///
/// This is the port of `dowhy.causal_graph.CausalGraph`: it wraps a directed
/// graph together with the semantic role of its nodes (treatment, outcome,
/// confounder, instrument, effect modifier, mediator) and the observed /
/// unobserved flag that the identifiers rely on.

///|
/// The algorithm of the checks of the adjustment sets.
///
/// This is the port of the `dseparation_algo` argument of the upstream, which
/// is the string `"default"` or `"naive"`.
pub enum DseparationAlgorithm {
  /// The d-separation of the graph.
  Default
  /// Every path of the graph has to be blocked by the candidate set.
  Naive
}

///|
/// The d-separation of the graph.
pub fn DseparationAlgorithm::default() -> DseparationAlgorithm {
  Default
}

///|
/// The naive check of the paths.
pub fn DseparationAlgorithm::naive() -> DseparationAlgorithm {
  Naive
}

///|
/// A causal graph with the semantic role of every node.
pub struct CausalGraph {
  treatment_name : Array[String]
  outcome_name : Array[String]
  graph : DirectedGraph
  observed : Map[String, Bool]
  effect_modifiers : Array[String]
}

///|
/// Build a causal graph.
///
/// When `graph` is given it is used as is, otherwise the graph is built from
/// the semantic roles of the variables.
pub fn CausalGraph::new(
  treatment_name : Array[String],
  outcome_name : Array[String],
  graph : DirectedGraph?,
  common_cause_names : Array[String],
  instrument_names : Array[String],
  effect_modifier_names : Array[String],
  mediator_names : Array[String],
  observed_node_names : Array[String],
) -> CausalGraph {
  let built = match graph {
    Some(g) => g.copy()
    None =>
      build_graph(
        treatment_name, outcome_name, common_cause_names, instrument_names, effect_modifier_names,
        mediator_names,
      )
  }
  let observed = if observed_node_names.length() == 0 && graph is Some(_) {
    let m : Map[String, Bool] = Map([])
    for node in built.node_list() {
      m.set(node, true)
    }
    m
  } else {
    let m : Map[String, Bool] = Map([])
    for node in built.node_list() {
      m.set(node, observed_node_names.contains(node))
    }
    m
  }
  {
    treatment_name,
    outcome_name,
    graph: built,
    observed,
    effect_modifiers: effect_modifier_names,
  }
}

///|
/// Build a graph from the semantic role of the variables.
pub fn build_graph(
  action_nodes : Array[String],
  outcome_nodes : Array[String],
  common_cause_nodes : Array[String],
  instrument_nodes : Array[String],
  effect_modifier_nodes : Array[String],
  mediator_nodes : Array[String],
) -> DirectedGraph {
  let graph = DirectedGraph::new()
  for treatment in action_nodes {
    graph.add_node(treatment)
  }
  for outcome in outcome_nodes {
    graph.add_node(outcome)
  }
  for treatment in action_nodes {
    for outcome in outcome_nodes {
      graph.add_edge(treatment, outcome)
    }
  }
  for node_name in common_cause_nodes {
    for treatment in action_nodes {
      for outcome in outcome_nodes {
        graph.add_node(node_name)
        graph.add_edge(node_name, treatment)
        graph.add_edge(node_name, outcome)
      }
    }
  }
  for instrument in instrument_nodes {
    for treatment in action_nodes {
      graph.add_node(instrument)
      graph.add_edge(instrument, treatment)
    }
  }
  for node_name in effect_modifier_nodes {
    if !common_cause_nodes.contains(node_name) {
      for outcome in outcome_nodes {
        graph.add_node(node_name)
        graph.add_edge(node_name, outcome)
      }
    }
  }
  for node_name in mediator_nodes {
    for treatment in action_nodes {
      for outcome in outcome_nodes {
        graph.add_node(node_name)
        graph.add_edge(treatment, node_name)
        graph.add_edge(node_name, outcome)
      }
    }
  }
  graph
}

///|
/// The underlying directed graph.
pub fn CausalGraph::directed_graph(self : CausalGraph) -> DirectedGraph {
  self.graph
}

///|
/// The treatment variables.
pub fn CausalGraph::treatments(self : CausalGraph) -> Array[String] {
  self.treatment_name.copy()
}

///|
/// The outcome variables.
pub fn CausalGraph::outcomes(self : CausalGraph) -> Array[String] {
  self.outcome_name.copy()
}

///|
/// The parents of a node.
pub fn CausalGraph::get_parents(
  self : CausalGraph,
  node_name : String,
) -> Array[String] {
  self.graph.predecessors(node_name)
}

///|
/// The strict ancestors of a node.
pub fn CausalGraph::get_ancestors(
  self : CausalGraph,
  node_name : String,
) -> Set[String] {
  self.graph.ancestors(node_name)
}

///|
/// The strict descendants of a set of nodes.
pub fn CausalGraph::get_descendants(
  self : CausalGraph,
  nodes : Array[String],
) -> Set[String] {
  self.graph.descendants_of(nodes)
}

///|
/// Whether every given node is observed.
pub fn CausalGraph::all_observed(
  self : CausalGraph,
  node_names : Array[String],
) -> Bool {
  for node_name in node_names {
    if !self.is_observed(node_name) {
      return false
    }
  }
  true
}

///|
/// Whether a node is observed.
pub fn CausalGraph::is_observed(self : CausalGraph, node_name : String) -> Bool {
  self.observed.get(node_name).unwrap_or(false)
}

///|
/// The observed nodes of the graph.
pub fn CausalGraph::observed_nodes(self : CausalGraph) -> Array[String] {
  let out : Array[String] = []
  for node in self.graph.node_list() {
    if self.is_observed(node) {
      out.push(node)
    }
  }
  out
}

///|
/// The nodes of the graph.
pub fn CausalGraph::get_all_nodes(
  self : CausalGraph,
  include_unobserved : Bool,
) -> Array[String] {
  let out : Array[String] = []
  for node in self.graph.node_list() {
    if include_unobserved || self.is_observed(node) {
      out.push(node)
    }
  }
  out
}

///|
/// A graph with the edges of the given nodes removed.
pub fn CausalGraph::do_surgery(
  self : CausalGraph,
  node_names : Array[String],
  remove_outgoing_edges : Bool,
  remove_incoming_edges : Bool,
  target_node_names : Array[String],
  remove_only_direct_edges_to_target : Bool,
) -> DirectedGraph {
  do_surgery(
    self.graph,
    node_names,
    remove_outgoing_edges,
    remove_incoming_edges,
    target_node_names,
    remove_only_direct_edges_to_target,
  )
}

///|
/// The common causes of two node sets.
///
/// The treatment contributes its ancestors, the outcome contributes its
/// parents and their ancestors.
pub fn CausalGraph::get_common_causes(
  self : CausalGraph,
  nodes1 : Array[String],
  nodes2 : Array[String],
) -> Array[String] {
  let causes_1 : Set[String] = Set::Set([])
  for node in nodes1 {
    for ancestor in self.graph.ancestors(node).to_array() {
      causes_1.add(ancestor)
    }
  }
  let causes_2 : Set[String] = Set::Set([])
  for node in nodes2 {
    for parent in self.graph.predecessors(node) {
      if !nodes1.contains(parent) {
        causes_2.add(parent)
        for ancestor in self.graph.ancestors(parent).to_array() {
          causes_2.add(ancestor)
        }
      }
    }
  }
  let out : Array[String] = []
  for node in causes_1.to_array() {
    if causes_2.contains(node) {
      out.push(node)
    }
  }
  out
}

///|
/// The effect modifiers of the graph.
pub fn CausalGraph::get_effect_modifiers(
  self : CausalGraph,
  nodes1 : Array[String],
  nodes2 : Array[String],
) -> Array[String] {
  let modifiers : Set[String] = Set::Set([])
  for node in nodes2 {
    for ancestor in self.graph.ancestors(node).to_array() {
      modifiers.add(ancestor)
    }
  }
  for node in nodes1 {
    modifiers.remove(node)
  }
  for node in nodes1 {
    for ancestor in self.graph.ancestors(node).to_array() {
      modifiers.remove(ancestor)
    }
  }
  // Remove every mediator.
  for node1 in nodes1 {
    for node2 in nodes2 {
      for path in self.graph.all_simple_paths(node1, node2) {
        for node in path {
          modifiers.remove(node)
        }
      }
    }
  }
  for node in self.effect_modifiers {
    modifiers.add(node)
  }
  modifiers.to_array()
}

///|
/// Whether the two node sets are d-separated given the conditioning set.
pub fn CausalGraph::check_dseparation(
  self : CausalGraph,
  nodes1 : Array[String],
  nodes2 : Array[String],
  nodes3 : Array[String],
  new_graph : DirectedGraph?,
) -> Bool {
  let graph = match new_graph {
    Some(g) => g
    None => self.graph
  }
  d_separated(graph, nodes1, nodes2, nodes3)
}

///|
/// Whether the candidate set blocks the backdoor paths.
///
/// The default algorithm of the upstream removes the outgoing edges of the
/// treatment and asks for the d-separation of the two node sets given the
/// candidate set; the naive one asks for every backdoor path to be blocked.
pub fn CausalGraph::check_valid_backdoor_set(
  self : CausalGraph,
  nodes1 : Array[String],
  nodes2 : Array[String],
  nodes3 : Array[String],
  new_graph : DirectedGraph?,
  algo~ : DseparationAlgorithm = DseparationAlgorithm::default(),
) -> Bool {
  match algo {
    Naive => {
      let paths = get_backdoor_paths(self.graph, nodes1, nodes2)
      for path in paths {
        if !is_blocked(self.graph, path, nodes3) {
          return false
        }
      }
      true
    }
    Default =>
      match new_graph {
        Some(graph) => d_separated(graph, nodes1, nodes2, nodes3)
        None => {
          let graph = self.do_surgery(nodes1, true, false, [], false)
          d_separated(graph, nodes1, nodes2, nodes3)
        }
      }
  }
}

///|
/// Whether the candidate set is a valid frontdoor set.
///
/// The default algorithm of the upstream asks for the d-separation of the two
/// node sets given the candidate set; the naive one asks for every directed
/// path from the treatment to the outcome to be blocked.
pub fn CausalGraph::check_valid_frontdoor_set(
  self : CausalGraph,
  nodes1 : Array[String],
  nodes2 : Array[String],
  candidate_nodes : Array[String],
  frontdoor_paths : Array[Array[String]],
  new_graph : DirectedGraph?,
  algo~ : DseparationAlgorithm = DseparationAlgorithm::default(),
) -> Bool {
  match algo {
    Naive => {
      let paths = if frontdoor_paths.length() == 0 {
        self.get_all_directed_paths(nodes1, nodes2)
      } else {
        frontdoor_paths
      }
      for path in paths {
        if !is_blocked(self.graph, path, candidate_nodes) {
          return false
        }
      }
      true
    }
    Default =>
      match new_graph {
        Some(graph) => d_separated(graph, nodes1, nodes2, candidate_nodes)
        None => d_separated(self.graph, nodes1, nodes2, candidate_nodes)
      }
  }
}

///|
/// Whether the candidate set mediates the effect.
pub fn CausalGraph::check_valid_mediation_set(
  self : CausalGraph,
  nodes1 : Array[String],
  nodes2 : Array[String],
  candidate_nodes : Array[String],
  mediation_paths : Array[Array[String]],
) -> Bool {
  check_valid_mediation_set(
    self.graph,
    nodes1,
    nodes2,
    candidate_nodes,
    mediation_paths,
  )
}

///|
/// The directed paths between two singleton node sets.
pub fn CausalGraph::get_all_directed_paths(
  self : CausalGraph,
  nodes1 : Array[String],
  nodes2 : Array[String],
) -> Array[Array[String]] {
  get_all_directed_paths(self.graph, nodes1, nodes2)
}

///|
/// Whether every treatment reaches an outcome and vice versa.
pub fn CausalGraph::has_directed_path(
  self : CausalGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
) -> Bool {
  has_directed_path(self.graph, action_nodes, outcome_nodes)
}

///|
/// The instruments of the treatment.
pub fn CausalGraph::get_instruments(
  self : CausalGraph,
  treatment_nodes : Array[String],
  outcome_nodes : Array[String],
) -> Array[String] {
  get_instruments(self.graph, treatment_nodes, outcome_nodes)
}

///|
/// The adjacency matrix of the graph.
pub fn CausalGraph::get_adjacency_matrix(self : CausalGraph) -> @utils.Matrix {
  let nodes = self.graph.node_list()
  let n = nodes.length()
  let matrix = @utils.Matrix::zeros(n, n)
  for (from, to) in self.graph.edge_list() {
    let mut i = 0
    let mut j = 0
    while i < nodes.length() {
      if nodes[i] == from {
        break
      }
      i = i + 1
    }
    while j < nodes.length() {
      if nodes[j] == to {
        break
      }
      j = j + 1
    }
    matrix.set(i, j, 1.0)
  }
  matrix
}

///|
/// Add an unobserved common cause to the graph.
pub fn CausalGraph::add_unobserved_common_cause(
  self : CausalGraph,
) -> DirectedGraph {
  let current = self.get_common_causes(self.treatment_name, self.outcome_name)
  let mut create_new = true
  for node_name in current {
    if !self.is_observed(node_name) {
      create_new = false
    }
  }
  if create_new {
    self.graph.add_node("U")
    self.observed.set("U", false)
    for node in self.treatment_name + self.outcome_name {
      self.graph.add_edge("U", node)
    }
  }
  self.graph
}

///|
/// Add the columns of the data that are not part of the graph as confounders.
pub fn CausalGraph::add_missing_nodes_as_common_causes(
  self : CausalGraph,
  observed_node_names : Array[String],
) -> DirectedGraph {
  for node_name in observed_node_names {
    if !self.graph.has_node(node_name) {
      self.graph.add_node(node_name)
      self.observed.set(node_name, true)
      for node in self.treatment_name + self.outcome_name {
        self.graph.add_edge(node_name, node)
      }
    }
  }
  self.graph
}
