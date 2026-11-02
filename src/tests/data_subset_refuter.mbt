/// Tests for the data subset refuter.
///
/// The cases mirror the upstream test file
/// (`tests/causal_refuters/test_data_subset_refuter.py`): the refuted effect
/// has to stay close to the effect of the data, because a subset of the data
/// holds the same information as the data.
///
/// The upstream runs the continuous treatment with one common cause and without
/// one, with the instrumental variable estimator, and the binary treatment with
/// one common cause, with the propensity score matching.  The upstream runs
/// five simulations for a binary treatment and the default of a hundred for
/// the other kinds.

///|
/// The number of rows the upstream test suite uses.
const SUBSET_NUM_SAMPLES : Int32 = 100000

///|
/// The seed of the generator of the refuters.
const SUBSET_SEED : UInt64 = 37

///|
/// The data set of the data subset refuter.
fn subset_dataset(
  num_common_causes : Int32,
  treatment_is_binary : Bool,
) -> @datasets.Dataset {
  @datasets.linear_dataset(
    SEED,
    SUBSET_NUM_SAMPLES,
    @datasets.LinearConfig::new(
      beta=10.0,
      num_common_causes~,
      num_instruments=1,
      num_effect_modifiers=0,
      num_frontdoor_variables=0,
      num_treatments=1,
      treatment_is_binary~,
      treatment_is_category=false,
      outcome_is_binary=false,
    ),
  )
}

///|
/// The estimator of the upstream test, fitted on the data set.
fn subset_estimator(
  dataset : @datasets.Dataset,
  binary_estimator : Bool,
) -> @estimators.CausalEstimator {
  let estimand = exhaustive_estimand(dataset, "backdoor")
  let estimator = if binary_estimator {
    @estimators.CausalEstimator::propensity_score_matching(estimand)
  } else {
    @estimators.CausalEstimator::instrumental_variable(estimand, "Z0")
  }
  estimator.fit(dataset.frame(), [])
  estimator
}

///|
/// The refutation of the data subset refuter for the given data set.
fn subset_refutation(
  dataset : @datasets.Dataset,
  binary_estimator : Bool,
  num_simulations : Int32,
) -> @refuters.CausalRefutation {
  let estimand = exhaustive_estimand(dataset, "backdoor")
  let estimator = if binary_estimator {
    @estimators.CausalEstimator::propensity_score_matching(estimand)
  } else {
    @estimators.CausalEstimator::instrumental_variable(estimand, "Z0")
  }
  estimator.fit(dataset.frame(), [])
  @refuters.refute_data_subset(
    estimator,
    estimand,
    dataset.frame(),
    0.8,
    num_simulations,
    1.0,
    0.0,
    "ate",
    @utils.Random::new(SUBSET_SEED),
  )
}

///|
test "the data subset refuter leaves the effect of a continuous treatment unchanged" {
  let dataset = subset_dataset(1, false)
  let estimator = subset_estimator(dataset, false)
  let original = estimator
    .estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
    .estimate()
  let refutation = subset_refutation(dataset, false, 100)
  let error = (refutation.new_effect() - original).abs()
  // The tolerance of the upstream test file.
  assert_true(error < original.abs() * 0.01)
  assert_eq(refutation.refutation_type(), "Refute: Use a subset of data")
}

///|
test "the data subset refuter leaves the effect of a continuous treatment without a common cause unchanged" {
  let dataset = subset_dataset(0, false)
  let estimator = subset_estimator(dataset, false)
  let original = estimator
    .estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
    .estimate()
  let refutation = subset_refutation(dataset, false, 100)
  let error = (refutation.new_effect() - original).abs()
  assert_true(error < original.abs() * 0.01)
}

///|
test "the data subset refuter leaves the effect of a binary treatment unchanged" {
  let dataset = subset_dataset(1, true)
  let estimator = subset_estimator(dataset, true)
  let original = estimator
    .estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
    .estimate()
  // The upstream runs five simulations for a binary treatment.
  let refutation = subset_refutation(dataset, true, 5)
  let error = (refutation.new_effect() - original).abs()
  assert_true(error < original.abs() * 0.01)
}
