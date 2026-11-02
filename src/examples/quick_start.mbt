/// A runnable tour of the package.
///
/// Run it with `moon run src/examples` from the repository root.

///|
/// The entry point of the example.
fn main {
  // A confounded data set: `W0 -> v0`, `W0 -> y` and `v0 -> y`.
  let dataset = @datasets.linear_dataset(
    42,
    1000,
    @datasets.LinearConfig::confounded(),
  )

  // The model. The causal graph is derived from the semantic roles of the
  // variables when no explicit graph is given.
  let model = @moonbit_dowhy.CausalModel::new(
    dataset.frame(),
    dataset.treatments(),
    [dataset.outcome()],
    None,
    dataset.common_causes(),
    dataset.instruments(),
    dataset.effect_modifiers(),
    dataset.frontdoor_variables(),
  )

  // Identify the effect with the backdoor criterion.
  let estimand = model.identify_effect("backdoor")
  let adjustment = estimand.get_adjustment_set(estimand.identifier_method())
  println("adjustment set: " + adjustment.join(", "))

  // Estimate the average treatment effect.
  let estimate = model.estimate_effect(
    "backdoor.linear_regression",
    1.0,
    0.0,
    "ate",
    effect_modifier_names=[],
  )
  println("ATE: " + estimate.estimate().to_string())
  println(
    "95% CI: [" +
    estimate.confidence_interval_lower().to_string() +
    ", " +
    estimate.confidence_interval_upper().to_string() +
    "]",
  )

  // Refute the estimate with a placebo treatment: the effect has to collapse
  // towards zero.
  let random = @utils.Random::new(7)
  let refutation = model.refute_estimate(
    "backdoor.linear_regression", estimate, "placebo", 10, random,
  )
  println("placebo effect: " + refutation.new_effect().to_string())

  // A binary outcome needs a link function, so the estimator is a
  // generalised linear model with the binomial family.
  let binary = @datasets.linear_dataset(
    42,
    2000,
    @datasets.LinearConfig::binary_outcome(),
  )
  let binary_model = @moonbit_dowhy.CausalModel::new(
    binary.frame(),
    binary.treatments(),
    [binary.outcome()],
    None,
    binary.common_causes(),
    binary.instruments(),
    binary.effect_modifiers(),
    binary.frontdoor_variables(),
  )
  let binomial = binary_model.estimate_effect(
    "backdoor.generalized_linear_model.binomial",
    1.0,
    0.0,
    "ate",
    effect_modifier_names=[],
  )
  println("binomial ATE: " + binomial.estimate().to_string())
  println("true ATE: " + binary.average_treatment_effect().to_string())
}
