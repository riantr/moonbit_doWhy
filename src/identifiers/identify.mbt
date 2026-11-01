/// The identification of a causal effect from a causal graph.
///
/// This is the port of `dowhy.causal_identifier.auto_identifier`: the
/// backdoor search of `identify_backdoor`, the frontdoor search of
/// `identify_frontdoor`, the complete adjustment search of
/// `identify_generalized_adjustment_set` and the estimand registry that
/// `identify_effect_auto` builds.
///
/// Two deliberate differences to the Python code are documented where they
/// occur: the candidate sets are enumerated in sorted order (the Python code
/// iterates over a `set`, so its order is hash dependent) and the frontdoor
/// search returns the smallest valid set instead of the largest one.

///|
/// The adjustment set that an identifier found.
///
/// This is the port of `dowhy.causal_identifier.adjustment_set.AdjustmentSet`.
pub struct AdjustmentSet {
  adjustment_type : String
  adjustment_variables : Array[String]
}

///|
/// A new adjustment set of the given type.
pub fn AdjustmentSet::new(
  adjustment_type : String,
  adjustment_variables : Array[String],
) -> AdjustmentSet {
  { adjustment_type, adjustment_variables, }
}

///|
/// The technique the adjustment set belongs to, `"backdoor"` or `"general"`.
pub fn AdjustmentSet::adjustment_type(self : AdjustmentSet) -> String {
  self.adjustment_type
}

///|
/// The variables of the adjustment set.
pub fn AdjustmentSet::adjustment_variables(
  self : AdjustmentSet,
) -> Array[String] {
  self.adjustment_variables.copy()
}

///|
/// The default backdoor strategy: the maximal and the minimal set.
pub const BACKDOOR_DEFAULT : String = "default"

///|
/// The exhaustive backdoor strategy: every valid set.
pub const BACKDOOR_EXHAUSTIVE : String = "exhaustive-search"

///|
/// The minimal backdoor strategy: the smallest valid set.
pub const BACKDOOR_MIN : String = "minimal-adjustment"

///|
/// The maximal backdoor strategy: the largest valid set.
pub const BACKDOOR_MAX : String = "maximal-adjustment"

///|
/// The efficient backdoor strategy of Smucler, Sapienza and Rotnitzky.
pub const BACKDOOR_EFFICIENT : String = "efficient-adjustment"

///|
/// The efficient minimal backdoor strategy.
pub const BACKDOOR_MIN_EFFICIENT : String = "efficient-minimal-adjustment"

///|
/// The efficient minimum cost backdoor strategy.
pub const BACKDOOR_MINCOST_EFFICIENT : String = "efficient-mincost-adjustment"

///|
/// The number of candidate sets the exhaustive search looks at before it
/// gives up, like `MAX_BACKDOOR_ITERATIONS` of the Python code.
const MAX_BACKDOOR_ITERATIONS : Int32 = 100000

///|
/// Whether the given name is one of the backdoor strategies of the upstream.
///
/// The strategies are the default, the exhaustive, the minimal and the maximal
/// backdoor search and the three efficient backdoor searches of Smucler,
/// Sapienza and Rotnitzky.
pub fn is_backdoor_strategy(backdoor_adjustment : String) -> Bool {
  backdoor_adjustment == BACKDOOR_DEFAULT ||
  backdoor_adjustment == BACKDOOR_EXHAUSTIVE ||
  backdoor_adjustment == BACKDOOR_MIN ||
  backdoor_adjustment == BACKDOOR_MAX ||
  backdoor_adjustment == BACKDOOR_EFFICIENT ||
  backdoor_adjustment == BACKDOOR_MIN_EFFICIENT ||
  backdoor_adjustment == BACKDOOR_MINCOST_EFFICIENT
}

///|
/// The error message of a backdoor strategy, or an empty string when the
/// strategy is supported.
///
/// The upstream raises an error for a strategy it does not know, and the port
/// reports the message instead of raising it.
pub fn backdoor_adjustment_error(backdoor_adjustment : String) -> String {
  if is_backdoor_strategy(backdoor_adjustment) {
    ""
  } else {
    "the backdoor strategy " + backdoor_adjustment + " is not supported"
  }
}

///|
/// Whether the strategy is one of the three efficient backdoor searches.
pub fn is_efficient_backdoor_strategy(backdoor_adjustment : String) -> Bool {
  backdoor_adjustment == BACKDOOR_EFFICIENT ||
  backdoor_adjustment == BACKDOOR_MIN_EFFICIENT ||
  backdoor_adjustment == BACKDOOR_MINCOST_EFFICIENT
}

///|
/// The backdoor adjustment sets of the graph.
///
/// The first component holds the adjustment sets, the second one an error
/// message that is empty when the search succeeded.
///
/// The three efficient strategies are the searches of Smucler, Sapienza and
/// Rotnitzky; they return one adjustment set, or an error message when no
/// adjustment set of the observable variables exists. The `costs` are the
/// costs of the variables of the minimum cost strategy; an empty list means
/// that every variable costs one, the way the upstream assumes it when no
/// costs are given. The `conditional_node_names` are the variables that
/// determine the treatment.
///
/// The `optimize_backdoor` flag replaces the search with the optimized search
/// of the upstream, which walks the backdoor paths and finds a small set of
/// variables that blocks all of them.
///
/// The candidate sets are enumerated in sorted order. The Python code
/// iterates over a `set` of variables, so the order in which it finds the
/// valid sets depends on the hash of the variable names and changes between
/// runs; the sorted order makes the result reproducible.
pub fn identify_backdoor(
  graph : @graph.DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
  observed_nodes : Array[String],
  backdoor_adjustment : String,
  direct_effect~ : Bool = false,
  costs~ : Array[(String, Double)] = [],
  conditional_node_names~ : Array[String] = [],
  optimize_backdoor~ : Bool = false,
) -> (Array[AdjustmentSet], String) {
  let message = backdoor_adjustment_error(backdoor_adjustment)
  if message != "" {
    return ([], message)
  }
  if optimize_backdoor {
    let sets = optimized_backdoor_adjustment(graph, action_nodes, outcome_nodes)
    return (sets, "")
  }
  if is_efficient_backdoor_strategy(backdoor_adjustment) {
    let (values, error) = efficient_backdoor_sets(
      backdoor_adjustment, graph, action_nodes, outcome_nodes, observed_nodes, conditional_node_names,
      costs,
    )
    if error != "" {
      return ([], error)
    }
    let sets : Array[AdjustmentSet] = []
    sets.push(AdjustmentSet::new("backdoor", values))
    return (sets, "")
  }
  let sets = search_backdoor(
    graph, action_nodes, outcome_nodes, observed_nodes, backdoor_adjustment, direct_effect,
  )
  (sets, "")
}

///|
/// The adjustment set of the given efficient backdoor strategy.
fn efficient_backdoor_sets(
  backdoor_adjustment : String,
  graph : @graph.DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
  observed_nodes : Array[String],
  conditional_node_names : Array[String],
  costs : Array[(String, Double)],
) -> (Array[String], String) {
  if backdoor_adjustment == BACKDOOR_EFFICIENT {
    efficient_backdoor_adjustment(
      graph, action_nodes, outcome_nodes, observed_nodes, conditional_node_names,
      costs,
    )
  } else if backdoor_adjustment == BACKDOOR_MIN_EFFICIENT {
    efficient_backdoor_minimal_adjustment(
      graph, action_nodes, outcome_nodes, observed_nodes, conditional_node_names,
      costs,
    )
  } else {
    efficient_backdoor_mincost_adjustment(
      graph, action_nodes, outcome_nodes, observed_nodes, conditional_node_names,
      costs,
    )
  }
}

///|
/// The backdoor adjustment sets of the graph.
fn search_backdoor(
  graph : @graph.DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
  observed_nodes : Array[String],
  backdoor_adjustment : String,
  direct_effect : Bool,
) -> Array[AdjustmentSet] {
  let backdoor_sets : Array[AdjustmentSet] = []
  // The graph on which the backdoor criterion is checked: the outgoing edges
  // of the treatment are removed, so that only the backdoor paths are left.
  let bdoor_graph = @graph.do_surgery(
    graph, action_nodes, true, false, outcome_nodes, direct_effect,
  )
  // The empty set is a valid backdoor set when the treatment and the outcome
  // are d-separated without conditioning on anything.
  if @graph.d_separated(bdoor_graph, action_nodes, outcome_nodes, []) {
    backdoor_sets.push(AdjustmentSet::new("backdoor", []))
    // The minimal strategy stops at the empty set.
    if backdoor_adjustment == BACKDOOR_MIN {
      return backdoor_sets
    }
  }
  let eligible = eligible_backdoor_variables(
    graph, action_nodes, outcome_nodes, observed_nodes, direct_effect,
  )
  let found = find_valid_adjustment_sets(
    graph, bdoor_graph, action_nodes, outcome_nodes, observed_nodes, eligible, backdoor_adjustment,
    backdoor_sets,
  )
  // The default strategy reports the maximal sets and the minimal sets.
  if backdoor_adjustment == BACKDOOR_DEFAULT && found {
    let _ = find_valid_adjustment_sets(
      graph,
      bdoor_graph,
      action_nodes,
      outcome_nodes,
      observed_nodes,
      eligible,
      BACKDOOR_MIN,
      backdoor_sets,
    )
  }
  backdoor_sets
}

///|
/// The variables that may take part in a backdoor set.
///
/// The eligible variables are the observed variables of the graph without the
/// treatment, without the outcome and without the descendants of the
/// treatment. A variable that is d-separated from both the treatment and the
/// outcome cannot block a backdoor path and is dropped as well.
fn eligible_backdoor_variables(
  graph : @graph.DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
  observed_nodes : Array[String],
  direct_effect : Bool,
) -> Array[String] {
  let excluded : Set[String] = Set::Set([])
  for node in action_nodes {
    excluded.add(node)
  }
  for node in outcome_nodes {
    excluded.add(node)
  }
  // The direct effect only drops the descendants of the outcome, the total
  // effect the descendants of the treatment.
  let descendants = if direct_effect {
    graph.descendants_of(outcome_nodes)
  } else {
    graph.descendants_of(action_nodes)
  }
  for node in descendants.to_array() {
    excluded.add(node)
  }
  let eligible : Array[String] = []
  for node in graph.node_list() {
    if !observed_nodes.contains(node) {
      continue
    }
    if excluded.contains(node) {
      continue
    }
    eligible.push(node)
  }
  let filtered : Array[String] = []
  for node in eligible {
    let dsep_treatment = @graph.d_separated(graph, action_nodes, [node], [])
    let dsep_outcome = @graph.d_separated(graph, outcome_nodes, [node], [])
    if !dsep_treatment || !dsep_outcome {
      filtered.push(node)
    }
  }
  sorted_unique(filtered)
}

///|
/// The candidate sets of the given size that satisfy the backdoor criterion.
///
/// The sets are appended to `backdoor_sets`; the result tells whether a
/// valid set was found.
fn find_valid_adjustment_sets(
  graph : @graph.DirectedGraph,
  bdoor_graph : @graph.DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
  observed_nodes : Array[String],
  eligible : Array[String],
  backdoor_adjustment : String,
  backdoor_sets : Array[AdjustmentSet],
) -> Bool {
  let count = eligible.length()
  let all_observed = every_node_observed(graph, observed_nodes)
  let mut found = false
  let mut iterations = 0
  // The minimal strategy starts with the smallest set, the other strategies
  // with the largest one.
  let ascending = backdoor_adjustment == BACKDOOR_MIN
  let mut size = if ascending { 1 } else { count }
  while size >= 1 && size <= count {
    for candidate in combinations(eligible, size) {
      iterations = iterations + 1
      if @graph.d_separated(bdoor_graph, action_nodes, outcome_nodes, candidate) {
        backdoor_sets.push(AdjustmentSet::new("backdoor", candidate))
        found = true
      }
      if backdoor_adjustment == BACKDOOR_EXHAUSTIVE &&
        iterations > MAX_BACKDOOR_ITERATIONS {
        break
      }
    }
    // The maximal and the minimal strategy stop at the first size that has a
    // valid set.
    if found &&
      (
        backdoor_adjustment == BACKDOOR_DEFAULT ||
        backdoor_adjustment == BACKDOOR_MAX ||
        backdoor_adjustment == BACKDOOR_MIN
      ) {
      break
    }
    // When every variable is observed the largest eligible set blocks all
    // the backdoor paths or none of its subsets does.
    if all_observed &&
      (
        backdoor_adjustment == BACKDOOR_DEFAULT ||
        backdoor_adjustment == BACKDOOR_MAX
      ) {
      break
    }
    if iterations > MAX_BACKDOOR_ITERATIONS {
      break
    }
    size = if ascending { size + 1 } else { size - 1 }
  }
  found
}

///|
/// The frontdoor variables of the graph.
///
/// The result is the smallest set that satisfies the three conditions of the
/// frontdoor criterion; it is empty when no such set exists. The Python code
/// keeps the last set it finds, which is the largest one because of the
/// `break` that only leaves the inner loop; the smallest set is the one the
/// frontdoor criterion asks for.
pub fn identify_frontdoor(
  graph : @graph.DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
  observed_nodes : Array[String],
) -> Array[String] {
  // The graph without the incoming edges of the treatment; on that graph a
  // directed path from the treatment to the outcome is a path that the
  // candidate set has to intercept.
  let cond1_graph = @graph.do_surgery(
    graph,
    action_nodes,
    false,
    true,
    [],
    false,
  )
  let excluded : Set[String] = Set::Set([])
  for node in action_nodes {
    excluded.add(node)
  }
  for node in outcome_nodes {
    excluded.add(node)
  }
  for node in graph.descendants_of(outcome_nodes).to_array() {
    excluded.add(node)
  }
  // The eligible variables are the descendants of the treatment that are
  // observed and that are neither the treatment, the outcome nor a
  // descendant of the outcome.
  let eligible : Array[String] = []
  for node in graph.descendants_of(action_nodes).to_array() {
    if excluded.contains(node) {
      continue
    }
    if !observed_nodes.contains(node) {
      continue
    }
    eligible.push(node)
  }
  let eligible = sorted_unique(eligible)
  let count = eligible.length()
  let mut size = 1
  while size <= count {
    for candidate in combinations(eligible, size) {
      if is_valid_frontdoor(
          graph, cond1_graph, action_nodes, outcome_nodes, candidate,
        ) {
        return candidate
      }
    }
    size = size + 1
  }
  []
}

///|
/// Whether the candidate set satisfies the three frontdoor conditions.
fn is_valid_frontdoor(
  graph : @graph.DirectedGraph,
  cond1_graph : @graph.DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
  candidate : Array[String],
) -> Bool {
  // Condition 1: the candidate intercepts every directed path from the
  // treatment to the outcome.
  if !@graph.d_separated(cond1_graph, action_nodes, outcome_nodes, candidate) {
    return false
  }
  // Condition 2: no unblocked backdoor path from the treatment to the
  // candidate.
  let cond2_graph = @graph.do_surgery(
    graph,
    action_nodes,
    true,
    false,
    [],
    false,
  )
  if !@graph.d_separated(cond2_graph, action_nodes, candidate, []) {
    return false
  }
  // Condition 3: the treatment blocks every backdoor path from the
  // candidate to the outcome.
  let cond3_graph = @graph.do_surgery(graph, candidate, true, false, [], false)
  if !@graph.d_separated(cond3_graph, candidate, outcome_nodes, action_nodes) {
    return false
  }
  true
}

///|
/// The adjustment set of the complete adjustment criterion.
///
/// The complete criterion of Shpitser et al. finds an adjustment set that is
/// not a backdoor set. The set is a minimal d-separator of the treatment and
/// the outcome in the proper backdoor graph, restricted to the observed
/// variables that are not descendants of a proper causal path node.
pub fn identify_generalized_adjustment_set(
  graph : @graph.DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
  observed_nodes : Array[String],
) -> Array[AdjustmentSet] {
  let graph_pbd = @graph.get_proper_backdoor_graph(
    graph, action_nodes, outcome_nodes,
  )
  let pcp_nodes = @graph.get_proper_causal_path_nodes(
    graph, action_nodes, outcome_nodes,
  )
  // The descendants of the proper causal path nodes may not be part of the
  // adjustment set.
  let excluded : Set[String] = pcp_nodes.copy()
  for node in graph.descendants_of(pcp_nodes.to_array()).to_array() {
    excluded.add(node)
  }
  let restricted : Array[String] = []
  for node in graph_pbd.node_list() {
    if excluded.contains(node) {
      continue
    }
    if !observed_nodes.contains(node) {
      continue
    }
    restricted.push(node)
  }
  match
    find_minimal_d_separator(graph_pbd, action_nodes, outcome_nodes, restricted) {
    Some(separator) => [AdjustmentSet::new("general", separator)]
    None => []
  }
}

///|
/// A minimal d-separator of the two node sets, or `None` when no separator
/// exists.
///
/// This is the port of `networkx.algorithms.find_minimal_d_separator`, which
/// implements the linear time algorithm of van der Zander and Liśkiewicz.
fn find_minimal_d_separator(
  graph : @graph.DirectedGraph,
  x : Array[String],
  y : Array[String],
  restricted : Array[String],
) -> Array[String]? {
  let nodeset = x + y
  // The ancestors of the two node sets; the separator is searched in that
  // part of the graph only.
  let ancestors : Set[String] = Set::Set([])
  for node in nodeset {
    ancestors.add(node)
    for ancestor in graph.ancestors(node).to_array() {
      ancestors.add(ancestor)
    }
  }
  let restricted_set : Set[String] = Set::Set([])
  for node in restricted {
    restricted_set.add(node)
  }
  // The candidates are the restricted nodes that are ancestors of the two
  // node sets.
  let z_init : Set[String] = Set::Set([])
  for node in restricted_set.to_array() {
    if ancestors.contains(node) && !x.contains(node) && !y.contains(node) {
      z_init.add(node)
    }
  }
  let x_closure = reachable(graph, x, ancestors, z_init)
  for node in y {
    if x_closure.contains(node) {
      return None
    }
  }
  let z_updated : Set[String] = Set::Set([])
  for node in z_init.to_array() {
    if x_closure.contains(node) {
      z_updated.add(node)
    }
  }
  let y_closure = reachable(graph, y, ancestors, z_updated)
  let separator : Array[String] = []
  for node in z_updated.to_array() {
    if y_closure.contains(node) {
      separator.push(node)
    }
  }
  Some(separator)
}

///|
/// The nodes that are d-connected to the given nodes given the conditioning
/// set, restricted to the ancestors of the given nodes.
///
/// This is the port of the `REACHABLE` function of van der Zander and
/// Liśkiewicz, a modified Bayes-Ball algorithm.
fn reachable(
  graph : @graph.DirectedGraph,
  x : Array[String],
  ancestors : Set[String],
  z : Set[String],
) -> Set[String] {
  // The state of the search is the node and the direction of the edge the
  // ball came in with; `true` means the edge points into the node.
  let processed : Set[String] = Set::Set([])
  let reached : Set[String] = Set::Set([])
  let queue : Array[(Bool, String)] = []
  for node in x {
    if graph.predecessors(node).length() > 0 {
      queue.push((true, node))
    }
    if graph.successors(node).length() > 0 {
      queue.push((false, node))
    }
  }
  for state in queue {
    processed.add(state_key(state))
    reached.add(state.1)
  }
  let mut head = 0
  while head < queue.length() {
    let (e, v) = queue[head]
    head = head + 1
    // The edge to a predecessor of `v` points into `v`.
    for node in graph.predecessors(v) {
      let state = (false, node)
      if !processed.contains(state_key(state)) &&
        ball_passes(e, v, false, node, ancestors, z) {
        queue.push(state)
        processed.add(state_key(state))
        reached.add(node)
      }
    }
    // The edge to a successor of `v` points out of `v`.
    for node in graph.successors(v) {
      let state = (true, node)
      if !processed.contains(state_key(state)) &&
        ball_passes(e, v, true, node, ancestors, z) {
        queue.push(state)
        processed.add(state_key(state))
        reached.add(node)
      }
    }
  }
  reached
}

///|
/// The key of a state of the reachability search.
fn state_key(state : (Bool, String)) -> String {
  let (incoming, node) = state
  if incoming {
    "1" + node
  } else {
    "0" + node
  }
}

///|
/// Whether the ball that came into `v` along an edge that points into `v`
/// may continue to `node`.
///
/// The edge between `v` and `node` points into `node` when `forward` is
/// `true`. The ball passes on when the node is one of the ancestors and the
/// path is open at `v`, which is the case when `v` is not conditioned on or
/// when `v` is a collider of the path.
fn ball_passes(
  incoming : Bool,
  v : String,
  forward : Bool,
  node : String,
  ancestors : Set[String],
  z : Set[String],
) -> Bool {
  if !ancestors.contains(node) {
    return false
  }
  let collider = incoming && !forward
  !z.contains(v) || collider
}

///|
/// The identified estimand of the causal effect of the treatment.
///
/// The estimand carries the adjustment sets of the backdoor criterion, the
/// instruments and the frontdoor variables, together with the assumptions
/// that every one of them needs.
///
/// The `costs` and the `conditional_node_names` are the arguments of the
/// efficient backdoor strategies; they are ignored by the other strategies.
/// The `optimize_backdoor` flag replaces the backdoor search with the
/// optimized search of the upstream.
pub fn identify_effect_auto(
  graph : @graph.DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
  observed_nodes : Array[String],
  estimand_type : String,
  backdoor_adjustment : String,
  costs~ : Array[(String, Double)] = [],
  conditional_node_names~ : Array[String] = [],
  optimize_backdoor~ : Bool = false,
) -> IdentifiedEstimand {
  // Without a directed path from the treatment to the outcome the causal
  // effect is zero.
  if !@graph.has_directed_path(graph, action_nodes, outcome_nodes) {
    let estimand = IdentifiedEstimand::new(action_nodes, outcome_nodes)
    return estimand.with_no_directed_path(true)
  }
  if estimand_type != "nonparametric-ate" &&
    estimand_type != "nonparametric-cde" {
    abort(
      "Estimand type " +
      estimand_type +
      " is not supported. Use either nonparametric-ate or nonparametric-cde.",
    )
  }
  let direct_effect = estimand_type == "nonparametric-cde"
  let (backdoor_sets, message) = identify_backdoor(
    graph,
    action_nodes,
    outcome_nodes,
    observed_nodes,
    backdoor_adjustment,
    direct_effect~,
    costs~,
    conditional_node_names~,
    optimize_backdoor~,
  )
  if message != "" {
    abort(message)
  }
  let estimand = IdentifiedEstimand::new(action_nodes, outcome_nodes)
  estimand.set_estimand_type(estimand_type)
  // The adjustment sets that use an unobserved variable cannot be estimated.
  let observed : Set[String] = Set::Set([])
  for node in observed_nodes {
    observed.add(node)
  }
  let usable : Array[AdjustmentSet] = []
  for set in backdoor_sets {
    let is_observed = set.adjustment_variables.all(fn(node) {
      observed.contains(node)
    })
    if is_observed {
      usable.push(set)
    }
  }
  // Every adjustment set gets a name of its own, `backdoor1`, `backdoor2`, ...
  let mut default_id = ""
  let mut default_size = 0
  for index = 0; index < usable.length(); index = index + 1 {
    let set = usable[index]
    let key = "backdoor" + (index + 1).to_string()
    estimand.set_estimand(
      key,
      backdoor_assumptions(
        action_nodes,
        outcome_nodes,
        set.adjustment_variables,
      ),
    )
    estimand.set_adjustment_set(set.adjustment_variables.copy(), key)
    if default_id == "" || set.adjustment_variables.length() < default_size {
      default_id = key
      default_size = set.adjustment_variables.length()
    }
  }
  if default_id != "" {
    // The default backdoor set is also registered under the plain
    // "backdoor" name, like the Python code does.
    let variables = estimand.get_backdoor_variables(default_id)
    estimand.set_estimand(
      "backdoor",
      backdoor_assumptions(action_nodes, outcome_nodes, variables),
    )
    estimand.set_adjustment_set(variables, "backdoor")
    estimand.set_default_backdoor_id(default_id)
    estimand.set_identifier_method("backdoor")
  }
  if direct_effect {
    return estimand
  }
  // The instrumental variables of the treatment.
  let instruments = @graph.get_instruments(graph, action_nodes, outcome_nodes)
  estimand.set_instrumental_variables(instruments.copy())
  if instruments.length() > 0 {
    estimand.set_estimand(
      "iv",
      iv_assumptions(action_nodes, outcome_nodes, instruments),
    )
  }
  // The frontdoor variables of the treatment.
  let frontdoor = identify_frontdoor(
    graph, action_nodes, outcome_nodes, observed_nodes,
  )
  estimand.set_frontdoor_variables(frontdoor.copy())
  if frontdoor.length() > 0 {
    estimand.set_estimand(
      "frontdoor",
      frontdoor_assumptions(action_nodes, outcome_nodes, frontdoor),
    )
  }
  // The adjustment set of the complete adjustment criterion.
  let general_sets = identify_generalized_adjustment_set(
    graph, action_nodes, outcome_nodes, observed_nodes,
  )
  for index = 0; index < general_sets.length(); index = index + 1 {
    let set = general_sets[index]
    let key = "general" + (index + 1).to_string()
    estimand.set_estimand(
      key,
      backdoor_assumptions(
        action_nodes,
        outcome_nodes,
        set.adjustment_variables,
      ),
    )
    estimand.set_general_adjustment_variables(
      set.adjustment_variables.copy(),
      key,
    )
    estimand.set_estimand(
      "general_adjustment",
      backdoor_assumptions(
        action_nodes,
        outcome_nodes,
        set.adjustment_variables,
      ),
    )
    estimand.set_general_adjustment_variables(
      set.adjustment_variables.copy(),
      "general_adjustment",
    )
    estimand.set_default_adjustment_set_id(key)
  }
  estimand
}

///|
/// The identified estimand of the causal effect of the treatment.
///
/// This is the same as `identify_effect_auto` with the default backdoor
/// strategy and the average total effect.
pub fn identify_effect(
  graph : @graph.DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
  observed_nodes : Array[String],
) -> IdentifiedEstimand {
  identify_effect_auto(
    graph,
    action_nodes,
    outcome_nodes,
    observed_nodes,
    "nonparametric-ate",
    BACKDOOR_DEFAULT,
  )
}

///|
/// The assumption of a backdoor adjustment set.
fn backdoor_assumptions(
  treatment_names : Array[String],
  outcome_names : Array[String],
  common_causes : Array[String],
) -> Array[String] {
  let treatment = join_names(treatment_names)
  let outcome = outcome_names[0]
  let causes = join_names(common_causes)
  [
    "Unconfoundedness: If U→{" +
    treatment +
    "} and U→" +
    outcome +
    " then P(" +
    outcome +
    "|" +
    treatment +
    "," +
    causes +
    ",U) = P(" +
    outcome +
    "|" +
    treatment +
    "," +
    causes +
    ")",
  ]
}

///|
/// The assumptions of a frontdoor adjustment set.
fn frontdoor_assumptions(
  treatment_names : Array[String],
  outcome_names : Array[String],
  frontdoor_names : Array[String],
) -> Array[String] {
  let treatment = join_names(treatment_names)
  let outcome = join_names(outcome_names)
  let first_outcome = outcome_names[0]
  let frontdoor = join_names(frontdoor_names)
  [
    "Full-mediation: " +
    frontdoor +
    " intercepts (blocks) all directed paths from " +
    treatment +
    " to " +
    outcome +
    ".",
    "First-stage-unconfoundedness: If U→{" +
    treatment +
    "} and U→{" +
    frontdoor +
    "} then P(" +
    frontdoor +
    "|" +
    treatment +
    ",U) = P(" +
    frontdoor +
    "|" +
    treatment +
    ")",
    "Second-stage-unconfoundedness: If U→{" +
    frontdoor +
    "} and U→" +
    first_outcome +
    " then P(" +
    first_outcome +
    "|" +
    frontdoor +
    ", " +
    treatment +
    ", U) = P(" +
    first_outcome +
    "|" +
    frontdoor +
    ", " +
    treatment +
    ")",
  ]
}

///|
/// The assumptions of an instrumental variable estimand.
fn iv_assumptions(
  treatment_names : Array[String],
  outcome_names : Array[String],
  instrument_names : Array[String],
) -> Array[String] {
  let treatment = join_names(treatment_names)
  let outcome = outcome_names[0]
  let instruments = join_names(instrument_names)
  [
    "As-if-random: If U→→" +
    outcome +
    " then ¬(U →→{" +
    instruments +
    "})",
    "Exclusion: If we remove {" +
    instruments +
    "}→{" +
    treatment +
    "}, then ¬({" +
    instruments +
    "}→" +
    outcome +
    ")",
  ]
}

///|
/// The names of the variables, separated by commas.
fn join_names(names : Array[String]) -> String {
  let mut out = ""
  let mut first = true
  for name in names {
    if !first {
      out = out + ","
    }
    out = out + name
    first = false
  }
  out
}

///|
/// The names of the variables, sorted and without duplicates.
fn sorted_unique(names : Array[String]) -> Array[String] {
  let sorted = names.copy()
  sorted.sort_by(fn(a, b) { compare(a, b) })
  let out : Array[String] = []
  for name in sorted {
    if out.length() == 0 || out[out.length() - 1] != name {
      out.push(name)
    }
  }
  out
}

///|
/// All the combinations of `size` elements of the sorted `items`, in
/// lexicographic order.
fn combinations(items : Array[String], size : Int32) -> Array[Array[String]] {
  let out : Array[Array[String]] = []
  let count = items.length()
  if size <= 0 || size > count {
    return out
  }
  let indices : Array[Int32] = []
  let mut index = 0
  while index < size {
    indices.push(index)
    index = index + 1
  }
  while true {
    let candidate : Array[String] = []
    for position in indices {
      candidate.push(items[position])
    }
    out.push(candidate)
    // Move to the next combination in lexicographic order.
    let mut position = size - 1
    while position >= 0 {
      if indices[position] < count - size + position {
        break
      }
      position = position - 1
    }
    if position < 0 {
      break
    }
    indices[position] = indices[position] + 1
    let mut next = position + 1
    while next < size {
      indices[next] = indices[next - 1] + 1
      next = next + 1
    }
  }
  out
}

///|
/// Whether every node of the graph is observed.
fn every_node_observed(
  graph : @graph.DirectedGraph,
  observed_nodes : Array[String],
) -> Bool {
  let observed : Set[String] = Set::Set([])
  for node in observed_nodes {
    observed.add(node)
  }
  let nodes = graph.node_list()
  if observed.length() != nodes.length() {
    return false
  }
  for node in nodes {
    if !observed.contains(node) {
      return false
    }
  }
  true
}

///|
/// Set the type of the estimand, e.g. `"nonparametric-ate"`.
pub fn IdentifiedEstimand::set_estimand_type(
  self : IdentifiedEstimand,
  estimand_type : String,
) -> Unit {
  self.estimand_type = estimand_type
}

///|
/// Set the instruments of the estimand.
pub fn IdentifiedEstimand::set_instrumental_variables(
  self : IdentifiedEstimand,
  variables : Array[String],
) -> Unit {
  self.instrumental_variables = variables
}

///|
/// Set the frontdoor variables of the estimand.
pub fn IdentifiedEstimand::set_frontdoor_variables(
  self : IdentifiedEstimand,
  variables : Array[String],
) -> Unit {
  self.frontdoor_variables = variables
}

///|
/// Set the adjustment variables of the complete adjustment criterion.
pub fn IdentifiedEstimand::set_general_adjustment_variables(
  self : IdentifiedEstimand,
  variables : Array[String],
  key : String,
) -> Unit {
  self.general_adjustment_variables.set(key, variables)
}

///|
/// The adjustment variables of the complete adjustment criterion.
pub fn IdentifiedEstimand::get_general_adjustment_variables(
  self : IdentifiedEstimand,
  key : String,
) -> Array[String] {
  match self.general_adjustment_variables.get(key) {
    Some(variables) => variables
    None => []
  }
}
