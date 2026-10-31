/// The PC (Peter-Clark) causal discovery algorithm.
///
/// This is the port of the algorithm of Spirtes, Glymour and Scheines that
/// the upstream `dowhy.cm.pc.PC` and `causal-learn` implement. The
/// algorithm starts from the complete undirected graph over the variables,
/// removes an edge as soon as a subset of the remaining neighbours of its
/// endpoints makes the endpoints conditionally independent, orients the
/// v-structures of the resulting skeleton and extends the orientation with
/// Meek's rules. The result is the CPDAG of the Markov equivalence class of
/// the data generating process.

///|
/// A partially directed acyclic graph, the result of the PC algorithm.
///
/// A CPDAG is the Markov equivalence class of a DAG: the edges that are
/// oriented the same way in every DAG of the class are directed, the
/// remaining edges are undirected.
pub struct Cpdag {
  /// The labels of the variables, in the order of the matrices.
  labels : Array[String]
  /// The undirected skeleton of the graph.
  skeleton : @utils.Matrix
  /// The directed edges of the graph.
  directed : @utils.Matrix
  /// The undirected edges of the graph.
  undirected : @utils.Matrix
  /// The v-structures of the graph.
  v_structures : Array[(Int32, Int32, Int32)]
}

///|
/// The PC algorithm for a fixed set of variables.
pub struct PC {
  /// The labels of the variables, in the order of the correlation matrix.
  labels : Array[String]
  /// The correlation matrix of the variables.
  corr : @utils.Matrix
  /// The number of observations behind the correlation matrix.
  n : Int32
  /// The significance level of the independence tests.
  alpha : Double
  /// The result of the last run of the algorithm.
  mut result : Cpdag?
}

///|
/// Build the PC algorithm for the given variables.
///
/// `corr` is the correlation matrix of the variables, `n` the number of
/// observations it was computed from and `alpha` the significance level of
/// the independence tests.
pub fn PC::new(
  labels : Array[String],
  corr : @utils.Matrix,
  n : Int32,
  alpha : Double,
) -> PC {
  { labels, corr, n, alpha, result: None, }
}

///|
/// The labels of the variables, in the order of the correlation matrix.
pub fn PC::labels(self : PC) -> Array[String] {
  self.labels.copy()
}

///|
/// The significance level of the independence tests.
pub fn PC::alpha(self : PC) -> Double {
  self.alpha
}

///|
/// Run the algorithm and return the discovered CPDAG.
///
/// The result is kept, so that the accessors of the algorithm do not have to
/// run it a second time.
pub fn PC::learn_graph(self : PC) -> Cpdag {
  let cpdag = self.compute()
  self.result = Some(cpdag)
  cpdag
}

///|
/// The result of the last run of the algorithm.
///
/// The algorithm is run when it has not been run yet.
pub fn PC::graph(self : PC) -> Cpdag {
  match self.result {
    Some(cpdag) => cpdag
    None => self.learn_graph()
  }
}

///|
/// The undirected skeleton the algorithm discovers.
pub fn PC::skeleton(self : PC) -> @utils.Matrix {
  self.graph().skeleton()
}

///|
/// The adjacency matrix of the discovered graph.
pub fn PC::adjacency_matrix(self : PC) -> @utils.Matrix {
  self.graph().adjacency_matrix()
}

///|
/// Run the skeleton search and the orientation of the algorithm.
fn PC::compute(self : PC) -> Cpdag {
  let count = self.labels.length()
  let cit = FisherZ::new(self.corr, self.n, self.alpha)
  let adj = complete_graph(count)
  let sepsets = pc_skeleton(adj, cit, count)
  let oriented = orient(adj, sepsets, count)
  build_cpdag(self.labels, adj, oriented)
}

///|
/// The labels of the variables.
pub fn Cpdag::labels(self : Cpdag) -> Array[String] {
  self.labels.copy()
}

///|
/// The undirected skeleton of the graph.
pub fn Cpdag::skeleton(self : Cpdag) -> @utils.Matrix {
  self.skeleton.copy()
}

///|
/// The adjacency matrix of the graph.
///
/// A directed edge gives a one in the row of its source, an undirected edge
/// gives a one in the rows of both of its endpoints.
pub fn Cpdag::adjacency_matrix(self : Cpdag) -> @utils.Matrix {
  let count = self.labels.length()
  let out = @utils.Matrix::zeros(count, count)
  for i = 0; i < count; i = i + 1 {
    for j = 0; j < count; j = j + 1 {
      if self.directed.get(i, j) != 0.0 {
        out.set(i, j, 1.0)
      } else if self.undirected.get(i, j) != 0.0 {
        out.set(i, j, 1.0)
        out.set(j, i, 1.0)
      }
    }
  }
  out
}

///|
/// The directed edges of the graph, as pairs of labels.
pub fn Cpdag::directed_edges(self : Cpdag) -> Array[(String, String)] {
  let out : Array[(String, String)] = []
  let count = self.labels.length()
  for i = 0; i < count; i = i + 1 {
    for j = 0; j < count; j = j + 1 {
      if self.directed.get(i, j) != 0.0 {
        out.push((self.labels[i], self.labels[j]))
      }
    }
  }
  out
}

///|
/// The undirected edges of the graph, as pairs of labels.
pub fn Cpdag::undirected_edges(self : Cpdag) -> Array[(String, String)] {
  let out : Array[(String, String)] = []
  let count = self.labels.length()
  for i = 0; i < count; i = i + 1 {
    for j = i + 1; j < count; j = j + 1 {
      if self.undirected.get(i, j) != 0.0 {
        out.push((self.labels[i], self.labels[j]))
      }
    }
  }
  out
}

///|
/// Whether the graph has the directed edge from `from` to `to`.
pub fn Cpdag::has_directed_edge(
  self : Cpdag,
  from : String,
  to : String,
) -> Bool {
  match (self.index_of(from), self.index_of(to)) {
    (Some(i), Some(j)) => self.directed.get(i, j) != 0.0
    _ => false
  }
}

///|
/// Whether the graph has the undirected edge between `from` and `to`.
pub fn Cpdag::has_undirected_edge(
  self : Cpdag,
  from : String,
  to : String,
) -> Bool {
  match (self.index_of(from), self.index_of(to)) {
    (Some(i), Some(j)) => self.undirected.get(i, j) != 0.0
    _ => false
  }
}

///|
/// The v-structures of the graph.
///
/// Every entry is the triple `(x, z, y)` of the collider `x -> z <- y`.
pub fn Cpdag::v_structures(self : Cpdag) -> Array[(String, String, String)] {
  let out : Array[(String, String, String)] = []
  for (x, z, y) in self.v_structures {
    out.push((self.labels[x], self.labels[z], self.labels[y]))
  }
  out
}

///|
/// The graph in the `dowhy.graph.DirectedGraph` representation.
///
/// A directed edge of the CPDAG becomes a single edge of the directed graph,
/// an undirected edge becomes an edge in both directions, because a directed
/// graph cannot hold an undirected edge.
pub fn Cpdag::to_graph(self : Cpdag) -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  for label in self.labels {
    graph.add_node(label)
  }
  for (from, to) in self.directed_edges() {
    graph.add_edge(from, to)
  }
  for (from, to) in self.undirected_edges() {
    graph.add_edge(from, to)
    graph.add_edge(to, from)
  }
  graph
}

///|
/// The graph in Graphviz DOT format.
pub fn Cpdag::to_dot(self : Cpdag) -> String {
  self.to_graph().to_dot()
}

///|
/// The index of the given label in the matrices of the graph.
fn Cpdag::index_of(self : Cpdag, label : String) -> Int32? {
  let count = self.labels.length()
  for i = 0; i < count; i = i + 1 {
    if self.labels[i] == label {
      return Some(i)
    }
  }
  None
}

///|
/// The complete undirected graph over the given number of variables.
fn complete_graph(count : Int32) -> Array[Array[Bool]] {
  let adj : Array[Array[Bool]] = []
  for i = 0; i < count; i = i + 1 {
    let row : Array[Bool] = []
    for j = 0; j < count; j = j + 1 {
      row.push(i != j)
    }
    adj.push(row)
  }
  adj
}

///|
/// A square matrix of `false` values.
fn bool_matrix(count : Int32) -> Array[Array[Bool]] {
  let out : Array[Array[Bool]] = []
  for i = 0; i < count; i = i + 1 {
    let row : Array[Bool] = []
    for j = 0; j < count; j = j + 1 {
      row.push(false)
    }
    out.push(row)
  }
  out
}

///|
/// The neighbours of a variable in the skeleton.
fn neighbours(adj : Array[Array[Bool]], x : Int32) -> Array[Int32] {
  let out : Array[Int32] = []
  let count = adj.length()
  for j = 0; j < count; j = j + 1 {
    if adj[x][j] {
      out.push(j)
    }
  }
  out
}

///|
/// The key of a pair of variables in the map of the separation sets.
fn edge_key(x : Int32, y : Int32, count : Int32) -> Int32 {
  if x < y {
    x * count + y
  } else {
    y * count + x
  }
}

///|
/// All subsets of the given size of the given values.
fn combinations(values : Array[Int32], size : Int32) -> Array[Array[Int32]] {
  let out : Array[Array[Int32]] = []
  if size == 0 {
    out.push([])
    return out
  }
  if values.length() < size {
    return out
  }
  let current : Array[Int32] = []
  collect_combinations(values, size, 0, current, out)
  out
}

///|
/// Collect the subsets of the given size, starting at the given position.
fn collect_combinations(
  values : Array[Int32],
  size : Int32,
  start : Int32,
  current : Array[Int32],
  out : Array[Array[Int32]],
) -> Unit {
  if current.length() == size {
    out.push(current.copy())
    return
  }
  let missing = size - current.length()
  let mut i = start
  while i <= values.length() - missing {
    current.push(values[i])
    collect_combinations(values, size, i + 1, current, out)
    let _ = current.pop()
    i = i + 1
  }
}

///|
/// Remove the edges whose endpoints become conditionally independent.
///
/// The adjacency of the skeleton is updated in place and the separation set
/// of every removed edge is returned.
fn pc_skeleton(
  adj : Array[Array[Bool]],
  cit : FisherZ,
  count : Int32,
) -> Map[Int32, Array[Int32]] {
  let sepsets : Map[Int32, Array[Int32]] = Map([])
  let mut level = 0
  let mut removed = true
  while removed {
    removed = false
    for x = 0; x < count; x = x + 1 {
      for y = x + 1; y < count; y = y + 1 {
        if !adj[x][y] {
          continue
        }
        let candidates = neighbours(adj, x).filter(fn(k) { k != y })
        if candidates.length() < level {
          continue
        }
        for s in combinations(candidates, level) {
          if cit.is_independent(x, y, s) {
            adj[x][y] = false
            adj[y][x] = false
            sepsets.set(edge_key(x, y, count), s)
            removed = true
            break
          }
        }
      }
    }
    level = level + 1
    if level > count {
      break
    }
  }
  sepsets
}

///|
/// The result of the orientation of the skeleton.
priv struct Orientation {
  /// The directed edges of the graph.
  directed : Array[Array[Bool]]
  /// The undirected edges of the graph.
  undirected : Array[Array[Bool]]
  /// The v-structures of the graph.
  v_structures : Array[(Int32, Int32, Int32)]
}

///|
/// Orient the skeleton into a CPDAG.
///
/// The v-structures are oriented first and Meek's rules extend the
/// orientation afterwards.
fn orient(
  adj : Array[Array[Bool]],
  sepsets : Map[Int32, Array[Int32]],
  count : Int32,
) -> Orientation {
  let directed = bool_matrix(count)
  let undirected = bool_matrix(count)
  for x = 0; x < count; x = x + 1 {
    for y = x + 1; y < count; y = y + 1 {
      if adj[x][y] {
        undirected[x][y] = true
        undirected[y][x] = true
      }
    }
  }
  let v_structures : Array[(Int32, Int32, Int32)] = []
  for x = 0; x < count; x = x + 1 {
    for y = x + 1; y < count; y = y + 1 {
      if adj[x][y] {
        continue
      }
      let key = edge_key(x, y, count)
      if !sepsets.contains(key) {
        continue
      }
      let sep = sepsets.get(key).unwrap()
      for z = 0; z < count; z = z + 1 {
        if z == x || z == y {
          continue
        }
        if !adj[x][z] || !adj[y][z] {
          continue
        }
        if sep.contains(z) {
          continue
        }
        directed[x][z] = true
        directed[y][z] = true
        undirected[x][z] = false
        undirected[z][x] = false
        undirected[y][z] = false
        undirected[z][y] = false
        v_structures.push((x, z, y))
      }
    }
  }
  apply_meek_rules(directed, undirected, count)
  { directed, undirected, v_structures, }
}

///|
/// Extend the orientation of the graph with Meek's rules.
fn apply_meek_rules(
  directed : Array[Array[Bool]],
  undirected : Array[Array[Bool]],
  count : Int32,
) -> Unit {
  let mut changed = true
  while changed {
    changed = false
    for a = 0; a < count; a = a + 1 {
      for b = 0; b < count; b = b + 1 {
        if a == b || !undirected[a][b] {
          continue
        }
        if meek_orient(directed, undirected, a, b) {
          directed[a][b] = true
          directed[b][a] = false
          undirected[a][b] = false
          undirected[b][a] = false
          changed = true
        }
      }
    }
  }
}

///|
/// Whether Meek's rules orient the undirected edge `a - b` as `a -> b`.
fn meek_orient(
  directed : Array[Array[Bool]],
  undirected : Array[Array[Bool]],
  a : Int32,
  b : Int32,
) -> Bool {
  let count = directed.length()
  for c = 0; c < count; c = c + 1 {
    if c == a || c == b {
      continue
    }
    // Rule 1: `c -> b` and `a` and `c` are not adjacent.
    if directed[c][b] && !adjacent(directed, undirected, a, c) {
      return true
    }
    // Rule 2: `a -> c -> b`.
    if directed[a][c] && directed[c][b] {
      return true
    }
  }
  for c = 0; c < count; c = c + 1 {
    if c == a || c == b || !undirected[a][c] {
      continue
    }
    for d = 0; d < count; d = d + 1 {
      if d == a || d == b || d == c || !undirected[a][d] {
        continue
      }
      // Rule 3: `a - c`, `a - d`, `c -> b`, `d -> b` and `c` and `d` are
      // not adjacent.
      if directed[c][b] &&
        directed[d][b] &&
        !adjacent(directed, undirected, c, d) {
        return true
      }
    }
  }
  for c = 0; c < count; c = c + 1 {
    if c == a || c == b || !undirected[a][c] {
      continue
    }
    for d = 0; d < count; d = d + 1 {
      if d == a || d == b || d == c {
        continue
      }
      // Rule 4: `a - c`, `c -> d`, `d -> b` and `c` and `b` are not adjacent.
      if directed[c][d] &&
        directed[d][b] &&
        !adjacent(directed, undirected, c, b) {
        return true
      }
    }
  }
  false
}

///|
/// Whether the two variables are joined by an edge.
fn adjacent(
  directed : Array[Array[Bool]],
  undirected : Array[Array[Bool]],
  x : Int32,
  y : Int32,
) -> Bool {
  directed[x][y] || directed[y][x] || undirected[x][y]
}

///|
/// Build the CPDAG from the adjacency of the algorithm.
fn build_cpdag(
  labels : Array[String],
  adj : Array[Array[Bool]],
  oriented : Orientation,
) -> Cpdag {
  let count = labels.length()
  let skeleton = @utils.Matrix::zeros(count, count)
  let directed = @utils.Matrix::zeros(count, count)
  let undirected = @utils.Matrix::zeros(count, count)
  for i = 0; i < count; i = i + 1 {
    for j = 0; j < count; j = j + 1 {
      if adj[i][j] {
        skeleton.set(i, j, 1.0)
      }
      if oriented.directed[i][j] {
        directed.set(i, j, 1.0)
      }
      if oriented.undirected[i][j] {
        undirected.set(i, j, 1.0)
      }
    }
  }
  {
    labels,
    skeleton,
    directed,
    undirected,
    v_structures: oriented.v_structures,
  }
}
