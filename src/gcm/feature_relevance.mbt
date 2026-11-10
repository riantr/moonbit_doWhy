///|
/// The feature relevance of the inputs of a prediction model.
///
/// This is the port of `dowhy.gcm.feature_relevance`. The feature relevance
/// measures how much every input of a model contributes to its output. The
/// contribution of an input is the Shapley value of the set function that
/// compares the output of the model when some of the inputs are randomized with
/// the output of the model when none of them is.
///
/// The upstream draws its randomness from the global numpy generator; the port
/// draws it from the generator it is given, so that the same generator always
/// gives the same relevance.

///|
/// The comparison of the predictions of a randomized subset with the
/// predictions of the baseline.
///
/// This is the type of the set function of the upstream. The first argument
/// holds the predictions of the sample of interest for every sample of the
/// background, and the second one holds the predictions of the sample of
/// interest itself, repeated for every sample of the background. The upstream
/// compares the two with a scalar and a vector, which broadcasts the scalar
/// over the vector; the port compares them with two vectors of the same
/// length.
pub type SubsetScoringFunc = (Array[Double], Array[Double]) -> Double

///|
/// The feature relevance of every input of a prediction model for every sample
/// of the baseline.
///
/// This is the port of `dowhy.gcm.feature_relevance.feature_relevance_sample`.
/// The samples of the background are the samples of the joint distribution of
/// the inputs; they are the samples the inputs that are not part of a subset
/// are drawn from. The samples of the baseline are the samples the relevance is
/// estimated for.
///
/// The result has one row per sample of the baseline and one column per input.
/// When the set function is averaged, the result has one row.
///
/// The upstream evaluates the set function of a subset for every sample of the
/// baseline at once, and estimates the Shapley values of the whole set of
/// samples in one pass. The port estimates the Shapley values of every sample
/// of the baseline on its own, which gives the same numbers for a set function
/// that does not depend on the sample, and the same numbers in expectation for
/// the others.
///
/// The `max_batch_size` of the upstream is an optimisation of the evaluation of
/// the prediction model only; the port evaluates the whole thing at once and
/// ignores it.
pub fn feature_relevance_sample(
  prediction_method : (@utils.Matrix) -> Array[Double],
  feature_samples : @utils.Matrix,
  baseline_samples : @utils.Matrix,
  subset_scoring_func : SubsetScoringFunc,
  baseline_target_values : Array[Double]?,
  average_set_function : Bool,
  max_batch_size : Int32,
  randomize_features_jointly : Bool,
  shapley_config : ShapleyConfig,
  rng : @utils.Random,
) -> @utils.Matrix {
  let _ = max_batch_size
  let num_inputs = feature_samples.ncols()
  let num_baseline = baseline_samples.nrows()
  if feature_samples.nrows() == 0 {
    abort("the feature relevance needs samples of the inputs")
  }
  let baseline_values = match baseline_target_values {
    Some(values) => {
      if values.length() != num_baseline {
        abort(
          "the samples of interest and the given baseline values need to have the same number of rows",
        )
      }
      values
    }
    None => prediction_method(baseline_samples)
  }
  let perturbation = if randomize_features_jointly {
    RandomizeColumnsJointly
  } else {
    RandomizeColumnsIndependently
  }
  let relevance = @utils.Matrix::zeros(num_baseline, num_inputs)
  for i in 0..<num_baseline {
    let sample = @utils.Matrix::from_rows([baseline_samples.row(i)])
    // The baseline of the sample is repeated for every sample of the
    // background, because the upstream compares the predictions of the
    // background with the one prediction of the sample, and the subtraction of
    // the two broadcasts it over the background.
    let baseline : Array[Double] = []
    for _ in 0..<feature_samples.nrows() {
      baseline.push(baseline_values[i])
    }
    let set_func = fn(subset : Array[Bool]) -> Double {
      let indices : Array[Int32] = []
      for j in 0..<num_inputs {
        if subset[j] {
          indices.push(j)
        }
      }
      let predictions = marginal_expectation(
        prediction_method, feature_samples, sample, indices, false, perturbation,
        rng,
      )
      subset_scoring_func(predictions.row(0), baseline)
    }
    let values = estimate_shapley_values(set_func, num_inputs, shapley_config)
    for j in 0..<num_inputs {
      relevance.set(i, j, values[j])
    }
  }
  if average_set_function {
    let averaged = @utils.Matrix::zeros(1, num_inputs)
    for j in 0..<num_inputs {
      averaged.set(0, j, @utils.mean(relevance.col(j)))
    }
    averaged
  } else {
    relevance
  }
}

///|
/// The feature relevance of every input of a prediction model for the whole
/// distribution of the inputs.
///
/// This is the port of
/// `dowhy.gcm.feature_relevance.feature_relevance_distribution`. The samples of
/// the baseline are drawn from the samples of the inputs, and the relevance is
/// the average of the relevance of every sample of the baseline.
///
/// The result has one row and one column per input.
pub fn feature_relevance_distribution(
  prediction_method : (@utils.Matrix) -> Array[Double],
  feature_samples : @utils.Matrix,
  subset_scoring_func : SubsetScoringFunc,
  max_num_samples_randomization : Int32,
  max_num_baseline_samples : Int32,
  max_batch_size : Int32,
  randomize_features_jointly : Bool,
  shapley_config : ShapleyConfig,
  rng : @utils.Random,
) -> @utils.Matrix {
  let num_samples = feature_samples.nrows()
  let baseline_rows = rows_without_replacement(
    rng,
    num_samples,
    limit_of(max_num_baseline_samples, num_samples),
  )
  let randomization_rows = rows_without_replacement(
    rng,
    num_samples,
    limit_of(max_num_samples_randomization, num_samples),
  )
  let baseline = @utils.Matrix::from_rows(
    selected_rows(feature_samples, baseline_rows),
  )
  let background = @utils.Matrix::from_rows(
    selected_rows(feature_samples, randomization_rows),
  )
  feature_relevance_sample(
    prediction_method,
    background,
    baseline,
    subset_scoring_func,
    None,
    true,
    max_batch_size,
    randomize_features_jointly,
    shapley_config,
    rng,
  )
}

///|
/// The feature relevance of the direct parents of a node of a causal model.
///
/// This is the port of `dowhy.gcm.feature_relevance.parent_relevance`. The
/// relevance of every parent of the node and the relevance of the noise of the
/// node are the Shapley values of the set function of the inputs of the
/// mechanism of the node.
///
/// The result holds the relevance of every parent of the node, in the order of
/// the parents, and the relevance of the noise of the node. The upstream
/// returns a dictionary that is keyed by the parent and the target node; the
/// port returns the pairs of the parent and its relevance, because the target
/// node is the same for all of them.
///
/// The samples of the parents are drawn from the model when they are not given.
pub fn parent_relevance(
  causal_model : ProbabilisticCausalModel,
  target_node : String,
  parent_samples : @api.DataFrame?,
  subset_scoring_func : SubsetScoringFunc?,
  num_samples_randomization : Int32,
  num_samples_baseline : Int32,
  max_batch_size : Int32,
  shapley_config : ShapleyConfig,
  rng : @utils.Random,
) -> (Array[(String, Double)], Array[Double]) {
  if is_root_node(causal_model, target_node) {
    abort(
      "cannot compute the feature relevance of the parents of the node " +
      target_node +
      ", because it is a root node and it has no parents",
    )
  }
  let mechanism = match causal_model.causal_mechanism(target_node) {
    Some(value) => value
    None =>
      abort(
        "the node " +
        target_node +
        " has parents and needs a causal mechanism, but it has none",
      )
  }
  let parents = causal_model.graph.ordered_predecessors(target_node)
  let num_samples = larger_of(num_samples_randomization, num_samples_baseline)
  let samples = match parent_samples {
    Some(frame) => frame
    None => draw_samples(causal_model, num_samples, rng)
  }
  let scoring = match subset_scoring_func {
    Some(func) => func
    None =>
      if is_classifier_kind(mechanism.kind()) {
        variance_of_matching_values
      } else {
        variance_of_deviations
      }
  }
  let parent_columns = columns_of_parents(samples, parents)
  let parent_matrix = @utils.Matrix::from_columns(parent_columns)
  // The noise of a categorical mechanism is uniform on `[0, 1]`, and the noise
  // of the other mechanisms comes from their distribution.
  let classifier = is_classifier_kind(mechanism.kind())
  let noise = if classifier {
    mechanism.draw_categorical_noise(parent_matrix.nrows(), rng)
  } else {
    mechanism.noise_model.draw_samples(parent_matrix.nrows(), rng)
  }
  let features = @utils.Matrix::from_columns(parent_columns + [noise])
  let num_parents = parents.length()
  // The upstream compares the class labels of a categorical target; the port
  // compares their indices, which is the same comparison.
  let classes = if classifier {
    Some(mechanism.classifier_model().classes())
  } else {
    None
  }
  let prediction_method = fn(inputs : @utils.Matrix) -> Array[Double] {
    let parent_columns = @utils.Matrix::from_columns(
      first_columns(inputs, num_parents),
    )
    let noise_column = inputs.col(num_parents)
    match classes {
      Some(names) => {
        let labels = mechanism.evaluate_categorical(
          parent_columns, noise_column,
        )
        let out : Array[Double] = []
        for label in labels {
          out.push(class_index_of(names, label).to_double())
        }
        out
      }
      None => mechanism.evaluate(parent_columns, noise_column)
    }
  }
  let relevance = feature_relevance_distribution(
    prediction_method, features, scoring, num_samples_randomization, num_samples_baseline,
    max_batch_size, true, shapley_config, rng,
  )
  let parent_relevance : Array[(String, Double)] = []
  for i in 0..<num_parents {
    parent_relevance.push((parents[i], relevance.get(0, i)))
  }
  (parent_relevance, [relevance.get(0, num_parents)])
}

///|
/// The smaller of the two numbers.
fn limit_of(value : Int32, maximum : Int32) -> Int32 {
  if value < maximum {
    value
  } else {
    maximum
  }
}

///|
/// The larger of the two numbers.
fn larger_of(value : Int32, other : Int32) -> Int32 {
  if value > other {
    value
  } else {
    other
  }
}

///|
/// The first columns of the matrix.
fn first_columns(m : @utils.Matrix, count : Int32) -> Array[Array[Double]] {
  let columns : Array[Array[Double]] = []
  for i in 0..<count {
    columns.push(m.col(i))
  }
  columns
}

///|
/// The rows of the matrix with the given indices.
fn selected_rows(
  m : @utils.Matrix,
  indices : Array[Int32],
) -> Array[Array[Double]] {
  let rows : Array[Array[Double]] = []
  for index in indices {
    rows.push(m.row(index))
  }
  rows
}

///|
/// The given number of rows of the given number, without a replacement.
///
/// The upstream draws the rows with `numpy.random.choice` and without a
/// replacement; the port draws a permutation of the rows and takes the first
/// ones of it, which is the same set of rows.
fn rows_without_replacement(
  rng : @utils.Random,
  num_rows : Int32,
  count : Int32,
) -> Array[Int32] {
  let order = random_permutation(rng, num_rows)
  let out : Array[Int32] = []
  for i in 0..<count {
    out.push(order[i])
  }
  out
}

///|
/// The index of the given label in the given classes.
///
/// The upstream compares the class labels of a categorical target themselves;
/// the port compares their indices, which is the same comparison.
fn class_index_of(classes : Array[String], label : String) -> Int32 {
  for i in 0..<classes.length() {
    if classes[i] == label {
      return i
    }
  }
  abort("the causal mechanism returned a class it was not fitted on")
}

///|
/// The columns of the given parents of the samples.
fn columns_of_parents(
  samples : @api.DataFrame,
  parents : Array[String],
) -> Array[Array[Double]] {
  let columns : Array[Array[Double]] = []
  for parent in parents {
    columns.push(samples.numeric(parent))
  }
  columns
}
