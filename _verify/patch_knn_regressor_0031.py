"""Add the nearest neighbour regressor to the models of the `gcm` package.

The multiply-robust causal change attribution of the upstream fits its
regressions with a regressor the caller chooses, and the test file of the
upstream uses the nearest neighbour regression.
"""

p = r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\src\gcm\ml.mbt"
s = open(p, encoding="utf-8", newline="").read()

addition = '''
///|
/// A prediction model that predicts with the average of the targets of the
/// nearest neighbours of a row.
///
/// This is the port of `dowhy.gcm.ml.regression.create_knn_regressor`, which
/// wraps `sklearn.neighbors.KNeighborsRegressor` with its default parameters:
/// five neighbours and the uniform weights.  The neighbours of a row are the
/// rows of the training data with the smallest euclidean distance to it, and
/// a tie is broken with the order of the rows, which is the rule of a scan
/// over the rows.
pub struct KnnModel {
  /// The number of the neighbours.
  k : Int32
  /// The rows of the training data.
  rows : @utils.Matrix
  /// The targets of the training data.
  targets : Array[Double]
  /// The rows of the training data, sorted by their first column.
  order : Array[Int32]
  /// Whether the model has been fitted.
  fitted : Bool
}

///|
/// An unfitted nearest neighbour prediction model.
pub fn KnnModel::new(k : Int32) -> KnnModel {
  {
    k,
    rows: @utils.Matrix::zeros(0, 0),
    targets: [],
    order: [],
    fitted: false,
  }
}

///|
/// Fit the model on the given data.
///
/// The result is a new model; the model the fit is called on stays as it is.
/// The fit of `sklearn.neighbors.KNeighborsRegressor` keeps the training data
/// and computes nothing else.
pub fn KnnModel::fit(
  self : KnnModel,
  x : @utils.Matrix,
  y : Array[Double],
) -> KnnModel {
  let order : Array[Int32] = []
  for i in 0..<x.nrows() {
    order.push(i)
  }
  // The rows are sorted by their first column, so that the neighbours of a row
  // are found with a walk over the sorted rows instead of a scan over all of
  // them.  The walk finds the same neighbours as the scan.
  if x.ncols() > 0 {
    order.sort_by(fn(a, b) {
      let c = @utils.compare_double(x.get(a, 0), x.get(b, 0))
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
  }
  {
    k: self.k,
    rows: x.copy(),
    targets: y.copy(),
    order,
    fitted: true,
  }
}

///|
/// Predict the target of every row of the design matrix.
pub fn KnnModel::predict(
  self : KnnModel,
  x : @utils.Matrix,
) -> Array[Double] {
  if !self.fitted {
    abort("the prediction model has not been fitted")
  }
  let out : Array[Double] = []
  if self.rows.ncols() == 0 {
    // Without a feature every row has the same distance to every row of the
    // training data, so the prediction is the mean of the targets.
    let mean = @utils.mean(self.targets)
    for _ in 0..<x.nrows() {
      out.push(mean)
    }
    return out
  }
  for i in 0..<x.nrows() {
    out.push(self.predict_row(x.row(i)))
  }
  out
}

///|
/// The prediction of one row: the average of the targets of its neighbours.
///
/// The neighbours are the rows with the smallest euclidean distance to the
/// row.  The rows are sorted by their first column, so the walk over the
/// sorted rows stops as soon as the rows that are left are further away than
/// the neighbours that were found already.
fn KnnModel::predict_row(self : KnnModel, query : Array[Double]) -> Double {
  let n = self.order.length()
  let k = if self.k < n { self.k } else { n }
  // The distances of the neighbours that were found and the rows they belong
  // to, in the order of their distance.
  let best_distances : Array[Double] = []
  let best_rows : Array[Int32] = []
  // The position of the row in the sorted rows.
  let mut lo = 0
  let mut hi = n
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    if self.rows.get(self.order[mid], 0) < query[0] {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  let mut left = lo - 1
  let mut right = lo
  let mut done = false
  while !done {
    if left < 0 && right >= n {
      // Every row was visited already.
      done = true
      break
    }
    // The smallest squared distance a row that was not visited can have.
    let mut bound = 1.0e300
    if left >= 0 {
      let difference = query[0] - self.rows.get(self.order[left], 0)
      bound = difference * difference
    }
    if right < n {
      let difference = self.rows.get(self.order[right], 0) - query[0]
      let squared = difference * difference
      if squared < bound {
        bound = squared
      }
    }
    if best_distances.length() == k && bound > best_distances[k - 1] {
      // Every row that is left is further away than the neighbours that were
      // found already.
      done = true
      break
    }
    // The nearer of the two sides is visited first.
    let take_left = if right >= n {
      true
    } else if left < 0 {
      false
    } else {
      let difference = query[0] - self.rows.get(self.order[left], 0)
      let right_difference = self.rows.get(self.order[right], 0) - query[0]
      difference <= right_difference
    }
    let row = if take_left {
      let visited = self.order[left]
      left = left - 1
      visited
    } else {
      let visited = self.order[right]
      right = right + 1
      visited
    }
    let distance = squared_distance(query, self.rows, row)
    // The neighbours are kept in the order of their distance.
    let mut position = best_distances.length()
    for i in 0..<best_distances.length() {
      if distance < best_distances[i] {
        position = i
        break
      }
    }
    if position < k {
      best_distances.insert(position, distance)
      best_rows.insert(position, row)
      if best_distances.length() > k {
        best_distances.pop()
        best_rows.pop()
      }
    }
  }
  let mut sum = 0.0
  for row in best_rows {
    sum = sum + self.targets[row]
  }
  if best_rows.length() == 0 {
    return 0.0
  }
  sum / best_rows.length().to_double()
}

///|
/// The squared euclidean distance of a row and a row of a matrix.
fn squared_distance(
  query : Array[Double],
  rows : @utils.Matrix,
  row : Int32,
) -> Double {
  let mut total = 0.0
  for j in 0..<query.length() {
    if j >= rows.ncols() {
      break
    }
    let difference = query[j] - rows.get(row, j)
    total = total + difference * difference
  }
  total
}

///|
/// A regressor of the `gcm` package.
///
/// The upstream wraps a whole zoo of scikit-learn regressors in
/// `SklearnRegressionModel`; the port has the linear regression and the
/// nearest neighbour regression, which are the two the upstream test of the
/// change attribution uses.
pub enum Regressor {
  /// The ordinary least squares regression.
  Linear(PredictionModel)
  /// The nearest neighbour regression.
  NearestNeighbour(KnnModel)
}

///|
/// The ordinary least squares regressor.
pub fn Regressor::linear() -> Regressor {
  Linear(PredictionModel::linear())
}

///|
/// The nearest neighbour regressor with the given number of neighbours.
pub fn Regressor::nearest_neighbour(k : Int32) -> Regressor {
  NearestNeighbour(KnnModel::new(k))
}

///|
/// Fit the regressor on the given data.
///
/// The result is a new regressor; the regressor the fit is called on stays as
/// it is.
pub fn Regressor::fit(
  self : Regressor,
  x : @utils.Matrix,
  y : Array[Double],
) -> Regressor {
  match self {
    Linear(model) => Linear(model.fit(x, y))
    NearestNeighbour(model) => NearestNeighbour(model.fit(x, y))
  }
}

///|
/// Predict the target of every row of the design matrix.
pub fn Regressor::predict(
  self : Regressor,
  x : @utils.Matrix,
) -> Array[Double] {
  match self {
    Linear(model) => model.predict(x)
    NearestNeighbour(model) => model.predict(x)
  }
}
'''

s = s.rstrip("\n") + "\n" + addition
open(p, "w", encoding="utf-8", newline="").write(s)
print("patched")
