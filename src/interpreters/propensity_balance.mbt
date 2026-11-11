/// The balance of the common causes of an estimate.
///
/// This is the port of
/// `dowhy.interpreters.propensity_balance_interpreter.PropensityBalanceInterpreter`.
/// The upstream draws a line of the standardized mean difference of every
/// common cause, before and after the adjustment of the strata, and it returns
/// the frame it plots. The port returns the numbers of that frame.

///|
/// The balance of one common cause.
///
/// The two differences are the standardized mean differences of the common
/// cause, without the strata and with them.
pub struct BalanceRow {
  /// The name of the common cause.
  name : String
  /// The standardized mean difference without the strata.
  unadjusted : Double
  /// The standardized mean difference with the strata.
  adjusted : Double
}

///|
/// The name of the common cause.
pub fn BalanceRow::common_cause(self : BalanceRow) -> String {
  self.name
}

///|
/// The standardized mean difference without the strata.
pub fn BalanceRow::unadjusted_difference(self : BalanceRow) -> Double {
  self.unadjusted
}

///|
/// The standardized mean difference with the strata.
pub fn BalanceRow::adjusted_difference(self : BalanceRow) -> Double {
  self.adjusted
}

///|
/// The balance of the common causes of the estimate.
///
/// This is the port of the `interpret` method of the propensity balance
/// interpreter of the upstream. The upstream takes the difference of the two
/// means of a common cause as the difference of the largest and the smallest
/// of them, so its standardized mean differences are the absolute differences.
///
/// The upstream takes the strata of the data from the column that the
/// propensity score stratification estimator adds to the data, and the port
/// computes them with the number of the strata of the estimator.
pub fn propensity_balance_interpretation(
  estimate : @model.CausalEstimate,
  estimator : @estimators.CausalEstimator,
  data : @api.DataFrame,
) -> Array[BalanceRow] {
  let treatment = data.numeric(estimate.treatment_name())
  let strata = estimator.strata_labels(data)
  let rows : Array[BalanceRow] = []
  for name in estimator.adjustment_set() {
    let values = data.numeric(name)
    rows.push({
      name,
      unadjusted: unadjusted_difference(values, treatment),
      adjusted: adjusted_difference(values, treatment, strata),
    })
  }
  rows
}

///|
/// The standardized mean difference of a common cause, without the strata.
///
/// The difference is the difference of the two means of the common cause, the
/// mean of the treated arm and the mean of the control arm, divided by the
/// standard deviation of the common cause over every row.
fn unadjusted_difference(
  values : Array[Double],
  treatment : Array[Double],
) -> Double {
  let n = values.length()
  let mut treated_sum = 0.0
  let mut treated_count = 0.0
  let mut control_sum = 0.0
  let mut control_count = 0.0
  for i = 0; i < n; i = i + 1 {
    if treatment[i] == 1.0 {
      treated_sum = treated_sum + values[i]
      treated_count = treated_count + 1.0
    } else if treatment[i] == 0.0 {
      control_sum = control_sum + values[i]
      control_count = control_count + 1.0
    }
  }
  if treated_count == 0.0 || control_count == 0.0 {
    return 0.0
  }
  let treated_mean = treated_sum / treated_count
  let control_mean = control_sum / control_count
  let deviation = @utils.std(values)
  if deviation == 0.0 {
    return 0.0
  }
  (treated_mean - control_mean).abs() / deviation
}

///|
/// The standardized mean difference of a common cause, with the strata.
///
/// The difference of every stratum is the difference of the two means of the
/// stratum, divided by the standard deviation of the common cause over the
/// rows of the stratum, and scaled by the number of the rows of the stratum
/// over the number of the rows of the data. The differences of the strata are
/// then summed.
fn adjusted_difference(
  values : Array[Double],
  treatment : Array[Double],
  strata : Array[Int32],
) -> Double {
  let n = values.length()
  let labels = sorted_labels(strata)
  let mut total = 0.0
  for label in labels {
    let mut treated_sum = 0.0
    let mut treated_count = 0.0
    let mut control_sum = 0.0
    let mut control_count = 0.0
    let stratum : Array[Double] = []
    for i = 0; i < n; i = i + 1 {
      if strata[i] != label {
        continue
      }
      stratum.push(values[i])
      if treatment[i] == 1.0 {
        treated_sum = treated_sum + values[i]
        treated_count = treated_count + 1.0
      } else if treatment[i] == 0.0 {
        control_sum = control_sum + values[i]
        control_count = control_count + 1.0
      }
    }
    if stratum.length() == 0 || treated_count == 0.0 || control_count == 0.0 {
      continue
    }
    let treated_mean = treated_sum / treated_count
    let control_mean = control_sum / control_count
    let deviation = @utils.std(stratum)
    if deviation == 0.0 {
      continue
    }
    let scaled = (treated_mean - control_mean).abs() /
      deviation *
      stratum.length().to_double() /
      n.to_double()
    total = total + scaled
  }
  total
}

///|
/// The distinct strata of the data, in the order of their labels.
fn sorted_labels(strata : Array[Int32]) -> Array[Int32] {
  let labels : Array[Int32] = []
  for label in strata {
    if !labels.contains(label) {
      labels.push(label)
    }
  }
  labels.sort_by(fn(a, b) { if a < b { -1 } else if a > b { 1 } else { 0 } })
  labels
}
