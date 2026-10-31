///|
/// Tests for the graph primitives the causal analysis is built on.
test "chain is separated by the mediator" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("A", "B")
  graph.add_edge("B", "C")
  assert_true(@graph.d_separated(graph, ["A"], ["C"], ["B"]))
  assert_false(@graph.d_separated(graph, ["A"], ["C"], []))
}

///|
test "collider opens when the collider is conditioned" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("A", "C")
  graph.add_edge("B", "C")
  // The collider blocks the path.
  assert_true(@graph.d_separated(graph, ["A"], ["B"], []))
  // Conditioning on the collider opens it.
  assert_false(@graph.d_separated(graph, ["A"], ["B"], ["C"]))
}

///|
test "fork is separated by the common cause" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("Z", "X")
  graph.add_edge("Z", "Y")
  assert_true(@graph.d_separated(graph, ["X"], ["Y"], ["Z"]))
  assert_false(@graph.d_separated(graph, ["X"], ["Y"], []))
}

///|
test "descendant of a collider opens the path" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("A", "C")
  graph.add_edge("B", "C")
  graph.add_edge("C", "D")
  assert_true(@graph.d_separated(graph, ["A"], ["B"], []))
  assert_false(@graph.d_separated(graph, ["A"], ["B"], ["D"]))
}

///|
test "ancestors and descendants" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X", "Y")
  graph.add_edge("Y", "Z")
  let ancestors = graph.ancestors("Z")
  assert_eq(ancestors.length(), 2)
  assert_true(ancestors.contains("X"))
  assert_true(ancestors.contains("Y"))
  let descendants = graph.descendants("X")
  assert_eq(descendants.length(), 2)
  assert_true(descendants.contains("Y"))
  assert_true(descendants.contains("Z"))
}

///|
test "simple paths are enumerated once" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X", "M")
  graph.add_edge("M", "Y")
  graph.add_edge("X", "Y")
  let paths = graph.all_simple_paths("X", "Y")
  assert_eq(paths.length(), 2)
}

///|
test "topological order respects the edges" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X", "Y")
  graph.add_edge("Y", "Z")
  let order = graph.topological_order()
  assert_eq(order.length(), 3)
  assert_true(graph.is_dag())
}

///|
test "cyclic graphs are not dags" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X", "Y")
  graph.add_edge("Y", "X")
  assert_false(graph.is_dag())
}

///|
test "do surgery removes the outgoing edges of the treatment" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X", "Y")
  graph.add_edge("Z", "X")
  graph.add_edge("Z", "Y")
  let surgery = @graph.do_surgery(graph, ["X"], true, false, [], false)
  assert_false(surgery.has_edge("X", "Y"))
  assert_true(surgery.has_edge("Z", "Y"))
  assert_true(surgery.has_edge("Z", "X"))
}

///|
test "backdoor paths start with an edge into the treatment" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("Z", "X")
  graph.add_edge("X", "Y")
  graph.add_edge("Z", "Y")
  let paths = @graph.get_backdoor_paths(graph, ["X"], ["Y"])
  assert_eq(paths.length(), 1)
  assert_eq(paths[0][0], "X")
  assert_eq(paths[0][1], "Z")
}

///|
test "instruments satisfy exclusion and as-if-random" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("Z", "X")
  graph.add_edge("X", "Y")
  let instruments = @graph.get_instruments(graph, ["X"], ["Y"])
  assert_eq(instruments.length(), 1)
  assert_eq(instruments[0], "Z")
}

///|
test "the ancestor and the descendant search leave the graph intact" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("Z", "X")
  graph.add_edge("Z", "Y")
  graph.add_edge("X", "Y")
  let _ = graph.ancestors("Y")
  let _ = graph.descendants("Z")
  // The searches must not consume the adjacency lists of the graph.
  assert_eq(graph.successors("Z").length(), 2)
  assert_eq(graph.predecessors("Y").length(), 2)
  assert_eq(graph.edge_count(), 3)
}

///|
test "the neighbour lists cannot be used to change the graph" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X", "Y")
  let children = graph.successors("X")
  children.push("Z")
  let parents = graph.predecessors("Y")
  parents.push("Z")
  assert_eq(graph.successors("X").length(), 1)
  assert_eq(graph.predecessors("Y").length(), 1)
  assert_false(graph.has_edge("X", "Z"))
}
