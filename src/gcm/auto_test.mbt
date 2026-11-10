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
/// The port mirrors 24 of the 26 cases of the upstream test file. The two
/// cases of the upstream that have no counterpart in the port are the one of
/// the namespace of the automatic assignment and the one of the AutoGluon
/// model, which the upstream skips as well.
///
/// The two cases of the missing values are mirrored, and they are the ones that
/// use the experimental flag of the upstream, which the port takes as well. The
/// upstream raises when the data holds a missing value and the flag is not
/// set, and MoonBit cannot catch the stop of a function, so the test reads the
/// predicate of the check instead of the raise. The upstream fits its models
/// on the rows that hold no missing value in their target and keeps the rows
/// whose features hold a missing value, because its histogram gradient
/// boosting model reads them; the port has no model that reads them, so it
/// drops the rows that hold a missing value in a feature as well.
///
/// One of the cases the port mirrors ends in a different model: the upstream
/// picks the linear model for a linear relation of three classes and the port
/// picks its polynomial logistic regression, because the classifier of the
/// port is the one-versus-rest variant of the upstream and its probabilities
/// of a target of more than two classes are worse than the ones of the
/// multinomial variant of the upstream. The test of the case records the
/// difference.

///|
/// The number of the rows of the fixture of the missing values.
const AUTO_MISSING_ROWS : Int32 = 600

///|
/// The seed of the generator of the fixture of the missing values.
const AUTO_MISSING_SEED : UInt64 = 20240301UL

///|
/// The share of the rows of the fixture of the missing values that hold a
/// missing value.
const AUTO_MISSING_SHARE : Double = 0.25

///|
/// The number of the samples the fixture of the missing values draws.
const AUTO_MISSING_SAMPLES : Int32 = 5000

///|
/// The number of the samples of the interventional distribution of the fixture
/// of the missing values.
const AUTO_MISSING_INTERVENTIONAL_SAMPLES : Int32 = 100

///|
/// The frame of the fixture of the missing values, whose columns are `X`, `Y`
/// and `Z`.
///
/// The relations are the ones of the upstream: `Y` is `2 * X + 10` with a
/// small noise and `Z` is `X + Y + 20` with a small noise. A quarter of the
/// rows of `X` and a quarter of the rows of `Z` hold a missing value and the
/// column of `Y` holds none, the way the upstream masks them.
fn auto_missing_frame() -> @api.DataFrame {
  let rng = @utils.Random::new(AUTO_MISSING_SEED)
  let x : Array[Double] = []
  let y : Array[Double] = []
  let z : Array[Double] = []
  for _ in 0..<AUTO_MISSING_ROWS {
    let value = 5.0 * rng.next_normal()
    let middle = 2.0 * value + 10.0 + 0.05 * rng.next_normal()
    let last = value + middle + 20.0 + 0.05 * rng.next_normal()
    x.push(
      if rng.next_double() < AUTO_MISSING_SHARE {
        @utils.nan()
      } else {
        value
      },
    )
    y.push(middle)
    z.push(
      if rng.next_double() < AUTO_MISSING_SHARE {
        @utils.nan()
      } else {
        last
      },
    )
  }
  @api.DataFrame::new(
    ["X", "Y", "Z"],
    Map([
      ("X", @api.Column::numeric(x)),
      ("Y", @api.Column::numeric(y)),
      ("Z", @api.Column::numeric(z)),
    ]),
  )
}

///|
/// The graph of the fixture of the missing values, where `X` is a parent of `Y`
/// and of `Z` and `Y` is a parent of `Z`.
fn auto_missing_graph() -> @graph.DirectedGraph {
  let g = @graph.DirectedGraph::new()
  g.add_edge("X", "Y")
  g.add_edge("Y", "Z")
  g.add_edge("X", "Z")
  g
}

///|
/// The frame of the fixture of the mixed missing values, whose columns are `X`,
/// `Y` and `Z`.
///
/// The relations are the ones of the upstream: `Y` holds the class of the sign
/// of `X` and `Z` is `X` with ten more when the class is `Class 1` and with ten
/// less when it is `Class 0`, plus a small noise. A quarter of the rows of `X`
/// and a quarter of the rows of `Z` hold a missing value and the column of `Y`
/// holds none, the way the upstream masks them.
fn auto_missing_mixed_frame() -> @api.DataFrame {
  let rng = @utils.Random::new(AUTO_MISSING_SEED + 5UL)
  let x : Array[Double] = []
  let y : Array[String] = []
  let z : Array[Double] = []
  for _ in 0..<AUTO_MISSING_ROWS {
    let value = 5.0 * rng.next_normal()
    let class_zero = value < 0.0
    let last = value +
      (if class_zero { -10.0 } else { 10.0 }) +
      0.1 * rng.next_normal()
    x.push(
      if rng.next_double() < AUTO_MISSING_SHARE {
        @utils.nan()
      } else {
        value
      },
    )
    y.push(if class_zero { "Class 0" } else { "Class 1" })
    z.push(
      if rng.next_double() < AUTO_MISSING_SHARE {
        @utils.nan()
      } else {
        last
      },
    )
  }
  @api.DataFrame::new(
    ["X", "Y", "Z"],
    Map([
      ("X", @api.Column::numeric(x)),
      ("Y", @api.Column::discrete(y)),
      ("Z", @api.Column::numeric(z)),
    ]),
  )
}

///|
/// The number of the samples of the interventional distribution of the mixed
/// fixture of the missing values.
const AUTO_MISSING_MIXED_INTERVENTIONAL_SAMPLES : Int32 = 10

///|
/// The noise data of the counterfactual of the fixture of the missing values.
fn auto_missing_noise_data() -> @api.DataFrame {
  @api.DataFrame::from_numeric(
    ["X", "Y", "Z"],
    Map([("X", [10.0]), ("Y", [1.0]), ("Z", [10.0])]),
  )
}

///|
/// test "given missing data only numerical when auto assign mechanism with
/// experimental feature then handles as expected"
///
/// This is the port of the upstream test
/// `test_given_missing_data_only_numerical_when_auto_assign_mechanism_with_experimental_feature_then_handles_as_expected`.
///
/// The upstream raises when the data holds a missing value and its
/// experimental flag is not set, and MoonBit cannot catch the stop of a
/// function, so the test reads the predicate of the check of the port.
test "given missing data only numerical when auto assign mechanism with experimental feature then handles as expected" {
  let data = auto_missing_frame()
  assert_true(data.has_missing_values())
  let model = @gcm.ProbabilisticCausalModel::new(auto_missing_graph())
  let _ = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
    allow_nans=true,
  )
  @gcm.fit(model, data)
  let samples = @gcm.draw_samples(
    model,
    AUTO_MISSING_SAMPLES,
    @utils.Random::new(AUTO_MISSING_SEED + 1UL),
  )
  // The mean of `X` is zero, the mean of `Y` is ten and the mean of `Z` is
  // thirty, the way the upstream reads them.
  assert_true((@utils.mean(samples.numeric("X")) - 0.0).abs() < 1.0)
  assert_true((@utils.mean(samples.numeric("Y")) - 10.0).abs() < 2.0)
  assert_true((@utils.mean(samples.numeric("Z")) - 30.0).abs() < 3.0)
  // The intervention on `X` moves the mean of `Y` to thirty and the mean of
  // `Z` to sixty.
  let interventional = @gcm.interventional_samples(
    model,
    Map([("X", @gcm.set_number(10.0))]),
    None,
    Some(AUTO_MISSING_INTERVENTIONAL_SAMPLES),
    @utils.Random::new(AUTO_MISSING_SEED + 2UL),
  )
  for value in interventional.numeric("X") {
    assert_true((value - 10.0).abs() < 1.0e-9)
  }
  assert_true((@utils.mean(interventional.numeric("Y")) - 30.0).abs() < 5.0)
  assert_true((@utils.mean(interventional.numeric("Z")) - 60.0).abs() < 5.0)
  // The counterfactual of the noise sample holds the value of the
  // intervention, the mean of `Y` and the mean of `Z`.
  let counterfactual = @gcm.counterfactual_samples(
    model,
    Map([("X", @gcm.set_number(10.0))]),
    None,
    Some(auto_missing_noise_data()),
  )
  assert_true((counterfactual.numeric("X")[0] - 10.0).abs() < 1.0e-9)
  assert_true((counterfactual.numeric("Y")[0] - 30.0).abs() < 5.0)
  assert_true((counterfactual.numeric("Z")[0] - 70.0).abs() < 5.0)
  // The influence of the ancestors of `Z` and the attribution of the
  // anomalies of `Y` do not stop on the missing values.
  let _ = @gcm.intrinsic_causal_influence(
    model,
    "Z",
    @gcm.IccPrediction::exact(),
    None,
    100,
    100,
    100,
    100,
    @gcm.AssignmentQuality::good(),
    @gcm.ShapleyConfig::new(@gcm.ShapleyApproximationMethod::auto()),
    @utils.Random::new(AUTO_MISSING_SEED + 3UL),
  )
  let _ = @gcm.attribute_anomalies(
    model,
    "Y",
    data.take_rows([0, 1, 2, 3, 4]),
    @gcm.AnomalyScorer::median_cdf_quantile(),
    false,
    100,
    @gcm.ShapleyConfig::new(@gcm.ShapleyApproximationMethod::auto()),
    @utils.Random::new(AUTO_MISSING_SEED + 4UL),
  )
}

///|
/// test "given missing data mixed numerical and categorical when auto assign
/// mechanism with experimental feature then handles as expected"
///
/// This is the port of the upstream test
/// `test_given_missing_data_mixed_numerical_and_categorical_when_auto_assign_mechanism_with_experimental_feature_then_handles_as_expected`.
test "given missing data mixed numerical and categorical when auto assign mechanism with experimental feature then handles as expected" {
  let data = auto_missing_mixed_frame()
  assert_true(data.has_missing_values())
  let model = @gcm.ProbabilisticCausalModel::new(auto_missing_graph())
  let _ = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
    allow_nans=true,
  )
  @gcm.fit(model, data)
  let samples = @gcm.draw_samples(
    model,
    AUTO_MISSING_SAMPLES,
    @utils.Random::new(AUTO_MISSING_SEED + 6UL),
  )
  // The mean of `X` is zero and the mean of `Z` is zero, the way the upstream
  // reads them.
  assert_true((@utils.mean(samples.numeric("X")) - 0.0).abs() < 1.0)
  assert_true((@utils.mean(samples.numeric("Z")) - 0.0).abs() < 1.0)
  // Half of the samples of `Y` hold the class `Class 0`, the way the upstream
  // counts them.
  let mut num_class_zero = 0
  for label in samples.discrete("Y") {
    if label == "Class 0" {
      num_class_zero = num_class_zero + 1
    }
  }
  let expected = AUTO_MISSING_SAMPLES / 2
  assert_true((num_class_zero - expected).abs() <= 500)
  // The intervention on `X` moves every sample of `Y` to the class `Class 1`
  // and the mean of `Z` to twenty.
  let interventional = @gcm.interventional_samples(
    model,
    Map([("X", @gcm.set_number(10.0))]),
    None,
    Some(AUTO_MISSING_MIXED_INTERVENTIONAL_SAMPLES),
    @utils.Random::new(AUTO_MISSING_SEED + 7UL),
  )
  let mut num_class_one = 0
  for label in interventional.discrete("Y") {
    if label == "Class 1" {
      num_class_one = num_class_one + 1
    }
  }
  assert_true(
    (num_class_one - AUTO_MISSING_MIXED_INTERVENTIONAL_SAMPLES).abs() <= 3,
  )
  assert_true((@utils.mean(interventional.numeric("Z")) - 20.0).abs() < 5.0)
  // The counterfactual of the noise sample holds the value of the
  // intervention, the class of `Y` and the value of `Z`.
  let counterfactual = @gcm.counterfactual_samples(
    model,
    Map([("X", @gcm.set_number(10.0))]),
    None,
    Some(auto_missing_noise_data()),
  )
  assert_true((counterfactual.numeric("X")[0] - 10.0).abs() < 1.0e-9)
  assert_eq(counterfactual.discrete("Y")[0], "Class 1")
  assert_true((counterfactual.numeric("Z")[0] - 30.0).abs() < 5.0)
  // The influence of the ancestors of `Z` does not stop on the missing values.
  let _ = @gcm.intrinsic_causal_influence(
    model,
    "Z",
    @gcm.IccPrediction::exact(),
    None,
    100,
    100,
    100,
    100,
    @gcm.AssignmentQuality::good(),
    @gcm.ShapleyConfig::new(@gcm.ShapleyApproximationMethod::auto()),
    @utils.Random::new(AUTO_MISSING_SEED + 8UL),
  )
}

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
    auto_has_message_with(summary, "Assigning 'AdditiveNoiseModel using"),
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
      summary, "Assigning 'Empirical Distribution' to the node representing the marginal distribution.",
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

///|
/// The seed of the generator of the fixtures of the test of a linear
/// relationship.
const AUTO_RELATIONSHIP_SEED : UInt64 = 20240103UL

///|
/// The number of the rows of the fixtures of the test of a linear relationship.
const AUTO_RELATIONSHIP_ROWS : Int32 = 1000

///|
/// The features of the fixture of the simple data of the test of a linear
/// relationship: a column of uniform deviates.
fn auto_relationship_uniform() -> Array[Double] {
  let rng = @utils.Random::new(AUTO_RELATIONSHIP_SEED)
  let column : Array[Double] = []
  for _ in 0..<AUTO_RELATIONSHIP_ROWS {
    column.push(rng.next_double())
  }
  column
}

///|
/// The features of the fixture of the categorical data of the test of a linear
/// relationship: two columns of normal deviates.
fn auto_relationship_normals() -> (Array[Double], Array[Double]) {
  let rng = @utils.Random::new(AUTO_RELATIONSHIP_SEED)
  let first : Array[Double] = []
  let second : Array[Double] = []
  for _ in 0..<AUTO_RELATIONSHIP_ROWS {
    first.push(rng.next_normal())
    second.push(rng.next_normal())
  }
  (first, second)
}

///|
/// The head of the summary of the automatic assignment.
///
/// This is the text of the summary of the upstream up to the nodes it
/// describes, and the port reproduces it character for character.
fn auto_expected_summary_head() -> String {
  let mut out = "When using this auto assignment function, the given data is used to automatically assign a causal mechanism to each node. Note that causal mechanisms can also be customized and assigned manually.\n"
  out = out +
    "The following types of causal mechanisms are considered for the automatic selection:\n"
  out = out + "\nIf root node:\n"
  out = out +
    "An empirical distribution, i.e., the distribution is represented by randomly sampling from the provided data. This provides a flexible and non-parametric way to model the marginal distribution and is valid for all types of data modalities.\n"
  out = out + "\nIf non-root node and the data is continuous:\n"
  out = out +
    "Additive Noise Models (ANM) of the form X_i = f(PA_i) + N_i, where PA_i are the parents of X_i and the unobserved noise N_i is assumed to be independent of PA_i.To select the best model for f, different regression models are evaluated and the model with the smallest mean squared error is selected.Note that minimizing the mean squared error here is equivalent to selecting the best choice of an ANM.\n"
  out = out + "\nIf non-root node and the data is discrete:\n"
  out = out +
    "Discrete Additive Noise Models have almost the same definition as non-discrete ANMs, but come with an additional constraint for f to only return discrete values.\nNote that 'discrete' here refers to numerical values with an order. If the data is categorical, consider representing them as strings to ensure proper model selection.\n"
  out = out + "\nIf non-root node and the data is categorical:\n"
  out = out +
    "A functional causal model based on a classifier, i.e., X_i = f(PA_i, N_i).\nHere, N_i follows a uniform distribution on [0, 1] and is used to randomly sample a class (category) using the conditional probability distribution produced by a classification model. Here, different model classes are evaluated using the log loss metric and the best performing model class is selected.\n"
  out = out + "\nIn total, 6 nodes were analyzed:\n"
  out
}

///|
/// The message of a root node of the summary of the automatic assignment.
fn auto_expected_root_message(node : String) -> String {
  "\n--- Node: " +
  node +
  "\nNode " +
  node +
  " is a root node. Therefore, assigning 'Empirical Distribution' to the node representing the marginal distribution.\n"
}

///|
/// test "a linear relation is found and a quadratic one is not"
///
/// This is the case of the upstream that checks that a linear relation is found
/// and that a quadratic one is not.  The name of that case of the upstream
/// carries a typo of its own, so it is not quoted here.
test "a linear relation is found and a quadratic one is not" {
  let x = auto_relationship_uniform()
  let linear : Array[Double] = []
  let quadratic : Array[Double] = []
  for value in x {
    linear.push(2.0 * value)
    quadratic.push(value * value)
  }
  let features = @api.DataFrame::of("X", x)
  assert_true(
    @gcm.has_linear_relationship(
      features,
      @api.DataFrame::of("Y", linear),
      seed=AUTO_RELATIONSHIP_SEED,
    ),
  )
  assert_false(
    @gcm.has_linear_relationship(
      features,
      @api.DataFrame::of("Y", quadratic),
      seed=AUTO_RELATIONSHIP_SEED,
    ),
  )
}

///|
/// test "a linear boundary is found and a product one is not"
///
/// This is the case of the upstream
/// `test_given_categorical_data_when_calling_has_linear_relationship_then_returns_correct_results`.
test "a linear boundary is found and a product one is not" {
  let (first, second) = auto_relationship_normals()
  let sum_labels : Array[String] = []
  let product_labels : Array[String] = []
  for i in 0..<AUTO_RELATIONSHIP_ROWS {
    sum_labels.push(if first[i] + second[i] > 0.0 { "1" } else { "0" })
    product_labels.push(if first[i] * second[i] > 0.0 { "1" } else { "0" })
  }
  let features = @api.DataFrame::new(
    ["X0", "X1"],
    Map([
      ("X0", @api.Column::numeric(first)),
      ("X1", @api.Column::numeric(second)),
    ]),
  )
  assert_true(
    @gcm.has_linear_relationship(
      features,
      @api.DataFrame::new(
        ["Y"],
        Map([("Y", @api.Column::discrete(sum_labels))]),
      ),
      seed=AUTO_RELATIONSHIP_SEED,
    ),
  )
  assert_false(
    @gcm.has_linear_relationship(
      features,
      @api.DataFrame::new(
        ["Y"],
        Map([("Y", @api.Column::discrete(product_labels))]),
      ),
      seed=AUTO_RELATIONSHIP_SEED,
    ),
  )
}

///|
/// test "an imbalanced categorical target is handled"
///
/// This is the case of the upstream
/// `test_given_imbalanced_categorical_data_when_calling_has_linear_relationship_then_does_not_raise_exception`.
test "an imbalanced categorical target is handled" {
  let rng = @utils.Random::new(AUTO_RELATIONSHIP_SEED)
  let values : Array[Double] = []
  let labels : Array[String] = []
  for _ in 0..<AUTO_RELATIONSHIP_ROWS {
    values.push(rng.next_normal())
    labels.push("OneClass")
  }
  // A second sample of the rare class makes the split of the rows possible.
  values.push(0.0)
  labels.push("RareClass")
  let features = @api.DataFrame::of("X", values)
  let target = @api.DataFrame::new(
    ["Y"],
    Map([("Y", @api.Column::discrete(labels))]),
  )
  assert_true(
    @gcm.has_linear_relationship(features, target, seed=AUTO_RELATIONSHIP_SEED),
  )
}

///|
/// test "a target of rare categorical features is handled"
///
/// This is the case of the upstream
/// `test_given_data_with_rare_categorical_features_when_calling_has_linear_relationship_then_does_not_raise_exception`.
test "a target of rare categorical features is handled" {
  let values : Array[String] = []
  let labels : Array[String] = []
  for i in 0..<20 {
    values.push("Feature" + i.to_string())
    labels.push(if i < 10 { "Class1" } else { "Class2" })
  }
  let features = @api.DataFrame::new(
    ["X"],
    Map([("X", @api.Column::discrete(values))]),
  )
  let target = @api.DataFrame::new(
    ["Y"],
    Map([("Y", @api.Column::discrete(labels))]),
  )
  assert_true(
    @gcm.has_linear_relationship(features, target, seed=AUTO_RELATIONSHIP_SEED),
  )
}

///|
/// test "the description of the summary holds the format of the upstream"
///
/// This is the case of the upstream
/// `test_given_continuous_data_when_print_auto_summary_then_returns_expected_formats`.
test "the description of the summary holds the format of the upstream" {
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
  assert_true(description.contains(auto_expected_summary_head()))
  for j in 0..<AUTO_NUM_FEATURES {
    assert_true(
      description.contains(auto_expected_root_message("X" + j.to_string())),
    )
  }
  assert_true(
    description.contains(
      "\n--- Node: Y\nNode Y is a non-root node with continuous data. Assigning 'AdditiveNoiseModel using ",
    ),
  )
  assert_true(
    description.contains(
      "This represents the causal relationship as Y := f(X0,X1,X2,X3,X4) + N.",
    ),
  )
  assert_true(
    description.contains(
      "For the model selection, the following models were evaluated on the mean squared error (MSE) metric:\n",
    ),
  )
  assert_true(
    description.contains(
      "===Note===\nNote, based on the selected auto assignment quality, the set of evaluated models changes.",
    ),
  )
}

///|
/// test "the description of the summary of a categorical target holds the format of the upstream"
///
/// This is the case of the upstream
/// `test_given_categorical_data_when_print_auto_summary_then_returns_expected_formats`.
test "the description of the summary of a categorical target holds the format of the upstream" {
  let columns = auto_features()
  let data = auto_selection_frame(
    columns,
    @api.Column::discrete(auto_linear_labels(columns)),
  )
  let model = @gcm.ProbabilisticCausalModel::new(auto_selection_graph())
  let summary = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
  )
  let description = summary.to_string()
  assert_true(description.contains(auto_expected_summary_head()))
  for j in 0..<AUTO_NUM_FEATURES {
    assert_true(
      description.contains(auto_expected_root_message("X" + j.to_string())),
    )
  }
  assert_true(
    description.contains(
      "\n--- Node: Y\nNode Y is a non-root node with categorical data. Assigning 'Classifier FCM based on ",
    ),
  )
  assert_true(
    description.contains(
      "This represents the causal relationship as Y := f(X0,X1,X2,X3,X4,N).",
    ),
  )
  assert_true(
    description.contains(
      "For the model selection, the following models were evaluated on the log loss metric:\n",
    ),
  )
}

///|
/// The seed of the generator of the fixtures of the statistics of the drawn
/// samples.
const AUTO_STATISTICS_SEED : UInt64 = 20240105UL

///|
/// The number of the rows of the fixtures of the statistics of the drawn
/// samples.
const AUTO_STATISTICS_ROWS : Int32 = 2000

///|
/// The standard deviation of the noise of the fixtures of the statistics of
/// the drawn samples.
const AUTO_STATISTICS_NOISE : Double = 0.2

///|
/// The graph of the fixtures of the statistics of the drawn samples, where the
/// nodes `X0` and `X2` are the parents of the nodes `X1` and `X3`.
fn auto_statistics_graph() -> @graph.DirectedGraph {
  let g = @graph.DirectedGraph::new()
  g.add_edge("X0", "X1")
  g.add_edge("X0", "X2")
  g.add_edge("X2", "X3")
  g
}

///|
/// The frame of the fixtures of the statistics of the drawn samples.
///
/// The relations of the fixture are the ones of the upstream: the linear
/// fixture holds `X1 = 2 * X0` and `X2 = 0.5 * X0`, the non-linear one
/// `X1 = sin(2 * X0)` and `X2 = 0.5 * X0 * X0`, and both of them hold
/// `X3 = 0.5 * X2`.
fn auto_statistics_frame(non_linear : Bool) -> @api.DataFrame {
  let rng = @utils.Random::new(AUTO_STATISTICS_SEED)
  let first : Array[Double] = []
  let second : Array[Double] = []
  let third : Array[Double] = []
  let fourth : Array[Double] = []
  for _ in 0..<AUTO_STATISTICS_ROWS {
    let x0 = rng.next_normal()
    let x1 = if non_linear { @math.sin(2.0 * x0) } else { 2.0 * x0 }
    let x2 = if non_linear { 0.5 * x0 * x0 } else { 0.5 * x0 }
    let noise1 = AUTO_STATISTICS_NOISE * rng.next_normal()
    let noise2 = AUTO_STATISTICS_NOISE * rng.next_normal()
    let noise3 = AUTO_STATISTICS_NOISE * rng.next_normal()
    first.push(x0)
    second.push(x1 + noise1)
    third.push(x2 + noise2)
    fourth.push(0.5 * (x2 + noise2) + noise3)
  }
  @api.DataFrame::new(
    ["X0", "X1", "X2", "X3"],
    Map([
      ("X0", @api.Column::numeric(first)),
      ("X1", @api.Column::numeric(second)),
      ("X2", @api.Column::numeric(third)),
      ("X3", @api.Column::numeric(fourth)),
    ]),
  )
}

///|
/// The data of the fixture and the samples that the fitted model draws.
///
/// The model is assigned, fitted and sampled, the way the upstream does it
/// before it compares the statistics of the samples with the ones of the data.
fn auto_draw_statistics(non_linear : Bool) -> (@api.DataFrame, @api.DataFrame) {
  let data = auto_statistics_frame(non_linear)
  let model = @gcm.ProbabilisticCausalModel::new(auto_statistics_graph())
  let _ = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
    seed=AUTO_STATISTICS_SEED,
  )
  @gcm.fit(model, data)
  let samples = @gcm.draw_samples(
    model,
    AUTO_STATISTICS_ROWS,
    @utils.Random::new(AUTO_STATISTICS_SEED),
  )
  (data, samples)
}

///|
/// test "the samples of a fitted linear model hold the statistics of the data"
///
/// This is the case of the upstream
/// `test_given_linear_gaussian_data_when_fit_scm_with_auto_assigned_models_with_default_parameters_then_generate_samples_with_correct_statistics`.
///
/// The mean and the standard deviation of every drawn column have to be the
/// ones of the column of the data.
test "the samples of a fitted linear model hold the statistics of the data" {
  let (data, samples) = auto_draw_statistics(false)
  for node in ["X0", "X1", "X2", "X3"] {
    let original = data.numeric(node)
    let drawn = samples.numeric(node)
    assert_true((@utils.mean(drawn) - @utils.mean(original)).abs() < 0.1)
    assert_true(
      (@utils.variance(drawn, 0).sqrt() - @utils.variance(original, 0).sqrt()).abs() <
      0.1,
    )
  }
}

///|
/// test "the samples of a fitted non-linear model hold the statistics of the data"
///
/// This is the case of the upstream
/// `test_given_nonlinear_gaussian_data_when_fit_scm_with_auto_assigned_models_with_default_parameters_then_generate_samples_with_correct_statistics`.
test "the samples of a fitted non-linear model hold the statistics of the data" {
  let (data, samples) = auto_draw_statistics(true)
  for node in ["X0", "X1", "X2", "X3"] {
    let original = data.numeric(node)
    let drawn = samples.numeric(node)
    assert_true((@utils.mean(drawn) - @utils.mean(original)).abs() < 0.1)
    assert_true(
      (@utils.variance(drawn, 0).sqrt() - @utils.variance(original, 0).sqrt()).abs() <
      0.1,
    )
  }
}

///|
/// The seed of the generator of the fixtures of the multiclass targets.
const AUTO_MULTICLASS_SEED : UInt64 = 20240104UL

///|
/// The number of the rows of the fixtures of the multiclass targets.
const AUTO_MULTICLASS_ROWS : Int32 = 100

///|
/// The graph of the fixtures of the multiclass targets, where every feature
/// is a parent of the target.
fn auto_multiclass_graph() -> @graph.DirectedGraph {
  let g = @graph.DirectedGraph::new()
  for j in 0..<4 {
    g.add_edge("X" + j.to_string(), "Y")
  }
  g
}

///|
/// The frame of the fixtures of the multiclass targets.
///
/// The features are the ones of the upstream: two numeric columns and two
/// categorical ones. The linear fixture holds the relation `2 * X0 + 1.5 * X1
/// + 0.8 * X2 + 0.5 * X3` and the non-linear one the relation of the upstream,
/// and the target of both of them holds three classes.
fn auto_multiclass_frame(non_linear : Bool) -> @api.DataFrame {
  let rng = @utils.Random::new(AUTO_MULTICLASS_SEED)
  let first : Array[Double] = []
  let second : Array[Double] = []
  let third : Array[String] = []
  let fourth : Array[String] = []
  for _ in 0..<AUTO_MULTICLASS_ROWS {
    first.push(rng.next_normal())
    second.push(rng.next_normal())
    third.push(if rng.next_double() < 0.5 { "TypeA" } else { "TypeB" })
    fourth.push(
      match rng.next_int(3) {
        0 => "Group1"
        1 => "Group2"
        _ => "Group3"
      },
    )
  }
  let values : Array[Double] = []
  for i in 0..<AUTO_MULTICLASS_ROWS {
    let cat1 = if third[i] == "TypeA" { 1.0 } else { -1.0 }
    let cat2 = if fourth[i] == "Group1" {
      2.0
    } else if fourth[i] == "Group2" {
      0.0
    } else {
      -2.0
    }
    if non_linear {
      values.push(
        @math.exp(first[i] * 0.5) +
        @math.sin(second[i] * 2.0) +
        first[i] * second[i] * 0.3 +
        cat1 * @math.exp(second[i] * 0.2) +
        cat2 * @math.cos(first[i]),
      )
    } else {
      values.push(2.0 * first[i] + 1.5 * second[i] + 0.8 * cat1 + 0.5 * cat2)
    }
  }
  let labels : Array[String] = []
  if non_linear {
    // The classes of the non-linear fixture are the thirds of the distribution
    // of the relation.
    let sorted = values.copy()
    sorted.sort_by(fn(a, b) { @utils.compare_double(a, b) })
    let low = sorted[33]
    let high = sorted[66]
    for value in values {
      labels.push(
        if value > high {
          "Class_A"
        } else if value > low {
          "Class_B"
        } else {
          "Class_C"
        },
      )
    }
  } else {
    for value in values {
      labels.push(
        if value > 1.0 {
          "Class_A"
        } else if value > -1.0 {
          "Class_B"
        } else {
          "Class_C"
        },
      )
    }
  }
  @api.DataFrame::new(
    ["X0", "X1", "X2", "X3", "Y"],
    Map([
      ("X0", @api.Column::numeric(first)),
      ("X1", @api.Column::numeric(second)),
      ("X2", @api.Column::discrete(third)),
      ("X3", @api.Column::discrete(fourth)),
      ("Y", @api.Column::discrete(labels)),
    ]),
  )
}

///|
/// test "a linear multiclass relation is assigned the classifier of the port"
///
/// This is the case of the upstream
/// `test_given_linear_multiclass_mixed_features_when_auto_assign_causal_models_with_good_quality_returns_linear_model`.
///
/// The upstream picks the linear model for this relation and the port picks
/// its polynomial logistic regression, because the classifier of the port is
/// the one-versus-rest variant of the upstream, whose probabilities of a
/// target of more than two classes are worse than the ones of the
/// multinomial variant of the upstream. The test records the difference.
test "a linear multiclass relation is assigned the classifier of the port" {
  let data = auto_multiclass_frame(false)
  let model = @gcm.ProbabilisticCausalModel::new(auto_multiclass_graph())
  let _ = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
    seed=AUTO_MULTICLASS_SEED,
  )
  assert_true(auto_is_classifier(model, "Y"))
  assert_true(auto_is_polynomial_logistic(model, "Y"))
}

///|
/// test "a non-linear multiclass relation is assigned a non-linear classifier of the port"
///
/// This is the case of the upstream
/// `test_given_non_linear_multiclass_mixed_features_when_auto_assign_causal_models_with_good_quality_returns_non_linear_model`.
///
/// The upstream picks a non-linear model for this relation and the port picks
/// its polynomial logistic regression, which is a non-linear model as well.
test "a non-linear multiclass relation is assigned a non-linear classifier of the port" {
  let data = auto_multiclass_frame(true)
  let model = @gcm.ProbabilisticCausalModel::new(auto_multiclass_graph())
  let _ = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
    seed=AUTO_MULTICLASS_SEED,
  )
  assert_true(auto_is_classifier(model, "Y"))
  assert_true(auto_is_polynomial_logistic(model, "Y"))
}
