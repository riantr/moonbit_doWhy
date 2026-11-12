/// Tests for the identification algorithms.
///
/// The cases come from the upstream test suite
/// (`tests/causal_identifiers/test_backdoor_identifier.py`,
/// `test_frontdoor_identifier.py` and `test_complete_adjustment_identifier.py`)
/// and the expected sets are the ones DoWhy 0.14 produces, which the script
/// `_verify/gen_identifier_testdata.py` reads from the upstream source.
/// The two graphs of the notebook of the upstream are two of the four graphs of the cases of the complete adjustment of this file.  The notebook `dowhy_generalized_covariate_adjustment_example.ipynb`.

///|
/// Build the graph of a test case.
fn build_case_graph(
  nodes : Array[String],
  edges : Array[String],
) -> @graph.DirectedGraph {
  let built = @graph.DirectedGraph::new()
  for node in nodes {
    built.add_node(node)
  }
  for edge in edges {
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
/// The graph of a backdoor test case.
fn backdoor_graph(
  case : @identifiers.IdentifierTestCase,
) -> @graph.DirectedGraph {
  build_case_graph(case.nodes, case.edges)
}

///|
/// The graph of a frontdoor test case.
fn frontdoor_graph(
  case : @identifiers.FrontdoorTestCase,
) -> @graph.DirectedGraph {
  build_case_graph(case.nodes, case.edges)
}

///|
/// The graph of a complete adjustment test case.
fn complete_graph(case : @identifiers.CompleteTestCase) -> @graph.DirectedGraph {
  build_case_graph(case.nodes, case.edges)
}

///|
/// Whether two variable sets are the same, regardless of their order.
fn same_set(left : Array[String], right : Array[String]) -> Bool {
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
/// The adjustment variables of the given sets.
fn variables_of(
  sets : Array[@identifiers.AdjustmentSet],
) -> Array[Array[String]] {
  let out : Array[Array[String]] = []
  for set in sets {
    out.push(set.adjustment_variables())
  }
  out
}

///|
test "the exhaustive backdoor search never returns a biased set" {
  for case in @identifiers.backdoor_cases() {
    let graph = backdoor_graph(case)
    let (sets, message) = @identifiers.identify_backdoor(
      graph,
      case.action_nodes,
      case.outcome_nodes,
      case.observed_nodes,
      @identifiers.BACKDOOR_EXHAUSTIVE,
    )
    assert_eq(message, "")
    let found = variables_of(sets)
    for biased in case.biased_sets {
      for set in found {
        assert_false(same_set(set, biased))
      }
    }
  }
}

///|
test "the backdoor search only uses observed variables" {
  for case in @identifiers.backdoor_cases() {
    let graph = backdoor_graph(case)
    let (sets, _) = @identifiers.identify_backdoor(
      graph,
      case.action_nodes,
      case.outcome_nodes,
      case.observed_nodes,
      @identifiers.BACKDOOR_EXHAUSTIVE,
    )
    for set in sets {
      for name in set.adjustment_variables {
        assert_true(case.observed_nodes.contains(name))
      }
    }
  }
}

///|
test "the minimal backdoor search returns the minimal sets" {
  for case in @identifiers.backdoor_cases() {
    let graph = backdoor_graph(case)
    let (sets, _) = @identifiers.identify_backdoor(
      graph,
      case.action_nodes,
      case.outcome_nodes,
      case.observed_nodes,
      @identifiers.BACKDOOR_MIN,
    )
    let found = variables_of(sets)
    for expected in case.minimal_sets {
      let mut present = false
      for set in found {
        if same_set(set, expected) {
          present = true
        }
      }
      assert_true(present)
    }
  }
}

///|
test "the maximal backdoor search returns the maximal sets" {
  for case in @identifiers.backdoor_cases() {
    let graph = backdoor_graph(case)
    let (sets, _) = @identifiers.identify_backdoor(
      graph,
      case.action_nodes,
      case.outcome_nodes,
      case.observed_nodes,
      @identifiers.BACKDOOR_MAX,
    )
    let found = variables_of(sets)
    for expected in case.maximal_sets {
      let mut present = false
      for set in found {
        if same_set(set, expected) {
          present = true
        }
      }
      assert_true(present)
    }
  }
}

///|
test "the maximal backdoor search returns the direct effect sets" {
  for case in @identifiers.backdoor_cases() {
    let graph = backdoor_graph(case)
    let (sets, _) = @identifiers.identify_backdoor(
      graph,
      case.action_nodes,
      case.outcome_nodes,
      case.observed_nodes,
      @identifiers.BACKDOOR_MAX,
      direct_effect=true,
    )
    let found = variables_of(sets)
    for expected in case.direct_maximal_sets {
      let mut present = false
      for set in found {
        if same_set(set, expected) {
          present = true
        }
      }
      assert_true(present)
    }
  }
}

///|
test "the frontdoor search finds a valid frontdoor set" {
  for case in @identifiers.frontdoor_cases() {
    let graph = frontdoor_graph(case)
    let found = @identifiers.identify_frontdoor(
      graph,
      case.action_nodes,
      case.outcome_nodes,
      case.observed_nodes,
    )
    if case.valid_sets.length() == 0 {
      assert_eq(found.length(), 0)
    } else {
      assert_true(found.length() > 0)
      let mut valid = false
      for expected in case.valid_sets {
        if same_set(found, expected) {
          valid = true
        }
      }
      assert_true(valid)
    }
  }
}

///|
test "the frontdoor search never returns an invalid frontdoor set" {
  for case in @identifiers.frontdoor_cases() {
    let graph = frontdoor_graph(case)
    let found = @identifiers.identify_frontdoor(
      graph,
      case.action_nodes,
      case.outcome_nodes,
      case.observed_nodes,
    )
    for invalid in case.invalid_sets {
      assert_false(same_set(found, invalid))
    }
  }
}

///|
test "the complete adjustment search returns the minimal sets" {
  for case in @identifiers.complete_cases() {
    let graph = complete_graph(case)
    let sets = @identifiers.identify_generalized_adjustment_set(
      graph,
      case.action_nodes,
      case.outcome_nodes,
      case.observed_nodes,
    )
    let found = variables_of(sets)
    // The upstream assertion runs the other way round than the backdoor one:
    // every set the search returns has to be one of the expected sets.
    for set in found {
      let mut known = false
      for expected in case.minimal_sets {
        if same_set(set, expected) {
          known = true
        }
      }
      assert_true(known)
    }
  }
}

///|
test "the efficient backdoor strategy returns the boundary of the outcome" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X", "Y")
  graph.add_edge("Z", "X")
  graph.add_edge("Z", "Y")
  let (sets, message) = @identifiers.identify_backdoor(
    graph,
    ["X"],
    ["Y"],
    ["X", "Y", "Z"],
    @identifiers.BACKDOOR_EFFICIENT,
  )
  assert_eq(message, "")
  assert_eq(sets.length(), 1)
  assert_true(sets[0].adjustment_variables.contains("Z"))
  assert_eq(sets[0].adjustment_variables.length(), 1)
}

///|
test "an unknown backdoor strategy reports that it is not supported" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X", "Y")
  let (sets, message) = @identifiers.identify_backdoor(
    graph,
    ["X"],
    ["Y"],
    ["X", "Y"],
    "no-such-strategy",
  )
  assert_eq(sets.length(), 0)
  assert_true(message != "")
}

///|
test "the estimand registry names the adjustment sets" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X", "Y")
  graph.add_edge("Z", "X")
  graph.add_edge("Z", "Y")
  let estimand = @identifiers.identify_effect_auto(
    graph,
    ["X"],
    ["Y"],
    ["X", "Y", "Z"],
    "nonparametric-ate",
    @identifiers.BACKDOOR_DEFAULT,
  )
  assert_eq(estimand.identifier_method(), "backdoor")
  assert_true(estimand.has_estimand("backdoor"))
  assert_true(estimand.default_backdoor_id() != "")
  assert_eq(estimand.get_adjustment_set(estimand.default_backdoor_id()), ["Z"])
}

///|
test "a graph without a directed path has no effect" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("Z", "X")
  graph.add_edge("Z", "Y")
  let estimand = @identifiers.identify_effect_auto(
    graph,
    ["X"],
    ["Y"],
    ["X", "Y", "Z"],
    "nonparametric-ate",
    @identifiers.BACKDOOR_DEFAULT,
  )
  assert_true(estimand.has_no_directed_path())
}
