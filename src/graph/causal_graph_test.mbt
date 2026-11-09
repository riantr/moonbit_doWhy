///|
/// The tests of the graph operations, the port of the upstream test file
/// `tests/test_causal_graph.py`.
///
/// The upstream test file builds the graph of the daggity web site and compares
/// every operation of the graph object of DoWhy with the same operation of the
/// module level functions of `dowhy.graph`, which run on a `networkx` graph.
/// The port has no `networkx`, so it asserts the answers the upstream gives on
/// the very same graph, which `_verify/causal_graph_reference.py` prints.
///
/// The graph of the fixture is the one of the file `tests/sample_dag.txt` of the
/// upstream, and it is the literal of `daggity_fixture`.
///
/// The treatment of the fixture is `v0`, the outcome is `y`, the observed nodes
/// are the seven of the fixture and `Unobserved Confounders` is the eighth one.

///|
/// The treatment of the fixture.
const ACTION : String = "v0"

///|
/// The outcome of the fixture.
const OUTCOME : String = "y"

///|
/// The observed nodes of the fixture.
fn observed_nodes() -> Array[String] {
  ["W0", "X0", "X1", "X2", "Z0", "v0", "y"]
}

///|
/// The graph of the fixture, built the way the upstream builds it.
fn fixture_graph() -> @graph.DirectedGraph {
  @graph.parse_dot(@graph.daggity_to_dot(@graph.daggity_fixture()))
}

///|
/// The causal graph of the fixture.
///
/// The `Unobserved Confounders` node of the fixture is not observed, the way
/// the upstream marks it.
fn fixture_causal_graph() -> @graph.CausalGraph {
  @graph.CausalGraph::new(
    [ACTION],
    [OUTCOME],
    Some(fixture_graph()),
    [],
    [],
    [],
    [],
    observed_nodes(),
  )
}

///|
/// The edges of a graph, sorted.
fn fixture_edges(graph : @graph.DirectedGraph) -> Array[String] {
  let out : Array[String] = []
  for (from, to) in graph.edge_list() {
    out.push(from + "->" + to)
  }
  out.sort_by(fn(a, b) { compare_names(a, b) })
  out
}

///|
/// Compare two edge names by their characters.
fn compare_names(a : String, b : String) -> Int32 {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i = 0; i < n; i = i + 1 {
    let cx = a.get(i)
    let cy = b.get(i)
    if cx < cy {
      return -1
    }
    if cx > cy {
      return 1
    }
  }
  if a.length() < b.length() {
    -1
  } else if a.length() > b.length() {
    1
  } else {
    0
  }
}

///|
/// The nodes of a graph, sorted.
fn fixture_nodes(graph : @graph.DirectedGraph) -> Array[String] {
  let out = graph.node_list()
  out.sort_by(fn(a, b) { compare_names(a, b) })
  out
}

///|
test "the graph of the daggity fixture holds the nodes and the edges of the upstream" {
  let graph = fixture_graph()
  assert_eq(fixture_nodes(graph), [
    "Unobserved Confounders", "W0", "X0", "X1", "X2", "Z0", "v0", "y",
  ])
  assert_eq(fixture_edges(graph), [
    "Unobserved Confounders->v0", "Unobserved Confounders->y", "W0->v0", "W0->y",
    "X0->v0", "X0->y", "X1->v0", "X1->y", "X2->v0", "X2->y", "Z0->v0", "v0->y",
  ])
}

///|
test "the backdoor set of the daggity fixture is not valid" {
  let graph = fixture_causal_graph()
  // The upstream answers `{"is_dseparated": False}` for this set.
  assert_false(
    graph.check_valid_backdoor_set([ACTION], [OUTCOME], ["X1", "X2"], None),
  )
}

///|
test "the frontdoor set of the daggity fixture is not valid" {
  let graph = fixture_causal_graph()
  assert_false(
    graph.check_valid_frontdoor_set([ACTION], [OUTCOME], ["X0"], [], None),
  )
}

///|
test "the mediation set of the daggity fixture is not valid" {
  let graph = fixture_causal_graph()
  assert_false(graph.check_valid_mediation_set([ACTION], [OUTCOME], ["X0"], []))
}

///|
test "the nodes of the daggity fixture are not d-separated by the two features" {
  let graph = fixture_causal_graph()
  assert_false(graph.check_dseparation([ACTION], [OUTCOME], ["X1", "X2"], None))
}

///|
test "the do-surgery of the daggity fixture keeps the edges of the treatment" {
  let graph = fixture_causal_graph()
  // The upstream removes no edge by default, so the graph keeps all of them.
  let surgery = graph.do_surgery([ACTION], false, false, [], false)
  assert_eq(fixture_nodes(surgery), [
    "Unobserved Confounders", "W0", "X0", "X1", "X2", "Z0", "v0", "y",
  ])
  assert_eq(fixture_edges(surgery), [
    "Unobserved Confounders->v0", "Unobserved Confounders->y", "W0->v0", "W0->y",
    "X0->v0", "X0->y", "X1->v0", "X1->y", "X2->v0", "X2->y", "Z0->v0", "v0->y",
  ])
}

///|
test "the backdoor paths of the daggity fixture are the five of the upstream" {
  let graph = fixture_graph()
  let paths = @graph.get_backdoor_paths(graph, [ACTION], [OUTCOME])
  assert_eq(paths.length(), 5)
  let found : Array[String] = []
  for path in paths {
    found.push(path.join("->"))
  }
  found.sort_by(fn(a, b) { compare_names(a, b) })
  assert_eq(found, [
    "v0->Unobserved Confounders->y", "v0->W0->y", "v0->X0->y", "v0->X1->y", "v0->X2->y",
  ])
}

///|
test "the instrument of the daggity fixture is the one of the upstream" {
  let graph = fixture_causal_graph()
  assert_eq(graph.get_instruments([ACTION], [OUTCOME]), ["Z0"])
}

///|
test "the nodes of the daggity fixture are the observed ones and the others" {
  let graph = fixture_causal_graph()
  assert_eq(graph.get_all_nodes(true), [
    "Unobserved Confounders", "W0", "X0", "X1", "X2", "Z0", "v0", "y",
  ])
  assert_eq(graph.get_all_nodes(false), [
    "W0", "X0", "X1", "X2", "Z0", "v0", "y",
  ])
}

///|
test "the directed paths of the daggity fixture are the ones of the upstream" {
  let graph = fixture_graph()
  assert_true(@graph.has_directed_path(graph, ["X0"], ["y"]))
  assert_true(@graph.has_directed_path(graph, ["X0", "X1", "X2"], ["y", "v0"]))
  assert_false(@graph.has_directed_path(graph, [], ["y"]))
  assert_false(
    @graph.has_directed_path(graph, ["X0", "X1", "X2"], ["y", "v0", "Z0"]),
  )
}

///|
test "the graph of the semantic roles of the daggity fixture has the edges of the upstream" {
  let graph = @graph.build_graph([ACTION], [OUTCOME], ["W0"], ["Z0"], [], [])
  assert_eq(fixture_nodes(graph), ["W0", "Z0", "v0", "y"])
  assert_eq(fixture_edges(graph), ["W0->v0", "W0->y", "Z0->v0", "v0->y"])
}

///|
test "the naive algorithm of the upstream blocks the paths of the fixture" {
  let graph = fixture_causal_graph()
  // The naive algorithm of the backdoor set asks for every backdoor path to be
  // blocked, and the two features block none of them.
  assert_false(
    graph.check_valid_backdoor_set(
      [ACTION],
      [OUTCOME],
      ["X1", "X2"],
      None,
      algo=@graph.DseparationAlgorithm::naive(),
    ),
  )
  // The naive algorithm of the frontdoor set asks for every directed path from
  // the treatment to the outcome to be blocked.
  assert_false(
    graph.check_valid_frontdoor_set(
      [ACTION],
      [OUTCOME],
      ["X0"],
      [],
      None,
      algo=@graph.DseparationAlgorithm::naive(),
    ),
  )
}
