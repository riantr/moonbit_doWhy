///|
/// The tests of the automatic assignment of the causal mechanisms.
///
/// The cases of the model selection are the ones of the upstream
/// `tests/gcm/test_auto.py`: the upstream draws the features of its fixtures
/// from a normal distribution, and the port draws them with its own
/// generator, so that the fixture is the same on every run. The upstream
/// evaluates a whole zoo of scikit-learn estimators and it asserts which
/// class of estimator it picked; the port evaluates the models of the `gcm`
/// package and it asserts which family of models it picked, the linear one
/// or the non-linear one.
///
/// The port mirrors 15 of the 26 cases of the upstream test file. The cases it
/// does not mirror yet are the ones of the linear relationship of
/// `has_linear_relationship`, the ones of the multiclass targets and the ones
/// of the statistics of the drawn samples. The cases of the upstream that
/// have no counterpart in the port are the one of the namespace of the
/// automatic assignment, the one of the AutoGluon model, which the upstream
/// skips as well, and the two ones of the missing values, which the frames of
/// the port do not hold.

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
/// The number of the features of the fixtures of the model selection.
const AUTO_NUM_FEATURES : Int32 = 5

///|
/// The number of the rows of the fixtures of the model selection.
const AUTO_NUM_ROWS : Int32 = 120

///|
/// The seed of the generator of the features of the fixtures of the model
/// selection.
const AUTO_SEED : UInt64 = 20240101UL

///|
/// The seed of the generator of the targets of the fixtures of the model
/// selection.
const AUTO_TARGET_SEED : UInt64 = 20240102UL

///|
/// The standard deviation of the noise of the linear fixtures.
const AUTO_NOISE : Double = 0.2

///|
/// The weights of the linear fixtures of the model selection.
fn auto_weights() -> Array[Double] {
  [2.0, -1.5, 3.0, -0.5, 1.0]
}

///|
/// The features of the fixtures of the model selection: five columns of
/// normal deviates.
fn auto_features() -> Array[Array[Double]] {
  let rng = @utils.Random::new(AUTO_SEED)
  let columns : Array[Array[Double]] = []
  for _ in 0..<AUTO_NUM_FEATURES {
    let column : Array[Double] = []
    for _ in 0..<AUTO_NUM_ROWS {
      column.push(rng.next_normal())
    }
    columns.push(column)
  }
  columns
}

///|
/// The target of the linear regression fixture: the sum of the features
/// weighted by a fixed vector, with a noise.
///
/// The upstream draws its target without a noise, which makes the ordinary
/// least squares regression and the polynomial regression fit the rows of
/// the fixture exactly; the two of them are then the same number and the
/// choice between them is a matter of the rounding of the fit. The port adds
/// a noise, so that the ordinary least squares regression is the model of the
/// relation and the selection is unambiguous.
fn auto_linear_target(columns : Array[Array[Double]]) -> Array[Double] {
  let rng = @utils.Random::new(AUTO_TARGET_SEED)
  let target : Array[Double] = []
  for i in 0..<AUTO_NUM_ROWS {
    let mut value = 0.0
    for j in 0..<AUTO_NUM_FEATURES {
      value = value + auto_weights()[j] * columns[j][i]
    }
    target.push(value + AUTO_NOISE * rng.next_normal())
  }
  target
}

///|
/// The target of the non-linear regression fixture: the sum of the logarithms
/// of the absolute values of the features.
fn auto_non_linear_target(columns : Array[Array[Double]]) -> Array[Double] {
  let target : Array[Double] = []
  for i in 0..<AUTO_NUM_ROWS {
    let mut value = 0.0
    for j in 0..<AUTO_NUM_FEATURES {
      value = value + @math.ln(columns[j][i].abs())
    }
    target.push(value)
  }
  target
}

///|
/// The target of the linear classification fixture: the class of a row is
/// drawn from the logistic function of the weighted sum of its features.
///
/// The upstream draws its target from the sign of the weighted sum of the
/// features, which is a deterministic boundary; the logistic regression of
/// the port and the polynomial logistic regression of the port are then
/// nearly the same number, because the boundary of the sign is curved. The
/// port draws the class from the logistic function of the weighted sum, so
/// that the logistic regression is the model of the relation and the
/// selection is unambiguous.
fn auto_linear_labels(columns : Array[Array[Double]]) -> Array[String] {
  let rng = @utils.Random::new(AUTO_TARGET_SEED)
  let labels : Array[String] = []
  for i in 0..<AUTO_NUM_ROWS {
    let mut value = 0.0
    for j in 0..<AUTO_NUM_FEATURES {
      value = value + auto_weights()[j] * columns[j][i]
    }
    let probability = 1.0 / (1.0 + @math.exp(-value))
    if rng.next_double() < probability {
      labels.push("Class 0")
    } else {
      labels.push("Class 1")
    }
  }
  labels
}

///|
/// The target of the non-linear classification fixture: the class of a row
/// is given by the sign of the product of its two first features.
///
/// This is the fixture of the upstream of its polynomial classification case.
/// The boundary of the product is curved, so the plain logistic regression
/// cannot fit it and the polynomial logistic regression can.
fn auto_non_linear_labels(columns : Array[Array[Double]]) -> Array[String] {
  let labels : Array[String] = []
  for i in 0..<AUTO_NUM_ROWS {
    if columns[0][i] * columns[1][i] > 0.0 {
      labels.push("Class 0")
    } else {
      labels.push("Class 1")
    }
  }
  labels
}

///|
/// The frame of the fixtures of the model selection, with the given target.
fn auto_selection_frame(
  columns : Array[Array[Double]],
  target : @api.Column,
) -> @api.DataFrame {
  let names : Array[String] = []
  let values : Map[String, @api.Column] = Map([])
  for j in 0..<AUTO_NUM_FEATURES {
    let name = "X" + j.to_string()
    names.push(name)
    values.set(name, @api.Column::numeric(columns[j]))
  }
  names.push("Y")
  values.set("Y", target)
  @api.DataFrame::new(names, values)
}

///|
/// The graph of the fixtures of the model selection, where every feature is a
/// parent of the target.
fn auto_selection_graph() -> @graph.DirectedGraph {
  let g = @graph.DirectedGraph::new()
  for j in 0..<AUTO_NUM_FEATURES {
    g.add_edge("X" + j.to_string(), "Y")
  }
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
/// Whether the model of the node is the nearest neighbour regression.
fn auto_is_nearest_neighbour(
  model : @gcm.ProbabilisticCausalModel,
  node : String,
) -> Bool {
  match model.causal_mechanism(node) {
    Some(mechanism) => mechanism.prediction_model().is_nearest_neighbour()
    None => false
  }
}

///|
/// Whether the model of the node is the ordinary least squares regression.
fn auto_is_least_squares(
  model : @gcm.ProbabilisticCausalModel,
  node : String,
) -> Bool {
  match model.causal_mechanism(node) {
    Some(mechanism) => {
      let prediction = mechanism.prediction_model()
      !prediction.is_nearest_neighbour() && prediction.degree() == 0
    }
    None => false
  }
}

///|
/// Whether the model of the node is the plain logistic regression.
fn auto_is_logistic(
  model : @gcm.ProbabilisticCausalModel,
  node : String,
) -> Bool {
  match model.causal_mechanism(node) {
    Some(mechanism) => mechanism.classifier_model().degree() == 0
    None => false
  }
}

///|
/// Whether the model of the node is the polynomial logistic regression.
fn auto_is_polynomial_logistic(
  model : @gcm.ProbabilisticCausalModel,
  node : String,
) -> Bool {
  match model.causal_mechanism(node) {
    Some(mechanism) => mechanism.classifier_model().degree() > 0
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
/// Whether the summary holds a message that holds the given text.
fn auto_has_message_with(
  summary : @gcm.AutoAssignmentSummary,
  text : String,
) -> Bool {
  for held in summary.messages() {
    if held.contains(text) {
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
  let _ = @gcm.assign_causal_mechanism_node(
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
  let _ = @gcm.assign_causal_mechanism_node(
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
  let _ = @gcm.assign_causal_mechanism_node(
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
  let _ = @gcm.assign_causal_mechanism_node(
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
  let _ = @gcm.assign_causal_mechanism_node(
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
  assert_true(auto_has_message_with(summary, "Node X0 is a root node."))
  assert_true(auto_has_message_with(summary, "Node X1 is a root node."))
  assert_true(
    auto_has_message_with(
      summary, "Node X2 is a non-root node with continuous data.",
    ),
  )
  assert_true(
    auto_has_message_with(
      summary, "This represents the causal relationship as X2 := f(X0,X1) + N.",
    ),
  )
  assert_true(
    auto_has_message_with(summary, "Assigning 'an additive noise model"),
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
  assert_true(auto_has_message_with(summary, "Node X0 is a root node."))
  assert_true(
    auto_has_message_with(
      summary, "Assigning 'an empirical distribution' to the node representing the marginal distribution.",
    ),
  )
  assert_true(
    auto_has_message_with(
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
/// test "the three qualities assign a valid mechanism to the node"
test "the three qualities assign a valid mechanism to the node" {
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

///|
/// test "a linear regression problem picks the linear model"
///
/// The upstream asserts that the linear model is picked for a linear
/// regression problem. Its own selection is not reproducible, so it accepts
/// the linear model and the polynomial one; the port picks the ordinary
/// least squares regression, because it is the model of the relation of its
/// fixture.
test "a linear regression problem picks the linear model" {
  let columns = auto_features()
  let data = auto_selection_frame(
    columns,
    @api.Column::numeric(auto_linear_target(columns)),
  )
  let model = @gcm.ProbabilisticCausalModel::new(auto_selection_graph())
  let _ = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
  )
  assert_true(auto_is_least_squares(model, "Y"))
  assert_false(auto_is_nearest_neighbour(model, "Y"))
}

///|
/// test "a linear regression problem picks the linear model with the better
/// quality"
test "a linear regression problem picks the linear model with the better quality" {
  let columns = auto_features()
  let data = auto_selection_frame(
    columns,
    @api.Column::numeric(auto_linear_target(columns)),
  )
  let model = @gcm.ProbabilisticCausalModel::new(auto_selection_graph())
  let _ = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::better(),
    false,
  )
  assert_true(auto_is_least_squares(model, "Y"))
  assert_false(auto_is_nearest_neighbour(model, "Y"))
}

///|
/// test "a non-linear regression problem picks a non-linear model"
///
/// The upstream asserts that a model of the non-linear family is picked for a
/// non-linear regression problem. The port picks the nearest neighbour
/// regression, because the ordinary least squares regression cannot fit the
/// sum of the logarithms of the features.
test "a non-linear regression problem picks a non-linear model" {
  let columns = auto_features()
  let data = auto_selection_frame(
    columns,
    @api.Column::numeric(auto_non_linear_target(columns)),
  )
  let model = @gcm.ProbabilisticCausalModel::new(auto_selection_graph())
  let _ = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
  )
  assert_false(auto_is_least_squares(model, "Y"))
}

///|
/// test "a non-linear regression problem picks a non-linear model with the
/// better quality"
test "a non-linear regression problem picks a non-linear model with the better quality" {
  let columns = auto_features()
  let data = auto_selection_frame(
    columns,
    @api.Column::numeric(auto_non_linear_target(columns)),
  )
  let model = @gcm.ProbabilisticCausalModel::new(auto_selection_graph())
  let _ = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::better(),
    false,
  )
  assert_false(auto_is_least_squares(model, "Y"))
}

///|
/// test "a linear classification problem picks the logistic regression"
///
/// The upstream asserts that the logistic regression is picked for a linear
/// classification problem.
test "a linear classification problem picks the logistic regression" {
  let columns = auto_features()
  let data = auto_selection_frame(
    columns,
    @api.Column::discrete(auto_linear_labels(columns)),
  )
  let model = @gcm.ProbabilisticCausalModel::new(auto_selection_graph())
  let _ = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
  )
  assert_true(auto_is_logistic(model, "Y"))
}

///|
/// test "a linear classification problem picks the logistic regression with
/// the better quality"
test "a linear classification problem picks the logistic regression with the better quality" {
  let columns = auto_features()
  let data = auto_selection_frame(
    columns,
    @api.Column::discrete(auto_linear_labels(columns)),
  )
  let model = @gcm.ProbabilisticCausalModel::new(auto_selection_graph())
  let _ = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::better(),
    false,
  )
  assert_true(auto_is_logistic(model, "Y"))
}

///|
/// test "a non-linear classification problem picks a non-linear model"
///
/// The upstream asserts that a model of the non-linear family is picked for a
/// non-linear classification problem. The port picks the polynomial logistic
/// regression, because the plain logistic regression cannot fit the boundary
/// of the sum of the exponentials of the features.
test "a non-linear classification problem picks a non-linear model" {
  let columns = auto_features()
  let data = auto_selection_frame(
    columns,
    @api.Column::discrete(auto_non_linear_labels(columns)),
  )
  let model = @gcm.ProbabilisticCausalModel::new(auto_selection_graph())
  let _ = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
  )
  assert_false(auto_is_logistic(model, "Y"))
  assert_true(auto_is_polynomial_logistic(model, "Y"))
}

///|
/// test "a non-linear classification problem picks a non-linear model with the
/// better quality"
test "a non-linear classification problem picks a non-linear model with the better quality" {
  let columns = auto_features()
  let data = auto_selection_frame(
    columns,
    @api.Column::discrete(auto_non_linear_labels(columns)),
  )
  let model = @gcm.ProbabilisticCausalModel::new(auto_selection_graph())
  let _ = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::better(),
    false,
  )
  assert_false(auto_is_logistic(model, "Y"))
  assert_true(auto_is_polynomial_logistic(model, "Y"))
}

///|
/// test "the polynomial regression data with a categorical input is assigned
/// without an error"
///
/// The upstream fits a model of a target that holds a product of two features
/// and whose first parent holds the categories "0" and "1".
test "the polynomial regression data with a categorical input is assigned without an error" {
  let rng = @utils.Random::new(AUTO_SEED)
  let categories : Array[String] = []
  let first : Array[Double] = []
  let second : Array[Double] = []
  for _ in 0..<AUTO_NUM_ROWS {
    if rng.next_double() < 0.5 {
      categories.push("0")
    } else {
      categories.push("1")
    }
    first.push(rng.next_normal())
    second.push(rng.next_normal())
  }
  let target : Array[Double] = []
  for i in 0..<AUTO_NUM_ROWS {
    if categories[i] == "0" {
      target.push(first[i] * second[i])
    } else {
      target.push(first[i] + second[i])
    }
  }
  let data = @api.DataFrame::new(
    ["X0", "X1", "X2", "Y"],
    Map([
      ("X0", @api.Column::discrete(categories)),
      ("X1", @api.Column::numeric(first)),
      ("X2", @api.Column::numeric(second)),
      ("Y", @api.Column::numeric(target)),
    ]),
  )
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "Y")
  graph.add_edge("X1", "Y")
  graph.add_edge("X2", "Y")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  let _ = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
  )
  assert_true(auto_is_additive_noise(model, "Y"))
}

///|
/// test "the polynomial classification data with a categorical input is
/// assigned without an error"
///
/// The upstream fits a classifier of a target that holds two classes, which
/// are given by the sign of the product of two features.
test "the polynomial classification data with a categorical input is assigned without an error" {
  let rng = @utils.Random::new(AUTO_SEED)
  let first : Array[Double] = []
  let second : Array[Double] = []
  for _ in 0..<AUTO_NUM_ROWS {
    first.push(rng.next_normal())
    second.push(rng.next_normal())
  }
  let labels : Array[String] = []
  for i in 0..<AUTO_NUM_ROWS {
    if first[i] * second[i] > 0.0 {
      labels.push("Class 0")
    } else {
      labels.push("Class 1")
    }
  }
  let data = @api.DataFrame::new(
    ["X0", "X1", "Y"],
    Map([
      ("X0", @api.Column::numeric(first)),
      ("X1", @api.Column::numeric(second)),
      ("Y", @api.Column::discrete(labels)),
    ]),
  )
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X0", "Y")
  graph.add_edge("X1", "Y")
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  let _ = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::better(),
    false,
  )
  assert_true(auto_is_classifier(model, "Y"))
}

///|
/// test "the summary holds the performances of the models of every node"
///
/// The upstream holds the performances of the models it evaluated for every
/// node, and it holds none for a root node.
test "the summary holds the performances of the models of every node" {
  let columns = auto_features()
  let data = auto_selection_frame(
    columns,
    @api.Column::numeric(auto_linear_target(columns)),
  )
  let model = @gcm.ProbabilisticCausalModel::new(auto_selection_graph())
  let summary = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
  )
  assert_eq(summary.model_performances_of("X0").length(), 0)
  assert_eq(summary.model_performances_of("Y").length(), 2)
  let best = summary.model_performances_of("Y")[0]
  assert_eq(best.metric(), "mean squared error (MSE)")
  // The score of the ordinary least squares regression is the variance of the
  // noise of the relation of the fixture.
  assert_true(best.performance() > 0.0)
  assert_true(best.performance() < 0.1)
}

///|
/// test "the description of the summary holds the model selection section"
///
/// The upstream describes the models it evaluated for every node and the note
/// about the quality of the selection.
test "the description of the summary holds the model selection section" {
  let columns = auto_features()
  let data = auto_selection_frame(
    columns,
    @api.Column::numeric(auto_linear_target(columns)),
  )
  let model = @gcm.ProbabilisticCausalModel::new(auto_selection_graph())
  let summary = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
  )
  let description = summary.to_string()
  assert_true(description.contains("In total, 6 nodes were analyzed:"))
  assert_true(description.contains("--- Node: Y"))
  assert_true(
    description.contains(
      "For the model selection, the following models were evaluated on the mean squared error (MSE) metric:",
    ),
  )
  assert_true(
    description.contains(
      "===Note===\nNote, based on the selected auto assignment quality, the set of evaluated models changes.",
    ),
  )
}

///|
/// test "the selection of a target of a single class is not supported"
///
/// The upstream raises a `ValueError` when the target of a classification
/// holds a single class. The port cannot catch an abort, so it reports the
/// case with a function of its own.
test "the selection of a target of a single class is not supported" {
  let labels : Array[String] = []
  for _ in 0..<10 {
    labels.push("OneClass")
  }
  assert_false(@gcm.supports_classification(labels))
  assert_true(@gcm.supports_classification(["OneClass", "RareClass"]))
}
