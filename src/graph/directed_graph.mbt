///|
/// A directed graph, the substrate of every causal graph in the library.
///
/// Node and edge insertion order is preserved, which keeps the generated
/// results (adjustment sets, paths, topological orders) deterministic.
pub struct DirectedGraph {
  mut nodes : Array[String]
  node_set : Set[String]
  succ : Map[String, Array[String]]
  pred : Map[String, Array[String]]
  mut edges : Array[(String, String)]
}

///|
/// A new empty graph.
pub fn DirectedGraph::new() -> DirectedGraph {
  {
    nodes: [],
    node_set: Set::Set([]),
    succ: Map([]),
    pred: Map([]),
    edges: [],
  }
}

///|
/// Add a node, ignoring duplicates.
pub fn DirectedGraph::add_node(self : DirectedGraph, name : String) -> Unit {
  if !self.node_set.contains(name) {
    self.node_set.add(name)
    self.nodes.push(name)
  }
}

///|
/// Add an edge, creating the endpoints when they are new.
pub fn DirectedGraph::add_edge(
  self : DirectedGraph,
  from : String,
  to : String,
) -> Unit {
  self.add_node(from)
  self.add_node(to)
  if !self.has_edge(from, to) {
    self.edges.push((from, to))
    let s = self.succ.get(from).unwrap_or([])
    s.push(to)
    self.succ.set(from, s)
    let p = self.pred.get(to).unwrap_or([])
    p.push(from)
    self.pred.set(to, p)
  }
}

///|
/// Whether the graph contains the node.
pub fn DirectedGraph::has_node(self : DirectedGraph, name : String) -> Bool {
  self.node_set.contains(name)
}

///|
/// Whether the graph contains the edge.
pub fn DirectedGraph::has_edge(
  self : DirectedGraph,
  from : String,
  to : String,
) -> Bool {
  match self.succ.get(from) {
    Some(children) => children.contains(to)
    None => false
  }
}

///|
/// The nodes of the graph in insertion order.
pub fn DirectedGraph::node_list(self : DirectedGraph) -> Array[String] {
  self.nodes.copy()
}

///|
/// The edges of the graph in insertion order.
pub fn DirectedGraph::edge_list(
  self : DirectedGraph,
) -> Array[(String, String)] {
  self.edges.copy()
}

///|
/// The number of nodes.
pub fn DirectedGraph::node_count(self : DirectedGraph) -> Int32 {
  self.nodes.length()
}

///|
/// The number of edges.
pub fn DirectedGraph::edge_count(self : DirectedGraph) -> Int32 {
  self.edges.length()
}

///|
/// The children of a node.
///
/// The returned array is a copy, so a caller may modify it without changing
/// the graph.
pub fn DirectedGraph::successors(
  self : DirectedGraph,
  name : String,
) -> Array[String] {
  self.succ.get(name).unwrap_or([]).copy()
}

///|
/// The parents of a node.
///
/// The returned array is a copy, so a caller may modify it without changing
/// the graph.
pub fn DirectedGraph::predecessors(
  self : DirectedGraph,
  name : String,
) -> Array[String] {
  self.pred.get(name).unwrap_or([]).copy()
}

///|
/// The strict ancestors of a node.
pub fn DirectedGraph::ancestors(
  self : DirectedGraph,
  name : String,
) -> Set[String] {
  let seen : Set[String] = Set::Set([])
  let stack = self.predecessors(name)
  while stack.length() > 0 {
    let node = stack[stack.length() - 1]
    let _ = stack.pop()
    if !seen.contains(node) {
      seen.add(node)
      for parent in self.predecessors(node) {
        stack.push(parent)
      }
    }
  }
  seen
}

///|
/// The strict descendants of a node.
pub fn DirectedGraph::descendants(
  self : DirectedGraph,
  name : String,
) -> Set[String] {
  let seen : Set[String] = Set::Set([])
  let stack = self.successors(name)
  while stack.length() > 0 {
    let node = stack[stack.length() - 1]
    let _ = stack.pop()
    if !seen.contains(node) {
      seen.add(node)
      for child in self.successors(node) {
        stack.push(child)
      }
    }
  }
  seen
}

///|
/// The union of the descendants of several nodes.
pub fn DirectedGraph::descendants_of(
  self : DirectedGraph,
  names : Array[String],
) -> Set[String] {
  let seen : Set[String] = Set::Set([])
  for name in names {
    for node in self.descendants(name).to_array() {
      seen.add(node)
    }
  }
  seen
}

///|
/// The union of the ancestors of several nodes.
pub fn DirectedGraph::ancestors_of(
  self : DirectedGraph,
  names : Array[String],
) -> Set[String] {
  let seen : Set[String] = Set::Set([])
  for name in names {
    for node in self.ancestors(name).to_array() {
      seen.add(node)
    }
  }
  seen
}

///|
/// Whether a path exists from `from` to `to`.
pub fn DirectedGraph::has_path(
  self : DirectedGraph,
  from : String,
  to : String,
) -> Bool {
  if from == to {
    return self.has_node(from)
  }
  let seen : Set[String] = Set::Set([])
  let stack = [from]
  while stack.length() > 0 {
    let node = stack[stack.length() - 1]
    let _ = stack.pop()
    if node == to {
      return true
    }
    if !seen.contains(node) {
      seen.add(node)
      for child in self.successors(node) {
        stack.push(child)
      }
    }
  }
  false
}

///|
/// All simple paths from `from` to `to`.
///
/// The paths are enumerated in the order the neighbours are stored, which
/// keeps the result deterministic.
pub fn DirectedGraph::all_simple_paths(
  self : DirectedGraph,
  from : String,
  to : String,
) -> Array[Array[String]] {
  let paths : Array[Array[String]] = []
  if !self.has_node(from) || !self.has_node(to) {
    return paths
  }
  let current : Array[String] = [from]
  let on_path : Set[String] = Set::Set([])
  on_path.add(from)
  self.walk_paths(from, to, current, on_path, paths)
  paths
}

///|
fn DirectedGraph::walk_paths(
  self : DirectedGraph,
  current : String,
  target : String,
  path : Array[String],
  on_path : Set[String],
  paths : Array[Array[String]],
) -> Unit {
  if current == target {
    paths.push(path.copy())
    return
  }
  for child in self.successors(current) {
    if !on_path.contains(child) {
      on_path.add(child)
      path.push(child)
      self.walk_paths(child, target, path, on_path, paths)
      let _ = path.pop()
      on_path.remove(child)
    }
  }
}

///|
/// All simple paths between two nodes, ignoring the direction of the edges.
///
/// The backdoor paths live in the underlying undirected graph, so the
/// traversal walks both the parents and the children of a node.
pub fn DirectedGraph::all_simple_paths_undirected(
  self : DirectedGraph,
  from : String,
  to : String,
) -> Array[Array[String]] {
  let paths : Array[Array[String]] = []
  if !self.has_node(from) || !self.has_node(to) {
    return paths
  }
  let current : Array[String] = [from]
  let on_path : Set[String] = Set::Set([])
  on_path.add(from)
  self.walk_paths_undirected(from, to, current, on_path, paths)
  paths
}

///|
fn DirectedGraph::walk_paths_undirected(
  self : DirectedGraph,
  current : String,
  target : String,
  path : Array[String],
  on_path : Set[String],
  paths : Array[Array[String]],
) -> Unit {
  if current == target {
    paths.push(path.copy())
    return
  }
  for neighbour in self.successors(current) + self.predecessors(current) {
    if !on_path.contains(neighbour) {
      on_path.add(neighbour)
      path.push(neighbour)
      self.walk_paths_undirected(neighbour, target, path, on_path, paths)
      let _ = path.pop()
      on_path.remove(neighbour)
    }
  }
}

///|
/// Whether the graph is acyclic.
pub fn DirectedGraph::is_dag(self : DirectedGraph) -> Bool {
  let order = self.topological_order()
  order.length() == self.node_count()
}

///|
/// A topological order of the graph.
///
/// Returns an empty array when the graph has a cycle.
pub fn DirectedGraph::topological_order(self : DirectedGraph) -> Array[String] {
  let indegree : Map[String, Int32] = Map([])
  for node in self.nodes {
    indegree.set(node, self.predecessors(node).length())
  }
  let queue : Array[String] = []
  for node in self.nodes {
    let d = indegree.get(node).unwrap_or(0)
    if d == 0 {
      queue.push(node)
    }
  }
  let order : Array[String] = []
  let mut qi = 0
  while qi < queue.length() {
    let node = queue[qi]
    qi = qi + 1
    order.push(node)
    for child in self.successors(node) {
      let d = indegree.get(child).unwrap_or(0) - 1
      indegree.set(child, d)
      if d == 0 {
        queue.push(child)
      }
    }
  }
  order
}

///|
/// A copy of the graph.
pub fn DirectedGraph::copy(self : DirectedGraph) -> DirectedGraph {
  let g = DirectedGraph::new()
  for node in self.nodes {
    g.add_node(node)
  }
  for (from, to) in self.edges {
    g.add_edge(from, to)
  }
  g
}

///|
/// Remove an edge from the graph.
pub fn DirectedGraph::remove_edge(
  self : DirectedGraph,
  from : String,
  to : String,
) -> Unit {
  if !self.has_edge(from, to) {
    return
  }
  let new_edges : Array[(String, String)] = []
  for edge in self.edges {
    if !(edge.0 == from && edge.1 == to) {
      new_edges.push(edge)
    }
  }
  self.edges = new_edges
  let s = self.succ.get(from).unwrap_or([]).copy()
  let kept_s : Array[String] = []
  for child in s {
    if child != to {
      kept_s.push(child)
    }
  }
  self.succ.set(from, kept_s)
  let p = self.pred.get(to).unwrap_or([]).copy()
  let kept_p : Array[String] = []
  for parent in p {
    if parent != from {
      kept_p.push(parent)
    }
  }
  self.pred.set(to, kept_p)
}

///|
/// The sub graph induced by the given nodes.
pub fn DirectedGraph::subgraph(
  self : DirectedGraph,
  names : Array[String],
) -> DirectedGraph {
  let g = DirectedGraph::new()
  for name in names {
    g.add_node(name)
  }
  for (from, to) in self.edges {
    if g.has_node(from) && g.has_node(to) {
      g.add_edge(from, to)
    }
  }
  g
}

///|
/// The predecessors of a node, sorted by their name.
///
/// This is the port of `dowhy.graph.get_ordered_predecessors`. The order of the
/// predecessors is not reliable otherwise, and the columns of a data frame are
/// picked by the parents of a node.
pub fn DirectedGraph::ordered_predecessors(
  self : DirectedGraph,
  name : String,
) -> Array[String] {
  let predecessors = self.predecessors(name)
  predecessors.sort_by(fn(a, b) { a.lexical_compare(b) })
  predecessors
}

///|
/// The sub graph induced by the nodes that can reach the given node.
///
/// This is the port of `dowhy.graph.node_connected_subgraph_view`, which keeps
/// the nodes of the graph that have a path to the given node.
pub fn DirectedGraph::node_connected_subgraph_view(
  self : DirectedGraph,
  name : String,
) -> DirectedGraph {
  let names : Array[String] = []
  for node in self.node_list() {
    if self.has_path(node, name) {
      names.push(node)
    }
  }
  self.subgraph(names)
}

///|
/// Remove the node with the given name and every edge that touches it.
///
/// This is the port of `networkx.DiGraph.remove_node`. Removing a node that is
/// not in the graph does nothing.
pub fn DirectedGraph::remove_node(self : DirectedGraph, name : String) -> Unit {
  if !self.node_set.contains(name) {
    return
  }
  self.node_set.remove(name)
  let kept : Array[String] = []
  for node in self.nodes {
    if node != name {
      kept.push(node)
    }
  }
  self.nodes = kept
  self.succ.remove(name)
  self.pred.remove(name)
  let kept_edges : Array[(String, String)] = []
  for (from, to) in self.edges {
    if from != name && to != name {
      kept_edges.push((from, to))
    }
  }
  self.edges = kept_edges
  for node in self.nodes {
    let children = self.succ.get(node).unwrap_or([]).copy()
    let kept_children : Array[String] = []
    for child in children {
      if child != name {
        kept_children.push(child)
      }
    }
    self.succ.set(node, kept_children)
    let parents = self.pred.get(node).unwrap_or([]).copy()
    let kept_parents : Array[String] = []
    for parent in parents {
      if parent != name {
        kept_parents.push(parent)
      }
    }
    self.pred.set(node, kept_parents)
  }
}

///|
/// The graph in Graphviz DOT format.
pub fn DirectedGraph::to_dot(self : DirectedGraph) -> String {
  let mut out = "digraph {\n"
  for node in self.nodes {
    out = out + "  \"" + node + "\";\n"
  }
  for (from, to) in self.edges {
    out = out + "  \"" + from + "\" -> \"" + to + "\";\n"
  }
  out + "}\n"
}
