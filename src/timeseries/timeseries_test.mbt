///|
/// The tests of the temporal graphs.
///
/// The cases mirror the two test files of the upstream:
/// `tests/timeseries/test_temporal_causal_graph_creation.py` and
/// `tests/timeseries/test_temporal_shift.py`.
///
/// The eight cases of `test_temporal_shift.py` are the eight cases of the
/// upstream: the unrolling of a graph into its lagged nodes and the shifting
/// of the columns of a frame by the lag of every node.
///
/// The seventeen cases of `test_temporal_causal_graph_creation.py` are the
/// five of the reader of a CSV file, the five of the reader of a DOT file and
/// the seven of the reader of the array representation. The upstream reads the
/// CSV and the DOT from files, and this library has no file system, so the
/// port reads the text of the files. The reader of the DOT of the upstream
/// needs `pygraphviz`, which is not installed here, so the reference script
/// `_verify/timeseries_readers_reference.py` runs it with the backend of
/// `pydot` in the place of the backend of `pygraphviz`.

///|
/// A graph with the given edges, every edge with a single time lag.
fn temporal_graph(
  edges : Array[(String, String, Int32)],
) -> @timeseries.TemporalGraph {
  @timeseries.create_graph_from_edges(edges)
}

///|
/// A graph with the given edges, every edge with the given time lags.
fn temporal_graph_with_lags(
  edges : Array[(String, String, Array[Int32])],
) -> @timeseries.TemporalGraph {
  let graph = @timeseries.TemporalGraph::new()
  for (from, to, lags) in edges {
    graph.add_edge_with_lags(from, to, lags)
  }
  graph
}

///|
/// A graph with the given nodes and no edges.
fn node_graph(nodes : Array[String]) -> @timeseries.TemporalGraph {
  let graph = @timeseries.TemporalGraph::new()
  for node in nodes {
    graph.add_node(node)
  }
  graph
}

///|
/// The array of the link labels of the networkx array representation.
///
/// The links are given as `(row, column, lag, label)` entries, the cells that
/// are not listed hold no link.
fn link_array(
  n : Int32,
  tau : Int32,
  links : Array[(Int32, Int32, Int32, String)],
) -> Array[Array[Array[String]]] {
  let array : Array[Array[Array[String]]] = []
  for i = 0; i < n; i = i + 1 {
    let row : Array[Array[String]] = []
    for j = 0; j < n; j = j + 1 {
      let cell : Array[String] = []
      for t = 0; t < tau; t = t + 1 {
        cell.push("")
      }
      row.push(cell)
    }
    array.push(row)
  }
  for (i, j, t, label) in links {
    array[i][j][t] = label
  }
  array
}

///|
/// Assert that a column of a frame holds the given values.
fn assert_column(
  frame : @api.DataFrame,
  name : String,
  expected : Array[Double],
) -> Unit raise {
  let values = frame.numeric(name)
  assert_eq(expected.length(), values.length())
  for i = 0; i < expected.length(); i = i + 1 {
    assert_true(expected[i] == values[i])
  }
}

///|
/// The unrolled graph holds the lagged nodes and the lagged edges.
test "the unrolled graph holds the lagged nodes and the lagged edges" {
  let graph = temporal_graph([("A", "B", 1), ("B", "C", 2)])
  let unrolled = @timeseries.add_lagged_edges(graph, "C")
  assert_true(unrolled.has_node("C_0"))
  assert_true(unrolled.has_node("B_-2"))
  assert_true(unrolled.has_node("A_-3"))
  assert_true(unrolled.has_edge("B_-2", "C_0"))
  assert_true(unrolled.has_edge("A_-3", "B_-2"))
}

///|
/// The unrolled graph holds a node for every time lag.
test "the unrolled graph holds a node for every time lag" {
  let graph = temporal_graph_with_lags([("A", "B", [1, 2]), ("B", "C", [1, 3])])
  let unrolled = @timeseries.add_lagged_edges(graph, "C")
  assert_true(unrolled.has_node("C_0"))
  assert_true(unrolled.has_node("B_-1"))
  assert_true(unrolled.has_node("B_-3"))
  assert_true(unrolled.has_node("A_-2"))
  assert_true(unrolled.has_node("A_-3"))
  assert_true(unrolled.has_node("A_-4"))
  assert_true(unrolled.has_node("A_-5"))
  assert_true(unrolled.has_edge("B_-1", "C_0"))
  assert_true(unrolled.has_edge("B_-3", "C_0"))
  assert_true(unrolled.has_edge("A_-2", "B_-1"))
  assert_true(unrolled.has_edge("A_-4", "B_-3"))
  assert_true(unrolled.has_edge("B_-3", "B_-1"))
  assert_true(unrolled.has_edge("A_-5", "A_-4"))
  assert_true(unrolled.has_edge("A_-4", "A_-3"))
  assert_true(unrolled.has_edge("A_-3", "A_-2"))
}

///|
/// The unrolled graph keeps the direct edges.
test "the unrolled graph keeps the direct edges" {
  let graph = temporal_graph([("A", "B", 1), ("B", "C", 2), ("A", "C", 3)])
  let unrolled = @timeseries.add_lagged_edges(graph, "C")
  assert_true(unrolled.has_node("C_0"))
  assert_true(unrolled.has_node("B_-2"))
  assert_true(unrolled.has_node("A_-3"))
  assert_true(unrolled.has_edge("B_-2", "C_0"))
  assert_true(unrolled.has_edge("A_-3", "B_-2"))
  assert_true(unrolled.has_edge("A_-3", "C_0"))
}

///|
/// An edge without a time lag contributes no lagged node.
test "an edge without a time lag contributes no lagged node" {
  let graph = @timeseries.TemporalGraph::new()
  graph.add_edge_with_lags("A", "B", [])
  graph.add_edge_with_lags("B", "C", [])
  let unrolled = @timeseries.add_lagged_edges(graph, "C")
  assert_eq(0, unrolled.node_count())
  assert_eq(0, unrolled.edge_count())
}

///|
/// The shifted columns hold the shifted values.
test "the shifted columns hold the shifted values" {
  let df = @api.DataFrame::from_numeric(
    ["A", "B"],
    Map([("A", [1.0, 2.0, 3.0, 4.0, 5.0]), ("B", [5.0, 4.0, 3.0, 2.0, 1.0])]),
  )
  let unrolled = node_graph(["A_0", "A_-1", "B_0", "B_-2"])
  let shifted = @timeseries.shift_columns_by_lag_using_unrolled_graph(
    df, unrolled,
  )
  assert_eq(["A_0", "A_-1", "B_0", "B_-2"], shifted.column_names())
  assert_column(shifted, "A_0", [1.0, 2.0, 3.0, 4.0, 5.0])
  assert_column(shifted, "A_-1", [0.0, 1.0, 2.0, 3.0, 4.0])
  assert_column(shifted, "B_0", [5.0, 4.0, 3.0, 2.0, 1.0])
  assert_column(shifted, "B_-2", [0.0, 0.0, 5.0, 4.0, 3.0])
}

///|
/// The shifted columns of a longer graph hold the shifted values.
test "the shifted columns of a longer graph hold the shifted values" {
  let df = @api.DataFrame::from_numeric(
    ["A", "B", "C"],
    Map([
      ("A", [1.0, 2.0, 3.0, 4.0, 5.0]),
      ("B", [5.0, 4.0, 3.0, 2.0, 1.0]),
      ("C", [1.0, 3.0, 5.0, 7.0, 9.0]),
    ]),
  )
  let unrolled = node_graph(["A_0", "A_-1", "B_0", "B_-2", "C_-1", "C_-3"])
  let shifted = @timeseries.shift_columns_by_lag_using_unrolled_graph(
    df, unrolled,
  )
  assert_eq(
    ["A_0", "A_-1", "B_0", "B_-2", "C_-1", "C_-3"],
    shifted.column_names(),
  )
  assert_column(shifted, "A_0", [1.0, 2.0, 3.0, 4.0, 5.0])
  assert_column(shifted, "A_-1", [0.0, 1.0, 2.0, 3.0, 4.0])
  assert_column(shifted, "B_0", [5.0, 4.0, 3.0, 2.0, 1.0])
  assert_column(shifted, "B_-2", [0.0, 0.0, 5.0, 4.0, 3.0])
  assert_column(shifted, "C_-1", [0.0, 1.0, 3.0, 5.0, 7.0])
  assert_column(shifted, "C_-3", [0.0, 0.0, 0.0, 1.0, 3.0])
}

///|
/// A node whose name carries no lag is skipped.
test "a node whose name carries no lag is skipped" {
  let df = @api.DataFrame::from_numeric(
    ["A", "B"],
    Map([("A", [1.0, 2.0, 3.0, 4.0, 5.0]), ("B", [5.0, 4.0, 3.0, 2.0, 1.0])]),
  )
  let unrolled = node_graph(["A_0", "B_invalid"])
  let shifted = @timeseries.shift_columns_by_lag_using_unrolled_graph(
    df, unrolled,
  )
  assert_eq(["A_0"], shifted.column_names())
  assert_column(shifted, "A_0", [1.0, 2.0, 3.0, 4.0, 5.0])
}

///|
/// A node whose base is no column of the frame is skipped.
test "a node whose base is no column of the frame is skipped" {
  let df = @api.DataFrame::from_numeric(
    ["A", "B"],
    Map([("A", [1.0, 2.0, 3.0, 4.0, 5.0]), ("B", [5.0, 4.0, 3.0, 2.0, 1.0])]),
  )
  let unrolled = node_graph(["C_0", "C_-1"])
  let shifted = @timeseries.shift_columns_by_lag_using_unrolled_graph(
    df, unrolled,
  )
  assert_eq(0, shifted.column_names().length())
}

///|
/// The entries of an edge are merged into one edge with several time lags.
test "the entries of an edge are merged into one edge with several time lags" {
  let graph = temporal_graph([("A", "B", 5), ("A", "B", 3), ("A", "C", 7)])
  assert_eq(2, graph.edge_count())
  assert_eq([5, 3], graph.time_lags_of("A", "B"))
  assert_eq([7], graph.time_lags_of("A", "C"))
}

///|
/// The label of a link kind is the label it was built from.
test "the label of a link kind is the label it was built from" {
  let forward = @timeseries.LinkKind::of_label("-->")
  assert_eq("-->", @timeseries.LinkKind::label(forward))
  let backward = @timeseries.LinkKind::of_label("<--")
  assert_eq("<--", @timeseries.LinkKind::label(backward))
  let undirected = @timeseries.LinkKind::of_label("o-o")
  assert_eq("o-o", @timeseries.LinkKind::label(undirected))
  let none = @timeseries.LinkKind::of_label("")
  assert_eq("", @timeseries.LinkKind::label(none))
}

///|
/// The networkx array representation gives the edges of the variables.
test "the networkx array representation gives the edges of the variables" {
  let array = link_array(3, 2, [
    (0, 1, 0, "-->"),
    (1, 2, 0, "-->"),
    (0, 2, 1, "-->"),
  ])
  let graph = @timeseries.create_graph_from_networkx_array(array, [
    "X1", "X2", "X3",
  ])
  assert_eq(3, graph.edge_count())
  assert_true(graph.has_edge("X1", "X2"))
  assert_eq([0], graph.time_lags_of("X1", "X2"))
  assert_true(graph.has_edge("X1", "X3"))
  assert_eq([1], graph.time_lags_of("X1", "X3"))
  assert_true(graph.has_edge("X2", "X3"))
  assert_eq([0], graph.time_lags_of("X2", "X3"))
}

///|
/// The backward label gives an edge in the other direction.
test "the backward label gives an edge in the other direction" {
  let array = link_array(2, 1, [(0, 1, 0, "<--")])
  let graph = @timeseries.create_graph_from_networkx_array(array, ["X1", "X2"])
  assert_eq(1, graph.edge_count())
  assert_true(graph.has_edge("X2", "X1"))
  assert_eq([0], graph.time_lags_of("X2", "X1"))
}

///|
/// The networkx array representation gives an edge several time lags.
test "the networkx array representation gives an edge several time lags" {
  let array = link_array(3, 3, [
    (0, 1, 0, "-->"),
    (0, 1, 1, "-->"),
    (1, 2, 2, "-->"),
  ])
  let graph = @timeseries.create_graph_from_networkx_array(array, [
    "X1", "X2", "X3",
  ])
  assert_eq(2, graph.edge_count())
  assert_true(graph.has_edge("X1", "X2"))
  assert_eq([0, 1], graph.time_lags_of("X1", "X2"))
  assert_true(graph.has_edge("X2", "X3"))
  assert_eq([2], graph.time_lags_of("X2", "X3"))
}

///|
/// The networkx array representation rejects the unsupported link types.
test "the networkx array representation rejects the unsupported link types" {
  let array = link_array(2, 1, [(0, 1, 0, "o-o")])
  let mut raised = false
  try {
    let _ = @timeseries.create_graph_from_networkx_array(array, ["X1", "X2"])
  } catch {
    e => {
      raised = true
      match e {
        @timeseries.TemporalError::UnsupportedLinkType(kind, _, _, _) =>
          assert_eq("o-o", kind)
        _ => ()
      }
    }
  } noraise {
    _ => ()
  }
  assert_true(raised)
  let array = link_array(2, 1, [(0, 1, 0, "x-x")])
  let mut raised = false
  try {
    let _ = @timeseries.create_graph_from_networkx_array(array, ["X1", "X2"])
  } catch {
    e => {
      raised = true
      match e {
        @timeseries.TemporalError::UnsupportedLinkType(kind, _, _, _) =>
          assert_eq("x-x", kind)
        _ => ()
      }
    }
  } noraise {
    _ => ()
  }
  assert_true(raised)
}

///|
/// The networkx array representation rejects an array that is not square.
test "the networkx array representation rejects an array that is not square" {
  let array : Array[Array[Array[String]]] = [[], []]
  let mut raised = false
  try {
    let _ = @timeseries.create_graph_from_networkx_array(array, ["X1"])
  } catch {
    e => {
      raised = true
      match e {
        @timeseries.TemporalError::NotSquare(rows, columns) => {
          assert_eq(2, rows)
          assert_eq(0, columns)
        }
        _ => ()
      }
    }
  } noraise {
    _ => ()
  }
  assert_true(raised)
}

///|
/// An empty networkx array representation gives an empty graph.
test "an empty networkx array representation gives an empty graph" {
  let array = link_array(0, 0, [])
  let graph = @timeseries.create_graph_from_networkx_array(array, [])
  assert_eq(0, graph.node_count())
  assert_eq(0, graph.edge_count())
}

///|
/// The networkx array representation skips the self loops.
test "the networkx array representation skips the self loops" {
  let array = link_array(2, 1, [(0, 0, 0, "-->")])
  let graph = @timeseries.create_graph_from_networkx_array(array, ["X1", "X2"])
  assert_eq(0, graph.edge_count())
}

///|
/// The CSV of the basic fixture of the upstream.
fn csv_basic() -> String {
  "node1,node2,time_lag\nA,B,5\nB,C,2\nA,C,7"
}

///|
/// The CSV of the fixture of the upstream that holds several lags of one edge.
fn csv_multiple_lags() -> String {
  "node1,node2,time_lag\nA,B,5\nA,B,3\nA,C,7"
}

///|
/// The CSV of the fixture of the upstream that holds a lag that is not a
/// number.
fn csv_invalid_lag() -> String {
  "node1,node2,time_lag\nA,B,five\nB,C,2\nA,C,7"
}

///|
/// The DOT of the basic fixture of the upstream.
fn dot_basic() -> String {
  "digraph G {\n  A -> B [label=\"(5)\"];\n  B -> C [label=\"(2)\"];\n  A -> C [label=\"(7)\"];\n}"
}

///|
/// The DOT of the fixture of the upstream that holds several lags of one edge.
fn dot_multiple_lags() -> String {
  "digraph G {\n  A -> B [label=\"(5,3)\"];\n  A -> C [label=\"(7)\"];\n}"
}

///|
/// The DOT of the fixture of the upstream that holds a label that is not a
/// number.
fn dot_invalid_lag() -> String {
  "digraph G {\n  A -> B [label=\"(five)\"];\n  B -> C [label=\"(2)\"];\n  A -> C [label=\"(7)\"];\n}"
}

///|
/// The CSV reader of the upstream gives the edges of the basic fixture.
test "the CSV reader gives the edges of the basic fixture of the upstream" {
  let graph = @timeseries.create_graph_from_csv_text(csv_basic())
  let graph = match graph {
    Some(value) => value
    None => return
  }
  assert_eq(3, graph.edge_count())
  assert_true(graph.has_edge("A", "B"))
  assert_eq([5], graph.time_lags_of("A", "B"))
  assert_true(graph.has_edge("B", "C"))
  assert_eq([2], graph.time_lags_of("B", "C"))
  assert_true(graph.has_edge("A", "C"))
  assert_eq([7], graph.time_lags_of("A", "C"))
}

///|
/// The CSV reader of the upstream merges the rows of one edge.
test "the CSV reader merges the rows of one edge of the upstream" {
  let graph = @timeseries.create_graph_from_csv_text(csv_multiple_lags())
  let graph = match graph {
    Some(value) => value
    None => return
  }
  assert_eq(2, graph.edge_count())
  assert_true(graph.has_edge("A", "B"))
  assert_eq([5, 3], graph.time_lags_of("A", "B"))
  assert_true(graph.has_edge("A", "C"))
  assert_eq([7], graph.time_lags_of("A", "C"))
}

///|
/// The CSV reader of the upstream refuses a lag that is not a number.
test "the CSV reader refuses a lag that is not a number" {
  let mut absent = false
  match @timeseries.create_graph_from_csv_text(csv_invalid_lag()) {
    Some(_) => ()
    None => absent = true
  }
  assert_true(absent)
}

///|
/// The CSV reader of the upstream gives an empty graph for an empty CSV.
test "the CSV reader gives an empty graph for an empty CSV" {
  let graph = @timeseries.create_graph_from_csv_text("node1,node2,time_lag")
  let graph = match graph {
    Some(value) => value
    None => return
  }
  assert_eq(0, graph.edge_count())
}

///|
/// The CSV reader of the upstream keeps a self loop.
test "the CSV reader keeps a self loop of the upstream" {
  let graph = @timeseries.create_graph_from_csv_text(
    "node1,node2,time_lag\nA,A,5",
  )
  let graph = match graph {
    Some(value) => value
    None => return
  }
  assert_eq(1, graph.edge_count())
  assert_true(graph.has_edge("A", "A"))
  assert_eq([5], graph.time_lags_of("A", "A"))
}

///|
/// The DOT reader of the upstream gives the edges of the basic fixture.
test "the DOT reader gives the edges of the basic fixture of the upstream" {
  let graph = @timeseries.create_graph_from_dot_text(dot_basic())
  let graph = match graph {
    Some(value) => value
    None => return
  }
  assert_eq(3, graph.edge_count())
  assert_true(graph.has_edge("A", "B"))
  assert_eq([5], graph.time_lags_of("A", "B"))
  assert_true(graph.has_edge("B", "C"))
  assert_eq([2], graph.time_lags_of("B", "C"))
  assert_true(graph.has_edge("A", "C"))
  assert_eq([7], graph.time_lags_of("A", "C"))
}

///|
/// The DOT reader of the upstream reads the lags of the label of an edge.
test "the DOT reader reads the lags of the label of an edge of the upstream" {
  let graph = @timeseries.create_graph_from_dot_text(dot_multiple_lags())
  let graph = match graph {
    Some(value) => value
    None => return
  }
  assert_eq(2, graph.edge_count())
  assert_true(graph.has_edge("A", "B"))
  assert_eq([5, 3], graph.time_lags_of("A", "B"))
  assert_true(graph.has_edge("A", "C"))
  assert_eq([7], graph.time_lags_of("A", "C"))
}

///|
/// The DOT reader of the upstream refuses a label that is not a number.
test "the DOT reader refuses a label that is not a number" {
  let mut absent = false
  match @timeseries.create_graph_from_dot_text(dot_invalid_lag()) {
    Some(_) => ()
    None => absent = true
  }
  assert_true(absent)
}

///|
/// The DOT reader of the upstream gives an empty graph for an empty DOT.
test "the DOT reader gives an empty graph for an empty DOT" {
  let graph = @timeseries.create_graph_from_dot_text("digraph G {}")
  let graph = match graph {
    Some(value) => value
    None => return
  }
  assert_eq(0, graph.edge_count())
}

///|
/// The DOT reader of the upstream keeps a self loop.
test "the DOT reader keeps a self loop of the upstream" {
  let graph = @timeseries.create_graph_from_dot_text(
    "digraph G {\n  A -> A [label=\"(5)\"];\n}",
  )
  let graph = match graph {
    Some(value) => value
    None => return
  }
  assert_eq(1, graph.edge_count())
  assert_true(graph.has_edge("A", "A"))
  assert_eq([5], graph.time_lags_of("A", "A"))
}
