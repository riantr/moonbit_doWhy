///|
/// The estimand that the identification step produced.
///
/// This is the port of `dowhy.causal_identifier.identified_estimand`.
///
/// An identified estimand carries the treatment and the outcome, the
/// adjustment variables that the chosen identifier selected, the instruments,
/// the frontdoor variables and the mediators. The estimators consume it and
/// the refuters replace it, so it has to be cheap to copy.
pub struct IdentifiedEstimand {
  treatment_variable : Array[String]
  outcome_variable : Array[String]
  mut estimand_type : String
  /// The registry of estimands, keyed by identifier (`"backdoor"`, `"iv"`,
  /// `"frontdoor"`, `"general_adjustment"`, ...).
  estimands : Map[String, Array[String]]
  /// The adjustment variables of every backdoor identifier.
  backdoor_variables : Map[String, Array[String]]
  /// The adjustment variables of every general adjustment identifier.
  general_adjustment_variables : Map[String, Array[String]]
  mut instrumental_variables : Array[String]
  mut frontdoor_variables : Array[String]
  mut mediator_variables : Array[String]
  mut mediation_first_stage_confounders : Map[String, Array[String]]
  mut mediation_second_stage_confounders : Map[String, Array[String]]
  mut default_backdoor_id : String
  mut default_adjustment_set_id : String
  mut identifier_method : String
  mut no_directed_path : Bool
}

///|
/// A fresh estimand for a treatment and an outcome.
pub fn IdentifiedEstimand::new(
  treatment_variable : Array[String],
  outcome_variable : Array[String],
) -> IdentifiedEstimand {
  {
    treatment_variable,
    outcome_variable,
    estimand_type: "nonparametric-ate",
    estimands: Map([]),
    backdoor_variables: Map([]),
    general_adjustment_variables: Map([]),
    instrumental_variables: [],
    frontdoor_variables: [],
    mediator_variables: [],
    mediation_first_stage_confounders: Map([]),
    mediation_second_stage_confounders: Map([]),
    default_backdoor_id: "",
    default_adjustment_set_id: "",
    identifier_method: "",
    no_directed_path: false,
  }
}

///|
/// The treatment variables.
pub fn IdentifiedEstimand::treatment(
  self : IdentifiedEstimand,
) -> Array[String] {
  self.treatment_variable.copy()
}

///|
/// The outcome variables.
pub fn IdentifiedEstimand::outcome(self : IdentifiedEstimand) -> Array[String] {
  self.outcome_variable.copy()
}

///|
/// The estimand type, e.g. `"nonparametric-ate"`.
pub fn IdentifiedEstimand::estimand_type(self : IdentifiedEstimand) -> String {
  self.estimand_type
}

///|
/// The name of the identifier that produced the estimand.
pub fn IdentifiedEstimand::identifier_method(
  self : IdentifiedEstimand,
) -> String {
  self.identifier_method
}

///|
/// Set the name of the identifier that produced the estimand.
pub fn IdentifiedEstimand::set_identifier_method(
  self : IdentifiedEstimand,
  name : String,
) -> Unit {
  self.identifier_method = name
}

///|
/// Whether the causal graph has no directed path from treatment to outcome.
pub fn IdentifiedEstimand::has_no_directed_path(
  self : IdentifiedEstimand,
) -> Bool {
  self.no_directed_path
}

///|
/// The adjustment variables of the current identifier.
///
/// Mirrors `IdentifiedEstimand.get_adjustment_set`: general adjustment sets
/// are used when the identifier is `"general_adjustment"`, otherwise the
/// backdoor variables are.
pub fn IdentifiedEstimand::get_adjustment_set(
  self : IdentifiedEstimand,
  key : String,
) -> Array[String] {
  if self.identifier_method == "general_adjustment" {
    match self.general_adjustment_variables.get(key) {
      Some(vars) => vars
      None => []
    }
  } else {
    match self.backdoor_variables.get(key) {
      Some(vars) => vars
      None => []
    }
  }
}

///|
/// The backdoor variables of the current identifier.
pub fn IdentifiedEstimand::get_backdoor_variables(
  self : IdentifiedEstimand,
  key : String,
) -> Array[String] {
  match self.backdoor_variables.get(key) {
    Some(vars) => vars
    None => []
  }
}

///|
/// Replace the adjustment variables of the current identifier.
pub fn IdentifiedEstimand::set_adjustment_set(
  self : IdentifiedEstimand,
  variables : Array[String],
  key : String,
) -> Unit {
  if self.identifier_method == "general_adjustment" {
    self.general_adjustment_variables.set(key, variables)
  } else {
    self.backdoor_variables.set(key, variables)
  }
}

///|
/// The instruments of the estimand.
pub fn IdentifiedEstimand::get_instrumental_variables(
  self : IdentifiedEstimand,
) -> Array[String] {
  self.instrumental_variables.copy()
}

///|
/// The frontdoor variables of the estimand.
pub fn IdentifiedEstimand::get_frontdoor_variables(
  self : IdentifiedEstimand,
) -> Array[String] {
  self.frontdoor_variables.copy()
}

///|
/// The mediator variables of the estimand.
pub fn IdentifiedEstimand::get_mediator_variables(
  self : IdentifiedEstimand,
) -> Array[String] {
  self.mediator_variables.copy()
}

///|
/// Set the mediator variables of the estimand.
pub fn IdentifiedEstimand::set_mediator_variables(
  self : IdentifiedEstimand,
  variables : Array[String],
) -> Unit {
  self.mediator_variables = variables
}

///|
/// The confounders of the first stage of a mediation.
///
/// The registry holds every backdoor adjustment set of the treatment and the
/// mediator, keyed by its name, and the default set of them under the plain
/// `backdoor` name.
pub fn IdentifiedEstimand::get_mediation_first_stage_confounders(
  self : IdentifiedEstimand,
) -> Map[String, Array[String]] {
  self.mediation_first_stage_confounders.copy()
}

///|
/// Set the confounders of the first stage of a mediation.
pub fn IdentifiedEstimand::set_mediation_first_stage_confounders(
  self : IdentifiedEstimand,
  confounders : Map[String, Array[String]],
) -> Unit {
  self.mediation_first_stage_confounders = confounders
}

///|
/// The confounders of the second stage of a mediation.
///
/// The registry holds every backdoor adjustment set of the mediator and the
/// outcome, keyed by its name, and the default set of them under the plain
/// `backdoor` name.
pub fn IdentifiedEstimand::get_mediation_second_stage_confounders(
  self : IdentifiedEstimand,
) -> Map[String, Array[String]] {
  self.mediation_second_stage_confounders.copy()
}

///|
/// Set the confounders of the second stage of a mediation.
pub fn IdentifiedEstimand::set_mediation_second_stage_confounders(
  self : IdentifiedEstimand,
  confounders : Map[String, Array[String]],
) -> Unit {
  self.mediation_second_stage_confounders = confounders
}

///|
/// The names of the estimands in the registry.
pub fn IdentifiedEstimand::estimand_keys(
  self : IdentifiedEstimand,
) -> Array[String] {
  let keys : Array[String] = []
  for key in self.estimands.keys() {
    keys.push(key)
  }
  keys
}

///|
/// The assumptions of an estimand in the registry.
///
/// The registry stores the assumption names of every estimand; the strings
/// match the ones `dowhy` reports.
pub fn IdentifiedEstimand::estimand_assumptions(
  self : IdentifiedEstimand,
  key : String,
) -> Array[String] {
  match self.estimands.get(key) {
    Some(assumptions) => assumptions
    None => []
  }
}

///|
/// Whether the registry contains the given estimand.
pub fn IdentifiedEstimand::has_estimand(
  self : IdentifiedEstimand,
  key : String,
) -> Bool {
  self.estimands.contains(key)
}

///|
/// Register an estimand with its assumptions.
pub fn IdentifiedEstimand::set_estimand(
  self : IdentifiedEstimand,
  key : String,
  assumptions : Array[String],
) -> Unit {
  self.estimands.set(key, assumptions)
}

///|
/// The identifier of the default backdoor set, e.g. `"backdoor1"`.
pub fn IdentifiedEstimand::default_backdoor_id(
  self : IdentifiedEstimand,
) -> String {
  self.default_backdoor_id
}

///|
/// Set the identifier of the default backdoor set.
pub fn IdentifiedEstimand::set_default_backdoor_id(
  self : IdentifiedEstimand,
  id : String,
) -> Unit {
  self.default_backdoor_id = id
}

///|
/// Set the identifier of the default general adjustment set.
pub fn IdentifiedEstimand::set_default_adjustment_set_id(
  self : IdentifiedEstimand,
  id : String,
) -> Unit {
  self.default_adjustment_set_id = id
}

///|
/// Set whether the causal graph has no directed path from treatment to
/// outcome.
pub fn IdentifiedEstimand::set_no_directed_path(
  self : IdentifiedEstimand,
  flag : Bool,
) -> Unit {
  self.no_directed_path = flag
}

///|
/// A copy of the estimand.
///
/// The variable lists and the registries are copied as well, so the copy and
/// the original share no state. This matters for the refuters: they replace
/// the adjustment set of a copy, and the estimator they were handed has to
/// keep the adjustment set it was fitted with.
pub fn IdentifiedEstimand::copy(
  self : IdentifiedEstimand,
) -> IdentifiedEstimand {
  {
    treatment_variable: self.treatment_variable.copy(),
    outcome_variable: self.outcome_variable.copy(),
    estimand_type: self.estimand_type,
    estimands: copy_variable_map(self.estimands),
    backdoor_variables: copy_variable_map(self.backdoor_variables),
    general_adjustment_variables: copy_variable_map(
      self.general_adjustment_variables,
    ),
    instrumental_variables: self.instrumental_variables.copy(),
    frontdoor_variables: self.frontdoor_variables.copy(),
    mediator_variables: self.mediator_variables.copy(),
    mediation_first_stage_confounders: copy_variable_map(
      self.mediation_first_stage_confounders,
    ),
    mediation_second_stage_confounders: copy_variable_map(
      self.mediation_second_stage_confounders,
    ),
    default_backdoor_id: self.default_backdoor_id,
    default_adjustment_set_id: self.default_adjustment_set_id,
    identifier_method: self.identifier_method,
    no_directed_path: self.no_directed_path,
  }
}

///|
/// A copy of a registry of variable lists.
fn copy_variable_map(
  registry : Map[String, Array[String]],
) -> Map[String, Array[String]] {
  let copy : Map[String, Array[String]] = Map([])
  for key in registry.keys() {
    match registry.get(key) {
      Some(variables) => copy.set(key, variables.copy())
      None => ()
    }
  }
  copy
}

///|
/// A copy of the estimand with the "no directed path" flag set.
///
/// The identification returns such an estimand when the causal graph has no
/// directed path from the treatment to the outcome.
pub fn IdentifiedEstimand::with_no_directed_path(
  self : IdentifiedEstimand,
  flag : Bool,
) -> IdentifiedEstimand {
  let copy = self.copy()
  copy.set_no_directed_path(flag)
  copy
}

///|
/// A copy of the estimand with a different adjustment set.
///
/// The random common cause refuter uses this to add the noise variable to the
/// adjustment set.
pub fn IdentifiedEstimand::with_adjustment_variables(
  self : IdentifiedEstimand,
  variables : Array[String],
) -> IdentifiedEstimand {
  let copy = self.copy()
  copy.set_adjustment_set(variables, copy.identifier_method)
  copy
}
