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
  mut p_value : Double
  /// Whether the refutation is statistically significant.
  mut is_significant : Bool
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
/// The kind of test the significance test of a refutation uses.
pub enum SignificanceTestType {
  /// The bootstrap test for a hundred simulations and more, the test of the
  /// normal distribution below that.
  Auto
  /// The two sided percentile test of the bootstrap.
  Bootstrap
  /// The test of the normal distribution.
  Normal
}

///|
/// The automatic kind of test.
pub fn SignificanceTestType::auto() -> SignificanceTestType {
  SignificanceTestType::Auto
}

///|
/// The two sided percentile test of the bootstrap.
pub fn SignificanceTestType::bootstrap() -> SignificanceTestType {
  SignificanceTestType::Bootstrap
}

///|
/// The test of the normal distribution.
pub fn SignificanceTestType::normal() -> SignificanceTestType {
  SignificanceTestType::Normal
}

///|
/// The p-value of the significance test of a refutation and whether the
/// estimate is significant at the given level.
///
/// This is the port of `test_significance` of `dowhy.causal_refuter`: the
/// estimate is tested against the distribution of the estimates the refuter
/// produced. The refutations that sever the causal relation test the zero
/// estimate against it, the ones that leave the relation alone test the
/// estimate of the data against it.
pub fn test_significance(
  estimate : Double,
  simulations : Array[Double],
  test_type~ : SignificanceTestType = SignificanceTestType::auto(),
  significance_level~ : Double = 0.05,
) -> (Double, Bool) {
  let p_value = match test_type {
    SignificanceTestType::Auto =>
      if simulations.length() >= 100 {
        bootstrap_significance(estimate, simulations)
      } else {
        normal_significance(estimate, simulations)
      }
    SignificanceTestType::Bootstrap =>
      bootstrap_significance(estimate, simulations)
    SignificanceTestType::Normal => normal_significance(estimate, simulations)
  }
  (p_value, p_value <= significance_level)
}

///|
/// The two sided percentile p-value of the bootstrap test.
///
/// A refuter that ran no simulation has no distribution to test the estimate
/// against, so the p-value is one.  The upstream computes the mean and the
/// standard deviation of the simulations with numpy, which returns `nan` for an
/// empty array, so its p-value is `nan` in that case.
fn bootstrap_significance(
  estimate : Double,
  simulations : Array[Double],
) -> Double {
  if simulations.length() == 0 {
    return 1.0
  }
  let mut half = 0.0
  for value in simulations {
    if value > estimate {
      half = half + 1.0
    } else if value == estimate {
      half = half + 0.5
    }
  }
  half = half / simulations.length().to_double()
  let other = 1.0 - half
  if half < other {
    2.0 * half
  } else {
    2.0 * other
  }
}

///|
/// The p-value of the test of the normal distribution.
fn normal_significance(
  estimate : Double,
  simulations : Array[Double],
) -> Double {
  if simulations.length() == 0 {
    return 1.0
  }
  let mean = @utils.mean(simulations)
  let deviation = @utils.variance(simulations, 0).sqrt()
  let z_score = (estimate - mean) / deviation
  if z_score > 0.0 {
    1.0 - @utils.normal_cdf(z_score)
  } else {
    @utils.normal_cdf(z_score)
  }
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
  let (p_value, significant) = test_significance(
    estimator
    .estimate_effect(data, treatment_value, control_value, target_units)
    .estimate(),
    estimates,
  )
  refutation.p_value = p_value
  refutation.is_significant = significant
  refutation
}

///|
/// The kind of placebo the placebo treatment refuter builds.
pub enum PlaceboType {
  /// A random variable of the kind the treatment column asks for.
  RandomData
  /// The rows of the treatment, permuted.
  Permute
}

///|
/// The random data placebo: the treatment is replaced by a random variable.
pub fn PlaceboType::random_data() -> PlaceboType {
  PlaceboType::RandomData
}

///|
/// The permuted placebo: the rows of the treatment are permuted.
pub fn PlaceboType::permute() -> PlaceboType {
  PlaceboType::Permute
}

///|
/// The placebo treatment refuter.
///
/// The treatment is replaced by a placebo variable and the effect is estimated
/// again on every simulation; a causal estimate that survives the refutation is
/// not credible.
///
/// The random data placebo builds the placebo the way the upstream does: a
/// continuous treatment becomes a constant zero, a binary treatment becomes a
/// random draw of a Bernoulli variable with the probability of a half, and a
/// categorical treatment becomes a random draw of one of its categories. The
/// permuted placebo takes the rows of the treatment and permutes them.
///
/// The upstream reports the error it raises for the instrumental variable
/// method with the random data placebo; MoonBit cannot catch an error, so the
/// port aborts with the message of the upstream.
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
  placebo_type~ : PlaceboType = PlaceboType::random_data(),
) -> CausalRefutation {
  let identifier = estimand.identifier_method()
  if identifier == "iv" && !is_permute(placebo_type) {
    abort(
      "Only placebo_type='permute' is supported for creating placebo for instrumental variable estimation methods.",
    )
  }
  let n = data.nrows()
  let kind = treatment_kind(data, treatment_name)
  let instrument = if identifier == "iv" {
    Some(estimator.instrument_name())
  } else {
    None
  }
  let estimates : Array[Double] = []
  for i = 0; i < num_simulations; i = i + 1 {
    // The permuted placebo permutes the rows of the treatment; the random
    // data placebo draws a new value for every row.
    let permutation = if is_permute(placebo_type) {
      random.shuffle(index_column(n))
    } else {
      index_column(n)
    }
    let mut placebo_data = data
    match kind {
      TreatmentKind::Categorical => {
        // The permuted placebo takes the rows of the treatment and permutes
        // them; the random data placebo draws one of the categories of the
        // treatment for every row.
        let values = if is_permute(placebo_type) {
          permute_categories(data.discrete(treatment_name), permutation)
        } else {
          placebo_categories(
            distinct_categories(data.discrete(treatment_name)),
            random,
            n,
          )
        }
        placebo_data = placebo_data.with_discrete("placebo", values)
      }
      TreatmentKind::Binary => {
        let values = if is_permute(placebo_type) {
          permute_values(data.numeric(treatment_name), permutation)
        } else {
          placebo_binary(random, n)
        }
        placebo_data = placebo_data.with_numeric("placebo", values)
      }
      TreatmentKind::Continuous => {
        let values = if is_permute(placebo_type) {
          permute_values(data.numeric(treatment_name), permutation)
        } else {
          placebo_constant(random, n)
        }
        placebo_data = placebo_data.with_numeric("placebo", values)
      }
    }
    // The instrumental variable method replaces its instrument as well; the
    // upstream renames it after the placebo and permutes it with the same
    // permutation.
    let mut placebo_estimand = estimand.with_treatment(["placebo"])
    let mut placebo_estimator = estimator
    match instrument {
      Some(name) => {
        let values = permute_values(data.numeric(name), permutation)
        placebo_data = placebo_data.with_numeric("placebo_" + name, values)
        placebo_estimand = placebo_estimand.with_instrumental_variables([
          "placebo_" + name,
        ])
        placebo_estimator = estimator.with_instrument_name("placebo_" + name)
      }
      None => ()
    }
    let effect = reestimate(
      placebo_estimator, placebo_estimand, placebo_data, treatment_value, control_value,
      target_units,
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
  // The upstream tests the zero estimate against the estimates of the
  // refutation, because the placebo severs the causal relation.
  let (p_value, significant) = test_significance(0.0, estimates)
  refutation.p_value = p_value
  refutation.is_significant = significant
  refutation
}

///|
/// Whether the placebo is the permuted one.
///
/// The enumeration of the placebo type carries no `Eq` implementation, so the
/// comparison is a match.
fn is_permute(placebo_type : PlaceboType) -> Bool {
  match placebo_type {
    PlaceboType::Permute => true
    PlaceboType::RandomData => false
  }
}

///|
/// The kind of the treatment column of the placebo refuter.
///
/// The upstream keys the placebo on the dtype of the column: a float becomes a
/// constant zero, a bool becomes a random Bernoulli variable, an int becomes a
/// random integer and a category becomes a random draw of one of its
/// categories. The frame of the port holds no dtype, so the port recognises
/// the binary treatment by its two values, which is what the data set of the
/// upstream holds for one.
priv enum TreatmentKind {
  Continuous
  Binary
  Categorical
}

///|
/// The kind of the treatment column of the placebo refuter.
fn treatment_kind(
  data : @api.DataFrame,
  treatment_name : String,
) -> TreatmentKind {
  if data.is_discrete(treatment_name) {
    return TreatmentKind::Categorical
  }
  let values = data.numeric(treatment_name)
  let mut binary = true
  for value in values {
    if value != 0.0 && value != 1.0 {
      binary = false
    }
  }
  if binary && values.length() > 0 {
    TreatmentKind::Binary
  } else {
    TreatmentKind::Continuous
  }
}

///|
/// The placebo of a binary treatment: a Bernoulli variable with the
/// probability of a half, the way the upstream draws it.
fn placebo_binary(random : @utils.Random, n : Int32) -> Array[Double] {
  let values : Array[Double] = []
  for _ in 0..<n {
    values.push(if random.next_double() < 0.5 { 0.0 } else { 1.0 })
  }
  values
}

///|
/// The placebo of a continuous treatment: the constant zero, the way the
/// upstream draws it with a normal distribution of a mean of zero and a
/// standard deviation of zero.
fn placebo_constant(random : @utils.Random, n : Int32) -> Array[Double] {
  let values : Array[Double] = []
  for _ in 0..<n {
    values.push(random.next_double() * 0.0)
  }
  values
}

///|
/// The placebo of a categorical treatment: a random draw of one of its
/// categories, the way the upstream draws it.
fn placebo_categories(
  categories : Array[String],
  random : @utils.Random,
  n : Int32,
) -> Array[String] {
  let values : Array[String] = []
  for _ in 0..<n {
    if categories.length() == 0 {
      values.push("")
    } else {
      values.push(categories[random.next_int(categories.length())])
    }
  }
  values
}

///|
/// The distinct values of a discrete column, in the order of their first
/// appearance.
///
/// The upstream draws the random placebo of a categorical treatment from the
/// distinct categories of its column, and not from its rows, so a category
/// that holds more rows is not drawn more often.
fn distinct_categories(values : Array[String]) -> Array[String] {
  let categories : Array[String] = []
  for value in values {
    let mut found = false
    for category in categories {
      if category == value {
        found = true
      }
    }
    if !found {
      categories.push(value)
    }
  }
  categories
}

///|
/// The values of a discrete column in the order of the given permutation of
/// the rows.
fn permute_categories(
  values : Array[String],
  permutation : Array[Double],
) -> Array[String] {
  let out : Array[String] = []
  for row in permutation {
    out.push(values[row.to_int()])
  }
  out
}

///|
/// The values of a column in the order of the given permutation of the rows.
fn permute_values(
  values : Array[Double],
  permutation : Array[Double],
) -> Array[Double] {
  let out : Array[Double] = []
  for row in permutation {
    out.push(values[row.to_int()])
  }
  out
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
  let (p_value, significant) = test_significance(
    estimator
    .estimate_effect(data, treatment_value, control_value, target_units)
    .estimate(),
    estimates,
  )
  refutation.p_value = p_value
  refutation.is_significant = significant
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
  // The dummy outcome severs the causal relation, so the zero estimate is the
  // one the refutation tests against the estimates it produced.
  let (p_value, significant) = test_significance(0.0, estimates)
  refutation.p_value = p_value
  refutation.is_significant = significant
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
  let (p_value, significant) = test_significance(
    estimator
    .estimate_effect(data, treatment_value, control_value, target_units)
    .estimate(),
    estimates,
  )
  refutation.p_value = p_value
  refutation.is_significant = significant
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
