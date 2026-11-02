/// The tests of the automatic identification.
///
/// The cases come from the upstream test file
/// `tests/causal_identifiers/test_auto_identifier.py`.  The upstream builds
/// the graph of the case from a string of the graph language of the upstream
/// and asks the automatic identification for the estimand of two action
/// nodes.  The graph of the port is built from its edges, which is the same
/// graph.
///
/// The upstream checks the flag `no_directed_path` of the estimand.  The flag
/// is set when the graph has no directed path from the action nodes to the
/// outcome, and the rule of the upstream is the one of
/// `dowhy.graph.has_directed_path`: every action node has to have a directed
/// path to one of the outcome nodes, and every outcome node has to have a
/// directed path from one of the action nodes.  The action node `B` of the
/// graph of the case has no path to the outcome, so the estimand has no
/// directed path.

///|
/// The graph of the case: `T` causes `Y`, `A` causes `Y` and `A` causes `B`.
fn auto_identifier_graph() -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("T", "Y")
  graph.add_edge("A", "Y")
  graph.add_edge("A", "B")
  graph
}

///|
/// The estimand of the automatic identification of the given action nodes.
fn auto_identifier_estimand(
  action_nodes : Array[String],
) -> @identifiers.IdentifiedEstimand {
  @identifiers.identify_effect_auto(
    auto_identifier_graph(),
    action_nodes,
    ["Y"],
    ["T", "Y", "A", "B"],
    "nonparametric-ate",
    @identifiers.BACKDOOR_DEFAULT,
  )
}

///|
test "the automatic identification has no directed path with two action nodes" {
  let estimand = auto_identifier_estimand(["T", "B"])
  assert_true(estimand.has_no_directed_path())
}

///|
test "the automatic identification has no directed path with two action nodes in the other order" {
  let estimand = auto_identifier_estimand(["B", "T"])
  assert_true(estimand.has_no_directed_path())
}
