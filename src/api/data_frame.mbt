/// A light-weight, column oriented data frame.
///
/// This is the port of the subset of `pandas.DataFrame` that the DoWhy
/// estimators use: column selection, row filtering, column assignment and the
/// numeric access that the regressions read. Columns keep their insertion
/// order so that a design matrix built from the frame has a deterministic
/// column order, which is what the estimators rely on.

///|
/// The payload of a single column.
pub enum Column {
  /// A column of floating point numbers.
  Numeric(Array[Double])
  /// A column of strings.
  Discrete(Array[String])
}

///|
/// A numeric column.
///
/// The constructor lives in the package that defines the enum, because a
/// variant whose payload is a mutable array cannot be built directly from
/// another package.
pub fn Column::numeric(values : Array[Double]) -> Column {
  Column::Numeric(values)
}

///|
/// A column of strings.
///
/// The constructor lives in the package that defines the enum, because a
/// variant whose payload is a mutable array cannot be built directly from
/// another package.
pub fn Column::discrete(values : Array[String]) -> Column {
  Column::Discrete(values)
}

///|
/// A tabular data frame.
pub struct DataFrame {
  columns : Map[String, Column]
  order : Array[String]
  nrows : Int32
}

///|
/// Build a data frame from an ordered list of column names and a map of
/// columns.
pub fn DataFrame::new(
  order : Array[String],
  columns : Map[String, Column],
) -> DataFrame {
  let mut n = 0
  for name in order {
    match columns.get(name) {
      Some(Numeric(values)) => if values.length() > n { n = values.length() }
      Some(Discrete(values)) => if values.length() > n { n = values.length() }
      None => ()
    }
  }
  { columns, order, nrows: n, }
}

///|
/// Build a data frame whose columns are all numeric.
///
/// The column order is the order of `order`.
pub fn DataFrame::from_numeric(
  order : Array[String],
  columns : Map[String, Array[Double]],
) -> DataFrame {
  let payload : Map[String, Column] = {
    let m : Map[String, Column] = Map([])
    for name in order {
      match columns.get(name) {
        Some(values) => m.set(name, Column::Numeric(values))
        None => ()
      }
    }
    m
  }
  DataFrame::new(order, payload)
}

///|
/// Build a single column data frame.
pub fn DataFrame::of(name : String, values : Array[Double]) -> DataFrame {
  DataFrame::from_numeric([name], Map([(name, values)]))
}

///|
/// Number of rows.
pub fn DataFrame::nrows(self : DataFrame) -> Int32 {
  self.nrows
}

///|
/// Column names in order.
pub fn DataFrame::column_names(self : DataFrame) -> Array[String] {
  self.order.copy()
}

///|
/// Whether the frame contains the given column.
pub fn DataFrame::has_column(self : DataFrame, name : String) -> Bool {
  self.columns.contains(name)
}

///|
/// The names of the numeric columns of the frame, in order.
///
/// The estimators use it to pick the columns of a design matrix out of an
/// encoded frame, whose discrete columns became numeric ones.
pub fn DataFrame::numeric_column_names(self : DataFrame) -> Array[String] {
  let names : Array[String] = []
  for name in self.order {
    match self.columns.get(name) {
      Some(Numeric(_)) => names.push(name)
      _ => ()
    }
  }
  names
}

///|
/// Whether the frame holds a value that is not a number.
///
/// This is the predicate of the check the upstream `assign_causal_mechanisms`
/// does before it assigns the mechanisms of a model: the upstream raises when
/// the data holds missing values and its experimental flag is not set, and
/// MoonBit cannot catch the stop of a function, so the check is available on
/// its own.
///
/// A column of strings cannot hold a missing value, so only the numeric
/// columns of the frame are read.
pub fn DataFrame::has_missing_values(self : DataFrame) -> Bool {
  for name in self.order {
    match self.columns.get(name) {
      Some(Numeric(values)) =>
        for value in values {
          if @utils.is_nan(value) {
            return true
          }
        }
      _ => ()
    }
  }
  false
}

///|
/// The rows of the frame that hold no missing value.
///
/// A row is missing when one of the numeric columns of the frame holds a value
/// that is not a number in it. A row of a column of strings is never missing.
///
/// The rows are the indices of the frame, in order, so that the caller can
/// take the rows of the frame and the rows of its columns with them.
pub fn DataFrame::complete_rows(self : DataFrame) -> Array[Int32] {
  let rows : Array[Int32] = []
  for row in 0..<self.nrows {
    if frame_row_is_complete(self, row) {
      rows.push(row)
    }
  }
  rows
}

///|
/// Whether the row of the frame holds no missing value.
fn frame_row_is_complete(frame : DataFrame, row : Int32) -> Bool {
  for name in frame.order {
    match frame.columns.get(name) {
      Some(Numeric(values)) =>
        if row < values.length() && @utils.is_nan(values[row]) {
          return false
        }
      _ => ()
    }
  }
  true
}

///|
/// Whether the given column holds discrete values.
pub fn DataFrame::is_discrete(self : DataFrame, name : String) -> Bool {
  match self.columns.get(name) {
    Some(Discrete(_)) => true
    _ => false
  }
}

///|
/// The raw payload of a column.
pub fn DataFrame::column(self : DataFrame, name : String) -> Column? {
  self.columns.get(name)
}

///|
/// The numeric values of a column.
///
/// Raises when the column is missing or not numeric.
pub fn DataFrame::numeric(self : DataFrame, name : String) -> Array[Double] {
  match self.columns.get(name) {
    Some(Numeric(values)) => values
    Some(Discrete(_)) => abort("column '" + name + "' is not numeric")
    None => abort("column '" + name + "' not found")
  }
}

///|
/// The string values of a column.
///
/// Raises when the column is missing or not discrete.
pub fn DataFrame::discrete(self : DataFrame, name : String) -> Array[String] {
  match self.columns.get(name) {
    Some(Discrete(values)) => values
    Some(Numeric(_)) => abort("column '" + name + "' is not discrete")
    None => abort("column '" + name + "' not found")
  }
}

///|
/// Mean of a numeric column.
pub fn DataFrame::mean(self : DataFrame, name : String) -> Double {
  @utils.mean(self.numeric(name))
}

///|
/// Sum of a numeric column.
pub fn DataFrame::sum(self : DataFrame, name : String) -> Double {
  let values = self.numeric(name)
  let mut s = 0.0
  for i = 0; i < values.length(); i = i + 1 {
    s = s + values[i]
  }
  s
}

///|
/// A copy of the frame.
///
/// The columns are copied as well, so the copy and the original do not share
/// any state.
pub fn DataFrame::copy(self : DataFrame) -> DataFrame {
  { columns: self.columns.copy(), order: self.order.copy(), nrows: self.nrows, }
}

///|
/// A frame restricted to the given columns, in the given order.
pub fn DataFrame::select(self : DataFrame, names : Array[String]) -> DataFrame {
  let selected : Map[String, Column] = {
    let m : Map[String, Column] = Map([])
    for name in names {
      match self.columns.get(name) {
        Some(col) => m.set(name, col)
        None => ()
      }
    }
    m
  }
  DataFrame::new(names, selected)
}

///|
/// A frame restricted to the rows selected by the mask.
pub fn DataFrame::filter(self : DataFrame, mask : Array[Bool]) -> DataFrame {
  let filtered : Map[String, Column] = {
    let m : Map[String, Column] = Map([])
    for name in self.order {
      match self.columns.get(name) {
        Some(Numeric(values)) => {
          let kept : Array[Double] = []
          for i = 0; i < values.length(); i = i + 1 {
            if i < mask.length() && mask[i] {
              kept.push(values[i])
            }
          }
          m.set(name, Column::Numeric(kept))
        }
        Some(Discrete(values)) => {
          let kept : Array[String] = []
          for i = 0; i < values.length(); i = i + 1 {
            if i < mask.length() && mask[i] {
              kept.push(values[i])
            }
          }
          m.set(name, Column::Discrete(kept))
        }
        None => ()
      }
    }
    m
  }
  DataFrame::new(self.order, filtered)
}

///|
/// A frame with an extra (or replaced) column.
///
/// The frame is copied first, so the frame the method is called on is left
/// unchanged; a map is mutated in place and a shared one would change the
/// other frame as well. The number of rows is recomputed, because the new
/// column can be shorter than the frame it is added to.
pub fn DataFrame::with_column(
  self : DataFrame,
  name : String,
  column : Column,
) -> DataFrame {
  let columns = self.columns.copy()
  columns.set(name, column)
  let order = if self.order.contains(name) {
    self.order.copy()
  } else {
    let extended = self.order.copy()
    extended.push(name)
    extended
  }
  let frame = { columns, order, nrows: self.nrows, }
  { columns: frame.columns, order: frame.order, nrows: row_count(frame), }
}

///|
/// The number of rows of the frame, which is the length of its longest column.
fn row_count(frame : DataFrame) -> Int32 {
  let mut rows = 0
  for name in frame.order {
    match frame.columns.get(name) {
      Some(Numeric(values)) =>
        if values.length() > rows {
          rows = values.length()
        }
      Some(Discrete(values)) =>
        if values.length() > rows {
          rows = values.length()
        }
      None => ()
    }
  }
  rows
}

///|
/// A frame with an extra numeric column.
pub fn DataFrame::with_numeric(
  self : DataFrame,
  name : String,
  values : Array[Double],
) -> DataFrame {
  self.with_column(name, Column::Numeric(values))
}

///|
/// A frame with an extra discrete column.
pub fn DataFrame::with_discrete(
  self : DataFrame,
  name : String,
  values : Array[String],
) -> DataFrame {
  self.with_column(name, Column::Discrete(values))
}

///|
/// A frame with the given rows, in the given order.
///
/// The rows are given by their index in the frame. An index that is out of
/// range is skipped, so a resample never reads past the end of a column.
pub fn DataFrame::take_rows(self : DataFrame, rows : Array[Int32]) -> DataFrame {
  let taken : Map[String, Column] = {
    let m : Map[String, Column] = Map([])
    for name in self.order {
      match self.columns.get(name) {
        Some(Numeric(values)) => {
          let selected : Array[Double] = []
          for index in rows {
            if index >= 0 && index < values.length() {
              selected.push(values[index])
            }
          }
          m.set(name, Column::Numeric(selected))
        }
        Some(Discrete(values)) => {
          let selected : Array[String] = []
          for index in rows {
            if index >= 0 && index < values.length() {
              selected.push(values[index])
            }
          }
          m.set(name, Column::Discrete(selected))
        }
        None => ()
      }
    }
    m
  }
  DataFrame::new(self.order.copy(), taken)
}

///|
/// A mask that selects the rows whose column equals the given value.
pub fn DataFrame::mask_eq(
  self : DataFrame,
  name : String,
  value : Double,
) -> Array[Bool] {
  let values = self.numeric(name)
  let mask : Array[Bool] = []
  for i = 0; i < values.length(); i = i + 1 {
    mask.push(values[i] == value)
  }
  mask
}

///|
/// A mask that selects the rows whose column differs from the given value.
pub fn DataFrame::mask_ne(
  self : DataFrame,
  name : String,
  value : Double,
) -> Array[Bool] {
  let values = self.numeric(name)
  let mask : Array[Bool] = []
  for i = 0; i < values.length(); i = i + 1 {
    mask.push(values[i] != value)
  }
  mask
}

///|
/// A mask that selects rows whose numeric column lies in `[lower, upper]`.
pub fn DataFrame::mask_range(
  self : DataFrame,
  name : String,
  lower : Double,
  upper : Double,
) -> Array[Bool] {
  let values = self.numeric(name)
  let mask : Array[Bool] = []
  for i = 0; i < values.length(); i = i + 1 {
    mask.push(values[i] >= lower && values[i] <= upper)
  }
  mask
}

///|
/// Build a design matrix from the given numeric columns, in order.
pub fn DataFrame::design_matrix(
  self : DataFrame,
  names : Array[String],
) -> @utils.Matrix {
  let columns : Array[Array[Double]] = []
  for name in names {
    columns.push(self.numeric(name))
  }
  @utils.Matrix::from_columns(columns)
}

///|
/// Discretise a numeric column into quantile bins, like `pandas.qcut`.
///
/// The returned column holds the bin index of every row; the bins are the
/// `q` quantile groups of the values, so the indices run from `0` to `q - 1`.
/// Rows whose value cannot be assigned (because of too few distinct values)
/// get the bin of their own value.
pub fn DataFrame::qcut(
  self : DataFrame,
  name : String,
  q : Int32,
) -> Array[Double] {
  let values = self.numeric(name)
  let n = values.length()
  let ranks = @utils.average_rank(values)
  let bins : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    // The rank of a row is counted from one, so the bin of the first row is
    // the first one and the bin of the last row is the last one.
    let bin = (ranks[i] - 1.0) * q.to_double() / n.to_double()
    bins.push(bin.floor())
  }
  bins
}

///|
/// Split the rows into groups keyed by the value of a numeric column.
///
/// Returns the group keys in ascending order together with the row indices of
/// every group.
pub fn DataFrame::group_by(
  self : DataFrame,
  name : String,
) -> (Array[Double], Array[Array[Int32]]) {
  let values = self.numeric(name)
  let keys : Array[Double] = []
  let groups : Array[Array[Int32]] = []
  let index_of : Map[Double, Int32] = Map([])
  for i = 0; i < values.length(); i = i + 1 {
    let key = values[i]
    match index_of.get(key) {
      Some(pos) => groups[pos].push(i)
      None => {
        index_of.set(key, keys.length())
        keys.push(key)
        let group : Array[Int32] = []
        group.push(i)
        groups.push(group)
      }
    }
  }
  // Sort the groups by key.
  let order : Array[Int32] = []
  for i = 0; i < keys.length(); i = i + 1 {
    order.push(i)
  }
  order.sort_by(fn(a, b) { @utils.compare_double(keys[a], keys[b]) })
  let sorted_keys : Array[Double] = []
  let sorted_groups : Array[Array[Int32]] = []
  for idx in order {
    sorted_keys.push(keys[idx])
    sorted_groups.push(groups[idx])
  }
  (sorted_keys, sorted_groups)
}
