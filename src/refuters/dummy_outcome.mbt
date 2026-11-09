///|
/// The dummy outcome refuter.
///
/// This is the port of `dowhy.causal_refuters.dummy_outcome_refuter`. The
/// outcome of the data is replaced by a simulated outcome for which the causal
/// effect of the treatment is known, and the estimator is refitted on the
/// simulated outcome. A refutation that works finds the known effect, which is
/// zero when the caller gives no other.
///
/// The simulation is a list of transformations of the outcome:
///
/// * `zero` replaces every value by zero,
/// * `noise` adds a white noise,
/// * `permute` permutes the rows,
/// * `linear_regression` and the k nearest neighbours replace the outcome by
///   their prediction from the covariates,
/// * `estimate` replaces the outcome by the prediction of a model the caller
///   gives.
///
/// The default list is `[zero, noise(1)]`, which gives an outcome that is pure
/// noise, the `DEFAULT_TRANSFORMATION` of the upstream.
///
/// The list decides which branch of the refuter runs, the way the upstream
/// `_has_estimator` decides it:
///
/// * A list without an estimator runs on the whole data at once and reports one
///   refutation.
/// * A list with an estimator splits the data into buckets of the treatment,
///   fits the model of one bucket on a part of it and evaluates it on the rest
///   of that bucket and on a part of every other bucket, so that the simulated
///   outcome of a row comes from a model that has not seen it, and reports one
///   refutation per bucket.
///
/// The buckets are the ones of the upstream, including its quirk: the edges are
/// taken from the ranges of *every* numeric column of the frame rather than from
/// the range of the treatment column alone. The edge of a column is
/// `(max - min) of the column / (bucket_size_scale_factor * std of the
/// treatment)`, in the column order of the frame, and the edges cut the
/// treatment the way `pandas.cut` cuts it, so a row whose treatment lies at or
/// below the first edge or above the last one takes part in no bucket. The two
/// estimator cases of `tests/causal_refuters/test_dummy_outcome_refuter.py` rely
/// on this: the frame of `dowhy.datasets.linear_dataset` is ordered
/// `Z0, W0, v0, y`, whose ranges increase, so the edges increase as well and the
/// branch runs. A frame whose ranges do not increase makes `pandas.cut` raise
/// `ValueError: bins must increase monotonically`, and the port aborts with the
/// same message.

///|
/// A transformation of the outcome of the dummy outcome refuter.
pub enum Transformation {
  /// Every value becomes zero.
  Zero
  /// A white noise of the given standard deviation is added.
  Noise(Double)
  /// The values are permuted over the given fraction of the rows.
  ///
  /// A fraction of one permutes every row; a smaller fraction swaps a row with
  /// a later one with the probability of half the fraction, the way the
  /// upstream does it, because every swap changes two rows.
  Permute(Double)
  /// The outcome is estimated from the covariates with a linear regression.
  LinearRegression
  /// The outcome is estimated from the covariates with the k nearest
  /// neighbours.
  NearestNeighbour(Int32)
  /// The outcome is estimated from the covariates with the model the caller
  /// gives.
  ///
  /// The model takes the covariates of the training rows, the outcome of the
  /// training rows and the covariates of the rows to predict, and returns its
  /// prediction for the training rows and for the rows to predict. The upstream
  /// takes a callable that returns a fitted estimator; the port takes the two
  /// predictions directly, which is the same contract without the intermediate
  /// object.
  Estimate(
    (@api.DataFrame, Array[Double], @api.DataFrame) -> (
      Array[Double],
      Array[Double],
    )
  )
}

///|
/// A transformation that replaces every value by zero.
pub fn Transformation::zero() -> Transformation {
  Zero
}

///|
/// A transformation that adds a white noise of the given standard deviation.
pub fn Transformation::noise(std_dev : Double) -> Transformation {
  Noise(std_dev)
}

///|
/// A transformation that permutes the given fraction of the rows.
pub fn Transformation::permute(fraction : Double) -> Transformation {
  if fraction > 1.0 {
    abort(
      "The value of permute_fraction is " +
      fraction.to_string() +
      ". Which is greater than 1.",
    )
  }
  Permute(fraction)
}

///|
/// A transformation that predicts the outcome with a linear regression.
pub fn Transformation::linear_regression() -> Transformation {
  LinearRegression
}

///|
/// A transformation that predicts the outcome with the k nearest neighbours.
pub fn Transformation::nearest_neighbour(k : Int32) -> Transformation {
  NearestNeighbour(k)
}

///|
/// A transformation that predicts the outcome with the given model.
pub fn Transformation::estimate(
  model : (@api.DataFrame, Array[Double], @api.DataFrame) -> (
    Array[Double],
    Array[Double],
  ),
) -> Transformation {
  Estimate(model)
}

///|
/// The transformation list of the upstream when the caller gives none.
pub fn dummy_outcome_default_transformations() -> Array[Transformation] {
  [Transformation::zero(), Transformation::noise(1.0)]
}

///|
/// Whether one of the transformations predicts the outcome from the
/// covariates.
///
/// This is the port of `_has_estimator` of the upstream, which decides the
/// branch of the refuter.
fn has_estimator(transformations : Array[Transformation]) -> Bool {
  for transformation in transformations {
    match transformation {
      Zero | Noise(_) | Permute(_) => ()
      LinearRegression | NearestNeighbour(_) | Estimate(_) => return true
    }
  }
  false
}

///|
/// The dummy outcome refuter.
///
/// The estimate of the data is refuted by replacing the outcome with a
/// simulated outcome whose causal effect is `true_causal_effect`, which is zero
/// when the caller gives no other. The refutations come back with one entry per
/// bucket of the treatment, the way the upstream returns its list.
pub fn refute_dummy_outcome(
  estimator : @estimators.CausalEstimator,
  estimand : @identifiers.IdentifiedEstimand,
  data : @api.DataFrame,
  outcome_name : String,
  treatment_name : String,
  num_simulations : Int32,
  treatment_value : Double,
  control_value : Double,
  target_units : String,
  random : @utils.Random,
  required_variables~ : RequiredVariables = RequiredVariables::all(),
  transformations~ : Array[Transformation] = dummy_outcome_default_transformations(),
  min_data_point_threshold~ : Int32 = 30,
  bucket_size_scale_factor~ : Double = 0.5,
  test_fraction~ : Double = 0.5,
  true_causal_effect~ : ((Array[Double]) -> Array[Double])? = None,
) -> Array[CausalRefutation] {
  let variables = choose_variables(
    required_variables,
    variables_of_interest(estimator, estimand),
    random,
  )
  let outcome = data.numeric(outcome_name)
  let treatment = numeric_or_none(data, treatment_name)
  let simulation = if has_estimator(transformations) {
    simulate_by_bucket(
      estimator, estimand, data, outcome_name, outcome, treatment_name, treatment,
      variables, num_simulations, treatment_value, control_value, target_units, random,
      transformations, min_data_point_threshold, bucket_size_scale_factor, test_fraction,
      true_causal_effect,
    )
  } else {
    simulate_on_whole_data(
      estimator, estimand, data, outcome_name, outcome, treatment, num_simulations,
      treatment_value, control_value, target_units, random, transformations, true_causal_effect,
    )
  }
  // The simulations are held one row per simulation and one column per bucket,
  // the way the upstream holds them in a numpy array.
  let refutations : Array[CausalRefutation] = []
  for bucket = 0; bucket < simulation.true_effects.length(); bucket = bucket + 1 {
    let estimates : Array[Double] = []
    for row in simulation.effects {
      estimates.push(row[bucket])
    }
    let refutation = CausalRefutation::new(
      simulation.true_effects[bucket],
      @utils.mean(estimates),
      "Refute: Use a Dummy Outcome",
    )
    refutation.new_effect_lower = @utils.percentile(estimates, 2.5)
    refutation.new_effect_upper = @utils.percentile(estimates, 97.5)
    // The simulated outcome severs the relation of the treatment to the
    // outcome, so the known effect is the one the estimates are tested against.
    let (p_value, significant) = test_significance(
      simulation.true_effects[bucket],
      estimates,
    )
    refutation.p_value = p_value
    refutation.is_significant = significant
    refutations.push(refutation)
  }
  refutations
}

///|
/// The result of the simulation: the estimates of every simulation and the
/// known effect of every bucket.
priv struct DummyOutcomeSimulation {
  /// The estimates, one row per simulation and one column per bucket.
  effects : Array[Array[Double]]
  /// The known causal effect of every bucket.
  true_effects : Array[Double]
}

///|
/// The column of the frame as numbers, or nothing when the column is discrete.
fn numeric_or_none(data : @api.DataFrame, name : String) -> Array[Double]? {
  if data.is_discrete(name) {
    None
  } else {
    Some(data.numeric(name))
  }
}

///|
/// The simulation of the branch of the refuter that has no estimator.
///
/// The whole data is used at once, so there is a single bucket.
fn simulate_on_whole_data(
  estimator : @estimators.CausalEstimator,
  estimand : @identifiers.IdentifiedEstimand,
  data : @api.DataFrame,
  outcome_name : String,
  outcome : Array[Double],
  treatment : Array[Double]?,
  num_simulations : Int32,
  treatment_value : Double,
  control_value : Double,
  target_units : String,
  random : @utils.Random,
  transformations : Array[Transformation],
  true_causal_effect : ((Array[Double]) -> Array[Double])?,
) -> DummyOutcomeSimulation {
  let known = causal_effect_of(outcome.length(), treatment, true_causal_effect)
  let known_effect = if known.length() == 0 { 0.0 } else { @utils.mean(known) }
  let effects : Array[Array[Double]] = []
  for simulation = 0; simulation < num_simulations; simulation = simulation + 1 {
    // The covariates are unused by a list without an estimator, but the whole
    // frame is passed all the same, because the shape of the prediction follows
    // it.
    let simulated = process_transformations(
      None,
      None,
      data,
      outcome,
      transformations,
      random,
    )
    let shifted = shift_outcome(simulated, known)
    let dummy_data = data.with_numeric(outcome_name, shifted)
    let effect = reestimate(
      estimator, estimand, dummy_data, treatment_value, control_value, target_units,
    )
    let row : Array[Double] = []
    row.push(effect)
    effects.push(row)
  }
  let true_effects : Array[Double] = []
  true_effects.push(known_effect)
  { effects, true_effects, }
}

///|
/// The simulation of the branch of the refuter that has an estimator.
///
/// The data is split into buckets of the treatment. The model of one bucket is
/// fitted on a part of that bucket and evaluated on the rest of it and on a part
/// of every other bucket, so the simulated outcome of a row comes from a model
/// that has not seen it.
fn simulate_by_bucket(
  estimator : @estimators.CausalEstimator,
  estimand : @identifiers.IdentifiedEstimand,
  data : @api.DataFrame,
  outcome_name : String,
  outcome : Array[Double],
  treatment_name : String,
  treatment : Array[Double]?,
  variables : Array[String],
  num_simulations : Int32,
  treatment_value : Double,
  control_value : Double,
  target_units : String,
  random : @utils.Random,
  transformations : Array[Transformation],
  min_data_point_threshold : Int32,
  bucket_size_scale_factor : Double,
  test_fraction : Double,
  true_causal_effect : ((Array[Double]) -> Array[Double])?,
) -> DummyOutcomeSimulation {
  let groups = treatment_buckets(data, treatment_name, bucket_size_scale_factor)
  let covariates = data.select(variables)
  let effects : Array[Array[Double]] = []
  // The known effect of a bucket is the one of the validation rows of the first
  // simulation, the way the upstream caches it in its ordered map.
  let known : Array[Array[Double]] = []
  for simulation = 0; simulation < num_simulations; simulation = simulation + 1 {
    let row : Array[Double] = []
    for bucket = 0; bucket < groups.length(); bucket = bucket + 1 {
      let rows = groups[bucket]
      let chosen = draw_training_rows(rows, test_fraction, random)
      // The validation rows are the rows of the bucket that were not drawn, in
      // the order of the data, followed by a part of every other bucket. The
      // upstream builds the first set as the difference of two sets of row
      // tuples, which also drops the rows that repeat, and hands them out in
      // the order of its set.
      let validation_rows : Array[Int32] = []
      for position = 0; position < rows.length(); position = position + 1 {
        if !chosen[position] {
          validation_rows.push(rows[position])
        }
      }
      for other = 0; other < groups.length(); other = other + 1 {
        if other == bucket {
          continue
        }
        let others = groups[other]
        let drawn_other = draw_training_rows(others, test_fraction, random)
        for position = 0; position < others.length(); position = position + 1 {
          if drawn_other[position] {
            validation_rows.push(others[position])
          }
        }
      }
      // Too few rows to fit the model of the bucket, so the upstream falls back
      // to its default list.
      let bucket_transformations = if chosen_count(chosen) <=
        min_data_point_threshold {
        dummy_outcome_default_transformations()
      } else {
        transformations
      }
      let train_rows : Array[Int32] = []
      for position = 0; position < rows.length(); position = position + 1 {
        if chosen[position] {
          train_rows.push(rows[position])
        }
      }
      let x_train = covariates.take_rows(train_rows)
      let y_train = take_values(outcome, train_rows)
      let x_validation = covariates.take_rows(validation_rows)
      let y_validation = take_values(outcome, validation_rows)
      let simulated = process_transformations(
        Some(x_train),
        Some(y_train),
        x_validation,
        y_validation,
        bucket_transformations,
        random,
      )
      let treatment_validation = take_values_or_none(treatment, validation_rows)
      if known.length() <= bucket {
        known.push(
          causal_effect_of(
            validation_rows.length(),
            treatment_validation,
            true_causal_effect,
          ),
        )
      }
      let shifted = shift_outcome(simulated, known[bucket])
      let validation_data = data
        .take_rows(validation_rows)
        .with_numeric(outcome_name, shifted)
      let effect = reestimate(
        estimator, estimand, validation_data, treatment_value, control_value, target_units,
      )
      row.push(effect)
    }
    effects.push(row)
  }
  let true_effects : Array[Double] = []
  for values in known {
    if values.length() == 0 {
      true_effects.push(0.0)
    } else {
      true_effects.push(@utils.mean(values))
    }
  }
  { effects, true_effects, }
}

///|
/// The buckets of the treatment, one entry per bucket, in the ascending order of
/// the buckets, every entry holding the row indices of the bucket in the order of
/// the data.
///
/// A treatment whose column is discrete is grouped by its values, the way the
/// upstream groups a treatment of booleans. A numeric treatment is grouped by the
/// cut of its values over the edges that the ranges of the columns of the frame
/// give, which is the port of the bucketing of the upstream.
fn treatment_buckets(
  data : @api.DataFrame,
  treatment_name : String,
  bucket_size_scale_factor : Double,
) -> Array[Array[Int32]] {
  if data.is_discrete(treatment_name) {
    return discrete_buckets(data.discrete(treatment_name))
  }
  let values = data.numeric(treatment_name)
  let edges = bucket_edges(
    data, values, treatment_name, bucket_size_scale_factor,
  )
  let buckets : Array[Array[Int32]] = []
  for index = 0; index < edges.length() - 1; index = index + 1 {
    buckets.push([])
  }
  for i = 0; i < values.length(); i = i + 1 {
    let value = values[i]
    // `pandas.cut` cuts over the half open intervals `(edge, edge]`: a value on
    // an edge belongs to the bucket on its left, a value at or below the first
    // edge or above the last one belongs to none of them.
    for bucket = 0; bucket < edges.length() - 1; bucket = bucket + 1 {
      if value > edges[bucket] && value <= edges[bucket + 1] {
        buckets[bucket].push(i)
        break
      }
    }
  }
  buckets
}

///|
/// The edges of the cut of the treatment, one per numeric column of the frame.
///
/// This is the port of the `num_bins` of the upstream, whose expression reads the
/// ranges of the whole frame rather than the range of the treatment column, so
/// the edges are the ranges of the columns in the column order of the frame,
/// scaled by the standard deviation of the treatment.
fn bucket_edges(
  data : @api.DataFrame,
  treatment : Array[Double],
  treatment_name : String,
  bucket_size_scale_factor : Double,
) -> Array[Double] {
  if data.nrows() < 2 {
    abort(
      "The frame has " +
      data.nrows().to_string() +
      " rows, which is too few to build the buckets of " +
      treatment_name,
    )
  }
  let deviation = @utils.std_sample(treatment)
  if @utils.is_nan(deviation) || deviation == 0.0 {
    abort(
      "The treatment " +
      treatment_name +
      " has no spread, so its buckets cannot be built",
    )
  }
  let edges : Array[Double] = []
  for name in data.numeric_column_names() {
    let values = data.numeric(name)
    let mut low = values[0]
    let mut high = values[0]
    for value in values {
      if value < low {
        low = value
      }
      if value > high {
        high = value
      }
    }
    edges.push((high - low) / (bucket_size_scale_factor * deviation))
  }
  for i = 1; i < edges.length(); i = i + 1 {
    if edges[i] < edges[i - 1] {
      abort("bins must increase monotonically.")
    }
  }
  edges
}

///|
/// The buckets of a discrete treatment, one entry per value, in the ascending
/// order of the values, the way the `groupby` of the upstream orders them.
fn discrete_buckets(values : Array[String]) -> Array[Array[Int32]] {
  let distinct : Array[String] = []
  for value in values {
    if !distinct.contains(value) {
      distinct.push(value)
    }
  }
  distinct.sort_by(fn(a, b) { if a < b { -1 } else if a > b { 1 } else { 0 } })
  let buckets : Array[Array[Int32]] = []
  for _ in distinct {
    buckets.push([])
  }
  for i = 0; i < values.length(); i = i + 1 {
    for bucket = 0; bucket < distinct.length(); bucket = bucket + 1 {
      if values[i] == distinct[bucket] {
        buckets[bucket].push(i)
        break
      }
    }
  }
  buckets
}

///|
/// The known causal effect of the given treatment values.
///
/// The caller that gives no function asks for the default of the upstream, which
/// is zero for every row.
fn causal_effect_of(
  n : Int32,
  treatment : Array[Double]?,
  true_causal_effect : ((Array[Double]) -> Array[Double])?,
) -> Array[Double] {
  match true_causal_effect {
    Some(effect) =>
      match treatment {
        Some(values) => effect(values)
        None =>
          abort(
            "The true causal effect of a discrete treatment needs the numbers of its column",
          )
      }
    None => zeros_of(n)
  }
}

///|
/// The simulated outcome with the known causal effect added to it.
fn shift_outcome(
  outcome : Array[Double],
  effects : Array[Double],
) -> Array[Double] {
  if outcome.length() != effects.length() {
    abort(
      "The true causal effect returned " +
      effects.length().to_string() +
      " values for " +
      outcome.length().to_string() +
      " rows",
    )
  }
  let out : Array[Double] = []
  for i = 0; i < outcome.length(); i = i + 1 {
    out.push(outcome[i] + effects[i])
  }
  out
}

///|
/// The rows that the sample of the fraction of the upstream draws.
///
/// The entry of a position tells whether the row at that position was drawn.
fn draw_training_rows(
  rows : Array[Int32],
  fraction : Double,
  random : @utils.Random,
) -> Array[Bool] {
  let count = round_count(fraction, rows.length())
  let drawn : Array[Bool] = []
  for position = 0; position < rows.length(); position = position + 1 {
    drawn.push(false)
  }
  let positions = random.sample_without_replacement(
    index_column(rows.length()),
    count,
  )
  for position in positions {
    drawn[position.to_int()] = true
  }
  drawn
}

///|
/// The number of rows the fraction of the upstream draws.
///
/// The `sample` of pandas rounds the product of the fraction and the number of
/// rows; the port rounds half away from zero.
fn round_count(fraction : Double, n : Int32) -> Int32 {
  let count = (fraction * n.to_double()).round().to_int()
  if count < 0 {
    0
  } else if count > n {
    n
  } else {
    count
  }
}

///|
/// The number of the entries that are set.
fn chosen_count(chosen : Array[Bool]) -> Int32 {
  let mut count = 0
  for flag in chosen {
    if flag {
      count = count + 1
    }
  }
  count
}

///|
/// The values of the given rows, in the order of the rows.
fn take_values(values : Array[Double], rows : Array[Int32]) -> Array[Double] {
  let out : Array[Double] = []
  for row in rows {
    out.push(values[row])
  }
  out
}

///|
/// The values of the given rows of a column that may be discrete, in the order of
/// the rows.
fn take_values_or_none(
  values : Array[Double]?,
  rows : Array[Int32],
) -> Array[Double]? {
  match values {
    Some(values) => Some(take_values(values, rows))
    None => None
  }
}

///|
/// The transformations of the outcome, applied in the order of the list.
///
/// The transformations chain: the outcome that one of them produces is the input
/// of the next one. The training outcome is transformed the same way when the
/// caller gives training rows, because the model of a later transformation is
/// fitted on the transformed outcome, the way the upstream chains them.
fn process_transformations(
  x_train : @api.DataFrame?,
  outcome_train : Array[Double]?,
  x_validation : @api.DataFrame,
  outcome_validation : Array[Double],
  transformations : Array[Transformation],
  random : @utils.Random,
) -> Array[Double] {
  let mut train = outcome_train
  let mut validation = outcome_validation
  for transformation in transformations {
    match transformation {
      Zero => {
        if train is Some(_) {
          train = Some(zeros_of(train.unwrap().length()))
        }
        validation = zeros_of(validation.length())
      }
      Noise(std_dev) => {
        if train is Some(_) {
          train = Some(add_white_noise(train.unwrap(), std_dev, random))
        }
        validation = add_white_noise(validation, std_dev, random)
      }
      Permute(fraction) => {
        if train is Some(_) {
          train = Some(permute_outcome(train.unwrap(), fraction, random))
        }
        validation = permute_outcome(validation, fraction, random)
      }
      LinearRegression => {
        let x = require_training_frame(x_train, "linear_regression")
        let y = require_training_outcome(train, "linear_regression")
        let beta = linear_regression_fit(x, y)
        if train is Some(_) {
          train = Some(linear_regression_predict(beta, x))
        }
        validation = linear_regression_predict(beta, x_validation)
      }
      NearestNeighbour(k) => {
        let x = require_training_frame(x_train, "nearest_neighbour")
        let y = require_training_outcome(train, "nearest_neighbour")
        if train is Some(_) {
          train = Some(knn_predict(x, y, x, k))
        }
        validation = knn_predict(x, y, x_validation, k)
      }
      Estimate(model) => {
        let x = require_training_frame(x_train, "estimate")
        let y = require_training_outcome(train, "estimate")
        let (train_prediction, validation_prediction) = model(
          x, y, x_validation,
        )
        if train is Some(_) {
          train = Some(train_prediction)
        }
        validation = validation_prediction
      }
    }
  }
  validation
}

///|
/// The covariates of the training rows of a transformation that needs them.
fn require_training_frame(
  x_train : @api.DataFrame?,
  name : String,
) -> @api.DataFrame {
  match x_train {
    Some(x) => x
    None =>
      abort(
        "The transformation " +
        name +
        " needs the covariates of the training rows, but the list holds no estimator that has them",
      )
  }
}

///|
/// The outcome of the training rows of a transformation that needs it.
fn require_training_outcome(
  outcome_train : Array[Double]?,
  name : String,
) -> Array[Double] {
  match outcome_train {
    Some(y) => y
    None =>
      abort(
        "The transformation " + name + " needs the outcome of the training rows",
      )
  }
}

///|
/// An array of zeros of the given length.
fn zeros_of(n : Int32) -> Array[Double] {
  let out : Array[Double] = []
  for index = 0; index < n; index = index + 1 {
    out.push(0.0)
  }
  out
}

///|
/// The outcome with a white noise of the given standard deviation added to it.
///
/// This is the port of `noise` of the upstream, which draws one normal per row.
fn add_white_noise(
  outcome : Array[Double],
  std_dev : Double,
  random : @utils.Random,
) -> Array[Double] {
  let out : Array[Double] = []
  for value in outcome {
    out.push(value + std_dev * random.next_normal())
  }
  out
}

///|
/// The outcome with its rows permuted.
///
/// A fraction of one permutes every row, the `sample(frac=1)` of the upstream. A
/// smaller fraction swaps a row with a later one with the probability of half the
/// fraction, the Fisher-Yates shuffle the upstream describes.
fn permute_outcome(
  outcome : Array[Double],
  fraction : Double,
  random : @utils.Random,
) -> Array[Double] {
  let out = outcome.copy()
  if fraction == 1.0 {
    let shuffled = random.shuffle(index_column(out.length()))
    for i = 0; i < out.length(); i = i + 1 {
      out[i] = outcome[shuffled[i].to_int()]
    }
    return out
  }
  let probability = fraction / 2.0
  for change = 0; change < out.length(); change = change + 1 {
    if random.next_double() <= probability && change + 1 < out.length() {
      let index = change + 1 + random.next_int(out.length() - change - 1)
      let temp = out[change]
      out[change] = out[index]
      out[index] = temp
    }
  }
  out
}

///|
/// The design matrix of the covariates of the frame, with the column of ones that
/// the intercept of the linear regression takes.
fn design_of(frame : @api.DataFrame) -> @utils.Matrix {
  let names = frame.numeric_column_names()
  let n = frame.nrows()
  let design = @utils.Matrix::zeros(n, names.length() + 1)
  for i = 0; i < n; i = i + 1 {
    design.set(i, 0, 1.0)
    for j = 0; j < names.length(); j = j + 1 {
      design.set(i, j + 1, frame.numeric(names[j])[i])
    }
  }
  design
}

///|
/// The coefficients of the linear regression of the outcome on the covariates of
/// the frame.
fn linear_regression_fit(
  x : @api.DataFrame,
  y : Array[Double],
) -> Array[Double] {
  if x.nrows() != y.length() {
    abort(
      "The outcome has " +
      y.length().to_string() +
      " values for " +
      x.nrows().to_string() +
      " rows",
    )
  }
  @utils.ols_fit(design_of(x), y).beta
}

///|
/// The prediction of the linear regression on the covariates of the frame.
fn linear_regression_predict(
  beta : Array[Double],
  x : @api.DataFrame,
) -> Array[Double] {
  design_of(x).matvec(beta)
}

///|
/// The prediction of the k nearest neighbours on the covariates of the frame.
///
/// This is the port of the `KNeighborsRegressor` of scikit-learn with its default
/// weights: the mean of the targets of the k training rows that are nearest in
/// the euclidean distance, the ties taken in the order of the training rows.
fn knn_predict(
  x_train : @api.DataFrame,
  y_train : Array[Double],
  x : @api.DataFrame,
  k : Int32,
) -> Array[Double] {
  let names = x_train.numeric_column_names()
  let train = design_of(x_train)
  let queries = design_of(x)
  let neighbours = if k < 1 {
    abort("The number of neighbours has to be at least one")
  } else if k > y_train.length() {
    y_train.length()
  } else {
    k
  }
  let out : Array[Double] = []
  for i = 0; i < queries.nrows(); i = i + 1 {
    let distances : Array[Double] = []
    for j = 0; j < train.nrows(); j = j + 1 {
      let mut total = 0.0
      for column = 1; column < names.length() + 1; column = column + 1 {
        // The column of ones is shared by both frames, so it does not
        // contribute to the distance.
        let difference = queries.get(i, column) - train.get(j, column)
        total = total + difference * difference
      }
      distances.push(total)
    }
    let order : Array[Int32] = []
    for j = 0; j < distances.length(); j = j + 1 {
      order.push(j)
    }
    // An insertion sort on the distances, which keeps the order of the training
    // rows for the ties.
    for a = 1; a < order.length(); a = a + 1 {
      let key = order[a]
      let key_distance = distances[key]
      let mut b = a - 1
      while b >= 0 && distances[order[b]] > key_distance {
        order[b + 1] = order[b]
        b = b - 1
      }
      order[b + 1] = key
    }
    let mut total = 0.0
    for j = 0; j < neighbours; j = j + 1 {
      total = total + y_train[order[j]]
    }
    out.push(total / neighbours.to_double())
  }
  out
}
