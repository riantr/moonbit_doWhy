///|
/// The general helpers of the `gcm` package.
///
/// This is the port of `dowhy.gcm.util.general`. The helpers that work on
/// numpy arrays of strings have no counterpart here: MoonBit keeps the string
/// columns and the numeric columns apart in the type system, so a categorical
/// column is encoded with `@api.OneHotEncoder` before it reaches these
/// functions.

///|
/// A vector as a matrix with one column.
///
/// The upstream code shapes its numpy inputs into two dimensional matrices
/// with `shape_into_2d`; a MoonBit array is already a vector, so the shaping
/// is done by the callers that build the matrix.
pub fn column_vector(values : Array[Double]) -> @utils.Matrix {
  @utils.Matrix::from_columns([values])
}

///|
/// The values of a matrix with one column.
pub fn matrix_to_vector(m : @utils.Matrix) -> Array[Double] {
  if m.ncols() != 1 {
    abort("the matrix has " + m.ncols().to_string() + " columns, not one")
  }
  m.col(0)
}

///|
/// The rows of `a` that are not in `b`, sorted and without duplicates.
///
/// This is the port of `dowhy.gcm.util.general.setdiff2d`, which generalises
/// `numpy.setdiff1d` to the rows of a matrix. Like numpy, the result is
/// sorted and holds every row only once.
pub fn setdiff2d(a : @utils.Matrix, b : @utils.Matrix) -> @utils.Matrix {
  let keys_of_b : Map[String, Bool] = Map([])
  for i = 0; i < b.nrows(); i = i + 1 {
    keys_of_b.set(row_key(b.row(i)), true)
  }
  let seen : Map[String, Bool] = Map([])
  let rows : Array[Array[Double]] = []
  for i = 0; i < a.nrows(); i = i + 1 {
    let key = row_key(a.row(i))
    if !keys_of_b.contains(key) && !seen.contains(key) {
      seen.set(key, true)
      rows.push(a.row(i))
    }
  }
  rows.sort_by(fn(x, y) { compare_rows(x, y) })
  @utils.Matrix::from_rows(rows)
}

///|
/// The key that identifies a row.
///
/// Two rows have the same key when they hold the same numbers, which is what
/// `numpy.setdiff1d` compares. The key of a row of a single column is the
/// number itself.
fn row_key(row : Array[Double]) -> String {
  let mut key = ""
  for i = 0; i < row.length(); i = i + 1 {
    if i > 0 {
      key = key + "|"
    }
    key = key + row[i].to_string()
  }
  key
}

///|
/// The lexicographic comparison of two rows.
fn compare_rows(x : Array[Double], y : Array[Double]) -> Int32 {
  let n = if x.length() < y.length() { x.length() } else { y.length() }
  for i = 0; i < n; i = i + 1 {
    if x[i] < y[i] {
      return -1
    }
    if x[i] > y[i] {
      return 1
    }
  }
  if x.length() < y.length() {
    -1
  } else if x.length() > y.length() {
    1
  } else {
    0
  }
}

///|
/// The difference of the means of the two samples.
///
/// This is the port of `dowhy.gcm.util.general.means_difference`.
pub fn means_difference(
  randomized : Array[Double],
  baseline : Array[Double],
) -> Double {
  @utils.mean(randomized) - @utils.mean(baseline)
}

///|
/// The negative variance of the differences of the two samples.
///
/// The sign is negative because the Shapley estimation evaluates
/// `v(S + i) - v(S)` for a subset `S`, and the variance of the differences is
/// then the contribution of a player to the target quantity.
pub fn variance_of_deviations(
  randomized : Array[Double],
  baseline : Array[Double],
) -> Double {
  -@utils.var_pop(deviations_of(randomized, baseline))
}

///|
/// The negative variance of the matches of the two samples.
///
/// A match is a pair of values that are equal, and the variance of the
/// indicator of a match is what the upstream code computes.
pub fn variance_of_matching_values(
  randomized : Array[Double],
  baseline : Array[Double],
) -> Double {
  let matches : Array[Double] = []
  let n = if randomized.length() < baseline.length() {
    randomized.length()
  } else {
    baseline.length()
  }
  for i = 0; i < n; i = i + 1 {
    matches.push(if randomized[i] == baseline[i] { 1.0 } else { 0.0 })
  }
  -@utils.var_pop(matches)
}

///|
/// The differences of the two samples, up to the length of the shorter one.
fn deviations_of(
  randomized : Array[Double],
  baseline : Array[Double],
) -> Array[Double] {
  let deviations : Array[Double] = []
  let n = if randomized.length() < baseline.length() {
    randomized.length()
  } else {
    baseline.length()
  }
  for i = 0; i < n; i = i + 1 {
    deviations.push(randomized[i] - baseline[i])
  }
  deviations
}

///|
/// The geometric median of the rows of the matrix.
///
/// This is the port of `dowhy.gcm.util.general.geometric_median`, which
/// minimises the sum of the euclidean distances to the rows with
/// `scipy.optimize.minimize`. The Weiszfeld iteration reaches the same
/// optimum without a general purpose optimiser, so it is what the port uses.
pub fn geometric_median(points : @utils.Matrix) -> Array[Double] {
  let n = points.nrows()
  let d = points.ncols()
  if n == 0 || d == 0 {
    return []
  }
  // The mean of the rows is the starting point of the iteration.
  let centre : Array[Double] = []
  for j = 0; j < d; j = j + 1 {
    centre.push(@utils.mean(points.col(j)))
  }
  for _ in 0..<1000 {
    let weighted : Array[Double] = []
    for j = 0; j < d; j = j + 1 {
      weighted.push(0.0)
    }
    let mut total = 0.0
    for i = 0; i < n; i = i + 1 {
      let mut squared = 0.0
      for j = 0; j < d; j = j + 1 {
        let difference = points.get(i, j) - centre[j]
        squared = squared + difference * difference
      }
      let distance = squared.sqrt()
      if distance < 1.0e-12 {
        // A point that sits on the current centre carries no direction, so it
        // is left out of the update instead of dividing by zero.
        continue
      }
      let weight = 1.0 / distance
      total = total + weight
      for j = 0; j < d; j = j + 1 {
        weighted[j] = weighted[j] + weight * points.get(i, j)
      }
    }
    if total <= 0.0 {
      break
    }
    let mut moved = 0.0
    for j = 0; j < d; j = j + 1 {
      let next = weighted[j] / total
      let difference = (next - centre[j]).abs()
      if difference > moved {
        moved = difference
      }
      centre[j] = next
    }
    if moved < 1.0e-12 {
      break
    }
  }
  centre
}

///|
/// Whether all the values of the array are whole numbers.
///
/// This is the port of `dowhy.gcm.util.general.is_discrete`.
pub fn is_discrete(values : Array[Double]) -> Bool {
  for value in values {
    if value != value.floor() {
      return false
    }
  }
  true
}

///|
/// The matrix with its columns scaled to zero mean and unit variance.
///
/// This is the port of `sklearn.preprocessing.scale`, which the regression
/// based independence test applies to its inputs. A column without any spread
/// is left as it is, like the sklearn helper does.
pub fn scale_columns(m : @utils.Matrix) -> @utils.Matrix {
  let out = m.copy()
  for j = 0; j < out.ncols(); j = j + 1 {
    let column = out.col(j)
    let centre = @utils.mean(column)
    let spread = @utils.std(column)
    if spread <= 0.0 {
      continue
    }
    for i = 0; i < out.nrows(); i = i + 1 {
      out.set(i, j, (out.get(i, j) - centre) / spread)
    }
  }
  out
}

///|
/// A random permutation of the numbers `0` to `n - 1`.
///
/// The upstream code draws it with `numpy.random.choice(n, n, replace=False)`.
pub fn random_permutation(rng : @utils.Random, n : Int32) -> Array[Int32] {
  let values : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    values.push(i.to_double())
  }
  let shuffled = rng.shuffle(values)
  let order : Array[Int32] = []
  for value in shuffled {
    order.push(value.to_int())
  }
  order
}
