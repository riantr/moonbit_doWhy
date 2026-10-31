///|
/// The tests of the chi-square and the F distribution, and of the rank
/// correlations.
///
/// The expected numbers are the ones `scipy.stats` produces, which
/// `_verify/distributions_reference.py` prints.

///|
/// Whether two numbers agree to the tolerance of the comparison.
fn near(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-10
}

///|
test "the chi-square distribution function matches scipy" {
  assert_true(near(@utils.chi2_cdf(0.5, 1.0), 0.520499877813047))
  assert_true(near(@utils.chi2_cdf(1.0, 3.0), 0.198748043098799))
  assert_true(near(@utils.chi2_cdf(3.84, 1.0), 0.949956478751295))
  assert_true(near(@utils.chi2_cdf(10.0, 5.0), 0.924764753853488))
  assert_true(near(@utils.chi2_cdf(23.0, 10.0), 0.989253421616717))
  assert_true(near(@utils.chi2_cdf(0.001, 4.0), 0.000000124958341))
}

///|
test "the chi-square survival function matches scipy" {
  assert_true(near(@utils.chi2_sf(0.5, 1.0), 0.479500122186953))
  assert_true(near(@utils.chi2_sf(3.84, 1.0), 0.050043521248705))
  assert_true(near(@utils.chi2_sf(10.0, 5.0), 0.075235246146512))
  assert_true(near(@utils.chi2_sf(23.0, 10.0), 0.010746578383283))
}

///|
test "the chi-square quantile function matches scipy" {
  assert_true(near(@utils.chi2_ppf(0.5, 1.0), 0.454936423119572))
  assert_true(near(@utils.chi2_ppf(0.95, 3.0), 7.814727903251179))
  assert_true(near(@utils.chi2_ppf(0.99, 10.0), 23.209251158954356))
  assert_true(near(@utils.chi2_ppf(0.025, 1.0), 0.000982069117175))
  assert_true(near(@utils.chi2_ppf(0.999, 7.0), 24.321886347856854))
}

///|
test "the F distribution function matches scipy" {
  assert_true(near(@utils.f_cdf(1.0, 3.0, 10.0), 0.567662796978303))
  assert_true(near(@utils.f_cdf(2.5, 5.0, 20.0), 0.935072953899055))
  assert_true(near(@utils.f_cdf(0.5, 1.0, 1.0), 0.391826552030607))
  assert_true(near(@utils.f_cdf(4.0, 12.0, 30.0), 0.998998842009415))
}

///|
test "the F survival function matches scipy" {
  assert_true(near(@utils.f_sf(1.0, 3.0, 10.0), 0.432337203021697))
  assert_true(near(@utils.f_sf(2.5, 5.0, 20.0), 0.064927046100945))
  assert_true(near(@utils.f_sf(0.5, 1.0, 1.0), 0.608173447969393))
  assert_true(near(@utils.f_sf(4.0, 12.0, 30.0), 0.001001157990585))
}

///|
test "the F quantile function matches scipy" {
  assert_true(near(@utils.f_ppf(0.5, 3.0, 10.0), 0.845080576591714))
  assert_true(near(@utils.f_ppf(0.95, 5.0, 20.0), 2.710889837209691))
  assert_true(near(@utils.f_ppf(0.975, 1.0, 1.0), 647.789011477844156))
  assert_true(near(@utils.f_ppf(0.99, 12.0, 30.0), 2.843095199077730))
}

///|
test "the Pearson correlation matches numpy" {
  let x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
  let y = [2.0, 1.0, 4.0, 3.0, 6.0, 5.0, 8.0, 7.0]
  assert_true(near(@utils.pearson_corr(x, y), 0.904761904761905))
}

///|
test "the Spearman correlation matches scipy" {
  let x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
  let y = [2.0, 1.0, 4.0, 3.0, 6.0, 5.0, 8.0, 7.0]
  assert_true(near(@utils.spearman_corr(x, y), 0.904761904761905))
  // With ties the ranks get the mean rank, like `pandas.Series.rank`.
  let xt = [1.0, 2.0, 2.0, 3.0, 4.0, 4.0]
  let yt = [1.0, 3.0, 2.0, 4.0, 3.0, 4.0]
  assert_true(near(@utils.spearman_corr(xt, yt), 0.772727272727273))
}

///|
test "the Kendall correlation matches scipy" {
  let x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
  let y = [2.0, 1.0, 4.0, 3.0, 6.0, 5.0, 8.0, 7.0]
  assert_true(near(@utils.kendall_tau(x, y), 0.714285714285714))
  let xt = [1.0, 2.0, 2.0, 3.0, 4.0, 4.0]
  let yt = [1.0, 3.0, 2.0, 4.0, 3.0, 4.0]
  assert_true(near(@utils.kendall_tau(xt, yt), 0.692307692307692))
}

///|
test "the regularised incomplete gamma function has the known values" {
  // The exponential distribution is the gamma distribution with the shape one.
  assert_true(near(@utils.gammainc(1.0, 1.0), 0.632120558828558))
  assert_true(near(@utils.gammainc(1.0, 2.0), 0.864664716763387))
  assert_true(near(@utils.gammainc(2.5, 3.0), 0.693781081586721))
  assert_true(near(@utils.gammainc(0.5, 0.25), 0.520499877813047))
}
