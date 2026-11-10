///|
/// The selection of the model of a causal mechanism.
///
/// This is the port of `dowhy.gcm.auto.select_model` and of
/// `dowhy.gcm.auto.find_best_model`. The upstream picks the model of a node
/// out of a zoo of scikit-learn estimators: it evaluates every model of the
/// zoo with a cross validation of five folds and it keeps the model with the
/// smallest mean squared error for a continuous target and the model with the
/// smallest log loss for a categorical one.
///
/// The deviations of the port are the following ones. The upstream shuffles
/// the rows of the cross validation with the global generator of numpy, so
/// its folds are not reproducible; the port shuffles them with its own
/// generator, whose seed is an argument of the functions. The upstream
/// evaluates the models of the zoo in parallel and gives every model its own
/// random seed; the port evaluates them one after the other, and the seed of
/// the generator is the one of the caller. The upstream evaluates the models
/// of the zoo of the scikit-learn estimators, which the port does not have;
/// the port evaluates the models of the `gcm` package, and the two families
/// of the upstream, the linear one and the non-linear one, are the ordinary
/// least squares regression and the nearest neighbour regression.

///|
/// The number of the folds of the cross validation of the selection.
///
/// This is the number of the splits of the upstream, which is five for the
/// `GOOD` quality and for the `BETTER` quality.
const MODEL_SELECTION_SPLITS : Int32 = 5

///|
/// The largest number of the rows of a split of the cross validation.
///
/// This is the limit of the upstream, which uses the first rows of a split
/// when the split holds more rows than the limit.
const MODEL_SELECTION_MAX_ROWS : Int32 = 20000

///|
/// The smallest probability the log loss uses.
///
/// This is the epsilon of `sklearn.metrics.log_loss`, which clips the
/// probabilities away from zero and away from one before it takes their
/// logarithm.
const LOG_LOSS_EPSILON : Double = 0.0000000000000002220446049250313

///|
/// The model that the selection picked for a node.
///
/// This is the port of the model that `dowhy.gcm.auto.select_model` returns.
/// The upstream returns a scikit-learn regressor or a scikit-learn
/// classifier; the port returns a prediction model or a classification model
/// of the `gcm` package.
pub enum SelectedModel {
  /// The model of a continuous target.
  Regression(PredictionModel)
  /// The model of a categorical target.
  Classification(ClassificationModel)
}

///|
/// The performance of one model of the zoo of the selection.
///
/// This is the port of the tuple that the upstream keeps for every model it
/// evaluated: the model, its score and the name of the metric.
pub struct ModelPerformance {
  /// The name of the model.
  model : String
  /// The score of the model, the mean of the metric over the folds.
  performance : Double
  /// The name of the metric.
  metric : String
}

///|
/// The name of the model.
pub fn ModelPerformance::model(self : ModelPerformance) -> String {
  self.model
}

///|
/// The score of the model.
pub fn ModelPerformance::performance(self : ModelPerformance) -> Double {
  self.performance
}

///|
/// The name of the metric the score was computed with.
pub fn ModelPerformance::metric(self : ModelPerformance) -> String {
  self.metric
}

///|
/// The result of the model selection.
///
/// This is the port of the pair that `dowhy.gcm.auto.select_model` returns:
/// the model it picked and the performances of the models it evaluated.
pub struct ModelSelection {
  model : SelectedModel
  performances : Array[ModelPerformance]
}

///|
/// The model the selection picked.
pub fn ModelSelection::model(self : ModelSelection) -> SelectedModel {
  self.model
}

///|
/// The performances of the models the selection evaluated, from the best one
/// to the worst one.
pub fn ModelSelection::performances(
  self : ModelSelection,
) -> Array[ModelPerformance] {
  self.performances.copy()
}

///|
/// The name of the metric of a regression.
///
/// This is the name of the upstream, which is the mean squared error.
pub fn regression_metric() -> String {
  "mean squared error (MSE)"
}

///|
/// The name of the metric of a classification.
///
/// This is the name of the upstream, which is the log loss.
pub fn classification_metric() -> String {
  "log loss"
}

///|
/// Select the model of a node by cross validation.
///
/// This is the port of `dowhy.gcm.auto.select_model`. The target of the
/// selection is the only column of the given frame, and the kind of the
/// target decides whether the selection looks for a regression or for a
/// classifier.
pub fn select_model(
  x : @api.DataFrame,
  y : @api.DataFrame,
  quality : AssignmentQuality,
  seed : UInt64,
) -> ModelSelection {
  let names = y.column_names()
  if names.length() == 0 {
    abort("the target of the model selection holds no column")
  }
  let name = names[0]
  if y.is_discrete(name) {
    select_classification_model(x, y.discrete(name), quality, seed)
  } else {
    select_regression_model(x, y.numeric(name), quality, seed)
  }
}

///|
/// Select the model of a continuous target by cross validation.
///
/// The folds of the cross validation are the same for every model of the
/// zoo, the way the upstream computes them once and shares them.
pub fn select_regression_model(
  x : @api.DataFrame,
  y : Array[Double],
  quality : AssignmentQuality,
  seed : UInt64,
) -> ModelSelection {
  let parents = x.column_names()
  let rng = @utils.Random::new(seed)
  let folds = selection_k_folds(y.length(), rng)
  let performances : Array[ModelPerformance] = []
  let mut best = PredictionModel::linear()
  let mut best_score = 0.0
  let mut found = false
  for model in regressors_of(quality) {
    let score = regression_score_of(model, x, parents, y, folds)
    performances.push({
      model: regression_model_name(model),
      performance: score,
      metric: regression_metric(),
    })
    if !found || score < best_score {
      found = true
      best = model
      best_score = score
    }
  }
  sort_performances(performances)
  { model: SelectedModel::Regression(best), performances, }
}

///|
/// Select the model of a categorical target by cross validation.
///
/// The folds of the cross validation are the folds of a stratified cross
/// validation, the way the upstream uses `StratifiedKFold` for a
/// classification.
pub fn select_classification_model(
  x : @api.DataFrame,
  y : Array[String],
  quality : AssignmentQuality,
  seed : UInt64,
) -> ModelSelection {
  let parents = x.column_names()
  let rng = @utils.Random::new(seed)
  let folds = selection_stratified_k_folds(y, rng)
  let performances : Array[ModelPerformance] = []
  let mut best = ClassificationModel::logistic()
  let mut best_score = 0.0
  let mut found = false
  for model in classifiers_of(quality) {
    let score = classification_score_of(model, x, parents, y, folds)
    performances.push({
      model: classification_model_name(model),
      performance: score,
      metric: classification_metric(),
    })
    if !found || score < best_score {
      found = true
      best = model
      best_score = score
    }
  }
  sort_performances(performances)
  { model: SelectedModel::Classification(best), performances, }
}

///|
/// Whether the classifier of the port can be fitted on the given labels.
///
/// This is the port of the check of `dowhy.gcm.auto.find_best_model`, which
/// raises a `ValueError` when the target holds a single class. The port
/// cannot catch an abort, so the check is a function of its own.
pub fn supports_classification(labels : Array[String]) -> Bool {
  sorted_distinct_labels(labels).length() == 2
}

///|
/// The regressors the selection evaluates.
///
/// This is the port of the lists of regressors of `dowhy.gcm.auto`. The
/// upstream evaluates the linear regression and the histogram gradient
/// boosting regression with the `GOOD` quality, and it adds the ridge, the
/// lasso, the random forest, the support vector, the extra trees, the
/// nearest neighbour and the ada boost regression with the `BETTER` quality.
/// It adds the polynomial regression to both lists when the encoded features
/// hold at most five columns.
///
/// The port has the linear regression, the polynomial regression and the
/// nearest neighbour regression, so its `GOOD` quality evaluates the linear
/// and the nearest neighbour regression, and its `BETTER` quality adds the
/// polynomial one. The nearest neighbour regression is the non-linear model of
/// the port, the way the histogram gradient boosting regression is the
/// non-linear model of the upstream.
fn regressors_of(quality : AssignmentQuality) -> Array[PredictionModel] {
  let models : Array[PredictionModel] = [
    PredictionModel::linear(),
    PredictionModel::nearest_neighbour(),
  ]
  match quality {
    Good => models
    Better => {
      models.push(PredictionModel::polynomial())
      models
    }
    Best => {
      // The upstream uses an AutoGluon model for this quality, which needs
      // the optional AutoGluon dependency; the port uses the models of the
      // `BETTER` quality.
      models.push(PredictionModel::polynomial())
      models
    }
  }
}

///|
/// The classifiers the selection evaluates.
///
/// This is the port of the lists of classifiers of `dowhy.gcm.auto`. The
/// upstream evaluates the histogram gradient boosting, the logistic and the
/// decision tree classifier with the `GOOD` quality, and it adds the random
/// forest, the extra trees, the support vector, the nearest neighbour, the
/// Gaussian naive Bayes and the ada boost classifier with the `BETTER`
/// quality. It adds the polynomial logistic regression to both lists when the
/// encoded features hold at most five columns.
///
/// The port has the logistic regression and the polynomial logistic
/// regression, so its lists are the same for the three qualities.
fn classifiers_of(quality : AssignmentQuality) -> Array[ClassificationModel] {
  let models : Array[ClassificationModel] = [
    ClassificationModel::logistic(),
    ClassificationModel::polynomial(),
  ]
  match quality {
    Good => models
    Better => models
    Best => models
  }
}

///|
/// The name of a regressor of the zoo of the selection.
fn regression_model_name(model : PredictionModel) -> String {
  if model.is_nearest_neighbour() {
    "the nearest neighbour regression"
  } else if model.degree() > 0 {
    "the polynomial regression"
  } else {
    "the ordinary least squares regression"
  }
}

///|
/// The name of a classifier of the zoo of the selection.
fn classification_model_name(model : ClassificationModel) -> String {
  if model.is_nearest_neighbour() {
    "the nearest neighbour classifier"
  } else if model.degree() > 0 {
    "the polynomial logistic regression"
  } else {
    "the logistic regression"
  }
}

///|
/// The folds of the cross validation of the selection.
///
/// This is the port of `sklearn.model_selection.KFold` with `shuffle=True`:
/// the rows are shuffled and then split into the folds, and the first
/// `n % k` folds hold one row more than the others.
priv struct SelectionFold {
  /// The rows of the training part of the fold.
  train : Array[Int32]
  /// The rows of the test part of the fold.
  held_out : Array[Int32]
}

///|
/// The folds of a k-fold cross validation.
fn selection_k_folds(n : Int32, rng : @utils.Random) -> Array[SelectionFold] {
  let indices = shuffle_indices(n, rng)
  let folds : Array[SelectionFold] = []
  let fold_size = n / MODEL_SELECTION_SPLITS
  let remainder = n % MODEL_SELECTION_SPLITS
  let mut current = 0
  for f = 0; f < MODEL_SELECTION_SPLITS; f = f + 1 {
    let size = fold_size + (if f < remainder { 1 } else { 0 })
    let held_out : Array[Int32] = []
    for i in current..<(current + size) {
      held_out.push(indices[i])
    }
    folds.push({ train: complement_of(n, held_out), held_out, })
    current = current + size
  }
  folds
}

///|
/// The folds of a stratified k-fold cross validation.
///
/// This is the port of `sklearn.model_selection.StratifiedKFold` with
/// `shuffle=True`: the rows of every class are shuffled and then split into
/// the folds, so that every fold holds the same share of every class.
fn selection_stratified_k_folds(
  labels : Array[String],
  rng : @utils.Random,
) -> Array[SelectionFold] {
  let n = labels.length()
  let fold_rows : Array[Array[Int32]] = []
  for _ in 0..<MODEL_SELECTION_SPLITS {
    fold_rows.push([])
  }
  for label in sorted_distinct_labels(labels) {
    let rows : Array[Int32] = []
    for i in 0..<n {
      if labels[i] == label {
        rows.push(i)
      }
    }
    let shuffled = shuffle_indices_of(rows, rng)
    let fold_size = rows.length() / MODEL_SELECTION_SPLITS
    let remainder = rows.length() % MODEL_SELECTION_SPLITS
    let mut current = 0
    for f = 0; f < MODEL_SELECTION_SPLITS; f = f + 1 {
      let size = fold_size + (if f < remainder { 1 } else { 0 })
      for i in current..<(current + size) {
        fold_rows[f].push(shuffled[i])
      }
      current = current + size
    }
  }
  let folds : Array[SelectionFold] = []
  for f in 0..<MODEL_SELECTION_SPLITS {
    let held_out = fold_rows[f]
    folds.push({ train: complement_of(n, held_out), held_out, })
  }
  folds
}

///|
/// The log loss of the predictions of a classifier.
///
/// This is the port of `sklearn.metrics.log_loss`: the probability of the
/// class of every row is clipped away from zero and away from one, and the
/// mean of the negative logarithms of the probabilities is the loss.
fn log_loss(
  classes : Array[String],
  y_true : Array[String],
  probabilities : Array[Array[Double]],
) -> Double {
  let n = y_true.length()
  if n == 0 {
    return 0.0
  }
  let mut total = 0.0
  for i in 0..<n {
    let index = index_of_class(classes, y_true[i])
    let mut probability = if index >= 0 { probabilities[i][index] } else { 0.0 }
    if probability < LOG_LOSS_EPSILON {
      probability = LOG_LOSS_EPSILON
    }
    if probability > 1.0 - LOG_LOSS_EPSILON {
      probability = 1.0 - LOG_LOSS_EPSILON
    }
    total = total + -@math.ln(probability)
  }
  total / n.to_double()
}

///|
/// The mean squared error of a model over the folds of the cross validation.
///
/// The encoder of the parents is fitted on the training rows of the fold and
/// applied to the test rows of the fold, the way the upstream fits its
/// encoders on the training rows of the fold and applies them to the test
/// rows of the fold.
fn regression_score_of(
  model : PredictionModel,
  x : @api.DataFrame,
  parents : Array[String],
  y : Array[Double],
  folds : Array[SelectionFold],
) -> Double {
  let mut total = 0.0
  let mut count = 0
  for fold in folds {
    let train_rows = limited_rows(fold.train)
    let held_out_rows = limited_rows(fold.held_out)
    let train_frame = x.take_rows(train_rows)
    let held_out_frame = x.take_rows(held_out_rows)
    let encoder = ParentEncoder::fit(train_frame, parents)
    let train_x = encoder.design_matrix(train_frame, parents)
    let held_out_x = encoder.design_matrix(held_out_frame, parents)
    let fitted = model.fit(train_x, take_values(y, train_rows))
    let predicted = fitted.predict(held_out_x)
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
/// skipped, the way the upstream skips it: the classifier cannot be fitted on
/// it and the log loss cannot be computed on it.
fn classification_score_of(
  model : ClassificationModel,
  x : @api.DataFrame,
  parents : Array[String],
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
    let train_frame = x.take_rows(train_rows)
    let held_out_frame = x.take_rows(held_out_rows)
    let encoder = ParentEncoder::fit(train_frame, parents)
    let train_x = encoder.design_matrix(train_frame, parents)
    let held_out_x = encoder.design_matrix(held_out_frame, parents)
    let fitted = model.fit(train_x, train_labels)
    let probabilities = fitted.predict_probabilities(held_out_x)
    total = total + log_loss(fitted.classes(), held_out_labels, probabilities)
    count = count + 1
  }
  if count == 0 {
    return 0.0
  }
  total / count.to_double()
}

///|
/// The first rows of a split of the cross validation.
///
/// This is the limit of the upstream, which uses the first rows of a split
/// when the split holds more rows than the limit.
fn limited_rows(rows : Array[Int32]) -> Array[Int32] {
  if rows.length() <= MODEL_SELECTION_MAX_ROWS {
    return rows.copy()
  }
  let out : Array[Int32] = []
  for i in 0..<MODEL_SELECTION_MAX_ROWS {
    out.push(rows[i])
  }
  out
}

///|
/// The rows that are not in the given rows.
fn complement_of(n : Int32, rows : Array[Int32]) -> Array[Int32] {
  let taken : Array[Bool] = []
  for _ in 0..<n {
    taken.push(false)
  }
  for row in rows {
    if row >= 0 && row < n {
      taken[row] = true
    }
  }
  let out : Array[Int32] = []
  for i in 0..<n {
    if !taken[i] {
      out.push(i)
    }
  }
  out
}

///|
/// A random permutation of the rows of the data.
fn shuffle_indices(n : Int32, rng : @utils.Random) -> Array[Int32] {
  let out : Array[Int32] = []
  for i in 0..<n {
    out.push(i)
  }
  shuffle_indices_of(out, rng)
}

///|
/// The given rows in a random order.
///
/// This is the shuffle of `Random::shuffle`, the Fisher-Yates shuffle that
/// walks the rows from the back.
fn shuffle_indices_of(
  indices : Array[Int32],
  rng : @utils.Random,
) -> Array[Int32] {
  let out = indices.copy()
  let n = out.length()
  let mut i = n - 1
  while i > 0 {
    let j = rng.next_int(i + 1)
    let tmp = out[i]
    out[i] = out[j]
    out[j] = tmp
    i = i - 1
  }
  out
}

///|
/// The values of the given rows.
fn take_values(values : Array[Double], rows : Array[Int32]) -> Array[Double] {
  let out : Array[Double] = []
  for row in rows {
    if row >= 0 && row < values.length() {
      out.push(values[row])
    }
  }
  out
}

///|
/// The labels of the given rows.
fn take_labels(labels : Array[String], rows : Array[Int32]) -> Array[String] {
  let out : Array[String] = []
  for row in rows {
    if row >= 0 && row < labels.length() {
      out.push(labels[row])
    }
  }
  out
}

///|
/// The performances, from the best one to the worst one.
///
/// This is the sort of the upstream, which sorts the results of the models
/// by their score and keeps the first one.
fn sort_performances(performances : Array[ModelPerformance]) -> Unit {
  let mut i = 1
  while i < performances.length() {
    let current = performances[i]
    let mut j = i - 1
    while j >= 0 && performances[j].performance > current.performance {
      performances[j + 1] = performances[j]
      j = j - 1
    }
    performances[j + 1] = current
    i = i + 1
  }
}
