///|
/// The cases of the features of a data frame.
///
/// The upstream has no test file for `dowhy.utils.regression`, so the cases of
/// the port are its own. Every one of them asserts a number that the reference
/// script `_verify/utilities_reference.py` prints for the upstream.

///|
test "the numeric features of a frame are the indices of its numeric columns" {
  let frame = @api.DataFrame::new(
    ["a", "b", "c"],
    Map([
      ("a", @api.Column::numeric([1.0, 2.0, 3.0])),
      ("b", @api.Column::discrete(["x", "y", "z"])),
      ("c", @api.Column::numeric([4.0, 5.0, 6.0])),
    ]),
  )
  let indices = frame.numeric_feature_indices()
  assert_eq(indices.length(), 2)
  assert_eq(indices[0], 0)
  assert_eq(indices[1], 2)
}
