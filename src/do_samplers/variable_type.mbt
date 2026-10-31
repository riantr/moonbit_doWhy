/// The variable types of the do samplers.
///
/// The port keeps the single letter codes of `dowhy`, so that the callers
/// write the same dictionaries as the Python code: `"c"` for a continuous
/// variable, `"d"` for a discrete one, `"b"` for a binary one, `"o"` for an
/// ordered discrete one and `"u"` for an unordered discrete one.

///|
/// The type of a variable.
pub enum VariableType {
  /// A continuous variable.
  Continuous
  /// A discrete variable.
  Discrete
  /// A binary variable.
  Binary
  /// An ordered discrete variable.
  Ordered
  /// An unordered discrete variable.
  Unordered
}

///|
/// The type of a variable, parsed from its single letter code.
///
/// This is the port of the type codes of `dowhy.utils.propensity_score`; an
/// unknown code is an error, like the upstream code raises one.
pub fn VariableType::from_code(code : String) -> VariableType {
  match code {
    "c" => Continuous
    "d" => Discrete
    "b" => Binary
    "o" => Ordered
    "u" => Unordered
    _ => abort("Variable type " + code + " is not a recognized format type.")
  }
}

///|
/// The single letter code of the type.
pub fn VariableType::code(self : VariableType) -> String {
  match self {
    Continuous => "c"
    Discrete => "d"
    Binary => "b"
    Ordered => "o"
    Unordered => "u"
  }
}

///|
/// Whether the variable has a finite number of levels.
pub fn VariableType::is_discrete(self : VariableType) -> Bool {
  match self {
    Continuous => false
    Discrete => true
    Binary => true
    Ordered => true
    Unordered => true
  }
}

///|
/// The variable types of the given name / code pairs.
///
/// The helper builds the dictionary of the types the way the upstream code
/// spells it, e.g. `variable_types([("v", "d"), ("X0", "c")])`.
pub fn variable_types(
  pairs : Array[(String, String)],
) -> Map[String, VariableType] {
  let types : Map[String, VariableType] = Map([])
  for pair in pairs {
    let (name, code) = pair
    types.set(name, VariableType::from_code(code))
  }
  types
}

///|
/// The type of a variable, or an error when the variable has no type.
fn variable_type_of(
  variable_types : Map[String, VariableType],
  name : String,
) -> VariableType {
  match variable_types.get(name) {
    Some(kind) => kind
    None =>
      abort(
        "Variable type of the variable " +
        name +
        " is not a recognized format type.",
      )
  }
}
