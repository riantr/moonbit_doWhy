///|
/// The tests of the multiply-robust causal change attribution.
///
/// The upstream reference of the layer is
/// `_verify/gcm_distribution_change_robust_reference.py`, which runs the
/// upstream `dowhy.gcm.distribution_change_robust` on the fixtures of the
/// layer.  The fixtures of the port are drawn from the generator of the
/// `utils` package, and the reference script reproduces that generator in
/// Python, so that the fixtures of the port and the fixtures of the reference
/// are the same numbers.
///
/// The upstream draws the rows of its fixtures from the global generator of
/// numpy, which is not seeded, so the numbers of the upstream move from one
/// run to the other; the upstream marks its test file as flaky for that
/// reason.  The port draws its rows from the generator it is given, so the
/// numbers of the port are the same on every run.
///
/// The numbers the tests assert are the numbers of the upstream on the very
/// same rows, which the reference script measures.  They are not equal to the
/// numbers of the port: the cross-fitting of the upstream splits the rows with
/// the `StratifiedKFold` of scikit-learn and the port splits them with its own
/// shuffle, so the two split the data differently and the attributions move a
/// little.  The tolerances of the tests hold that difference and are tighter
/// than the tolerances of the upstream test file, which are a tenth and a
/// fifth.
///
/// The functional of the variance is the one of the upstream, which is the
/// second moment of the target minus the square of the first moment of the
/// target.  The parentheses of the upstream make it look like the square of the
/// difference of the two moments, but the exponent of Python binds tighter
/// than the subtraction, so the upstream squares the first moment alone.

///|
/// The seed of the generator of the fixtures.
const CHANGE_ATTRIBUTION_SEED : UInt64 = 2024

///|
/// The number of the rows of the fixtures.
const CHANGE_ATTRIBUTION_NUM_ROWS : Int32 = 10000

///|
/// The tolerance of the attribution of the mean.
///
/// The difference of the attribution of the port and the attribution of the
/// upstream is a twentieth of the tolerance.
const CHANGE_ATTRIBUTION_MEAN_TOLERANCE : Double = 0.05

///|
/// The tolerance of the attribution of the variance.
///
/// The difference of the attribution of the port and the attribution of the
/// upstream is a third of the tolerance.
const CHANGE_ATTRIBUTION_VARIANCE_TOLERANCE : Double = 0.15

///|
/// The two data sets of the test, the old one and the new one.
///
/// This is the port of the `_gen_data` of the upstream test file
/// `tests/gcm/test_distribution_change_robust.py`.  The rows are drawn in the
/// order of the upstream: the noise of the first variable of the old data set,
/// the noise of the second one, the noise of the outcome, and then the same
/// three noises of the new data set.
fn change_attribution_data(
  rng : @utils.Random,
  num_rows : Int32,
) -> (@api.DataFrame, @api.DataFrame) {
  let x1_old : Array[Double] = []
  for _ in 0..<num_rows {
    x1_old.push(1.0 + rng.next_normal())
  }
  let x2_old : Array[Double] = []
  for i in 0..<num_rows {
    x2_old.push(0.5 * x1_old[i] + rng.next_normal())
  }
  let y_old : Array[Double] = []
  for i in 0..<num_rows {
    y_old.push(
      x1_old[i] +
      x2_old[i] +
      0.25 * x1_old[i] * x1_old[i] +
      0.25 * x2_old[i] * x2_old[i] +
      rng.next_normal(),
    )
  }
  let x1_new : Array[Double] = []
  for _ in 0..<num_rows {
    x1_new.push(1.0 + 1.1 * rng.next_normal())
  }
  let x2_new : Array[Double] = []
  for i in 0..<num_rows {
    x2_new.push(0.2 * x1_new[i] + rng.next_normal())
  }
  let y_new : Array[Double] = []
  for i in 0..<num_rows {
    y_new.push(
      x1_new[i] +
      x2_new[i] +
      0.25 * x1_new[i] * x1_new[i] -
      0.25 * x2_new[i] * x2_new[i] +
      rng.next_normal(),
    )
  }
  (
    change_attribution_frame([("X1", x1_old), ("X2", x2_old), ("Y", y_old)]),
    change_attribution_frame([("X1", x1_new), ("X2", x2_new), ("Y", y_new)]),
  )
}

///|
/// The data frame of the given columns.
fn change_attribution_frame(
  columns : Array[(String, Array[Double])],
) -> @api.DataFrame {
  let order : Array[String] = []
  let payload : Map[String, Array[Double]] = Map([])
  for column in columns {
    let (name, values) = column
    order.push(name)
    payload.set(name, values)
  }
  @api.DataFrame::from_numeric(order, payload)
}

///|
/// The causal model of the test: `X1` causes `X2` and `Y`, and `X2` causes `Y`.
fn change_attribution_model() -> @gcm.ProbabilisticCausalModel {
  let graph = @graph.DirectedGraph::new()
  graph.add_edge("X1", "X2")
  graph.add_edge("X1", "Y")
  graph.add_edge("X2", "Y")
  @gcm.ProbabilisticCausalModel::new(graph)
}

///|
/// The attribution of the change of the functional of the target.
fn change_attribution(
  functional : @gcm.TargetFunctional,
  change_method : @gcm.ChangeMethod,
) -> Map[String, Double] {
  let rng = @utils.Random::new(CHANGE_ATTRIBUTION_SEED)
  let (old_data, new_data) = change_attribution_data(
    rng,
    CHANGE_ATTRIBUTION_NUM_ROWS,
  )
  let config = @gcm.DistributionChangeRobustConfig::new()
    .with_xfit_folds(10)
    .with_target_functional(functional)
    .with_method(change_method)
  @gcm.distribution_change_robust(
    change_attribution_model(),
    old_data,
    new_data,
    "Y",
    config,
    @gcm.Regressor::nearest_neighbour(5),
    @gcm.ClassificationModel::logistic(),
  )
}

///|
/// The attribution of the node with the given name.
fn change_attribution_of(
  attribution : Map[String, Double],
  name : String,
) -> Double {
  attribution.get(name).unwrap_or(0.0)
}

///|
/// Whether the attribution of the node is the expected one.
fn change_attribution_is(
  attribution : Map[String, Double],
  name : String,
  expected : Double,
  tolerance : Double,
) -> Bool {
  (change_attribution_of(attribution, name) - expected).abs() <= tolerance
}

///|
/// Whether the three attributions are the expected ones.
fn change_attribution_are(
  attribution : Map[String, Double],
  x1 : Double,
  x2 : Double,
  y : Double,
  tolerance : Double,
) -> Bool {
  change_attribution_is(attribution, "X1", x1, tolerance) &&
  change_attribution_is(attribution, "X2", x2, tolerance) &&
  change_attribution_is(attribution, "Y", y, tolerance)
}

///|
test "the change of the mean of the target is attributed by the multiply-robust method" {
  let attribution = change_attribution(
    @gcm.TargetFunctional::mean(),
    @gcm.ChangeMethod::multiply_robust(),
  )
  assert_true(
    change_attribution_are(
      attribution,
      0.028989856242,
      -0.304901381947,
      -0.644796109318,
      CHANGE_ATTRIBUTION_MEAN_TOLERANCE,
    ),
  )
}

///|
test "the change of the variance of the target is attributed by the multiply-robust method" {
  let attribution = change_attribution(
    @gcm.TargetFunctional::variance(),
    @gcm.ChangeMethod::multiply_robust(),
  )
  assert_true(
    change_attribution_are(
      attribution,
      0.908096094967,
      -1.383187710899,
      -1.347345263753,
      CHANGE_ATTRIBUTION_VARIANCE_TOLERANCE,
    ),
  )
}

///|
test "the change of the mean of the target is attributed by the regression method" {
  let attribution = change_attribution(
    @gcm.TargetFunctional::mean(),
    @gcm.ChangeMethod::regression(),
  )
  assert_true(
    change_attribution_are(
      attribution,
      0.032079458923,
      -0.309935716764,
      -0.642851377182,
      CHANGE_ATTRIBUTION_MEAN_TOLERANCE,
    ),
  )
}

///|
test "the change of the variance of the target is attributed by the regression method" {
  let attribution = change_attribution(
    @gcm.TargetFunctional::variance(),
    @gcm.ChangeMethod::regression(),
  )
  assert_true(
    change_attribution_are(
      attribution,
      0.919382883668,
      -1.368283974173,
      -1.373535789181,
      CHANGE_ATTRIBUTION_VARIANCE_TOLERANCE,
    ),
  )
}

///|
test "the change of the mean of the target is attributed by the re-weighting method" {
  let attribution = change_attribution(
    @gcm.TargetFunctional::mean(),
    @gcm.ChangeMethod::reweighting(),
  )
  assert_true(
    change_attribution_are(
      attribution,
      -0.021202046798,
      -0.297138242708,
      -0.602367345517,
      CHANGE_ATTRIBUTION_MEAN_TOLERANCE,
    ),
  )
}

///|
test "the change of the variance of the target is attributed by the re-weighting method" {
  let attribution = change_attribution(
    @gcm.TargetFunctional::variance(),
    @gcm.ChangeMethod::reweighting(),
  )
  assert_true(
    change_attribution_are(
      attribution,
      -0.027160677522,
      -0.180229760876,
      -1.615046441288,
      CHANGE_ATTRIBUTION_VARIANCE_TOLERANCE,
    ),
  )
}
