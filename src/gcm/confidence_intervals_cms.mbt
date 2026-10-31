///|
/// The confidence intervals of the `gcm` package that refit the causal model.
///
/// This is the port of `dowhy.gcm.confidence_intervals_cms`. The upstream
/// module bootstraps the fitting of a causal model as well as the sampling of
/// it: every repetition of the bootstrap refits the model on a random subset
/// of the training data and evaluates the causal query on the refitted model,
/// so that the interval takes the uncertainty of the fit into account.

///|
/// A causal query on a causal model.
///
/// The query returns the attribution of the nodes, the way the upstream
/// returns a dictionary of attribution-like data.
///
/// This is the type of the argument `f` of
/// `dowhy.gcm.confidence_intervals_cms.fit_and_compute`. The upstream query
/// takes the causal model and any number of further arguments and returns a
/// dictionary; the port takes the causal model alone and returns the numbers
/// of the attribution, because the summary of the bootstrap of the package
/// works on matrices of numbers.
pub type CausalQuery = (ProbabilisticCausalModel) -> Array[Double]

///|
/// A function that fits a causal model on a subset of the data and then
/// evaluates a query on it.
///
/// The function takes the seed of the resample and returns the result of the
/// query, which is the shape the `confidence_intervals` of the package
/// expects.
///
/// This is the port of `dowhy.gcm.confidence_intervals_cms.fit_and_compute`.
/// The upstream returns a callable that the `confidence_intervals` of the
/// package calls once per bootstrap iteration. Every call clones the causal
/// model, draws a random subset of the training data without replacement,
/// assigns the causal mechanisms again when a quality is given, fits the copy
/// on the subset and evaluates the query on the fitted copy.
///
/// The deviations from the upstream are the following ones. The upstream draws
/// the subset from the global generator of numpy and passes the further
/// arguments of the query through; the port draws the subset from the seed of
/// the call, so that the same seed always gives the same subset and the whole
/// interval is reproducible, and the query takes the causal model alone. The
/// clone of the causal model keeps the causal mechanisms untrained, like the
/// clone of the upstream does.
pub fn fit_and_compute(
  query : CausalQuery,
  causal_model : ProbabilisticCausalModel,
  bootstrap_training_data : @api.DataFrame,
  bootstrap_data_subset_size_fraction : Double,
  quality : AssignmentQuality?,
) -> (UInt64) -> Array[Double] {
  fn(seed : UInt64) -> Array[Double] {
    // The copy of the model is fitted, so the model of the caller stays as it
    // is.
    let model_copy = causal_model.clone()
    let sampled_data = cms_bootstrap_subset(
      bootstrap_training_data, bootstrap_data_subset_size_fraction, seed,
    )
    match quality {
      Some(assignment_quality) => {
        // The upstream overrides the mechanisms of the copy when a quality is
        // given.
        let _ = assign_causal_mechanisms(
          model_copy, sampled_data, assignment_quality, true,
        )
      }
      None => ()
    }
    fit(model_copy, sampled_data)
    query(model_copy)
  }
}

///|
/// A random subset of the training data, drawn without replacement.
///
/// This is the port of the `numpy.random.choice` of the upstream, which draws
/// the rows of the subset without replacement. The size of the subset is
/// `int(n * fraction)`, like the size of the upstream, and the rows of the
/// subset are the first rows of a random permutation of the rows of the
/// training data.
fn cms_bootstrap_subset(
  training_data : @api.DataFrame,
  fraction : Double,
  seed : UInt64,
) -> @api.DataFrame {
  let rng = @utils.Random::new(seed)
  let n = training_data.nrows()
  let mut size = (n.to_double() * fraction).to_int()
  if size > n {
    size = n
  }
  if size < 0 {
    size = 0
  }
  let permutation = random_permutation(rng, n)
  let rows : Array[Int32] = []
  for i in 0..<size {
    rows.push(permutation[i])
  }
  training_data.take_rows(rows)
}
