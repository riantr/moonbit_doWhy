///|
/// The Graphviz backend of the plotting layer.
///
/// This is the port of `dowhy.utils.graphviz_plotting`. The upstream builds a
/// `pygraphviz.AGraph` and hands it to Graphviz, which draws it. The port
/// computes the attributes of the same graph and writes them as a Graphviz
/// DOT document.

///|
/// The plot of a causal graph, in the form the Graphviz backend of the
/// upstream builds.
pub struct GraphPlot {
  /// The nodes of the graph, in the order of the graph.
  nodes : Array[PlotNode]
  /// The edges of the graph, in the order of the graph.
  edges : Array[PlotEdge]
  /// Whether the graph is directed.
  directed : Bool
  /// The largest absolute strength of the edges of the graph.
  max_strength : Double
}

///|
/// A node of a plot.
pub struct PlotNode {
  /// The name of the node.
  name : String
  /// The colour of the node. It is absent when the caller gave no colour.
  color : String?
  /// The colour of the label of the node. It is absent when the caller gave no
  /// colour.
  fontcolor : String?
}

///|
/// An edge of a plot.
pub struct PlotEdge {
  /// The name of the node the edge starts at.
  source : String
  /// The name of the node the edge ends at.
  target : String
  /// The colour of the edge.
  color : String
  /// The label of the edge, which is the strength of the edge truncated to two
  /// decimals. It is absent when the edge has no strength.
  label : String?
  /// The width of the arrow of the edge. It is absent when the edge has no
  /// strength.
  penwidth : Double?
}

///|
/// The plot of a causal graph, in the form the Graphviz backend of the
/// upstream builds.
///
/// This is the port of
/// `dowhy.utils.graphviz_plotting.plot_causal_graph_graphviz`.
///
/// The upstream copies the strengths and the colours of the caller before it
/// reads them, so the plot does not change them. The port does the same: it
/// never writes into the maps of the caller.
///
/// The upstream takes the strength of an edge from the `CAUSAL_STRENGTH`
/// attribute of the edge when the caller gave none. The graph of the port holds
/// no attribute on its edges, so the strength of an edge is the one of the
/// caller, and an edge the caller gave no strength for has none.
pub fn graphviz_plot(
  graph : @graph.DirectedGraph,
  directed : Bool,
  causal_strengths : Map[(String, String), Double]?,
  node_colors : Map[String, String]?,
  edge_colors : Map[(String, String), String]?,
) -> GraphPlot {
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
      colors.set((source, target), "black")
    }
  }
  let nodes : Array[PlotNode] = []
  for name in graph.node_list() {
    let color = match node_colors {
      Some(values) => values.get(name)
      None => None
    }
    nodes.push({ name, color, fontcolor: color, })
  }
  let edges : Array[PlotEdge] = []
  for (source, target) in graph.edge_list() {
    let color = match colors.get((source, target)) {
      Some(value) => value
      None => "black"
    }
    match strengths.get((source, target)) {
      Some(strength) => {
        let (label, value) = label_and_strength(strength)
        let width = arrow_width(value, max_strength)
        edges.push({
          source,
          target,
          color,
          label: Some(label),
          penwidth: Some(width),
        })
      }
      None =>
        edges.push({ source, target, color, label: None, penwidth: None, })
    }
  }
  { nodes, edges, directed, max_strength, }
}

///|
/// The width of the arrow of an edge, when the largest strength of the graph
/// is not negative.
fn arrow_width(strength : Double, max_strength : Double) -> Double {
  if max_strength == 0.0 {
    return 4.1
  }
  0.1 + 4.0 * strength.abs() / max_strength
}

///|
/// The graph of the plot, in the Graphviz DOT format.
///
/// The upstream hands the graph to Graphviz, which draws it. The port writes
/// the same attributes as a DOT document, which Graphviz reads and draws.
pub fn GraphPlot::to_dot(self : GraphPlot) -> String {
  let mut out = if self.directed { "digraph {\n" } else { "graph {\n" }
  for node in self.nodes {
    out = out + "  \"" + node.name + "\""
    match node.color {
      Some(color) =>
        out = out + " [color=\"" + color + "\", fontcolor=\"" + color + "\"]"
      None => ()
    }
    out = out + ";\n"
  }
  let arrow = if self.directed { " -> " } else { " -- " }
  for edge in self.edges {
    out = out + "  \"" + edge.source + "\"" + arrow + "\"" + edge.target + "\""
    let mut attributes = ""
    match edge.label {
      Some(label) => attributes = attributes + "label=\"" + label + "\", "
      None => ()
    }
    match edge.penwidth {
      Some(width) =>
        attributes = attributes + "penwidth=\"" + float_text(width) + "\", "
      None => ()
    }
    attributes = attributes + "color=\"" + edge.color + "\""
    out = out + " [" + attributes + "];\n"
  }
  out + "}\n"
}
