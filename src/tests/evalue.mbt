///|
/// The tests of the E-value analyzer.
///
/// The expectations are the ones of the upstream test file
/// `tests/causal_refuters/test_add_unobserved_common_cause.py`, whose case
/// `test_evalue` compares the analyzer of the upstream with the examples of the
/// R package `EValue`.
///
/// The numbers of the upstream are the ones of that package, and the reference
/// script `_verify/evalue_reference.py` prints them on the upstream itself:
///
/// * `_evalue_OLS(0.293, 0.196, 17.405)` gives the converted estimate
///   `1.015`, the converted limits `0.995` and `1.036`, the E-value of the
///   estimate `1.141`, the E-value of the lower limit `1.000` and no E-value
///   of the upper limit,
/// * `_evalue_MD(0.5, 0.25)` gives the converted estimate `1.576`, the
///   converted limits `1.010` and `2.460`, the E-value of the estimate `2.529`,
///   the E-value of the lower limit `1.111` and no E-value of the upper limit,
/// * `_evalue_OR(0.86, 0.75, 0.99, rare=False)` gives the converted estimate
///   `0.927`, the converted limits `0.866` and `0.995`, the E-value of the
///   estimate `1.369`, no E-value of the lower limit and the E-value of the
///   upper limit `1.076`,
/// * `_evalue_RR(0.8, 0.71, 0.91)` gives the converted estimate `0.800`, the
///   converted limits `0.710` and `0.910`, the E-value of the estimate `1.809`,
///   no E-value of the lower limit and the E-value of the upper limit `1.429`,
/// * `_observed_covariate_e_value` gives `3.414` for the pairs `(2, 4)` and
///   `(4, 2)` and `1.500` for the pair `(0.8, 0.9)`.

///|
/// Whether two numbers are close to each other.
fn evalue_near(a : Double, b : Double, tolerance : Double) -> Bool {
  (a - b).abs() <= tolerance
}

///|
/// Whether an optional number is close to a number.
fn evalue_option_near(a : Double?, b : Double, tolerance : Double) -> Bool {
  match a {
    Some(value) => evalue_near(value, b, tolerance)
    None => false
  }
}

///|
/// Whether an optional number is absent.
fn evalue_is_absent(a : Double?) -> Bool {
  match a {
    Some(_) => false
    None => true
  }
}

///|
test "the E-value of a linear regression reproduces the example of the upstream" {
  let stats = @refuters.evalue_ols(0.293, 0.196, 17.405, 1.0)
  assert_true(evalue_near(stats.converted_estimate(), 1.015, 1.0e-3))
  assert_true(evalue_option_near(stats.converted_lower_ci(), 0.995, 1.0e-3))
  assert_true(evalue_option_near(stats.converted_upper_ci(), 1.036, 1.0e-3))
  assert_true(evalue_near(stats.evalue_estimate(), 1.141, 1.0e-3))
  assert_true(evalue_option_near(stats.evalue_lower_ci(), 1.000, 1.0e-3))
  assert_true(evalue_is_absent(stats.evalue_upper_ci()))
}

///|
test "the E-value of a standardised difference reproduces the example of the upstream" {
  let stats = @refuters.evalue_md(0.5, Some(0.25))
  assert_true(evalue_near(stats.converted_estimate(), 1.576, 1.0e-3))
  assert_true(evalue_option_near(stats.converted_lower_ci(), 1.010, 1.0e-3))
  assert_true(evalue_option_near(stats.converted_upper_ci(), 2.460, 1.0e-3))
  assert_true(evalue_near(stats.evalue_estimate(), 2.529, 1.0e-3))
  assert_true(evalue_option_near(stats.evalue_lower_ci(), 1.111, 1.0e-3))
  assert_true(evalue_is_absent(stats.evalue_upper_ci()))
}

///|
test "the E-value of an odds ratio reproduces the example of the upstream" {
  let stats = @refuters.evalue_or(0.86, Some(0.75), Some(0.99), false)
  assert_true(evalue_near(stats.converted_estimate(), 0.927, 1.0e-3))
  assert_true(evalue_option_near(stats.converted_lower_ci(), 0.866, 1.0e-3))
  assert_true(evalue_option_near(stats.converted_upper_ci(), 0.995, 1.0e-3))
  assert_true(evalue_near(stats.evalue_estimate(), 1.369, 1.0e-3))
  assert_true(evalue_is_absent(stats.evalue_lower_ci()))
  assert_true(evalue_option_near(stats.evalue_upper_ci(), 1.076, 1.0e-3))
}

///|
test "the E-value of a risk ratio reproduces the example of the upstream" {
  let stats = @refuters.evalue_rr(0.8, Some(0.71), Some(0.91))
  assert_true(evalue_near(stats.converted_estimate(), 0.800, 1.0e-9))
  assert_true(evalue_option_near(stats.converted_lower_ci(), 0.710, 1.0e-9))
  assert_true(evalue_option_near(stats.converted_upper_ci(), 0.910, 1.0e-9))
  assert_true(evalue_near(stats.evalue_estimate(), 1.809, 1.0e-3))
  assert_true(evalue_is_absent(stats.evalue_lower_ci()))
  assert_true(evalue_option_near(stats.evalue_upper_ci(), 1.429, 1.0e-3))
}

///|
test "the E-value of a measured confounder reproduces the examples of the upstream" {
  assert_true(
    evalue_near(@refuters.observed_covariate_e_value(2.0, 4.0), 3.414, 1.0e-3),
  )
  assert_true(
    evalue_near(@refuters.observed_covariate_e_value(4.0, 2.0), 3.414, 1.0e-3),
  )
  assert_true(
    evalue_near(@refuters.observed_covariate_e_value(0.8, 0.9), 1.500, 1.0e-3),
  )
}

///|
test "the E-value of an interval that crosses the null is one" {
  let stats = @refuters.evalue_rr(1.1, Some(0.9), Some(1.3))
  assert_true(
    evalue_near(stats.evalue_estimate(), 1.1 + (1.1 * 0.1).sqrt(), 1.0e-9),
  )
  assert_true(evalue_option_near(stats.evalue_lower_ci(), 1.0, 1.0e-9))
  assert_true(evalue_is_absent(stats.evalue_upper_ci()))
}

///|
test "the E-value of a risk ratio of one is one" {
  let stats = @refuters.evalue_rr(1.0, None, None)
  assert_true(evalue_near(stats.evalue_estimate(), 1.0, 1.0e-12))
  assert_true(evalue_is_absent(stats.evalue_lower_ci()))
  assert_true(evalue_is_absent(stats.evalue_upper_ci()))
}

///|
test "the E-value of an odds ratio of a rare outcome keeps the odds ratio" {
  let rare = @refuters.evalue_or(0.86, Some(0.75), Some(0.99), true)
  assert_true(evalue_near(rare.converted_estimate(), 0.86, 1.0e-12))
  let common = @refuters.evalue_or(0.86, Some(0.75), Some(0.99), false)
  assert_true(evalue_near(common.converted_estimate(), 0.86.sqrt(), 1.0e-12))
}

///|
/// The fixture of the analysis: five common causes, a thousand rows and a
/// coefficient of ten.
fn evalue_fixture() -> @datasets.Dataset {
  @datasets.linear_dataset(
    SEED,
    1000,
    @datasets.LinearConfig::new(num_common_causes=5),
  )
}

///|
/// The linear regression estimator of the fixture, fitted on it.
fn evalue_estimator(dataset : @datasets.Dataset) -> @estimators.CausalEstimator {
  let estimator = @estimators.CausalEstimator::linear_regression(
    backdoor_estimand(dataset),
  )
  estimator.fit(dataset.frame(), [])
  estimator
}

///|
test "the analysis of a linear regression reports the E-value of its estimate" {
  let dataset = evalue_fixture()
  let estimator = evalue_estimator(dataset)
  let analysis = @refuters.evalue_sensitivity_analyzer(
    estimator,
    dataset.frame(),
    dataset.outcome(),
  )
  // The contrast of the treatment is the one of the two values of the binary
  // treatment of the fixture.
  assert_true(evalue_near(analysis.treatment_delta(), 1.0, 1.0e-12))
  // The analysis reports the numbers of the pure function for the estimate of
  // the estimator.
  let expected = @refuters.evalue_ols(
    analysis.estimate(),
    analysis.standard_error(),
    analysis.outcome_sd(),
    analysis.treatment_delta(),
  )
  assert_true(
    evalue_near(
      analysis.stats().evalue_estimate(),
      expected.evalue_estimate(),
      1.0e-12,
    ),
  )
  assert_true(
    evalue_near(
      analysis.stats().converted_estimate(),
      expected.converted_estimate(),
      1.0e-12,
    ),
  )
  // The estimate of the fixture is far from zero, so its E-value is above one.
  assert_true(analysis.stats().evalue_estimate() > 1.0)
}

///|
test "the analysis benchmarks the E-value against the measured confounders" {
  let dataset = evalue_fixture()
  let estimator = evalue_estimator(dataset)
  let analysis = @refuters.evalue_sensitivity_analyzer(
    estimator,
    dataset.frame(),
    dataset.outcome(),
  )
  // The upstream drops every measured confounder, refits the estimator and
  // reports the Observed Covariate E-value of the confounder.
  assert_eq(analysis.benchmarking().length(), 5)
  for entry in analysis.benchmarking() {
    assert_true(entry.evalue() >= 1.0)
    assert_true(entry.converted_estimate() > 0.0)
  }
}

///|
test "the entry point of the causal model reports the same E-value" {
  let dataset = evalue_fixture()
  let estimator = evalue_estimator(dataset)
  let model = @moonbit_dowhy.CausalModel::new(
    dataset.frame(),
    dataset.treatments(),
    [dataset.outcome()],
    None,
    dataset.common_causes(),
    dataset.instruments(),
    dataset.effect_modifiers(),
    dataset.frontdoor_variables(),
  )
  let analysis = model.refute_e_value(estimator)
  let direct = @refuters.evalue_sensitivity_analyzer(
    estimator,
    dataset.frame(),
    dataset.outcome(),
  )
  assert_true(
    evalue_near(
      analysis.stats().evalue_estimate(),
      direct.stats().evalue_estimate(),
      1.0e-12,
    ),
  )
  assert_true(evalue_near(analysis.estimate(), direct.estimate(), 1.0e-12))
}

///|
test "the E-value of a standardised difference without a standard error has no interval" {
  let stats = @refuters.evalue_md(0.5, None)
  assert_true(
    evalue_near(stats.converted_estimate(), 1.5761733830339912, 1.0e-12),
  )
  assert_true(evalue_is_absent(stats.converted_lower_ci()))
  assert_true(evalue_is_absent(stats.converted_upper_ci()))
  assert_true(evalue_is_absent(stats.evalue_lower_ci()))
  assert_true(evalue_is_absent(stats.evalue_upper_ci()))
}
