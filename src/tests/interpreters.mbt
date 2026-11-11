/// The tests of the visual interpreters of the upstream.
///
/// The upstream draws the two interpreters with the matplotlib of the upstream,
/// and the script `_verify/interpreter_reference.py` prints the numbers of the
/// two figures on the very rows of the port.

///|
/// The frame of the visual interpreters.
///
/// This is the frame of the script `_verify/interpreter_reference.py`: four
/// hundred rows of a treatment, of a common cause, of an outcome and of the
/// propensity score of the row. The rows hold their propensity score, so the
/// port and the script build the very same strata and the very same weights.
fn visual_frame(discrete : Bool) -> @api.DataFrame {
  let treatment : Array[Double] = []
  let common_cause : Array[Double] = []
  let outcome : Array[Double] = []
  let propensity : Array[Double] = []
  let mut state : Int64 = 42
  for index in 0..<400 {
    state = (1103515245L * state + 12345L) % 2147483648L
    let w = state.to_double() / 2147483648.0 * 4.0 - 2.0
    state = (1103515245L * state + 12345L) % 2147483648L
    let noise = state.to_double() / 2147483648.0 - 0.5
    let t = if index % 3 == 0 { 1.0 } else { 0.0 }
    treatment.push(t)
    if discrete {
      common_cause.push((w * 2.0).to_int().to_double() + 3.0)
    } else {
      common_cause.push(w)
    }
    outcome.push(2.0 * t + 0.5 * w + noise)
    propensity.push(1.0 / (1.0 + @math.exp(-0.8 * w)))
  }
  @api.DataFrame::from_numeric(
    ["v0", "W0", "y", "propensity_score"],
    Map([
      ("v0", treatment),
      ("W0", common_cause),
      ("y", outcome),
      ("propensity_score", propensity),
    ]),
  )
}

///|
/// The estimand of the frame of the visual interpreters.
fn visual_estimand() -> @identifiers.IdentifiedEstimand {
  let graph = @graph.build_graph(["v0"], ["y"], ["W0"], [], [], [])
  @identifiers.identify_effect_auto(
    graph,
    ["v0"],
    ["y"],
    ["v0", "W0", "y", "propensity_score"],
    "nonparametric-ate",
    @identifiers.BACKDOOR_DEFAULT,
  )
}

///|
test "the balance of the upstream is the balance of the port" {
  let frame = visual_frame(false)
  let estimand = visual_estimand()
  let estimator = @estimators.CausalEstimator::propensity_score_stratification(
    estimand,
    @estimators.NumStrata::auto(),
    10,
  )
  estimator.fit(frame, [])
  let estimate = estimator.estimate_effect(frame, 1.0, 0.0, "ate")
  let balance = @interpreters.propensity_balance_interpretation(
    estimate, estimator, frame,
  )
  assert_true(balance.length() == 1)
  assert_true(balance[0].common_cause() == "W0")
  // The upstream computes the numbers 0.1365284270842497 and
  // 0.28508698448244507 on the very same rows.
  assert_true(
    (balance[0].unadjusted_difference() - 0.1365284270842497).abs() <
    0.000000000001,
  )
  assert_true(
    (balance[0].adjusted_difference() - 0.28508698448244507).abs() <
    0.000000000001,
  )
}

///|
test "the distribution of the upstream is the distribution of the port" {
  let frame = visual_frame(true)
  let estimand = visual_estimand()
  let estimator = @estimators.CausalEstimator::propensity_score_weighting(
    estimand,
    0.05,
    0.95,
    @estimators.WeightingScheme::ips_weight(),
  )
  estimator.fit(frame, [])
  let estimate = estimator.estimate_effect(frame, 1.0, 0.0, "ate")
  let distribution = @interpreters.confounder_distribution_interpretation(
    estimate, frame, "W0",
  )
  assert_true(distribution.nrows() == 7)
  let categories = distribution.numeric("category")
  let untreated = distribution.numeric("untreated")
  let treated = distribution.numeric("treated")
  let untreated_weight = distribution.numeric("untreated_weight")
  let treated_weight = distribution.numeric("treated_weight")
  // The counts of the upstream, category by category.
  let counts = [
    (35.0, 23.0),
    (27.0, 11.0),
    (23.0, 17.0),
    (67.0, 36.0),
    (39.0, 15.0),
    (31.0, 14.0),
    (44.0, 18.0),
  ]
  // The sums of the weights of the upstream, category by category.
  let weights = [
    (44.017415535657264, 117.61170154209857),
    (36.866155710427655, 40.41400616203459),
    (35.73041672579647, 49.18443172075895),
    (131.8130348497636, 72.1314561125158),
    (109.19980301675987, 23.382609583864912),
    (114.01323873590717, 19.404479214714012),
    (228.34065489237275, 22.502922458360928),
  ]
  for i in 0..<7 {
    assert_true(categories[i] == i.to_double())
    assert_true(untreated[i] == counts[i].0)
    assert_true(treated[i] == counts[i].1)
    assert_true((untreated_weight[i] - weights[i].0).abs() < 0.000000000001)
    assert_true((treated_weight[i] - weights[i].1).abs() < 0.000000000001)
  }
}
