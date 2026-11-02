"""The shared estimand of the refuter tests.

The upstream test suite identifies the effect with the exhaustive search of the
backdoor criterion and then sets the identifier method of the case, so the
helper takes the identifier method as an argument.
"""

import io
import sys

FIXTURES = r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\src\tests\fixtures.mbt"
PLACEBO = r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\src\tests\placebo_refuter.mbt"

FIXTURES_OLD = """///|
/// The estimand of the data set, identified with the backdoor criterion.
fn backdoor_estimand(
  dataset : @datasets.Dataset,
) -> @identifiers.IdentifiedEstimand {
"""

FIXTURES_NEW = """///|
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
"""

PLACEBO_OLD = """///|
/// The estimand of the upstream test: the exhaustive search of the backdoor
/// criterion, with the method of the backdoor criterion.
fn placebo_estimand(
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
  let estimand = @identifiers.identify_effect_auto(
    graph,
    dataset.treatments(),
    [dataset.outcome()],
    dataset.observed_nodes(),
    "nonparametric-ate",
    @identifiers.BACKDOOR_EXHAUSTIVE,
  )
  estimand.set_identifier_method("backdoor")
  estimand
}

"""

text = io.open(FIXTURES, encoding="utf-8").read()
if text.count(FIXTURES_OLD) != 1:
    sys.exit("the fixtures marker was not found exactly once")
text = text.replace(FIXTURES_OLD, FIXTURES_NEW)
io.open(FIXTURES, "w", encoding="utf-8", newline="\n").write(text)

text = io.open(PLACEBO, encoding="utf-8").read()
if text.count(PLACEBO_OLD) != 1:
    sys.exit("the placebo marker was not found exactly once")
text = text.replace(PLACEBO_OLD, "")
text = text.replace("placebo_estimand(dataset)", 'exhaustive_estimand(dataset, "backdoor")')
io.open(PLACEBO, "w", encoding="utf-8", newline="\n").write(text)
print("patched")
