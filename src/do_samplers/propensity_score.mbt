/// The propensity scores of the do samplers.
///
/// This is the port of `dowhy.utils.propensity_score`: the state propensity
/// score of the treatment and the three treatment models (binary, categorical
/// and continuous) that produce it.
///
/// The upstream code fits the models with `scikit-learn` and estimates the
/// conditional density of a continuous treatment with
/// `statsmodels.nonparametric.kernel_density.KDEMultivariateConditional`.
/// The port uses the logistic regression of the `utils` package for the
/// binary treatment, the one versus rest logistic regression of the upstream
/// code for the categorical treatment and a Gaussian conditional density for
/// the continuous treatment. Every deviation is documented where it occurs.

///|
/// The columns of the design of a propensity model.
///
/// The discrete covariates are binarised like `binarize_discrete` of the
/// upstream code does: every level but the largest one becomes a column of
/// its own, and the level that is left out is absorbed by the intercept.
priv struct Design {
  columns : Array[Array[Double]]
}

///|
/// The smallest propensity score the port uses.
///
/// The weight of a row is the inverse of its propensity score, so a score of
/// zero would make the weight infinite. The upstream code has the same
/// problem and lets the division produce an infinity; the port clips the
/// score instead.
const MINIMUM_PROPENSITY : Double = 1.0e-12

///|
/// The propensity score of the observed treatment state of every row.
///
/// This is the port of `state_propensity_score`: the density of the
/// treatment state given the covariates. The inverse of the score is the
/// weight the weighting sampler gives to the row.
///
/// The covariates must not contain a treatment; the upstream code raises an
/// error when they do.
pub fn state_propensity_score(
  data : @api.DataFrame,
  covariates : Array[String],
  treatments : Array[String],
  variable_types : Map[String, VariableType],
) -> Array[Double] {
  for covariate in covariates {
    if treatments.contains(covariate) {
      abort(
        "Can't control for causal states. Remove treatment from covariates.",
      )
    }
  }
  let log_propensities : Array[Array[Double]] = []
  for index = 0; index < treatments.length(); index = index + 1 {
    let treatment = treatments[index]
    // The upstream code conditions on the covariates and on the treatments
    // that follow this one.
    let rest = covariates.copy()
    for other = index + 1; other < treatments.length(); other = other + 1 {
      rest.push(treatments[other])
    }
    let scores = match variable_type_of(variable_types, treatment) {
      Binary => binary_treatment_model(data, rest, treatment, variable_types)
      Discrete =>
        categorical_treatment_model(data, rest, treatment, variable_types)
      Ordered =>
        categorical_treatment_model(data, rest, treatment, variable_types)
      Unordered =>
        categorical_treatment_model(data, rest, treatment, variable_types)
      Continuous =>
        continuous_treatment_model(data, rest, treatment, variable_types)
    }
    let logs : Array[Double] = []
    for score in scores {
      logs.push(@math.ln(score))
    }
    log_propensities.push(logs)
  }
  let scores : Array[Double] = []
  for row = 0; row < data.nrows(); row = row + 1 {
    let mut total = 0.0
    for logs in log_propensities {
      total = total + logs[row]
    }
    scores.push(@math.exp(total))
  }
  scores
}

///|
/// The propensity score of a binary treatment.
///
/// This is the port of `binary_treatment_model`: a logistic regression of the
/// treatment on the covariates, and the probability of the class the row
/// actually received.
fn binary_treatment_model(
  data : @api.DataFrame,
  covariates : Array[String],
  treatment : String,
  variable_types : Map[String, VariableType],
) -> Array[Double] {
  let design = build_design(data, covariates, variable_types)
  let matrix = design_matrix(design)
  let targets = binary_targets(data, treatment)
  let fit = @utils.logistic_fit(matrix, targets, 1.0, 100, 1.0e-4)
  let probabilities = @utils.logistic_predict(fit.beta, matrix)
  let scores : Array[Double] = []
  for row = 0; row < targets.length(); row = row + 1 {
    let probability = if targets[row] == 1.0 {
      probabilities[row]
    } else {
      1.0 - probabilities[row]
    }
    scores.push(clamp_probability(probability))
  }
  scores
}

///|
/// The propensity score of a categorical treatment.
///
/// This is the port of `categorical_treatment_model`: a one versus rest
/// logistic regression for every level of the treatment, and the probability
/// of the level the row received.
///
/// The fits use the IRLS of `utils.logistic_fit`, but the weighted normal
/// equations are solved directly instead of building the matrix of the
/// weights, which the port's implementation does in every step and which
/// grows with the square of the number of rows.
fn categorical_treatment_model(
  data : @api.DataFrame,
  covariates : Array[String],
  treatment : String,
  variable_types : Map[String, VariableType],
) -> Array[Double] {
  let design = build_design(data, covariates, variable_types)
  let matrix = design_matrix(design)
  let (codes, classes) = label_encode(data, treatment)
  let n = codes.length()
  // The probability of every level, for every row.
  let probabilities : Array[Array[Double]] = []
  for k = 0; k < classes; k = k + 1 {
    let targets : Array[Double] = []
    for row = 0; row < n; row = row + 1 {
      targets.push(if codes[row] == k { 1.0 } else { 0.0 })
    }
    let beta = binary_logistic_fit(matrix, targets, 1.0, 100, 1.0e-4)
    probabilities.push(@utils.logistic_predict(beta, matrix))
  }
  // The probabilities of the levels are normalised over the levels, like
  // the one versus rest probabilities of `scikit-learn` are.
  let scores : Array[Double] = []
  for row = 0; row < n; row = row + 1 {
    let mut total = 0.0
    for k = 0; k < classes; k = k + 1 {
      total = total + probabilities[k][row]
    }
    let probability = if total > 0.0 {
      probabilities[codes[row]][row] / total
    } else {
      1.0 / classes.to_double()
    }
    scores.push(clamp_probability(probability))
  }
  scores
}

///|
/// The coefficients of a binary logistic regression with an L2 penalty.
///
/// The objective is the one of `utils.logistic_fit`:
/// `sum_i log_loss(y_i, p_i) + 1 / (2 C) * ||w||²`, where the intercept is
/// not penalised. The fit is the same iteratively reweighted least squares
/// iteration, but the weighted normal equations are built and solved
/// directly; the port's implementation builds the matrix of the weights,
/// which costs the square of the number of rows in every step.
fn binary_logistic_fit(
  x : @utils.Matrix,
  y : Array[Double],
  c : Double,
  max_iter : Int32,
  tol : Double,
) -> Array[Double] {
  let n = x.nrows()
  let p = x.ncols()
  let lambda = 1.0 / c
  let beta : Array[Double] = []
  for j = 0; j < p; j = j + 1 {
    beta.push(0.0)
  }
  let mut iteration = 0
  while iteration < max_iter {
    iteration = iteration + 1
    // The working weights and the working response of the step.
    let eta = x.matvec(beta)
    let weights : Array[Double] = []
    let response : Array[Double] = []
    for i = 0; i < n; i = i + 1 {
      let mean = @utils.sigmoid(eta[i])
      let raw = mean * (1.0 - mean)
      let weight = if raw > 1.0e-10 { raw } else { 1.0e-10 }
      weights.push(weight)
      response.push(eta[i] + (y[i] - mean) / weight)
    }
    // The weighted normal equations of the step.
    let hessian = @utils.Matrix::zeros(p, p)
    let rhs : Array[Double] = []
    for j = 0; j < p; j = j + 1 {
      rhs.push(0.0)
    }
    for i = 0; i < n; i = i + 1 {
      let weight = weights[i]
      for a = 0; a < p; a = a + 1 {
        let value = x.get(i, a)
        rhs[a] = rhs[a] + value * weight * response[i]
        for b = 0; b < p; b = b + 1 {
          hessian.set(a, b, hessian.get(a, b) + value * weight * x.get(i, b))
        }
      }
    }
    // The penalty of the slopes; the intercept is not penalised.
    for j = 1; j < p; j = j + 1 {
      hessian.set(j, j, hessian.get(j, j) + lambda)
    }
    let new_beta = match @utils.mat_inverse(hessian) {
      Some(inverse) => inverse.matvec(rhs)
      None => @utils.lstsq(hessian, rhs)
    }
    let mut change = 0.0
    for j = 0; j < p; j = j + 1 {
      let delta = (new_beta[j] - beta[j]).abs()
      if delta > change {
        change = delta
      }
      beta[j] = new_beta[j]
    }
    if change < tol {
      break
    }
  }
  beta
}

///|
/// The propensity score of a continuous treatment.
///
/// The upstream code estimates the conditional density of the treatment with
/// `KDEMultivariateConditional`. The port has no conditional kernel density
/// estimator, so the density is modelled as a Gaussian around the least
/// squares fit of the treatment on the covariates, with the bandwidth of the
/// normal reference rule. That is the family the kernel estimator
/// approximates: a Gaussian kernel of the residuals of the fit.
fn continuous_treatment_model(
  data : @api.DataFrame,
  covariates : Array[String],
  treatment : String,
  variable_types : Map[String, VariableType],
) -> Array[Double] {
  let design = build_design(data, covariates, variable_types)
  let matrix = design_matrix(design)
  let values = data.numeric(treatment)
  let fit = @utils.ols_fit(matrix, values)
  let sigma = fit.sigma2.sqrt()
  // The bandwidth of the normal reference rule of Scott.
  let bandwidth = 1.06 * sigma * @math.pow(values.length().to_double(), -0.2)
  let variance = fit.sigma2 + bandwidth * bandwidth
  let scores : Array[Double] = []
  for row = 0; row < values.length(); row = row + 1 {
    let residual = values[row] - fit.fitted[row]
    scores.push(clamp_probability(normal_density(residual, variance)))
  }
  scores
}

///|
/// The density of the normal distribution with the given variance.
fn normal_density(value : Double, variance : Double) -> Double {
  if variance <= 0.0 {
    return 0.0
  }
  @math.exp(-value * value / (2.0 * variance)) /
  (2.0 * @math.PI * variance).sqrt()
}

///|
/// A propensity score that is neither zero nor infinite.
fn clamp_probability(probability : Double) -> Double {
  if probability < MINIMUM_PROPENSITY {
    MINIMUM_PROPENSITY
  } else if probability > 1.0 / MINIMUM_PROPENSITY {
    1.0 / MINIMUM_PROPENSITY
  } else {
    probability
  }
}

///|
/// The design of a propensity model.
///
/// The discrete covariates are binarised, the continuous ones are taken as
/// they are.
fn build_design(
  data : @api.DataFrame,
  covariates : Array[String],
  variable_types : Map[String, VariableType],
) -> Design {
  let columns : Array[Array[Double]] = []
  for covariate in covariates {
    if variable_type_of(variable_types, covariate).is_discrete() {
      let codes = discrete_codes(data, covariate)
      let levels = level_count(codes)
      for level = 0; level < levels - 1; level = level + 1 {
        let column : Array[Double] = []
        for row = 0; row < codes.length(); row = row + 1 {
          column.push(if codes[row] == level { 1.0 } else { 0.0 })
        }
        columns.push(column)
      }
    } else {
      columns.push(data.numeric(covariate))
    }
  }
  { columns, }
}

///|
/// The design matrix of a propensity model, with the intercept first.
fn design_matrix(design : Design) -> @utils.Matrix {
  let columns : Array[Array[Double]] = []
  let intercept : Array[Double] = []
  for row = 0; row < design_row_count(design); row = row + 1 {
    intercept.push(1.0)
  }
  columns.push(intercept)
  for column in design.columns {
    columns.push(column)
  }
  @utils.Matrix::from_columns(columns)
}

///|
/// The number of rows of a design.
fn design_row_count(design : Design) -> Int32 {
  if design.columns.length() == 0 {
    0
  } else {
    design.columns[0].length()
  }
}

///|
/// The treatment of every row, as a zero or a one.
fn binary_targets(data : @api.DataFrame, treatment : String) -> Array[Double] {
  let (codes, classes) = label_encode(data, treatment)
  if classes != 2 {
    abort(
      "The binary treatment model needs a treatment with exactly two levels",
    )
  }
  let targets : Array[Double] = []
  for code in codes {
    targets.push(code.to_double())
  }
  targets
}

///|
/// The label encoded values of a column and the number of its levels.
///
/// This is the port of `LabelEncoder`: the levels are sorted and every value
/// is replaced by the index of its level.
fn label_encode(data : @api.DataFrame, name : String) -> (Array[Int32], Int32) {
  match data.column(name) {
    Some(@api.Column::Numeric(values)) => {
      let sorted = values.copy()
      sorted.sort_by(fn(a, b) { @utils.compare_double(a, b) })
      let levels : Array[Double] = []
      for value in sorted {
        if levels.length() == 0 || levels[levels.length() - 1] != value {
          levels.push(value)
        }
      }
      let codes : Array[Int32] = []
      for value in values {
        codes.push(level_index(levels, value))
      }
      (codes, levels.length())
    }
    Some(@api.Column::Discrete(values)) => {
      let sorted = values.copy()
      sorted.sort_by(fn(a, b) { compare(a, b) })
      let levels : Array[String] = []
      for value in sorted {
        if levels.length() == 0 || levels[levels.length() - 1] != value {
          levels.push(value)
        }
      }
      let codes : Array[Int32] = []
      for value in values {
        codes.push(string_level_index(levels, value))
      }
      (codes, levels.length())
    }
    None => abort("column '" + name + "' not found")
  }
}

///|
/// The label encoded values of a column.
fn discrete_codes(data : @api.DataFrame, name : String) -> Array[Int32] {
  let (codes, _) = label_encode(data, name)
  codes
}

///|
/// The number of levels of a label encoded column.
fn level_count(codes : Array[Int32]) -> Int32 {
  let mut count = 0
  for code in codes {
    if code + 1 > count {
      count = code + 1
    }
  }
  count
}

///|
/// The index of a level in the sorted levels.
fn level_index(levels : Array[Double], value : Double) -> Int32 {
  let mut low = 0
  let mut high = levels.length() - 1
  while low < high {
    let middle = (low + high) / 2
    if levels[middle] < value {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low
}

///|
/// The index of a level in the sorted levels.
fn string_level_index(levels : Array[String], value : String) -> Int32 {
  let mut low = 0
  let mut high = levels.length() - 1
  while low < high {
    let middle = (low + high) / 2
    if compare(levels[middle], value) < 0 {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low
}
