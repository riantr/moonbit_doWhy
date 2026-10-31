///|
/// The temporal shift: the unrolling of a temporal graph into lagged nodes
/// and the shift of the data columns that belong to them.
///
/// This is the port of `dowhy.timeseries.temporal_shift`.

///|
/// Parse an integer, returning `None` when the text is not a number.
fn parse_int(text : String) -> Int32? {
  Some(@string.parse_int(text, base=10)) catch {
    _ => None
  }
}

///|
/// The lag that a lagged node name carries.
///
/// A lagged node is named `<base>_<lag>`, so the lag is the part behind the
/// last underscore. `None` is returned when the name carries no lag.
fn node_lag(node : String) -> Int32? {
  match node.rev_split_once("_") {
    Some((_, tail)) => parse_int(tail.to_owned())
    None => None
  }
}

///|
/// The lagged nodes of every original node.
///
/// The mapping holds the lagged nodes per original node, the array holds the
/// original nodes in the order they were added, so that the iteration over
/// the mapping is deterministic.
priv struct LaggedNodes {
  nodes : Array[String]
  mapping : Map[String, Array[String]]
}

///|
/// A new empty collection of lagged nodes.
fn LaggedNodes::new() -> LaggedNodes {
  { nodes: [], mapping: Map([]), }
}

///|
/// The lagged nodes of an original node, creating the `<base>_0` node of the
/// original node when it is seen for the first time.
fn LaggedNodes::get_or_create(
  self : LaggedNodes,
  graph : TemporalGraph,
  original : String,
) -> Array[String] {
  match self.mapping.get(original) {
    Some(lagged) => lagged
    None => {
      let lagged = [original + "_0"]
      graph.add_node(original + "_0")
      self.mapping.set(original, lagged)
      self.nodes.push(original)
      lagged
    }
  }
}

///|
/// The lagged nodes of an original node, with the given lagged nodes added.
///
/// The merged collection replaces the old one, so a caller that still holds
/// the old array sees the lagged nodes it had before the merge.
fn LaggedNodes::merge(
  self : LaggedNodes,
  original : String,
  lagged : Array[String],
) -> Unit {
  match self.mapping.get(original) {
    Some(existing) => {
      let merged = existing.copy()
      for node in lagged {
        if !merged.contains(node) {
          merged.push(node)
        }
      }
      self.mapping.set(original, merged)
    }
    None => {
      self.mapping.set(original, lagged.copy())
      self.nodes.push(original)
    }
  }
}

///|
/// Add the edges between the consecutive lagged nodes of an original node.
///
/// The lagged nodes are ordered by their lag, so the edge runs from the
/// lagged node with the smaller lag to the one with the larger lag.
fn link_lagged_nodes(graph : TemporalGraph, lagged : Array[String]) -> Unit {
  let sorted = lagged.copy()
  sorted.sort_by(fn(a, b) {
    let lag_a = node_lag(a).unwrap_or(0)
    let lag_b = node_lag(b).unwrap_or(0)
    lag_a.compare(lag_b)
  })
  for i = 0; i + 1 < sorted.length(); i = i + 1 {
    graph.add_edge_with_lags(sorted[i], sorted[i + 1], [])
  }
}

///|
/// Unroll a temporal graph into a graph of lagged nodes.
///
/// The walk starts at `start_node` and proceeds to the parents level by
/// level. Every parent of a node is added to the unrolled graph with the
/// accumulated time lag, so the edge `parent -> node` of the temporal graph
/// becomes the edge `<parent>_<lag> -> <node>_<lag>` of the unrolled graph.
/// The lagged nodes of one variable are linked to each other, from the
/// smallest lag to the largest one.
///
/// The edges of the unrolled graph carry no time lag, which is what the
/// upstream function does as well.
///
/// This is the port of `add_lagged_edges`.
pub fn add_lagged_edges(
  graph : TemporalGraph,
  start_node : String,
) -> TemporalGraph {
  let unrolled = TemporalGraph::new()
  let lagged_nodes = LaggedNodes::new()
  let queue = [start_node]
  let mut head = 0
  while head < queue.length() {
    let current = queue[head]
    head = head + 1
    for parent in graph.predecessors(current) {
      let lags = graph.time_lags_of(parent, current)
      if lags.length() == 0 {
        // An edge without a time lag does not contribute a lagged node.
        continue
      }
      for lag in lags {
        let lagged = lagged_nodes.get_or_create(unrolled, current)
        let new_lagged : Array[String] = []
        for node in lagged {
          let total_lag = -node_lag(node).unwrap_or(0) + lag
          let parent_node = parent + "_" + (-total_lag).to_string()
          if !new_lagged.contains(parent_node) {
            new_lagged.push(parent_node)
          }
          unrolled.add_node(parent_node)
          unrolled.add_edge_with_lags(parent_node, node, [])
          queue.push(parent)
        }
        lagged_nodes.merge(parent, new_lagged)
      }
    }
    for original in lagged_nodes.nodes {
      match lagged_nodes.mapping.get(original) {
        Some(lagged) => link_lagged_nodes(unrolled, lagged)
        None => ()
      }
    }
  }
  unrolled
}

///|
/// Shift the values of a column by the given number of rows.
///
/// The values that the shift moves in from outside the column are filled
/// with zero, the way `pandas.DataFrame.shift` fills them.
fn shift_values(values : Array[Double], lag : Int32) -> Array[Double] {
  let shifted : Array[Double] = []
  let n = values.length()
  for i = 0; i < n; i = i + 1 {
    let source = i - lag
    if source >= 0 && source < n {
      shifted.push(values[source])
    } else {
      shifted.push(0.0)
    }
  }
  shifted
}

///|
/// Shift the values of a discrete column by the given number of rows.
///
/// The values that the shift moves in from outside the column are filled with
/// the empty string.
fn shift_discrete(values : Array[String], lag : Int32) -> Array[String] {
  let shifted : Array[String] = []
  let n = values.length()
  for i = 0; i < n; i = i + 1 {
    let source = i - lag
    if source >= 0 && source < n {
      shifted.push(values[source])
    } else {
      shifted.push("")
    }
  }
  shifted
}

///|
/// Shift the columns of a frame by the lags of the nodes of an unrolled
/// graph.
///
/// Every node of the unrolled graph is named `<base>_<lag>`, and the column
/// `<base>` of the frame is shifted by that lag into a new column
/// `<base>_<lag>`. The values that the shift moves in from outside the frame
/// are filled with zero, the way `pandas.DataFrame.shift` fills them.
///
/// The result holds the shifted columns only, in the order of the nodes of
/// the unrolled graph. A node whose name carries no lag, and a node whose
/// base is no column of the frame, are skipped.
///
/// This is the port of `shift_columns_by_lag_using_unrolled_graph`.
pub fn shift_columns_by_lag_using_unrolled_graph(
  df : @api.DataFrame,
  unrolled_graph : TemporalGraph,
) -> @api.DataFrame {
  let order : Array[String] = []
  let columns : Map[String, @api.Column] = Map([])
  for node in unrolled_graph.node_list() {
    match node.rev_split_once("_") {
      Some((base_view, lag_view)) => {
        let base = base_view.to_owned()
        match parse_int(lag_view.to_owned()) {
          Some(lag) => {
            if !df.has_column(base) {
              continue
            }
            // The lag of the node is the shift of the column: the node
            // `A_-2` holds the values of `A` shifted by two rows.
            let name = base + "_" + lag.to_string()
            if !order.contains(name) {
              order.push(name)
            }
            match df.column(base) {
              Some(@api.Column::Numeric(values)) =>
                columns.set(
                  name,
                  @api.Column::numeric(shift_values(values, -lag)),
                )
              Some(@api.Column::Discrete(values)) =>
                columns.set(
                  name,
                  @api.Column::discrete(shift_discrete(values, -lag)),
                )
              None => ()
            }
          }
          None => ()
        }
      }
      None => ()
    }
  }
  @api.DataFrame::new(order, columns)
}
