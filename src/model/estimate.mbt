///|
/// The result of a causal estimation.
///
/// This is the port of `dowhy.causal_estimator.CausalEstimate`.
pub struct CausalEstimate {
  /// The point estimate of the treatment effect.
  value : Double
  /// The treatment the estimate refers to.
  treatment_name : String
  /// The outcome the estimate refers to.
  outcome_name : String
  /// The estimand the estimate was computed for.
  target_estimand : String
  /// The symbolic description of the realised estimand.
  realized_estimand_expr : String
  /// The value of the treatment in the control arm.
  control_value : Double
  /// The value of the treatment in the treated arm.
  treatment_value : Double
  /// The propensity scores the estimator computed, when it has any.
  mut propensity_scores : Array[Double]
  /// The lower bound of the confidence interval.
  mut ci_lower : Double
  /// The upper bound of the confidence interval.
  mut ci_upper : Double
  /// The standard error of the estimate.
  mut standard_error : Double
  /// The p-value of the significance test.
  mut p_value : Double
  /// The conditional estimates, keyed by the effect modifier values.
  conditional_estimates : Array[(String, Double)]
  /// Extra parameters of the estimate.
  params : Map[String, String]
}

///|
/// An estimate without any interval information.
pub fn CausalEstimate::new(
  value : Double,
  treatment_name : String,
  outcome_name : String,
  target_estimand : String,
  control_value : Double,
  treatment_value : Double,
) -> CausalEstimate {
  {
    value,
    treatment_name,
    outcome_name,
    target_estimand,
    realized_estimand_expr: "",
    control_value,
    treatment_value,
    propensity_scores: [],
    ci_lower: 0.0,
    ci_upper: 0.0,
    standard_error: 0.0,
    p_value: 0.0,
    conditional_estimates: [],
    params: Map([]),
  }
}

///|
/// The point estimate.
pub fn CausalEstimate::estimate(self : CausalEstimate) -> Double {
  self.value
}

///|
/// The lower bound of the confidence interval.
pub fn CausalEstimate::confidence_interval_lower(
  self : CausalEstimate,
) -> Double {
  self.ci_lower
}

///|
/// The upper bound of the confidence interval.
pub fn CausalEstimate::confidence_interval_upper(
  self : CausalEstimate,
) -> Double {
  self.ci_upper
}

///|
/// The standard error of the estimate.
pub fn CausalEstimate::standard_error(self : CausalEstimate) -> Double {
  self.standard_error
}

///|
/// The p-value of the significance test.
pub fn CausalEstimate::p_value(self : CausalEstimate) -> Double {
  self.p_value
}

///|
/// The propensity scores the estimator computed.
pub fn CausalEstimate::propensity_scores(
  self : CausalEstimate,
) -> Array[Double] {
  self.propensity_scores.copy()
}

///|
/// The estimand the estimate was computed for.
pub fn CausalEstimate::target_estimand(self : CausalEstimate) -> String {
  self.target_estimand
}

///|
/// Set the confidence interval of the estimate.
pub fn CausalEstimate::set_confidence_interval(
  self : CausalEstimate,
  lower : Double,
  upper : Double,
) -> Unit {
  self.ci_lower = lower
  self.ci_upper = upper
}

///|
/// Set the standard error of the estimate.
pub fn CausalEstimate::set_standard_error(
  self : CausalEstimate,
  se : Double,
) -> Unit {
  self.standard_error = se
}

///|
/// Set the p-value of the estimate.
pub fn CausalEstimate::set_p_value(self : CausalEstimate, p : Double) -> Unit {
  self.p_value = p
}

///|
/// Attach the propensity scores to the estimate.
pub fn CausalEstimate::set_propensity_scores(
  self : CausalEstimate,
  scores : Array[Double],
) -> Unit {
  self.propensity_scores = scores
}

///|
/// Attach a conditional estimate.
pub fn CausalEstimate::add_conditional_estimate(
  self : CausalEstimate,
  key : String,
  value : Double,
) -> Unit {
  self.conditional_estimates.push((key, value))
}

///|
/// Attach a parameter to the estimate.
pub fn CausalEstimate::add_param(
  self : CausalEstimate,
  key : String,
  value : String,
) -> Unit {
  self.params.set(key, value)
}

///|
/// A human readable summary of the estimate.
pub fn CausalEstimate::to_string(self : CausalEstimate) -> String {
  "Estimate of the treatment effect: " +
  self.value.to_string() +
  " (control value " +
  self.control_value.to_string() +
  ", treatment value " +
  self.treatment_value.to_string() +
  ")"
}
