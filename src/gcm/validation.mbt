///|
/// The validation layer of the graphical causal models of the `gcm` package.
///
/// This is the port of `dowhy.gcm.validation`. The upstream validates the
/// assumptions of a causal graph against the data with
/// `refute_causal_structure` and validates that the causal mechanisms of a
/// model can be represented by an invertible functional causal model with
/// `refute_invertible_model`.
///
/// The deviations from the upstream are the following ones.
///
/// The upstream takes two callables for the independence tests, one for the
/// marginal test of the edges and one for the conditional test of the local
/// Markov condition. The port takes two as well, but both have the type
/// `IndependenceTest`, whose third argument is the optional conditioning
/// variable: the marginal test of an edge gets `None` and the conditional test
/// of the local Markov condition gets the parents of the node.
///
/// The upstream takes the method of the false discovery rate control as a
/// string and hands it to `statsmodels`; the port has the enumeration
/// `FdrControlMethod` with the single value `FdrBh`, and `None` stands for the
/// `None` of the upstream.
///
/// The upstream builds the set of the non-descendants of a node in an arbitrary
/// order; the port uses the order of the graph, which is deterministic.
///
/// The upstream raises when the data has a missing value; the port has no
/// missing values.
///
/// The upstream's `refute_invertible_model` takes an
/// `InvertibleStructuralCausalModel`; the port has one model type,
/// `ProbabilisticCausalModel`.

///|
/// The outcome of a validation.
///
/// This is the port of `dowhy.gcm.validation.RejectionResult`.
pub enum RejectionResult {
  ///
  /// The assumption does not hold.
  Rejected
  ///
  /// The assumption holds.
  NotRejected
}

///|
/// Whether the assumption was rejected.
pub fn RejectionResult::is_rejected(self : RejectionResult) -> Bool {
  match self {
    Rejected => true
    NotRejected => false
  }
}

///|
/// The name of the outcome.
pub fn RejectionResult::to_string(self : RejectionResult) -> String {
  match self {
    Rejected => "Rejected"
    NotRejected => "NotRejected"
  }
}

///|
/// The method of the false discovery rate control.
///
/// This is the port of the `fdr_control_method` argument of the upstream, which
/// is a string there and an enumeration here. The upstream hands the string to
/// `statsmodels.stats.multitest.multipletests`, which knows several methods;
/// the port knows the method of Benjamini and Hochberg only.
pub enum FdrControlMethod {
  ///
  /// The step up procedure of Benjamini and Hochberg.
  FdrBh
}

///|
/// The step up procedure of Benjamini and Hochberg.
///
/// This is the port of the `fdr_bh` method of the upstream.
pub fn FdrControlMethod::fdr_bh() -> FdrControlMethod {
  FdrBh
}

///|
/// The result of the dependence test of an edge.
///
/// The test of an edge has the independence of the parent and of the node as
/// its null hypothesis, so its success means that the parent and the node were
/// found to be dependent.
pub struct EdgeDependenceTest {
  /// The p-value of the test.
  p_value : Double
  /// The p-value after the false discovery rate control.
  fdr_adjusted_p_value : Double
  /// Whether the test succeeded.
  success : Bool
}

///|
/// The p-value of the dependence test of an edge.
pub fn EdgeDependenceTest::p_value(self : EdgeDependenceTest) -> Double {
  self.p_value
}

///|
/// The p-value of the dependence test of an edge after the false discovery
/// rate control.
pub fn EdgeDependenceTest::fdr_adjusted_p_value(
  self : EdgeDependenceTest,
) -> Double {
  self.fdr_adjusted_p_value
}

///|
/// Whether the dependence test of an edge succeeded.
pub fn EdgeDependenceTest::success(self : EdgeDependenceTest) -> Bool {
  self.success
}

///|
/// The result of the local Markov test of a node.
///
/// The test has the conditional independence of the node and of its
/// non-descendants given its parents as its null hypothesis, so its success
/// means that the null hypothesis was not rejected.
pub struct LocalMarkovTest {
  /// The p-value of the test.
  p_value : Double
  /// The p-value after the false discovery rate control.
  fdr_adjusted_p_value : Double
  /// Whether the test succeeded.
  success : Bool
}

///|
/// The p-value of the local Markov test of a node.
pub fn LocalMarkovTest::p_value(self : LocalMarkovTest) -> Double {
  self.p_value
}

///|
/// The p-value of the local Markov test of a node after the false discovery
/// rate control.
pub fn LocalMarkovTest::fdr_adjusted_p_value(self : LocalMarkovTest) -> Double {
  self.fdr_adjusted_p_value
}

///|
/// Whether the local Markov test of a node succeeded.
pub fn LocalMarkovTest::success(self : LocalMarkovTest) -> Bool {
  self.success
}

///|
/// The validation results of one node.
///
/// The local Markov test is absent when the node has no parent or when it has
/// no non-descendant, because the test needs both of them.
pub struct NodeValidation {
  /// The local Markov test of the node, when it was run.
  local_markov_test : LocalMarkovTest?
  /// The dependence test of every edge into the node, keyed by the parent.
  edge_dependence_test : Map[String, EdgeDependenceTest]
}

///|
/// The local Markov test of a node, when it was run.
pub fn NodeValidation::local_markov_test(
  self : NodeValidation,
) -> LocalMarkovTest? {
  self.local_markov_test
}

///|
/// The dependence test of every edge into a node.
///
/// The returned map is a copy, so a caller may modify it without changing the
/// validation results.
pub fn NodeValidation::edge_dependence_test(
  self : NodeValidation,
) -> Map[String, EdgeDependenceTest] {
  self.edge_dependence_test.copy()
}

///|
/// The dependence test of the edge between the given parent and the node.
pub fn NodeValidation::edge_dependence_test_of(
  self : NodeValidation,
  parent : String,
) -> EdgeDependenceTest? {
  self.edge_dependence_test.get(parent)
}

///|
/// A copy of the validation results of a node.
///
/// The map of the edge dependence tests is copied as well, so that the copy
/// shares nothing with the original.
fn copy_node_validation(node : NodeValidation) -> NodeValidation {
  {
    local_markov_test: node.local_markov_test,
    edge_dependence_test: node.edge_dependence_test.copy(),
  }
}

///|
/// The validation summary of a graph.
///
/// The summary holds the results of every node of the graph, keyed by the name
/// of the node.
pub struct ValidationSummary {
  /// The results of every node of the graph.
  nodes : Map[String, NodeValidation]
}

///|
/// The results of every node of the graph.
///
/// The returned map is a copy, so a caller may modify it without changing the
/// summary.
pub fn ValidationSummary::nodes(
  self : ValidationSummary,
) -> Map[String, NodeValidation] {
  let nodes : Map[String, NodeValidation] = Map([])
  for name in self.nodes.keys() {
    match self.nodes.get(name) {
      Some(node) => nodes.set(name, copy_node_validation(node))
      None => ()
    }
  }
  nodes
}

///|
/// The results of the given node of the graph.
pub fn ValidationSummary::node(
  self : ValidationSummary,
  name : String,
) -> NodeValidation? {
  match self.nodes.get(name) {
    Some(node) => Some(copy_node_validation(node))
    None => None
  }
}

///|
/// The names of the nodes of the graph.
///
/// The returned array is a copy, so a caller may modify it without changing the
/// summary.
pub fn ValidationSummary::node_names(self : ValidationSummary) -> Array[String] {
  let names : Array[String] = []
  for name in self.nodes.keys() {
    names.push(name)
  }
  names
}

///|
/// The result of the false discovery rate control.
pub struct FdrControlResult {
  /// Whether every p-value was rejected.
  reject : Array[Bool]
  /// The p-value of every test after the control.
  adjusted_p_values : Array[Double]
}

///|
/// Whether every p-value was rejected.
pub fn FdrControlResult::reject(self : FdrControlResult) -> Array[Bool] {
  self.reject.copy()
}

///|
/// The p-value of every test after the control.
///
/// The returned array is a copy, so a caller may modify it without changing the
/// result.
pub fn FdrControlResult::adjusted_p_values(
  self : FdrControlResult,
) -> Array[Double] {
  self.adjusted_p_values.copy()
}

///|
/// The false discovery rate control of Benjamini and Hochberg.
///
/// This is the port of the `fdr_bh` method of
/// `statsmodels.stats.multitest.multipletests`. The p-values are sorted in
/// ascending order and the p-value of the rank `k` is compared with the factor
/// `(k + 1) / m` of the number `m` of the p-values. Every p-value up to the
/// largest rejected one is rejected, and the adjusted p-values are the
/// p-values divided by their factor, made monotone from the end and capped at
/// one.
///
/// The result holds the rejections and the adjusted p-values in the order of
/// the given p-values.
pub fn fdr_bh_adjust(
  p_values : Array[Double],
  alpha : Double,
) -> FdrControlResult {
  let m = p_values.length()
  if m == 0 {
    return { reject: [], adjusted_p_values: [], }
  }
  let order = sorted_indices(p_values)
  // The factor of every rank of the sorted p-values.
  let ecdffactor : Array[Double] = []
  for k in 0..<m {
    ecdffactor.push((k + 1).to_double() / m.to_double())
  }
  // The rejection of every rank of the sorted p-values.
  let reject_sorted : Array[Bool] = []
  for k in 0..<m {
    reject_sorted.push(p_values[order[k]] <= ecdffactor[k] * alpha)
  }
  // Every p-value up to the largest rejected one is rejected as well.
  let mut reject_max : Int32 = -1
  for k in 0..<m {
    if reject_sorted[k] {
      reject_max = k
    }
  }
  if reject_max >= 0 {
    for k in 0..<reject_max {
      reject_sorted[k] = true
    }
  }
  // The adjusted p-values of the sorted p-values: the minimum of the p-values
  // of the ranks from the rank itself to the last one, which is what
  // `numpy.minimum.accumulate` on the reversed array computes.
  let adjusted_sorted : Array[Double] = []
  for k in 0..<m {
    adjusted_sorted.push(p_values[order[k]] / ecdffactor[k])
  }
  let mut rank = m - 2
  while rank >= 0 {
    if adjusted_sorted[rank] > adjusted_sorted[rank + 1] {
      adjusted_sorted[rank] = adjusted_sorted[rank + 1]
    }
    rank = rank - 1
  }
  for k in 0..<m {
    if adjusted_sorted[k] > 1.0 {
      adjusted_sorted[k] = 1.0
    }
  }
  // The rank of every p-value in the sorted p-values.
  let ranks : Array[Int32] = []
  for _ in 0..<m {
    ranks.push(0)
  }
  for k in 0..<m {
    ranks[order[k]] = k
  }
  // The result in the order of the given p-values.
  let reject : Array[Bool] = []
  let adjusted_p_values : Array[Double] = []
  for i in 0..<m {
    reject.push(reject_sorted[ranks[i]])
    adjusted_p_values.push(adjusted_sorted[ranks[i]])
  }
  { reject, adjusted_p_values, }
}

///|
/// The indices of the p-values in ascending order.
///
/// The p-values that are equal keep the order they have in the given array, so
/// the result is deterministic.
fn sorted_indices(p_values : Array[Double]) -> Array[Int32] {
  let indices : Array[Int32] = []
  for i in 0..<p_values.length() {
    indices.push(i)
  }
  indices.sort_by(fn(a, b) {
    let order = @utils.compare_double(p_values[a], p_values[b])
    if order != 0 {
      order
    } else if a < b {
      -1
    } else if a > b {
      1
    } else {
      0
    }
  })
  indices
}

///|
/// The parents of a node, in the order the upstream uses.
///
/// The upstream sorts the parents of a node, because it selects the columns of
/// the parents by name and their order has to be well defined.
fn ordered_predecessors(
  causal_graph : @graph.DirectedGraph,
  node : String,
) -> Array[String] {
  let parents = causal_graph.predecessors(node)
  parents.sort_by(fn(a, b) { a.lexical_compare(b) })
  parents
}

///|
/// The non-descendants of a node, in the order of the graph.
///
/// The non-descendants are the nodes that are neither the node itself, nor a
/// descendant of it, nor one of its parents. The upstream builds the set in an
/// arbitrary order; the port uses the order of the graph.
fn non_descendants_of(
  causal_graph : @graph.DirectedGraph,
  node : String,
) -> Array[String] {
  let descendants = causal_graph.descendants(node)
  let parents = causal_graph.predecessors(node)
  let non_descendants : Array[String] = []
  for candidate in causal_graph.node_list() {
    if candidate == node {
      continue
    }
    if descendants.contains(candidate) {
      continue
    }
    if parents.contains(candidate) {
      continue
    }
    non_descendants.push(candidate)
  }
  non_descendants
}

///|
/// Validate the assumptions of a causal graph against the data.
///
/// This is the port of `dowhy.gcm.validation.refute_causal_structure`. At every
/// node of the graph the function tests whether the node is dependent on each
/// of its parents, and it tests the local Markov condition of the node. A
/// valid local Markov condition implies a valid global Markov condition.
///
/// The null hypothesis of the test of an edge is the independence of the parent
/// and of the node, so the edge succeeds when the parent and the node are found
/// to be dependent. The null hypothesis of the local Markov test is the
/// conditional independence of the node and of its non-descendants given its
/// parents, so the test succeeds when the null hypothesis is not rejected.
///
/// The result holds the outcome of the validation and the summary of the tests
/// of every node of the graph.
pub fn refute_causal_structure(
  causal_graph : @graph.DirectedGraph,
  data : @api.DataFrame,
  independence_test : IndependenceTest,
  conditional_independence_test : IndependenceTest,
  significance_level : Double,
  fdr_control_method : FdrControlMethod?,
) -> (RejectionResult, ValidationSummary) {
  let node_names = causal_graph.node_list()
  // The parents of every node, the p-value of the local Markov test of every
  // node and the p-value of every edge into every node, in the order of the
  // nodes of the graph.
  let parents_of : Array[Array[String]] = []
  let local_markov_p_values : Array[Double] = []
  let has_local_markov_test : Array[Bool] = []
  let edge_p_values : Array[Array[Double]] = []
  // The p-values of all the tests, in the order the upstream computes them.
  let all_p_values : Array[Double] = []
  for node in node_names {
    let parents = ordered_predecessors(causal_graph, node)
    let non_descendants = non_descendants_of(causal_graph, node)
    let has_test = parents.length() > 0 && non_descendants.length() > 0
    has_local_markov_test.push(has_test)
    if has_test {
      // The local Markov condition, whose null hypothesis is the conditional
      // independence of the node and of its non-descendants.
      let p_value = conditional_independence_test(
        data.design_matrix([node]),
        data.design_matrix(non_descendants),
        Some(data.design_matrix(parents)),
      )
      local_markov_p_values.push(p_value)
      all_p_values.push(p_value)
    } else {
      local_markov_p_values.push(0.0)
    }
    parents_of.push(parents)
    let p_values : Array[Double] = []
    for parent in parents {
      // The dependence of the edge, whose null hypothesis is the independence
      // of the parent and of the node.
      let p_value = independence_test(
        data.design_matrix([parent]),
        data.design_matrix([node]),
        None,
      )
      p_values.push(p_value)
      all_p_values.push(p_value)
    }
    edge_p_values.push(p_values)
  }
  // The false discovery rate control over all the p-values.
  let (rejected, adjusted_p_values) = match fdr_control_method {
    Some(FdrBh) => {
      let control = fdr_bh_adjust(all_p_values, significance_level)
      (control.reject(), control.adjusted_p_values())
    }
    None => {
      let rejected : Array[Bool] = []
      let adjusted_p_values : Array[Double] = []
      for p_value in all_p_values {
        rejected.push(p_value <= significance_level)
        adjusted_p_values.push(@utils.nan())
      }
      (rejected, adjusted_p_values)
    }
  }
  // The results of the tests, in the order the p-values were computed.
  let mut is_dag_valid = true
  let mut index = 0
  let nodes : Map[String, NodeValidation] = Map([])
  for i in 0..<node_names.length() {
    let node = node_names[i]
    let local_markov_test : LocalMarkovTest? = if has_local_markov_test[i] {
      let adjusted_p_value = adjusted_p_values[index]
      let success = !rejected[index]
      is_dag_valid = is_dag_valid && success
      index = index + 1
      Some({
        p_value: local_markov_p_values[i],
        fdr_adjusted_p_value: adjusted_p_value,
        success,
      })
    } else {
      None
    }
    let edge_dependence_test : Map[String, EdgeDependenceTest] = Map([])
    let parents = parents_of[i]
    for j in 0..<parents.length() {
      let success = rejected[index]
      is_dag_valid = is_dag_valid && success
      edge_dependence_test.set(parents[j], {
        p_value: edge_p_values[i][j],
        fdr_adjusted_p_value: adjusted_p_values[index],
        success,
      })
      index = index + 1
    }
    nodes.set(node, { local_markov_test, edge_dependence_test, })
  }
  let outcome = if is_dag_valid { NotRejected } else { Rejected }
  (outcome, { nodes, })
}

///|
/// Validate that the causal mechanisms of a model can be represented by an
/// invertible functional causal model.
///
/// This is the port of `dowhy.gcm.validation.refute_invertible_model`. The
/// residual of the causal mechanism of a node has to be independent of the
/// parents of the node, because the noise of the mechanism is assumed to be
/// independent of them.
///
/// The graph of the model has to be a directed acyclic graph, otherwise the
/// function aborts.
///
/// The result is the outcome of the validation. The model cannot be rejected
/// when all its causal mechanisms are consistent with the invertible model
/// assumption.
pub fn refute_invertible_model(
  causal_model : ProbabilisticCausalModel,
  data : @api.DataFrame,
  independence_test : IndependenceTest,
  significance_level : Double,
  fdr_control_method : FdrControlMethod?,
) -> RejectionResult {
  validate_causal_dag(causal_model)
  let all_p_values : Array[Double] = []
  for node in causal_model.graph.node_list() {
    if is_root_node(causal_model, node) {
      continue
    }
    let parents = ordered_predecessors(causal_model.graph, node)
    let parents_samples = data.design_matrix(parents)
    let mechanism = match causal_model.causal_mechanism(node) {
      Some(mechanism) => mechanism
      None =>
        abort(
          "the node " +
          node +
          " has parents and needs a causal mechanism, but it has none",
        )
    }
    let residuals = mechanism.estimate_noise(
      data.numeric(node),
      parents_samples,
    )
    let residual_samples = @utils.Matrix::from_columns([residuals])
    all_p_values.push(
      independence_test(parents_samples, residual_samples, None),
    )
  }
  match fdr_control_method {
    Some(FdrBh) => {
      if all_p_values.length() == 0 {
        return NotRejected
      }
      let control = fdr_bh_adjust(all_p_values, significance_level)
      for rejected in control.reject() {
        if rejected {
          return Rejected
        }
      }
      NotRejected
    }
    None => {
      for p_value in all_p_values {
        if p_value <= significance_level {
          return Rejected
        }
      }
      NotRejected
    }
  }
}
