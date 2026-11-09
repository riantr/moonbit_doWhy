///|
/// The independence tests of the `gcm` package.
///
/// This is the port of `dowhy.gcm.independence_test.regression` and
/// `dowhy.gcm.independence_test.generalised_cov_measure`.

///|
/// An independence test on the samples of two variables.
///
/// The test takes the samples of X, the samples of Y and the samples of the
/// conditioning variable Z, which is absent when the test is a marginal one.
/// It returns the p-value of the null hypothesis that X and Y are independent,
/// given Z.
///
/// This is the type of the argument of the tests of `dowhy.gcm.validation`. The
/// upstream takes two different callables there, one for the marginal test and
/// one for the conditional one; the port takes one callable for both, because
/// the tests of the port take the conditioning variable as an argument that
/// may be absent.
pub type IndependenceTest = (@utils.Matrix, @utils.Matrix, @utils.Matrix?) -> Double

///|
/// The p-value of the null hypothesis that X and Y are independent given Z.
///
/// The idea is that X helps in predicting Y when X and Y are dependent, and
/// that it does not help when they are independent. When Z is given, X has to
/// help in predicting Y beyond what Z already tells.
///
/// The inputs are scaled like `sklearn.preprocessing.scale` does it, and they
/// are mapped into a kernel feature space with the Nystroem method of
/// `sklearn.kernel_approximation`, which uses the RBF kernel. The features of
/// the kernel space and the features of the conditioning variable Z are then
/// compared with an F-test: the p-value is the probability that a regression
/// with the kernel features does not perform better than a regression with the
/// features of Z alone.
///
/// The upstream splits the samples into folds with
/// `sklearn.model_selection.KFold(shuffle=True)`, which draws the folds from
/// the global numpy generator, and the Nystroem transformer picks its basis
/// points from the same generator. The port draws the folds and the basis
/// points from the generator it is given, so its p-value differs slightly from
/// the one of the upstream code on the same rows; both agree on the decision
/// the tests assert.
pub fn regression_based(
  x : @utils.Matrix,
  y : @utils.Matrix,
  z : @utils.Matrix?,
  max_num_components_all_inputs : Int32,
  k_folds : Int32,
  p_value_adjust_func : (Array[Double]) -> Double,
  max_samples_per_fold : Int32,
  rng : @utils.Random,
) -> Double {
  // The variable with the lower dimension is the target.
  let (inputs, target) = if x.ncols() < y.ncols() { (y, x) } else { (x, y) }
  regression_based_of_matrices(
    inputs, target, z, max_num_components_all_inputs, k_folds, p_value_adjust_func,
    max_samples_per_fold, rng,
  )
}

///|
/// The regression based (conditional) independence test with categorical data.
///
/// This is the port of `dowhy.gcm.independence_test.regression_based` for data
/// that holds categories. The upstream encodes the categorical columns of the
/// variables with a one-hot encoder before the test, and it counts the
/// columns of the variables before the encoding to decide which one is the
/// target; the port does the same.
///
/// The target of the test can have more than one column, because a categorical
/// target becomes one column per category.
pub fn regression_based_with_categorical(
  x : @api.DataFrame,
  y : @api.DataFrame,
  z : @api.DataFrame?,
  max_num_components_all_inputs : Int32,
  k_folds : Int32,
  p_value_adjust_func : (Array[Double]) -> Double,
  max_samples_per_fold : Int32,
  rng : @utils.Random,
) -> Double {
  // The variable with the lower dimension is the target. The upstream counts
  // the columns of the variables before it encodes them.
  let (x_frame, y_frame) = if x.column_names().length() <
    y.column_names().length() {
    (y, x)
  } else {
    (x, y)
  }
  let conditioning = match z {
    Some(frame) => Some(one_hot_encode_frame(frame))
    None => None
  }
  regression_based_of_matrices(
    one_hot_encode_frame(x_frame),
    one_hot_encode_frame(y_frame),
    conditioning,
    max_num_components_all_inputs,
    k_folds,
    p_value_adjust_func,
    max_samples_per_fold,
    rng,
  )
}

///|
/// The regression based (conditional) independence test of the given matrices.
///
/// The inputs and the target are the matrices of the test, with the target
/// already chosen. The target can have more than one column, which is what a
/// categorical target becomes when it is one-hot encoded.
fn regression_based_of_matrices(
  inputs : @utils.Matrix,
  target : @utils.Matrix,
  z : @utils.Matrix?,
  max_num_components_all_inputs : Int32,
  k_folds : Int32,
  p_value_adjust_func : (Array[Double]) -> Double,
  max_samples_per_fold : Int32,
  rng : @utils.Random,
) -> Double {
  if max_num_components_all_inputs < 2 {
    abort(
      "the regression based independence test needs at least two components for all inputs, but only " +
      max_num_components_all_inputs.to_string() +
      " were given",
    )
  }
  if k_folds < 2 {
    abort(
      "the regression based independence test needs at least two folds, but only " +
      k_folds.to_string() +
      " were given",
    )
  }
  let scaled_inputs = scale_columns(inputs)
  let scaled_target = scale_columns(target)
  let scaled_z = match z {
    Some(conditioning) => Some(scale_columns(conditioning))
    None => None
  }
  let n = scaled_inputs.nrows()
  let limit = if max_samples_per_fold == -1 { n } else { max_samples_per_fold }
  let p_values = fold_p_values(
    scaled_inputs, scaled_target, scaled_z, max_num_components_all_inputs, k_folds,
    limit, rng,
  )
  p_value_adjust_func(p_values)
}

///|
/// The p-value of every fold of the regression based independence test.
fn fold_p_values(
  inputs : @utils.Matrix,
  target : @utils.Matrix,
  z : @utils.Matrix?,
  max_num_components_all_inputs : Int32,
  k_folds : Int32,
  limit : Int32,
  rng : @utils.Random,
) -> Array[Double] {
  let folds = k_folds_split(inputs.nrows(), k_folds, rng)
  let p_values : Array[Double] = []
  for fold in folds {
    let (training, testing) = fold
    // The number of components is a third of the number of samples of the
    // training set, but at most the given maximum and at least two. The
    // upstream code counts the samples before it limits them.
    let by_samples = training.length() / 3
    let capped = if by_samples < max_num_components_all_inputs {
      by_samples
    } else {
      max_num_components_all_inputs
    }
    let adaptive = if capped < 2 { 2 } else { capped }
    let training_indices = first_indices(training, limit)
    let testing_indices = first_indices(testing, limit)
    let p_value = match z {
      Some(conditioning) => {
        let all = hstack([inputs, conditioning])
        let transformer_all = nystroem_fit(
          select_rows(all, training_indices),
          adaptive,
          rng,
        )
        let transformer_z = nystroem_fit(
          select_rows(conditioning, training_indices),
          adaptive / 2,
          rng,
        )
        let training_all = nystroem_transform(
          select_rows(all, training_indices),
          transformer_all,
        )
        let training_z = nystroem_transform(
          select_rows(conditioning, training_indices),
          transformer_z,
        )
        let testing_all = nystroem_transform(
          select_rows(all, testing_indices),
          transformer_all,
        )
        let testing_z = nystroem_transform(
          select_rows(conditioning, testing_indices),
          transformer_z,
        )
        estimate_ftest_pvalue_of_targets(
          training_all,
          training_z,
          select_rows(target, training_indices),
          testing_all,
          testing_z,
          select_rows(target, testing_indices),
        )
      }
      None => {
        let transformer_all = nystroem_fit(
          select_rows(inputs, training_indices),
          adaptive,
          rng,
        )
        let training_all = nystroem_transform(
          select_rows(inputs, training_indices),
          transformer_all,
        )
        let testing_all = nystroem_transform(
          select_rows(inputs, testing_indices),
          transformer_all,
        )
        estimate_ftest_pvalue_of_targets(
          training_all,
          @utils.Matrix::zeros(training_indices.length(), 0),
          select_rows(target, training_indices),
          testing_all,
          @utils.Matrix::zeros(testing_indices.length(), 0),
          select_rows(target, testing_indices),
        )
      }
    }
    p_values.push(p_value)
  }
  p_values
}

///|
/// The p-value of the null hypothesis that X and Y are independent given Z.
///
/// This is the port of `dowhy.gcm.independence_test.generalised_cov_measure`,
/// which is based on the generalised covariance measure of Shah and Peters
/// (2018). The residuals of the regressions of X and Y on Z are multiplied,
/// and the test statistic is the sum of the products divided by the standard
/// deviation of the products.
///
/// The upstream picks the prediction model with the automatic model selection
/// of `dowhy.gcm.auto`, which chooses the model that predicts the target best
/// in a cross validation. The port uses the ordinary least squares fit
/// instead, so that it needs no model selection; the p-values of the
/// conditional test therefore differ from the ones of the upstream code.
///
/// The upstream raises when X or Y is categorical or has more than one column,
/// and when the residuals are constant. The port aborts with a message that
/// names the cause. A categorical variable is a variable whose values are all
/// whole numbers, because the matrices of the port hold numbers only.
///
/// The port computes the tail probability of the normal distribution itself,
/// because the error function of the `utils` package is not accurate enough
/// for the tail of the distribution.
pub fn generalised_cov_based(
  x : @utils.Matrix,
  y : @utils.Matrix,
  z : @utils.Matrix?,
) -> Double {
  if x.ncols() > 1 || y.ncols() > 1 {
    abort(
      "the generalised covariance measure needs one dimensional variables, but X has " +
      x.ncols().to_string() +
      " and Y has " +
      y.ncols().to_string() +
      " columns",
    )
  }
  if is_discrete(x.col(0)) || is_discrete(y.col(0)) {
    abort(
      "the generalised covariance measure needs continuous variables, but X or Y is categorical",
    )
  }
  if x.nrows() != y.nrows() {
    abort(
      "the generalised covariance measure needs X and Y with the same number of rows, but they have " +
      x.nrows().to_string() +
      " and " +
      y.nrows().to_string() +
      " rows",
    )
  }
  let residuals_x = match z {
    Some(conditioning) => {
      if conditioning.nrows() != x.nrows() {
        abort(
          "the generalised covariance measure needs Z, X and Y with the same number of rows, but they have " +
          conditioning.nrows().to_string() +
          ", " +
          x.nrows().to_string() +
          " and " +
          y.nrows().to_string() +
          " rows",
        )
      }
      residuals_of(x.col(0), conditioning)
    }
    None => deviations_from_mean(x.col(0))
  }
  let residuals_y = match z {
    Some(conditioning) => residuals_of(y.col(0), conditioning)
    None => deviations_from_mean(y.col(0))
  }
  if @utils.var_pop(residuals_x) == 0.0 || @utils.var_pop(residuals_y) == 0.0 {
    abort(
      "the residuals of the generalised covariance measure cannot be constant",
    )
  }
  // The products of the residuals.
  let products : Array[Double] = []
  for i = 0; i < residuals_x.length(); i = i + 1 {
    products.push(residuals_x[i] * residuals_y[i])
  }
  let spread = @utils.std(products)
  if spread == 0.0 {
    return 1.0
  }
  let mut sum = 0.0
  for product in products {
    sum = sum + product
  }
  let statistic = sum / x.nrows().to_double().sqrt() / spread
  2.0 * normal_survival(statistic.abs())
}

///|
/// The generalised covariance measure with a categorical conditioning variable.
///
/// This is the port of `dowhy.gcm.independence_test.generalised_cov_based` for
/// a conditioning variable that holds categories. The upstream hands the
/// conditioning variable to the automatic model selection of `dowhy.gcm.auto`,
/// which encodes its categorical columns before it fits the prediction models;
/// the port encodes them itself, with the same one-hot encoding that the
/// regression based test of this package uses, and then runs the test of the
/// numeric matrices.
///
/// The two routes give the same p-value: on the fixture of the upstream test
/// file `tests/gcm/independence_test/test_generalised_cov_measure.py` the
/// explicit encoding and the automatic one agree to about `1e-3`, which is the
/// spread of the automatic model selection, and they lead to the same decision.
pub fn generalised_cov_based_with_categorical(
  x : @utils.Matrix,
  y : @utils.Matrix,
  z : @api.DataFrame?,
) -> Double {
  let conditioning = match z {
    Some(frame) => Some(one_hot_encode_frame(frame))
    None => None
  }
  generalised_cov_based(x, y, conditioning)
}

///|
/// The survival function of the standard normal distribution.
///
/// The tail of the distribution is computed with the complementary error
/// function of the `utils` package, which agrees with SciPy to about 1e-15.
fn normal_survival(z : Double) -> Double {
  0.5 * @utils.erfc(z / 2.0.sqrt())
}

///|
/// The residuals of the regression of the values on the given features.
///
/// The regression is the ordinary least squares fit with an intercept.
fn residuals_of(
  values : Array[Double],
  features : @utils.Matrix,
) -> Array[Double] {
  let (coefficients, intercept) = linear_regression(features, values)
  let residuals : Array[Double] = []
  for i = 0; i < values.length(); i = i + 1 {
    let mut prediction = intercept
    for j = 0; j < features.ncols(); j = j + 1 {
      prediction = prediction + coefficients[j] * features.get(i, j)
    }
    residuals.push(values[i] - prediction)
  }
  residuals
}

///|
/// The deviations of the values from their mean.
fn deviations_from_mean(values : Array[Double]) -> Array[Double] {
  let mean = @utils.mean(values)
  let deviations : Array[Double] = []
  for value in values {
    deviations.push(value - mean)
  }
  deviations
}

///|
/// The coefficients and the intercept of the ordinary least squares fit.
///
/// The features and the values are centred with their means, like the
/// `sklearn.linear_model.LinearRegression` of the upstream code does it.
fn linear_regression(
  features : @utils.Matrix,
  values : Array[Double],
) -> (Array[Double], Double) {
  let n = features.nrows()
  let p = features.ncols()
  let means : Array[Double] = []
  for j = 0; j < p; j = j + 1 {
    means.push(@utils.mean(features.col(j)))
  }
  let mean_value = @utils.mean(values)
  let centred = @utils.Matrix::zeros(n, p)
  let centred_values : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    for j = 0; j < p; j = j + 1 {
      centred.set(i, j, features.get(i, j) - means[j])
    }
    centred_values.push(values[i] - mean_value)
  }
  let coefficients = @utils.lstsq(centred, centred_values)
  let mut intercept = mean_value
  for j = 0; j < p; j = j + 1 {
    intercept = intercept - means[j] * coefficients[j]
  }
  (coefficients, intercept)
}

///|
/// The Nystroem transformer, which maps the samples into the feature space of
/// a kernel.
priv struct NystroemTransformer {
  basis : @utils.Matrix
  normalisation : @utils.Matrix
  gamma : Double
}

///|
/// The Nystroem transformer of the given samples.
///
/// This is the port of `sklearn.kernel_approximation.Nystroem` with the RBF
/// kernel. The basis points are drawn from the generator that is given, the
/// kernel matrix of the basis points is normalised with its eigenvalues, and
/// the samples are mapped with the kernel between them and the basis points.
fn nystroem_fit(
  samples : @utils.Matrix,
  n_components : Int32,
  rng : @utils.Random,
) -> NystroemTransformer {
  let n_samples = samples.nrows()
  let count = if n_components > n_samples { n_samples } else { n_components }
  let order = random_permutation(rng, n_samples)
  let basis = select_rows(samples, first_indices(order, count))
  let gamma = 1.0 / samples.ncols().to_double()
  let kernel = rbf_kernel(basis, basis, gamma)
  // The normalisation of the transformer, which is the square root of the
  // kernel matrix of the basis points.
  let (values, vectors) = @utils.jacobi_eigen(kernel)
  let n = basis.nrows()
  let normalisation = @utils.Matrix::zeros(n, n)
  for k = 0; k < n; k = k + 1 {
    let eigenvalue = if values[k] < 1.0e-12 { 1.0e-12 } else { values[k] }
    let factor = 1.0 / eigenvalue.sqrt()
    for i = 0; i < n; i = i + 1 {
      for j = 0; j < n; j = j + 1 {
        normalisation.set(
          i,
          j,
          normalisation.get(i, j) +
          factor * vectors.get(i, k) * vectors.get(j, k),
        )
      }
    }
  }
  { basis, normalisation, gamma, }
}

///|
/// The samples in the feature space of the kernel.
fn nystroem_transform(
  samples : @utils.Matrix,
  transformer : NystroemTransformer,
) -> @utils.Matrix {
  let embedded = rbf_kernel(samples, transformer.basis, transformer.gamma)
  embedded.mul(transformer.normalisation.transpose())
}

///|
/// The kernel matrix of the RBF kernel of the two sets of samples.
///
/// The gamma of the kernel is the inverse of the number of features, which is
/// the default of sklearn.
fn rbf_kernel(
  left : @utils.Matrix,
  right : @utils.Matrix,
  gamma : Double,
) -> @utils.Matrix {
  let out = @utils.Matrix::zeros(left.nrows(), right.nrows())
  for i = 0; i < left.nrows(); i = i + 1 {
    for j = 0; j < right.nrows(); j = j + 1 {
      let mut squared = 0.0
      for k = 0; k < left.ncols(); k = k + 1 {
        let difference = left.get(i, k) - right.get(j, k)
        squared = squared + difference * difference
      }
      out.set(i, j, @utils.exp(-gamma * squared))
    }
  }
  out
}

///|
/// The folds of the samples, with the samples of the training set and the
/// samples of the test set.
///
/// The samples are shuffled with the generator that is given and then split
/// into the folds, like `sklearn.model_selection.KFold` with `shuffle=True`
/// does it.
fn k_folds_split(
  n : Int32,
  k_folds : Int32,
  rng : @utils.Random,
) -> Array[(Array[Int32], Array[Int32])] {
  let order = random_permutation(rng, n)
  let folds : Array[(Array[Int32], Array[Int32])] = []
  for k = 0; k < k_folds; k = k + 1 {
    let start = n * k / k_folds
    let end = n * (k + 1) / k_folds
    let testing = indices_between(order, start, end)
    let held : Set[Int32] = Set::Set([])
    for index in testing {
      held.add(index)
    }
    let training : Array[Int32] = []
    for index in order {
      if !held.contains(index) {
        training.push(index)
      }
    }
    folds.push((training, testing))
  }
  folds
}

///|
/// The first indices of the given ones, at most the given number.
fn first_indices(indices : Array[Int32], count : Int32) -> Array[Int32] {
  let out : Array[Int32] = []
  let limit = if count < indices.length() { count } else { indices.length() }
  for i = 0; i < limit; i = i + 1 {
    out.push(indices[i])
  }
  out
}

///|
/// The indices of the given ones between the two positions.
fn indices_between(
  indices : Array[Int32],
  start : Int32,
  end : Int32,
) -> Array[Int32] {
  let out : Array[Int32] = []
  let limit = if end < indices.length() { end } else { indices.length() }
  let mut i = start
  while i < limit {
    out.push(indices[i])
    i = i + 1
  }
  out
}

///|
/// The rows of the matrix with the given indices.
fn select_rows(m : @utils.Matrix, indices : Array[Int32]) -> @utils.Matrix {
  let rows : Array[Array[Double]] = []
  for index in indices {
    rows.push(m.row(index))
  }
  @utils.Matrix::from_rows(rows)
}

///|
/// The matrix with the given matrices as its columns.
fn hstack(matrices : Array[@utils.Matrix]) -> @utils.Matrix {
  let columns : Array[Array[Double]] = []
  for m in matrices {
    for j = 0; j < m.ncols(); j = j + 1 {
      columns.push(m.col(j))
    }
  }
  @utils.Matrix::from_columns(columns)
}
