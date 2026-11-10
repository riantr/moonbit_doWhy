///|
/// The statistics of the `gcm` package: the merging of p-values, the
/// permutation of the features and the F-test of two nested models.
///
/// This is the port of `dowhy.gcm.stats`.

///|
/// The kind of perturbation of the features of a marginal expectation.
///
/// This is the port of the `feature_perturbation` argument of the upstream
/// code, which is a string there and an enumeration here.
pub enum FeaturePerturbation {
  RandomizeColumnsIndependently
  RandomizeColumnsJointly
}

///|
/// The perturbation that permutes every feature on its own.
pub fn FeaturePerturbation::independently() -> FeaturePerturbation {
  RandomizeColumnsIndependently
}

///|
/// The perturbation that permutes all the features with one and the same
/// permutation of the rows.
pub fn FeaturePerturbation::jointly() -> FeaturePerturbation {
  RandomizeColumnsJointly
}

///|
/// The name of the perturbation, like the string of the upstream code.
pub fn FeaturePerturbation::name(self : FeaturePerturbation) -> String {
  match self {
    RandomizeColumnsIndependently => "randomize_columns_independently"
    RandomizeColumnsJointly => "randomize_columns_jointly"
  }
}

///|
/// A statistically sound method to merge multiple potentially dependent
/// p-values into one.
///
/// This is the port of `dowhy.gcm.stats.merge_p_values_average`, which follows
/// Theorem 5.3 (second equation, F_UA) of
///
/// M. Gasparini, R. Wang, and A. Ramdas, *Combining exchangeable p-values*,
/// arXiv 2404.03484, 2024
///
/// If `randomization` is false, the value of `u` is 1, which is the
/// deterministic default of the upstream code. If it is true, `u` is drawn
/// uniformly from `[0, 1)` with the given generator, which makes the result
/// non-deterministic and generally more powerful. The upstream code draws it
/// from the global generator of numpy.
pub fn merge_p_values_average(
  p_values : Array[Double],
  randomization : Bool,
  rng : @utils.Random,
) -> Double {
  if p_values.length() == 0 {
    abort("the given list of p-values is empty")
  }
  if p_values.length() == 1 {
    return p_values[0]
  }
  if all_are_nan(p_values) {
    return @utils.nan()
  }
  let u = if randomization { rng.next_double() } else { 1.0 }
  let sorted = sorted_p_values(p_values)
  let k = sorted.length()
  let mut result = 1.0
  for m = 1; m <= k; m = m + 1 {
    let ratio = k.to_double() * u / m.to_double()
    if ratio < 2.0 {
      // The twice the average rule: the average of the m smallest p-values,
      // weighted by the number of tests that are still to come.
      let candidate = 2.0 * mean_of_range(sorted, 0, m) / (2.0 - ratio)
      if candidate < result {
        result = candidate
      }
    }
  }
  if result < 1.0 {
    result
  } else {
    1.0
  }
}

///|
/// Applies a quantile based approach to merge multiple potentially dependent
/// p-values into one.
///
/// This is the port of `dowhy.gcm.stats.merge_p_values_quantile`, which follows
/// the approach of
///
/// Meinshausen, N., Meier, L. and Buehlmann, P., *p-values for high-dimensional
/// regression*, J. Amer. Statist. Assoc.104 1671-1681, 2009
///
/// An empty scaling array means that no scaling is applied, which is the
/// default of the upstream code. The p-values that are not a number are
/// dropped, together with their scaling.
///
/// The upstream code rejects the quantiles that are not on the interval
/// `(0, 1]`: the ones that are not positive are rejected by its own check and
/// the ones that are larger than one by the quantile function of numpy. The
/// port rejects all of them with one check.
pub fn merge_p_values_quantile(
  p_values : Array[Double],
  p_values_scaling : Array[Double],
  quantile : Double,
) -> Double {
  if !quantile_is_valid(quantile) {
    abort(
      "the given quantile is " +
      quantile.to_string() +
      ", but it needs to be on (0, 1]!",
    )
  }
  if p_values.length() == 0 {
    abort("the given list of p-values is empty")
  }
  if p_values_scaling.length() != 0 &&
    p_values_scaling.length() != p_values.length() {
    abort(
      "the p-value scaling array needs to have the same dimension as the given p-values",
    )
  }
  let scaled : Array[Double] = []
  for i = 0; i < p_values.length(); i = i + 1 {
    if @utils.is_nan(p_values[i]) {
      continue
    }
    let factor = if p_values_scaling.length() == 0 {
      1.0
    } else {
      p_values_scaling[i]
    }
    let value = p_values[i] * factor
    scaled.push(if value > 1.0 { 1.0 } else { value })
  }
  if scaled.length() == 0 {
    abort("the given list of p-values holds no value that is a number")
  }
  if scaled.length() == 1 {
    return scaled[0]
  }
  // The quantile is taken of the scaled values divided by the quantile.
  let divided : Array[Double] = []
  for value in scaled {
    divided.push(value / quantile)
  }
  let result = @utils.percentile(divided, quantile * 100.0)
  if result < 1.0 {
    result
  } else {
    1.0
  }
}

///|
/// Whether the quantile based merging of the p-values accepts the given
/// inputs.
///
/// The merging aborts when the list of p-values is empty, when the quantile is
/// not on the interval `(0, 1]` and when the scaling does not have the same
/// length as the list of p-values. MoonBit cannot catch an abort, so the
/// condition is a function of its own that the tests can check.
pub fn merge_p_values_quantile_is_valid(
  p_values_length : Int32,
  p_values_scaling_length : Int32,
  quantile : Double,
) -> Bool {
  p_values_length > 0 &&
  quantile_is_valid(quantile) &&
  (p_values_scaling_length == 0 || p_values_scaling_length == p_values_length)
}

///|
/// Merges p-values to represent the global null hypothesis that all the
/// hypotheses the p-values stand for are true.
///
/// This is the port of `dowhy.gcm.stats.merge_p_values_fdr`. The p-values are
/// first adjusted with the false discovery rate control of Benjamini and
/// Hochberg, like `statsmodels.stats.multitest.multipletests` with the method
/// `fdr_bh` does, and the smallest adjusted p-value is returned.
///
/// The upstream code takes the method of the false discovery rate control as
/// an argument. The port implements the default one, the Benjamini and
/// Hochberg method.
pub fn merge_p_values_fdr(p_values : Array[Double]) -> Double {
  if p_values.length() == 0 {
    abort("the given list of p-values is empty")
  }
  if all_are_nan(p_values) {
    return @utils.nan()
  }
  let sorted = sorted_p_values(p_values)
  let n = sorted.length()
  let adjusted : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    adjusted.push(sorted[i] * n.to_double() / (i + 1).to_double())
  }
  // The adjusted p-values have to grow with the rank, so the largest one is
  // kept and every smaller one is capped by it.
  let mut cap = adjusted[n - 1]
  for i = n - 2; i >= 0; i = i - 1 {
    if adjusted[i] > cap {
      adjusted[i] = cap
    } else {
      cap = adjusted[i]
    }
  }
  let result = adjusted[0]
  if result < 1.0 {
    result
  } else {
    1.0
  }
}

///|
/// A copy of the samples with the rows of the given columns permuted.
///
/// This is the port of `dowhy.gcm.stats.permute_features`. When the features
/// are randomized jointly, one permutation of the rows is applied to all the
/// given columns, which still represents an interventional distribution. When
/// they are randomized independently, every column gets a permutation of its
/// own. The columns that are not given stay as they are.
pub fn permute_features(
  feature_samples : @utils.Matrix,
  features_to_permute : Array[Int32],
  randomize_features_jointly : Bool,
  rng : @utils.Random,
) -> @utils.Matrix {
  let out = feature_samples.copy()
  let n = feature_samples.nrows()
  if randomize_features_jointly {
    // One permutation of the rows for all the columns.
    let order = random_permutation(rng, n)
    for column in features_to_permute {
      for i = 0; i < n; i = i + 1 {
        out.set(i, column, feature_samples.get(order[i], column))
      }
    }
  } else {
    // One permutation of the rows for every column.
    for column in features_to_permute {
      let order = random_permutation(rng, n)
      for i = 0; i < n; i = i + 1 {
        out.set(i, column, feature_samples.get(order[i], column))
      }
    }
  }
  out
}

///|
/// Estimates the marginal expectation of the samples of `baseline_samples` when
/// the features that are not part of `baseline_feature_indices` are randomized.
///
/// This is the port of `dowhy.gcm.stats.marginal_expectation`, which estimates
/// `y^i = E[Y | do(x^i_s)]`, where `x^i_s` is the i-th sample of the baseline
/// samples, `s` are the baseline features and the other features are drawn
/// from the samples of `feature_samples`.
///
/// The upstream code evaluates the prediction method in batches, which is an
/// optimisation only. The port evaluates the whole thing at once and returns
/// the same numbers. The `max_batch_size` of the upstream is therefore
/// accepted and ignored, like the one of the feature relevance.
///
/// The upstream code returns a one dimensional array when the results are
/// averaged and a three dimensional array when they are not. The port returns
/// a matrix in both cases: one row per baseline sample and one column per
/// prediction, so the averaged results have one column and the results that
/// are not averaged have one column per sample of the features.
pub fn marginal_expectation(
  prediction_method : (@utils.Matrix) -> Array[Double],
  feature_samples : @utils.Matrix,
  baseline_samples : @utils.Matrix,
  baseline_feature_indices : Array[Int32],
  return_averaged_results : Bool,
  feature_perturbation : FeaturePerturbation,
  rng : @utils.Random,
  max_batch_size~ : Int32 = -1,
) -> @utils.Matrix {
  marginal_expectation_matrix(
    fn(inputs : @utils.Matrix) -> @utils.Matrix {
      @utils.Matrix::from_columns([prediction_method(inputs)])
    },
    feature_samples,
    baseline_samples,
    baseline_feature_indices,
    return_averaged_results,
    feature_perturbation,
    rng,
    max_batch_size~,
  )
}

///|
/// The marginal expectation of a prediction method whose predictions hold one
/// column per class.
///
/// This is the port of `dowhy.gcm.stats.marginal_expectation` for a prediction
/// method that returns a matrix of predictions. The upstream evaluates the
/// prediction method on the same rows as the vector variant and averages the
/// predictions of every block of rows over their columns, so the result holds
/// one row per baseline sample and one column per class.
///
/// The result of the vector variant is the result of this one for a prediction
/// method with a single column, so the two agree.
pub fn marginal_expectation_matrix(
  prediction_method : (@utils.Matrix) -> @utils.Matrix,
  feature_samples : @utils.Matrix,
  baseline_samples : @utils.Matrix,
  baseline_feature_indices : Array[Int32],
  return_averaged_results : Bool,
  feature_perturbation : FeaturePerturbation,
  rng : @utils.Random,
  max_batch_size~ : Int32 = -1,
) -> @utils.Matrix {
  let _ = max_batch_size
  let n_features = feature_samples.nrows()
  let n_baseline = baseline_samples.nrows()
  let n_columns = feature_samples.ncols()
  // The features that are not part of the baseline are randomized.
  let features_to_randomize : Array[Int32] = []
  for j = 0; j < n_columns; j = j + 1 {
    if !baseline_feature_indices.contains(j) {
      features_to_randomize.push(j)
    }
  }
  let jointly = match feature_perturbation {
    RandomizeColumnsJointly => true
    RandomizeColumnsIndependently => false
  }
  let randomized = permute_features(
    feature_samples, features_to_randomize, jointly, rng,
  )
  // Every baseline sample gets a block of as many rows as there are feature
  // samples, in which the columns of the baseline features hold the values of
  // the baseline sample.
  let inputs = @utils.Matrix::zeros(n_baseline * n_features, n_columns)
  for i = 0; i < n_baseline; i = i + 1 {
    for j = 0; j < n_features; j = j + 1 {
      let row = i * n_features + j
      for c = 0; c < n_columns; c = c + 1 {
        inputs.set(row, c, randomized.get(j, c))
      }
      for index in baseline_feature_indices {
        inputs.set(row, index, baseline_samples.get(i, index))
      }
    }
  }
  let predictions = prediction_method(inputs)
  let n_predictions = predictions.ncols()
  if return_averaged_results {
    let out = @utils.Matrix::zeros(n_baseline, n_predictions)
    for i = 0; i < n_baseline; i = i + 1 {
      for c = 0; c < n_predictions; c = c + 1 {
        out.set(
          i,
          c,
          mean_of_column_range(
            predictions,
            i * n_features,
            (i + 1) * n_features,
            c,
          ),
        )
      }
    }
    out
  } else {
    let out = @utils.Matrix::zeros(n_baseline, n_features)
    for i = 0; i < n_baseline; i = i + 1 {
      for j = 0; j < n_features; j = j + 1 {
        out.set(i, j, predictions.get(i * n_features + j, 0))
      }
    }
    out
  }
}

///|
/// Estimates the p-value of the null hypothesis that a regression with less
/// parameters reaches the same error as a regression with more parameters.
///
/// This is the port of `dowhy.gcm.stats.estimate_ftest_pvalue`. The models are
/// fitted with the ordinary least squares of the `utils` package and the
/// p-value is the survival function of the F distribution.
///
/// The upstream code fits the models with `sklearn.linear_model.LinearRegression`,
/// which adds an intercept to the design matrix. The port does the same, by
/// putting a column of ones in front of the columns of the samples.
///
/// A model without any parameter is the matrix without any column, and the
/// error of such a model is the sum of the squared deviations of the test
/// target from the mean of the training target.
pub fn estimate_ftest_pvalue(
  x_training_a : @utils.Matrix,
  x_training_b : @utils.Matrix,
  y_training : Array[Double],
  x_test_a : @utils.Matrix,
  x_test_b : @utils.Matrix,
  y_test : Array[Double],
) -> Double {
  estimate_ftest_pvalue_of_targets(
    x_training_a,
    x_training_b,
    @utils.Matrix::from_columns([y_training]),
    x_test_a,
    x_test_b,
    @utils.Matrix::from_columns([y_test]),
  )
}

///|
/// Estimates the p-value of the null hypothesis that a regression with less
/// parameters reaches the same error as a regression with more parameters, for
/// a target with several columns.
///
/// This is the port of `dowhy.gcm.stats.estimate_ftest_pvalue` for a target
/// with more than one column, which is what a categorical target becomes when
/// it is one-hot encoded. The upstream fits the models with the
/// `LinearRegression` of scikit-learn, which fits every column of the target
/// on its own with the same design matrix, and it sums the squared errors of
/// every column; the port does the same.
///
/// The degrees of freedom of the test do not depend on the number of the
/// columns of the target, which is what the upstream computes as well.
pub fn estimate_ftest_pvalue_of_targets(
  x_training_a : @utils.Matrix,
  x_training_b : @utils.Matrix,
  y_training : @utils.Matrix,
  x_test_a : @utils.Matrix,
  x_test_b : @utils.Matrix,
  y_test : @utils.Matrix,
) -> Double {
  let parameters_a = x_training_a.ncols()
  let parameters_b = x_training_b.ncols()
  if parameters_a <= parameters_b {
    abort(
      "the data X_training_a should have more dimensions (model parameters) than the data X_training_b!",
    )
  }
  let mut ssr_a = 0.0
  for k = 0; k < y_training.ncols(); k = k + 1 {
    let (beta_a, intercept_a) = centered_ols_fit(
      x_training_a,
      y_training.col(k),
    )
    let predictions_a = predictions_of(x_test_a, beta_a, intercept_a)
    for i = 0; i < y_test.nrows(); i = i + 1 {
      let difference = y_test.get(i, k) - predictions_a[i]
      ssr_a = ssr_a + difference * difference
    }
  }
  let mut ssr_b = 0.0
  if parameters_b > 0 {
    for k = 0; k < y_training.ncols(); k = k + 1 {
      let (beta_b, intercept_b) = centered_ols_fit(
        x_training_b,
        y_training.col(k),
      )
      let predictions_b = predictions_of(x_test_b, beta_b, intercept_b)
      for i = 0; i < y_test.nrows(); i = i + 1 {
        let difference = y_test.get(i, k) - predictions_b[i]
        ssr_b = ssr_b + difference * difference
      }
    }
  } else {
    // The model without any parameter is the mean of the training target.
    for k = 0; k < y_training.ncols(); k = k + 1 {
      let mean_target = @utils.mean(y_training.col(k))
      for i = 0; i < y_test.nrows(); i = i + 1 {
        let difference = y_test.get(i, k) - mean_target
        ssr_b = ssr_b + difference * difference
      }
    }
  }
  let dof_diff_1 = x_test_a.ncols() - parameters_b
  let dof_diff_2 = x_test_a.nrows() - x_test_a.ncols() - 1
  let mut f_statistic = (ssr_b - ssr_a) /
    dof_diff_1.to_double() *
    dof_diff_2.to_double()
  // The residual sums of squares that are below the machine epsilon are set to
  // zero, so that the division below does not blow up.
  let residual_a = if ssr_a < EPS { 0.0 } else { ssr_a }
  let residual_b = if ssr_b < EPS { 0.0 } else { ssr_b }
  if residual_a == 0.0 && residual_b == 0.0 {
    f_statistic = 0.0
  } else if residual_a != 0.0 {
    f_statistic = f_statistic / residual_a
  }
  @utils.f_sf(f_statistic, dof_diff_1.to_double(), dof_diff_2.to_double())
}

///|
/// The fit of a linear model with an intercept.
///
/// This is the fit of `sklearn.linear_model.LinearRegression`, which centres
/// the features and the target before the least squares fit and computes the
/// intercept from the offsets. The centring matters when the design matrix is
/// ill-conditioned, which is the case for the kernel features of the
/// regression based independence test: without it the fit of the port is off by
/// more than the difference between the models of the test, and the test finds
/// no dependence where the upstream finds one.
///
/// The result is the coefficient of every feature, without the intercept, and
/// the intercept of the model.
fn centered_ols_fit(
  x : @utils.Matrix,
  y : Array[Double],
) -> (Array[Double], Double) {
  let n = x.nrows()
  let p = x.ncols()
  if p == 0 {
    return ([], @utils.mean(y))
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
  (coefficients, intercept)
}

///|
/// The predictions of the given samples under a linear model with an
/// intercept.
fn predictions_of(
  x : @utils.Matrix,
  coefficients : Array[Double],
  intercept : Double,
) -> Array[Double] {
  let out : Array[Double] = []
  for i = 0; i < x.nrows(); i = i + 1 {
    let mut value = intercept
    for j = 0; j < x.ncols(); j = j + 1 {
      if j < coefficients.length() {
        value = value + coefficients[j] * x.get(i, j)
      }
    }
    out.push(value)
  }
  out
}

///|
/// Whether all the values of the array are "not a number".
fn all_are_nan(values : Array[Double]) -> Bool {
  for value in values {
    if !@utils.is_nan(value) {
      return false
    }
  }
  true
}

///|
/// The p-values that are not a number, sorted in ascending order.
fn sorted_p_values(p_values : Array[Double]) -> Array[Double] {
  let kept : Array[Double] = []
  for value in p_values {
    if !@utils.is_nan(value) {
      kept.push(value)
    }
  }
  kept.sort_by(fn(a, b) { @utils.compare_double(a, b) })
  kept
}

///|
/// The mean of the values of a column of the matrix between `start` and `end`.
fn mean_of_column_range(
  values : @utils.Matrix,
  start : Int32,
  end : Int32,
  column : Int32,
) -> Double {
  let mut sum = 0.0
  for i = start; i < end; i = i + 1 {
    sum = sum + values.get(i, column)
  }
  sum / (end - start).to_double()
}

///|
/// The mean of the values of the array between `start` and `end`.
fn mean_of_range(values : Array[Double], start : Int32, end : Int32) -> Double {
  let mut sum = 0.0
  for i = start; i < end; i = i + 1 {
    sum = sum + values[i]
  }
  sum / (end - start).to_double()
}

///|
/// Whether the quantile is on the interval `(0, 1]`.
fn quantile_is_valid(quantile : Double) -> Bool {
  quantile > 0.0 && quantile <= 1.0
}
