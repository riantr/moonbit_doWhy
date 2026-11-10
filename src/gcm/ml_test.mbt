///|
/// The tests of the prediction models of the `gcm` package.
///
/// The expectations are the ones of the upstream tests of
/// `dowhy.gcm.ml.regression` and `dowhy.gcm.ml.classification`, and of the
/// file `tests/gcm/test_ml.py`.
///
/// The five cases of `tests/gcm/test_ml.py` are among the cases of this file:
/// the clone of the classifier, the regressor of fixed parameters and its
/// predictions, and the regressor and the classifier of the fixture with a
/// categorical column. The upstream fits the encoder of a categorical column
/// inside the model, and the port encodes the column before the fit, the way
/// the mechanism of the `gcm` package does it for every other model.

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
/// The largest difference between two arrays of the same length.
fn ml_max_error(
  predictions : Array[Double],
  expected : Array[Double],
) -> Double {
  let mut worst = 0.0
  for i = 0; i < predictions.length(); i = i + 1 {
    let error = (predictions[i] - expected[i]).abs()
    if error > worst {
      worst = error
    }
  }
  worst
}

///|
/// The fixture of the upstream with a categorical column: a column of the
/// standard normal distribution, a column of the three categories "0", "1" and
/// "2", and the target of the relation of the two columns.
///
/// The target is twice the numeric column, less five for the category "0", ten
/// more for the category "1" and five more for the category "2", the way the
/// upstream builds it.
fn ml_categorical_fixture(
  generator : @utils.Random,
  rows : Int32,
) -> (Array[String], Array[Double], Array[Double]) {
  let first : Array[Double] = []
  for _ in 0..<rows {
    first.push(generator.next_normal())
  }
  let categories : Array[String] = []
  for _ in 0..<rows {
    let category = generator.next_int(3)
    categories.push(
      if category == 0 {
        "0"
      } else if category == 1 {
        "1"
      } else {
        "2"
      },
    )
  }
  let target : Array[Double] = []
  for i in 0..<rows {
    let effect = if categories[i] == "0" {
      -5.0
    } else if categories[i] == "1" {
      10.0
    } else {
      5.0
    }
    target.push(2.0 * first[i] + effect)
  }
  (categories, first, target)
}

///|
/// The distinct categories of the fixture of the upstream, in lexicographic
/// order, which is the order of the columns of its one-hot encoding.
fn ml_distinct_labels(categories : Array[String]) -> Array[String] {
  let distinct : Array[String] = []
  for category in categories {
    if !distinct.contains(category) {
      distinct.push(category)
    }
  }
  distinct.sort_by(fn(a, b) { a.lexical_compare(b) })
  distinct
}

///|
/// The design matrix of the categorical fixture of the upstream.
///
/// The upstream fits the encoder of the categorical column inside the model,
/// and the design matrix of the port holds the numeric column and the three
/// columns of the encoding, in the order of the upstream.
fn ml_categorical_matrix(
  categories : Array[String],
  first : Array[Double],
) -> @utils.Matrix {
  let encoded = @gcm.one_hot_encode(categories)
  let columns : Array[Array[Double]] = [first]
  for j in 0..<encoded.ncols() {
    columns.push(encoded.col(j))
  }
  @utils.Matrix::from_columns(columns)
}

///|
/// The design matrix of one row of the categorical fixture of the upstream.
///
/// The columns of the encoding are the columns of the categories of the
/// fixture, so a row of the fixture and a row of the test have the same
/// design. The labels are the distinct categories of the fixture, in the
/// lexicographic order of the encoding.
fn ml_categorical_row(
  value : Double,
  category : String,
  labels : Array[String],
) -> @utils.Matrix {
  let columns : Array[Array[Double]] = [[value]]
  for name in labels {
    columns.push([if name == category { 1.0 } else { 0.0 }])
  }
  @utils.Matrix::from_columns(columns)
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
test "the clone of the linear model is not fitted" {
  let model = @gcm.PredictionModel::linear().fit(ml_column([1.0, 2.0, 3.0]), [
    3.0, 5.0, 7.0,
  ])
  let copy = model.clone()
  assert_false(copy.is_fitted())
  assert_eq(copy.coefficients().length(), 0)
  // The original keeps its fit.
  assert_true(ml_near(model.coefficients()[0], 2.0, 1.0e-9))
}

///|
test "the clone of the linear model is fitted on its own" {
  let model = @gcm.PredictionModel::linear().fit(ml_column([1.0, 2.0, 3.0]), [
    3.0, 5.0, 7.0,
  ])
  let copy = model.clone()
  let refitted = copy.fit(ml_column([1.0, 2.0, 3.0]), [30.0, 50.0, 70.0])
  assert_true(ml_near(model.coefficients()[0], 2.0, 1.0e-9))
  assert_true(ml_near(refitted.coefficients()[0], 20.0, 1.0e-9))
}

///|
test "the clone of the linear model of fixed parameters keeps them" {
  let model = @gcm.PredictionModel::with_fixed_parameters([2.0], 1.0)
  let copy = model.clone()
  assert_true(copy.is_fitted())
  assert_true(copy.has_fixed_parameters())
  assert_true(ml_near(copy.coefficients()[0], 2.0, 1.0e-12))
  assert_true(ml_near(copy.intercept(), 1.0, 1.0e-12))
}

///|
test "the fit of the linear model of fixed parameters keeps them" {
  let model = @gcm.PredictionModel::with_fixed_parameters([2.0], 1.0)
  let fitted = model.fit(ml_column([1.0, 2.0, 3.0]), [30.0, 50.0, 70.0])
  assert_true(ml_near(fitted.coefficients()[0], 2.0, 1.0e-12))
  assert_true(ml_near(fitted.intercept(), 1.0, 1.0e-12))
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
/// test "the clone of the logistic model is not fitted"
test "the clone of the logistic model is not fitted" {
  let x = ml_column([-3.0, -2.5, -2.0, -1.5, 1.5, 2.0, 2.5, 3.0])
  let y = ["a", "a", "a", "a", "b", "b", "b", "b"]
  let model = @gcm.ClassificationModel::logistic().fit(x, y)
  let copy = model.clone()
  assert_false(copy.is_fitted())
  assert_eq(copy.classes().length(), 0)
  // The original keeps its fit.
  assert_eq(model.classes().length(), 2)
}

///|
/// test "the linear regressor reproduces the target of the categorical fixture
/// of the upstream"
///
/// The relation of the fixture of the upstream is exactly linear in the
/// numeric column and in the category, so the fit reproduces the target of
/// every row, and the prediction of the row `(2, "1")` is `2 * 2 + 10`.
test "the linear regressor reproduces the target of the categorical fixture of the upstream" {
  let generator = @utils.Random::new(20240201UL)
  let (categories, first, target) = ml_categorical_fixture(generator, 1000)
  let distinct = ml_distinct_labels(categories)
  let x = ml_categorical_matrix(categories, first)
  let model = @gcm.PredictionModel::linear().fit(x, target)
  let predicted = model.predict(ml_categorical_row(2.0, "1", distinct))
  assert_true(ml_near(predicted[0], 14.0, 1.0e-6))
  let predictions = model.predict(x)
  assert_true(ml_max_error(predictions, target) < 1.0e-6)
}

///|
/// test "the logistic classifier learns the classes of the categorical fixture
/// of the upstream"
///
/// The classes of the fixture of the upstream are the two sides of the median
/// of its target, and the upstream asserts that the classifier predicts more
/// than 980 of the 1000 classes right, that the probability of the second
/// class of the row `(2, "1")` is one and that the two classes hold half of
/// the rows each.
test "the logistic classifier learns the classes of the categorical fixture of the upstream" {
  let generator = @utils.Random::new(20240202UL)
  let (categories, first, target) = ml_categorical_fixture(generator, 1000)
  let distinct = ml_distinct_labels(categories)
  let x = ml_categorical_matrix(categories, first)
  let median = @utils.percentile(target, 50.0)
  let binary_labels : Array[String] = []
  for value in target {
    binary_labels.push(if value > median { "true" } else { "false" })
  }
  let model = @gcm.ClassificationModel::logistic().fit(x, binary_labels)
  let probabilities = model.predict_probabilities(
    ml_categorical_row(2.0, "1", distinct),
  )
  assert_true(ml_near(probabilities[0][1], 1.0, 0.01))
  let predictions = model.predict(x)
  let mut correct = 0
  let mut first_class = 0
  for i = 0; i < predictions.length(); i = i + 1 {
    if predictions[i] == binary_labels[i] {
      correct = correct + 1
    }
    if predictions[i] == "false" {
      first_class = first_class + 1
    }
  }
  assert_true(correct > 980)
  // The two classes hold half of the rows each.
  assert_true(ml_near(first_class.to_double() / 1000.0, 0.5, 0.05))
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
