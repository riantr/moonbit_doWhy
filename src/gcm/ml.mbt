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
