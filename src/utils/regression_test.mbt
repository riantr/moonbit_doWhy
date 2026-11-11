///|
/// The cases of the regression helpers of the upstream.
///
/// The upstream has no test file for `dowhy.utils.regression`, so the cases of
/// the port are its own. Every one of them asserts a number that the reference
/// script `_verify/utilities_reference.py` prints for the upstream.

///|
test "the moment function is the difference of the two arms of the treatment" {
  let data = [[0.0, 1.0], [1.0, 2.0], [1.0, 3.0]]
  let moments = @utils.generate_moment_function(data, fn(rows) {
    let values : Array[Double] = []
    for row in rows {
      let mut sum = 0.0
      for value in row {
        sum = sum + value * value
      }
      values.push(sum)
    }
    values
  })
  assert_eq(moments.length(), 3)
  assert_eq(moments[0], 1.0)
  assert_eq(moments[1], 1.0)
  assert_eq(moments[2], 1.0)
}

///|
test "the polynomial functions raise the column to their own degree" {
  let polynomials = @utils.create_polynomial_function(3)
  assert_eq(polynomials.length(), 4)
  let data = [[2.0, 5.0], [3.0, 7.0]]
  let zeroth = polynomials[0](data)
  assert_eq(zeroth[0], 1.0)
  assert_eq(zeroth[1], 1.0)
  let first = polynomials[1](data)
  assert_eq(first[0], 2.0)
  assert_eq(first[1], 3.0)
  let second = polynomials[2](data)
  assert_eq(second[0], 4.0)
  assert_eq(second[1], 9.0)
  let third = polynomials[3](data)
  assert_eq(third[0], 8.0)
  assert_eq(third[1], 27.0)
}
