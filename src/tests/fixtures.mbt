/// The fixtures the estimator and the refuter tests share.

///|
/// The number of rows the tests draw.
const NUM_SAMPLES : Int32 = 2000

///|
/// The seed the tests use.
const SEED : Int32 = 42

///|
/// The confounded data set the tests run on.
fn confounded() -> @datasets.Dataset {
  @datasets.linear_dataset(
    SEED,
    NUM_SAMPLES,
    @datasets.LinearConfig::confounded(),
  )
}

///|
/// The estimand of the refuter tests.
///
/// This is the estimand of the upstream test suite: the exhaustive search of the
/// backdoor criterion, with the identifier method of the case.
fn exhaustive_estimand(
  dataset : @datasets.Dataset,
  identifier_method : String,
) -> @identifiers.IdentifiedEstimand {
  let graph = @graph.build_graph(
    dataset.treatments(),
    [dataset.outcome()],
    dataset.common_causes(),
    dataset.instruments(),
    dataset.effect_modifiers(),
    dataset.frontdoor_variables(),
  )
  let estimand = @identifiers.identify_effect_auto(
    graph,
    dataset.treatments(),
    [dataset.outcome()],
    dataset.observed_nodes(),
    "nonparametric-ate",
    @identifiers.BACKDOOR_EXHAUSTIVE,
  )
  estimand.set_identifier_method(identifier_method)
  estimand
}

///|
/// The estimand of the data set, identified with the backdoor criterion.
fn backdoor_estimand(
  dataset : @datasets.Dataset,
) -> @identifiers.IdentifiedEstimand {
  let graph = @graph.build_graph(
    dataset.treatments(),
    [dataset.outcome()],
    dataset.common_causes(),
    dataset.instruments(),
    dataset.effect_modifiers(),
    dataset.frontdoor_variables(),
  )
  @identifiers.identify_effect_auto(
    graph,
    dataset.treatments(),
    [dataset.outcome()],
    dataset.observed_nodes(),
    "nonparametric-ate",
    @identifiers.BACKDOOR_DEFAULT,
  )
}
