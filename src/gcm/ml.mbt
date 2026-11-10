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
  /// The degree of the polynomial expansion of the features, zero when the
  /// model is fitted on the features themselves.
  degree : Int32
  /// The nearest neighbour model, when the model is one.
  neighbours : KnnModel?
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
    degree: 0,
    neighbours: None,
  }
}

///|
/// A prediction model of the polynomial features of the input.
///
/// This is the port of `dowhy.gcm.ml.create_polynom_regressor`, which builds the
/// pipeline of `PolynomialFeatures(degree=degree, include_bias=False)` and a
/// linear regression. The port fits a linear model on the expanded features, so
/// the model holds the coefficients of the expansion and the degree of it. The
/// default degree is the default of the upstream, which is two.
pub fn PredictionModel::polynomial(degree~ : Int32 = 2) -> PredictionModel {
  if degree < 1 {
    abort("the degree of a polynomial model has to be at least one")
  }
  {
    coefficients: [],
    intercept: 0.0,
    fitted: false,
    fixed: false,
    equation: None,
    degree,
    neighbours: None,
  }
}

///|
/// A prediction model of the nearest neighbours of a row.
///
/// This is the port of `dowhy.gcm.ml.regression.create_knn_regressor`, which
/// wraps `sklearn.neighbors.KNeighborsRegressor` with its default parameters:
/// five neighbours and the uniform weights. The neighbours of a row are the
/// rows of the training data with the smallest euclidean distance to it.
pub fn PredictionModel::nearest_neighbour(k~ : Int32 = 5) -> PredictionModel {
  if k < 1 {
    abort("the number of the neighbours has to be at least one")
  }
  {
    coefficients: [],
    intercept: 0.0,
    fitted: false,
    fixed: false,
    equation: None,
    degree: 0,
    neighbours: Some(KnnModel::new(k)),
  }
}

///|
/// Whether the model is a nearest neighbour model.
///
/// A nearest neighbour model has no coefficient and no intercept: it keeps the
/// training data and predicts with the average of the targets of the
/// neighbours of a row.
pub fn PredictionModel::is_nearest_neighbour(self : PredictionModel) -> Bool {
  match self.neighbours {
    Some(_) => true
    None => false
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
    degree: 0,
    neighbours: None,
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
/// The degree of the polynomial expansion of the features of the model.
///
/// The degree is zero when the model is fitted on the features themselves.
pub fn PredictionModel::degree(self : PredictionModel) -> Int32 {
  self.degree
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
        degree: self.degree,
        neighbours: self.neighbours,
      }
    None => ()
  }
  match self.neighbours {
    Some(neighbours) =>
      // A nearest neighbour model keeps the training data and computes nothing
      // else, so the fit is the fit of the nearest neighbour model.
      return {
        coefficients: [],
        intercept: 0.0,
        fitted: true,
        fixed: false,
        equation: None,
        degree: 0,
        neighbours: Some(neighbours.fit(x, y)),
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
      degree: self.degree,
      neighbours: None,
    }
  }
  let n = x.nrows()
  // A model of the polynomial features is fitted on the expansion of the
  // features, the way the pipeline of the upstream expands them before its
  // linear regression sees them.
  let design = if self.degree > 0 {
    polynomial_features(x, self.degree)
  } else {
    x
  }
  let p = design.ncols()
  if p == 0 {
    return {
      coefficients: [],
      intercept: @utils.mean(y),
      fitted: true,
      fixed: false,
      equation: None,
      degree: self.degree,
      neighbours: None,
    }
  }
  let offsets : Array[Double] = []
  for j = 0; j < p; j = j + 1 {
    offsets.push(@utils.mean(design.col(j)))
  }
  let y_offset = @utils.mean(y)
  let centred = @utils.Matrix::zeros(n, p)
  for i = 0; i < n; i = i + 1 {
    for j = 0; j < p; j = j + 1 {
      centred.set(i, j, design.get(i, j) - offsets[j])
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
  {
    coefficients,
    intercept,
    fitted: true,
    fixed: false,
    equation: None,
    degree: self.degree,
    neighbours: None,
  }
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
  match self.neighbours {
    Some(neighbours) => return neighbours.predict(x)
    None => ()
  }
  if !self.fitted {
    abort("the prediction model has not been fitted")
  }
  // A model of the polynomial features predicts with the expansion of the
  // features, the way the pipeline of the upstream expands them before its
  // linear regression sees them.
  let design = if self.degree > 0 {
    polynomial_features(x, self.degree)
  } else {
    x
  }
  let out : Array[Double] = []
  for i = 0; i < design.nrows(); i = i + 1 {
    let mut value = self.intercept
    for j = 0; j < design.ncols(); j = j + 1 {
      if j < self.coefficients.length() {
        value = value + self.coefficients[j] * design.get(i, j)
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
        degree: self.degree,
        neighbours: self.neighbours,
      }
    None => ()
  }
  match self.neighbours {
    Some(neighbours) =>
      // The copy keeps the number of the neighbours, because it is a hyper
      // parameter of the model and not the result of a fit.
      return {
        coefficients: [],
        intercept: 0.0,
        fitted: false,
        fixed: false,
        equation: None,
        degree: 0,
        neighbours: Some(KnnModel::new(neighbours.k)),
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
      degree: self.degree,
      neighbours: None,
    }
  }
  {
    coefficients: [],
    intercept: 0.0,
    fitted: false,
    fixed: false,
    equation: None,
    degree: self.degree,
    neighbours: None,
  }
}

///|
/// The one-versus-rest models of a classifier of more than two classes.
///
/// This is the port of the multiclass logistic regression of the upstream,
/// which scikit-learn fits with a multinomial solver. The port fits one
/// binary logistic regression per class and it normalises the probabilities
/// of the classes, the way the one-versus-rest variant of the logistic
/// regression does.
pub struct OneVersusRestModel {
  /// The coefficient of every feature of every class, without the intercept.
  coefficients : Array[Array[Double]]
  /// The intercept of every class.
  intercepts : Array[Double]
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
  /// The degree of the polynomial expansion of the features, zero when the
  /// model is fitted on the features themselves.
  degree : Int32
  /// The one-versus-rest models, when the target holds more than two classes.
  one_versus_rest : OneVersusRestModel?
  /// The nearest neighbour model, when the model is one.
  neighbours : KnnClassifier?
}

///|
/// An unfitted logistic classification model.
///
/// This is the port of `dowhy.gcm.ml.create_logistic_regression_classifier`.
pub fn ClassificationModel::logistic() -> ClassificationModel {
  {
    coefficients: [],
    intercept: 0.0,
    classes: [],
    fitted: false,
    degree: 0,
    one_versus_rest: None,
    neighbours: None,
  }
}

///|
/// A classification model of the nearest neighbours of a row.
///
/// This is the port of
/// `dowhy.gcm.ml.classification.create_knn_classifier`, which wraps
/// `sklearn.neighbors.KNeighborsClassifier` with its default parameters: five
/// neighbours and the uniform weights. The neighbours of a row are the rows of
/// the training data with the smallest euclidean distance to it, and the class
/// of the row is the class of the majority of its neighbours.
pub fn ClassificationModel::nearest_neighbour(
  k~ : Int32 = 5,
) -> ClassificationModel {
  if k < 1 {
    abort("the number of the neighbours has to be at least one")
  }
  {
    coefficients: [],
    intercept: 0.0,
    classes: [],
    fitted: false,
    degree: 0,
    one_versus_rest: None,
    neighbours: Some(KnnClassifier::new(k)),
  }
}

///|
/// Whether the model is a nearest neighbour model.
///
/// A nearest neighbour model has no coefficient and no intercept: it keeps the
/// training data and predicts with the classes of the neighbours of a row.
pub fn ClassificationModel::is_nearest_neighbour(
  self : ClassificationModel,
) -> Bool {
  match self.neighbours {
    Some(_) => true
    None => false
  }
}

///|
/// A classification model of the polynomial features of the input.
///
/// This is the port of
/// `dowhy.gcm.ml.classification.create_polynom_logistic_regression_classifier`,
/// which builds the pipeline of `PolynomialFeatures(degree=degree,
/// include_bias=False)` and a logistic regression. The port fits a logistic
/// regression on the expanded features, so the model holds the coefficients of
/// the expansion and the degree of it. The default degree is the default of the
/// upstream, which is three.
pub fn ClassificationModel::polynomial(
  degree~ : Int32 = 3,
) -> ClassificationModel {
  if degree < 1 {
    abort("the degree of a polynomial model has to be at least one")
  }
  {
    coefficients: [],
    intercept: 0.0,
    classes: [],
    fitted: false,
    degree,
    one_versus_rest: None,
    neighbours: None,
  }
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
/// The degree of the polynomial expansion of the features of the model.
///
/// The degree is zero when the model is fitted on the features themselves.
pub fn ClassificationModel::degree(self : ClassificationModel) -> Int32 {
  self.degree
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
  let classes = sorted_distinct_labels(y)
  if classes.length() < 2 {
    abort(
      "the target of a classifier needs at least two classes, but it has " +
      classes.length().to_string() +
      " classes",
    )
  }
  match self.neighbours {
    Some(neighbours) =>
      // A nearest neighbour model keeps the training data and computes nothing
      // else, so the fit is the fit of the nearest neighbour classifier.
      return {
        coefficients: [],
        intercept: 0.0,
        classes,
        fitted: true,
        degree: 0,
        one_versus_rest: None,
        neighbours: Some(neighbours.fit(x, y)),
      }
    None => ()
  }
  // A model of the polynomial features is fitted on the expansion of the
  // features, the way the pipeline of the upstream expands them before its
  // logistic regression sees them.
  let design = if self.degree > 0 {
    polynomial_features(x, self.degree)
  } else {
    x
  }
  if classes.length() > 2 {
    return fit_one_versus_rest(self, design, y, classes)
  }
  let response : Array[Double] = []
  for label in y {
    response.push(if label == classes[0] { 0.0 } else { 1.0 })
  }
  let fit = @utils.logistic_fit(
    with_intercept_column(design),
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
  {
    coefficients,
    intercept,
    classes,
    fitted: true,
    degree: self.degree,
    one_versus_rest: None,
    neighbours: None,
  }
}

///|
/// Fit one binary logistic regression per class and normalise the
/// probabilities of the classes.
///
/// The response of the model of a class holds a one for the rows of that
/// class and a zero for the rows of the other classes.
fn fit_one_versus_rest(
  model : ClassificationModel,
  design : @utils.Matrix,
  y : Array[String],
  classes : Array[String],
) -> ClassificationModel {
  let coefficients : Array[Array[Double]] = []
  let intercepts : Array[Double] = []
  for k in 0..<classes.length() {
    let response : Array[Double] = []
    for label in y {
      if label == classes[k] {
        response.push(1.0)
      } else {
        response.push(0.0)
      }
    }
    let fit = @utils.logistic_fit(
      with_intercept_column(design),
      response,
      1.0,
      100,
      1.0e-8,
    )
    let beta = fit.beta
    let row : Array[Double] = []
    for i = 1; i < beta.length(); i = i + 1 {
      row.push(beta[i])
    }
    coefficients.push(row)
    intercepts.push(if beta.length() > 0 { beta[0] } else { 0.0 })
  }
  {
    coefficients: [],
    intercept: 0.0,
    classes,
    fitted: true,
    degree: model.degree,
    one_versus_rest: Some({ coefficients, intercepts, }),
    neighbours: None,
  }
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
  match self.neighbours {
    Some(neighbours) => return neighbours.predict_probabilities(x)
    None => ()
  }
  // A model of the polynomial features predicts with the expansion of the
  // features, the way the pipeline of the upstream expands them before its
  // logistic regression sees them.
  let design = if self.degree > 0 {
    polynomial_features(x, self.degree)
  } else {
    x
  }
  match self.one_versus_rest {
    Some(models) => {
      let out : Array[Array[Double]] = []
      for i = 0; i < design.nrows(); i = i + 1 {
        let row : Array[Double] = []
        let mut total = 0.0
        for k = 0; k < models.coefficients.length(); k = k + 1 {
          let mut value = models.intercepts[k]
          let row_coefficients = models.coefficients[k]
          for j = 0; j < row_coefficients.length(); j = j + 1 {
            if j < design.ncols() {
              value = value + row_coefficients[j] * design.get(i, j)
            }
          }
          let probability = @utils.sigmoid(value)
          row.push(probability)
          total = total + probability
        }
        if total > 0.0 {
          for k = 0; k < row.length(); k = k + 1 {
            row[k] = row[k] / total
          }
        }
        out.push(row)
      }
      out
    }
    None => {
      let out : Array[Array[Double]] = []
      for i = 0; i < design.nrows(); i = i + 1 {
        let mut value = self.intercept
        for j = 0; j < design.ncols(); j = j + 1 {
          if j < self.coefficients.length() {
            value = value + self.coefficients[j] * design.get(i, j)
          }
        }
        let positive = @utils.sigmoid(value)
        out.push([1.0 - positive, positive])
      }
      out
    }
  }
}

///|
/// The predicted class of every row of the design matrix.
pub fn ClassificationModel::predict(
  self : ClassificationModel,
  x : @utils.Matrix,
) -> Array[String] {
  let out : Array[String] = []
  for probabilities in self.predict_probabilities(x) {
    // The class of the row is the one of the largest probability.
    let mut best = 0
    for k = 1; k < probabilities.length(); k = k + 1 {
      if probabilities[k] > probabilities[best] {
        best = k
      }
    }
    out.push(self.classes[best])
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
  // The copy keeps the degree of the polynomial features, because it is a
  // hyper parameter of the model and not the result of a fit.
  {
    coefficients: [],
    intercept: 0.0,
    classes: [],
    fitted: false,
    degree: self.degree,
    one_versus_rest: None,
    neighbours: match self.neighbours {
      Some(neighbours) => Some(KnnClassifier::new(neighbours.k))
      None => None
    },
  }
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
/// The polynomial expansion of the features.
///
/// This is the port of `sklearn.preprocessing.PolynomialFeatures` with
/// `include_bias=False`, which the upstream builds its polynom regressor and
/// its polynom classifier with. The expansion holds every product of the
/// features of a total degree of one up to the given degree, and the order of
/// its columns is the order of the upstream: the products of the degree one
/// come first, then the ones of the degree two, and so on, and the products of
/// one degree are ordered by the indices of the features they multiply.
///
/// The expansion of two features of the degree two therefore holds the columns
/// `x0`, `x1`, `x0 * x0`, `x0 * x1` and `x1 * x1`, and the expansion of two
/// features of the degree three holds those five columns and the four products
/// of the degree three.
pub fn polynomial_features(x : @utils.Matrix, degree : Int32) -> @utils.Matrix {
  if degree < 1 {
    abort("the degree of a polynomial model has to be at least one")
  }
  let n = x.ncols()
  let combinations : Array[Array[Int32]] = []
  for d = 1; d <= degree; d = d + 1 {
    for combination in polynomial_combinations(n, d, 0) {
      combinations.push(combination)
    }
  }
  let out = @utils.Matrix::zeros(x.nrows(), combinations.length())
  for i = 0; i < x.nrows(); i = i + 1 {
    for c = 0; c < combinations.length(); c = c + 1 {
      let combination = combinations[c]
      let mut value = 1.0
      for index in combination {
        value = value * x.get(i, index)
      }
      out.set(i, c, value)
    }
  }
  out
}

///|
/// The combinations of `length` features of `n` features with a repetition, in
/// the order of the upstream.
///
/// The combinations are the ones of `itertools.combinations_with_replacement`,
/// which the upstream's transformer enumerates: the indices of a combination
/// are not decreasing, and the combinations of one length are ordered by their
/// indices.
fn polynomial_combinations(
  n : Int32,
  length : Int32,
  start : Int32,
) -> Array[Array[Int32]] {
  let out : Array[Array[Int32]] = []
  if length == 0 {
    let empty : Array[Int32] = []
    out.push(empty)
    return out
  }
  for i = start; i < n; i = i + 1 {
    for tail in polynomial_combinations(n, length - 1, i) {
      let combination : Array[Int32] = [i]
      for index in tail {
        combination.push(index)
      }
      out.push(combination)
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
/// The index of the label in the classes, or minus one when the label is not
/// one of them.
fn index_of_class(classes : Array[String], label : String) -> Int32 {
  for i in 0..<classes.length() {
    if classes[i] == label {
      return i
    }
  }
  -1
}

///|
/// The sorted distinct labels of a column of classes.
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
  {
    k: self.k,
    rows: x.copy(),
    targets: y.copy(),
    order: sorted_row_order(x),
    fitted: true,
  }
}

///|
/// The rows of a design matrix, sorted by their first column.
///
/// The rows are sorted by their first column, so that the neighbours of a row
/// are found with a walk over the sorted rows instead of a scan over all of
/// them.  The walk finds the same neighbours as the scan.
fn sorted_row_order(x : @utils.Matrix) -> Array[Int32] {
  let order : Array[Int32] = []
  for i in 0..<x.nrows() {
    order.push(i)
  }
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
  order
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
  let best_rows = knn_neighbour_rows(self.rows, self.order, self.k, query)
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
/// The rows that are the nearest neighbours of a row.
///
/// The neighbours are the rows with the smallest euclidean distance to the
/// row, and they are returned in the order of their distance.  The rows are
/// sorted by their first column, so the walk over the sorted rows stops as
/// soon as the rows that are left are further away than the neighbours that
/// were found already.  A tie is broken with the order of the rows, which is
/// the rule of a scan over the rows.
fn knn_neighbour_rows(
  rows : @utils.Matrix,
  order : Array[Int32],
  k : Int32,
  query : Array[Double],
) -> Array[Int32] {
  let n = order.length()
  let count = if k < n { k } else { n }
  // The distances of the neighbours that were found and the rows they belong
  // to, in the order of their distance.
  let best_distances : Array[Double] = []
  let best_rows : Array[Int32] = []
  // The position of the row in the sorted rows.
  let mut lo = 0
  let mut hi = n
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    if rows.get(order[mid], 0) < query[0] {
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
      let difference = query[0] - rows.get(order[left], 0)
      bound = difference * difference
    }
    if right < n {
      let difference = rows.get(order[right], 0) - query[0]
      let squared = difference * difference
      if squared < bound {
        bound = squared
      }
    }
    if best_distances.length() == count && bound > best_distances[count - 1] {
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
      let difference = query[0] - rows.get(order[left], 0)
      let right_difference = rows.get(order[right], 0) - query[0]
      difference <= right_difference
    }
    let row = if take_left {
      let visited = order[left]
      left = left - 1
      visited
    } else {
      let visited = order[right]
      right = right + 1
      visited
    }
    let distance = squared_distance(query, rows, row)
    // The neighbours are kept in the order of their distance.
    let mut position = best_distances.length()
    for i in 0..<best_distances.length() {
      if distance < best_distances[i] {
        position = i
        break
      }
    }
    if position < count {
      best_distances.insert(position, distance)
      best_rows.insert(position, row)
      if best_distances.length() > count {
        let _ = best_distances.pop()
        let _ = best_rows.pop()
      }
    }
  }
  best_rows
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
/// A classification model of the nearest neighbours of a row.
///
/// This is the port of `dowhy.gcm.ml.classification.create_knn_classifier`,
/// which wraps `sklearn.neighbors.KNeighborsClassifier` with its default
/// parameters: five neighbours and the uniform weights.  The neighbours of a
/// row are the rows of the training data with the smallest euclidean distance
/// to it, and the class of the row is the class of the majority of its
/// neighbours.
pub struct KnnClassifier {
  /// The number of the neighbours.
  k : Int32
  /// The rows of the training data.
  rows : @utils.Matrix
  /// The labels of the training data.
  labels : Array[String]
  /// The rows of the training data, sorted by their first column.
  order : Array[Int32]
  /// The classes of the model, in lexicographic order.
  classes : Array[String]
  /// Whether the model has been fitted.
  fitted : Bool
}

///|
/// An unfitted nearest neighbour classification model.
pub fn KnnClassifier::new(k : Int32) -> KnnClassifier {
  {
    k,
    rows: @utils.Matrix::zeros(0, 0),
    labels: [],
    order: [],
    classes: [],
    fitted: false,
  }
}

///|
/// Fit the model on the given labels.
///
/// The result is a new model; the model the fit is called on stays as it is.
/// The fit of `sklearn.neighbors.KNeighborsClassifier` keeps the training data
/// and computes nothing else.
pub fn KnnClassifier::fit(
  self : KnnClassifier,
  x : @utils.Matrix,
  y : Array[String],
) -> KnnClassifier {
  {
    k: self.k,
    rows: x.copy(),
    labels: y.copy(),
    order: sorted_row_order(x),
    classes: sorted_distinct_labels(y),
    fitted: true,
  }
}

///|
/// The probability of every class for every row of the design matrix.
///
/// The probability of a class is the share of the neighbours of the row that
/// belong to it, the way the uniform weights of the neighbours of scikit-learn
/// give every neighbour the same share of the vote.
pub fn KnnClassifier::predict_probabilities(
  self : KnnClassifier,
  x : @utils.Matrix,
) -> Array[Array[Double]] {
  if !self.fitted {
    abort("the classification model has not been fitted")
  }
  let out : Array[Array[Double]] = []
  for i in 0..<x.nrows() {
    out.push(self.probabilities_of_row(x.row(i)))
  }
  out
}

///|
/// The predicted class of every row of the design matrix.
pub fn KnnClassifier::predict(
  self : KnnClassifier,
  x : @utils.Matrix,
) -> Array[String] {
  let out : Array[String] = []
  for probabilities in self.predict_probabilities(x) {
    // The class of the row is the one of the largest probability.
    let mut best = 0
    for k = 1; k < probabilities.length(); k = k + 1 {
      if probabilities[k] > probabilities[best] {
        best = k
      }
    }
    out.push(self.classes[best])
  }
  out
}

///|
/// The probabilities of the classes for one row.
fn KnnClassifier::probabilities_of_row(
  self : KnnClassifier,
  query : Array[Double],
) -> Array[Double] {
  let counts : Array[Double] = []
  for _ in self.classes {
    counts.push(0.0)
  }
  let neighbours = knn_neighbour_rows(self.rows, self.order, self.k, query)
  for row in neighbours {
    let index = index_of_class(self.classes, self.labels[row])
    if index >= 0 {
      counts[index] = counts[index] + 1.0
    }
  }
  let total = neighbours.length().to_double()
  if total > 0.0 {
    for i in 0..<counts.length() {
      counts[i] = counts[i] / total
    }
  }
  counts
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
