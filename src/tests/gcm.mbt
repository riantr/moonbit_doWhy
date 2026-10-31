/// Tests for the graphical causal model package.
///
/// The tests of the package itself live inside it. These ones check that the
/// package is usable from the outside, the way a consumer of the published
/// package uses it, and that the pieces of it fit together.

///|
/// The seed of the fixtures.
const GCM_SEED : UInt64 = 2024UL

///|
/// The design matrix of the Shapley fixture and the coefficients of the model.
fn linear_fixture() -> (@utils.Matrix, Array[Double]) {
  let rng = @utils.Random::new(GCM_SEED)
  let rows : Array[Array[Double]] = []
  for _ in 0..<50 {
    rows.push([rng.next_normal(), rng.next_normal(), rng.next_normal()])
  }
  let coefficients = [2.0, -3.0, 0.5]
  (@utils.Matrix::from_rows(rows), coefficients)
}

///|
/// The set function of the linear model: the value of a subset of the players
/// is the prediction of the model when the players of the subset keep their
/// value and the others are drawn from the sample.
fn linear_set_function(
  design : @utils.Matrix,
  coefficients : Array[Double],
) -> (Array[Bool]) -> Double {
  fn(set : Array[Bool]) -> Double {
    let mut total = 0.0
    for i = 0; i < design.nrows(); i = i + 1 {
      let mut prediction = 0.0
      for j = 0; j < design.ncols(); j = j + 1 {
        // The players of the subset keep the value of the first row, the
        // others are drawn from the sample.
        let value = if set[j] { design.get(0, j) } else { design.get(i, j) }
        prediction = prediction + coefficients[j] * value
      }
      total = total + prediction
    }
    total / design.nrows().to_double()
  }
}

///|
/// test "the shapley values of a linear model are the contributions of the players"
test "the shapley values of a linear model are the contributions of the players" {
  let (design, coefficients) = linear_fixture()
  let set_function = linear_set_function(design, coefficients)
  let values = @gcm.estimate_shapley_values(
    set_function,
    design.ncols(),
    @gcm.ShapleyConfig::new(@gcm.ShapleyApproximationMethod::exact()),
  )
  assert_eq(values.length(), design.ncols())
  // The Shapley value of a player of a linear model is its coefficient times
  // the difference between its value and its mean.
  for j = 0; j < design.ncols(); j = j + 1 {
    let mean = @utils.mean(design.col(j))
    let expected = coefficients[j] * (design.get(0, j) - mean)
    assert_true((values[j] - expected).abs() < 1.0e-9)
  }
}

///|
/// The rows of the design matrix of the resample.
///
/// The design matrix holds the intercept, the treatment and the common cause.
fn resampled_design(
  treatment : Array[Double],
  cause : Array[Double],
  rows : Array[Int32],
) -> @utils.Matrix {
  let design : Array[Array[Double]] = []
  for index in rows {
    design.push([1.0, treatment[index], cause[index]])
  }
  @utils.Matrix::from_rows(design)
}

///|
/// The average treatment effect of a resample of the data.
///
/// The rows are drawn with replacement, the linear model of the outcome on the
/// treatment and the common cause is fitted, and its coefficient of the
/// treatment is the estimate of the effect.
fn resampled_effect(
  treatment : Array[Double],
  cause : Array[Double],
  outcome : Array[Double],
  seed : UInt64,
) -> Array[Double] {
  let rng = @utils.Random::new(seed)
  let n = outcome.length()
  let rows : Array[Int32] = []
  let targets : Array[Double] = []
  for _ in 0..<n {
    let index = rng.next_int(n)
    rows.push(index)
    targets.push(outcome[index])
  }
  let fit = @utils.ols_fit(resampled_design(treatment, cause, rows), targets)
  [fit.beta[1]]
}

///|
/// test "the bootstrap interval of the effect of the linear data holds the estimate"
test "the bootstrap interval of the effect of the linear data holds the estimate" {
  let dataset = @datasets.linear_dataset(
    42,
    300,
    @datasets.LinearConfig::confounded(),
  )
  let frame = dataset.frame()
  let treatment = frame.numeric("v0")
  let cause = frame.numeric("W0")
  let outcome = frame.numeric("y")
  // The estimate of the effect on the whole data set.
  let rows : Array[Int32] = []
  for i = 0; i < outcome.length(); i = i + 1 {
    rows.push(i)
  }
  let fit = @utils.ols_fit(resampled_design(treatment, cause, rows), outcome)
  let effect = fit.beta[1]
  // The bootstrap interval of that estimate.
  let (summary, intervals) = @gcm.confidence_intervals(
    fn(seed : UInt64) -> Array[Double] {
      resampled_effect(treatment, cause, outcome, seed)
    },
    0.95,
    20,
    fn(results : @utils.Matrix) -> Array[Double] {
      @gcm.estimate_geometric_median(results)
    },
    @utils.Random::new(GCM_SEED),
  )
  assert_eq(summary.length(), 1)
  assert_eq(intervals.length(), 1)
  // The bootstrap distribution is centred on the estimate, and the interval
  // holds its summary. The percentile interval itself need not hold the
  // estimate of the whole data set, because it is the interval of the
  // distribution of the resamples rather than of the one estimate.
  assert_true((summary[0] - effect).abs() < 0.05 * effect.abs())
  assert_true(intervals[0][0] < summary[0])
  assert_true(intervals[0][1] > summary[0])
}

///|
/// test "the divergence of a sample with itself is zero"
test "the divergence of a sample with itself is zero" {
  let sample = @utils.Matrix::from_rows([[0.0], [1.0], [2.0], [3.0]])
  let divergence = @gcm.estimate_kl_divergence_categorical(sample, sample)
  assert_true(divergence.abs() < 1.0e-10)
}

///|
/// test "the regression based independence test separates the dependent from the independent variables"
test "the regression based independence test separates the dependent from the independent variables" {
  let rng = @utils.Random::new(GCM_SEED)
  let xs : Array[Array[Double]] = []
  let ys : Array[Array[Double]] = []
  let zs : Array[Array[Double]] = []
  for _ in 0..<300 {
    let z = rng.next_normal()
    let x = z + 0.5 * rng.next_normal()
    let y = z + 0.5 * rng.next_normal()
    xs.push([x])
    ys.push([y])
    zs.push([z])
  }
  let x = @utils.Matrix::from_rows(xs)
  let y = @utils.Matrix::from_rows(ys)
  let z = @utils.Matrix::from_rows(zs)
  let adjust = fn(p_values : Array[Double]) -> Double {
    @gcm.merge_p_values_average(p_values, false, @utils.Random::new(GCM_SEED))
  }
  let p_value = @gcm.regression_based(
    x,
    y,
    Some(z),
    10,
    3,
    adjust,
    -1,
    @utils.Random::new(GCM_SEED),
  )
  assert_true(p_value >= 0.0)
  assert_true(p_value <= 1.0)
}
