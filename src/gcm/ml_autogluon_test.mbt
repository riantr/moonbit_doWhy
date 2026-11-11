///|
/// The tests of the model that selects itself out of a zoo of models.
///
/// This is the port of `tests/gcm/ml/test_autogluon.py` of the upstream. The
/// upstream skips the file when the optional dependency of AutoGluon is
/// missing, and its four cases configure the model of the upstream with the
/// linear model as the only model of its zoo, which is the model the port
/// tries when the configuration of its model holds the linear family alone.
///
/// The fixtures of the port are the fixtures of the upstream: the generator of
/// numpy draws the same numbers for the same seed, so the rows of the port and
/// the rows of the upstream are the same rows. The script
/// `_verify/autogluon_reference.py` prints the numbers of the upstream.
///
/// The one difference is the fourth case: the upstream passes the classifier
/// of AutoGluon to the additive noise model, which works because the class of
/// the upstream inherits from the regressor and from the classifier at the same
/// time. The port passes the regressor, which is the model the additive noise
/// model of the port takes.

///|
/// The data of a linear model, the way the upstream draws it.
///
/// This is the port of `_generate_linear_data` of the upstream: the number of
/// the features is drawn from the numbers of `[0, 20]`, the coefficients are
/// drawn from the uniform distribution on `[-5, 5]`, the features are drawn
/// from the normal distribution and the target is the sum of the products of
/// the coefficients and the features plus the noise.
fn auto_ml_linear_data(
  generator : @utils.NumpyRandom,
  num_samples : Int32,
  noise_std : Double,
) -> (@utils.Matrix, Array[Double]) {
  let num_features = generator.randint(20) + 1
  let coefficients : Array[Double] = []
  for _ in 0..<num_features {
    coefficients.push(generator.uniform(-5.0, 5.0))
  }
  let x = generator.randn(num_samples, num_features)
  let y : Array[Double] = []
  for i in 0..<num_samples {
    let mut value = 0.0
    for j in 0..<num_features {
      value = value + coefficients[j] * x.get(i, j)
    }
    y.push(value + noise_std * generator.standard_normal())
  }
  (x, y)
}

///|
/// The labels of a target, the way the upstream labels it.
///
/// This is the port of the labels of `_generate_linear_classification_data` of
/// the upstream: a value is above the median of the target or below it, and
/// the labels are the texts of the two cases.
fn auto_ml_classification_labels(y : Array[Double]) -> Array[String] {
  let middle = @utils.median(y)
  let labels : Array[String] = []
  for value in y {
    if value > middle {
      labels.push("True")
    } else {
      labels.push("False")
    }
  }
  labels
}

///|
/// The rows of the training part and of the test part of the data.
///
/// This is the port of `sklearn.model_selection.train_test_split` with the
/// shuffle it does by default: the rows are permuted and the first half of
/// them is the test part.
fn auto_ml_train_test_split(
  generator : @utils.NumpyRandom,
  count : Int32,
) -> (Array[Int32], Array[Int32]) {
  let permutation = generator.permutation(count)
  let test_size = (count + 1) / 2
  let test_rows : Array[Int32] = []
  for i in 0..<test_size {
    test_rows.push(permutation[i])
  }
  let train_rows : Array[Int32] = []
  for i in test_size..<count {
    train_rows.push(permutation[i])
  }
  (train_rows, test_rows)
}

///|
/// The values of the given rows.
fn auto_ml_values_of(
  values : Array[Double],
  rows : Array[Int32],
) -> Array[Double] {
  let out : Array[Double] = []
  for row in rows {
    out.push(values[row])
  }
  out
}

///|
/// The labels of the given rows.
fn auto_ml_labels_of(
  labels : Array[String],
  rows : Array[Int32],
) -> Array[String] {
  let out : Array[String] = []
  for row in rows {
    out.push(labels[row])
  }
  out
}

///|
/// The labels of three classes, the way the upstream draws them.
///
/// This is the port of the labels of the third case of the upstream, which
/// draws them with the choice of the numbers of `[0, 3]`.
fn auto_ml_three_class_labels(
  generator : @utils.NumpyRandom,
  count : Int32,
) -> Array[String] {
  let labels : Array[String] = []
  for _ in 0..<count {
    labels.push(generator.randint(3).to_string())
  }
  labels
}

///|
/// The configuration of a model that tries the linear model alone.
///
/// This is the configuration of the upstream that its cases use, the
/// `hyperparameters` of the model of AutoGluon with the linear model alone.
fn auto_ml_linear_configuration() -> @gcm.AutoMlConfiguration {
  @gcm.AutoMlConfiguration::new(
    families=[@gcm.AutoMlFamily::linear()],
    seed=0UL,
  )
}

///|
test "given_linear_categorical_data_when_using_auto_gluon_classifier_linear_then_provides_good_fit" {
  let generator = @utils.NumpyRandom::new(42)
  let (x, y) = auto_ml_linear_data(generator, 1000, 0.2)
  let labels = auto_ml_classification_labels(y)
  let (train_rows, test_rows) = auto_ml_train_test_split(generator, 1000)
  let model = @gcm.auto_gluon_classifier(
    configuration=auto_ml_linear_configuration(),
  )
  let fitted = model.fit(
    x.take_rows(train_rows),
    auto_ml_labels_of(labels, train_rows),
  )
  let predicted = fitted.predict(x.take_rows(test_rows))
  let expected = auto_ml_labels_of(labels, test_rows)
  let mut correct = 0
  for i in 0..<predicted.length() {
    if predicted[i] == expected[i] {
      correct = correct + 1
    }
  }
  // The upstream asserts that the accuracy is one up to a tenth, and the
  // accuracy of the upstream is 0.976, which is 488 rows of the 500 rows of
  // the test part.
  assert_eq(correct, 488)
}

///|
test "given_linear_continuous_data_when_using_auto_gluon_regressor_linear_then_provides_good_fit" {
  let generator = @utils.NumpyRandom::new(42)
  let (x, y) = auto_ml_linear_data(generator, 2000, 0.2)
  let (train_rows, test_rows) = auto_ml_train_test_split(generator, 2000)
  let model = @gcm.auto_gluon_regressor(
    configuration=auto_ml_linear_configuration(),
  )
  let fitted = model.fit(
    x.take_rows(train_rows),
    auto_ml_values_of(y, train_rows),
  )
  let predicted = fitted.predict(x.take_rows(test_rows))
  let expected = auto_ml_values_of(y, test_rows)
  let residuals : Array[Double] = []
  for i in 0..<predicted.length() {
    residuals.push(predicted[i] - expected[i])
  }
  // The upstream asserts that the deviation of the residuals is 0.2 up to one,
  // and its deviation is 0.19372956189465734.
  assert_true((@utils.std(residuals) - 0.19372956189465734).abs() < 0.000000001)
}

///|
test "given_classifier_fcm_with_autogluon_classifier_model_when_drawing_samples_then_returns_samples" {
  let generator = @utils.NumpyRandom::new(42)
  let x = generator.randn(100, 3)
  let labels = auto_ml_three_class_labels(generator, 100)
  let mechanism = @gcm.CausalMechanism::classifier(@gcm.auto_gluon_classifier())
  let fitted = mechanism.fit_categorical(x, labels)
  let samples = fitted.draw_categorical_samples(
    generator.randn(5, 3),
    @utils.Random::new(42),
  )
  assert_eq(samples.length(), 5)
}

///|
test "given_anm_with_autogluon_regressor_model_when_drawing_samples_then_returns_samples" {
  let generator = @utils.NumpyRandom::new(42)
  let x = generator.randn(100, 3)
  let y : Array[Double] = []
  for _ in 0..<100 {
    y.push(generator.standard_normal())
  }
  let mechanism = @gcm.CausalMechanism::additive_noise(
    @gcm.auto_gluon_regressor(),
  )
  let fitted = mechanism.fit(x, y)
  let samples = fitted.draw_samples(
    generator.randn(5, 3),
    @utils.Random::new(42),
  )
  assert_eq(samples.length(), 5)
}
