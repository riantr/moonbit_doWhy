/// The features of a data frame.
///
/// This is the port of `dowhy.utils.regression.get_numeric_features`: the
/// indices of the numeric columns of a data frame. The helper of the upstream
/// lives in the `utils` package of the upstream, and the `utils` package of
/// the port has no dependency on the `api` package, so the port keeps it
/// where the data frame lives.

///|
/// The indices of the numeric columns of the frame, in order.
///
/// This is the port of `dowhy.utils.regression.get_numeric_features`. The
/// upstream picks the columns of the frame with the `select_dtypes` of pandas
/// and the `number` of it, which keeps the integer columns as well as the
/// floating point ones; the port keeps the columns of the frame whose values
/// are numbers.
pub fn DataFrame::numeric_feature_indices(self : DataFrame) -> Array[Int32] {
  let indices : Array[Int32] = []
  let names = self.numeric_column_names()
  for name in names {
    for index = 0; index < self.order.length(); index = index + 1 {
      if self.order[index] == name {
        indices.push(index)
        break
      }
    }
  }
  indices
}
