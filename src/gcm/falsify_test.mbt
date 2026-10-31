///|
/// The tests of the falsification layer of the `gcm` package.
///
/// The upstream reference of the layer is `_verify/gcm_falsify_reference.py`,
/// which runs the upstream `dowhy.gcm.falsify` on the fixtures of the
/// falsification layer, which `_verify/gen_falsify_testdata.py` builds. The
/// upstream tests of `tests/gcm/test_falsify.py` use the generalised
/// covariance measure with a linear regressor for the continuous fixtures, and
/// the port uses its own `generalised_cov_based`, which is the same measure
/// with an ordinary least squares fit.
///
/// The upstream test of the categorical fixture is not ported: the data frame
/// of the port holds one numeric or one discrete column per name, and the
/// kernel based test of the port takes numeric matrices only.

///|
/// The significance level of the tests.
const FALSIFY_SIGNIFICANCE_LEVEL : Double = 0.05

///|
/// Whether two p-values are close to each other.
///
/// The comparison is relative, because the p-values of the tests span many
/// orders of magnitude: the p-value of a dependent pair of variables is of the
/// order of `1e-30` and the p-value of an independent one is of the order of
/// `1e-01`.
///
/// The tolerance of `1e-12` is the noise floor of the upstream: the upstream
/// fits the regression with the singular value decomposition of
/// `scipy.linalg.lstsq` and the port with the pseudo inverse of the ordinary
/// least squares fit, and the p-value of a test in the far tail of the normal
/// distribution amplifies the difference of the two fits.
fn falsify_near(a : Double, b : Double) -> Bool {
  let scale = b.abs()
  if scale < 1.0e-300 {
    return (a - b).abs() <= 1.0e-300
  }
  (a - b).abs() <= 1.0e-12 * scale
}

///|
/// Whether a p-value is close to the expected one.
///
/// The p-value of a test that was not run is never close to the expected one.
fn falsify_p_value_near(actual : Double?, expected : Double) -> Bool {
  match actual {
    Some(value) => falsify_near(value, expected)
    None => false
  }
}

///|
/// The independence test of the tests, which is the generalised covariance
/// measure of the package.
fn falsify_test(
  x : @utils.Matrix,
  y : @utils.Matrix,
  z : @utils.Matrix?,
) -> Double {
  @gcm.generalised_cov_based(x, y, z)
}

///|
/// The graph of the collider, whose edges are `X -> Z` and `Y -> Z`.
fn falsify_collider_graph() -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X", "Z")
  graph.add_edge("Y", "Z")
  graph
}

///|
/// The wrong graph of the collider, whose edges are `X -> Y` and `Z -> Y`.
fn falsify_wrong_collider_graph() -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X", "Y")
  graph.add_edge("Z", "Y")
  graph
}

///|
/// The graph of the chain, whose edges are `X -> Y` and `Y -> Z`.
fn falsify_chain_graph() -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X", "Y")
  graph.add_edge("Y", "Z")
  graph
}

///|
/// The wrong graph of the chain, whose edges are `X -> Z` and `Z -> Y`.
fn falsify_wrong_chain_graph() -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X", "Z")
  graph.add_edge("Z", "Y")
  graph
}

///|
/// The full graph of the upstream.
fn falsify_full_dag_graph() -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "X1")
  graph.add_edge("X0", "X2")
  graph.add_edge("X0", "X3")
  graph.add_edge("X1", "X2")
  graph.add_edge("X1", "X3")
  graph.add_edge("X2", "X3")
  graph
}

///|
/// The graph with a single node.
fn falsify_single_node_graph() -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  graph.add_node("X")
  graph
}

///|
/// The graph with a single edge, `X0 -> X1`.
fn falsify_single_edge_graph() -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "X1")
  graph
}

///|
/// The wrong graph with a single edge, which has the two nodes and no edge.
fn falsify_wrong_single_edge_graph() -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  graph.add_node("X0")
  graph.add_node("X1")
  graph
}

///|
/// The graph of the causal minimality, whose edges are `X0 -> Y` and
/// `X1 -> Y`.
fn falsify_minimality_graph() -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "Y")
  graph.add_edge("X1", "Y")
  graph
}

///|
/// The graph that is not causally minimal, whose edges are `X0 -> Y`,
/// `X1 -> Y` and `X2 -> Y`.
fn falsify_non_minimality_graph() -> @graph.DirectedGraph {
  let graph = falsify_minimality_graph()
  graph.add_edge("X2", "Y")
  graph
}

///|
/// The graph whose nodes are permuted by the tests of the permutations.
///
/// The graph is a directed path of four nodes, so that no permutation of its
/// nodes gives the same graph again.
fn falsify_permutation_graph() -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "X1")
  graph.add_edge("X1", "X2")
  graph.add_edge("X2", "X3")
  graph
}

///|
/// The edges of a graph, as a string, so that two graphs can be compared.
fn falsify_graph_key(graph : @graph.DirectedGraph) -> String {
  let mut out = ""
  for (from, to) in graph.edge_list() {
    out = out + from + "->" + to + ";"
  }
  out
}

///|
/// The summary of the local Markov condition.
fn falsify_lmc_summary(summary : @gcm.ValidationResults) -> @gcm.LmcSummary {
  match summary.local_markov_condition() {
    Some(value) => value
    None => abort("the local Markov condition was not validated")
  }
}

///|
/// The summary of the pairwise dependencies.
fn falsify_pairwise_summary(summary : @gcm.ValidationResults) -> @gcm.PdSummary {
  match summary.pairwise_dependencies() {
    Some(value) => value
    None => abort("the pairwise dependencies were not validated")
  }
}

///|
/// The summary of the parental d-separations.
fn falsify_tpa_summary(summary : @gcm.ValidationResults) -> @gcm.TpaSummary {
  match summary.parental_d_separations() {
    Some(value) => value
    None => abort("the parental d-separations were not validated")
  }
}

///|
/// The summary of the causal minimality.
fn falsify_cm_summary(summary : @gcm.ValidationResults) -> @gcm.CmSummary {
  match summary.causal_minimality() {
    Some(value) => value
    None => abort("the causal minimality was not validated")
  }
}

///|
/// The methods of the validations of the upstream tests.
fn falsify_validation_methods(
  causal_graph_reference : @graph.DirectedGraph,
) -> Array[@gcm.ValidationMethod] {
  [
    @gcm.ValidationMethod::local_markov_condition(
      falsify_test,
      falsify_test,
      FALSIFY_SIGNIFICANCE_LEVEL,
    ),
    @gcm.ValidationMethod::pairwise_dependencies(
      falsify_test,
      FALSIFY_SIGNIFICANCE_LEVEL,
    ),
    @gcm.ValidationMethod::parental_d_separations(causal_graph_reference),
  ]
}

///|
/// The methods of the validation of the causal minimality of the upstream
/// tests.
fn falsify_minimality_methods() -> Array[@gcm.ValidationMethod] {
  [
    @gcm.ValidationMethod::causal_minimality(
      falsify_test,
      falsify_test,
      FALSIFY_SIGNIFICANCE_LEVEL,
    ),
  ]
}

///|
/// test "the permutations of the nodes exclude the original order when they are
/// asked to"
///
/// The upstream test draws a random number of nodes and a random graph; the
/// port uses a graph of four nodes, so that the number of the permutations is
/// known.
test "the permutations of the nodes exclude the original order when they are asked to" {
  let graph = falsify_permutation_graph()
  let generator = @gcm.PermuteNodes::new(graph, true, -1)
  assert_eq(generator.length(), 23)
  let permutations = generator.permutations(@utils.Random::new(1UL))
  assert_eq(permutations.length(), 23)
  let original = graph.node_list()
  let distinct : Array[String] = []
  for permuted in permutations {
    assert_false(permuted.node_list() == original)
    let key = falsify_graph_key(permuted)
    if !distinct.contains(key) {
      distinct.push(key)
    }
  }
  assert_eq(distinct.length(), 23)
}

///|
/// test "the permutations of the nodes keep the original order when they are
/// not asked to exclude it"
test "the permutations of the nodes keep the original order when they are not asked to exclude it" {
  let graph = falsify_permutation_graph()
  let generator = @gcm.PermuteNodes::new(graph, false, -1)
  assert_eq(generator.length(), 24)
  let permutations = generator.permutations(@utils.Random::new(1UL))
  assert_eq(permutations.length(), 24)
  let original = graph.node_list()
  let mut found_original = false
  let distinct : Array[String] = []
  for permuted in permutations {
    if permuted.node_list() == original {
      found_original = true
    }
    let key = falsify_graph_key(permuted)
    if !distinct.contains(key) {
      distinct.push(key)
    }
  }
  assert_true(found_original)
  assert_eq(distinct.length(), 24)
}

///|
/// test "given correct collider when validating graph then report no violations"
test "given correct collider when validating graph then report no violations" {
  let graph = falsify_collider_graph()
  let summary = @gcm.run_validations(
    graph,
    @gcm.falsify_collider_frame(),
    falsify_validation_methods(graph),
  )
  let lmc = falsify_lmc_summary(summary)
  assert_eq(lmc.n_violations(), 0)
  assert_eq(lmc.n_tests(), 2)
  assert_true(
    falsify_p_value_near(lmc.p_value_of("X", "Y"), 0.3870828144269376),
  )
  assert_true(
    falsify_p_value_near(lmc.p_value_of("Y", "X"), 0.3870828144269376),
  )
  let pairwise = falsify_pairwise_summary(summary)
  assert_eq(pairwise.n_violations(), 0)
  assert_eq(pairwise.n_tests(), 2)
  assert_true(
    falsify_p_value_near(pairwise.p_value_of("Z", "X"), 1.648504987388527e-30),
  )
  assert_true(
    falsify_p_value_near(pairwise.p_value_of("Z", "Y"), 2.0208070223293335e-47),
  )
  let tpa = falsify_tpa_summary(summary)
  assert_eq(tpa.n_violations(), 0)
  assert_eq(tpa.n_tests(), 2)
}

///|
/// test "given wrong collider when validating graph then report violations"
test "given wrong collider when validating graph then report violations" {
  let graph = falsify_wrong_collider_graph()
  let summary = @gcm.run_validations(
    graph,
    @gcm.falsify_collider_frame(),
    falsify_validation_methods(falsify_collider_graph()),
  )
  let lmc = falsify_lmc_summary(summary)
  assert_eq(lmc.n_violations(), 2)
  assert_eq(lmc.n_tests(), 2)
  assert_true(
    falsify_p_value_near(lmc.p_value_of("X", "Z"), 1.648504987388527e-30),
  )
  assert_true(
    falsify_p_value_near(lmc.p_value_of("Z", "X"), 1.648504987388527e-30),
  )
  let pairwise = falsify_pairwise_summary(summary)
  assert_eq(pairwise.n_violations(), 1)
  assert_eq(pairwise.n_tests(), 2)
  assert_true(
    falsify_p_value_near(pairwise.p_value_of("Y", "X"), 0.3870828144269376),
  )
  assert_true(
    falsify_p_value_near(pairwise.p_value_of("Y", "Z"), 2.0208070223293335e-47),
  )
  let tpa = falsify_tpa_summary(summary)
  assert_eq(tpa.n_violations(), 2)
  assert_eq(tpa.n_tests(), 2)
}

///|
/// test "given correct chain when validating graph then report no violations"
test "given correct chain when validating graph then report no violations" {
  let graph = falsify_chain_graph()
  let summary = @gcm.run_validations(
    graph,
    @gcm.falsify_chain_frame(),
    falsify_validation_methods(graph),
  )
  let lmc = falsify_lmc_summary(summary)
  assert_eq(lmc.n_violations(), 0)
  assert_eq(lmc.n_tests(), 1)
  assert_true(
    falsify_p_value_near(lmc.p_value_of("Z", "X"), 0.6227107213956038),
  )
  let pairwise = falsify_pairwise_summary(summary)
  assert_eq(pairwise.n_violations(), 0)
  assert_eq(pairwise.n_tests(), 3)
  assert_true(
    falsify_p_value_near(pairwise.p_value_of("Y", "X"), 3.229255803441655e-25),
  )
  assert_true(
    falsify_p_value_near(pairwise.p_value_of("Z", "X"), 5.775291018426854e-18),
  )
  assert_true(
    falsify_p_value_near(pairwise.p_value_of("Z", "Y"), 4.978645772927865e-41),
  )
  let tpa = falsify_tpa_summary(summary)
  assert_eq(tpa.n_violations(), 0)
  assert_eq(tpa.n_tests(), 1)
}

///|
/// test "given wrong chain when validating graph then report violations"
test "given wrong chain when validating graph then report violations" {
  let graph = falsify_wrong_chain_graph()
  let summary = @gcm.run_validations(
    graph,
    @gcm.falsify_chain_frame(),
    falsify_validation_methods(falsify_chain_graph()),
  )
  let lmc = falsify_lmc_summary(summary)
  assert_eq(lmc.n_violations(), 1)
  assert_eq(lmc.n_tests(), 1)
  assert_true(
    falsify_p_value_near(lmc.p_value_of("Y", "X"), 5.220824583485307e-11),
  )
  let pairwise = falsify_pairwise_summary(summary)
  assert_eq(pairwise.n_violations(), 0)
  assert_eq(pairwise.n_tests(), 3)
  let tpa = falsify_tpa_summary(summary)
  assert_eq(tpa.n_violations(), 1)
  assert_eq(tpa.n_tests(), 1)
}

///|
/// test "given empty DAG and data when validating graph then report no
/// violations"
test "given empty DAG and data when validating graph then report no violations" {
  let graph = @graph.DirectedGraph::new()
  let summary = @gcm.run_validations(
    graph,
    @api.DataFrame::from_numeric([], Map([])),
    falsify_validation_methods(graph),
  )
  let lmc = falsify_lmc_summary(summary)
  assert_eq(lmc.n_violations(), 0)
  assert_eq(lmc.n_tests(), 0)
  let pairwise = falsify_pairwise_summary(summary)
  assert_eq(pairwise.n_violations(), 0)
  assert_eq(pairwise.n_tests(), 0)
  let tpa = falsify_tpa_summary(summary)
  assert_eq(tpa.n_violations(), 0)
  assert_eq(tpa.n_tests(), 0)
}

///|
/// test "given correct full DAG when validating graph then report no
/// violations"
test "given correct full DAG when validating graph then report no violations" {
  let graph = falsify_full_dag_graph()
  let summary = @gcm.run_validations(
    graph,
    @gcm.falsify_full_dag_frame(),
    falsify_validation_methods(graph),
  )
  let lmc = falsify_lmc_summary(summary)
  assert_eq(lmc.n_violations(), 0)
  assert_eq(lmc.n_tests(), 0)
  let pairwise = falsify_pairwise_summary(summary)
  assert_eq(pairwise.n_violations(), 0)
  assert_eq(pairwise.n_tests(), 6)
  assert_true(
    falsify_p_value_near(
      pairwise.p_value_of("X1", "X0"),
      4.3647372761782895e-28,
    ),
  )
  assert_true(
    falsify_p_value_near(pairwise.p_value_of("X2", "X0"), 4.034774870764436e-42),
  )
  assert_true(
    falsify_p_value_near(pairwise.p_value_of("X2", "X1"), 3.440471741645087e-47),
  )
  assert_true(
    falsify_p_value_near(pairwise.p_value_of("X3", "X0"), 1.954668902175098e-43),
  )
  assert_true(
    falsify_p_value_near(
      pairwise.p_value_of("X3", "X1"),
      4.7145133043027784e-51,
    ),
  )
  assert_true(
    falsify_p_value_near(pairwise.p_value_of("X3", "X2"), 6.636060190439766e-63),
  )
  let tpa = falsify_tpa_summary(summary)
  assert_eq(tpa.n_violations(), 0)
  assert_eq(tpa.n_tests(), 0)
}

///|
/// test "given correct single node when validating graph then report no
/// violations"
test "given correct single node when validating graph then report no violations" {
  let graph = falsify_single_node_graph()
  let summary = @gcm.run_validations(
    graph,
    @gcm.falsify_single_node_frame(),
    falsify_validation_methods(graph),
  )
  let lmc = falsify_lmc_summary(summary)
  assert_eq(lmc.n_violations(), 0)
  assert_eq(lmc.n_tests(), 0)
  let pairwise = falsify_pairwise_summary(summary)
  assert_eq(pairwise.n_violations(), 0)
  assert_eq(pairwise.n_tests(), 0)
  let tpa = falsify_tpa_summary(summary)
  assert_eq(tpa.n_violations(), 0)
  assert_eq(tpa.n_tests(), 0)
}

///|
/// test "given correct single edge when validating graph then report no
/// violations"
test "given correct single edge when validating graph then report no violations" {
  let graph = falsify_single_edge_graph()
  let summary = @gcm.run_validations(
    graph,
    @gcm.falsify_single_edge_frame(),
    falsify_validation_methods(graph),
  )
  let lmc = falsify_lmc_summary(summary)
  assert_eq(lmc.n_violations(), 0)
  assert_eq(lmc.n_tests(), 0)
  let pairwise = falsify_pairwise_summary(summary)
  assert_eq(pairwise.n_violations(), 0)
  assert_eq(pairwise.n_tests(), 1)
  assert_true(
    falsify_p_value_near(
      pairwise.p_value_of("X1", "X0"),
      1.4228819060183535e-52,
    ),
  )
  let tpa = falsify_tpa_summary(summary)
  assert_eq(tpa.n_violations(), 0)
  assert_eq(tpa.n_tests(), 0)
}

///|
/// test "given wrong single edge when validating graph then report violations"
test "given wrong single edge when validating graph then report violations" {
  let graph = falsify_wrong_single_edge_graph()
  let summary = @gcm.run_validations(
    graph,
    @gcm.falsify_single_edge_frame(),
    falsify_validation_methods(falsify_single_edge_graph()),
  )
  let lmc = falsify_lmc_summary(summary)
  assert_eq(lmc.n_violations(), 2)
  assert_eq(lmc.n_tests(), 2)
  assert_true(
    falsify_p_value_near(lmc.p_value_of("X0", "X1"), 1.4228819060183535e-52),
  )
  assert_true(
    falsify_p_value_near(lmc.p_value_of("X1", "X0"), 1.4228819060183535e-52),
  )
  let pairwise = falsify_pairwise_summary(summary)
  assert_eq(pairwise.n_violations(), 0)
  assert_eq(pairwise.n_tests(), 0)
  let tpa = falsify_tpa_summary(summary)
  assert_eq(tpa.n_violations(), 2)
  assert_eq(tpa.n_tests(), 2)
}

///|
/// test "given non minimal DAG when validating causal minimality then report
/// violations"
test "given non minimal DAG when validating causal minimality then report violations" {
  let graph = falsify_non_minimality_graph()
  let summary = @gcm.run_validations(
    graph,
    @gcm.falsify_causal_minimality_frame(),
    falsify_minimality_methods(),
  )
  let cm = falsify_cm_summary(summary)
  assert_eq(cm.n_violations(), 1)
  assert_eq(cm.n_tests(), 3)
  assert_true(
    falsify_p_value_near(
      cm.p_value_of("Y", "X0", ["X1", "X2"]),
      8.780079041279715e-51,
    ),
  )
  assert_true(
    falsify_p_value_near(
      cm.p_value_of("Y", "X1", ["X0", "X2"]),
      3.348282079983788e-59,
    ),
  )
  assert_true(
    falsify_p_value_near(
      cm.p_value_of("Y", "X2", ["X0", "X1"]),
      0.38134523306085344,
    ),
  )
}

///|
/// test "given minimal DAG when validating causal minimality then report no
/// violations"
test "given minimal DAG when validating causal minimality then report no violations" {
  let graph = falsify_minimality_graph()
  let summary = @gcm.run_validations(
    graph,
    @gcm.falsify_causal_minimality_frame(),
    falsify_minimality_methods(),
  )
  let cm = falsify_cm_summary(summary)
  assert_eq(cm.n_violations(), 0)
  assert_eq(cm.n_tests(), 2)
  assert_true(
    falsify_p_value_near(
      cm.p_value_of("Y", "X0", ["X1"]),
      5.388323541605452e-51,
    ),
  )
  assert_true(
    falsify_p_value_near(
      cm.p_value_of("Y", "X1", ["X0"]),
      4.471765279142472e-59,
    ),
  )
}

///|
/// test "given data of only a subset of nodes when falsify and set allow data
/// subset to false then raise error"
///
/// MoonBit has no exceptions, so the function that tells whether the data
/// covers the graph is public and the test asserts its answer.
test "given data of only a subset of nodes when falsify and set allow data subset to false then raise error" {
  let graph = falsify_chain_graph()
  let data = @api.DataFrame::from_numeric(["X"], Map([("X", [0.1, 0.2, 0.3])]))
  assert_false(@gcm.data_covers_graph(graph, data))
}

///|
/// test "given no data when falsify then does not raise error but cannot
/// evaluate"
test "given no data when falsify then does not raise error but cannot evaluate" {
  let graph = falsify_chain_graph()
  let empty = @gcm.falsify_graph(
    graph,
    @api.DataFrame::from_numeric([], Map([])),
    falsify_test,
    falsify_test,
    FALSIFY_SIGNIFICANCE_LEVEL,
    FALSIFY_SIGNIFICANCE_LEVEL,
    Some(-1),
    false,
    @utils.Random::new(1UL),
    true,
  )
  assert_false(empty.can_evaluate())
  assert_true(empty.falsified() == None)
  let partial = @gcm.falsify_graph(
    graph,
    @api.DataFrame::from_numeric(["X"], Map([("X", [])])),
    falsify_test,
    falsify_test,
    FALSIFY_SIGNIFICANCE_LEVEL,
    FALSIFY_SIGNIFICANCE_LEVEL,
    Some(-1),
    false,
    @utils.Random::new(1UL),
    true,
  )
  assert_false(partial.can_evaluate())
}

///|
/// test "the falsification of the collider graph agrees with the upstream"
///
/// The upstream reference computes the falsification with every permutation of
/// the nodes of the graph, so the result does not depend on the generator.
test "the falsification of the collider graph agrees with the upstream" {
  let graph = falsify_collider_graph()
  let result = @gcm.falsify_graph(
    graph,
    @gcm.falsify_collider_frame(),
    falsify_test,
    falsify_test,
    FALSIFY_SIGNIFICANCE_LEVEL,
    FALSIFY_SIGNIFICANCE_LEVEL,
    Some(-1),
    false,
    @utils.Random::new(1UL),
    true,
  )
  assert_true(result.can_evaluate())
  assert_eq(result.falsified(), Some(false))
  assert_eq(result.falsifiable(), Some(false))
  let summary = result.summary()
  let lmc = match summary.local_markov_condition() {
    Some(value) => value
    None => abort("the local Markov condition was not validated")
  }
  assert_eq(lmc.n_tests(), 2)
  assert_eq(lmc.given_violations(), 0)
  assert_eq(lmc.f_given_violations(), 0.0)
  assert_true(falsify_p_value_near(Some(lmc.p_value()), 0.3333333333333333))
  let violations = lmc.perm_violations()
  assert_eq(violations.length(), 6)
  assert_eq(violations[0], 0)
  assert_eq(violations[1], 2)
  assert_eq(violations[2], 2)
  assert_eq(violations[3], 2)
  assert_eq(violations[4], 2)
  assert_eq(violations[5], 0)
  let fractions = lmc.f_perm_violations()
  assert_eq(fractions.length(), 6)
  assert_eq(fractions[0], 0.0)
  assert_eq(fractions[1], 1.0)
  assert_eq(fractions[5], 0.0)
  assert_eq(summary.markov_equivalence_class().length(), 2)
}

///|
/// test "the falsification of the chain graph agrees with the upstream"
test "the falsification of the chain graph agrees with the upstream" {
  let graph = falsify_chain_graph()
  let result = @gcm.falsify_graph(
    graph,
    @gcm.falsify_chain_frame(),
    falsify_test,
    falsify_test,
    FALSIFY_SIGNIFICANCE_LEVEL,
    FALSIFY_SIGNIFICANCE_LEVEL,
    Some(-1),
    false,
    @utils.Random::new(1UL),
    true,
  )
  assert_true(result.can_evaluate())
  assert_eq(result.falsified(), Some(false))
  assert_eq(result.falsifiable(), Some(false))
  let summary = result.summary()
  let lmc = match summary.local_markov_condition() {
    Some(value) => value
    None => abort("the local Markov condition was not validated")
  }
  assert_eq(lmc.n_tests(), 1)
  assert_eq(lmc.given_violations(), 0)
  assert_true(falsify_p_value_near(Some(lmc.p_value()), 0.3333333333333333))
  let violations = lmc.perm_violations()
  assert_eq(violations.length(), 6)
  assert_eq(violations[0], 0)
  assert_eq(violations[5], 0)
  assert_eq(violations[1], 1)
  assert_eq(summary.markov_equivalence_class().length(), 2)
}

///|
/// test "the suggestions of a falsification remove the edges whose causal
/// minimality was violated"
test "the suggestions of a falsification remove the edges whose causal minimality was violated" {
  let graph = falsify_non_minimality_graph()
  let result = @gcm.falsify_graph(
    graph,
    @gcm.falsify_causal_minimality_frame(),
    falsify_test,
    falsify_test,
    FALSIFY_SIGNIFICANCE_LEVEL,
    FALSIFY_SIGNIFICANCE_LEVEL,
    Some(-1),
    true,
    @utils.Random::new(1UL),
    true,
  )
  let suggested = @gcm.apply_suggestions(graph, result, None)
  assert_false(suggested.has_edge("X2", "Y"))
  assert_true(suggested.has_edge("X0", "Y"))
  assert_true(suggested.has_edge("X1", "Y"))
  let kept = @gcm.apply_suggestions(graph, result, Some([("X2", "Y")]))
  assert_true(kept.has_edge("X2", "Y"))
}

///|
/// test "the memory of the p-values is shared by the two orders of a pair"
test "the memory of the p-values is shared by the two orders of a pair" {
  let memory = @gcm.PValuesMemory::new()
  assert_false(memory.contains(["X"], ["Y"], []))
  memory.add_p_value(Some(0.25), ["X"], ["Y"], [])
  assert_true(memory.contains(["X"], ["Y"], []))
  assert_true(memory.contains(["Y"], ["X"], []))
  assert_eq(memory.get_p_value(["Y"], ["X"], []), Some(0.25))
  assert_eq(memory.get_p_value(["X"], ["Y"], ["Z"]), None)
}
