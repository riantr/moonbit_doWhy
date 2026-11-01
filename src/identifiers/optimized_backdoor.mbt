///|
/// The optimized backdoor search of the `identifiers` package.
///
/// This is the port of `dowhy.causal_identifier.backdoor`. The search walks
/// the paths between the treatment and the outcome, keeps the ones that are
/// backdoor paths, and finds a small set of variables that blocks all of them
/// with the greedy hitting set algorithm of the upstream.
///
/// Two things are different on purpose:
/// - the upstream breaks a tie in its hitting set algorithm with the iteration
///   order of a Python dictionary of strings, and the order of the strings
///   changes between the runs of the interpreter. The port breaks the tie with
///   the name of the variable, so its result does not change.
/// - the upstream keeps the state of a pair of nodes and of a path only for
///   its own printing. The port keeps the variables that block the paths and
///   nothing else.

///|
/// The backdoor sets of the optimized search.
///
/// The search returns one set per pair of a treatment and an outcome, and no
/// set for a pair whose paths are all blocked already.
pub fn optimized_backdoor_adjustment(
  graph : @graph.DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
) -> Array[AdjustmentSet] {
  let search = OptimizedBackdoorSearch::new(graph, action_nodes, outcome_nodes)
  search.get_backdoor_vars()
}

///|
/// The state of the paths between two nodes.
///
/// This is the port of `dowhy.causal_identifier.backdoor.NodePair`. The
/// upstream keeps the names of the two nodes and the flag that says whether
/// all the paths between them are blocked; the port keeps neither, because the
/// search does not read them.
priv struct NodePair {
  condition_vars : Array[Set[String]]
  mut complete : Bool
}

///|
/// A new pair of nodes without any path.
fn NodePair::new() -> NodePair {
  { condition_vars: [], complete: false, }
}

///|
/// The variables that block the paths of the pair.
///
/// The upstream adds the variables of a path that is not blocked, and adds the
/// variables of a path together with the ones that block the other paths.
fn NodePair::add_path(self : NodePair, variables : Set[String]) -> Unit {
  self.condition_vars.push(variables)
}

///|
/// One path between two nodes.
///
/// This is the port of `dowhy.causal_identifier.backdoor.Path`.
priv struct PathVar {
  mut is_blocked : Bool
  condition_vars : Set[String]
}

///|
/// A new path that is not blocked.
fn PathVar::new() -> PathVar {
  { is_blocked: false, condition_vars: Set::Set([]), }
}

///|
/// The variables of the given path.
///
/// The variables that block the path are the nodes of the path without its
/// first and its last node, and a blocked path has no variables. The path
/// starts at the given index of the path of the search.
fn PathVar::update(
  self : PathVar,
  path : Array[String],
  from : Int32,
  is_blocked : Bool,
) -> Unit {
  self.is_blocked = is_blocked
  if !is_blocked {
    for index in (from + 1)..<(path.length() - 1) {
      self.condition_vars.add(path[index])
    }
  }
}

///|
/// The search of the optimized backdoor sets.
priv struct OptimizedBackdoorSearch {
  graph : @graph.DirectedGraph
  nodes1 : Array[String]
  nodes2 : Array[String]
  nodes12 : Set[String]
  colliders : Set[String]
  adjacency : Map[String, Array[String]]
  path_dict : Map[(String, String), NodePair]
}

///|
/// The search of the optimized backdoor sets of the given graph.
fn OptimizedBackdoorSearch::new(
  graph : @graph.DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
) -> OptimizedBackdoorSearch {
  let nodes12 : Set[String] = Set::Set([])
  for node in action_nodes {
    nodes12.add(node)
  }
  for node in outcome_nodes {
    nodes12.add(node)
  }
  {
    graph,
    nodes1: action_nodes,
    nodes2: outcome_nodes,
    nodes12,
    colliders: Set::Set([]),
    adjacency: undirected_adjacency(graph),
    path_dict: Map([]),
  }
}

///|
/// The backdoor sets of the search.
///
/// The upstream adds a set for every pair of a treatment and an outcome whose
/// paths were found. The upstream checks that the whole table of the pairs is
/// not empty and reads the pair out of it, which raises an error when a pair
/// has no path and another pair has one; the port checks the pair itself, and
/// a pair without a path gets no set.
fn OptimizedBackdoorSearch::get_backdoor_vars(
  self : OptimizedBackdoorSearch,
) -> Array[AdjustmentSet] {
  let sets : Array[AdjustmentSet] = []
  for node1 in self.nodes1 {
    for node2 in self.nodes2 {
      let key = (node1, node2)
      if self.path_dict.contains(key) {
        continue
      }
      self.path_search(node1, node2)
      let pair = match self.path_dict.get(key) {
        Some(found) => found
        None => continue
      }
      let hitting = HittingSetAlgorithm::new(
        pair.condition_vars.copy(),
        self.colliders,
      )
      let variables = hitting.find_set().to_array()
      variables.sort_by(fn(a, b) { a.lexical_compare(b) })
      sets.push(AdjustmentSet::new("backdoor", variables))
    }
  }
  sets
}

///|
/// The search of the paths between two nodes.
fn OptimizedBackdoorSearch::path_search(
  self : OptimizedBackdoorSearch,
  node1 : String,
  node2 : String,
) -> Unit {
  let visited : Set[String] = Set::Set([])
  let path : Array[String] = []
  self.path_search_util(node1, node2, visited, path, false, false)
}

///|
/// The search of the paths between two nodes, one node at a time.
///
/// The `is_blocked` flag says that the path that reaches the node is blocked
/// by a collider, and the `prev_arrow_incoming` flag says that the arrow that
/// reaches the node points into it. Two arrows into the same node open the
/// path again, so the search blocks it and remembers the node as a collider.
fn OptimizedBackdoorSearch::path_search_util(
  self : OptimizedBackdoorSearch,
  node1 : String,
  node2 : String,
  visited : Set[String],
  path : Array[String],
  is_blocked : Bool,
  prev_arrow_incoming : Bool,
) -> Unit {
  if is_blocked {
    return
  }
  let key = (node1, node2)
  let complete = match self.path_dict.get(key) {
    Some(pair) => pair.complete
    None => false
  }
  if complete {
    // The paths between the two nodes are known already, so the variables
    // that block them block the paths that reach the pair as well.
    let source = self.path_dict.get(key).unwrap()
    let hitting = HittingSetAlgorithm::new(
      source.condition_vars.copy(),
      self.colliders,
    )
    let variables : Set[String] = Set::Set([])
    variables.add(node1)
    for name in hitting.find_set().to_array() {
      variables.add(name)
    }
    for index in 0..<path.length() {
      let sub_key = (path[index], node2)
      if !self.path_dict.contains(sub_key) {
        self.path_dict.set(sub_key, NodePair::new())
      }
      let pair = self.path_dict.get(sub_key).unwrap()
      let path_variables : Set[String] = Set::Set([])
      for position in (index + 1)..<path.length() {
        path_variables.add(path[position])
      }
      for name in variables.to_array() {
        path_variables.add(name)
      }
      pair.add_path(path_variables)
    }
  } else {
    path.push(node1)
    visited.add(node1)
    if node1 == node2 {
      if self.is_backdoor(path) && self.is_free_of_endpoints(path) {
        for index in 0..<(path.length() - 1) {
          let sub_key = (path[index], node2)
          if !self.path_dict.contains(sub_key) {
            self.path_dict.set(sub_key, NodePair::new())
          }
          let pair = self.path_dict.get(sub_key).unwrap()
          let path_var = PathVar::new()
          path_var.update(path, index, is_blocked)
          // A path that a collider blocks is already blocked, so it has no
          // variables and it is not added to the pair.
          if !path_var.is_blocked {
            pair.add_path(path_var.condition_vars.copy())
          }
        }
      }
    } else {
      // The upstream keeps the flag of the blocked path in the variable of the
      // function, so a path that a collider blocks stays blocked for the rest
      // of the neighbours of the node.
      let mut blocked = is_blocked
      for neighbour in self.adjacency.get(node1).unwrap_or([]) {
        if !visited.contains(neighbour) {
          // The arrow points into the node when the graph has no edge from the
          // node to the neighbour.
          let next_incoming = !self.graph.has_edge(node1, neighbour)
          if next_incoming && prev_arrow_incoming {
            blocked = true
            self.colliders.add(node1)
          }
          self.path_search_util(
            neighbour,
            node2,
            visited,
            path,
            blocked,
            !next_incoming,
          )
        }
      }
    }
    let _ = path.pop()
    visited.remove(node1)
  }
  match self.path_dict.get(key) {
    Some(pair) => pair.complete = true
    None => ()
  }
}

///|
/// Whether the path starts with an arrow into its first node.
fn OptimizedBackdoorSearch::is_backdoor(
  self : OptimizedBackdoorSearch,
  path : Array[String],
) -> Bool {
  if path.length() < 2 {
    return false
  }
  self.graph.has_edge(path[1], path[0])
}

///|
/// Whether the path has no treatment and no outcome between its ends.
fn OptimizedBackdoorSearch::is_free_of_endpoints(
  self : OptimizedBackdoorSearch,
  path : Array[String],
) -> Bool {
  for index in 1..<(path.length() - 1) {
    if self.nodes12.contains(path[index]) {
      return false
    }
  }
  true
}

///|
/// The neighbours of every node of the graph, without the direction of the
/// edges.
///
/// The neighbours of a node are in the order of the nodes of the graph, which
/// is the order the upstream gets them from its adjacency matrix.
fn undirected_adjacency(
  graph : @graph.DirectedGraph,
) -> Map[String, Array[String]] {
  let adjacency : Map[String, Array[String]] = Map([])
  let nodes = graph.node_list()
  for node in nodes {
    adjacency.set(node, [])
  }
  for node in nodes {
    let neighbours : Array[String] = []
    for other in nodes {
      if other != node &&
        (graph.has_edge(node, other) || graph.has_edge(other, node)) &&
        !neighbours.contains(other) {
        neighbours.push(other)
      }
    }
    adjacency.set(node, neighbours)
  }
  adjacency
}

///|
/// The greedy hitting set algorithm of the upstream.
///
/// This is the port of `dowhy.causal_identifier.backdoor.HittingSetAlgorithm`.
/// The algorithm picks the variable that is in the most of the sets that are
/// not covered yet, and repeats until every set holds a variable of the
/// result.
priv struct HittingSetAlgorithm {
  list_of_sets : Array[Set[String]]
  colliders : Set[String]
  var_count : Map[String, Int32]
}

///|
/// The hitting set algorithm of the given sets.
fn HittingSetAlgorithm::new(
  list_of_sets : Array[Set[String]],
  colliders : Set[String],
) -> HittingSetAlgorithm {
  let algorithm = { list_of_sets, colliders, var_count: Map([]), }
  algorithm.count_vars(all_indices(algorithm.list_of_sets.length()))
  algorithm
}

///|
/// Every index of the list of the sets.
fn all_indices(count : Int32) -> Array[Int32] {
  let indices : Array[Int32] = []
  for index in 0..<count {
    indices.push(index)
  }
  indices
}

///|
/// The number of the sets that every variable is in.
///
/// The variables that are colliders are left out, because a collider cannot be
/// conditioned on.
fn HittingSetAlgorithm::count_vars(
  self : HittingSetAlgorithm,
  set_index : Array[Int32],
) -> Unit {
  for index in set_index {
    let variables = self.list_of_sets[index]
    for name in variables.to_array() {
      if !self.colliders.contains(name) {
        match self.var_count.get(name) {
          Some(count) => self.var_count.set(name, count + 1)
          None => self.var_count.set(name, 1)
        }
      }
    }
  }
}

///|
/// The variables of the sets that are covered already are counted one less.
fn HittingSetAlgorithm::modify_count(
  self : HittingSetAlgorithm,
  indices_covered : Array[Int32],
) -> Unit {
  for index in indices_covered {
    let variables = self.list_of_sets[index]
    for name in variables.to_array() {
      if !self.colliders.contains(name) {
        match self.var_count.get(name) {
          Some(count) => self.var_count.set(name, count - 1)
          None => ()
        }
      }
    }
  }
}

///|
/// The variable that is in the most of the sets.
fn HittingSetAlgorithm::max_occurrence_var(
  self : HittingSetAlgorithm,
) -> String? {
  let mut best : String? = None
  let mut best_count = 0
  let names = self.var_count.keys().to_array()
  names.sort_by(fn(a, b) { a.lexical_compare(b) })
  for name in names {
    let count = self.var_count.get(name).unwrap_or(0)
    if count > best_count {
      best_count = count
      best = Some(name)
    }
  }
  best
}

///|
/// The indices of the sets that hold the given variable.
fn HittingSetAlgorithm::indices_covered(
  self : HittingSetAlgorithm,
  name : String,
  set_index : Array[Int32],
) -> Array[Int32] {
  let covered : Array[Int32] = []
  for index in set_index {
    if self.list_of_sets[index].contains(name) {
      covered.push(index)
    }
  }
  covered
}

///|
/// The set of variables that hits every one of the sets.
fn HittingSetAlgorithm::find_set(self : HittingSetAlgorithm) -> Set[String] {
  let var_set : Set[String] = Set::Set([])
  let num_indices = self.list_of_sets.length()
  let mut indices_covered : Array[Int32] = []
  while indices_covered.length() < num_indices {
    let uncovered : Array[Int32] = []
    for index in all_indices(num_indices) {
      if !indices_covered.contains(index) {
        uncovered.push(index)
      }
    }
    let max_el = self.max_occurrence_var()
    if max_el is None {
      break
    }
    var_set.add(max_el.unwrap())
    let covered = self.indices_covered(max_el.unwrap(), uncovered)
    self.modify_count(covered)
    indices_covered = indices_covered + covered
  }
  var_set
}
