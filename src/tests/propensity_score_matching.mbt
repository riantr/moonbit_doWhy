/// The match rule of the propensity score matching estimator.
///
/// The estimator matches every treated unit with the control unit whose
/// propensity score is the closest, and the search is a binary search over the
/// sorted scores.  These tests check that the search picks the same units as a
/// scan over every unit of the other group, which is the rule the estimator
/// used before the search was made logarithmic.

///|
/// The average treatment effect of a scan over every unit of the other group.
///
/// This is the brute force version of the matching of the propensity score
/// matching estimator: every treated unit is matched with the control unit
/// whose propensity score is the closest, and a tie is broken with the index
/// of the unit, because the scan visits the units in the order of their
/// index.
fn brute_force_ate(
  ps : Array[Double],
  treatment : Array[Double],
  outcome : Array[Double],
) -> Double {
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
  let mut att_sum = 0.0
  for row in treated {
    let mut best = control[0]
    let mut best_distance = (ps[row] - ps[best]).abs()
    for candidate in control {
      let distance = (ps[row] - ps[candidate]).abs()
      if distance < best_distance {
        best_distance = distance
        best = candidate
      }
    }
    att_sum = att_sum + outcome[row] - outcome[best]
  }
  let mut atc_sum = 0.0
  for row in control {
    let mut best = treated[0]
    let mut best_distance = (ps[row] - ps[best]).abs()
    for candidate in treated {
      let distance = (ps[row] - ps[candidate]).abs()
      if distance < best_distance {
        best_distance = distance
        best = candidate
      }
    }
    atc_sum = atc_sum + outcome[best] - outcome[row]
  }
  let att = att_sum / treated.length().to_double()
  let atc = atc_sum / control.length().to_double()
  (att * treated.length().to_double() + atc * control.length().to_double()) /
  (treated.length() + control.length()).to_double()
}

///|
/// The estimate of the propensity score matching estimator and the estimate of
/// the scan over the units.
fn psm_case(dataset : @datasets.Dataset) -> (Double, Double) {
  let estimand = exhaustive_estimand(dataset, "backdoor")
  let estimator = @estimators.CausalEstimator::propensity_score_matching(
    estimand,
  )
  estimator.fit(dataset.frame(), [])
  let estimate = estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
  let treatment = dataset.frame().numeric(dataset.treatments()[0])
  let outcome = dataset.frame().numeric(dataset.outcome())
  (
    estimate.estimate(),
    brute_force_ate(estimate.propensity_scores(), treatment, outcome),
  )
}

///|
test "the propensity score matching matches the same units as a scan over the units" {
  let dataset = confounded()
  let (estimate, scan) = psm_case(dataset)
  assert_eq(estimate, scan)
}

///|
test "the propensity score matching matches the same units when the scores are tied" {
  // A discrete common cause gives the propensity scores only a few distinct
  // values, so the units are matched in large groups of equal distance.
  let dataset = @datasets.linear_dataset(
    SEED,
    NUM_SAMPLES,
    @datasets.LinearConfig::new(
      num_common_causes=1,
      num_discrete_common_causes=1,
      treatment_is_binary=true,
    ),
  )
  let (estimate, scan) = psm_case(dataset)
  assert_eq(estimate, scan)
}
