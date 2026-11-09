///|
/// The refuter that adds an unobserved common cause.
///
/// This is the port of the `direct-simulation` branch of
/// `dowhy.causal_refuters.add_unobserved_common_cause`: a simulated confounder
/// is drawn for every row, it is made to act on the treatment and on the
/// outcome with the strengths the caller gives, and the estimator is refitted on
/// the changed data. A refutation that works reports how far the estimate moves,
/// which is the sensitivity of the estimate to a confounder the data does not
/// hold.
///
/// The two effects are the ones of the upstream `_include_confounders_effect`:
///
/// * `linear` adds `kappa * w` to the treatment and `-kappa * w` to the outcome.
///   The sign of the outcome is negative on purpose: the confounder of the data
///   is assumed to have acted on both, so subtracting it from the outcome is
///   what removes its effect.
/// * `binary_flip` flips a value of the column with the probability the strength
///   describes. The strength is read as the probability of a flip, and the
///   values whose draw is beyond the edge of the central interval of the
///   standard normal that the probability spans are the ones that flip. A
///   strength of `0` flips nothing, a strength of `0.5` flips half of the rows
///   and a strength of `1` flips every row.
///
/// The upstream draws its confounder with the global generator of numpy and the
/// port draws it with the generator it is given, so the refuted effects of the
/// two are not the same numbers. What the upstream test asserts is unaffected:
/// with a strength of zero the data does not change at all, so the refuted
/// effect is the estimate of the data exactly.

///|
/// The kind of effect the simulated confounder has on the treatment.
pub enum ConfoundersEffectOnT {
  /// A value of the column is flipped with the probability the strength
  /// describes.
  BinaryFlip
  /// The strength times the confounder is added to the column.
  Linear
}

///|
/// A flipped value of the treatment.
pub fn ConfoundersEffectOnT::binary_flip() -> ConfoundersEffectOnT {
  BinaryFlip
}

///|
/// A linear effect on the treatment.
pub fn ConfoundersEffectOnT::linear() -> ConfoundersEffectOnT {
  Linear
}

///|
/// The kind of effect the simulated confounder has on the outcome.
pub enum ConfoundersEffectOnY {
  /// A value of the column is flipped with the probability the strength
  /// describes.
  BinaryFlip
  /// Minus the strength times the confounder is added to the column.
  Linear
}

///|
/// A flipped value of the outcome.
pub fn ConfoundersEffectOnY::binary_flip() -> ConfoundersEffectOnY {
  BinaryFlip
}

///|
/// A linear effect on the outcome.
pub fn ConfoundersEffectOnY::linear() -> ConfoundersEffectOnY {
  Linear
}

///|
/// The refuter that adds an unobserved common cause.
///
/// `kappa_t` is the strength of the confounder on the treatment and `kappa_y` the
/// strength on the outcome. The simulation is the one of the upstream: a single
/// confounder is drawn and a single refutation is reported, so there is no
/// interval to report besides the refuted effect itself.
pub fn refute_add_unobserved_common_cause(
  estimator : @estimators.CausalEstimator,
  estimand : @identifiers.IdentifiedEstimand,
  data : @api.DataFrame,
  treatment_name : String,
  outcome_name : String,
  kappa_t : Double,
  kappa_y : Double,
  treatment_value : Double,
  control_value : Double,
  target_units : String,
  random : @utils.Random,
  effect_on_t~ : ConfoundersEffectOnT = ConfoundersEffectOnT::binary_flip(),
  effect_on_y~ : ConfoundersEffectOnY = ConfoundersEffectOnY::linear(),
) -> CausalRefutation {
  let n = data.nrows()
  // One confounder per row, shared by the treatment and the outcome, the way the
  // upstream draws it.
  let confounder : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    confounder.push(random.next_normal())
  }
  let treatment = match effect_on_t {
    BinaryFlip =>
      flip_with_confounder(data.numeric(treatment_name), confounder, kappa_t)
    Linear => add_effect(data.numeric(treatment_name), confounder, kappa_t)
  }
  let outcome = match effect_on_y {
    BinaryFlip =>
      flip_with_confounder(data.numeric(outcome_name), confounder, kappa_y)
    Linear => add_effect(data.numeric(outcome_name), confounder, -kappa_y)
  }
  let changed = data.with_numeric(treatment_name, treatment)
  let changed = changed.with_numeric(outcome_name, outcome)
  let refutation = CausalRefutation::new(
    estimator
    .estimate_effect(data, treatment_value, control_value, target_units)
    .estimate(),
    reestimate(
      estimator, estimand, changed, treatment_value, control_value, target_units,
    ),
    "Refute: Add an Unobserved Common Cause",
  )
  // A simulation of a single confounder has no spread, so the interval of the
  // refutation is the refuted effect itself.
  refutation.new_effect_lower = refutation.new_effect
  refutation.new_effect_upper = refutation.new_effect
  refutation
}

///|
/// The values with the confounder added, weighted by the strength.
fn add_effect(
  values : Array[Double],
  confounder : Array[Double],
  strength : Double,
) -> Array[Double] {
  let out : Array[Double] = []
  for i = 0; i < values.length(); i = i + 1 {
    out.push(values[i] + strength * confounder[i])
  }
  out
}

///|
/// The values with the ones that the draw picks flipped.
///
/// The strength is the probability of a flip. The upstream builds the central
/// interval of the standard normal that the probability spans and takes its
/// lower edge when the probability is at least one half and its upper edge
/// otherwise. A strength of `0` spans the whole line, so the upper edge is
/// infinite and nothing flips; a strength of `0.5` gives the edge zero, so half
/// of the rows flip; a strength of `1` spans the whole line as well, so the lower
/// edge is negative infinity and every row flips. A value flips to one minus
/// itself, the way the upstream flips a column of zeros and ones.
fn flip_with_confounder(
  values : Array[Double],
  confounder : Array[Double],
  strength : Double,
) -> Array[Double] {
  let alpha = if strength >= 0.5 {
    2.0 * strength - 1.0
  } else {
    1.0 - 2.0 * strength
  }
  let lower = @utils.normal_ppf((1.0 - alpha) / 2.0)
  let upper = @utils.normal_ppf((1.0 + alpha) / 2.0)
  let edge = if strength >= 0.5 { lower } else { upper }
  let out : Array[Double] = []
  for i = 0; i < values.length(); i = i + 1 {
    if confounder[i] >= edge {
      out.push(1.0 - values[i])
    } else {
      out.push(values[i])
    }
  }
  out
}
