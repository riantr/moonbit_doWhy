///|
/// The tests of the polynomial models of the `gcm` package.
///
/// The expectations are the ones of the upstream tests of
/// `tests/gcm/ml/test_regression.py` and of
/// `tests/gcm/ml/test_classification.py`.
///
/// The upstream draws its fixtures with the global generator of numpy and marks
/// both of its regression tests and its classification test as flaky, so the
/// port draws them with the generator of the `utils` package and a fixed seed.
/// The expectations of the upstream are kept: the polynom regressor has to
/// reproduce the product of its two features to `1e-10`, the polynom regressor
/// of the categorical fixture has to reproduce its target to `1e-10` as well,
/// and the polynom classifier has to predict more than 950 of the 1000 classes
/// of its fixture right.

///|
/// Whether two numbers are close to each other.
fn polynomial_near(a : Double, b : Double, tolerance : Double) -> Bool {
  (a - b).abs() <= tolerance
}

///|
/// The design matrix of the given columns.
fn polynomial_matrix(columns : Array[Array[Double]]) -> @utils.Matrix {
  @utils.Matrix::from_columns(columns)
}

///|
/// The largest difference between two arrays of the same length.
fn polynomial_max_error(
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
/// Two columns of the standard normal distribution.
fn polynomial_normal_columns(
  generator : @utils.Random,
  rows : Int32,
) -> (Array[Double], Array[Double]) {
  let first : Array[Double] = []
  let second : Array[Double] = []
  for _ in 0..<rows {
    first.push(generator.next_normal())
    second.push(generator.next_normal())
  }
  (first, second)
}

///|
/// The target of the numeric fixture of the upstream: the product of the two
/// features.
fn polynomial_product_target(
  first : Array[Double],
  second : Array[Double],
) -> Array[Double] {
  let out : Array[Double] = []
  for i = 0; i < first.length(); i = i + 1 {
    out.push(first[i] * second[i])
  }
  out
}

///|
/// A categorical column of the categories "0" and "1" and two columns of the
/// standard normal distribution.
fn polynomial_categorical_fixture(
  generator : @utils.Random,
  rows : Int32,
) -> (Array[String], Array[Double], Array[Double]) {
  let categories : Array[String] = []
  let first : Array[Double] = []
  let second : Array[Double] = []
  for _ in 0..<rows {
    categories.push(if generator.next_int(2) == 0 { "0" } else { "1" })
    first.push(generator.next_normal())
    second.push(generator.next_normal())
  }
  (categories, first, second)
}

///|
/// The design matrix of the categorical fixture of the upstream.
///
/// The upstream encodes the categorical column with a one hot encoder before
/// its polynomial expansion, so the matrix of the port holds the two columns
/// of the encoding and the two numeric columns.
fn polynomial_categorical_matrix(
  categories : Array[String],
  first : Array[Double],
  second : Array[Double],
) -> @utils.Matrix {
  let encoded = @gcm.one_hot_encode(categories)
  let columns : Array[Array[Double]] = []
  for j in 0..<encoded.ncols() {
    columns.push(encoded.col(j))
  }
  columns.push(first)
  columns.push(second)
  polynomial_matrix(columns)
}

///|
/// The target of the categorical fixture of the upstream: the product of the
/// two numeric features when the category is "0" and their sum otherwise.
fn polynomial_categorical_target(
  categories : Array[String],
  first : Array[Double],
  second : Array[Double],
) -> Array[Double] {
  let out : Array[Double] = []
  for i = 0; i < categories.length(); i = i + 1 {
    if categories[i] == "0" {
      out.push(first[i] * second[i])
    } else {
      out.push(first[i] + second[i])
    }
  }
  out
}

///|
test "the polynom regressor reproduces the product of its two features" {
  let generator = @utils.Random::new(20240101UL)
  let (first, second) = polynomial_normal_columns(generator, 100)
  let x = polynomial_matrix([first, second])
  let y = polynomial_product_target(first, second)
  let model = @gcm.PredictionModel::polynomial(degree=2).fit(x, y)
  let (test_first, test_second) = polynomial_normal_columns(generator, 100)
  let x_test = polynomial_matrix([test_first, test_second])
  let y_test = polynomial_product_target(test_first, test_second)
  let predictions = model.predict(x_test)
  assert_true(polynomial_max_error(predictions, y_test) < 1.0e-10)
}

///|
test "the polynom regressor holds the coefficient of the product of its features" {
  let generator = @utils.Random::new(20240102UL)
  let (first, second) = polynomial_normal_columns(generator, 100)
  let x = polynomial_matrix([first, second])
  let y = polynomial_product_target(first, second)
  let model = @gcm.PredictionModel::polynomial(degree=2).fit(x, y)
  // The columns of the expansion of two features of the degree two are
  // `x0`, `x1`, `x0 * x0`, `x0 * x1` and `x1 * x1`, so the coefficient of the
  // product is the fourth one.
  assert_eq(model.coefficients().length(), 5)
  assert_true(polynomial_near(model.coefficients()[3], 1.0, 1.0e-9))
  assert_true(polynomial_near(model.intercept(), 0.0, 1.0e-9))
}

///|
test "the polynom regressor of the degree three reproduces the product of its two features" {
  let generator = @utils.Random::new(20240103UL)
  let (first, second) = polynomial_normal_columns(generator, 100)
  let x = polynomial_matrix([first, second])
  let y = polynomial_product_target(first, second)
  let model = @gcm.PredictionModel::polynomial(degree=3).fit(x, y)
  let (test_first, test_second) = polynomial_normal_columns(generator, 100)
  let x_test = polynomial_matrix([test_first, test_second])
  let y_test = polynomial_product_target(test_first, test_second)
  let predictions = model.predict(x_test)
  assert_true(polynomial_max_error(predictions, y_test) < 1.0e-10)
}

///|
test "the polynom regressor of a categorical fixture reproduces its target" {
  let generator = @utils.Random::new(20240104UL)
  let (categories, first, second) = polynomial_categorical_fixture(
    generator, 100,
  )
  let x = polynomial_categorical_matrix(categories, first, second)
  let y = polynomial_categorical_target(categories, first, second)
  let model = @gcm.PredictionModel::polynomial(degree=3).fit(x, y)
  let (test_categories, test_first, test_second) = polynomial_categorical_fixture(
    generator, 100,
  )
  let x_test = polynomial_categorical_matrix(
    test_categories, test_first, test_second,
  )
  let y_test = polynomial_categorical_target(
    test_categories, test_first, test_second,
  )
  let predictions = model.predict(x_test)
  assert_true(polynomial_max_error(predictions, y_test) < 1.0e-10)
}

///|
test "the clone of the polynom regressor is not fitted and keeps its degree" {
  let generator = @utils.Random::new(20240105UL)
  let (first, second) = polynomial_normal_columns(generator, 100)
  let x = polynomial_matrix([first, second])
  let y = polynomial_product_target(first, second)
  let model = @gcm.PredictionModel::polynomial(degree=2).fit(x, y)
  let copy = model.clone()
  assert_false(copy.is_fitted())
  // The copy has to be fitted again, and the fit of the copy has to expand the
  // features as well.
  let refitted = copy.fit(x, y)
  assert_true(refitted.is_fitted())
  let (test_first, test_second) = polynomial_normal_columns(generator, 20)
  let predictions = refitted.predict(
    polynomial_matrix([test_first, test_second]),
  )
  let expected = polynomial_product_target(test_first, test_second)
  assert_true(polynomial_max_error(predictions, expected) < 1.0e-10)
}

///|
test "the expansion of two features of the degree two holds the products of the upstream" {
  // The rows of the matrix are the pairs (1, 2), (3, 4) and (5, 6).
  let x = polynomial_matrix([[1.0, 3.0, 5.0], [2.0, 4.0, 6.0]])
  let expanded = @gcm.polynomial_features(x, 2)
  assert_eq(expanded.ncols(), 5)
  // The columns are `x0`, `x1`, `x0 * x0`, `x0 * x1` and `x1 * x1`.
  assert_true(polynomial_near(expanded.get(0, 0), 1.0, 1.0e-12))
  assert_true(polynomial_near(expanded.get(0, 1), 2.0, 1.0e-12))
  assert_true(polynomial_near(expanded.get(0, 2), 1.0, 1.0e-12))
  assert_true(polynomial_near(expanded.get(0, 3), 2.0, 1.0e-12))
  assert_true(polynomial_near(expanded.get(0, 4), 4.0, 1.0e-12))
  assert_true(polynomial_near(expanded.get(1, 3), 12.0, 1.0e-12))
}

///|
test "the expansion of two features of the degree three holds the products of the upstream" {
  // The rows of the matrix are the pairs (1, 2), (3, 4) and (5, 6).
  let x = polynomial_matrix([[1.0, 3.0, 5.0], [2.0, 4.0, 6.0]])
  let expanded = @gcm.polynomial_features(x, 3)
  assert_eq(expanded.ncols(), 9)
  // The five columns of the degree two come first, and the four products of the
  // degree three follow them.
  assert_true(polynomial_near(expanded.get(0, 5), 1.0, 1.0e-12))
  assert_true(polynomial_near(expanded.get(0, 6), 2.0, 1.0e-12))
  assert_true(polynomial_near(expanded.get(0, 7), 4.0, 1.0e-12))
  assert_true(polynomial_near(expanded.get(0, 8), 8.0, 1.0e-12))
  assert_true(polynomial_near(expanded.get(1, 5), 27.0, 1.0e-12))
  assert_true(polynomial_near(expanded.get(1, 6), 36.0, 1.0e-12))
  assert_true(polynomial_near(expanded.get(1, 7), 48.0, 1.0e-12))
  assert_true(polynomial_near(expanded.get(1, 8), 64.0, 1.0e-12))
}

///|
test "the expansion of three features holds the products of the upstream" {
  // The rows of the matrix are the triples (1, 2, 3) and (4, 5, 6).
  let x = polynomial_matrix([[1.0, 4.0], [2.0, 5.0], [3.0, 6.0]])
  assert_eq(@gcm.polynomial_features(x, 1).ncols(), 3)
  assert_eq(@gcm.polynomial_features(x, 2).ncols(), 9)
  assert_eq(@gcm.polynomial_features(x, 3).ncols(), 19)
}

///|
test "the polynom classifier predicts the class of every row" {
  let generator = @utils.Random::new(20240106UL)
  let (first, second) = polynomial_normal_columns(generator, 1000)
  let x = polynomial_matrix([first, second])
  let labels = polynomial_class_labels(first, second)
  let model = @gcm.ClassificationModel::polynomial(degree=3).fit(x, labels)
  let (test_first, test_second) = polynomial_normal_columns(generator, 1000)
  let predictions = model.predict(polynomial_matrix([test_first, test_second]))
  let correct = polynomial_correct_count(predictions, test_first, test_second)
  assert_true(correct > 950)
}

///|
test "the clone of the polynom classifier keeps its degree" {
  let generator = @utils.Random::new(20240107UL)
  let (first, second) = polynomial_normal_columns(generator, 1000)
  let x = polynomial_matrix([first, second])
  let labels = polynomial_class_labels(first, second)
  let model = @gcm.ClassificationModel::polynomial(degree=3).fit(x, labels)
  let copy = model.clone()
  assert_false(copy.is_fitted())
  // The copy has to be fitted again, and the fit of the copy has to expand the
  // features as well.
  let refitted = copy.fit(x, labels)
  let predictions = refitted.predict(x)
  let correct = polynomial_correct_count(predictions, first, second)
  assert_true(correct * 100 > first.length() * 95)
}

///|
test "the polynom models have the default degrees of the upstream" {
  // The default degree of the regressor of the upstream is two and the default
  // degree of its classifier is three.
  let generator = @utils.Random::new(20240108UL)
  let (first, second) = polynomial_normal_columns(generator, 100)
  let x = polynomial_matrix([first, second])
  let y = polynomial_product_target(first, second)
  let model = @gcm.PredictionModel::polynomial().fit(x, y)
  assert_eq(model.degree(), 2)
  // The expansion of two features of the degree two holds five columns.
  assert_eq(model.coefficients().length(), 5)
  let labels = polynomial_class_labels(first, second)
  let classifier = @gcm.ClassificationModel::polynomial().fit(x, labels)
  assert_eq(classifier.degree(), 3)
}

///|
/// The labels of the fixture of the upstream: the class of a row depends on
/// the sign of the product of its two features.
fn polynomial_class_labels(
  first : Array[Double],
  second : Array[Double],
) -> Array[String] {
  let labels : Array[String] = []
  for i = 0; i < first.length(); i = i + 1 {
    if first[i] * second[i] > 0.0 {
      labels.push("Class 0")
    } else {
      labels.push("Class 1")
    }
  }
  labels
}

///|
/// The number of the rows whose class agrees with the rule of the upstream.
fn polynomial_correct_count(
  predictions : Array[String],
  first : Array[Double],
  second : Array[Double],
) -> Int32 {
  let mut correct = 0
  for i = 0; i < predictions.length(); i = i + 1 {
    let expected = if first[i] * second[i] > 0.0 {
      "Class 0"
    } else {
      "Class 1"
    }
    if predictions[i] == expected {
      correct = correct + 1
    }
  }
  correct
}
