///|
/// The base class of the causal discovery methods, the port of
/// `dowhy.graph_learner.GraphLearner`.
///
/// The learner owns the data, the labels of the variables and the discovered
/// graph. `learn_graph` runs the PC algorithm over the data and fills the
/// adjacency matrix and the graph, `to_dot` renders the discovered graph.
pub struct GraphLearner {
  /// The data the graph is discovered from.
  data : @api.DataFrame
  /// The labels of the variables, in the order of the columns.
  labels : Array[String]
  /// The significance level of the independence tests.
  alpha : Double
  /// The adjacency matrix of the discovered graph.
  mut adjacency_matrix : @utils.Matrix
  /// The discovered graph.
  mut graph : @graph.DirectedGraph
}

///|
/// Build a graph learner for the given data.
///
/// The labels are the names of the variables, in the order of the columns of
/// the data.
pub fn GraphLearner::new(
  data : @api.DataFrame,
  labels : Array[String],
  alpha : Double,
) -> GraphLearner {
  {
    data,
    labels,
    alpha,
    adjacency_matrix: @utils.Matrix::zeros(0, 0),
    graph: @graph.DirectedGraph::new(),
  }
}

///|
/// Build a graph learner that uses the column names of the frame as labels.
pub fn GraphLearner::of(data : @api.DataFrame, alpha : Double) -> GraphLearner {
  GraphLearner::new(data, data.column_names(), alpha)
}

///|
/// The labels of the variables.
pub fn GraphLearner::labels(self : GraphLearner) -> Array[String] {
  self.labels.copy()
}

///|
/// The significance level of the independence tests.
pub fn GraphLearner::alpha(self : GraphLearner) -> Double {
  self.alpha
}

///|
/// Discover the causal graph of the data.
///
/// The PC algorithm is run over the correlation matrix of the data and the
/// discovered graph is returned.
pub fn GraphLearner::learn_graph(self : GraphLearner) -> @graph.DirectedGraph {
  let corr = correlation_matrix(self.data, self.labels)
  let pc = PC::new(self.labels, corr, self.data.nrows(), self.alpha)
  let cpdag = pc.learn_graph()
  self.adjacency_matrix = cpdag.adjacency_matrix()
  self.graph = cpdag.to_graph()
  self.graph
}

///|
/// The discovered graph in Graphviz DOT format.
pub fn GraphLearner::to_dot(self : GraphLearner) -> String {
  self.graph.to_dot()
}

///|
/// The adjacency matrix of the discovered graph.
pub fn GraphLearner::get_adjacency_matrix(self : GraphLearner) -> @utils.Matrix {
  self.adjacency_matrix.copy()
}

///|
/// The Pearson correlation matrix of the given columns of the frame.
///
/// The diagonal of the matrix is one and the matrix is symmetric.
pub fn correlation_matrix(
  data : @api.DataFrame,
  labels : Array[String],
) -> @utils.Matrix {
  let count = labels.length()
  let corr = @utils.Matrix::zeros(count, count)
  for i = 0; i < count; i = i + 1 {
    let left = data.numeric(labels[i])
    for j = i; j < count; j = j + 1 {
      let right = data.numeric(labels[j])
      let value = if i == j { 1.0 } else { pearson(left, right) }
      corr.set(i, j, value)
      corr.set(j, i, value)
    }
  }
  corr
}

///|
/// The Pearson correlation coefficient of two samples.
fn pearson(left : Array[Double], right : Array[Double]) -> Double {
  let n = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  if n < 2 {
    return 0.0
  }
  let sum_left = @utils.mean(left)
  let sum_right = @utils.mean(right)
  let mut covariance = 0.0
  let mut variance_left = 0.0
  let mut variance_right = 0.0
  for i = 0; i < n; i = i + 1 {
    let dx = left[i] - sum_left
    let dy = right[i] - sum_right
    covariance = covariance + dx * dy
    variance_left = variance_left + dx * dx
    variance_right = variance_right + dy * dy
  }
  if variance_left <= 0.0 || variance_right <= 0.0 {
    return 0.0
  }
  covariance / (variance_left * variance_right).sqrt()
}
