///|
/// The evaluation of a causal model.
///
/// This is the port of `dowhy.gcm.model_evaluation`. The module evaluates four
/// things about a causal model: the performance of the causal mechanisms of its
/// nodes, the assumption of the invertible functional causal model, the
/// distribution that the model generates and the structure of the graph of the
/// model.
///
/// The deviations from the upstream are the following ones.
/// - The upstream takes the parameters of the evaluation in a configuration
///   object and the parts to evaluate in the arguments of the function. The port
///   takes both in a configuration object and in an options object, because the
///   package has no mutable module globals and passes every setting explicitly.
/// - The upstream draws its randomness from the global generator of numpy. The
///   port draws it from the generator it is given, so that the same generator
///   always gives the same result.
/// - The upstream compares the mechanisms of the nodes with a whole zoo of
///   baseline models and skips the baseline whose model class is the class of
///   the mechanism. The port has one regression model and one classification
///   model, so it compares the mechanism with every baseline it is given.
/// - The upstream has a parameter that limits the number of the samples of the
///   evaluation, but the code of the upstream does not use it to take a subset
///   of the data. The port does not have the parameter.
/// - The upstream plots the histogram of the falsification of the graph when it
///   writes the report. The plotting of the upstream is not ported, so the
///   port only writes the report.

///|
/// The configuration of the evaluation of a causal model.
///
/// This is the port of `dowhy.gcm.model_evaluation.EvaluateCausalModelConfig`.
pub struct EvaluationConfig {
  /// The number of the folds of the cross validation of the mechanisms.
  mechanism_evaluation_kfolds : Int32
  /// The baselines of the continuous nodes, with the name the report shows.
  baseline_models_regression : Array[(String, () -> PredictionModel)]
  /// The baselines of the categorical nodes, with the name the report shows.
  baseline_models_classification : Array[(String, () -> ClassificationModel)]
  /// The test of the independence of the inputs and of the noise of the
  /// mechanisms.
  independence_test_invertible : IndependenceTest
  /// The significance level of the test of the invertibility assumption.
  significance_level_invertible : Double
  /// The control of the false discovery rate of the tests of the invertibility
  /// assumption. The absence of the control means that every test is compared
  /// with the significance level on its own.
  fdr_control_method_invertible : FdrControlMethod?
  /// The number of the subsets the test of the invertibility runs on.
  bootstrap_runs_invertible : Int32
  /// The number of the permutations of the falsification of the graph. The
  /// absence of the number means that the number is the inverse of the
  /// significance level of the falsification.
  max_num_permutations_falsify : Int32?
  /// The test of the independence of two variables of the falsification.
  independence_test_falsify : IndependenceTest
  /// The test of the independence of two variables given a third one of the
  /// falsification.
  conditional_independence_test_falsify : IndependenceTest
  /// The significance level of the permutation test of the falsification.
  falsify_graph_significance_level : Double
}

///|
/// The default configuration of the evaluation of a causal model.
///
/// The independence tests of the configuration are the generalised covariance
/// measure of the package, which is the test of the package that needs one
/// dimensional variables only. The test of the invertibility assumption of a
/// node with more than one parent needs a test that takes several variables,
/// which the kernel based test of the package does; `kernel_independence_test`
/// builds one.
pub fn EvaluationConfig::new() -> EvaluationConfig {
  {
    mechanism_evaluation_kfolds: 5,
    baseline_models_regression: [
      ("AdditiveNoiseModel(PredictionModel::linear)", PredictionModel::linear),
    ],
    baseline_models_classification: [
      (
        "ClassifierFCM(ClassificationModel::logistic)",
        ClassificationModel::logistic,
      ),
    ],
    independence_test_invertible: generalised_cov_based,
    significance_level_invertible: 0.05,
    fdr_control_method_invertible: Some(FdrBonferroni),
    bootstrap_runs_invertible: 5,
    max_num_permutations_falsify: Some(50),
    independence_test_falsify: generalised_cov_based,
    conditional_independence_test_falsify: generalised_cov_based,
    falsify_graph_significance_level: 0.2,
  }
}

///|
/// A copy of the configuration with the given number of the folds.
pub fn EvaluationConfig::with_mechanism_evaluation_kfolds(
  self : EvaluationConfig,
  kfolds : Int32,
) -> EvaluationConfig {
  {
    mechanism_evaluation_kfolds: kfolds,
    baseline_models_regression: self.baseline_models_regression.copy(),
    baseline_models_classification: self.baseline_models_classification.copy(),
    independence_test_invertible: self.independence_test_invertible,
    significance_level_invertible: self.significance_level_invertible,
    fdr_control_method_invertible: self.fdr_control_method_invertible,
    bootstrap_runs_invertible: self.bootstrap_runs_invertible,
    max_num_permutations_falsify: self.max_num_permutations_falsify,
    independence_test_falsify: self.independence_test_falsify,
    conditional_independence_test_falsify: self.conditional_independence_test_falsify,
    falsify_graph_significance_level: self.falsify_graph_significance_level,
  }
}

///|
/// A copy of the configuration with the given baselines of the continuous nodes.
pub fn EvaluationConfig::with_baseline_models_regression(
  self : EvaluationConfig,
  models : Array[(String, () -> PredictionModel)],
) -> EvaluationConfig {
  {
    mechanism_evaluation_kfolds: self.mechanism_evaluation_kfolds,
    baseline_models_regression: models.copy(),
    baseline_models_classification: self.baseline_models_classification.copy(),
    independence_test_invertible: self.independence_test_invertible,
    significance_level_invertible: self.significance_level_invertible,
    fdr_control_method_invertible: self.fdr_control_method_invertible,
    bootstrap_runs_invertible: self.bootstrap_runs_invertible,
    max_num_permutations_falsify: self.max_num_permutations_falsify,
    independence_test_falsify: self.independence_test_falsify,
    conditional_independence_test_falsify: self.conditional_independence_test_falsify,
    falsify_graph_significance_level: self.falsify_graph_significance_level,
  }
}

///|
/// A copy of the configuration with the given baselines of the categorical
/// nodes.
pub fn EvaluationConfig::with_baseline_models_classification(
  self : EvaluationConfig,
  models : Array[(String, () -> ClassificationModel)],
) -> EvaluationConfig {
  {
    mechanism_evaluation_kfolds: self.mechanism_evaluation_kfolds,
    baseline_models_regression: self.baseline_models_regression.copy(),
    baseline_models_classification: models.copy(),
    independence_test_invertible: self.independence_test_invertible,
    significance_level_invertible: self.significance_level_invertible,
    fdr_control_method_invertible: self.fdr_control_method_invertible,
    bootstrap_runs_invertible: self.bootstrap_runs_invertible,
    max_num_permutations_falsify: self.max_num_permutations_falsify,
    independence_test_falsify: self.independence_test_falsify,
    conditional_independence_test_falsify: self.conditional_independence_test_falsify,
    falsify_graph_significance_level: self.falsify_graph_significance_level,
  }
}

///|
/// A copy of the configuration with the given test of the invertibility
/// assumption.
pub fn EvaluationConfig::with_independence_test_invertible(
  self : EvaluationConfig,
  independence_test : IndependenceTest,
) -> EvaluationConfig {
  {
    mechanism_evaluation_kfolds: self.mechanism_evaluation_kfolds,
    baseline_models_regression: self.baseline_models_regression.copy(),
    baseline_models_classification: self.baseline_models_classification.copy(),
    independence_test_invertible: independence_test,
    significance_level_invertible: self.significance_level_invertible,
    fdr_control_method_invertible: self.fdr_control_method_invertible,
    bootstrap_runs_invertible: self.bootstrap_runs_invertible,
    max_num_permutations_falsify: self.max_num_permutations_falsify,
    independence_test_falsify: self.independence_test_falsify,
    conditional_independence_test_falsify: self.conditional_independence_test_falsify,
    falsify_graph_significance_level: self.falsify_graph_significance_level,
  }
}

///|
/// A copy of the configuration with the given significance level of the test of
/// the invertibility assumption.
pub fn EvaluationConfig::with_significance_level_invertible(
  self : EvaluationConfig,
  level : Double,
) -> EvaluationConfig {
  {
    mechanism_evaluation_kfolds: self.mechanism_evaluation_kfolds,
    baseline_models_regression: self.baseline_models_regression.copy(),
    baseline_models_classification: self.baseline_models_classification.copy(),
    independence_test_invertible: self.independence_test_invertible,
    significance_level_invertible: level,
    fdr_control_method_invertible: self.fdr_control_method_invertible,
    bootstrap_runs_invertible: self.bootstrap_runs_invertible,
    max_num_permutations_falsify: self.max_num_permutations_falsify,
    independence_test_falsify: self.independence_test_falsify,
    conditional_independence_test_falsify: self.conditional_independence_test_falsify,
    falsify_graph_significance_level: self.falsify_graph_significance_level,
  }
}

///|
/// A copy of the configuration with the given control of the false discovery
/// rate of the tests of the invertibility assumption.
pub fn EvaluationConfig::with_fdr_control_method_invertible(
  self : EvaluationConfig,
  control : FdrControlMethod?,
) -> EvaluationConfig {
  {
    mechanism_evaluation_kfolds: self.mechanism_evaluation_kfolds,
    baseline_models_regression: self.baseline_models_regression.copy(),
    baseline_models_classification: self.baseline_models_classification.copy(),
    independence_test_invertible: self.independence_test_invertible,
    significance_level_invertible: self.significance_level_invertible,
    fdr_control_method_invertible: control,
    bootstrap_runs_invertible: self.bootstrap_runs_invertible,
    max_num_permutations_falsify: self.max_num_permutations_falsify,
    independence_test_falsify: self.independence_test_falsify,
    conditional_independence_test_falsify: self.conditional_independence_test_falsify,
    falsify_graph_significance_level: self.falsify_graph_significance_level,
  }
}

///|
/// A copy of the configuration with the given number of the subsets the test of
/// the invertibility runs on.
pub fn EvaluationConfig::with_bootstrap_runs_invertible(
  self : EvaluationConfig,
  runs : Int32,
) -> EvaluationConfig {
  {
    mechanism_evaluation_kfolds: self.mechanism_evaluation_kfolds,
    baseline_models_regression: self.baseline_models_regression.copy(),
    baseline_models_classification: self.baseline_models_classification.copy(),
    independence_test_invertible: self.independence_test_invertible,
    significance_level_invertible: self.significance_level_invertible,
    fdr_control_method_invertible: self.fdr_control_method_invertible,
    bootstrap_runs_invertible: runs,
    max_num_permutations_falsify: self.max_num_permutations_falsify,
    independence_test_falsify: self.independence_test_falsify,
    conditional_independence_test_falsify: self.conditional_independence_test_falsify,
    falsify_graph_significance_level: self.falsify_graph_significance_level,
  }
}

///|
/// A copy of the configuration with the given number of the permutations of the
/// falsification of the graph.
pub fn EvaluationConfig::with_max_num_permutations_falsify(
  self : EvaluationConfig,
  permutations : Int32?,
) -> EvaluationConfig {
  {
    mechanism_evaluation_kfolds: self.mechanism_evaluation_kfolds,
    baseline_models_regression: self.baseline_models_regression.copy(),
    baseline_models_classification: self.baseline_models_classification.copy(),
    independence_test_invertible: self.independence_test_invertible,
    significance_level_invertible: self.significance_level_invertible,
    fdr_control_method_invertible: self.fdr_control_method_invertible,
    bootstrap_runs_invertible: self.bootstrap_runs_invertible,
    max_num_permutations_falsify: permutations,
    independence_test_falsify: self.independence_test_falsify,
    conditional_independence_test_falsify: self.conditional_independence_test_falsify,
    falsify_graph_significance_level: self.falsify_graph_significance_level,
  }
}

///|
/// A copy of the configuration with the given test of the independence of two
/// variables of the falsification.
pub fn EvaluationConfig::with_independence_test_falsify(
  self : EvaluationConfig,
  independence_test : IndependenceTest,
) -> EvaluationConfig {
  {
    mechanism_evaluation_kfolds: self.mechanism_evaluation_kfolds,
    baseline_models_regression: self.baseline_models_regression.copy(),
    baseline_models_classification: self.baseline_models_classification.copy(),
    independence_test_invertible: self.independence_test_invertible,
    significance_level_invertible: self.significance_level_invertible,
    fdr_control_method_invertible: self.fdr_control_method_invertible,
    bootstrap_runs_invertible: self.bootstrap_runs_invertible,
    max_num_permutations_falsify: self.max_num_permutations_falsify,
    independence_test_falsify: independence_test,
    conditional_independence_test_falsify: self.conditional_independence_test_falsify,
    falsify_graph_significance_level: self.falsify_graph_significance_level,
  }
}

///|
/// A copy of the configuration with the given test of the independence of two
/// variables given a third one of the falsification.
pub fn EvaluationConfig::with_conditional_independence_test_falsify(
  self : EvaluationConfig,
  independence_test : IndependenceTest,
) -> EvaluationConfig {
  {
    mechanism_evaluation_kfolds: self.mechanism_evaluation_kfolds,
    baseline_models_regression: self.baseline_models_regression.copy(),
    baseline_models_classification: self.baseline_models_classification.copy(),
    independence_test_invertible: self.independence_test_invertible,
    significance_level_invertible: self.significance_level_invertible,
    fdr_control_method_invertible: self.fdr_control_method_invertible,
    bootstrap_runs_invertible: self.bootstrap_runs_invertible,
    max_num_permutations_falsify: self.max_num_permutations_falsify,
    independence_test_falsify: self.independence_test_falsify,
    conditional_independence_test_falsify: independence_test,
    falsify_graph_significance_level: self.falsify_graph_significance_level,
  }
}

///|
/// A copy of the configuration with the given significance level of the
/// permutation test of the falsification.
pub fn EvaluationConfig::with_falsify_graph_significance_level(
  self : EvaluationConfig,
  level : Double,
) -> EvaluationConfig {
  {
    mechanism_evaluation_kfolds: self.mechanism_evaluation_kfolds,
    baseline_models_regression: self.baseline_models_regression.copy(),
    baseline_models_classification: self.baseline_models_classification.copy(),
    independence_test_invertible: self.independence_test_invertible,
    significance_level_invertible: self.significance_level_invertible,
    fdr_control_method_invertible: self.fdr_control_method_invertible,
    bootstrap_runs_invertible: self.bootstrap_runs_invertible,
    max_num_permutations_falsify: self.max_num_permutations_falsify,
    independence_test_falsify: self.independence_test_falsify,
    conditional_independence_test_falsify: self.conditional_independence_test_falsify,
    falsify_graph_significance_level: level,
  }
}

///|
/// The parts of the model that the evaluation covers.
///
/// The upstream takes them in the arguments of its `evaluate_causal_model`.
pub struct EvaluationOptions {
  /// Whether the causal mechanisms of the nodes are evaluated.
  evaluate_causal_mechanisms : Bool
  /// Whether the causal mechanisms are compared with the baseline models.
  compare_mechanism_baselines : Bool
  /// Whether the assumption of the invertible functional causal model is
  /// tested.
  evaluate_invertibility_assumptions : Bool
  /// Whether the divergence of the generated and of the observed distribution
  /// is estimated.
  evaluate_overall_kl_divergence : Bool
  /// Whether the structure of the graph of the model is falsified.
  evaluate_causal_structure : Bool
}

///|
/// The default parts of the model that the evaluation covers.
///
/// The comparison with the baseline models is the only part that the upstream
/// does not run by default.
pub fn EvaluationOptions::new() -> EvaluationOptions {
  {
    evaluate_causal_mechanisms: true,
    compare_mechanism_baselines: false,
    evaluate_invertibility_assumptions: true,
    evaluate_overall_kl_divergence: true,
    evaluate_causal_structure: true,
  }
}

///|
/// A copy of the options with the given value of the evaluation of the
/// mechanisms.
pub fn EvaluationOptions::with_evaluate_causal_mechanisms(
  self : EvaluationOptions,
  value : Bool,
) -> EvaluationOptions {
  {
    evaluate_causal_mechanisms: value,
    compare_mechanism_baselines: self.compare_mechanism_baselines,
    evaluate_invertibility_assumptions: self.evaluate_invertibility_assumptions,
    evaluate_overall_kl_divergence: self.evaluate_overall_kl_divergence,
    evaluate_causal_structure: self.evaluate_causal_structure,
  }
}

///|
/// A copy of the options with the given value of the comparison with the
/// baseline models.
pub fn EvaluationOptions::with_compare_mechanism_baselines(
  self : EvaluationOptions,
  value : Bool,
) -> EvaluationOptions {
  {
    evaluate_causal_mechanisms: self.evaluate_causal_mechanisms,
    compare_mechanism_baselines: value,
    evaluate_invertibility_assumptions: self.evaluate_invertibility_assumptions,
    evaluate_overall_kl_divergence: self.evaluate_overall_kl_divergence,
    evaluate_causal_structure: self.evaluate_causal_structure,
  }
}

///|
/// A copy of the options with the given value of the evaluation of the
/// invertibility assumption.
pub fn EvaluationOptions::with_evaluate_invertibility_assumptions(
  self : EvaluationOptions,
  value : Bool,
) -> EvaluationOptions {
  {
    evaluate_causal_mechanisms: self.evaluate_causal_mechanisms,
    compare_mechanism_baselines: self.compare_mechanism_baselines,
    evaluate_invertibility_assumptions: value,
    evaluate_overall_kl_divergence: self.evaluate_overall_kl_divergence,
    evaluate_causal_structure: self.evaluate_causal_structure,
  }
}

///|
/// A copy of the options with the given value of the estimation of the overall
/// divergence.
pub fn EvaluationOptions::with_evaluate_overall_kl_divergence(
  self : EvaluationOptions,
  value : Bool,
) -> EvaluationOptions {
  {
    evaluate_causal_mechanisms: self.evaluate_causal_mechanisms,
    compare_mechanism_baselines: self.compare_mechanism_baselines,
    evaluate_invertibility_assumptions: self.evaluate_invertibility_assumptions,
    evaluate_overall_kl_divergence: value,
    evaluate_causal_structure: self.evaluate_causal_structure,
  }
}

///|
/// A copy of the options with the given value of the falsification of the
/// graph.
pub fn EvaluationOptions::with_evaluate_causal_structure(
  self : EvaluationOptions,
  value : Bool,
) -> EvaluationOptions {
  {
    evaluate_causal_mechanisms: self.evaluate_causal_mechanisms,
    compare_mechanism_baselines: self.compare_mechanism_baselines,
    evaluate_invertibility_assumptions: self.evaluate_invertibility_assumptions,
    evaluate_overall_kl_divergence: self.evaluate_overall_kl_divergence,
    evaluate_causal_structure: value,
  }
}

///|
/// The performance of the causal mechanism of one node.
///
/// This is the port of `dowhy.gcm.model_evaluation.MechanismPerformanceResult`.
pub struct MechanismPerformanceResult {
  /// The name of the node.
  node_name : String
  /// Whether the node is a root of the graph.
  is_root : Bool
  /// The score of the continuous ranked probability score.
  crps : Double?
  /// The divergence between the generated and the observed distribution.
  kl_divergence : Double?
  /// The mean squared error of the conditional expectation.
  mse : Double?
  /// The normalised mean squared error of the conditional expectation.
  nmse : Double?
  /// The coefficient of the determination of the conditional expectation.
  r2 : Double?
  /// The score of the F1 measure of the classifier.
  f1 : Double?
  /// The number of the baselines that performed significantly better.
  count_better_performance : Int32?
  /// The name of the baseline that performed best.
  best_baseline_model : String?
  /// The number of the baselines that were compared with the mechanism.
  total_number_baselines : Int32
  /// The score of the baseline that performed best.
  best_baseline_performance : Double?
}

///|
/// The name of the node.
pub fn MechanismPerformanceResult::node_name(
  self : MechanismPerformanceResult,
) -> String {
  self.node_name
}

///|
/// Whether the node is a root of the graph.
pub fn MechanismPerformanceResult::is_root(
  self : MechanismPerformanceResult,
) -> Bool {
  self.is_root
}

///|
/// The score of the continuous ranked probability score.
pub fn MechanismPerformanceResult::crps(
  self : MechanismPerformanceResult,
) -> Double? {
  self.crps
}

///|
/// The divergence between the generated and the observed distribution.
pub fn MechanismPerformanceResult::kl_divergence(
  self : MechanismPerformanceResult,
) -> Double? {
  self.kl_divergence
}

///|
/// The mean squared error of the conditional expectation.
pub fn MechanismPerformanceResult::mse(
  self : MechanismPerformanceResult,
) -> Double? {
  self.mse
}

///|
/// The normalised mean squared error of the conditional expectation.
pub fn MechanismPerformanceResult::nmse(
  self : MechanismPerformanceResult,
) -> Double? {
  self.nmse
}

///|
/// The coefficient of the determination of the conditional expectation.
pub fn MechanismPerformanceResult::r2(
  self : MechanismPerformanceResult,
) -> Double? {
  self.r2
}

///|
/// The score of the F1 measure of the classifier.
pub fn MechanismPerformanceResult::f1(
  self : MechanismPerformanceResult,
) -> Double? {
  self.f1
}

///|
/// The number of the baselines that performed significantly better.
pub fn MechanismPerformanceResult::count_better_performance(
  self : MechanismPerformanceResult,
) -> Int32? {
  self.count_better_performance
}

///|
/// The name of the baseline that performed best.
pub fn MechanismPerformanceResult::best_baseline_model(
  self : MechanismPerformanceResult,
) -> String? {
  self.best_baseline_model
}

///|
/// The number of the baselines that were compared with the mechanism.
pub fn MechanismPerformanceResult::total_number_baselines(
  self : MechanismPerformanceResult,
) -> Int32 {
  self.total_number_baselines
}

///|
/// The score of the baseline that performed best.
pub fn MechanismPerformanceResult::best_baseline_performance(
  self : MechanismPerformanceResult,
) -> Double? {
  self.best_baseline_performance
}

///|
/// The result of the evaluation of the invertibility assumption of one node.
///
/// This is the port of the tuple of the upstream, which holds the p-value of
/// the test, the decision of the test and the significance level of the test.
pub struct InvertibilityAssumption {
  /// The p-value of the test of the independence of the inputs and of the
  /// noise.
  p_value : Double
  /// Whether the assumption was rejected.
  rejected : Bool
  /// The significance level of the test.
  significance_level : Double
}

///|
/// The p-value of the test of the independence of the inputs and of the noise.
pub fn InvertibilityAssumption::p_value(
  self : InvertibilityAssumption,
) -> Double {
  self.p_value
}

///|
/// Whether the assumption was rejected.
pub fn InvertibilityAssumption::rejected(
  self : InvertibilityAssumption,
) -> Bool {
  self.rejected
}

///|
/// The significance level of the test.
pub fn InvertibilityAssumption::significance_level(
  self : InvertibilityAssumption,
) -> Double {
  self.significance_level
}

///|
/// The result of the evaluation of a causal model.
///
/// This is the port of `dowhy.gcm.model_evaluation.CausalModelEvaluationResult`.
pub struct CausalModelEvaluationResult {
  /// The performance of the mechanism of every node, when the mechanisms were
  /// evaluated.
  mechanism_performances : Map[String, MechanismPerformanceResult]?
  /// The result of the test of the invertibility assumption of every node,
  /// when the assumption was evaluated.
  pnl_assumptions : Map[String, InvertibilityAssumption]?
  /// The result of the falsification of the graph, when the graph was
  /// falsified.
  graph_falsification : EvaluationResult?
  /// The average divergence of the generated and of the observed distribution,
  /// when the divergence was estimated.
  overall_kl_divergence : Double?
  /// Whether the histogram of the falsification is plotted. The plotting of the
  /// upstream is not ported, so the flag has no effect.
  plot_falsification_histogram : Bool
}

///|
/// The performance of the mechanism of every node, when the mechanisms were
/// evaluated.
pub fn CausalModelEvaluationResult::mechanism_performances(
  self : CausalModelEvaluationResult,
) -> Map[String, MechanismPerformanceResult]? {
  self.mechanism_performances
}

///|
/// The performance of the mechanism of the given node.
pub fn CausalModelEvaluationResult::mechanism_performance(
  self : CausalModelEvaluationResult,
  node : String,
) -> MechanismPerformanceResult? {
  match self.mechanism_performances {
    Some(performances) => performances.get(node)
    None => None
  }
}

///|
/// The result of the test of the invertibility assumption of every node, when
/// the assumption was evaluated.
pub fn CausalModelEvaluationResult::pnl_assumptions(
  self : CausalModelEvaluationResult,
) -> Map[String, InvertibilityAssumption]? {
  self.pnl_assumptions
}

///|
/// The result of the falsification of the graph, when the graph was falsified.
pub fn CausalModelEvaluationResult::graph_falsification(
  self : CausalModelEvaluationResult,
) -> EvaluationResult? {
  self.graph_falsification
}

///|
/// The average divergence of the generated and of the observed distribution,
/// when the divergence was estimated.
pub fn CausalModelEvaluationResult::overall_kl_divergence(
  self : CausalModelEvaluationResult,
) -> Double? {
  self.overall_kl_divergence
}

///|
/// Whether the histogram of the falsification is plotted.
pub fn CausalModelEvaluationResult::plot_falsification_histogram(
  self : CausalModelEvaluationResult,
) -> Bool {
  self.plot_falsification_histogram
}

///|
/// The report of the evaluation of a causal model.
///
/// This is the port of the `__str__` of
/// `dowhy.gcm.model_evaluation.CausalModelEvaluationResult`. The report names
/// the parts of the model that were evaluated, the performance of every
/// mechanism, the outcome of the test of the invertibility assumption of every
/// node, the divergence of the generated and of the observed distribution and
/// the result of the falsification of the graph.
pub fn CausalModelEvaluationResult::to_string(
  self : CausalModelEvaluationResult,
) -> String {
  let mut summary = "Evaluated"
  let has_mechanisms = match self.mechanism_performances {
    Some(_) => true
    None => false
  }
  if has_mechanisms {
    summary = summary + " the performance of the causal mechanisms"
  }
  let has_assumptions = match self.pnl_assumptions {
    Some(_) => true
    None => false
  }
  if has_assumptions {
    summary = summary +
      " and the invertibility assumption of the causal mechanisms"
  }
  let has_divergence = match self.overall_kl_divergence {
    Some(_) => true
    None => false
  }
  if has_divergence {
    summary = summary +
      " and the overall average KL divergence between generated and observed distribution"
  }
  let has_falsification = match self.graph_falsification {
    Some(_) => true
    None => false
  }
  if has_falsification {
    summary = summary + " and the graph structure"
  }
  summary = summary + ". The results are as follows:"
  let lines : Array[String] = [summary]

  match self.mechanism_performances {
    Some(performances) => {
      lines.push("\n==== Evaluation of Causal Mechanisms ====")
      lines.push(
        "The used evaluation metrics are:\n" +
        "- KL divergence (only for root-nodes): Evaluates the divergence between the generated and the observed distribution.\n" +
        "- Mean Squared Error (MSE): Evaluates the average squared differences between the observed values and the conditional expectation of the causal mechanisms.\n" +
        "- Normalized MSE (NMSE): The MSE normalized by the standard deviation for better comparison.\n" +
        "- R2 coefficient: Indicates how much variance is explained by the conditional expectations of the mechanisms. Note, however, that this can be misleading for nonlinear relationships.\n" +
        "- F1 score (only for categorical non-root nodes): The harmonic mean of the precision and recall indicating the goodness of the underlying classifier model.\n" +
        "- (normalized) Continuous Ranked Probability Score (CRPS): The CRPS generalizes the Mean Absolute Percentage Error to probabilistic predictions. This gives insights into the accuracy and calibration of the causal mechanisms.\n" +
        "NOTE: Every metric focuses on different aspects and they might not consistently indicate a good or bad performance.\n" +
        "We will mostly utilize the CRPS for comparing and interpreting the performance of the mechanisms, since this captures the most important properties for the causal model.",
      )
      for node in performances.keys() {
        let performance = match performances.get(node) {
          Some(value) => value
          None => continue
        }
        lines.push("\n--- Node " + performance.node_name)
        match performance.kl_divergence {
          Some(value) => {
            lines.push(
              "- The KL divergence between generated and observed distribution is " +
              format_double(value) +
              ".",
            )
            lines.push(kl_divergence_interpretation(value))
          }
          None => ()
        }
        match performance.mse {
          Some(value) =>
            lines.push("- The MSE is " + format_double(value) + ".")
          None => ()
        }
        match performance.nmse {
          Some(value) =>
            lines.push("- The NMSE is " + format_double(value) + ".")
          None => ()
        }
        match performance.r2 {
          Some(value) =>
            lines.push("- The R2 coefficient is " + format_double(value) + ".")
          None => ()
        }
        match performance.f1 {
          Some(value) =>
            lines.push("- The F1 score is " + format_double(value) + ".")
          None => ()
        }
        match performance.crps {
          Some(value) => {
            lines.push("- The normalized CRPS is " + format_double(value) + ".")
            lines.push(crps_interpretation(value))
          }
          None => ()
        }
        if performance.total_number_baselines > 0 {
          lines.push(
            baseline_interpretation(
              performance.count_better_performance.unwrap_or(0),
              performance.total_number_baselines,
              performance.best_baseline_model.unwrap_or(""),
              performance.best_baseline_performance.unwrap_or(0.0),
            ),
          )
        }
      }
    }
    None => ()
  }

  match self.pnl_assumptions {
    Some(assumptions) => {
      lines.push(
        "\n==== Evaluation of Invertible Functional Causal Model Assumption ====",
      )
      if assumptions.length() == 0 {
        lines.push("The causal model has no invertible causal models.")
      } else {
        for node in assumptions.keys() {
          let assumption = match assumptions.get(node) {
            Some(value) => value
            None => continue
          }
          let rejected = if assumption.rejected {
            "rejected"
          } else {
            "not rejected"
          }
          lines.push(
            "\n--- The model assumption for node " +
            node +
            " is " +
            rejected +
            " with a p-value of " +
            format_double(assumption.p_value) +
            " (after potential adjustment) and a significance level of " +
            format_double(assumption.significance_level) +
            ".",
          )
          if !assumption.rejected {
            lines.push("This implies that the model assumption might be valid.")
          } else {
            lines.push(
              "This implies that the model assumption might not be valid. This is, " +
              "the relationship cannot be represent with this type of mechanism or " +
              "there is a hidden confounder between the node and its parents.",
            )
          }
        }
        lines.push(
          "\nNote that these results are based on statistical independence tests, and the " +
          "fact that the assumption was not rejected does not necessarily imply that it " +
          "is correct. There is just no evidence against it.",
        )
      }
    }
    None => ()
  }

  match self.overall_kl_divergence {
    Some(value) => {
      lines.push("\n==== Evaluation of Generated Distribution ====")
      lines.push(
        "The overall average KL divergence between the generated and observed distribution is " +
        format_double(value),
      )
      lines.push(kl_divergence_interpretation(value))
    }
    None => ()
  }

  match self.graph_falsification {
    Some(result) => {
      lines.push("\n==== Evaluation of the Causal Graph Structure ====")
      lines.push(result.to_string())
    }
    None => ()
  }

  lines.push("\n==== NOTE ====")
  lines.push(
    "Always double check the made model assumptions with respect to the graph structure and " +
    "choice of causal mechanisms.",
  )
  lines.push(
    "All these evaluations give some insight into the goodness of the causal model, but should not be " +
    "overinterpreted, since some causal relationships can be intrinsically hard to model. Furthermore, many " +
    "algorithms are fairly robust against misspecifications or poor performances of causal mechanisms.",
  )
  let mut out = ""
  for line in lines {
    out = out + line + "\n"
  }
  // The upstream joins the lines with a line break and does not end with one.
  out[0:out.length() - 1].to_owned()
}

///|
/// The normalised mean squared error of the given samples.
///
/// This is the port of `dowhy.gcm.model_evaluation.nmse`. The error is the mean
/// squared error of the samples, which is divided by the standard deviation of
/// the observed values. When the squared error is asked for, the mean squared
/// error is divided by the variance of the observed values instead, and the
/// square root of the mean squared error is not taken.
pub fn nmse(
  y_true : Array[Double],
  y_pred : Array[Double],
  squared : Bool,
) -> Double {
  if y_true.length() != y_pred.length() {
    abort(
      "the observed and the predicted values need to have the same number of rows, but they have " +
      y_true.length().to_string() +
      " and " +
      y_pred.length().to_string() +
      " rows",
    )
  }
  let y_std = @utils.std(y_true)
  let mut error = mean_squared_error(y_true, y_pred)
  if !squared {
    error = error.sqrt()
  }
  if y_std == 0.0 {
    return error
  }
  if squared {
    error / @utils.var_pop(y_true)
  } else {
    error / y_std
  }
}

///|
/// The continuous ranked probability score of the given samples.
///
/// This is the port of `dowhy.gcm.model_evaluation.crps` for the continuous
/// data. The score measures the calibration of a probabilistic prediction: for
/// every row of the inputs the score of the samples of the target is the mean
/// of the distance of the samples to the observed value, less the half of the
/// mean of the distance of the samples to each other.
///
/// The samples of the target are drawn by the given method, which takes the
/// rows of the inputs and the generator and returns the samples of the target.
/// The number of the samples of every row is the given number.
///
/// The target values are divided by their standard deviation when the score is
/// normalised, which makes the scores of the different scales comparable.
pub fn crps(
  x : @utils.Matrix,
  y : Array[Double],
  conditional_sampling : (@utils.Matrix, @utils.Random) -> Array[Double],
  num_conditional_samples : Int32,
  normalize : Bool,
  rng : @utils.Random,
) -> Double {
  if x.nrows() != y.length() {
    abort(
      "the inputs and the observed values need to have the same number of rows, but they have " +
      x.nrows().to_string() +
      " and " +
      y.length().to_string() +
      " rows",
    )
  }
  let mut std_y = 1.0
  if normalize {
    std_y = @utils.std(y)
    if std_y == 0.0 {
      std_y = 1.0
    }
  }
  let values : Array[Double] = []
  for i in 0..<x.nrows() {
    let row = repeated_row(x, i, num_conditional_samples)
    let samples = conditional_sampling(row, rng)
    let scaled : Array[Double] = []
    for sample in samples {
      scaled.push(sample / std_y)
    }
    values.push(empirical_crps(scaled, y[i] / std_y))
  }
  @utils.mean(values)
}

///|
/// The continuous ranked probability score of the given categorical samples.
///
/// This is the port of the categorical case of
/// `dowhy.gcm.model_evaluation.crps`. The score is the mean of the scores of
/// the classes: the score of a class is the score of the indicator of the
/// class in the samples and in the observed value, which is the Brier score of
/// the class.
pub fn crps_categorical(
  x : @utils.Matrix,
  y : Array[String],
  conditional_sampling : (@utils.Matrix, @utils.Random) -> Array[String],
  num_conditional_samples : Int32,
  rng : @utils.Random,
) -> Double {
  if x.nrows() != y.length() {
    abort(
      "the inputs and the observed values need to have the same number of rows, but they have " +
      x.nrows().to_string() +
      " and " +
      y.length().to_string() +
      " rows",
    )
  }
  let classes = distinct_labels(y)
  let values : Array[Double] = []
  for i in 0..<x.nrows() {
    let row = repeated_row(x, i, num_conditional_samples)
    let samples = conditional_sampling(row, rng)
    let per_class : Array[Double] = []
    for class in classes {
      let indicators : Array[Double] = []
      for sample in samples {
        indicators.push(if sample == class { 1.0 } else { 0.0 })
      }
      let observed = if y[i] == class { 1.0 } else { 0.0 }
      per_class.push(empirical_crps(indicators, observed))
    }
    values.push(@utils.mean(per_class))
  }
  @utils.mean(values)
}

///|
/// The conditional expectation of the target for the given parents.
///
/// This is the port of `dowhy.gcm.model_evaluation._estimate_conditional_expectations`
/// for the continuous data. The conditional expectation of a continuous model
/// is the prediction of its model with the noise of zero, which is the branch
/// the upstream takes for every continuous model: the additive noise model of
/// the upstream is a post non-linear model, whose function is the identity.
///
/// The upstream has a branch that averages the samples of the models that are
/// neither post non-linear nor classifiers, but the upstream has no such model.
pub fn estimate_conditional_expectations(
  causal_mechanism : CausalMechanism,
  parent_samples : @utils.Matrix,
) -> Array[Double] {
  if is_classifier_kind(causal_mechanism.kind()) {
    abort("a classifier mechanism has no continuous conditional expectation")
  }
  let noise : Array[Double] = []
  for _ in 0..<parent_samples.nrows() {
    noise.push(0.0)
  }
  causal_mechanism.evaluate(parent_samples, noise)
}

///|
/// The conditional class of the target for the given parents.
///
/// This is the port of the categorical case of
/// `dowhy.gcm.model_evaluation._estimate_conditional_expectations`. The
/// conditional class of a categorical model is the class its classifier
/// predicts.
pub fn estimate_conditional_expectations_categorical(
  causal_mechanism : CausalMechanism,
  parent_samples : @utils.Matrix,
) -> Array[String] {
  if !is_classifier_kind(causal_mechanism.kind()) {
    abort("a continuous mechanism has no conditional class")
  }
  causal_mechanism.classifier_model().predict(parent_samples)
}

///|
/// The result of the test of the invertibility assumption of every node.
///
/// This is the port of
/// `dowhy.gcm.model_evaluation._evaluate_invertibility_assumptions`. The test
/// of a node checks the independence of the noise of its mechanism and of its
/// parents, which is the assumption of the invertible functional causal model.
///
/// The test runs on a subset of the samples, and the p-values of the runs are
/// merged with the false discovery rate control of the package. The p-values of
/// the nodes are then adjusted with the control of the false discovery rate of
/// the configuration, when it has one.
pub fn evaluate_invertibility_assumptions(
  causal_model : ProbabilisticCausalModel,
  data : @api.DataFrame,
  config : EvaluationConfig,
  rng : @utils.Random,
) -> Map[String, InvertibilityAssumption] {
  let all_p_values : Map[String, Double] = Map([])
  let mut runs = config.bootstrap_runs_invertible
  let max_num_samples_per_run = 2000
  if max_num_samples_per_run >= data.nrows() {
    runs = 1
  }
  let limit = if max_num_samples_per_run < data.nrows() {
    max_num_samples_per_run
  } else {
    data.nrows()
  }
  for node in causal_model.graph.node_list() {
    if is_root_node(causal_model, node) {
      continue
    }
    let mechanism = match causal_model.causal_mechanism(node) {
      Some(value) => value
      None =>
        abort(
          "the node " +
          node +
          " has parents and needs a causal mechanism, but it has none",
        )
    }
    if is_classifier_kind(mechanism.kind()) {
      // A categorical model has no invertible functional causal model.
      continue
    }
    let parents = evaluation_parents(causal_model.graph, node)
    let parent_samples = data.design_matrix(parents)
    let target_samples = data.numeric(node)
    let p_values : Array[Double] = []
    for _ in 0..<runs {
      let indices = sample_without_replacement(data.nrows(), limit, rng)
      let noise = mechanism.estimate_noise(
        select_values(target_samples, indices),
        evaluation_rows(parent_samples, indices),
      )
      p_values.push(
        (config.independence_test_invertible)(
          @utils.Matrix::from_columns([noise]),
          evaluation_rows(parent_samples, indices),
          None,
        ),
      )
    }
    all_p_values.set(node, merge_p_values_fdr(p_values))
  }
  let adjusted = adjust_p_values(all_p_values, config)
  adjusted
}

///|
/// The performance of the causal mechanism of every node of the model.
///
/// This is the port of
/// `dowhy.gcm.model_evaluation._evaluate_model_performances`. The mechanisms
/// are fitted from scratch in the folds of a cross validation, and the metrics
/// of every fold are averaged.
///
/// The root nodes are measured by the divergence between the generated and the
/// observed distribution, and the nodes with parents are measured by the score
/// of the continuous ranked probability score, by the error of the conditional
/// expectation and by the score of the classifier.
///
/// The baselines are compared with the mechanism when the caller asks for it.
/// A baseline that performs significantly better is a baseline whose score is
/// more than 0.05 below the score of the mechanism.
pub fn evaluate_model_performances(
  causal_model : ProbabilisticCausalModel,
  data : @api.DataFrame,
  compare_mechanism_baselines : Bool,
  config : EvaluationConfig,
  rng : @utils.Random,
) -> Map[String, MechanismPerformanceResult] {
  let performances : Map[String, MechanismPerformanceResult] = Map([])
  for node in causal_model.graph.topological_order() {
    if is_root_node(causal_model, node) {
      performances.set(
        node,
        evaluate_root_performance(causal_model, data, node, config, rng),
      )
    } else if data.is_discrete(node) {
      performances.set(
        node,
        evaluate_categorical_performance(
          causal_model, data, node, compare_mechanism_baselines, config, rng,
        ),
      )
    } else {
      performances.set(
        node,
        evaluate_continuous_performance(
          causal_model, data, node, compare_mechanism_baselines, config, rng,
        ),
      )
    }
  }
  performances
}

///|
/// The performance of the mechanism of a root node.
///
/// The root nodes are measured by the divergence between the generated and the
/// observed distribution, which is the only metric of the upstream for them.
fn evaluate_root_performance(
  causal_model : ProbabilisticCausalModel,
  data : @api.DataFrame,
  node : String,
  config : EvaluationConfig,
  rng : @utils.Random,
) -> MechanismPerformanceResult {
  let kl_divergences : Array[Double] = []
  let root_model = match causal_model.root_model(node) {
    Some(value) => value
    None =>
      abort(
        "the node " +
        node +
        " is a root and needs a distribution, but it has none",
      )
  }
  if data.is_discrete(node) {
    let labels = data.discrete(node)
    let folds = k_folds_split(
      labels.length(),
      config.mechanism_evaluation_kfolds,
      rng,
    )
    for fold in folds {
      let (training, testing) = fold
      let fitted = root_model.fit_categorical(select_labels(labels, training))
      let samples = fitted.draw_category_samples(testing.length(), rng)
      kl_divergences.push(
        estimate_kl_divergence_categorical(
          @utils.Matrix::from_columns([encode_labels(samples)]),
          @utils.Matrix::from_columns([
            encode_labels(select_labels(labels, testing)),
          ]),
        ),
      )
    }
  } else {
    let values = data.numeric(node)
    let folds = k_folds_split(
      values.length(),
      config.mechanism_evaluation_kfolds,
      rng,
    )
    for fold in folds {
      let (training, testing) = fold
      let fitted = root_model.fit(select_values(values, training))
      let samples = fitted.draw_samples(testing.length(), rng)
      kl_divergences.push(
        auto_estimate_kl_divergence(
          @utils.Matrix::from_columns([samples]),
          @utils.Matrix::from_columns([select_values(values, testing)]),
          rng,
        ),
      )
    }
  }
  {
    node_name: node,
    is_root: true,
    crps: None,
    kl_divergence: mean_or_none(kl_divergences),
    mse: None,
    nmse: None,
    r2: None,
    f1: None,
    count_better_performance: None,
    best_baseline_model: None,
    total_number_baselines: 0,
    best_baseline_performance: None,
  }
}

///|
/// The performance of the mechanism of a node with parents and a continuous
/// target.
fn evaluate_continuous_performance(
  causal_model : ProbabilisticCausalModel,
  data : @api.DataFrame,
  node : String,
  compare_mechanism_baselines : Bool,
  config : EvaluationConfig,
  rng : @utils.Random,
) -> MechanismPerformanceResult {
  let parents = evaluation_parents(causal_model.graph, node)
  let parent_data = data.design_matrix(parents)
  let node_data = data.numeric(node)
  let mechanism = match causal_model.causal_mechanism(node) {
    Some(value) => value
    None =>
      abort(
        "the node " +
        node +
        " has parents and needs a causal mechanism, but it has none",
      )
  }
  let crps_values : Array[Double] = []
  let mses : Array[Double] = []
  let nmses : Array[Double] = []
  let r2s : Array[Double] = []
  let baseline_scores : Map[String, Array[Double]] = Map([])
  let folds = k_folds_split(
    parent_data.nrows(),
    config.mechanism_evaluation_kfolds,
    rng,
  )
  for fold in folds {
    let (training, testing) = fold
    let training_parents = evaluation_rows(parent_data, training)
    let training_target = select_values(node_data, training)
    let testing_parents = evaluation_rows(parent_data, testing)
    let testing_target = select_values(node_data, testing)
    let fitted = mechanism.clone().fit(training_parents, training_target)
    crps_values.push(
      crps(
        testing_parents,
        testing_target,
        fn(inputs : @utils.Matrix, generator : @utils.Random) {
          fitted.draw_samples(inputs, generator)
        },
        100,
        true,
        rng,
      ),
    )
    let predictions = estimate_conditional_expectations(fitted, testing_parents)
    mses.push(mean_squared_error(testing_target, predictions))
    nmses.push(nmse(testing_target, predictions, false))
    r2s.push(r2_score(testing_target, predictions))
    if !compare_mechanism_baselines {
      continue
    }
    for baseline in config.baseline_models_regression {
      let (name, factory) = baseline
      let fitted_baseline = CausalMechanism::additive_noise(factory()).fit(
        training_parents, training_target,
      )
      let score = crps(
        testing_parents,
        testing_target,
        fn(inputs : @utils.Matrix, generator : @utils.Random) {
          fitted_baseline.draw_samples(inputs, generator)
        },
        100,
        true,
        rng,
      )
      match baseline_scores.get(name) {
        Some(scores) => scores.push(score)
        None => baseline_scores.set(name, [score])
      }
    }
  }
  let mechanism_score = mean_or_none(crps_values)
  let baselines = summarise_baselines(
    mechanism_score, baseline_scores, compare_mechanism_baselines,
  )
  {
    node_name: node,
    is_root: false,
    crps: mechanism_score,
    kl_divergence: None,
    mse: mean_or_none(mses),
    nmse: mean_or_none(nmses),
    r2: mean_or_none(r2s),
    f1: None,
    count_better_performance: baselines.count_better_performance,
    best_baseline_model: baselines.best_baseline_model,
    total_number_baselines: baselines.total_number_baselines,
    best_baseline_performance: baselines.best_baseline_performance,
  }
}

///|
/// The performance of the mechanism of a node with parents and a categorical
/// target.
fn evaluate_categorical_performance(
  causal_model : ProbabilisticCausalModel,
  data : @api.DataFrame,
  node : String,
  compare_mechanism_baselines : Bool,
  config : EvaluationConfig,
  rng : @utils.Random,
) -> MechanismPerformanceResult {
  let parents = evaluation_parents(causal_model.graph, node)
  let parent_data = data.design_matrix(parents)
  let node_data = data.discrete(node)
  let mechanism = match causal_model.causal_mechanism(node) {
    Some(value) => value
    None =>
      abort(
        "the node " +
        node +
        " has parents and needs a causal mechanism, but it has none",
      )
  }
  let crps_values : Array[Double] = []
  let f1s : Array[Double] = []
  let baseline_scores : Map[String, Array[Double]] = Map([])
  let folds = k_folds_split(
    parent_data.nrows(),
    config.mechanism_evaluation_kfolds,
    rng,
  )
  for fold in folds {
    let (training, testing) = fold
    let training_parents = evaluation_rows(parent_data, training)
    let training_target = select_labels(node_data, training)
    let testing_parents = evaluation_rows(parent_data, testing)
    let testing_target = select_labels(node_data, testing)
    let fitted = mechanism
      .clone()
      .fit_categorical(training_parents, training_target)
    crps_values.push(
      crps_categorical(
        testing_parents,
        testing_target,
        fn(inputs : @utils.Matrix, generator : @utils.Random) {
          fitted.draw_categorical_samples(inputs, generator)
        },
        100,
        rng,
      ),
    )
    let predictions = estimate_conditional_expectations_categorical(
      fitted, testing_parents,
    )
    f1s.push(f1_score(testing_target, predictions))
    if !compare_mechanism_baselines {
      continue
    }
    for baseline in config.baseline_models_classification {
      let (name, factory) = baseline
      let fitted_baseline = CausalMechanism::classifier(factory()).fit_categorical(
        training_parents, training_target,
      )
      let score = crps_categorical(
        testing_parents,
        testing_target,
        fn(inputs : @utils.Matrix, generator : @utils.Random) {
          fitted_baseline.draw_categorical_samples(inputs, generator)
        },
        100,
        rng,
      )
      match baseline_scores.get(name) {
        Some(scores) => scores.push(score)
        None => baseline_scores.set(name, [score])
      }
    }
  }
  let mechanism_score = mean_or_none(crps_values)
  let baselines = summarise_baselines(
    mechanism_score, baseline_scores, compare_mechanism_baselines,
  )
  {
    node_name: node,
    is_root: false,
    crps: mechanism_score,
    kl_divergence: None,
    mse: None,
    nmse: None,
    r2: None,
    f1: mean_or_none(f1s),
    count_better_performance: baselines.count_better_performance,
    best_baseline_model: baselines.best_baseline_model,
    total_number_baselines: baselines.total_number_baselines,
    best_baseline_performance: baselines.best_baseline_performance,
  }
}

///|
/// The comparison of the mechanism with the baselines.
priv struct BaselineSummary {
  count_better_performance : Int32?
  best_baseline_model : String?
  total_number_baselines : Int32
  best_baseline_performance : Double?
}

///|
/// The comparison of the mechanism with the baselines.
///
/// A baseline that performed significantly better is a baseline whose score is
/// more than 0.05 below the score of the mechanism.
fn summarise_baselines(
  mechanism_score : Double?,
  baseline_scores : Map[String, Array[Double]],
  compare_mechanism_baselines : Bool,
) -> BaselineSummary {
  let mut count_better_performance : Int32? = None
  let mut best_baseline_model : String? = None
  let mut best_baseline_performance : Double? = None
  let mut total_number_baselines = 0
  if compare_mechanism_baselines {
    count_better_performance = Some(0)
    for name in baseline_scores.keys() {
      total_number_baselines = total_number_baselines + 1
      let score = match baseline_scores.get(name) {
        Some(scores) => @utils.mean(scores)
        None => 0.0
      }
      if mechanism_score.unwrap_or(0.0) - score > 0.05 {
        count_better_performance = Some(
          count_better_performance.unwrap_or(0) + 1,
        )
      }
      match best_baseline_performance {
        None => {
          best_baseline_model = Some(name)
          best_baseline_performance = Some(score)
        }
        Some(best) =>
          if score < best {
            best_baseline_model = Some(name)
            best_baseline_performance = Some(score)
          }
      }
    }
  }
  {
    count_better_performance,
    best_baseline_model,
    total_number_baselines,
    best_baseline_performance,
  }
}

///|
/// Evaluate a causal model with the given data.
///
/// This is the port of `dowhy.gcm.model_evaluation.evaluate_causal_model`. The
/// evaluation runs the four evaluations of the module: the performance of the
/// causal mechanisms, the assumption of the invertible functional causal model,
/// the divergence of the generated and of the observed distribution and the
/// structure of the graph of the model.
pub fn evaluate_causal_model(
  causal_model : ProbabilisticCausalModel,
  data : @api.DataFrame,
  config : EvaluationConfig,
  options : EvaluationOptions,
  rng : @utils.Random,
) -> CausalModelEvaluationResult {
  let mechanism_performances = if options.evaluate_causal_mechanisms {
    Some(
      evaluate_model_performances(
        causal_model,
        data,
        options.compare_mechanism_baselines,
        config,
        rng,
      ),
    )
  } else {
    None
  }
  let pnl_assumptions = if options.evaluate_invertibility_assumptions {
    Some(evaluate_invertibility_assumptions(causal_model, data, config, rng))
  } else {
    None
  }
  let overall_kl_divergence = if options.evaluate_overall_kl_divergence {
    Some(overall_kl_divergence(causal_model, data, rng))
  } else {
    None
  }
  let graph_falsification = if options.evaluate_causal_structure {
    for node in causal_model.graph.node_list() {
      if data.is_discrete(node) {
        abort(
          "the falsification of the graph needs the numeric data of every node of the graph, but the column " +
          node +
          " holds strings",
        )
      }
    }
    Some(
      falsify_graph(
        causal_model.graph,
        data,
        config.independence_test_falsify,
        config.conditional_independence_test_falsify,
        config.falsify_graph_significance_level,
        0.05,
        config.max_num_permutations_falsify,
        false,
        rng,
        false,
      ),
    )
  } else {
    None
  }
  {
    mechanism_performances,
    pnl_assumptions,
    graph_falsification,
    overall_kl_divergence,
    plot_falsification_histogram: true,
  }
}

///|
/// The average divergence of the generated and of the observed distribution.
///
/// This is the port of the divergence of
/// `dowhy.gcm.model_evaluation.evaluate_causal_model`. The divergence is the
/// average of the divergences of the nodes, because the divergence of the
/// whole distribution cannot be estimated with a sample of a high dimension.
fn overall_kl_divergence(
  causal_model : ProbabilisticCausalModel,
  data : @api.DataFrame,
  rng : @utils.Random,
) -> Double {
  let drawn = draw_samples(causal_model, data.nrows(), rng)
  let values : Array[Double] = []
  for node in causal_model.graph.node_list() {
    if data.is_discrete(node) {
      values.push(
        estimate_kl_divergence_categorical(
          @utils.Matrix::from_columns([encode_labels(data.discrete(node))]),
          @utils.Matrix::from_columns([encode_labels(drawn.discrete(node))]),
        ),
      )
    } else {
      values.push(
        auto_estimate_kl_divergence(
          @utils.Matrix::from_columns([drawn.numeric(node)]),
          @utils.Matrix::from_columns([data.numeric(node)]),
          rng,
        ),
      )
    }
  }
  @utils.mean(values)
}

///|
/// The kernel based independence test, for the tests that need a generator.
///
/// This is the counterpart of the `partial(kernel_based, use_bootstrap=False)`
/// of the upstream, which the upstream uses as the test of the invertibility
/// assumption and of the falsification of the graph. The test of the port draws
/// the randomness of the median trick of the width of the kernel from the given
/// generator.
pub fn kernel_independence_test(
  rng : @utils.Random,
  max_num_samples_run : Int32,
) -> IndependenceTest {
  fn(x : @utils.Matrix, y : @utils.Matrix, z : @utils.Matrix?) -> Double {
    kernel_based(
      x, y, z, false, 1, max_num_samples_run, merge_p_values_fdr, rng,
    )
  }
}

///|
/// The mean of the given values, when there are any.
fn mean_or_none(values : Array[Double]) -> Double? {
  if values.length() == 0 {
    None
  } else {
    Some(@utils.mean(values))
  }
}

///|
/// The p-values of the nodes after the control of the false discovery rate.
fn adjust_p_values(
  all_p_values : Map[String, Double],
  config : EvaluationConfig,
) -> Map[String, InvertibilityAssumption] {
  let assumptions : Map[String, InvertibilityAssumption] = Map([])
  if all_p_values.length() == 0 {
    return assumptions
  }
  let nodes : Array[String] = []
  let p_values : Array[Double] = []
  for node in all_p_values.keys() {
    nodes.push(node)
    p_values.push(
      match all_p_values.get(node) {
        Some(value) => value
        None => 1.0
      },
    )
  }
  match config.fdr_control_method_invertible {
    Some(fdr_method) => {
      let control = match fdr_method {
        FdrBh => fdr_bh_adjust(p_values, config.significance_level_invertible)
        FdrBonferroni =>
          fdr_bonferroni_adjust(p_values, config.significance_level_invertible)
      }
      let rejections = control.reject()
      let adjusted_p_values = control.adjusted_p_values()
      for i in 0..<nodes.length() {
        assumptions.set(nodes[i], {
          p_value: adjusted_p_values[i],
          rejected: rejections[i],
          significance_level: config.significance_level_invertible,
        })
      }
    }
    None =>
      for i in 0..<nodes.length() {
        assumptions.set(nodes[i], {
          p_value: p_values[i],
          rejected: p_values[i] < config.significance_level_invertible,
          significance_level: config.significance_level_invertible,
        })
      }
  }
  assumptions
}

///|
/// The parents of a node, in the order the upstream uses.
///
/// The helper sorts the parents of a node by their name, like the helper of
/// the validation layer of the package does.
fn evaluation_parents(
  causal_graph : @graph.DirectedGraph,
  node : String,
) -> Array[String] {
  let parents = causal_graph.predecessors(node)
  parents.sort_by(fn(a, b) { a.lexical_compare(b) })
  parents
}

///|
/// The mean squared error of the given samples.
fn mean_squared_error(y_true : Array[Double], y_pred : Array[Double]) -> Double {
  if y_true.length() != y_pred.length() {
    abort(
      "the observed and the predicted values need to have the same number of rows, but they have " +
      y_true.length().to_string() +
      " and " +
      y_pred.length().to_string() +
      " rows",
    )
  }
  if y_true.length() == 0 {
    return 0.0
  }
  let mut total = 0.0
  for i in 0..<y_true.length() {
    let difference = y_true[i] - y_pred[i]
    total = total + difference * difference
  }
  total / y_true.length().to_double()
}

///|
/// The coefficient of the determination of the given samples.
///
/// This is the port of the `r2_score` of scikit-learn. The coefficient is one
/// less the quotient of the sum of the squares of the errors and the sum of the
/// squares of the deviations of the observed values from their mean.
fn r2_score(y_true : Array[Double], y_pred : Array[Double]) -> Double {
  if y_true.length() != y_pred.length() {
    abort(
      "the observed and the predicted values need to have the same number of rows, but they have " +
      y_true.length().to_string() +
      " and " +
      y_pred.length().to_string() +
      " rows",
    )
  }
  if y_true.length() == 0 {
    return 0.0
  }
  let mean = @utils.mean(y_true)
  let mut residual = 0.0
  let mut total = 0.0
  for i in 0..<y_true.length() {
    let difference = y_true[i] - y_pred[i]
    residual = residual + difference * difference
    let deviation = y_true[i] - mean
    total = total + deviation * deviation
  }
  if total == 0.0 {
    if residual == 0.0 {
      return 1.0
    }
    return 0.0
  }
  1.0 - residual / total
}

///|
/// The F1 measure of the given labels.
///
/// This is the port of the `f1_score` of scikit-learn with the average of the
/// macro kind and with a zero division of zero. The measure is the mean of the
/// measures of the classes, which are the labels of the observed and of the
/// predicted values together.
fn f1_score(y_true : Array[String], y_pred : Array[String]) -> Double {
  if y_true.length() != y_pred.length() {
    abort(
      "the observed and the predicted labels need to have the same number of rows, but they have " +
      y_true.length().to_string() +
      " and " +
      y_pred.length().to_string() +
      " rows",
    )
  }
  let classes = distinct_labels(y_true)
  for label in y_pred {
    if !classes.contains(label) {
      classes.push(label)
    }
  }
  if classes.length() == 0 {
    return 0.0
  }
  let scores : Array[Double] = []
  for class in classes {
    let mut true_positives = 0.0
    let mut predicted = 0.0
    let mut observed = 0.0
    for i in 0..<y_true.length() {
      let is_observed = y_true[i] == class
      let is_predicted = y_pred[i] == class
      if is_observed {
        observed = observed + 1.0
      }
      if is_predicted {
        predicted = predicted + 1.0
      }
      if is_observed && is_predicted {
        true_positives = true_positives + 1.0
      }
    }
    let precision = if predicted == 0.0 {
      0.0
    } else {
      true_positives / predicted
    }
    let recall = if observed == 0.0 { 0.0 } else { true_positives / observed }
    let denominator = precision + recall
    if denominator == 0.0 {
      scores.push(0.0)
    } else {
      scores.push(2.0 * precision * recall / denominator)
    }
  }
  @utils.mean(scores)
}

///|
/// The continuous ranked probability score of the given samples and of the
/// observed value.
///
/// This is the port of the `empirical_crps` of the upstream, which estimates
/// the integral of the squared difference of the distribution function and of
/// the indicator of the observed value.
fn empirical_crps(generated : Array[Double], observed : Double) -> Double {
  if generated.length() == 0 {
    return 0.0
  }
  let mut distance = 0.0
  for value in generated {
    distance = distance + (value - observed).abs()
  }
  distance = distance / generated.length().to_double()
  let mut spread = 0.0
  for a in generated {
    for b in generated {
      spread = spread + (a - b).abs()
    }
  }
  spread = spread / (generated.length() * generated.length()).to_double()
  distance - 0.5 * spread
}

///|
/// The row of the matrix, repeated the given number of times.
fn repeated_row(x : @utils.Matrix, row : Int32, count : Int32) -> @utils.Matrix {
  let values = x.row(row)
  let rows : Array[Array[Double]] = []
  for _ in 0..<count {
    rows.push(values.copy())
  }
  @utils.Matrix::from_rows(rows)
}

///|
/// The values of the given indices.
fn select_values(
  values : Array[Double],
  indices : Array[Int32],
) -> Array[Double] {
  let out : Array[Double] = []
  for index in indices {
    out.push(values[index])
  }
  out
}

///|
/// The labels of the given indices.
fn select_labels(
  values : Array[String],
  indices : Array[Int32],
) -> Array[String] {
  let out : Array[String] = []
  for index in indices {
    out.push(values[index])
  }
  out
}

///|
/// The rows of the matrix with the given indices.
fn evaluation_rows(x : @utils.Matrix, indices : Array[Int32]) -> @utils.Matrix {
  let rows : Array[Array[Double]] = []
  for index in indices {
    rows.push(x.row(index))
  }
  @utils.Matrix::from_rows(rows)
}

///|
/// The labels of the given values, in lexicographic order.
fn distinct_labels(values : Array[String]) -> Array[String] {
  let distinct : Array[String] = []
  for value in values {
    if !distinct.contains(value) {
      distinct.push(value)
    }
  }
  distinct.sort_by(fn(a, b) { a.lexical_compare(b) })
  distinct
}

///|
/// The labels of the given values, encoded as numbers.
fn encode_labels(values : Array[String]) -> Array[Double] {
  let classes = distinct_labels(values)
  let out : Array[Double] = []
  for value in values {
    let mut index = 0
    for i in 0..<classes.length() {
      if classes[i] == value {
        index = i
      }
    }
    out.push(index.to_double())
  }
  out
}

///|
/// The given number of the indices of the rows, without a replacement.
fn sample_without_replacement(
  n : Int32,
  count : Int32,
  rng : @utils.Random,
) -> Array[Int32] {
  let order = random_permutation(rng, n)
  let out : Array[Int32] = []
  let limit = if count < order.length() { count } else { order.length() }
  for i in 0..<limit {
    out.push(order[i])
  }
  out
}

///|
/// The report of the divergence of the generated and of the observed
/// distribution.
///
/// This is the port of
/// `dowhy.gcm.model_evaluation._get_kl_divergence_interpretation_string`.
fn kl_divergence_interpretation(kl_divergence : Double) -> String {
  if kl_divergence < 0.5 {
    "The estimated KL divergence indicates an overall very good representation of the data distribution."
  } else if kl_divergence < 1.0 {
    "The estimated KL divergence indicates a good representation of the data distribution, but might indicate some smaller mismatches between the distributions."
  } else if kl_divergence < 1.5 {
    "The estimated KL divergence indicates some mismatches between the distributions."
  } else if kl_divergence < 3.0 {
    "The estimated KL divergence indicates some significant mismatches between the distributions."
  } else {
    "The estimated KL divergence indicates a significant mismatches between the distributions. Consider using models that better fit the distribution. However, also note that regardless of the model choice, intrinsically weak connections or very small signal to noise ratios will always lead to a poor fit."
  }
}

///|
/// The report of the score of the continuous ranked probability score.
///
/// This is the port of
/// `dowhy.gcm.model_evaluation._get_crps_interpretation_string`.
fn crps_interpretation(crps : Double) -> String {
  if crps < 0.2 {
    "The estimated CRPS indicates a very good model performance."
  } else if crps < 0.35 {
    "The estimated CRPS indicates a good model performance."
  } else if crps < 0.65 {
    "The estimated CRPS indicates only a fair model performance. Note, however, that a high CRPS could also result from a small signal to noise ratio."
  } else if crps < 0.9 {
    "The estimated CRPS indicates a rather poor model performance. Note, however, that a high CRPS could also result from a very small signal to noise ratio."
  } else if crps < 1.0 {
    "The estimated CRPS indicates a bad model performance. Consider trying alternative causal mechanism types. Note, however, that a high CRPS could also result from a very small signal to noise ratio."
  } else {
    "The estimated CRPS indicates a very bad model performance. Consider trying alternative causal mechanism types."
  }
}

///|
/// The report of the comparison of the mechanism with the baselines.
///
/// This is the port of
/// `dowhy.gcm.model_evaluation._get_baseline_model_interpretation_string`.
fn baseline_interpretation(
  count_better : Int32,
  count_total : Int32,
  best_baseline_model : String,
  best_baseline_performance : Double,
) -> String {
  let percentage_better = count_better.to_double() / count_total.to_double()
  if percentage_better == 0.0 {
    "The mechanism is better or equally good than all " +
    count_total.to_string() +
    " baseline mechanisms."
  } else if percentage_better < 0.2 {
    count_better.to_string() +
    " of " +
    count_total.to_string() +
    " baseline mechanisms performed significantly better. The best baseline mechanism is: " +
    best_baseline_model +
    " with a CRPS of " +
    format_double(best_baseline_performance) +
    "."
  } else if percentage_better < 0.4 {
    count_better.to_string() +
    " of " +
    count_total.to_string() +
    " baseline mechanisms performed significantly better. The best baseline mechanism is: " +
    best_baseline_model +
    " with a CRPS of " +
    format_double(best_baseline_performance) +
    "."
  } else if percentage_better < 0.6 {
    count_better.to_string() +
    " of " +
    count_total.to_string() +
    " baseline mechanisms performed significantly better. The best baseline mechanism is: " +
    best_baseline_model +
    " with a CRPS of " +
    format_double(best_baseline_performance) +
    "."
  } else if percentage_better < 0.8 {
    count_better.to_string() +
    " of " +
    count_total.to_string() +
    " baseline mechanisms performed significantly better. The best baseline mechanism is: " +
    best_baseline_model +
    " with a CRPS of " +
    format_double(best_baseline_performance) +
    "."
  } else {
    count_better.to_string() +
    " of " +
    count_total.to_string() +
    " baseline mechanisms performed significantly better. The best baseline mechanism is: " +
    best_baseline_model +
    " with a CRPS of " +
    format_double(best_baseline_performance) +
    "."
  }
}

///|
/// The text of a number of the report.
///
/// The upstream writes the numbers of its report with the `%s` of Python,
/// which is the shortest text that reads the number back. The port writes the
/// numbers with the same number of the significant digits.
fn format_double(value : Double) -> String {
  let text = value.to_string()
  text
}
