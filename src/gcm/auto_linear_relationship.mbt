///|
/// The test of a linear relationship between the features and the target.
///
/// This is the port of `dowhy.gcm.auto.has_linear_relationship`. The upstream
/// splits the rows into a training part and a test part, it fits a linear
/// model and a non-linear model on the training part and it compares the two
/// models on the test part. For a continuous target the mean squared error of
/// the linear model has to be no larger than the one of the non-linear model,
/// and for a categorical target the linear model has to classify at least as
/// many rows of the test part correctly as the non-linear model.
///
/// The deviations of the port are the following ones. The upstream compares
/// the linear regression with the histogram gradient boosting regression, and
/// the logistic regression with the histogram gradient boosting classifier;
/// the port compares the ordinary least squares regression with the nearest
/// neighbour regression, and the logistic regression with the nearest
/// neighbour classifier. The upstream splits the rows with the global
/// generator of numpy, so its split is not reproducible; the port splits them
/// with its own generator, whose seed is an argument of the function. The
/// upstream picks the classes of the largest remainder of a stratified split
/// at random when several of them have the same remainder; the port picks them
/// in the order of the classes.

///|
/// Whether the relationship between the features and the target is linear.
///
/// The target is the only column of the given frame, and its kind decides
/// whether the relationship is tested with a regression or with a
/// classification.
pub fn has_linear_relationship(
  x : @api.DataFrame,
  y : @api.DataFrame,
  max_num_samples~ : Int32 = 3000,
  seed~ : UInt64 = 0UL,
) -> Bool {
  let names = y.column_names()
  if names.length() == 0 {
    abort("the target of the test of a linear relationship holds no column")
  }
  if x.nrows() != y.nrows() {
    abort(
      "the features and the target of the test of a linear relationship hold a different number of rows",
    )
  }
  let name = names[0]
  if y.is_discrete(name) {
    categorical_relationship(x, y.discrete(name), max_num_samples, seed)
  } else {
    continuous_relationship(x, y.numeric(name), max_num_samples, seed)
  }
}

///|
/// The test of a linear relationship for a continuous target.
///
/// The mean squared error of the linear model on the test part has to be no
/// larger than the one of the non-linear model.
fn continuous_relationship(
  x : @api.DataFrame,
  y : Array[Double],
  max_num_samples : Int32,
  seed : UInt64,
) -> Bool {
  let n = x.nrows()
  let num_train = relationship_training_size(n, max_num_samples)
  let num_test = relationship_test_size(n, num_train, max_num_samples)
  let rng = @utils.Random::new(seed)
  let (train_rows, held_out_rows) = shuffle_split(n, num_train, num_test, rng)
  let (train_x, held_out_x) = relationship_design_matrices(
    x,
    train_rows,
    held_out_rows,
    take_values(y, train_rows),
  )
  let train_y = take_values(y, train_rows)
  let held_out_y = take_values(y, held_out_rows)
  let linear = PredictionModel::linear().fit(train_x, train_y)
  let neighbours = PredictionModel::nearest_neighbour().fit(train_x, train_y)
  let linear_error = mean_squared_error(held_out_y, linear.predict(held_out_x))
  let neighbour_error = mean_squared_error(
    held_out_y,
    neighbours.predict(held_out_x),
  )
  linear_error <= neighbour_error
}

///|
/// The test of a linear relationship for a categorical target.
///
/// The linear model has to classify at least as many rows of the test part
/// correctly as the non-linear model.
fn categorical_relationship(
  x : @api.DataFrame,
  y : Array[String],
  max_num_samples : Int32,
  seed : UInt64,
) -> Bool {
  // A class that holds a single row is duplicated, so that the stratified
  // split can put one of its rows in the training part and one in the test
  // part.  This is what the upstream does.
  let rows = rows_with_duplicated_singletons(y)
  let labels = take_labels(y, rows)
  let n = rows.length()
  let num_train = relationship_training_size(n, max_num_samples)
  let num_test = relationship_test_size(n, num_train, max_num_samples)
  let rng = @utils.Random::new(seed)
  let (train_rows, held_out_rows) = stratified_shuffle_split(
    labels, num_train, num_test, rng,
  )
  let data = x.take_rows(rows)
  let (train_x, held_out_x) = relationship_design_matrices(
    data,
    train_rows,
    held_out_rows,
    label_numbers(labels),
  )
  let train_labels = take_labels(labels, train_rows)
  let held_out_labels = take_labels(labels, held_out_rows)
  let linear = ClassificationModel::logistic().fit(train_x, train_labels)
  let neighbours = ClassificationModel::nearest_neighbour().fit(
    train_x, train_labels,
  )
  let linear_correct = correct_classifications(
    linear.predict(held_out_x),
    held_out_labels,
  )
  let neighbour_correct = correct_classifications(
    neighbours.predict(held_out_x),
    held_out_labels,
  )
  linear_correct >= neighbour_correct
}

///|
/// The design matrix of the training part and of the test part of the split.
///
/// The encoder is fitted on the training part and applied to both parts, the
/// way the upstream fits its encoders on the training rows and applies them
/// to the test rows. The upstream uses the one-hot encoder when the data
/// holds at most seven categories and the CatBoost encoder otherwise; the
/// port does the same.
fn relationship_design_matrices(
  x : @api.DataFrame,
  train_rows : Array[Int32],
  held_out_rows : Array[Int32],
  target : Array[Double],
) -> (@utils.Matrix, @utils.Matrix) {
  let columns = x.column_names()
  let train_frame = x.take_rows(train_rows)
  let held_out_frame = x.take_rows(held_out_rows)
  let discrete : Array[String] = []
  for column in columns {
    if train_frame.is_discrete(column) {
      discrete.push(column)
    }
  }
  if number_of_categories(train_frame, discrete) > CATBOOST_THRESHOLD {
    let encoders = CatBoostEncoders::fit(train_frame, discrete, target)
    return (
      encoders.design_matrix(train_frame, columns),
      encoders.design_matrix(held_out_frame, columns),
    )
  }
  let encoder = ParentEncoder::fit(train_frame, columns)
  (
    encoder.design_matrix(train_frame, columns),
    encoder.design_matrix(held_out_frame, columns),
  )
}

///|
/// The number of the rows of the training part of the split.
///
/// This is the port of the upstream, which takes seventy percent of the rows
/// and at most `max_num_samples` of them.
fn relationship_training_size(n : Int32, max_num_samples : Int32) -> Int32 {
  let wanted = @utils.round_half_even(n.to_double() * 0.7).to_int()
  if wanted < max_num_samples {
    wanted
  } else {
    max_num_samples
  }
}

///|
/// The number of the rows of the test part of the split.
///
/// This is the port of the upstream, which takes the rows that are left and at
/// most `max_num_samples` of them.
fn relationship_test_size(
  n : Int32,
  num_train : Int32,
  max_num_samples : Int32,
) -> Int32 {
  let wanted = n - num_train
  if wanted < max_num_samples {
    wanted
  } else {
    max_num_samples
  }
}

///|
/// The rows of the training part and of the test part of the split.
///
/// This is the port of the split of `sklearn.model_selection.train_test_split`
/// without a stratification: the rows are shuffled and the first ones are the
/// training part.
fn shuffle_split(
  n : Int32,
  num_train : Int32,
  num_test : Int32,
  rng : @utils.Random,
) -> (Array[Int32], Array[Int32]) {
  let indices = shuffle_indices(n, rng)
  let train : Array[Int32] = []
  for i in 0..<num_train {
    if i < indices.length() {
      train.push(indices[i])
    }
  }
  let held_out : Array[Int32] = []
  for i in num_train..<(num_train + num_test) {
    if i < indices.length() {
      held_out.push(indices[i])
    }
  }
  (train, held_out)
}

///|
/// The rows of the training part and of the test part of a stratified split.
///
/// This is the port of the split of `sklearn.model_selection.train_test_split`
/// with a stratification: every class keeps the same share of the rows of the
/// training part and of the test part.
fn stratified_shuffle_split(
  labels : Array[String],
  num_train : Int32,
  num_test : Int32,
  rng : @utils.Random,
) -> (Array[Int32], Array[Int32]) {
  let classes = sorted_distinct_labels(labels)
  let n = labels.length()
  let counts : Array[Int32] = []
  for label in classes {
    counts.push(number_of_class(labels, label))
  }
  let train_counts = approximate_mode(counts, n, num_train)
  let remaining : Array[Int32] = []
  for k in 0..<counts.length() {
    remaining.push(counts[k] - train_counts[k])
  }
  let test_counts = approximate_mode(remaining, n - num_train, num_test)
  let train : Array[Int32] = []
  let held_out : Array[Int32] = []
  for k in 0..<classes.length() {
    let rows = rows_of_class(labels, classes[k])
    let shuffled = shuffle_indices_of(rows, rng)
    let train_count = train_counts[k]
    for i in 0..<train_count {
      if i < shuffled.length() {
        train.push(shuffled[i])
      }
    }
    for i in train_count..<(train_count + test_counts[k]) {
      if i < shuffled.length() {
        held_out.push(shuffled[i])
      }
    }
  }
  (train, held_out)
}

///|
/// The number of the rows of every class in a part of a stratified split.
///
/// This is the port of `sklearn.model_selection._approximate_mode`: the share
/// of a class is proportional to the number of its rows, the shares are
/// rounded down and the rows that are left over go to the classes whose share
/// has the largest remainder.
fn approximate_mode(
  counts : Array[Int32],
  total : Int32,
  draws : Int32,
) -> Array[Int32] {
  let out : Array[Int32] = []
  let remainders : Array[Double] = []
  let sum = total.to_double()
  for count in counts {
    let continuous = if sum > 0.0 {
      draws.to_double() * count.to_double() / sum
    } else {
      0.0
    }
    let floored = continuous.floor()
    out.push(floored.to_int())
    remainders.push(continuous - floored)
  }
  let mut needed = draws
  for count in out {
    needed = needed - count
  }
  // The classes whose share has the largest remainder get a row more, until
  // every row of the part is given.
  let order : Array[Int32] = []
  for k in 0..<counts.length() {
    order.push(k)
  }
  order.sort_by(fn(a, b) {
    let c = @utils.compare_double(remainders[b], remainders[a])
    if c != 0 {
      c
    } else if a < b {
      -1
    } else if a > b {
      1
    } else {
      0
    }
  })
  for k in order {
    if needed <= 0 {
      break
    }
    out[k] = out[k] + 1
    needed = needed - 1
  }
  out
}

///|
/// The rows of the data, with the rows of the classes that hold a single
/// sample duplicated.
///
/// This is the port of the duplication of the upstream, which makes sure that
/// every class holds at least two rows before it splits the rows with a
/// stratified split.
fn rows_with_duplicated_singletons(labels : Array[String]) -> Array[Int32] {
  let rows : Array[Int32] = []
  for i in 0..<labels.length() {
    rows.push(i)
  }
  for label in sorted_distinct_labels(labels) {
    let class_rows = rows_of_class(labels, label)
    if class_rows.length() == 1 {
      rows.push(class_rows[0])
    }
  }
  rows
}

///|
/// The rows of the given class.
fn rows_of_class(labels : Array[String], label : String) -> Array[Int32] {
  let rows : Array[Int32] = []
  for i in 0..<labels.length() {
    if labels[i] == label {
      rows.push(i)
    }
  }
  rows
}

///|
/// The number of the rows of the given class.
fn number_of_class(labels : Array[String], label : String) -> Int32 {
  let mut count = 0
  for value in labels {
    if value == label {
      count = count + 1
    }
  }
  count
}

///|
/// The number of the class of every label.
///
/// This is the port of the label encoder of the upstream, which numbers the
/// classes of a categorical target from zero.
fn label_numbers(labels : Array[String]) -> Array[Double] {
  let classes = sorted_distinct_labels(labels)
  let out : Array[Double] = []
  for label in labels {
    out.push(index_of_class(classes, label).to_double())
  }
  out
}

///|
/// The number of the rows the model classifies correctly.
fn correct_classifications(
  predicted : Array[String],
  expected : Array[String],
) -> Int32 {
  let mut count = 0
  for i in 0..<expected.length() {
    if i < predicted.length() && predicted[i] == expected[i] {
      count = count + 1
    }
  }
  count
}
