///|
/// A directed graph whose edges carry the causal time lag of the edge.
///
/// This is the port of the temporal graphs of `dowhy.utils.timeseries` and
/// `dowhy.timeseries.temporal_shift`. The `graph` package of this library
/// carries no edge attributes, so the temporal graph is a type of its own
/// here.
///
/// Every edge of a temporal graph has one or more time lags. The lags of an
/// edge are the causal lags of the edge, and an edge may carry several of
/// them: the entries of two edges that share the same ordered pair of nodes
/// are merged into one edge whose lags are the concatenation of the lags of
/// the entries.
///
/// The nodes keep their insertion order, so every derived result (the lagged
/// nodes of `add_lagged_edges`, the columns of
/// `shift_columns_by_lag_using_unrolled_graph`) is deterministic.
pub struct TemporalGraph {
  nodes : Array[String]
  node_set : Set[String]
  edges : Array[(String, String)]
  succ : Map[String, Array[String]]
  pred : Map[String, Array[String]]
  lags : Map[String, Array[Int32]]
}

///|
/// The key under which the lags of an edge are stored.
fn edge_key(from : String, to : String) -> String {
  from + "\u{1}" + to
}

///|
/// A new empty temporal graph.
pub fn TemporalGraph::new() -> TemporalGraph {
  {
    nodes: [],
    node_set: Set::Set([]),
    edges: [],
    succ: Map([]),
    pred: Map([]),
    lags: Map([]),
  }
}

///|
/// Add a node, ignoring duplicates.
pub fn TemporalGraph::add_node(self : TemporalGraph, name : String) -> Unit {
  if !self.node_set.contains(name) {
    self.node_set.add(name)
    self.nodes.push(name)
  }
}

///|
/// Add an edge with a single time lag, creating the endpoints when they are
/// new.
///
/// When the edge already exists, the lag is appended to the lags of the
/// edge, which is how the entries of a graph description are merged into one
/// edge.
pub fn TemporalGraph::add_edge(
  self : TemporalGraph,
  from : String,
  to : String,
  lag : Int32,
) -> Unit {
  self.add_edge_with_lags(from, to, [lag])
}

///|
/// Add an edge with the given time lags, creating the endpoints when they are
/// new.
///
/// When the edge already exists, the lags are appended to the lags of the
/// edge. An edge with an empty array of lags is an edge without a time lag,
/// which the lagged graph of `add_lagged_edges` ignores.
pub fn TemporalGraph::add_edge_with_lags(
  self : TemporalGraph,
  from : String,
  to : String,
  lags : Array[Int32],
) -> Unit {
  let key = self.ensure_edge(from, to)
  match self.lags.get(key) {
    Some(existing) =>
      for lag in lags {
        existing.push(lag)
      }
    None => self.lags.set(key, lags.copy())
  }
}

///|
/// Replace the time lags of an edge.
///
/// The edge is created when it does not exist yet. The lags are copied, so the
/// caller may modify the array it hands over without changing the graph.
///
/// The upstream merges the lags of two entries of the same edge in two ways:
/// the reader of a CSV file appends the lag of the row to the lags of the
/// edge, and the reader of a DOT file replaces them with the lags of all the
/// entries without their duplicates. The appending is the method
/// `add_edge_with_lags`, and the replacing is this one.
pub fn TemporalGraph::set_time_lags(
  self : TemporalGraph,
  from : String,
  to : String,
  lags : Array[Int32],
) -> Unit {
  let key = self.ensure_edge(from, to)
  self.lags.set(key, lags.copy())
}

///|
/// Create the edge when it does not exist yet, and return the key it is
/// stored under.
fn TemporalGraph::ensure_edge(
  self : TemporalGraph,
  from : String,
  to : String,
) -> String {
  self.add_node(from)
  self.add_node(to)
  let key = edge_key(from, to)
  if !self.lags.contains(key) {
    self.edges.push((from, to))
    let children = self.succ.get(from).unwrap_or([])
    children.push(to)
    self.succ.set(from, children)
    let parents = self.pred.get(to).unwrap_or([])
    parents.push(from)
    self.pred.set(to, parents)
  }
  key
}

///|
/// Whether the graph contains the node.
pub fn TemporalGraph::has_node(self : TemporalGraph, name : String) -> Bool {
  self.node_set.contains(name)
}

///|
/// Whether the graph contains the edge.
pub fn TemporalGraph::has_edge(
  self : TemporalGraph,
  from : String,
  to : String,
) -> Bool {
  self.lags.contains(edge_key(from, to))
}

///|
/// The nodes of the graph in insertion order.
pub fn TemporalGraph::node_list(self : TemporalGraph) -> Array[String] {
  self.nodes.copy()
}

///|
/// The edges of the graph in insertion order.
pub fn TemporalGraph::edge_list(
  self : TemporalGraph,
) -> Array[(String, String)] {
  self.edges.copy()
}

///|
/// The number of nodes.
pub fn TemporalGraph::node_count(self : TemporalGraph) -> Int32 {
  self.nodes.length()
}

///|
/// The number of edges.
pub fn TemporalGraph::edge_count(self : TemporalGraph) -> Int32 {
  self.edges.length()
}

///|
/// The time lags of the edge, in the order they were added.
///
/// The returned array is a copy, so a caller may modify it without changing
/// the graph. An edge without a time lag has an empty array of lags.
pub fn TemporalGraph::time_lags_of(
  self : TemporalGraph,
  from : String,
  to : String,
) -> Array[Int32] {
  match self.lags.get(edge_key(from, to)) {
    Some(lags) => lags.copy()
    None => []
  }
}

///|
/// The parents of a node, in the order the edges were added.
///
/// The returned array is a copy, so a caller may modify it without changing
/// the graph.
pub fn TemporalGraph::predecessors(
  self : TemporalGraph,
  name : String,
) -> Array[String] {
  self.pred.get(name).unwrap_or([]).copy()
}

///|
/// The children of a node, in the order the edges were added.
///
/// The returned array is a copy, so a caller may modify it without changing
/// the graph.
pub fn TemporalGraph::successors(
  self : TemporalGraph,
  name : String,
) -> Array[String] {
  self.succ.get(name).unwrap_or([]).copy()
}

///|
/// A copy of the graph.
///
/// The nodes, the edges and the lags are copied as well, so the copy and the
/// original do not share any state.
pub fn TemporalGraph::copy(self : TemporalGraph) -> TemporalGraph {
  let graph = TemporalGraph::new()
  for node in self.nodes {
    graph.add_node(node)
  }
  for (from, to) in self.edges {
    graph.add_edge_with_lags(from, to, self.time_lags_of(from, to))
  }
  graph
}

///|
/// The kind of link between two variables at one time lag.
///
/// The kinds are the link types of the array representation of the temporal
/// graphs: a directed link, a directed link in the other direction and the
/// two kinds of undirected link that the temporal graphs do not support.
///
/// A kind is built with `LinkKind::of_label`, because the constructor of a
/// variant of an enum is not reachable from another package.
pub enum LinkKind {
  /// No link between the two variables at this lag.
  NoLink
  /// A directed link from the row variable to the column variable (`"-->"`).
  Forward
  /// A directed link from the column variable to the row variable (`"<--"`).
  Backward
  /// An undirected link (`"o-o"`), which the temporal graphs do not support.
  Undirected
  /// A link in both directions (`"x-x"`), which the temporal graphs do not
  /// support.
  BiDirected
}

///|
/// The link kind of a label of the array representation.
///
/// Every label that is not one of the four link types of the array
/// representation stands for the absence of a link.
pub fn LinkKind::of_label(label : String) -> LinkKind {
  if label == "-->" {
    Forward
  } else if label == "<--" {
    Backward
  } else if label == "o-o" {
    Undirected
  } else if label == "x-x" {
    BiDirected
  } else {
    NoLink
  }
}

///|
/// The label of a link kind, as it appears in the array representation.
pub fn LinkKind::label(self : LinkKind) -> String {
  match self {
    NoLink => ""
    Forward => "-->"
    Backward => "<--"
    Undirected => "o-o"
    BiDirected => "x-x"
  }
}

///|
/// The errors the temporal graph constructors raise.
pub suberror TemporalError {
  /// An unsupported link type was found in the array representation. The
  /// fields are the link type, the two variables and the time lag.
  UnsupportedLinkType(String, String, String, Int32)
  /// The array representation is not square. The fields are the number of
  /// rows and the number of columns.
  NotSquare(Int32, Int32)
  /// The array representation has more variables than there are names. The
  /// field is the index of the variable without a name.
  MissingVariableName(Int32)
}

///|
/// Build a temporal graph from a list of `(from, to, lag)` entries.
///
/// This is the data form of the graph descriptions of `dowhy.utils.timeseries`:
/// the console reader, the CSV reader and the DOT reader all reduce to a list
/// of edges with a time lag. The file readers themselves are not ported,
/// because this library has no file IO.
///
/// The entries of the same ordered pair of nodes are merged into one edge,
/// whose time lags are the lags of the entries in the order they appear. An
/// entry with several lags is added with `TemporalGraph::add_edge_with_lags`.
pub fn create_graph_from_edges(
  edges : Array[(String, String, Int32)],
) -> TemporalGraph {
  let graph = TemporalGraph::new()
  for (from, to, lag) in edges {
    graph.add_edge(from, to, lag)
  }
  graph
}

///|
/// Build a temporal graph from the array representation of the links.
///
/// The array holds one link label per pair of variables and time lag, with the
/// shape `(n, n, tau)`, and the names give the name of every variable. A
/// forward label (`"-->"`) at lag `t` becomes an edge from the row variable to
/// the column variable with the time lag `t`, a backward label (`"<--"`) an
/// edge in the other direction. The undirected labels (`"o-o"` and `"x-x"`)
/// are not supported and raise an error, every other label means that there is
/// no link.
///
/// This is the port of `create_graph_from_networkx_array`, whose array holds
/// the same labels.
pub fn create_graph_from_networkx_array(
  array : Array[Array[Array[String]]],
  var_names : Array[String],
) -> TemporalGraph raise TemporalError {
  let n = array.length()
  for row in array {
    if row.length() != n {
      raise TemporalError::NotSquare(n, row.length())
    }
  }
  let graph = TemporalGraph::new()
  for name in var_names {
    graph.add_node(name)
  }
  for i = 0; i < n; i = i + 1 {
    if i >= var_names.length() {
      raise TemporalError::MissingVariableName(i)
    }
    for j = 0; j < n; j = j + 1 {
      if i == j {
        continue
      }
      let cell = array[i][j]
      for t = 0; t < cell.length(); t = t + 1 {
        match LinkKind::of_label(cell[t]) {
          Forward => graph.add_edge(var_names[i], var_names[j], t)
          Backward => graph.add_edge(var_names[j], var_names[i], t)
          Undirected =>
            raise TemporalError::UnsupportedLinkType(
              "o-o",
              var_names[i],
              var_names[j],
              t,
            )
          BiDirected =>
            raise TemporalError::UnsupportedLinkType(
              "x-x",
              var_names[i],
              var_names[j],
              t,
            )
          NoLink => ()
        }
      }
    }
  }
  graph
}
