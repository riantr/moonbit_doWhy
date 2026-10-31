///|
/// The divergence estimators of the `gcm` package.
///
/// This is the port of `dowhy.gcm.divergence`. The upstream code works on numpy
/// arrays that may hold strings, while a MoonBit matrix holds numbers only, so
/// a category is a distinct number: the categorical divergence treats the
/// distinct values of the samples as the categories.
///
/// The upstream code detects a categorical input from the dtype of its numpy
/// array, which a matrix of numbers cannot show. The port therefore dispatches
/// on the shape of the matrix alone, and the categorical estimator has to be
/// called explicitly.

///|
/// Whether the matrix holds probability vectors.
///
/// This is the port of `dowhy.gcm.divergence.is_probability_matrix`. A matrix
/// with more than one column is a probability matrix when every row sums to one,
/// and a matrix with one column never is. The upstream sums the absolute values
/// of a row and compares the sum with one the way `numpy.isclose` does.
pub fn is_probability_matrix(x : @utils.Matrix) -> Bool {
  if x.ncols() == 1 {
    return false
  }
  for i = 0; i < x.nrows(); i = i + 1 {
    let mut total = 0.0
    for j = 0; j < x.ncols(); j = j + 1 {
      total = total + x.get(i, j).abs()
    }
    if !is_close(total, 1.0) {
      return false
    }
  }
  true
}

///|
/// The Kullback-Leibler divergence of two samples of categories.
///
/// This is the port of
/// `dowhy.gcm.divergence.estimate_kl_divergence_categorical`. Every probability
/// is smoothed with `EPS`, exactly like the upstream code does, and the
/// divergence is summed over the distinct values of both samples.
pub fn estimate_kl_divergence_categorical(
  x : @utils.Matrix,
  y : @utils.Matrix,
) -> Double {
  check_same_dimension(x, y)
  let mut total = 0.0
  for value in distinct_values(x, y) {
    let p = (count_value(x, value).to_double() + EPS) /
      (x.nrows().to_double() + EPS)
    let q = (count_value(y, value).to_double() + EPS) /
      (y.nrows().to_double() + EPS)
    total = total + p * @utils.ln(p / q)
  }
  total
}

///|
/// The mean Kullback-Leibler divergence of the rows of two probability matrices.
///
/// This is the port of
/// `dowhy.gcm.divergence.estimate_kl_divergence_of_probabilities`, which is the
/// mean of `scipy.stats.entropy(x + EPS, y + EPS, axis=1)` over the rows.
pub fn estimate_kl_divergence_of_probabilities(
  x : @utils.Matrix,
  y : @utils.Matrix,
) -> Double {
  check_same_dimension(x, y)
  if x.nrows() != y.nrows() {
    abort(
      "the two samples have " +
      x.nrows().to_string() +
      " and " +
      y.nrows().to_string() +
      " rows, but they need the same number of rows",
    )
  }
  if x.nrows() == 0 {
    return 0.0
  }
  let mut total = 0.0
  for i = 0; i < x.nrows(); i = i + 1 {
    let mut row = 0.0
    for j = 0; j < x.ncols(); j = j + 1 {
      let p = x.get(i, j) + EPS
      let q = y.get(i, j) + EPS
      row = row + p * @utils.ln(p / q)
    }
    total = total + row
  }
  total / x.nrows().to_double()
}

///|
/// The Kullback-Leibler divergence of two continuous samples, estimated with the
/// k nearest neighbours.
///
/// This is the port of
/// `dowhy.gcm.divergence.estimate_kl_divergence_continuous_knn`, the estimator
/// of Wang et al. (2009): with `n` samples in X and `m` samples in Y, `rho` is
/// the distance to the (k+1)-th neighbour inside X and `nu` the distance to the
/// k-th neighbour inside Y, and the estimate is
/// `sum_i (d / n) * ln(nu_i / rho_i) + ln(m / (n - 1))`, where `d` is the number
/// of the columns.
///
/// While the estimator handles multidimensional inputs in theory, the upstream
/// code suggests the classifier based estimator for data with more than one
/// dimension.
///
/// The rows of X that also occur in Y are removed first when
/// `remove_common_elements` is true, because a distance of zero would make the
/// estimate infinite.
pub fn estimate_kl_divergence_continuous_knn(
  x : @utils.Matrix,
  y : @utils.Matrix,
  k : Int32,
  remove_common_elements : Bool,
) -> Double {
  check_same_dimension(x, y)
  let samples = if remove_common_elements { setdiff2d(x, y) } else { x }
  if remove_common_elements && samples.nrows() < k + 1 {
    // All the elements are equal, or at least less than k samples are different.
    return 0.0
  }
  let n = samples.nrows()
  let m = y.nrows()
  if n == 0 {
    return 0.0
  }
  if n < k + 1 {
    abort(
      "the sample of X has " +
      n.to_string() +
      " rows, but the estimator needs " +
      (k + 1).to_string() +
      " of them",
    )
  }
  if m < k {
    abort(
      "the sample of Y has " +
      m.to_string() +
      " rows, but the estimator needs " +
      k.to_string() +
      " of them",
    )
  }
  let d = samples.ncols().to_double()
  let mut total = 0.0
  for i = 0; i < n; i = i + 1 {
    // The distance to the (k+1)-th neighbour inside X, the sample itself
    // included, and the distance to the k-th neighbour inside Y.
    let rho = kth_distance(samples, i, samples, k + 1)
    let nu = kth_distance(samples, i, y, k)
    total = total + d / n.to_double() * @utils.ln(nu / rho)
  }
  total = total + @utils.ln(m.to_double() / (n - 1).to_double())
  if !is_finite(total) {
    abort(
      "the KL divergence is not finite, which happens when the two samples share " +
      "elements; they are normally removed by this estimator",
    )
  }
  if total < 0.0 {
    return 0.0
  }
  total
}

///|
/// The Kullback-Leibler divergence of two continuous samples, estimated with a
/// classifier.
///
/// This is the port of
/// `dowhy.gcm.divergence.estimate_kl_divergence_continuous_clf`. A logistic
/// regression is fitted on the samples of P (the label zero) and the samples of
/// Q (the label one), and the divergence is the mean of
/// `-ln(p / (1 - p))` over the held out samples of P, where `p` is the
/// probability that a sample comes from Q.
///
/// The upstream code shuffles the folds of its cross validation with the global
/// numpy random state. The port draws them with the generator it is given, so
/// that the result is reproducible, and it fits the classifier without a
/// penalty, because the estimate of a divergence is the maximum likelihood one.
///
/// The probabilities are clipped at `epsilon` and `1 - epsilon`, like the
/// upstream code does.
pub fn estimate_kl_divergence_continuous_clf(
  samples_p : @utils.Matrix,
  samples_q : @utils.Matrix,
  n_splits : Int32,
  epsilon : Double,
  rng : @utils.Random,
) -> Double {
  check_same_dimension(samples_p, samples_q)
  let folds_p = kfold_splits(samples_p.nrows(), n_splits, rng)
  let folds_q = kfold_splits(samples_q.nrows(), n_splits, rng)
  let probs : Array[Double] = []
  for k = 0; k < n_splits; k = k + 1 {
    let train_p = folds_p[k].0
    let held_out_p = folds_p[k].1
    let train_q = folds_q[k].0
    // The classes are balanced, like the upstream code does.
    let num = if train_p.length() < train_q.length() {
      train_p.length()
    } else {
      train_q.length()
    }
    let design = @utils.Matrix::zeros(2 * num, samples_p.ncols() + 1)
    let labels : Array[Double] = []
    for i = 0; i < num; i = i + 1 {
      design.set(i, 0, 1.0)
      for j = 0; j < samples_p.ncols(); j = j + 1 {
        design.set(i, j + 1, samples_p.get(train_p[i], j))
      }
      labels.push(0.0)
    }
    for i = 0; i < num; i = i + 1 {
      design.set(num + i, 0, 1.0)
      for j = 0; j < samples_q.ncols(); j = j + 1 {
        design.set(num + i, j + 1, samples_q.get(train_q[i], j))
      }
      labels.push(1.0)
    }
    // The penalty of the fit is `1 / c`, so a large `c` is the unpenalised fit:
    // the term it adds to the Hessian is far below its precision.
    let fit = @utils.logistic_fit(design, labels, 1.0e300, 10000, 1.0e-10)
    let held_out = @utils.Matrix::zeros(
      held_out_p.length(),
      samples_p.ncols() + 1,
    )
    for i = 0; i < held_out_p.length(); i = i + 1 {
      held_out.set(i, 0, 1.0)
      for j = 0; j < samples_p.ncols(); j = j + 1 {
        held_out.set(i, j + 1, samples_p.get(held_out_p[i], j))
      }
    }
    for probability in @utils.logistic_predict(fit.beta, held_out) {
      let clipped = if probability == 0.0 {
        epsilon
      } else if probability == 1.0 {
        1.0 - epsilon
      } else {
        probability
      }
      probs.push(clipped)
    }
  }
  let mut total = 0.0
  for probability in probs {
    total = total + -@utils.ln(probability / (1.0 - probability))
  }
  let divergence = if probs.length() == 0 {
    0.0
  } else {
    total / probs.length().to_double()
  }
  if divergence < 0.0 {
    return 0.0
  }
  divergence
}

///|
/// The Kullback-Leibler divergence of two samples, with the estimator that fits
/// their shape.
///
/// This is the port of `dowhy.gcm.divergence.auto_estimate_kl_divergence`. The
/// upstream code detects a categorical input from the dtype of its numpy array,
/// which a matrix of numbers cannot show, so the port dispatches on the shape of
/// the matrix alone: a probability matrix goes to the probability estimator, a
/// matrix with one column goes to the nearest neighbour estimator and a matrix
/// with more than one column goes to the classifier estimator. The categorical
/// estimator has to be called explicitly.
pub fn auto_estimate_kl_divergence(
  x : @utils.Matrix,
  y : @utils.Matrix,
  rng : @utils.Random,
) -> Double {
  if is_probability_matrix(x) {
    return estimate_kl_divergence_of_probabilities(x, y)
  }
  if x.ncols() > 1 {
    return estimate_kl_divergence_continuous_clf(x, y, 5, EPS, rng)
  }
  estimate_kl_divergence_continuous_knn(x, y, 1, true)
}

///|
/// Abort when the two samples do not have the same number of columns.
fn check_same_dimension(x : @utils.Matrix, y : @utils.Matrix) -> Unit {
  if x.ncols() != y.ncols() {
    abort(
      "the samples of X and Y need to have the same dimension, but X has " +
      "dimension " +
      x.ncols().to_string() +
      " and Y has dimension " +
      y.ncols().to_string(),
    )
  }
}

///|
/// Whether two numbers are as close as `numpy.isclose` says.
fn is_close(a : Double, b : Double) -> Bool {
  (a - b).abs() <= 1.0e-8 + 1.0e-5 * b.abs()
}

///|
/// Whether the value is a finite number.
///
/// The check avoids the `double` package: a finite number is the only one whose
/// difference with itself is zero.
fn is_finite(value : Double) -> Bool {
  value - value == 0.0
}

///|
/// The distinct values of the two matrices, in ascending order.
///
/// This is the port of the `numpy.unique` of the concatenated samples.
fn distinct_values(x : @utils.Matrix, y : @utils.Matrix) -> Array[Double] {
  let values : Array[Double] = []
  for i = 0; i < x.nrows(); i = i + 1 {
    for j = 0; j < x.ncols(); j = j + 1 {
      values.push(x.get(i, j))
    }
  }
  for i = 0; i < y.nrows(); i = i + 1 {
    for j = 0; j < y.ncols(); j = j + 1 {
      values.push(y.get(i, j))
    }
  }
  values.sort_by(fn(a, b) { @utils.compare_double(a, b) })
  let distinct : Array[Double] = []
  for value in values {
    if distinct.length() == 0 || distinct[distinct.length() - 1] != value {
      distinct.push(value)
    }
  }
  distinct
}

///|
/// The number of the elements of the matrix that are equal to the value.
fn count_value(m : @utils.Matrix, value : Double) -> Int32 {
  let mut count = 0
  for i = 0; i < m.nrows(); i = i + 1 {
    for j = 0; j < m.ncols(); j = j + 1 {
      if m.get(i, j) == value {
        count = count + 1
      }
    }
  }
  count
}

///|
/// The distance to the `k`-th nearest row of `rows`, the smallest distance first.
///
/// The row of `from` the distance is measured from is one of the rows of
/// `rows` when both are the same matrix, and it is then counted as a
/// neighbour of itself, like the `NearestNeighbors` of sklearn does.
fn kth_distance(
  from : @utils.Matrix,
  i : Int32,
  rows : @utils.Matrix,
  k : Int32,
) -> Double {
  let nearest : Array[Double] = []
  for j = 0; j < rows.nrows(); j = j + 1 {
    let distance = distance_between(from, i, rows, j)
    if nearest.length() < k {
      insert_ordered(nearest, distance)
    } else if distance < nearest[k - 1] {
      let _ = nearest.pop()
      insert_ordered(nearest, distance)
    }
  }
  if nearest.length() < k {
    abort(
      "the sample has " +
      rows.nrows().to_string() +
      " rows, but " +
      k.to_string() +
      " neighbours are needed",
    )
  }
  nearest[k - 1]
}

///|
/// The euclidean distance of two rows of two matrices.
fn distance_between(
  a : @utils.Matrix,
  i : Int32,
  b : @utils.Matrix,
  j : Int32,
) -> Double {
  let mut squared = 0.0
  for c = 0; c < a.ncols(); c = c + 1 {
    let difference = a.get(i, c) - b.get(j, c)
    squared = squared + difference * difference
  }
  squared.sqrt()
}

///|
/// Insert a value into a sorted array, keeping the order.
fn insert_ordered(sorted : Array[Double], value : Double) -> Unit {
  let mut i = sorted.length()
  sorted.push(value)
  while i > 0 && sorted[i - 1] > value {
    sorted[i] = sorted[i - 1]
    i = i - 1
  }
  sorted[i] = value
}

///|
/// The folds of a cross validation, like `sklearn.model_selection.KFold` with
/// `shuffle = true`.
///
/// Every fold holds the training indices and the test indices of the rows. The
/// upstream code shuffles the rows with the global numpy random state; the port
/// shuffles them with the generator it is given, so that the result is
/// reproducible.
fn kfold_splits(
  n : Int32,
  n_splits : Int32,
  rng : @utils.Random,
) -> Array[(Array[Int32], Array[Int32])] {
  if n_splits <= 0 {
    abort("the number of the splits has to be positive")
  }
  let order = random_permutation(rng, n)
  let fold_size = n / n_splits
  let remainder = n % n_splits
  let folds : Array[(Array[Int32], Array[Int32])] = []
  let mut current = 0
  for k = 0; k < n_splits; k = k + 1 {
    let mut stop = current + fold_size
    if k < remainder {
      stop = stop + 1
    }
    let test_indices : Array[Int32] = []
    for i = current; i < stop; i = i + 1 {
      test_indices.push(order[i])
    }
    let train_indices : Array[Int32] = []
    for i = 0; i < current; i = i + 1 {
      train_indices.push(order[i])
    }
    for i = stop; i < n; i = i + 1 {
      train_indices.push(order[i])
    }
    folds.push((train_indices, test_indices))
    current = stop
  }
  folds
}
