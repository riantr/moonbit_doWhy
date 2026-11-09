///| Tests for the refuter that adds an unobserved common cause.
///
/// The cases mirror `tests/causal_refuters/test_add_unobserved_common_cause.py`,
/// which runs its two refutation cases through the `SimpleRefuter` harness of
/// `tests/causal_refuters/base.py`. The harness makes two calls per case:
///
/// 1. one with the strengths of the case, which it only has to survive — the
///    upstream asserts nothing about the effect it reports,
/// 2. one with both strengths set to zero, after which it asserts
///    `abs(refute.new_effect - ate.value) < abs(ate.value) * error_tolerance`,
///    because a confounder of strength zero changes no value of the data.
///
/// The mirrored cases, with the strengths and the estimator of the upstream:
///
/// * `test_refutation_binary_treatment` — the propensity score matching
///   estimator, a binary treatment, `binary_flip` on the treatment and `linear`
///   on the outcome, strengths `0.01` and `0.02`, tolerance `0.01`.
/// * `test_refutation_continuous_treatment` — the instrumental variable
///   estimator, a continuous treatment, `linear` on both, strengths `0.01` and
///   `0.02`, tolerance `0.01`.
///
/// The cases that are not mirrored:
///
/// * The three `..._range_...` cases, which pass a list of strengths and draw a
///   matrix of refutations for a plot. The port has no plotting, and the matrix
///   path of the upstream reports no number a test could assert.
/// * `test_linear_sensitivity_with_confounders` and
///   `test_linear_sensitivity_given_strength_of_confounding`, which exercise the
///   sensitivity analyzers (`simulation_method` other than `direct-simulation`).
///   The port does not have them yet.
///
/// The rows are 20000 rather than the 100000 of the upstream suite: the assertion
/// is exact — a confounder of strength zero leaves the data alone, so the refuted
/// effect is the estimate of the data down to the last bit — and the four
/// backends of the gate would not finish the larger fixture.

///|
/// The dataset of the binary treatment case: one common cause, a binary
/// treatment and no instrument.
fn unobserved_binary_dataset(num_samples : Int32) -> @datasets.Dataset {
  @datasets.linear_dataset(
    SEED,
    num_samples,
    @datasets.LinearConfig::confounded(),
  )
}

///|
/// The dataset of the continuous treatment case: one common cause, one
/// instrument and a continuous treatment.
fn unobserved_continuous_dataset(num_samples : Int32) -> @datasets.Dataset {
  @datasets.linear_dataset(
    SEED,
    num_samples,
    @datasets.LinearConfig::new(
      num_common_causes=1,
      num_instruments=1,
      treatment_is_binary=false,
    ),
  )
}

///|
/// The propensity score matching estimator of the dataset, fitted on it.
fn unobserved_psm(dataset : @datasets.Dataset) -> @estimators.CausalEstimator {
  let estimator = @estimators.CausalEstimator::propensity_score_matching(
    backdoor_estimand(dataset),
  )
  estimator.fit(dataset.frame(), [])
  estimator
}

///|
/// The instrumental variable estimator of the dataset, fitted on it.
fn unobserved_iv(dataset : @datasets.Dataset) -> @estimators.CausalEstimator {
  let estimator = @estimators.CausalEstimator::instrumental_variable(
    backdoor_estimand(dataset),
    "Z0",
  )
  estimator.fit(dataset.frame(), [])
  estimator
}

///|
/// The refutation of the case.
fn unobserved_refute(
  dataset : @datasets.Dataset,
  estimator : @estimators.CausalEstimator,
  kappa_t : Double,
  kappa_y : Double,
  seed : UInt64,
  effect_on_t~ : @refuters.ConfoundersEffectOnT = @refuters.ConfoundersEffectOnT::linear(),
) -> @refuters.CausalRefutation {
  @refuters.refute_add_unobserved_common_cause(
    estimator,
    backdoor_estimand(dataset),
    dataset.frame(),
    dataset.treatments()[0],
    dataset.outcome(),
    kappa_t,
    kappa_y,
    1.0,
    0.0,
    "ate",
    @utils.Random::new(seed),
    effect_on_t~,
  )
}

///|
test "the refuter of a binary treatment survives the strengths of the case" {
  let dataset = unobserved_binary_dataset(20000)
  let estimator = unobserved_psm(dataset)
  let refutation = unobserved_refute(
    dataset,
    estimator,
    0.01,
    0.02,
    31UL,
    effect_on_t=@refuters.ConfoundersEffectOnT::binary_flip(),
  )
  assert_eq(
    refutation.refutation_type(),
    "Refute: Add an Unobserved Common Cause",
  )
  // The upstream asserts nothing about the effect of this call; the port states
  // that the refutation reports the estimate of the data as the effect it
  // refutes.
  assert_eq(
    refutation.estimated_effect(),
    estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate").estimate(),
  )
}

///|
test "the absent confounder leaves the effect of a binary treatment alone" {
  let dataset = unobserved_binary_dataset(20000)
  let estimator = unobserved_psm(dataset)
  let original = estimator
    .estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
    .estimate()
  let refutation = unobserved_refute(
    dataset,
    estimator,
    0.0,
    0.0,
    32UL,
    effect_on_t=@refuters.ConfoundersEffectOnT::binary_flip(),
  )
  // A confounder of strength zero flips nothing, so the data is unchanged and the
  // refuted effect is the estimate itself.
  assert_eq(refutation.new_effect(), original)
  assert_true(refutation.new_effect_lower() == refutation.new_effect())
  assert_true(refutation.new_effect_upper() == refutation.new_effect())
}

///|
test "the refuter of a continuous treatment survives the strengths of the case" {
  let dataset = unobserved_continuous_dataset(20000)
  let estimator = unobserved_iv(dataset)
  let refutation = unobserved_refute(dataset, estimator, 0.01, 0.02, 33UL)
  assert_eq(
    refutation.refutation_type(),
    "Refute: Add an Unobserved Common Cause",
  )
  assert_eq(
    refutation.estimated_effect(),
    estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate").estimate(),
  )
}

///|
test "the absent confounder leaves the effect of a continuous treatment alone" {
  let dataset = unobserved_continuous_dataset(20000)
  let estimator = unobserved_iv(dataset)
  let original = estimator
    .estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
    .estimate()
  let refutation = unobserved_refute(dataset, estimator, 0.0, 0.0, 34UL)
  assert_eq(refutation.new_effect(), original)
}

///|
test "the linear confounder moves the effect of a continuous treatment" {
  let dataset = unobserved_continuous_dataset(20000)
  let estimator = unobserved_iv(dataset)
  let original = estimator
    .estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
    .estimate()
  let refutation = unobserved_refute(dataset, estimator, 1.0, 1.0, 35UL)
  // The upstream has no case for this, but a confounder of strength one that acts
  // on both columns has to register: the port states that the refuted effect
  // leaves the estimate.
  assert_true((refutation.new_effect() - original).abs() > 0.0)
}
