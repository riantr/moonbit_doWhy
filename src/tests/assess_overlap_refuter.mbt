/// Tests for the refuter that assesses the support and the overlap.
///
/// The cases mirror the upstream test file
/// (`tests/causal_refuters/test_assess_overlap.py`): the support rules have to
/// describe the region the data cover, and the overlap rules have to describe
/// the region where the treatment and the control overlap.
///
/// The upstream draws the reference samples with the global generator of numpy
/// and the port draws them with its own generator, so the two do not produce
/// the same rules. The upstream test accepts a set of equivalent rule sets for
/// the same reason, and the port asserts that the rules are one of them.

///|
/// The data set of the upstream test file.
///
/// The data has two binary features and a binary treatment, where the cell of
/// the two features that are both one is empty, and where the treatment only
/// happens in the cell where both features are zero.
fn overlap_dataset() -> @api.DataFrame {
  let x1 : Array[Double] = []
  let x2 : Array[Double] = []
  let treatment : Array[Double] = []
  let outcome : Array[Double] = []
  for i = 0; i < 50; i = i + 1 {
    x1.push(0.0)
    x2.push(0.0)
    treatment.push(1.0)
    outcome.push(0.0)
    x1.push(0.0)
    x2.push(0.0)
    treatment.push(0.0)
    outcome.push(1.0)
    x1.push(0.0)
    x2.push(1.0)
    treatment.push(0.0)
    outcome.push(0.0)
    x1.push(1.0)
    x2.push(0.0)
    treatment.push(0.0)
    outcome.push(0.0)
  }
  @api.DataFrame::from_numeric(
    ["X1", "X2", "T", "Y"],
    Map([("X1", x1), ("X2", x2), ("T", treatment), ("Y", outcome)]),
  )
}

///|
/// The model of the data set, with the graph derived from the semantic roles of
/// the variables.
fn overlap_model() -> @moonbit_dowhy.CausalModel {
  @moonbit_dowhy.CausalModel::new(
    overlap_dataset(),
    ["T"],
    ["Y"],
    None,
    ["X1", "X2"],
    [],
    [],
    [],
  )
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
/// The rule sets of the support that the upstream test accepts.
fn accepted_support_rules() -> Array[String] {
  [
    "X1:not|X1:,X2:not", "X1:not|X2:not,X1:", "X2:not|X1:not,X2:", "X2:not|X2:,X1:not",
    "X2:not|X1:not", "X1:not|X2:not",
  ]
}

///|
/// The rule sets of the overlap that the upstream test accepts.
fn accepted_overlap_rules() -> Array[String] {
  ["X1:not,X2:not", "X2:not,X1:not"]
}

///|
/// Whether the text of the rules is one of the accepted ones.
fn is_accepted(text : String, accepted : Array[String]) -> Bool {
  for candidate in accepted {
    if text == candidate {
      return true
    }
  }
  false
}

///|
test "the support rules of the upstream fixture describe the region the data cover" {
  let model = overlap_model()
  let _ = model.identify_effect("backdoor")
  let _ = model.estimate_effect("backdoor.linear_regression", 1.0, 0.0, "ate")
  let analyzer = model.refute_assess_overlap()
  let support = ruleset_text(analyzer.support_rules())
  assert_true(is_accepted(support, accepted_support_rules()))
  // Every row of the fixture is in the support, because the cell where the two
  // features are both one is empty.
  let indicator = analyzer.support_indicator()
  assert_eq(indicator.length(), 200)
  for value in indicator {
    assert_true(value)
  }
}

///|
test "the overlap rules of the upstream fixture describe the region of the treatment" {
  let model = overlap_model()
  let _ = model.identify_effect("backdoor")
  let _ = model.estimate_effect("backdoor.linear_regression", 1.0, 0.0, "ate")
  let analyzer = model.refute_assess_overlap()
  let overlap = ruleset_text(analyzer.overlap_rules())
  assert_true(is_accepted(overlap, accepted_overlap_rules()))
  // The overlap region is the cell where both features are zero, because the
  // treatment only happens there.
  let indicator = analyzer.overlap_indicator()
  assert_eq(indicator.length(), 200)
  let x1 = model.data().numeric("X1")
  let x2 = model.data().numeric("X2")
  let mut covered = 0
  for i = 0; i < indicator.length(); i = i + 1 {
    if indicator[i] {
      covered = covered + 1
      assert_true(x1[i] == 0.0 && x2[i] == 0.0)
    }
  }
  assert_eq(covered, 100)
}

///|
test "the refuter of the overlap finds the rows the support and the overlap cover" {
  let model = overlap_model()
  let _ = model.identify_effect("backdoor")
  let analyzer = model.refute_assess_overlap()
  let rows = analyzer.predict_overlap_support([
    model.data().numeric("X1"),
    model.data().numeric("X2"),
  ])
  assert_eq(rows.length(), 200)
  let mut covered = 0
  for i = 0; i < rows.length(); i = i + 1 {
    if rows[i] {
      covered = covered + 1
    }
  }
  assert_eq(covered, 100)
}
