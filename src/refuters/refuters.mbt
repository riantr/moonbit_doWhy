/// The refutations of a causal estimate.
///
/// This is the port of `dowhy.causal_refuter.CausalRefutation` and of the
/// refuters in `dowhy.causal_refuters`.

///|
/// The result of one refutation.
pub struct CausalRefutation {
  /// The original estimate.
  estimated_effect : Double
  /// The estimate after the refutation.
  new_effect : Double
  /// The lower bound of the refuted estimates, when the refuter produces a
  /// range.
  mut new_effect_lower : Double
  /// The upper bound of the refuted estimates.
  mut new_effect_upper : Double
  /// The name of the refutation.
  refutation_type : String
  /// The p-value of the significance test, when the refuter computes one.
  p_value : Double
  /// Whether the refutation is statistically significant.
  is_significant : Bool
}

///|
/// A refutation without a significance test.
pub fn CausalRefutation::new(
  estimated_effect : Double,
  new_effect : Double,
  refutation_type : String,
) -> CausalRefutation {
  {
    estimated_effect,
    new_effect,
    new_effect_lower: new_effect,
    new_effect_upper: new_effect,
    refutation_type,
    p_value: 0.0,
    is_significant: false,
  }
}

///|
/// The original estimate.
pub fn CausalRefutation::estimated_effect(self : CausalRefutation) -> Double {
  self.estimated_effect
}

///|
/// The estimate after the refutation.
pub fn CausalRefutation::new_effect(self : CausalRefutation) -> Double {
  self.new_effect
}

///|
/// The lower bound of the refuted estimates.
pub fn CausalRefutation::new_effect_lower(self : CausalRefutation) -> Double {
  self.new_effect_lower
}

///|
/// The upper bound of the refuted estimates.
pub fn CausalRefutation::new_effect_upper(self : CausalRefutation) -> Double {
  self.new_effect_upper
}

///|
/// The name of the refutation.
pub fn CausalRefutation::refutation_type(self : CausalRefutation) -> String {
  self.refutation_type
}

///|
/// The p-value of the significance test.
pub fn CausalRefutation::p_value(self : CausalRefutation) -> Double {
  self.p_value
}

///|
/// Whether the refutation is statistically significant.
pub fn CausalRefutation::is_significant(self : CausalRefutation) -> Bool {
  self.is_significant
}

///|
/// A human readable summary of the refutation.
pub fn CausalRefutation::to_string(self : CausalRefutation) -> String {
  self.refutation_type +
  "\nEstimated effect:" +
  self.estimated_effect.to_string() +
  "\nNew effect:" +
  self.new_effect.to_string() +
  "\np value:" +
  self.p_value.to_string() +
  "\n"
}

///|
/// Re-estimate the effect on a new data frame.
///
/// This is the contract every refuter uses: a fresh estimator of the same
/// kind is fitted on the new data and the point estimate is returned.
fn reestimate(
  estimator : @estimators.CausalEstimator,
  estimand : @identifiers.IdentifiedEstimand,
  data : @api.DataFrame,
  treatment_value : Double,
  control_value : Double,
  target_units : String,
) -> Double {
  let new_estimator = estimator.with_estimand(estimand)
  new_estimator.fit(data, [])
  let estimate = new_estimator.estimate_effect(
    data, treatment_value, control_value, target_units,
  )
  estimate.estimate()
}

///|
/// The bootstrap refuter.
///
/// The data is resampled with replacement and the effect is re-estimated on
/// every resample; the refutation reports the mean of the resampled estimates
/// and the interval they span.
pub fn refute_bootstrap(
  estimator : @estimators.CausalEstimator,
  estimand : @identifiers.IdentifiedEstimand,
  data : @api.DataFrame,
  num_simulations : Int32,
  sample_size_fraction : Double,
  treatment_value : Double,
  control_value : Double,
  target_units : String,
  random : @utils.Random,
) -> CausalRefutation {
  let n = data.nrows()
  let sample_size = (sample_size_fraction * n.to_double()).to_int()
  let estimates : Array[Double] = []
  for i = 0; i < num_simulations; i = i + 1 {
    let rows = random.sample_with_replacement(index_column(n), sample_size)
    let resampled = take_rows(data, rows)
    let effect = reestimate(
      estimator, estimand, resampled, treatment_value, control_value, target_units,
    )
    estimates.push(effect)
  }
  let mean_effect = @utils.mean(estimates)
  let refutation = CausalRefutation::new(
    estimator
    .estimate_effect(data, treatment_value, control_value, target_units)
    .estimate(),
    mean_effect,
    "Refute: Bootstrap Sample Dataset",
  )
  let mut lower = mean_effect
  let mut upper = mean_effect
  if estimates.length() > 0 {
    lower = @utils.percentile(estimates, 2.5)
    upper = @utils.percentile(estimates, 97.5)
  }
  refutation.new_effect_lower = lower
  refutation.new_effect_upper = upper
  refutation
}

///|
/// The placebo treatment refuter.
///
/// The treatment is replaced by a random permutation of itself; a causal
/// estimate that survives the refutation is not credible.
pub fn refute_placebo_treatment(
  estimator : @estimators.CausalEstimator,
  estimand : @identifiers.IdentifiedEstimand,
  data : @api.DataFrame,
  treatment_name : String,
  num_simulations : Int32,
  treatment_value : Double,
  control_value : Double,
  target_units : String,
  random : @utils.Random,
) -> CausalRefutation {
  let treatment = data.numeric(treatment_name)
  let estimates : Array[Double] = []
  for i = 0; i < num_simulations; i = i + 1 {
    let placebo = random.shuffle(treatment)
    let placebo_data = data.with_numeric(treatment_name, placebo)
    let effect = reestimate(
      estimator, estimand, placebo_data, treatment_value, control_value, target_units,
    )
    estimates.push(effect)
  }
  let mean_effect = @utils.mean(estimates)
  let refutation = CausalRefutation::new(
    estimator
    .estimate_effect(data, treatment_value, control_value, target_units)
    .estimate(),
    mean_effect,
    "Refute: Use a Placebo Treatment",
  )
  refutation.new_effect_lower = @utils.percentile(estimates, 2.5)
  refutation.new_effect_upper = @utils.percentile(estimates, 97.5)
  refutation
}

///|
/// The data subset refuter.
///
/// The effect is re-estimated on random subsets of the data; a robust
/// estimate does not depend on the subset.
pub fn refute_data_subset(
  estimator : @estimators.CausalEstimator,
  estimand : @identifiers.IdentifiedEstimand,
  data : @api.DataFrame,
  subset_fraction : Double,
  num_simulations : Int32,
  treatment_value : Double,
  control_value : Double,
  target_units : String,
  random : @utils.Random,
) -> CausalRefutation {
  let n = data.nrows()
  let subset_size = (subset_fraction * n.to_double()).to_int()
  let estimates : Array[Double] = []
  for i = 0; i < num_simulations; i = i + 1 {
    let rows = random.sample_with_replacement(index_column(n), subset_size)
    let subset = take_rows(data, rows)
    let effect = reestimate(
      estimator, estimand, subset, treatment_value, control_value, target_units,
    )
    estimates.push(effect)
  }
  let mean_effect = @utils.mean(estimates)
  let refutation = CausalRefutation::new(
    estimator
    .estimate_effect(data, treatment_value, control_value, target_units)
    .estimate(),
    mean_effect,
    "Refute: Use a subset of data",
  )
  refutation.new_effect_lower = @utils.percentile(estimates, 2.5)
  refutation.new_effect_upper = @utils.percentile(estimates, 97.5)
  refutation
}

///|
/// The dummy outcome refuter.
///
/// The outcome is replaced by a random variable; the refuted effect must be
/// close to zero.
pub fn refute_dummy_outcome(
  estimator : @estimators.CausalEstimator,
  estimand : @identifiers.IdentifiedEstimand,
  data : @api.DataFrame,
  outcome_name : String,
  num_simulations : Int32,
  treatment_value : Double,
  control_value : Double,
  target_units : String,
  random : @utils.Random,
) -> CausalRefutation {
  let n = data.nrows()
  let estimates : Array[Double] = []
  for i = 0; i < num_simulations; i = i + 1 {
    let dummy : Array[Double] = []
    for i = 0; i < n; i = i + 1 {
      dummy.push(random.next_double())
    }
    let dummy_data = data.with_numeric(outcome_name, dummy)
    let effect = reestimate(
      estimator, estimand, dummy_data, treatment_value, control_value, target_units,
    )
    estimates.push(effect)
  }
  let mean_effect = @utils.mean(estimates)
  let refutation = CausalRefutation::new(
    0.0, mean_effect, "Refute: Use a Dummy Outcome",
  )
  refutation.new_effect_lower = @utils.percentile(estimates, 2.5)
  refutation.new_effect_upper = @utils.percentile(estimates, 97.5)
  refutation
}

///|
/// The random common cause refuter.
///
/// A random variable is added to the adjustment set; a robust estimate does
/// not change.
pub fn refute_random_common_cause(
  estimator : @estimators.CausalEstimator,
  _estimand : @identifiers.IdentifiedEstimand,
  data : @api.DataFrame,
  num_simulations : Int32,
  treatment_value : Double,
  control_value : Double,
  target_units : String,
  random : @utils.Random,
) -> CausalRefutation {
  let n = data.nrows()
  let estimates : Array[Double] = []
  for i = 0; i < num_simulations; i = i + 1 {
    let noise : Array[Double] = []
    for i = 0; i < n; i = i + 1 {
      noise.push(random.next_normal())
    }
    let noisy = data.with_numeric("random_common_cause", noise)
    let noisy_estimand = estimator
      .estimand()
      .with_adjustment_variables(
        estimator
        .estimand()
        .get_adjustment_set(estimator.estimand().identifier_method()) +
        ["random_common_cause"],
      )
    let effect = reestimate(
      estimator, noisy_estimand, noisy, treatment_value, control_value, target_units,
    )
    estimates.push(effect)
  }
  let mean_effect = @utils.mean(estimates)
  let refutation = CausalRefutation::new(
    estimator
    .estimate_effect(data, treatment_value, control_value, target_units)
    .estimate(),
    mean_effect,
    "Refute: Add a random common cause",
  )
  refutation.new_effect_lower = @utils.percentile(estimates, 2.5)
  refutation.new_effect_upper = @utils.percentile(estimates, 97.5)
  refutation
}

///|
/// The unobserved common cause refuter.
///
/// An unobserved confounder is simulated with the strength `epsilon` and the
/// effect is re-estimated; the refutation reports how much the estimate moves
/// when the confounder is strong.
pub fn refute_add_unobserved_common_cause(
  estimator : @estimators.CausalEstimator,
  estimand : @identifiers.IdentifiedEstimand,
  data : @api.DataFrame,
  treatment_name : String,
  outcome_name : String,
  epsilon : Double,
  num_simulations : Int32,
  treatment_value : Double,
  control_value : Double,
  target_units : String,
  random : @utils.Random,
) -> CausalRefutation {
  let n = data.nrows()
  let treatment = data.numeric(treatment_name)
  let outcome = data.numeric(outcome_name)
  let estimates : Array[Double] = []
  for i = 0; i < num_simulations; i = i + 1 {
    let confounder : Array[Double] = []
    for i = 0; i < n; i = i + 1 {
      confounder.push(random.next_normal())
    }
    let new_treatment : Array[Double] = []
    let new_outcome : Array[Double] = []
    for i = 0; i < n; i = i + 1 {
      new_treatment.push(treatment[i] + epsilon * confounder[i])
      new_outcome.push(outcome[i] - epsilon * confounder[i])
    }
    let noisy = data.with_numeric(treatment_name, new_treatment)
    let noisy = noisy.with_numeric(outcome_name, new_outcome)
    let effect = reestimate(
      estimator, estimand, noisy, treatment_value, control_value, target_units,
    )
    estimates.push(effect)
  }
  let mean_effect = @utils.mean(estimates)
  let refutation = CausalRefutation::new(
    estimator
    .estimate_effect(data, treatment_value, control_value, target_units)
    .estimate(),
    mean_effect,
    "Refute: Add an Unobserved Common Cause",
  )
  refutation.new_effect_lower = @utils.percentile(estimates, 2.5)
  refutation.new_effect_upper = @utils.percentile(estimates, 97.5)
  refutation
}

///|
/// A column with the row indices, used to resample the data.
fn index_column(n : Int32) -> Array[Double] {
  let indices : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    indices.push(i.to_double())
  }
  indices
}

///|
/// A data frame with the given rows, in the given order.
fn take_rows(data : @api.DataFrame, rows : Array[Double]) -> @api.DataFrame {
  let indices : Array[Int32] = []
  for row in rows {
    indices.push(row.to_int())
  }
  data.take_rows(indices)
}
