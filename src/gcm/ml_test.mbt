///|
/// The tests of the prediction models of the `gcm` package.
///
/// The expectations are the ones of the upstream tests of
/// `dowhy.gcm.ml.regression` and `dowhy.gcm.ml.classification`.

///|
/// Whether two numbers are close to each other.
fn ml_near(a : Double, b : Double, tolerance : Double) -> Bool {
  (a - b).abs() <= tolerance
}

///|
/// A design matrix with a single column.
fn ml_column(values : Array[Double]) -> @utils.Matrix {
  @utils.Matrix::from_columns([values])
}

///|
test "the linear model recovers the coefficients of a linear relation" {
  let x = ml_column([1.0, 2.0, 3.0, 4.0, 5.0])
  let y = [4.0, 6.0, 8.0, 10.0, 12.0]
  let model = @gcm.PredictionModel::linear().fit(x, y)
  assert_true(ml_near(model.coefficients()[0], 2.0, 1.0e-9))
  assert_true(ml_near(model.intercept(), 2.0, 1.0e-9))
}

///|
test "the linear model predicts the target of every row" {
  let x = ml_column([1.0, 2.0, 3.0, 4.0, 5.0])
  let y = [4.0, 6.0, 8.0, 10.0, 12.0]
  let model = @gcm.PredictionModel::linear().fit(x, y)
  let predictions = model.predict(ml_column([1.0, 5.0]))
  assert_true(ml_near(predictions[0], 4.0, 1.0e-9))
  assert_true(ml_near(predictions[1], 12.0, 1.0e-9))
}

///|
test "the linear model of fixed parameters predicts without a fit" {
  let model = @gcm.PredictionModel::with_fixed_parameters([2.0], 1.0)
  assert_true(model.is_fitted())
  let predictions = model.predict(ml_column([0.0, 3.0]))
  assert_true(ml_near(predictions[0], 1.0, 1.0e-12))
  assert_true(ml_near(predictions[1], 7.0, 1.0e-12))
}

///|
test "the fit of the linear model leaves the model it is called on alone" {
  let model = @gcm.PredictionModel::linear()
  let _ = model.fit(ml_column([1.0, 2.0]), [3.0, 5.0])
  assert_false(model.is_fitted())
}

///|
test "the clone of the linear model is fitted on its own" {
  let model = @gcm.PredictionModel::linear().fit(ml_column([1.0, 2.0, 3.0]), [
    3.0, 5.0, 7.0,
  ])
  let copy = model.clone()
  let refitted = copy.fit(ml_column([1.0, 2.0, 3.0]), [30.0, 50.0, 70.0])
  assert_true(ml_near(model.coefficients()[0], 2.0, 1.0e-9))
  assert_true(ml_near(copy.coefficients()[0], 2.0, 1.0e-9))
  assert_true(ml_near(refitted.coefficients()[0], 20.0, 1.0e-9))
}

///|
test "the logistic model learns the classes of the target" {
  let x = ml_column([-3.0, -2.5, -2.0, -1.5, 1.5, 2.0, 2.5, 3.0])
  let y = ["a", "a", "a", "a", "b", "b", "b", "b"]
  let model = @gcm.ClassificationModel::logistic().fit(x, y)
  assert_eq(model.classes().length(), 2)
  assert_eq(model.classes()[0], "a")
  assert_eq(model.classes()[1], "b")
}

///|
test "the logistic model predicts the probability of the second class" {
  let x = ml_column([-3.0, -2.5, -2.0, -1.5, 1.5, 2.0, 2.5, 3.0])
  let y = ["a", "a", "a", "a", "b", "b", "b", "b"]
  let model = @gcm.ClassificationModel::logistic().fit(x, y)
  let probabilities = model.predict_probabilities(ml_column([-3.0, 0.0, 3.0]))
  assert_true(ml_near(probabilities[0][0] + probabilities[0][1], 1.0, 1.0e-12))
  assert_true(probabilities[0][1] < 0.5)
  assert_true(probabilities[1][1] > 0.5)
  assert_true(probabilities[2][1] > probabilities[0][1])
}

///|
test "the logistic model predicts the class of every row" {
  let x = ml_column([-3.0, -2.5, -2.0, -1.5, 1.5, 2.0, 2.5, 3.0])
  let y = ["a", "a", "a", "a", "b", "b", "b", "b"]
  let model = @gcm.ClassificationModel::logistic().fit(x, y)
  let predictions = model.predict(ml_column([-3.0, 3.0]))
  assert_eq(predictions[0], "a")
  assert_eq(predictions[1], "b")
}

///|
test "the identity function leaves its input alone" {
  let function = @gcm.InvertibleFunction::identity()
  assert_eq(function.evaluate([1.5, -2.0])[0], 1.5)
  assert_eq(function.evaluate_inverse([1.5, -2.0])[1], -2.0)
}

///|
test "the exponential function is the inverse of the logarithm" {
  let function = @gcm.InvertibleFunction::exponential()
  assert_true(ml_near(function.evaluate([2.0])[0], @math.exp(2.0), 1.0e-12))
  assert_true(
    ml_near(function.evaluate_inverse([2.0])[0], @math.ln(2.0), 1.0e-12),
  )
}

///|
test "the logarithm is the inverse of the exponential function" {
  let function = @gcm.InvertibleFunction::logarithmic()
  assert_true(ml_near(function.evaluate([2.0])[0], @math.ln(2.0), 1.0e-12))
  assert_true(
    ml_near(function.evaluate_inverse([2.0])[0], @math.exp(2.0), 1.0e-12),
  )
}
