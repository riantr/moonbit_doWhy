/// The graph operations of the upstream.
///
/// This is the port of `dowhy.utils.graph_operations`: the helpers that turn
/// an adjacency matrix into an adjacency list and into a graph, the ones that
/// cut a graph down to a subset of its nodes, the ones that find the ancestors
/// and the C-components of a graph, the ones that check whether a graph is
/// connected, and the ones that add or remove an edge without breaking the
/// graph.

///|
/// The adjacency list of an adjacency matrix.
///
/// This is the port of
/// `dowhy.utils.graph_operations.adjacency_matrix_to_adjacency_list`. The keys
/// are the labels of the nodes and the values are the labels of the children of
/// the nodes, in the order of the columns of the matrix.
///
/// The labels of the nodes are the numbers one, two and so on when the caller
/// gives none, the way the upstream numbers them.
pub fn adjacency_matrix_to_adjacency_list(
  matrix : @utils.Matrix,
  labels : Array[String]?,
) -> Map[String, Array[String]] {
  let names = match labels {
    Some(given) => given
    None => numbered_labels(matrix.nrows())
  }
  let list : Map[String, Array[String]] = Map([])
  for i in 0..<matrix.nrows() {
    let children : Array[String] = []
    for j in 0..<matrix.ncols() {
      if matrix.get(i, j) != 0.0 {
        children.push(names[j])
      }
    }
    list.set(names[i], children)
  }
  list
}

///|
/// The labels of the nodes of an adjacency matrix, numbered from one.
fn numbered_labels(count : Int32) -> Array[String] {
  let labels : Array[String] = []
  for i in 0..<count {
    labels.push((i + 1).to_string())
  }
  labels
}

///|
/// The labels of the nodes of an adjacency matrix, named after the `x` of their
/// index.
fn indexed_labels(count : Int32) -> Array[String] {
  let labels : Array[String] = []
  for i in 0..<count {
    labels.push("x" + i.to_string())
  }
  labels
}

///|
/// The DOT graph of an adjacency matrix.
///
/// This is the port of `dowhy.utils.graph_operations.adjacency_matrix_to_graph`,
/// which builds a `graphviz.Digraph` of the matrix. The port returns the source
/// of that graph, the way the upstream reads it back with `str_to_dot`.
///
/// Only the edges whose weight is larger than `0.01` in absolute value become
/// edges of the graph, and the label of an edge is its weight.
///
/// The upstream draws the edges from the column to the row of the matrix, the
/// way its own loop over the indices of the matrix does; the port does the
/// same.
pub fn adjacency_matrix_to_dot(
  matrix : @utils.Matrix,
  labels : Array[String]?,
) -> String {
  let names = match labels {
    Some(given) => given
    None => indexed_labels(matrix.nrows())
  }
  let mut text = "digraph {\n"
  for name in names {
    text = text + "\t" + name + "\n"
  }
  for i in 0..<matrix.nrows() {
    for j in 0..<matrix.ncols() {
      let weight = matrix.get(i, j)
      if weight.abs() > 0.01 {
        text = text +
          "\t" +
          names[j] +
          " -> " +
          names[i] +
          " [label=" +
          @utils.float_text(weight) +
          "]\n"
      }
    }
  }
  text + "}\n"
}

///|
/// The compact DOT graph of a DOT graph.
///
/// This is the port of `dowhy.utils.graph_operations.str_to_dot`. The upstream
/// turns every line of the graph into a statement of its own, drops the
/// semicolon that follows the opening brace and the one that precedes the
/// closing brace, and keeps the braces.
///
/// The result is a graph the DOT reader of the port reads.
pub fn str_to_dot(text : String) -> String {
  let compact = text
    .trim()
    .replace_all(old="\n", new=";")
    .replace_all(old="\t", new="")
    .to_owned()
  let count = compact.length()
  if count == 0 {
    return ""
  }
  let tail = compact[count - 1:count].to_owned()
  if count < 9 {
    return compact + tail
  }
  let head = compact[0:9].to_owned()
  if count < 12 {
    return head + tail
  }
  let body = compact[10:count - 2].to_owned()
  head + body + tail
}

///|
/// The ancestors of the given nodes, the nodes themselves included.
///
/// This is the port of `dowhy.utils.graph_operations.find_ancestor`.
pub fn find_ancestor(
  graph : DirectedGraph,
  nodes : Array[String],
) -> Set[String] {
  let ancestors : Set[String] = Set::Set([])
  for node in nodes {
    let stack : Array[String] = [node]
    while stack.length() > 0 {
      let current = stack[stack.length() - 1]
      let _ = stack.pop()
      if !ancestors.contains(current) {
        ancestors.add(current)
        for parent in graph.predecessors(current) {
          if !ancestors.contains(parent) {
            stack.push(parent)
          }
        }
      }
    }
  }
  ancestors
}

///|
/// The graph induced by the given nodes.
///
/// This is the port of `dowhy.utils.graph_operations.induced_graph`.
pub fn induced_graph(
  graph : DirectedGraph,
  nodes : Array[String],
) -> DirectedGraph {
  graph.subgraph(nodes)
}

///|
/// The C-components of the graph.
///
/// This is the port of `dowhy.utils.graph_operations.find_c_components`: the
/// connected components of the graph of the edges that point in both
/// directions.
pub fn find_c_components(
  graph : DirectedGraph,
  nodes : Array[String],
) -> Array[Array[String]] {
  let adjacency : Map[String, Array[String]] = Map([])
  for node in nodes {
    adjacency.set(node, [])
  }
  for i in 0..<(nodes.length() - 1) {
    for j in (i + 1)..<nodes.length() {
      let first = nodes[i]
      let second = nodes[j]
      if graph.has_edge(first, second) && graph.has_edge(second, first) {
        let first_neighbours = adjacency.get(first).unwrap_or([]).copy()
        first_neighbours.push(second)
        adjacency.set(first, first_neighbours)
        let second_neighbours = adjacency.get(second).unwrap_or([]).copy()
        second_neighbours.push(first)
        adjacency.set(second, second_neighbours)
      }
    }
  }
  let components : Array[Array[String]] = []
  let visited : Set[String] = Set::Set([])
  for node in nodes {
    if !visited.contains(node) {
      let component : Array[String] = []
      collect_component(node, adjacency, visited, component)
      components.push(component)
    }
  }
  components
}

///|
/// The connected component of the node in the graph of the bidirected edges.
fn collect_component(
  node : String,
  adjacency : Map[String, Array[String]],
  visited : Set[String],
  component : Array[String],
) -> Unit {
  visited.add(node)
  component.push(node)
  for neighbour in adjacency.get(node).unwrap_or([]) {
    if !visited.contains(neighbour) {
      collect_component(neighbour, adjacency, visited, component)
    }
  }
}

///|
/// The simple ordered tree of the given number of nodes.
///
/// This is the port of `dowhy.utils.graph_operations.get_simple_ordered_tree`:
/// the graph `0 -> 1 -> ...`, whose nodes are numbered from zero.
pub fn get_simple_ordered_tree(count : Int32) -> DirectedGraph {
  let graph = DirectedGraph::new()
  for i in 0..<count {
    graph.add_node(i.to_string())
  }
  if count > 1 {
    for i in 0..<(count - 1) {
      graph.add_edge(i.to_string(), (i + 1).to_string())
    }
  }
  graph
}

///|
/// Whether the graph is connected when its edges are read in both directions.
///
/// This is the port of `dowhy.utils.graph_operations.is_connected`.
pub fn is_connected(graph : DirectedGraph) -> Bool {
  let nodes = graph.node_list()
  if nodes.length() <= 1 {
    return true
  }
  let seen : Set[String] = Set::Set([nodes[0]])
  let stack : Array[String] = [nodes[0]]
  while stack.length() > 0 {
    let node = stack[stack.length() - 1]
    let _ = stack.pop()
    for neighbour in undirected_neighbours(graph, node) {
      if !seen.contains(neighbour) {
        seen.add(neighbour)
        stack.push(neighbour)
      }
    }
  }
  seen.length() == nodes.length()
}

///|
/// The neighbours of a node, with the edges read in both directions.
fn undirected_neighbours(graph : DirectedGraph, node : String) -> Array[String] {
  let out : Array[String] = []
  for successor in graph.successors(node) {
    out.push(successor)
  }
  for predecessor in graph.predecessors(node) {
    out.push(predecessor)
  }
  out
}

///|
/// The graph of the edges of the graph, read in both directions.
///
/// This is the port of
/// `dowhy.utils.graph_operations.convert_to_undirected_graph`. The port has no
/// undirected graph, so every edge of the graph becomes an edge in both
/// directions.
pub fn convert_to_undirected_graph(graph : DirectedGraph) -> DirectedGraph {
  let result = DirectedGraph::new()
  for node in graph.node_list() {
    result.add_node(node)
  }
  for (from, to) in graph.edge_list() {
    result.add_edge(from, to)
    if from != to {
      result.add_edge(to, from)
    }
  }
  result
}

///|
/// A pair of two different nodes.
///
/// This is the port of `dowhy.utils.graph_operations.get_random_node_pair`. The
/// upstream draws the two numbers from the global generator of numpy; the port
/// draws them from the generator it is given, so the two numbers are the
/// numbers of numpy for the seed of that generator.
///
/// The upstream loops forever when there is only one node, because the second
/// number can never differ from the first one; the port does the same.
pub fn get_random_node_pair(
  count : Int32,
  random : @utils.NumpyRandom,
) -> (Int32, Int32) {
  let i = random.randint(count)
  let mut j = random.randint(count)
  while j == i {
    j = random.randint(count)
  }
  (i, j)
}

///|
/// A predecessor of the second node on a path to the first one.
///
/// This is the port of `dowhy.utils.graph_operations.find_predecessor`: the
/// first parent of the second node whose path to the first node exists when the
/// edges are read in both directions.
pub fn find_predecessor(
  graph : DirectedGraph,
  i : String,
  j : String,
) -> String? {
  let undirected = convert_to_undirected_graph(graph)
  for parent in graph.predecessors(j) {
    if undirected.has_path(parent, i) {
      return Some(parent)
    }
  }
  None
}

///|
/// Remove the edge between the two nodes, unless the graph would fall apart.
///
/// This is the port of `dowhy.utils.graph_operations.del_edge`: the edge is put
/// back when the graph is not connected without it.
pub fn del_edge(graph : DirectedGraph, from : String, to : String) -> Unit {
  if !graph.has_edge(from, to) {
    return
  }
  graph.remove_edge(from, to)
  if !is_connected(graph) {
    graph.add_edge(from, to)
  }
}

///|
/// Add the edge between the two nodes, unless the graph would have a cycle.
///
/// This is the port of `dowhy.utils.graph_operations.add_edge`: the edge is
/// taken back when the graph is not acyclic with it.
pub fn add_edge(graph : DirectedGraph, from : String, to : String) -> Unit {
  graph.add_edge(from, to)
  if !graph.is_dag() {
    graph.remove_edge(from, to)
  }
}
