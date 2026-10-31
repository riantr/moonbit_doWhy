/// The instrumental variable estimator and the regression discontinuity
/// estimator.

///|
/// The effect of the instrumental variable estimator.
///
/// A binary instrument gives the Wald estimator; a continuous instrument gives
/// the ratio of the sample covariances, which is the two stage least squares
/// estimate without any control variables.
fn CausalEstimator::estimate_instrumental_variable(
  self : CausalEstimator,
  data : @api.DataFrame,
) -> @model.CausalEstimate {
  let instruments = if self.instrument_name != "" {
    [self.instrument_name]
  } else {
    self.adjustment_names
  }
  if instruments.length() != 1 {
    abort("Only a single instrument is supported by this estimator")
  }
  let instrument = data.numeric(instruments[0])
  let outcome = data.numeric(self.outcome_name)
  let treatment = data.numeric(self.treatment_name)
  let n = instrument.length()
  // A binary instrument is detected by the number of distinct values.
  let unique_values : Array[Double] = []
  for value in instrument {
    let mut seen = false
    for other in unique_values {
      if other == value {
        seen = true
      }
    }
    if !seen {
      unique_values.push(value)
    }
  }
  let mut value = 0.0
  if unique_values.length() <= 2 {
    // The Wald estimator.
    let mut y1_sum = 0.0
    let mut y1_count = 0.0
    let mut y0_sum = 0.0
    let mut y0_count = 0.0
    let mut x1_sum = 0.0
    let mut x1_count = 0.0
    let mut x0_sum = 0.0
    let mut x0_count = 0.0
    for i = 0; i < n; i = i + 1 {
      if instrument[i] == 1.0 {
        y1_sum = y1_sum + outcome[i]
        y1_count = y1_count + 1.0
        x1_sum = x1_sum + treatment[i]
        x1_count = x1_count + 1.0
      } else if instrument[i] == 0.0 {
        y0_sum = y0_sum + outcome[i]
        y0_count = y0_count + 1.0
        x0_sum = x0_sum + treatment[i]
        x0_count = x0_count + 1.0
      }
    }
    let y1_z = y1_sum / y1_count
    let y0_z = y0_sum / y0_count
    let x1_z = x1_sum / x1_count
    let x0_z = x0_sum / x0_count
    value = (y1_z - y0_z) / (x1_z - x0_z)
  } else {
    value = @utils.cov(outcome, instrument) / @utils.cov(treatment, instrument)
  }
  let estimate = @model.CausalEstimate::new(
    value,
    self.treatment_name,
    self.outcome_name,
    self.target_estimand.identifier_method(),
    self.control_value,
    self.treatment_value,
  )
  estimate
}

///|
/// Fit the regression discontinuity estimator.
///
/// The data is restricted to the band around the threshold; inside the band
/// the estimator is an instrumental variable estimator whose instrument is the
/// running variable.
fn CausalEstimator::fit_regression_discontinuity(
  self : CausalEstimator,
  data : @api.DataFrame,
) -> Unit {
  let lower = self.rd_threshold_value - self.rd_bandwidth
  let upper = self.rd_threshold_value + self.rd_bandwidth
  let mask = data.mask_range(self.rd_variable_name, lower, upper)
  let filtered = data.filter(mask)
  let band = filtered.with_numeric(
    "local_rd_variable",
    filtered.numeric(self.rd_variable_name),
  )
  self.rd_local_data = Some(band)
  self.instrument_name = "local_rd_variable"
  self.adjustment_names = ["local_rd_variable"]
}

///|
/// The effect of the regression discontinuity estimator.
fn CausalEstimator::estimate_regression_discontinuity(
  self : CausalEstimator,
  data : @api.DataFrame,
  _target_units : String,
) -> @model.CausalEstimate {
  let band = match self.rd_local_data {
    Some(frame) => frame
    None => data
  }
  self.estimate_instrumental_variable(band)
}
