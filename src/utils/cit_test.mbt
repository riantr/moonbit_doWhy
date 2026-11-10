///|
/// The tests of the tests of the conditional independence of the columns of a
/// table.
///
/// The expected numbers are the ones the upstream of DoWhy produces on the
/// fixture of the port, which `_verify/cit_reference.py` prints.

///|
/// Whether two numbers agree to the tolerance of the comparison.
fn agrees(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-12
}

///|
/// The columns of the fixture: fifty rows of four columns.
fn fixture_columns() -> Array[Array[Double]] {
  let z : Array[Double] = []
  let x : Array[Double] = []
  let y : Array[Double] = []
  let w : Array[Double] = []
  for i in 0..<50 {
    let z_value = (i % 7).to_double() - 3.0
    let x_value = 2.0 * z_value + 0.5 * ((i % 5).to_double() - 2.0)
    z.push(z_value)
    x.push(x_value)
    y.push(1.5 * x_value + 0.3 * ((i % 3).to_double() - 1.0))
    w.push((i % 11).to_double() - 5.0)
  }
  [x, y, z, w]
}

///|
/// The text of the values of a column.
fn text_of(column : Array[Double]) -> Array[String] {
  let values : Array[String] = []
  for value in column {
    values.push(value.to_string())
  }
  values
}

///|
test "the confidence interval of a correlation is the one of the upstream" {
  let (lower, upper) = @utils.compute_ci(0.5, 200, 0.95)
  assert_true(agrees(lower, 0.38818776724780973))
  assert_true(agrees(upper, 0.59730562108214591))
  let (lower, upper) = @utils.compute_ci(0.9, 50, 0.95)
  assert_true(agrees(lower, 0.82943698455383763))
  assert_true(agrees(upper, 0.94229149858944905))
  let (lower, upper) = @utils.compute_ci(-0.3, 100, 0.95)
  assert_true(agrees(lower, -0.4687942145230049))
  assert_true(agrees(upper, -0.11006766754074288))
  let (lower, upper) = @utils.compute_ci(0.0, 47, 0.95)
  assert_true(agrees(lower, -0.28716681161902879))
  assert_true(agrees(upper, 0.28716681161902879))
}

///|
test "the partial correlation of two columns is the one of the upstream" {
  let columns = fixture_columns()
  let correlation = @utils.partial_corr(columns, 0, 1, [2], "pearson")
  assert_eq(correlation.n, 50)
  assert_true(agrees(correlation.r, 0.97479651146288571))
  assert_true(agrees(correlation.ci_lower, 0.956))
  assert_true(agrees(correlation.ci_upper, 0.986))
  assert_true(agrees(correlation.p_value, 0.0))
  let correlation = @utils.partial_corr(columns, 0, 3, [2], "pearson")
  assert_true(agrees(correlation.r, -0.04675798539267946))
  assert_true(agrees(correlation.ci_lower, -0.324))
  assert_true(agrees(correlation.ci_upper, 0.238))
  assert_true(agrees(correlation.p_value, 0.7497))
  let correlation = @utils.partial_corr(columns, 0, 3, [2, 1], "pearson")
  assert_true(agrees(correlation.r, -0.0094414927228942021))
  assert_true(agrees(correlation.ci_lower, -0.293))
  assert_true(agrees(correlation.ci_upper, 0.275))
  assert_true(agrees(correlation.p_value, 0.94922))
}

///|
test "the partial correlation of the ranks is the one of the upstream" {
  let columns = fixture_columns()
  let correlation = @utils.partial_corr(columns, 0, 3, [2], "spearman")
  assert_eq(correlation.n, 50)
  assert_true(agrees(correlation.r, -0.048695443927854618))
  assert_true(agrees(correlation.ci_lower, -0.325))
  assert_true(agrees(correlation.ci_upper, 0.236))
  assert_true(agrees(correlation.p_value, 0.73969))
}

///|
test "the entropy of a categorical variable is the one of the upstream" {
  assert_true(agrees(@utils.entropy(["0", "0", "1", "1"]), 1.0))
  assert_true(agrees(@utils.entropy(["0", "0", "0", "0"]), 0.0))
  assert_true(agrees(@utils.entropy(["a", "a", "b"]), 0.9182958340544896))
  assert_true(
    agrees(@utils.entropy(["0", "1", "2", "3", "4", "5", "6", "7"]), 3.0),
  )
}

///|
test "the conditional mutual information is the one of the upstream" {
  let columns = fixture_columns()
  let d : Array[Double] = []
  let e : Array[Double] = []
  for i in 0..<50 {
    d.push(if columns[2][i] > 0.0 { 1.0 } else { 0.0 })
    e.push(if columns[3][i] > 0.0 { 1.0 } else { 0.0 })
  }
  let information = @utils.conditional_mi([text_of(columns[2])])
  assert_true(agrees(information, -2.805678055246338))
  let information = @utils.conditional_mi([
    text_of(columns[2]),
    text_of(columns[3]),
  ])
  assert_true(agrees(information, -5.643856189774728))
  let information = @utils.conditional_mi([text_of(columns[2])])
  assert_true(agrees(information, -2.805678055246338))
}
