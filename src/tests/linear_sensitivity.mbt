///| Tests for the linear sensitivity analysis.
///
/// The cases mirror the three linear cases of
/// `tests/causal_refuters/test_add_unobserved_common_cause.py`, which drive the
/// analyzer of the upstream through
/// `refute_estimate(method_name="add_unobserved_common_cause",
/// simulation_method="linear-partial-R2", benchmark_common_causes=["W3"],
/// effect_fraction_on_treatment=[1, 2, 3])` and assert
///
/// * every partial R2 of the benchmarking results is between 0 and 1,
/// * `stats["r2yt_w"]` and `stats["robustness_value"]` are between 0 and 1,
/// * the bias adjusted estimates lie on the far side of the estimate from zero,
///   in the direction `confounder_increases_estimate` names,
/// * `compute_bias_adjusted` with the two sets of partial R2 of the upstream
///   reports an adjusted estimate that is farther from the original estimate for
///   the first set than for the second,
/// * the robustness value of a data set without confounders is above `0.95`.
///
/// The fixture is the one of the upstream file: six common causes, five hundred
/// rows, a coefficient of ten, a treatment noise of ten and an outcome noise of
/// one. The upstream builds it with `dowhy.datasets.linear_dataset` and drops its
/// `W4` column; the port generates six common causes directly, so its columns
/// are `W0` to `W5` and the benchmark common cause `W3` is the fourth of them.
/// The two noise parameters of the upstream were added to the configuration of
/// the port for this fixture; their defaults are the ones the port already used,
/// so every other fixture of the port keeps its rows.
///
/// The plot of the upstream is not ported, so the assertion that a figure was
/// drawn has no counterpart here. The third case of the upstream file builds its
/// data set from the graph of the generator instead of from the graph of the
/// test, which is the only difference between the two fixtures of the upstream;
/// the port has one graph for both, so the case is the first one here.
/// The cases of this file mirror the analysis of the sensitivity of the notebook of the upstream.  The notebook `sensitivity_analysis_testing.ipynb`.

///|
/// The fixture of the upstream file: six common causes, five hundred rows, a
/// coefficient of ten, a treatment noise of ten and an outcome noise of one.
fn sensitivity_fixture() -> @datasets.Dataset {
  @datasets.linear_dataset(
    SEED,
    500,
    @datasets.LinearConfig::new(
      num_common_causes=6,
      stddev_treatment_noise=10.0,
      stddev_outcome_noise=1.0,
    ),
  )
}

///|
/// The linear regression estimator of the fixture, fitted on it.
fn sensitivity_estimator(
  dataset : @datasets.Dataset,
) -> @estimators.CausalEstimator {
  let estimator = @estimators.CausalEstimator::linear_regression(
    backdoor_estimand(dataset),
  )
  estimator.fit(dataset.frame(), [])
  estimator
}

///|
/// The analysis of the fixture, with the strengths of the upstream.
fn sensitivity_analysis(
  dataset : @datasets.Dataset,
  estimator : @estimators.CausalEstimator,
) -> @refuters.LinearSensitivityAnalyzer {
  @refuters.linear_sensitivity_analyzer(
    estimator,
    dataset.frame(),
    dataset.treatments()[0],
    ["W3"],
    [1.0, 2.0, 3.0],
    None,
    1.0,
    0.05,
  )
}

///|
test "the analysis of a data set with confounders keeps every partial R2 inside the unit interval" {
  let dataset = sensitivity_fixture()
  let estimator = sensitivity_estimator(dataset)
  let analysis = sensitivity_analysis(dataset, estimator)
  for value in analysis.r2tu_w() {
    assert_true(value >= 0.0 && value <= 1.0)
  }
  for value in analysis.r2yu_tw() {
    assert_true(value >= 0.0 && value <= 1.0)
  }
  assert_true(analysis.r2yt_w() >= 0.0 && analysis.r2yt_w() <= 1.0)
  assert_true(
    analysis.robustness_value() >= 0.0 && analysis.robustness_value() <= 1.0,
  )
}

///|
test "the analysis of a data set with confounders moves the estimate toward zero" {
  let dataset = sensitivity_fixture()
  let estimator = sensitivity_estimator(dataset)
  let analysis = sensitivity_analysis(dataset, estimator)
  // The confounder increases the estimate, so the bias moves it toward zero and
  // the adjusted estimates are all below the estimate. The upstream reaches the
  // same flag, because its `sensitivity_linear_partial_r2` builds the analyzer
  // without the flag of its refuter and the analyzer keeps its own default.
  assert_true(analysis.confounder_increases_estimate())
  for value in analysis.bias_adjusted_estimate() {
    assert_true(value <= analysis.estimate())
  }
}

///|
test "the given strengths of the confounding are ordered by the distance of the adjusted estimate" {
  let dataset = sensitivity_fixture()
  let estimator = sensitivity_estimator(dataset)
  let analysis = sensitivity_analysis(dataset, estimator)
  // The upstream calls the analysis with the two sets of partial R2 of its own
  // and compares the distance of the two adjusted estimates from the estimate.
  let terms = @refuters.compute_bias_adjusted(analysis, [0.7, 0.2], [0.9, 0.3])
  let estimates = terms.estimates()
  assert_eq(estimates.length(), 2)
  let first = (analysis.estimate() - estimates[0]).abs()
  let second = (analysis.estimate() - estimates[1]).abs()
  assert_true(first > second)
}

///|
test "the robustness value of the estimate is the one of the analysis" {
  let dataset = sensitivity_fixture()
  let estimator = sensitivity_estimator(dataset)
  let analysis = sensitivity_analysis(dataset, estimator)
  // The robustness value is the strength the confounder needs to remove the
  // whole estimate, so it grows with the t statistic of the estimate.
  assert_true(analysis.robustness_value() > 0.0)
  assert_true(analysis.robustness_value() <= 1.0)
  assert_true(analysis.robustness_value_alpha() <= 1.0)
  assert_true(analysis.partial_f2() > 0.0)
  assert_true(analysis.t_statistic() != 0.0)
  // The design holds the intercept, the treatment and the six common causes,
  // so the degrees of freedom of the fit are the rows less those eight.
  assert_eq(analysis.degree_of_freedom(), 500 - 8)
}

///|
test "the analysis of a data set without confounders is robust" {
  let dataset = @datasets.linear_dataset(
    SEED,
    500,
    @datasets.LinearConfig::new(
      stddev_treatment_noise=10.0,
      stddev_outcome_noise=1.0,
    ),
  )
  let estimator = sensitivity_estimator(dataset)
  let analysis = @refuters.linear_sensitivity_analyzer(
    estimator,
    dataset.frame(),
    dataset.treatments()[0],
    [],
    [1.0, 2.0, 3.0],
    None,
    1.0,
    0.05,
  )
  // A data set without confounders has a treatment that is explained by
  // nothing, so the estimate is certain and the robustness value is high.
  assert_true(analysis.robustness_value() >= 0.95)
  assert_true(analysis.robustness_value() <= 1.0)
}
