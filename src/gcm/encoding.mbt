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
