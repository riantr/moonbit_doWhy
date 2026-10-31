///|
/// The estimator family that DoWhy offers.
///
/// The kind decides which algorithm `fit` and `estimate_effect` run; the
/// estimator itself keeps the fitted state, exactly like the Python classes
/// inherit from `CausalEstimator`.
pub enum EstimatorKind {
  /// Ordinary least squares on the treatment and the adjustment variables.
  LinearRegression
  /// Inverse propensity score weighting.
  PropensityScoreWeighting
  /// Propensity score matching.
  PropensityScoreMatching
  /// Propensity score stratification.
  PropensityScoreStratification
  /// The augmented inverse propensity weighted estimator.
  DoublyRobust
  /// Two stage least squares with an instrument.
  InstrumentalVariable
  /// Two stage regression for the frontdoor and the mediation estimands.
  TwoStageRegression
  /// Regression discontinuity.
  RegressionDiscontinuity
  /// A generalised linear model, with the family of the estimator.
  GeneralizedLinearModel
}

///|
/// The weighting scheme of the propensity score weighting estimator.
pub enum WeightingScheme {
  /// Inverse propensity score weighting.
  IpsWeight
  /// Stabilised inverse propensity score weighting.
  IpsStabilizedWeight
  /// Normalised (Hajek) inverse propensity score weighting.
  IpsNormalizedWeight
}

///|
/// The inverse propensity score weighting scheme.
pub fn WeightingScheme::ips_weight() -> WeightingScheme {
  IpsWeight
}

///|
/// The stabilised inverse propensity score weighting scheme.
pub fn WeightingScheme::ips_stabilized_weight() -> WeightingScheme {
  IpsStabilizedWeight
}

///|
/// The normalised inverse propensity score weighting scheme.
pub fn WeightingScheme::ips_normalized_weight() -> WeightingScheme {
  IpsNormalizedWeight
}

///|
/// The name of the weighting scheme.
pub fn WeightingScheme::name(self : WeightingScheme) -> String {
  match self {
    IpsWeight => "ips_weight"
    IpsStabilizedWeight => "ips_stabilized_weight"
    IpsNormalizedWeight => "ips_normalized_weight"
  }
}

///|
/// A causal estimator.
///
/// The estimator owns the identified estimand and the state that `fit`
/// produced; `estimate_effect` turns a data frame into a `CausalEstimate`.
pub struct CausalEstimator {
  /// The estimand the estimator was built for.
  mut target_estimand : @identifiers.IdentifiedEstimand
  /// The algorithm of the estimator.
  kind : EstimatorKind
  /// The weighting scheme, used by the propensity score weighting estimator.
  mut weighting_scheme : WeightingScheme
  /// The lower bound of the propensity score.
  mut min_ps_score : Double
  /// The upper bound of the propensity score.
  mut max_ps_score : Double
  /// The number of strata, used by the stratification estimator.
  mut num_strata : Int32
  /// Strata with fewer units than this are dropped.
  mut clipping_threshold : Int32
  /// The instrument, used by the instrumental variable estimator.
  mut instrument_name : String
  /// The running variable and the threshold, used by the discontinuity estimator.
  mut rd_variable_name : String
  mut rd_threshold_value : Double
  mut rd_bandwidth : Double
  /// The data inside the band, used by the regression discontinuity estimator.
  mut rd_local_data : @api.DataFrame?
  /// The fitted model of the regression based estimators.
  mut model : @utils.OlsFit
  /// The fitted model of the generalised linear model estimator.
  mut glm_model : @utils.GlmFit
  /// The family of the generalised linear model estimator.
  mut glm_family : @utils.GlmFamily
  /// The encoders of the discrete columns, one per set of variables.
  ///
  /// The encoders are fitted when the estimator is fitted, so that the
  /// encoding of the data does not depend on the order the rows arrive in.
  encoders : @api.Encoders
  /// The columns of the design matrix, in order.
  mut features : Array[String]
  /// The fitted propensity scores.
  mut propensities : Array[Double]
  /// The coefficients of the fitted propensity score model.
  ///
  /// The scores of a data frame are computed from them, so that the scores
  /// follow the rows of the data they are used with.
  mut propensity_beta : Array[Double]
  /// The adjustment variables the estimator uses.
  mut adjustment_names : Array[String]
  /// The effect modifiers the estimator uses.
  mut effect_modifier_names : Array[String]
  /// The treatment column.
  mut treatment_name : String
  /// The outcome column.
  mut outcome_name : String
  /// The treatment value of the treated arm.
  mut treatment_value : Double
  /// The treatment value of the control arm.
  mut control_value : Double
  /// The confidence level of the intervals.
  mut confidence_level : Double
  /// The number of bootstrap simulations.
  mut num_simulations : Int32
  /// The fraction of the sample a bootstrap resample takes.
  mut sample_size_fraction : Double
  /// Whether the confidence intervals are computed.
  mut compute_confidence_intervals : Bool
  /// Whether the significance is tested.
  mut test_significance : Bool
}

///|
/// The default number of simulations used for the confidence intervals.
pub const DEFAULT_NUMBER_OF_SIMULATIONS_CI : Int32 = 399

///|
/// The default number of simulations used for the significance test.
pub const DEFAULT_NUMBER_OF_SIMULATIONS_STAT_TEST : Int32 = 1000

///|
/// The default confidence level.
pub const DEFAULT_CONFIDENCE_LEVEL : Double = 0.95

///|
/// The default number of quantiles a continuous effect modifier is split into.
pub const NUM_QUANTILES_TO_DISCRETIZE_CONT_COLS : Int32 = 5

///|
/// An ordinary least squares estimator for the given estimand.
pub fn CausalEstimator::linear_regression(
  estimand : @identifiers.IdentifiedEstimand,
) -> CausalEstimator {
  CausalEstimator::new(estimand, EstimatorKind::LinearRegression)
}

///|
/// An inverse propensity score weighting estimator.
pub fn CausalEstimator::propensity_score_weighting(
  estimand : @identifiers.IdentifiedEstimand,
  min_ps_score : Double,
  max_ps_score : Double,
  scheme : WeightingScheme,
) -> CausalEstimator {
  let estimator = CausalEstimator::new(
    estimand,
    EstimatorKind::PropensityScoreWeighting,
  )
  estimator.min_ps_score = min_ps_score
  estimator.max_ps_score = max_ps_score
  estimator.weighting_scheme = scheme
  estimator
}

///|
/// A propensity score matching estimator.
pub fn CausalEstimator::propensity_score_matching(
  estimand : @identifiers.IdentifiedEstimand,
) -> CausalEstimator {
  CausalEstimator::new(estimand, EstimatorKind::PropensityScoreMatching)
}

///|
/// A propensity score stratification estimator.
pub fn CausalEstimator::propensity_score_stratification(
  estimand : @identifiers.IdentifiedEstimand,
  num_strata : Int32,
  clipping_threshold : Int32,
) -> CausalEstimator {
  let estimator = CausalEstimator::new(
    estimand,
    EstimatorKind::PropensityScoreStratification,
  )
  estimator.num_strata = num_strata
  estimator.clipping_threshold = clipping_threshold
  estimator
}

///|
/// A doubly robust estimator.
pub fn CausalEstimator::doubly_robust(
  estimand : @identifiers.IdentifiedEstimand,
  min_ps_score : Double,
  max_ps_score : Double,
) -> CausalEstimator {
  let estimator = CausalEstimator::new(estimand, EstimatorKind::DoublyRobust)
  estimator.min_ps_score = min_ps_score
  estimator.max_ps_score = max_ps_score
  estimator
}

///|
/// An instrumental variable estimator.
pub fn CausalEstimator::instrumental_variable(
  estimand : @identifiers.IdentifiedEstimand,
  instrument_name : String,
) -> CausalEstimator {
  let estimator = CausalEstimator::new(
    estimand,
    EstimatorKind::InstrumentalVariable,
  )
  estimator.instrument_name = instrument_name
  estimator
}

///|
/// A two stage regression estimator.
pub fn CausalEstimator::two_stage_regression(
  estimand : @identifiers.IdentifiedEstimand,
) -> CausalEstimator {
  CausalEstimator::new(estimand, EstimatorKind::TwoStageRegression)
}

///|
/// A regression discontinuity estimator.
pub fn CausalEstimator::regression_discontinuity(
  estimand : @identifiers.IdentifiedEstimand,
  rd_variable_name : String,
  rd_threshold_value : Double,
  rd_bandwidth : Double,
) -> CausalEstimator {
  let estimator = CausalEstimator::new(
    estimand,
    EstimatorKind::RegressionDiscontinuity,
  )
  estimator.rd_variable_name = rd_variable_name
  estimator.rd_threshold_value = rd_threshold_value
  estimator.rd_bandwidth = rd_bandwidth
  estimator
}

///|
/// A generalised linear model estimator for the given estimand.
///
/// The family decides the link of the model: a binomial family fits a logistic
/// regression, a poisson family fits a count model and the gaussian family
/// fits an ordinary least squares model.
pub fn CausalEstimator::generalized_linear_model(
  estimand : @identifiers.IdentifiedEstimand,
  family : @utils.GlmFamily,
) -> CausalEstimator {
  let estimator = CausalEstimator::new(
    estimand,
    EstimatorKind::GeneralizedLinearModel,
  )
  estimator.glm_family = family
  estimator
}

///|
fn CausalEstimator::new(
  estimand : @identifiers.IdentifiedEstimand,
  kind : EstimatorKind,
) -> CausalEstimator {
  {
    target_estimand: estimand,
    kind,
    weighting_scheme: IpsWeight,
    min_ps_score: 0.05,
    max_ps_score: 0.95,
    num_strata: 5,
    clipping_threshold: 10,
    instrument_name: "",
    rd_variable_name: "",
    rd_threshold_value: 0.0,
    rd_bandwidth: 0.0,
    rd_local_data: None,
    model: @utils.OlsFit::empty(),
    glm_model: @utils.GlmFit::empty(),
    glm_family: @utils.GlmFamily::gaussian(),
    encoders: @api.Encoders::new(true),
    features: [],
    propensities: [],
    propensity_beta: [],
    adjustment_names: [],
    effect_modifier_names: [],
    treatment_name: "",
    outcome_name: "",
    treatment_value: 1.0,
    control_value: 0.0,
    confidence_level: DEFAULT_CONFIDENCE_LEVEL,
    num_simulations: DEFAULT_NUMBER_OF_SIMULATIONS_CI,
    sample_size_fraction: 1.0,
    compute_confidence_intervals: false,
    test_significance: false,
  }
}

///|
/// The estimand the estimator was built for.
pub fn CausalEstimator::estimand(
  self : CausalEstimator,
) -> @identifiers.IdentifiedEstimand {
  self.target_estimand
}

///|
/// Replace the estimand the estimator was built for.
///
/// The refuters use this to estimate a different effect with the same
/// estimator.
pub fn CausalEstimator::set_estimand(
  self : CausalEstimator,
  estimand : @identifiers.IdentifiedEstimand,
) -> Unit {
  self.target_estimand = estimand
}

///|
/// The algorithm of the estimator.
pub fn CausalEstimator::estimator_kind(self : CausalEstimator) -> EstimatorKind {
  self.kind
}

///|
/// The treatment column the estimator uses.
pub fn CausalEstimator::treatment(self : CausalEstimator) -> String {
  self.treatment_name
}

///|
/// The outcome column the estimator uses.
pub fn CausalEstimator::outcome(self : CausalEstimator) -> String {
  self.outcome_name
}

///|
/// The adjustment variables the estimator uses.
pub fn CausalEstimator::adjustment_set(self : CausalEstimator) -> Array[String] {
  self.adjustment_names.copy()
}

///|
/// The propensity scores the estimator computed.
pub fn CausalEstimator::propensity_scores(
  self : CausalEstimator,
) -> Array[Double] {
  self.propensities.copy()
}

///|
/// Set the confidence level of the intervals.
pub fn CausalEstimator::set_confidence_level(
  self : CausalEstimator,
  level : Double,
) -> Unit {
  self.confidence_level = level
}

///|
/// Set the number of bootstrap simulations.
pub fn CausalEstimator::set_num_simulations(
  self : CausalEstimator,
  num_simulations : Int32,
) -> Unit {
  self.num_simulations = num_simulations
}

///|
/// Set the fraction of the sample a bootstrap resample takes.
pub fn CausalEstimator::set_sample_size_fraction(
  self : CausalEstimator,
  fraction : Double,
) -> Unit {
  self.sample_size_fraction = fraction
}

///|
/// Ask the estimator to compute the confidence intervals.
pub fn CausalEstimator::set_compute_confidence_intervals(
  self : CausalEstimator,
  compute : Bool,
) -> Unit {
  self.compute_confidence_intervals = compute
}

///|
/// Ask the estimator to test the significance of the estimate.
pub fn CausalEstimator::set_test_significance(
  self : CausalEstimator,
  do_test : Bool,
) -> Unit {
  self.test_significance = do_test
}

///|
/// A copy of the estimator that estimates a different estimand.
///
/// The refuters use this to re-estimate the effect with the same algorithm on
/// modified data. The copy starts without any fitted state, so the estimator
/// that was handed in keeps the model and the adjustment set it was fitted
/// with.
pub fn CausalEstimator::with_estimand(
  self : CausalEstimator,
  estimand : @identifiers.IdentifiedEstimand,
) -> CausalEstimator {
  let copy = CausalEstimator::new(estimand, self.kind)
  copy.weighting_scheme = self.weighting_scheme
  copy.min_ps_score = self.min_ps_score
  copy.max_ps_score = self.max_ps_score
  copy.num_strata = self.num_strata
  copy.clipping_threshold = self.clipping_threshold
  copy.instrument_name = self.instrument_name
  copy.rd_variable_name = self.rd_variable_name
  copy.rd_threshold_value = self.rd_threshold_value
  copy.rd_bandwidth = self.rd_bandwidth
  copy.glm_family = self.glm_family
  copy.confidence_level = self.confidence_level
  copy.num_simulations = self.num_simulations
  copy.sample_size_fraction = self.sample_size_fraction
  copy.compute_confidence_intervals = self.compute_confidence_intervals
  copy.test_significance = self.test_significance
  copy
}
