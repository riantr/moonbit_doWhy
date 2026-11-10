///|
/// The linear sensitivity analysis of an unobserved confounder.
///
/// This is the port of `dowhy.causal_refuters.linear_sensitivity_analyzer`, the
/// analyzer of the `linear-partial-R2` simulation method of the upstream. It asks
/// how strong an unobserved confounder has to be to move the estimate of the
/// data, and it answers with the partial R2 of the confounder with the
/// treatment and with the outcome, the robustness value and the bias adjusted
/// estimate.
///
/// The analysis rests on two regressions:
///
/// * the **outcome regression**, the regression of the outcome on the treatment
///   and on the observed common causes, which is the model of the estimator,
/// * the **treatment regression**, the regression of the treatment on the observed
///   common causes, which says how much of the treatment the common causes
///   explain.
///
/// The partial R2 of a covariate is `t^2 / (t^2 + degrees of freedom)` of its
/// coefficient, which is the partial R2 of the treatment with the outcome given
/// the common causes (`r2yt_w`) and of a common cause with the treatment given
/// the other common causes (`r2twj_w`).
///
/// The strength of the confounder is a fraction of the strength of a benchmark
/// common cause, `frac_strength_treatment`, and the partial R2 of the
/// confounder with the treatment follows from it:
///
/// * `r2tu_w = strength * r2twj_w / (1 - r2twj_w)`,
/// * `r2uwj_wt = strength * r2twj_w^2 / ((1 - strength * r2twj_w) * (1 - r2twj_w))`,
/// * `r2yu_tw = ((sqrt(strength_outcome) + sqrt(r2uwj_wt)) / sqrt(1 - r2uwj_wt))^2
///   * r2ywj_tw / (1 - r2ywj_tw)`.
///
/// The bias the confounder adds to the estimate is
/// `sqrt(r2yu_tw * r2tu_w / (1 - r2tu_w)) * standard_error * sqrt(degrees of
/// freedom)`, and the bias adjusted estimate is the estimate moved by that bias
/// away from zero or toward it, the way `confounder_increases_estimate` names.

///|
/// The result of the linear sensitivity analysis.
pub struct LinearSensitivityAnalyzer {
  /// The estimate of the data.
  estimate : Double
  /// The standard error of the estimate.
  standard_error : Double
  /// The degrees of freedom of the outcome regression.
  degree_of_freedom : Int32
  /// The t statistic of the estimate against the null hypothesis of the
  /// analysis.
  t_statistic : Double
  /// The partial R2 of the treatment with the outcome given the common causes.
  r2yt_w : Double
  /// The partial F2 of the estimate.
  partial_f2 : Double
  /// The robustness value of the estimate.
  robustness_value : Double
  /// The robustness value at the significance level of the analysis.
  robustness_value_alpha : Double
  /// Whether the confounder moves the estimate away from zero.
  confounder_increases_estimate : Bool
  /// The effect under the null hypothesis of the analysis.
  null_hypothesis_effect : Double
  /// The level of the interval of the bias adjusted estimate.
  significance_level : Double
  /// The partial R2 of the confounder with the treatment given the common
  /// causes, one value per strength.
  r2tu_w : Array[Double]
  /// The partial R2 of the confounder with the outcome given the treatment and
  /// the common causes, one value per strength.
  r2yu_tw : Array[Double]
  /// The bias adjusted estimate, one value per strength.
  bias_adjusted_estimate : Array[Double]
  /// The standard error of the bias adjusted estimate, one value per strength.
  bias_adjusted_se : Array[Double]
  /// The t statistic of the bias adjusted estimate, one value per strength.
  bias_adjusted_t : Array[Double]
  /// The lower bound of the bias adjusted estimate, one value per strength.
  bias_adjusted_lower_ci : Array[Double]
  /// The upper bound of the bias adjusted estimate, one value per strength.
  bias_adjusted_upper_ci : Array[Double]
}

///|
/// The estimate of the data.
pub fn LinearSensitivityAnalyzer::estimate(
  self : LinearSensitivityAnalyzer,
) -> Double {
  self.estimate
}

///|
/// The standard error of the estimate.
pub fn LinearSensitivityAnalyzer::standard_error(
  self : LinearSensitivityAnalyzer,
) -> Double {
  self.standard_error
}

///|
/// The degrees of freedom of the outcome regression.
pub fn LinearSensitivityAnalyzer::degree_of_freedom(
  self : LinearSensitivityAnalyzer,
) -> Int32 {
  self.degree_of_freedom
}

///|
/// The t statistic of the estimate against the null hypothesis of the analysis.
pub fn LinearSensitivityAnalyzer::t_statistic(
  self : LinearSensitivityAnalyzer,
) -> Double {
  self.t_statistic
}

///|
/// The partial R2 of the treatment with the outcome given the common causes.
pub fn LinearSensitivityAnalyzer::r2yt_w(
  self : LinearSensitivityAnalyzer,
) -> Double {
  self.r2yt_w
}

///|
/// The partial F2 of the estimate.
pub fn LinearSensitivityAnalyzer::partial_f2(
  self : LinearSensitivityAnalyzer,
) -> Double {
  self.partial_f2
}

///|
/// The robustness value of the estimate.
pub fn LinearSensitivityAnalyzer::robustness_value(
  self : LinearSensitivityAnalyzer,
) -> Double {
  self.robustness_value
}

///|
/// The robustness value at the significance level of the analysis.
pub fn LinearSensitivityAnalyzer::robustness_value_alpha(
  self : LinearSensitivityAnalyzer,
) -> Double {
  self.robustness_value_alpha
}

///|
/// Whether the confounder moves the estimate away from zero.
pub fn LinearSensitivityAnalyzer::confounder_increases_estimate(
  self : LinearSensitivityAnalyzer,
) -> Bool {
  self.confounder_increases_estimate
}

///|
/// The effect under the null hypothesis of the analysis.
pub fn LinearSensitivityAnalyzer::null_hypothesis_effect(
  self : LinearSensitivityAnalyzer,
) -> Double {
  self.null_hypothesis_effect
}

///|
/// The level of the interval of the bias adjusted estimate.
pub fn LinearSensitivityAnalyzer::significance_level(
  self : LinearSensitivityAnalyzer,
) -> Double {
  self.significance_level
}

///|
/// The partial R2 of the confounder with the treatment given the common causes.
pub fn LinearSensitivityAnalyzer::r2tu_w(
  self : LinearSensitivityAnalyzer,
) -> Array[Double] {
  self.r2tu_w.copy()
}

///|
/// The partial R2 of the confounder with the outcome given the treatment and the
/// common causes.
pub fn LinearSensitivityAnalyzer::r2yu_tw(
  self : LinearSensitivityAnalyzer,
) -> Array[Double] {
  self.r2yu_tw.copy()
}

///|
/// The bias adjusted estimate.
pub fn LinearSensitivityAnalyzer::bias_adjusted_estimate(
  self : LinearSensitivityAnalyzer,
) -> Array[Double] {
  self.bias_adjusted_estimate.copy()
}

///|
/// The standard error of the bias adjusted estimate.
pub fn LinearSensitivityAnalyzer::bias_adjusted_se(
  self : LinearSensitivityAnalyzer,
) -> Array[Double] {
  self.bias_adjusted_se.copy()
}

///|
/// The t statistic of the bias adjusted estimate.
pub fn LinearSensitivityAnalyzer::bias_adjusted_t(
  self : LinearSensitivityAnalyzer,
) -> Array[Double] {
  self.bias_adjusted_t.copy()
}

///|
/// The lower bound of the bias adjusted estimate.
pub fn LinearSensitivityAnalyzer::bias_adjusted_lower_ci(
  self : LinearSensitivityAnalyzer,
) -> Array[Double] {
  self.bias_adjusted_lower_ci.copy()
}

///|
/// The upper bound of the bias adjusted estimate.
pub fn LinearSensitivityAnalyzer::bias_adjusted_upper_ci(
  self : LinearSensitivityAnalyzer,
) -> Array[Double] {
  self.bias_adjusted_upper_ci.copy()
}

///|
/// The linear sensitivity analysis of the estimate.
///
/// `benchmark_common_causes` names the common causes whose strength bounds the
/// strength of the confounder, `frac_strength_treatment` holds the fractions of
/// that strength to analyse, one per row of the results, and
/// `frac_strength_outcome` the fractions on the outcome. When the outcome's
/// fractions are not given, the treatment's ones are used, which is what the
/// upstream does when the caller does not give a strength for the outcome.
///
/// `percent_change_estimate` is the share of the estimate the confounder has to
/// remove to change the conclusion, `significance_level` the level of the
/// interval of the bias adjusted estimate, and `confounder_increases_estimate`
/// whether the confounder moves the estimate away from zero or toward it.
///
/// The confounder moves the estimate away from zero unless the caller says
/// otherwise, because the upstream builds its analyzer without the flag of its
/// refuter: `sensitivity_linear_partial_r2` never passes it, so the analyzer
/// keeps its own default of `True`.
pub fn linear_sensitivity_analyzer(
  estimator : @estimators.CausalEstimator,
  data : @api.DataFrame,
  treatment_name : String,
  benchmark_common_causes : Array[String],
  frac_strength_treatment : Array[Double],
  frac_strength_outcome : Array[Double]?,
  percent_change_estimate : Double,
  significance_level : Double,
  confounder_increases_estimate~ : Bool = true,
) -> LinearSensitivityAnalyzer {
  let model = estimator.regression_model()
  let features = estimator.design_features()
  let treatment_index = index_of_feature(features, treatment_name)
  let estimate = model.beta[treatment_index]
  let standard_error = model.se[treatment_index]
  let t_statistic = model.tstat[treatment_index]
  let degree_of_freedom = model.df_resid
  // The partial R2 of the treatment with the outcome given the common causes.
  let r2yt_w = partial_r2(t_statistic, degree_of_freedom)
  let robustness = robustness_value(
    t_statistic, degree_of_freedom, percent_change_estimate, 1.0,
  )
  let robustness_at_level = robustness_value(
    t_statistic, degree_of_freedom, percent_change_estimate, significance_level,
  )
  // The upstream sets the effect under the null hypothesis from the share of the
  // estimate the confounder has to remove, and the value the caller gives is
  // overwritten by it.
  let null_hypothesis_effect = if confounder_increases_estimate {
    estimate * (1.0 - percent_change_estimate)
  } else {
    estimate * (1.0 + percent_change_estimate)
  }
  let t_against_null = (estimate - null_hypothesis_effect) / standard_error
  let partial_f2 = t_against_null *
    t_against_null /
    degree_of_freedom.to_double()
  // The regression of the treatment on the common causes, which says how much of
  // the treatment the common causes explain.
  let common_causes = estimator.adjustment_set()
  let treatment_model = @utils.ols_fit(
    design_of_columns(data, common_causes),
    data.numeric(treatment_name),
  )
  let strengths_outcome = match frac_strength_outcome {
    Some(strengths) => strengths
    None => frac_strength_treatment.copy()
  }
  let r2tu_w : Array[Double] = []
  let r2yu_tw : Array[Double] = []
  for benchmark in benchmark_common_causes {
    let index = index_of_feature(features, benchmark)
    // The partial R2 of the benchmark common cause with the outcome given the
    // treatment and the other common causes.
    let r2ywj_tw = partial_r2(model.tstat[index], degree_of_freedom)
    // The partial R2 of the benchmark common cause with the treatment given the
    // other common causes.
    let r2twj_w = partial_r2(
      treatment_model.tstat[index],
      treatment_model.df_resid,
    )
    r2tu_w.clear()
    r2yu_tw.clear()
    for index = 0; index < frac_strength_treatment.length(); index = index + 1 {
      let strength = frac_strength_treatment[index]
      let value = strength * (r2twj_w / (1.0 - r2twj_w))
      if value >= 1.0 {
        abort(
          "r2tu_w can not be >= 1. Try a lower frac_strength_treatment value",
        )
      }
      r2tu_w.push(value)
      let r2uwj_wt = strength *
        (r2twj_w * r2twj_w) /
        ((1.0 - strength * r2twj_w) * (1.0 - r2twj_w))
      if r2uwj_wt >= 1.0 {
        abort(
          "r2uwj_wt can not be >= 1. Try a lower frac_strength_treatment value",
        )
      }
      let outcome_strength = strength_of(strengths_outcome, index)
      let numerator = (outcome_strength.sqrt() + r2uwj_wt.sqrt()) /
        (1.0 - r2uwj_wt).sqrt()
      let value = numerator * numerator * (r2ywj_tw / (1.0 - r2ywj_tw))
      // The upstream caps the value at one and warns about it.
      r2yu_tw.push(if value > 1.0 { 1.0 } else { value })
    }
  }
  let bias = compute_bias_adjusted_terms(
    estimate, standard_error, degree_of_freedom, null_hypothesis_effect, significance_level,
    confounder_increases_estimate, r2tu_w, r2yu_tw,
  )
  {
    estimate,
    standard_error,
    degree_of_freedom,
    t_statistic: t_against_null,
    r2yt_w,
    partial_f2,
    robustness_value: robustness,
    robustness_value_alpha: robustness_at_level,
    confounder_increases_estimate,
    null_hypothesis_effect,
    significance_level,
    r2tu_w,
    r2yu_tw,
    bias_adjusted_estimate: bias.estimates,
    bias_adjusted_se: bias.standard_errors,
    bias_adjusted_t: bias.t_statistics,
    bias_adjusted_lower_ci: bias.lower_bounds,
    bias_adjusted_upper_ci: bias.upper_bounds,
  }
}

///|
/// The bias adjusted terms of two sets of partial R2.
///
/// This is the port of `compute_bias_adjusted` of the upstream, which the
/// upstream test calls with two sets of its own.
pub fn compute_bias_adjusted(
  analyzer : LinearSensitivityAnalyzer,
  r2tu_w : Array[Double],
  r2yu_tw : Array[Double],
) -> BiasAdjustedTerms {
  compute_bias_adjusted_terms(
    analyzer.estimate,
    analyzer.standard_error,
    analyzer.degree_of_freedom,
    analyzer.null_hypothesis_effect,
    analyzer.significance_level,
    analyzer.confounder_increases_estimate,
    r2tu_w,
    r2yu_tw,
  )
}

///|
/// The bias adjusted terms of a set of partial R2.
pub struct BiasAdjustedTerms {
  /// The bias adjusted estimate, one value per pair of partial R2.
  estimates : Array[Double]
  /// The standard error of the bias adjusted estimate.
  standard_errors : Array[Double]
  /// The t statistic of the bias adjusted estimate.
  t_statistics : Array[Double]
  /// The lower bound of the bias adjusted estimate.
  lower_bounds : Array[Double]
  /// The upper bound of the bias adjusted estimate.
  upper_bounds : Array[Double]
}

///|
/// The bias adjusted estimate of every pair of partial R2.
pub fn BiasAdjustedTerms::estimates(self : BiasAdjustedTerms) -> Array[Double] {
  self.estimates.copy()
}

///|
/// The standard error of the bias adjusted estimate.
pub fn BiasAdjustedTerms::standard_errors(
  self : BiasAdjustedTerms,
) -> Array[Double] {
  self.standard_errors.copy()
}

///|
/// The t statistic of the bias adjusted estimate.
pub fn BiasAdjustedTerms::t_statistics(
  self : BiasAdjustedTerms,
) -> Array[Double] {
  self.t_statistics.copy()
}

///|
/// The lower bound of the bias adjusted estimate.
pub fn BiasAdjustedTerms::lower_bounds(
  self : BiasAdjustedTerms,
) -> Array[Double] {
  self.lower_bounds.copy()
}

///|
/// The upper bound of the bias adjusted estimate.
pub fn BiasAdjustedTerms::upper_bounds(
  self : BiasAdjustedTerms,
) -> Array[Double] {
  self.upper_bounds.copy()
}

///|
/// The bias adjusted terms of the given pairs of partial R2.
fn compute_bias_adjusted_terms(
  estimate : Double,
  standard_error : Double,
  degree_of_freedom : Int32,
  null_hypothesis_effect : Double,
  significance_level : Double,
  confounder_increases_estimate : Bool,
  r2tu_w : Array[Double],
  r2yu_tw : Array[Double],
) -> BiasAdjustedTerms {
  if r2tu_w.length() != r2yu_tw.length() {
    abort(
      "The two sets of partial R2 must have the same length, but they have " +
      r2tu_w.length().to_string() +
      " and " +
      r2yu_tw.length().to_string() +
      " values",
    )
  }
  let estimates : Array[Double] = []
  let standard_errors : Array[Double] = []
  let t_statistics : Array[Double] = []
  let lower_bounds : Array[Double] = []
  let upper_bounds : Array[Double] = []
  let degrees = degree_of_freedom.to_double()
  for i = 0; i < r2tu_w.length(); i = i + 1 {
    let bias_factor = (r2yu_tw[i] * r2tu_w[i] / (1.0 - r2tu_w[i])).sqrt()
    let bias = bias_factor * (standard_error * degrees.sqrt())
    let adjusted = if confounder_increases_estimate {
      sign(estimate) * (estimate.abs() - bias)
    } else {
      sign(estimate) * (estimate.abs() + bias)
    }
    let adjusted_se = ((1.0 - r2yu_tw[i]) / (1.0 - r2tu_w[i])).sqrt() *
      standard_error *
      (degrees / (degrees - 1.0)).sqrt()
    let numerator = adjusted - null_hypothesis_effect
    let adjusted_t = if adjusted_se == 0.0 {
      if numerator > 0.0 {
        @double.infinity
      } else if numerator < 0.0 {
        @double.neg_infinity
      } else {
        @utils.nan()
      }
    } else {
      numerator / adjusted_se
    }
    // The upstream takes the lower quantile of the Student distribution at half
    // the significance level, which is negative, and swaps the two bounds with
    // it. The port keeps the arithmetic and the names of the upstream.
    let num_se = @utils.t_ppf(
      significance_level / 2.0,
      degree_of_freedom.to_double(),
    )
    estimates.push(adjusted)
    standard_errors.push(adjusted_se)
    t_statistics.push(adjusted_t)
    lower_bounds.push(adjusted + num_se * adjusted_se)
    upper_bounds.push(adjusted - num_se * adjusted_se)
  }
  { estimates, standard_errors, t_statistics, lower_bounds, upper_bounds, }
}

///|
/// The partial R2 of a coefficient.
///
/// This is the port of `partial_r2_func` of the upstream, whose scalar branch
/// is `t^2 / (t^2 + degrees of freedom)`.
fn partial_r2(t_statistic : Double, degree_of_freedom : Int32) -> Double {
  let square = t_statistic * t_statistic
  square / (square + degree_of_freedom.to_double())
}

///|
/// The robustness value of the estimate.
///
/// This is the port of `robustness_value_func` of the upstream. The partial F of
/// the treatment with the outcome is `|t| / sqrt(degrees of freedom)`, the
/// strength that has to be reached is the share of the estimate the confounder
/// has to remove times that partial F, and the critical value comes from the
/// Student distribution at the level of the analysis.
fn robustness_value(
  t_statistic : Double,
  degree_of_freedom : Int32,
  percent_change_estimate : Double,
  alpha : Double,
) -> Double {
  let degrees = degree_of_freedom.to_double()
  let partial_cohen_f = (t_statistic / degrees.sqrt()).abs()
  let f_q = percent_change_estimate * partial_cohen_f
  let t_alpha = @utils.t_ppf(alpha / 2.0, (degree_of_freedom - 1).to_double()).abs()
  let f_critical = t_alpha / (degrees - 1.0).sqrt()
  let f_adjusted = f_q - f_critical
  if f_adjusted < 0.0 {
    return 0.0
  }
  let value = 0.5 *
    (
      (f_adjusted * f_adjusted * f_adjusted * f_adjusted +
      4.0 * f_adjusted * f_adjusted).sqrt() -
      f_adjusted * f_adjusted
    )
  if f_adjusted > 0.0 && f_critical != 0.0 && f_q > 1.0 / f_critical {
    return (f_q * f_q - f_critical * f_critical) / (1.0 + f_q * f_q)
  }
  value
}

///|
/// The sign of a number, the way `numpy.sign` gives it.
fn sign(value : Double) -> Double {
  if value > 0.0 {
    1.0
  } else if value < 0.0 {
    -1.0
  } else {
    0.0
  }
}

///|
/// The strength on the outcome that goes with a strength on the treatment.
///
/// The upstream holds the two strengths in arrays of the same length, and the
/// strength of the outcome that goes with the first strength of the treatment is
/// the first strength of the outcome. When the arrays have different lengths,
/// the last strength of the outcome is used.
fn strength_of(strengths : Array[Double], index : Int32) -> Double {
  if strengths.length() == 0 {
    return 1.0
  }
  if index < strengths.length() {
    strengths[index]
  } else {
    strengths[strengths.length() - 1]
  }
}

///|
/// The position of a column of the design matrix, by its name.
fn index_of_feature(features : Array[String], name : String) -> Int32 {
  for i = 0; i < features.length(); i = i + 1 {
    if features[i] == name {
      return i
    }
  }
  abort(
    "The column " +
    name +
    " is not a column of the design matrix of the estimator",
  )
}

///|
/// The design matrix of the given columns of the frame, with the column of ones
/// of the intercept in front of them.
fn design_of_columns(
  data : @api.DataFrame,
  names : Array[String],
) -> @utils.Matrix {
  let n = data.nrows()
  let design = @utils.Matrix::zeros(n, names.length() + 1)
  for i = 0; i < n; i = i + 1 {
    design.set(i, 0, 1.0)
    for j = 0; j < names.length(); j = j + 1 {
      if data.is_discrete(names[j]) {
        abort(
          "The sensitivity analysis needs the common causes to be numbers, but " +
          names[j] +
          " is a category",
        )
      }
      design.set(i, j + 1, data.numeric(names[j])[i])
    }
  }
  design
}
