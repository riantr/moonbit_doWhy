/// Tests for the bootstrap refuter.
///
/// The cases mirror the upstream test file
/// (`tests/causal_refuters/test_bootstrap_refuter.py`): the refuted effect
/// has to stay close to the effect of the data, because a bootstrap sample
/// holds the same information as the data.
///
/// The upstream runs the continuous treatment with one common cause and without
/// one, the binary treatment with the propensity score matching and with the
/// propensity score matching of the general adjustment, and the cases that
/// choose the variables the refuter perturbs: a number of them, a list of
/// names and a list of names to leave out.

///|
/// The seed of the generator of the refuters.
const BOOTSTRAP_SEED : UInt64 = 41

///|
/// The data set of the bootstrap refuter.
fn bootstrap_dataset(
  num_common_causes : Int32,
  num_samples : Int32,
  treatment_is_binary : Bool,
) -> @datasets.Dataset {
  @datasets.linear_dataset(
    SEED,
    num_samples,
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
/// The number of simulations of the refuter.
///
/// The upstream runs five simulations for a binary treatment and the default of
/// a hundred for a continuous one.
fn bootstrap_simulations(treatment_is_binary : Bool) -> Int32 {
  if treatment_is_binary {
    5
  } else {
    100
  }
}

///|
/// The original effect and the refuted effect of the bootstrap refuter.
fn bootstrap_case(
  dataset : @datasets.Dataset,
  identifier_method : String,
  binary_estimator : Bool,
  required_variables : @refuters.RequiredVariables,
) -> (Double, Double, String) {
  let estimand = exhaustive_estimand(dataset, identifier_method)
  let estimator = if binary_estimator {
    @estimators.CausalEstimator::propensity_score_matching(estimand)
  } else {
    @estimators.CausalEstimator::instrumental_variable(estimand, "Z0")
  }
  estimator.fit(dataset.frame(), [])
  let original = estimator
    .estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
    .estimate()
  let refutation = @refuters.refute_bootstrap(
    estimator,
    estimand,
    dataset.frame(),
    bootstrap_simulations(binary_estimator),
    1.0,
    1.0,
    0.0,
    "ate",
    @utils.Random::new(BOOTSTRAP_SEED),
    required_variables~,
  )
  (original, refutation.new_effect(), refutation.refutation_type())
}

///|
/// The refuted effect of the bootstrap refuter with the given noise and the
/// given probability of the change.
fn bootstrap_refutation(
  dataset : @datasets.Dataset,
  noise : Double,
  probability_of_change : Double?,
) -> Double {
  let estimand = exhaustive_estimand(dataset, "backdoor")
  let estimator = @estimators.CausalEstimator::propensity_score_matching(
    estimand,
  )
  estimator.fit(dataset.frame(), [])
  @refuters.refute_bootstrap(
    estimator,
    estimand,
    dataset.frame(),
    5,
    1.0,
    1.0,
    0.0,
    "ate",
    @utils.Random::new(BOOTSTRAP_SEED),
    noise~,
    probability_of_change~,
  ).new_effect()
}

///|
test "the bootstrap refuter leaves the effect of a continuous treatment unchanged" {
  let dataset = bootstrap_dataset(1, 1000, false)
  let (original, refuted, kind) = bootstrap_case(
    dataset,
    "backdoor",
    false,
    @refuters.RequiredVariables::all(),
  )
  let error = (refuted - original).abs()
  // The tolerance of the upstream test file.
  assert_true(error < original.abs() * 0.05)
  assert_eq(kind, "Refute: Bootstrap Sample Dataset")
}

///|
test "the bootstrap refuter leaves the effect of a continuous treatment without a common cause unchanged" {
  let dataset = bootstrap_dataset(0, 1000, false)
  let (original, refuted, _) = bootstrap_case(
    dataset,
    "backdoor",
    false,
    @refuters.RequiredVariables::all(),
  )
  let error = (refuted - original).abs()
  assert_true(error < original.abs() * 0.05)
}

///|
test "the bootstrap refuter leaves the effect of a binary treatment unchanged" {
  let dataset = bootstrap_dataset(1, 1000, true)
  let (original, refuted, _) = bootstrap_case(
    dataset,
    "backdoor",
    true,
    @refuters.RequiredVariables::all(),
  )
  let error = (refuted - original).abs()
  assert_true(error < original.abs() * 0.05)
}

///|
test "the bootstrap refuter leaves the effect of a binary treatment unchanged with the general adjustment" {
  let dataset = bootstrap_dataset(1, 1000, true)
  let (original, refuted, _) = bootstrap_case(
    dataset,
    "general_adjustment",
    true,
    @refuters.RequiredVariables::all(),
  )
  let error = (refuted - original).abs()
  assert_true(error < original.abs() * 0.05)
}

///|
test "the bootstrap refuter leaves the effect of a continuous treatment unchanged with three variables" {
  let dataset = bootstrap_dataset(5, 1000, false)
  let (original, refuted, _) = bootstrap_case(
    dataset,
    "backdoor",
    false,
    @refuters.RequiredVariables::count(3),
  )
  let error = (refuted - original).abs()
  assert_true(error < original.abs() * 0.05)
}

///|
test "the bootstrap refuter leaves the effect of a continuous treatment unchanged with two named variables" {
  let dataset = bootstrap_dataset(5, 1000, false)
  let (original, refuted, _) = bootstrap_case(
    dataset,
    "backdoor",
    false,
    @refuters.RequiredVariables::named(["W0", "W1"]),
  )
  let error = (refuted - original).abs()
  assert_true(error < original.abs() * 0.05)
}

///|
test "the bootstrap refuter leaves the effect of a binary treatment unchanged with three variables" {
  let dataset = bootstrap_dataset(5, 5000, true)
  let (original, refuted, _) = bootstrap_case(
    dataset,
    "backdoor",
    true,
    @refuters.RequiredVariables::count(3),
  )
  let error = (refuted - original).abs()
  assert_true(error < original.abs() * 0.1)
}

///|
test "the bootstrap refuter leaves the effect of a binary treatment unchanged with three variables and the general adjustment" {
  let dataset = bootstrap_dataset(5, 5000, true)
  let (original, refuted, _) = bootstrap_case(
    dataset,
    "general_adjustment",
    true,
    @refuters.RequiredVariables::count(3),
  )
  let error = (refuted - original).abs()
  assert_true(error < original.abs() * 0.1)
}

///|
test "the bootstrap refuter leaves the effect of a binary treatment unchanged with two named variables" {
  let dataset = bootstrap_dataset(5, 5000, true)
  let (original, refuted, _) = bootstrap_case(
    dataset,
    "backdoor",
    true,
    @refuters.RequiredVariables::named(["W0", "W1"]),
  )
  let error = (refuted - original).abs()
  assert_true(error < original.abs() * 0.1)
}

///|
test "the bootstrap refuter leaves the effect of a binary treatment unchanged with two named variables and the general adjustment" {
  let dataset = bootstrap_dataset(5, 5000, true)
  let (original, refuted, _) = bootstrap_case(
    dataset,
    "general_adjustment",
    true,
    @refuters.RequiredVariables::named(["W0", "W1"]),
  )
  let error = (refuted - original).abs()
  assert_true(error < original.abs() * 0.1)
}

///|
test "the bootstrap refuter leaves the effect of a continuous treatment unchanged without two named variables" {
  let dataset = bootstrap_dataset(5, 5000, false)
  let (original, refuted, _) = bootstrap_case(
    dataset,
    "backdoor",
    false,
    @refuters.RequiredVariables::others(["W0", "W1"]),
  )
  let error = (refuted - original).abs()
  assert_true(error < original.abs() * 0.1)
}

///|
test "the bootstrap refuter leaves the effect of a binary treatment unchanged without two named variables" {
  let dataset = bootstrap_dataset(5, 5000, true)
  let (original, refuted, _) = bootstrap_case(
    dataset,
    "backdoor",
    true,
    @refuters.RequiredVariables::others(["W0", "W1"]),
  )
  let error = (refuted - original).abs()
  assert_true(error < original.abs() * 0.1)
}

///|
test "the bootstrap refuter leaves the effect of a binary treatment unchanged without two named variables and the general adjustment" {
  let dataset = bootstrap_dataset(5, 5000, true)
  let (original, refuted, _) = bootstrap_case(
    dataset,
    "general_adjustment",
    true,
    @refuters.RequiredVariables::others(["W0", "W1"]),
  )
  let error = (refuted - original).abs()
  assert_true(error < original.abs() * 0.1)
}

///|
test "the bootstrap refuter derives the probability of the change from the noise" {
  // A discrete common cause is the variable the probability of the change
  // applies to, so the numbers of the refutation tell whether the probability
  // was derived from the noise or not.
  let dataset = @datasets.linear_dataset(
    SEED,
    NUM_SAMPLES,
    @datasets.LinearConfig::new(
      num_common_causes=1,
      num_discrete_common_causes=1,
      treatment_is_binary=true,
    ),
  )
  // The noise is zero, so the probability of the change is zero when it is
  // derived from the noise, and the discrete column is left alone.
  let derived = bootstrap_refutation(dataset, 0.0, None)
  let given = bootstrap_refutation(dataset, 0.0, Some(0.0))
  assert_eq(derived, given)
  // A probability of one changes every row of the discrete column, so the
  // refuted effect is a different number.
  let changed = bootstrap_refutation(dataset, 0.0, Some(1.0))
  assert_true((changed - derived).abs() > derived.abs() * 0.1)
}
