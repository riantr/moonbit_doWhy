///|
/// The E-value of an estimate and of the limit of its interval.
///
/// This is the port of `dowhy.causal_refuters.evalue_sensitivity_analyzer`, the
/// analyzer of the E-value of Ding and VanderWeele. The E-value is the minimum
/// strength of association, on the risk ratio scale, that an unmeasured
/// confounder would need with both the treatment and the outcome to explain
/// away the observed association.
///
/// The estimate and the limits of its interval are converted to the risk ratio
/// scale before the E-value is computed, and the E-value of a risk ratio `x` is
///
/// * `x + sqrt(x * (x - 1))` when `x` is larger than one,
/// * the same number of the reciprocal of `x` when `x` is smaller than one.
///
/// The E-value of the limit of the interval that is closer to the null is the
/// one that is reported, the way the upstream reports it.

///|
/// The E-value of an estimate and of its confidence limits.
///
/// This is the port of the dictionary the upstream returns from
/// `EValueSensitivityAnalyzer._evalue_RR`. The E-value of the limit of the
/// interval that is closer to the null is the one that is reported, so the other
/// one is absent.
pub struct EValueStats {
  /// The estimate, converted to the risk ratio scale.
  converted_estimate : Double
  /// The lower limit of the interval, converted to the risk ratio scale.
  converted_lower_ci : Double?
  /// The upper limit of the interval, converted to the risk ratio scale.
  converted_upper_ci : Double?
  /// The E-value of the estimate.
  evalue_estimate : Double
  /// The E-value of the limit of the interval that is closer to the null.
  evalue_lower_ci : Double?
  /// The E-value of the limit of the interval that is closer to the null.
  evalue_upper_ci : Double?
}

///|
/// The estimate, converted to the risk ratio scale.
pub fn EValueStats::converted_estimate(self : EValueStats) -> Double {
  self.converted_estimate
}

///|
/// The lower limit of the interval, converted to the risk ratio scale.
pub fn EValueStats::converted_lower_ci(self : EValueStats) -> Double? {
  self.converted_lower_ci
}

///|
/// The upper limit of the interval, converted to the risk ratio scale.
pub fn EValueStats::converted_upper_ci(self : EValueStats) -> Double? {
  self.converted_upper_ci
}

///|
/// The E-value of the estimate.
pub fn EValueStats::evalue_estimate(self : EValueStats) -> Double {
  self.evalue_estimate
}

///|
/// The E-value of the limit of the interval that is closer to the null.
pub fn EValueStats::evalue_lower_ci(self : EValueStats) -> Double? {
  self.evalue_lower_ci
}

///|
/// The E-value of the limit of the interval that is closer to the null.
pub fn EValueStats::evalue_upper_ci(self : EValueStats) -> Double? {
  self.evalue_upper_ci
}

///|
/// The E-value analysis of an estimate.
///
/// This is the port of
/// `dowhy.causal_refuters.evalue_sensitivity_analyzer.EValueSensitivityAnalyzer`.
/// It reports the E-value of the estimate of the data, the E-value of the limit
/// of its interval that is closer to the null, and the Observed Covariate
/// E-value of every measured confounder.
///
/// The estimate of a linear regression is a difference of means, and the
/// analysis turns it into a standardised difference with the standard
/// deviation of the outcome before it converts it to the risk ratio scale. The
/// estimate of a generalised linear model is on the scale of the link of its
/// family: a binomial model with the logit link gives an odds ratio and a
/// Poisson model with the log link gives a rate ratio.
pub struct EValueSensitivityAnalyzer {
  /// The effect of the treatment.
  estimate : Double
  /// The standard error of the effect.
  standard_error : Double
  /// The contrast of the treatment, the difference of the treatment value of
  /// the treated arm and the one of the control arm.
  treatment_delta : Double
  /// The standard deviation of the outcome.
  outcome_sd : Double
  /// The statistics of the analysis.
  stats : EValueStats
  /// The Observed Covariate E-value of every measured confounder.
  benchmarking : Array[ObservedCovariateEValue]
}

///|
/// The Observed Covariate E-value of a measured confounder.
///
/// This is the port of the row of the `benchmarking_results` of the upstream. It
/// reports the estimate that was computed without the confounder and the
/// strength of the association that the confounder would need to move the limit
/// of the interval of the original estimate to the limit of the interval of the
/// estimate without it.
pub struct ObservedCovariateEValue {
  /// The name of the confounder.
  covariate : String
  /// The estimate without the confounder, converted to the risk ratio scale.
  converted_estimate : Double
  /// The lower limit of the interval without the confounder, converted to the
  /// risk ratio scale.
  converted_lower_ci : Double?
  /// The upper limit of the interval without the confounder, converted to the
  /// risk ratio scale.
  converted_upper_ci : Double?
  /// The E-value of the confounder.
  evalue : Double
}

///|
/// The name of the confounder.
pub fn ObservedCovariateEValue::covariate(
  self : ObservedCovariateEValue,
) -> String {
  self.covariate
}

///|
/// The estimate without the confounder, converted to the risk ratio scale.
pub fn ObservedCovariateEValue::converted_estimate(
  self : ObservedCovariateEValue,
) -> Double {
  self.converted_estimate
}

///|
/// The E-value of the confounder.
pub fn ObservedCovariateEValue::evalue(
  self : ObservedCovariateEValue,
) -> Double {
  self.evalue
}

///|
/// The effect of the treatment.
pub fn EValueSensitivityAnalyzer::estimate(
  self : EValueSensitivityAnalyzer,
) -> Double {
  self.estimate
}

///|
/// The standard error of the effect.
pub fn EValueSensitivityAnalyzer::standard_error(
  self : EValueSensitivityAnalyzer,
) -> Double {
  self.standard_error
}

///|
/// The contrast of the treatment.
pub fn EValueSensitivityAnalyzer::treatment_delta(
  self : EValueSensitivityAnalyzer,
) -> Double {
  self.treatment_delta
}

///|
/// The standard deviation of the outcome.
pub fn EValueSensitivityAnalyzer::outcome_sd(
  self : EValueSensitivityAnalyzer,
) -> Double {
  self.outcome_sd
}

///|
/// The statistics of the analysis.
pub fn EValueSensitivityAnalyzer::stats(
  self : EValueSensitivityAnalyzer,
) -> EValueStats {
  self.stats
}

///|
/// The Observed Covariate E-value of every measured confounder.
pub fn EValueSensitivityAnalyzer::benchmarking(
  self : EValueSensitivityAnalyzer,
) -> Array[ObservedCovariateEValue] {
  self.benchmarking.copy()
}

///|
/// The E-value analysis of the estimate of an estimator.
///
/// This is the port of the `check_sensitivity` of the upstream and of its
/// `benchmark`.
///
/// The estimate of the estimator is the effect of the treatment, and its
/// standard error is the standard error of that effect, so the two carry the
/// contrast of the treatment already. The analysis of the upstream scales the
/// coefficient of the treatment with the contrast and leaves the standard error
/// alone, because the standard error of its estimator carries the contrast as
/// well.
///
/// The standard deviation of the outcome is the one of the rows of the data,
/// with the convention of NumPy, which is the one the upstream uses.
///
/// The upstream refuses an estimator with effect modifiers, and the port does
/// the same.
pub fn evalue_sensitivity_analyzer(
  estimator : @estimators.CausalEstimator,
  data : @api.DataFrame,
  outcome_name : String,
  target_units~ : String = "ate",
) -> EValueSensitivityAnalyzer {
  if estimator.effect_modifiers().length() > 0 {
    abort(
      "the E-value analysis of the upstream does not support effect modifiers",
    )
  }
  let outcome = data.numeric(outcome_name)
  let outcome_sd = @utils.variance(outcome, 0).sqrt()
  let treatment_value = estimator.treatment_value()
  let control_value = estimator.control_value()
  let treatment_delta = (treatment_value - control_value).abs()
  let stats = evalue_of_estimator(estimator, outcome, treatment_delta)
  let model = estimator.regression_model()
  let features = estimator.design_features()
  let index = index_of_feature(features, estimator.treatment())
  let effect = model.beta[index] * treatment_delta
  let standard_error = model.se[index] * treatment_delta
  // The Observed Covariate E-value of every measured confounder: the confounder
  // is dropped, the estimator is refitted, and the limit of the interval that is
  // closer to the null is compared with the limit of the original one.
  //
  // The upstream does not benchmark the E-value when the interval of the
  // estimate already crosses the null, because the interval is then already
  // tipped, and the port does the same.
  let benchmarking : Array[ObservedCovariateEValue] = []
  let covariates = if evalue_is_tipped(stats) {
    []
  } else {
    estimator.adjustment_set()
  }
  let estimand = estimator.estimand()
  for covariate in covariates {
    let remaining : Array[String] = []
    for name in covariates {
      if name != covariate {
        remaining.push(name)
      }
    }
    let new_estimator = estimator.with_estimand(
      estimand.with_adjustment_variables(remaining),
    )
    new_estimator.fit(data, [])
    let _ = new_estimator.estimate_effect(
      data, treatment_value, control_value, target_units,
    )
    let new_stats = evalue_of_estimator(new_estimator, outcome, treatment_delta)
    let limit = match stats.evalue_lower_ci() {
      None => stats.converted_upper_ci()
      Some(_) => stats.converted_lower_ci()
    }
    let new_limit = match stats.evalue_lower_ci() {
      None => new_stats.converted_upper_ci()
      Some(_) => new_stats.converted_lower_ci()
    }
    match (limit, new_limit) {
      (Some(bound), Some(new_bound)) =>
        benchmarking.push({
          covariate,
          converted_estimate: new_stats.converted_estimate(),
          converted_lower_ci: new_stats.converted_lower_ci(),
          converted_upper_ci: new_stats.converted_upper_ci(),
          evalue: observed_covariate_e_value(bound, new_bound),
        })
      _ => ()
    }
  }
  {
    estimate: effect,
    standard_error,
    treatment_delta,
    outcome_sd,
    stats,
    benchmarking,
  }
}

///|
/// Whether the interval of the estimate is already tipped.
///
/// The interval of the estimate crosses the null when the E-value of the limit
/// of the interval that is closer to the null is one.
fn evalue_is_tipped(stats : EValueStats) -> Bool {
  match (stats.evalue_lower_ci(), stats.evalue_upper_ci()) {
    (None, Some(upper)) => upper == 1.0
    (Some(lower), None) => lower == 1.0
    _ => false
  }
}

///|
/// The E-value of the estimate of a fitted estimator.
///
/// The estimate of a linear regression is the coefficient of the treatment, and
/// the standard error of its estimator already carries the contrast of the
/// treatment, so the standard error is not scaled with it again.
fn evalue_of_estimator(
  estimator : @estimators.CausalEstimator,
  outcome : Array[Double],
  treatment_delta : Double,
) -> EValueStats {
  let outcome_sd = @utils.variance(outcome, 0).sqrt()
  let features = estimator.design_features()
  let index = index_of_feature(features, estimator.treatment())
  match estimator.estimator_kind() {
    LinearRegression => {
      let model = estimator.regression_model()
      evalue_ols(
        model.beta[index],
        model.se[index] * treatment_delta,
        outcome_sd,
        treatment_delta,
      )
    }
    GeneralizedLinearModel => {
      let model = estimator.glm_model()
      let estimate = model.beta[index]
      let standard_error = model.se[index]
      let lower = @math.exp(estimate - 1.96 * standard_error)
      let upper = @math.exp(estimate + 1.96 * standard_error)
      let rare = @utils.mean(outcome) < 0.15
      match estimator.glm_family() {
        Binomial =>
          evalue_or(@math.exp(estimate), Some(lower), Some(upper), rare)
        Poisson => evalue_rr(@math.exp(estimate), Some(lower), Some(upper))
        Gaussian =>
          abort(
            "the E-value analysis of the upstream supports the binomial, the " +
            "Poisson, the negative binomial and the gamma family of the " +
            "generalised linear model, and not the gaussian one",
          )
      }
    }
    _ =>
      abort(
        "the E-value analysis of the upstream is only implemented for the " +
        "regression based estimators",
      )
  }
}

///|
/// The E-value of a risk ratio and of the limits of its interval.
///
/// This is the port of `EValueSensitivityAnalyzer._evalue_RR`. The E-value of
/// the limit of the interval that is closer to the null is the one that is
/// reported, and both of them are one when the interval of the estimate
/// crosses the null, because the interval is then already tipped.
///
/// The baseline is the risk ratio of no effect, which is one for a risk ratio.
/// A baseline that is not one asks for the strength of the confounding that
/// moves the estimate to that baseline instead of to the null.
pub fn evalue_rr(
  estimate : Double,
  lower : Double?,
  upper : Double?,
  no_effect_baseline~ : Double = 1.0,
) -> EValueStats {
  if estimate < 0.0 {
    abort("a risk ratio cannot be negative")
  }
  if no_effect_baseline < 0.0 {
    abort("the baseline of no effect cannot be negative")
  }
  match (lower, upper) {
    (Some(lo), Some(hi)) =>
      if lo > hi {
        abort(
          "the lower limit of the interval has to be smaller than the upper one",
        )
      }
    _ => ()
  }
  match lower {
    Some(lo) =>
      if estimate < lo {
        abort("the estimate has to be inside the interval")
      }
    None => ()
  }
  match upper {
    Some(hi) =>
      if estimate > hi {
        abort("the estimate has to be inside the interval")
      }
    None => ()
  }
  let e_estimate = evalue_threshold(estimate, no_effect_baseline)
  let mut e_lower = match lower {
    Some(lo) => Some(evalue_threshold(lo, no_effect_baseline))
    None => None
  }
  let mut e_upper = match upper {
    Some(hi) => Some(evalue_threshold(hi, no_effect_baseline))
    None => None
  }
  // An interval that crosses the null is already tipped, so the E-value of both
  // of its limits is one.
  let mut null_interval = false
  if estimate > no_effect_baseline {
    match lower {
      Some(lo) => null_interval = lo < no_effect_baseline
      None => ()
    }
  }
  if estimate < no_effect_baseline {
    match upper {
      Some(hi) => null_interval = hi > no_effect_baseline
      None => ()
    }
  }
  if null_interval {
    e_lower = Some(1.0)
    e_upper = Some(1.0)
  }
  // Only the limit of the interval that is closer to the null is reported.
  if evalue_is_present(lower) || evalue_is_present(upper) {
    if estimate > no_effect_baseline {
      e_upper = None
    } else {
      e_lower = None
    }
  }
  {
    converted_estimate: estimate,
    converted_lower_ci: lower,
    converted_upper_ci: upper,
    evalue_estimate: e_estimate,
    evalue_lower_ci: e_lower,
    evalue_upper_ci: e_upper,
  }
}

///|
/// The E-value of a standardised difference and of the limits of its interval.
///
/// This is the port of `EValueSensitivityAnalyzer._evalue_MD`. The limits of
/// the interval are the ones of the table 2 of the paper of Ding and
/// VanderWeele, and the standardised difference is converted to an approximate
/// risk ratio with `exp(0.91 * difference)`.
pub fn evalue_md(
  estimate : Double,
  standard_error : Double?,
  no_effect_baseline~ : Double = 0.0,
) -> EValueStats {
  let mut lower : Double? = None
  let mut upper : Double? = None
  match standard_error {
    Some(se) => {
      if se < 0.0 {
        abort("the standard error cannot be negative")
      }
      lower = Some(@math.exp(0.91 * estimate - 1.78 * se))
      upper = Some(@math.exp(0.91 * estimate + 1.78 * se))
    }
    None => ()
  }
  evalue_rr(
    @math.exp(0.91 * estimate),
    lower,
    upper,
    no_effect_baseline=@math.exp(0.91 * no_effect_baseline),
  )
}

///|
/// The E-value of an odds ratio and of the limits of its interval.
///
/// This is the port of `EValueSensitivityAnalyzer._evalue_OR`. An outcome that
/// is rare keeps its odds ratio, and an outcome that is not rare is converted
/// to an approximate risk ratio with its square root.
pub fn evalue_or(
  estimate : Double,
  lower : Double?,
  upper : Double?,
  rare : Bool,
  no_effect_baseline~ : Double = 1.0,
) -> EValueStats {
  if estimate < 0.0 {
    abort("an odds ratio cannot be negative")
  }
  evalue_rr(
    evalue_or_to_rr(estimate, rare),
    match lower {
      Some(lo) => Some(evalue_or_to_rr(lo, rare))
      None => None
    },
    match upper {
      Some(hi) => Some(evalue_or_to_rr(hi, rare))
      None => None
    },
    no_effect_baseline=evalue_or_to_rr(no_effect_baseline, rare),
  )
}

///|
/// The E-value of the coefficient of a linear regression.
///
/// This is the port of `EValueSensitivityAnalyzer._evalue_OLS`. The coefficient
/// and its standard error are turned into a standardised difference with the
/// standard deviation of the outcome, and the contrast of the treatment scales
/// the coefficient but not the standard error, because the estimator of the
/// upstream already scaled it.
pub fn evalue_ols(
  estimate : Double,
  standard_error : Double,
  outcome_sd : Double,
  treatment_delta : Double,
  no_effect_baseline~ : Double = 0.0,
) -> EValueStats {
  if standard_error < 0.0 {
    abort("the standard error cannot be negative")
  }
  evalue_md(
    evalue_to_smd(estimate, outcome_sd, treatment_delta),
    Some(evalue_to_smd(standard_error, outcome_sd, 1.0)),
    no_effect_baseline~,
  )
}

///|
/// The E-value of a measured confounder, the one of McGowan and Greevy.
///
/// This is the port of
/// `EValueSensitivityAnalyzer._observed_covariate_e_value`. It compares the
/// limit of the interval of the estimate with the limit of the interval of the
/// estimate that was computed without the confounder, and it reports the
/// strength of the association that the confounder would need to move the
/// first limit to the second one.
pub fn observed_covariate_e_value(ci : Double, new_ci : Double) -> Double {
  let mut limit = ci
  let mut other = new_ci
  if limit < 1.0 {
    limit = 1.0 / limit
    other = 1.0 / other
  }
  let ratio = if limit < other { other / limit } else { limit / other }
  ratio + (ratio * (ratio - 1.0)).sqrt()
}

///|
/// Whether an optional number is there.
fn evalue_is_present(value : Double?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
/// The E-value of a single risk ratio.
///
/// This is the port of `EValueSensitivityAnalyzer._threshold`.
fn evalue_threshold(x : Double, no_effect_baseline : Double) -> Double {
  let mut value = x
  let mut baseline = no_effect_baseline
  if value <= 1.0 {
    value = 1.0 / value
    baseline = 1.0 / baseline
  }
  if baseline <= value {
    (value + (value * (value - baseline)).sqrt()) / baseline
  } else {
    let ratio = baseline / value
    ratio + (ratio * (ratio - 1.0)).sqrt()
  }
}

///|
/// The standardised difference of an estimate.
///
/// This is the port of `EValueSensitivityAnalyzer._to_smd`.
fn evalue_to_smd(estimate : Double, sd : Double, delta : Double) -> Double {
  estimate * delta / sd
}

///|
/// The approximate risk ratio of an odds ratio.
///
/// This is the port of `EValueSensitivityAnalyzer._or_to_rr`.
fn evalue_or_to_rr(estimate : Double, rare : Bool) -> Double {
  if rare {
    estimate
  } else {
    estimate.sqrt()
  }
}
