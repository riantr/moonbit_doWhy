///|
/// The plotting layer of the library.
///
/// This is the port of `dowhy.utils.plotting`, of
/// `dowhy.utils.graphviz_plotting` and of `dowhy.utils.networkx_plotting`.
///
/// The upstream draws a causal graph with Graphviz and falls back to
/// `matplotlib` when Graphviz is not installed. MoonBit has neither of them,
/// so the port computes the attributes the two backends compute: the width of
/// the arrow of an edge, the label and the colour of the nodes and of the
/// edges, the layer of every node and the uncertainty bars of a bar plot. The
/// attributes of the Graphviz backend are written as a Graphviz DOT document,
/// which Graphviz reads and draws.
///
/// The upstream keeps the strengths and the colours of a plot in dictionaries
/// that hold the nodes and the edges together, keyed by the name of a node and
/// by the pair of the names of an edge. The port keeps them apart, in a map of
/// the nodes and in a map of the edges, because MoonBit has no type that holds
/// two kinds of keys.

///|
/// The width of the arrow of an edge.
///
/// This is the port of `dowhy.utils.plotting._calc_arrow_width`. The width
/// grows with the strength of the edge, relative to the largest strength of
/// the graph, and it is `4.1` when the graph holds no strength at all.
///
/// The upstream raises a `ValueError` when the largest strength is negative.
/// MoonBit cannot catch an abort, so the port returns `None` for that case.
pub fn calc_arrow_width(strength : Double, max_strength : Double) -> Double? {
  if max_strength < 0.0 {
    return None
  }
  if max_strength == 0.0 {
    return Some(4.1)
  }
  Some(0.1 + 4.0 * strength.abs() / max_strength)
}

///|
/// The label of the arrow of an edge.
///
/// This is the port of the label the Graphviz backend of the upstream writes
/// on an edge, which is the strength of the edge truncated to two decimals.
/// The upstream truncates towards zero, so the label of the strength `0.29`
/// is ` 0.28`, and it writes a space in front of the number. The label of an
/// infinite strength is `Inf`, and it holds no space.
///
/// The text of a number is the text MoonBit writes, with a decimal point
/// added to an integral number. Python writes the numbers of a magnitude of
/// `1e16` and above in the scientific notation, and the port writes them in
/// the plain notation.
pub fn strength_label(strength : Double) -> String {
  if strength.is_inf() {
    return "Inf"
  }
  " " + float_text(truncated_strength(strength))
}

///|
/// The label of the arrow of an edge and the strength the width of
/// its arrow is computed from.
///
/// The upstream replaces an infinite strength by a strength of a
/// hundred before it computes the width of the arrow, and it keeps
/// the infinite strength for the label of the edge.
fn label_and_strength(strength : Double) -> (String, Double) {
  if strength.is_inf() {
    return ("Inf", 10000.0)
  }
  (" " + float_text(truncated_strength(strength)), strength)
}

///|
/// The strength of an edge, truncated to two decimals.
///
/// The upstream truncates the strength towards zero and divides it by a
/// hundred, so the strength `0.29` becomes `0.28`.
pub fn truncated_strength(strength : Double) -> Double {
  (strength * 100.0).trunc() / 100.0
}

///|
/// The text of a number, the way Python writes it.
///
/// MoonBit writes an integral number without a decimal point, and Python
/// writes one with it.
fn float_text(value : Double) -> String {
  if value.is_nan() {
    return "nan"
  }
  if value.is_inf() {
    return if value > 0.0 { "inf" } else { "-inf" }
  }
  let text = value.to_string()
  if text.contains(".") || text.contains("e") || text.contains("E") {
    return text
  }
  text + ".0"
}

///|
/// The bars of a bar plot, with the uncertainty of every bar.
///
/// This is the port of the data `dowhy.utils.plotting.bar_plot` hands to
/// `matplotlib`. The upstream draws the bars; the port computes them.
pub struct BarPlot {
  /// The label of every bar, in the order of the bars.
  labels : Array[String]
  /// The value of every bar, in the order of the bars.
  values : Array[Double]
  /// The length of the error bar below every bar.
  ci_minus : Array[Double]
  /// The length of the error bar above every bar.
  ci_plus : Array[Double]
  /// The label of the y-axis.
  ylabel : String
  /// The width of the bars.
  bar_width : Double
  /// The labels of the ticks of the x-axis.
  xticks : Array[String]?
  /// The rotation of the labels of the ticks of the x-axis.
  xticks_rotation : Int32
}

///|
/// The bar plot of the given values, with the uncertainty of every bar.
///
/// This is the port of `dowhy.utils.plotting.bar_plot`.
///
/// The upstream takes a dictionary of values, whose order is the order of its
/// keys, so the port takes an ordered list of pairs. A bar whose uncertainty
/// the caller did not give has no error bar, and an error bar that reaches
/// below the value of its bar is dropped, like the upstream drops it.
///
/// The upstream writes the bars it does not have an uncertainty for into the
/// dictionary of the uncertainties of the caller. The port reads the dictionary
/// and never writes into it.
///
/// The upstream places the ticks of the x-axis at the keys of the dictionary of
/// the uncertainties, which are strings, and `matplotlib` refuses them. The
/// port places them at the bars, in the order of the values.
pub fn bar_plot(
  values : Array[(String, Double)],
  uncertainties : Map[String, (Double, Double)]?,
  ylabel~ : String = "",
  bar_width~ : Double = 0.8,
  xticks~ : Array[String]? = None,
  xticks_rotation~ : Int32 = 90,
  sort_names~ : Bool = false,
) -> BarPlot {
  let entries = if sort_names { sorted_values(values) } else { values.copy() }
  let labels : Array[String] = []
  let bars : Array[Double] = []
  let ci_minus : Array[Double] = []
  let ci_plus : Array[Double] = []
  for (name, value) in entries {
    labels.push(name)
    bars.push(value)
    let (low, high) = match uncertainties {
      Some(bounds) =>
        match bounds.get(name) {
          Some(pair) => pair
          None => (value, value)
        }
      None => (value, value)
    }
    let mut minus = value - low
    let mut plus = high - value
    if minus < 0.0 || plus < 0.0 {
      minus = 0.0
      plus = 0.0
    }
    ci_minus.push(minus)
    ci_plus.push(plus)
  }
  let mut ticks : Array[String]? = None
  match xticks {
    Some(names) => {
      let sorted = if sort_names { sorted_names(names) } else { names.copy() }
      ticks = Some(sorted)
    }
    None => ()
  }
  {
    labels,
    values: bars,
    ci_minus,
    ci_plus,
    ylabel,
    bar_width,
    xticks: ticks,
    xticks_rotation,
  }
}

///|
/// The values of a bar plot, in the order of their names.
fn sorted_values(values : Array[(String, Double)]) -> Array[(String, Double)] {
  let sorted = values.copy()
  sorted.sort_by(fn(left, right) { left.0.lexical_compare(right.0) })
  sorted
}

///|
/// The names of the ticks of a bar plot, in their order.
fn sorted_names(names : Array[String]) -> Array[String] {
  let sorted = names.copy()
  sorted.sort_by(fn(left, right) { left.lexical_compare(right) })
  sorted
}

///|
/// The plot of a causal graph.
///
/// This is the port of `dowhy.utils.plotting.plot`. The upstream draws the
/// graph with Graphviz and falls back to `matplotlib` when Graphviz is not
/// installed. The port has no drawing, so it computes the attributes of the
/// Graphviz backend, which is the backend the upstream prefers, and writes
/// them as a Graphviz DOT document.
///
/// The upstream takes the layout, the name of the file and the size of the
/// figure; the port ignores them, because it draws nothing.
pub fn plot(
  graph : @graph.DirectedGraph,
  directed : Bool,
  causal_strengths : Map[(String, String), Double]?,
  node_colors : Map[String, String]?,
  edge_colors : Map[(String, String), String]?,
) -> GraphPlot {
  graphviz_plot(graph, directed, causal_strengths, node_colors, edge_colors)
}

///|
/// The plot of the graph of an adjacency matrix.
///
/// This is the port of `dowhy.utils.plotting.plot_adjacency_matrix`, which
/// builds the graph of the matrix with `nx.from_pandas_adjacency` and draws
/// it.
///
/// The matrix of the upstream is a `pandas.DataFrame` whose index holds the
/// names of the nodes. The frame of the port has no index, so the names of its
/// columns are the names of the nodes, and the matrix has to be square.
pub fn plot_adjacency_matrix(
  frame : @api.DataFrame,
  is_directed : Bool,
) -> GraphPlot {
  let labels = frame.column_names()
  let matrix = adjacency_matrix_of(frame, labels)
  let graph = graph_of_adjacency_matrix(labels, matrix, is_directed)
  plot(graph, is_directed, None, None, None)
}

///|
/// The graph of an adjacency matrix.
///
/// This is the port of `nx.from_pandas_adjacency`, which the upstream uses in
/// `plot_adjacency_matrix`. Every name of the matrix is a node of the graph,
/// and two names are joined by an edge when the entry of the matrix at their
/// row and their column is not zero.
///
/// The upstream keeps a single edge between two nodes of an undirected graph,
/// and the port does the same.
pub fn graph_of_adjacency_matrix(
  labels : Array[String],
  matrix : Array[Array[Double]],
  is_directed : Bool,
) -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  for name in labels {
    graph.add_node(name)
  }
  for i in 0..<labels.length() {
    if i >= matrix.length() {
      break
    }
    let row = matrix[i]
    for j in 0..<labels.length() {
      if j >= row.length() {
        break
      }
      if row[j] != 0.0 {
        if is_directed {
          graph.add_edge(labels[i], labels[j])
        } else if !graph.has_edge(labels[j], labels[i]) {
          graph.add_edge(labels[i], labels[j])
        }
      }
    }
  }
  graph
}

///|
/// The matrix of the given columns of the frame, in the order of the names.
fn adjacency_matrix_of(
  frame : @api.DataFrame,
  labels : Array[String],
) -> Array[Array[Double]] {
  let matrix : Array[Array[Double]] = []
  for name in labels {
    matrix.push(frame.numeric(name))
  }
  matrix
}
