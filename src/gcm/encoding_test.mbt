///|
/// The tests of the encoding of the graphical causal model package.
///
/// The cases are the ones of the upstream test file
/// `tests/gcm/util/test_general.py`: the one-hot encoding of the categorical
/// columns of a matrix with a numerical column among them, the encoding of a
/// category that the encoder has not seen, and the two checks of whether a
/// column of the matrix is categorical.
///
/// The upstream decides whether a column is categorical from the numpy dtype,
/// which is a string or a boolean for a categorical column. The frame of the
/// port holds no dtype, so a column is categorical exactly when it is a
/// discrete one, and that is the difference of the two checks of the port.
///
/// The upstream builds its fixture from a `numpy` array of `dtype=object`
/// because a mixed array converts the numbers to strings; the port builds the
/// frame from a column per name, so the kinds are the kinds of the columns.

///|
/// The fixture of the upstream one-hot test: two categorical columns with a
/// numerical column between them.
fn encoding_fixture() -> @api.DataFrame {
  @api.DataFrame::new(
    ["C0", "C1", "C2"],
    Map([
      ("C0", @api.Column::discrete(["d", "b", "a"])),
      ("C1", @api.Column::numeric([1.0, 2.0, 3.0])),
      ("C2", @api.Column::discrete(["a", "d", "a"])),
    ]),
  )
}

///|
/// The value of a row of a matrix, as a row of text.
fn encoding_row(matrix : @utils.Matrix, row : Int32) -> Array[Double] {
  let out : Array[Double] = []
  for j = 0; j < matrix.ncols(); j = j + 1 {
    out.push(matrix.get(row, j))
  }
  out
}

///|
test "the one-hot encoding of a mixed matrix is the vector of the upstream" {
  let encoded = @gcm.one_hot_encode_frame(encoding_fixture())
  assert_eq(encoded.nrows(), 3)
  assert_eq(encoded.ncols(), 6)
  // The categories of `C0` are `a`, `b` and `d` in that order, then the value
  // of the numerical column, then the categories of `C2`, which are `a` and
  // `d`.
  assert_eq(encoding_row(encoded, 0), [0.0, 0.0, 1.0, 1.0, 1.0, 0.0])
  assert_eq(encoding_row(encoded, 1), [0.0, 1.0, 0.0, 2.0, 0.0, 1.0])
  assert_eq(encoding_row(encoded, 2), [1.0, 0.0, 0.0, 3.0, 1.0, 0.0])
}

///|
test "a category the encoder has not seen is encoded with zeros" {
  let encoder = @gcm.ParentEncoder::fit(encoding_fixture(), ["C0", "C1", "C2"])
  // The row of the upstream test: a seen category, a new value of the
  // numerical column and an unseen category.
  let unseen = @api.DataFrame::new(
    ["C0", "C1", "C2"],
    Map([
      ("C0", @api.Column::discrete(["a"])),
      ("C1", @api.Column::numeric([4.0])),
      ("C2", @api.Column::discrete(["f"])),
    ]),
  )
  let encoded = encoder.design_matrix(unseen, ["C0", "C1", "C2"])
  assert_eq(encoded.nrows(), 1)
  assert_eq(encoded.ncols(), 6)
  assert_eq(encoding_row(encoded, 0), [1.0, 0.0, 0.0, 4.0, 0.0, 0.0])
}

///|
test "every column of a frame of categories is categorical" {
  let categorical = @api.DataFrame::new(
    ["A", "B"],
    Map([
      ("A", @api.Column::discrete(["A", "B", "A"])),
      ("B", @api.Column::discrete(["x", "y", "x"])),
    ]),
  )
  assert_true(@gcm.is_categorical(categorical))
  // A single numerical column is not categorical, which is the last case of
  // the upstream test.
  let numerical = @api.DataFrame::new(
    ["A"],
    Map([("A", @api.Column::numeric([1.0, 2.0, 3.0]))]),
  )
  assert_false(@gcm.is_categorical(numerical))
  // A frame of a single categorical column is categorical as well.
  let single = @api.DataFrame::new(
    ["X"],
    Map([("X", @api.Column::discrete(["A", "B", "A"]))]),
  )
  assert_true(@gcm.is_categorical(single))
}

///|
test "a frame with a categorical column among the numerical ones has a categorical column" {
  let mixed = @api.DataFrame::new(
    ["A", "B", "C"],
    Map([
      ("A", @api.Column::discrete(["A", "B"])),
      ("B", @api.Column::numeric([2.0, 4.0])),
      ("C", @api.Column::numeric([3.0, 5.0])),
    ]),
  )
  assert_true(@gcm.has_categorical(mixed))
  // A frame of numerical columns has no categorical column, which is the last
  // case of the upstream test.
  let numerical = @api.DataFrame::new(
    ["A", "B", "C"],
    Map([
      ("A", @api.Column::numeric([1.0, 12.2])),
      ("B", @api.Column::numeric([2.0, 2.3])),
      ("C", @api.Column::numeric([3.0, 3.231])),
    ]),
  )
  assert_false(@gcm.has_categorical(numerical))
}
