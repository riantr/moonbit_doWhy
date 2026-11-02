///|
/// The configuration of the support rules, the port of the `SupportConfig` of
/// the upstream.
pub struct SupportConfig {
  /// The multiplier of the number of the reference samples.
  n_ref_multiplier : Double
  /// The seed of the reference samples.
  seed : Int32
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
  /// The number of the bins of a continuous feature.
  num_thresholds : Int32
  /// The strategy of the rounding.
  rounding : RoundingStrategy
}

///|
/// The configuration of the support rules, with the defaults of the upstream.
pub fn SupportConfig::new() -> SupportConfig {
  {
    n_ref_multiplier: 1.0,
    seed: 0,
    alpha: 0.98,
    lambda0: 0.01,
    lambda1: 0.001,
    k: 20,
    d: 20,
    b: 10,
    iter_max: 10,
    num_thresholds: 9,
    rounding: RoundingStrategy::GreedySweep,
  }
}

///|
/// The configuration of the overlap rules, the port of the `OverlapConfig` of
/// the upstream.
pub struct OverlapConfig {
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
  /// The number of the bins of a continuous feature.
  num_thresholds : Int32
  /// The strategy of the rounding.
  rounding : RoundingStrategy
}

///|
/// The configuration of the overlap rules, with the defaults of the upstream.
pub fn OverlapConfig::new() -> OverlapConfig {
  {
    alpha: 0.95,
    lambda0: 0.001,
    lambda1: 0.001,
    k: 20,
    d: 20,
    b: 10,
    iter_max: 10,
    num_thresholds: 9,
    rounding: RoundingStrategy::GreedySweep,
  }
}

///|
/// The configuration of a ruleset estimator of the support.
fn SupportConfig::ruleset_config(self : SupportConfig) -> RulesetConfig {
  {
    n_ref_multiplier: self.n_ref_multiplier,
    alpha: self.alpha,
    lambda0: self.lambda0,
    lambda1: self.lambda1,
    k: self.k,
    d: self.d,
    b: self.b,
    iter_max: self.iter_max,
    eps: 0.000001,
    num_thresholds: self.num_thresholds,
    negations: true,
    rounding: self.rounding,
    seed: self.seed,
  }
}

///|
/// The configuration of a ruleset estimator of the overlap.
///
/// The overlap rules have no reference samples, because the region they
/// describe is bounded by the data themselves.
fn OverlapConfig::ruleset_config(self : OverlapConfig) -> RulesetConfig {
  {
    n_ref_multiplier: 0.0,
    alpha: self.alpha,
    lambda0: self.lambda0,
    lambda1: self.lambda1,
    k: self.k,
    d: self.d,
    b: self.b,
    iter_max: self.iter_max,
    eps: 0.000001,
    num_thresholds: self.num_thresholds,
    negations: true,
    rounding: self.rounding,
    seed: 0,
  }
}

///|
/// The analyzer of the support and the overlap rules, the port of the
/// `OverruleAnalyzer` of the upstream.
///
/// The support rules describe the region of the covariates the data cover, and
/// the overlap rules describe the region where the treatment and the control
/// overlap, which is found with the propensity scores.
pub struct OverlapAnalyzer {
  backdoor_vars : Array[String]
  treatment_name : String
  support_config : SupportConfig
  overlap_config : OverlapConfig
  overlap_eps : Double
  mut support_only : Bool
  overlap_only : Bool
  mut support_estimator : RulesetEstimator?
  mut overlap_estimator : RulesetEstimator?
  mut support_indicator : Array[Bool]
  mut overlap_indicator : Array[Bool]
  mut raw_overlap : Array[Bool]
  mut fitted : Bool
}

///|
/// An analyzer of the support and the overlap rules.
///
/// The range of the propensity scores that describes the overlap region is
/// `(overlap_eps, 1 - overlap_eps)`, and only the support or only the overlap
/// rules are learned when the analyzer is asked for one of them.
pub fn OverlapAnalyzer::new(
  backdoor_vars : Array[String],
  treatment_name : String,
  support_config : SupportConfig,
  overlap_config : OverlapConfig,
  overlap_eps~ : Double = 0.1,
  support_only~ : Bool = false,
  overlap_only~ : Bool = false,
) -> OverlapAnalyzer {
  {
    backdoor_vars: backdoor_vars.copy(),
    treatment_name,
    support_config,
    overlap_config,
    overlap_eps,
    support_only,
    overlap_only,
    support_estimator: None,
    overlap_estimator: None,
    support_indicator: [],
    overlap_indicator: [],
    raw_overlap: [],
    fitted: false,
  }
}

///|
/// Learn the rules of the given covariates.
///
/// The columns are the backdoor variables and the treatment is the column of
/// the treatment, the way the upstream takes them.
pub fn OverlapAnalyzer::fit(
  self : OverlapAnalyzer,
  columns : Array[Array[Double]],
  treatment : Array[Double],
) -> Unit {
  let mut support : Array[Bool] = []
  if !self.overlap_only {
    let estimator = RulesetEstimator::new(self.support_config.ruleset_config())
    let labels : Array[Double] = []
    for i = 0; i < treatment.length(); i = i + 1 {
      labels.push(1.0)
    }
    estimator.fit(columns, self.backdoor_vars, labels)
    support = estimator.predict(columns)
    self.support_estimator = Some(estimator)
  } else {
    for i = 0; i < treatment.length(); i = i + 1 {
      support.push(true)
    }
  }
  self.support_indicator = support
  // The rows of the support.
  let supported_rows : Array[Int32] = []
  for i = 0; i < support.length(); i = i + 1 {
    if support[i] {
      supported_rows.push(i)
    }
  }
  let supported_columns : Array[Array[Double]] = []
  for c = 0; c < columns.length(); c = c + 1 {
    let values : Array[Double] = []
    for row in supported_rows {
      values.push(columns[c][row])
    }
    supported_columns.push(values)
  }
  let supported_treatment : Array[Double] = []
  for row in supported_rows {
    supported_treatment.push(treatment[row])
  }
  if self.support_only {
    self.overlap_indicator = support
    self.fitted = true
    return
  }
  // The overlap region is found with the propensity scores.
  let raw = propensity_overlap(
    supported_columns,
    supported_treatment,
    self.overlap_eps,
  )
  self.raw_overlap = raw
  let mut all = true
  for value in raw {
    if !value {
      all = false
      break
    }
  }
  if all {
    // Every sample of the support is in the overlap region, so there are no
    // overlap rules to learn.
    self.overlap_indicator = support
    self.support_only = true
    self.fitted = true
    return
  }
  let labels : Array[Double] = []
  for value in raw {
    labels.push(if value { 1.0 } else { 0.0 })
  }
  let estimator = RulesetEstimator::new(self.overlap_config.ruleset_config())
  estimator.fit(supported_columns, self.backdoor_vars, labels)
  self.overlap_indicator = estimator.predict(supported_columns)
  self.overlap_estimator = Some(estimator)
  self.fitted = true
}

///|
/// The rows of the support.
pub fn OverlapAnalyzer::support_indicator(
  self : OverlapAnalyzer,
) -> Array[Bool] {
  self.support_indicator.copy()
}

///|
/// The rows of the overlap region.
pub fn OverlapAnalyzer::overlap_indicator(
  self : OverlapAnalyzer,
) -> Array[Bool] {
  self.overlap_indicator.copy()
}

///|
/// The rules of the support.
pub fn OverlapAnalyzer::support_rules(self : OverlapAnalyzer) -> RuleSet {
  match self.support_estimator {
    Some(estimator) => estimator.rules()
    None => []
  }
}

///|
/// The rules of the overlap region.
pub fn OverlapAnalyzer::overlap_rules(self : OverlapAnalyzer) -> RuleSet {
  match self.overlap_estimator {
    Some(estimator) => estimator.rules()
    None => []
  }
}

///|
/// The value of the program of the support rules.
pub fn OverlapAnalyzer::support_objective(self : OverlapAnalyzer) -> Double {
  match self.support_estimator {
    Some(estimator) => estimator.objective()
    None => 0.0
  }
}

///|
/// The value of the program of the overlap rules.
pub fn OverlapAnalyzer::overlap_objective(self : OverlapAnalyzer) -> Double {
  match self.overlap_estimator {
    Some(estimator) => estimator.objective()
    None => 0.0
  }
}

///|
/// The rows of the covariates that the support rules cover and the overlap
/// rules cover.
pub fn OverlapAnalyzer::predict_overlap_support(
  self : OverlapAnalyzer,
  columns : Array[Array[Double]],
) -> Array[Bool] {
  let out : Array[Bool] = []
  let support = match self.support_estimator {
    Some(estimator) => estimator.predict(columns)
    None => {
      let every : Array[Bool] = []
      for i = 0; i < columns[0].length(); i = i + 1 {
        every.push(true)
      }
      every
    }
  }
  let overlap = match self.overlap_estimator {
    Some(estimator) => estimator.predict(columns)
    None => {
      let every : Array[Bool] = []
      for i = 0; i < columns[0].length(); i = i + 1 {
        every.push(true)
      }
      every
    }
  }
  for i = 0; i < support.length(); i = i + 1 {
    out.push(support[i] && overlap[i])
  }
  out
}

///|
/// The rows of the covariates that are in the overlap region, found with the
/// propensity scores.
///
/// The propensity scores are fitted with a cross fitting of two folds, so that
/// the score of a row is not the score of a model that saw that row. A row is
/// in the overlap region when its score is between `overlap_eps` and one minus
/// `overlap_eps`.
fn propensity_overlap(
  columns : Array[Array[Double]],
  treatment : Array[Double],
  overlap_eps : Double,
) -> Array[Bool] {
  let n = treatment.length()
  let scores = cross_fitted_propensity_scores(columns, treatment)
  let out : Array[Bool] = []
  for i = 0; i < n; i = i + 1 {
    out.push(scores[i] < 1.0 - overlap_eps && scores[i] > overlap_eps)
  }
  out
}

///|
/// The propensity scores of the treatment, fitted with a cross fitting of two
/// folds.
///
/// The folds are stratified by the treatment, so that both of them hold the
/// same share of the treated rows.
fn cross_fitted_propensity_scores(
  columns : Array[Array[Double]],
  treatment : Array[Double],
) -> Array[Double] {
  let n = treatment.length()
  let scores : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    scores.push(0.0)
  }
  let folds = stratified_folds(treatment)
  for fold = 0; fold < 2; fold = fold + 1 {
    // The design of the model: the intercept and the covariates.
    let design = @utils.Matrix::from_columns(design_columns(columns))
    // The model of a fold is fitted on the rows of the other fold.
    let train_target : Array[Double] = []
    for i = 0; i < n; i = i + 1 {
      if folds[i] != fold {
        train_target.push(treatment[i])
      }
    }
    let train_design = take_rows(design, folds, fold, false)
    let fit = @utils.logistic_fit(train_design, train_target, 1.0, 100, 0.0001)
    let test_design = take_rows(design, folds, fold, true)
    let predicted = @utils.logistic_predict(fit.beta, test_design)
    let mut position = 0
    for i = 0; i < n; i = i + 1 {
      if folds[i] == fold {
        scores[i] = predicted[position]
        position = position + 1
      }
    }
  }
  scores
}

///|
/// The design of the propensity model: the intercept and the covariates.
fn design_columns(columns : Array[Array[Double]]) -> Array[Array[Double]] {
  let n = if columns.length() == 0 { 0 } else { columns[0].length() }
  let out : Array[Array[Double]] = []
  let intercept : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    intercept.push(1.0)
  }
  out.push(intercept)
  for c = 0; c < columns.length(); c = c + 1 {
    out.push(columns[c].copy())
  }
  out
}

///|
/// The rows of a design matrix that belong to a fold, or to the other folds.
fn take_rows(
  design : @utils.Matrix,
  folds : Array[Int32],
  fold : Int32,
  keep : Bool,
) -> @utils.Matrix {
  let columns : Array[Array[Double]] = []
  for j = 0; j < design.ncols(); j = j + 1 {
    let values : Array[Double] = []
    for i = 0; i < design.nrows(); i = i + 1 {
      if (folds[i] == fold) == keep {
        values.push(design.get(i, j))
      }
    }
    columns.push(values)
  }
  @utils.Matrix::from_columns(columns)
}

///|
/// The fold of every row, stratified by the treatment.
fn stratified_folds(treatment : Array[Double]) -> Array[Int32] {
  let folds : Array[Int32] = []
  for i = 0; i < treatment.length(); i = i + 1 {
    folds.push(0)
  }
  let treated : Array[Int32] = []
  let untreated : Array[Int32] = []
  for i = 0; i < treatment.length(); i = i + 1 {
    if treatment[i] == 1.0 {
      treated.push(i)
    } else {
      untreated.push(i)
    }
  }
  for group in [treated, untreated] {
    for i = 0; i < group.length(); i = i + 1 {
      folds[group[i]] = i % 2
    }
  }
  folds
}
