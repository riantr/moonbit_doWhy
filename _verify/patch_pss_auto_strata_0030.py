"""Add the automatic number of strata to the stratification estimator of the port.

The upstream takes the number of strata of the propensity score stratification
estimator from the string `"auto"`, which searches for the number of strata,
and the estimator test file of the upstream uses that default.
"""

p = r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\src\estimators\propensity_score.mbt"
s = open(p, encoding="utf-8", newline="").read()

old_start = "///|\n/// The effect of the propensity score stratification estimator."
old_end = "///|\n/// The effect of the doubly robust estimator."
i = s.find(old_start)
j = s.find(old_end)
assert i >= 0 and j > i, (i, j)

new = '''///|
/// The effect of the propensity score stratification estimator.
///
/// The units are grouped into strata of the propensity score and the effect is
/// computed inside every stratum before the strata are aggregated.
///
/// The number of strata is either given or searched for, the way the upstream
/// searches for it: the search starts with `0.5 * rows / clipping_threshold`
/// strata and halves the number until at least half of the strata hold more
/// than `clipping_threshold` units of both arms.
fn CausalEstimator::estimate_propensity_score_stratification(
  self : CausalEstimator,
  data : @api.DataFrame,
  target_units : String,
) -> @model.CausalEstimate {
  let ps = self.propensity_scores_of(data)
  let treatment = data.numeric(self.treatment_name)
  let outcome = data.numeric(self.outcome_name)
  let groups = match self.num_strata {
    NumStrata::Fixed(count) =>
      kept_strata(
        strata_groups(ps, count.to_double()),
        treatment,
        self.clipping_threshold,
      )
    NumStrata::Auto =>
      auto_strata_groups(ps, treatment, self.clipping_threshold)
  }
  // Aggregate every stratum.
  let mut total_treatment = 0.0
  let mut total_control = 0.0
  let mut att_sum = 0.0
  let mut atc_sum = 0.0
  let mut ate_sum = 0.0
  for group in groups {
    let mut t_sum = 0.0
    let mut dbar_sum = 0.0
    let mut d_y_sum = 0.0
    let mut dbar_y_sum = 0.0
    for row in group {
      let t = treatment[row]
      let y = outcome[row]
      t_sum = t_sum + t
      dbar_sum = dbar_sum + (1.0 - t)
      d_y_sum = d_y_sum + t * y
      dbar_y_sum = dbar_y_sum + (1.0 - t) * y
    }
    let d_y_mean = d_y_sum / t_sum
    let dbar_y_mean = dbar_y_sum / dbar_sum
    let effect = d_y_mean - dbar_y_mean
    total_treatment = total_treatment + t_sum
    total_control = total_control + dbar_sum
    att_sum = att_sum + effect * t_sum
    atc_sum = atc_sum + effect * dbar_sum
    ate_sum = ate_sum + effect * (dbar_sum + t_sum)
  }
  if total_treatment == 0.0 || total_control == 0.0 {
    abort(
      "Method requires strata with number of data points per treatment > clipping_threshold (=" +
      self.clipping_threshold.to_string() +
      "). No such strata exists. Consider decreasing \\'num_strata\\' or \\'clipping_threshold\\' parameters.",
    )
  }
  let value = match target_units {
    "att" => att_sum / total_treatment
    "atc" => atc_sum / total_control
    "ate" => ate_sum / (total_treatment + total_control)
    _ => abort("Target units string value not supported")
  }
  let estimate = @model.CausalEstimate::new(
    value,
    self.treatment_name,
    self.outcome_name,
    self.target_estimand.identifier_method(),
    self.control_value,
    self.treatment_value,
  )
  estimate.set_propensity_scores(ps)
  estimate
}

///|
/// The rows of every stratum of the data, sorted by the stratum.
///
/// The stratum of a row is the rounded rank of its propensity score, scaled by
/// the number of strata, the way the upstream computes it with the `rank`
/// method of pandas and the `round` method of numpy.
fn strata_groups(
  ps : Array[Double],
  num_strata : Double,
) -> Array[Array[Int32]] {
  let n = ps.length()
  let ranks = @utils.average_rank(ps)
  let keys : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    keys.push(@utils.round_half_even(ranks[i] / n.to_double() * num_strata))
  }
  let order : Array[Int32] = []
  for i = 0; i < n; i = i + 1 {
    order.push(i)
  }
  order.sort_by(fn(a, b) {
    let c = @utils.compare_double(keys[a], keys[b])
    if c != 0 {
      c
    } else if a < b {
      -1
    } else if a > b {
      1
    } else {
      0
    }
  })
  let groups : Array[Array[Int32]] = []
  let mut i = 0
  while i < n {
    let mut j = i
    while j + 1 < n && keys[order[j + 1]] == keys[order[i]] {
      j = j + 1
    }
    let group : Array[Int32] = []
    for k in i; k <= j; k = k + 1 {
      group.push(order[k])
    }
    groups.push(group)
    i = j + 1
  }
  groups
}

///|
/// The strata that hold more than `clipping_threshold` units of both arms.
///
/// A stratum is dropped when one of its arms holds fewer units than the
/// threshold, the way the upstream drops it with the `filter` of pandas.
fn kept_strata(
  groups : Array[Array[Int32]],
  treatment : Array[Double],
  clipping_threshold : Int32,
) -> Array[Array[Int32]] {
  let kept : Array[Array[Int32]] = []
  for group in groups {
    let mut treated_units = 0
    let mut control_units = 0
    for row in group {
      if treatment[row] == 1.0 {
        treated_units = treated_units + 1
      } else {
        control_units = control_units + 1
      }
    }
    let smaller = if treated_units < control_units {
      treated_units
    } else {
      control_units
    }
    if smaller > clipping_threshold {
      kept.push(group)
    }
  }
  kept
}

///|
/// The strata of the data, with the number of strata the upstream searches
/// for.
///
/// The search starts with `0.5 * rows / clipping_threshold` strata and halves
/// the number until at least half of the strata are kept, which is the rule of
/// the upstream.
fn auto_strata_groups(
  ps : Array[Double],
  treatment : Array[Double],
  clipping_threshold : Int32,
) -> Array[Array[Int32]] {
  let n = treatment.length()
  let mut num_strata = 0.5 * n.to_double() / clipping_threshold.to_double()
  let mut groups : Array[Array[Int32]] = []
  let mut found = false
  while !found {
    groups = kept_strata(
      strata_groups(ps, num_strata),
      treatment,
      clipping_threshold,
    )
    if groups.length().to_double() >= 0.5 * num_strata {
      found = true
    } else {
      num_strata = (num_strata / 2.0).to_int().to_double()
      if num_strata < 2.0 {
        abort(
          "Not enough data to generate at least two strata. This error may be due to a high value of \\'clipping_threshold\\'.",
        )
      }
    }
  }
  groups
}

'''

s = s[:i] + new + s[j:]
open(p, "w", encoding="utf-8", newline="").write(s)
print("patched")
