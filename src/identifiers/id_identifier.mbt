///|
/// The ID algorithm of the `identifiers` package.
///
/// This is the port of `dowhy.causal_identifier.id_identifier`, the algorithm
/// of Shpitser and Pearl (2006). The algorithm returns the estimand of the
/// effect of a treatment on an outcome as a product of conditional
/// distributions, together with the variables the product has to be summed
/// over.
///
/// The upstream keeps the variables of a sum in a Python `set`, so their order
/// changes between the runs of the interpreter. The port keeps them in the
/// order of the nodes of the graph, so its estimand does not change.

///|
/// The message that the graph is not a directed acyclic graph.
pub const ID_NOT_A_DAG : String = "the graph must be a directed acyclic graph (DAG)"

///|
/// The message that the effect is not identifiable.
pub const ID_NOT_IDENTIFIABLE : String = "the graph is not identifiable"

///|
/// One factor of the estimand: the distribution of the outcome variables
/// given the condition variables.
pub struct IDPredictor {
  outcome_vars : Array[String]
  condition_vars : Array[String]
}

///|
/// A new predictor of the given variables.
pub fn IDPredictor::new(
  outcome_vars : Array[String],
  condition_vars : Array[String],
) -> IDPredictor {
  { outcome_vars, condition_vars, }
}

///|
/// The variables the predictor is the distribution of.
pub fn IDPredictor::outcome_vars(self : IDPredictor) -> Array[String] {
  self.outcome_vars.copy()
}

///|
/// The variables the predictor is conditioned on.
pub fn IDPredictor::condition_vars(self : IDPredictor) -> Array[String] {
  self.condition_vars.copy()
}

///|
/// One element of a product: a predictor or a nested expression.
///
/// The upstream holds the two kinds of element in one list, and tells them
/// apart by their type. The port holds them in one struct, and the element
/// with a predictor is the one without an expression.
pub struct IDElement {
  predictor : IDPredictor?
  expression : IDExpression?
}

///|
/// An element that is a predictor.
pub fn IDElement::of_predictor(predictor : IDPredictor) -> IDElement {
  { predictor: Some(predictor), expression: None, }
}

///|
/// An element that is a nested expression.
pub fn IDElement::of_expression(expression : IDExpression) -> IDElement {
  { predictor: None, expression: Some(expression), }
}

///|
/// The predictor of the element, when it has one.
pub fn IDElement::as_predictor(self : IDElement) -> IDPredictor? {
  self.predictor
}

///|
/// The expression of the element, when it has one.
pub fn IDElement::as_expression(self : IDElement) -> IDExpression? {
  self.expression
}

///|
/// The estimand of the ID algorithm.
///
/// The estimand holds the factors of the product and the variables the
/// product has to be summed over.
pub struct IDExpression {
  product : Array[IDElement]
  sum : Array[String]
}

///|
/// A new expression without any factor.
pub fn IDExpression::new() -> IDExpression {
  { product: [], sum: [], }
}

///|
/// Add a factor to the product.
pub fn IDExpression::add_product(
  self : IDExpression,
  element : IDElement,
) -> Unit {
  self.product.push(element)
}

///|
/// Add the given variables to the sum.
pub fn IDExpression::add_sum(
  self : IDExpression,
  variables : Array[String],
) -> Unit {
  for name in variables {
    self.sum.push(name)
  }
}

///|
/// The factors of the product.
pub fn IDExpression::product(self : IDExpression) -> Array[IDElement] {
  self.product.copy()
}

///|
/// The variables the product has to be summed over.
pub fn IDExpression::sum(self : IDExpression) -> Array[String] {
  self.sum.copy()
}

///|
/// The string of the estimand, the way the upstream prints it.
///
/// The string is the sum of the variables, if there are any, and then one line
/// per factor of the product.
pub fn IDExpression::to_string(self : IDExpression) -> String {
  print_expression("", self)
}

///|
/// The string of an expression and of the factors of its product.
fn print_expression(prefix : String, expression : IDExpression) -> String {
  let mut text = ""
  let mut inner = prefix
  if expression.sum.length() > 0 {
    text = prefix + "Sum over {" + expression.sum.join(",") + "}:\n"
    inner = prefix + "\t"
  }
  let mut first = true
  for element in expression.product {
    if !first {
      text = text + "\n"
    }
    first = false
    text = text + print_element(inner, element)
  }
  text
}

///|
/// The string of one factor of a product.
fn print_element(prefix : String, element : IDElement) -> String {
  match element.expression {
    Some(expression) => print_expression(prefix, expression)
    None => {
      let predictor = element.predictor.unwrap()
      let mut text = prefix + "Predictor: P(" + predictor.outcome_vars.join(",")
      if predictor.condition_vars.length() > 0 {
        text = text + "|" + predictor.condition_vars.join(",")
      }
      text + ")"
    }
  }
}

///|
/// The estimand of the effect of the treatment on the outcome.
///
/// The first component holds the estimand, the second one an error message
/// that is empty when the search succeeded. The graph has to be a directed
/// acyclic graph, and the effect has to be identifiable.
pub fn identify_effect_id(
  graph : @graph.DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
) -> (IDExpression?, String) {
  if !graph.is_dag() {
    return (None, ID_NOT_A_DAG)
  }
  let tsort_node_names = graph.topological_order()
  let node_names = graph.node_list()
  identify_effect_of_graph(
    graph,
    action_nodes.copy(),
    outcome_nodes.copy(),
    tsort_node_names,
    node_names,
  )
}

///|
/// The estimand of the effect of the treatment on the outcome.
///
/// This is the port of `__adjacency_matrix_identify_effect` of the upstream.
/// The upstream works on an adjacency matrix, and the port works on the graph
/// and on the list of the nodes of the problem.
fn identify_effect_of_graph(
  graph : @graph.DirectedGraph,
  treatment_name : Array[String],
  outcome_name : Array[String],
  tsort_node_names : Array[String],
  node_names : Array[String],
) -> (IDExpression?, String) {
  // Line 1. Without a treatment the effect on the outcome is the marginal of
  // the observational distribution.
  if treatment_name.length() == 0 {
    let identifier = IDExpression::new()
    identifier.add_product(
      IDElement::of_predictor(IDPredictor::new(node_names.copy(), [])),
    )
    identifier.add_sum(difference(node_names, to_set(outcome_name)))
    let estimators = IDExpression::new()
    estimators.add_product(IDElement::of_expression(identifier))
    return (Some(estimators), "")
  }
  // Line 2. It is enough to look at the parts of the model that are ancestral
  // to the outcome.
  let ancestors = find_ancestor(graph, outcome_name)
  if difference(node_names, ancestors).length() > 0 {
    let treatment = intersection(treatment_name, ancestors)
    let nodes = intersection(node_names, ancestors)
    return identify_effect_of_graph(
      graph.subgraph(nodes),
      treatment,
      outcome_name,
      tsort_node_names,
      nodes,
    )
  }
  // Line 3. An action on a node that has no effect on the outcome is forced.
  let do_graph = do_graph_of(graph, treatment_name)
  let ancestors_do = find_ancestor(do_graph, outcome_name)
  let w = difference(
    difference(node_names, to_set(treatment_name)),
    ancestors_do,
  )
  if w.length() > 0 {
    let treatment = union(treatment_name, w)
    return identify_effect_of_graph(
      graph, treatment, outcome_name, tsort_node_names, node_names,
    )
  }
  // Line 4. The problem is split into the problems of the C-components.
  let nodes_minus_x = difference(node_names, to_set(treatment_name))
  let components = c_components(graph.subgraph(nodes_minus_x), nodes_minus_x)
  if components.length() > 1 {
    let identifier = IDExpression::new()
    let sum_over = difference(
      node_names,
      to_set(union(outcome_name, treatment_name)),
    )
    for component in components {
      let (expressions, message) = identify_effect_of_graph(
        graph,
        difference(node_names, to_set(component)),
        component,
        tsort_node_names,
        node_names,
      )
      match expressions {
        Some(expression) =>
          for element in expression.product {
            identifier.add_product(element)
          }
        None => return (None, message)
      }
    }
    identifier.add_sum(sum_over)
    let estimators = IDExpression::new()
    estimators.add_product(IDElement::of_expression(identifier))
    return (Some(estimators), "")
  }
  // Line 5. The algorithm fails when the graph has a hedge.
  let s = components[0]
  let components_g = c_components(graph, node_names)
  if components_g.length() == 1 && same_set(components_g[0], node_names) {
    return (None, ID_NOT_IDENTIFIABLE)
  }
  // Line 6. The component is a C-component of the graph, so the effect is the
  // product of the conditional distributions of its nodes.
  if contains_component(components_g, s) {
    let sum_over = difference(s, to_set(outcome_name))
    let estimators = IDExpression::new()
    let prev_nodes : Array[String] = []
    for node in tsort_node_names {
      if s.contains(node) {
        let identifier = IDExpression::new()
        identifier.add_product(
          IDElement::of_predictor(IDPredictor::new([node], prev_nodes.copy())),
        )
        identifier.add_sum(sum_over.copy())
        estimators.add_product(IDElement::of_expression(identifier))
      }
      prev_nodes.push(node)
    }
    return (Some(estimators), "")
  }
  // Line 7. The upstream stops here: the case is the one of a hedge that the
  // upstream does not handle, and the effect is not identifiable.
  (None, ID_NOT_IDENTIFIABLE)
}

///|
/// The ancestors of the given nodes, the nodes themselves included.
fn find_ancestor(
  graph : @graph.DirectedGraph,
  nodes : Array[String],
) -> Set[String] {
  let ancestors : Set[String] = Set::Set([])
  for node in nodes {
    let stack : Array[String] = [node]
    while stack.length() > 0 {
      let current = stack[stack.length() - 1]
      let _ = stack.pop()
      if !ancestors.contains(current) {
        ancestors.add(current)
        for parent in graph.predecessors(current) {
          if !ancestors.contains(parent) {
            stack.push(parent)
          }
        }
      }
    }
  }
  ancestors
}

///|
/// The graph of the intervention on the given nodes: the edges that point into
/// them are removed.
fn do_graph_of(
  graph : @graph.DirectedGraph,
  nodes : Array[String],
) -> @graph.DirectedGraph {
  let result = graph.copy()
  for node in nodes {
    for parent in graph.predecessors(node) {
      result.remove_edge(parent, node)
    }
  }
  result
}

///|
/// The C-components of the graph: the connected components of the subgraph of
/// the edges that point in both directions.
fn c_components(
  graph : @graph.DirectedGraph,
  node_set : Array[String],
) -> Array[Array[String]] {
  let adjacency : Map[String, Array[String]] = Map([])
  for node in node_set {
    adjacency.set(node, [])
  }
  for i in 0..<(node_set.length() - 1) {
    for j in (i + 1)..<node_set.length() {
      let first = node_set[i]
      let second = node_set[j]
      if graph.has_edge(first, second) && graph.has_edge(second, first) {
        let first_neighbours = adjacency.get(first).unwrap_or([]).copy()
        first_neighbours.push(second)
        adjacency.set(first, first_neighbours)
        let second_neighbours = adjacency.get(second).unwrap_or([]).copy()
        second_neighbours.push(first)
        adjacency.set(second, second_neighbours)
      }
    }
  }
  let components : Array[Array[String]] = []
  let visited : Set[String] = Set::Set([])
  for node in node_set {
    if !visited.contains(node) {
      let component : Array[String] = []
      collect_component(node, adjacency, visited, component)
      components.push(component)
    }
  }
  components
}

///|
/// The connected component of the node in the graph of the bidirected edges.
fn collect_component(
  node : String,
  adjacency : Map[String, Array[String]],
  visited : Set[String],
  component : Array[String],
) -> Unit {
  visited.add(node)
  component.push(node)
  for neighbour in adjacency.get(node).unwrap_or([]) {
    if !visited.contains(neighbour) {
      collect_component(neighbour, adjacency, visited, component)
    }
  }
}

///|
/// Whether the list of the components holds the given component.
fn contains_component(
  components : Array[Array[String]],
  component : Array[String],
) -> Bool {
  for candidate in components {
    if same_set(candidate, component) {
      return true
    }
  }
  false
}

///|
/// Whether two lists hold the same variables, regardless of their order.
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
/// The variables of the list as a set.
fn to_set(names : Array[String]) -> Set[String] {
  let set : Set[String] = Set::Set([])
  for name in names {
    set.add(name)
  }
  set
}

///|
/// The variables of the list that are not in the set, in the order of the
/// list.
fn difference(left : Array[String], right : Set[String]) -> Array[String] {
  let result : Array[String] = []
  for name in left {
    if !right.contains(name) {
      result.push(name)
    }
  }
  result
}

///|
/// The variables of the list that are in the set, in the order of the list.
fn intersection(left : Array[String], right : Set[String]) -> Array[String] {
  let result : Array[String] = []
  for name in left {
    if right.contains(name) {
      result.push(name)
    }
  }
  result
}

///|
/// The variables of the two lists, the ones of the first list first.
fn union(left : Array[String], right : Array[String]) -> Array[String] {
  let result = left.copy()
  for name in right {
    if !result.contains(name) {
      result.push(name)
    }
  }
  result
}
