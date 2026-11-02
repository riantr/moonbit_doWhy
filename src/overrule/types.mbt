///|
/// The operation of a literal of a binarised feature.
pub enum LiteralOperation {
  /// The value of the feature itself.
  Binary
  /// The negation of the value of the feature.
  Negation
  /// The value of the feature is not greater than the threshold.
  LessEqual
  /// The value of the feature is greater than the threshold.
  Greater
}

///|
/// The name of the operation, the way the upstream reports it in a rule.
pub fn LiteralOperation::name(self : LiteralOperation) -> String {
  match self {
    Binary => ""
    Negation => "not"
    LessEqual => "<="
    Greater => ">"
  }
}

///|
/// The strategy of the rounding of the coefficients of the rules.
pub enum RoundingStrategy {
  /// A fixed reward for the inclusion of the positive samples.
  Greedy
  /// A sweep over the reward, the way the upstream rounds by default.
  GreedySweep
}

///|
/// The rounding with a fixed reward for the positive samples.
pub fn RoundingStrategy::greedy() -> RoundingStrategy {
  Greedy
}

///|
/// A literal of a binarised feature: a condition on the value of a feature.
pub struct Literal {
  /// The name of the feature.
  feature : String
  /// The operation of the literal.
  operation : LiteralOperation
  /// The threshold of the literal.
  value : Double
}

///|
/// An atom of a rule, the way the upstream reports it.
pub struct RuleAtom {
  /// The name of the feature.
  feature : String
  /// The operation of the literal, the way the upstream spells it.
  operation : String
  /// The value of the literal, the empty string for a binary feature.
  value : String
}

///|
/// A rule of a ruleset: the literals that have to hold at the same time.
pub type Rule = Array[RuleAtom]

///|
/// The rules of a ruleset estimator.
pub type RuleSet = Array[Rule]

///|
/// The kind of a feature of the binariser.
pub enum FeatureKind {
  /// A feature with at most two distinct values.
  Binary
  /// A feature with more than two distinct values.
  Ordinal
}

///|
/// The binarised features of a data set.
pub struct BinarizedData {
  /// The literals of the features.
  literals : Array[Literal]
  /// The values of every literal: an array of zeros and ones per literal.
  columns : Array[Array[Double]]
  /// The feature of every literal.
  feature_of : Array[Int32]
  /// The number of the rows.
  n_rows : Int32
}

///|
/// The distinct values of a column, in the increasing order.
pub fn distinct_values(values : Array[Double]) -> Array[Double] {
  let sorted = values.copy()
  sorted.sort_by(fn(a, b) { @utils.compare_double(a, b) })
  let out : Array[Double] = []
  for value in sorted {
    if out.length() == 0 || out[out.length() - 1] != value {
      out.push(value)
    }
  }
  out
}

///|
/// The index of a value in the list of the distinct values, or minus one when
/// the value is not among them.
fn index_of_value(values : Array[Double], value : Double) -> Int32 {
  for i = 0; i < values.length(); i = i + 1 {
    if values[i] == value {
      return i
    }
  }
  -1
}
