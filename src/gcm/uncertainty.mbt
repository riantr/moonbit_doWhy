///|
/// The uncertainty estimates of the `gcm` package.
///
/// This is the port of `dowhy.gcm.uncertainty`. The layer estimates the entropy
/// of a sample in three ways and the variance of a sample, which the
/// distribution change tests of the upstream use.
///
/// The upstream shapes its numpy inputs into two dimensional matrices with
/// `shape_into_2d`; the port takes a matrix, so a vector is a matrix with one
/// column.

///|
/// The base of the natural logarithm, like `math.e`.
const EULER : Double = 2.718281828459045

///|
/// The entropy of the given probabilities, in nats.
///
/// This is the port of `scipy.stats.entropy`, which normalises the
/// probabilities by their sum before it computes the entropy. A probability of
/// zero contributes nothing, and a distribution of zeros has the entropy zero.
fn entropy_of_probabilities(probabilities : Array[Double]) -> Double {
  let mut total = 0.0
  for probability in probabilities {
    if probability < 0.0 {
      abort("a probability cannot be negative")
    }
    total = total + probability
  }
  if total == 0.0 {
    return 0.0
  }
  let mut entropy = 0.0
  for probability in probabilities {
    if probability > 0.0 {
      let normalised = probability / total
      entropy = entropy - normalised * @math.ln(normalised)
    }
  }
  entropy
}

///|
/// The variance of the given sample.
///
/// This is the port of `dowhy.gcm.uncertainty.estimate_variance`. A sample with
/// one column has the population variance, like `numpy.var`, and a sample with
/// more columns has the determinant of its sample covariance matrix, like
/// `numpy.linalg.det(numpy.cov(x, rowvar=False))`. The covariance of numpy
/// divides by `n - 1`.
pub fn estimate_variance(x : @utils.Matrix) -> Double {
  if x.ncols() == 0 {
    return 0.0
  }
  let result = if x.ncols() > 1 {
    @utils.mat_determinant(sample_covariance(x))
  } else {
    @utils.var_pop(x.col(0))
  }
  // Extremely small values can somehow result in negative values.
  if result < 0.0 {
    return 0.0
  }
  result
}

///|
/// The entropy of the given sample, when it is a sample of a Gaussian.
///
/// This is the port of `dowhy.gcm.uncertainty.estimate_gaussian_entropy`. The
/// entropy is taken with respect to the standardised variables, so it is the
/// differential entropy of the fitted Gaussian.
pub fn estimate_gaussian_entropy(x : @utils.Matrix) -> Double {
  let d = x.ncols()
  let variance = estimate_variance(x)
  if d > 1 {
    let scale = @math.pow(2.0 * @math.PI * EULER, d.to_double())
    return 0.5 * @math.ln(scale * variance)
  }
  0.5 * @math.ln(2.0 * @math.PI * EULER * variance)
}

///|
/// The entropy of the given sample, estimated with a discretisation.
///
/// This is the port of
/// `dowhy.gcm.uncertainty.estimate_entropy_using_discretization`. The sample is
/// put into bins of the given width, and the entropy of the bin counts is the
/// entropy of the sample. The bins reach from the smallest value of the sample
/// to the largest one, and the number of them is the width of the range of the
/// sample divided by the width of a bin.
pub fn estimate_entropy_using_discretization(
  x : @utils.Matrix,
  bin_width : Double,
) -> Double {
  if x.ncols() != 1 {
    abort(
      "the discrete entropy estimator can only handle one dimensional data, but the input data is " +
      x.ncols().to_string() +
      " dimensional",
    )
  }
  if bin_width <= 0.0 {
    abort("the width of a bin has to be positive")
  }
  let values = x.col(0)
  if values.length() == 0 {
    return 0.0
  }
  let mut max_value = values[0]
  let mut min_value = values[0]
  for value in values {
    if value > max_value {
      max_value = value
    }
    if value < min_value {
      min_value = value
    }
  }
  let mut number_of_bins = ((max_value - min_value) / bin_width)
    .floor()
    .to_int()
  if number_of_bins < 1 {
    number_of_bins = 1
  }
  // The upstream builds the edges of the bins with
  // `numpy.linspace(min_value, max_value, number_of_bins)`, which gives
  // `number_of_bins` edges, and `numpy.histogram` makes `number_of_bins - 1`
  // bins out of them. With a single edge there is no bin at all, and every
  // count is zero.
  if number_of_bins < 2 {
    return 0.0
  }
  let edges = linspace(min_value, max_value, number_of_bins)
  let number_of_bins = number_of_bins - 1
  let counts : Array[Double] = []
  for _ in 0..<number_of_bins {
    counts.push(0.0)
  }
  for value in values {
    let mut index = upper_bound(edges, value) - 1
    if index < 0 {
      index = 0
    }
    if index > number_of_bins - 1 {
      index = number_of_bins - 1
    }
    counts[index] = counts[index] + 1.0
  }
  let n = values.length().to_double()
  let mut entropy = 0.0
  for count in counts {
    if count > 0.0 {
      let probability = count / n
      entropy = entropy - probability * @math.ln(probability)
    }
  }
  entropy
}

///|
/// The entropy of the given sample, estimated with the Kozachenko-Leonenko
/// estimator.
///
/// This is the port of `dowhy.gcm.uncertainty.estimate_entropy_kmeans`. The
/// estimator is the one of the paper *Sample estimate of the entropy of a random
/// vector* of Kozachenko and Leonenko: it uses the distances to the `k` nearest
/// neighbours of every point, where `k` is the square root of the number of the
/// points.
pub fn estimate_entropy_kmeans(x : @utils.Matrix) -> Double {
  let n = x.nrows()
  if n == 0 {
    return 0.0
  }
  let d = x.ncols()
  let mut k = n.to_double().sqrt().to_int()
  if k < 1 {
    k = 1
  }
  let distances = knn_distances(x, k)
  let mut sum_log_dist = 0.0
  for distance in distances {
    sum_log_dist = sum_log_dist + @math.ln(2.0 * distance + EPS)
  }
  -@utils.digamma(k.to_double()) +
  @utils.digamma(n.to_double()) +
  d.to_double() / n.to_double() * sum_log_dist
}

///|
/// The entropy of every row of the given matrix of probabilities, averaged over
/// the rows.
///
/// This is the port of
/// `dowhy.gcm.uncertainty.estimate_entropy_of_probabilities`, which is the mean
/// of `scipy.stats.entropy(x, axis=1)`.
pub fn estimate_entropy_of_probabilities(x : @utils.Matrix) -> Double {
  let n = x.nrows()
  if n == 0 {
    return 0.0
  }
  let mut total = 0.0
  for i in 0..<n {
    total = total + entropy_of_probabilities(x.row(i))
  }
  total / n.to_double()
}

///|
/// The entropy of the given sample of discrete values.
///
/// This is the port of `dowhy.gcm.uncertainty.estimate_entropy_discrete`. The
/// rows of the sample are the outcomes of a discrete variable, and the entropy
/// is the entropy of their frequencies.
pub fn estimate_entropy_discrete(x : @utils.Matrix) -> Double {
  let counts : Map[String, Double] = Map([])
  let keys : Array[String] = []
  for i in 0..<x.nrows() {
    let key = row_key(x.row(i))
    match counts.get(key) {
      Some(count) => counts.set(key, count + 1.0)
      None => {
        counts.set(key, 1.0)
        keys.push(key)
      }
    }
  }
  let frequencies : Array[Double] = []
  for key in keys {
    frequencies.push(counts.get(key).unwrap())
  }
  entropy_of_probabilities(frequencies)
}

///|
/// The sample covariance matrix of the rows of the given matrix.
///
/// This is the port of `numpy.cov(x, rowvar=False)`, which divides the sums of
/// the products of the deviations by `n - 1`.
fn sample_covariance(x : @utils.Matrix) -> @utils.Matrix {
  let n = x.nrows()
  let d = x.ncols()
  let out = @utils.Matrix::zeros(d, d)
  if n < 2 {
    return out
  }
  let means : Array[Double] = []
  for j in 0..<d {
    means.push(@utils.mean(x.col(j)))
  }
  for i in 0..<d {
    for j in 0..<d {
      let mut total = 0.0
      for k in 0..<n {
        total = total + (x.get(k, i) - means[i]) * (x.get(k, j) - means[j])
      }
      out.set(i, j, total / (n - 1).to_double())
    }
  }
  out
}

///|
/// The given number of points between the smallest and the largest value.
///
/// This is the port of `numpy.linspace(min_value, max_value, count)`.
fn linspace(
  min_value : Double,
  max_value : Double,
  count : Int32,
) -> Array[Double] {
  let out : Array[Double] = []
  if count <= 0 {
    return out
  }
  if count == 1 {
    out.push(min_value)
    return out
  }
  let step = (max_value - min_value) / (count - 1).to_double()
  for i in 0..<count {
    out.push(min_value + step * i.to_double())
  }
  out
}

///|
/// The number of the edges that are not greater than the given value.
///
/// This is the port of `numpy.searchsorted(edges, value, side="right")`.
fn upper_bound(edges : Array[Double], value : Double) -> Int32 {
  let mut low = 0
  let mut high = edges.length()
  while low < high {
    let middle = (low + high) / 2
    if edges[middle] <= value {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low
}

///|
/// The distance from every row of the given data to its k-th nearest neighbour.
///
/// This is the port of the `NearestNeighbors` of the upstream, which returns the
/// distances to the `k` nearest neighbours of every row and keeps the largest
/// of them. The row itself is one of the candidates, so the distance the
/// upstream keeps is the distance to the k-th nearest row that is not the row
/// itself.
///
/// For one column the port sorts the values and walks the two sides of every
/// value, which costs `O(n k)`. For more columns the port compares every pair
/// of rows, which costs `O(n^2 d)` and the sort of the distances of every row.
fn knn_distances(x : @utils.Matrix, k : Int32) -> Array[Double] {
  if x.ncols() == 1 {
    return knn_distances_of_a_column(x.col(0), k)
  }
  let n = x.nrows()
  let d = x.ncols()
  let distances : Array[Double] = []
  for i in 0..<n {
    let candidates : Array[Double] = []
    for j in 0..<n {
      if j == i {
        continue
      }
      let mut squared = 0.0
      for c in 0..<d {
        let difference = x.get(i, c) - x.get(j, c)
        squared = squared + difference * difference
      }
      candidates.push(squared.sqrt())
    }
    if candidates.length() == 0 {
      distances.push(0.0)
      continue
    }
    candidates.sort_by(fn(a, b) { @utils.compare_double(a, b) })
    let mut index = k - 1
    if index > candidates.length() - 1 {
      index = candidates.length() - 1
    }
    distances.push(candidates[index])
  }
  distances
}

///|
/// The distance from every value of the given column to its k-th nearest
/// neighbour.
///
/// The values are sorted first, so that the neighbours of a value are the ones
/// on its two sides, and the k-th of them is found by walking the two sides in
/// the order of their distance. The distances are put back into the order of
/// the rows of the data.
fn knn_distances_of_a_column(
  values : Array[Double],
  k : Int32,
) -> Array[Double] {
  let n = values.length()
  let order : Array[Int32] = []
  for i in 0..<n {
    order.push(i)
  }
  order.sort_by(fn(a, b) {
    let left = values[a]
    let right = values[b]
    if left < right {
      -1
    } else if left > right {
      1
    } else if a < b {
      -1
    } else if a > b {
      1
    } else {
      0
    }
  })
  let distances : Array[Double] = []
  for _ in 0..<n {
    distances.push(0.0)
  }
  for position in 0..<n {
    let value = values[order[position]]
    let mut left = position - 1
    let mut right = position + 1
    let mut taken = 0
    let mut distance = 0.0
    while taken < k {
      let has_left = left >= 0
      let has_right = right < n
      if !has_left && !has_right {
        break
      }
      let left_distance = if has_left {
        value - values[order[left]]
      } else {
        1.0e308
      }
      let right_distance = if has_right {
        values[order[right]] - value
      } else {
        1.0e308
      }
      if left_distance <= right_distance {
        distance = left_distance
        left = left - 1
      } else {
        distance = right_distance
        right = right + 1
      }
      taken = taken + 1
    }
    distances[order[position]] = distance
  }
  distances
}
