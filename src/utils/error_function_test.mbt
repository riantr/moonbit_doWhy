///|
/// The tests of the error function and of the standard normal distribution.
///
/// The expected numbers are the ones `scipy.special` and `scipy.stats` produce,
/// which `_verify/distributions_reference.py` prints.
///
/// These functions feed the confidence interval and the p-value of the
/// generalised linear model estimator and the Fisher-z test of the `cm`
/// package, so a wrong value of the error function silently narrows every
/// confidence interval of the port.

///|
/// Whether two numbers agree to the tolerance of the comparison.
fn close_enough(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-12
}

///|
/// test "the complementary error function matches scipy"
test "the complementary error function matches scipy" {
  assert_true(close_enough(@utils.erfc(0.0), 1.000000000000000))
  assert_true(close_enough(@utils.erfc(0.25), 0.723673609831763))
  assert_true(close_enough(@utils.erfc(0.5), 0.479500122186953))
  assert_true(close_enough(@utils.erfc(0.75), 0.288844366346485))
  assert_true(close_enough(@utils.erfc(1.0), 0.157299207050285))
  assert_true(close_enough(@utils.erfc(1.5), 0.033894853524689))
  assert_true(close_enough(@utils.erfc(2.0), 0.004677734981047))
  assert_true(close_enough(@utils.erfc(3.0), 0.000022090496999))
  assert_true(close_enough(@utils.erfc(4.0), 0.000000015417258))
  assert_true(close_enough(@utils.erfc(-0.5), 1.520499877813047))
  assert_true(close_enough(@utils.erfc(-1.0), 1.842700792949715))
}

///|
/// test "the error function matches scipy"
test "the error function matches scipy" {
  assert_true(close_enough(@utils.erf(0.0), 0.000000000000000))
  assert_true(close_enough(@utils.erf(0.25), 0.276326390168237))
  assert_true(close_enough(@utils.erf(0.5), 0.520499877813047))
  assert_true(close_enough(@utils.erf(1.0), 0.842700792949715))
  assert_true(close_enough(@utils.erf(2.0), 0.995322265018953))
  assert_true(close_enough(@utils.erf(-0.5), -0.520499877813047))
}

///|
/// test "the cumulative distribution function of the normal distribution matches scipy"
test "the cumulative distribution function of the normal distribution matches scipy" {
  assert_true(close_enough(@utils.normal_cdf(-3.0), 0.001349898031630))
  assert_true(
    close_enough(@utils.normal_cdf(-1.959963984540054), 0.025000000000000),
  )
  assert_true(close_enough(@utils.normal_cdf(-1.0), 0.158655253931457))
  assert_true(close_enough(@utils.normal_cdf(0.0), 0.500000000000000))
  assert_true(close_enough(@utils.normal_cdf(1.0), 0.841344746068543))
  assert_true(
    close_enough(@utils.normal_cdf(1.959963984540054), 0.975000000000000),
  )
  assert_true(close_enough(@utils.normal_cdf(3.0), 0.998650101968370))
}

///|
/// test "the quantile function of the normal distribution matches scipy"
test "the quantile function of the normal distribution matches scipy" {
  assert_true(close_enough(@utils.normal_ppf(0.001), -3.090232306167813))
  assert_true(close_enough(@utils.normal_ppf(0.025), -1.959963984540054))
  assert_true(close_enough(@utils.normal_ppf(0.1), -1.281551565544600))
  assert_true(close_enough(@utils.normal_ppf(0.5), 0.000000000000000))
  assert_true(close_enough(@utils.normal_ppf(0.9), 1.281551565544600))
  assert_true(close_enough(@utils.normal_ppf(0.975), 1.959963984540054))
  assert_true(close_enough(@utils.normal_ppf(0.999), 3.090232306167813))
}

///|
/// test "the regularised upper incomplete gamma function is the complement of the lower one"
test "the regularised upper incomplete gamma function is the complement of the lower one" {
  assert_true(close_enough(@utils.gammaincc(0.5, 0.25), 0.479500122186953))
  assert_true(close_enough(@utils.gammaincc(0.5, 4.0), 0.004677734981047))
  assert_true(close_enough(@utils.gammaincc(1.0, 2.0), 0.135335283236613))
  assert_true(close_enough(@utils.gammaincc(0.5, 0.0), 1.0))
}
