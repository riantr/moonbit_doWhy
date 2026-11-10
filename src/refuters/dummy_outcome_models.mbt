///|
/// The random forest of the dummy outcome refuter.
///
/// This is the port of the `RandomForestRegressor` of scikit-learn, which the
/// upstream builds when the transformation list of the refuter names the
/// `random_forest` estimator. The forest holds a hundred trees, every tree
/// reads a sample of the training rows with replacement, and every split of a
/// tree reads the square root of the number of the features, the way the
/// defaults of scikit-learn do. The criterion of a split is the sum of the
/// squared errors of the two sides, the way the criterion of scikit-learn is,
/// and the value of a leaf is the mean of its samples.
///
/// The upstream draws the samples of every tree and the features of every
/// split with the global generator of numpy, which it does not seed; the port
/// draws them with its own generator, whose seed is the argument of the
/// function, so that a forest of the port is the same forest on every run.

///|
/// The number of the trees of the forest.
///
/// This is the default of scikit-learn.
const FOREST_NUM_TREES : Int32 = 100

///|
/// The smallest number of the samples of a leaf.
const FOREST_MIN_SAMPLES_LEAF : Int32 = 1

///|
/// The smallest number of the samples of a node that is split.
const FOREST_MIN_SAMPLES_SPLIT : Int32 = 2

///|
/// A sample of a node of a tree, with the value of the feature it is split on.
priv struct ForestSample {
  value : Double
  row : Int32
}

///|
/// A node of a tree of the forest.
priv struct ForestNode {
  /// The feature of the split, or minus one for a leaf.
  feature : Int32
  /// The threshold of the split.
  threshold : Double
  /// The index of the left child in the array of the nodes of the tree, or
  /// minus one for a leaf.
  left : Int32
  /// The index of the right child in the array of the nodes of the tree, or
  /// minus one for a leaf.
  right : Int32
  /// The mean of the samples of a leaf.
  value : Double
}

///|
/// A tree of the forest.
priv struct ForestTree {
  nodes : Array[ForestNode]
}

///|
/// The forest.
priv struct Forest {
  trees : Array[ForestTree]
}

///|
/// The split of the samples of a node.
priv struct ForestSplit {
  feature : Int32
  threshold : Double
  left : Array[Int32]
  right : Array[Int32]
}

///|
/// Fit the forest on the covariates and the outcome.
///
/// The depth of the trees is the one the caller gives, the way the upstream
/// gives the depth of its forest to scikit-learn.
fn forest_fit(
  x : @api.DataFrame,
  y : Array[Double],
  max_depth : Int32,
  rng : @utils.Random,
) -> Forest {
  if x.nrows() != y.length() {
    abort(
      "The outcome has " +
      y.length().to_string() +
      " values for " +
      x.nrows().to_string() +
      " rows",
    )
  }
  let matrix = forest_matrix(x)
  let max_features = forest_max_features(matrix.ncols())
  let trees : Array[ForestTree] = []
  for _ in 0..<FOREST_NUM_TREES {
    let rows = forest_bootstrap(matrix.nrows(), rng)
    let nodes : Array[ForestNode] = []
    let _ = forest_grow(nodes, matrix, y, rows, 0, max_depth, max_features, rng)
    trees.push({ nodes, })
  }
  { trees, }
}

///|
/// The prediction of the forest on the covariates of the frame.
///
/// The prediction of a row is the mean of the predictions of the trees, the
/// way the prediction of a forest of scikit-learn is.
fn forest_predict(forest : Forest, x : @api.DataFrame) -> Array[Double] {
  let matrix = forest_matrix(x)
  let out : Array[Double] = []
  for i in 0..<matrix.nrows() {
    let mut total = 0.0
    for tree in forest.trees {
      total = total + forest_predict_row(tree, matrix, i)
    }
    out.push(total / forest.trees.length().to_double())
  }
  out
}

///|
/// The covariates of the frame, without the column of ones that the linear
/// regression of the refuter uses.
fn forest_matrix(x : @api.DataFrame) -> @utils.Matrix {
  let columns : Array[Array[Double]] = []
  for name in x.numeric_column_names() {
    columns.push(x.numeric(name))
  }
  @utils.Matrix::from_columns(columns)
}

///|
/// The number of the features that a split reads.
///
/// This is the square root of the number of the features, the default of
/// scikit-learn for a regression.
fn forest_max_features(num_features : Int32) -> Int32 {
  let mut count = 1
  while (count + 1) * (count + 1) <= num_features {
    count = count + 1
  }
  count
}

///|
/// The rows of the samples of a tree, drawn with replacement.
fn forest_bootstrap(n : Int32, rng : @utils.Random) -> Array[Int32] {
  let rows : Array[Int32] = []
  if n <= 0 {
    return rows
  }
  for _ in 0..<n {
    rows.push(rng.next_int(n))
  }
  rows
}

///|
/// The features that a split reads, drawn without replacement.
fn forest_candidate_features(
  num_features : Int32,
  max_features : Int32,
  rng : @utils.Random,
) -> Array[Int32] {
  let count = if max_features > num_features {
    num_features
  } else {
    max_features
  }
  let chosen : Array[Int32] = []
  if num_features <= 0 {
    return chosen
  }
  let taken : Array[Bool] = []
  for _ in 0..<num_features {
    taken.push(false)
  }
  while chosen.length() < count {
    let feature = rng.next_int(num_features)
    if !taken[feature] {
      taken[feature] = true
      chosen.push(feature)
    }
  }
  chosen
}

///|
/// The node of the tree that holds the given samples.
///
/// The node is added to the array of the nodes of the tree and its index is
/// returned. The children of the node are grown after it, so that the index
/// of a node is known as soon as it is built and the children of a node never
/// have to be moved.
///
/// A node whose samples cannot be split is a leaf: its feature is minus one
/// and its value is the mean of its samples.
fn forest_grow(
  nodes : Array[ForestNode],
  x : @utils.Matrix,
  y : Array[Double],
  rows : Array[Int32],
  depth : Int32,
  max_depth : Int32,
  max_features : Int32,
  rng : @utils.Random,
) -> Int32 {
  let index = nodes.length()
  nodes.push({
    feature: -1,
    threshold: 0.0,
    left: -1,
    right: -1,
    value: forest_mean(y, rows),
  })
  if depth >= max_depth || rows.length() < FOREST_MIN_SAMPLES_SPLIT {
    return index
  }
  let candidates = forest_candidate_features(x.ncols(), max_features, rng)
  let split = forest_best_split(x, y, rows, candidates)
  match split {
    None => index
    Some(found) => {
      let left = forest_grow(
        nodes,
        x,
        y,
        found.left,
        depth + 1,
        max_depth,
        max_features,
        rng,
      )
      let right = forest_grow(
        nodes,
        x,
        y,
        found.right,
        depth + 1,
        max_depth,
        max_features,
        rng,
      )
      nodes.set(index, {
        feature: found.feature,
        threshold: found.threshold,
        left,
        right,
        value: 0.0,
      })
      index
    }
  }
}

///|
/// The split of the samples with the largest gain, when there is one.
///
/// The gain of a split is the sum of the squared errors of the node minus the
/// sums of the squared errors of its two sides. The threshold of the split is
/// the middle of the two values that surround it.
fn forest_best_split(
  x : @utils.Matrix,
  y : Array[Double],
  rows : Array[Int32],
  candidates : Array[Int32],
) -> ForestSplit? {
  let n = rows.length()
  let mut total = 0.0
  let mut total_square = 0.0
  for row in rows {
    let value = y[row]
    total = total + value
    total_square = total_square + value * value
  }
  let parent = total_square - total * total / n.to_double()
  let mut best_feature = -1
  let mut best_threshold = 0.0
  let mut best_gain = 0.0
  let mut best_k = -1
  let mut best_sorted : Array[ForestSample] = []
  for feature in candidates {
    let sorted = forest_sorted_samples(x, rows, feature)
    let mut left_sum = 0.0
    let mut left_square = 0.0
    for k = 1; k < sorted.length(); k = k + 1 {
      let value = y[sorted[k].row]
      left_sum = left_sum + value
      left_square = left_square + value * value
      // A split is only possible between two different values.
      if sorted[k - 1].value == sorted[k].value {
        continue
      }
      let left_n = k
      let right_n = sorted.length() - k
      if left_n < FOREST_MIN_SAMPLES_LEAF || right_n < FOREST_MIN_SAMPLES_LEAF {
        continue
      }
      let right_sum = total - left_sum
      let right_square = total_square - left_square
      let left_error = left_square - left_sum * left_sum / left_n.to_double()
      let right_error = right_square -
        right_sum * right_sum / right_n.to_double()
      let gain = parent - (left_error + right_error)
      if gain > best_gain {
        best_gain = gain
        best_feature = feature
        best_threshold = (sorted[k - 1].value + sorted[k].value) / 2.0
        best_k = k
        best_sorted = sorted
      }
    }
  }
  if best_k < 0 {
    return None
  }
  let left : Array[Int32] = []
  let right : Array[Int32] = []
  for k = 0; k < best_sorted.length(); k = k + 1 {
    if k < best_k {
      left.push(best_sorted[k].row)
    } else {
      right.push(best_sorted[k].row)
    }
  }
  Some({ feature: best_feature, threshold: best_threshold, left, right, })
}

///|
/// The samples of a node, sorted by the value of the given feature.
fn forest_sorted_samples(
  x : @utils.Matrix,
  rows : Array[Int32],
  feature : Int32,
) -> Array[ForestSample] {
  let samples : Array[ForestSample] = []
  for row in rows {
    samples.push({ value: x.get(row, feature), row, })
  }
  samples.sort_by(fn(a, b) {
    if a.value < b.value {
      -1
    } else if a.value > b.value {
      1
    } else {
      0
    }
  })
  samples
}

///|
/// The mean of the targets of the given rows.
fn forest_mean(y : Array[Double], rows : Array[Int32]) -> Double {
  if rows.length() == 0 {
    return 0.0
  }
  let mut total = 0.0
  for row in rows {
    total = total + y[row]
  }
  total / rows.length().to_double()
}

///|
/// The prediction of the tree on the row of the matrix.
fn forest_predict_row(
  tree : ForestTree,
  x : @utils.Matrix,
  row : Int32,
) -> Double {
  let mut index = 0
  let mut node = tree.nodes[0]
  while node.feature >= 0 {
    if x.get(row, node.feature) <= node.threshold {
      index = node.left
    } else {
      index = node.right
    }
    node = tree.nodes[index]
  }
  node.value
}
