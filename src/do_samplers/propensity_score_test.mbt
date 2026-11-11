///|
/// The cases of the propensity score of a treatment.
///
/// The upstream has no test file for `dowhy.utils.propensity_score`, so the
/// cases of the port are its own. Every one of them asserts a number that the
/// reference script `_verify/utilities_reference.py` prints for the upstream.

///|
test "the propensity of a treatment is the probability of the class one" {
  let frame = @api.DataFrame::new(
    ["x", "y"],
    Map([
      ("x", @api.Column::numeric([0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0])),
      ("y", @api.Column::numeric([1.0, 0.0, 1.0, 1.0, 0.0, 1.0, 1.0, 0.0])),
    ]),
  )
  let types = @do_samplers.variable_types([("x", "c"), ("y", "c")])
  let scores = @do_samplers.propensity_of_treatment_score(
    frame,
    ["x"],
    "y",
    types,
  )
  assert_eq(scores.length(), 8)
  // The scores of the upstream are 0.66486279 and 0.58527909. The upstream
  // fits the regression with the lbfgs solver of scikit-learn and the port
  // fits it with the iteration of the utils package.
  assert_true((scores[0] - 0.66486279).abs() < 0.001)
  assert_true((scores[1] - 0.58527909).abs() < 0.001)
}
