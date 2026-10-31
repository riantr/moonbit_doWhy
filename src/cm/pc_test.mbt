/// Tests for the causal discovery algorithms of the package.

///|
/// A four variable linear Gaussian DAG with the edges `x -> y`, `z -> y` and
/// `x -> w`.
///
/// The data are generated inside the package, so that the package keeps a
/// clean dependency set and does not rely on the `datasets` package.
fn linear_gaussian_dag(rows : Int32, seed : UInt64) -> @api.DataFrame {
  let rng = @utils.Random::new(seed)
  let xs : Array[Double] = []
  let ys : Array[Double] = []
  let zs : Array[Double] = []
  let ws : Array[Double] = []
  for i = 0; i < rows; i = i + 1 {
    let x = rng.next_normal()
    let z = rng.next_normal()
    let w = 0.8 * x + rng.next_normal()
    let y = 0.8 * x + 0.8 * z + rng.next_normal()
    xs.push(x)
    ys.push(y)
    zs.push(z)
    ws.push(w)
  }
  @api.DataFrame::from_numeric(
    ["x", "y", "z", "w"],
    Map([("x", xs), ("y", ys), ("z", zs), ("w", ws)]),
  )
}

///|
/// The labels of the variables of the fixture.
fn fixture_labels() -> Array[String] {
  ["x", "y", "z", "w"]
}

///|
test "the fisher z test separates the dependent from the independent variables" {
  let frame = linear_gaussian_dag(500, 7UL)
  let labels = fixture_labels()
  let corr = @cm.correlation_matrix(frame, labels)
  let cit = @cm.FisherZ::new(corr, 500, 0.05)
  // `x` and `y` are joined by an edge, `x` and `z` are not.
  assert_false(cit.is_independent(0, 1, []))
  assert_true(cit.is_independent(0, 2, []))
  // Conditioning on `z` does not d-separate `x` and `y`.
  assert_false(cit.is_independent(0, 1, [2]))
  let result = cit.check(0, 1, [])
  assert_true(result.correlation() > 0.3)
  assert_true(result.p_value() < 0.05)
  assert_true(result.statistic().abs() > cit.critical_value())
  // The result of the test carries the Fisher transform of the correlation.
  assert_true(result.z() > 0.0)
}

///|
test "the pc algorithm recovers the skeleton of a linear gaussian dag" {
  let frame = linear_gaussian_dag(1000, 42UL)
  let labels = fixture_labels()
  let corr = @cm.correlation_matrix(frame, labels)
  let cpdag = @cm.PC::new(labels, corr, 1000, 0.05).learn_graph()
  let skeleton = cpdag.skeleton()
  // The skeleton keeps `x - y`, `x - w` and `y - z`.
  assert_eq(skeleton.get(0, 1), 1.0)
  assert_eq(skeleton.get(0, 3), 1.0)
  assert_eq(skeleton.get(1, 2), 1.0)
  // The pairs `x - z`, `y - w` and `z - w` are separated.
  assert_eq(skeleton.get(0, 2), 0.0)
  assert_eq(skeleton.get(1, 3), 0.0)
  assert_eq(skeleton.get(2, 3), 0.0)
}

///|
test "the pc algorithm orients the v-structure of a linear gaussian dag" {
  let frame = linear_gaussian_dag(1000, 42UL)
  let labels = fixture_labels()
  let corr = @cm.correlation_matrix(frame, labels)
  let cpdag = @cm.PC::new(labels, corr, 1000, 0.05).learn_graph()
  // The collider `x -> y <- z` is oriented.
  assert_true(cpdag.has_directed_edge("x", "y"))
  assert_true(cpdag.has_directed_edge("z", "y"))
  assert_false(cpdag.has_directed_edge("y", "x"))
  assert_false(cpdag.has_directed_edge("y", "z"))
  // The edge `x - w` is not part of a collider and stays undirected.
  assert_true(cpdag.has_undirected_edge("x", "w"))
  assert_false(cpdag.has_directed_edge("x", "w"))
  assert_false(cpdag.has_directed_edge("w", "x"))
  // The v-structure is reported.
  let colliders = cpdag.v_structures()
  assert_eq(colliders.length(), 1)
  assert_eq(colliders[0].0, "x")
  assert_eq(colliders[0].1, "y")
  assert_eq(colliders[0].2, "z")
  // The adjacency matrix holds the directed edges only.
  let adjacency = cpdag.adjacency_matrix()
  assert_eq(adjacency.get(0, 1), 1.0)
  assert_eq(adjacency.get(2, 1), 1.0)
  assert_eq(adjacency.get(1, 0), 0.0)
  assert_eq(adjacency.get(0, 2), 0.0)
}

///|
test "the pc algorithm exposes the skeleton and the adjacency matrix" {
  let frame = linear_gaussian_dag(1000, 42UL)
  let labels = fixture_labels()
  let corr = @cm.correlation_matrix(frame, labels)
  let pc = @cm.PC::new(labels, corr, 1000, 0.05)
  let skeleton = pc.skeleton()
  let adjacency = pc.adjacency_matrix()
  assert_eq(skeleton.nrows(), 4)
  assert_eq(adjacency.nrows(), 4)
  assert_eq(skeleton.get(0, 1), 1.0)
  assert_eq(adjacency.get(0, 1), 1.0)
  // The result of the algorithm is kept, so it does not change between calls.
  assert_eq(pc.graph().skeleton().get(0, 1), 1.0)
}

///|
test "the graph learner discovers the graph of the data" {
  let frame = linear_gaussian_dag(1000, 42UL)
  let learner = @cm.GraphLearner::of(frame, 0.05)
  let graph = learner.learn_graph()
  assert_eq(graph.node_count(), 4)
  assert_true(graph.has_node("x"))
  assert_true(graph.has_node("w"))
  // The directed edges of the collider are kept.
  assert_true(graph.has_edge("x", "y"))
  assert_true(graph.has_edge("z", "y"))
  assert_false(graph.has_edge("y", "x"))
  // The undirected edge is stored in both directions.
  assert_true(graph.has_edge("x", "w"))
  assert_true(graph.has_edge("w", "x"))
  assert_false(graph.has_edge("x", "z"))
  let adjacency = learner.get_adjacency_matrix()
  assert_eq(adjacency.nrows(), 4)
  assert_eq(adjacency.get(0, 1), 1.0)
  assert_eq(adjacency.get(0, 2), 0.0)
}

///|
test "the graph learner renders the discovered graph as dot" {
  let frame = linear_gaussian_dag(1000, 42UL)
  let learner = @cm.GraphLearner::of(frame, 0.05)
  let graph = learner.learn_graph()
  let dot = learner.to_dot()
  assert_true(dot.contains("digraph"))
  assert_true(dot.contains("\"x\" -> \"y\""))
  assert_true(dot.contains("\"z\" -> \"y\""))
  // The dot representation is the one of the discovered graph.
  assert_eq(dot, graph.to_dot())
}
