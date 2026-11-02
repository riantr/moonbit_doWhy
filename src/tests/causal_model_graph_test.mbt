/// The tests of the causal model with a graph.
///
/// The cases are the tests of the upstream file `tests/test_causal_model.py`
/// that the port can run: the GML graph of `test_graph_input` and of
/// `test_graph_input2`, the graph of the daggity web site of `test_graph_input3`
/// and of `test_graph_input4`, the graph object of `test_graph_input_nx`, the
/// observed and the unobserved variables of
/// `test_unobserved_graph_variables_log_warning`, the format check of
/// `test_incorrect_graph_format`, the cache of the estimators of
/// `test_causal_estimator_cache` and the conditional estimates of
/// `test_cate_estimates_regression`.
///
/// The facts of the upstream that these tests compare against are computed by
/// the script `_verify/causal_model_reference.py`.

///|
/// The seed of the fixture of the causal model tests.
const CAUSAL_MODEL_SEED : Int32 = 42

///|
/// The number of samples of the fixture of the causal model tests.
const CAUSAL_MODEL_NUM_SAMPLES : Int32 = 100

///|
/// The data set of the upstream tests: five common causes, one instrument and
/// one binary treatment.
fn graph_fixture() -> @datasets.Dataset {
  @datasets.linear_dataset(
    CAUSAL_MODEL_SEED,
    CAUSAL_MODEL_NUM_SAMPLES,
    @datasets.LinearConfig::five_common_causes_one_instrument(),
  )
}

///|
/// The model of the fixture, with the given graph.
fn model_with_graph(
  dataset : @datasets.Dataset,
  graph : String,
) -> @moonbit_dowhy.CausalModel {
  @moonbit_dowhy.CausalModel::new_with_graph_string(
    dataset.frame(),
    dataset.treatments(),
    [dataset.outcome()],
    graph,
    [],
    [],
    [],
    missing_nodes_as_confounders=true,
  )
}

///|
/// The GML graph of the upstream test `test_graph_input`.
///
/// The `{0}` of the upstream is the treatment and the `{1}` is the outcome.
fn upstream_gml_graph() -> String {
  "graph[directed 1 node[ id \"v0\" label \"v0\"]node[ id \"y\" label \"y\"]" +
  "node[ id \"Unobserved Confounders\" label \"Unobserved Confounders\"]" +
  "edge[source \"v0\" target \"y\"]" +
  "edge[source \"Unobserved Confounders\" target \"v0\"]" +
  "edge[source \"Unobserved Confounders\" target \"y\"]" +
  "node[ id \"X0\" label \"X0\"] edge[ source \"X0\" target \"v0\"]" +
  " node[ id \"X1\" label \"X1\"] edge[ source \"X1\" target \"v0\"]" +
  " node[ id \"X2\" label \"X2\"] edge[ source \"X2\" target \"v0\"]" +
  " edge[ source \"X0\" target \"y\"] edge[ source \"X1\" target \"y\"]" +
  " edge[ source \"X2\" target \"y\"] node[ id \"Z0\" label \"Z0\"]" +
  " edge[ source \"Z0\" target \"v0\"]]"
}

///|
/// The GML graph of the upstream test `test_graph_input2`.
///
/// The upstream writes the same graph as the one of `test_graph_input`, but
/// spread over many lines, so that the reader has to cope with the newlines
/// and with the spaces between the tokens.
fn upstream_gml_graph_over_many_lines() -> String {
  let lines = [
    "graph[", "        directed 1 ", "        node[ id \"v0\" ", "        label \"v0\"",
    "        ]", "        node [ ", "        id \"y\" ", "        label \"y\"", "        ]",
    "        node [ ", "        id \"Unobserved Confounders\" ", "        label \"Unobserved Confounders\"",
    "        ]", "        edge[", "        source \"v0\" ", "        target \"y\"",
    "        ]", "        edge[", "        source \"Unobserved Confounders\" ", "        target \"v0\"",
    "        ]", "        edge[", "        source \"Unobserved Confounders\" ", "        target \"y\"",
    "        ]", "        node[ ", "        id \"X0\" ", "        label \"X0\"",
    "        ] ", "        edge[ ", "        source \"X0\" ", "        target \"v0\"",
    "        ] ", "        node[ ", "        id \"X1\" ", "        label \"X1\"",
    "        ] ", "        edge[ ", "        source \"X1\" ", "        target \"v0\"",
    "        ] ", "        node[ ", "        id \"X2\" ", "        label \"X2\"",
    "        ] ", "        edge[ ", "        source \"X2\" ", "        target \"v0\"",
    "        ] ", "        edge[ ", "        source \"X0\" ", "        target \"y\"",
    "        ] ", "        edge[ ", "        source \"X1\" ", "        target \"y\"",
    "        ] ", "        edge[ ", "        source \"X2\" ", "        target \"y\"",
    "        ] ", "        node[ ", "        id \"Z0\" ", "        label \"Z0\"",
    "        ] ", "        edge[", "        source \"Z0\" ", "        target \"v0\"",
    "        ]]",
  ]
  lines.join("\n")
}

///|
/// The graph of the daggity web site of the upstream test `test_graph_input3`.
fn upstream_daggity_graph() -> String {
  let lines = [
    "dag {", "        \"Unobserved Confounders\" [pos=\"0.491,-1.056\"]", "        X0 [pos=\"-2.109,0.057\"]",
    "        X1 [adjusted, pos=\"-0.453,-1.562\"]", "        X2 [pos=\"-2.268,-1.210\"]",
    "        Z0 [pos=\"-1.918,-1.735\"]", "        v0 [latent, pos=\"-1.525,-1.293\"]",
    "        y [outcome, pos=\"-1.164,-0.116\"]", "        \"Unobserved Confounders\" -> v0",
    "        \"Unobserved Confounders\" -> y", "        X0 -> v0", "        X0 -> y",
    "        X1 -> v0", "        X1 -> y", "        X2 -> v0", "        X2 -> y",
    "        Z0 -> v0", "        v0 -> y", "        }", "        ",
  ]
  lines.join("\n")
}

///|
/// The graph of the daggity web site of the upstream file `tests/sample_dag.txt`,
/// which the upstream test `test_graph_input4` reads.
fn upstream_sample_dag() -> String {
  let lines = [
    "dag {", "\"Unobserved Confounders\" [pos=\"0.491,-1.056\"]", "W0", "X0 [pos=\"-2.109,0.057\"]",
    "X1 [adjusted, pos=\"-0.453,-1.562\"]", "X2 [pos=\"-2.268,-1.210\"]", "Z0 [pos=\"-1.918,-1.735\"]",
    "v0 [pos=\"-1.525,-1.293\"]", "y [outcome, pos=\"-1.164,-0.116\"]", "\"Unobserved Confounders\" -> v0",
    "\"Unobserved Confounders\" -> y", "W0 -> v0", "W0 -> y", "X0 -> v0", "X0 -> y",
    "X1 -> v0", "X1 -> y", "X2 -> v0", "X2 -> y", "Z0 -> v0", "v0 -> y", "}", "",
  ]
  lines.join("\n")
}

///|
/// Whether the two lists hold the same names.
fn same_names(left : Array[String], right : Array[String]) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for name in left {
    if !right.contains(name) {
      return false
    }
  }
  true
}

///|
/// The nodes the upstream finds in the graph of its test `test_graph_input`.
fn upstream_graph_nodes() -> Array[String] {
  ["Unobserved Confounders", "X0", "X1", "X2", "Z0", "v0", "y"]
}

///|
/// The nodes the upstream finds in the graph of its test `test_graph_input`,
/// once the columns of the data that are not part of the graph have been added
/// as common causes.
fn upstream_model_nodes() -> Array[String] {
  [
    "Unobserved Confounders", "W0", "W1", "W2", "W3", "W4", "X0", "X1", "X2", "Z0",
    "v0", "y",
  ]
}

///|
/// The observed nodes the upstream finds in the graph of its test
/// `test_graph_input`.
fn upstream_observed_nodes() -> Array[String] {
  ["W0", "W1", "W2", "W3", "W4", "Z0", "v0", "y"]
}

///|
test "the model reads a GML graph and finds the common causes" {
  let dataset = graph_fixture()
  let model = model_with_graph(dataset, upstream_gml_graph())
  let common_causes = model.get_common_causes()
  assert_true(common_causes.contains("X1"))
  assert_true(common_causes.contains("X2"))
  // The upstream finds the unobserved confounder and the two effect modifiers
  // of the graph among the common causes, next to the common causes of the
  // data.
  assert_true(common_causes.contains("Unobserved Confounders"))
  assert_true(common_causes.contains("X0"))
  assert_true(common_causes.contains("W0"))
}

///|
test "the model reads a GML graph and finds the nodes of the graph" {
  let dataset = graph_fixture()
  let model = model_with_graph(dataset, upstream_gml_graph())
  let nodes = model.graph_with_roles().get_all_nodes(true)
  assert_true(same_names(nodes, upstream_model_nodes()))
  let observed = model.graph_with_roles().get_all_nodes(false)
  assert_true(same_names(observed, upstream_observed_nodes()))
}

///|
test "the model reads a GML graph that is spread over many lines" {
  let dataset = graph_fixture()
  let model = model_with_graph(dataset, upstream_gml_graph_over_many_lines())
  let common_causes = model.get_common_causes()
  assert_true(common_causes.contains("X1"))
  assert_true(common_causes.contains("X2"))
  let nodes = model.graph_with_roles().get_all_nodes(true)
  assert_true(same_names(nodes, upstream_model_nodes()))
}

///|
test "the DOT graph of the daggity web site is the graph of the upstream" {
  // The upstream turns the graph of the daggity web site into a DOT graph
  // with a chain of regular expressions, and the reference script prints the
  // text it produces. The port produces the same text.
  let expected = "digraph {         \"Unobserved Confounders\" [pos=\"0.491,-1.056\"]; " +
    "        X0 [pos=\"-2.109,0.057\"]; " +
    "        X1 [ pos=\"-0.453,-1.562\"]; " +
    "        X2 [pos=\"-2.268,-1.210\"]; " +
    "        Z0 [pos=\"-1.918,-1.735\"]; " +
    "        v0 [observed=\"no\", pos=\"-1.525,-1.293\"]; " +
    "        y [ pos=\"-1.164,-0.116\"]; " +
    "        \"Unobserved Confounders\" -> v0; " +
    "        \"Unobserved Confounders\" -> y; " +
    "        X0 -> v0; " +
    "        X0 -> y; " +
    "        X1 -> v0; " +
    "        X1 -> y; " +
    "        X2 -> v0; " +
    "        X2 -> y; " +
    "        Z0 -> v0; " +
    "        v0 -> y; " +
    "        }         "
  assert_eq(@graph.daggity_to_dot(upstream_daggity_graph()), expected)
}

///|
test "the model reads a daggity graph and finds the common causes" {
  let dataset = graph_fixture()
  let model = model_with_graph(dataset, upstream_daggity_graph())
  let common_causes = model.get_common_causes()
  assert_true(common_causes.contains("X1"))
  assert_true(common_causes.contains("X2"))
}

///|
test "the model reads a daggity graph and finds the nodes of the graph" {
  let dataset = graph_fixture()
  let model = model_with_graph(dataset, upstream_daggity_graph())
  let nodes = model.graph_with_roles().get_all_nodes(true)
  assert_true(same_names(nodes, upstream_model_nodes()))
  let observed = model.graph_with_roles().get_all_nodes(false)
  assert_true(same_names(observed, upstream_observed_nodes()))
}

///|
test "the model reads the graph of the sample dag of the upstream" {
  let dataset = graph_fixture()
  let model = model_with_graph(dataset, upstream_sample_dag())
  let common_causes = model.get_common_causes()
  assert_true(common_causes.contains("X1"))
  assert_true(common_causes.contains("X2"))
  let nodes = model.graph_with_roles().get_all_nodes(true)
  for name in upstream_graph_nodes() {
    assert_true(nodes.contains(name))
  }
  let observed = model.graph_with_roles().get_all_nodes(false)
  assert_false(observed.contains("Unobserved Confounders"))
}

///|
test "the model reads a graph that is given as a graph" {
  let dataset = graph_fixture()
  // The upstream reads the graph of its data set with `networkx.parse_gml`
  // and the graph of the daggity web site with `pygraphviz`; the port reads
  // them with its own readers and hands the graph over.
  let parsed = @graph.parse_gml(dataset.gml_graph())
  let model = @moonbit_dowhy.CausalModel::new(
    dataset.frame(),
    dataset.treatments(),
    [dataset.outcome()],
    Some(parsed),
    [],
    [],
    [],
    [],
  )
  let common_causes = model.get_common_causes()
  assert_true(common_causes.contains("W0"))
  let dot = @graph.parse_dot(@graph.daggity_to_dot(upstream_sample_dag()))
  let other = @moonbit_dowhy.CausalModel::new(
    dataset.frame(),
    dataset.treatments(),
    [dataset.outcome()],
    Some(dot),
    [],
    [],
    [],
    [],
    missing_nodes_as_confounders=true,
  )
  let causes = other.get_common_causes()
  assert_true(causes.contains("X1"))
  assert_true(causes.contains("X2"))
}

///|
test "the model reports the variables of the graph that are not in the data" {
  // The fixture of the upstream test
  // `test_unobserved_graph_variables_log_warning`: three common causes, one
  // instrument and one effect modifier, with the column `W0` dropped from the
  // data.
  let dataset = @datasets.linear_dataset(
    CAUSAL_MODEL_SEED,
    3,
    @datasets.LinearConfig::new(
      beta=10.0,
      num_common_causes=3,
      num_instruments=1,
      num_effect_modifiers=1,
      num_discrete_common_causes=1,
    ),
  )
  let names : Array[String] = []
  for name in dataset.frame().column_names() {
    if name != "W0" {
      names.push(name)
    }
  }
  let model = @moonbit_dowhy.CausalModel::new(
    dataset.frame().select(names),
    dataset.treatments(),
    [dataset.outcome()],
    Some(@graph.parse_gml(dataset.gml_graph())),
    [],
    [],
    [],
    [],
  )
  // The upstream finds seven variables in the graph, six of them in the data
  // and one of them, `W0`, in neither.
  let unobserved = model.unobserved_graph_variables()
  assert_eq(unobserved.length(), 1)
  assert_true(unobserved.contains("W0"))
  let nodes = model.graph_with_roles().get_all_nodes(true)
  assert_eq(nodes.length(), 7)
}

///|
test "the model reports the columns of the data that are not in the graph" {
  let dataset = graph_fixture()
  let model = model_with_graph(dataset, upstream_gml_graph())
  // The common causes of the data set are not part of the graph, but the
  // model adds them as confounders, so they are part of the graph.
  let unused = model.unused_data_variables()
  assert_eq(unused.length(), 0)
}

///|
test "the model refuses a graph it cannot read" {
  // The upstream raises a `ValueError` whose message starts with
  // "Incorrect format:" when the graph is neither a graph nor a string of a
  // format it can read. The port cannot catch its own abort, so the test asks
  // the format of the graph instead.
  assert_false(@moonbit_dowhy.is_supported_graph_format("not a graph"))
  assert_true(@moonbit_dowhy.is_supported_graph_format(upstream_gml_graph()))
  assert_true(
    @moonbit_dowhy.is_supported_graph_format(upstream_daggity_graph()),
  )
}

///|
test "the model keeps the estimator of every method it has used" {
  let dataset = graph_fixture()
  let model = @moonbit_dowhy.CausalModel::new_with_graph_string(
    dataset.frame(),
    dataset.treatments(),
    [dataset.outcome()],
    dataset.gml_graph(),
    [],
    [],
    [],
  )
  let _ = model.identify_effect("backdoor")
  let _ = model.estimate_effect("backdoor.linear_regression", 1.0, 0.0, "ate")
  let _ = model.estimate_effect(
    "backdoor.propensity_score_matching", 1.0, 0.0, "ate",
  )
  let first = model.get_estimator("backdoor.linear_regression")
  let second = model.get_estimator("backdoor.propensity_score_matching")
  assert_true(first is Some(_))
  assert_true(second is Some(_))
  match (first, second) {
    (Some(one), Some(two)) => assert_true(kinds_differ(one, two))
    _ => ()
  }
  // A method the model has not used has no estimator.
  assert_true(model.get_estimator("backdoor.doubly_robust") is None)
}

///|
/// Whether the two estimators are of a different kind.
///
/// The estimator of the port does not implement `Eq`, so the kind of the two
/// estimators is what tells them apart.
fn kinds_differ(
  one : @estimators.CausalEstimator,
  two : @estimators.CausalEstimator,
) -> Bool {
  match (one.estimator_kind(), two.estimator_kind()) {
    (
      @estimators.EstimatorKind::LinearRegression,
      @estimators.EstimatorKind::PropensityScoreMatching,
    ) => true
    _ => false
  }
}

///|
test "the model reports the summary of the model" {
  let dataset = graph_fixture()
  let model = model_with_graph(dataset, upstream_gml_graph())
  let summary = model.summary()
  assert_true(summary.contains("v0"))
  assert_true(summary.contains("y"))
}

///|
test "the GML graph of the data set is the graph of the upstream" {
  let dataset = graph_fixture()
  let expected = "graph[directed 1node[ id \"y\" label \"y\"]" +
    "node[ id \"W0\" label \"W0\"] node[ id \"W1\" label \"W1\"]" +
    " node[ id \"W2\" label \"W2\"] node[ id \"W3\" label \"W3\"]" +
    " node[ id \"W4\" label \"W4\"]node[ id \"Z0\" label \"Z0\"]" +
    "node[ id \"v0\" label \"v0\"]edge[source \"v0\" target \"y\"]" +
    "edge[ source \"W0\" target \"v0\"] edge[ source \"W1\" target \"v0\"]" +
    " edge[ source \"W2\" target \"v0\"] edge[ source \"W3\" target \"v0\"]" +
    " edge[ source \"W4\" target \"v0\"]edge[ source \"Z0\" target \"v0\"]" +
    "edge[ source \"W0\" target \"y\"] edge[ source \"W1\" target \"y\"]" +
    " edge[ source \"W2\" target \"y\"] edge[ source \"W3\" target \"y\"]" +
    " edge[ source \"W4\" target \"y\"]]"
  assert_eq(dataset.gml_graph(), expected)
}

///|
test "the estimate of a model without an effect modifier has no conditional estimate" {
  let dataset = @datasets.linear_dataset(
    CAUSAL_MODEL_SEED,
    CAUSAL_MODEL_NUM_SAMPLES,
    @datasets.LinearConfig::new(beta=10.0, num_common_causes=2),
  )
  let model = @moonbit_dowhy.CausalModel::new(
    dataset.frame(),
    dataset.treatments(),
    [dataset.outcome()],
    Some(@graph.parse_gml(dataset.gml_graph())),
    [],
    [],
    [],
    [],
  )
  let _ = model.identify_effect("backdoor")
  let estimate = model.estimate_effect(
    "backdoor.linear_regression", 1.0, 0.0, "ate",
  )
  assert_eq(estimate.conditional_estimates().length(), 0)
}

///|
test "the estimate of a model with an effect modifier has conditional estimates" {
  let dataset = @datasets.linear_dataset(
    CAUSAL_MODEL_SEED,
    CAUSAL_MODEL_NUM_SAMPLES,
    @datasets.LinearConfig::new(
      beta=10.0,
      num_common_causes=2,
      num_effect_modifiers=1,
    ),
  )
  let model = @moonbit_dowhy.CausalModel::new(
    dataset.frame(),
    dataset.treatments(),
    [dataset.outcome()],
    Some(@graph.parse_gml(dataset.gml_graph())),
    [],
    [],
    [],
    [],
  )
  let _ = model.identify_effect("backdoor")
  let estimate = model.estimate_effect(
    "backdoor.linear_regression", 1.0, 0.0, "ate",
  )
  // The upstream splits a continuous effect modifier into five quantile groups
  // and estimates the effect on every one of them.
  let conditional = estimate.conditional_estimates()
  assert_eq(conditional.length(), 5)
}
