///|
/// The tests of the confidence intervals that refit the causal model.
///
/// This is the port of the tests of `dowhy.gcm.confidence_intervals_cms`,
/// which are in `tests/gcm/test_confidence_intervals_cms.py`. The fixture is
/// the data of the upstream test, so the port sees the same rows as the
/// upstream, and the randomness comes from the deterministic generator of the
/// `utils` package.
///
/// The upstream test that binds the parameters of a query with the
/// `bootstrap_sampling` alias has no counterpart here: the alias of the
/// upstream is a plain `functools.partial`, and the estimation function of
/// the `confidence_intervals` of the port takes the seed of the resample
/// already.

///|
/// The seed of the generator of the tests.
const CMS_SEED : UInt64 = 2024UL

///|
/// The seed of the generator that draws the sample of the query.
const CMS_DRAW_SEED : UInt64 = 20240UL

///|
/// The data of the fixture.
///
/// This is the data of the upstream test
/// `test_given_causal_graph_based_estimation_func_when_confidence_interval_then_can_use_fit_and_compute`.
fn cms_data() -> @api.DataFrame {
  @api.DataFrame::from_numeric(
    ["X", "Y"],
    Map([
      ("X", [1.0, 3.0, 4.0, 4.0, 1.0, 3.0, 6.0, 3.0, 3.0, 6.0, 3.0, 4.0]),
      ("Y", [4.0, 5.0, 4.0, 4.0, 4.0, 5.0, 3.0, 6.0, 5.0, 3.0, 6.0, 4.0]),
    ]),
  )
}

///|
/// The model of the fixture, whose graph is `X -> Y`.
///
/// The root node has an empirical distribution, so its samples are the rows of
/// the column of the node, and the node with parents has an additive noise
/// model with a linear prediction.
fn cms_model() -> @gcm.ProbabilisticCausalModel {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X", "Y")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  model.set_root_model("X", @gcm.StochasticModel::empirical())
  model.set_causal_mechanism(
    "Y",
    @gcm.CausalMechanism::additive_noise(@gcm.PredictionModel::linear()),
  )
  model
}

///|
/// The model whose root node has a normal distribution.
///
/// The parameters of a normal distribution are fixed, so the fit of the model
/// keeps them, and the query can tell the distribution of the root node of the
/// copy from the one of the model of the caller.
fn cms_model_with_normal_root() -> @gcm.ProbabilisticCausalModel {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X", "Y")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  model.set_root_model("X", @gcm.StochasticModel::normal(0.0, 1.0))
  model.set_causal_mechanism(
    "Y",
    @gcm.CausalMechanism::additive_noise(@gcm.PredictionModel::linear()),
  )
  model
}

///|
/// The mean of the column of the root node of the model.
///
/// The root node has an empirical distribution, so the samples of the
/// distribution are the values of the column of the subset the model was
/// fitted on.
fn cms_mean_query(model : @gcm.ProbabilisticCausalModel) -> Array[Double] {
  match model.root_model("X") {
    Some(root) => [@utils.mean(root.samples())]
    None => [0.0]
  }
}

///|
/// The number of the rows the model was fitted on.
fn cms_row_count_query(model : @gcm.ProbabilisticCausalModel) -> Array[Double] {
  match model.root_model("X") {
    Some(root) => [root.samples().length().to_double()]
    None => [0.0]
  }
}

///|
/// The number of the nodes of the model that have a mechanism.
fn cms_mechanism_count_query(
  model : @gcm.ProbabilisticCausalModel,
) -> Array[Double] {
  let mut count = 0.0
  for node in model.nodes() {
    if model.has_causal_mechanism(node) {
      count = count + 1.0
    }
  }
  [count]
}

///|
/// Whether the distribution of the root node of the model is an empirical one.
fn cms_empirical_root_query(
  model : @gcm.ProbabilisticCausalModel,
) -> Array[Double] {
  match model.root_model("X") {
    Some(root) =>
      match root.kind() {
        @gcm.StochasticModelKind::Empirical => [1.0]
        _ => [0.0]
      }
    None => [0.0]
  }
}

///|
/// A single sample of the root node of the model.
///
/// This is the query of the upstream test, which draws one sample of the
/// model and returns the value of the variable.
fn cms_draw_query(model : @gcm.ProbabilisticCausalModel) -> Array[Double] {
  let samples = @gcm.draw_samples(model, 1, @utils.Random::new(CMS_DRAW_SEED))
  [samples.numeric("X")[0]]
}

///|
/// Whether the two results are the same.
fn cms_same_result(a : Array[Double], b : Array[Double]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i = 0; i < a.length(); i = i + 1 {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
/// test "the confidence intervals accept the function of the fit and the
/// compute"
///
/// This is the port of the upstream test
/// `test_given_causal_graph_based_estimation_func_when_confidence_interval_then_can_use_fit_and_compute`.
/// The interval of the bootstrap holds its summary, which is the geometric
/// median of the results.
test "the confidence intervals accept the function of the fit and the compute" {
  let model = cms_model()
  let data = cms_data()
  @gcm.fit(model, data)
  let (summary, intervals) = @gcm.confidence_intervals(
    @gcm.fit_and_compute(cms_mean_query, model, data, 0.75, None),
    0.95,
    20,
    fn(results : @utils.Matrix) -> Array[Double] {
      @gcm.estimate_geometric_median(results)
    },
    @utils.Random::new(CMS_SEED),
  )
  assert_eq(summary.length(), 1)
  assert_eq(intervals.length(), 1)
  assert_eq(intervals[0].length(), 2)
  assert_true(intervals[0][0] <= summary[0])
  assert_true(summary[0] <= intervals[0][1])
}

///|
/// test "the same seed gives the same result and another seed another result"
///
/// The subset of the data is drawn from the seed of the call, so the same
/// seed always gives the same subset and the same result.
test "the same seed gives the same result and another seed another result" {
  let model = cms_model()
  let data = cms_data()
  @gcm.fit(model, data)
  let estimation = @gcm.fit_and_compute(cms_mean_query, model, data, 0.75, None)
  let first = estimation(CMS_SEED)
  let again = estimation(CMS_SEED)
  assert_true(cms_same_result(first, again))
  let other = estimation(CMS_SEED + 1UL)
  assert_false(cms_same_result(first, other))
}

///|
/// test "the subset is smaller than the whole training data"
///
/// The fraction of the subset is 0.75, so the model is fitted on nine of the
/// twelve rows of the training data.
test "the subset is smaller than the whole training data" {
  let model = cms_model()
  let data = cms_data()
  @gcm.fit(model, data)
  let estimation = @gcm.fit_and_compute(
    cms_row_count_query,
    model,
    data,
    0.75,
    None,
  )
  let result = estimation(CMS_SEED)
  assert_eq(result.length(), 1)
  assert_eq(result[0], 9.0)
  assert_true(result[0] < data.nrows().to_double())
}

///|
/// test "the quality assigns the mechanisms of the copy again"
///
/// The model of the caller has no mechanism at all, so the copy has a
/// mechanism for every node only when the quality assigns them.
test "the quality assigns the mechanisms of the copy again" {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X", "Y")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  let estimation = @gcm.fit_and_compute(
    cms_mechanism_count_query,
    model,
    cms_data(),
    0.75,
    Some(@gcm.AssignmentQuality::good()),
  )
  let result = estimation(CMS_SEED)
  assert_eq(result.length(), 1)
  assert_eq(result[0], 2.0)
}

///|
/// test "the quality replaces the mechanisms of the model"
///
/// The root node of the model has a normal distribution, which the fit keeps,
/// so the copy keeps it as well when no quality is given. The automatic
/// assignment replaces it with an empirical distribution, which is what the
/// upstream does when a quality is given.
test "the quality replaces the mechanisms of the model" {
  let model = cms_model_with_normal_root()
  let data = cms_data()
  let without_quality = @gcm.fit_and_compute(
    cms_empirical_root_query,
    model,
    data,
    0.75,
    None,
  )
  assert_eq(without_quality(CMS_SEED)[0], 0.0)
  let with_quality = @gcm.fit_and_compute(
    cms_empirical_root_query,
    model,
    data,
    0.75,
    Some(@gcm.AssignmentQuality::good()),
  )
  assert_eq(with_quality(CMS_SEED)[0], 1.0)
}

///|
/// test "the mean query returns the mean of the column of the node"
///
/// The fraction of the subset is one, so the subset is the whole training
/// data and the mean of the column of the root node is the mean of the
/// training data.
test "the mean query returns the mean of the column of the node" {
  let model = cms_model()
  let data = cms_data()
  @gcm.fit(model, data)
  let estimation = @gcm.fit_and_compute(cms_mean_query, model, data, 1.0, None)
  let result = estimation(CMS_SEED)
  assert_eq(result.length(), 1)
  assert_true((result[0] - @utils.mean(data.numeric("X"))).abs() < 1.0e-12)
}

///|
/// test "the fit and the compute leave the model of the caller alone"
///
/// The copy of the model is the one that is fitted, so the mechanisms of the
/// model of the caller keep the values they had.
test "the fit and the compute leave the model of the caller alone" {
  let model = cms_model_with_normal_root()
  let estimation = @gcm.fit_and_compute(
    cms_empirical_root_query,
    model,
    cms_data(),
    0.75,
    None,
  )
  let _ = estimation(CMS_SEED)
  let root = match model.root_model("X") {
    Some(root) => root
    None => abort("the node X has no distribution")
  }
  let is_normal = match root.kind() {
    @gcm.StochasticModelKind::Normal => true
    _ => false
  }
  assert_true(is_normal)
  // The model of the caller was not fitted, so it has no local structure.
  assert_false(@gcm.has_valid_local_structure(model, "Y"))
}

///|
/// test "the confidence interval of a drawn sample lies in the range of the
/// data"
///
/// This is the second part of the upstream test: the query draws one sample
/// of the model, so the results of the bootstrap are values of the column of
/// the root node and their interval lies in the range of the data.
test "the confidence interval of a drawn sample lies in the range of the data" {
  let model = cms_model()
  let data = cms_data()
  @gcm.fit(model, data)
  let (summary, intervals) = @gcm.confidence_intervals(
    @gcm.fit_and_compute(cms_draw_query, model, data, 0.5, None),
    0.95,
    20,
    fn(results : @utils.Matrix) -> Array[Double] {
      @gcm.estimate_geometric_median(results)
    },
    @utils.Random::new(CMS_SEED),
  )
  assert_eq(summary.length(), 1)
  assert_eq(intervals.length(), 1)
  // The column of the root node holds the values 1, 3, 4 and 6, so every
  // result and every bound of the interval lies in that range.
  assert_true(summary[0] >= 1.0 && summary[0] <= 6.0)
  assert_true(intervals[0][0] >= 1.0 && intervals[0][1] <= 6.0)
  assert_true(intervals[0][0] <= summary[0])
  assert_true(summary[0] <= intervals[0][1])
}
