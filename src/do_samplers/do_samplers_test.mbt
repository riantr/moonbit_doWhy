/// Tests for the do samplers.
///
/// The cases mirror the upstream test suite
/// (`tests/do_sampler/test_pandas_do_api.py`): the interventional average
/// treatment effect of a generated data set has to be within the same ten
/// percent tolerance of the true effect that the upstream tests use.

///|
/// The tolerance the upstream do sampler tests use.
const ERROR_TOLERANCE : Double = 0.1

///|
/// The true average treatment effect of the data sets of the upstream tests.
const TRUE_EFFECT : Double = 10.0

///|
/// The number of rows of the data sets of the upstream tests.
const NUM_SAMPLES : Int32 = 10000

///|
/// The seed of the generators of the tests.
const SEED : UInt64 = 42

///|
/// Whether the estimate is within the tolerance of the true effect.
fn close_enough(estimate : Double, truth : Double) -> Bool {
  let error = (estimate - truth).abs()
  error < truth.abs() * ERROR_TOLERANCE
}

///|
/// The data set of the upstream tests.
///
/// The upstream test builds the data with `numpy.random`: a confounder
/// `X0`, a cause `v` and an outcome `y` whose coefficient of the cause is
/// the true effect of ten. The cause and the confounder are either discrete
/// or continuous.
fn upstream_data(
  seed : UInt64,
  n : Int32,
  discrete_cause : Bool,
  discrete_confounder : Bool,
) -> @api.DataFrame {
  let random = @utils.Random::new(seed)
  let x0 : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    let value = random.next_normal()
    x0.push(if discrete_confounder { value.trunc() } else { value })
  }
  let v : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    let value = random.next_normal() + x0[i]
    v.push(if discrete_cause { value.trunc() } else { value })
  }
  // The upstream code adds a single normal deviate to the whole outcome
  // column, because it calls `numpy.random.normal()` without a size. The
  // port does the same, so that the data of the two ports is the same.
  let noise = random.next_normal()
  let y : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    y.push(TRUE_EFFECT * v[i] + x0[i] + noise)
  }
  @api.DataFrame::from_numeric(
    ["v", "X0", "y"],
    Map([("v", v), ("X0", x0), ("y", y)]),
  )
}

///|
/// The data set of the upstream tests that specify the variable types.
///
/// The upstream test uses `dowhy.datasets.linear_dataset` with a binary
/// treatment, one common cause and an effect of five. The port builds the
/// same shape here, so that the package needs no data set package.
fn binary_dataset(seed : UInt64, n : Int32) -> @api.DataFrame {
  let random = @utils.Random::new(seed)
  let effect = 5.0
  let w0 : Array[Double] = []
  let v0 : Array[Double] = []
  let y : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    let confounder = random.next_normal()
    let linear = random.next_normal() + confounder
    let treatment = if random.next_double() < @utils.sigmoid(linear) {
      1.0
    } else {
      0.0
    }
    w0.push(confounder)
    v0.push(treatment)
    y.push(effect * treatment + confounder)
  }
  @api.DataFrame::from_numeric(
    ["v0", "y", "W0"],
    Map([("v0", v0), ("y", y), ("W0", w0)]),
  )
}

///|
/// The average treatment effect of a sampled frame with a discrete cause.
///
/// This is the difference of the two group means the upstream test computes.
fn discrete_ate(frame : @api.DataFrame) -> Double {
  let v = frame.numeric("v")
  let y = frame.numeric("y")
  let mut treated = 0.0
  let mut treated_count = 0
  let mut control = 0.0
  let mut control_count = 0
  for i = 0; i < v.length(); i = i + 1 {
    if v[i] == 1.0 {
      treated = treated + y[i]
      treated_count = treated_count + 1
    } else if v[i] == 0.0 {
      control = control + y[i]
      control_count = control_count + 1
    }
  }
  treated / treated_count.to_double() - control / control_count.to_double()
}

///|
/// The average treatment effect of a sampled frame with a continuous cause.
///
/// This is the slope of the regression of the outcome on the cause, like the
/// upstream test computes it.
fn continuous_ate(frame : @api.DataFrame) -> Double {
  let v = frame.numeric("v")
  let y = frame.numeric("y")
  let intercept : Array[Double] = []
  for i = 0; i < v.length(); i = i + 1 {
    intercept.push(1.0)
  }
  let design = @utils.Matrix::from_columns([intercept, v])
  let fit = @utils.ols_fit(design, y)
  fit.beta[1]
}

///|
/// The data set of a binary treatment and a continuous confounder.
fn binary_treatment_dataset(seed : UInt64, n : Int32) -> @api.DataFrame {
  let random = @utils.Random::new(seed)
  let x0 : Array[Double] = []
  let v : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    let confounder = random.next_normal()
    let treatment = if random.next_double() < @utils.sigmoid(confounder) {
      1.0
    } else {
      0.0
    }
    x0.push(confounder)
    v.push(treatment)
  }
  @api.DataFrame::from_numeric(["v", "X0"], Map([("v", v), ("X0", x0)]))
}

///|
test "the weighting sampler recovers the effect of a discrete cause with a continuous confounder" {
  let data = upstream_data(SEED, NUM_SAMPLES, true, false)
  let types = @do_samplers.variable_types([("v", "d"), ("X0", "c"), ("y", "c")])
  let frame = @do_samplers.do_sample(
    data,
    None,
    ["v"],
    ["y"],
    types,
    ["X0"],
    "weighting",
    @utils.Random::new(SEED),
  )
  assert_true(close_enough(discrete_ate(frame), TRUE_EFFECT))
}

///|
test "the weighting sampler recovers the effect of a discrete cause with a discrete confounder" {
  let data = upstream_data(SEED, NUM_SAMPLES, true, true)
  let types = @do_samplers.variable_types([("v", "d"), ("X0", "d"), ("y", "c")])
  let frame = @do_samplers.do_sample(
    data,
    None,
    ["v"],
    ["y"],
    types,
    ["X0"],
    "weighting",
    @utils.Random::new(SEED),
  )
  assert_true(close_enough(discrete_ate(frame), TRUE_EFFECT))
}

///|
test "the weighting sampler recovers the effect of a continuous cause with a discrete confounder" {
  let data = upstream_data(SEED, NUM_SAMPLES, false, true)
  let types = @do_samplers.variable_types([("v", "c"), ("X0", "d"), ("y", "c")])
  let frame = @do_samplers.do_sample(
    data,
    None,
    ["v"],
    ["y"],
    types,
    ["X0"],
    "weighting",
    @utils.Random::new(SEED),
  )
  assert_true(close_enough(continuous_ate(frame), TRUE_EFFECT))
}

///|
test "the weighting sampler recovers the effect of a continuous cause with a continuous confounder" {
  let data = upstream_data(SEED, NUM_SAMPLES, false, false)
  let types = @do_samplers.variable_types([("v", "c"), ("X0", "c"), ("y", "c")])
  let frame = @do_samplers.do_sample(
    data,
    None,
    ["v"],
    ["y"],
    types,
    ["X0"],
    "weighting",
    @utils.Random::new(SEED),
  )
  assert_true(close_enough(continuous_ate(frame), TRUE_EFFECT))
}

///|
test "the do operation runs with a full specification of the variable types" {
  let data = binary_dataset(SEED, 1000)
  let types = @do_samplers.variable_types([("v0", "b"), ("y", "c"), ("W0", "c")])
  let frame = @do_samplers.do_sample(
    data,
    None,
    ["v0"],
    ["y"],
    types,
    ["W0"],
    "weighting",
    @utils.Random::new(SEED),
  )
  let (keys, groups) = frame.group_by("v0")
  assert_eq(keys.length(), 2)
  assert_true(groups[0].length() > 0)
  assert_true(groups[1].length() > 0)
}

///|
test "the do operation runs with a partial specification of the variable types" {
  let data = binary_dataset(SEED, 1000)
  let types = @do_samplers.variable_types([("v0", "b"), ("W0", "c")])
  let frame = @do_samplers.do_sample(
    data,
    None,
    ["v0"],
    ["y"],
    types,
    ["W0"],
    "weighting",
    @utils.Random::new(SEED),
  )
  let (keys, groups) = frame.group_by("v0")
  assert_eq(keys.length(), 2)
  assert_true(groups[0].length() > 0)
  assert_true(groups[1].length() > 0)
}

///|
test "the do operation runs without a specification of the variable types" {
  let data = binary_dataset(SEED, 1000)
  let frame = @do_samplers.do_sample(
    data,
    None,
    ["v0"],
    ["y"],
    Map([]),
    ["W0"],
    "weighting",
    @utils.Random::new(SEED),
  )
  let (keys, groups) = frame.group_by("v0")
  assert_eq(keys.length(), 2)
  assert_true(groups[0].length() > 0)
  assert_true(groups[1].length() > 0)
}

///|
test "the sampler draws a different sample every time" {
  let data = upstream_data(SEED, 1000, true, false)
  let types = @do_samplers.variable_types([("v", "d"), ("X0", "c"), ("y", "c")])
  let random = @utils.Random::new(SEED)
  let graph = @graph.build_graph(["v"], ["y"], ["X0"], [], [], [])
  let sampler = @do_samplers.DoSampler::weighting(
    graph,
    ["v"],
    ["y"],
    graph.node_list(),
    data,
    types,
    random,
  )
  let first = sampler.do_sample(Map([]))
  let second = sampler.do_sample(Map([]))
  let first_outcome = first.numeric("y")
  let second_outcome = second.numeric("y")
  let mut different = false
  for i = 0; i < first_outcome.length(); i = i + 1 {
    if first_outcome[i] != second_outcome[i] {
      different = true
    }
  }
  assert_true(different)
}

///|
test "the sampler uses the adjustment variables of the backdoor criterion" {
  let data = upstream_data(SEED, 1000, true, false)
  let types = @do_samplers.variable_types([("v", "d"), ("X0", "c"), ("y", "c")])
  let random = @utils.Random::new(SEED)
  let graph = @graph.build_graph(["v"], ["y"], ["X0"], [], [], [])
  let sampler = @do_samplers.DoSampler::weighting(
    graph,
    ["v"],
    ["y"],
    graph.node_list(),
    data,
    types,
    random,
  )
  assert_true(sampler.adjustment_set().contains("X0"))
  assert_eq(sampler.treatments(), ["v"])
  assert_eq(sampler.outcomes(), ["y"])
}

///|
test "the propensity score of a two level treatment agrees with the port's logistic regression" {
  let n = 500
  let data = binary_treatment_dataset(SEED, n)
  let types = @do_samplers.variable_types([("v", "d"), ("X0", "c")])
  let scores = @do_samplers.state_propensity_score(data, ["X0"], ["v"], types)
  // The same model, fitted with the logistic regression of the port.
  let x0 = data.numeric("X0")
  let v = data.numeric("v")
  let intercept : Array[Double] = []
  let targets : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    intercept.push(1.0)
    targets.push(v[i])
  }
  let design = @utils.Matrix::from_columns([intercept, x0])
  let fit = @utils.logistic_fit(design, targets, 1.0, 100, 1.0e-4)
  let probabilities = @utils.logistic_predict(fit.beta, design)
  for i = 0; i < n; i = i + 1 {
    let expected = if v[i] == 1.0 {
      probabilities[i]
    } else {
      1.0 - probabilities[i]
    }
    assert_true((scores[i] - expected).abs() < 1.0e-4)
  }
}

///|
test "the multivariate weighting sampler recovers the effect as well" {
  let data = upstream_data(SEED, NUM_SAMPLES, true, false)
  let types = @do_samplers.variable_types([("v", "d"), ("X0", "c"), ("y", "c")])
  let frame = @do_samplers.do_sample(
    data,
    None,
    ["v"],
    ["y"],
    types,
    ["X0"],
    "multivariate_weighting",
    @utils.Random::new(SEED),
  )
  assert_true(frame.has_column("state_propensity"))
  assert_true(frame.has_column("weight"))
  assert_true(close_enough(discrete_ate(frame), TRUE_EFFECT))
}

///|
test "the kernel density sampler draws the outcome of the intervention" {
  let data = upstream_data(SEED, NUM_SAMPLES, false, false)
  let types = @do_samplers.variable_types([("v", "c"), ("X0", "c"), ("y", "c")])
  let frame = @do_samplers.do_sample(
    data,
    None,
    ["v"],
    ["y"],
    types,
    ["X0"],
    "kernel_density",
    @utils.Random::new(SEED),
    treatment_values=Map([("v", 1.0)]),
  )
  // Every row carries the imposed treatment.
  for value in frame.numeric("v") {
    assert_eq(value, 1.0)
  }
  // The outcome of the intervention has the mean of the conditional model.
  assert_true(close_enough(frame.mean("y"), TRUE_EFFECT))
}
