///|
/// The cases of the graph operations of the upstream.
///
/// The upstream has no test file for `dowhy.utils.graph_operations`, so the
/// cases of the port are its own. Every one of them asserts a number that the
/// reference script `_verify/graph_operations_reference.py` prints for the
/// upstream.

///|
/// The weighted fixture of the port: the graph `a -> b -> c`, `a -> c` and
/// `d -> c`, whose edges hold the weights.
fn weighted_fixture() -> @utils.Matrix {
  @utils.Matrix::from_rows([
    [0.0, 0.5, 0.25, 0.0],
    [0.0, 0.0, 0.0, 0.0],
    [0.0, 0.0, 0.0, 0.0],
    [0.0, 0.0, 0.75, 0.0],
  ])
}

///|
/// The binary fixture of the port: the same graph without the weights.
fn binary_fixture() -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("a", "b")
  graph.add_edge("a", "c")
  graph.add_edge("d", "c")
  graph
}

///|
test "the adjacency list of a matrix holds the children of every node" {
  let list = @graph.adjacency_matrix_to_adjacency_list(weighted_fixture(), None)
  let first : Array[String] = list.get("1").unwrap_or([])
  assert_eq(first.length(), 2)
  assert_eq(first[0], "2")
  assert_eq(first[1], "3")
  let fourth : Array[String] = list.get("4").unwrap_or([])
  assert_eq(fourth.length(), 1)
  assert_eq(fourth[0], "3")
}

///|
test "the adjacency list of a matrix holds the labels of the caller" {
  let list = @graph.adjacency_matrix_to_adjacency_list(
    weighted_fixture(),
    Some(["a", "b", "c", "d"]),
  )
  let first : Array[String] = list.get("a").unwrap_or([])
  assert_eq(first.length(), 2)
  assert_eq(first[0], "b")
  assert_eq(first[1], "c")
  let fourth : Array[String] = list.get("d").unwrap_or([])
  assert_eq(fourth.length(), 1)
  assert_eq(fourth[0], "c")
}

///|
test "the graph of a matrix holds the edges that are heavier than a hundredth" {
  let dot = @graph.adjacency_matrix_to_dot(weighted_fixture(), None)
  assert_eq(
    dot, "digraph {\n\tx0\n\tx1\n\tx2\n\tx3\n\tx1 -> x0 [label=0.5]\n\tx2 -> x0 [label=0.25]\n\tx2 -> x3 [label=0.75]\n}\n",
  )
}

///|
test "the compact graph of a graph holds its statements on one line" {
  let dot = @graph.adjacency_matrix_to_dot(weighted_fixture(), None)
  let compact = @graph.str_to_dot(dot)
  assert_eq(
    compact, "digraph {x0;x1;x2;x3;x1 -> x0 [label=0.5];x2 -> x0 [label=0.25];x2 -> x3 [label=0.75]}",
  )
}

///|
test "the ancestors of the nodes hold the nodes themselves" {
  let ancestors = @graph.find_ancestor(binary_fixture(), ["c"])
  assert_eq(ancestors.length(), 3)
  assert_true(ancestors.contains("a"))
  assert_true(ancestors.contains("c"))
  assert_true(ancestors.contains("d"))
}

///|
test "the induced graph holds the edges of the nodes it keeps" {
  let induced = @graph.induced_graph(binary_fixture(), ["a", "b", "c"])
  assert_eq(induced.node_count(), 3)
  assert_true(induced.has_edge("a", "b"))
  assert_true(induced.has_edge("a", "c"))
  assert_false(induced.has_edge("d", "c"))
}

///|
test "the C-components are the components of the edges that point in both directions" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("a", "b")
  graph.add_edge("b", "a")
  graph.add_edge("a", "c")
  graph.add_edge("c", "d")
  graph.add_edge("d", "c")
  let components = @graph.find_c_components(graph, ["a", "b", "c", "d"])
  assert_eq(components.length(), 2)
  assert_eq(components[0].length(), 2)
  assert_true(components[0].contains("a"))
  assert_true(components[0].contains("b"))
  assert_true(components[1].contains("c"))
  assert_true(components[1].contains("d"))
}

///|
test "the simple ordered tree is a chain" {
  let tree = @graph.get_simple_ordered_tree(4)
  assert_eq(tree.node_count(), 4)
  assert_eq(tree.edge_count(), 3)
  assert_true(tree.has_edge("0", "1"))
  assert_true(tree.has_edge("2", "3"))
  assert_false(tree.has_edge("3", "0"))
}

///|
test "the connectivity of a graph ignores the direction of its edges" {
  let connected = @graph.DirectedGraph::new()
  connected.add_edge("a", "b")
  connected.add_edge("b", "c")
  assert_true(@graph.is_connected(connected))
  let split = @graph.DirectedGraph::new()
  split.add_edge("a", "b")
  split.add_node("c")
  assert_false(@graph.is_connected(split))
}

///|
test "the undirected graph of a graph holds every edge in both directions" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("a", "b")
  graph.add_edge("b", "c")
  let undirected = @graph.convert_to_undirected_graph(graph)
  assert_eq(undirected.node_count(), 3)
  assert_true(undirected.has_edge("a", "b"))
  assert_true(undirected.has_edge("b", "a"))
}

///|
test "the predecessor of a node is a parent of it that reaches the other node" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("a", "b")
  graph.add_edge("b", "c")
  assert_eq(@graph.find_predecessor(graph, "a", "c"), Some("b"))
  assert_eq(@graph.find_predecessor(graph, "c", "a"), None)
}

///|
test "the removal of an edge keeps the graph connected" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("a", "b")
  graph.add_edge("a", "c")
  graph.add_edge("b", "c")
  @graph.del_edge(graph, "b", "c")
  assert_false(graph.has_edge("b", "c"))
  // The edge that would break the graph is put back.
  @graph.del_edge(graph, "a", "b")
  assert_true(graph.has_edge("a", "b"))
}

///|
test "the addition of an edge keeps the graph acyclic" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("a", "b")
  graph.add_edge("a", "c")
  @graph.add_edge(graph, "c", "b")
  assert_true(graph.has_edge("c", "b"))
  // The edge that would make a cycle is taken back.
  @graph.add_edge(graph, "b", "c")
  assert_false(graph.has_edge("b", "c"))
}

///|
test "the random pair of nodes holds two different nodes" {
  let generator = @utils.NumpyRandom::new(42UL)
  let (i, j) = @graph.get_random_node_pair(5, generator)
  assert_eq(i, 3)
  assert_eq(j, 4)
}
