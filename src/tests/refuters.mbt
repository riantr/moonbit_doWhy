/// Tests for the refuters.
///
/// The cases mirror the upstream test suite
/// (`tests/causal_refuters/base.py`): a placebo treatment must drive the
/// effect to zero, a dummy outcome must drive the effect to zero, and the
/// bootstrap, the data subset and the random common cause refuters must leave
/// the effect unchanged.

///|
/// A linear regression estimator fitted on the data set.
fn fitted_estimator(dataset : @datasets.Dataset) -> @estimators.CausalEstimator {
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::linear_regression(estimand)
  estimator.fit(dataset.frame(), [])
  estimator
}

///|
test "the placebo treatment refuter drives the effect to zero" {
  let dataset = confounded()
  let estimator = fitted_estimator(dataset)
  let random = @utils.Random::new(7)
  let refutation = @refuters.refute_placebo_treatment(
    estimator,
    backdoor_estimand(dataset),
    dataset.frame(),
    "v0",
    10,
    1.0,
    0.0,
    "ate",
    random,
  )
  assert_true(refutation.new_effect().abs() < 1.0)
  assert_eq(refutation.refutation_type(), "Refute: Use a Placebo Treatment")
  assert_true(refutation.new_effect_lower() <= refutation.new_effect_upper())
}

///|
test "the dummy outcome refuter drives the effect to zero" {
  let dataset = confounded()
  let estimator = fitted_estimator(dataset)
  let random = @utils.Random::new(11)
  let refutations = @refuters.refute_dummy_outcome(
    estimator,
    backdoor_estimand(dataset),
    dataset.frame(),
    "y",
    "v0",
    5,
    1.0,
    0.0,
    "ate",
    random,
  )
  // The default transformation list carries no estimator, so the whole data is
  // simulated at once and a single refutation comes back.
  assert_eq(refutations.length(), 1)
  let refutation = refutations[0]
  assert_true(refutation.new_effect().abs() < 1.0)
  assert_eq(refutation.refutation_type(), "Refute: Use a Dummy Outcome")
}

///|
test "the data subset refuter leaves the effect unchanged" {
  let dataset = confounded()
  let estimator = fitted_estimator(dataset)
  let original = estimator
    .estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
    .estimate()
  let random = @utils.Random::new(13)
  let refutation = @refuters.refute_data_subset(
    estimator,
    backdoor_estimand(dataset),
    dataset.frame(),
    0.9,
    5,
    1.0,
    0.0,
    "ate",
    random,
  )
  let error = (refutation.new_effect() - original).abs()
  assert_true(error < original.abs() * 0.1)
  assert_eq(refutation.refutation_type(), "Refute: Use a subset of data")
}

///|
test "the bootstrap refuter leaves the effect unchanged" {
  let dataset = confounded()
  let estimator = fitted_estimator(dataset)
  let original = estimator
    .estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
    .estimate()
  let random = @utils.Random::new(17)
  let refutation = @refuters.refute_bootstrap(
    estimator,
    backdoor_estimand(dataset),
    dataset.frame(),
    5,
    1.0,
    1.0,
    0.0,
    "ate",
    random,
  )
  let error = (refutation.new_effect() - original).abs()
  assert_true(error < original.abs() * 0.1)
  assert_eq(refutation.refutation_type(), "Refute: Bootstrap Sample Dataset")
  assert_true(refutation.new_effect_lower() <= refutation.new_effect_upper())
}

///|
test "the random common cause refuter leaves the effect unchanged" {
  let dataset = confounded()
  let estimator = fitted_estimator(dataset)
  let original = estimator
    .estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
    .estimate()
  let random = @utils.Random::new(19)
  let refutation = @refuters.refute_random_common_cause(
    estimator,
    backdoor_estimand(dataset),
    dataset.frame(),
    5,
    1.0,
    0.0,
    "ate",
    random,
  )
  let error = (refutation.new_effect() - original).abs()
  assert_true(error < original.abs() * 0.1)
  assert_eq(refutation.refutation_type(), "Refute: Add a random common cause")
}

///|
test "the unobserved common cause refuter moves the effect when the confounder is strong" {
  let dataset = confounded()
  let estimator = fitted_estimator(dataset)
  let original = estimator
    .estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
    .estimate()
  let random = @utils.Random::new(23)
  let refutation = @refuters.refute_add_unobserved_common_cause(
    estimator,
    backdoor_estimand(dataset),
    dataset.frame(),
    "v0",
    "y",
    1.0,
    5,
    1.0,
    0.0,
    "ate",
    random,
  )
  assert_true((refutation.new_effect() - original).abs() > 0.0)
  assert_eq(
    refutation.refutation_type(),
    "Refute: Add an Unobserved Common Cause",
  )
}

///|
test "the unobserved common cause refuter keeps the effect when the confounder is absent" {
  let dataset = confounded()
  let estimator = fitted_estimator(dataset)
  let original = estimator
    .estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
    .estimate()
  let random = @utils.Random::new(29)
  let refutation = @refuters.refute_add_unobserved_common_cause(
    estimator,
    backdoor_estimand(dataset),
    dataset.frame(),
    "v0",
    "y",
    0.0,
    5,
    1.0,
    0.0,
    "ate",
    random,
  )
  let error = (refutation.new_effect() - original).abs()
  assert_true(error < original.abs() * 0.1)
}

///|
test "the refutation reports the original estimate" {
  let dataset = confounded()
  let estimator = fitted_estimator(dataset)
  let original = estimator
    .estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
    .estimate()
  let random = @utils.Random::new(31)
  let refutation = @refuters.refute_data_subset(
    estimator,
    backdoor_estimand(dataset),
    dataset.frame(),
    0.9,
    5,
    1.0,
    0.0,
    "ate",
    random,
  )
  assert_true((refutation.estimated_effect() - original).abs() < 1.0e-9)
}
