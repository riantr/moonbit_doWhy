/// The integration test of the two stage regression estimator.
///
/// The case is the one of the upstream test `test_dowhy_chapter_7` of the file
/// `tests/causal-inference-discovery-book/test_causal_inference_discovery_book.py`,
/// the one of the chapter 7 of the book "Causal Inference and Discovery in
/// Python": the treatment `X` has the mediator `Z` and the outcome `Y`, and
/// the unobserved variable `U` is a common cause of the treatment and of the
/// outcome.
///
/// The rows are the rows of the upstream test, and the numbers of the estimate
/// are the ones `_verify/two_stage_reference.py` computes with the upstream on
/// those rows.

///|
/// The tolerance the numbers of the upstream are compared with.
///
/// The port and the upstream agree on the estimate of the two stage regression
/// to about `5e-14`, so the tolerance leaves a margin of two orders of
/// magnitude.
const TOLERANCE : Double = 0.000000000001

///|
/// The estimate of the upstream.
const UPSTREAM_ESTIMATE : Double = -0.417448516953309

///|
/// The graph of the upstream test, character for character.
fn book_gml_graph() -> String {
  let lines = [
    "", "        graph [", "            directed 1", "            ", "            node [",
    "                id \"X\" ", "                label \"X\"", "            ]     ",
    "            node [", "                id \"Z\"", "                label \"Z\"",
    "            ]", "            node [", "                id \"Y\"", "                label \"Y\"",
    "            ]", "            node [", "                id \"U\"", "                label \"U\"",
    "            ]", "            ", "            edge [", "                source \"X\"",
    "                target \"Z\"", "            ]", "            edge [", "                source \"Z\"",
    "                target \"Y\"", "            ]", "            edge [", "                source \"U\"",
    "                target \"X\"", "            ]", "            edge [", "                source \"U\"",
    "                target \"Y\"", "            ]", "        ]", "        ",
  ]
  lines.join("\n")
}

///|
/// The model of the upstream test.
fn book_model() -> @moonbit_dowhy.CausalModel {
  @moonbit_dowhy.CausalModel::new_with_graph_string(
    @tests.book_memory_frame(),
    ["X"],
    ["Y"],
    book_gml_graph(),
    [],
    [],
    [],
  )
}

///|
/// Whether the two lists hold the same names.
fn book_same_names(left : Array[String], right : Array[String]) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for name in left {
    if !right.contains(name) {
      return false
    }
  }
  true
}

///|
/// The variables of the registry under the given key.
fn registry_variables(
  registry : Map[String, Array[String]],
  key : String,
) -> Array[String] {
  match registry.get(key) {
    Some(variables) => variables
    None => []
  }
}

///|
test "the identification of the book test finds the frontdoor variable" {
  let model = book_model()
  let estimand = model.identify_effect("frontdoor")
  assert_true(book_same_names(estimand.get_frontdoor_variables(), ["Z"]))
  // The upstream finds the same confounders for the two stages: the first
  // stage regresses the mediator on the treatment and needs none, the second
  // stage regresses the outcome on the mediator and needs the treatment.
  let first = estimand.get_mediation_first_stage_confounders()
  assert_true(book_same_names(registry_variables(first, "backdoor"), []))
  assert_true(book_same_names(registry_variables(first, "backdoor1"), []))
  let second = estimand.get_mediation_second_stage_confounders()
  assert_true(book_same_names(registry_variables(second, "backdoor"), ["X"]))
  assert_true(book_same_names(registry_variables(second, "backdoor1"), ["X"]))
  assert_true(book_same_names(registry_variables(second, "backdoor2"), ["X"]))
}

///|
test "the two stage regression estimator reproduces the estimate of the upstream" {
  let model = book_model()
  let estimate = model.estimate_effect(
    "frontdoor.two_stage_regression", 1.0, 0.0, "ate",
  )
  let error = (estimate.estimate() - UPSTREAM_ESTIMATE).abs()
  assert_true(error < TOLERANCE)
}

///|
test "the mediation method name estimates the same effect" {
  let model = book_model()
  let estimate = model.estimate_effect(
    "mediation.two_stage_regression", 1.0, 0.0, "ate",
  )
  // The mediator of the graph is the frontdoor variable of the graph as well,
  // so the two stages of the mediation are the two stages of the frontdoor.
  let error = (estimate.estimate() - UPSTREAM_ESTIMATE).abs()
  assert_true(error < TOLERANCE)
}

///|
test "the two stages of the estimator are the ones of the upstream" {
  let model = book_model()
  let _ = model.estimate_effect(
    "frontdoor.two_stage_regression", 1.0, 0.0, "ate",
  )
  let estimator = model.get_estimator("frontdoor.two_stage_regression")
  match estimator {
    Some(fitted) => {
      let (first, second) = fitted.two_stage_features()
      // The first stage regresses the mediator on the treatment, the second
      // stage regresses the outcome on the mediator and on the treatment.
      assert_true(book_same_names(first, ["const", "X"]))
      assert_true(book_same_names(second, ["const", "Z", "X"]))
    }
    None => abort("the estimator was not cached")
  }
}

///|
test "the refutation of the book test runs on the two stage estimate" {
  let model = book_model()
  let estimate = model.estimate_effect(
    "frontdoor.two_stage_regression", 1.0, 0.0, "ate",
  )
  let refutation = model.refute_estimate(
    "frontdoor.two_stage_regression",
    estimate,
    "subset",
    10,
    @utils.Random::new(31),
  )
  // A subset of the data holds the effect of the whole data, the way the
  // upstream holds it; the numbers of the refutation itself differ, because
  // the two implementations draw their subsets from different generators.
  let error = (refutation.new_effect() - UPSTREAM_ESTIMATE).abs()
  assert_true(error < UPSTREAM_ESTIMATE.abs() * 0.5)
  assert_eq(refutation.refutation_type(), "Refute: Use a subset of data")
  assert_true(refutation.new_effect_lower() <= refutation.new_effect_upper())
}
