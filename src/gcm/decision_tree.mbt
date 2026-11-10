///|
/// A node of a decision tree.
///
/// A node is a leaf when its feature is negative. A leaf holds the number of the
/// samples of every class of the node, and an inner node holds the feature of
/// its split and the threshold of it: a row goes to the left child of the node
/// when the value of the feature is at most the threshold.
pub struct TreeNode {
  /// The index of the feature of the split, negative when the node is a leaf.
  feature : Int32
  /// The threshold of the split of the node.
  threshold : Double
  /// The left child of the node.
  left : TreeNode?
  /// The right child of the node.
  right : TreeNode?
  /// The number of the samples of every class of the node.
  counts : Array[Int32]
}

///|
/// The split of a node of a decision tree.
priv struct TreeSplit {
  /// The index of the feature of the split.
  feature : Int32
  /// The threshold of the split.
  threshold : Double
}

///|
/// A classification model of a decision tree.
///
/// This is the port of `sklearn.tree.DecisionTreeClassifier` with its default
/// parameters: the gini impurity as the criterion, every feature of the design
/// matrix at every split, a node of at least two samples and a leaf of at least
/// one sample.
///
/// The tree grows greedily, the way the tree of scikit-learn grows: a node is
/// split by the threshold that lowers the gini impurity of its children the
/// most, and the threshold of a feature is the middle of two consecutive
/// values of it, so that a row goes to the left child of the node when the
/// value of the feature is at most the threshold.
///
/// Two splits of the same impurity are the same split for the port: the first
/// feature and the first threshold of it win. The splitter of scikit-learn
/// keeps the first split it finds as well, but it measures the impurity of a
/// split with its own arithmetic, whose last bits can break a tie the other
/// way.
pub struct DecisionTreeClassifier {
  /// The root of the tree.
  root : TreeNode?
  /// The classes of the model, in lexicographic order.
  classes : Array[String]
  /// The smallest number of the samples of a leaf.
  min_samples_leaf : Int32
  /// The smallest number of the samples of a node that can be split.
  min_samples_split : Int32
  /// Whether the model has been fitted.
  fitted : Bool
}

///|
/// An unfitted decision tree classification model.
///
/// The two limits are the defaults of scikit-learn: a leaf holds at least one
/// sample and a node that is split holds at least two.
pub fn DecisionTreeClassifier::new() -> DecisionTreeClassifier {
  {
    root: None,
    classes: [],
    min_samples_leaf: 1,
    min_samples_split: 2,
    fitted: false,
  }
}

///|
/// Fit the model on the given labels.
///
/// The result is a new model; the model the fit is called on stays as it is.
pub fn DecisionTreeClassifier::fit(
  self : DecisionTreeClassifier,
  x : @utils.Matrix,
  y : Array[String],
) -> DecisionTreeClassifier {
  let classes = sorted_distinct_labels(y)
  if classes.length() < 2 {
    abort(
      "the target of a classifier needs at least two classes, but it has " +
      classes.length().to_string() +
      " classes",
    )
  }
  let encoded = tree_encode(y, classes)
  let indices : Array[Int32] = []
  for i in 0..<encoded.length() {
    indices.push(i)
  }
  let root = tree_build(
    x,
    encoded,
    indices,
    classes.length(),
    self.min_samples_split,
    self.min_samples_leaf,
  )
  {
    root: Some(root),
    classes,
    min_samples_leaf: self.min_samples_leaf,
    min_samples_split: self.min_samples_split,
    fitted: true,
  }
}

///|
/// The probability of every class for every row of the design matrix.
///
/// The probability of a class of a leaf is the share of the samples of the leaf
/// that belong to it, the way the probabilities of the leaves of scikit-learn
/// are the distribution of the classes of the samples of the leaf.
pub fn DecisionTreeClassifier::predict_probabilities(
  self : DecisionTreeClassifier,
  x : @utils.Matrix,
) -> Array[Array[Double]] {
  if !self.fitted {
    abort("the classification model has not been fitted")
  }
  let out : Array[Array[Double]] = []
  for i in 0..<x.nrows() {
    let counts = match self.root {
      Some(root) => tree_leaf_counts(root, x, i)
      None => []
    }
    let total = tree_total(counts)
    let row : Array[Double] = []
    for count in counts {
      if total == 0 {
        row.push(0.0)
      } else {
        row.push(count.to_double() / total.to_double())
      }
    }
    out.push(row)
  }
  out
}

///|
/// The predicted class of every row of the design matrix.
///
/// The class of a row is the one of the largest probability, the way the class
/// of a row of scikit-learn is the one of the largest probability.
pub fn DecisionTreeClassifier::predict(
  self : DecisionTreeClassifier,
  x : @utils.Matrix,
) -> Array[String] {
  let out : Array[String] = []
  for probabilities in self.predict_probabilities(x) {
    let mut best = 0
    for k in 1..<probabilities.length() {
      if probabilities[k] > probabilities[best] {
        best = k
      }
    }
    out.push(self.classes[best])
  }
  out
}

///|
/// The index of the class of every label.
fn tree_encode(y : Array[String], classes : Array[String]) -> Array[Int32] {
  let encoded : Array[Int32] = []
  for label in y {
    let mut index = 0
    let mut found = false
    for k in 0..<classes.length() {
      if classes[k] == label {
        index = k
        found = true
        break
      }
    }
    if !found {
      abort("the label " + label + " is not one of the classes of the model")
    }
    encoded.push(index)
  }
  encoded
}

///|
/// The node of the tree of the given samples.
///
/// A node of a single sample, a node of a single class and a node of too few
/// samples are leaves, the way the tree of scikit-learn stops at them.
fn tree_build(
  x : @utils.Matrix,
  encoded : Array[Int32],
  indices : Array[Int32],
  n_classes : Int32,
  min_samples_split : Int32,
  min_samples_leaf : Int32,
) -> TreeNode {
  let counts = tree_counts(encoded, indices, n_classes)
  if indices.length() < min_samples_split ||
    indices.length() < 2 * min_samples_leaf ||
    tree_distinct(counts) < 2 {
    return { feature: -1, threshold: 0.0, left: None, right: None, counts, }
  }
  let split = tree_best_split(
    x, encoded, indices, counts, n_classes, min_samples_leaf,
  )
  match split {
    None => { feature: -1, threshold: 0.0, left: None, right: None, counts, }
    Some(value) => {
      let left : Array[Int32] = []
      let right : Array[Int32] = []
      for index in indices {
        if x.get(index, value.feature) <= value.threshold {
          left.push(index)
        } else {
          right.push(index)
        }
      }
      {
        feature: value.feature,
        threshold: value.threshold,
        left: Some(
          tree_build(
            x, encoded, left, n_classes, min_samples_split, min_samples_leaf,
          ),
        ),
        right: Some(
          tree_build(
            x, encoded, right, n_classes, min_samples_split, min_samples_leaf,
          ),
        ),
        counts,
      }
    }
  }
}

///|
/// The split of a node that lowers the gini impurity of its children the most.
///
/// A split of a feature is the middle of two consecutive values of it, so that
/// a row goes to the left child when the value of the feature is at most the
/// threshold. Two samples of the same value are never separated, and a split
/// that leaves too few samples on one of its sides is no split at all.
fn tree_best_split(
  x : @utils.Matrix,
  encoded : Array[Int32],
  indices : Array[Int32],
  counts : Array[Int32],
  n_classes : Int32,
  min_samples_leaf : Int32,
) -> TreeSplit? {
  let total = indices.length()
  let mut best : TreeSplit? = None
  let mut best_score = 0.0
  for feature in 0..<x.ncols() {
    let column = feature
    // The samples of the node, sorted by the value of the feature.
    let order = indices.copy()
    order.sort_by(fn(a, b) {
      @utils.compare_double(x.get(a, column), x.get(b, column))
    })
    let left_counts = tree_zero_counts(n_classes)
    for position in 0..<(total - 1) {
      let row = order[position]
      let class = encoded[row]
      left_counts[class] = left_counts[class] + 1
      let value = x.get(row, column)
      let next = x.get(order[position + 1], column)
      if value == next {
        continue
      }
      let left_n = position + 1
      let right_n = total - left_n
      if left_n < min_samples_leaf || right_n < min_samples_leaf {
        continue
      }
      let threshold = (value + next) / 2.0
      let right_counts = tree_subtract(counts, left_counts)
      let score = (
          left_n.to_double() * tree_gini(left_counts) +
          right_n.to_double() * tree_gini(right_counts)
        ) /
        total.to_double()
      match best {
        None => {
          best = Some({ feature, threshold, })
          best_score = score
        }
        Some(_) =>
          // A split of the same impurity is not a better split: the first
          // feature and the first threshold of it win.
          if score < best_score - 0.000000000001 {
            best = Some({ feature, threshold, })
            best_score = score
          }
      }
    }
  }
  best
}

///|
/// The number of the samples of every class of the given samples.
fn tree_counts(
  encoded : Array[Int32],
  indices : Array[Int32],
  n_classes : Int32,
) -> Array[Int32] {
  let counts = tree_zero_counts(n_classes)
  for index in indices {
    let class = encoded[index]
    counts[class] = counts[class] + 1
  }
  counts
}

///|
/// The number of the samples of every class, all of them zero.
fn tree_zero_counts(n_classes : Int32) -> Array[Int32] {
  let counts : Array[Int32] = []
  for _ in 0..<n_classes {
    counts.push(0)
  }
  counts
}

///|
/// The counts of every class without the counts of the first ones.
fn tree_subtract(counts : Array[Int32], other : Array[Int32]) -> Array[Int32] {
  let out : Array[Int32] = []
  for k in 0..<counts.length() {
    out.push(counts[k] - other[k])
  }
  out
}

///|
/// The number of the samples of the given counts.
fn tree_total(counts : Array[Int32]) -> Int32 {
  let mut total = 0
  for count in counts {
    total = total + count
  }
  total
}

///|
/// The number of the classes of the given counts that hold a sample.
fn tree_distinct(counts : Array[Int32]) -> Int32 {
  let mut distinct = 0
  for count in counts {
    if count > 0 {
      distinct = distinct + 1
    }
  }
  distinct
}

///|
/// The gini impurity of the given counts.
///
/// This is the gini impurity of scikit-learn: one minus the sum of the squares
/// of the shares of the classes of the samples.
fn tree_gini(counts : Array[Int32]) -> Double {
  let total = tree_total(counts)
  if total == 0 {
    return 0.0
  }
  let mut squares = 0.0
  for count in counts {
    squares = squares + count.to_double() * count.to_double()
  }
  1.0 - squares / (total.to_double() * total.to_double())
}

///|
/// The counts of the leaf the given row of the design matrix falls into.
fn tree_leaf_counts(
  root : TreeNode,
  x : @utils.Matrix,
  row : Int32,
) -> Array[Int32] {
  let mut node = root
  while node.feature >= 0 {
    let left = match node.left {
      Some(value) => value
      None => break
    }
    let right = match node.right {
      Some(value) => value
      None => break
    }
    if x.get(row, node.feature) <= node.threshold {
      node = left
    } else {
      node = right
    }
  }
  node.counts
}

///|
/// The tests of the decision tree classifier of the `gcm` package.
///
/// The tree is the port of `sklearn.tree.DecisionTreeClassifier` with its
/// default parameters. The fixture is the one of
/// `_verify/decision_tree_reference.py`, which fits the tree of scikit-learn on
/// the same rows and prints its nodes.
///
/// The tree of scikit-learn breaks the tie of two splits of the same impurity
/// at random, because it takes its randomness from the global generator of
/// numpy, which it does not seed. The tree of the port breaks the tie the other
/// way: the first feature and the first threshold of it win. The two trees
/// therefore differ at the nodes of the ties, and the fixture of the port has
/// one of them; the shape of the two trees and the predictions of the two are
/// the same.

///|
/// The fixture of the decision tree: two columns of the standard normal
/// distribution, a column of zeros and ones, and the target of the relation of
/// the three columns.
fn tree_fixture() -> (@utils.Matrix, Array[String]) {
  let rng = @utils.Random::new(2071)
  let first : Array[Double] = []
  let second : Array[Double] = []
  let third : Array[Double] = []
  for _ in 0..<200 {
    first.push(rng.next_normal())
    second.push(rng.next_normal())
    if rng.next_double() > 0.5 {
      third.push(1.0)
    } else {
      third.push(0.0)
    }
  }
  let labels : Array[String] = []
  for i in 0..<200 {
    if first[i] + second[i] - 0.5 * third[i] > 0.0 {
      labels.push("true")
    } else {
      labels.push("false")
    }
  }
  (@utils.Matrix::from_columns([first, second, third]), labels)
}

///|
/// The number of the nodes of a tree and the number of its leaves.
fn tree_shape(node : TreeNode) -> (Int32, Int32) {
  if node.feature < 0 {
    return (1, 1)
  }
  let left = match node.left {
    Some(value) => value
    None => return (1, 0)
  }
  let right = match node.right {
    Some(value) => value
    None => return (1, 0)
  }
  let (left_nodes, left_leaves) = tree_shape(left)
  let (right_nodes, right_leaves) = tree_shape(right)
  (left_nodes + right_nodes + 1, left_leaves + right_leaves)
}

///|
test "the decision tree of the port is the tree of scikit-learn" {
  let (x, labels) = tree_fixture()
  let tree = DecisionTreeClassifier::new().fit(x, labels)
  let root = match tree.root {
    Some(value) => value
    None => abort("the tree has no root")
  }
  // The shape of the tree of scikit-learn on the fixture: thirty one nodes and
  // sixteen leaves.
  let (nodes, leaves) = tree_shape(root)
  assert_eq(nodes, 31)
  assert_eq(leaves, 16)
  // The split of the root of the tree of scikit-learn. Its threshold is kept in
  // single precision, so the two differ in their last bits.
  assert_eq(root.feature, 1)
  assert_true((root.threshold - 0.13489530980587006).abs() < 0.000001)
  // The predictions of the two trees are the same.
  let model = ClassificationModel::decision_tree().fit(x, labels)
  let probabilities = model.predict_probabilities(x)
  assert_eq(probabilities.length(), 200)
  let expected : Array[Double] = [
    0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0,
  ]
  for i in 0..<expected.length() {
    assert_true((probabilities[i][1] - expected[i]).abs() < 0.000000000001)
  }
  // Every leaf of the tree of scikit-learn is pure, so the probability of a
  // row is zero or one, and eighty six rows are of the class "true".
  let mut true_rows = 0
  for row in probabilities {
    assert_true(row[1] == 0.0 || row[1] == 1.0)
    if row[1] > row[0] {
      true_rows = true_rows + 1
    }
  }
  assert_eq(true_rows, 86)
}
