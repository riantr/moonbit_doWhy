/// Fitting and estimation for every estimator family.

///|
/// Build the design matrix of a regression based estimator.
///
/// The column order is the one `dowhy` uses: the intercept, the treatment,
/// the adjustment variables and finally the interaction of the treatment with
/// every effect modifier.
fn build_design(
  data : @api.DataFrame,
  treatment_name : String,
  adjustment_names : Array[String],
  effect_modifier_names : Array[String],
) -> (@utils.Matrix, Array[String]) {
  let n = data.nrows()
  let names : Array[String] = ["const"]
  let columns : Array[Array[Double]] = [const_column(n)]
  let treatment = data.numeric(treatment_name)
  names.push(treatment_name)
  columns.push(treatment)
  for name in adjustment_names {
    names.push(name)
    columns.push(data.numeric(name))
  }
  for modifier in effect_modifier_names {
    let values = data.numeric(modifier)
    let interaction : Array[Double] = []
    for i = 0; i < n; i = i + 1 {
      interaction.push(treatment[i] * values[i])
    }
    names.push(treatment_name + ":" + modifier)
    columns.push(interaction)
  }
  (@utils.Matrix::from_columns(columns), names)
}

///|
fn const_column(n : Int32) -> Array[Double] {
  let column : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    column.push(1.0)
  }
  column
}

///|
/// Replace the treatment column of a data frame with a constant.
fn with_treatment(
  data : @api.DataFrame,
  treatment_name : String,
  value : Double,
) -> @api.DataFrame {
  let n = data.nrows()
  let column : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    column.push(value)
  }
  data.with_numeric(treatment_name, column)
}

///|
/// The mean of the predicted outcome when the treatment is set to `value`.
fn CausalEstimator::interventional_outcomes(
  self : CausalEstimator,
  data : @api.DataFrame,
  value : Double,
) -> Array[Double] {
  let modified = with_treatment(data, self.treatment_name, value)
  let (design, _) = build_design(
    modified,
    self.treatment_name,
    self.adjustment_names,
    self.effect_modifier_names,
  )
  design.matvec(self.model.beta)
}

///|
/// Fit the estimator on the given data.
///
/// The estimator remembers the adjustment variables of its estimand, fits the
/// model it needs and stores the propensity scores when it uses them.
pub fn CausalEstimator::fit(
  self : CausalEstimator,
  data : @api.DataFrame,
  effect_modifier_names : Array[String],
) -> Unit {
  let treatment = self.target_estimand.treatment()
  let outcome = self.target_estimand.outcome()
  if treatment.length() != 1 {
    abort("The estimator cannot handle more than one treatment variable")
  }
  if outcome.length() != 1 {
    abort("The estimator cannot handle more than one outcome variable")
  }
  self.treatment_name = treatment[0]
  self.outcome_name = outcome[0]
  self.adjustment_names = self.target_estimand.get_adjustment_set(
    self.target_estimand.identifier_method(),
  )
  self.effect_modifier_names = effect_modifier_names.copy()
  match self.kind {
    LinearRegression => self.fit_regression(data)
    PropensityScoreWeighting => self.fit_propensity_score(data)
    PropensityScoreMatching => self.fit_propensity_score(data)
    PropensityScoreStratification => self.fit_propensity_score(data)
    DoublyRobust => {
      self.fit_propensity_score(data)
      self.fit_regression(data)
    }
    InstrumentalVariable => self.fit_instrumental_variable(data)
    TwoStageRegression => self.fit_regression(data)
    RegressionDiscontinuity => self.fit_regression_discontinuity(data)
  }
}

///|
/// Fit the ordinary least squares model.
fn CausalEstimator::fit_regression(
  self : CausalEstimator,
  data : @api.DataFrame,
) -> Unit {
  let (design, names) = build_design(
    data,
    self.treatment_name,
    self.adjustment_names,
    self.effect_modifier_names,
  )
  let outcome = data.numeric(self.outcome_name)
  self.model = @utils.ols_fit(design, outcome)
  self.features = names
}

///|
/// Fit the propensity score model.
///
/// The logistic regression follows `sklearn.linear_model.LogisticRegression`
/// with its default settings: an L2 penalty with `C = 1.0`.
fn CausalEstimator::fit_propensity_score(
  self : CausalEstimator,
  data : @api.DataFrame,
) -> Unit {
  if self.adjustment_names.length() == 0 {
    abort(
      "No common causes/confounders present. Propensity score based methods are not applicable",
    )
  }
  let treatment = data.numeric(self.treatment_name)
  for value in treatment {
    if value != 0.0 && value != 1.0 {
      abort(
        "Propensity score methods are applicable only for binary treatments",
      )
    }
  }
  let (design, _) = build_design(
    data,
    self.treatment_name,
    self.adjustment_names,
    self.effect_modifier_names,
  )
  // The propensity score is a function of the confounders only.
  let confounders : Array[Array[Double]] = []
  for j = 0; j < design.ncols(); j = j + 1 {
    if j != 1 {
      confounders.push(design.col(j))
    }
  }
  let design_without_treatment = @utils.Matrix::from_columns(confounders)
  let fit = @utils.logistic_fit(
    design_without_treatment, treatment, 1.0, 100, 1.0e-4,
  )
  let propensities = @utils.logistic_predict(fit.beta, design_without_treatment)
  self.propensities = propensities
  let _ = data.with_numeric("propensity_score", propensities)
}

///|
/// Fit the instrumental variable estimator.
fn CausalEstimator::fit_instrumental_variable(
  self : CausalEstimator,
  data : @api.DataFrame,
) -> Unit {
  let instruments = if self.instrument_name != "" {
    [self.instrument_name]
  } else {
    self.target_estimand.get_instrumental_variables()
  }
  if instruments.length() == 0 {
    abort("No valid instruments found. IV Method not applicable")
  }
  if instruments.length() < self.target_estimand.treatment().length() {
    abort(
      "Number of instruments fewer than number of treatments. 2SLS requires at least as many instruments as treatments.",
    )
  }
  self.adjustment_names = instruments
  self.fit_regression(data)
}

///|
/// Estimate the treatment effect.
///
/// `target_units` is one of `"ate"`, `"att"` or `"atc"`.
pub fn CausalEstimator::estimate_effect(
  self : CausalEstimator,
  data : @api.DataFrame,
  treatment_value : Double,
  control_value : Double,
  target_units : String,
) -> @model.CausalEstimate {
  self.treatment_value = treatment_value
  self.control_value = control_value
  match self.kind {
    LinearRegression => self.estimate_regression(data, target_units)
    PropensityScoreWeighting =>
      self.estimate_propensity_score_weighting(data, target_units)
    PropensityScoreMatching =>
      self.estimate_propensity_score_matching(data, target_units)
    PropensityScoreStratification =>
      self.estimate_propensity_score_stratification(data, target_units)
    DoublyRobust => self.estimate_doubly_robust(data, target_units)
    InstrumentalVariable => self.estimate_instrumental_variable(data)
    TwoStageRegression => self.estimate_regression(data, target_units)
    RegressionDiscontinuity =>
      self.estimate_regression_discontinuity(data, target_units)
  }
}

///|
/// The effect of a regression based estimator.
fn CausalEstimator::estimate_regression(
  self : CausalEstimator,
  data : @api.DataFrame,
  _target_units : String,
) -> @model.CausalEstimate {
  let treated = self.interventional_outcomes(data, self.treatment_value)
  let control = self.interventional_outcomes(data, self.control_value)
  let value = @utils.mean(treated) - @utils.mean(control)
  let estimate = @model.CausalEstimate::new(
    value,
    self.treatment_name,
    self.outcome_name,
    self.target_estimand.identifier_method(),
    self.control_value,
    self.treatment_value,
  )
  // The confidence interval and the standard error scale the treatment
  // coefficient by the difference of the two treatment values.
  let factor = self.treatment_value - self.control_value
  let lower = @utils.t_ppf(
    1.0 - (1.0 - self.confidence_level) / 2.0,
    self.model.df_resid.to_double(),
  )
  let upper = @utils.t_ppf(
    1.0 - (1.0 - self.confidence_level) / 2.0,
    self.model.df_resid.to_double(),
  )
  let mut ci_lower = 0.0
  let mut ci_upper = 0.0
  let mut standard_error = 0.0
  let mut p_value = 0.0
  if self.features.length() > 1 {
    let beta = self.model.beta[1]
    let se = self.model.se[1]
    ci_lower = (beta - lower * se) * factor
    ci_upper = (beta + upper * se) * factor
    standard_error = se * factor
    p_value = @utils.t_pvalue(
      self.model.tstat[1],
      self.model.df_resid.to_double(),
    )
  }
  estimate.set_confidence_interval(ci_lower, ci_upper)
  estimate.set_standard_error(standard_error)
  estimate.set_p_value(p_value)
  estimate
}
