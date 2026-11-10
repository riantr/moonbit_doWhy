/// The tests of the interpreters.
///
/// The upstream has no test file for its interpreters, so the expected text of
/// the port is the text the upstream writes on the fixture of the port, which
/// the script `_verify/interpreter_reference.py` prints.

///|
/// The frame of the fixture of the interpreters.
///
/// This is the frame of the script `_verify/interpreter_reference.py`: sixty
/// rows of a treatment, of a common cause and of an outcome.
fn interpreter_frame() -> @api.DataFrame {
  let v : Array[Double] = []
  let w : Array[Double] = []
  let y : Array[Double] = []
  for i in 0..<60 {
    let w_value = (i % 7).to_double() - 3.0
    let v_value = (i % 2).to_double()
    let noise = ((i % 5).to_double() - 2.0) * 0.25
    v.push(v_value)
    w.push(w_value)
    y.push(2.0 * v_value + 0.5 * w_value + noise)
  }
  @api.DataFrame::from_numeric(
    ["v0", "W0", "y"],
    Map([("v0", v), ("W0", w), ("y", y)]),
  )
}

///|
test "the interpretation of an estimate is the sentence of the upstream" {
  let estimate = @model.CausalEstimate::new(
    1.9999297752808973, "v0", "y", "backdoor", 0.0, 1.0,
  )
  let text = @interpreters.textual_effect_interpretation(
    estimate,
    interpreter_frame(),
  )
  match text {
    Some(sentence) =>
      assert_eq(
        sentence, "Increasing the treatment variable(s) [v0] from 0 to 1 causes an increase of 1.9999297752808973 in the expected value of the outcome [y], over the data distribution/population represented by the dataset.",
      )
    None => assert_true(false)
  }
}

///|
test "the interpretation of a categorical treatment is refused" {
  let estimate = @model.CausalEstimate::new(
    1.9999297752808973, "v0", "y", "backdoor", 0.0, 1.0,
  )
  let frame = interpreter_frame()
  let with_a_category = @api.DataFrame::new(
    ["v0", "W0", "y"],
    Map([
      ("v0", @api.Column::discrete(["a", "b"])),
      ("W0", @api.Column::numeric(frame.numeric("W0"))),
      ("y", @api.Column::numeric(frame.numeric("y"))),
    ]),
  )
  let text = @interpreters.textual_effect_interpretation(
    estimate, with_a_category,
  )
  match text {
    Some(_) => assert_true(false)
    None => assert_true(true)
  }
}
