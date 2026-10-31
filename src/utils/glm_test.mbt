///|
/// The tests of the generalised linear models.
///
/// The fixture is generated with the deterministic generator of the package,
/// and the expected numbers are the ones `statsmodels.api.GLM` produces on the
/// very same rows, which `_verify/glm_reference.py` prints.
///
/// The two families are the ones the upstream estimator test uses: a binomial
/// family for a binary response and a poisson family for a count response.

///|
/// The rows of the fixture.
const ROWS : Int32 = 800

///|
/// The seed of the fixture.
const SEED : UInt64 = 2024UL

///|
/// The design matrix of the fixture, the response vectors and the treatments.
///
/// The columns of the design matrix are the intercept, the treatment and the
/// two continuous confounders.
fn fixture() -> (@utils.Matrix, Array[Double], Array[Double]) {
  let rng = @utils.Random::new(SEED)
  let constant : Array[Double] = []
  let treatment : Array[Double] = []
  let first : Array[Double] = []
  let second : Array[Double] = []
  let binary : Array[Double] = []
  let count : Array[Double] = []
  for i = 0; i < ROWS; i = i + 1 {
    let x1 = rng.next_normal()
    let x2 = rng.next_normal()
    let u = rng.next_double()
    let t = if u < @utils.sigmoid(-0.2 + 0.9 * x1 - 0.4 * x2) {
      1.0
    } else {
      0.0
    }
    let u = rng.next_double()
    let probability = @utils.sigmoid(0.3 + 0.8 * t - 0.5 * x1 + 0.6 * x2)
    let y_binary = if u < probability { 1.0 } else { 0.0 }
    let u = rng.next_double()
    let rate = u * @math.exp(0.4 + 0.5 * t + 0.3 * x1)
    let y_count = rate.floor()
    constant.push(1.0)
    treatment.push(t)
    first.push(x1)
    second.push(x2)
    binary.push(y_binary)
    count.push(y_count)
  }
  (
    @utils.Matrix::from_columns([constant, treatment, first, second]),
    binary,
    count,
  )
}

///|
/// Whether two numbers agree to the tolerance of the comparison.
fn close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-8
}

///|
/// Whether every number of the two arrays agrees to the tolerance.
fn arrays_close(a : Array[Double], b : Array[Double]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i = 0; i < a.length(); i = i + 1 {
    if !close(a[i], b[i]) {
      return false
    }
  }
  true
}

///|
test "the binomial generalised linear model reproduces the statsmodels fit" {
  let (design, binary, _) = fixture()
  let fit = @utils.glm_fit(
    design,
    binary,
    @utils.GlmFamily::binomial(),
    100,
    1.0e-10,
  )
  assert_true(fit.converged)
  let expected = [
    0.420788813805723, 0.565474795061193, -0.547943802461362, 0.539735559901150,
  ]
  assert_true(arrays_close(fit.beta, expected))
  let expected_errors = [
    0.107675817066780, 0.174952830073824, 0.089943141786421, 0.087234046179152,
  ]
  assert_true(arrays_close(fit.se, expected_errors))
}

///|
test "the poisson generalised linear model reproduces the statsmodels fit" {
  let (design, _, count) = fixture()
  let fit = @utils.glm_fit(
    design,
    count,
    @utils.GlmFamily::poisson(),
    100,
    1.0e-10,
  )
  assert_true(fit.converged)
  let expected = [
    -1.229429494946392, 0.948122043905110, 0.525106127421394, -0.024061064068623,
  ]
  assert_true(arrays_close(fit.beta, expected))
  let expected_errors = [
    0.091448400647183, 0.111540254229397, 0.049093754526808, 0.046180244755200,
  ]
  assert_true(arrays_close(fit.se, expected_errors))
}

///|
test "the predicted means of the generalised linear model match statsmodels" {
  let (design, binary, count) = fixture()
  let binomial = @utils.glm_fit(
    design,
    binary,
    @utils.GlmFamily::binomial(),
    100,
    1.0e-10,
  )
  let predicted = @utils.glm_predict(binomial, design)
  let expected = [
    0.985329646497895, 0.841278729791791, 0.402338766158461, 0.484607550044190, 0.791037008819066,
  ]
  for i = 0; i < expected.length(); i = i + 1 {
    assert_true(close(predicted[i], expected[i]))
  }
  assert_true(close(@utils.mean(predicted), 0.646250000000000))
  let poisson = @utils.glm_fit(
    design,
    count,
    @utils.GlmFamily::poisson(),
    100,
    1.0e-10,
  )
  let rates = @utils.glm_predict(poisson, design)
  let expected_rates = [
    0.014653109526689, 0.866688974160926, 1.201861355163287, 0.330386285448627, 0.219607042026087,
  ]
  for i = 0; i < expected_rates.length(); i = i + 1 {
    assert_true(close(rates[i], expected_rates[i]))
  }
  assert_true(close(@utils.mean(rates), 0.658750000000000))
}

///|
test "the gaussian generalised linear model is an ordinary least squares fit" {
  let (design, _, _) = fixture()
  let response = design.matvec([0.5, 1.5, -0.25, 0.75])
  let glm = @utils.glm_fit(
    design,
    response,
    @utils.GlmFamily::gaussian(),
    100,
    1.0e-10,
  )
  let ols = @utils.ols_fit(design, response)
  assert_true(arrays_close(glm.beta, ols.beta))
  assert_true(arrays_close(glm.se, ols.se))
  assert_true(arrays_close(glm.mu, ols.fitted))
}

///|
test "the covariance of the generalised linear model is the weighted gram matrix" {
  let (design, binary, _) = fixture()
  let fit = @utils.glm_fit(
    design,
    binary,
    @utils.GlmFamily::binomial(),
    100,
    1.0e-10,
  )
  // The variance of the intercept is the first element of the covariance.
  let variance = fit.cov.get(0, 0)
  assert_true(close(variance, 0.011594081797642))
  // The covariance matrix is symmetric.
  for i = 0; i < fit.cov.nrows(); i = i + 1 {
    for j = 0; j < fit.cov.ncols(); j = j + 1 {
      assert_true(close(fit.cov.get(i, j), fit.cov.get(j, i)))
    }
  }
}

///|
test "the family of a generalised linear model has a name" {
  assert_eq(@utils.GlmFamily::gaussian().name(), "gaussian")
  assert_eq(@utils.GlmFamily::binomial().name(), "binomial")
  assert_eq(@utils.GlmFamily::poisson().name(), "poisson")
}
