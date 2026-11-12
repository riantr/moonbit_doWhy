/// The tests of the two stage regression estimator.
///
/// The cases are the ones of the upstream test file
/// `tests/causal_estimators/test_two_stage_regression_estimator.py`:
///
///  * the average treatment effect test suite case: the data set of the
///    upstream `linear_dataset` with one frontdoor mediator and no common
///    cause, the estimate of the two stage regression estimator and the
///    tolerance of ten percent the upstream test allows;
///  * the frontdoor estimator case: the data set of the upstream test, the
///    estimate of the two stage regression estimator and the value of 0.45 the
///    upstream test asserts.
///
/// The numbers of the upstream are the ones
/// `_verify/two_stage_estimator_reference.py` computes with the upstream. The
/// first case runs on the rows of the port, which
/// `_verify/port_linear_dataset.py` replicates in Python, so that the two
/// implementations run on the very same rows; the second case runs on the rows
/// of the upstream test, which `_verify/gen_two_stage_estimator_testdata.py`
/// writes into `src/tests/two_stage_testdata.mbt`.
///
/// The third case of the upstream, the one that asks for an error, is ported
/// as a reported error: MoonBit cannot catch the error the estimator raises,
/// so the port aborts with the message of the upstream and
/// `CausalEstimator::two_stage_error` reports that message before the fit.
/// The cases of this file mirror the two stages of the estimator of the notebook of the upstream.  The notebook `dowhy_mediation_analysis.ipynb`.

///|
/// The tolerance the upstream estimator tests use.
const TWO_STAGE_ERROR_TOLERANCE : Double = 0.1

///|
/// The tolerance the numbers of the upstream are compared with.
const TWO_STAGE_TOLERANCE : Double = 0.000000000001

///|
/// The estimate of the upstream on the rows of the port.
const TWO_STAGE_UPSTREAM_ESTIMATE : Double = 7.358245425999947

///|
/// The estimate of the upstream on the rows of the upstream test.
const TWO_STAGE_UPSTREAM_FRONTDOOR_ESTIMATE : Double = 0.45640579505094725

///|
/// The value the upstream test of the frontdoor estimator asserts.
const TWO_STAGE_UPSTREAM_EXPECTED : Double = 0.45

///|
/// The tolerance the upstream test of the frontdoor estimator allows.
const TWO_STAGE_UPSTREAM_TOLERANCE : Double = 0.025

///|
/// The graph of the upstream test of the frontdoor estimator, character for
/// character.
///
/// The upstream removes the newlines of the string, so the graph it reads is
/// one long line.
fn two_stage_frontdoor_graph() -> String {
  let lines = [
    "", "        graph [", "            directed 1", "            ", "            node [",
    "                id \"X\" ", "                label \"X\"", "            ]    ",
    "            node [", "                id \"Z\"", "                label \"Z\"",
    "            ]", "            node [", "                id \"Y\"", "                label \"Y\"",
    "            ]", "            node [", "                id \"U\"", "                label \"U\"",
    "            ]", "            ", "            edge [", "                source \"X\"",
    "                target \"Z\"", "            ]", "            ", "            edge [",
    "                source \"Z\"", "                target \"Y\"", "            ]",
    "            ", "            edge [", "                source \"U\"", "                target \"Y\"",
    "            ]", "            ", "            edge [", "                source \"U\"",
    "                target \"X\"", "            ]", "        ]", "        ",
  ]
  lines.join("")
}

///|
/// The data set of the average treatment effect test suite case of the upstream.
///
/// The configuration is the one of the upstream test: a treatment effect of
/// ten, one frontdoor mediator, no common cause, no instrument, no effect
/// modifier, a continuous treatment and a continuous outcome.
fn two_stage_dataset() -> @datasets.Dataset {
  two_stage_dataset_with(0, 1, 1)
}

///|
/// The data set of the upstream test with the given number of common causes,
/// of treatments and of frontdoor mediators.
fn two_stage_dataset_with(
  num_common_causes : Int32,
  num_treatments : Int32,
  num_frontdoor_variables : Int32,
) -> @datasets.Dataset {
  @datasets.linear_dataset(
    SEED,
    NUM_SAMPLES,
    @datasets.LinearConfig::new(
      beta=10.0,
      num_common_causes~,
      num_instruments=0,
      num_effect_modifiers=0,
      num_frontdoor_variables~,
      num_treatments~,
      treatment_is_binary=false,
      outcome_is_binary=false,
    ),
  )
}

///|
/// The model of the average treatment effect test suite case of the upstream.
///
/// The upstream reads the graph of the data set from its GML string, because
/// the graph of a data set with a frontdoor mediator holds no edge between the
/// treatment and the outcome.
fn two_stage_model() -> @moonbit_dowhy.CausalModel {
  two_stage_model_of(two_stage_dataset())
}

///|
/// The model of the given data set.
fn two_stage_model_of(
  dataset : @datasets.Dataset,
) -> @moonbit_dowhy.CausalModel {
  @moonbit_dowhy.CausalModel::new_with_graph_string(
    dataset.frame(),
    dataset.treatments(),
    [dataset.outcome()],
    dataset.gml_graph(),
    dataset.common_causes(),
    dataset.instruments(),
    dataset.effect_modifiers(),
  )
}

///|
/// The model of the frontdoor estimator case of the upstream.
fn two_stage_frontdoor_model() -> @moonbit_dowhy.CausalModel {
  @moonbit_dowhy.CausalModel::new_with_graph_string(
    two_stage_frame(),
    ["X"],
    ["Y"],
    two_stage_frontdoor_graph(),
    [],
    [],
    [],
  )
}

///|
/// Whether the two lists hold the same names.
fn two_stage_same_names(left : Array[String], right : Array[String]) -> Bool {
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
fn two_stage_registry_variables(
  registry : Map[String, Array[String]],
  key : String,
) -> Array[String] {
  match registry.get(key) {
    Some(variables) => variables
    None => []
  }
}

///|
test "the two stage regression estimator recovers the effect of the data set of the upstream" {
  let model = two_stage_model()
  let estimate = model.estimate_effect(
    "frontdoor.two_stage_regression", 1.0, 0.0, "ate",
  )
  // The upstream computes the same number on the very same rows.
  let error = (estimate.estimate() - TWO_STAGE_UPSTREAM_ESTIMATE).abs()
  assert_true(error < TWO_STAGE_TOLERANCE)
  // The upstream test asserts that the error is below ten percent of the true
  // average treatment effect of the data set.
  let truth = two_stage_dataset().average_treatment_effect()
  let error = (estimate.estimate() - truth).abs()
  assert_true(error < truth.abs() * TWO_STAGE_ERROR_TOLERANCE)
}

///|
test "the identification of the data set of the upstream finds the frontdoor variable" {
  let model = two_stage_model()
  let estimand = model.identify_effect("frontdoor")
  assert_true(two_stage_same_names(estimand.get_frontdoor_variables(), ["FD0"]))
  // The upstream finds the same confounders for the two stages: the first
  // stage regresses the mediator on the treatment and needs none, the second
  // stage regresses the outcome on the mediator and needs none either, because
  // the graph holds no backdoor path between them.
  let first = estimand.get_mediation_first_stage_confounders()
  assert_true(
    two_stage_same_names(two_stage_registry_variables(first, "backdoor"), []),
  )
  let second = estimand.get_mediation_second_stage_confounders()
  assert_true(
    two_stage_same_names(two_stage_registry_variables(second, "backdoor"), []),
  )
}

///|
test "the two stages of the estimator are the ones of the upstream" {
  let model = two_stage_model()
  let _ = model.estimate_effect(
    "frontdoor.two_stage_regression", 1.0, 0.0, "ate",
  )
  let estimator = model.get_estimator("frontdoor.two_stage_regression")
  match estimator {
    Some(fitted) => {
      let (first, second) = fitted.two_stage_features()
      // The first stage regresses the mediator on the treatment, the second
      // stage regresses the outcome on the mediator.
      assert_true(two_stage_same_names(first, ["const", "v0"]))
      assert_true(two_stage_same_names(second, ["const", "FD0"]))
    }
    None => abort("the estimator was not cached")
  }
}

///|
test "the two stage regression estimator reports the errors of the upstream" {
  // The upstream raises an error when the estimand holds more than one
  // treatment variable, and it raises one when the identification finds no
  // frontdoor variable. MoonBit cannot catch an error, so the port reports the
  // message of the upstream and aborts with it.
  let many_treatments = two_stage_dataset_with(1, 2, 1)
  let model = two_stage_model_of(many_treatments)
  let estimand = model.identify_effect("frontdoor")
  let estimator = @estimators.CausalEstimator::two_stage_regression(estimand)
  assert_eq(
    estimator.two_stage_error(),
    "The estimator cannot handle more than one treatment variable",
  )
  let many_frontdoors = two_stage_dataset_with(1, 1, 2)
  let model = two_stage_model_of(many_frontdoors)
  let estimand = model.identify_effect("frontdoor")
  // The upstream finds no frontdoor variable for that graph either: the
  // mediators and the treatment share a common cause, so the second condition
  // of the frontdoor criterion fails for every set of them.
  assert_eq(estimand.get_frontdoor_variables().length(), 0)
  let estimator = @estimators.CausalEstimator::two_stage_regression(estimand)
  assert_eq(
    estimator.two_stage_error(),
    "No front-door variable present. Two stage regression is not applicable",
  )
}

///|
test "the two stage regression estimator reproduces the estimate of the upstream frontdoor test" {
  let model = two_stage_frontdoor_model()
  let estimate = model.estimate_effect(
    "frontdoor.two_stage_regression", 1.0, 0.0, "ate",
  )
  // The upstream computes the same number on the very same rows.
  let error = (estimate.estimate() - TWO_STAGE_UPSTREAM_FRONTDOOR_ESTIMATE).abs()
  assert_true(error < TWO_STAGE_TOLERANCE)
  // The upstream test asserts the value of 0.45 with a tolerance of 0.025.
  let error = (estimate.estimate() - TWO_STAGE_UPSTREAM_EXPECTED).abs()
  assert_true(error < TWO_STAGE_UPSTREAM_TOLERANCE)
}

///|
test "the identification of the frontdoor test of the upstream finds the mediator" {
  let model = two_stage_frontdoor_model()
  let estimand = model.identify_effect("frontdoor")
  assert_true(two_stage_same_names(estimand.get_frontdoor_variables(), ["Z"]))
  // The upstream finds the same confounders for the two stages: the first
  // stage regresses the mediator on the treatment and needs none, the second
  // stage regresses the outcome on the mediator and needs the treatment,
  // because the unobserved variable is a common cause of the two.
  let first = estimand.get_mediation_first_stage_confounders()
  assert_true(
    two_stage_same_names(two_stage_registry_variables(first, "backdoor"), []),
  )
  let second = estimand.get_mediation_second_stage_confounders()
  assert_true(
    two_stage_same_names(two_stage_registry_variables(second, "backdoor"), ["X"]),
  )
}

///|
test "the two stages of the frontdoor test of the upstream are the ones of the upstream" {
  let model = two_stage_frontdoor_model()
  let _ = model.estimate_effect(
    "frontdoor.two_stage_regression", 1.0, 0.0, "ate",
  )
  let estimator = model.get_estimator("frontdoor.two_stage_regression")
  match estimator {
    Some(fitted) => {
      let (first, second) = fitted.two_stage_features()
      // The first stage regresses the mediator on the treatment, the second
      // stage regresses the outcome on the mediator and on the treatment.
      assert_true(two_stage_same_names(first, ["const", "X"]))
      assert_true(two_stage_same_names(second, ["const", "Z", "X"]))
    }
    None => abort("the estimator was not cached")
  }
}
