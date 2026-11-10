///|
/// The default strength of the confounder on the treatment or on the outcome.
///
/// This is the port of `_infer_default_kappa_t` and `_infer_default_kappa_y` of
/// `dowhy.causal_refuters.add_unobserved_common_cause`, which infer the
/// strength of the simulated confounder from the observed common causes when
/// the caller does not give one.
///
/// The common causes are the adjustment set of the estimand. They are one-hot
/// encoded with the first category of every discrete column dropped and they
/// are standardised, the way the upstream does it.
///
/// The strength of the confounder is then
///
/// * the share of the predictions of a logistic regression of the column on the
///   common causes that flip when one common cause is set to zero, for the
///   `binary_flip` effect,
/// * the correlation of every common cause with the column, scaled with the
///   standard deviation of the column, for the `linear` effect.
///
/// The range of the strengths is scaled with the fraction of the strength the
/// caller gives, and the function returns ten values of it, the way the
/// upstream does.
///
/// The upstream reads the standard deviation of the column with `np.std(t)[0]`,
/// and the standard deviation of a column is a number and not an array, so its
/// `linear` branch raises an `IndexError` on the numpy of today. The port
/// computes the number that branch means to compute, the correlation of every
/// common cause with the column scaled with its standard deviation.
///
/// The `binary_flip` effect of the upstream fits a classifier on the column, so
/// the column has to be binary. The upstream fits a multinomial model for a
/// column with more levels, and the share of the flips is then the distance
/// between the classes rather than a share, so the port refuses such a column.
/// A column with one level is refused by the solver of the upstream, and the
/// port refuses it too.

///|
/// The default strength of the confounder on the treatment.
///
/// This is the port of `_infer_default_kappa_t` of the upstream.
pub fn infer_default_kappa_t(
  data : @api.DataFrame,
  estimand : @identifiers.IdentifiedEstimand,
  treatment_name : String,
  effect_on_t : ConfoundersEffectOnT,
  frac_strength_treatment : Double,
  len_kappa_t : Int32,
) -> Array[Double] {
  let causes = kappa_common_causes(data, estimand)
  let treatment = data.numeric(treatment_name)
  match effect_on_t {
    BinaryFlip =>
      kappa_from_flips(causes, treatment, frac_strength_treatment, len_kappa_t)
    Linear =>
      kappa_from_correlations(
        causes, treatment, frac_strength_treatment, len_kappa_t,
      )
  }
}

///|
/// The default strength of the confounder on the outcome.
///
/// This is the port of `_infer_default_kappa_y` of the upstream.
pub fn infer_default_kappa_y(
  data : @api.DataFrame,
  estimand : @identifiers.IdentifiedEstimand,
  outcome_name : String,
  effect_on_y : ConfoundersEffectOnY,
  frac_strength_outcome : Double,
  len_kappa_y : Int32,
) -> Array[Double] {
  let causes = kappa_common_causes(data, estimand)
  let outcome = data.numeric(outcome_name)
  match effect_on_y {
    BinaryFlip =>
      kappa_from_flips(causes, outcome, frac_strength_outcome, len_kappa_y)
    Linear =>
      kappa_from_correlations(
        causes, outcome, frac_strength_outcome, len_kappa_y,
      )
  }
}

///|
/// The observed common causes of the estimand, encoded and standardised.
///
/// This is the port of `preprocess_observed_common_causes` of the upstream. The
/// discrete columns are one-hot encoded with the first category of every column
/// dropped, and every column is standardised with the mean and the standard
/// deviation of its rows.
fn kappa_common_causes(
  data : @api.DataFrame,
  estimand : @identifiers.IdentifiedEstimand,
) -> @utils.Matrix {
  let names = estimand.get_adjustment_set(estimand.identifier_method())
  if names.length() == 0 {
    abort(
      "there needs to be at least one common cause to compute the default " +
      "strength of the confounder",
    )
  }
  let encoders = @api.Encoders::new(true)
  let encoded = encoders.encode(data.select(names), "observed_common_causes")
  let columns = encoded.numeric_column_names()
  let out = @utils.Matrix::zeros(encoded.nrows(), columns.length())
  for j = 0; j < columns.length(); j = j + 1 {
    let column = encoded.numeric(columns[j])
    let mean = @utils.mean(column)
    let sd = @utils.variance(column, 0).sqrt()
    for i = 0; i < column.length(); i = i + 1 {
      out.set(i, j, if sd == 0.0 { 0.0 } else { (column[i] - mean) / sd })
    }
  }
  out
}

///|
/// The strengths of the confounder of the `binary_flip` effect.
///
/// This is the port of the `binary_flip` branch of the upstream. A logistic
/// regression of the column on the common causes is fitted, and the strength of
/// a common cause is the share of the predictions that flip when the common
/// cause is set to zero.
fn kappa_from_flips(
  causes : @utils.Matrix,
  column : Array[Double],
  frac_strength : Double,
  len_kappa : Int32,
) -> Array[Double] {
  let response : Array[Double] = []
  let mut zeros = 0
  let mut ones = 0
  for value in column {
    if value == 0.0 {
      response.push(0.0)
      zeros = zeros + 1
    } else if value == 1.0 {
      response.push(1.0)
      ones = ones + 1
    } else {
      abort(
        "the strength of the confounder is a share of the predictions that " +
        "flip, which needs a binary column; the upstream fits a multinomial " +
        "model for a column with more levels, and its share is then the " +
        "distance between the classes",
      )
    }
  }
  if zeros == 0 || ones == 0 {
    abort(
      "the upstream fits a classifier on the column, which needs two classes",
    )
  }
  let fit = @utils.logistic_fit(
    kappa_design(causes),
    response,
    1.0,
    100,
    1.0e-8,
  )
  let predictions = kappa_classes(fit.beta, causes)
  let flips : Array[Double] = []
  for j = 0; j < causes.ncols(); j = j + 1 {
    let zeroed = causes.copy()
    for i = 0; i < zeroed.nrows(); i = i + 1 {
      zeroed.set(i, j, 0.0)
    }
    let capped = kappa_classes(fit.beta, zeroed)
    let mut flipped = 0
    for i = 0; i < predictions.length(); i = i + 1 {
      if capped[i] != predictions[i] {
        flipped = flipped + 1
      }
    }
    flips.push(flipped.to_double() / predictions.length().to_double())
  }
  kappa_range(flips, frac_strength, len_kappa)
}

///|
/// The strengths of the confounder of the `linear` effect.
///
/// This is the port of the `linear` branch of the upstream, which takes the
/// correlation of every common cause with the column and scales it with the
/// standard deviation of the column.
fn kappa_from_correlations(
  causes : @utils.Matrix,
  column : Array[Double],
  frac_strength : Double,
  len_kappa : Int32,
) -> Array[Double] {
  let sd = @utils.variance(column, 0).sqrt()
  let coefficients : Array[Double] = []
  for j = 0; j < causes.ncols(); j = j + 1 {
    coefficients.push(@utils.pearson_corr(causes.col(j), column) * sd)
  }
  kappa_range(coefficients, frac_strength, len_kappa)
}

///|
/// The strengths of the confounder, scaled and spread over the range.
///
/// This is the port of `_compute_min_max_coeff` and of the tail of the two
/// functions of the upstream. The range of the strengths is scaled with the
/// fraction of the strength the caller gives, and the function returns
/// `len_kappa` values of it. A range of one value is that value alone.
fn kappa_range(
  coefficients : Array[Double],
  frac_strength : Double,
  len_kappa : Int32,
) -> Array[Double] {
  let mut smallest = coefficients[0]
  let mut largest = coefficients[0]
  for value in coefficients {
    if value < smallest {
      smallest = value
    }
    if value > largest {
      largest = value
    }
  }
  let min_coeff = frac_strength * smallest
  let max_coeff = frac_strength * largest
  if min_coeff == max_coeff {
    return [max_coeff]
  }
  let step = (max_coeff - min_coeff) / len_kappa.to_double()
  let out : Array[Double] = []
  for i = 0; i < len_kappa; i = i + 1 {
    out.push(min_coeff + step * i.to_double())
  }
  out
}

///|
/// The matrix with the column of ones that the intercept takes.
fn kappa_design(causes : @utils.Matrix) -> @utils.Matrix {
  let out = @utils.Matrix::zeros(causes.nrows(), causes.ncols() + 1)
  for i = 0; i < causes.nrows(); i = i + 1 {
    out.set(i, 0, 1.0)
    for j = 0; j < causes.ncols(); j = j + 1 {
      out.set(i, j + 1, causes.get(i, j))
    }
  }
  out
}

///|
/// The class every row of the common causes belongs to.
///
/// The class is the one with the larger probability, and a row whose two
/// probabilities are the same belongs to the first class, which is the rule of
/// the argument of the maximum of the upstream.
fn kappa_classes(beta : Array[Double], causes : @utils.Matrix) -> Array[Double] {
  let out : Array[Double] = []
  for i = 0; i < causes.nrows(); i = i + 1 {
    let mut value = beta[0]
    for j = 0; j < causes.ncols(); j = j + 1 {
      value = value + beta[j + 1] * causes.get(i, j)
    }
    out.push(if @utils.sigmoid(value) > 0.5 { 1.0 } else { 0.0 })
  }
  out
}
