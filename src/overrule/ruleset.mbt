///|
/// The configuration of a ruleset estimator, the port of the parameters of
/// the `BCSRulesetEstimator` of the upstream.
pub struct RulesetConfig {
  /// The multiplier of the number of the reference samples.
  n_ref_multiplier : Double
  /// The share of the positive samples the rules have to cover.
  alpha : Double
  /// The regularisation of the number of the rules.
  lambda0 : Double
  /// The regularisation of the number of the literals.
  lambda1 : Double
  /// The number of the results of the beam search.
  k : Int32
  /// The number of the extra rules per iteration of the beam search.
  d : Int32
  /// The width of the beam search.
  b : Int32
  /// The number of the iterations of the column generation.
  iter_max : Int32
  /// The tolerance of the comparisons.
  eps : Double
  /// The number of the bins of a continuous feature.
  num_thresholds : Int32
  /// Whether the negations of the literals are added.
  negations : Bool
  /// The strategy of the rounding.
  rounding : RoundingStrategy
  /// The seed of the reference samples.
  seed : Int32
}

///|
/// The estimator of a boolean rule set, the port of the
/// `BCSRulesetEstimator` of the upstream.
///
/// The estimator learns the rules of a region of the covariates: the support
/// of the data or the region where the treatment and the control overlap.
pub struct RulesetEstimator {
  config : RulesetConfig
  mut binarizer : FeatureBinarizer
  mut literals : Array[Literal]
  mut rule : BooleanRule
  mut fitted : Bool
}

///|
/// An estimator of a boolean rule set.
pub fn RulesetEstimator::new(config : RulesetConfig) -> RulesetEstimator {
  {
    config,
    binarizer: FeatureBinarizer::new([], 9, true),
    literals: [],
    rule: BooleanRule::new(
      0.95,
      0.001,
      0.001,
      20,
      20,
      10,
      10,
      0.000001,
      RoundingStrategy::GreedySweep,
    ),
    fitted: false,
  }
}

///|
/// Learn the rules of the given rows.
///
/// The labels of the rows are one for the rows the rules have to cover and
/// zero for the rows they have to avoid. The reference samples are the
/// background the rules are learned against.
pub fn RulesetEstimator::fit(
  self : RulesetEstimator,
  columns : Array[Array[Double]],
  names : Array[String],
  labels : Array[Double],
) -> Unit {
  let n = if columns.length() == 0 { 0 } else { columns[0].length() }
  let dim = columns.length()
  let num_reference = (n.to_double() *
  dim.to_double() *
  self.config.n_ref_multiplier).to_int()
  let random = @utils.Random::new(self.config.seed.to_uint64())
  let reference = sample_reference(
    columns,
    num_reference,
    random,
    self.config.seed,
  )
  let all_columns : Array[Array[Double]] = []
  for c = 0; c < dim; c = c + 1 {
    let values = columns[c].copy()
    for i = 0; i < num_reference; i = i + 1 {
      values.push(reference[c][i])
    }
    all_columns.push(values)
  }
  let all_labels = labels.copy()
  for i = 0; i < num_reference; i = i + 1 {
    all_labels.push(-1.0)
  }
  let binarizer = FeatureBinarizer::new(
    names,
    self.config.num_thresholds,
    self.config.negations,
  )
  // The binariser is fitted on the rows of the data, and not on the reference
  // samples, the way the upstream does it.
  let fitted_columns : Array[Array[Double]] = []
  for c = 0; c < dim; c = c + 1 {
    let head : Array[Double] = []
    for i = 0; i < n; i = i + 1 {
      head.push(all_columns[c][i])
    }
    fitted_columns.push(head)
  }
  binarizer.fit(fitted_columns)
  let binarized = binarizer.transform(all_columns)
  let rule = BooleanRule::new(
    self.config.alpha,
    self.config.lambda0,
    self.config.lambda1,
    self.config.k,
    self.config.d,
    self.config.b,
    self.config.iter_max,
    self.config.eps,
    self.config.rounding,
  )
  rule.fit(binarized, all_labels)
  self.binarizer = binarizer
  self.literals = binarized.literals
  self.rule = rule
  self.fitted = true
}

///|
/// Whether the rules cover every row of the given covariates.
pub fn RulesetEstimator::predict(
  self : RulesetEstimator,
  columns : Array[Array[Double]],
) -> Array[Bool] {
  let binarized = self.binarizer.transform(columns)
  self.rule.predict(binarized)
}

///|
/// The rules of the estimator.
pub fn RulesetEstimator::rules(self : RulesetEstimator) -> RuleSet {
  self.rule.rules(self.literals)
}

///|
/// The value of the program of the rules.
pub fn RulesetEstimator::objective(self : RulesetEstimator) -> Double {
  self.rule.lp_value()
}
