///|
/// The confidence intervals of the `gcm` package, estimated by bootstrapping.
///
/// This is the port of `dowhy.gcm.confidence_intervals`.

///|
/// Estimates the confidence intervals of the results of the given estimation
/// function.
///
/// This is the port of `dowhy.gcm.confidence_intervals.confidence_intervals`.
/// The estimation function is called `num_bootstrap_resamples` times and the
/// results of the calls are summarized by `bootstrap_results_summary_func`,
/// which gets the matrix of all the results and returns one value per
/// dimension. The interval of a dimension is the `(1 - confidence_level)` and
/// the `confidence_level` percentile of the values of that dimension.
///
/// The upstream code seeds the global generator of numpy before every call of
/// the estimation function. MoonBit has no global generator, so the port draws
/// a seed for every call and hands it to the estimation function, which seeds
/// its own generator with it.
///
/// The upstream code can also summarize results that are dictionaries. The
/// port has no counterpart of that, because the results are arrays of numbers.
///
/// The upstream code runs the repetitions in parallel with the number of jobs
/// of its `n_jobs` argument. The port runs them one after the other, which
/// changes no result.
pub fn confidence_intervals(
  estimation_func : (UInt64) -> Array[Double],
  confidence_level : Double,
  num_bootstrap_resamples : Int32,
  bootstrap_results_summary_func : (@utils.Matrix) -> Array[Double],
  rng : @utils.Random,
) -> (Array[Double], Array[Array[Double]]) {
  if num_bootstrap_resamples < 1 {
    abort(
      "the number of repetitions should be greater than 0, but got " +
      num_bootstrap_resamples.to_string(),
    )
  }
  let results : Array[Array[Double]] = []
  let mut dimensions = -1
  for _ in 0..<num_bootstrap_resamples {
    let seed = rng.next_u64()
    let result = estimation_func(seed)
    if dimensions < 0 {
      dimensions = result.length()
    } else if result.length() != dimensions {
      abort("the estimation function returned results of different lengths")
    }
    results.push(result)
  }
  let matrix = @utils.Matrix::from_rows(results)
  let summary = bootstrap_results_summary_func(matrix)
  let intervals : Array[Array[Double]] = []
  for dimension = 0; dimension < dimensions; dimension = dimension + 1 {
    let column = matrix.col(dimension)
    let lower = @utils.percentile(column, (1.0 - confidence_level) * 100.0)
    let upper = @utils.percentile(column, confidence_level * 100.0)
    intervals.push([lower, upper])
  }
  (summary, intervals)
}

///|
/// The geometric median of the rows of the matrix.
///
/// This is the port of `dowhy.gcm.confidence_intervals.estimate_geometric_median`,
/// which is the default summary of the bootstrap results. It is the same
/// geometric median as the one of `dowhy.gcm.util.general`, so the port calls
/// that helper.
pub fn estimate_geometric_median(x : @utils.Matrix) -> Array[Double] {
  geometric_median(x)
}
