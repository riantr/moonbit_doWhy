///|
/// The tests of the confidence intervals of the `gcm` package.
///
/// The expected numbers are the ones the upstream
/// `dowhy.gcm.confidence_intervals` produces, which
/// `_verify/gcm_stats_reference.py` prints.
///
/// The case of the upstream test file `tests/gcm/test_confidence_intervals.py`
/// is among the cases of this file: the counter of the upstream returns 1, 2,
/// ..., 20, so the median of the twenty bootstrap results is 10.5 and their
/// 5th and 95th percentile are 1.95 and 19.05.

///|
/// The seed of the generator of the test.
const CI_SEED : UInt64 = 2024UL

///|
/// Whether two numbers agree to the tolerance of the comparison.
fn ci_near(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-9
}

///|
/// test "the confidence interval of a counter has the expected bounds"
///
/// The counter returns 1, 2, ..., 20, so the twenty bootstrap results are the
/// numbers from 1 to 20. Their median is 10.5 and their 5th and 95th
/// percentile are 1.95 and 19.05.
test "the confidence interval of a counter has the expected bounds" {
  let mut counter = 0.0
  let estimation_func = fn(_seed : UInt64) -> Array[Double] {
    counter = counter + 1.0
    [counter]
  }
  let summary_func = fn(_results : @utils.Matrix) -> Array[Double] { [10.5] }
  let (summary, intervals) = @gcm.confidence_intervals(
    estimation_func,
    0.95,
    20,
    summary_func,
    @utils.Random::new(CI_SEED),
  )
  assert_eq(summary.length(), 1)
  assert_true(ci_near(summary[0], 10.5))
  assert_eq(intervals.length(), 1)
  assert_eq(intervals[0].length(), 2)
  assert_true(ci_near(intervals[0][0], 1.95))
  assert_true(ci_near(intervals[0][1], 19.05))
}

///|
/// test "the geometric median is the summary of the bootstrap results"
///
/// The geometric median is the default summary of the upstream code, so it is
/// the summary of the results of a counter as well.
test "the geometric median is the summary of the bootstrap results" {
  let mut counter = 0.0
  let estimation_func = fn(_seed : UInt64) -> Array[Double] {
    counter = counter + 1.0
    [counter]
  }
  let (summary, intervals) = @gcm.confidence_intervals(
    estimation_func,
    0.95,
    20,
    fn(results : @utils.Matrix) -> Array[Double] {
      @gcm.estimate_geometric_median(results)
    },
    @utils.Random::new(CI_SEED),
  )
  assert_eq(summary.length(), 1)
  assert_true(ci_near(summary[0], 10.5))
  assert_true(ci_near(intervals[0][0], 1.95))
  assert_true(ci_near(intervals[0][1], 19.05))
}
