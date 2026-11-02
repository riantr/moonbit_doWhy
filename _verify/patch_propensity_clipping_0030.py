"""Patch the propensity score estimators of the port.

The upstream trims the propensity scores only in the inverse propensity score
weighting estimator and in the doubly robust estimator.  The port trimmed them
in every estimator, which changed the strata of the stratification estimator
and the matches of the matching estimator.
"""

p = r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\src\estimators\propensity_score.mbt"
s = open(p, encoding="utf-8", newline="").read()


def replace(old, new, count=1):
    global s
    assert s.count(old) == count, (s.count(old), old[:80])
    s = s.replace(old, new)


# 1. The raw scores.
replace(
    """///|
/// The propensity scores of the data, clipped to the configured bounds.
///
/// The scores are computed with the model and the encoder that were fitted
/// when the estimator was fitted, which is what the `predict_proba` method of
/// the upstream propensity score estimator does. The scores therefore follow
/// the rows of the data they are computed for, and the estimate does not
/// change when the rows of the data are permuted.
fn CausalEstimator::propensity_scores_of(
  self : CausalEstimator,
  data : @api.DataFrame,
) -> Array[Double] {
  let scores = if data.has_column("propensity_score") {
    data.numeric("propensity_score")
  } else if self.propensity_beta.length() > 0 {
    let design = self.build_common_cause_design(data)
    @utils.logistic_predict(self.propensity_beta, design)
  } else {
    self.propensities.copy()
  }
  let clipped : Array[Double] = []
  for score in scores {
    let mut value = score
    if value > self.max_ps_score {
      value = self.max_ps_score
    }
    if value < self.min_ps_score {
      value = self.min_ps_score
    }
    clipped.push(value)
  }
  clipped
}
""",
    """///|
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
fn clip_propensity_score(
  score : Double,
  low : Double,
  high : Double,
) -> Double {
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
""",
)

# 2. The weighting estimator trims the scores itself.
replace(
    """///|
/// The effect of the inverse propensity score weighting estimator.
fn CausalEstimator::estimate_propensity_score_weighting(
  self : CausalEstimator,
  data : @api.DataFrame,
  target_units : String,
) -> @model.CausalEstimate {
  let ps = self.propensity_scores_of(data)
""",
    """///|
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
""",
)

# 3. The doubly robust estimator trims the scores of the two arms itself.
replace(
    """  let treatment = data.numeric(self.treatment_name)
  let outcome = data.numeric(self.outcome_name)
  let n = treatment.length()
  let ps = self.propensity_scores_of(data)
  let treated_outcomes = self.interventional_outcomes(
""",
    """  let treatment = data.numeric(self.treatment_name)
  let outcome = data.numeric(self.outcome_name)
  let n = treatment.length()
  // The upstream trims the scores of the arm the unit belongs to, and the two
  // arms are trimmed separately: the score of the control arm is the
  // probability of the control class, not the complement of the trimmed score
  // of the treated arm.
  let raw = self.propensity_scores_of(data)
  let ps = clip_propensity_scores(raw, self.min_ps_score, self.max_ps_score)
  let mut ps_control : Array[Double] = []
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
""",
)

replace(
    """    // The propensity score of the arm the unit actually received.
    let ps_treated = ps[i]
    let ps_control = 1.0 - ps[i]
""",
    """    // The propensity score of the arm the unit actually received.
    let ps_treated = ps[i]
    let ps_control = ps_control[i]
""",
)

open(p, "w", encoding="utf-8", newline="").write(s)
print("patched")
