///|
/// The falsification layer of the graphical causal models of the `gcm` package.
///
/// This is the port of `dowhy.gcm.falsify`. The upstream validates a causal
/// graph against the data with four methods and it falsifies a graph with a
/// permutation test.
///
/// The four validation methods are:
/// - the local Markov condition: a node is conditionally independent of its
///   non-descendants given its parents,
/// - the pairwise dependencies: a node is dependent on each of its ancestors,
/// - the parental d-separations: the d-separations that the graph implies are
///   d-separations of the reference graph as well,
/// - the causal minimality: a node is conditionally independent of each of its
///   parents given its other parents.
///
/// The falsification of a graph is a permutation test: the number of the
/// violations of the local Markov condition of a random permutation of the
/// nodes of the graph is the null distribution of the test. The graph is
/// falsified when it violates fewer local Markov conditions than the
/// permutations do, and it is falsifiable when it lies in a different Markov
/// equivalence class than almost all of the permutations.
///
/// The deviations from the upstream are the following ones.
///
/// The upstream takes two callables for the independence tests, one for the
/// marginal test and one for the conditional test. The port takes one callable
/// of the type `IndependenceTest` for both, because the test of the port takes
/// the conditioning variable as an optional third argument.
///
/// The upstream runs the tests of a validation in a process pool and draws the
/// randomness of the tests from the global generator of numpy. The port runs
/// the tests one after another and takes the generator it is given.
///
/// The upstream builds the set of the non-descendants of a node in an arbitrary
/// order; the port uses the order of the graph, which is deterministic.
///
/// The upstream chooses the pairs of the pairwise dependencies at random. The
/// port draws them from the generator it is given.
///
/// The upstream reports the results in dictionaries that are keyed by the
/// constants of its `FalsifyConst` enumeration. The port reports them in
/// structures, one for every validation.
///
/// The upstream encodes the data of its independence tests with a one-hot
/// encoder, so that a column that holds categories becomes one column per
/// category. The port encodes the data of the tests at the call site, the
/// way the other callers of the kernel based test of the package do it.
///
/// The plotting functions of the upstream are not ported: the port has no
/// plotting.

///|
/// The validation methods of the falsification layer.
///
/// This is the port of the `FalsifyConst` enumeration of the upstream, which
/// holds the keys of the dictionaries of its summaries. The port reports its
/// summaries in structures with named fields, so only the methods are left.
pub enum FalsifyConst {
  ValidateLmc
  ValidateTpa
  ValidatePd
  ValidateCm
}

///|
/// The name of the constant.
pub fn FalsifyConst::to_string(self : FalsifyConst) -> String {
  match self {
    ValidateLmc => "VALIDATE_LMC"
    ValidateTpa => "VALIDATE_TPA"
    ValidatePd => "VALIDATE_PD"
    ValidateCm => "VALIDATE_CM"
  }
}

///|
/// The name of the validation method, like the upstream names it in its
/// report.
pub fn FalsifyConst::method_name(self : FalsifyConst) -> String {
  match self {
    ValidateLmc => "LMC"
    ValidatePd => "Faithfulness"
    ValidateTpa => "TPa"
    ValidateCm => "Causal Minimality"
  }
}

///|
/// The memory of the p-values of the independence tests.
///
/// This is the port of the `_PValuesMemory` of the upstream. The memory is
/// useful when a graph is validated and its permuted nodes are validated as
/// well: the conditional independence of `X` and `Y` given `Z` is the same as
/// the conditional independence of `Y` and `X` given `Z`, so only one of the
/// two has to be computed.
///
/// The memory is keyed by the names of the nodes of the test, sorted, so that
/// the two orders of the same pair of nodes share one entry.
pub struct PValuesMemory {
  p_values : Map[String, Double?]
}

///|
/// An empty memory.
pub fn PValuesMemory::new() -> PValuesMemory {
  { p_values: Map([]), }
}

///|
/// The key of the entry of the test of X and Y given Z.
///
/// The two nodes are sorted, so that the test of X and Y and the test of Y and
/// X share one entry.
fn p_values_key(
  x : Array[String],
  y : Array[String],
  z : Array[String],
) -> String {
  let key_x = names_key(x)
  let key_y = names_key(y)
  let key_z = names_key(z)
  if key_x.lexical_compare(key_y) <= 0 {
    key_x + "\u{1}" + key_y + "\u{1}" + key_z
  } else {
    key_y + "\u{1}" + key_x + "\u{1}" + key_z
  }
}

///|
/// The key of a set of nodes: the names, sorted, joined by a comma.
fn names_key(names : Array[String]) -> String {
  let sorted = names.copy()
  sorted.sort_by(fn(a, b) { a.lexical_compare(b) })
  let mut out = ""
  for i in 0..<sorted.length() {
    if i > 0 {
      out = out + ","
    }
    out = out + sorted[i]
  }
  out
}

///|
/// Store the p-value of the test of X and Y given Z.
///
/// A p-value of `None` is the placeholder of the upstream: it marks a test
/// that was scheduled but whose result is not known yet.
pub fn PValuesMemory::add_p_value(
  self : PValuesMemory,
  p_value : Double?,
  x : Array[String],
  y : Array[String],
  z : Array[String],
) -> Unit {
  self.p_values.set(p_values_key(x, y, z), p_value)
}

///|
/// The p-value of the test of X and Y given Z.
///
/// Returns `None` when the test was not run and when its result is not known
/// yet.
pub fn PValuesMemory::get_p_value(
  self : PValuesMemory,
  x : Array[String],
  y : Array[String],
  z : Array[String],
) -> Double? {
  match self.p_values.get(p_values_key(x, y, z)) {
    Some(value) => value
    None => None
  }
}

///|
/// Whether the test of X and Y given Z was already run.
pub fn PValuesMemory::contains(
  self : PValuesMemory,
  x : Array[String],
  y : Array[String],
  z : Array[String],
) -> Bool {
  self.p_values.contains(p_values_key(x, y, z))
}

///|
/// The summary of the validation of the local Markov condition.
///
/// The p-values are keyed by the node and by the non-descendant it was tested
/// against. The flag of an entry says whether the test is a violation, that
/// is whether the p-value is at most the significance level.
pub struct LmcSummary {
  n_violations : Int32
  n_tests : Int32
  p_values : Map[(String, String), (Double, Bool)]
}

///|
/// The number of violations of the local Markov condition.
pub fn LmcSummary::n_violations(self : LmcSummary) -> Int32 {
  self.n_violations
}

///|
/// The number of tests of the local Markov condition.
pub fn LmcSummary::n_tests(self : LmcSummary) -> Int32 {
  self.n_tests
}

///|
/// The p-value of every test of the local Markov condition.
///
/// The returned map is a copy, so a caller may modify it without changing the
/// summary.
pub fn LmcSummary::p_values(
  self : LmcSummary,
) -> Map[(String, String), (Double, Bool)] {
  self.p_values.copy()
}

///|
/// The p-value of the test of the node against the non-descendant.
pub fn LmcSummary::p_value_of(
  self : LmcSummary,
  node : String,
  non_descendant : String,
) -> Double? {
  match self.p_values.get((node, non_descendant)) {
    Some((p_value, _)) => Some(p_value)
    None => None
  }
}

///|
/// The summary of the validation of the pairwise dependencies.
///
/// The p-values are keyed by the node and by the ancestor it was tested
/// against. The flag of an entry says whether the test is a violation, that
/// is whether the p-value is greater than the significance level: the node and
/// the ancestor were found to be independent, although the graph claims that
/// they are dependent.
pub struct PdSummary {
  n_violations : Int32
  n_tests : Int32
  p_values : Map[(String, String), (Double, Bool)]
}

///|
/// The number of violations of the pairwise dependencies.
pub fn PdSummary::n_violations(self : PdSummary) -> Int32 {
  self.n_violations
}

///|
/// The number of tests of the pairwise dependencies.
pub fn PdSummary::n_tests(self : PdSummary) -> Int32 {
  self.n_tests
}

///|
/// The p-value of every test of the pairwise dependencies.
///
/// The returned map is a copy, so a caller may modify it without changing the
/// summary.
pub fn PdSummary::p_values(
  self : PdSummary,
) -> Map[(String, String), (Double, Bool)] {
  self.p_values.copy()
}

///|
/// The p-value of the test of the node against the ancestor.
pub fn PdSummary::p_value_of(
  self : PdSummary,
  node : String,
  ancestor : String,
) -> Double? {
  match self.p_values.get((node, ancestor)) {
    Some((p_value, _)) => Some(p_value)
    None => None
  }
}

///|
/// The summary of the validation of the causal minimality.
///
/// The p-values are keyed by the node, by the parent it was tested against and
/// by the other parents of the node. The flag of an entry says whether the
/// test is a violation, that is whether the p-value is greater than the
/// significance level: the node and the parent were found to be independent
/// given the other parents, although the graph claims that the parent is a
/// cause of the node.
pub struct CmSummary {
  n_violations : Int32
  n_tests : Int32
  p_values : Map[(String, String, String), (Double, Bool)]
}

///|
/// The number of violations of the causal minimality.
pub fn CmSummary::n_violations(self : CmSummary) -> Int32 {
  self.n_violations
}

///|
/// The number of tests of the causal minimality.
pub fn CmSummary::n_tests(self : CmSummary) -> Int32 {
  self.n_tests
}

///|
/// The p-value of every test of the causal minimality.
///
/// The returned map is a copy, so a caller may modify it without changing the
/// summary.
pub fn CmSummary::p_values(
  self : CmSummary,
) -> Map[(String, String, String), (Double, Bool)] {
  self.p_values.copy()
}

///|
/// The p-value of the test of the node against the parent, given the other
/// parents.
pub fn CmSummary::p_value_of(
  self : CmSummary,
  node : String,
  parent : String,
  other_parents : Array[String],
) -> Double? {
  match self.p_values.get((node, parent, names_key(other_parents))) {
    Some((p_value, _)) => Some(p_value)
    None => None
  }
}

///|
/// The summary of the validation of the parental d-separations.
///
/// The method is a graphical one: it does not use the data at all, so it holds
/// no p-value.
pub struct TpaSummary {
  n_violations : Int32
  n_tests : Int32
}

///|
/// The number of violations of the parental d-separations.
pub fn TpaSummary::n_violations(self : TpaSummary) -> Int32 {
  self.n_violations
}

///|
/// The number of tests of the parental d-separations.
pub fn TpaSummary::n_tests(self : TpaSummary) -> Int32 {
  self.n_tests
}

///|
/// The summaries of the validation methods.
///
/// This is the port of the dictionary of the summaries that the upstream
/// returns. A method that was not run has no summary.
pub struct ValidationResults {
  lmc : LmcSummary?
  tpa : TpaSummary?
  pairwise : PdSummary?
  cm : CmSummary?
}

///|
/// The summary of the validation of the local Markov condition.
pub fn ValidationResults::local_markov_condition(
  self : ValidationResults,
) -> LmcSummary? {
  self.lmc
}

///|
/// The summary of the validation of the parental d-separations.
pub fn ValidationResults::parental_d_separations(
  self : ValidationResults,
) -> TpaSummary? {
  self.tpa
}

///|
/// The summary of the validation of the pairwise dependencies.
pub fn ValidationResults::pairwise_dependencies(
  self : ValidationResults,
) -> PdSummary? {
  self.pairwise
}

///|
/// The summary of the validation of the causal minimality.
pub fn ValidationResults::causal_minimality(
  self : ValidationResults,
) -> CmSummary? {
  self.cm
}

///|
/// A validation method of the falsification layer.
///
/// This is the port of the `partial` objects that the upstream builds around
/// its validation methods: the method, the independence tests and the
/// parameters of the method travel together.
pub struct ValidationMethod {
  kind : FalsifyConst
  independence_test : IndependenceTest
  conditional_independence_test : IndependenceTest
  significance_level : Double
  include_unconditional : Bool
  adjacent_only : Bool
  n_pairs : Int32
  causal_graph_reference : @graph.DirectedGraph?
  p_values_memory : PValuesMemory
  rng : @utils.Random
}

///|
/// The validation of the local Markov condition.
///
/// The method tests the conditional independence of a node and of each of its
/// non-descendants given its parents. The unconditional tests of the nodes
/// without a parent are included, like the upstream does by default.
pub fn ValidationMethod::local_markov_condition(
  independence_test : IndependenceTest,
  conditional_independence_test : IndependenceTest,
  significance_level : Double,
) -> ValidationMethod {
  {
    kind: ValidateLmc,
    independence_test,
    conditional_independence_test,
    significance_level,
    include_unconditional: true,
    adjacent_only: false,
    n_pairs: -1,
    causal_graph_reference: None,
    p_values_memory: PValuesMemory::new(),
    rng: @utils.Random::new(0UL),
  }
}

///|
/// The validation of the pairwise dependencies.
///
/// The method tests the dependence of a node and of each of its ancestors. All
/// the pairs are tested, like the upstream does by default.
pub fn ValidationMethod::pairwise_dependencies(
  independence_test : IndependenceTest,
  significance_level : Double,
) -> ValidationMethod {
  {
    kind: ValidatePd,
    independence_test,
    conditional_independence_test: independence_test,
    significance_level,
    include_unconditional: true,
    adjacent_only: false,
    n_pairs: -1,
    causal_graph_reference: None,
    p_values_memory: PValuesMemory::new(),
    rng: @utils.Random::new(0UL),
  }
}

///|
/// The validation of the parental d-separations.
///
/// The method tests whether the d-separations that the graph implies hold in
/// the reference graph as well. Two graphs that violate none of them lie in
/// the same Markov equivalence class.
pub fn ValidationMethod::parental_d_separations(
  causal_graph_reference : @graph.DirectedGraph,
) -> ValidationMethod {
  {
    kind: ValidateTpa,
    independence_test: fn(
      _x : @utils.Matrix,
      _y : @utils.Matrix,
      _z : @utils.Matrix?,
    ) -> Double {
      1.0
    },
    conditional_independence_test: fn(
      _x : @utils.Matrix,
      _y : @utils.Matrix,
      _z : @utils.Matrix?,
    ) -> Double {
      1.0
    },
    significance_level: 0.05,
    include_unconditional: true,
    adjacent_only: false,
    n_pairs: -1,
    causal_graph_reference: Some(causal_graph_reference),
    p_values_memory: PValuesMemory::new(),
    rng: @utils.Random::new(0UL),
  }
}

///|
/// The validation of the causal minimality.
///
/// The method tests the conditional independence of a node and of each of its
/// parents given its other parents.
pub fn ValidationMethod::causal_minimality(
  independence_test : IndependenceTest,
  conditional_independence_test : IndependenceTest,
  significance_level : Double,
) -> ValidationMethod {
  {
    kind: ValidateCm,
    independence_test,
    conditional_independence_test,
    significance_level,
    include_unconditional: true,
    adjacent_only: false,
    n_pairs: -1,
    causal_graph_reference: None,
    p_values_memory: PValuesMemory::new(),
    rng: @utils.Random::new(0UL),
  }
}

///|
/// A copy of the method that stores its p-values in the given memory.
///
/// The memory is shared with the other methods that use it, so that the tests
/// that were already run are not run again.
pub fn ValidationMethod::with_p_values_memory(
  self : ValidationMethod,
  p_values_memory : PValuesMemory,
) -> ValidationMethod {
  {
    kind: self.kind,
    independence_test: self.independence_test,
    conditional_independence_test: self.conditional_independence_test,
    significance_level: self.significance_level,
    include_unconditional: self.include_unconditional,
    adjacent_only: self.adjacent_only,
    n_pairs: self.n_pairs,
    causal_graph_reference: self.causal_graph_reference,
    p_values_memory,
    rng: self.rng,
  }
}

///|
/// A copy of the method that draws its randomness from the given generator.
pub fn ValidationMethod::with_random(
  self : ValidationMethod,
  rng : @utils.Random,
) -> ValidationMethod {
  {
    kind: self.kind,
    independence_test: self.independence_test,
    conditional_independence_test: self.conditional_independence_test,
    significance_level: self.significance_level,
    include_unconditional: self.include_unconditional,
    adjacent_only: self.adjacent_only,
    n_pairs: self.n_pairs,
    causal_graph_reference: self.causal_graph_reference,
    p_values_memory: self.p_values_memory,
    rng,
  }
}

///|
/// A copy of the method that tests only the adjacent nodes.
pub fn ValidationMethod::with_adjacent_only(
  self : ValidationMethod,
  adjacent_only : Bool,
) -> ValidationMethod {
  {
    kind: self.kind,
    independence_test: self.independence_test,
    conditional_independence_test: self.conditional_independence_test,
    significance_level: self.significance_level,
    include_unconditional: self.include_unconditional,
    adjacent_only,
    n_pairs: self.n_pairs,
    causal_graph_reference: self.causal_graph_reference,
    p_values_memory: self.p_values_memory,
    rng: self.rng,
  }
}

///|
/// A copy of the method that tests the given number of pairs.
pub fn ValidationMethod::with_n_pairs(
  self : ValidationMethod,
  n_pairs : Int32,
) -> ValidationMethod {
  {
    kind: self.kind,
    independence_test: self.independence_test,
    conditional_independence_test: self.conditional_independence_test,
    significance_level: self.significance_level,
    include_unconditional: self.include_unconditional,
    adjacent_only: self.adjacent_only,
    n_pairs,
    causal_graph_reference: self.causal_graph_reference,
    p_values_memory: self.p_values_memory,
    rng: self.rng,
  }
}

///|
/// A copy of the method that skips the unconditional tests.
pub fn ValidationMethod::with_unconditional(
  self : ValidationMethod,
  include_unconditional : Bool,
) -> ValidationMethod {
  {
    kind: self.kind,
    independence_test: self.independence_test,
    conditional_independence_test: self.conditional_independence_test,
    significance_level: self.significance_level,
    include_unconditional,
    adjacent_only: self.adjacent_only,
    n_pairs: self.n_pairs,
    causal_graph_reference: self.causal_graph_reference,
    p_values_memory: self.p_values_memory,
    rng: self.rng,
  }
}

///|
/// The parents of a node, in the order the upstream uses.
///
/// The upstream sorts the parents of a node, because it selects the columns
/// of the parents by name and their order has to be well defined.
fn falsify_parents_of(
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
fn falsify_non_descendants_of(
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
/// The parental triples of a graph.
///
/// The triple `(X, Y, Z)` is a parental triple when `Y` is a non-descendant of
/// `X` and `Z` are the parents of `X`. The parents are empty when the
/// unconditional tests are included and `X` has no parent.
fn parental_triples(
  causal_graph : @graph.DirectedGraph,
  include_unconditional : Bool,
) -> Array[(String, String, Array[String])] {
  let triples : Array[(String, String, Array[String])] = []
  for node in causal_graph.node_list() {
    let parents = falsify_parents_of(causal_graph, node)
    let non_descendants = falsify_non_descendants_of(causal_graph, node)
    if (parents.length() > 0 || include_unconditional) &&
      non_descendants.length() > 0 {
      for non_descendant in non_descendants {
        triples.push((node, non_descendant, parents.copy()))
      }
    }
  }
  triples
}

///|
/// The p-value of the independence test of X and Y given Z.
///
/// The marginal test is used when there is no conditioning variable, and the
/// conditional test otherwise, like the upstream.
///
/// Returns `None` when the data of one of the nodes is missing, like the
/// upstream, which skips such a test.
fn falsify_compute_p_value(
  data : @api.DataFrame,
  x : String,
  y : String,
  z : Array[String],
  independence_test : IndependenceTest,
  conditional_independence_test : IndependenceTest,
) -> Double? {
  if !data.has_column(x) || !data.has_column(y) {
    return None
  }
  for node in z {
    if !data.has_column(node) {
      return None
    }
  }
  if z.length() > 0 {
    Some(
      conditional_independence_test(
        falsify_design_matrix(data, [x]),
        falsify_design_matrix(data, [y]),
        Some(falsify_design_matrix(data, z)),
      ),
    )
  } else {
    Some(
      independence_test(
        falsify_design_matrix(data, [x]),
        falsify_design_matrix(data, [y]),
        None,
      ),
    )
  }
}

///|
/// The design matrix of the data of the given nodes.
///
/// A column that holds categories is encoded with the one-hot encoder, the
/// way the upstream encodes the data of its independence tests: the
/// categories of a column are in lexicographic order and every category
/// becomes a column of its own. The numeric columns keep their values.
fn falsify_design_matrix(
  data : @api.DataFrame,
  names : Array[String],
) -> @utils.Matrix {
  one_hot_encode_frame(data.select(names))
}

///|
/// Validate the local Markov condition of a graph against the data.
///
/// This is the port of `dowhy.gcm.falsify.validate_lmc`. The method tests the
/// conditional independence of a node and of each of its non-descendants given
/// its parents. A violation is a test whose p-value is at most the
/// significance level.
///
/// The tests that the memory already holds are not run again.
pub fn validate_lmc(
  causal_graph : @graph.DirectedGraph,
  data : @api.DataFrame,
  independence_test : IndependenceTest,
  conditional_independence_test : IndependenceTest,
  significance_level : Double,
  include_unconditional : Bool,
  p_values_memory : PValuesMemory,
) -> LmcSummary {
  let triples = parental_triples(causal_graph, include_unconditional)
  // The tests that are not in the memory yet.
  let to_test : Array[(String, String, Array[String])] = []
  for triple in triples {
    let (node, non_descendant, parents) = triple
    if !p_values_memory.contains([node], [non_descendant], parents) {
      to_test.push(triple)
      p_values_memory.add_p_value(None, [node], [non_descendant], parents)
    }
  }
  for triple in to_test {
    let (node, non_descendant, parents) = triple
    let p_value = falsify_compute_p_value(
      data, node, non_descendant, parents, independence_test, conditional_independence_test,
    )
    p_values_memory.add_p_value(p_value, [node], [non_descendant], parents)
  }
  // The summary of the tests.
  let mut n_violations = 0
  let mut n_tests = 0
  let p_values : Map[(String, String), (Double, Bool)] = Map([])
  for triple in triples {
    let (node, non_descendant, parents) = triple
    match p_values_memory.get_p_value([node], [non_descendant], parents) {
      Some(p_value) => {
        n_tests = n_tests + 1
        let violation = p_value <= significance_level
        p_values.set((node, non_descendant), (p_value, violation))
        if violation {
          n_violations = n_violations + 1
        }
      }
      None => ()
    }
  }
  { n_violations, n_tests, p_values, }
}

///|
/// Validate the pairwise dependencies of a graph against the data.
///
/// This is the port of `dowhy.gcm.falsify.validate_pd`. The method tests the
/// dependence of a node and of each of its ancestors. A violation is a test
/// whose p-value is greater than the significance level: the node and the
/// ancestor were found to be independent, although the graph claims that they
/// are dependent.
///
/// The number of the pairs that are tested is the number of the ancestors of
/// every node, unless the caller asks for fewer of them. The pairs are drawn
/// from the generator of the method, without replacement, like the upstream
/// draws them from the global generator of numpy.
pub fn validate_pd(
  causal_graph : @graph.DirectedGraph,
  data : @api.DataFrame,
  independence_test : IndependenceTest,
  significance_level : Double,
  n_pairs : Int32,
  adjacent_only : Bool,
  p_values_memory : PValuesMemory,
  rng : @utils.Random,
) -> PdSummary {
  // The pairs of an ancestor and of a node.
  let pairs : Array[(String, String)] = []
  for node in causal_graph.node_list() {
    for ancestor in causal_graph.ancestors(node).to_array() {
      if adjacent_only {
        let parents = falsify_parents_of(causal_graph, node)
        if !parents.contains(ancestor) {
          continue
        }
      }
      pairs.push((ancestor, node))
    }
  }
  let count = if n_pairs < 0 { pairs.length() } else { n_pairs }
  if count > pairs.length() {
    abort(
      "the number of the pairs (" +
      count.to_string() +
      ") is greater than the number of the pairs of the graph (" +
      pairs.length().to_string() +
      ")",
    )
  }
  // The pairs that are tested.
  let selected = select_pair_indices(pairs.length(), count, rng)
  let mut n_violations = 0
  let p_values : Map[(String, String), (Double, Bool)] = Map([])
  for index in selected {
    let (ancestor, node) = pairs[index]
    if !p_values_memory.contains([ancestor], [node], []) {
      p_values_memory.add_p_value(None, [ancestor], [node], [])
    }
  }
  for index in selected {
    let (ancestor, node) = pairs[index]
    let p_value = falsify_compute_p_value(
      data,
      ancestor,
      node,
      [],
      independence_test,
      independence_test,
    )
    p_values_memory.add_p_value(p_value, [ancestor], [node], [])
  }
  for index in selected {
    let (ancestor, node) = pairs[index]
    match p_values_memory.get_p_value([ancestor], [node], []) {
      Some(p_value) => {
        let violation = p_value > significance_level
        p_values.set((node, ancestor), (p_value, violation))
        if violation {
          n_violations = n_violations + 1
        }
      }
      None => ()
    }
  }
  { n_violations, n_tests: count, p_values, }
}

///|
/// The indices of the given number of the pairs, drawn without replacement.
///
/// The whole set is returned when the number of the pairs is the number of the
/// indices, which is the case of the default of the upstream.
fn select_pair_indices(
  length : Int32,
  count : Int32,
  rng : @utils.Random,
) -> Array[Int32] {
  let indices : Array[Int32] = []
  for i in 0..<length {
    indices.push(i)
  }
  if count >= length {
    return indices
  }
  // The Fisher-Yates shuffle of the first `count` indices.
  for i in 0..<count {
    let j = i + rng.next_int(length - i)
    let tmp = indices[i]
    indices[i] = indices[j]
    indices[j] = tmp
  }
  let selected : Array[Int32] = []
  for i in 0..<count {
    selected.push(indices[i])
  }
  selected
}

///|
/// Validate the causal minimality of a graph against the data.
///
/// This is the port of `dowhy.gcm.falsify.validate_cm`. The method tests the
/// conditional independence of a node and of each of its parents given its
/// other parents. A violation is a test whose p-value is greater than the
/// significance level: the node and the parent were found to be independent
/// given the other parents, although the graph claims that the parent is a
/// cause of the node.
///
/// The tests that the memory already holds are not run again.
pub fn validate_cm(
  causal_graph : @graph.DirectedGraph,
  data : @api.DataFrame,
  independence_test : IndependenceTest,
  conditional_independence_test : IndependenceTest,
  significance_level : Double,
  p_values_memory : PValuesMemory,
) -> CmSummary {
  // The triples of a node, of one of its parents and of its other parents.
  let triples : Array[(String, String, Array[String])] = []
  let to_test : Array[(String, String, Array[String])] = []
  for node in causal_graph.node_list() {
    let parents = causal_graph.predecessors(node)
    if parents.length() == 0 {
      continue
    }
    for parent in parents {
      let other_parents : Array[String] = []
      for other in parents {
        if other != parent {
          other_parents.push(other)
        }
      }
      let triple = (node, parent, other_parents)
      triples.push(triple)
      if !p_values_memory.contains([node], [parent], other_parents) {
        to_test.push(triple)
        p_values_memory.add_p_value(None, [node], [parent], other_parents)
      }
    }
  }
  for triple in to_test {
    let (node, parent, other_parents) = triple
    let p_value = falsify_compute_p_value(
      data, node, parent, other_parents, independence_test, conditional_independence_test,
    )
    p_values_memory.add_p_value(p_value, [node], [parent], other_parents)
  }
  let mut n_violations = 0
  let mut n_tests = 0
  let p_values : Map[(String, String, String), (Double, Bool)] = Map([])
  for triple in triples {
    let (node, parent, other_parents) = triple
    match p_values_memory.get_p_value([node], [parent], other_parents) {
      Some(p_value) => {
        n_tests = n_tests + 1
        let violation = p_value > significance_level
        p_values.set(
          (node, parent, names_key(other_parents)),
          (p_value, violation),
        )
        if violation {
          n_violations = n_violations + 1
        }
      }
      None => ()
    }
  }
  { n_violations, n_tests, p_values, }
}

///|
/// Validate the parental d-separations of a graph against a reference graph.
///
/// This is the port of `dowhy.gcm.falsify.validate_tpa`. The method tests,
/// for every parental triple of the graph, whether the d-separation that the
/// triple implies holds in the reference graph as well. Two graphs that
/// violate none of them lie in the same Markov equivalence class.
pub fn validate_tpa(
  causal_graph : @graph.DirectedGraph,
  causal_graph_reference : @graph.DirectedGraph,
  include_unconditional : Bool,
) -> TpaSummary {
  let triples = parental_triples(causal_graph, include_unconditional)
  let mut n_violations = 0
  let mut n_tests = 0
  for triple in triples {
    let (node, non_descendant, parents) = triple
    n_tests = n_tests + 1
    if !@graph.d_separated(
        causal_graph_reference,
        [node],
        [non_descendant],
        parents,
      ) {
      n_violations = n_violations + 1
    }
  }
  { n_violations, n_tests, }
}

///|
/// Run the given validation methods on a graph.
///
/// This is the port of `dowhy.gcm.falsify.run_validations`. The upstream binds
/// the data to the methods with a `partial` object; the port passes the data
/// and the methods separately.
pub fn run_validations(
  causal_graph : @graph.DirectedGraph,
  data : @api.DataFrame,
  methods : Array[ValidationMethod],
) -> ValidationResults {
  let mut lmc : LmcSummary? = None
  let mut tpa : TpaSummary? = None
  let mut pairwise : PdSummary? = None
  let mut cm : CmSummary? = None
  for validation in methods {
    match validation.kind {
      ValidateLmc =>
        lmc = Some(
          validate_lmc(
            causal_graph,
            data,
            validation.independence_test,
            validation.conditional_independence_test,
            validation.significance_level,
            validation.include_unconditional,
            validation.p_values_memory,
          ),
        )
      ValidateTpa => {
        let reference = match validation.causal_graph_reference {
          Some(graph) => graph
          None => causal_graph
        }
        tpa = Some(
          validate_tpa(
            causal_graph,
            reference,
            validation.include_unconditional,
          ),
        )
      }
      ValidatePd =>
        pairwise = Some(
          validate_pd(
            causal_graph,
            data,
            validation.independence_test,
            validation.significance_level,
            validation.n_pairs,
            validation.adjacent_only,
            validation.p_values_memory,
            validation.rng,
          ),
        )
      ValidateCm =>
        cm = Some(
          validate_cm(
            causal_graph,
            data,
            validation.independence_test,
            validation.conditional_independence_test,
            validation.significance_level,
            validation.p_values_memory,
          ),
        )
    }
  }
  { lmc, tpa, pairwise, cm, }
}

///|
/// The generator of the permutations of the nodes of a graph.
///
/// This is the port of the `_PermuteNodes` of the upstream. The permutation
/// keeps the structure of the graph and only renames its nodes, so that the
/// permuted graph has the same edges as the original one.
///
/// The upstream generates all the permutations of the nodes when the number of
/// the permutations is -1 or greater than the number of the permutations that
/// exist, and it draws them at random otherwise. The port does the same, but
/// it draws the random permutations from the generator it is given.
pub struct PermuteNodes {
  causal_graph : @graph.DirectedGraph
  exclude_original_order : Bool
  n_permutations : Int32
  max_perms : Int32
}

///|
/// The generator of the permutations of the nodes of the given graph.
pub fn PermuteNodes::new(
  causal_graph : @graph.DirectedGraph,
  exclude_original_order : Bool,
  n_permutations : Int32,
) -> PermuteNodes {
  let count = causal_graph.node_count()
  let max_perms = falsify_factorial(count) -
    (if exclude_original_order { 1 } else { 0 })
  { causal_graph, exclude_original_order, n_permutations, max_perms, }
}

///|
/// The number of the permutations the generator yields.
pub fn PermuteNodes::length(self : PermuteNodes) -> Int32 {
  if self.n_permutations == -1 || self.n_permutations > self.max_perms {
    self.max_perms
  } else {
    self.n_permutations
  }
}

///|
/// The permutations of the nodes of the graph.
///
/// The permutations are yielded in the order of the upstream when all of them
/// are used: the lexicographic order of the sequences of the indices of the
/// nodes. The random permutations are drawn from the generator that is given.
pub fn PermuteNodes::permutations(
  self : PermuteNodes,
  rng : @utils.Random,
) -> Array[@graph.DirectedGraph] {
  let nodes = self.causal_graph.node_list()
  let count = nodes.length()
  let out : Array[@graph.DirectedGraph] = []
  if self.n_permutations == -1 || self.n_permutations > self.max_perms {
    let orders = permutation_orders(count)
    for i in 0..<orders.length() {
      if self.exclude_original_order && i == 0 {
        continue
      }
      out.push(relabel_nodes(self.causal_graph, orders[i]))
    }
  } else {
    for _ in 0..<self.n_permutations {
      let mut order = random_order(count, rng)
      while self.exclude_original_order && is_original_order(order) {
        order = random_order(count, rng)
      }
      out.push(relabel_nodes(self.causal_graph, order))
    }
  }
  out
}

///|
/// The factorial of a number.
fn falsify_factorial(n : Int32) -> Int32 {
  let mut out = 1
  for i in 1..<=n {
    out = out * i
  }
  out
}

///|
/// All the orders of the given number of nodes.
///
/// The orders are the sequences of the indices of the nodes in the
/// lexicographic order, which is the order of the permutations of the upstream.
fn permutation_orders(count : Int32) -> Array[Array[Int32]] {
  let out : Array[Array[Int32]] = []
  let indices : Array[Int32] = []
  for i in 0..<count {
    indices.push(i)
  }
  let mut running = true
  while running {
    out.push(indices.copy())
    // The next sequence of the indices in the lexicographic order.
    let mut i = count - 2
    while i >= 0 && indices[i] >= indices[i + 1] {
      i = i - 1
    }
    if i < 0 {
      running = false
    } else {
      let mut j = count - 1
      while indices[j] <= indices[i] {
        j = j - 1
      }
      let tmp = indices[i]
      indices[i] = indices[j]
      indices[j] = tmp
      // The tail of the sequence is reversed.
      let mut low = i + 1
      let mut high = count - 1
      while low < high {
        let value = indices[low]
        indices[low] = indices[high]
        indices[high] = value
        low = low + 1
        high = high - 1
      }
    }
  }
  out
}

///|
/// A random order of the given number of nodes.
fn random_order(count : Int32, rng : @utils.Random) -> Array[Int32] {
  let indices : Array[Int32] = []
  for i in 0..<count {
    indices.push(i)
  }
  for i in 0..<count {
    let j = i + rng.next_int(count - i)
    let tmp = indices[i]
    indices[i] = indices[j]
    indices[j] = tmp
  }
  indices
}

///|
/// Whether the order is the order of the nodes themselves.
fn is_original_order(order : Array[Int32]) -> Bool {
  for i in 0..<order.length() {
    if order[i] != i {
      return false
    }
  }
  true
}

///|
/// The graph whose nodes are renamed after the given order.
///
/// The node at the position `i` of the graph takes the name of the node at the
/// position `order[i]` of the order, and the edges follow the names. The order
/// of the nodes of the result is the order of the nodes of the original graph.
fn relabel_nodes(
  causal_graph : @graph.DirectedGraph,
  order : Array[Int32],
) -> @graph.DirectedGraph {
  let names = causal_graph.node_list()
  let positions : Map[String, Int32] = Map([])
  for i in 0..<names.length() {
    positions.set(names[i], i)
  }
  // The new name of every node.
  let new_names : Array[String] = []
  for index in order {
    new_names.push(names[index])
  }
  let out = @graph.DirectedGraph::new()
  for index in order {
    out.add_node(names[index])
  }
  for (from, to) in causal_graph.edge_list() {
    out.add_edge(
      new_names[positions.get(from).unwrap_or(0)],
      new_names[positions.get(to).unwrap_or(0)],
    )
  }
  out
}

///|
/// The summary of one validation method of the falsification of a graph.
///
/// The summary holds the number of the violations of the method for the given
/// graph and for every permutation of its nodes, the fraction of the
/// violations of the permutations, and the p-value of the permutation test.
pub struct PermutationSummary {
  perm_violations : Array[Int32]
  given_violations : Int32
  n_tests : Int32
  f_perm_violations : Array[Double]
  f_given_violations : Double
  p_value : Double
}

///|
/// The number of the violations of the method for every permutation.
pub fn PermutationSummary::perm_violations(
  self : PermutationSummary,
) -> Array[Int32] {
  self.perm_violations.copy()
}

///|
/// The number of the violations of the method for the given graph.
pub fn PermutationSummary::given_violations(self : PermutationSummary) -> Int32 {
  self.given_violations
}

///|
/// The number of the tests of the method for the given graph.
pub fn PermutationSummary::n_tests(self : PermutationSummary) -> Int32 {
  self.n_tests
}

///|
/// The fraction of the violations of the method for every permutation.
pub fn PermutationSummary::f_perm_violations(
  self : PermutationSummary,
) -> Array[Double] {
  self.f_perm_violations.copy()
}

///|
/// The fraction of the violations of the method for the given graph.
pub fn PermutationSummary::f_given_violations(
  self : PermutationSummary,
) -> Double {
  self.f_given_violations
}

///|
/// The p-value of the permutation test.
pub fn PermutationSummary::p_value(self : PermutationSummary) -> Double {
  self.p_value
}

///|
/// The summary of the falsification of a graph.
///
/// The summary holds the summary of every validation method that was run, the
/// permuted graphs that lie in the same Markov equivalence class as the given
/// graph, and the summaries of the given graph itself.
pub struct FalsifySummary {
  lmc : PermutationSummary?
  tpa : PermutationSummary?
  pairwise : PermutationSummary?
  cm : PermutationSummary?
  mec : Array[@graph.DirectedGraph]
  given : ValidationResults
}

///|
/// The summary of the local Markov condition.
pub fn FalsifySummary::local_markov_condition(
  self : FalsifySummary,
) -> PermutationSummary? {
  self.lmc
}

///|
/// The summary of the parental d-separations.
pub fn FalsifySummary::parental_d_separations(
  self : FalsifySummary,
) -> PermutationSummary? {
  self.tpa
}

///|
/// The summary of the pairwise dependencies.
pub fn FalsifySummary::pairwise_dependencies(
  self : FalsifySummary,
) -> PermutationSummary? {
  self.pairwise
}

///|
/// The summary of the causal minimality.
pub fn FalsifySummary::causal_minimality(
  self : FalsifySummary,
) -> PermutationSummary? {
  self.cm
}

///|
/// The permuted graphs that lie in the same Markov equivalence class as the
/// given graph.
pub fn FalsifySummary::markov_equivalence_class(
  self : FalsifySummary,
) -> Array[@graph.DirectedGraph] {
  self.mec.copy()
}

///|
/// The summaries of the given graph.
pub fn FalsifySummary::given(self : FalsifySummary) -> ValidationResults {
  self.given
}

///|
/// The result of the falsification of a graph.
///
/// The result holds the summary of the falsification, the significance level of
/// the permutation test, the suggestions for the graph when they were asked
/// for, and the two decisions of the upstream: whether the graph is
/// falsifiable and whether it is falsified.
///
/// A graph that cannot be evaluated has neither of the two decisions: the
/// local Markov condition of the graph was not tested at all, because the
/// graph has no node with a parent and a non-descendant.
pub struct EvaluationResult {
  summary : FalsifySummary
  significance_level : Double
  suggestions : ValidationResults?
  can_evaluate : Bool
  falsified : Bool?
  falsifiable : Bool?
}

///|
/// The summary of the falsification.
pub fn EvaluationResult::summary(self : EvaluationResult) -> FalsifySummary {
  self.summary
}

///|
/// The significance level of the permutation test.
pub fn EvaluationResult::significance_level(self : EvaluationResult) -> Double {
  self.significance_level
}

///|
/// The suggestions for the graph, when they were asked for.
pub fn EvaluationResult::suggestions(
  self : EvaluationResult,
) -> ValidationResults? {
  self.suggestions
}

///|
/// Whether the graph could be evaluated at all.
pub fn EvaluationResult::can_evaluate(self : EvaluationResult) -> Bool {
  self.can_evaluate
}

///|
/// Whether the graph was falsified.
///
/// The value is absent when the graph could not be evaluated.
pub fn EvaluationResult::falsified(self : EvaluationResult) -> Bool? {
  self.falsified
}

///|
/// Whether the graph is falsifiable.
///
/// The value is absent when the graph could not be evaluated.
pub fn EvaluationResult::falsifiable(self : EvaluationResult) -> Bool? {
  self.falsifiable
}

///|
/// The report of the falsification of a graph.
///
/// This is the port of the `__repr__` of the `EvaluationResult` of the
/// upstream, which writes a table of the decision of the falsification and of
/// the suggestions for the graph.
///
/// The upstream writes the numbers of the table with two decimals and with one
/// decimal; the port writes them with the text of the number, which is the
/// shortest text that reads the number back.
pub fn EvaluationResult::to_string(self : EvaluationResult) -> String {
  let validation_lines : Array[String] = []
  if self.can_evaluate {
    let falsified = match self.falsified {
      Some(value) => value
      None => false
    }
    let falsifiable = match self.falsifiable {
      Some(value) => value
      None => false
    }
    let decision = if falsified { " " } else { " do not " }
    let informative = if falsifiable { " " } else { " not " }
    let lmc = self.summary.local_markov_condition()
    let tpa = self.summary.parental_d_separations()
    let given_violations = match lmc {
      Some(value) => value.given_violations()
      None => 0
    }
    let n_tests = match lmc {
      Some(value) => value.n_tests()
      None => 0
    }
    let p_lmc = match lmc {
      Some(value) => value.p_value()
      None => 0.0
    }
    let p_dsep = match tpa {
      Some(value) => value.p_value()
      None => 0.0
    }
    let n_permutations = match tpa {
      Some(value) => value.perm_violations().length()
      None => 0
    }
    let frac_mec = self.summary.markov_equivalence_class().length().to_string() +
      " / " +
      n_permutations.to_string()
    let frac_vlmc = given_violations.to_string() + "/" + n_tests.to_string()
    validation_lines.push(
      "The given DAG is" +
      informative +
      "informative because " +
      frac_mec +
      " of the permutations lie in the Markov",
    )
    validation_lines.push(
      "equivalence class of the given DAG (p-value: " +
      p_dsep.to_string() +
      ").",
    )
    validation_lines.push(
      "The given DAG violates " +
      frac_vlmc +
      " LMCs and is better than " +
      ((1.0 - p_lmc) * 100.0).to_string() +
      "% of the permuted DAGs (p-value: " +
      p_lmc.to_string() +
      ").",
    )
    validation_lines.push(
      "Based on the provided significance level (" +
      self.significance_level.to_string() +
      ") and because the DAG is" +
      informative +
      "informative,",
    )
    validation_lines.push("we" + decision + "reject the DAG.")
  } else {
    validation_lines.push("Cannot be evaluated!")
  }
  let suggestion_lines : Array[String] = []
  match self.suggestions {
    Some(suggestions) =>
      match suggestions.causal_minimality() {
        Some(summary) =>
          for entry in summary.p_values().keys() {
            let (node, parent, _) = entry
            let violation = match summary.p_values().get(entry) {
              Some((_, violated)) => violated
              None => false
            }
            if violation {
              suggestion_lines.push("Remove edge " + parent + " --> " + node)
            }
          }
        None => ()
      }
    None => ()
  }
  falsify_table(validation_lines, suggestion_lines)
}

///|
/// The table of the report of the falsification of a graph.
///
/// This is the port of the `_generate_table` of the upstream.
fn falsify_table(
  validation_lines : Array[String],
  suggestion_lines : Array[String],
) -> String {
  let width = 105
  let border = "+" + repeat_text("-", width - 2) + "+"
  let mut out = border +
    "\n" +
    "|" +
    centered_text("Falsification Summary", width - 2) +
    "|\n" +
    border +
    "\n"
  for line in validation_lines {
    out = out +
      "| " +
      line +
      repeat_text(" ", padding(width - 3 - line.length())) +
      "|\n"
  }
  out = out + border + "\n"
  if suggestion_lines.length() > 0 {
    out = out +
      "|" +
      centered_text("Suggestions", width - 2) +
      "|\n" +
      border +
      "\n"
    for line in suggestion_lines {
      out = out +
        "| " +
        line +
        repeat_text(" ", padding(width - 3 - line.length())) +
        "|\n"
    }
    out = out + border
  } else {
    out = out[0:out.length() - 1].to_owned()
  }
  out
}

///|
/// The number of the spaces that pad a line of the table.
fn padding(count : Int32) -> Int32 {
  if count < 0 {
    0
  } else {
    count
  }
}

///|
/// The text of the given number of times.
fn repeat_text(text : String, count : Int32) -> String {
  let mut out = ""
  for _ in 0..<count {
    out = out + text
  }
  out
}

///|
/// The text in the middle of the given width.
fn centered_text(text : String, width : Int32) -> String {
  let total = width - text.length()
  if total <= 0 {
    return text
  }
  let left = total / 2
  let right = total - left
  repeat_text(" ", left) + text + repeat_text(" ", right)
}

///|
/// A result of the falsification of a graph.
///
/// This is the port of the `EvaluationResult` of the upstream, whose
/// `__post_init__` computes the two decisions.
pub fn EvaluationResult::new(
  summary : FalsifySummary,
  significance_level : Double,
  suggestions : ValidationResults?,
) -> EvaluationResult {
  let can_evaluate = EvaluationResult::can_evaluate_summary(summary)
  let mut falsified : Bool? = None
  let mut falsifiable : Bool? = None
  if can_evaluate {
    let lmc = summary.lmc
    let tpa = summary.tpa
    let lmc_p_value = match lmc {
      Some(value) => value.p_value
      None => 0.0
    }
    let tpa_p_value = match tpa {
      Some(value) => value.p_value
      None => 0.0
    }
    if lmc_p_value > significance_level && significance_level > tpa_p_value {
      falsified = Some(true)
      falsifiable = Some(true)
    } else if significance_level < tpa_p_value {
      falsified = Some(false)
      falsifiable = Some(false)
    } else {
      falsified = Some(false)
      falsifiable = Some(true)
    }
  }
  {
    summary,
    significance_level,
    suggestions,
    can_evaluate,
    falsified,
    falsifiable,
  }
}

///|
/// Whether the summary holds enough tests for the graph to be evaluated.
fn EvaluationResult::can_evaluate_summary(summary : FalsifySummary) -> Bool {
  match summary.lmc {
    Some(lmc) => {
      if lmc.n_tests == 0 {
        return false
      }
      match summary.tpa {
        Some(_) => true
        None => false
      }
    }
    None => false
  }
}

///|
/// Whether the data holds a column for every node of the graph.
///
/// The upstream raises when the data is only available for a subset of the
/// nodes of the graph and the caller does not allow it. MoonBit has no
/// exceptions, so the check is public and the function that needs it aborts.
pub fn data_covers_graph(
  causal_graph : @graph.DirectedGraph,
  data : @api.DataFrame,
) -> Bool {
  for node in causal_graph.node_list() {
    if !data.has_column(node) {
      return false
    }
  }
  true
}

///|
/// Falsify a given graph with the data.
///
/// This is the port of `dowhy.gcm.falsify.falsify_graph`. The method runs the
/// validation of the local Markov condition and of the parental
/// d-separations on the given graph and on a number of permutations of its
/// nodes, and it compares the number of the violations of the given graph with
/// the number of the violations of the permutations.
///
/// The graph is falsifiable when it lies in a different Markov equivalence
/// class than almost all of the permutations, and it is falsified when it
/// violates fewer local Markov conditions than almost all of the
/// permutations.
///
/// The number of the permutations is the inverse of the significance level,
/// when the caller does not give one. The number -1 stands for all the
/// permutations of the nodes of the graph.
///
/// The suggestions are the violations of the causal minimality of the graph,
/// which the method computes when the caller asks for them.
pub fn falsify_graph(
  causal_graph : @graph.DirectedGraph,
  data : @api.DataFrame,
  independence_test : IndependenceTest,
  conditional_independence_test : IndependenceTest,
  significance_level : Double,
  significance_ci : Double,
  n_permutations : Int32?,
  suggestions : Bool,
  rng : @utils.Random,
  allow_data_subset : Bool,
) -> EvaluationResult {
  if !allow_data_subset {
    if !data_covers_graph(causal_graph, data) {
      abort(
        "Did not find data for all nodes of the given graph! Make sure that the node names coincide with the column names in the data.",
      )
    }
  }
  let permutations = match n_permutations {
    Some(count) => count
    None => (1.0 / significance_level).to_int()
  }
  // The memory of the p-values is shared by the given graph and by the
  // permutations, so that a test that was already run is not run again.
  let memory = PValuesMemory::new()
  let lmc_method = ValidationMethod::local_markov_condition(
      independence_test, conditional_independence_test, significance_ci,
    )
    .with_p_values_memory(memory)
    .with_random(rng)
  let tpa_method = ValidationMethod::parental_d_separations(causal_graph).with_random(
    rng,
  )
  let methods = [lmc_method, tpa_method]
  let suggestion_methods = if suggestions {
    [
      ValidationMethod::causal_minimality(
        independence_test, conditional_independence_test, significance_ci,
      )
      .with_p_values_memory(memory)
      .with_random(rng),
    ]
  } else {
    []
  }
  let given = run_validations(causal_graph, data, methods + suggestion_methods)
  let (permuted_graphs, permutation_results) = permutation_based(
    causal_graph, data, methods, false, permutations, rng,
  )
  // The summary of every method that was run on the permutations.
  let mut lmc : PermutationSummary? = None
  let mut tpa : PermutationSummary? = None
  for validation in methods {
    match validation.kind {
      ValidateLmc =>
        lmc = Some(permutation_summary(given, permutation_results, ValidateLmc))
      ValidateTpa =>
        tpa = Some(permutation_summary(given, permutation_results, ValidateTpa))
      _ => ()
    }
  }
  // The permutations that lie in the same Markov equivalence class as the
  // given graph.
  let mec : Array[@graph.DirectedGraph] = []
  for i in 0..<permutation_results.length() {
    let numbers = method_numbers(permutation_results[i], ValidateTpa)
    if numbers.violations == 0 {
      mec.push(permuted_graphs[i])
    }
  }
  let summary = { lmc, tpa, pairwise: None, cm: None, mec, given, }
  let suggestion_results = if suggestions { Some(given) } else { None }
  EvaluationResult::new(summary, significance_level, suggestion_results)
}

///|
/// The summary of one method of the given graph and of the permutations.
fn permutation_summary(
  given : ValidationResults,
  permutation_results : Array[ValidationResults],
  validation : FalsifyConst,
) -> PermutationSummary {
  let given_numbers = method_numbers(given, validation)
  let perm_violations : Array[Int32] = []
  let f_perm_violations : Array[Double] = []
  for result in permutation_results {
    let numbers = method_numbers(result, validation)
    perm_violations.push(numbers.violations)
    let denominator = if numbers.tests > 1 { numbers.tests } else { 1 }
    f_perm_violations.push(
      numbers.violations.to_double() / denominator.to_double(),
    )
  }
  let denominator = if given_numbers.tests > 1 {
    given_numbers.tests
  } else {
    1
  }
  let f_given_violations = given_numbers.violations.to_double() /
    denominator.to_double()
  let mut count = 0
  for fraction in f_perm_violations {
    if fraction <= f_given_violations {
      count = count + 1
    }
  }
  let p_value = if f_perm_violations.length() == 0 {
    0.0
  } else {
    count.to_double() / f_perm_violations.length().to_double()
  }
  {
    perm_violations,
    given_violations: given_numbers.violations,
    n_tests: given_numbers.tests,
    f_perm_violations,
    f_given_violations,
    p_value,
  }
}

///|
/// The number of the violations and the number of the tests of one validation.
priv struct MethodNumbers {
  violations : Int32
  tests : Int32
}

///|
/// The number of the violations and the number of the tests of one validation.
fn method_numbers(
  results : ValidationResults,
  validation : FalsifyConst,
) -> MethodNumbers {
  match validation {
    ValidateLmc =>
      match results.lmc {
        Some(summary) =>
          { violations: summary.n_violations, tests: summary.n_tests, }
        None => { violations: 0, tests: 0, }
      }
    ValidateTpa =>
      match results.tpa {
        Some(summary) =>
          { violations: summary.n_violations, tests: summary.n_tests, }
        None => { violations: 0, tests: 0, }
      }
    ValidatePd =>
      match results.pairwise {
        Some(summary) =>
          { violations: summary.n_violations, tests: summary.n_tests, }
        None => { violations: 0, tests: 0, }
      }
    ValidateCm =>
      match results.cm {
        Some(summary) =>
          { violations: summary.n_violations, tests: summary.n_tests, }
        None => { violations: 0, tests: 0, }
      }
  }
}

///|
/// The results of the validations of the permutations of the nodes of a graph.
///
/// The result holds the permuted graphs and the summaries of the validations
/// of every one of them.
fn permutation_based(
  causal_graph : @graph.DirectedGraph,
  data : @api.DataFrame,
  methods : Array[ValidationMethod],
  exclude_original_order : Bool,
  n_permutations : Int32,
  rng : @utils.Random,
) -> (Array[@graph.DirectedGraph], Array[ValidationResults]) {
  let generator = PermuteNodes::new(
    causal_graph, exclude_original_order, n_permutations,
  )
  let graphs = generator.permutations(rng)
  let results : Array[ValidationResults] = []
  for graph in graphs {
    results.push(run_validations(graph, data, methods))
  }
  (graphs, results)
}

///|
/// Apply the suggestions of a falsification to a graph.
///
/// This is the port of `dowhy.gcm.falsify.apply_suggestions`. The edges whose
/// causal minimality was violated are removed from the graph, and the graph
/// that is returned is a copy of the given one.
///
/// The edges of the `edges_to_keep` list are not removed, when the list is
/// given.
pub fn apply_suggestions(
  causal_graph : @graph.DirectedGraph,
  evaluation_result : EvaluationResult,
  edges_to_keep : Array[(String, String)]?,
) -> @graph.DirectedGraph {
  let graph = causal_graph.copy()
  match evaluation_result.suggestions {
    Some(suggestions) =>
      match suggestions.cm {
        Some(summary) =>
          for key in summary.p_values.keys() {
            let entry = summary.p_values.get(key)
            match entry {
              Some((_, violation)) =>
                if violation {
                  let parent = key.1
                  let node = key.0
                  let keep = match edges_to_keep {
                    Some(kept) => kept.contains((parent, node))
                    None => false
                  }
                  if !keep {
                    graph.remove_edge(parent, node)
                  }
                }
              None => ()
            }
          }
        None => ()
      }
    None => ()
  }
  graph
}
