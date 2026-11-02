/// Tests for the causal model, the entry point of the package.
///
/// The cases cover the two ways the model is used: the effect is identified
/// first and the estimate is asked for afterwards, and the estimate is asked
/// for straight away.

///|
/// The model of a data set, with the graph derived from the semantic roles of
/// the variables.
fn model_of(dataset : @datasets.Dataset) -> @moonbit_dowhy.CausalModel {
  @moonbit_dowhy.CausalModel::new(
    dataset.frame(),
    dataset.treatments(),
    [dataset.outcome()],
    None,
    dataset.common_causes(),
    dataset.instruments(),
    dataset.effect_modifiers(),
    dataset.frontdoor_variables(),
  )
}

///|
test "the model estimates the effect of a confounded data set" {
  let dataset = confounded()
  let model = model_of(dataset)
  let _ = model.identify_effect("backdoor")
  let estimate = model.estimate_effect(
    "backdoor.linear_regression",
    1.0,
    0.0,
    "ate",
    effect_modifier_names=[],
  )
  assert_true(close_enough(estimate.value, dataset.average_treatment_effect()))
}

///|
test "the model identifies the effect when the estimate is asked for" {
  let dataset = confounded()
  let model = model_of(dataset)
  // No explicit `identify_effect` call: the model identifies the effect with
  // the identifier of the method name.
  let estimate = model.estimate_effect(
    "backdoor.linear_regression",
    1.0,
    0.0,
    "ate",
    effect_modifier_names=[],
  )
  assert_true(close_enough(estimate.value, dataset.average_treatment_effect()))
  let adjustment = model
    .identified_estimand()
    .get_adjustment_set(model.identified_estimand().identifier_method())
  assert_true(adjustment.contains("W0"))
}

///|
test "the model estimates the effect with the generalised linear model" {
  let dataset = binary_outcome()
  let model = model_of(dataset)
  let _ = model.identify_effect("backdoor")
  let estimate = model.estimate_effect(
    "backdoor.generalized_linear_model.binomial",
    1.0,
    0.0,
    "ate",
    effect_modifier_names=[],
  )
  assert_true(close_enough(estimate.value, dataset.average_treatment_effect()))
}
