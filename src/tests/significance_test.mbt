/// Tests for the significance test of the refutations.
///
/// The case mirrors `dowhy.causal_refuter.test_significance`: the automatic
/// test uses the two sided percentile test of the bootstrap for a hundred
/// simulations and more and the test of the normal distribution below that,
/// and either of the two can be asked for by name.  The refutations that sever
/// the causal relation test the zero estimate against the estimates they
/// produced, the other ones test the estimate of the data.
///
/// The last case is the one of the upstream test file
/// `tests/test_causal_refuter.py`: the percentile test of the bootstrap on
/// five thousand standard normal deviates, which the upstream asserts to be
/// above 0.95.  The other case of that file checks that the placeholder method
/// of the base class of the refuters raises, and it has no counterpart here:
/// the port has no base class whose refutation is a placeholder.

///|
/// The simulations of the cases of this file.
fn significance_simulations(count : Int32) -> Array[Double] {
  let simulations : Array[Double] = []
  for i in 0..<count {
    simulations.push(i.to_double())
  }
  simulations
}

///|
test "the significance test uses the bootstrap test for a hundred simulations" {
  let (p_value, significant) = @refuters.test_significance(
    0.0,
    significance_simulations(100),
  )
  // The percentile test counts the estimates that are above the estimate and
  // the half of the ones that are equal to it.
  assert_true((p_value - 0.01).abs() < 1.0e-12)
  assert_true(significant)
}

///|
test "the significance test uses the normal test below a hundred simulations" {
  let (p_value, significant) = @refuters.test_significance(
    0.0,
    significance_simulations(99),
  )
  // The z-score of the estimate against the mean and the standard deviation
  // of the simulations.
  assert_true((p_value - 0.04320536648685008).abs() < 1.0e-12)
  assert_true(significant)
}

///|
test "the significance test can be asked for by name" {
  let simulations = [1.0, 2.0, 3.0, 4.0, 5.0]
  let (bootstrap, _) = @refuters.test_significance(
    3.0,
    simulations,
    test_type=@refuters.SignificanceTestType::bootstrap(),
  )
  // Half of the simulations are above the estimate and none of them is equal
  // to it, so the percentile test is the whole of the distribution.
  assert_true((bootstrap - 1.0).abs() < 1.0e-12)
  let (normal, _) = @refuters.test_significance(
    3.0,
    simulations,
    test_type=@refuters.SignificanceTestType::normal(),
  )
  // The estimate is the mean of the simulations, so the z-score is zero.
  assert_true((normal - 0.5).abs() < 1.0e-12)
}

///|
test "the significance test counts the ties as a half" {
  let simulations = [1.0, 1.0, 1.0, 2.0, 2.0]
  let (p_value, _) = @refuters.test_significance(
    1.0,
    simulations,
    test_type=@refuters.SignificanceTestType::bootstrap(),
  )
  // Three of the simulations are equal to the estimate and none of them is
  // above it, so the percentile test is a tenth.
  assert_true((p_value - 0.6).abs() < 1.0e-12)
}

///|
test "the significance test takes the level of the test as an argument" {
  let simulations = significance_simulations(99)
  let (p_value, significant) = @refuters.test_significance(
    0.0,
    simulations,
    significance_level=0.01,
  )
  assert_true((p_value - 0.04320536648685008).abs() < 1.0e-12)
  assert_false(significant)
}

///|
test "the significance test of an empty distribution is not significant" {
  let (p_value, significant) = @refuters.test_significance(0.0, [])
  assert_eq(p_value, 1.0)
  assert_false(significant)
}

///|
/// The standard normal deviates of the case of the upstream.
fn standard_normal_deviations(count : Int32, seed : UInt64) -> Array[Double] {
  let generator = @utils.Random::new(seed)
  let deviations : Array[Double] = []
  for _ in 0..<count {
    deviations.push(generator.next_normal())
  }
  deviations
}

///|
test "the percentile test of the bootstrap agrees with the upstream case" {
  let deviations = standard_normal_deviations(5000, 2027UL)
  let p_value = @refuters.bootstrap_significance(0.0, deviations)
  // The upstream asserts that the p-value of its case is above 0.95, and the
  // draw of the upstream gives 0.9864.
  assert_true(p_value > 0.95)
  // The draw of the port gives 0.9936, which the reference script computes.
  assert_true((p_value - 0.9936).abs() < 1.0e-12)
}
