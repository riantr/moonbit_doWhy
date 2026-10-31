/// The causal model: the entry point of the library.
///
/// This is the port of `dowhy.causal_model.CausalModel`. It ties the data,
/// the causal graph and the estimators together:
///
/// ```moonbit
/// let model = CausalModel::new(data, ["treatment"], ["outcome"], None, ["confounder"], [], [], [])
/// let estimand = model.identify_effect("backdoor")
/// let estimate = model.estimate_effect("backdoor.linear_regression", 1.0, 0.0, "ate")
/// ```

///|
/// A causal model.
pub struct CausalModel {
  /// The data the analysis runs on.
  data : @api.DataFrame
  /// The treatment variables.
  treatment : Array[String]
  /// The outcome variables.
  outcome : Array[String]
  /// The causal graph.
  graph : @graph.DirectedGraph
  /// The observed nodes of the graph.
  observed_nodes : Array[String]
  /// The estimand the identification produced.
  mut estimand : @identifiers.IdentifiedEstimand
}

///|
/// Build a causal model.
///
/// When `graph` is `None` the graph is built from the semantic roles of the
/// variables.
pub fn CausalModel::new(
  data : @api.DataFrame,
  treatment : Array[String],
  outcome : Array[String],
  graph : @graph.DirectedGraph?,
  common_causes : Array[String],
  instruments : Array[String],
  effect_modifiers : Array[String],
  mediators : Array[String],
) -> CausalModel {
  let built = match graph {
    Some(g) => g.copy()
    None =>
      @graph.build_graph(
        treatment, outcome, common_causes, instruments, effect_modifiers, mediators,
      )
  }
  let observed : Array[String] = []
  for name in data.column_names() {
    observed.push(name)
  }
  let estimand = @identifiers.IdentifiedEstimand::new(treatment, outcome)
  {
    data,
    treatment,
    outcome,
    graph: built,
    observed_nodes: observed,
    estimand,
  }
}

///|
/// The data of the model.
pub fn CausalModel::data(self : CausalModel) -> @api.DataFrame {
  self.data
}

///|
/// The causal graph of the model.
pub fn CausalModel::causal_graph(self : CausalModel) -> @graph.DirectedGraph {
  self.graph
}

///|
/// The estimand the identification produced.
pub fn CausalModel::identified_estimand(
  self : CausalModel,
) -> @identifiers.IdentifiedEstimand {
  self.estimand
}

///|
/// Identify the causal effect.
///
/// `method_name` selects the identifier: `"backdoor"` (the default),
/// `"frontdoor"`, `"mediation"`, `"iv"` or `"general_adjustment"`.
pub fn CausalModel::identify_effect(
  self : CausalModel,
  method_name : String,
) -> @identifiers.IdentifiedEstimand {
  let estimand = @identifiers.identify_effect_auto(
    self.graph,
    self.treatment,
    self.outcome,
    self.observed_nodes,
    "nonparametric-ate",
    method_name,
  )
  self.estimand = estimand
  estimand
}

///|
/// Build the estimator the method name refers to.
fn CausalModel::build_estimator(
  self : CausalModel,
  method_name : String,
) -> @estimators.CausalEstimator {
  let estimand = self.estimand
  match method_name {
    "backdoor.linear_regression" =>
      @estimators.CausalEstimator::linear_regression(estimand)
    "backdoor.propensity_score_weighting" =>
      @estimators.CausalEstimator::propensity_score_weighting(
        estimand,
        0.05,
        0.95,
        @estimators.WeightingScheme::ips_weight(),
      )
    "backdoor.propensity_score_matching" =>
      @estimators.CausalEstimator::propensity_score_matching(estimand)
    "backdoor.propensity_score_stratification" =>
      @estimators.CausalEstimator::propensity_score_stratification(
        estimand, 5, 10,
      )
    "backdoor.doubly_robust" =>
      @estimators.CausalEstimator::doubly_robust(estimand, 0.01, 0.99)
    "iv.instrumental_variable" =>
      @estimators.CausalEstimator::instrumental_variable(estimand, "")
    "frontdoor.two_stage_regression" =>
      @estimators.CausalEstimator::two_stage_regression(estimand)
    "backdoor.generalized_linear_model" =>
      @estimators.CausalEstimator::generalized_linear_model(
        estimand,
        @utils.GlmFamily::gaussian(),
      )
    "backdoor.generalized_linear_model.gaussian" =>
      @estimators.CausalEstimator::generalized_linear_model(
        estimand,
        @utils.GlmFamily::gaussian(),
      )
    "backdoor.generalized_linear_model.binomial" =>
      @estimators.CausalEstimator::generalized_linear_model(
        estimand,
        @utils.GlmFamily::binomial(),
      )
    "backdoor.generalized_linear_model.poisson" =>
      @estimators.CausalEstimator::generalized_linear_model(
        estimand,
        @utils.GlmFamily::poisson(),
      )
    _ =>
      abort(
        "The method " + method_name + " is not supported by this port of DoWhy",
      )
  }
}

///|
/// Estimate the causal effect.
///
/// `method_name` names the estimator, e.g. `"backdoor.linear_regression"`.
/// The first segment of the name selects the identifier, exactly like
/// `dowhy` does.
///
/// When the effect has not been identified yet, it is identified with the
/// identifier of the method name, so that a model that is used for a single
/// estimate does not need an explicit `identify_effect` call.
pub fn CausalModel::estimate_effect(
  self : CausalModel,
  method_name : String,
  treatment_value : Double,
  control_value : Double,
  target_units : String,
  effect_modifier_names : Array[String],
) -> @model.CausalEstimate {
  // The identifier of the estimator is the first segment of its name.
  let identifier = first_segment(method_name)
  if !self.estimand.has_estimand(identifier) {
    let _ = self.identify_effect(identifier)
  }
  self.estimand.set_identifier_method(identifier)
  let estimator = self.build_estimator(method_name)
  estimator.fit(self.data, effect_modifier_names)
  estimator.estimate_effect(
    self.data,
    treatment_value,
    control_value,
    target_units,
  )
}

///|
/// Refute the estimate.
///
/// `refuter_name` is one of `"bootstrap"`, `"placebo"`, `"subset"`,
/// `"dummy_outcome"`, `"random_common_cause"` or
/// `"add_unobserved_common_cause"`.
pub fn CausalModel::refute_estimate(
  self : CausalModel,
  method_name : String,
  estimate : @model.CausalEstimate,
  refuter_name : String,
  num_simulations : Int32,
  random : @utils.Random,
) -> @refuters.CausalRefutation {
  let estimator = self.build_estimator(method_name)
  estimator.fit(self.data, [])
  let estimand = self.estimand
  match refuter_name {
    "bootstrap" =>
      @refuters.refute_bootstrap(
        estimator,
        estimand,
        self.data,
        num_simulations,
        1.0,
        estimate.control_value,
        estimate.treatment_value,
        "ate",
        random,
      )
    "placebo" =>
      @refuters.refute_placebo_treatment(
        estimator,
        estimand,
        self.data,
        self.treatment[0],
        num_simulations,
        estimate.treatment_value,
        estimate.control_value,
        "ate",
        random,
      )
    "subset" =>
      @refuters.refute_data_subset(
        estimator,
        estimand,
        self.data,
        0.8,
        num_simulations,
        estimate.treatment_value,
        estimate.control_value,
        "ate",
        random,
      )
    "dummy_outcome" =>
      @refuters.refute_dummy_outcome(
        estimator,
        estimand,
        self.data,
        self.outcome[0],
        num_simulations,
        estimate.treatment_value,
        estimate.control_value,
        "ate",
        random,
      )
    "random_common_cause" =>
      @refuters.refute_random_common_cause(
        estimator,
        estimand,
        self.data,
        num_simulations,
        estimate.treatment_value,
        estimate.control_value,
        "ate",
        random,
      )
    "add_unobserved_common_cause" =>
      @refuters.refute_add_unobserved_common_cause(
        estimator,
        estimand,
        self.data,
        self.treatment[0],
        self.outcome[0],
        0.05,
        num_simulations,
        estimate.treatment_value,
        estimate.control_value,
        "ate",
        random,
      )
    _ => abort("The refuter " + refuter_name + " is not supported")
  }
}

///|
/// The first segment of a dotted name.
fn first_segment(name : String) -> String {
  let parts = name.split(".")
  match parts.next() {
    Some(first) => first.to_owned()
    None => name
  }
}
