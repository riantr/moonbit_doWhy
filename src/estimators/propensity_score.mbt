/// The propensity score based estimators and the doubly robust estimator.

///|
/// The propensity scores of the data.
///
/// The scores are computed with the model and the encoder that were fitted
/// when the estimator was fitted, which is what the `predict_proba` method of
/// the upstream propensity score estimator does. The scores therefore follow
/// the rows of the data they are computed for, and the estimate does not
/// change when the rows of the data are permuted.
///
/// The scores are the raw ones. The upstream trims them only in the inverse
/// propensity score weighting estimator and in the doubly robust estimator,
/// and the two estimators trim them themselves.
fn CausalEstimator::propensity_scores_of(
  self : CausalEstimator,
  data : @api.DataFrame,
) -> Array[Double] {
  if data.has_column("propensity_score") {
    data.numeric("propensity_score")
  } else if self.propensity_beta.length() > 0 {
    let design = self.build_common_cause_design(data)
    @utils.logistic_predict(self.propensity_beta, design)
  } else {
    self.propensities.copy()
  }
}

///|
/// The propensity score, trimmed to the given bounds.
///
/// This is the `np.minimum` and the `np.maximum` of the upstream, which trim
/// the scores of the inverse propensity score weighting estimator and of the
/// doubly robust estimator.
fn clip_propensity_score(score : Double, low : Double, high : Double) -> Double {
  let mut value = score
  if value > high {
    value = high
  }
  if value < low {
    value = low
  }
  value
}

///|
/// The propensity scores, trimmed to the given bounds.
fn clip_propensity_scores(
  scores : Array[Double],
  low : Double,
  high : Double,
) -> Array[Double] {
  let clipped : Array[Double] = []
  for score in scores {
    clipped.push(clip_propensity_score(score, low, high))
  }
  clipped
}

///|
/// The effect of the inverse propensity score weighting estimator.
///
/// The scores are trimmed to the configured bounds before the weights are
/// computed, the way the upstream trims the score column of the data.
fn CausalEstimator::estimate_propensity_score_weighting(
  self : CausalEstimator,
  data : @api.DataFrame,
  target_units : String,
) -> @model.CausalEstimate {
  let ps = clip_propensity_scores(
    self.propensity_scores_of(data),
    self.min_ps_score,
    self.max_ps_score,
  )
  let treatment = data.numeric(self.treatment_name)
  let outcome = data.numeric(self.outcome_name)
  let n = treatment.length()
  let mut ipst_sum = 0.0
  let mut ipsc_sum = 0.0
  let mut ipst_for_att_sum = 0.0
  let mut ipsc_for_att_sum = 0.0
  let mut ipst_for_atc_sum = 0.0
  let mut ipsc_for_atc_sum = 0.0
  let mut treated_units = 0.0
  for i = 0; i < n; i = i + 1 {
    let t = treatment[i]
    let p = ps[i]
    let one_minus_t = 1.0 - t
    ipst_sum = ipst_sum + t / p
    ipsc_sum = ipsc_sum + one_minus_t / (1.0 - p)
    ipst_for_att_sum = ipst_for_att_sum + t
    ipsc_for_att_sum = ipsc_for_att_sum + one_minus_t / (1.0 - p) * p
    ipst_for_atc_sum = ipst_for_atc_sum + t / p * (1.0 - p)
    ipsc_for_atc_sum = ipsc_for_atc_sum + one_minus_t
    treated_units = treated_units + t
  }
  let p_treatment = treated_units / n.to_double()
  let scheme = match target_units {
    "ate" => self.weighting_scheme.name()
    "att" => "t" + self.weighting_scheme.name()
    "atc" => "c" + self.weighting_scheme.name()
    _ => abort("Target units value " + target_units + " not supported")
  }
  let weights : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    let t = treatment[i]
    let p = ps[i]
    let one_minus_t = 1.0 - t
    let weight = match scheme {
      "ips_weight" => t / p + one_minus_t / (1.0 - p)
      "tips_weight" => t + one_minus_t * p / (1.0 - p)
      "cips_weight" => t * (1.0 - p) / p + one_minus_t
      "ips_normalized_weight" =>
        t / p / ipst_sum + one_minus_t / (1.0 - p) / ipsc_sum
      "tips_normalized_weight" =>
        t / ipst_for_att_sum + one_minus_t * p / (1.0 - p) / ipsc_for_att_sum
      "cips_normalized_weight" =>
        t * (1.0 - p) / p / ipst_for_atc_sum + one_minus_t / ipsc_for_atc_sum
      "ips_stabilized_weight" =>
        t / p * p_treatment + one_minus_t / (1.0 - p) * (1.0 - p_treatment)
      "tips_stabilized_weight" =>
        t * p_treatment + one_minus_t * p / (1.0 - p) * (1.0 - p_treatment)
      "cips_stabilized_weight" =>
        t * (1.0 - p) / p * p_treatment + one_minus_t * (1.0 - p_treatment)
      _ => abort("Unknown weighting scheme " + scheme)
    }
    weights.push(weight)
  }
  let mut sum_dy = 0.0
  let mut sum_dbary = 0.0
  let mut sum_dy_weights = 0.0
  let mut sum_dbary_weights = 0.0
  for i = 0; i < n; i = i + 1 {
    let t = treatment[i]
    let y = outcome[i]
    let w = weights[i]
    sum_dy = sum_dy + w * t * y
    sum_dbary = sum_dbary + w * (1.0 - t) * y
    sum_dy_weights = sum_dy_weights + w * t
    sum_dbary_weights = sum_dbary_weights + w * (1.0 - t)
  }
  let value = sum_dy / sum_dy_weights - sum_dbary / sum_dbary_weights
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
/// The effect of the propensity score matching estimator.
///
/// Every treated unit is matched with the control unit whose propensity score
/// is closest; ties are broken by the order of the rows, exactly like the
/// nearest neighbour search of `scikit-learn`.
fn CausalEstimator::estimate_propensity_score_matching(
  self : CausalEstimator,
  data : @api.DataFrame,
  target_units : String,
) -> @model.CausalEstimate {
  let ps = self.propensity_scores_of(data)
  let treatment = data.numeric(self.treatment_name)
  let outcome = data.numeric(self.outcome_name)
  let n = treatment.length()
  let treated : Array[Int32] = []
  let control : Array[Int32] = []
  for i = 0; i < n; i = i + 1 {
    if treatment[i] == 1.0 {
      treated.push(i)
    } else if treatment[i] == 0.0 {
      control.push(i)
    }
  }
  if treated.length() == 0 || control.length() == 0 {
    abort(
      "The propensity score matching estimator needs both treated and control units",
    )
  }
  // The average treatment effect on the treated.
  //
  // Every treated unit is matched with the control unit whose propensity score
  // is the closest.  The control units are sorted by their score once and
  // every match is a binary search over that order, so a match costs
  // `O(log n)` instead of a scan over every control unit.
  let control_order = sorted_by_score(ps, control)
  let control_groups = equal_score_groups(control_order, ps)
  let mut att_sum = 0.0
  for row in treated {
    let best = nearest_score(control_order, control_groups, ps, ps[row])
    att_sum = att_sum + outcome[row] - outcome[best]
  }
  let att = att_sum / treated.length().to_double()
  // The average treatment effect on the control.
  let treated_order = sorted_by_score(ps, treated)
  let treated_groups = equal_score_groups(treated_order, ps)
  let mut atc_sum = 0.0
  for row in control {
    let best = nearest_score(treated_order, treated_groups, ps, ps[row])
    atc_sum = atc_sum + outcome[best] - outcome[row]
  }
  let atc = atc_sum / control.length().to_double()
  let value = match target_units {
    "att" => att
    "atc" => atc
    "ate" =>
      (att * treated.length().to_double() + atc * control.length().to_double()) /
      (treated.length() + control.length()).to_double()
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
/// The units of the given list, sorted by their propensity score.
///
/// The units that hold the same score are ordered by their index, so the first
/// unit of a group of equal scores is the one with the smallest index.
fn sorted_by_score(ps : Array[Double], units : Array[Int32]) -> Array[Int32] {
  let order = units.copy()
  order.sort_by(fn(a, b) {
    let c = @utils.compare_double(ps[a], ps[b])
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
  order
}

///|
/// The first position of the group of equal scores of every unit.
///
/// The units of a group hold the same propensity score, so they all are at the
/// same distance from a score, and the unit with the smallest index of the
/// group is the one a scan over the units would pick.
fn equal_score_groups(order : Array[Int32], ps : Array[Double]) -> Array[Int32] {
  let m = order.length()
  let groups : Array[Int32] = []
  let mut i = 0
  while i < m {
    let mut j = i
    while j + 1 < m && ps[order[j + 1]] == ps[order[i]] {
      j = j + 1
    }
    for k = i; k <= j; k = k + 1 {
      groups.push(i)
    }
    i = j + 1
  }
  groups
}

///|
/// The unit whose propensity score is the closest to the given score.
///
/// The units of the search are sorted by their score, so the closest one is
/// either the unit below the score or the unit above it.  A tie is broken
/// with the index of the unit, which is the rule of a scan over the units: the
/// first unit with the smallest distance wins.
fn nearest_score(
  order : Array[Int32],
  groups : Array[Int32],
  ps : Array[Double],
  value : Double,
) -> Int32 {
  let m = order.length()
  // The first unit whose score is not smaller than the value.
  let mut lo = 0
  let mut hi = m
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    if ps[order[mid]] < value {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  let pos = lo
  let below = if pos > 0 { order[groups[pos - 1]] } else { -1 }
  let above = if pos < m { order[groups[pos]] } else { -1 }
  if below < 0 {
    return above
  }
  if above < 0 {
    return below
  }
  let below_distance = value - ps[below]
  let above_distance = ps[above] - value
  if below_distance < above_distance {
    below
  } else if above_distance < below_distance {
    above
  } else if below < above {
    below
  } else {
    above
  }
}

///|
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
      "). No such strata exists. Consider decreasing \'num_strata\' or \'clipping_threshold\' parameters.",
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
    for k = i; k <= j; k = k + 1 {
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
          "Not enough data to generate at least two strata. This error may be due to a high value of \'clipping_threshold\'.",
        )
      }
    }
  }
  groups
}

///|
/// The effect of the doubly robust estimator.
///
/// The estimator combines the outcome regression with the inverse propensity
/// score, so it is consistent when either of the two models is correct.
///
/// For every treatment value `t` the upstream code computes
///
/// ```text
/// Y_dr(t) = E[Y | X, T = t] + (Y - E[Y | X, T = t]) / Pr[T = t | X] * 1{T = t}
/// ```
///
/// and averages it over every row; the effect is the difference of the two
/// averages.
fn CausalEstimator::estimate_doubly_robust(
  self : CausalEstimator,
  data : @api.DataFrame,
  target_units : String,
) -> @model.CausalEstimate {
  if target_units != "ate" {
    abort(
      "ATE is the only target unit supported for the doubly robust estimator",
    )
  }
  let treatment = data.numeric(self.treatment_name)
  let outcome = data.numeric(self.outcome_name)
  let n = treatment.length()
  // The upstream trims the scores of the arm the unit belongs to, and the two
  // arms are trimmed separately: the score of the control arm is the
  // probability of the control class, not the complement of the trimmed score
  // of the treated arm.
  let raw = self.propensity_scores_of(data)
  let ps = clip_propensity_scores(raw, self.min_ps_score, self.max_ps_score)
  let ps_control : Array[Double] = []
  for score in raw {
    ps_control.push(
      clip_propensity_score(1.0 - score, self.min_ps_score, self.max_ps_score),
    )
  }
  for score in ps {
    if score <= 0.0 {
      abort(
        "Propensity scores must be strictly positive for doubly robust estimation.",
      )
    }
  }
  for score in ps_control {
    if score <= 0.0 {
      abort(
        "Propensity scores must be strictly positive for doubly robust estimation.",
      )
    }
  }
  let treated_outcomes = self.interventional_outcomes(
    data,
    self.treatment_value,
  )
  let control_outcomes = self.interventional_outcomes(data, self.control_value)
  let mut treated_sum = 0.0
  let mut control_sum = 0.0
  for i = 0; i < n; i = i + 1 {
    let t = treatment[i]
    let y = outcome[i]
    // The propensity score of the arm the unit actually received.
    let ps_treated = ps[i]
    let ps_control = ps_control[i]
    let treated_value = treated_outcomes[i]
    let control_value = control_outcomes[i]
    // The treated arm.
    let mut treated = treated_value
    if t == self.treatment_value {
      treated = treated + (y - treated_value) / ps_treated
    }
    treated_sum = treated_sum + treated
    // The control arm.
    let mut control = control_value
    if t == self.control_value {
      control = control + (y - control_value) / ps_control
    }
    control_sum = control_sum + control
  }
  let value = treated_sum / n.to_double() - control_sum / n.to_double()
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
