///|
/// The tests of the automatic assignment of the causal mechanisms.
///
/// The fixture is the upstream `_generate_data_with_categorical_input` of
/// `tests/gcm/test_fcms.py`: the column `X0` is numeric, the column `X1` holds
/// the strings "0", "1" and "2", and the column `X2` is
/// `2 * X0 + (-5 if X1 == "0" else 10 if X1 == "1" else 5)`. The upstream
/// draws the column `X0` from a normal distribution; the port uses a fixed
/// column, so that the fixture is the same on every run.

///|
/// The numeric column of the fixture.
fn auto_numeric_column() -> Array[Double] {
  [0.5, -1.25, 2.0, 0.75, -0.5, 1.5, -2.25, 3.0, 0.25, -1.75, 2.5, -0.25]
}

///|
/// The categorical column of the fixture, whose categories are the strings
/// "0", "1" and "2".
fn auto_categorical_column() -> Array[String] {
  ["0", "1", "2", "0", "1", "2", "0", "1", "2", "0", "1", "2"]
}

///|
/// The column of the fixture that holds whole numbers.
fn auto_integer_column() -> Array[Double] {
  [2.0, 4.0, 6.0, 8.0, 10.0, 12.0, 14.0, 16.0, 18.0, 20.0, 22.0, 24.0]
}

///|
/// The target of the fixture, which is
/// `2 * X0 + (-5 if X1 == "0" else 10 if X1 == "1" else 5)`.
fn auto_target_column() -> Array[Double] {
  let x0 = auto_numeric_column()
  let x1 = auto_categorical_column()
  let target : Array[Double] = []
  for i = 0; i < x0.length(); i = i + 1 {
    let mut value = 2.0 * x0[i]
    if x1[i] == "0" {
      value = value - 5.0
    } else if x1[i] == "1" {
      value = value + 10.0
    } else {
      value = value + 5.0
    }
    target.push(value)
  }
  target
}

///|
/// The frame of the fixture.
fn auto_fixture() -> @api.DataFrame {
  @api.DataFrame::new(
    ["X0", "X1", "X2"],
    Map([
      ("X0", @api.Column::numeric(auto_numeric_column())),
      ("X1", @api.Column::discrete(auto_categorical_column())),
      ("X2", @api.Column::numeric(auto_target_column())),
    ]),
  )
}

///|
/// The frame whose target column holds whole numbers.
fn auto_integer_fixture() -> @api.DataFrame {
  @api.DataFrame::new(
    ["X0", "X1", "X2"],
    Map([
      ("X0", @api.Column::numeric(auto_numeric_column())),
      ("X1", @api.Column::discrete(auto_categorical_column())),
      ("X2", @api.Column::numeric(auto_integer_column())),
    ]),
  )
}

///|
/// The frame whose target column holds the categories of the fixture.
fn auto_categorical_fixture() -> @api.DataFrame {
  @api.DataFrame::new(
    ["X0", "X1", "X2"],
    Map([
      ("X0", @api.Column::numeric(auto_numeric_column())),
      ("X1", @api.Column::discrete(auto_categorical_column())),
      ("X2", @api.Column::discrete(auto_categorical_column())),
    ]),
  )
}

///|
/// The graph of the fixture, where the columns `X0` and `X1` are the parents
/// of the column `X2`.
fn auto_graph() -> @graph.DirectedGraph {
  let g = @graph.DirectedGraph::new()
  g.add_edge("X0", "X2")
  g.add_edge("X1", "X2")
  g
}

///|
/// Whether the distribution of the root node is an empirical distribution.
fn auto_is_empirical(
  model : @gcm.ProbabilisticCausalModel,
  node : String,
) -> Bool {
  match model.root_model(node) {
    Some(root) =>
      match root.kind() {
        @gcm.StochasticModelKind::Empirical => true
        _ => false
      }
    None => false
  }
}

///|
/// Whether the distribution of the root node is an empirical categorical
/// distribution.
fn auto_is_empirical_categorical(
  model : @gcm.ProbabilisticCausalModel,
  node : String,
) -> Bool {
  match model.root_model(node) {
    Some(root) =>
      match root.kind() {
        @gcm.StochasticModelKind::EmpiricalCategorical => true
        _ => false
      }
    None => false
  }
}

///|
/// Whether the causal mechanism of the node is an additive noise model.
fn auto_is_additive_noise(
  model : @gcm.ProbabilisticCausalModel,
  node : String,
) -> Bool {
  match model.causal_mechanism(node) {
    Some(mechanism) =>
      match mechanism.kind() {
        @gcm.CausalMechanismKind::AdditiveNoise => true
        _ => false
      }
    None => false
  }
}

///|
/// Whether the causal mechanism of the node is a discrete additive noise
/// model.
fn auto_is_discrete_additive_noise(
  model : @gcm.ProbabilisticCausalModel,
  node : String,
) -> Bool {
  match model.causal_mechanism(node) {
    Some(mechanism) => @gcm.is_discrete_additive_noise_kind(mechanism.kind())
    None => false
  }
}

///|
/// Whether the causal mechanism of the node is the categorical model.
fn auto_is_classifier(
  model : @gcm.ProbabilisticCausalModel,
  node : String,
) -> Bool {
  match model.causal_mechanism(node) {
    Some(mechanism) => @gcm.is_classifier_kind(mechanism.kind())
    None => false
  }
}

///|
/// Whether the summary holds the given message.
fn auto_has_message(
  summary : @gcm.AutoAssignmentSummary,
  message : String,
) -> Bool {
  for held in summary.messages() {
    if held == message {
      return true
    }
  }
  false
}

///|
/// test "a root node with a numeric column gets an empirical distribution"
test "a root node with a numeric column gets an empirical distribution" {
  let data = auto_fixture()
  let model = @gcm.ProbabilisticCausalModel::new(auto_graph())
  @gcm.assign_causal_mechanism_node(
    model,
    "X0",
    data,
    @gcm.AssignmentQuality::good(),
  )
  assert_true(auto_is_empirical(model, "X0"))
}

///|
/// test "a root node with a string column gets a categorical distribution"
test "a root node with a string column gets a categorical distribution" {
  let data = auto_fixture()
  let model = @gcm.ProbabilisticCausalModel::new(auto_graph())
  @gcm.assign_causal_mechanism_node(
    model,
    "X1",
    data,
    @gcm.AssignmentQuality::good(),
  )
  assert_true(auto_is_empirical_categorical(model, "X1"))
}

///|
/// test "a node with parents and a continuous column gets the additive noise
/// model"
test "a node with parents and a continuous column gets the additive noise model" {
  let data = auto_fixture()
  let model = @gcm.ProbabilisticCausalModel::new(auto_graph())
  @gcm.assign_causal_mechanism_node(
    model,
    "X2",
    data,
    @gcm.AssignmentQuality::good(),
  )
  assert_true(auto_is_additive_noise(model, "X2"))
}

///|
/// test "a node with parents and a column of whole numbers gets the discrete
/// additive noise model"
test "a node with parents and a column of whole numbers gets the discrete additive noise model" {
  let data = auto_integer_fixture()
  let model = @gcm.ProbabilisticCausalModel::new(auto_graph())
  @gcm.assign_causal_mechanism_node(
    model,
    "X2",
    data,
    @gcm.AssignmentQuality::good(),
  )
  assert_true(auto_is_discrete_additive_noise(model, "X2"))
}

///|
/// test "a node with parents and a string column gets the classifier model"
test "a node with parents and a string column gets the classifier model" {
  let data = auto_categorical_fixture()
  let model = @gcm.ProbabilisticCausalModel::new(auto_graph())
  @gcm.assign_causal_mechanism_node(
    model,
    "X2",
    data,
    @gcm.AssignmentQuality::good(),
  )
  assert_true(auto_is_classifier(model, "X2"))
}

///|
/// test "the assignment leaves a node alone when the override parameter is
/// false"
///
/// The classifier is not the mechanism that the automatic assignment picks for
/// the continuous column of the node, so the node keeps its mechanism.
test "the assignment leaves a node alone when the override parameter is false" {
  let data = auto_fixture()
  let model = @gcm.ProbabilisticCausalModel::new(auto_graph())
  model.set_causal_mechanism(
    "X2",
    @gcm.CausalMechanism::classifier(@gcm.ClassificationModel::logistic()),
  )
  let summary = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
  )
  assert_true(auto_is_classifier(model, "X2"))
  assert_true(
    auto_has_message(
      summary, "Node X2 already has a causal mechanism assigned and the override parameter is False. Skipping this node.",
    ),
  )
}

///|
/// test "the assignment replaces a node when the override parameter is true"
test "the assignment replaces a node when the override parameter is true" {
  let data = auto_fixture()
  let model = @gcm.ProbabilisticCausalModel::new(auto_graph())
  model.set_causal_mechanism(
    "X2",
    @gcm.CausalMechanism::classifier(@gcm.ClassificationModel::logistic()),
  )
  let _ = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::good(),
    true,
  )
  assert_true(auto_is_additive_noise(model, "X2"))
}

///|
/// test "the summary holds a message for every node of the model"
test "the summary holds a message for every node of the model" {
  let data = auto_fixture()
  let model = @gcm.ProbabilisticCausalModel::new(auto_graph())
  let summary = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
  )
  // The three nodes of the model have a message each.
  assert_true(summary.messages().length() >= 3)
  assert_true(auto_has_message(summary, "Node X0 is a root node."))
  assert_true(auto_has_message(summary, "Node X1 is a root node."))
  assert_true(
    auto_has_message(
      summary, "Node X2 is a non-root node with continuous data.",
    ),
  )
  assert_true(
    auto_has_message(
      summary, "This represents the causal relationship as X2 := f(X0,X1) + N.",
    ),
  )
  assert_true(
    auto_has_message(
      summary, "Assigning 'an additive noise model' to the node.",
    ),
  )
}

///|
/// test "the message of a root node mentions that it is a root"
test "the message of a root node mentions that it is a root" {
  let data = auto_fixture()
  let model = @gcm.ProbabilisticCausalModel::new(auto_graph())
  let summary = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
  )
  assert_true(auto_has_message(summary, "Node X0 is a root node."))
  assert_true(
    auto_has_message(
      summary, "Assigning 'an empirical distribution' to the node representing the marginal distribution.",
    ),
  )
  assert_true(
    auto_has_message(
      summary, "Assigning 'an empirical categorical distribution' to the node representing the marginal distribution.",
    ),
  )
}

///|
/// test "the description of the summary holds the messages"
test "the description of the summary holds the messages" {
  let data = auto_fixture()
  let model = @gcm.ProbabilisticCausalModel::new(auto_graph())
  let summary = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
  )
  let description = summary.to_string()
  assert_true(description.contains("Node X0 is a root node."))
  assert_true(
    description.contains("Node X2 is a non-root node with continuous data."),
  )
}

///|
/// test "the assignment of every node is valid"
test "the assignment of every node is valid" {
  let data = auto_fixture()
  let model = @gcm.ProbabilisticCausalModel::new(auto_graph())
  let _ = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::better(),
    false,
  )
  for node in model.nodes() {
    assert_true(@gcm.has_valid_causal_model_assignment(model, node))
  }
  assert_true(@gcm.has_valid_causal_model(model))
}

///|
/// test "the three qualities assign the same mechanisms"
///
/// The port has one model per kind of data, so the quality of the upstream,
/// which selects the model out of a zoo of scikit-learn estimators, does not
/// change the outcome.
test "the three qualities assign the same mechanisms" {
  let data = auto_fixture()
  let good_model = @gcm.ProbabilisticCausalModel::new(auto_graph())
  let better_model = @gcm.ProbabilisticCausalModel::new(auto_graph())
  let best_model = @gcm.ProbabilisticCausalModel::new(auto_graph())
  let _ = @gcm.assign_causal_mechanisms(
    good_model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
  )
  let _ = @gcm.assign_causal_mechanisms(
    better_model,
    data,
    @gcm.AssignmentQuality::better(),
    false,
  )
  let _ = @gcm.assign_causal_mechanisms(
    best_model,
    data,
    @gcm.AssignmentQuality::best(),
    false,
  )
  assert_true(auto_is_empirical(good_model, "X0"))
  assert_true(auto_is_empirical(better_model, "X0"))
  assert_true(auto_is_empirical(best_model, "X0"))
  assert_true(auto_is_empirical_categorical(good_model, "X1"))
  assert_true(auto_is_empirical_categorical(better_model, "X1"))
  assert_true(auto_is_empirical_categorical(best_model, "X1"))
  assert_true(auto_is_additive_noise(good_model, "X2"))
  assert_true(auto_is_additive_noise(better_model, "X2"))
  assert_true(auto_is_additive_noise(best_model, "X2"))
}
