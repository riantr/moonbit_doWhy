/// The data sets that are generated from a random graph.
///
/// This is the port of the part of `dowhy.datasets` that builds a random
/// directed acyclic graph, gives every node of it a kind of data and draws the
/// rows of the data from the graph.
///
/// The upstream draws its graph and its rows with the global generator of
/// numpy, so the data set of the upstream is not reproducible. The port takes
/// the seed of its own generator, so the data set of the port is.
///
/// The upstream writes the binary column of a node with
/// `numpy.vectorize(convert_to_binary)`, and the function it vectorizes
/// returns an array of one element instead of a number. The call therefore
/// fails with the numpy of the version two, and the port draws the column the
/// way the upstream means it: one Bernoulli variate per row, with the
/// probability of the sigmoid of the value of the row.

///|
/// A data set that was generated from a random graph.
///
/// This is the port of the dictionary `dowhy.datasets.dataset_from_random_graph`
/// returns.
pub struct RandomGraphDataset {
  df : @api.DataFrame
  outcome_name : String
  treatment_names : Array[String]
  gml_graph : String
  discrete_columns : Array[String]
  continuous_columns : Array[String]
  binary_columns : Array[String]
  ate : Double?
}

///|
/// The data frame of the data set.
pub fn RandomGraphDataset::frame(self : RandomGraphDataset) -> @api.DataFrame {
  self.df
}

///|
/// The name of the outcome column.
pub fn RandomGraphDataset::outcome(self : RandomGraphDataset) -> String {
  self.outcome_name
}

///|
/// The names of the treatment columns.
pub fn RandomGraphDataset::treatments(
  self : RandomGraphDataset,
) -> Array[String] {
  self.treatment_names.copy()
}

///|
/// The graph of the data set, in the GML format.
///
/// This is the port of the `gml_graph` of the upstream, which writes the graph
/// with `networkx.generate_gml`.
pub fn RandomGraphDataset::gml_graph(self : RandomGraphDataset) -> String {
  self.gml_graph
}

///|
/// The names of the columns that hold integers.
pub fn RandomGraphDataset::discrete_columns(
  self : RandomGraphDataset,
) -> Array[String] {
  self.discrete_columns.copy()
}

///|
/// The names of the columns that hold floating point numbers.
pub fn RandomGraphDataset::continuous_columns(
  self : RandomGraphDataset,
) -> Array[String] {
  self.continuous_columns.copy()
}

///|
/// The names of the columns that hold zeros and ones.
pub fn RandomGraphDataset::binary_columns(
  self : RandomGraphDataset,
) -> Array[String] {
  self.binary_columns.copy()
}

///|
/// The average treatment effect of the data set.
///
/// It is `None` when the upstream cannot compute it: the empirical effect of
/// the upstream reads the outcome of the two frames of the intervention, and
/// the frames miss the outcome when a treatment is a root of the graph, because
/// the upstream does not generate the columns that hang below a treatment of an
/// intervention.
pub fn RandomGraphDataset::average_treatment_effect(
  self : RandomGraphDataset,
) -> Double? {
  self.ate
}

///|
/// A data set that was generated from a random graph.
///
/// This is the port of `dowhy.datasets.dataset_from_random_graph`.
///
/// The `num_vars` variables are named after the letters of the alphabet, the
/// way the upstream names them, and their data is drawn from the graph. The
/// `prob_type_of_data` holds the probability of a variable to be discrete, to
/// be continuous and to be binary, in the order of the upstream.
///
/// The `prob_edge` is the probability of an edge of the graph. The upstream
/// takes it and does not use it, and the port does the same.
///
/// The average treatment effect of the data set is `None` when the upstream
/// cannot compute it, the way the accessor of the data set reports it.
pub fn dataset_from_random_graph(
  num_vars : Int32,
  num_samples~ : Int32 = 1000,
  prob_edge~ : Double = 0.3,
  random_seed~ : Int32 = 0,
  prob_type_of_data~ : (Double, Double, Double) = (0.333, 0.333, 0.334),
) -> RandomGraphDataset {
  let _ = prob_edge
  let random = @utils.Random::new(random_seed.to_uint64())
  let graph = random_graph(num_vars, random)
  let all_nodes = sorted_nodes(graph)
  let outcome = outcome_of(graph, all_nodes)
  let treatments = treatments_of(graph, all_nodes, outcome)
  let kinds = variable_kinds(all_nodes, random, prob_type_of_data)
  let weights = edge_weights(graph, random)
  let generated = compute_columns(
    graph,
    all_nodes,
    treatments,
    kinds,
    weights,
    num_samples,
    random,
    None,
  )
  let ate = average_treatment_effect(
    graph, all_nodes, treatments, outcome, kinds, weights, num_samples, random,
  )
  {
    df: to_frame(generated),
    outcome_name: outcome,
    treatment_names: treatments,
    gml_graph: graph_to_gml(graph),
    discrete_columns: columns_of_kind(all_nodes, kinds, Discrete),
    continuous_columns: columns_of_kind(all_nodes, kinds, Continuous),
    binary_columns: columns_of_kind(all_nodes, kinds, Binary),
    ate,
  }
}

///|
/// The kind of the data of a node of a random graph.
priv enum RandomVariableKind {
  Discrete
  Continuous
  Binary
}

///|
/// The columns of a data set that was generated from a random graph.
priv struct GeneratedColumns {
  values : Map[String, Array[Double]]
  kinds : Map[String, RandomVariableKind]
  order : Array[String]
}

///|
/// A random directed acyclic graph.
///
/// This is the port of `dowhy.datasets.generate_random_graph`. The upstream
/// starts from the simple ordered tree `0 -> 1 -> ...` and adds or removes ten
/// random edges: an edge is removed only when the graph stays connected, and
/// an edge is added only when the graph stays acyclic.
fn random_graph(
  num_vars : Int32,
  random : @utils.Random,
) -> @graph.DirectedGraph {
  let graph = simple_ordered_tree(num_vars)
  for _ in 0..<10 {
    let (i, j) = random_node_pair(num_vars, random)
    if graph.has_edge(node_name(i), node_name(j)) {
      @graph.del_edge(graph, node_name(i), node_name(j))
    } else {
      @graph.add_edge(graph, node_name(i), node_name(j))
    }
  }
  graph
}

///|
/// The simple ordered tree `a -> b -> ...`.
///
/// This is the port of `dowhy.utils.graph_operations.get_simple_ordered_tree`.
fn simple_ordered_tree(num_vars : Int32) -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  for i in 0..<num_vars {
    graph.add_node(node_name(i))
  }
  for i in 0..<(num_vars - 1) {
    graph.add_edge(node_name(i), node_name(i + 1))
  }
  graph
}

///|
/// A pair of two different nodes.
///
/// This is the port of `dowhy.utils.graph_operations.get_random_node_pair`.
fn random_node_pair(num_vars : Int32, random : @utils.Random) -> (Int32, Int32) {
  let i = random.next_int(num_vars)
  let mut j = random.next_int(num_vars)
  while j == i {
    j = random.next_int(num_vars)
  }
  (i, j)
}

///|
/// The name of the node with the given index.
///
/// The upstream names the nodes of its random graph after the letters of the
/// alphabet, in the order of the indices of the nodes of the simple ordered
/// tree.
fn node_name(index : Int32) -> String {
  let letters = [
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p",
    "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
  ]
  if index < 0 || index >= letters.length() {
    abort("a random graph holds at most 26 variables")
  }
  letters[index]
}

///|
/// The nodes of the graph, in the order of the alphabet.
fn sorted_nodes(graph : @graph.DirectedGraph) -> Array[String] {
  let nodes = graph.node_list()
  nodes.sort_by(fn(a, b) { a.lexical_compare(b) })
  nodes
}

///|
/// The outcome of the data set.
///
/// This is the port of the outcome of the upstream, which is the first node of
/// the graph that has no successor.
fn outcome_of(
  graph : @graph.DirectedGraph,
  all_nodes : Array[String],
) -> String {
  for node in all_nodes {
    if graph.successors(node).length() == 0 {
      return node
    }
  }
  ""
}

///|
/// The treatments of the data set.
///
/// This is the port of the treatments of the upstream, which are the nodes that
/// have a successor and whose successors hold the outcome.
fn treatments_of(
  graph : @graph.DirectedGraph,
  all_nodes : Array[String],
  outcome : String,
) -> Array[String] {
  let out : Array[String] = []
  for node in all_nodes {
    if graph.predecessors(node).length() > 0 {
      if graph.successors(node).contains(outcome) {
        out.push(node)
      }
    }
  }
  out
}

///|
/// The kind of the data of every node.
///
/// This is the port of the dictionary of the kinds of the upstream, which draws
/// one number per node and compares it with the probabilities of the kinds.
fn variable_kinds(
  all_nodes : Array[String],
  random : @utils.Random,
  prob_type_of_data : (Double, Double, Double),
) -> Map[String, RandomVariableKind] {
  let kinds : Map[String, RandomVariableKind] = Map([])
  let (prob_discrete, prob_continuous, _) = prob_type_of_data
  for node in all_nodes {
    let value = random.next_double()
    let kind = if value <= prob_discrete {
      Discrete
    } else if value <= prob_discrete + prob_continuous {
      Continuous
    } else {
      Binary
    }
    kinds.set(node, kind)
  }
  kinds
}

///|
/// The weight of every edge of the graph.
///
/// This is the port of the weights of the upstream, which draws them from the
/// uniform distribution of the interval from zero to one.
fn edge_weights(
  graph : @graph.DirectedGraph,
  random : @utils.Random,
) -> Map[(String, String), Double] {
  let weights : Map[(String, String), Double] = Map([])
  for (from, to) in graph.edge_list() {
    weights.set((from, to), random.next_double())
  }
  weights
}

///|
/// The columns of the data set.
///
/// This is the port of the `_compute_y` of the upstream, which walks the graph
/// from its roots and gives every node the values of a linear model of its
/// parents. The `intervene` holds the value of the treatment of the
/// intervention: `None` leaves the treatments alone, `Some(true)` sets them to
/// one and `Some(false)` sets them to zero.
fn compute_columns(
  graph : @graph.DirectedGraph,
  all_nodes : Array[String],
  treatments : Array[String],
  kinds : Map[String, RandomVariableKind],
  weights : Map[(String, String), Double],
  num_samples : Int32,
  random : @utils.Random,
  intervene : Bool?,
) -> GeneratedColumns {
  let values : Map[String, Array[Double]] = Map([])
  let order : Array[String] = []
  let changed : Map[String, Bool] = Map([])
  let mut current : Array[String] = []
  for node in all_nodes {
    if treatments.contains(node) {
      match intervene {
        Some(true) => {
          values.set(node, constant_column(num_samples, 1.0))
          order.push(node)
          continue
        }
        Some(false) => {
          values.set(node, constant_column(num_samples, 0.0))
          order.push(node)
          continue
        }
        None => ()
      }
    }
    if graph.predecessors(node).length() == 0 {
      let kind = kinds.get(node).unwrap_or(Continuous)
      values.set(node, root_column(kind, num_samples, random))
      order.push(node)
      changed.set(node, true)
      let successors = graph.successors(node)
      successors.sort_by(fn(a, b) { a.lexical_compare(b) })
      for successor in successors {
        current.push(successor)
      }
    }
  }
  while current.length() > 0 {
    let next : Array[String] = []
    for node in current {
      if changed.get(node).unwrap_or(false) {
        continue
      }
      if !all_predecessors_changed(graph, node, changed) {
        continue
      }
      let successors = graph.successors(node)
      successors.sort_by(fn(a, b) { a.lexical_compare(b) })
      for successor in successors {
        next.push(successor)
      }
      changed.set(node, true)
      let intervened = match intervene {
        Some(_) => true
        None => false
      }
      if intervened {
        // The upstream keeps the column of the treatment of an intervention.
        continue
      }
      let kind = kinds.get(node).unwrap_or(Continuous)
      let linear = linear_values(
        graph, node, weights, values, num_samples, random,
      )
      values.set(node, convert_column(kind, linear, random))
      order.push(node)
    }
    current = next
  }
  { values, kinds, order, }
}

///|
/// The frame of the generated columns.
fn to_frame(generated : GeneratedColumns) -> @api.DataFrame {
  let columns : Map[String, @api.Column] = Map([])
  for name in generated.order {
    let values = generated.values.get(name).unwrap_or([])
    let kind = generated.kinds.get(name).unwrap_or(Continuous)
    match kind {
      Continuous => columns.set(name, @api.Column::numeric(values))
      Discrete => {
        let texts : Array[String] = []
        for value in values {
          texts.push(value.to_string())
        }
        columns.set(name, @api.Column::discrete(texts))
      }
      Binary => {
        let texts : Array[String] = []
        for value in values {
          texts.push(if value >= 0.5 { "1" } else { "0" })
        }
        columns.set(name, @api.Column::discrete(texts))
      }
    }
  }
  @api.DataFrame::new(generated.order, columns)
}

///|
/// Whether the kind is the given one.
fn kind_is(kind : RandomVariableKind, other : RandomVariableKind) -> Bool {
  match (kind, other) {
    (Discrete, Discrete) => true
    (Continuous, Continuous) => true
    (Binary, Binary) => true
    _ => false
  }
}

///|
/// The columns of the given kind.
fn columns_of_kind(
  all_nodes : Array[String],
  kinds : Map[String, RandomVariableKind],
  kind : RandomVariableKind,
) -> Array[String] {
  let out : Array[String] = []
  for node in all_nodes {
    if kind_is(kinds.get(node).unwrap_or(Continuous), kind) {
      out.push(node)
    }
  }
  out
}

///|
/// The average treatment effect of the data set.
///
/// This is the port of the average treatment effect of the upstream. The
/// upstream computes it from the graph when every variable that is not a
/// treatment is continuous, and it computes it from the two frames of the
/// intervention otherwise.
fn average_treatment_effect(
  graph : @graph.DirectedGraph,
  all_nodes : Array[String],
  treatments : Array[String],
  outcome : String,
  kinds : Map[String, RandomVariableKind],
  weights : Map[(String, String), Double],
  num_samples : Int32,
  random : @utils.Random,
) -> Double? {
  let mut all_continuous = true
  for node in all_nodes {
    if treatments.contains(node) {
      continue
    }
    if !kind_is(kinds.get(node).unwrap_or(Continuous), Continuous) {
      all_continuous = false
    }
  }
  if all_continuous {
    return Some(exact_ate(graph, treatments, outcome, weights))
  }
  let treated = compute_columns(
    graph,
    all_nodes,
    treatments,
    kinds,
    weights,
    num_samples,
    random,
    Some(true),
  )
  let untreated = compute_columns(
    graph,
    all_nodes,
    treatments,
    kinds,
    weights,
    num_samples,
    random,
    Some(false),
  )
  match (treated.values.get(outcome), untreated.values.get(outcome)) {
    (Some(treated_values), Some(untreated_values)) =>
      Some(@utils.mean(treated_values) - @utils.mean(untreated_values))
    _ => None
  }
}

///|
/// The average treatment effect of the graph.
///
/// This is the port of `dowhy.datasets.exact_ate_of_linear_graph`, which adds
/// the product of the weights of the edges of every path from a treatment to
/// the outcome. A path that holds another treatment is left out.
fn exact_ate(
  graph : @graph.DirectedGraph,
  treatments : Array[String],
  outcome : String,
  weights : Map[(String, String), Double],
) -> Double {
  let mut ate = 0.0
  for treatment in treatments {
    for path in graph.all_simple_paths(treatment, outcome) {
      let mut interior = true
      for index in 1..<(path.length() - 1) {
        if treatments.contains(path[index]) {
          interior = false
        }
      }
      if !interior {
        continue
      }
      let mut multiplier = 1.0
      for index in 0..<(path.length() - 1) {
        let weight = weights.get((path[index], path[index + 1])).unwrap_or(0.0)
        multiplier = multiplier * weight
      }
      ate = ate + multiplier
    }
  }
  ate
}

///|
/// The values of a node that has no parent.
fn root_column(
  kind : RandomVariableKind,
  num_samples : Int32,
  random : @utils.Random,
) -> Array[Double] {
  match kind {
    Continuous => normal_column(num_samples, random)
    Discrete => discrete_sample_column(num_samples, random)
    Binary => binary_column(normal_column(num_samples, random), random)
  }
}

///|
/// The values of a column of the given number of samples of the normal
/// distribution.
fn normal_column(num_samples : Int32, random : @utils.Random) -> Array[Double] {
  let values : Array[Double] = []
  for _ in 0..<num_samples {
    values.push(random.next_normal())
  }
  values
}

///|
/// A column of the given number of samples of the same value.
fn constant_column(num_samples : Int32, value : Double) -> Array[Double] {
  let values : Array[Double] = []
  for _ in 0..<num_samples {
    values.push(value)
  }
  values
}

///|
/// A column of the given number of samples of the discrete distribution of the
/// upstream.
///
/// This is the port of `dowhy.datasets.create_discrete_column`, which takes the
/// probability of a value from the normal distribution with the mean zero and
/// the standard deviation one.
fn discrete_sample_column(
  num_samples : Int32,
  random : @utils.Random,
) -> Array[Double] {
  let probabilities = discrete_probabilities()
  let values : Array[Double] = []
  for _ in 0..<num_samples {
    values.push(choose_weighted(probabilities, random).to_double())
  }
  values
}

///|
/// The probabilities of the values from minus five to five.
fn discrete_probabilities() -> Array[Double] {
  let probabilities : Array[Double] = []
  let mut total = 0.0
  for value in -5..<=5 {
    let upper = @utils.normal_cdf(value.to_double() + 0.5)
    let lower = @utils.normal_cdf(value.to_double() - 0.5)
    let probability = upper - lower
    probabilities.push(probability)
    total = total + probability
  }
  for i in 0..<probabilities.length() {
    probabilities[i] = probabilities[i] / total
  }
  probabilities
}

///|
/// Draw one of the values of a distribution given by its probabilities.
///
/// The values of the distribution of the upstream are the numbers from minus
/// five to five, and the index of the probability is the index of the value.
fn choose_weighted(
  probabilities : Array[Double],
  random : @utils.Random,
) -> Int32 {
  let draw = random.next_double()
  let mut cumulative = 0.0
  for i in 0..<probabilities.length() {
    cumulative = cumulative + probabilities[i]
    if draw < cumulative {
      return i - 5
    }
  }
  probabilities.length() - 1 - 5
}

///|
/// The binary column of the given values.
///
/// This is the port of `dowhy.datasets.convert_to_binary`, which draws a
/// Bernoulli variate with the probability of the sigmoid of the value.
fn binary_column(
  values : Array[Double],
  random : @utils.Random,
) -> Array[Double] {
  let out : Array[Double] = []
  for value in values {
    let probability = @utils.sigmoid(value)
    out.push(if random.next_double() < probability { 1.0 } else { 0.0 })
  }
  out
}

///|
/// The values of a node, as the kind of its data asks for.
fn convert_column(
  kind : RandomVariableKind,
  values : Array[Double],
  random : @utils.Random,
) -> Array[Double] {
  match kind {
    Continuous => values
    Discrete => {
      let out : Array[Double] = []
      for value in values {
        out.push(value.trunc())
      }
      out
    }
    Binary => binary_column(values, random)
  }
}

///|
/// The values of a node that has parents.
///
/// This is the port of the linear model of the upstream, which adds the noise
/// of the node to the weighted sum of the values of its parents.
fn linear_values(
  graph : @graph.DirectedGraph,
  node : String,
  weights : Map[(String, String), Double],
  values : Map[String, Array[Double]],
  num_samples : Int32,
  random : @utils.Random,
) -> Array[Double] {
  let out : Array[Double] = []
  for _ in 0..<num_samples {
    out.push(random.next_normal())
  }
  let predecessors = graph.predecessors(node)
  for row in 0..<num_samples {
    let mut total = out[row]
    for predecessor in predecessors {
      let weight = weights.get((predecessor, node)).unwrap_or(0.0)
      total = total + parent_value(values, predecessor, row) * weight
    }
    out[row] = total
  }
  out
}

///|
/// The value of a row of a parent of a node.
fn parent_value(
  values : Map[String, Array[Double]],
  name : String,
  row : Int32,
) -> Double {
  match values.get(name) {
    Some(column) => column[row]
    None => 0.0
  }
}

///|
/// Whether every parent of a node has been generated.
fn all_predecessors_changed(
  graph : @graph.DirectedGraph,
  node : String,
  changed : Map[String, Bool],
) -> Bool {
  for predecessor in graph.predecessors(node) {
    if !changed.get(predecessor).unwrap_or(false) {
      return false
    }
  }
  true
}

///|
/// The graph in the GML format.
///
/// This is the port of `networkx.generate_gml`, which names every node after
/// its label and gives it the index of the node as its id.
fn graph_to_gml(graph : @graph.DirectedGraph) -> String {
  let nodes = graph.node_list()
  let mut out = "graph [\n  directed 1"
  let ids : Map[String, Int32] = Map([])
  for i in 0..<nodes.length() {
    ids.set(nodes[i], i)
    out = out +
      "\n  node [\n    id " +
      i.to_string() +
      "\n    label \"" +
      nodes[i] +
      "\"\n  ]"
  }
  for (from, to) in graph.edge_list() {
    let source = ids.get(from).unwrap_or(0)
    let target = ids.get(to).unwrap_or(0)
    out = out +
      "\n  edge [\n    source " +
      source.to_string() +
      "\n    target " +
      target.to_string() +
      "\n  ]"
  }
  out + "\n]"
}
