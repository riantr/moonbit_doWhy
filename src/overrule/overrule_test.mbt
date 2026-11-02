///|
/// The cases of the upstream test file `tests/causal_refuters/test_assess_overlap.py`.
///
/// The data of the upstream is a frame with two binary features and a binary
/// treatment, where the cell of the two features that are both one is empty,
/// and where the treatment only happens in the cell where both features are
/// zero.
///
/// The rules of the upstream are drawn with the global generator of numpy and
/// the rules of the port are drawn with its own generator, so the two do not
/// produce the same rules. The upstream test accepts a set of equivalent rule
/// sets for the same reason, and the port asserts that the rules are one of
/// them.
test "overrule::the_rules_of_the_upstream_fixture" {
  let x1 : Array[Double] = []
  let x2 : Array[Double] = []
  let treatment : Array[Double] = []
  for i = 0; i < 50; i = i + 1 {
    x1.push(0.0)
    x2.push(0.0)
    treatment.push(1.0)
    x1.push(0.0)
    x2.push(0.0)
    treatment.push(0.0)
    x1.push(0.0)
    x2.push(1.0)
    treatment.push(0.0)
    x1.push(1.0)
    x2.push(0.0)
    treatment.push(0.0)
  }
  let analyzer = @overrule.OverlapAnalyzer::new(
    ["X1", "X2"],
    "T",
    @overrule.SupportConfig::new(),
    @overrule.OverlapConfig::new(),
  )
  analyzer.fit([x1, x2], treatment)
  // The support rules of the upstream are one of the six rule sets the
  // upstream test accepts.
  let support = ruleset_text(analyzer.support_rules())
  assert_true(
    support == "X1:not|X1:,X2:not" ||
    support == "X1:not|X2:not,X1:" ||
    support == "X2:not|X1:not,X2:" ||
    support == "X2:not|X2:,X1:not" ||
    support == "X2:not|X1:not" ||
    support == "X1:not|X2:not",
  )
  // The overlap rules of the upstream are one of the two rule sets the upstream
  // test accepts.
  let overlap = ruleset_text(analyzer.overlap_rules())
  assert_true(overlap == "X1:not,X2:not" || overlap == "X2:not,X1:not")
  // The value of the program of the overlap rules is the one of the upstream,
  // which `_verify/overrule_reference.py` prints. The program of the support
  // rules is not comparable, because the port draws its own reference samples
  // and the program is measured against them.
  assert_true((analyzer.overlap_objective() - 0.00285).abs() < 0.000001)
  // Every row of the fixture is in the support, because the cell where the two
  // features are both one is empty.
  let indicator = analyzer.support_indicator()
  assert_eq(indicator.length(), 200)
  for value in indicator {
    assert_true(value)
  }
  // The overlap region is the cell where both features are zero, because the
  // treatment only happens there.
  let overlap_indicator = analyzer.overlap_indicator()
  let mut covered = 0
  for i = 0; i < overlap_indicator.length(); i = i + 1 {
    if overlap_indicator[i] {
      covered = covered + 1
      assert_true(x1[i] == 0.0 && x2[i] == 0.0)
    }
  }
  assert_eq(covered, 100)
}

///|
/// The text of a rule: the literals of the rule, joined by commas.
fn rule_text(rule : @overrule.Rule) -> String {
  let mut out = ""
  for i = 0; i < rule.length(); i = i + 1 {
    if i > 0 {
      out = out + ","
    }
    out = out + rule[i].feature + ":" + rule[i].operation
  }
  out
}

///|
/// The text of a rule set: the rules of the set, joined by bars.
fn ruleset_text(rules : @overrule.RuleSet) -> String {
  let mut out = ""
  for i = 0; i < rules.length(); i = i + 1 {
    if i > 0 {
      out = out + "|"
    }
    out = out + rule_text(rules[i])
  }
  out
}

///|
/// The beam search finds the conjunction of the upstream fixture.
///
/// The search of the upstream returns the conjunction of the two negations
/// with the value of `-0.499`, because the singletons of the fixture have the
/// value zero, which is not below the bound of the search.
test "overrule::the_beam_search_of_the_upstream_fixture" {
  let x1 : Array[Double] = []
  let x2 : Array[Double] = []
  let overlap : Array[Bool] = []
  for i = 0; i < 50; i = i + 1 {
    x1.push(0.0)
    x2.push(0.0)
    overlap.push(true)
    x1.push(0.0)
    x2.push(0.0)
    overlap.push(true)
    x1.push(0.0)
    x2.push(1.0)
    overlap.push(false)
    x1.push(1.0)
    x2.push(0.0)
    overlap.push(false)
  }
  let binarizer = @overrule.FeatureBinarizer::new(["X1", "X2"], 9, true)
  binarizer.fit([x1, x2])
  let data = binarizer.transform([x1, x2])
  // The literals of the fixture: the feature itself and its negation.
  assert_eq(data.literals.length(), 4)
  assert_eq(data.literals[0].feature, "X1")
  assert_eq(data.literals[0].operation.name(), "")
  assert_eq(data.literals[1].operation.name(), "not")
  assert_eq(data.literals[2].feature, "X2")
  assert_eq(data.literals[3].operation.name(), "not")
  // The residuals of the upstream: the shadow price of the rows of the overlap
  // region and the share of the rows that have to be avoided.
  let r : Array[Double] = []
  for i = 0; i < 200; i = i + 1 {
    if overlap[i] {
      r.push(-0.00502)
    } else {
      r.push(0.01)
    }
  }
  let result = @overrule.beam_search(
    r, data, 0.001, 0.001, 20, 0.0, 0.000001, 10, 20, 0.5,
  )
  assert_eq(result.values.length(), 1)
  assert_true((result.values[0] + 0.499).abs() < 0.000000001)
  // The conjunction is the one of the two negations.
  assert_eq(result.z.length(), 1)
  assert_false(result.z[0][0])
  assert_true(result.z[0][1])
  assert_false(result.z[0][2])
  assert_true(result.z[0][3])
}
