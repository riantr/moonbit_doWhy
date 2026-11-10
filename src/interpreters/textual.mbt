/// The interpreters of the model.
///
/// This is the port of `dowhy.interpreters`, the module of the upstream that
/// reads an estimate and writes what it means.

///|
/// The text of the interpretation of an estimate.
///
/// This is the port of
/// `dowhy.interpreters.textual_effect_interpreter.TextualEffectInterpreter`.
///
/// The upstream writes the sentence and returns it, and the port returns it.
/// The upstream writes the name of the outcome as the list it holds it in, so
/// its text holds `[['y']]`, and the port holds one name, so its text holds
/// `[y]`.
///
/// The text is `None` when the treatment is a category, which is the case the
/// upstream refuses with a `NotImplementedError`.
pub fn textual_effect_interpretation(
  estimate : @model.CausalEstimate,
  data : @api.DataFrame,
) -> String? {
  if !is_numeric_column(data, estimate.treatment_name()) {
    return None
  }
  Some(
    "Increasing the treatment variable(s) [" +
    estimate.treatment_name() +
    "] from " +
    estimate.control_value().to_string() +
    " to " +
    estimate.treatment_value().to_string() +
    " causes an increase of " +
    estimate.estimate().to_string() +
    " in the expected value of the outcome [" +
    estimate.outcome_name() +
    "], over the data distribution/population represented by the dataset.",
  )
}

///|
/// Whether the column of the data holds numbers.
///
/// The upstream reads the kind of a column from its type, so a column of
/// categories is not a number.
fn is_numeric_column(data : @api.DataFrame, name : String) -> Bool {
  match data.column(name) {
    Some(@api.Column::Numeric(_)) => true
    _ => false
  }
}
