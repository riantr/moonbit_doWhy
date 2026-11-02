/// The tests of the graph readers of the port.
///
/// The readers are the port of the GML and DOT branches of
/// `dowhy.causal_graph.CausalGraph` and of
/// `dowhy.utils.graph_operations.daggity_to_dot`. The graphs of the upstream
/// tests are the fixtures here, and the expectations are the nodes and the
/// edges that `networkx.parse_gml` and `pygraphviz` read out of them.

///|
/// The GML graph of the upstream test `test_graph_input`.
///
/// The `{0}` of the upstream is the treatment and the `{1}` is the outcome.
fn gml_graph_of_the_upstream() -> String {
  "graph[directed 1 node[ id \"v0\" label \"v0\"]node[ id \"y\" label \"y\"]" +
  "node[ id \"Unobserved Confounders\" label \"Unobserved Confounders\"]" +
  "edge[source \"v0\" target \"y\"]" +
  "edge[source \"Unobserved Confounders\" target \"v0\"]" +
  "edge[source \"Unobserved Confounders\" target \"y\"]" +
  "node[ id \"X0\" label \"X0\"] edge[ source \"X0\" target \"v0\"]" +
  " node[ id \"X1\" label \"X1\"] edge[ source \"X1\" target \"v0\"]" +
  " node[ id \"X2\" label \"X2\"] edge[ source \"X2\" target \"v0\"]" +
  " edge[ source \"X0\" target \"y\"] edge[ source \"X1\" target \"y\"]" +
  " edge[ source \"X2\" target \"y\"] node[ id \"Z0\" label \"Z0\"]" +
  " edge[ source \"Z0\" target \"v0\"]]"
}

///|
/// The daggity graph of the upstream test `test_graph_input3`.
fn daggity_graph_of_the_upstream() -> String {
  "dag {\n" +
  "    \"Unobserved Confounders\" [pos=\"0.491,-1.056\"]\n" +
  "    X0 [pos=\"-2.109,0.057\"]\n" +
  "    X1 [adjusted, pos=\"-0.453,-1.562\"]\n" +
  "    X2 [pos=\"-2.268,-1.210\"]\n" +
  "    Z0 [pos=\"-1.918,-1.735\"]\n" +
  "    v0 [latent, pos=\"-1.525,-1.293\"]\n" +
  "    y [outcome, pos=\"-1.164,-0.116\"]\n" +
  "    \"Unobserved Confounders\" -> v0\n" +
  "    \"Unobserved Confounders\" -> y\n" +
  "    X0 -> v0\n" +
  "    X0 -> y\n" +
  "    X1 -> v0\n" +
  "    X1 -> y\n" +
  "    X2 -> v0\n" +
  "    X2 -> y\n" +
  "    Z0 -> v0\n" +
  "    v0 -> y\n" +
  "    }\n    "
}

///|
/// The GML graph of the upstream test `test_graph_refutation2`, whose nodes
/// are numbered and whose labels are the letters.
fn gml_graph_of_the_letters() -> String {
  let mut text = "graph [\ndirected 1\n"
  for i in 0..<10 {
    let letter = letter_at(i)
    text = text + "node [ id " + i.to_string() + " label \"" + letter + "\" ]\n"
  }
  let edges = [
    ("0", "1"),
    ("0", "3"),
    ("3", "2"),
    ("7", "4"),
    ("6", "5"),
    ("7", "8"),
    ("9", "2"),
    ("9", "8"),
  ]
  for (source, target) in edges {
    text = text + "edge [ source " + source + " target " + target + " ]\n"
  }
  text + "]"
}

///|
/// The letter of the given index.
fn letter_at(index : Int32) -> String {
  let letters = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"]
  letters[index]
}

///|
/// The edges of the graph, as a sorted list of pairs.
fn sorted_edges(graph : @graph.DirectedGraph) -> Array[String] {
  let out : Array[String] = []
  for (from, to) in graph.edge_list() {
    out.push(from + "->" + to)
  }
  out.sort_by(fn(a, b) { compare_edges(a, b) })
  out
}

///|
/// The comparison of two edges.
fn compare_edges(a : String, b : String) -> Int32 {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
test "the reader of the GML graphs reads the nodes and the edges" {
  let graph = @graph.parse_gml(gml_graph_of_the_upstream())
  let nodes = graph.node_list()
  assert_eq(nodes.length(), 7)
  assert_true(nodes.contains("v0"))
  assert_true(nodes.contains("y"))
  assert_true(nodes.contains("Unobserved Confounders"))
  assert_true(nodes.contains("X0"))
  assert_true(nodes.contains("X1"))
  assert_true(nodes.contains("X2"))
  assert_true(nodes.contains("Z0"))
  let edges = sorted_edges(graph)
  assert_eq(edges.length(), 10)
  assert_true(edges.contains("v0->y"))
  assert_true(edges.contains("Unobserved Confounders->v0"))
  assert_true(edges.contains("Unobserved Confounders->y"))
  assert_true(edges.contains("X0->v0"))
  assert_true(edges.contains("X0->y"))
  assert_true(edges.contains("X1->v0"))
  assert_true(edges.contains("X1->y"))
  assert_true(edges.contains("X2->v0"))
  assert_true(edges.contains("X2->y"))
  assert_true(edges.contains("Z0->v0"))
}

///|
test "the reader of the GML graphs names a node after its label" {
  let graph = @graph.parse_gml(gml_graph_of_the_letters())
  let nodes = graph.node_list()
  assert_eq(nodes.length(), 10)
  assert_true(nodes.contains("a"))
  assert_true(nodes.contains("j"))
  assert_false(nodes.contains("0"))
  let edges = sorted_edges(graph)
  assert_eq(edges.length(), 8)
  assert_true(edges.contains("a->b"))
  assert_true(edges.contains("a->d"))
  assert_true(edges.contains("d->c"))
  assert_true(edges.contains("h->e"))
  assert_true(edges.contains("g->f"))
  assert_true(edges.contains("h->i"))
  assert_true(edges.contains("j->c"))
  assert_true(edges.contains("j->i"))
}

///|
test "the reader of the GML graphs reads a graph of many lines" {
  let graph = @graph.parse_gml(
    "graph[\n        directed 1 \n        node[ id \"v0\" \n        label \"v0\"\n        ]\n" +
    "        node [ \n        id \"y\" \n        label \"y\"\n        ]\n" +
    "        edge[ source \"v0\" target \"y\"]\n]",
  )
  let nodes = graph.node_list()
  assert_eq(nodes.length(), 2)
  assert_true(nodes.contains("v0"))
  assert_true(nodes.contains("y"))
  assert_true(graph.has_edge("v0", "y"))
}

///|
test "the reader of the DOT graphs reads the nodes and the edges" {
  let graph = @graph.parse_dot("digraph {v0->y; W0->v0; W0->y;}")
  let nodes = graph.node_list()
  assert_eq(nodes.length(), 3)
  assert_true(nodes.contains("v0"))
  assert_true(nodes.contains("y"))
  assert_true(nodes.contains("W0"))
  let edges = sorted_edges(graph)
  assert_eq(edges.length(), 3)
  assert_true(edges.contains("v0->y"))
  assert_true(edges.contains("W0->v0"))
  assert_true(edges.contains("W0->y"))
}

///|
test "the reader of the DOT graphs reads the edges of quoted names" {
  let graph = @graph.parse_dot(
    "digraph {\"Unobserved Confounders\" -> v0; \"Unobserved Confounders\" -> y;}",
  )
  let edges = sorted_edges(graph)
  assert_eq(edges.length(), 2)
  assert_true(edges.contains("Unobserved Confounders->v0"))
  assert_true(edges.contains("Unobserved Confounders->y"))
}

///|
test "the graph of the daggity web site is turned into a DOT graph" {
  let dot = @graph.daggity_to_dot(daggity_graph_of_the_upstream())
  assert_true(dot.has_prefix("digraph "))
  assert_false(dot.contains("outcome"))
  assert_false(dot.contains("adjusted"))
  assert_true(dot.contains("observed=\"no\""))
  let graph = @graph.parse_dot(dot)
  let nodes = graph.node_list()
  assert_eq(nodes.length(), 7)
  assert_true(nodes.contains("Unobserved Confounders"))
  assert_true(nodes.contains("v0"))
  assert_true(nodes.contains("y"))
  let edges = sorted_edges(graph)
  assert_eq(edges.length(), 10)
  assert_true(edges.contains("v0->y"))
  assert_true(edges.contains("Unobserved Confounders->v0"))
  assert_true(edges.contains("X0->v0"))
  assert_true(edges.contains("Z0->v0"))
}
