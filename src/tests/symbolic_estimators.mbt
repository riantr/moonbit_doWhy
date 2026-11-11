/// The tests of the symbolic estimators of the upstream.
///
/// The upstream builds the symbolic estimator of an estimator when it is
/// fitted and hands it to the estimate as the `realized_estimand_expr` of the
/// estimate. The script `_verify/symbolic_estimators_reference.py` prints the
/// strings the upstream builds on the fixtures of the port.

///|
/// The data set with an effect modifier.
fn symbolic_with_modifier() -> @datasets.Dataset {
  @datasets.linear_dataset(
    SEED,
    NUM_SAMPLES,
    @datasets.LinearConfig::effect_modifier(),
  )
}

///|
/// The symbolic estimator of the linear regression estimator.
fn symbolic_linear_regression() -> String {
  let dataset = confounded()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::linear_regression(estimand)
  estimator.fit(dataset.frame(), [])
  match estimator.symbolic_estimator() {
    Some(expression) => expression
    None => ""
  }
}

///|
test "the symbolic estimator of the linear regression is the one of the upstream" {
  // The upstream builds the string `b: y~v0+W0`.
  assert_true(symbolic_linear_regression() == "b: y~v0+W0")
}

///|
test "the symbolic estimator of the linear regression holds the interaction of the effect modifier" {
  let dataset = symbolic_with_modifier()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::linear_regression(estimand)
  estimator.fit(dataset.frame(), dataset.effect_modifiers())
  match estimator.symbolic_estimator() {
    // The upstream builds the string `b: y~v0+v0*X0`: the data set of the
    // port holds no common cause, so the adjustment set of the estimand is
    // empty.
    Some(expression) => assert_true(expression == "b: y~v0+v0*X0")
    None => assert_true(false)
  }
}

///|
test "the symbolic estimator of the generalised linear model is the one of the upstream" {
  let dataset = confounded()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::generalized_linear_model(
    estimand,
    @utils.GlmFamily::binomial(),
  )
  estimator.fit(dataset.frame(), [])
  match estimator.symbolic_estimator() {
    // The upstream builds the string `b: y~Sigmoid(v0+W0)`.
    Some(expression) => assert_true(expression == "b: y~Sigmoid(v0+W0)")
    None => assert_true(false)
  }
}

///|
test "the symbolic estimator of the propensity score estimators is the one of the upstream" {
  let dataset = confounded()
  let estimand = backdoor_estimand(dataset)
  // The upstream builds the string `b: y~v0+W0` for the three estimators.
  let weighting = @estimators.CausalEstimator::propensity_score_weighting(
    estimand,
    0.05,
    0.95,
    @estimators.WeightingScheme::ips_weight(),
  )
  weighting.fit(dataset.frame(), [])
  match weighting.symbolic_estimator() {
    Some(expression) => assert_true(expression == "b: y~v0+W0")
    None => assert_true(false)
  }
  let matching = @estimators.CausalEstimator::propensity_score_matching(
    estimand,
  )
  matching.fit(dataset.frame(), [])
  match matching.symbolic_estimator() {
    Some(expression) => assert_true(expression == "b: y~v0+W0")
    None => assert_true(false)
  }
  let stratification = @estimators.CausalEstimator::propensity_score_stratification(
    estimand,
    @estimators.NumStrata::fixed(5),
    10,
  )
  stratification.fit(dataset.frame(), [])
  match stratification.symbolic_estimator() {
    Some(expression) => assert_true(expression == "b: y~v0+W0")
    None => assert_true(false)
  }
  let doubly_robust = @estimators.CausalEstimator::doubly_robust(
    estimand, 0.01, 0.99,
  )
  doubly_robust.fit(dataset.frame(), [])
  match doubly_robust.symbolic_estimator() {
    Some(expression) => assert_true(expression == "b: y~v0+W0")
    None => assert_true(false)
  }
}

///|
test "the symbolic estimator of the distance matching estimator is the one of the upstream" {
  let dataset = confounded()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::distance_matching(estimand)
  estimator.fit(dataset.frame(), [])
  match estimator.symbolic_estimator() {
    // The upstream builds the string `b: y~v0+W0`.
    Some(expression) => assert_true(expression == "b: y~v0+W0")
    None => assert_true(false)
  }
}

///|
test "the base estimator and the instrumental variable estimator have no symbolic estimator" {
  let dataset = confounded()
  let estimand = backdoor_estimand(dataset)
  // The upstream raises a NotImplementedError for the base estimator and it
  // builds the expressions of the sympy for the instrumental variable
  // estimator.
  let base = @estimators.CausalEstimator::base(estimand)
  assert_true(base.symbolic_estimator() is None)
  let instrument = @estimators.CausalEstimator::instrumental_variable(
    estimand, "z",
  )
  assert_true(instrument.symbolic_estimator() is None)
}

///|
/// The frame of the regression discontinuity estimator.
///
/// The frame holds a running variable, so that the estimator of the upstream
/// finds the rows of its band.
fn symbolic_discontinuity_frame() -> @api.DataFrame {
  let treatment : Array[Double] = []
  let common_cause : Array[Double] = []
  let outcome : Array[Double] = []
  let running : Array[Double] = []
  for index in 0..<40 {
    let x = -1.0 + 2.0 * index.to_double() / 39.0
    let t = if index % 2 == 0 { 1.0 } else { 0.0 }
    treatment.push(t)
    common_cause.push(index.to_double() * 0.1)
    outcome.push(2.0 * t + 0.5 * x)
    running.push(x)
  }
  @api.DataFrame::from_numeric(
    ["v0", "W0", "y", "x"],
    Map([
      ("v0", treatment),
      ("W0", common_cause),
      ("y", outcome),
      ("x", running),
    ]),
  )
}

///|
/// The estimand of the frame of the regression discontinuity estimator.
fn symbolic_discontinuity_estimand() -> @identifiers.IdentifiedEstimand {
  let graph = @graph.build_graph(["v0"], ["y"], ["W0"], [], [], [])
  @identifiers.identify_effect_auto(
    graph,
    ["v0"],
    ["y"],
    ["v0", "W0", "y", "x"],
    "nonparametric-ate",
    @identifiers.BACKDOOR_DEFAULT,
  )
}

///|
test "the regression discontinuity estimator builds the empty symbolic estimator" {
  let frame = symbolic_discontinuity_frame()
  let estimand = symbolic_discontinuity_estimand()
  let estimator = @estimators.CausalEstimator::regression_discontinuity(
    estimand, "x", 0.0, 1.0,
  )
  estimator.fit(frame, [])
  match estimator.symbolic_estimator() {
    // The upstream builds the empty string.
    Some(expression) => assert_true(expression == "")
    None => assert_true(false)
  }
}

///|
test "the estimate carries the symbolic estimator of its estimator" {
  let dataset = confounded()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::linear_regression(estimand)
  estimator.fit(dataset.frame(), [])
  let estimate = estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
  assert_true(estimate.realized_estimand_expr() == "b: y~v0+W0")
}

///|
test "the symbolic estimator of the two stage regression is the composition of the two stages" {
  let model = two_stage_frontdoor_model()
  let estimate = model.estimate_effect(
    "frontdoor.two_stage_regression", 1.0, 0.0, "ate",
  )
  // The upstream builds the string `(b: Z~X)*(b: Y~Z+X)`.
  assert_true(estimate.realized_estimand_expr() == "(b: Z~X)*(b: Y~Z+X)")
}
