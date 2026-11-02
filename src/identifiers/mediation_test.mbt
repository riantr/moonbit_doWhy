/// Tests for the mediation identification.
///
/// The case is the one of the upstream test `test_dowhy_chapter_7` of the file
/// `tests/causal-inference-discovery-book/test_causal_inference_discovery_book.py`:
/// the treatment `X` has the mediator `Z` and the outcome `Y`, and the
/// unobserved variable `U` is a common cause of the treatment and of the
/// outcome.
///
/// The confounders of the two stages are the ones `_verify/two_stage_reference.py`
/// computes with the upstream.

///|
/// The graph of the upstream test.
fn mediation_graph() -> @graph.DirectedGraph {
  let built = @graph.DirectedGraph::new()
  for node in ["U", "X", "Z", "Y"] {
    built.add_node(node)
  }
  built.add_edge("U", "X")
  built.add_edge("U", "Y")
  built.add_edge("X", "Z")
  built.add_edge("Z", "Y")
  built
}

///|
/// Whether two variable sets are the same, regardless of their order.
fn mediation_same_set(left : Array[String], right : Array[String]) -> Bool {
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
/// The variables of the registry under the given key.
fn mediation_registry_variables(
  registry : Map[String, Array[String]],
  key : String,
) -> Array[String] {
  match registry.get(key) {
    Some(variables) => variables
    None => []
  }
}

///|
test "the mediation search finds the mediator of the upstream test" {
  let graph = mediation_graph()
  let mediators = @identifiers.identify_mediation(graph, ["X"], ["Y"])
  assert_true(mediation_same_set(mediators, ["Z"]))
}

///|
test "the mediation search finds no mediator when the graph has none" {
  let built = @graph.DirectedGraph::new()
  built.add_node("X")
  built.add_node("Y")
  built.add_edge("X", "Y")
  let mediators = @identifiers.identify_mediation(built, ["X"], ["Y"])
  assert_eq(mediators.length(), 0)
}

///|
test "the two stages of the mediation have the confounders of the upstream" {
  let graph = mediation_graph()
  let first = @identifiers.identify_mediation_first_stage_confounders(
    graph,
    ["X"],
    ["Y"],
    ["Z"],
    ["X", "Z", "Y"],
    @identifiers.BACKDOOR_DEFAULT,
  )
  // The first stage regresses the mediator on the treatment, and the treatment
  // and the mediator are not confounded in the graph of the upstream test.
  assert_true(
    mediation_same_set(mediation_registry_variables(first, "backdoor"), []),
  )
  assert_true(
    mediation_same_set(mediation_registry_variables(first, "backdoor1"), []),
  )
  let second = @identifiers.identify_mediation_second_stage_confounders(
    graph,
    ["X"],
    ["Z"],
    ["Y"],
    ["X", "Z", "Y"],
    @identifiers.BACKDOOR_DEFAULT,
  )
  // The second stage regresses the outcome on the mediator, and the treatment
  // is a common cause of the two.
  assert_true(
    mediation_same_set(mediation_registry_variables(second, "backdoor"), ["X"]),
  )
  assert_true(
    mediation_same_set(mediation_registry_variables(second, "backdoor1"), ["X"]),
  )
  assert_true(
    mediation_same_set(mediation_registry_variables(second, "backdoor2"), ["X"]),
  )
}

///|
test "the identification of the average effect carries the confounders of the frontdoor" {
  let graph = mediation_graph()
  let estimand = @identifiers.identify_effect_auto(
    graph,
    ["X"],
    ["Y"],
    ["X", "Z", "Y"],
    "nonparametric-ate",
    @identifiers.BACKDOOR_DEFAULT,
  )
  assert_true(mediation_same_set(estimand.get_frontdoor_variables(), ["Z"]))
  let first = estimand.get_mediation_first_stage_confounders()
  assert_true(
    mediation_same_set(mediation_registry_variables(first, "backdoor"), []),
  )
  let second = estimand.get_mediation_second_stage_confounders()
  assert_true(
    mediation_same_set(mediation_registry_variables(second, "backdoor"), ["X"]),
  )
}

///|
test "the identification of the natural indirect effect registers the mediation" {
  let graph = mediation_graph()
  let estimand = @identifiers.identify_effect_auto(
    graph,
    ["X"],
    ["Y"],
    ["X", "Z", "Y"],
    "nonparametric-nie",
    @identifiers.BACKDOOR_DEFAULT,
  )
  assert_true(estimand.has_estimand("mediation"))
  // The upstream resets the registry of the estimands before it looks for the
  // mediators, so the backdoor sets are not part of it.
  assert_false(estimand.has_estimand("backdoor"))
  assert_true(mediation_same_set(estimand.get_mediator_variables(), ["Z"]))
  assert_eq(estimand.estimand_assumptions("mediation").length(), 3)
  let second = estimand.get_mediation_second_stage_confounders()
  assert_true(
    mediation_same_set(mediation_registry_variables(second, "backdoor"), ["X"]),
  )
}
