/// The algorithms of the do samplers.
///
/// This is the port of the samplers in `dowhy.do_samplers`.

///|
/// The name of the column the propensity score is stored in.
///
/// The upstream weighting sampler calls it `propensity_score` and the
/// multivariate one `state_propensity`.
fn DoSampler::propensity_column(self : DoSampler) -> String {
  match self.kind {
    Weighting => "propensity_score"
    MultivariateWeighting => "state_propensity"
    KernelDensity => "propensity_score"
  }
}

///|
/// Compute the propensity score and the weight of every row.
///
/// The treatment assignment is rendered ignorable with the inverse of the
/// propensity score, like the upstream weighting sampler does it.
fn DoSampler::disrupt_causes_weighting(self : DoSampler) -> Unit {
  let scores = state_propensity_score(
    self.data,
    self.adjustment_names,
    self.treatment_names,
    self.variable_types,
  )
  let weights : Array[Double] = []
  for score in scores {
    weights.push(1.0 / score)
  }
  let column = self.propensity_column()
  self.frame = self.frame.with_numeric(column, scores)
  self.frame = self.frame.with_numeric("weight", weights)
}

///|
/// Keep the rows whose treatment already has the imposed value.
///
/// The weight of a row is the inverse of the propensity score of the
/// treatment state the row received, so a row whose treatment has a
/// different value cannot be weighted; the upstream sampler drops it.
fn DoSampler::make_treatment_effective_weighting(
  self : DoSampler,
  x : Map[String, Double],
) -> Unit {
  if self.keep_original_treatment {
    return
  }
  let mask : Array[Bool] = []
  for row = 0; row < self.frame.nrows(); row = row + 1 {
    mask.push(true)
  }
  for name in x.keys() {
    let value = x.get(name).unwrap_or(0.0)
    let values = self.frame.numeric(name)
    let mut row = 0
    while row < values.length() && row < mask.length() {
      if values[row] != value {
        mask[row] = false
      }
      row = row + 1
    }
  }
  self.frame = self.frame.filter(mask)
}

///|
/// Draw the weighted bootstrap sample.
///
/// The rows are drawn with replacement, with the probability of a row
/// proportional to its weight, exactly like `pandas.DataFrame.sample` does
/// it. The sample has the size of the original data.
fn DoSampler::sample_weighting(self : DoSampler) -> Unit {
  let weights = self.frame.numeric("weight")
  let rows = self.weighted_bootstrap(weights, self.data.nrows())
  self.frame = self.frame.take_rows(rows)
}

///|
/// The row indices of a weighted bootstrap sample.
fn DoSampler::weighted_bootstrap(
  self : DoSampler,
  weights : Array[Double],
  size : Int32,
) -> Array[Int32] {
  let n = weights.length()
  if n == 0 {
    return []
  }
  let cumulative : Array[Double] = []
  let mut total = 0.0
  for i = 0; i < n; i = i + 1 {
    total = total + weights[i]
    cumulative.push(total)
  }
  let rows : Array[Int32] = []
  for i = 0; i < size; i = i + 1 {
    let target = self.random.next_double() * total
    rows.push(search_cumulative(cumulative, target))
  }
  rows
}

///|
/// The index of the first entry of the cumulative distribution that is
/// larger than the target.
fn search_cumulative(cumulative : Array[Double], target : Double) -> Int32 {
  let mut low = 0
  let mut high = cumulative.length() - 1
  while low < high {
    let middle = (low + high) / 2
    if cumulative[middle] <= target {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low
}

///|
/// Fit the conditional distribution of the outcome.
///
/// The upstream kernel density sampler estimates the conditional density of
/// the outcome given the treatment and the adjustment variables with
/// `KDEMultivariateConditional`. The port has no conditional kernel density
/// estimator, so the conditional distribution is modelled as a Gaussian
/// around the least squares fit of the outcome on the treatment and the
/// adjustment variables, with the residual variance of the fit. That is the
/// family the kernel estimator approximates.
fn DoSampler::disrupt_causes_kernel(self : DoSampler) -> Unit {
  let names = self.treatment_names + self.adjustment_names
  let design = build_design(self.data, names, self.variable_types)
  let matrix = design_matrix(design)
  let outcome = self.data.numeric(self.outcome_names[0])
  let fit = @utils.ols_fit(matrix, outcome)
  self.kernel_names = names
  self.kernel_beta = fit.beta
  self.kernel_sigma = fit.sigma2.sqrt()
}

///|
/// Impose the value of the treatment on the frame.
fn DoSampler::make_treatment_effective_kernel(
  self : DoSampler,
  x : Map[String, Double],
) -> Unit {
  if self.keep_original_treatment {
    return
  }
  for name in x.keys() {
    let value = x.get(name).unwrap_or(0.0)
    let column : Array[Double] = []
    for row = 0; row < self.frame.nrows(); row = row + 1 {
      column.push(value)
    }
    self.frame = self.frame.with_numeric(name, column)
  }
}

///|
/// Draw the outcome from the conditional distribution.
///
/// The design of the conditional model is built again, so that the outcome
/// is drawn for the treatment the intervention imposed.
fn DoSampler::sample_kernel(self : DoSampler) -> Unit {
  let outcome_name = self.outcome_names[0]
  let design = build_design(self.frame, self.kernel_names, self.variable_types)
  let matrix = design_matrix(design)
  let n = self.frame.nrows()
  let values : Array[Double] = []
  for row = 0; row < n; row = row + 1 {
    let mut mean = 0.0
    for a = 0; a < matrix.ncols() && a < self.kernel_beta.length(); a = a + 1 {
      mean = mean + self.kernel_beta[a] * matrix.get(row, a)
    }
    values.push(mean + self.kernel_sigma * self.random.next_normal())
  }
  self.frame = self.frame.with_numeric(outcome_name, values)
}
