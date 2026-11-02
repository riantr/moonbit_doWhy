/// The samplers from the interventional distribution.
///
/// This is the port of `dowhy.do_sampler.DoSampler`. MoonBit has no class
/// inheritance, so the sampler holds the algorithm in a `DoSamplerKind` and
/// dispatches on it, exactly like the estimators of the port do.
///
/// The `do` operation of Pearl (2000) is implemented in three steps: the
/// causes of the treatment are disrupted, the treatment is made effective
/// and the outcome is drawn from the resulting distribution.

///|
/// The do samplers the port offers.
pub enum DoSamplerKind {
  /// The weighting sampler of `dowhy.do_samplers.weighting_sampler`.
  Weighting
  /// The multivariate weighting sampler of
  /// `dowhy.do_samplers.multivariate_weighting_sampler`.
  MultivariateWeighting
  /// The kernel density sampler of
  /// `dowhy.do_samplers.kernel_density_sampler`.
  KernelDensity
}

///|
/// A sampler from the interventional distribution.
pub struct DoSampler {
  /// The algorithm of the sampler.
  kind : DoSamplerKind
  /// The data the sampler works on.
  data : @api.DataFrame
  /// The estimand the sampler was built for.
  estimand : @identifiers.IdentifiedEstimand
  /// The treatment variables.
  treatment_names : Array[String]
  /// The outcome variables.
  outcome_names : Array[String]
  /// The types of the variables.
  variable_types : Map[String, VariableType]
  /// The adjustment variables of the estimand.
  adjustment_names : Array[String]
  /// The frame the sampler works on.
  mut frame : @api.DataFrame
  /// The generator the sampler draws from.
  random : @utils.Random
  /// Whether the original treatment assignments are kept.
  keep_original_treatment : Bool
  /// The coefficients of the conditional model of the kernel density sampler.
  mut kernel_beta : Array[Double]
  /// The residual standard deviation of the conditional model.
  mut kernel_sigma : Double
  /// The columns of the conditional model of the kernel density sampler.
  mut kernel_names : Array[String]
}

///|
/// A weighting sampler.
///
/// The sampler weights every row with the inverse of its propensity score
/// and draws a weighted bootstrap sample of the size of the data.
pub fn DoSampler::weighting(
  graph : @graph.DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
  observed_nodes : Array[String],
  data : @api.DataFrame,
  variable_types : Map[String, VariableType],
  random : @utils.Random,
  keep_original_treatment~ : Bool = false,
) -> DoSampler {
  DoSampler::new(
    DoSamplerKind::Weighting,
    graph,
    action_nodes,
    outcome_nodes,
    observed_nodes,
    data,
    variable_types,
    random,
    keep_original_treatment,
  )
}

///|
/// A multivariate weighting sampler.
///
/// The upstream multivariate sampler is the weighting sampler with another
/// name for its propensity column; the port keeps that difference.
pub fn DoSampler::multivariate_weighting(
  graph : @graph.DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
  observed_nodes : Array[String],
  data : @api.DataFrame,
  variable_types : Map[String, VariableType],
  random : @utils.Random,
  keep_original_treatment~ : Bool = false,
) -> DoSampler {
  DoSampler::new(
    DoSamplerKind::MultivariateWeighting,
    graph,
    action_nodes,
    outcome_nodes,
    observed_nodes,
    data,
    variable_types,
    random,
    keep_original_treatment,
  )
}

///|
/// A kernel density sampler.
///
/// The sampler fits the conditional distribution of the outcome given the
/// treatment and the adjustment variables, and draws the outcome from it.
pub fn DoSampler::kernel_density(
  graph : @graph.DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
  observed_nodes : Array[String],
  data : @api.DataFrame,
  variable_types : Map[String, VariableType],
  random : @utils.Random,
  keep_original_treatment~ : Bool = false,
) -> DoSampler {
  DoSampler::new(
    DoSamplerKind::KernelDensity,
    graph,
    action_nodes,
    outcome_nodes,
    observed_nodes,
    data,
    variable_types,
    random,
    keep_original_treatment,
  )
}

///|
/// Build a sampler.
///
/// The sampler identifies the effect of the treatment on the outcome with the
/// backdoor criterion, like the upstream code does, and uses the adjustment
/// variables of that criterion as the covariates of the propensity model.
fn DoSampler::new(
  kind : DoSamplerKind,
  graph : @graph.DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
  observed_nodes : Array[String],
  data : @api.DataFrame,
  variable_types : Map[String, VariableType],
  random : @utils.Random,
  keep_original_treatment : Bool,
) -> DoSampler {
  let estimand = @identifiers.identify_effect_auto(
    graph,
    action_nodes,
    outcome_nodes,
    observed_nodes,
    "nonparametric-ate",
    @identifiers.BACKDOOR_DEFAULT,
  )
  estimand.set_identifier_method("backdoor")
  let adjustment = estimand.get_adjustment_set("backdoor")
  {
    kind,
    data: data.copy(),
    estimand,
    treatment_names: action_nodes.copy(),
    outcome_names: outcome_nodes.copy(),
    variable_types: variable_types.copy(),
    adjustment_names: adjustment.copy(),
    frame: data.copy(),
    random,
    keep_original_treatment,
    kernel_beta: [],
    kernel_sigma: 0.0,
    kernel_names: [],
  }
}

///|
/// The algorithm of the sampler.
pub fn DoSampler::sampler_kind(self : DoSampler) -> DoSamplerKind {
  self.kind
}

///|
/// The estimand the sampler was built for.
pub fn DoSampler::estimand(self : DoSampler) -> @identifiers.IdentifiedEstimand {
  self.estimand
}

///|
/// The adjustment variables of the sampler.
pub fn DoSampler::adjustment_set(self : DoSampler) -> Array[String] {
  self.adjustment_names.copy()
}

///|
/// The treatment variables of the sampler.
pub fn DoSampler::treatments(self : DoSampler) -> Array[String] {
  self.treatment_names.copy()
}

///|
/// The outcome variables of the sampler.
pub fn DoSampler::outcomes(self : DoSampler) -> Array[String] {
  self.outcome_names.copy()
}

///|
/// The frame the sampler produced.
pub fn DoSampler::sampled_frame(self : DoSampler) -> @api.DataFrame {
  self.frame
}

///|
/// Reset the sampler to the original data.
///
/// The sampler can be used again after a reset; the random generator is not
/// reset, so the next sample differs from the previous one.
pub fn DoSampler::reset(self : DoSampler) -> Unit {
  self.frame = self.data.copy()
}

///|
/// Make the treatment effective.
///
/// The value of every treatment of `x` is imposed on the frame; the
/// weighting sampler keeps the rows whose treatment already has the value
/// instead, because the weight of a row is only defined for the treatment
/// state it was computed for.
pub fn DoSampler::make_treatment_effective(
  self : DoSampler,
  x : Map[String, Double],
) -> Unit {
  match self.kind {
    Weighting => self.make_treatment_effective_weighting(x)
    MultivariateWeighting => self.make_treatment_effective_weighting(x)
    KernelDensity => self.make_treatment_effective_kernel(x)
  }
}

///|
/// Disrupt the causes of the treatment.
///
/// The base sampler has no way of doing that; the weighting sampler renders
/// the treatment assignment ignorable with the propensity score and the
/// kernel density sampler cuts the edges into the treatment.
pub fn DoSampler::disrupt_causes(self : DoSampler) -> Unit {
  match self.kind {
    Weighting => self.disrupt_causes_weighting()
    MultivariateWeighting => self.disrupt_causes_weighting()
    KernelDensity => self.disrupt_causes_kernel()
  }
}

///|
/// Draw the sample of the outcome.
pub fn DoSampler::sample(self : DoSampler) -> Unit {
  match self.kind {
    Weighting => self.sample_weighting()
    MultivariateWeighting => self.sample_weighting()
    KernelDensity => self.sample_kernel()
  }
}

///|
/// Sample from the interventional distribution.
///
/// The three steps of the `do` operation run in the order of the upstream
/// code: the causes of the treatment are disrupted, the treatment is made
/// effective and the outcome is drawn. The frame the sampler works on is
/// returned.
pub fn DoSampler::do_sample(
  self : DoSampler,
  x : Map[String, Double],
) -> @api.DataFrame {
  self.reset()
  self.disrupt_causes()
  self.make_treatment_effective(x)
  self.sample()
  self.frame
}

///|
/// The number of entries of a map.
fn[V] map_size(entries : Map[String, V]) -> Int32 {
  let mut count = 0
  for key in entries.keys() {
    let _ = key
    count = count + 1
  }
  count
}
