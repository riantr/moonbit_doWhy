///|
/// The tests of the base estimator of the upstream.
///
/// The upstream test file `tests/test_causal_estimator.py` builds a mock
/// estimator that derives from the base class `CausalEstimator` of the
/// upstream, and it checks that the two placeholder methods of the base raise
/// a `NotImplementedError`: the do operator and the symbolic estimator.
///
/// The port reports the placeholders with the predicates
/// `supports_do_operator` and `supports_symbolic_estimator` and with a `None`
/// return, because MoonBit cannot catch the abort of a method.

///|
test "the base estimator of the upstream has no do operator" {
  let dataset = confounded()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::base(estimand)
  assert_false(estimator.supports_do_operator())
  assert_true(estimator.do_operator(1.0, dataset.frame()) is None)
}

///|
test "the base estimator of the upstream has no symbolic estimator" {
  let dataset = confounded()
  let estimand = backdoor_estimand(dataset)
  let estimator = @estimators.CausalEstimator::base(estimand)
  assert_false(estimator.supports_symbolic_estimator())
}

///|
test "the do operator of the upstream is the one of the regression and of the doubly robust estimator" {
  let dataset = confounded()
  let estimand = backdoor_estimand(dataset)
  // The upstream implements the do operator in the class of the regression
  // estimator and in the class of the doubly robust estimator, and every other
  // estimator inherits the placeholder of the base.
  let regression = @estimators.CausalEstimator::linear_regression(estimand)
  assert_true(regression.supports_do_operator())
  let linear = @estimators.CausalEstimator::generalized_linear_model(
    estimand,
    @utils.GlmFamily::gaussian(),
  )
  assert_true(linear.supports_do_operator())
  let doubly_robust = @estimators.CausalEstimator::doubly_robust(
    estimand, 0.05, 0.95,
  )
  assert_true(doubly_robust.supports_do_operator())
  let weighting = @estimators.CausalEstimator::propensity_score_weighting(
    estimand,
    0.05,
    0.95,
    @estimators.WeightingScheme::ips_weight(),
  )
  assert_false(weighting.supports_do_operator())
  let matching = @estimators.CausalEstimator::propensity_score_matching(
    estimand,
  )
  assert_false(matching.supports_do_operator())
  let stratification = @estimators.CausalEstimator::propensity_score_stratification(
    estimand,
    @estimators.NumStrata::auto(),
    10,
  )
  assert_false(stratification.supports_do_operator())
  let instrument = @estimators.CausalEstimator::instrumental_variable(
    estimand, "z",
  )
  assert_false(instrument.supports_do_operator())
  let two_stage = @estimators.CausalEstimator::two_stage_regression(estimand)
  assert_false(two_stage.supports_do_operator())
  let discontinuity = @estimators.CausalEstimator::regression_discontinuity(
    estimand, "x", 0.0, 1.0,
  )
  assert_false(discontinuity.supports_do_operator())
}

///|
test "every estimator of the upstream but the base has a symbolic estimator" {
  let dataset = confounded()
  let estimand = backdoor_estimand(dataset)
  let base = @estimators.CausalEstimator::base(estimand)
  assert_false(base.supports_symbolic_estimator())
  let regression = @estimators.CausalEstimator::linear_regression(estimand)
  assert_true(regression.supports_symbolic_estimator())
  let weighting = @estimators.CausalEstimator::propensity_score_weighting(
    estimand,
    0.05,
    0.95,
    @estimators.WeightingScheme::ips_weight(),
  )
  assert_true(weighting.supports_symbolic_estimator())
  let doubly_robust = @estimators.CausalEstimator::doubly_robust(
    estimand, 0.05, 0.95,
  )
  assert_true(doubly_robust.supports_symbolic_estimator())
}

///|
test "the message of the upstream for a method it does not implement is the one of the upstream" {
  let message = @estimators.default_not_implemented_error_message()
  assert_true(
    message.has_prefix(
      "not yet implemented for {0}. If you would this to be implemented in the next version, please raise an issue at ",
    ),
  )
  assert_true(message.has_suffix("https://github.com/microsoft/dowhy/issues"))
}
