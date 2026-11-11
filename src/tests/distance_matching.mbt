/// The tests of the distance matching estimator.
///
/// The upstream has no test file for the distance matching estimator: the
/// estimator is one of the classes of the registry of the upstream, and the
/// registry reaches it with the method name `backdoor.distance_matching`, but
/// the test suite of the upstream does not cover it.
///
/// The port therefore checks two things: that the estimate recovers the true
/// effect of a generated data set, like the tests of the estimators of the
/// upstream do, and that the numbers of the estimate are the numbers of the
/// upstream. The second check uses the fixture of the script
/// `_verify/distance_matching_reference.py`, which runs the estimator of the
/// upstream on the same rows.

///|
/// The frame of the fixture of the distance matching estimator.
///
/// This is the frame of the script `_verify/distance_matching_reference.py`:
/// thirty rows of a treatment, of a common cause and of an outcome. The common
/// cause is drawn from a linear congruential generator, so that the port and
/// the script build the same rows without a shared random number generator.
fn distance_matching_frame() -> @api.DataFrame {
  let treatment : Array[Double] = []
  let common_cause : Array[Double] = []
  let outcome : Array[Double] = []
  let mut state : Int64 = 42
  for index in 0..<30 {
    state = (1103515245L * state + 12345L) % 2147483648L
    let w = state.to_double() / 2147483648.0 * 4.0 - 2.0
    state = (1103515245L * state + 12345L) % 2147483648L
    let noise = state.to_double() / 2147483648.0 - 0.5
    let t = if index % 3 == 0 { 1.0 } else { 0.0 }
    treatment.push(t)
    common_cause.push(w)
    outcome.push(2.0 * t + 0.5 * w + noise)
  }
  @api.DataFrame::from_numeric(
    ["v0", "W0", "y"],
    Map([("v0", treatment), ("W0", common_cause), ("y", outcome)]),
  )
}

///|
/// The estimand of the fixture of the distance matching estimator.
///
/// The graph is the one of the script `_verify/distance_matching_reference.py`:
/// the common cause is a cause of the treatment and of the outcome.
fn distance_matching_estimand() -> @identifiers.IdentifiedEstimand {
  let graph = @graph.build_graph(["v0"], ["y"], ["W0"], [], [], [])
  @identifiers.identify_effect_auto(
    graph,
    ["v0"],
    ["y"],
    ["v0", "W0", "y"],
    "nonparametric-ate",
    @identifiers.BACKDOOR_DEFAULT,
  )
}

///|
test "the distance matching estimator reproduces the numbers of the upstream" {
  let frame = distance_matching_frame()
  let estimand = distance_matching_estimand()
  let estimator = @estimators.CausalEstimator::distance_matching(estimand)
  estimator.fit(frame, [])
  let att = estimator.estimate_effect(frame, 1.0, 0.0, "att")
  let atc = estimator.estimate_effect(frame, 1.0, 0.0, "atc")
  let ate = estimator.estimate_effect(frame, 1.0, 0.0, "ate")
  assert_true((att.value - 1.822948021069169).abs() < 0.000000000001)
  assert_true((atc.value - 1.783625119132921).abs() < 0.000000000001)
  assert_true((ate.value - 1.7967327531116704).abs() < 0.000000000001)
}

///|
test "the distance matching estimator with two matches reproduces the numbers of the upstream" {
  let frame = distance_matching_frame()
  let estimand = distance_matching_estimand()
  let estimator = @estimators.CausalEstimator::distance_matching(
    estimand,
    num_matches_per_unit=2,
  )
  estimator.fit(frame, [])
  let att = estimator.estimate_effect(frame, 1.0, 0.0, "att")
  let atc = estimator.estimate_effect(frame, 1.0, 0.0, "atc")
  let ate = estimator.estimate_effect(frame, 1.0, 0.0, "ate")
  assert_true((att.value - 1.8536190246697515).abs() < 0.000000000001)
  assert_true((atc.value - 1.7259645089507103).abs() < 0.000000000001)
  assert_true((ate.value - 1.7685160141903906).abs() < 0.000000000001)
}

///|
test "the distance matching estimator recovers the true effect" {
  let dataset = confounded()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::distance_matching(estimand)
  estimator.fit(dataset.frame(), [])
  let estimate = estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
  assert_true(close_enough(estimate.value, dataset.average_treatment_effect()))
}

///|
test "the distance matching estimator of the model is the estimator of the upstream" {
  let frame = distance_matching_frame()
  let model = @moonbit_dowhy.CausalModel::new(
    frame,
    ["v0"],
    ["y"],
    None,
    ["W0"],
    [],
    [],
    [],
  )
  let estimate = model.estimate_effect(
    "backdoor.distance_matching", 1.0, 0.0, "ate",
  )
  assert_true((estimate.value - 1.7967327531116704).abs() < 0.000000000001)
}

///|
test "the distance matching estimator reports the errors of the upstream" {
  let frame = distance_matching_frame()
  let estimand = distance_matching_estimand()
  let estimator = @estimators.CausalEstimator::distance_matching(estimand)
  assert_true(estimator.distance_matching_error(frame) is None)
  // The upstream raises an exception when the treatment is not binary.
  let treatment : Array[Double] = []
  let common_cause : Array[Double] = []
  let outcome : Array[Double] = []
  for row in 0..<30 {
    treatment.push(if row == 0 { 2.0 } else { 0.0 })
    common_cause.push(row.to_double())
    outcome.push(row.to_double())
  }
  let other = @api.DataFrame::from_numeric(
    ["v0", "W0", "y"],
    Map([("v0", treatment), ("W0", common_cause), ("y", outcome)]),
  )
  match estimator.distance_matching_error(other) {
    Some(message) =>
      assert_true(
        message ==
        "Distance Matching method is applicable only for binary treatments.",
      )
    None => assert_true(false)
  }
  // The upstream raises an exception when the estimand has no common cause.
  let empty = @identifiers.IdentifiedEstimand::new(["v0"], ["y"])
  let without = @estimators.CausalEstimator::distance_matching(empty)
  match without.distance_matching_error(frame) {
    Some(message) =>
      assert_true(
        message ==
        "No common causes/confounders present. Distance matching methods are not applicable",
      )
    None => assert_true(false)
  }
}

///|
test "the distance matching estimator has no do operator and has a symbolic estimator" {
  let estimand = distance_matching_estimand()
  let estimator = @estimators.CausalEstimator::distance_matching(estimand)
  // The upstream implements the do operator in the class of the regression
  // estimator and in the class of the doubly robust estimator, and every other
  // estimator inherits the placeholder of the base.
  assert_false(estimator.supports_do_operator())
  assert_true(estimator.supports_symbolic_estimator())
}
