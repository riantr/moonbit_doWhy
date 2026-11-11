/// The regression helpers of the upstream.
///
/// This is the port of `dowhy.utils.regression`: the moment function of a
/// treatment and the polynomial functions a moment function is built with.
///
/// The upstream finds the numeric features of a data set as well. The helper
/// needs a data frame, and the `utils` package of the port has no dependency
/// on the `api` package, so the helper is the public function
/// `api::numeric_feature_indices`.

///|
/// The moment function of a treatment.
///
/// This is the port of `dowhy.utils.regression.generate_moment_function`: the
/// function is applied to the data of the two arms of the treatment, which is
/// the first column of the data, and the difference of the two answers is the
/// moment function.
///
/// The comment of the upstream calls the data of the arm zero the data of the
/// arm one and the other way round; the code of the upstream does the opposite
/// of its comment, and the port does the same.
pub fn generate_moment_function(
  data : Array[Array[Double]],
  g : (Array[Array[Double]]) -> Array[Double],
) -> Array[Double] {
  let control : Array[Array[Double]] = []
  let treated : Array[Array[Double]] = []
  for row in data {
    let rest : Array[Double] = []
    for column = 1; column < row.length(); column = column + 1 {
      rest.push(row[column])
    }
    control.push(prepend(0.0, rest))
    treated.push(prepend(1.0, rest))
  }
  let high = g(treated)
  let low = g(control)
  let moments : Array[Double] = []
  for row = 0; row < high.length(); row = row + 1 {
    moments.push(high[row] - low[row])
  }
  moments
}

///|
/// The row of a treatment that holds the given value of the treatment.
fn prepend(value : Double, rest : Array[Double]) -> Array[Double] {
  let row : Array[Double] = [value]
  for item in rest {
    row.push(item)
  }
  row
}

///|
/// The polynomial functions of the degrees zero to the given degree.
///
/// This is the port of `dowhy.utils.regression.create_polynomial_function`:
/// every function of the list raises the first column of the data to its own
/// degree.
///
/// The upstream closes over the loop variable of its own loop, and every
/// function of the list it returns raises the column to the highest degree of
/// the list. The port closes over the degree of its own function, so every
/// function of the list raises the column to its own degree.
pub fn create_polynomial_function(
  max_degree : Int32,
) -> Array[(Array[Array[Double]]) -> Array[Double]] {
  let functions : Array[(Array[Array[Double]]) -> Array[Double]] = []
  for degree in 0..<=max_degree {
    let power = degree
    functions.push(fn(data) {
      let values : Array[Double] = []
      for row in data {
        values.push(power_of(row[0], power))
      }
      values
    })
  }
  functions
}

///|
/// The number raised to the given degree.
///
/// The degree is a whole number that is not negative, so the power is a
/// product, which is exact.
fn power_of(value : Double, degree : Int32) -> Double {
  let mut result = 1.0
  for _ in 0..<degree {
    result = result * value
  }
  result
}
