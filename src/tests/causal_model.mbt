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
/// The frame of the fixture of the interpretation.
///
/// This is the frame of the script `_verify/interpreter_reference.py`: sixty
/// rows of a treatment, of a common cause and of an outcome.
fn interpretation_frame() -> @api.DataFrame {
  let v : Array[Double] = []
  let w : Array[Double] = []
  let y : Array[Double] = []
  for i in 0..<60 {
    let w_value = (i % 7).to_double() - 3.0
    let v_value = (i % 2).to_double()
    let noise = ((i % 5).to_double() - 2.0) * 0.25
    v.push(v_value)
    w.push(w_value)
    y.push(2.0 * v_value + 0.5 * w_value + noise)
  }
  @api.DataFrame::from_numeric(
    ["v0", "W0", "y"],
    Map([("v0", v), ("W0", w), ("y", y)]),
  )
}

///|
/// The model of the frame of the fixture of the interpretation.
fn interpretation_model() -> @moonbit_dowhy.CausalModel {
  @moonbit_dowhy.CausalModel::new(
    interpretation_frame(),
    ["v0"],
    ["y"],
    None,
    ["W0"],
    [],
    [],
    [],
  )
}

///|
test "the view of the model is the document of the graph" {
  let model = interpretation_model()
  let document = model.view_model()
  assert_true(document.has_prefix("digraph {"))
  assert_true(document.contains("\"v0\""))
  assert_true(document.contains("\"y\""))
}

///|
test "the interpretation of the model is the summary and the document of the graph" {
  let model = interpretation_model()
  match model.interpret(None) {
    Some(text) => {
      assert_true(text.has_prefix("Model to find the causal effect"))
      assert_true(text.contains("digraph {"))
    }
    None => assert_true(false)
  }
}

///|
test "the interpretation of the estimate of the model is the sentence of the upstream" {
  let model = interpretation_model()
  let estimate = model.estimate_effect(
    "backdoor.linear_regression",
    1.0,
    0.0,
    "ate",
    effect_modifier_names=[],
  )
  match model.interpret(Some(estimate)) {
    Some(text) =>
      assert_true(
        text.has_prefix(
          "Increasing the treatment variable(s) [v0] from 0 to 1 causes an increase of 1.9999297752808973 in the expected value of the outcome [y], over the data distribution/population represented by the dataset.",
        ),
      )
    None => assert_true(false)
  }
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
