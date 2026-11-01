///|
/// The tests of the stochastic models of the `gcm` package.
///
/// The expectations are the ones of the upstream tests of
/// `dowhy.gcm.stochastic_models`, which are in
/// `tests/gcm/test_stochastic_models.py`. The upstream
/// `BayesianGaussianMixtureDistribution` and the beta distribution are not
/// part of the port, so the three tests of the upstream that use them have no
/// counterpart here.
///
/// The fixtures are drawn with the deterministic generator of the `utils`
/// package, and the expected numbers are the ones the upstream
/// `dowhy.gcm.stochastic_models` produces on the very same rows, which
/// `_verify/gcm_stochastic_models_reference.py` prints.

///|
/// The seed of the fixture of the fit of a normal distribution.
const STOCHASTIC_SEED_FIT : UInt64 = 2030UL

///|
/// The seed of the fixture of the fit of a normal distribution whose samples
/// are drawn afterwards.
const STOCHASTIC_SEED_AUTO : UInt64 = 2031UL

///|
/// The seed of the samples that are drawn from the fitted distribution.
const STOCHASTIC_SEED_AUTO_DRAW : UInt64 = 2032UL

///|
/// The seed of the samples of the distribution whose parameters are recovered.
const STOCHASTIC_SEED_SCALED : UInt64 = 2033UL

///|
/// The seed of the fixture of the empirical distribution.
const STOCHASTIC_SEED_EMPIRICAL : UInt64 = 2034UL

///|
/// The seed of the samples that are drawn from the empirical distribution.
const STOCHASTIC_SEED_EMPIRICAL_DRAW : UInt64 = 2035UL

///|
/// The number of rows of the fixture of the fit of a normal distribution.
const STOCHASTIC_FIT_ROWS : Int32 = 1000

///|
/// The number of rows of the fixture of the fit of a normal distribution whose
/// samples are drawn afterwards.
const STOCHASTIC_AUTO_ROWS : Int32 = 5000

///|
/// The number of the samples that are drawn from a distribution.
const STOCHASTIC_DRAWN_ROWS : Int32 = 1000

///|
/// The number of the samples of the distribution whose parameters are
/// recovered.
const STOCHASTIC_SCALED_ROWS : Int32 = 10000

///|
/// The number of rows of the fixture of the empirical distribution.
const STOCHASTIC_EMPIRICAL_ROWS : Int32 = 1000

///|
/// The tolerance of the comparison of the numbers of the reference script.
const STOCHASTIC_TOLERANCE : Double = 1.0e-9

///|
/// Whether two numbers agree to the tolerance of the comparison.
fn stochastic_near(a : Double, b : Double, tolerance : Double) -> Bool {
  (a - b).abs() <= tolerance
}

///|
/// A column of standard normal draws.
fn stochastic_normal_rows(seed : UInt64, rows : Int32) -> Array[Double] {
  let rng = @utils.Random::new(seed)
  let values : Array[Double] = []
  for _ in 0..<rows {
    values.push(rng.next_normal())
  }
  values
}

///|
test "a distribution with fixed parameters keeps them" {
  let normal = @gcm.StochasticModel::normal(0.0, 1.0)
  assert_true(stochastic_near(normal.loc(), 0.0, 0.0))
  assert_true(stochastic_near(normal.scale(), 1.0, 0.0))
  let laplace = @gcm.StochasticModel::laplace(2.0, 3.0)
  assert_true(stochastic_near(laplace.loc(), 2.0, 0.0))
  assert_true(stochastic_near(laplace.scale(), 3.0, 0.0))
  let uniform = @gcm.StochasticModel::uniform(-1.0, 1.0)
  assert_true(stochastic_near(uniform.loc(), -1.0, 0.0))
  assert_true(stochastic_near(uniform.scale(), 1.0, 0.0))
}

///|
test "a fitted normal distribution has the location and the scale of the data" {
  let rows = stochastic_normal_rows(STOCHASTIC_SEED_FIT, STOCHASTIC_FIT_ROWS)
  let fitted = @gcm.StochasticModel::normal(0.0, 1.0)
    .with_estimated_parameters()
    .fit(rows)
  assert_true(
    stochastic_near(fitted.loc(), -0.046280731933, STOCHASTIC_TOLERANCE),
  )
  assert_true(
    stochastic_near(fitted.scale(), 1.032534220912, STOCHASTIC_TOLERANCE),
  )
  // The upstream asserts the same two numbers with a tolerance of 0.1.
  assert_true(fitted.loc().abs() <= 0.1)
  assert_true((fitted.scale() - 1.0).abs() <= 0.1)
}

///|
test "the samples of a fitted normal distribution have the location and the scale of the data" {
  let rows = stochastic_normal_rows(STOCHASTIC_SEED_AUTO, STOCHASTIC_AUTO_ROWS)
  let fitted = @gcm.StochasticModel::normal(0.0, 1.0)
    .with_estimated_parameters()
    .fit(rows)
  let drawn = fitted.draw_samples(
    STOCHASTIC_DRAWN_ROWS,
    @utils.Random::new(STOCHASTIC_SEED_AUTO_DRAW),
  )
  assert_true(
    stochastic_near(@utils.mean(drawn), 0.045109173244, STOCHASTIC_TOLERANCE),
  )
  assert_true(
    stochastic_near(@utils.std(drawn), 1.006425581295, STOCHASTIC_TOLERANCE),
  )
  // The upstream asserts the same two numbers with a tolerance of 0.2.
  assert_true(@utils.mean(drawn).abs() <= 0.2)
  assert_true((@utils.std(drawn) - 1.0).abs() <= 0.2)
}

///|
test "a normal distribution fitted on the samples of a normal distribution recovers its parameters" {
  let drawn = @gcm.StochasticModel::normal(3.0, 2.0).draw_samples(
    STOCHASTIC_SCALED_ROWS,
    @utils.Random::new(STOCHASTIC_SEED_SCALED),
  )
  let fitted = @gcm.StochasticModel::normal(0.0, 1.0)
    .with_estimated_parameters()
    .fit(drawn)
  assert_true(
    stochastic_near(fitted.loc(), 3.021156300699, STOCHASTIC_TOLERANCE),
  )
  assert_true(
    stochastic_near(fitted.scale(), 2.018694239408, STOCHASTIC_TOLERANCE),
  )
  // The upstream asserts the same two numbers with a tolerance of 0.3.
  assert_true((fitted.loc() - 3.0).abs() <= 0.3)
  assert_true((fitted.scale() - 2.0).abs() <= 0.3)
}

///|
test "every sample of an empirical distribution is one of the samples it was fitted on" {
  let rows = stochastic_normal_rows(
    STOCHASTIC_SEED_EMPIRICAL,
    STOCHASTIC_EMPIRICAL_ROWS,
  )
  let fitted = @gcm.StochasticModel::empirical().fit(rows)
  let drawn = fitted.draw_samples(
    STOCHASTIC_DRAWN_ROWS,
    @utils.Random::new(STOCHASTIC_SEED_EMPIRICAL_DRAW),
  )
  for value in drawn {
    assert_true(rows.contains(value))
  }
  assert_true(stochastic_near(drawn[0], 0.184247957548, STOCHASTIC_TOLERANCE))
  assert_true(stochastic_near(drawn[1], -0.473915193948, STOCHASTIC_TOLERANCE))
  assert_true(stochastic_near(drawn[2], 1.714438750947, STOCHASTIC_TOLERANCE))
}
