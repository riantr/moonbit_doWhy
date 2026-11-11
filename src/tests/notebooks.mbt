/// The tests of the scenarios of the notebooks of the upstream.
///
/// This is the port of `tests/test_notebooks.py` of the upstream. The upstream
/// executes the notebooks of its documentation and asserts that no cell of
/// them fails; the port runs the scenarios of the notebooks as test cases and
/// asserts the numbers they compute.
///
/// The port mirrors the notebooks of the portable core: the causal API of the
/// notebook `dowhy_causal_api.ipynb`, the interpreter of the notebook
/// `dowhy_interpreter.ipynb` and the basic graphical causal model of the
/// notebook `gcm_basic_example.ipynb`. The other notebooks of the upstream
/// walk through the features the tests of the port cover one by one, or
/// through the features the port does not have, like the estimators of
/// `econml`.

///|
/// The data set of the notebook of the causal API.
///
/// This is the port of the fixture of `dowhy_causal_api.ipynb`: a treatment
/// effect of five, one common cause, no instrument, a binary treatment and a
/// thousand rows.
fn notebook_causal_api_dataset() -> @datasets.Dataset {
  @datasets.linear_dataset(
    42,
    1000,
    @datasets.LinearConfig::new(
      beta=5.0,
      num_common_causes=1,
      num_instruments=0,
      num_effect_modifiers=0,
      num_frontdoor_variables=0,
      num_treatments=1,
      num_discrete_common_causes=0,
      num_discrete_effect_modifiers=0,
      treatment_is_binary=true,
      outcome_is_binary=false,
    ),
  )
}

///|
/// The data of the notebook of the basic graphical causal model.
///
/// This is the port of the fixture of `gcm_basic_example.ipynb`: a thousand
/// rows of three nodes, `X`, `Y` and `Z`, where `Y` is twice `X` plus the
/// noise and `Z` is three times `Y` plus the noise.
fn notebook_gcm_data() -> @api.DataFrame {
  let generator = @utils.NumpyRandom::new(42)
  let x = generator.randn(1000, 1)
  let noise_of_y = generator.randn(1000, 1)
  let noise_of_z = generator.randn(1000, 1)
  let y : Array[Double] = []
  let z : Array[Double] = []
  for i in 0..<1000 {
    let value_of_x = x.get(i, 0)
    let value_of_y = 2.0 * value_of_x + noise_of_y.get(i, 0)
    y.push(value_of_y)
    z.push(3.0 * value_of_y + noise_of_z.get(i, 0))
  }
  @api.DataFrame::from_numeric(
    ["X", "Y", "Z"],
    Map([("X", x.col(0)), ("Y", y), ("Z", z)]),
  )
}

///|
test "the causal api of the upstream runs the do operator on the data" {
  let dataset = notebook_causal_api_dataset()
  let frame = dataset.frame()
  let treatment = dataset.treatments()[0]
  let outcome = dataset.outcome()
  let cause = dataset.common_causes()[0]
  // The notebook of the upstream intervenes on the treatment at one and at
  // zero and compares the two outcomes.
  let treated = @do_samplers.do_sample(
    frame,
    None,
    [treatment],
    [outcome],
    Map([]),
    [cause],
    "weighting",
    @utils.Random::new(42),
    treatment_values=Map([(treatment, 1.0)]),
  )
  let control = @do_samplers.do_sample(
    frame,
    None,
    [treatment],
    [outcome],
    Map([]),
    [cause],
    "weighting",
    @utils.Random::new(42),
    treatment_values=Map([(treatment, 0.0)]),
  )
  assert_eq(treated.nrows(), 1000)
  assert_eq(control.nrows(), 1000)
  let difference = treated.mean(outcome) - control.mean(outcome)
  // The effect of the fixture is five, so the difference of the two means is
  // the effect up to the noise of the sampler. The script
  // `_verify/notebooks_reference.py` prints the difference of the upstream,
  // which is 4.9096695443447205.
  assert_true(difference > 3.0)
  assert_true(difference < 7.0)
}

///|
test "the interpreter of the upstream reads the estimate of the propensity score" {
  let dataset = @datasets.linear_dataset(
    42,
    1000,
    @datasets.LinearConfig::five_common_causes_one_instrument(),
  )
  let model = @moonbit_dowhy.CausalModel::new(
    dataset.frame(),
    dataset.treatments(),
    [dataset.outcome()],
    None,
    dataset.common_causes(),
    dataset.instruments(),
    dataset.effect_modifiers(),
    dataset.frontdoor_variables(),
  )
  let estimand = model.identify_effect("backdoor")
  let adjustment = estimand.get_adjustment_set(estimand.identifier_method())
  assert_true(adjustment.length() > 0)
  let estimate = model.estimate_effect(
    "backdoor.propensity_score_stratification",
    1.0,
    0.0,
    "ate",
    effect_modifier_names=[],
  )
  // The script `_verify/notebooks_reference.py` prints the estimate of the
  // upstream, which is 1.002648087451465.
  assert_true(estimate.estimate() > 0.0)
  match model.interpret(Some(estimate)) {
    Some(text) => assert_true(text.length() > 0)
    None => abort("the interpretation of the estimate is missing")
  }
}

///|
test "the basic gcm of the upstream assigns the mechanisms and samples from the model" {
  let graph = @graph.DirectedGraph::new()
  graph.add_node("X")
  graph.add_node("Y")
  graph.add_node("Z")
  graph.add_edge("X", "Y")
  graph.add_edge("Y", "Z")
  let data = notebook_gcm_data()
  let model = @gcm.ProbabilisticCausalModel::new(graph)
  // The notebook of the upstream assigns the mechanisms of the nodes
  // automatically and it prints the summary of the assignment.
  let summary = @gcm.assign_causal_mechanisms(
    model,
    data,
    @gcm.AssignmentQuality::good(),
    false,
    seed=42UL,
  )
  assert_eq(summary.nodes().length(), 3)
  assert_true(summary.messages_of("Y").length() > 0)
  assert_eq(summary.model_performances_of("Y").length(), 2)
  // The notebook of the upstream fits the model and it samples from it under
  // an intervention on the middle node.
  @gcm.fit(model, data)
  let samples = @gcm.interventional_samples(
    model,
    Map([("Y", @gcm.set_number(2.34))]),
    None,
    Some(100),
    @utils.Random::new(42),
  )
  assert_eq(samples.nrows(), 100)
  // The intervention sets the middle node to the number it names, and the
  // script `_verify/notebooks_reference.py` prints the mean of the samples of
  // the upstream, which is 2.34 for the middle node.
  let values_of_y = samples.numeric("Y")
  for value in values_of_y {
    assert_true((value - 2.34).abs() < 0.000000001)
  }
}
