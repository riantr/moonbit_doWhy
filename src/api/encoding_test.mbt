///|
/// The tests of the one-hot encoding.
///
/// The cases mirror the upstream test suite (`tests/utils/test_encoding.py`):
/// the encoding has to be the one `pandas.get_dummies` produces, and the
/// encoding of new data has to agree with the encoding of the data the
/// encoder was fitted on.

///|
/// A frame with a discrete column and a numeric one.
fn mixed_frame(discrete : Array[String]) -> @api.DataFrame {
  let numeric : Array[Double] = []
  for i = 0; i < discrete.length(); i = i + 1 {
    numeric.push((i + 1).to_double())
  }
  @api.DataFrame::new(
    ["C", "N"],
    Map([
      ("C", @api.Column::discrete(discrete)),
      ("N", @api.Column::numeric(numeric)),
    ]),
  )
}

///|
test "the one hot encoding is the one pandas get_dummies produces" {
  let data = mixed_frame(["X", "Y", "Z", "X", "Y", "Z"])
  let (encoded, _) = @api.one_hot_encode(data, ["C"], true)
  let columns = encoded.column_names()
  // The column that is not encoded is kept and comes first, and the encoded
  // columns follow it.
  assert_eq(columns.length(), 3)
  assert_eq(columns[0], "N")
  assert_eq(columns[1], "C_Y")
  assert_eq(columns[2], "C_Z")
  // The numeric column is unchanged.
  let numbers = encoded.numeric("N")
  assert_eq(numbers.length(), 6)
  for i = 0; i < numbers.length(); i = i + 1 {
    assert_eq(numbers[i], (i + 1).to_double())
  }
  // The first category is dropped, so only the other two get a column.
  let y = encoded.numeric("C_Y")
  let z = encoded.numeric("C_Z")
  assert_eq(y.length(), 6)
  assert_eq(z.length(), 6)
  let expected_y = [0.0, 1.0, 0.0, 0.0, 1.0, 0.0]
  let expected_z = [0.0, 0.0, 1.0, 0.0, 0.0, 1.0]
  for i = 0; i < 6; i = i + 1 {
    assert_eq(y[i], expected_y[i])
    assert_eq(z[i], expected_z[i])
  }
}

///|
test "the one hot encoding keeps every category when nothing is dropped" {
  let data = mixed_frame(["X", "Y", "Z", "X", "Y", "Z"])
  let (encoded, _) = @api.one_hot_encode(data, ["C"], false)
  let columns = encoded.column_names()
  assert_eq(columns.length(), 4)
  assert_eq(columns[0], "N")
  assert_eq(columns[1], "C_X")
  assert_eq(columns[2], "C_Y")
  assert_eq(columns[3], "C_Z")
  let x = encoded.numeric("C_X")
  assert_eq(x[0], 1.0)
  assert_eq(x[1], 0.0)
}

///|
test "the one hot encoding of new data agrees with the encoding of the old data" {
  let first = mixed_frame(["X", "Y", "Z", "X", "Y", "Z"])
  let (encoded_first, encoder) = @api.one_hot_encode(first, ["C"], true)
  // The same variables, in another order.
  let second = mixed_frame(["Y", "Z", "X", "X", "Y", "Z"])
  let encoded_second = @api.one_hot_encode_with(second, encoder)
  // The shape does not change.
  assert_eq(encoded_first.nrows(), encoded_second.nrows())
  assert_eq(
    encoded_first.column_names().length(),
    encoded_second.column_names().length(),
  )
  assert_eq(encoded_first.column_names(), encoded_second.column_names())
  // And the values of the permuted rows agree.
  let y_first = encoded_first.numeric("C_Y")
  let y_second = encoded_second.numeric("C_Y")
  assert_eq(y_first[1], y_second[0])
  assert_eq(y_first[4], y_second[4])
  let z_first = encoded_first.numeric("C_Z")
  let z_second = encoded_second.numeric("C_Z")
  assert_eq(z_first[2], z_second[1])
  assert_eq(z_first[5], z_second[5])
}

///|
test "the encoder names its columns and its categories" {
  let data = mixed_frame(["X", "Y", "Z", "X", "Y", "Z"])
  let (_, encoder) = @api.one_hot_encode(data, ["C"], true)
  assert_eq(encoder.encoded_columns(), ["C"])
  assert_eq(encoder.categories_of("C"), ["X", "Y", "Z"])
  assert_eq(encoder.get_feature_names_out(), ["C_Y", "C_Z"])
}

///|
test "the encoder registry reuses the encoder of a named set of variables" {
  let data = mixed_frame(["X", "Y", "Z", "X", "Y", "Z"])
  let encoders = @api.Encoders::new(true)
  let first = encoders.encode(data, "cause")
  assert_eq(encoders.names(), ["cause"])
  // The second data set has the same variables in another order, and the
  // encoder that was fitted on the first one is used again.
  let second = mixed_frame(["Y", "Z", "X", "X", "Y", "Z"])
  let encoded = encoders.encode(second, "cause")
  assert_eq(first.column_names(), encoded.column_names())
  let y_first = first.numeric("C_Y")
  let y_second = encoded.numeric("C_Y")
  assert_eq(y_first[1], y_second[0])
  // A different name gets its own encoder.
  let other = encoders.encode(data, "outcome")
  assert_eq(encoders.names().length(), 2)
  assert_eq(other.column_names(), first.column_names())
  // Resetting forgets the encoders.
  encoders.reset()
  assert_eq(encoders.names().length(), 0)
}

///|
test "the discrete columns of a frame are found" {
  let data = mixed_frame(["X", "Y", "Z", "X", "Y", "Z"])
  assert_eq(@api.discrete_columns(data), ["C"])
}
