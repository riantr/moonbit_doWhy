///|
/// The tests of the efficient backdoor search of the `identifiers` package.
///
/// This is the port of the test file
/// `tests/causal_identifiers/test_efficient_backdoor_identifier.py` of the
/// upstream. The upstream test file runs the three efficient strategies on
/// every example graph and compares the adjustment sets with the ones of the
/// upstream; the tests of the port do the same, with the example graphs of
/// `src/identifiers/test_efficient_graphs.mbt`, which the script
/// `_verify/gen_efficient_backdoor_testdata.py` reads from the upstream source.

///|
/// The graph of an efficient backdoor test case.
fn efficient_case_graph(
  case : @identifiers.EfficientTestCase,
) -> @graph.DirectedGraph {
  let built = @graph.DirectedGraph::new()
  for node in case.nodes {
    built.add_node(node)
  }
  for edge in case.edges {
    let parts = edge.split("->")
    match parts.next() {
      Some(source) =>
        match parts.next() {
          Some(target) => built.add_edge(source.to_owned(), target.to_owned())
          None => ()
        }
      None => ()
    }
  }
  built
}

///|
/// Whether two variable sets are the same, regardless of their order.
fn efficient_same_set(left : Array[String], right : Array[String]) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for name in left {
    if !right.contains(name) {
      return false
    }
  }
  true
}

///|
/// The adjustment set of the given strategy, and the message of the search.
fn efficient_adjustment_of(
  case : @identifiers.EfficientTestCase,
  strategy : String,
) -> (Array[String], String) {
  let graph = efficient_case_graph(case)
  if strategy == "efficient" {
    @identifiers.efficient_backdoor_adjustment(
      graph,
      ["X"],
      ["Y"],
      case.observed_nodes,
      case.conditional_nodes,
      case.costs,
    )
  } else if strategy == "efficient-minimal" {
    @identifiers.efficient_backdoor_minimal_adjustment(
      graph,
      ["X"],
      ["Y"],
      case.observed_nodes,
      case.conditional_nodes,
      case.costs,
    )
  } else {
    @identifiers.efficient_backdoor_mincost_adjustment(
      graph,
      ["X"],
      ["Y"],
      case.observed_nodes,
      case.conditional_nodes,
      case.costs,
    )
  }
}

///|
/// The expected adjustment set of the given strategy.
fn efficient_expected_of(
  case : @identifiers.EfficientTestCase,
  strategy : String,
) -> Array[String]? {
  if strategy == "efficient" {
    case.efficient
  } else if strategy == "efficient-minimal" {
    case.efficient_minimal
  } else {
    case.efficient_mincost
  }
}

///|
/// The check of one strategy on one example graph.
///
/// The upstream raises an error when the adjustment set does not exist, and the
/// port reports a message instead, so the test asserts that the message is
/// empty when the upstream finds a set and that it is not empty when the
/// upstream fails.
fn assert_efficient_strategy(
  case : @identifiers.EfficientTestCase,
  strategy : String,
) -> Unit raise {
  let (values, message) = efficient_adjustment_of(case, strategy)
  match efficient_expected_of(case, strategy) {
    Some(expected) => {
      assert_true(message == "")
      assert_true(efficient_same_set(values, expected))
    }
    None => {
      assert_true(message != "")
      assert_true(values.length() == 0)
    }
  }
}

///|
/// The example graph of the upstream that the failure tests use.
fn efficient_sr22_fig2() -> @identifiers.EfficientTestCase {
  @identifiers.efficient_cases()[4]
}

///|
test "given the example graphs when identifying the efficient backdoor sets then report the adjustment sets of the upstream" {
  for case in @identifiers.efficient_cases() {
    assert_efficient_strategy(case, "efficient")
    assert_efficient_strategy(case, "efficient-minimal")
    assert_efficient_strategy(case, "efficient-mincost")
  }
}

///|
test "given a treatment with more than one dimension when identifying the efficient backdoor sets then report that the search is not valid" {
  let case = efficient_sr22_fig2()
  let graph = efficient_case_graph(case)
  let (values, message) = @identifiers.efficient_backdoor_mincost_adjustment(
    graph,
    ["X", "K"],
    ["Y"],
    case.observed_nodes,
    case.conditional_nodes,
    case.costs,
  )
  assert_true(values.length() == 0)
  assert_true(message == @identifiers.EFFICIENT_BACKDOOR_MULTIVARIATE_TREATMENT)
}

///|
test "given an outcome with more than one dimension when identifying the efficient backdoor sets then report that the search is not valid" {
  let case = efficient_sr22_fig2()
  let graph = efficient_case_graph(case)
  let (values, message) = @identifiers.efficient_backdoor_mincost_adjustment(
    graph,
    ["U"],
    ["Y", "F"],
    case.observed_nodes,
    case.conditional_nodes,
    case.costs,
  )
  assert_true(values.length() == 0)
  assert_true(message == @identifiers.EFFICIENT_BACKDOOR_MULTIVARIATE_OUTCOME)
}

///|
test "given a cost of zero when identifying the efficient backdoor sets then report that the costs have to be positive" {
  let case = efficient_sr22_fig2()
  let graph = efficient_case_graph(case)
  // The upstream sets the cost of the first variable of the list to zero.
  let costs : Array[(String, Double)] = [("L", 0.0)]
  for entry in case.costs {
    let (node, cost) = entry
    if node != "L" {
      costs.push((node, cost))
    }
  }
  let (values, message) = @identifiers.efficient_backdoor_mincost_adjustment(
    graph,
    ["X"],
    ["Y"],
    case.observed_nodes,
    case.conditional_nodes,
    costs,
  )
  assert_true(values.length() == 0)
  assert_true(message == @identifiers.EFFICIENT_BACKDOOR_NEGATIVE_COST)
}

///|
test "given a conditional variable that is not observed when identifying the efficient backdoor sets then report that the conditional variables have to be observed" {
  let case = efficient_sr22_fig2()
  let graph = efficient_case_graph(case)
  let (values, message) = @identifiers.efficient_backdoor_mincost_adjustment(
    graph,
    ["X"],
    ["Y"],
    case.observed_nodes,
    case.conditional_nodes + ["U"],
    case.costs,
  )
  assert_true(values.length() == 0)
  assert_true(message == @identifiers.EFFICIENT_BACKDOOR_UNOBSERVED_CONDITIONAL)
}

///|
test "given a graph in which the treatment is a neighbour of the outcome when identifying the efficient backdoor sets then report that no adjustment set exists" {
  // The unobserved variable W connects the treatment and the outcome, so the
  // two of them are neighbours of the H1 graph and no adjustment set of the
  // observable variables can block the path between them.
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("W", "X")
  graph.add_edge("W", "Y")
  graph.add_edge("X", "Y")
  let (values, message) = @identifiers.efficient_backdoor_adjustment(
    graph,
    ["X"],
    ["Y"],
    ["X", "Y"],
    [],
    [],
  )
  assert_true(values.length() == 0)
  assert_true(message == @identifiers.EFFICIENT_BACKDOOR_NO_ADJUSTMENT_SET)
}
