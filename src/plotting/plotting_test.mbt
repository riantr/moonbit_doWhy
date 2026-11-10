/// The tests of the plotting layer of the library.
///
/// This file is the port of `tests/utils/test_plotting.py` of the upstream.
///
/// The upstream draws the graphs and the bar plots with Graphviz and with
/// `matplotlib`, so its tests check that the drawing does not raise. The port
/// draws nothing, so its tests check the attributes the upstream computes:
/// the width of the arrows, the labels and the colours of the nodes and of the
/// edges, the layers of the nodes and the uncertainty bars.
///
/// The upstream keeps the strengths and the colours of a plot in dictionaries
/// that hold the nodes and the edges together. The port keeps them apart, in a
/// map of the nodes and in a map of the edges.

///|
/// The graph of the fixture of the upstream: `X -> Y -> Z`.
fn fixture_graph() -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X", "Y")
  graph.add_edge("Y", "Z")
  graph
}

///|
/// The frame of the fixture of the upstream: the matrix
/// `[[0, 1, 0], [0, 0, 1], [0, 0, 0]]`.
fn fixture_frame() -> @api.DataFrame {
  @api.DataFrame::from_numeric(
    ["X", "Y", "Z"],
    Map([("X", [0.0, 1.0, 0.0]), ("Y", [0.0, 0.0, 1.0]), ("Z", [0.0, 0.0, 0.0])]),
  )
}

///|
/// The width of an arrow, when the port computes one.
fn arrow_width_of(strength : Double, max_strength : Double) -> Double {
  match @plotting.calc_arrow_width(strength, max_strength) {
    Some(width) => width
    None => abort("the port refused the width of the arrow")
  }
}

///|
/// The width of an arrow is the width the upstream computes.
test "the width of an arrow" {
  assert_true((arrow_width_of(0.4, 0.5) - 3.3).abs() < 0.01)
  assert_true((arrow_width_of(0.2, 0.5) - 1.7).abs() < 0.01)
  assert_true((arrow_width_of(-0.2, 0.5) - 1.7).abs() < 0.01)
  assert_true((arrow_width_of(0.5, 0.5) - 4.1).abs() < 0.01)
  assert_true((arrow_width_of(0.35, 0.5) - 2.9).abs() < 0.01)
  assert_true((arrow_width_of(100.0, 101.0) - 4.06).abs() < 0.01)
  assert_true((arrow_width_of(100.0, 0.0) - 4.1).abs() < 0.01)
  // The upstream raises a `ValueError` when the largest strength is negative.
  // The port cannot catch an abort, so the width is absent.
  match @plotting.calc_arrow_width(100.0, -1.0) {
    Some(_) => assert_true(false)
    None => ()
  }
}

///|
/// The plot of a graph holds its nodes and its edges.
test "the plot of a graph does not raise" {
  let graph = fixture_graph()
  let plot = @plotting.plot(graph, true, None, None, None)
  assert_eq(plot.nodes.length(), 3)
  assert_eq(plot.edges.length(), 2)
  assert_eq(plot.nodes[0].name, "X")
  assert_eq(plot.nodes[1].name, "Y")
  assert_eq(plot.nodes[2].name, "Z")
  assert_eq(plot.edges[0].source, "X")
  assert_eq(plot.edges[0].target, "Y")
  assert_eq(plot.edges[1].source, "Y")
  assert_eq(plot.edges[1].target, "Z")
}

///|
/// The plot of the graph of an adjacency matrix holds the nodes and the edges
/// of the matrix.
test "the plot of an adjacency matrix" {
  let frame = fixture_frame()
  let plot = @plotting.plot_adjacency_matrix(frame, true)
  assert_eq(plot.nodes.length(), 3)
  assert_eq(plot.edges.length(), 2)
  assert_eq(plot.nodes[0].name, "X")
  assert_eq(plot.edges[0].source, "X")
  assert_eq(plot.edges[0].target, "Y")
  assert_eq(plot.edges[1].source, "Y")
  assert_eq(plot.edges[1].target, "Z")
  // The graph of an undirected matrix keeps a single edge between two nodes.
  let undirected = @plotting.plot_adjacency_matrix(frame, false)
  assert_eq(undirected.nodes.length(), 3)
  assert_eq(undirected.edges.length(), 2)
  assert_eq(undirected.edges[0].source, "X")
  assert_eq(undirected.edges[0].target, "Y")
}

///|
/// The plot of a graph does not change the strengths of the caller.
test "the plot of a graph does not change the strengths of the caller" {
  let graph = fixture_graph()
  let strengths : Map[(String, String), Double] = Map([(("X", "Y"), 10.0)])
  let plot = @plotting.plot(graph, true, Some(strengths), None, None)
  assert_eq(strengths.length(), 1)
  match strengths.get(("X", "Y")) {
    Some(strength) => assert_true((strength - 10.0).abs() < 0.000000000001)
    None => assert_true(false)
  }
  assert_eq(plot.max_strength, 10.0)
}

///|
/// The plot of a graph does not change the colours of the caller.
test "the plot of a graph does not change the colours of the caller" {
  let graph = fixture_graph()
  let node_colors : Map[String, String] = Map([("X", "blue")])
  let edge_colors : Map[(String, String), String] = Map([(("X", "Y"), "red")])
  let plot = @plotting.plot(
    graph,
    true,
    None,
    Some(node_colors),
    Some(edge_colors),
  )
  assert_eq(node_colors.length(), 1)
  assert_eq(edge_colors.length(), 1)
  match node_colors.get("X") {
    Some(color) => assert_eq(color, "blue")
    None => assert_true(false)
  }
  match edge_colors.get(("X", "Y")) {
    Some(color) => assert_eq(color, "red")
    None => assert_true(false)
  }
  assert_eq(plot.nodes.length(), 3)
}

///|
/// The attributes the Graphviz backend of the upstream computes.
test "the attributes of the graphviz backend" {
  let graph = fixture_graph()
  // The upstream writes the label of the edge and the width of its arrow, and
  // it gives every edge the colour black.
  let strengths : Map[(String, String), Double] = Map([(("X", "Y"), 10.0)])
  let plot = @plotting.graphviz_plot(graph, true, Some(strengths), None, None)
  assert_eq(plot.edges[0].color, "black")
  match plot.edges[0].label {
    Some(label) => assert_eq(label, " 10.0")
    None => assert_true(false)
  }
  match plot.edges[0].penwidth {
    Some(width) => assert_true((width - 4.1).abs() < 0.000000000001)
    None => assert_true(false)
  }
  // An edge without a strength holds no label and no width.
  match plot.edges[1].label {
    Some(_) => assert_true(false)
    None => ()
  }
  match plot.edges[1].penwidth {
    Some(_) => assert_true(false)
    None => ()
  }
  assert_eq(plot.edges[1].color, "black")
  // The upstream truncates the strength towards zero.
  let weak : Map[(String, String), Double] = Map([(("X", "Y"), 0.29)])
  let weak_plot = @plotting.graphviz_plot(graph, true, Some(weak), None, None)
  match weak_plot.edges[0].label {
    Some(label) => assert_eq(label, " 0.28")
    None => assert_true(false)
  }
  // The upstream writes the label of an infinite strength and draws its arrow
  // with the width of the strength of a hundred.
  let infinite : Map[(String, String), Double] = Map([(("X", "Y"), 1.0 / 0.0)])
  let infinite_plot = @plotting.graphviz_plot(
    graph,
    true,
    Some(infinite),
    None,
    None,
  )
  match infinite_plot.edges[0].label {
    Some(label) => assert_eq(label, "Inf")
    None => assert_true(false)
  }
  match infinite_plot.edges[0].penwidth {
    Some(width) => assert_true((width - 0.1).abs() < 0.000000000001)
    None => assert_true(false)
  }
  // The upstream colours the nodes and the edges the caller asked for, and it
  // leaves the other nodes without a colour.
  let node_colors : Map[String, String] = Map([("X", "blue")])
  let edge_colors : Map[(String, String), String] = Map([(("X", "Y"), "red")])
  let colored = @plotting.graphviz_plot(
    graph,
    true,
    None,
    Some(node_colors),
    Some(edge_colors),
  )
  match colored.nodes[0].color {
    Some(color) => assert_eq(color, "blue")
    None => assert_true(false)
  }
  match colored.nodes[0].fontcolor {
    Some(color) => assert_eq(color, "blue")
    None => assert_true(false)
  }
  match colored.nodes[1].color {
    Some(_) => assert_true(false)
    None => ()
  }
  assert_eq(colored.edges[0].color, "red")
  assert_eq(colored.edges[1].color, "black")
}

///|
/// The graph of a plot is a Graphviz DOT document.
test "the graph of a plot is a dot document" {
  let graph = fixture_graph()
  let strengths : Map[(String, String), Double] = Map([(("X", "Y"), 10.0)])
  let plot = @plotting.graphviz_plot(graph, true, Some(strengths), None, None)
  let dot = plot.to_dot()
  assert_true(dot.has_prefix("digraph {"))
  assert_true(dot.contains("\"X\" -> \"Y\""))
  assert_true(dot.contains("label=\" 10.0\""))
  assert_true(dot.contains("penwidth=\"4.1\""))
  assert_true(dot.contains("color=\"black\""))
  assert_true(dot.has_suffix("}\n"))
}

///|
/// The attributes the networkx backend of the upstream computes.
test "the attributes of the networkx backend" {
  let graph = fixture_graph()
  let strengths : Map[(String, String), Double] = Map([(("X", "Y"), 10.0)])
  let plot = match
    @plotting.networkx_plot(graph, true, Some(strengths), None, None) {
    Some(value) => value
    None => abort("the port refused the plot of the graph")
  }
  // The upstream gives every node the colour skyblue and every edge the
  // colour gray.
  assert_eq(plot.nodes[0].color, "skyblue")
  assert_eq(plot.nodes[1].color, "skyblue")
  assert_eq(plot.nodes[2].color, "skyblue")
  assert_eq(plot.edges[0].color, "gray")
  assert_eq(plot.edges[1].color, "gray")
  // The upstream draws an edge without a strength with the width of two.
  assert_true((plot.edges[0].width - 4.1).abs() < 0.000000000001)
  assert_true((plot.edges[1].width - 2.0).abs() < 0.000000000001)
  // The upstream lays the nodes out in layers, and the layer of a node is the
  // distance to the nearest root of the graph.
  match plot.layers.get("X") {
    Some(layer) => assert_eq(layer, 0)
    None => assert_true(false)
  }
  match plot.layers.get("Y") {
    Some(layer) => assert_eq(layer, 1)
    None => assert_true(false)
  }
  match plot.layers.get("Z") {
    Some(layer) => assert_eq(layer, 2)
    None => assert_true(false)
  }
  // The upstream draws the figure of a graph of three nodes in a square of
  // five by five.
  assert_true((plot.figure_width - 5.0).abs() < 0.000000000001)
  assert_true((plot.figure_height - 5.0).abs() < 0.000000000001)
}

///|
/// The upstream refuses to draw a graph that holds a self-cycle.
test "the upstream refuses a graph that holds a self-cycle" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X", "X")
  assert_true(@plotting.has_self_cycle(graph))
  match @plotting.networkx_plot(graph, true, None, None, None) {
    Some(_) => assert_true(false)
    None => ()
  }
}

///|
/// The label of a node holds a line break in front of every long word.
test "the label of a node is wrapped" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("a bbbb c", "aaaa bbb ccc")
  let plot = match @plotting.networkx_plot(graph, true, None, None, None) {
    Some(value) => value
    None => abort("the port refused the plot of the graph")
  }
  assert_eq(plot.nodes[0].label, "a bbbb\nc")
  assert_eq(plot.nodes[1].label, "aaaa\nbbb\nccc")
}

///|
/// The bar plot of misspecified uncertainties does not raise.
test "the bar plot of misspecified uncertainties does not raise" {
  // The upstream drops the error bar of a bar whose uncertainty reaches below
  // the value of the bar, and it gives no error bar to a bar whose uncertainty
  // the caller did not give.
  let uncertainties : Map[String, (Double, Double)] = Map([
    ("X", (1.1, 0.9)),
    ("Y", (1.5, 2.1)),
  ])
  let plot = @plotting.bar_plot(
    [("X", 1.0), ("Y", 2.0), ("Z", 3.0)],
    Some(uncertainties),
  )
  assert_eq(plot.labels.length(), 3)
  assert_eq(plot.labels[0], "X")
  assert_eq(plot.labels[2], "Z")
  assert_true((plot.values[0] - 1.0).abs() < 0.000000000001)
  assert_true((plot.values[2] - 3.0).abs() < 0.000000000001)
  assert_true((plot.ci_minus[0] - 0.0).abs() < 0.000000000001)
  assert_true((plot.ci_plus[0] - 0.0).abs() < 0.000000000001)
  assert_true((plot.ci_minus[1] - 0.5).abs() < 0.000000000001)
  assert_true((plot.ci_plus[1] - 0.10000000000000009).abs() < 0.000000000001)
  assert_true((plot.ci_minus[2] - 0.0).abs() < 0.000000000001)
  assert_true((plot.ci_plus[2] - 0.0).abs() < 0.000000000001)
  // The upstream writes the bar it has no uncertainty for into the dictionary
  // of the uncertainties of the caller. The port never writes into it.
  assert_eq(uncertainties.length(), 2)
}

///|
/// The bar plot of the uncertainties the upstream drops.
test "the bar plot of the uncertainties the upstream drops" {
  let small : Map[String, (Double, Double)] = Map([
    ("X", (0.01, 0.1)),
    ("Y", (0.01, 0.1)),
  ])
  let plot = @plotting.bar_plot([("X", 1.0), ("Y", 2.0)], Some(small))
  assert_true((plot.ci_minus[0] - 0.0).abs() < 0.000000000001)
  assert_true((plot.ci_plus[0] - 0.0).abs() < 0.000000000001)
  assert_true((plot.ci_minus[1] - 0.0).abs() < 0.000000000001)
  assert_true((plot.ci_plus[1] - 0.0).abs() < 0.000000000001)
  // The uncertainty of a bar that holds the value of the bar gives an error
  // bar below the bar and none above it.
  let below : Map[String, (Double, Double)] = Map([("X", (0.0, 1.0))])
  let below_plot = @plotting.bar_plot([("X", 1.0)], Some(below))
  assert_true((below_plot.ci_minus[0] - 1.0).abs() < 0.000000000001)
  assert_true((below_plot.ci_plus[0] - 0.0).abs() < 0.000000000001)
  // An uncertainty that reaches below the value of the bar is dropped.
  let reaching : Map[String, (Double, Double)] = Map([
    ("X", (0.0, 0.99999999999)),
  ])
  let reaching_plot = @plotting.bar_plot([("X", 1.0)], Some(reaching))
  assert_true((reaching_plot.ci_minus[0] - 0.0).abs() < 0.000000000001)
  assert_true((reaching_plot.ci_plus[0] - 0.0).abs() < 0.000000000001)
  // An uncertainty that reaches around the value of the bar gives an error
  // bar on both sides of it.
  let around : Map[String, (Double, Double)] = Map([
    ("X", (1.0 - 0.000000000000001, 1.0 + 0.000000000000001)),
  ])
  let around_plot = @plotting.bar_plot([("X", 1.0)], Some(around))
  assert_true(
    (around_plot.ci_minus[0] - 0.0000000000000009992).abs() < 0.000000000000001,
  )
  assert_true(
    (around_plot.ci_plus[0] - 0.0000000000000011102).abs() < 0.000000000000001,
  )
}

///|
/// The bars of a bar plot are sorted by their names when the caller asks for
/// it.
test "the bars of a bar plot are sorted by their names" {
  let plot = @plotting.bar_plot(
    [("Z", 3.0), ("X", 1.0), ("Y", 2.0)],
    None,
    sort_names=true,
  )
  assert_eq(plot.labels.length(), 3)
  assert_eq(plot.labels[0], "X")
  assert_eq(plot.labels[1], "Y")
  assert_eq(plot.labels[2], "Z")
  assert_true((plot.values[0] - 1.0).abs() < 0.000000000001)
}
