///|
/// The one-hot encoding of the discrete parents of a node.
///
/// This is the port of the encoding of `dowhy.gcm.util.general`, which encodes
/// every categorical column of the parents with
/// `sklearn.preprocessing.OneHotEncoder(handle_unknown="ignore")`. Every
/// category becomes a column of its own; a category that was not seen when the
/// encoder was fitted is encoded with zeros, which is what the upstream does
/// as well.

///|
/// Whether every column of the frame is categorical.
///
/// This is the port of `dowhy.gcm.util.general.is_categorical`. The upstream
/// decides from the numpy dtype of the columns, which is a string or a boolean
/// for a categorical column; the frame of the port holds no dtype, so a column
/// is categorical exactly when it is a discrete one.
///
/// The upstream refuses a categorical input that holds missing values, because
/// only the missing values of a numerical variable are supported. The frame of
/// the port holds no missing value, so there is no such check here.
pub fn is_categorical(data : @api.DataFrame) -> Bool {
  let names = data.column_names()
  if names.length() == 0 {
    return false
  }
  for name in names {
    if !data.is_discrete(name) {
      return false
    }
  }
  true
}

///|
/// Whether any column of the frame is categorical.
///
/// This is the port of `dowhy.gcm.util.general.has_categorical`, which asks
/// `is_categorical` of every column.
pub fn has_categorical(data : @api.DataFrame) -> Bool {
  for name in data.column_names() {
    if data.is_discrete(name) {
      return true
    }
  }
  false
}

///|
/// The one-hot encoding of the discrete parents of a node.
pub struct ParentEncoder {
  /// The names of the discrete parent columns, in the order of the parents.
  discrete_columns : Array[String]
  /// The categories of every discrete parent column, in lexicographic order.
  categories : Map[String, Array[String]]
}

///|
/// Fit the encoder on the discrete columns of the given parents.
pub fn ParentEncoder::fit(
  data : @api.DataFrame,
  parents : Array[String],
) -> ParentEncoder {
  let discrete_columns : Array[String] = []
  let categories : Map[String, Array[String]] = Map([])
  for parent in parents {
    if data.is_discrete(parent) {
      discrete_columns.push(parent)
      categories.set(parent, sorted_distinct_labels(data.discrete(parent)))
    }
  }
  { discrete_columns, categories, }
}

///|
/// The one-hot encoding of a column of categories.
///
/// This is the port of the encoding of the categorical columns of
/// `dowhy.gcm.util.general`, which fits a
/// `sklearn.preprocessing.OneHotEncoder(handle_unknown="ignore")` on every
/// categorical column and applies it. Every category becomes a column of its
/// own, in lexicographic order, and a category that was not seen when the
/// encoder was fitted is encoded with zeros.
///
/// The rows are the rows of the column and the columns are the categories.
pub fn one_hot_encode(values : Array[String]) -> @utils.Matrix {
  let categories = sorted_distinct_labels(values)
  let columns : Array[Array[Double]] = []
  for category in categories {
    let column : Array[Double] = []
    for value in values {
      column.push(if value == category { 1.0 } else { 0.0 })
    }
    columns.push(column)
  }
  if columns.length() == 0 {
    return @utils.Matrix::zeros(values.length(), 0)
  }
  @utils.Matrix::from_columns(columns)
}

///|
/// The one-hot encoding of the discrete columns of a frame.
///
/// The numeric columns keep their values and the discrete columns become one
/// column per category, so the result holds the same rows as the frame.
pub fn one_hot_encode_frame(data : @api.DataFrame) -> @utils.Matrix {
  let columns : Array[Array[Double]] = []
  for name in data.column_names() {
    if data.is_discrete(name) {
      let encoded = one_hot_encode(data.discrete(name))
      for j in 0..<encoded.ncols() {
        columns.push(encoded.col(j))
      }
    } else {
      columns.push(data.numeric(name))
    }
  }
  if columns.length() == 0 {
    return @utils.Matrix::zeros(data.nrows(), 0)
  }
  @utils.Matrix::from_columns(columns)
}

///|
/// The names of the columns of the design matrix.
///
/// A numeric parent keeps its own name, and a discrete parent becomes one
/// column per category, named `<parent>_<category>`.
pub fn ParentEncoder::column_names(
  self : ParentEncoder,
  parents : Array[String],
) -> Array[String] {
  let names : Array[String] = []
  for parent in parents {
    if self.discrete_columns.contains(parent) {
      match self.categories.get(parent) {
        Some(cats) =>
          for category in cats {
            names.push(parent + "_" + category)
          }
        None => ()
      }
    } else {
      names.push(parent)
    }
  }
  names
}

///|
/// The design matrix of the given parents.
///
/// The rows are the rows of the data and the columns follow the order of the
/// parents.
pub fn ParentEncoder::design_matrix(
  self : ParentEncoder,
  data : @api.DataFrame,
  parents : Array[String],
) -> @utils.Matrix {
  let columns : Array[Array[Double]] = []
  for parent in parents {
    if self.discrete_columns.contains(parent) {
      let values = data.discrete(parent)
      match self.categories.get(parent) {
        Some(cats) =>
          for category in cats {
            let column : Array[Double] = []
            for value in values {
              column.push(if value == category { 1.0 } else { 0.0 })
            }
            columns.push(column)
          }
        None => ()
      }
    } else {
      columns.push(data.numeric(parent))
    }
  }
  if columns.length() == 0 {
    return @utils.Matrix::zeros(data.nrows(), 0)
  }
  @utils.Matrix::from_columns(columns)
}
