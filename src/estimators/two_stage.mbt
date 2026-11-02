/// The two stage regression estimator.
///
/// This is the port of
/// `dowhy.causal_estimators.two_stage_regression_estimator`: the first stage
/// regresses the mediator on the treatment and on the confounders of the first
/// stage, the second stage regresses the outcome on the mediator and on the
/// confounders of the second stage, and the estimate is the product of the two
/// effects.
///
/// The estimator of the upstream takes the two stage models as arguments, so a
/// caller can replace them; the port always fits the two linear regressions
/// the upstream falls back to.

///|
/// One stage of the two stage regression estimator.
///
/// Every stage has its own encoders, because the treatment of the first stage
/// is the column the second stage regresses on.
struct TwoStageModel {
  /// The treatment column of the stage.
  treatment_name : String
  /// The outcome column of the stage.
  outcome_name : String
  /// The adjustment variables of the stage.
  adjustment_names : Array[String]
  /// The encoders of the discrete columns of the stage.
  encoders : @api.Encoders
  /// The fitted model of the stage.
  mut model : @utils.OlsFit
  /// The columns of the design matrix of the stage, in order.
  mut features : Array[String]
}

///|
/// A stage of the two stage regression estimator.
fn TwoStageModel::new(
  treatment_name : String,
  outcome_name : String,
  adjustment_names : Array[String],
) -> TwoStageModel {
  {
    treatment_name,
    outcome_name,
    adjustment_names,
    encoders: @api.Encoders::new(true),
    model: @utils.OlsFit::empty(),
    features: [],
  }
}

///|
/// The message of the error the upstream raises when the estimand holds more
/// than one treatment variable.
const TWO_STAGE_TREATMENT_ERROR : String = "The estimator cannot handle more than one treatment variable"

///|
/// The message of the error the upstream raises when the estimand holds more
/// than one outcome variable.
const TWO_STAGE_OUTCOME_ERROR : String = "The estimator cannot handle more than one outcome variable"

///|
/// The message of the error the upstream raises when the estimand of the
/// mediation holds no mediator variable.
const TWO_STAGE_NO_MEDIATOR_ERROR : String = "No mediator variable present. Two stage regression is not applicable"

///|
/// The message of the error the upstream raises when the estimand of the
/// mediation holds more than one mediator variable.
const TWO_STAGE_MEDIATOR_ERROR : String = "Only singleton mediator variables are supported for estimation using TwoStageRegression."

///|
/// The message of the error the upstream raises when the estimand holds no
/// frontdoor variable.
const TWO_STAGE_NO_FRONTDOOR_ERROR : String = "No front-door variable present. Two stage regression is not applicable"

///|
/// The message of the error the upstream raises when the estimand holds more
/// than one frontdoor variable.
const TWO_STAGE_FRONTDOOR_ERROR : String = "Only singleton frontdoor variables are supported for estimation using TwoStageRegression."

///|
/// Fit the two stages of the two stage regression estimator.
///
/// The first stage regresses the mediator on the treatment, the second stage
/// regresses the outcome on the mediator. The confounders of the two stages
/// are the ones the identification found.
fn CausalEstimator::fit_two_stage_regression(
  self : CausalEstimator,
  data : @api.DataFrame,
) -> Unit {
  let error = self.two_stage_error()
  if error != "" {
    abort(error)
  }
  let mediator = self.mediator_of_the_estimand()
  let treatment = self.target_estimand.treatment()
  let outcome = self.target_estimand.outcome()
  let first = TwoStageModel::new(
    treatment[0],
    mediator,
    default_adjustment_variables(
      self.target_estimand.get_mediation_first_stage_confounders(),
    ),
  )
  let second = TwoStageModel::new(
    mediator,
    outcome[0],
    default_adjustment_variables(
      self.target_estimand.get_mediation_second_stage_confounders(),
    ),
  )
  let (first_design, first_features) = build_design_matrix(
    first.encoders,
    data,
    first.treatment_name,
    first.adjustment_names,
    self.effect_modifier_names,
  )
  first.model = @utils.ols_fit(first_design, data.numeric(first.outcome_name))
  first.features = first_features
  let (second_design, second_features) = build_design_matrix(
    second.encoders,
    data,
    second.treatment_name,
    second.adjustment_names,
    self.effect_modifier_names,
  )
  second.model = @utils.ols_fit(
    second_design,
    data.numeric(second.outcome_name),
  )
  second.features = second_features
  self.first_stage = Some(first)
  self.second_stage = Some(second)
}

///|
/// The effect of the two stage regression estimator.
///
/// The estimate is the product of the two effects: the effect of the treatment
/// on the mediator and the effect of the mediator on the outcome. The upstream
/// reports no confidence interval for it, so the port reports none either.
fn CausalEstimator::estimate_two_stage_regression(
  self : CausalEstimator,
  data : @api.DataFrame,
  _target_units : String,
) -> @model.CausalEstimate {
  let first = match self.first_stage {
    Some(stage) => stage
    None => abort("The two stage regression estimator was not fitted")
  }
  let second = match self.second_stage {
    Some(stage) => stage
    None => abort("The two stage regression estimator was not fitted")
  }
  let first_effect = stage_effect(
    first,
    data,
    self.treatment_value,
    self.control_value,
    self.effect_modifier_names,
  )
  let second_effect = stage_effect(
    second,
    data,
    self.treatment_value,
    self.control_value,
    self.effect_modifier_names,
  )
  let value = first_effect * second_effect
  @model.CausalEstimate::new(
    value,
    self.treatment_name,
    self.outcome_name,
    self.target_estimand.identifier_method(),
    self.control_value,
    self.treatment_value,
  )
}

///|
/// The columns of the design matrix of the two stages of the two stage
/// regression estimator.
///
/// The first element holds the columns of the first stage, the one that
/// regresses the mediator on the treatment, and the second one the columns of
/// the second stage, the one that regresses the outcome on the mediator.
pub fn CausalEstimator::two_stage_features(
  self : CausalEstimator,
) -> (Array[String], Array[String]) {
  let first = match self.first_stage {
    Some(stage) => stage.features.copy()
    None => []
  }
  let second = match self.second_stage {
    Some(stage) => stage.features.copy()
    None => []
  }
  (first, second)
}

///|
/// The error the two stage regression estimator reports for the estimand of
/// the estimator, or an empty string when it can estimate the effect.
///
/// The upstream raises a `ValueError` when the estimand holds no mediator
/// variable or more than one, and it raises an `Exception` when the estimand
/// holds more than one treatment variable or more than one outcome variable.
/// MoonBit cannot catch an error, so the port aborts with the message of the
/// upstream; this function reports the message of the error the upstream
/// raises, so that a caller can check for it before it fits the estimator.
pub fn CausalEstimator::two_stage_error(self : CausalEstimator) -> String {
  if self.target_estimand.treatment().length() != 1 {
    return TWO_STAGE_TREATMENT_ERROR
  }
  if self.target_estimand.outcome().length() != 1 {
    return TWO_STAGE_OUTCOME_ERROR
  }
  if self.target_estimand.identifier_method() == "mediation" {
    let mediators = self.target_estimand.get_mediator_variables()
    if mediators.length() == 0 {
      return TWO_STAGE_NO_MEDIATOR_ERROR
    }
    if mediators.length() > 1 {
      return TWO_STAGE_MEDIATOR_ERROR
    }
    return ""
  }
  let frontdoor = self.target_estimand.get_frontdoor_variables()
  if frontdoor.length() == 0 {
    return TWO_STAGE_NO_FRONTDOOR_ERROR
  }
  if frontdoor.length() > 1 {
    return TWO_STAGE_FRONTDOOR_ERROR
  }
  ""
}

///|
/// The mediator the two stage regression estimates through.
///
/// The frontdoor variable is the mediator of the frontdoor estimand, the
/// mediator of the estimand is the mediator of the mediation estimand.
fn CausalEstimator::mediator_of_the_estimand(self : CausalEstimator) -> String {
  let identifier = self.target_estimand.identifier_method()
  if identifier == "mediation" {
    let mediators = self.target_estimand.get_mediator_variables()
    if mediators.length() == 0 {
      abort(TWO_STAGE_NO_MEDIATOR_ERROR)
    }
    if mediators.length() > 1 {
      abort(TWO_STAGE_MEDIATOR_ERROR)
    }
    return mediators[0]
  }
  let frontdoor = self.target_estimand.get_frontdoor_variables()
  if frontdoor.length() == 0 {
    abort(TWO_STAGE_NO_FRONTDOOR_ERROR)
  }
  if frontdoor.length() > 1 {
    abort(TWO_STAGE_FRONTDOOR_ERROR)
  }
  frontdoor[0]
}

///|
/// The effect of one stage of the two stage regression estimator.
///
/// The effect is the difference of the two means the model of the stage
/// predicts, the way the upstream computes it.
fn stage_effect(
  stage : TwoStageModel,
  data : @api.DataFrame,
  treatment_value : Double,
  control_value : Double,
  effect_modifier_names : Array[String],
) -> Double {
  let treated = stage_outcomes(
    stage, data, treatment_value, effect_modifier_names,
  )
  let control = stage_outcomes(
    stage, data, control_value, effect_modifier_names,
  )
  @utils.mean(treated) - @utils.mean(control)
}

///|
/// The outcomes the model of the stage predicts when its treatment is set to
/// the given value.
fn stage_outcomes(
  stage : TwoStageModel,
  data : @api.DataFrame,
  value : Double,
  effect_modifier_names : Array[String],
) -> Array[Double] {
  let modified = with_column_value(data, stage.treatment_name, value)
  let (design, _) = build_design_matrix(
    stage.encoders,
    modified,
    stage.treatment_name,
    stage.adjustment_names,
    effect_modifier_names,
  )
  design.matvec(stage.model.beta)
}

///|
/// The default adjustment set of a stage of a mediation.
///
/// The registry holds every set the search found and the default set of them
/// under the plain `backdoor` name.
fn default_adjustment_variables(
  confounders : Map[String, Array[String]],
) -> Array[String] {
  match confounders.get("backdoor") {
    Some(variables) => variables
    None => []
  }
}
