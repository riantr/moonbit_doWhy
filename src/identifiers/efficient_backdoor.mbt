///|
/// The efficient backdoor search of the `identifiers` package.
///
/// This is the port of `dowhy.causal_identifier.efficient_backdoor`. The search
/// finds the adjustment set of a treatment and an outcome that is the smallest
/// under the order of Smucler, Sapienza and Rotnitzky (2021, Biometrika) and of
/// Smucler and Rotnitzky (2022, Journal of Causal Inference).
///
/// The three strategies of the upstream are the port of the three functions of
/// the upstream:
/// - the **efficient** adjustment set, which is the boundary of the outcome in
///   the graph of the observable variables,
/// - the **efficient minimal** adjustment set, which is the smallest subset of
///   that boundary that still adjusts for the confounding,
/// - the **efficient minimum cost** adjustment set, which is found with a
///   minimum cut of a flow network whose capacities are the costs of the
///   variables.

///|
/// The message that no adjustment set of the observable variables exists.
pub const EFFICIENT_BACKDOOR_NO_ADJUSTMENT_SET : String = "an adjustment set formed by observable variables does not exist"

///|
/// The message that the conditions for the existence of an optimal adjustment
/// set are not satisfied.
pub const EFFICIENT_BACKDOOR_NO_OPTIMAL_SET : String = "the conditions that guarantee the existence of an optimal adjustment set are not satisfied"

///|
/// The message that the search is only valid for a one dimensional treatment.
pub const EFFICIENT_BACKDOOR_MULTIVARIATE_TREATMENT : String = "the efficient backdoor search is only valid for a one dimensional treatment"

///|
/// The message that the search is only valid for a one dimensional outcome.
pub const EFFICIENT_BACKDOOR_MULTIVARIATE_OUTCOME : String = "the efficient backdoor search is only valid for a one dimensional outcome"

///|
/// The message that the costs of the variables have to be positive.
pub const EFFICIENT_BACKDOOR_NEGATIVE_COST : String = "the costs of the variables have to be positive"

///|
/// The message that some of the conditional variables are not observed.
pub const EFFICIENT_BACKDOOR_UNOBSERVED_CONDITIONAL : String = "some of the conditional variables are not marked as observed"

///|
/// The capacity that stands for an infinite capacity of the flow network.
///
/// The capacities of the variables are the costs of the variables, which are
/// small numbers, so a capacity of this size is never reached by the flow.
const EFFICIENT_BACKDOOR_INFINITE_CAPACITY : Double = 1.0e15

///|
/// The efficient adjustment set of the treatment and the outcome.
///
/// The first component holds the adjustment set, the second one an error
/// message that is empty when the search succeeded.
///
/// The `conditional_node_names` are the variables that determine the treatment.
/// When they are not given, the intervention sets the treatment to a constant.
/// The `costs` are the costs of the variables; the variables that are not in
/// the list have no cost and are therefore free. An empty list of costs means
/// that every variable of the graph costs one, the way the upstream assumes it
/// when it is given no costs at all.
pub fn efficient_backdoor_adjustment(
  graph : @graph.DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
  observed_nodes : Array[String],
  conditional_node_names : Array[String],
  costs : Array[(String, Double)],
) -> (Array[String], String) {
  let (search, message) = efficient_backdoor_search(
    graph, action_nodes, outcome_nodes, observed_nodes, conditional_node_names, costs,
  )
  if message != "" {
    return ([], message)
  }
  let h1 = search.build_h1()
  if neighbours(h1, search.outcome_name).contains(search.treatment_name) {
    return ([], EFFICIENT_BACKDOOR_NO_ADJUSTMENT_SET)
  }
  let ancestors = search.ancestors_all(
    search.conditional_node_names + [search.treatment_name, search.outcome_name],
  )
  let all_observed = search.observed_node_count == search.graph.node_count()
  let mut observed_are_ancestors = true
  for node in search.observed_nodes.to_array() {
    if !ancestors.contains(node) {
      observed_are_ancestors = false
      break
    }
  }
  if !all_observed && !observed_are_ancestors {
    return ([], EFFICIENT_BACKDOOR_NO_OPTIMAL_SET)
  }
  (node_boundary(h1, [search.outcome_name]), "")
}

///|
/// The efficient minimal adjustment set of the treatment and the outcome.
///
/// The first component holds the adjustment set, the second one an error
/// message that is empty when the search succeeded.
///
/// The arguments are the ones of `efficient_backdoor_adjustment`.
pub fn efficient_backdoor_minimal_adjustment(
  graph : @graph.DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
  observed_nodes : Array[String],
  conditional_node_names : Array[String],
  costs : Array[(String, Double)],
) -> (Array[String], String) {
  let (search, message) = efficient_backdoor_search(
    graph, action_nodes, outcome_nodes, observed_nodes, conditional_node_names, costs,
  )
  if message != "" {
    return ([], message)
  }
  let h1 = search.build_h1()
  if neighbours(h1, search.outcome_name).contains(search.treatment_name) {
    return ([], EFFICIENT_BACKDOOR_NO_ADJUSTMENT_SET)
  }
  let boundary = node_boundary(h1, [search.outcome_name])
  (unblocked(h1, boundary, search.treatment_name), "")
}

///|
/// The efficient minimum cost adjustment set of the treatment and the outcome.
///
/// The first component holds the adjustment set, the second one an error
/// message that is empty when the search succeeded.
///
/// The adjustment set is found with the minimum cut of the flow network of the
/// upstream: every variable is split into an in and an out node, the edge
/// between them costs the cost of the variable, and the edges of the graph are
/// free. The variables of the cut are the adjustment set.
///
/// The arguments are the ones of `efficient_backdoor_adjustment`.
pub fn efficient_backdoor_mincost_adjustment(
  graph : @graph.DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
  observed_nodes : Array[String],
  conditional_node_names : Array[String],
  costs : Array[(String, Double)],
) -> (Array[String], String) {
  let (search, message) = efficient_backdoor_search(
    graph, action_nodes, outcome_nodes, observed_nodes, conditional_node_names, costs,
  )
  if message != "" {
    return ([], message)
  }
  let h1 = search.build_h1()
  if neighbours(h1, search.outcome_name).contains(search.treatment_name) {
    return ([], EFFICIENT_BACKDOOR_NO_ADJUSTMENT_SET)
  }
  let source = search.outcome_name + "''"
  let sink = search.treatment_name + "'"
  let network = build_flow_network(h1, search.cost_of)
  let residual = maximum_flow_residual(network, source, sink)
  let reachable = residual_reachable(network, residual, source)
  (h_operator(reachable, search.graph.node_list()), "")
}

///|
/// The search of the efficient backdoor sets.
priv struct EfficientBackdoorSearch {
  graph : @graph.DirectedGraph
  treatment_name : String
  outcome_name : String
  observed_nodes : Set[String]
  observed_node_count : Int32
  conditional_node_names : Array[String]
  cost_of : Map[String, Double]
}

///|
/// The search of the efficient backdoor sets of the given graph.
fn efficient_backdoor_search(
  graph : @graph.DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
  observed_nodes : Array[String],
  conditional_node_names : Array[String],
  costs : Array[(String, Double)],
) -> (EfficientBackdoorSearch, String) {
  if action_nodes.length() != 1 {
    return (empty_search(graph), EFFICIENT_BACKDOOR_MULTIVARIATE_TREATMENT)
  }
  if outcome_nodes.length() != 1 {
    return (empty_search(graph), EFFICIENT_BACKDOOR_MULTIVARIATE_OUTCOME)
  }
  // The variables of the cost list are part of the graph, the way the upstream
  // adds them to it.
  let work = graph.copy()
  let cost_of : Map[String, Double] = Map([])
  if costs.length() == 0 {
    // The upstream uses a cost of one for every variable of the graph when no
    // costs are given, and a variable without a cost has an infinite capacity
    // in the flow network. An empty list of costs therefore means a cost of
    // one for every variable, and not an infinite cost for every variable.
    for node in work.node_list() {
      cost_of.set(node, 1.0)
    }
  } else {
    for entry in costs {
      let (node, cost) = entry
      if cost <= 0.0 {
        return (empty_search(graph), EFFICIENT_BACKDOOR_NEGATIVE_COST)
      }
      work.add_node(node)
      cost_of.set(node, cost)
    }
  }
  let observed : Set[String] = Set::Set([])
  for node in work.node_list() {
    if observed_nodes.contains(node) {
      observed.add(node)
    }
  }
  for node in conditional_node_names {
    if !observed.contains(node) {
      return (empty_search(work), EFFICIENT_BACKDOOR_UNOBSERVED_CONDITIONAL)
    }
  }
  let search = {
    graph: work,
    treatment_name: action_nodes[0],
    outcome_name: outcome_nodes[0],
    observed_nodes: observed,
    observed_node_count: observed.length(),
    conditional_node_names,
    cost_of,
  }
  (search, "")
}

///|
/// A search without a graph, for the cases that fail before the search starts.
fn empty_search(graph : @graph.DirectedGraph) -> EfficientBackdoorSearch {
  {
    graph,
    treatment_name: "",
    outcome_name: "",
    observed_nodes: Set::Set([]),
    observed_node_count: 0,
    conditional_node_names: [],
    cost_of: Map([]),
  }
}

///|
/// The ancestors of the given nodes, the nodes themselves included.
fn EfficientBackdoorSearch::ancestors_all(
  self : EfficientBackdoorSearch,
  nodes : Array[String],
) -> Set[String] {
  let ancestors = self.graph.ancestors_of(nodes)
  for node in nodes {
    ancestors.add(node)
  }
  ancestors
}

///|
/// The nodes that lie on a causal path between the treatment and the outcome.
fn EfficientBackdoorSearch::causal_vertices(
  self : EfficientBackdoorSearch,
) -> Array[String] {
  let vertices : Array[String] = []
  let seen : Set[String] = Set::Set([])
  for
    path in self.graph.all_simple_paths(self.treatment_name, self.outcome_name) {
    for node in path {
      if node != self.treatment_name && !seen.contains(node) {
        seen.add(node)
        vertices.push(node)
      }
    }
  }
  vertices
}

///|
/// The forbidden set with respect to the treatment and the outcome.
fn EfficientBackdoorSearch::forbidden(
  self : EfficientBackdoorSearch,
) -> Set[String] {
  let forbidden : Set[String] = Set::Set([])
  let vertices = self.causal_vertices()
  for node in vertices {
    for descendant in self.graph.descendants(node).to_array() {
      forbidden.add(descendant)
    }
    forbidden.add(node)
  }
  forbidden.add(self.treatment_name)
  forbidden
}

///|
/// The ignorable vertices with respect to the treatment, the outcome, the
/// conditional and the observable variables.
fn EfficientBackdoorSearch::ignore(
  self : EfficientBackdoorSearch,
) -> Set[String] {
  let first = self.ancestors_all(
    self.conditional_node_names + [self.treatment_name, self.outcome_name],
  )
  first.remove(self.treatment_name)
  first.remove(self.outcome_name)
  let second : Set[String] = Set::Set([])
  for node in self.graph.node_list() {
    if !self.observed_nodes.contains(node) {
      second.add(node)
    }
  }
  for node in self.forbidden().to_array() {
    second.add(node)
  }
  let ignore : Set[String] = Set::Set([])
  for node in first.to_array() {
    if second.contains(node) {
      ignore.add(node)
    }
  }
  ignore
}

///|
/// The H0 graph of the search: the moral graph of the backdoor graph of the
/// ancestors of the treatment, the outcome and the conditional variables.
///
/// The graph is an adjacency map, because the moral graph is undirected.
fn EfficientBackdoorSearch::build_h0(
  self : EfficientBackdoorSearch,
) -> Map[String, Array[String]] {
  let ancestors = self.ancestors_all(
    self.conditional_node_names + [self.treatment_name, self.outcome_name],
  )
  let restricted = self.graph.subgraph(ancestors.to_array())
  // The backdoor graph: the edges of the causal paths out of the treatment are
  // removed.
  let backdoor = restricted.copy()
  for node in self.causal_vertices() {
    if restricted.has_edge(self.treatment_name, node) {
      backdoor.remove_edge(self.treatment_name, node)
    }
  }
  moral_graph(backdoor)
}

///|
/// The H1 graph of the search: the H0 graph without the ignorable vertices,
/// with the edges between the vertices that are connected through them, and
/// with the edges of the conditional variables.
fn EfficientBackdoorSearch::build_h1(
  self : EfficientBackdoorSearch,
) -> Map[String, Array[String]] {
  let h0 = self.build_h0()
  let ignorable = self.ignore()
  let vertices : Array[String] = []
  for node in self.graph.node_list() {
    if h0.contains(node) && !ignorable.contains(node) {
      vertices.push(node)
    }
  }
  let h1 : Map[String, Array[String]] = Map([])
  for node in vertices {
    h1.set(node, [])
  }
  // Two vertices are connected when a path of the H0 graph that holds only the
  // ignorable vertices connects them.
  for i in 0..<vertices.length() {
    for j in (i + 1)..<vertices.length() {
      let first = vertices[i]
      let second = vertices[j]
      if connected_through(h0, ignorable, first, second) {
        add_undirected_edge(h1, first, second)
      }
    }
  }
  // The conditional variables are between the treatment and the outcome.
  for node in self.conditional_node_names {
    add_undirected_edge(h1, self.treatment_name, node)
    add_undirected_edge(h1, node, self.outcome_name)
  }
  h1
}

///|
/// Whether two vertices of the graph are connected by a path that holds only
/// the ignorable vertices and the two vertices themselves.
fn connected_through(
  graph : Map[String, Array[String]],
  ignorable : Set[String],
  first : String,
  second : String,
) -> Bool {
  if first == second {
    return true
  }
  let allowed : Set[String] = Set::Set([])
  allowed.add(first)
  allowed.add(second)
  for node in ignorable.to_array() {
    allowed.add(node)
  }
  let seen : Set[String] = Set::Set([])
  seen.add(first)
  let queue : Array[String] = [first]
  while queue.length() > 0 {
    let node = queue[queue.length() - 1]
    let _ = queue.pop()
    for neighbour in neighbours(graph, node) {
      if !seen.contains(neighbour) {
        if neighbour == second {
          return true
        }
        if allowed.contains(neighbour) {
          seen.add(neighbour)
          queue.push(neighbour)
        }
      }
    }
  }
  false
}

///|
/// The moral graph of a directed graph: every edge becomes undirected and the
/// parents of a node are connected with each other.
fn moral_graph(graph : @graph.DirectedGraph) -> Map[String, Array[String]] {
  let moral : Map[String, Array[String]] = Map([])
  for node in graph.node_list() {
    moral.set(node, [])
  }
  for (from, to) in graph.edge_list() {
    add_undirected_edge(moral, from, to)
  }
  for node in graph.node_list() {
    let parents = graph.predecessors(node)
    for i in 0..<parents.length() {
      for j in (i + 1)..<parents.length() {
        add_undirected_edge(moral, parents[i], parents[j])
      }
    }
  }
  moral
}

///|
/// The neighbours of a node of an undirected graph.
fn neighbours(
  graph : Map[String, Array[String]],
  node : String,
) -> Array[String] {
  graph.get(node).unwrap_or([])
}

///|
/// The edge between two nodes of an undirected graph.
fn add_undirected_edge(
  graph : Map[String, Array[String]],
  from : String,
  to : String,
) -> Unit {
  if !graph.contains(from) {
    graph.set(from, [])
  }
  if !graph.contains(to) {
    graph.set(to, [])
  }
  let from_neighbours = graph.get(from).unwrap_or([]).copy()
  if !from_neighbours.contains(to) {
    from_neighbours.push(to)
    graph.set(from, from_neighbours)
  }
  let to_neighbours = graph.get(to).unwrap_or([]).copy()
  if !to_neighbours.contains(from) {
    to_neighbours.push(from)
    graph.set(to, to_neighbours)
  }
}

///|
/// The boundary of a set of nodes of an undirected graph: the nodes that are
/// not in the set and that have an edge to a node of the set.
fn node_boundary(
  graph : Map[String, Array[String]],
  nodes : Array[String],
) -> Array[String] {
  let inside : Set[String] = Set::Set([])
  for node in nodes {
    inside.add(node)
  }
  let boundary : Array[String] = []
  for node in nodes {
    for neighbour in neighbours(graph, node) {
      if !inside.contains(neighbour) && !boundary.contains(neighbour) {
        boundary.push(neighbour)
      }
    }
  }
  boundary.sort_by(fn(a, b) { a.lexical_compare(b) })
  boundary
}

///|
/// The nodes that are not blocked by the given set: the boundary of the
/// connected component of the treatment in the graph without the given set.
fn unblocked(
  graph : Map[String, Array[String]],
  nodes : Array[String],
  treatment : String,
) -> Array[String] {
  let removed : Set[String] = Set::Set([])
  for node in nodes {
    removed.add(node)
  }
  // The connected component of the treatment in the graph without the nodes.
  let component : Set[String] = Set::Set([])
  if !removed.contains(treatment) {
    component.add(treatment)
    let queue : Array[String] = [treatment]
    while queue.length() > 0 {
      let node = queue[queue.length() - 1]
      let _ = queue.pop()
      for neighbour in neighbours(graph, node) {
        if !removed.contains(neighbour) && !component.contains(neighbour) {
          component.add(neighbour)
          queue.push(neighbour)
        }
      }
    }
  }
  node_boundary(graph, component.to_array())
}

///|
/// The flow network of the search: every variable is split into an in and an
/// out node, the edge between them costs the cost of the variable, and the
/// edges of the graph are free.
fn build_flow_network(
  graph : Map[String, Array[String]],
  cost_of : Map[String, Double],
) -> FlowNetwork {
  let network = FlowNetwork::new()
  for node in graph.keys().to_array() {
    let capacity = match cost_of.get(node) {
      Some(cost) => cost
      None => EFFICIENT_BACKDOOR_INFINITE_CAPACITY
    }
    network.add_edge(node + "'", node + "''", capacity)
  }
  for node in graph.keys().to_array() {
    for neighbour in neighbours(graph, node) {
      if node < neighbour {
        network.add_edge(
          node + "''",
          neighbour + "'",
          EFFICIENT_BACKDOOR_INFINITE_CAPACITY,
        )
        network.add_edge(
          neighbour + "''",
          node + "'",
          EFFICIENT_BACKDOOR_INFINITE_CAPACITY,
        )
      }
    }
  }
  network
}

///|
/// The operator h of the upstream: the variables whose in node is on the source
/// side of the cut and whose out node is on the other side.
fn h_operator(reachable : Set[String], nodes : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for node in nodes {
    if reachable.contains(node + "'") && !reachable.contains(node + "''") {
      out.push(node)
    }
  }
  out.sort_by(fn(a, b) { a.lexical_compare(b) })
  out
}

///|
/// A flow network with a residual capacity per edge.
priv struct FlowNetwork {
  names : Array[String]
  index_of : Map[String, Int32]
  targets : Array[Int32]
  capacities : Array[Double]
  adjacency : Array[Array[Int32]]
}

///|
/// A new flow network without any node.
fn FlowNetwork::new() -> FlowNetwork {
  { names: [], index_of: Map([]), targets: [], capacities: [], adjacency: [], }
}

///|
/// The index of a node of the network, which is added when it is not there.
fn FlowNetwork::index(self : FlowNetwork, name : String) -> Int32 {
  match self.index_of.get(name) {
    Some(value) => value
    None => {
      let value = self.names.length()
      self.names.push(name)
      self.index_of.set(name, value)
      self.targets.push(value)
      self.capacities.push(0.0)
      self.adjacency.push([])
      value
    }
  }
}

///|
/// The edge from one node of the network to another one.
fn FlowNetwork::add_edge(
  self : FlowNetwork,
  from : String,
  to : String,
  capacity : Double,
) -> Unit {
  let from_index = self.index(from)
  let to_index = self.index(to)
  // Every edge is stored together with its reverse, so that the reverse of an
  // edge is the edge with the next index.
  self.targets.push(to_index)
  self.capacities.push(capacity)
  self.adjacency[from_index].push(self.targets.length() - 1)
  self.targets.push(from_index)
  self.capacities.push(0.0)
  self.adjacency[to_index].push(self.targets.length() - 1)
}

///|
/// The residual capacities of the network after a maximum flow was computed
/// from the source to the sink.
///
/// The algorithm is the one of Dinic: the level graph of the residual network
/// is built breadth first, and a blocking flow is pushed along it. The flow
/// that is found does not depend on the order the augmenting paths are found
/// in, and the source side of the minimum cut is the same for every maximum
/// flow, so the cut the upstream finds is the cut the port finds.
fn maximum_flow_residual(
  network : FlowNetwork,
  source : String,
  sink : String,
) -> Array[Double] {
  let node_count = network.names.length()
  let source_index = network.index(source)
  let sink_index = network.index(sink)
  let residual = network.capacities.copy()
  while true {
    // The levels of the level graph. The nodes have to be reached in the order
    // of their distance to the source, so the queue is read from its front.
    let levels = empty_levels(node_count)
    levels[source_index] = 0
    let queue : Array[Int32] = [source_index]
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head = head + 1
      for edge in network.adjacency[node] {
        let target = network.targets[edge]
        if residual[edge] > 0.0 && levels[target] < 0 {
          levels[target] = levels[node] + 1
          queue.push(target)
        }
      }
    }
    if levels[sink_index] < 0 {
      break
    }
    let pointers = empty_pointers(node_count)
    while true {
      let sent = blocking_flow(
        network,
        residual,
        levels,
        pointers,
        source_index,
        sink_index,
        EFFICIENT_BACKDOOR_INFINITE_CAPACITY,
      )
      if sent <= 0.0 {
        break
      }
    }
  }
  residual
}

///|
/// An array of the given length whose entries are all minus one.
///
/// The minus one is the sign that a node of the level graph was not reached
/// yet, so it has to differ from the level of the source, which is zero.
fn empty_levels(count : Int32) -> Array[Int32] {
  let levels : Array[Int32] = []
  for _ in 0..<count {
    levels.push(-1)
  }
  levels
}

///|
/// An array of the given length whose entries are all zero.
///
/// The entries are the positions of the current edge of the level graph, and
/// the first edge of a node is the one at the position zero.
fn empty_pointers(count : Int32) -> Array[Int32] {
  let pointers : Array[Int32] = []
  for _ in 0..<count {
    pointers.push(0)
  }
  pointers
}

///|
/// The index of the edge that is the reverse of the given one.
///
/// The edges of the network are stored in pairs: the edge that was added and
/// the edge that goes the other way. The index of the reverse of an even edge
/// is the next one, and the index of the reverse of an odd edge is the
/// previous one.
fn reverse_of(edge : Int32) -> Int32 {
  if edge % 2 == 0 {
    edge + 1
  } else {
    edge - 1
  }
}

///|
/// The blocking flow of one level graph.
///
/// The amount that is pushed along a path is the smallest residual capacity of
/// the path, so at least one edge of the path is saturated and the search
/// terminates. The limit is passed down the path and every edge of the path is
/// pushed that same amount; passing the amount back up instead would push
/// more on the edges near the source than on the edges near the sink, and the
/// flow would not be conserved.
fn blocking_flow(
  network : FlowNetwork,
  residual : Array[Double],
  levels : Array[Int32],
  pointers : Array[Int32],
  node : Int32,
  sink : Int32,
  limit : Double,
) -> Double {
  if node == sink {
    return limit
  }
  while pointers[node] < network.adjacency[node].length() {
    let edge = network.adjacency[node][pointers[node]]
    let target = network.targets[edge]
    if residual[edge] > 0.0 && levels[target] == levels[node] + 1 {
      let allowed = if limit < residual[edge] { limit } else { residual[edge] }
      let sent = blocking_flow(
        network, residual, levels, pointers, target, sink, allowed,
      )
      if sent > 0.0 {
        residual[edge] = residual[edge] - sent
        residual[reverse_of(edge)] = residual[reverse_of(edge)] + sent
        return sent
      }
    }
    pointers[node] = pointers[node] + 1
  }
  0.0
}

///|
/// The nodes that are reachable from the source in the residual network.
///
/// A node is reachable when it can be reached by an edge that still has a
/// residual capacity, which is the case for the forward edges that are not
/// saturated and for the reverse edges that carry a flow. The set is the
/// source side of the minimum cut.
fn residual_reachable(
  network : FlowNetwork,
  residual : Array[Double],
  source : String,
) -> Set[String] {
  let source_index = network.index(source)
  let reachable : Set[String] = Set::Set([])
  let seen : Set[Int32] = Set::Set([])
  seen.add(source_index)
  reachable.add(network.names[source_index])
  let queue : Array[Int32] = [source_index]
  while queue.length() > 0 {
    let node = queue[queue.length() - 1]
    let _ = queue.pop()
    for edge in network.adjacency[node] {
      if residual[edge] > 0.0 {
        let target = network.targets[edge]
        if !seen.contains(target) {
          seen.add(target)
          reachable.add(network.names[target])
          queue.push(target)
        }
      }
    }
  }
  reachable
}
