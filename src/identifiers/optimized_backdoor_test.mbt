///|
/// The tests of the optimized backdoor search of the `identifiers` package.
///
/// This is the port of the test file
/// `tests/causal_identifiers/test_optimize_backdoor.py` of the upstream. The
/// upstream test file checks that the set the optimized search finds blocks
/// every backdoor path; the tests of the port check that as well, and they
/// compare the set with the set of the upstream, which the script
/// `_verify/optimized_backdoor_reference.py` computes with the upstream code.

///|
/// The graph of the edges of the upstream test file.
fn optimized_graph(edges : Array[String]) -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  for edge in edges {
    let parts = edge.split("->")
    match parts.next() {
      Some(source) =>
        match parts.next() {
          Some(target) => graph.add_edge(source.to_owned(), target.to_owned())
          None => ()
        }
      None => ()
    }
  }
  graph
}

///|
/// The check of one example graph of the upstream test file.
///
/// The expected set is the set the upstream finds, and the check that the set
/// blocks every backdoor path is the check the upstream test file makes.
fn assert_optimized_backdoor(
  edges : Array[String],
  expected : Array[String],
) -> Unit raise {
  let graph = optimized_graph(edges)
  let sets = @identifiers.optimized_backdoor_adjustment(graph, ["T"], ["Y"])
  assert_eq(sets.length(), 1)
  let variables = sets[0].adjustment_variables()
  assert_eq(variables.length(), expected.length())
  for name in expected {
    assert_true(variables.contains(name))
  }
  // The set has to block every backdoor path of the treatment and the
  // outcome.
  let bdoor_graph = @graph.do_surgery(graph, ["T"], true, false, ["Y"], false)
  assert_true(@graph.d_separated(bdoor_graph, ["T"], ["Y"], variables))
}

///|
test "given the optimized flag when identifying the backdoor sets then use the optimized search" {
  let graph = optimized_graph(["X1->T", "X2->T", "X1->X2", "X2->Y", "T->Y"])
  let (sets, message) = @identifiers.identify_backdoor(
    graph,
    ["T"],
    ["Y"],
    ["T", "Y", "X1", "X2"],
    @identifiers.BACKDOOR_DEFAULT,
    optimize_backdoor=true,
  )
  assert_eq(message, "")
  assert_eq(sets.length(), 1)
  assert_eq(sets[0].adjustment_variables(), ["X2"])
}

///|
test "given a graph with two confounds when optimizing the backdoor search then find the variable that blocks every backdoor path" {
  assert_optimized_backdoor(["X1->T", "X2->T", "X1->X2", "X2->Y", "T->Y"], [
    "X2",
  ])
}

///|
test "given a graph without a backdoor path when optimizing the backdoor search then find no adjustment set" {
  let graph = optimized_graph(["T->X1", "T->X2", "X1->X2", "X2->Y", "T->Y"])
  let sets = @identifiers.optimized_backdoor_adjustment(graph, ["T"], ["Y"])
  assert_eq(sets.length(), 0)
}

///|
test "given a graph with a collider when optimizing the backdoor search then find the variable that blocks every backdoor path" {
  assert_optimized_backdoor(
    ["X1->T", "X1->X2", "Y->X2", "X3->T", "X3->Y", "T->Y"],
    ["X3"],
  )
}

///|
test "given a graph with a confounder of the outcome when optimizing the backdoor search then find the variable that blocks every backdoor path" {
  assert_optimized_backdoor(["T->Y", "X1->T", "X1->Y", "X2->T"], ["X1"])
}

///|
test "given a graph with two chains when optimizing the backdoor search then find the variables that block every backdoor path" {
  assert_optimized_backdoor(
    ["X1->T", "X1->X2", "X2->Y", "X3->T", "X3->X4", "X4->Y", "T->Y"],
    ["X1", "X3"],
  )
}

///|
test "given a graph with a chain and a collider when optimizing the backdoor search then find the variable that blocks every backdoor path" {
  assert_optimized_backdoor(
    ["X1->T", "X1->X2", "Y->X2", "X3->T", "X3->X4", "X4->Y", "T->Y"],
    ["X3"],
  )
}
