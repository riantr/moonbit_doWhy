///|
/// The tests of the noise of the `gcm` package.
///
/// The expectations are the ones of the upstream tests of `dowhy.gcm._noise`,
/// which are in `tests/gcm/test_noise.py`. The upstream
/// `get_noise_dependent_function` is not part of the port, so the four tests
/// of the upstream that use it have no counterpart here.
///
/// The fixtures are drawn with the deterministic generator of the `utils`
/// package, and the expected numbers are the ones the upstream `dowhy.gcm._noise`
/// produces on the very same rows, which `_verify/gcm_noise_reference.py`
/// prints.

///|
/// The seed of the fixtures.
const NOISE_SEED : UInt64 = 2040UL

///|
/// The number of rows of the fixtures.
const NOISE_ROWS : Int32 = 1000

///|
/// The number of rows of the fixture of the single row.
const NOISE_SINGLE_ROWS : Int32 = 10

///|
/// The size of the noise of the fixtures.
const NOISE_SCALE : Double = 0.1

///|
/// The tolerance of the comparison of the numbers of the reference script.
const NOISE_TOLERANCE : Double = 1.0e-12

///|
/// Whether two numbers agree to the tolerance of the comparison.
fn noise_near(a : Double, b : Double, tolerance : Double) -> Bool {
  (a - b).abs() <= tolerance
}

///|
/// Whether two columns of numbers agree to the tolerance of the comparison.
fn noise_columns_near(
  a : Array[Double],
  b : Array[Double],
  tolerance : Double,
) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i = 0; i < a.length(); i = i + 1 {
    if !noise_near(a[i], b[i], tolerance) {
      return false
    }
  }
  true
}

///|
/// The noise of the four nodes of the fixture of the upstream test.
///
/// The noise of the root node is uniform on `[-1, 1]`, like the upstream one,
/// and the noise of the other three nodes is normal.
fn noise_columns() -> (
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let rng = @utils.Random::new(NOISE_SEED)
  let n0 : Array[Double] = []
  for _ in 0..<NOISE_ROWS {
    n0.push(2.0 * rng.next_double() - 1.0)
  }
  let n1 : Array[Double] = []
  for _ in 0..<NOISE_ROWS {
    n1.push(NOISE_SCALE * rng.next_normal())
  }
  let n2 : Array[Double] = []
  for _ in 0..<NOISE_ROWS {
    n2.push(NOISE_SCALE * rng.next_normal())
  }
  let n3 : Array[Double] = []
  for _ in 0..<NOISE_ROWS {
    n3.push(NOISE_SCALE * rng.next_normal())
  }
  (n0, n1, n2, n3)
}

///|
/// The data of the four nodes of the fixture of the upstream test.
fn noise_data_columns() -> (
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let (n0, n1, n2, n3) = noise_columns()
  let x0 = n0.copy()
  let x1 : Array[Double] = []
  for i in 0..<NOISE_ROWS {
    x1.push(2.0 * x0[i] + n1[i])
  }
  let x2 : Array[Double] = []
  for i in 0..<NOISE_ROWS {
    x2.push(0.5 * x0[i] + n2[i])
  }
  let x3 : Array[Double] = []
  for i in 0..<NOISE_ROWS {
    x3.push(0.5 * x2[i] + n3[i])
  }
  (x0, x1, x2, x3)
}

///|
/// The frame of the fixture of the upstream test.
fn noise_fixture() -> (@api.DataFrame, @api.DataFrame) {
  let (n0, n1, n2, n3) = noise_columns()
  let (x0, x1, x2, x3) = noise_data_columns()
  let noise = @api.DataFrame::from_numeric(
    ["X0", "X1", "X2", "X3"],
    Map([("X0", n0), ("X1", n1), ("X2", n2), ("X3", n3)]),
  )
  let data = @api.DataFrame::from_numeric(
    ["X0", "X1", "X2", "X3"],
    Map([("X0", x0), ("X1", x1), ("X2", x2), ("X3", x3)]),
  )
  (data, noise)
}

///|
/// The model of the fixture of the upstream test.
///
/// The mechanisms of the three nodes with parents have fixed parameters, so
/// that the data of the model follow from the noise of its nodes exactly. The
/// model is fitted on the data, which stores the parents of every node and
/// the encoding of its parents; the upstream stores the parents with its
/// `_persist_parents` helper and encodes the parents when it fits a
/// mechanism.
fn noise_model(data : @api.DataFrame) -> @gcm.ProbabilisticCausalModel {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "X1")
  graph.add_edge("X0", "X2")
  graph.add_edge("X2", "X3")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  model.set_root_model("X0", @gcm.StochasticModel::empirical())
  model.set_causal_mechanism(
    "X1",
    @gcm.CausalMechanism::additive_noise(
      @gcm.PredictionModel::with_fixed_parameters([2.0], 0.0),
    ),
  )
  model.set_causal_mechanism(
    "X2",
    @gcm.CausalMechanism::additive_noise(
      @gcm.PredictionModel::with_fixed_parameters([0.5], 0.0),
    ),
  )
  model.set_causal_mechanism(
    "X3",
    @gcm.CausalMechanism::additive_noise(
      @gcm.PredictionModel::with_fixed_parameters([0.5], 0.0),
    ),
  )
  @gcm.fit(model, data)
  model
}

///|
/// The model whose node `X3` has the parents `X2` and `X1`.
///
/// The edges are added in an order that is not the sorted one, so the parents
/// of the node in the order of the edges are not the parents the upstream
/// takes: the upstream sorts them with `dowhy.graph.get_ordered_predecessors`.
fn noise_two_parent_model(
  data : @api.DataFrame,
) -> @gcm.ProbabilisticCausalModel {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "X1")
  graph.add_edge("X0", "X2")
  graph.add_edge("X2", "X3")
  graph.add_edge("X1", "X3")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  model.set_root_model("X0", @gcm.StochasticModel::empirical())
  model.set_causal_mechanism(
    "X1",
    @gcm.CausalMechanism::additive_noise(
      @gcm.PredictionModel::with_fixed_parameters([2.0], 0.0),
    ),
  )
  model.set_causal_mechanism(
    "X2",
    @gcm.CausalMechanism::additive_noise(
      @gcm.PredictionModel::with_fixed_parameters([0.5], 0.0),
    ),
  )
  model.set_causal_mechanism(
    "X3",
    @gcm.CausalMechanism::additive_noise(
      @gcm.PredictionModel::with_fixed_parameters([2.0, 3.0], 0.0),
    ),
  )
  @gcm.fit(model, data)
  model
}

///|
/// The data of the fixture whose node `X3` has two parents.
fn noise_two_parent_data() -> (@api.DataFrame, @api.DataFrame) {
  let (n0, n1, n2, n3) = noise_columns()
  let x0 = n0.copy()
  let x1 : Array[Double] = []
  for i in 0..<NOISE_ROWS {
    x1.push(2.0 * x0[i] + n1[i])
  }
  let x2 : Array[Double] = []
  for i in 0..<NOISE_ROWS {
    x2.push(0.5 * x0[i] + n2[i])
  }
  let x3 : Array[Double] = []
  for i in 0..<NOISE_ROWS {
    x3.push(2.0 * x1[i] + 3.0 * x2[i] + n3[i])
  }
  let noise = @api.DataFrame::from_numeric(
    ["X0", "X1", "X2", "X3"],
    Map([("X0", n0), ("X1", n1), ("X2", n2), ("X3", n3)]),
  )
  let data = @api.DataFrame::from_numeric(
    ["X0", "X1", "X2", "X3"],
    Map([("X0", x0), ("X1", x1), ("X2", x2), ("X3", x3)]),
  )
  (data, noise)
}

///|
test "the data of a causal model are computed from the noise of its nodes" {
  let (data, noise) = noise_fixture()
  let model = noise_model(data)
  let computed = @gcm.compute_data_from_noise(model, noise)
  for node in ["X0", "X1", "X2", "X3"] {
    assert_true(
      noise_columns_near(
        computed.numeric(node),
        data.numeric(node),
        NOISE_TOLERANCE,
      ),
    )
  }
  assert_true(
    noise_near(computed.numeric("X0")[0], -0.999999762536, NOISE_TOLERANCE),
  )
  assert_true(
    noise_near(computed.numeric("X1")[0], -1.846678759887, NOISE_TOLERANCE),
  )
  assert_true(
    noise_near(computed.numeric("X2")[0], -0.449361357855, NOISE_TOLERANCE),
  )
  assert_true(
    noise_near(computed.numeric("X3")[0], -0.234158736467, NOISE_TOLERANCE),
  )
}

///|
test "the noise of a causal model is computed from the data of its nodes" {
  let (data, noise) = noise_fixture()
  let model = noise_model(data)
  let computed = @gcm.compute_noise_from_data(model, data)
  for node in ["X0", "X1", "X2", "X3"] {
    assert_true(
      noise_columns_near(
        computed.numeric(node),
        noise.numeric(node),
        NOISE_TOLERANCE,
      ),
    )
  }
  assert_true(
    noise_near(computed.numeric("X0")[0], -0.999999762536, NOISE_TOLERANCE),
  )
  assert_true(
    noise_near(computed.numeric("X1")[0], 0.153320765186, NOISE_TOLERANCE),
  )
  assert_true(
    noise_near(computed.numeric("X2")[0], 0.050638523413, NOISE_TOLERANCE),
  )
  assert_true(
    noise_near(computed.numeric("X3")[0], -0.009478057539, NOISE_TOLERANCE),
  )
}

///|
test "the data of a causal model whose node has two parents are computed from the sorted parents" {
  let (data, noise) = noise_two_parent_data()
  let model = noise_two_parent_model(data)
  let computed = @gcm.compute_data_from_noise(model, noise)
  for node in ["X0", "X1", "X2", "X3"] {
    assert_true(
      noise_columns_near(
        computed.numeric(node),
        data.numeric(node),
        NOISE_TOLERANCE,
      ),
    )
  }
  assert_true(
    noise_near(computed.numeric("X3")[0], -5.050919650878, NOISE_TOLERANCE),
  )
}

///|
test "the noise of a causal model whose node has two parents is computed from the sorted parents" {
  let (data, noise) = noise_two_parent_data()
  let model = noise_two_parent_model(data)
  let computed = @gcm.compute_noise_from_data(model, data)
  for node in ["X0", "X1", "X2", "X3"] {
    assert_true(
      noise_columns_near(
        computed.numeric(node),
        noise.numeric(node),
        NOISE_TOLERANCE,
      ),
    )
  }
  assert_true(
    noise_near(computed.numeric("X3")[0], -0.009478057539, NOISE_TOLERANCE),
  )
}

///|
test "the noise of a causal model is computed from a single row of data" {
  let rng = @utils.Random::new(NOISE_SEED)
  let x0 : Array[Double] = []
  for _ in 0..<NOISE_SINGLE_ROWS {
    x0.push(rng.next_normal())
  }
  let x1 : Array[Double] = []
  for i in 0..<NOISE_SINGLE_ROWS {
    x1.push(x0[i] + NOISE_SCALE * rng.next_normal())
  }
  let data = @api.DataFrame::from_numeric(
    ["X0", "X1"],
    Map([("X0", x0), ("X1", x1)]),
  )
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "X1")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  let _ = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
  )
  @gcm.fit(model, data)
  let noise = @gcm.compute_noise_from_data(model, data.take_rows([0]))
  assert_eq(noise.nrows(), 1)
  assert_true(noise.has_column("X0"))
  assert_true(noise.has_column("X1"))
}
