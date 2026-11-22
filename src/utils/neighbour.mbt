///|
/// The message of the error of a number of neighbours below one.
///
/// The upstream builds its nearest neighbour estimators with scikit-learn,
/// which refuses a number of neighbours below one: its `NearestNeighbors`, its
/// `KNeighborsRegressor` and its `KNeighborsClassifier` all raise an
/// `InvalidParameterError` for it.  The estimators of the port refuse it as
/// well, so that a number of neighbours below one does not read outside the
/// array of the neighbours.  MoonBit cannot catch the abort of a function, so
/// the condition is a function of its own that the tests can check.
pub const NEIGHBOUR_COUNT_ERROR : String = "The number of neighbours has to be at least one"

///|
/// Whether a number of neighbours is one the nearest neighbour estimators of
/// the port accept.
///
/// The upstream builds its nearest neighbour estimators with scikit-learn,
/// which refuses a number of neighbours below one.  The estimators of the port
/// refuse it as well, so that a number of neighbours below one does not read
/// outside the array of the neighbours.  MoonBit cannot catch the abort of a
/// function, so the condition is a function of its own that the tests can
/// check.
pub fn has_valid_neighbour_count(k : Int32) -> Bool {
  k >= 1
}
