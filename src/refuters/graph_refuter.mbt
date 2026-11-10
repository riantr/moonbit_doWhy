///|
/// The refuter that checks the conditional independences of a graph against
/// the data.
///
/// This is the port of `dowhy.causal_refuters.graph_refuter`. The upstream
/// tests every conditional independence the graph entails, with the partial
/// correlation of the continuous data and with the conditional mutual
/// information of the discrete data, and it reports how many of them the data
/// satisfies.

///|
/// A conditional independence of a graph.
///
/// This is the port of the implication of the upstream, which is a pair of
/// variables and the variables that are conditioned on.
pub struct Implication {
  /// The first variable of the implication.
  x : String
  /// The second variable of the implication.
  y : String
  /// The variables the implication is conditioned on.
  z : Array[String]
}

///|
/// A conditional independence of a graph.
///
/// This is the port of the implication of the upstream, which is a pair of
/// variables and the variables that are conditioned on.
pub fn Implication::new(
  x : String,
  y : String,
  z : Array[String],
) -> Implication {
  { x, y, z: z.copy(), }
}

///|
/// The kind of a column of the data.
///
/// The upstream tells the columns of its data apart by their type: a column
/// of integers is discrete, a column of floating point numbers is continuous,
/// and a column of integers that holds only zeros and ones is binary.
pub enum VariableKind {
  /// A column of numbers.
  Continuous
  /// A column of categories.
  Discrete
  /// A column of categories that holds only zeros and ones.
  Binary
}

///|
/// The names of the tests of the conditional independence.
///
/// This is the port of the dictionary `independence_test` of the upstream, which
/// names the test of the continuous data and the test of the discrete data.
pub struct IndependenceTests {
  /// The name of the test of the continuous data.
  test_for_continuous : String
  /// The name of the test of the discrete data.
  test_for_discrete : String
}

///|
/// The names of the tests of the conditional independence.
pub fn IndependenceTests::new(
  test_for_continuous : String,
  test_for_discrete : String,
) -> IndependenceTests {
  { test_for_continuous, test_for_discrete, }
}

///|
/// The name of the test of the continuous data.
pub fn IndependenceTests::continuous(self : IndependenceTests) -> String {
  self.test_for_continuous
}

///|
/// The name of the test of the discrete data.
pub fn IndependenceTests::discrete(self : IndependenceTests) -> String {
  self.test_for_discrete
}

///|
/// The result of the test of one conditional independence.
pub struct IndependenceTest {
  /// The value of the test: the p-value of the partial correlation of the
  /// continuous data and the conditional mutual information of the discrete
  /// data.
  ///
  /// It is `None` when the upstream could not run the test.
  value : Double?
  /// Whether the independence holds.
  ///
  /// It is `None` when the upstream could not run the test, the way the
  /// upstream writes the text `"NotImplemented"` in the place of the verdict.
  holds : Bool?
}

///|
/// The result of the refutation of a graph.
pub struct GraphRefutation {
  /// The name of the test of the discrete data.
  method_name_discrete : String
  /// The name of the test of the continuous data.
  method_name_continuous : String
  /// The number of the conditional independences the model entails.
  number_of_constraints_model : Int32
  /// The number of the conditional independences the data satisfies.
  number_of_constraints_satisfied : Int32
  /// Whether the refutation passed.
  ///
  /// The upstream sets it when every conditional independence of the model
  /// holds or when none of them fails, and it leaves it unset when it could
  /// not run a test.
  refutation_result : Bool?
  /// The result of the test of every conditional independence, keyed by the
  /// implication.
  results : Map[String, IndependenceTest]
}

///|
/// The value of the test of one conditional independence.
///
/// It is `None` when the upstream could not run the test.
pub fn IndependenceTest::value(self : IndependenceTest) -> Double? {
  self.value
}

///|
/// Whether the independence of one conditional independence holds.
///
/// It is `None` when the upstream could not run the test.
pub fn IndependenceTest::holds(self : IndependenceTest) -> Bool? {
  self.holds
}

///|
/// The refuter that checks the conditional independences of a graph.
///
/// This is the port of `dowhy.causal_refuters.graph_refuter.GraphRefuter`.
///
/// The upstream copies the data and keeps the results in the refuter, and the
/// port does the same. The results live in the arrays and in the map of the
/// refuter, and a container of the toolchain is mutated in place, so the
/// results of the refutation are the results of the refuter that produced
/// them.
pub struct GraphRefuter {
  /// The data the conditional independences are tested on.
  data : @api.DataFrame
  /// The name of the test of the discrete data.
  method_name_discrete : String
  /// The name of the test of the continuous data.
  method_name_continuous : String
  /// The implications that hold false for the data.
  false_implications : Array[Implication]
  /// The implications that hold true for the data.
  true_implications : Array[Implication]
  /// The result of the test of every implication.
  results : Map[String, IndependenceTest]
}

///|
/// The name of the test of the discrete data.
pub fn GraphRefutation::discrete_method(self : GraphRefutation) -> String {
  self.method_name_discrete
}

///|
/// The name of the test of the continuous data.
pub fn GraphRefutation::continuous_method(self : GraphRefutation) -> String {
  self.method_name_continuous
}

///|
/// The number of the conditional independences the model entails.
pub fn GraphRefutation::constraints_of_the_model(
  self : GraphRefutation,
) -> Int32 {
  self.number_of_constraints_model
}

///|
/// The number of the conditional independences the data satisfies.
pub fn GraphRefutation::constraints_satisfied_by_the_data(
  self : GraphRefutation,
) -> Int32 {
  self.number_of_constraints_satisfied
}

///|
/// Whether the refutation passed.
///
/// It is `None` when the refutation has not run yet.
pub fn GraphRefutation::refutation_result(self : GraphRefutation) -> Bool? {
  self.refutation_result
}

///|
/// The result of the test of every conditional independence.
pub fn GraphRefutation::results(
  self : GraphRefutation,
) -> Map[String, IndependenceTest] {
  self.results.copy()
}

///|
/// A refuter of the conditional independences of a graph.
///
/// This is the port of the constructor of
/// `dowhy.causal_refuters.graph_refuter.GraphRefuter`.
pub fn GraphRefuter::new(
  data : @api.DataFrame,
  method_name_discrete : String,
  method_name_continuous : String,
) -> GraphRefuter {
  {
    data,
    method_name_discrete,
    method_name_continuous,
    false_implications: [],
    true_implications: [],
    results: Map([]),
  }
}

///|
/// The results of the tests of the implications.
pub fn GraphRefuter::results(
  self : GraphRefuter,
) -> Map[String, IndependenceTest] {
  self.results.copy()
}

///|
/// The implications that hold false for the data.
pub fn GraphRefuter::false_implications(
  self : GraphRefuter,
) -> Array[Implication] {
  self.false_implications.copy()
}

///|
/// The implications that hold true for the data.
pub fn GraphRefuter::true_implications(
  self : GraphRefuter,
) -> Array[Implication] {
  self.true_implications.copy()
}

///|
/// Test the given conditional independences against the data.
///
/// This is the port of
/// `dowhy.causal_refuters.graph_refuter.GraphRefuter.refute_model`.
///
/// The upstream tests an implication with the partial correlation when the
/// data of the implication is continuous, and with the conditional mutual
/// information when it is discrete. A binary column is a discrete column of
/// the upstream, so it is tested with the conditional mutual information when
/// it is one of the two variables and with the partial correlation when it is
/// one of the variables that are conditioned on.
pub fn GraphRefuter::refute_model(
  self : GraphRefuter,
  constraints : Array[Implication],
) -> GraphRefutation {
  for constraint in constraints {
    self.test_implication(constraint)
  }
  let passed = self.set_refutation_result(constraints.length())
  {
    method_name_discrete: self.method_name_discrete,
    method_name_continuous: self.method_name_continuous,
    number_of_constraints_model: constraints.length(),
    number_of_constraints_satisfied: self.true_implications.length(),
    refutation_result: passed,
    results: self.results.copy(),
  }
}

///|
/// Test one conditional independence against the data.
fn GraphRefuter::test_implication(
  self : GraphRefuter,
  constraint : Implication,
) -> Unit {
  let kind_x = self.kind_of(constraint.x)
  let kind_y = self.kind_of(constraint.y)
  let kinds : Array[VariableKind] = []
  for name in constraint.z {
    kinds.push(self.kind_of(name))
  }
  let all_continuous = is_continuous_kind(kind_x) &&
    is_continuous_kind(kind_y) &&
    kinds.all(fn(kind) { is_continuous_kind(kind) })
  let all_discrete = is_discrete_kind(kind_x) &&
    is_discrete_kind(kind_y) &&
    kinds.all(fn(kind) { is_discrete_kind(kind) })
  let all_continuous_or_binary = is_continuous_or_binary_kind(kind_x) &&
    is_continuous_or_binary_kind(kind_y) &&
    kinds.all(fn(kind) { is_continuous_or_binary_kind(kind) })
  if all_continuous {
    if self.method_name_continuous == "" ||
      self.method_name_continuous == "partial_correlation" {
      self.partial_correlation(constraint)
    }
    return
  }
  if all_discrete {
    if self.method_name_discrete == "" ||
      self.method_name_discrete == "conditional_mutual_information" {
      self.conditional_mutual_information(constraint)
    }
    return
  }
  if all_continuous_or_binary {
    self.partial_correlation(constraint)
    return
  }
  if kinds.all(fn(kind) { is_discrete_kind(kind) }) &&
    (is_discrete_kind(kind_x) || is_discrete_kind(kind_y)) {
    self.conditional_mutual_information(constraint)
    return
  }
  if is_discrete_kind(kind_x) && is_discrete_kind(kind_y) {
    self.conditional_mutual_information(constraint)
    return
  }
  // The upstream reports the implication it cannot test, and it writes the
  // text "NotImplemented" in the place of the verdict.
  self.results.set(implication_key(constraint), { value: None, holds: None, })
}

///|
/// Test one conditional independence with the partial correlation.
///
/// This is the port of
/// `dowhy.causal_refuters.graph_refuter.GraphRefuter.partial_correlation`.
fn GraphRefuter::partial_correlation(
  self : GraphRefuter,
  constraint : Implication,
) -> Unit {
  let names = [constraint.x, constraint.y] + constraint.z
  let columns : Array[Array[Double]] = []
  for name in names {
    columns.push(numeric_values(self.data, name))
  }
  let conditioning : Array[Int32] = []
  for i in 2..<names.length() {
    conditioning.push(i)
  }
  let correlation = @utils.partial_corr(columns, 0, 1, conditioning, "pearson")
  let p_value = correlation.p_value
  if p_value < 0.05 {
    self.false_implications.push(constraint)
    self.results.set(implication_key(constraint), {
      value: Some(p_value),
      holds: Some(false),
    })
  } else {
    self.true_implications.push(constraint)
    self.results.set(implication_key(constraint), {
      value: Some(p_value),
      holds: Some(true),
    })
  }
}

///|
/// Test one conditional independence with the conditional mutual information.
///
/// This is the port of
/// `dowhy.causal_refuters.graph_refuter.GraphRefuter.conditional_mutual_information`.
fn GraphRefuter::conditional_mutual_information(
  self : GraphRefuter,
  constraint : Implication,
) -> Unit {
  let conditioning : Array[Array[String]] = []
  for name in constraint.z {
    conditioning.push(text_values(self.data, name))
  }
  let information = @utils.conditional_mi(conditioning)
  if information <= 0.05 {
    self.true_implications.push(constraint)
    self.results.set(implication_key(constraint), {
      value: Some(information),
      holds: Some(true),
    })
  } else {
    self.false_implications.push(constraint)
    self.results.set(implication_key(constraint), {
      value: Some(information),
      holds: Some(false),
    })
  }
}

///|
/// The result of the refutation, once every implication has been tested.
///
/// This is the port of
/// `dowhy.causal_refuters.graph_refuter.GraphRefuter.set_refutation_result`.
fn GraphRefuter::set_refutation_result(
  self : GraphRefuter,
  number_of_constraints_model : Int32,
) -> Bool? {
  if self.true_implications.length() == number_of_constraints_model {
    return Some(true)
  }
  if self.false_implications.length() == 0 {
    return Some(true)
  }
  Some(false)
}

///|
/// The kind of the given column of the data.
fn GraphRefuter::kind_of(self : GraphRefuter, name : String) -> VariableKind {
  match self.data.column(name) {
    Some(@api.Column::Discrete(values)) =>
      if is_binary_text(values) {
        Binary
      } else {
        Discrete
      }
    _ => Continuous
  }
}

///|
/// The key of an implication.
///
/// The upstream keys the results of the implications with the pair of the two
/// variables and with the variables that are conditioned on.
pub fn implication_key(implication : Implication) -> String {
  let mut key = implication.x + "|" + implication.y
  for name in implication.z {
    key = key + "|" + name
  }
  key
}

///|
/// Whether a column of categories holds only zeros and ones.
fn is_binary_text(values : Array[String]) -> Bool {
  for value in values {
    if value != "0" && value != "1" {
      return false
    }
  }
  true
}

///|
/// The values of a column, as numbers.
///
/// The upstream reads the columns of its integer columns as numbers, and the
/// columns of the port hold the categories of a discrete column as text.
fn numeric_values(data : @api.DataFrame, name : String) -> Array[Double] {
  match data.column(name) {
    Some(@api.Column::Numeric(values)) => values
    Some(@api.Column::Discrete(values)) => {
      let numbers : Array[Double] = []
      for value in values {
        numbers.push(if value == "1" { 1.0 } else { 0.0 })
      }
      numbers
    }
    None => []
  }
}

///|
/// The text of the values of a column.
fn text_values(data : @api.DataFrame, name : String) -> Array[String] {
  match data.column(name) {
    Some(@api.Column::Discrete(values)) => values
    Some(@api.Column::Numeric(values)) => {
      let texts : Array[String] = []
      for value in values {
        texts.push(value.to_string())
      }
      texts
    }
    None => []
  }
}

///|
/// Whether the kind is a continuous one.
fn is_continuous_kind(kind : VariableKind) -> Bool {
  match kind {
    Continuous => true
    Discrete => false
    Binary => false
  }
}

///|
/// Whether the kind is a discrete one.
fn is_discrete_kind(kind : VariableKind) -> Bool {
  match kind {
    Continuous => false
    Discrete => true
    Binary => true
  }
}

///|
/// Whether the kind is a continuous one or a binary one.
fn is_continuous_or_binary_kind(kind : VariableKind) -> Bool {
  match kind {
    Continuous => true
    Discrete => false
    Binary => true
  }
}
