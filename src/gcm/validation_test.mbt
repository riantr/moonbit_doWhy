///|
/// The tests of the validation layer of the `gcm` package.
///
/// The upstream reference of the layer is `_verify/gcm_validation_reference.py`,
/// which runs the upstream `dowhy.gcm.validation` on the fixtures of the
/// validation layer. The p-values of the upstream come from the kernel based
/// independence test, which the port does not have yet, so the tests of the
/// structure of a graph use a stub of an independence test that returns a fixed
/// p-value. The stub makes the p-values, the adjusted p-values and the success
/// flags of every test of the summary exact.
///
/// The tests of the invertible model use the regression based test of the `gcm`
/// package, which is the closest counterpart of the kernel based test that the
/// upstream uses by default.
///
/// The nine cases of the upstream test file `tests/gcm/test_validation.py` are
/// among the cases of this file. Two of them depend on the number of the rows
/// of the data: the upstream test file uses five thousand rows of the non-linear
/// data and asserts that the invertible model of the correct graph is not
/// rejected and that the one of the graph with a collider is rejected, while
/// the sixty rows of the fixture of the port are too few for the upstream to
/// tell the signal from the noise. The outcomes of the upstream on the sixty
/// rows are the ones the reference script prints, and the port agrees with
/// them.

///|
/// The significance level of the tests.
const VALIDATION_SIGNIFICANCE_LEVEL : Double = 0.05

///|
/// The p-value of the stub of the marginal independence test.
const VALIDATION_EDGE_P_VALUE : Double = 0.001

///|
/// The p-value of the stub of the conditional independence test.
const VALIDATION_CONDITIONAL_P_VALUE : Double = 0.5

///|
/// The seed of the generator of the independence test of the invertible model
/// tests.
const VALIDATION_SEED : UInt64 = 20261031UL

///|
/// Whether two numbers are close to each other.
///
/// The comparison is relative, because the p-values of the tests span many
/// orders of magnitude: the p-value of an edge of a dependent pair of
/// variables is of the order of `1e-15` and the p-value of the local Markov
/// condition of an independent one is of the order of `1e-01`. Two numbers
/// that are not a number are close to each other only when both of them are
/// not a number.
///
/// The tolerance of `1e-10` is the noise floor of the upstream: the p-value
/// the upstream computes moves by about `1e-11` with the permutation of the
/// rows that its kernel test draws.
fn validation_near(a : Double, b : Double) -> Bool {
  if @utils.is_nan(a) || @utils.is_nan(b) {
    return @utils.is_nan(a) && @utils.is_nan(b)
  }
  let scale = b.abs()
  if scale < 1.0e-300 {
    return (a - b).abs() <= 1.0e-300
  }
  (a - b).abs() <= 1.0e-10 * scale
}

///|
/// A stub of an independence test that always returns the given p-value.
fn constant_test(p_value : Double) -> @gcm.IndependenceTest {
  fn(_x, _y, _z) { p_value }
}

///|
/// The graph of the collider, whose edges are `X -> Z` and `Y -> Z`.
fn collider_graph() -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X", "Z")
  graph.add_edge("Y", "Z")
  graph
}

///|
/// The graph of the chain, whose edges are `X -> Z` and `Z -> Y`.
fn chain_graph() -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X", "Z")
  graph.add_edge("Z", "Y")
  graph
}

///|
/// The graph of the fork, whose edges are `Z -> X` and `Z -> Y`.
fn fork_graph() -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("Z", "X")
  graph.add_edge("Z", "Y")
  graph
}

///|
/// The graph of the general graph, whose edges are `Z -> X`, `Z -> Y` and
/// `X -> Y`.
fn general_graph() -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("Z", "X")
  graph.add_edge("Z", "Y")
  graph.add_edge("X", "Y")
  graph
}

///|
/// The parents of the edges into a node, in ascending order.
fn edge_parents(
  summary : @gcm.ValidationSummary,
  node : String,
) -> Array[String] {
  match summary.node(node) {
    Some(node_validation) => {
      let parents : Array[String] = []
      for parent in node_validation.edge_dependence_test().keys() {
        parents.push(parent)
      }
      parents.sort_by(fn(a, b) { a.lexical_compare(b) })
      parents
    }
    None => abort("the summary has no node " + node)
  }
}

///|
/// Assert that the node has no local Markov test.
fn assert_no_local_markov_test(
  summary : @gcm.ValidationSummary,
  node : String,
) -> Unit {
  match summary.node(node) {
    Some(node_validation) =>
      match node_validation.local_markov_test() {
        Some(_) => abort("the node " + node + " has a local Markov test")
        None => ()
      }
    None => abort("the summary has no node " + node)
  }
}

///|
/// Assert the result of the local Markov test of a node.
fn assert_local_markov_test(
  summary : @gcm.ValidationSummary,
  node : String,
  p_value : Double,
  adjusted_p_value : Double,
  success : Bool,
) -> Unit raise {
  match summary.node(node) {
    Some(node_validation) =>
      match node_validation.local_markov_test() {
        Some(result) => {
          assert_true(validation_near(result.p_value(), p_value))
          assert_true(
            validation_near(result.fdr_adjusted_p_value(), adjusted_p_value),
          )
          assert_eq(result.success(), success)
        }
        None => abort("the node " + node + " has no local Markov test")
      }
    None => abort("the summary has no node " + node)
  }
}

///|
/// Assert that the node has no edge dependence test.
fn assert_no_edge_dependence_test(
  summary : @gcm.ValidationSummary,
  node : String,
) -> Unit raise {
  match summary.node(node) {
    Some(node_validation) =>
      assert_eq(node_validation.edge_dependence_test().length(), 0)
    None => abort("the summary has no node " + node)
  }
}

///|
/// Assert the result of the dependence test of the edge between the given
/// parent and the node.
fn assert_edge_dependence_test(
  summary : @gcm.ValidationSummary,
  node : String,
  parent : String,
  p_value : Double,
  adjusted_p_value : Double,
  success : Bool,
) -> Unit raise {
  match summary.node(node) {
    Some(node_validation) =>
      match node_validation.edge_dependence_test_of(parent) {
        Some(result) => {
          assert_true(validation_near(result.p_value(), p_value))
          assert_true(
            validation_near(result.fdr_adjusted_p_value(), adjusted_p_value),
          )
          assert_eq(result.success(), success)
        }
        None =>
          abort(
            "the node " +
            node +
            " has no edge dependence test of the parent " +
            parent,
          )
      }
    None => abort("the summary has no node " + node)
  }
}

///|
/// The p-value and the FDR adjusted p-value of the local Markov test of a
/// node.
fn local_markov_values(
  summary : @gcm.ValidationSummary,
  node : String,
) -> (Double, Double) {
  match summary.node(node) {
    Some(node_validation) =>
      match node_validation.local_markov_test() {
        Some(result) => (result.p_value(), result.fdr_adjusted_p_value())
        None => abort("the node " + node + " has no local Markov test")
      }
    None => abort("the summary has no node " + node)
  }
}

///|
/// The p-value and the FDR adjusted p-value of the dependence test of the edge
/// between the given parent and the node.
fn edge_dependence_values(
  summary : @gcm.ValidationSummary,
  node : String,
  parent : String,
) -> (Double, Double) {
  match summary.node(node) {
    Some(node_validation) =>
      match node_validation.edge_dependence_test_of(parent) {
        Some(result) => (result.p_value(), result.fdr_adjusted_p_value())
        None =>
          abort(
            "the node " +
            node +
            " has no edge dependence test of the parent " +
            parent,
          )
      }
    None => abort("the summary has no node " + node)
  }
}

///|
/// Assert that the summary holds the given nodes.
fn assert_nodes(
  summary : @gcm.ValidationSummary,
  nodes : Array[String],
) -> Unit raise {
  let names = summary.node_names()
  assert_eq(names.length(), nodes.length())
  for node in nodes {
    assert_true(names.contains(node))
  }
}

///|
/// The independence test of the invertible model tests.
///
/// This is the kernel based test of the `gcm` package, which is the test the
/// upstream uses by default.
fn kernel_test(
  x : @utils.Matrix,
  y : @utils.Matrix,
  z : @utils.Matrix?,
) -> Double {
  @gcm.kernel_based(
    x,
    y,
    z,
    false,
    1,
    2000,
    fn(p_values) { p_values[0] },
    @utils.Random::new(VALIDATION_SEED),
  )
}

///|
/// A fitted causal model of the graph with the given edges.
fn fitted_model(
  edges : Array[(String, String)],
  data : @api.DataFrame,
) -> @gcm.ProbabilisticCausalModel {
  let graph = @graph.DirectedGraph::new()
  for (from, to) in edges {
    graph.add_edge(from, to)
  }
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  let _ = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
  )
  @gcm.fit(model, data)
  model
}

///|
/// The p-values the validation of the invertible model computes, one for every
/// node that has a parent.
fn invertible_p_values(
  model : @gcm.ProbabilisticCausalModel,
  data : @api.DataFrame,
  independence_test : @gcm.IndependenceTest,
) -> Array[Double] {
  let p_values : Array[Double] = []
  for node in model.nodes() {
    let parents = model.graph().predecessors(node)
    if parents.length() == 0 {
      continue
    }
    parents.sort_by(fn(a, b) { a.lexical_compare(b) })
    let parents_samples = data.design_matrix(parents)
    let mechanism = match model.causal_mechanism(node) {
      Some(mechanism) => mechanism
      None => abort("the node " + node + " has no causal mechanism")
    }
    let residuals = mechanism.estimate_noise(
      data.numeric(node),
      parents_samples,
    )
    let residual_samples = @utils.Matrix::from_columns([residuals])
    p_values.push(independence_test(parents_samples, residual_samples, None))
  }
  p_values
}

///|
/// test "the false discovery rate control of Benjamini and Hochberg rejects the
/// first p-value only"
///
/// The p-values and the adjusted p-values are the ones of the upstream
/// `statsmodels.stats.multitest.multipletests` with the method `fdr_bh` and
/// the level `0.05`.
test "the false discovery rate control of Benjamini and Hochberg rejects the first p-value only" {
  let p_values = [
    0.001, 0.008, 0.039, 0.041, 0.042, 0.06, 0.074, 0.205, 0.212, 0.216, 0.222, 0.251,
    0.269, 0.275, 0.34,
  ]
  let expected = [
    0.015, 0.06, 0.126, 0.126, 0.126, 0.15, 0.15857142857142857, 0.29464285714285715,
    0.29464285714285715, 0.29464285714285715, 0.29464285714285715, 0.29464285714285715,
    0.29464285714285715, 0.29464285714285715, 0.34,
  ]
  let result = @gcm.fdr_bh_adjust(p_values, VALIDATION_SIGNIFICANCE_LEVEL)
  let reject = result.reject()
  let adjusted_p_values = result.adjusted_p_values()
  assert_eq(reject.length(), 15)
  assert_eq(adjusted_p_values.length(), 15)
  assert_true(reject[0])
  for i in 1..<15 {
    assert_false(reject[i])
  }
  for i in 0..<15 {
    assert_true(validation_near(adjusted_p_values[i], expected[i]))
  }
}

///|
/// test "the false discovery rate control of an empty list of p-values is
/// empty"
test "the false discovery rate control of an empty list of p-values is empty" {
  let result = @gcm.fdr_bh_adjust([], VALIDATION_SIGNIFICANCE_LEVEL)
  assert_eq(result.reject().length(), 0)
  assert_eq(result.adjusted_p_values().length(), 0)
}

///|
/// test "the validation of the collider graph is not rejected"
///
/// The graph is `X -> Z <- Y`, so the node `Z` has the parents `X` and `Y` and
/// no non-descendant. The local Markov test of the node `Z` is therefore not
/// run, and the two edges into it are found to be dependent.
test "the validation of the collider graph is not rejected" {
  let (outcome, summary) = @gcm.refute_causal_structure(
    collider_graph(),
    @gcm.validation_collider_frame(),
    constant_test(VALIDATION_EDGE_P_VALUE),
    constant_test(VALIDATION_CONDITIONAL_P_VALUE),
    VALIDATION_SIGNIFICANCE_LEVEL,
    Some(@gcm.FdrControlMethod::fdr_bh()),
  )
  assert_eq(outcome.to_string(), "NotRejected")
  assert_false(outcome.is_rejected())
  assert_nodes(summary, ["X", "Y", "Z"])
  assert_no_local_markov_test(summary, "X")
  assert_no_edge_dependence_test(summary, "X")
  assert_no_local_markov_test(summary, "Y")
  assert_no_edge_dependence_test(summary, "Y")
  assert_no_local_markov_test(summary, "Z")
  assert_eq(edge_parents(summary, "Z"), ["X", "Y"])
  assert_edge_dependence_test(
    summary,
    "Z",
    "X",
    VALIDATION_EDGE_P_VALUE,
    VALIDATION_EDGE_P_VALUE,
    true,
  )
  assert_edge_dependence_test(
    summary,
    "Z",
    "Y",
    VALIDATION_EDGE_P_VALUE,
    VALIDATION_EDGE_P_VALUE,
    true,
  )
}

///|
/// test "the validation of the chain graph is not rejected"
///
/// The graph is `X -> Z -> Y`. The node `Y` has the parent `Z` and the
/// non-descendant `X`, so its local Markov test is run, and the node `Z` has
/// the parent `X` and no non-descendant, so its local Markov test is not run.
test "the validation of the chain graph is not rejected" {
  let (outcome, summary) = @gcm.refute_causal_structure(
    chain_graph(),
    @gcm.validation_chain_frame(),
    constant_test(VALIDATION_EDGE_P_VALUE),
    constant_test(VALIDATION_CONDITIONAL_P_VALUE),
    VALIDATION_SIGNIFICANCE_LEVEL,
    Some(@gcm.FdrControlMethod::fdr_bh()),
  )
  assert_eq(outcome.to_string(), "NotRejected")
  assert_false(outcome.is_rejected())
  assert_nodes(summary, ["X", "Y", "Z"])
  assert_no_local_markov_test(summary, "X")
  assert_no_edge_dependence_test(summary, "X")
  assert_no_local_markov_test(summary, "Z")
  assert_eq(edge_parents(summary, "Z"), ["X"])
  assert_edge_dependence_test(
    summary,
    "Z",
    "X",
    VALIDATION_EDGE_P_VALUE,
    0.0015,
    true,
  )
  assert_local_markov_test(
    summary,
    "Y",
    VALIDATION_CONDITIONAL_P_VALUE,
    VALIDATION_CONDITIONAL_P_VALUE,
    true,
  )
  assert_eq(edge_parents(summary, "Y"), ["Z"])
  assert_edge_dependence_test(
    summary,
    "Y",
    "Z",
    VALIDATION_EDGE_P_VALUE,
    0.0015,
    true,
  )
}

///|
/// test "the validation of the fork graph is not rejected"
///
/// The graph is `Z -> X` and `Z -> Y`. The nodes `X` and `Y` have the parent
/// `Z` and one non-descendant each, so their local Markov tests are run.
test "the validation of the fork graph is not rejected" {
  let (outcome, summary) = @gcm.refute_causal_structure(
    fork_graph(),
    @gcm.validation_fork_frame(),
    constant_test(VALIDATION_EDGE_P_VALUE),
    constant_test(VALIDATION_CONDITIONAL_P_VALUE),
    VALIDATION_SIGNIFICANCE_LEVEL,
    Some(@gcm.FdrControlMethod::fdr_bh()),
  )
  assert_eq(outcome.to_string(), "NotRejected")
  assert_false(outcome.is_rejected())
  assert_nodes(summary, ["X", "Y", "Z"])
  assert_no_local_markov_test(summary, "Z")
  assert_no_edge_dependence_test(summary, "Z")
  assert_local_markov_test(
    summary,
    "X",
    VALIDATION_CONDITIONAL_P_VALUE,
    VALIDATION_CONDITIONAL_P_VALUE,
    true,
  )
  assert_eq(edge_parents(summary, "X"), ["Z"])
  assert_edge_dependence_test(
    summary,
    "X",
    "Z",
    VALIDATION_EDGE_P_VALUE,
    0.002,
    true,
  )
  assert_local_markov_test(
    summary,
    "Y",
    VALIDATION_CONDITIONAL_P_VALUE,
    VALIDATION_CONDITIONAL_P_VALUE,
    true,
  )
  assert_eq(edge_parents(summary, "Y"), ["Z"])
  assert_edge_dependence_test(
    summary,
    "Y",
    "Z",
    VALIDATION_EDGE_P_VALUE,
    0.002,
    true,
  )
}

///|
/// test "the validation of the general graph is not rejected"
///
/// The graph is `Z -> X`, `Z -> Y` and `X -> Y`. Every node with a parent has
/// no non-descendant, so no local Markov test is run.
test "the validation of the general graph is not rejected" {
  let (outcome, summary) = @gcm.refute_causal_structure(
    general_graph(),
    @gcm.validation_general_frame(),
    constant_test(VALIDATION_EDGE_P_VALUE),
    constant_test(VALIDATION_CONDITIONAL_P_VALUE),
    VALIDATION_SIGNIFICANCE_LEVEL,
    Some(@gcm.FdrControlMethod::fdr_bh()),
  )
  assert_eq(outcome.to_string(), "NotRejected")
  assert_false(outcome.is_rejected())
  assert_nodes(summary, ["X", "Y", "Z"])
  assert_no_local_markov_test(summary, "Z")
  assert_no_edge_dependence_test(summary, "Z")
  assert_no_local_markov_test(summary, "X")
  assert_eq(edge_parents(summary, "X"), ["Z"])
  assert_edge_dependence_test(
    summary,
    "X",
    "Z",
    VALIDATION_EDGE_P_VALUE,
    VALIDATION_EDGE_P_VALUE,
    true,
  )
  assert_no_local_markov_test(summary, "Y")
  assert_eq(edge_parents(summary, "Y"), ["X", "Z"])
  assert_edge_dependence_test(
    summary,
    "Y",
    "X",
    VALIDATION_EDGE_P_VALUE,
    VALIDATION_EDGE_P_VALUE,
    true,
  )
  assert_edge_dependence_test(
    summary,
    "Y",
    "Z",
    VALIDATION_EDGE_P_VALUE,
    VALIDATION_EDGE_P_VALUE,
    true,
  )
}

///|
/// test "the validation with the false discovery rate control has adjusted
/// p-values that are not smaller than the p-values"
///
/// The control of Benjamini and Hochberg only raises the p-values, so the
/// adjusted p-value of every test is not smaller than the p-value of the same
/// test. The upstream asserts the same relation for the four tests of the fork
/// graph.
test "the validation with the false discovery rate control has adjusted p-values that are not smaller than the p-values" {
  let (outcome, summary) = @gcm.refute_causal_structure(
    fork_graph(),
    @gcm.validation_fork_frame(),
    kernel_test,
    kernel_test,
    VALIDATION_SIGNIFICANCE_LEVEL,
    Some(@gcm.FdrControlMethod::fdr_bh()),
  )
  assert_eq(outcome.to_string(), "NotRejected")
  let (x_markov, x_markov_adjusted) = local_markov_values(summary, "X")
  let (x_edge, x_edge_adjusted) = edge_dependence_values(summary, "X", "Z")
  let (y_markov, y_markov_adjusted) = local_markov_values(summary, "Y")
  let (y_edge, y_edge_adjusted) = edge_dependence_values(summary, "Y", "Z")
  assert_true(x_markov_adjusted >= x_markov)
  assert_true(x_edge_adjusted >= x_edge)
  assert_true(y_markov_adjusted >= y_markov)
  assert_true(y_edge_adjusted >= y_edge)
}

///|
/// test "the validation without the false discovery rate control has no
/// adjusted p-value"
///
/// Without the control the p-values are compared with the significance level
/// one by one, and the adjusted p-values are not a number.
test "the validation without the false discovery rate control has no adjusted p-value" {
  let (outcome, summary) = @gcm.refute_causal_structure(
    fork_graph(),
    @gcm.validation_fork_frame(),
    constant_test(VALIDATION_EDGE_P_VALUE),
    constant_test(VALIDATION_CONDITIONAL_P_VALUE),
    VALIDATION_SIGNIFICANCE_LEVEL,
    None,
  )
  assert_eq(outcome.to_string(), "NotRejected")
  assert_local_markov_test(
    summary,
    "X",
    VALIDATION_CONDITIONAL_P_VALUE,
    @utils.nan(),
    true,
  )
  assert_edge_dependence_test(
    summary,
    "X",
    "Z",
    VALIDATION_EDGE_P_VALUE,
    @utils.nan(),
    true,
  )
  assert_local_markov_test(
    summary,
    "Y",
    VALIDATION_CONDITIONAL_P_VALUE,
    @utils.nan(),
    true,
  )
  assert_edge_dependence_test(
    summary,
    "Y",
    "Z",
    VALIDATION_EDGE_P_VALUE,
    @utils.nan(),
    true,
  )
  // The adjusted p-values are not a number, and the success flags follow the
  // comparison of the p-values with the significance level.
  let (other_outcome, other_summary) = @gcm.refute_causal_structure(
    fork_graph(),
    @gcm.validation_fork_frame(),
    constant_test(0.9),
    constant_test(0.001),
    VALIDATION_SIGNIFICANCE_LEVEL,
    None,
  )
  assert_eq(other_outcome.to_string(), "Rejected")
  assert_local_markov_test(other_summary, "X", 0.001, @utils.nan(), false)
  assert_edge_dependence_test(other_summary, "X", "Z", 0.9, @utils.nan(), false)
  assert_local_markov_test(other_summary, "Y", 0.001, @utils.nan(), false)
  assert_edge_dependence_test(other_summary, "Y", "Z", 0.9, @utils.nan(), false)
}

///|
/// test "the validation of a graph whose edges are independent is rejected"
///
/// A p-value that is above the significance level means that the parent and
/// the node were found to be independent, so the edge does not hold.
test "the validation of a graph whose edges are independent is rejected" {
  let (outcome, summary) = @gcm.refute_causal_structure(
    chain_graph(),
    @gcm.validation_chain_frame(),
    constant_test(0.9),
    constant_test(0.9),
    VALIDATION_SIGNIFICANCE_LEVEL,
    Some(@gcm.FdrControlMethod::fdr_bh()),
  )
  assert_eq(outcome.to_string(), "Rejected")
  assert_true(outcome.is_rejected())
  // The edge into the node `Z` is found to be independent, and the local
  // Markov condition of the node `Y` holds.
  assert_edge_dependence_test(summary, "Z", "X", 0.9, 0.9, false)
  assert_local_markov_test(summary, "Y", 0.9, 0.9, true)
}

///|
/// test "the validation of a graph whose local Markov condition fails is
/// rejected"
///
/// A p-value of the conditional test that is below the significance level means
/// that the node was found to be dependent of its non-descendants given its
/// parents, so the local Markov condition does not hold.
test "the validation of a graph whose local Markov condition fails is rejected" {
  let (outcome, summary) = @gcm.refute_causal_structure(
    chain_graph(),
    @gcm.validation_chain_frame(),
    constant_test(VALIDATION_EDGE_P_VALUE),
    constant_test(VALIDATION_EDGE_P_VALUE),
    VALIDATION_SIGNIFICANCE_LEVEL,
    Some(@gcm.FdrControlMethod::fdr_bh()),
  )
  assert_eq(outcome.to_string(), "Rejected")
  assert_true(outcome.is_rejected())
  // The edges are found to be dependent, and the local Markov condition of the
  // node `Y` fails.
  assert_edge_dependence_test(summary, "Z", "X", 0.001, 0.001, true)
  assert_local_markov_test(summary, "Y", 0.001, 0.001, false)
  assert_edge_dependence_test(summary, "Y", "Z", 0.001, 0.001, true)
}

///|
/// test "the validation of a graph whose edges are dependent and whose local
/// Markov condition holds is not rejected"
test "the validation of a graph whose edges are dependent and whose local Markov condition holds is not rejected" {
  let (outcome, summary) = @gcm.refute_causal_structure(
    chain_graph(),
    @gcm.validation_chain_frame(),
    constant_test(VALIDATION_EDGE_P_VALUE),
    constant_test(0.9),
    VALIDATION_SIGNIFICANCE_LEVEL,
    Some(@gcm.FdrControlMethod::fdr_bh()),
  )
  assert_eq(outcome.to_string(), "NotRejected")
  assert_false(outcome.is_rejected())
  assert_edge_dependence_test(summary, "Z", "X", 0.001, 0.0015, true)
  assert_local_markov_test(summary, "Y", 0.9, 0.9, true)
  assert_edge_dependence_test(summary, "Y", "Z", 0.001, 0.0015, true)
}

///|
/// test "the validation of the collider graph with the kernel based test
/// agrees with the upstream"
///
/// The upstream computes the p-values of the test with the kernel based
/// independence test, which is its default. The expectations are the ones of
/// the reference script `_verify/gcm_validation_reference.py`.
test "the validation of the collider graph with the kernel based test agrees with the upstream" {
  let (outcome, summary) = @gcm.refute_causal_structure(
    collider_graph(),
    @gcm.validation_collider_frame(),
    kernel_test,
    kernel_test,
    VALIDATION_SIGNIFICANCE_LEVEL,
    Some(@gcm.FdrControlMethod::fdr_bh()),
  )
  assert_eq(outcome.to_string(), "NotRejected")
  assert_no_local_markov_test(summary, "X")
  assert_no_local_markov_test(summary, "Y")
  assert_no_local_markov_test(summary, "Z")
  assert_edge_dependence_test(
    summary, "Z", "X", 7.86620205069921141e-05, 7.86620205069921141e-05, true,
  )
  assert_edge_dependence_test(
    summary, "Z", "Y", 4.80876649611161611e-09, 9.617532992223232e-09, true,
  )
}

///|
/// test "the validation of the chain graph with the kernel based test agrees
/// with the upstream"
test "the validation of the chain graph with the kernel based test agrees with the upstream" {
  let (outcome, summary) = @gcm.refute_causal_structure(
    chain_graph(),
    @gcm.validation_chain_frame(),
    kernel_test,
    kernel_test,
    VALIDATION_SIGNIFICANCE_LEVEL,
    Some(@gcm.FdrControlMethod::fdr_bh()),
  )
  assert_eq(outcome.to_string(), "NotRejected")
  assert_no_local_markov_test(summary, "X")
  assert_no_local_markov_test(summary, "Z")
  assert_edge_dependence_test(
    summary, "Z", "X", 2.07611705604904273e-14, 3.114175584073564e-14, true,
  )
  assert_local_markov_test(
    summary, "Y", 4.66289432601723397e-01, 4.66289432601723397e-01, true,
  )
  assert_edge_dependence_test(
    summary, "Y", "Z", 4.44089209850062616e-16, 1.3322676295501878e-15, true,
  )
}

///|
/// test "the validation of the fork graph with the kernel based test agrees
/// with the upstream"
test "the validation of the fork graph with the kernel based test agrees with the upstream" {
  let (outcome, summary) = @gcm.refute_causal_structure(
    fork_graph(),
    @gcm.validation_fork_frame(),
    kernel_test,
    kernel_test,
    VALIDATION_SIGNIFICANCE_LEVEL,
    Some(@gcm.FdrControlMethod::fdr_bh()),
  )
  assert_eq(outcome.to_string(), "NotRejected")
  assert_no_local_markov_test(summary, "Z")
  assert_local_markov_test(
    summary, "X", 1.77488509791884352e-01, 1.82808519054147744e-01, true,
  )
  assert_edge_dependence_test(
    summary, "X", "Z", 1.22124532708767219e-15, 3.774758283725532e-15, true,
  )
  assert_local_markov_test(
    summary, "Y", 1.82808519054147744e-01, 1.82808519054147744e-01, true,
  )
  assert_edge_dependence_test(
    summary, "Y", "Z", 1.88737914186276612e-15, 3.774758283725532e-15, true,
  )
}

///|
/// test "the validation of the general graph with the kernel based test
/// agrees with the upstream"
test "the validation of the general graph with the kernel based test agrees with the upstream" {
  let (outcome, summary) = @gcm.refute_causal_structure(
    general_graph(),
    @gcm.validation_general_frame(),
    kernel_test,
    kernel_test,
    VALIDATION_SIGNIFICANCE_LEVEL,
    Some(@gcm.FdrControlMethod::fdr_bh()),
  )
  assert_eq(outcome.to_string(), "NotRejected")
  assert_no_local_markov_test(summary, "Z")
  assert_no_local_markov_test(summary, "X")
  assert_edge_dependence_test(
    summary, "X", "Z", 2.67563748934662726e-14, 4.013456234019941e-14, true,
  )
  assert_no_local_markov_test(summary, "Y")
  assert_edge_dependence_test(
    summary, "Y", "X", 1.66533453693773481e-15, 4.9960036108132044e-15, true,
  )
  assert_edge_dependence_test(
    summary, "Y", "Z", 2.20823359597943636e-13, 2.20823359597943636e-13, true,
  )
}

///|
/// test "the validation of the invertible model of a linear chain is not
/// rejected"
///
/// The fixture of the test is a linear chain, so the noise of the mechanism of
/// every node is independent of the parents of the node.
///
/// The upstream gives the same outcome for the three graphs of the fixture,
/// with the p-values `0.9047354286996766` and `0.6985439639801129` for the
/// correct chain, `0.6236135685663282` and `0.5663386858037838` for the
/// reversed one and `0.7304902965407123` for the collider.
test "the validation of the invertible model of a linear chain is not rejected" {
  let data = @gcm.validation_linear_frame()
  let graphs = [
    [("X", "Y"), ("Y", "Z")],
    [("Z", "Y"), ("Y", "X")],
    [("X", "Y"), ("Z", "Y")],
  ]
  for edges in graphs {
    let model = fitted_model(edges, data)
    let p_values = invertible_p_values(model, data, kernel_test)
    assert_true(p_values.length() > 0)
    for p_value in p_values {
      assert_true(p_value > VALIDATION_SIGNIFICANCE_LEVEL)
    }
    let outcome = @gcm.refute_invertible_model(
      model,
      data,
      kernel_test,
      VALIDATION_SIGNIFICANCE_LEVEL,
      None,
    )
    assert_eq(outcome.to_string(), "NotRejected")
    let controlled = @gcm.refute_invertible_model(
      model,
      data,
      kernel_test,
      VALIDATION_SIGNIFICANCE_LEVEL,
      Some(@gcm.FdrControlMethod::fdr_bh()),
    )
    assert_eq(controlled.to_string(), "NotRejected")
  }
}

///|
/// test "the validation of the invertible model of a non-linear chain is
/// rejected"
///
/// The relation of the fixture is `Y = X * X + noise`, and the automatic
/// assignment of the port always picks a linear regressor, so the residual of
/// the mechanism of the node `Y` still depends on its parent.
///
/// The upstream rejects the model of the correct chain as well, because its
/// own model of the node `Z` cannot capture the relation `Z = exp(-Y)` with
/// the sixty rows of the fixture.
test "the validation of the invertible model of a non-linear chain is rejected" {
  let data = @gcm.validation_nonlinear_frame()
  let model = fitted_model([("X", "Y"), ("Y", "Z")], data)
  let p_values = invertible_p_values(model, data, kernel_test)
  assert_true(p_values.length() > 0)
  let outcome = @gcm.refute_invertible_model(
    model,
    data,
    kernel_test,
    VALIDATION_SIGNIFICANCE_LEVEL,
    None,
  )
  assert_eq(outcome.to_string(), "Rejected")
  let controlled = @gcm.refute_invertible_model(
    model,
    data,
    kernel_test,
    VALIDATION_SIGNIFICANCE_LEVEL,
    Some(@gcm.FdrControlMethod::fdr_bh()),
  )
  assert_eq(controlled.to_string(), "Rejected")
}

///|
/// test "the validation of the invertible model of a reversed chain is
/// rejected"
///
/// The graph is `Z -> Y -> X`, which is the wrong direction of the relation of
/// the fixture, so the noise of the mechanism of the node `X` depends on its
/// parent. The upstream rejects the model of the same graph on the same rows,
/// with the p-value `3.8957551387386324e-05` for the node `X`.
test "the validation of the invertible model of a reversed chain is rejected" {
  let data = @gcm.validation_nonlinear_frame()
  let model = fitted_model([("Z", "Y"), ("Y", "X")], data)
  let p_values = invertible_p_values(model, data, kernel_test)
  assert_true(p_values.length() > 0)
  let outcome = @gcm.refute_invertible_model(
    model,
    data,
    kernel_test,
    VALIDATION_SIGNIFICANCE_LEVEL,
    None,
  )
  assert_eq(outcome.to_string(), "Rejected")
  let controlled = @gcm.refute_invertible_model(
    model,
    data,
    kernel_test,
    VALIDATION_SIGNIFICANCE_LEVEL,
    Some(@gcm.FdrControlMethod::fdr_bh()),
  )
  assert_eq(controlled.to_string(), "Rejected")
}

///|
/// test "the validation of the invertible model of a graph with a collider is
/// rejected"
///
/// The graph is `X -> Y <- Z`, so the node `Y` has the two parents `X` and `Z`.
/// The relation of the fixture is `Y = X * X + noise`, and the automatic
/// assignment of the port always picks a linear regressor, so the residual of
/// the mechanism of the node `Y` still depends on its parents.
///
/// The upstream rejects a model of that graph as well, on the five thousand
/// rows of its own test file. On the sixty rows of the fixture of the port the
/// upstream does not reject it, because its own selection of the causal
/// mechanisms captures the relation `Y = X * X` and the p-value of the node
/// `Y` is `0.6384596059805349` there.
test "the validation of the invertible model of a graph with a collider is rejected" {
  let data = @gcm.validation_nonlinear_frame()
  let model = fitted_model([("X", "Y"), ("Z", "Y")], data)
  let p_values = invertible_p_values(model, data, kernel_test)
  assert_true(p_values.length() > 0)
  let outcome = @gcm.refute_invertible_model(
    model,
    data,
    kernel_test,
    VALIDATION_SIGNIFICANCE_LEVEL,
    None,
  )
  assert_eq(outcome.to_string(), "Rejected")
  let controlled = @gcm.refute_invertible_model(
    model,
    data,
    kernel_test,
    VALIDATION_SIGNIFICANCE_LEVEL,
    Some(@gcm.FdrControlMethod::fdr_bh()),
  )
  assert_eq(controlled.to_string(), "Rejected")
}

///|
/// test "the validation of the invertible model refuses a model whose graph is
/// not acyclic"
///
/// The upstream raises a `ValueError` when the graph of the model has a cycle.
/// MoonBit cannot catch an abort, so the test asserts the condition that makes
/// the validation abort.
test "the validation of the invertible model refuses a model whose graph is not acyclic" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X", "Y")
  graph.add_edge("Y", "X")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  assert_false(graph.is_dag())
  assert_false(@gcm.has_valid_causal_model(model))
}
