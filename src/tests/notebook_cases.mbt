/// The tests of the scenarios of the notebooks of the upstream.
///
/// This is the port of the test file `tests/test_notebooks.py` of the upstream.
/// The upstream executes every notebook of its documentation with `jupyter
/// nbconvert` and asserts that no cell of it fails; the port runs the
/// scenario of the notebook as a test case and asserts the conclusion the
/// notebook demonstrates.
///
/// The scenarios of the notebooks that come from `dowhy.datasets.linear_dataset`
/// are not the data sets of the port: the port draws them with a generator of
/// its own, so the numbers of those notebooks are the numbers of the port and
/// the cases assert the conclusion of the notebook, which is the same
/// conclusion. The script `_verify/notebooks_reference.py` prints the numbers
/// of the upstream for every scenario of this file.
///
/// The notebooks this file mirrors are:
///
/// * `dowhy_estimation_methods.ipynb` -- the eight estimators of the upstream
///   on one data set;
/// * `dowhy_simple_example.ipynb` -- the estimate and the refuters;
/// * `dowhy_demo_dummy_outcome_refuter.ipynb` -- the instrumental variable
///   estimate and the dummy outcome refuter;
/// * `do_sampler_demo.ipynb` -- the weighting sampler;
/// * `dowhy_confounder_example.ipynb` -- the data set of the hidden confounder;
/// * `dowhy_efficient_backdoor_example.ipynb` -- the three efficient
///   strategies;
/// * `dowhy-simple-iv-example.ipynb` -- the instrumental variable estimate and
///   the placebo refuter;
/// * `graph_conditional_independence_refuter.ipynb` -- the refuter of the
///   conditional independences of a graph;
/// * `dowhy_optimize_backdoor_example.ipynb` -- the optimized backdoor
///   search of a random graph.

///|
/// The seed of the scenarios of the notebooks.
const NOTEBOOK_SEED : Int32 = 42

///|
/// The tolerance the upstream estimator tests use.
const NOTEBOOK_TOLERANCE : Double = 0.1

///|
/// Whether the estimate recovers the true effect of the data set.
fn notebook_close_enough(estimate : Double, truth : Double) -> Bool {
  let error = (estimate - truth).abs()
  error < truth.abs() * NOTEBOOK_TOLERANCE
}

///|
/// The data set of the notebook of the estimation methods.
///
/// The notebook draws a data set with five common causes, two instruments, a
/// binary treatment, a treatment effect of ten and a treatment noise with a
/// standard deviation of ten.
fn notebook_estimation_methods_dataset() -> @datasets.Dataset {
  @datasets.linear_dataset(
    NOTEBOOK_SEED,
    10000,
    @datasets.LinearConfig::new(
      beta=10.0,
      num_common_causes=5,
      num_instruments=2,
      num_treatments=1,
      treatment_is_binary=true,
      outcome_is_binary=false,
      stddev_treatment_noise=10.0,
    ),
  )
}

///|
test "the estimation methods notebook of the upstream runs the eight estimators of its scenario" {
  let dataset = notebook_estimation_methods_dataset()
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
  let regression = model.estimate_effect(
    "backdoor.linear_regression", 1.0, 0.0, "ate",
  )
  assert_true(notebook_close_enough(regression.estimate(), 10.0))
  let matching = model.estimate_effect(
    "backdoor.distance_matching", 1.0, 0.0, "att",
  )
  assert_true(notebook_close_enough(matching.estimate(), 10.0))
  let stratification = model.estimate_effect(
    "backdoor.propensity_score_stratification", 1.0, 0.0, "att",
  )
  assert_true(notebook_close_enough(stratification.estimate(), 10.0))
  let matched = model.estimate_effect(
    "backdoor.propensity_score_matching", 1.0, 0.0, "atc",
  )
  assert_true(notebook_close_enough(matched.estimate(), 10.0))
  let weighting = model.estimate_effect(
    "backdoor.propensity_score_weighting", 1.0, 0.0, "ate",
  )
  assert_true(notebook_close_enough(weighting.estimate(), 10.0))
  let doubly_robust = model.estimate_effect(
    "backdoor.doubly_robust", 1.0, 0.0, "ate",
  )
  assert_true(notebook_close_enough(doubly_robust.estimate(), 10.0))
  // The notebook estimates with the instrument `Z0` and with the running
  // variable `Z1` of the regression discontinuity.
  let instrument = @estimators.CausalEstimator::instrumental_variable(
    estimand, "Z0",
  )
  instrument.fit(dataset.frame(), [])
  let instrumental = instrument.estimate_effect(
    dataset.frame(),
    1.0,
    0.0,
    "ate",
  )
  assert_true(notebook_close_enough(instrumental.estimate(), 10.0))
  let discontinuity = @estimators.CausalEstimator::regression_discontinuity(
    estimand, "Z1", 0.5, 0.15,
  )
  discontinuity.fit(dataset.frame(), [])
  let continuous = discontinuity.estimate_effect(
    dataset.frame(),
    1.0,
    0.0,
    "ate",
  )
  // The band of the running variable holds a small part of the data, so the
  // estimate of the upstream, which is 12.458687360559782, is far from the
  // true effect. The case checks that the estimate of the port is of the same
  // order.
  assert_true(continuous.estimate() > 0.0)
  assert_true(continuous.estimate() < 30.0)
}

///|
/// The data set of the notebook of the simple example.
///
/// The notebook draws a data set with five common causes, two instruments, one
/// effect modifier, one discrete common cause, a binary treatment, a treatment
/// effect of ten and a treatment noise with a standard deviation of ten.
fn notebook_simple_example_dataset() -> @datasets.Dataset {
  @datasets.linear_dataset(
    NOTEBOOK_SEED,
    5000,
    @datasets.LinearConfig::new(
      beta=10.0,
      num_common_causes=5,
      num_instruments=2,
      num_effect_modifiers=1,
      num_treatments=1,
      num_discrete_common_causes=1,
      treatment_is_binary=true,
      outcome_is_binary=false,
      stddev_treatment_noise=10.0,
    ),
  )
}

///|
test "the simple example notebook of the upstream estimates the effect with and without the graph" {
  let dataset = notebook_simple_example_dataset()
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
  let estimate = model.estimate_effect(
    "backdoor.propensity_score_stratification", 1.0, 0.0, "ate",
  )
  // The treatment of the data set of the notebook is very noisy, so the
  // estimate of the upstream, which is 8.232441621395594, is below the true
  // effect of ten.
  assert_true(estimate.estimate() > 5.0)
  assert_true(estimate.estimate() < 11.0)
  let on_control = model.estimate_effect(
    "backdoor.propensity_score_stratification", 1.0, 0.0, "atc",
  )
  // The estimate on the control group of the upstream, which is
  // 8.027083839276482, is close to the estimate on the whole data set.
  let difference = (on_control.estimate() - estimate.estimate()).abs()
  assert_true(difference < 1.0)
  // The notebook builds the model a second time without the graph and gets the
  // very same estimate, which is 8.232441621395594.
  let without_graph = @moonbit_dowhy.CausalModel::new(
    dataset.frame(),
    dataset.treatments(),
    [dataset.outcome()],
    None,
    dataset.common_causes(),
    [],
    dataset.effect_modifiers(),
    [],
  )
  let other = without_graph.identify_effect("backdoor")
  let other_estimate = without_graph.estimate_effect(
    "backdoor.propensity_score_stratification", 1.0, 0.0, "ate",
  )
  assert_true(
    (other_estimate.estimate() - estimate.estimate()).abs() < 0.000001,
  )
  assert_true(other.has_estimand("backdoor"))
  assert_true(estimand.has_estimand("backdoor"))
}

///|
/// The data set of the notebook of the dummy outcome refuter.
///
/// The notebook draws a data set with two common causes, one instrument, a
/// continuous treatment, a treatment effect of ten and a hundred thousand
/// rows.
fn notebook_dummy_outcome_dataset() -> @datasets.Dataset {
  @datasets.linear_dataset(
    NOTEBOOK_SEED,
    100000,
    @datasets.LinearConfig::new(
      beta=10.0,
      num_common_causes=2,
      num_instruments=1,
      num_treatments=1,
      treatment_is_binary=false,
      outcome_is_binary=false,
    ),
  )
}

///|
test "the dummy outcome notebook of the upstream refutes the instrumental variable estimate" {
  let dataset = notebook_dummy_outcome_dataset()
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
  let estimand = model.identify_effect("iv")
  let estimator = @estimators.CausalEstimator::instrumental_variable(
    estimand, "Z0",
  )
  estimator.fit(dataset.frame(), [])
  let estimate = estimator.estimate_effect(dataset.frame(), 1.0, 0.0, "ate")
  // The estimate of the upstream is 9.997620226790636.
  assert_true(notebook_close_enough(estimate.estimate(), 10.0))
  let refutations = @refuters.refute_dummy_outcome(
    estimator,
    estimand,
    dataset.frame(),
    dataset.outcome(),
    dataset.treatments()[0],
    5,
    1.0,
    0.0,
    "ate",
    @utils.Random::new(11),
  )
  assert_eq(refutations.length(), 1)
  // The dummy outcome wipes the prediction of the estimator, so the effect of
  // the upstream is 7.190493096137617e-05.
  assert_true(refutations[0].new_effect().abs() < 0.5)
}

///|
/// The data set of the notebook of the do sampler.
///
/// The notebook draws five thousand rows of a confounder, a binary treatment
/// and an outcome.
fn notebook_do_sampler_frame() -> @api.DataFrame {
  let generator = @utils.NumpyRandom::new(NOTEBOOK_SEED.to_uint64())
  let z : Array[Double] = []
  let d : Array[Double] = []
  let y : Array[Double] = []
  for _ in 0..<5000 {
    let value_of_z = generator.uniform(0.0, 1.0)
    let probability = 1.0 / (1.0 + @math.exp(-5.0 * value_of_z))
    let value_of_d = generator.bernoulli(probability).to_double()
    let value_of_y = 2.0 * value_of_z +
      value_of_d +
      0.1 * generator.standard_normal()
    z.push(value_of_z)
    d.push(value_of_d)
    y.push(value_of_y)
  }
  @api.DataFrame::from_numeric(
    ["Z", "D", "Y"],
    Map([("Z", z), ("D", d), ("Y", y)]),
  )
}

///|
test "the do sampler notebook of the upstream samples the outcome of the intervention" {
  let frame = notebook_do_sampler_frame()
  let model = @moonbit_dowhy.CausalModel::new(
    frame,
    ["D"],
    ["Y"],
    None,
    ["Z"],
    [],
    [],
    [],
  )
  let estimand = model.identify_effect("backdoor")
  assert_true(estimand.has_estimand("backdoor"))
  let sampled = @do_samplers.do_sample(
    frame,
    None,
    ["D"],
    ["Y"],
    @do_samplers.variable_types([("D", "b"), ("Z", "c"), ("Y", "c")]),
    ["Z"],
    "weighting",
    @utils.Random::new(42),
  )
  assert_eq(sampled.nrows(), 5000)
  // The difference of the two means of the sampled outcome is the effect of the
  // intervention. The script `_verify/notebooks_reference.py` prints the
  // difference of the upstream, which is 1.1145513302505097.
  let treated = sampled.filter(
    sampled.numeric("D").map(fn(value) { value == 1.0 }),
  )
  let control = sampled.filter(
    sampled.numeric("D").map(fn(value) { value == 0.0 }),
  )
  let difference = treated.mean("Y") - control.mean("Y")
  assert_true(difference > 0.5)
  assert_true(difference < 2.0)
}

///|
test "the confounder example notebook of the upstream recovers the effect of the hidden confounder" {
  let dataset = @datasets.xy_dataset(
    NOTEBOOK_SEED,
    10000,
    effect=false,
    num_common_causes=1,
    sd_error=0.2,
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
  let estimate = model.estimate_effect(
    "backdoor.linear_regression", 1.0, 0.0, "ate",
  )
  // The notebook draws the true effect at random and it is zero for the seed
  // of the script, so the estimate of the upstream, which is
  // -0.009826407992330033, is zero as well.
  assert_true(estimate.estimate().abs() < 0.1)
  assert_true(estimand.has_estimand("backdoor"))
}

///|
/// The graph of the notebook of the efficient backdoor.
///
/// The notebook builds the graph of a coach, a team, a fitness and an injury.
fn notebook_efficient_graph() -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  for
    node in [
      "coach", "team motivation", "fitness", "pre-game prop", "intra-game prop",
      "neuromusc fatigue", "warm-up", "previous injury", "contact sport", "genetics",
      "injury", "tissue disorder", "tissue weakness",
    ] {
    graph.add_node(node)
  }
  for
    edge in [
      ("coach", "team motivation"),
      ("coach", "fitness"),
      ("fitness", "pre-game prop"),
      ("fitness", "neuromusc fatigue"),
      ("team motivation", "warm-up"),
      ("team motivation", "previous injury"),
      ("pre-game prop", "warm-up"),
      ("warm-up", "intra-game prop"),
      ("contact sport", "previous injury"),
      ("contact sport", "intra-game prop"),
      ("intra-game prop", "injury"),
      ("genetics", "fitness"),
      ("genetics", "neuromusc fatigue"),
      ("genetics", "tissue disorder"),
      ("tissue disorder", "neuromusc fatigue"),
      ("tissue disorder", "tissue weakness"),
      ("neuromusc fatigue", "intra-game prop"),
      ("neuromusc fatigue", "injury"),
      ("tissue weakness", "injury"),
    ] {
    graph.add_edge(edge.0, edge.1)
  }
  graph
}

///|
test "the efficient backdoor notebook of the upstream finds the adjustment sets of its graph" {
  let graph = notebook_efficient_graph()
  let observed = [
    "coach", "team motivation", "fitness", "neuromusc fatigue", "warm-up", "previous injury",
    "contact sport", "tissue disorder", "injury",
  ]
  let conditional = ["previous injury", "team motivation"]
  let (efficient, message) = @identifiers.identify_backdoor(
    graph,
    ["warm-up"],
    ["injury"],
    observed,
    @identifiers.BACKDOOR_EFFICIENT,
    conditional_node_names=conditional,
  )
  assert_eq(message, "")
  assert_eq(efficient.length(), 1)
  assert_true(efficient[0].adjustment_variables.contains("contact sport"))
  assert_true(efficient[0].adjustment_variables.contains("neuromusc fatigue"))
  assert_true(efficient[0].adjustment_variables.contains("previous injury"))
  assert_true(efficient[0].adjustment_variables.contains("team motivation"))
  assert_true(efficient[0].adjustment_variables.contains("tissue disorder"))
  assert_eq(efficient[0].adjustment_variables.length(), 5)
  let (minimal, message) = @identifiers.identify_backdoor(
    graph,
    ["warm-up"],
    ["injury"],
    observed,
    @identifiers.BACKDOOR_MIN_EFFICIENT,
    conditional_node_names=conditional,
  )
  assert_eq(message, "")
  assert_eq(minimal.length(), 1)
  assert_true(minimal[0].adjustment_variables.contains("neuromusc fatigue"))
  assert_true(minimal[0].adjustment_variables.contains("previous injury"))
  assert_true(minimal[0].adjustment_variables.contains("team motivation"))
  assert_true(minimal[0].adjustment_variables.contains("tissue disorder"))
  assert_eq(minimal[0].adjustment_variables.length(), 4)
}

///|
/// The data set of the notebook of the instrumental variable.
///
/// The notebook draws a thousand rows of an education, an income and a voucher,
/// with an unobserved ability that confounds the education and the income.
fn notebook_iv_frame() -> @api.DataFrame {
  let generator = @utils.NumpyRandom::new(NOTEBOOK_SEED.to_uint64())
  let education : Array[Double] = []
  let income : Array[Double] = []
  let voucher : Array[Double] = []
  for _ in 0..<1000 {
    let ability = generator.normal(0.0, 3.0)
    let value_of_voucher = generator.normal(2.0, 1.0)
    let value_of_education = generator.normal(5.0, 1.0) +
      ability +
      2.0 * value_of_voucher
    let value_of_income = generator.normal(10.0, 3.0) +
      2.0 * ability +
      4.0 * value_of_education
    education.push(value_of_education)
    income.push(value_of_income)
    voucher.push(value_of_voucher)
  }
  @api.DataFrame::from_numeric(
    ["education", "income", "voucher"],
    Map([("education", education), ("income", income), ("voucher", voucher)]),
  )
}

///|
test "the instrumental variable notebook of the upstream estimates the effect of the education" {
  let frame = notebook_iv_frame()
  let model = @moonbit_dowhy.CausalModel::new(
    frame,
    ["education"],
    ["income"],
    None,
    ["U"],
    ["voucher"],
    [],
    [],
  )
  let estimand = model.identify_effect("iv")
  let estimate = model.estimate_effect(
    "iv.instrumental_variable", 1.0, 0.0, "ate",
  )
  // The true effect of the notebook is four, and the estimate of the
  // instrumental variable recovers it. The script
  // `_verify/notebooks_reference.py` prints the estimate of the upstream, which
  // is 4.030284450056028.
  assert_true(estimate.estimate() > 2.0)
  assert_true(estimate.estimate() < 7.0)
  let estimator = @estimators.CausalEstimator::instrumental_variable(
    estimand, "voucher",
  )
  estimator.fit(frame, [])
  let refutation = @refuters.refute_placebo_treatment(
    estimator,
    estimand,
    frame,
    "education",
    10,
    1.0,
    0.0,
    "ate",
    @utils.Random::new(7),
    placebo_type=@refuters.PlaceboType::permute(),
  )
  // The placebo treatment drives the effect to zero. The script
  // `_verify/notebooks_reference.py` prints the new effect of the upstream,
  // which is -0.01055604085488724.
  assert_true(refutation.new_effect().abs() < 1.0)
}

///|
/// The random graph of the notebook of the optimized backdoor search.
///
/// The notebook draws a random graph of ten nodes with `networkx` and keeps
/// the edges that go from a lower number to a higher one, so that the graph
/// is acyclic. The port draws its random graph with its own generator, and the
/// graph of the data set it builds is the one of the case.
fn notebook_optimize_backdoor_graph() -> (
  @graph.DirectedGraph,
  Array[String],
  String,
) {
  let dataset = @datasets.dataset_from_random_graph(
    10,
    num_samples=1000,
    prob_edge=0.5,
    random_seed=100,
  )
  let graph = @graph.parse_gml(dataset.gml_graph())
  (graph, dataset.treatments(), dataset.outcome())
}

///|
test "the optimize backdoor notebook of the upstream identifies a random graph with the two searches" {
  let (graph, treatments, outcome) = notebook_optimize_backdoor_graph()
  let treatment = treatments[0]
  let observed = graph.node_list()
  let (vanilla, message) = @identifiers.identify_backdoor(
    graph,
    [treatment],
    [outcome],
    observed,
    @identifiers.BACKDOOR_EXHAUSTIVE,
  )
  assert_eq(message, "")
  let (optimized, message) = @identifiers.identify_backdoor(
    graph,
    [treatment],
    [outcome],
    observed,
    @identifiers.BACKDOOR_DEFAULT,
    optimize_backdoor=true,
  )
  assert_eq(message, "")
  // The notebook identifies the graph twice, once with the vanilla search and
  // once with the optimized one.
  assert_true(vanilla.length() > 0)
  // The optimized search returns no set when the paths of the pair are blocked
  // already, and a set that blocks every backdoor path otherwise.
  let bdoor_graph = @graph.do_surgery(
    graph,
    [treatment],
    true,
    false,
    [outcome],
    false,
  )
  for set in optimized {
    let variables = set.adjustment_variables()
    assert_true(
      @graph.d_separated(bdoor_graph, [treatment], [outcome], variables),
    )
  }
}

///|
/// The graph of the notebook of the refuter of the conditional independences.
///
/// The notebook builds the graph of ten nodes, `a` to `j`.
fn notebook_graph_refuter_graph() -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  for name in ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"] {
    graph.add_node(name)
  }
  for
    edge in [
      ("a", "b"),
      ("a", "i"),
      ("b", "c"),
      ("b", "f"),
      ("c", "d"),
      ("c", "e"),
      ("d", "e"),
      ("e", "f"),
      ("f", "g"),
      ("g", "h"),
      ("h", "i"),
      ("i", "j"),
    ] {
    graph.add_edge(edge.0, edge.1)
  }
  graph
}

///|
/// The conditional independences of a graph, for the given number of the
/// variables of the conditioning set.
///
/// This is the port of the derivation of the conditional independences of
/// `dowhy.causal_model.CausalModel.refute_graph`: every pair of the nodes is
/// tested against every set of the given size of the other nodes, and the
/// pairs the graph separates are the conditional independences of the graph.
fn notebook_conditional_independences(
  graph : @graph.CausalGraph,
  nodes : Array[String],
  k : Int32,
) -> Array[@refuters.Implication] {
  let implications : Array[@refuters.Implication] = []
  for i in 0..<nodes.length() {
    for j in (i + 1)..<nodes.length() {
      let rest : Array[String] = []
      for index in 0..<nodes.length() {
        if index != i && index != j {
          rest.push(nodes[index])
        }
      }
      if k == 0 {
        if graph.check_dseparation([nodes[i]], [nodes[j]], [], None) {
          implications.push(@refuters.Implication::new(nodes[i], nodes[j], []))
        }
      } else if k == 1 {
        for name in rest {
          if graph.check_dseparation([nodes[i]], [nodes[j]], [name], None) {
            implications.push(
              @refuters.Implication::new(nodes[i], nodes[j], [name]),
            )
          }
        }
      }
    }
  }
  implications
}

///|
test "the graph refuter notebook of the upstream tests the conditional independences of the graph" {
  let dataset = @datasets.dataset_from_random_graph(
    10,
    num_samples=5000,
    prob_edge=0.3,
    random_seed=100,
  )
  let graph = notebook_graph_refuter_graph()
  let causal = @graph.CausalGraph::new(
    [],
    [],
    Some(graph),
    [],
    [],
    [],
    [],
    dataset.frame().column_names(),
  )
  let implications = notebook_conditional_independences(
    causal,
    dataset.frame().column_names(),
    1,
  )
  // The graph of the notebook entails the conditional independences the refuter
  // tests. The script `_verify/notebooks_reference.py` prints the number of the
  // upstream, which is 34.
  assert_eq(implications.length(), 34)
  let refuter = @refuters.GraphRefuter::new(
    dataset.frame(),
    "conditional_mutual_information",
    "partial_correlation",
  )
  let refutation = refuter.refute_model(implications)
  assert_eq(refutation.constraints_of_the_model(), implications.length())
  assert_eq(
    refutation.constraints_satisfied_by_the_data(),
    refuter.true_implications().length(),
  )
  assert_true(refutation.continuous_method() == "partial_correlation")
  assert_true(refutation.discrete_method() == "conditional_mutual_information")
}
