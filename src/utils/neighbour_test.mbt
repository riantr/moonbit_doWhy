///|
/// The tests of the check of the number of the neighbours.
///
/// The upstream builds its nearest neighbour estimators with scikit-learn,
/// which refuses a number of neighbours below one.  The port refuses it as
/// well, so that a number of neighbours below one does not read outside the
/// array of the neighbours.  MoonBit cannot catch the abort of a function, so
/// the test checks the condition of the refusal and its message.

///|
/// The nearest neighbour estimators refuse a number of neighbours below one.
test "the nearest neighbour estimators refuse a number of neighbours below one" {
  assert_true(@utils.has_valid_neighbour_count(1))
  assert_true(@utils.has_valid_neighbour_count(2))
  assert_false(@utils.has_valid_neighbour_count(0))
  assert_false(@utils.has_valid_neighbour_count(-1))
}

///|
/// The message of the refusal of a number of neighbours below one is the one
/// the port uses for it.
test "the message of the refusal of a number of neighbours below one is the one of the port" {
  assert_eq(
    "The number of neighbours has to be at least one",
    @utils.NEIGHBOUR_COUNT_ERROR,
  )
}
