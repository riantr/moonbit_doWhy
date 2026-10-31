///|
/// The tests of the causal mechanisms of the `gcm` package.
///
/// The expectations are the ones of the upstream tests of
/// `dowhy.gcm.causal_mechanisms`, which are in `tests/gcm/test_fcms.py`.

///|
/// Whether two numbers are close to each other.
fn mechanism_near(a : Double, b : Double, tolerance : Double) -> Bool {
  (a - b).abs() <= tolerance
}

///|
/// Whether two arrays of numbers are close to each other.
fn mechanism_arrays_near(
  a : Array[Double],
  b : Array[Double],
  tolerance : Double,
) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i = 0; i < a.length(); i = i + 1 {
    if !mechanism_near(a[i], b[i], tolerance) {
      return false
    }
  }
  true
}

///|
/// A design matrix with a single column.
fn mechanism_column(values : Array[Double]) -> @utils.Matrix {
  @utils.Matrix::from_columns([values])
}

///|
/// A design matrix with two columns.
fn mechanism_two_columns(
  first : Array[Double],
  second : Array[Double],
) -> @utils.Matrix {
  @utils.Matrix::from_columns([first, second])
}

///|
/// The full factorial design over {-1, 0, 1} of two parents, whose columns are
/// orthogonal, so that a fit of the sum of the parents on them is exact.
fn mechanism_factorial_column() -> @utils.Matrix {
  let first : Array[Double] = []
  let second : Array[Double] = []
  for a in -1..<=1 {
    for b in -1..<=1 {
      first.push(a.to_double())
      second.push(b.to_double())
    }
  }
  mechanism_two_columns(first, second)
}

///|
/// The noise of a linear relation, with a fixed pattern.
fn mechanism_noise() -> Array[Double] {
  [0.1, -0.1, 0.2, -0.2, 0.05, -0.05, 0.15, -0.15]
}

///|
/// A noise pattern that does not lean to one side of the linear relation, so
/// that the least squares fit recovers the coefficients of the relation
/// exactly.
fn mechanism_balanced_noise() -> Array[Double] {
  [0.1, -0.1, 0.1, -0.1, -0.1, 0.1, -0.1, 0.1]
}

///|
/// The parents of a linear relation whose noise does not lean to one side.
fn mechanism_balanced_column() -> @utils.Matrix {
  mechanism_column([-3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0, 4.0])
}

///|
test "the post non-linear model of the identity function estimates the noise" {
  let x = mechanism_column([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0])
  let noise = mechanism_noise()
  let y : Array[Double] = []
  for i = 0; i < x.nrows(); i = i + 1 {
    y.push(2.0 * x.get(i, 0) + noise[i])
  }
  let model = @gcm.CausalMechanism::post_nonlinear(
    @gcm.PredictionModel::with_fixed_parameters([2.0], 0.0),
    @gcm.StochasticModel::empirical(),
    @gcm.InvertibleFunction::identity(),
  )
  assert_true(mechanism_arrays_near(model.estimate_noise(y, x), noise, 1.0e-9))
}

///|
test "the post non-linear model of the identity function evaluates the target" {
  let model = @gcm.CausalMechanism::post_nonlinear(
    @gcm.PredictionModel::with_fixed_parameters([2.0], 0.0),
    @gcm.StochasticModel::empirical(),
    @gcm.InvertibleFunction::identity(),
  )
  assert_true(
    mechanism_near(
      model.evaluate(mechanism_column([2.0]), [0.0])[0],
      4.0,
      1.0e-12,
    ),
  )
  assert_true(
    mechanism_near(
      model.evaluate(mechanism_column([2.0]), [1.0])[0],
      5.0,
      1.0e-12,
    ),
  )
}

///|
test "the post non-linear model of the exponential function estimates the noise" {
  let x = mechanism_column([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0])
  let noise = mechanism_noise()
  let y : Array[Double] = []
  for i = 0; i < x.nrows(); i = i + 1 {
    y.push(@math.exp(2.0 * x.get(i, 0) + noise[i]))
  }
  let model = @gcm.CausalMechanism::post_nonlinear(
    @gcm.PredictionModel::with_fixed_parameters([2.0], 0.0),
    @gcm.StochasticModel::empirical(),
    @gcm.InvertibleFunction::exponential(),
  )
  assert_true(mechanism_arrays_near(model.estimate_noise(y, x), noise, 1.0e-9))
  assert_true(
    mechanism_near(
      model.evaluate(mechanism_column([2.0]), [0.0])[0],
      @math.exp(4.0),
      1.0e-12,
    ),
  )
}

///|
test "the post non-linear model of the logarithm estimates the noise" {
  let x = mechanism_column([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0])
  let noise = mechanism_noise()
  let y : Array[Double] = []
  for i = 0; i < x.nrows(); i = i + 1 {
    y.push(@math.ln(2.0 * x.get(i, 0) + noise[i]))
  }
  let model = @gcm.CausalMechanism::post_nonlinear(
    @gcm.PredictionModel::with_fixed_parameters([2.0], 0.0),
    @gcm.StochasticModel::empirical(),
    @gcm.InvertibleFunction::logarithmic(),
  )
  assert_true(mechanism_arrays_near(model.estimate_noise(y, x), noise, 1.0e-9))
  assert_true(
    mechanism_near(
      model.evaluate(mechanism_column([2.0]), [0.0])[0],
      @math.ln(4.0),
      1.0e-12,
    ),
  )
  assert_true(
    mechanism_near(
      model.evaluate(mechanism_column([2.0]), [1.0])[0],
      @math.ln(5.0),
      1.0e-12,
    ),
  )
}

///|
test "the additive noise model learns the coefficients of a linear relation" {
  let x = mechanism_balanced_column()
  let noise = mechanism_balanced_noise()
  let y : Array[Double] = []
  for i = 0; i < x.nrows(); i = i + 1 {
    y.push(2.0 * x.get(i, 0) + 2.0 + noise[i])
  }
  let model = @gcm.CausalMechanism::additive_noise(
    @gcm.PredictionModel::linear(),
  ).fit(x, y)
  assert_true(
    mechanism_near(model.prediction_model().coefficients()[0], 2.0, 0.02),
  )
  assert_true(mechanism_near(model.prediction_model().intercept(), 2.0, 0.02))
}

///|
test "the additive noise model fits the noise to the residuals" {
  let x = mechanism_column([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0])
  let noise = mechanism_noise()
  let y : Array[Double] = []
  for i = 0; i < x.nrows(); i = i + 1 {
    y.push(2.0 * x.get(i, 0) + noise[i])
  }
  let model = @gcm.CausalMechanism::additive_noise(
    @gcm.PredictionModel::linear(),
  ).fit(x, y)
  let residuals = model.noise_model().samples()
  assert_eq(residuals.length(), noise.length())
  let mean = @utils.mean(residuals)
  assert_true(mechanism_near(mean, 0.0, 0.02))
}

///|
test "the discrete additive noise model estimates the noise" {
  // The parents and the target of the fixture are the full factorial design
  // over {-1, 0, 1}, so the fit of the target on the parents is exact and the
  // noise of the upstream test follows.
  let x = mechanism_factorial_column()
  let y = [-2.0, -1.0, 0.0, -1.0, 0.0, 1.0, 0.0, 1.0, 2.0]
  let model = @gcm.CausalMechanism::discrete_additive_noise(
    @gcm.PredictionModel::linear(),
  ).fit(x, y)
  let noise = model.estimate_noise(
    [0.0, 1.0, 2.0],
    mechanism_two_columns([-1.0, 0.0, 0.0], [1.0, 0.0, 1.0]),
  )
  assert_true(mechanism_arrays_near(noise, [0.0, 1.0, 1.0], 1.0e-9))
}

///|
test "the discrete additive noise model rounds the prediction" {
  let x = @utils.Matrix::from_columns([[0.1, 10.5, 20.0, 30.7, 40.3]])
  let y = [0.0, 10.0, 20.0, 30.0, 40.0]
  let model = @gcm.CausalMechanism::discrete_additive_noise(
    @gcm.PredictionModel::linear(),
  ).fit(x, y)
  let evaluated = model.evaluate(
    @utils.Matrix::from_columns([
      [-100.0, -32.4, 0.4, 4.0, 9.0, 11.0, 30.1, 101.4, 0.9],
    ]),
    [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
  )
  assert_true(
    mechanism_arrays_near(
      evaluated,
      [-100.0, -32.0, 0.0, 4.0, 9.0, 11.0, 30.0, 101.0, 1.0],
      1.0e-9,
    ),
  )
}

///|
test "the classifier mechanism draws samples of a class" {
  let x = mechanism_column([-3.0, -2.5, -2.0, -1.5, 1.5, 2.0, 2.5, 3.0])
  let y = ["a", "a", "a", "a", "b", "b", "b", "b"]
  let model = @gcm.CausalMechanism::classifier(
    @gcm.ClassificationModel::logistic(),
  ).fit_categorical(x, y)
  let rng = @utils.Random::new(42UL)
  let samples = model.draw_categorical_samples(
    mechanism_column([-3.0, -2.0, 2.0, 3.0]),
    rng,
  )
  assert_eq(samples.length(), 4)
  assert_eq(samples[0], "a")
  assert_eq(samples[3], "b")
}

///|
test "the classifier mechanism draws the class of the probabilities" {
  let x = mechanism_column([-3.0, -2.5, -2.0, -1.5, 1.5, 2.0, 2.5, 3.0])
  let y = ["a", "a", "a", "a", "b", "b", "b", "b"]
  let model = @gcm.CausalMechanism::classifier(
    @gcm.ClassificationModel::logistic(),
  ).fit_categorical(x, y)
  // The class is the first one whose cumulative probability reaches the
  // noise, which is what the upstream does as well.
  let classes = model.evaluate_categorical(mechanism_column([-3.0, 3.0]), [
    0.1, 0.5,
  ])
  assert_eq(classes[0], "a")
  assert_eq(classes[1], "b")
}

///|
test "the empirical distribution draws the samples it was fitted on" {
  let model = @gcm.StochasticModel::empirical().fit([1.0, 2.0, 3.0])
  let rng = @utils.Random::new(7UL)
  let samples = model.draw_samples(50, rng)
  assert_eq(samples.length(), 50)
  for value in samples {
    assert_true(value == 1.0 || value == 2.0 || value == 3.0)
  }
}

///|
test "the normal distribution has the location and the scale it was given" {
  let model = @gcm.StochasticModel::normal(2.0, 3.0)
  let rng = @utils.Random::new(11UL)
  let samples = model.draw_samples(20000, rng)
  assert_true(mechanism_near(@utils.mean(samples), 2.0, 0.15))
  assert_true(mechanism_near(@utils.std(samples), 3.0, 0.15))
}

///|
test "the normal distribution is fitted with the mean and the spread of the data" {
  let values : Array[Double] = []
  for i in 0..<100 {
    values.push(1.0 + 0.5 * i.to_double())
  }
  let model = @gcm.StochasticModel::normal(0.0, 1.0)
    .with_estimated_parameters()
    .fit(values)
  assert_true(mechanism_near(model.loc(), @utils.mean(values), 1.0e-12))
  assert_true(mechanism_near(model.scale(), @utils.std(values), 1.0e-12))
}

///|
test "the normal distribution keeps the parameters it was given" {
  let values : Array[Double] = []
  for i in 0..<100 {
    values.push(1.0 + 0.5 * i.to_double())
  }
  let model = @gcm.StochasticModel::normal(2.0, 3.0).fit(values)
  assert_true(mechanism_near(model.loc(), 2.0, 1.0e-12))
  assert_true(mechanism_near(model.scale(), 3.0, 1.0e-12))
}

///|
test "the clone of a mechanism is not fitted" {
  let x = mechanism_column([1.0, 2.0, 3.0, 4.0])
  let model = @gcm.CausalMechanism::additive_noise(
    @gcm.PredictionModel::linear(),
  ).fit(x, [3.0, 5.0, 7.0, 9.0])
  let copy = model.clone()
  assert_false(copy.prediction_model().is_fitted())
  assert_false(copy.noise_model().is_fitted())
  // The original keeps its fit.
  assert_true(
    mechanism_near(model.prediction_model().coefficients()[0], 2.0, 1.0e-9),
  )
}

///|
test "the clone of a mechanism is fitted on its own" {
  let x = mechanism_column([1.0, 2.0, 3.0, 4.0])
  let model = @gcm.CausalMechanism::additive_noise(
    @gcm.PredictionModel::linear(),
  ).fit(x, [3.0, 5.0, 7.0, 9.0])
  let copy = model.clone()
  let refitted = copy.fit(x, [30.0, 50.0, 70.0, 90.0])
  assert_true(
    mechanism_near(model.prediction_model().coefficients()[0], 2.0, 1.0e-9),
  )
  assert_true(
    mechanism_near(refitted.prediction_model().coefficients()[0], 20.0, 1.0e-9),
  )
}

///|
test "the clone of a distribution is not fitted" {
  let values : Array[Double] = []
  for i in 0..<100 {
    values.push(1.0 + 0.5 * i.to_double())
  }
  let model = @gcm.StochasticModel::empirical().fit(values)
  let copy = model.clone()
  assert_false(copy.is_fitted())
  assert_eq(copy.samples().length(), 0)
}

///|
test "the clone of a distribution of fixed parameters keeps them" {
  let model = @gcm.StochasticModel::normal(2.0, 3.0)
  let copy = model.clone()
  assert_true(copy.is_fitted())
  assert_true(mechanism_near(copy.loc(), 2.0, 1.0e-12))
  assert_true(mechanism_near(copy.scale(), 3.0, 1.0e-12))
}
