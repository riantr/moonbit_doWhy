/// Fitting and estimation for every estimator family.

///|
/// Build the design matrix of a regression based estimator.
///
/// The column order is the one `dowhy` uses: the intercept, the treatment,
/// the adjustment variables and finally the interaction of the treatment with
/// every effect modifier.
///
/// The discrete columns of the three groups of variables are one-hot encoded
/// with the encoders of the estimator, so that the encoding of a column does
/// not depend on the order the rows of the data arrive in.
fn CausalEstimator::build_design(
  self : CausalEstimator,
  data : @api.DataFrame,
) -> (@utils.Matrix, Array[String]) {
  let n = data.nrows()
  let names : Array[String] = ["const"]
  let columns : Array[Array[Double]] = [const_column(n)]
  let treatment_frame = self.encoders.encode(
    data.select([self.treatment_name]),
    "treatment",
  )
  let treatment_names = treatment_frame.numeric_column_names()
  for name in treatment_names {
    names.push(name)
    columns.push(treatment_frame.numeric(name))
  }
  if self.adjustment_names.length() > 0 {
    let common_frame = self.encoders.encode(
      data.select(self.adjustment_names),
      "observed_common_causes",
    )
    for name in common_frame.numeric_column_names() {
      names.push(name)
      columns.push(common_frame.numeric(name))
    }
  }
  if self.effect_modifier_names.length() > 0 {
    let modifier_frame = self.encoders.encode(
      data.select(self.effect_modifier_names),
      "effect_modifiers",
    )
    let modifier_names = modifier_frame.numeric_column_names()
    for treatment_name in treatment_names {
      let treatment_values = treatment_frame.numeric(treatment_name)
      for modifier_name in modifier_names {
        let values = modifier_frame.numeric(modifier_name)
        let interaction : Array[Double] = []
        for i = 0; i < n; i = i + 1 {
          interaction.push(treatment_values[i] * values[i])
        }
        names.push(treatment_name + ":" + modifier_name)
        columns.push(interaction)
      }
    }
  }
  (@utils.Matrix::from_columns(columns), names)
}

///|
/// Build the design matrix of the propensity score model.
///
/// The propensity score is a function of the confounders only, so the
/// treatment is not part of the design.
fn CausalEstimator::build_common_cause_design(
  self : CausalEstimator,
  data : @api.DataFrame,
) -> @utils.Matrix {
  let n = data.nrows()
  let columns : Array[Array[Double]] = [const_column(n)]
  let common_frame = self.encoders.encode(
    data.select(self.adjustment_names),
    "observed_common_causes",
  )
  for name in common_frame.numeric_column_names() {
    columns.push(common_frame.numeric(name))
  }
  @utils.Matrix::from_columns(columns)
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
///
/// A discrete treatment keeps its type, so that the encoder of the estimator
/// can encode the new value the same way it encoded the old ones.
fn CausalEstimator::with_treatment(
  self : CausalEstimator,
  data : @api.DataFrame,
  value : Double,
) -> @api.DataFrame {
  let n = data.nrows()
  if data.is_discrete(self.treatment_name) {
    let column : Array[String] = []
    let text = value.to_string()
    for i = 0; i < n; i = i + 1 {
      column.push(text)
    }
    data.with_discrete(self.treatment_name, column)
  } else {
    let column : Array[Double] = []
    for i = 0; i < n; i = i + 1 {
      column.push(value)
    }
    data.with_numeric(self.treatment_name, column)
  }
}

///|
/// The mean of the predicted outcome when the treatment is set to `value`.
fn CausalEstimator::interventional_outcomes(
  self : CausalEstimator,
  data : @api.DataFrame,
  value : Double,
) -> Array[Double] {
  let modified = self.with_treatment(data, value)
  let (design, _) = self.build_design(modified)
  match self.kind {
    GeneralizedLinearModel => @utils.glm_predict(self.glm_model, design)
    _ => design.matvec(self.model.beta)
  }
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
  // The encoders are fitted again, because the data is assumed to have
  // changed since the last fit.
  self.encoders.reset()
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
    GeneralizedLinearModel => self.fit_generalized_linear_model(data)
  }
}

///|
/// Fit the ordinary least squares model.
fn CausalEstimator::fit_regression(
  self : CausalEstimator,
  data : @api.DataFrame,
) -> Unit {
  let (design, names) = self.build_design(data)
  let outcome = data.numeric(self.outcome_name)
  self.model = @utils.ols_fit(design, outcome)
  self.features = names
}

///|
/// Fit the generalised linear model.
///
/// The model is fitted with iteratively reweighted least squares and without
/// any penalty, which is what `statsmodels.api.GLM` does.
fn CausalEstimator::fit_generalized_linear_model(
  self : CausalEstimator,
  data : @api.DataFrame,
) -> Unit {
  let (design, names) = self.build_design(data)
  let outcome = data.numeric(self.outcome_name)
  self.glm_model = @utils.glm_fit(
    design,
    outcome,
    self.glm_family,
    100,
    1.0e-10,
  )
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
  let design_without_treatment = self.build_common_cause_design(data)
  let fit = @utils.logistic_fit(
    design_without_treatment, treatment, 1.0, 100, 1.0e-4,
  )
  self.propensity_beta = fit.beta.copy()
  let propensities = @utils.logistic_predict(fit.beta, design_without_treatment)
  self.propensities = propensities
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
    GeneralizedLinearModel =>
      self.estimate_generalized_linear_model(data, target_units)
  }
}

///|
/// The mean outcome of the intervention `do(treatment = value)`.
///
/// This is the port of the `do` operator of the upstream estimators: the
/// treatment is set to the given value in every row of the data and the model
/// predicts the outcome of the modified data.
pub fn CausalEstimator::intervene(
  self : CausalEstimator,
  value : Double,
  data : @api.DataFrame,
) -> Double {
  @utils.mean(self.interventional_outcomes(data, value))
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

///|
/// The effect of the generalised linear model estimator.
///
/// The point estimate is the difference of the two predicted means, exactly
/// like the upstream estimator computes it. The upstream estimator bootstraps
/// the confidence interval and the standard error, while the port reports the
/// analytic values of the fitted model.
///
/// The standard error of the effect follows from the delta method: the effect
/// is a function of the coefficients, and its gradient is the derivative of
/// the inverse link times the difference of the two design matrices.
fn CausalEstimator::estimate_generalized_linear_model(
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
  let quantile = @utils.normal_ppf(1.0 - (1.0 - self.confidence_level) / 2.0)
  let standard_error = self.generalized_linear_model_standard_error(
    data, treated, control,
  )
  let mut ci_lower = value - quantile * standard_error
  let mut ci_upper = value + quantile * standard_error
  let mut p_value = 0.0
  if standard_error > 0.0 {
    p_value = 2.0 * (1.0 - @utils.normal_cdf((value / standard_error).abs()))
  } else {
    ci_lower = value
    ci_upper = value
  }
  estimate.set_confidence_interval(ci_lower, ci_upper)
  estimate.set_standard_error(standard_error)
  estimate.set_p_value(p_value)
  estimate
}

///|
/// The standard error of the effect of the generalised linear model.
///
/// It is the delta method: the gradient of the effect with respect to the
/// coefficients is the derivative of the inverse link times the difference of
/// the two design matrices, and the variance of the effect is the quadratic
/// form of that gradient with the covariance of the coefficients.
fn CausalEstimator::generalized_linear_model_standard_error(
  self : CausalEstimator,
  data : @api.DataFrame,
  treated : Array[Double],
  control : Array[Double],
) -> Double {
  let (treated_design, _) = self.build_design(
    self.with_treatment(data, self.treatment_value),
  )
  let (control_design, _) = self.build_design(
    self.with_treatment(data, self.control_value),
  )
  let rows = data.nrows()
  let columns = treated_design.ncols()
  let derivative_treated = @utils.glm_link_derivative(self.glm_family, treated)
  let derivative_control = @utils.glm_link_derivative(self.glm_family, control)
  let gradient : Array[Double] = []
  for j = 0; j < columns; j = j + 1 {
    gradient.push(0.0)
  }
  for i = 0; i < rows; i = i + 1 {
    for j = 0; j < columns; j = j + 1 {
      gradient[j] = gradient[j] +
        (
          derivative_treated[i] * treated_design.get(i, j) -
          derivative_control[i] * control_design.get(i, j)
        ) /
        rows.to_double()
    }
  }
  let cov = self.glm_model.cov
  let mut variance = 0.0
  for i = 0; i < columns; i = i + 1 {
    for j = 0; j < columns; j = j + 1 {
      variance = variance + gradient[i] * cov.get(i, j) * gradient[j]
    }
  }
  if variance > 0.0 {
    variance.sqrt()
  } else {
    0.0
  }
}
