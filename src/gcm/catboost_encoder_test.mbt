///|
/// The tests of the CatBoost encoder of the `gcm` package.
///
/// The cases are the ones of the upstream test file
/// `tests/gcm/util/test_general.py`: the encoding of a categorical column with
/// the target of the rows, the encoding of the same column without the target,
/// the encoding of a categorical column whose target is categorical, and the
/// choice of the encoder of the automatic assignment.
///
/// The upstream encodes a column with the target of the rows with the
/// equation (1) of the CatBoost paper, which leaves the row itself out of the
/// mean of its category, and it encodes it without the target with the mean of
/// the whole category. The port reproduces the two.
///
/// The upstream builds its fixture from a `numpy` array of `dtype=object`,
/// because a mixed array converts the numbers to strings; the port builds the
/// frame from a column per name, so the kinds are the kinds of the columns.

///|
/// The categorical column of the fixture of the upstream.
fn catboost_categories() -> Array[String] {
  ["A", "B", "A", "D", "C", "C", "C", "A"]
}

///|
/// The target of the fixture of the upstream.
fn catboost_target() -> Array[Double] {
  [1.0, 2.0, 3.0, 4.0, 2.0, 3.0, 4.0, 2.0]
}

///|
/// The frame of the categorical column of the fixture of the upstream.
fn catboost_frame() -> @api.DataFrame {
  @api.DataFrame::new(
    ["X"],
    Map([("X", @api.Column::discrete(catboost_categories()))]),
  )
}

///|
/// The tolerance of the assertions of the encoder.
const CATBOOST_TOLERANCE : Double = 1.0e-9

///|
/// Whether two numbers agree.
fn catboost_same(a : Double, b : Double) -> Bool {
  (a - b).abs() <= CATBOOST_TOLERANCE * b.abs()
}

///|
/// Whether every value of the two arrays agrees.
fn catboost_same_values(a : Array[Double], b : Array[Double]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if !catboost_same(a[i], b[i]) {
      return false
    }
  }
  true
}

///|
/// test "the CatBoost encoding of a categorical column is the vector of the upstream"
///
/// This is the case of the upstream
/// `test_given_categorical_data_when_fit_catboost_encoders_and_apply_catboost_encoding_then_returns_expected_feature_vector`.
test "the CatBoost encoding of a categorical column is the vector of the upstream" {
  let encoder = @gcm.CatBoostEncoder::new().fit(
    catboost_categories(),
    catboost_target(),
  )
  // The encoding with the target of the rows leaves the row itself out of the
  // mean of its category.
  assert_true(
    catboost_same_values(
      encoder.transform_with_target(catboost_categories(), catboost_target()),
      [
        2.625, 2.625, 1.8125, 2.625, 2.625, 2.3125, 2.5416666666666667, 2.2083333333333335,
      ],
    ),
  )
  // The encoding without the target is the mean of the whole category, and a
  // category that holds a single row takes the mean of the whole column.
  assert_true(
    catboost_same_values(encoder.transform(catboost_categories()), [
      2.15625, 2.625, 2.15625, 2.625, 2.90625, 2.90625, 2.90625, 2.15625,
    ]),
  )
}

///|
/// test "the CatBoost encoding of a categorical column with a numerical column among them is the matrix of the upstream"
///
/// This is the last assertion of the upstream
/// `test_given_categorical_data_when_fit_catboost_encoders_and_apply_catboost_encoding_then_returns_expected_feature_vector`.
test "the CatBoost encoding of a categorical column with a numerical column among them is the matrix of the upstream" {
  let numbers : Array[Double] = []
  for i in 0..<8 {
    numbers.push(i.to_double())
  }
  let frame = @api.DataFrame::new(
    ["X", "N"],
    Map([
      ("X", @api.Column::discrete(catboost_categories())),
      ("N", @api.Column::numeric(numbers)),
    ]),
  )
  let encoders = @gcm.CatBoostEncoders::fit(frame, ["X"], catboost_target())
  let encoded = encoders.design_matrix_with_target(
    frame,
    ["X", "N"],
    catboost_target(),
  )
  assert_eq(encoded.nrows(), 8)
  assert_eq(encoded.ncols(), 2)
  assert_true(
    catboost_same_values(encoded.col(0), [
      2.625, 2.625, 1.8125, 2.625, 2.625, 2.3125, 2.5416666666666667, 2.2083333333333335,
    ]),
  )
  // The numerical column keeps its values.
  assert_true(catboost_same_values(encoded.col(1), numbers))
}

///|
/// test "the CatBoost encoding of a categorical target is the vector of the upstream"
///
/// This is the case of the upstream
/// `test_given_categorical_input_and_target_data_when_fit_catboost_encoders_and_apply_catboost_encoding_then_returns_expected_feature_vector`.
test "the CatBoost encoding of a categorical target is the vector of the upstream" {
  let categories = ["A", "B", "A", "C", "A"]
  let encoder = @gcm.CatBoostEncoder::new().fit(categories, [
    0.0, 0.0, 0.0, 1.0, 0.0,
  ])
  assert_true(
    catboost_same_values(
      encoder.transform_with_target(categories, [0.0, 0.0, 0.0, 1.0, 0.0]),
      [0.2, 0.2, 0.1, 0.2, 0.2 / 3.0],
    ),
  )
  let encoder = @gcm.CatBoostEncoder::new().fit(categories, [
    0.0, 0.0, 1.0, 1.0, 0.0,
  ])
  assert_true(
    catboost_same_values(
      encoder.transform_with_target(categories, [0.0, 0.0, 1.0, 1.0, 0.0]),
      [0.4, 0.4, 0.2, 0.4, 1.4 / 3.0],
    ),
  )
}

///|
/// test "the automatic encoder picks the CatBoost encoder above the threshold"
///
/// This is the first assertion of the upstream
/// `test_given_categorical_data_when_using_auto_fit_and_apply_encoder_then_returns_expected_feature_vector`.
test "the automatic encoder picks the CatBoost encoder above the threshold" {
  let frame = catboost_frame()
  let encoded = @gcm.auto_encode(
    frame,
    ["X"],
    catboost_target(),
    catboost_threshold=3,
  )
  assert_eq(encoded.nrows(), 8)
  assert_eq(encoded.ncols(), 1)
  assert_true(
    catboost_same_values(encoded.col(0), [
      2.625, 2.625, 1.8125, 2.625, 2.625, 2.3125, 2.5416666666666667, 2.2083333333333335,
    ]),
  )
}

///|
/// test "the automatic encoder counts the categories of every column"
///
/// This is the last assertion of the upstream
/// `test_given_categorical_data_when_using_auto_fit_and_apply_encoder_then_returns_expected_feature_vector`.
///
/// The upstream counts the categories of every categorical column of the data
/// and compares the total with its threshold, so two columns of four categories
/// each are above a threshold of five, even though every column of them is
/// below it.
test "the automatic encoder counts the categories of every column" {
  let categories = catboost_categories()
  let frame = @api.DataFrame::new(
    ["X", "Y"],
    Map([
      ("X", @api.Column::discrete(categories)),
      ("Y", @api.Column::discrete(categories)),
    ]),
  )
  let encoded = @gcm.auto_encode(
    frame,
    ["X", "Y"],
    catboost_target(),
    catboost_threshold=5,
  )
  assert_eq(encoded.nrows(), 8)
  assert_eq(encoded.ncols(), 2)
  assert_true(
    catboost_same_values(encoded.col(0), [
      2.625, 2.625, 1.8125, 2.625, 2.625, 2.3125, 2.5416666666666667, 2.2083333333333335,
    ]),
  )
  assert_true(catboost_same_values(encoded.col(0), encoded.col(1)))
}

///|
/// test "the automatic encoder picks the one-hot encoder below the threshold"
///
/// This is the second assertion of the upstream
/// `test_given_categorical_data_when_using_auto_fit_and_apply_encoder_then_returns_expected_feature_vector`.
test "the automatic encoder picks the one-hot encoder below the threshold" {
  let frame = catboost_frame()
  let encoded = @gcm.auto_encode(
    frame,
    ["X"],
    catboost_target(),
    catboost_threshold=5,
  )
  assert_eq(encoded.nrows(), 8)
  assert_eq(encoded.ncols(), 4)
  // The categories of the column are `A`, `B`, `C` and `D` in that order.
  assert_eq(encoded.row(0), [1.0, 0.0, 0.0, 0.0])
  assert_eq(encoded.row(1), [0.0, 1.0, 0.0, 0.0])
  assert_eq(encoded.row(2), [1.0, 0.0, 0.0, 0.0])
  assert_eq(encoded.row(3), [0.0, 0.0, 0.0, 1.0])
  assert_eq(encoded.row(4), [0.0, 0.0, 1.0, 0.0])
  assert_eq(encoded.row(5), [0.0, 0.0, 1.0, 0.0])
  assert_eq(encoded.row(6), [0.0, 0.0, 1.0, 0.0])
  assert_eq(encoded.row(7), [1.0, 0.0, 0.0, 0.0])
}
