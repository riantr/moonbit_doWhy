///|
/// The networkx backend of the plotting layer.
///
/// This is the port of `dowhy.utils.networkx_plotting`. The upstream draws the
/// graph with `matplotlib` and the layout of `networkx`. The port computes the
/// attributes of the same drawing: the colour and the label of every node, the
/// colour and the width of every edge, the layer of every node and the size of
/// the figure.

///|
/// The plot of a causal graph, in the form the networkx backend of the
/// upstream builds.
pub struct NetworkxPlot {
  /// The nodes of the graph, in the order of the graph.
  nodes : Array[NetworkxNode]
  /// The edges of the graph, in the order of the graph.
  edges : Array[NetworkxEdge]
  /// The layer of every node of the graph.
  layers : Map[String, Int32]
  /// The width of the figure the upstream draws.
  figure_width : Double
  /// The height of the figure the upstream draws.
  figure_height : Double
}

///|
/// A node of a plot.
pub struct NetworkxNode {
  /// The name of the node.
  name : String
  /// The colour of the node.
  color : String
  /// The label of the node, with its words wrapped.
  label : String
}

///|
/// An edge of a plot.
pub struct NetworkxEdge {
  /// The name of the node the edge starts at.
  source : String
  /// The name of the node the edge ends at.
  target : String
  /// The colour of the edge.
  color : String
  /// The width of the edge.
  width : Double
  /// Whether the upstream draws the edge as a curve.
  ///
  /// The upstream draws the edges between two nodes of the same layer as
  /// curves, unless the two nodes are neighbours in their layer, which it
  /// draws as straight lines.
  curved : Bool
}

///|
/// The number of words of a label of a node that the upstream wraps.
///
/// The upstream wraps the label of a node when the word in front of it is
/// longer than this.
const LABEL_WRAP_LENGTH : Int32 = 3

///|
/// Whether the graph holds an edge whose source and whose target are the same
/// node.
///
/// This is the port of the check of
/// `dowhy.utils.networkx_plotting.plot_causal_graph_networkx`, which raises a
/// `ValueError` for such an edge. MoonBit cannot catch an abort, so the check
/// is a function of its own and the plot of the graph is `None`.
pub fn has_self_cycle(graph : @graph.DirectedGraph) -> Bool {
  for (source, target) in graph.edge_list() {
    if source == target {
      return true
    }
  }
  false
}

///|
/// The plot of a causal graph, in the form the networkx backend of the
/// upstream builds.
///
/// This is the port of
/// `dowhy.utils.networkx_plotting.plot_causal_graph_networkx`.
///
/// The upstream copies the strengths and the colours of the caller before it
/// reads them, so the plot does not change them. The port does the same: it
/// never writes into the maps of the caller.
///
/// The upstream takes the strength of an edge from the `CAUSAL_STRENGTH`
/// attribute of the edge when the caller gave none. The graph of the port holds
/// no attribute on its edges, so the strength of an edge is the one of the
/// caller, and an edge the caller gave no strength for has none.
///
/// The result is `None` when the graph holds a self-cycle, which the upstream
/// refuses to draw.
pub fn networkx_plot(
  graph : @graph.DirectedGraph,
  directed : Bool,
  causal_strengths : Map[(String, String), Double]?,
  node_colors : Map[String, String]?,
  edge_colors : Map[(String, String), String]?,
) -> NetworkxPlot? {
  if has_self_cycle(graph) {
    return None
  }
  let strengths = match causal_strengths {
    Some(values) => values.copy()
    None => Map([])
  }
  let colors = match edge_colors {
    Some(values) => values.copy()
    None => Map([])
  }
  let mut max_strength = 0.0
  for (source, target) in graph.edge_list() {
    match strengths.get((source, target)) {
      Some(strength) => {
        let magnitude = strength.abs()
        if magnitude > max_strength {
          max_strength = magnitude
        }
      }
      None => ()
    }
    if !colors.contains((source, target)) {
      colors.set((source, target), "gray")
    }
  }
  let layers = assign_layers(graph, directed)
  let positions = layer_positions(graph, layers)
  let nodes : Array[NetworkxNode] = []
  for name in graph.node_list() {
    let color = match node_colors {
      Some(values) =>
        match values.get(name) {
          Some(value) => value
          None => "skyblue"
        }
      None => "skyblue"
    }
    nodes.push({ name, color, label: wrap_label(name), })
  }
  let edges : Array[NetworkxEdge] = []
  for (source, target) in graph.edge_list() {
    let color = match colors.get((source, target)) {
      Some(value) => value
      None => "gray"
    }
    let width = match strengths.get((source, target)) {
      Some(strength) => arrow_width(strength, max_strength)
      None => 2.0
    }
    let source_layer = match layers.get(source) {
      Some(value) => value
      None => -1
    }
    let target_layer = match layers.get(target) {
      Some(value) => value
      None => -1
    }
    let curved = source_layer == target_layer &&
      !is_vertical_neighbour(positions, source, target)
    edges.push({ source, target, color, width, curved, })
  }
  let figure_width = max_double(2.0 * largest_layer(layers), 5.0)
  let figure_height = max_double(1.25 * count_nodes_vertically(layers), 5.0)
  Some({ nodes, edges, layers, figure_width, figure_height, })
}

///|
/// The label of a node, with its words wrapped.
///
/// This is the port of the wrapping of the labels of
/// `dowhy.utils.networkx_plotting.plot_causal_graph_networkx`. The upstream
/// breaks the line in front of a word when the word in front of it is longer
/// than three characters, and it joins the words with a space otherwise. The
/// word in front of a word is the one the upstream has already written, with
/// its break or its space, so the port measures that word.
fn wrap_label(name : String) -> String {
  let words : Array[String] = []
  for word in name.split(" ") {
    words.push(word.to_owned())
  }
  if words.length() == 0 {
    return ""
  }
  let mut text = words[0]
  let mut previous_length = words[0].length()
  for i in 1..<words.length() {
    if previous_length > LABEL_WRAP_LENGTH {
      text = text + "\n" + words[i]
    } else {
      text = text + " " + words[i]
    }
    previous_length = 1 + words[i].length()
  }
  text
}

///|
/// The layer of every node of the graph.
///
/// This is the port of
/// `dowhy.utils.networkx_plotting._custom_assign_layers`. The layer of a node
/// is the distance to the nearest root of the graph: the roots of a directed
/// graph are the nodes without a predecessor, and the root of an undirected
/// graph is the first node of every connected component.
///
/// The layer of a node no root reaches is `-1` in the port. The upstream gives
/// it an infinite distance.
fn assign_layers(
  graph : @graph.DirectedGraph,
  directed : Bool,
) -> Map[String, Int32] {
  let layers : Map[String, Int32] = Map([])
  let roots = if directed {
    root_nodes_of_directed(graph)
  } else {
    root_nodes_of_undirected(graph)
  }
  for node in graph.node_list() {
    let mut best = -1
    for root in roots {
      match shortest_distance(graph, root, node, directed) {
        Some(distance) => if best < 0 || distance < best { best = distance }
        None => ()
      }
    }
    layers.set(node, best)
  }
  layers
}

///|
/// The nodes of the graph without a predecessor.
fn root_nodes_of_directed(graph : @graph.DirectedGraph) -> Array[String] {
  let roots : Array[String] = []
  for node in graph.node_list() {
    if graph.predecessors(node).length() == 0 {
      roots.push(node)
    }
  }
  roots
}

///|
/// The first node of every connected component of the graph.
fn root_nodes_of_undirected(graph : @graph.DirectedGraph) -> Array[String] {
  let roots : Array[String] = []
  let seen : Set[String] = Set::Set([])
  for node in graph.node_list() {
    if !seen.contains(node) {
      roots.push(node)
      for other in connected_component(graph, node) {
        seen.add(other)
      }
    }
  }
  roots
}

///|
/// The nodes of the connected component of the given node.
fn connected_component(
  graph : @graph.DirectedGraph,
  start : String,
) -> Array[String] {
  let component : Array[String] = []
  let seen : Set[String] = Set::Set([start])
  let queue : Array[String] = [start]
  while queue.length() > 0 {
    let node = queue[queue.length() - 1]
    let _ = queue.pop()
    component.push(node)
    for neighbour in neighbours_of(graph, node, false) {
      if !seen.contains(neighbour) {
        seen.add(neighbour)
        queue.push(neighbour)
      }
    }
  }
  component
}

///|
/// The distance between two nodes of the graph, or `None` when there is no
/// path between them.
fn shortest_distance(
  graph : @graph.DirectedGraph,
  from : String,
  to : String,
  directed : Bool,
) -> Int32? {
  if from == to {
    return Some(0)
  }
  if !graph.has_node(from) || !graph.has_node(to) {
    return None
  }
  let seen : Set[String] = Set::Set([from])
  let mut queue : Array[String] = [from]
  let mut distance = 0
  while queue.length() > 0 {
    distance = distance + 1
    let next : Array[String] = []
    for node in queue {
      for neighbour in neighbours_of(graph, node, directed) {
        if neighbour == to {
          return Some(distance)
        }
        if !seen.contains(neighbour) {
          seen.add(neighbour)
          next.push(neighbour)
        }
      }
    }
    queue = next
  }
  None
}

///|
/// The neighbours of a node, in the direction of the edges when the graph is
/// directed and in both directions otherwise.
fn neighbours_of(
  graph : @graph.DirectedGraph,
  node : String,
  directed : Bool,
) -> Array[String] {
  if directed {
    graph.successors(node)
  } else {
    graph.successors(node) + graph.predecessors(node)
  }
}

///|
/// The place of every node of the graph in its layer.
///
/// The upstream lays the nodes of a layer out in the order of the graph and
/// reads the vertical neighbours of two nodes from that order.
fn layer_positions(
  graph : @graph.DirectedGraph,
  layers : Map[String, Int32],
) -> Map[String, Int32] {
  let counts : Map[Int32, Int32] = Map([])
  let positions : Map[String, Int32] = Map([])
  for node in graph.node_list() {
    let layer = match layers.get(node) {
      Some(value) => value
      None => -1
    }
    let index = match counts.get(layer) {
      Some(value) => value
      None => 0
    }
    positions.set(node, index)
    counts.set(layer, index + 1)
  }
  positions
}

///|
/// Whether the two nodes are neighbours in their layer.
fn is_vertical_neighbour(
  positions : Map[String, Int32],
  source : String,
  target : String,
) -> Bool {
  let source_place = match positions.get(source) {
    Some(value) => value
    None => return false
  }
  let target_place = match positions.get(target) {
    Some(value) => value
    None => return false
  }
  source_place == target_place + 1 || source_place == target_place - 1
}

///|
/// The larger of the two numbers.
fn max_double(left : Double, right : Double) -> Double {
  if left > right {
    left
  } else {
    right
  }
}

///|
/// The largest layer of the graph.
fn largest_layer(layers : Map[String, Int32]) -> Double {
  let mut largest = 0
  for node in layers.keys() {
    match layers.get(node) {
      Some(layer) => if layer > largest { largest = layer }
      None => ()
    }
  }
  largest.to_double()
}

///|
/// The largest number of nodes of a layer of the graph.
///
/// The upstream takes the maximum of the pairs of the number of the
/// nodes of a layer and of the number of the layer, so the result is
/// the largest of the numbers of the layers and of their counts. The
/// port does the same.
fn count_nodes_vertically(layers : Map[String, Int32]) -> Double {
  let counts : Map[Int32, Int32] = Map([])
  let mut largest = 0
  for node in layers.keys() {
    match layers.get(node) {
      Some(layer) => {
        if layer > largest {
          largest = layer
        }
        let count = match counts.get(layer) {
          Some(value) => value
          None => 0
        }
        counts.set(layer, count + 1)
      }
      None => ()
    }
  }
  for layer in counts.keys() {
    match counts.get(layer) {
      Some(count) => if count > largest { largest = count }
      None => ()
    }
  }
  largest.to_double()
}
