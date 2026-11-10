///|
/// The CatBoost encoder of the categorical columns of a frame.
///
/// This is the port of `dowhy.gcm.util.catboost_encoder.CatBoostEncoder` and
/// of the part of `dowhy.gcm.util.general.auto_fit_encoders` that uses it.
/// The upstream fits the CatBoost encoder on the categorical columns of the
/// data when the data holds more than seven categories, and it fits the
/// one-hot encoder otherwise; the encoder of the parents of the port is the
/// one-hot encoder, so this file holds the other one.
///
/// The CatBoost encoder is a target encoder: the value of a category is the
/// mean of the target of the rows of that category, smoothed with the mean of
/// the target of the whole column. A category that holds a single row takes
/// the mean of the whole column, the way the upstream does it.

///|
/// The number of the categories above which the upstream uses the CatBoost
/// encoder instead of the one-hot encoder.
pub const CATBOOST_THRESHOLD : Int32 = 7

///|
/// The CatBoost encoder of one categorical column.
///
/// This is the port of `dowhy.gcm.util.catboost_encoder.CatBoostEncoder`.
pub struct CatBoostEncoder {
  /// The smoothing parameter of the encoder, which is one in the upstream.
  p : Double
  /// The mean of the target of the whole column.
  alpha : Double
  /// The value of every category.
  means : Map[String, Double]
  /// Whether the encoder has been fitted.
  fitted : Bool
}

///|
/// An unfitted CatBoost encoder.
pub fn CatBoostEncoder::new() -> CatBoostEncoder {
  { p: 1.0, alpha: 0.0, means: Map([]), fitted: false, }
}

///|
/// Fit the encoder on the given target.
///
/// The result is a new encoder; the encoder the fit is called on stays as it
/// is. The value of a category that holds more than one row is the mean of
/// the target of its rows and the mean of the whole column, the way the
/// equation (1) of the CatBoost paper computes it. A category that holds a
/// single row takes the mean of the whole column.
pub fn CatBoostEncoder::fit(
  self : CatBoostEncoder,
  x : Array[String],
  y : Array[Double],
) -> CatBoostEncoder {
  let alpha = @utils.mean(y)
  let means : Map[String, Double] = Map([])
  for category in sorted_distinct_labels(x) {
    let mut sum = 0.0
    let mut count = 0
    for i in 0..<x.length() {
      if i < y.length() && x[i] == category {
        sum = sum + y[i]
        count = count + 1
      }
    }
    if count == 1 {
      // A category that holds a single row takes the mean of the whole
      // column.
      means.set(category, alpha)
    } else {
      means.set(category, (sum + alpha * self.p) / (count.to_double() + self.p))
    }
  }
  { p: self.p, alpha, means, fitted: true, }
}

///|
/// The encoded values of the given categories.
///
/// A category that was not seen when the encoder was fitted takes the mean of
/// the target of the whole column, the way the upstream does it.
pub fn CatBoostEncoder::transform(
  self : CatBoostEncoder,
  x : Array[String],
) -> Array[Double] {
  if !self.fitted {
    abort("the encoder has not been fitted")
  }
  let out : Array[Double] = []
  for value in x {
    match self.means.get(value) {
      Some(mean) => out.push(mean)
      None => out.push(self.alpha)
    }
  }
  out
}

///|
/// The CatBoost encoders of the categorical columns of a frame.
///
/// This is the port of the map of the encoders that
/// `dowhy.gcm.util.general.auto_fit_encoders` returns.
pub struct CatBoostEncoders {
  /// The names of the categorical columns, in the order of the columns.
  columns : Array[String]
  /// The encoder of every categorical column.
  encoders : Map[String, CatBoostEncoder]
}

///|
/// Fit the encoders on the categorical columns of the given frame.
///
/// The target of the encoders is the label of every row, which is the number
/// of the class of the row for a categorical target and the value of the row
/// for a continuous one.
pub fn CatBoostEncoders::fit(
  data : @api.DataFrame,
  columns : Array[String],
  target : Array[Double],
) -> CatBoostEncoders {
  let encoders : Map[String, CatBoostEncoder] = Map([])
  for column in columns {
    encoders.set(
      column,
      CatBoostEncoder::new().fit(data.discrete(column), target),
    )
  }
  { columns, encoders, }
}

///|
/// The design matrix of the given frame, with the encoded categorical columns.
///
/// The numeric columns keep their values and every categorical column becomes
/// a column of its own, the value of the category.
pub fn CatBoostEncoders::design_matrix(
  self : CatBoostEncoders,
  data : @api.DataFrame,
  columns : Array[String],
) -> @utils.Matrix {
  let out : Array[Array[Double]] = []
  for column in columns {
    if self.columns.contains(column) {
      match self.encoders.get(column) {
        Some(encoder) => out.push(encoder.transform(data.discrete(column)))
        None => ()
      }
    } else {
      out.push(data.numeric(column))
    }
  }
  if out.length() == 0 {
    return @utils.Matrix::zeros(data.nrows(), 0)
  }
  @utils.Matrix::from_columns(out)
}

///|
/// The number of the categories of the categorical columns of a frame.
///
/// This is the number the upstream compares with its threshold: the number of
/// the categories of every categorical column of the data.
pub fn number_of_categories(
  data : @api.DataFrame,
  columns : Array[String],
) -> Int32 {
  let mut total = 0
  for column in columns {
    total = total + sorted_distinct_labels(data.discrete(column)).length()
  }
  total
}
