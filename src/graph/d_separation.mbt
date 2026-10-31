/// d-separation and the do-surgery operation on directed graphs.
///
/// The d-separation test follows Koller & Friedman's "Reachable" algorithm,
/// which is the same decision procedure that `networkx.is_d_separator` uses.

///|
/// Whether `x` and `y` are d-separated given `z`.
///
/// Returns `true` when the two node sets are separated by the conditioning
/// set.
///
/// The traversal follows the classical "active path" characterisation: a path
/// is active given `z` when every non collider on it is outside `z` and every
/// collider on it is in `z` or has a descendant in `z`. The descendant test
/// is what the ancestor set of `z` provides.
pub fn d_separated(
  graph : DirectedGraph,
  x : Array[String],
  y : Array[String],
  z : Array[String],
) -> Bool {
  let conditioned : Set[String] = Set::Set([])
  for node in z {
    conditioned.add(node)
  }
  // The ancestors of the conditioning set; a collider is opened when it, or
  // one of its descendants, is conditioned on.
  let ancestors = conditioned.copy()
  let stack = z.copy()
  while stack.length() > 0 {
    let node = stack[stack.length() - 1]
    let _ = stack.pop()
    for parent in graph.predecessors(node) {
      if !ancestors.contains(parent) {
        ancestors.add(parent)
        stack.push(parent)
      }
    }
  }
  // The traversal state is (node, direction) where `downwards` means the last
  // edge was traversed downwards (a parent of the node) and `false` means it
  // was traversed upwards (a child of the node).
  let visited_down : Set[String] = Set::Set([])
  let visited_up : Set[String] = Set::Set([])
  let queue : Array[(String, Bool)] = []
  let reachable : Set[String] = Set::Set([])
  for node in x {
    reachable.add(node)
    for child in graph.successors(node) {
      if !visited_down.contains(child) {
        visited_down.add(child)
        reachable.add(child)
        queue.push((child, true))
      }
    }
    for parent in graph.predecessors(node) {
      if !visited_up.contains(parent) {
        visited_up.add(parent)
        reachable.add(parent)
        queue.push((parent, false))
      }
    }
  }
  let mut head = 0
  while head < queue.length() {
    let (node, downwards) = queue[head]
    head = head + 1
    if downwards {
      // The last edge pointed into `node`.
      for child in graph.successors(node) {
        // Chain: allowed when `node` is not conditioned on.
        if !conditioned.contains(node) && !visited_down.contains(child) {
          visited_down.add(child)
          reachable.add(child)
          queue.push((child, true))
        }
      }
      for parent in graph.predecessors(node) {
        // Collider: allowed when the collider is opened by the conditioning.
        if ancestors.contains(node) && !visited_up.contains(parent) {
          visited_up.add(parent)
          reachable.add(parent)
          queue.push((parent, false))
        }
      }
    } else {
      // The last edge pointed out of `node`.
      for child in graph.successors(node) {
        // Fork: allowed when `node` is not conditioned on.
        if !conditioned.contains(node) && !visited_down.contains(child) {
          visited_down.add(child)
          reachable.add(child)
          queue.push((child, true))
        }
      }
      for parent in graph.predecessors(node) {
        // Chain: allowed when `node` is not conditioned on.
        if !conditioned.contains(node) && !visited_up.contains(parent) {
          visited_up.add(parent)
          reachable.add(parent)
          queue.push((parent, false))
        }
      }
    }
  }
  for node in y {
    if reachable.contains(node) {
      return false
    }
  }
  true
}

///|
/// A graph with the edges of the given nodes removed.
///
/// * `remove_outgoing_edges` drops every edge leaving the focal nodes;
/// * `remove_incoming_edges` drops every edge entering the focal nodes;
/// * `remove_only_direct_edges_to_target` restricts the removal to the edges
///   that point at `target_node_names`.
pub fn do_surgery(
  graph : DirectedGraph,
  node_names : Array[String],
  remove_outgoing_edges : Bool,
  remove_incoming_edges : Bool,
  target_node_names : Array[String],
  remove_only_direct_edges_to_target : Bool,
) -> DirectedGraph {
  let new_graph = graph.copy()
  for node_name in node_names {
    if remove_outgoing_edges {
      if remove_only_direct_edges_to_target {
        for target in target_node_names {
          new_graph.remove_edge(node_name, target)
        }
      } else {
        for child in new_graph.successors(node_name).copy() {
          new_graph.remove_edge(node_name, child)
        }
      }
    }
    if remove_incoming_edges {
      for parent in new_graph.predecessors(node_name).copy() {
        new_graph.remove_edge(parent, node_name)
      }
    }
  }
  new_graph
}

///|
/// The backdoor paths between two node sets.
///
/// A path is a backdoor path when its first edge points into the treatment.
pub fn get_backdoor_paths(
  graph : DirectedGraph,
  nodes1 : Array[String],
  nodes2 : Array[String],
) -> Array[Array[String]] {
  let paths : Array[Array[String]] = []
  for node1 in nodes1 {
    for node2 in nodes2 {
      for path in graph.all_simple_paths_undirected(node1, node2) {
        if path.length() < 2 {
          continue
        }
        if !graph.has_edge(path[1], path[0]) {
          continue
        }
        // Paths whose interior contains one of the endpoints are dropped.
        let mut blocked = false
        for i = 1; i < path.length() - 1; i = i + 1 {
          if nodes1.contains(path[i]) || nodes2.contains(path[i]) {
            blocked = true
          }
        }
        if !blocked {
          paths.push(path)
        }
      }
    }
  }
  paths
}

///|
/// Whether a path is blocked by the given conditioning set.
pub fn is_blocked(
  graph : DirectedGraph,
  path : Array[String],
  conditioned_nodes : Array[String],
) -> Bool {
  let conditioned : Set[String] = Set::Set([])
  for node in conditioned_nodes {
    conditioned.add(node)
  }
  let mut blocked_by_conditioning = false
  let mut has_unconditioned_collider = false
  let mut i = 0
  while i < path.length() - 2 {
    let a = path[i]
    let b = path[i + 1]
    let c = path[i + 2]
    if graph.has_edge(a, b) && graph.has_edge(c, b) {
      // Collider.
      if !conditioned.contains(b) {
        let mut collider_blocked = false
        for descendant in graph.descendants(b).to_array() {
          if conditioned.contains(descendant) {
            collider_blocked = true
          }
        }
        if !collider_blocked {
          has_unconditioned_collider = true
        }
      }
    } else if conditioned.contains(b) {
      blocked_by_conditioning = true
      break
    }
    i = i + 1
  }
  blocked_by_conditioning || has_unconditioned_collider
}

///|
/// Whether every treatment has a directed path to an outcome and vice versa.
pub fn has_directed_path(
  graph : DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
) -> Bool {
  let outcome_candidates = graph.descendants_of(action_nodes)
  let action_candidates = graph.ancestors_of(outcome_nodes)
  for node in outcome_nodes {
    if !outcome_candidates.contains(node) {
      return false
    }
  }
  for node in action_nodes {
    if !action_candidates.contains(node) {
      return false
    }
  }
  true
}

///|
/// The directed paths between two singleton node sets.
pub fn get_all_directed_paths(
  graph : DirectedGraph,
  nodes1 : Array[String],
  nodes2 : Array[String],
) -> Array[Array[String]] {
  if nodes1.length() != 1 || nodes2.length() != 1 {
    abort(
      "The list of action and outcome nodes can only contain one element, i.e., needs to be univariate!",
    )
  }
  graph.all_simple_paths(nodes1[0], nodes2[0])
}

///|
/// The nodes that lie on a proper causal path from the actions to the
/// outcomes, as defined by van der Zander et al.
pub fn get_proper_causal_path_nodes(
  graph : DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
) -> Set[String] {
  // Remove the incoming edges of the action nodes.
  let post_intervention = do_surgery(
    graph,
    action_nodes,
    false,
    true,
    [],
    false,
  )
  // Remove the outgoing edges of the action nodes.
  let with_sinks = do_surgery(graph, action_nodes, true, false, [], false)
  let descendants = post_intervention.descendants_of(action_nodes)
  for node in action_nodes {
    descendants.add(node)
  }
  let ancestors = with_sinks.ancestors_of(outcome_nodes)
  for node in outcome_nodes {
    ancestors.add(node)
  }
  let result : Set[String] = Set::Set([])
  for node in descendants.to_array() {
    if !action_nodes.contains(node) && ancestors.contains(node) {
      result.add(node)
    }
  }
  result
}

///|
/// The proper backdoor graph of the given causal graph.
pub fn get_proper_backdoor_graph(
  graph : DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
) -> DirectedGraph {
  let pcp_nodes = get_proper_causal_path_nodes(
    graph, action_nodes, outcome_nodes,
  )
  let graph_pbd = graph.copy()
  for action in action_nodes {
    for node in pcp_nodes.to_array() {
      graph_pbd.remove_edge(action, node)
    }
  }
  graph_pbd
}

///|
/// The instruments of the treatment, following `dowhy.graph.get_instruments`.
pub fn get_instruments(
  graph : DirectedGraph,
  treatment_nodes : Array[String],
  outcome_nodes : Array[String],
) -> Array[String] {
  let parents_treatment : Set[String] = Set::Set([])
  for node in treatment_nodes {
    for parent in graph.predecessors(node) {
      parents_treatment.add(parent)
    }
  }
  let no_parents = do_surgery(graph, treatment_nodes, false, true, [], false)
  let ancestors_outcome : Set[String] = Set::Set([])
  for node in outcome_nodes {
    for ancestor in no_parents.ancestors(node).to_array() {
      ancestors_outcome.add(ancestor)
    }
  }
  // Exclusion restriction.
  let candidates : Array[String] = []
  for node in parents_treatment.to_array() {
    if !ancestors_outcome.contains(node) {
      candidates.push(node)
    }
  }
  // As-if-random setup.
  let children : Set[String] = Set::Set([])
  for node in ancestors_outcome.to_array() {
    for descendant in no_parents.descendants(node).to_array() {
      children.add(descendant)
    }
  }
  let instruments : Array[String] = []
  for node in candidates {
    if !children.contains(node) {
      instruments.push(node)
    }
  }
  instruments
}
