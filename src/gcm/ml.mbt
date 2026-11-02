///|
/// The prediction models of the `gcm` package.
///
/// This is the port of `dowhy.gcm.ml`. The upstream wraps the scikit-learn
/// regressors and classifiers in `SklearnRegressionModel` and
/// `SklearnClassificationModel`; the port implements the linear regression and
/// the logistic regression, which are the two models the upstream tests of the
/// causal mechanisms use. The upstream can select a model by cross validation
/// from a whole zoo of scikit-learn estimators; the port has one model per
/// kind, so the selection is made by the kind of the target alone.

///|
/// A prediction model that maps a design matrix to a continuous target.
///
/// This is the port of `dowhy.gcm.ml.PredictionModel`. The upstream model holds
/// a scikit-learn regressor; the port holds the coefficients of a linear model,
/// which is the regressor the upstream tests use.
pub struct PredictionModel {
  /// The coefficient of every feature, without the intercept.
  coefficients : Array[Double]
  /// The intercept of the model.
  intercept : Double
  /// Whether the model has been fitted.
  fitted : Bool
  /// Whether the parameters of the model are fixed, which means that the model
  /// is never fitted again.
  fixed : Bool
  /// The custom function of an equation, when the model is one.
  equation : EquationModel?
}

///|
/// An unfitted linear prediction model.
///
/// This is the port of `dowhy.gcm.ml.create_linear_regressor`.
pub fn PredictionModel::linear() -> PredictionModel {
  {
    coefficients: [],
    intercept: 0.0,
    fitted: false,
    fixed: false,
    equation: None,
  }
}

///|
/// A prediction model with the given parameters, which is never fitted again.
///
/// This is the port of
/// `dowhy.gcm.ml.create_linear_regressor_with_given_parameters`. The parameters
/// of such a model are its hyper parameters and not the result of a fit, so the
/// fit of the model does nothing and the clone of the model keeps them.
pub fn PredictionModel::with_fixed_parameters(
  coefficients : Array[Double],
  intercept : Double,
) -> PredictionModel {
  {
    coefficients: coefficients.copy(),
    intercept,
    fitted: true,
    fixed: true,
    equation: None,
  }
}

///|
/// Whether the parameters of the model are fixed.
pub fn PredictionModel::has_fixed_parameters(self : PredictionModel) -> Bool {
  self.fixed
}

///|
/// Whether the model has been fitted.
pub fn PredictionModel::is_fitted(self : PredictionModel) -> Bool {
  self.fitted
}

///|
/// The coefficient of every feature, without the intercept.
pub fn PredictionModel::coefficients(self : PredictionModel) -> Array[Double] {
  self.coefficients.copy()
}

///|
/// The intercept of the model.
pub fn PredictionModel::intercept(self : PredictionModel) -> Double {
  self.intercept
}

///|
/// Fit the model on the given data.
///
/// The result is a new model; the model the fit is called on stays as it is.
/// The fit is the fit of `sklearn.linear_model.LinearRegression`, which centres
/// the features and the target before the least squares fit and computes the
/// intercept from the offsets. The centring matters: the one-hot encoding of
/// a categorical parent and the intercept are collinear, and the two
/// conventions spread the same fit over the columns differently. The centred
/// one is the convention of the upstream, so it is the one the port uses.
///
/// The fit of a model whose parameters are fixed does nothing, which is the
/// fit of `dowhy.gcm.ml.regression.LinearRegressionWithFixedParameter`.
pub fn PredictionModel::fit(
  self : PredictionModel,
  x : @utils.Matrix,
  y : Array[Double],
) -> PredictionModel {
  match self.equation {
    Some(equation) =>
      // The custom function of an equation is fully defined, so there is
      // nothing to fit.
      return {
        coefficients: self.coefficients.copy(),
        intercept: self.intercept,
        fitted: true,
        fixed: true,
        equation: Some(equation),
      }
    None => ()
  }
  if self.fixed {
    // The upstream keeps the parameters of a model whose parameters are fixed.
    return {
      coefficients: self.coefficients.copy(),
      intercept: self.intercept,
      fitted: true,
      fixed: true,
      equation: None,
    }
  }
  let p = x.ncols()
  let n = x.nrows()
  if p == 0 {
    return {
      coefficients: [],
      intercept: @utils.mean(y),
      fitted: true,
      fixed: false,
      equation: None,
    }
  }
  let offsets : Array[Double] = []
  for j = 0; j < p; j = j + 1 {
    offsets.push(@utils.mean(x.col(j)))
  }
  let y_offset = @utils.mean(y)
  let centred = @utils.Matrix::zeros(n, p)
  for i = 0; i < n; i = i + 1 {
    for j = 0; j < p; j = j + 1 {
      centred.set(i, j, x.get(i, j) - offsets[j])
    }
  }
  let centred_y : Array[Double] = []
  for value in y {
    centred_y.push(value - y_offset)
  }
  let coefficients = @utils.lstsq(centred, centred_y)
  let mut intercept = y_offset
  for j = 0; j < p; j = j + 1 {
    intercept = intercept - offsets[j] * coefficients[j]
  }
  { coefficients, intercept, fitted: true, fixed: false, equation: None, }
}

///|
/// Predict the target of every row of the design matrix.
pub fn PredictionModel::predict(
  self : PredictionModel,
  x : @utils.Matrix,
) -> Array[Double] {
  match self.equation {
    Some(equation) => return predict_equation(equation, x)
    None => ()
  }
  if !self.fitted {
    abort("the prediction model has not been fitted")
  }
  let out : Array[Double] = []
  for i = 0; i < x.nrows(); i = i + 1 {
    let mut value = self.intercept
    for j = 0; j < x.ncols(); j = j + 1 {
      if j < self.coefficients.length() {
        value = value + self.coefficients[j] * x.get(i, j)
      }
    }
    out.push(value)
  }
  out
}

///|
/// A copy of the model.
///
/// This is the port of `dowhy.gcm.ml.regression.SklearnRegressionModel.clone`,
/// which clones the model with the same hyper parameters but not fitted. A
/// model whose parameters are fixed keeps them, because they are its hyper
/// parameters and not the result of a fit; that is the clone of
/// `dowhy.gcm.ml.regression.LinearRegressionWithFixedParameter`.
pub fn PredictionModel::clone(self : PredictionModel) -> PredictionModel {
  match self.equation {
    Some(equation) =>
      // The custom function of an equation is fully defined, so the copy keeps
      // it, like the copy of the upstream does.
      return {
        coefficients: [],
        intercept: 0.0,
        fitted: true,
        fixed: true,
        equation: Some(equation),
      }
    None => ()
  }
  if self.fixed {
    return {
      coefficients: self.coefficients.copy(),
      intercept: self.intercept,
      fitted: self.fitted,
      fixed: true,
      equation: None,
    }
  }
  {
    coefficients: [],
    intercept: 0.0,
    fitted: false,
    fixed: false,
    equation: None,
  }
}

///|
/// A classification model that maps a design matrix to a class label.
///
/// This is the port of `dowhy.gcm.ml.ClassificationModel`. The upstream model
/// wraps a scikit-learn classifier that can predict the probability of every
/// class; the port implements the logistic regression of two classes, which is
/// the classifier the upstream tests of the causal mechanisms use.
pub struct ClassificationModel {
  /// The coefficient of every feature, without the intercept.
  coefficients : Array[Double]
  /// The intercept of the model.
  intercept : Double
  /// The classes of the model, in lexicographic order.
  classes : Array[String]
  /// Whether the model has been fitted.
  fitted : Bool
}

///|
/// An unfitted logistic classification model.
///
/// This is the port of `dowhy.gcm.ml.create_logistic_regression_classifier`.
pub fn ClassificationModel::logistic() -> ClassificationModel {
  { coefficients: [], intercept: 0.0, classes: [], fitted: false, }
}

///|
/// Whether the model has been fitted.
pub fn ClassificationModel::is_fitted(self : ClassificationModel) -> Bool {
  self.fitted
}

///|
/// The classes of the model, in lexicographic order.
pub fn ClassificationModel::classes(
  self : ClassificationModel,
) -> Array[String] {
  self.classes.copy()
}

///|
/// Fit the model on the given labels.
///
/// The result is a new model; the model the fit is called on stays as it is.
/// The fit is the logistic regression of `sklearn.linear_model.LogisticRegression`
/// with its default parameters, which is the convention the `utils` package
/// implements.
pub fn ClassificationModel::fit(
  self : ClassificationModel,
  x : @utils.Matrix,
  y : Array[String],
) -> ClassificationModel {
  let _ = self
  let classes = sorted_distinct_labels(y)
  if classes.length() != 2 {
    abort(
      "the port supports a classifier of two classes only, but the target has " +
      classes.length().to_string() +
      " classes",
    )
  }
  let response : Array[Double] = []
  for label in y {
    response.push(if label == classes[0] { 0.0 } else { 1.0 })
  }
  let fit = @utils.logistic_fit(
    with_intercept_column(x),
    response,
    1.0,
    100,
    1.0e-8,
  )
  let beta = fit.beta
  let coefficients : Array[Double] = []
  for i = 1; i < beta.length(); i = i + 1 {
    coefficients.push(beta[i])
  }
  let intercept = if beta.length() > 0 { beta[0] } else { 0.0 }
  { coefficients, intercept, classes, fitted: true, }
}

///|
/// The probability of every class for every row of the design matrix.
///
/// The probabilities of a row sum to one, and the classes are in the order of
/// `classes`.
pub fn ClassificationModel::predict_probabilities(
  self : ClassificationModel,
  x : @utils.Matrix,
) -> Array[Array[Double]] {
  if !self.fitted {
    abort("the classification model has not been fitted")
  }
  let out : Array[Array[Double]] = []
  for i = 0; i < x.nrows(); i = i + 1 {
    let mut value = self.intercept
    for j = 0; j < x.ncols(); j = j + 1 {
      if j < self.coefficients.length() {
        value = value + self.coefficients[j] * x.get(i, j)
      }
    }
    let positive = @utils.sigmoid(value)
    out.push([1.0 - positive, positive])
  }
  out
}

///|
/// The predicted class of every row of the design matrix.
pub fn ClassificationModel::predict(
  self : ClassificationModel,
  x : @utils.Matrix,
) -> Array[String] {
  let out : Array[String] = []
  for probabilities in self.predict_probabilities(x) {
    if probabilities[1] > probabilities[0] {
      out.push(self.classes[1])
    } else {
      out.push(self.classes[0])
    }
  }
  out
}

///|
/// A copy of the model.
///
/// This is the port of
/// `dowhy.gcm.ml.classification.SklearnClassificationModel.clone`, which clones
/// the model with the same hyper parameters but not fitted.
pub fn ClassificationModel::clone(
  self : ClassificationModel,
) -> ClassificationModel {
  let _ = self
  { coefficients: [], intercept: 0.0, classes: [], fitted: false, }
}

///|
/// An invertible function of a causal mechanism.
///
/// This is the port of `dowhy.gcm.ml.regression.InvertibleFunction`. The
/// function is applied to the sum of the prediction and the noise, and its
/// inverse is applied to the target before the prediction is fitted.
pub enum InvertibleFunction {
  ///
  /// The identity function, which leaves the prediction alone.
  Identity
  ///
  /// The exponential function, whose inverse is the logarithm.
  Exponential
  ///
  /// The logarithm, whose inverse is the exponential function.
  Logarithmic
}

///|
/// The identity function, which leaves the prediction alone.
pub fn InvertibleFunction::identity() -> InvertibleFunction {
  Identity
}

///|
/// The exponential function, whose inverse is the logarithm.
pub fn InvertibleFunction::exponential() -> InvertibleFunction {
  Exponential
}

///|
/// The logarithm, whose inverse is the exponential function.
pub fn InvertibleFunction::logarithmic() -> InvertibleFunction {
  Logarithmic
}

///|
/// Apply the function on the given values.
pub fn InvertibleFunction::evaluate(
  self : InvertibleFunction,
  x : Array[Double],
) -> Array[Double] {
  let out : Array[Double] = []
  for value in x {
    match self {
      Identity => out.push(value)
      Exponential => out.push(@math.exp(value))
      Logarithmic => out.push(@math.ln(value))
    }
  }
  out
}

///|
/// Apply the inverse of the function on the given values.
pub fn InvertibleFunction::evaluate_inverse(
  self : InvertibleFunction,
  x : Array[Double],
) -> Array[Double] {
  let out : Array[Double] = []
  for value in x {
    match self {
      Identity => out.push(value)
      Exponential => out.push(@math.ln(value))
      Logarithmic => out.push(@math.exp(value))
    }
  }
  out
}

///|
/// The matrix with an intercept column in front of its columns.
pub fn with_intercept_column(x : @utils.Matrix) -> @utils.Matrix {
  let out = @utils.Matrix::zeros(x.nrows(), x.ncols() + 1)
  for i = 0; i < x.nrows(); i = i + 1 {
    out.set(i, 0, 1.0)
    for j = 0; j < x.ncols(); j = j + 1 {
      out.set(i, j + 1, x.get(i, j))
    }
  }
  out
}

///|
/// The distinct values of the labels, in lexicographic order.
fn sorted_distinct_labels(y : Array[String]) -> Array[String] {
  let distinct : Array[String] = []
  for label in y {
    if !distinct.contains(label) {
      distinct.push(label)
    }
  }
  distinct.sort_by(fn(a, b) { a.lexical_compare(b) })
  distinct
}

///|
/// A prediction model that predicts with the average of the targets of the
/// nearest neighbours of a row.
///
/// This is the port of `dowhy.gcm.ml.regression.create_knn_regressor`, which
/// wraps `sklearn.neighbors.KNeighborsRegressor` with its default parameters:
/// five neighbours and the uniform weights.  The neighbours of a row are the
/// rows of the training data with the smallest euclidean distance to it, and
/// a tie is broken with the order of the rows, which is the rule of a scan
/// over the rows.
pub struct KnnModel {
  /// The number of the neighbours.
  k : Int32
  /// The rows of the training data.
  rows : @utils.Matrix
  /// The targets of the training data.
  targets : Array[Double]
  /// The rows of the training data, sorted by their first column.
  order : Array[Int32]
  /// Whether the model has been fitted.
  fitted : Bool
}

///|
/// An unfitted nearest neighbour prediction model.
pub fn KnnModel::new(k : Int32) -> KnnModel {
  {
    k,
    rows: @utils.Matrix::zeros(0, 0),
    targets: [],
    order: [],
    fitted: false,
  }
}

///|
/// Fit the model on the given data.
///
/// The result is a new model; the model the fit is called on stays as it is.
/// The fit of `sklearn.neighbors.KNeighborsRegressor` keeps the training data
/// and computes nothing else.
pub fn KnnModel::fit(
  self : KnnModel,
  x : @utils.Matrix,
  y : Array[Double],
) -> KnnModel {
  let order : Array[Int32] = []
  for i in 0..<x.nrows() {
    order.push(i)
  }
  // The rows are sorted by their first column, so that the neighbours of a row
  // are found with a walk over the sorted rows instead of a scan over all of
  // them.  The walk finds the same neighbours as the scan.
  if x.ncols() > 0 {
    order.sort_by(fn(a, b) {
      let c = @utils.compare_double(x.get(a, 0), x.get(b, 0))
      if c != 0 {
        c
      } else if a < b {
        -1
      } else if a > b {
        1
      } else {
        0
      }
    })
  }
  { k: self.k, rows: x.copy(), targets: y.copy(), order, fitted: true, }
}

///|
/// Predict the target of every row of the design matrix.
pub fn KnnModel::predict(self : KnnModel, x : @utils.Matrix) -> Array[Double] {
  if !self.fitted {
    abort("the prediction model has not been fitted")
  }
  let out : Array[Double] = []
  if self.rows.ncols() == 0 {
    // Without a feature every row has the same distance to every row of the
    // training data, so the prediction is the mean of the targets.
    let mean = @utils.mean(self.targets)
    for _ in 0..<x.nrows() {
      out.push(mean)
    }
    return out
  }
  for i in 0..<x.nrows() {
    out.push(self.predict_row(x.row(i)))
  }
  out
}

///|
/// The prediction of one row: the average of the targets of its neighbours.
///
/// The neighbours are the rows with the smallest euclidean distance to the
/// row.  The rows are sorted by their first column, so the walk over the
/// sorted rows stops as soon as the rows that are left are further away than
/// the neighbours that were found already.
fn KnnModel::predict_row(self : KnnModel, query : Array[Double]) -> Double {
  let n = self.order.length()
  let k = if self.k < n { self.k } else { n }
  // The distances of the neighbours that were found and the rows they belong
  // to, in the order of their distance.
  let best_distances : Array[Double] = []
  let best_rows : Array[Int32] = []
  // The position of the row in the sorted rows.
  let mut lo = 0
  let mut hi = n
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    if self.rows.get(self.order[mid], 0) < query[0] {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  let mut left = lo - 1
  let mut right = lo
  let mut done = false
  while !done {
    if left < 0 && right >= n {
      // Every row was visited already.
      done = true
      break
    }
    // The smallest squared distance a row that was not visited can have.
    let mut bound = 1.0e300
    if left >= 0 {
      let difference = query[0] - self.rows.get(self.order[left], 0)
      bound = difference * difference
    }
    if right < n {
      let difference = self.rows.get(self.order[right], 0) - query[0]
      let squared = difference * difference
      if squared < bound {
        bound = squared
      }
    }
    if best_distances.length() == k && bound > best_distances[k - 1] {
      // Every row that is left is further away than the neighbours that were
      // found already.
      done = true
      break
    }
    // The nearer of the two sides is visited first.
    let take_left = if right >= n {
      true
    } else if left < 0 {
      false
    } else {
      let difference = query[0] - self.rows.get(self.order[left], 0)
      let right_difference = self.rows.get(self.order[right], 0) - query[0]
      difference <= right_difference
    }
    let row = if take_left {
      let visited = self.order[left]
      left = left - 1
      visited
    } else {
      let visited = self.order[right]
      right = right + 1
      visited
    }
    let distance = squared_distance(query, self.rows, row)
    // The neighbours are kept in the order of their distance.
    let mut position = best_distances.length()
    for i in 0..<best_distances.length() {
      if distance < best_distances[i] {
        position = i
        break
      }
    }
    if position < k {
      best_distances.insert(position, distance)
      best_rows.insert(position, row)
      if best_distances.length() > k {
        let _ = best_distances.pop()
        let _ = best_rows.pop()
      }
    }
  }
  let mut sum = 0.0
  for row in best_rows {
    sum = sum + self.targets[row]
  }
  if best_rows.length() == 0 {
    return 0.0
  }
  sum / best_rows.length().to_double()
}

///|
/// The squared euclidean distance of a row and a row of a matrix.
fn squared_distance(
  query : Array[Double],
  rows : @utils.Matrix,
  row : Int32,
) -> Double {
  let mut total = 0.0
  for j in 0..<query.length() {
    if j >= rows.ncols() {
      break
    }
    let difference = query[j] - rows.get(row, j)
    total = total + difference * difference
  }
  total
}

///|
/// A regressor of the `gcm` package.
///
/// The upstream wraps a whole zoo of scikit-learn regressors in
/// `SklearnRegressionModel`; the port has the linear regression and the
/// nearest neighbour regression, which are the two the upstream test of the
/// change attribution uses.
pub enum Regressor {
  /// The ordinary least squares regression.
  Linear(PredictionModel)
  /// The nearest neighbour regression.
  NearestNeighbour(KnnModel)
}

///|
/// The ordinary least squares regressor.
pub fn Regressor::linear() -> Regressor {
  Linear(PredictionModel::linear())
}

///|
/// The nearest neighbour regressor with the given number of neighbours.
pub fn Regressor::nearest_neighbour(k : Int32) -> Regressor {
  NearestNeighbour(KnnModel::new(k))
}

///|
/// Fit the regressor on the given data.
///
/// The result is a new regressor; the regressor the fit is called on stays as
/// it is.
pub fn Regressor::fit(
  self : Regressor,
  x : @utils.Matrix,
  y : Array[Double],
) -> Regressor {
  match self {
    Linear(model) => Linear(model.fit(x, y))
    NearestNeighbour(model) => NearestNeighbour(model.fit(x, y))
  }
}

///|
/// Predict the target of every row of the design matrix.
pub fn Regressor::predict(self : Regressor, x : @utils.Matrix) -> Array[Double] {
  match self {
    Linear(model) => model.predict(x)
    NearestNeighbour(model) => model.predict(x)
  }
}
