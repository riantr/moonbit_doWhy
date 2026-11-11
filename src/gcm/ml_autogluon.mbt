///|
/// The model that selects itself out of a zoo of models.
///
/// This is the port of `dowhy.gcm.ml.autogluon`. The upstream wraps the
/// `TabularPredictor` of AutoGluon, which fits a whole zoo of models and keeps
/// the one with the best validation score; the port keeps the same shape: the
/// model holds the families of the models it tries, it fits every model of the
/// zoo with a cross validation and it keeps the one with the smallest error,
/// which it then fits on all the rows.
///
/// The upstream needs the optional dependency of AutoGluon, so the port has no
/// `TabularPredictor`: the zoo of the port holds the models of the `gcm`
/// package, and the cross validation of the selection is the one of
/// `dowhy.gcm.auto.select_model`, the way the selection of the `gcm` package
/// computes it. The upstream draws the rows of its cross validation with the
/// global generator of numpy and the port draws them with its own generator,
/// whose seed is the seed of the configuration.

///|
/// A family of the models the model that selects itself tries.
///
/// This is the port of the names of the models of the `hyperparameters` of the
/// upstream. AutoGluon names the families of its models the same way for a
/// regression and for a classification, so the port does the same: the linear
/// family is the ordinary least squares regression or the logistic regression,
/// and the polynomial family is the polynomial regression or the polynomial
/// logistic regression.
pub enum AutoMlFamily {
  /// The linear model.
  Linear
  /// The polynomial model.
  Polynomial
  /// The nearest neighbour model.
  NearestNeighbour
  /// The decision tree, which the port has for a classification alone.
  DecisionTree
}

///|
/// The linear model.
pub fn AutoMlFamily::linear() -> AutoMlFamily {
  Linear
}

///|
/// The polynomial model.
pub fn AutoMlFamily::polynomial() -> AutoMlFamily {
  Polynomial
}

///|
/// The nearest neighbour model.
pub fn AutoMlFamily::nearest_neighbour() -> AutoMlFamily {
  NearestNeighbour
}

///|
/// The decision tree, which the port has for a classification alone.
pub fn AutoMlFamily::decision_tree() -> AutoMlFamily {
  DecisionTree
}

///|
/// The configuration of the model that selects itself out of a zoo of models.
///
/// This is the port of the `hyperparameters` of `dowhy.gcm.ml.autogluon`, which
/// tells AutoGluon the models it tries. The port holds the families of the
/// models it tries and the seed of the generator of the cross validation of the
/// selection.
pub struct AutoMlConfiguration {
  /// The families of the models the model tries.
  families : Array[AutoMlFamily]
  /// The seed of the generator of the cross validation of the selection.
  seed : UInt64
}

///|
/// The families of the models the model tries by default.
///
/// This is the zoo of the port, which holds the linear model, the polynomial
/// model, the nearest neighbour model and the decision tree. The upstream uses
/// the light preset of AutoGluon with the linear model added to it, which is a
/// zoo of the models of AutoGluon.
fn default_auto_ml_families() -> Array[AutoMlFamily] {
  [
    AutoMlFamily::linear(),
    AutoMlFamily::polynomial(),
    AutoMlFamily::nearest_neighbour(),
    AutoMlFamily::decision_tree(),
  ]
}

///|
/// The configuration of the model that selects itself out of a zoo of models.
///
/// The families are the ones the model tries and the seed is the seed of the
/// generator of the cross validation of the selection.
pub fn AutoMlConfiguration::new(
  families~ : Array[AutoMlFamily] = default_auto_ml_families(),
  seed~ : UInt64 = 0UL,
) -> AutoMlConfiguration {
  { families: families.copy(), seed, }
}

///|
/// The families of the models the model tries.
///
/// The returned array is a copy, so a caller may modify it without changing the
/// configuration.
pub fn AutoMlConfiguration::families(
  self : AutoMlConfiguration,
) -> Array[AutoMlFamily] {
  self.families.copy()
}

///|
/// The seed of the generator of the cross validation of the selection.
pub fn AutoMlConfiguration::seed(self : AutoMlConfiguration) -> UInt64 {
  self.seed
}

///|
/// A copy of the configuration.
///
/// The copy holds a copy of the families, because the array of the families is
/// a container and a copy of it would share its state with the original.
pub fn AutoMlConfiguration::copy(
  self : AutoMlConfiguration,
) -> AutoMlConfiguration {
  { families: self.families.copy(), seed: self.seed, }
}

///|
/// The model that selects a regressor out of a zoo of models.
///
/// This is the port of `dowhy.gcm.ml.autogluon.AutoGluonRegressor`. The model
/// is not fitted: it selects itself when it is fitted, the way the model of the
/// upstream selects itself inside its `TabularPredictor`.
pub fn auto_gluon_regressor(
  configuration~ : AutoMlConfiguration = AutoMlConfiguration::new(),
) -> PredictionModel {
  {
    coefficients: [],
    intercept: 0.0,
    fitted: false,
    fixed: false,
    equation: None,
    degree: 0,
    neighbours: None,
    auto_ml: Some(configuration),
  }
}

///|
/// The model that selects a classifier out of a zoo of models.
///
/// This is the port of `dowhy.gcm.ml.autogluon.AutoGluonClassifier`. The model
/// is not fitted: it selects itself when it is fitted, the way the model of the
/// upstream selects itself inside its `TabularPredictor`.
pub fn auto_gluon_classifier(
  configuration~ : AutoMlConfiguration = AutoMlConfiguration::new(),
) -> ClassificationModel {
  {
    coefficients: [],
    intercept: 0.0,
    classes: [],
    fitted: false,
    degree: 0,
    one_versus_rest: None,
    neighbours: None,
    tree: None,
    auto_ml: Some(configuration),
  }
}

///|
/// The regressors of the families of the given configuration.
///
/// The decision tree has no regressor in the port, so the family is left out of
/// the zoo of the regressors.
fn auto_ml_regressors_of(
  configuration : AutoMlConfiguration,
) -> Array[PredictionModel] {
  let models : Array[PredictionModel] = []
  for family in configuration.families {
    match family {
      AutoMlFamily::Linear => models.push(PredictionModel::linear())
      AutoMlFamily::Polynomial => models.push(PredictionModel::polynomial())
      AutoMlFamily::NearestNeighbour =>
        models.push(PredictionModel::nearest_neighbour())
      AutoMlFamily::DecisionTree => ()
    }
  }
  models
}

///|
/// The classifiers of the families of the given configuration.
fn auto_ml_classifiers_of(
  configuration : AutoMlConfiguration,
) -> Array[ClassificationModel] {
  let models : Array[ClassificationModel] = []
  for family in configuration.families {
    match family {
      AutoMlFamily::Linear => models.push(ClassificationModel::logistic())
      AutoMlFamily::Polynomial => models.push(ClassificationModel::polynomial())
      AutoMlFamily::NearestNeighbour =>
        models.push(ClassificationModel::nearest_neighbour())
      AutoMlFamily::DecisionTree =>
        models.push(ClassificationModel::decision_tree())
    }
  }
  models
}

///|
/// Fit the model that selects itself on the given data.
///
/// Every regressor of the zoo is fitted with a cross validation and the one
/// with the smallest mean squared error is kept, which is then fitted on all
/// the rows. The result is a new model; the model the fit is called on stays as
/// it is.
fn auto_ml_fit_regression(
  configuration : AutoMlConfiguration,
  x : @utils.Matrix,
  y : Array[Double],
) -> PredictionModel {
  let regressors = auto_ml_regressors_of(configuration)
  if regressors.length() == 0 {
    abort("the model that selects itself has no regressor to try")
  }
  let rng = @utils.Random::new(configuration.seed)
  let folds = selection_k_folds(y.length(), rng)
  let mut best = regressors[0]
  let mut best_score = 0.0
  let mut found = false
  for regressor in regressors {
    let score = auto_ml_regression_score(regressor, x, y, folds)
    if !found || score < best_score {
      found = true
      best = regressor
      best_score = score
    }
  }
  let fitted = best.fit(x, y)
  {
    coefficients: fitted.coefficients,
    intercept: fitted.intercept,
    fitted: true,
    fixed: false,
    equation: None,
    degree: fitted.degree,
    neighbours: fitted.neighbours,
    auto_ml: Some(configuration.copy()),
  }
}

///|
/// Fit the model that selects itself on the given labels.
///
/// Every classifier of the zoo is fitted with a cross validation and the one
/// with the smallest log loss is kept, which is then fitted on all the rows.
/// The result is a new model; the model the fit is called on stays as it is.
fn auto_ml_fit_classification(
  configuration : AutoMlConfiguration,
  x : @utils.Matrix,
  y : Array[String],
) -> ClassificationModel {
  let classifiers = auto_ml_classifiers_of(configuration)
  if classifiers.length() == 0 {
    abort("the model that selects itself has no classifier to try")
  }
  let rng = @utils.Random::new(configuration.seed)
  let folds = selection_stratified_k_folds(y, rng)
  let mut best = classifiers[0]
  let mut best_score = 0.0
  let mut found = false
  for classifier in classifiers {
    let score = auto_ml_classification_score(classifier, x, y, folds)
    if !found || score < best_score {
      found = true
      best = classifier
      best_score = score
    }
  }
  let fitted = best.fit(x, y)
  {
    coefficients: fitted.coefficients,
    intercept: fitted.intercept,
    classes: fitted.classes,
    fitted: true,
    degree: fitted.degree,
    one_versus_rest: fitted.one_versus_rest,
    neighbours: fitted.neighbours,
    tree: fitted.tree,
    auto_ml: Some(configuration.copy()),
  }
}

///|
/// The mean squared error of a regressor over the folds of the cross
/// validation.
///
/// The design matrix of a fold holds the rows of the matrix themselves, because
/// the model that selects itself takes the features as they are.
fn auto_ml_regression_score(
  model : PredictionModel,
  x : @utils.Matrix,
  y : Array[Double],
  folds : Array[SelectionFold],
) -> Double {
  let mut total = 0.0
  let mut count = 0
  for fold in folds {
    let train_rows = limited_rows(fold.train)
    let held_out_rows = limited_rows(fold.held_out)
    let fitted = model.fit(x.take_rows(train_rows), take_values(y, train_rows))
    let predicted = fitted.predict(x.take_rows(held_out_rows))
    total = total + mean_squared_error(take_values(y, held_out_rows), predicted)
    count = count + 1
  }
  if count == 0 {
    return 0.0
  }
  total / count.to_double()
}

///|
/// The log loss of a classifier over the folds of the cross validation.
///
/// A fold whose training rows or whose test rows hold a single class is
/// skipped, the way the selection of the `gcm` package skips it: the
/// classifier cannot be fitted on it and the log loss cannot be computed on it.
fn auto_ml_classification_score(
  model : ClassificationModel,
  x : @utils.Matrix,
  y : Array[String],
  folds : Array[SelectionFold],
) -> Double {
  let mut total = 0.0
  let mut count = 0
  for fold in folds {
    let train_rows = limited_rows(fold.train)
    let held_out_rows = limited_rows(fold.held_out)
    let train_labels = take_labels(y, train_rows)
    let held_out_labels = take_labels(y, held_out_rows)
    if sorted_distinct_labels(train_labels).length() < 2 {
      continue
    }
    if sorted_distinct_labels(held_out_labels).length() < 2 {
      continue
    }
    let fitted = model.fit(x.take_rows(train_rows), train_labels)
    let probabilities = fitted.predict_probabilities(x.take_rows(held_out_rows))
    total = total + log_loss(fitted.classes(), held_out_labels, probabilities)
    count = count + 1
  }
  if count == 0 {
    return 0.0
  }
  total / count.to_double()
}
