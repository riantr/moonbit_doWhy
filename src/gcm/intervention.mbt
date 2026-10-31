///|
/// The interventions on the nodes of a causal model.
///
/// This is the port of the interventions of `dowhy.gcm.whatif`. The upstream
/// holds them in a dictionary of functions of a numpy array; the port holds
/// them in a map of functions of a single value, because a MoonBit array
/// holds one kind of value and a node of a causal model holds either a number
/// or a category.

///|
/// A value of a node of a causal model.
///
/// A node of a causal model holds either a number or a category, and an
/// intervention is a function of the value of the node, so the port needs one
/// type for both.
pub enum CausalValue {
  ///
  /// The value of a node that holds a number.
  Number(Double)
  ///
  /// The value of a node that holds a category.
  Category(String)
}

///|
/// An intervention on a node of a causal model.
///
/// The intervention maps the value of the node before the intervention to its
/// value after it. An atomic intervention is a constant one, and a soft
/// intervention maps the value of the node.
pub type Intervention = (CausalValue) -> CausalValue

///|
/// The intervention that sets the value of a node.
pub fn set_value(value : CausalValue) -> Intervention {
  fn(_value : CausalValue) { value }
}

///|
/// The intervention that sets the value of a numeric node.
///
/// This is the port of the atomic intervention `do(X := 2)` of the upstream.
pub fn set_number(value : Double) -> Intervention {
  fn(_value : CausalValue) { Number(value) }
}

///|
/// The intervention that sets the value of a categorical node.
pub fn set_category(value : String) -> Intervention {
  fn(_value : CausalValue) { Category(value) }
}

///|
/// The intervention that adds a number to the value of a numeric node.
///
/// This is the port of the soft intervention `{'X': lambda x: x + 1}` of the
/// upstream.
pub fn add_number(delta : Double) -> Intervention {
  fn(value : CausalValue) {
    match value {
      Number(x) => Number(x + delta)
      Category(_) =>
        abort(
          "the intervention adds a number to the value of a categorical node",
        )
    }
  }
}

///|
/// The intervention that scales the value of a numeric node.
pub fn scale_number(factor : Double) -> Intervention {
  fn(value : CausalValue) {
    match value {
      Number(x) => Number(x * factor)
      Category(_) =>
        abort("the intervention scales the value of a categorical node")
    }
  }
}

///|
/// The values of a numeric column after the intervention.
pub fn apply_to_numbers(
  intervention : Intervention,
  values : Array[Double],
) -> Array[Double] {
  let out : Array[Double] = []
  for value in values {
    match intervention(Number(value)) {
      Number(result) => out.push(result)
      Category(_) =>
        abort("the intervention turned a numeric node into a categorical one")
    }
  }
  out
}

///|
/// The values of a categorical column after the intervention.
pub fn apply_to_categories(
  intervention : Intervention,
  values : Array[String],
) -> Array[String] {
  let out : Array[String] = []
  for value in values {
    match intervention(Category(value)) {
      Category(result) => out.push(result)
      Number(_) =>
        abort("the intervention turned a categorical node into a numeric one")
    }
  }
  out
}
