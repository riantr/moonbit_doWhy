/// The multiply-robust causal change attribution.
///
/// This is the port of `dowhy.gcm.distribution_change_robust`, the estimator of
/// the paper "Multiply-Robust Causal Change Attribution" of Quintas-Martinez,
/// Bahadori, Santiago, Mu, Janzing and Heckerman (ICML 2024).
///
/// The estimator attributes the change of a functional of the target -- its
/// mean or its variance -- to the variables upstream of it.  The attribution
/// is the Shapley value of a set function that fixes the distribution of a
/// group of the variables to the one of the old data or to the one of the new
/// data.  The set function is estimated with the multiply-robust method: the
/// estimate of the regression and the estimate of the re-weighting are
/// combined, so the estimate is consistent when either of the two models is
/// correct.
///
/// The upstream can calibrate the probabilities of the classifier on a
/// calibration set and can weight the samples; the port has neither, so the
/// port does not take a calibrator and no sample weights.

///|
/// The functional of the target the change is attributed.
pub enum TargetFunctional {
  /// The mean of the target.
  Mean
  /// The variance of the target.
  Variance
}

///|
/// The mean of the target.
pub fn TargetFunctional::mean() -> TargetFunctional {
  Mean
}

///|
/// The variance of the target.
pub fn TargetFunctional::variance() -> TargetFunctional {
  Variance
}

///|
/// The method of the estimator of the change.
pub enum ChangeMethod {
  /// The regression method, which fits the mechanisms of the variables.
  Regression
  /// The re-weighting method, which weighs the samples of the two data sets.
  Reweighting
  /// The multiply-robust method, which combines the two.
  MultiplyRobust
}

///|
/// The regression method.
pub fn ChangeMethod::regression() -> ChangeMethod {
  Regression
}

///|
/// The re-weighting method.
pub fn ChangeMethod::reweighting() -> ChangeMethod {
  Reweighting
}

///|
/// The multiply-robust method.
pub fn ChangeMethod::multiply_robust() -> ChangeMethod {
  MultiplyRobust
}

///|
/// The moment of the target the estimator of the change works with.
pub enum TargetMoment {
  /// The target itself, which is the first moment.
  First
  /// The square of the target, which is the second moment.
  Second
}

///|
/// The first moment of the target.
pub fn TargetMoment::first() -> TargetMoment {
  First
}

///|
/// The second moment of the target.
pub fn TargetMoment::second() -> TargetMoment {
  Second
}

///|
/// The configuration of the multiply-robust causal change attribution.
pub struct DistributionChangeRobustConfig {
  /// The functional of the target the change is attributed.
  target_functional : TargetFunctional
  /// Whether the nuisance parameters are fitted with cross-fitting.
  xfit : Bool
  /// The number of the folds of the cross-fitting.
  xfit_folds : Int32
  /// The share of the observations of the training set, when the cross-fitting
  /// is not used.
  train_size : Double
  /// The seed of the split of the data.
  split_random_state : Int32
  /// The method of the estimator.
  change_method : ChangeMethod
  /// Whether all the explanatory variables are independent.
  all_indep : Bool
  /// The lower and the upper bound of the predicted probabilities.
  crop : Double
  /// The configuration of the Shapley estimator.
  shapley_config : ShapleyConfig
}

///|
/// The configuration with the defaults of the upstream.
///
/// The upstream cross-fits the nuisance parameters with five folds, splits the
/// data with the seed zero, uses the multiply-robust method and trims the
/// predicted probabilities at a thousandth.
pub fn DistributionChangeRobustConfig::new() -> DistributionChangeRobustConfig {
  {
    target_functional: TargetFunctional::Mean,
    xfit: true,
    xfit_folds: 5,
    train_size: 0.5,
    split_random_state: 0,
    change_method: ChangeMethod::MultiplyRobust,
    all_indep: false,
    crop: 1.0e-3,
    shapley_config: ShapleyConfig::new(ShapleyApproximationMethod::auto()),
  }
}

///|
/// The functional of the target the change is attributed.
pub fn DistributionChangeRobustConfig::with_target_functional(
  self : DistributionChangeRobustConfig,
  functional : TargetFunctional,
) -> DistributionChangeRobustConfig {
  {
    target_functional: functional,
    xfit: self.xfit,
    xfit_folds: self.xfit_folds,
    train_size: self.train_size,
    split_random_state: self.split_random_state,
    change_method: self.change_method,
    all_indep: self.all_indep,
    crop: self.crop,
    shapley_config: self.shapley_config,
  }
}

///|
/// The method of the estimator of the change.
pub fn DistributionChangeRobustConfig::with_method(
  self : DistributionChangeRobustConfig,
  change_method : ChangeMethod,
) -> DistributionChangeRobustConfig {
  {
    target_functional: self.target_functional,
    xfit: self.xfit,
    xfit_folds: self.xfit_folds,
    train_size: self.train_size,
    split_random_state: self.split_random_state,
    change_method,
    all_indep: self.all_indep,
    crop: self.crop,
    shapley_config: self.shapley_config,
  }
}

///|
/// The number of the folds of the cross-fitting.
pub fn DistributionChangeRobustConfig::with_xfit_folds(
  self : DistributionChangeRobustConfig,
  folds : Int32,
) -> DistributionChangeRobustConfig {
  {
    target_functional: self.target_functional,
    xfit: self.xfit,
    xfit_folds: folds,
    train_size: self.train_size,
    split_random_state: self.split_random_state,
    change_method: self.change_method,
    all_indep: self.all_indep,
    crop: self.crop,
    shapley_config: self.shapley_config,
  }
}

///|
/// The configuration of the Shapley estimator.
pub fn DistributionChangeRobustConfig::with_shapley_config(
  self : DistributionChangeRobustConfig,
  config : ShapleyConfig,
) -> DistributionChangeRobustConfig {
  {
    target_functional: self.target_functional,
    xfit: self.xfit,
    xfit_folds: self.xfit_folds,
    train_size: self.train_size,
    split_random_state: self.split_random_state,
    change_method: self.change_method,
    all_indep: self.all_indep,
    crop: self.crop,
    shapley_config: config,
  }
}

///|
/// The change of the functional of the target, attributed to the variables
/// upstream of it.
///
/// This is the port of `dowhy.gcm.distribution_change_robust.distribution_change_robust`.
/// The variables of the graph that have a path to the target are the players
/// of the Shapley estimator, and the target is the last one.  The nuisance
/// parameters are fitted with the cross-fitting, and the attribution is the
/// average of the Shapley values of the folds.
pub fn distribution_change_robust(
  causal_model : ProbabilisticCausalModel,
  old_data : @api.DataFrame,
  new_data : @api.DataFrame,
  target_node : String,
  config : DistributionChangeRobustConfig,
  regressor : Regressor,
  classifier : ClassificationModel,
) -> Map[String, Double] {
  let graph = causal_model.graph.node_connected_subgraph_view(target_node)
  let names = lexicographical_topological_order(graph)
  if names.length() == 0 {
    abort("the graph of the model has no node")
  }
  let target = names[names.length() - 1]
  let x_names : Array[String] = []
  for i in 0..<(names.length() - 1) {
    x_names.push(names[i])
  }
  let n0 = old_data.nrows()
  let n1 = new_data.nrows()
  // The design matrix of the two data sets, the old one first.
  let columns : Array[Array[Double]] = []
  for name in x_names {
    let values = old_data.numeric(name).copy()
    for value in new_data.numeric(name) {
      values.push(value)
    }
    columns.push(values)
  }
  let x = @utils.Matrix::from_columns(columns)
  // The target of the two data sets.
  let y : Array[Double] = []
  for value in old_data.numeric(target) {
    y.push(value)
  }
  for value in new_data.numeric(target) {
    y.push(value)
  }
  // The indicator of the data set every row belongs to.
  let t : Array[Double] = []
  for _ in 0..<n0 {
    t.push(0.0)
  }
  for _ in 0..<n1 {
    t.push(1.0)
  }
  let folds = stratified_folds(
    t,
    config.xfit_folds,
    config.split_random_state,
    config.xfit,
    config.train_size,
  )
  let attributions : Array[Double] = []
  for _ in 0..<names.length() {
    attributions.push(0.0)
  }
  let fold_count = folds.length().to_double()
  for fold in folds {
    let (train_rows, test_rows) = fold
    let x_train = select_matrix_rows(x, train_rows)
    let x_eval = select_matrix_rows(x, test_rows)
    let y_train = select_array_values(y, train_rows)
    let y_eval = select_array_values(y, test_rows)
    let t_train = select_array_values(t, train_rows)
    let t_eval = select_array_values(t, test_rows)
    let set_func = fn(flags : Array[Bool]) -> Double {
      let change : Array[Int32] = []
      for flag in flags {
        change.push(if flag { 1 } else { 0 })
      }
      match config.target_functional {
        Mean =>
          est_theta(
            change,
            TargetMoment::first(),
            x_eval,
            y_eval,
            t_eval,
            x_train,
            y_train,
            t_train,
            config.change_method,
            regressor,
            classifier,
            config.all_indep,
            config.crop,
          ).0
        Variance => {
          let second = est_theta(
              change,
              TargetMoment::second(),
              x_eval,
              y_eval,
              t_eval,
              x_train,
              y_train,
              t_train,
              config.change_method,
              regressor,
              classifier,
              config.all_indep,
              config.crop,
            ).0
          let first = est_theta(
              change,
              TargetMoment::first(),
              x_eval,
              y_eval,
              t_eval,
              x_train,
              y_train,
              t_train,
              config.change_method,
              regressor,
              classifier,
              config.all_indep,
              config.crop,
            ).0
          // The upstream computes the second moment of the target minus the
          // square of the first moment of the target.  Its parentheses make it
          // look like the square of the difference of the two moments, but the
          // exponent of Python binds tighter than the subtraction, so the
          // upstream squares the first moment alone.  The port keeps the
          // functional of the upstream.
          second - first * first
        }
      }
    }
    let values = estimate_shapley_values(
      set_func,
      names.length(),
      config.shapley_config,
    )
    for i in 0..<attributions.length() {
      attributions[i] = attributions[i] + values[i] / fold_count
    }
  }
  let out : Map[String, Double] = Map([])
  for i in 0..<names.length() {
    out.set(names[i], attributions[i])
  }
  out
}

///|
/// The estimate of the change of the moment of the target, and the standard
/// error of the estimate.
///
/// This is the port of `ThetaC.est_theta`. The estimate is the mean of the
/// scores of the estimator, and the standard error is the one of
/// `statsmodels.stats.weightstats.DescrStatsW` with the weights of one.
fn est_theta(
  change : Array[Int32],
  moment : TargetMoment,
  x_eval : @utils.Matrix,
  y_eval : Array[Double],
  t_eval : Array[Double],
  x_train : @utils.Matrix,
  y_train : Array[Double],
  t_train : Array[Double],
  change_method : ChangeMethod,
  regressor : Regressor,
  classifier : ClassificationModel,
  all_indep : Bool,
  crop : Double,
) -> (Double, Double) {
  let scores = est_scores(
    change, moment, x_eval, y_eval, t_eval, x_train, y_train, t_train, change_method,
    regressor, classifier, all_indep, crop,
  )
  let n = scores.length()
  let mut sum = 0.0
  for score in scores {
    sum = sum + score
  }
  let mean = if n == 0 { 0.0 } else { sum / n.to_double() }
  let mut variance = 0.0
  for score in scores {
    let difference = score - mean
    variance = variance + difference * difference
  }
  if n > 0 {
    variance = variance / n.to_double()
  }
  let standard_error = if n > 1 {
    variance.sqrt() / (n.to_double() - 1.0).sqrt()
  } else {
    0.0
  }
  (mean, standard_error)
}

///|
/// The scores of the estimator of the change.
///
/// This is the port of `ThetaC.est_scores`. The scores are the values whose
/// mean is the estimate of the change: the scores of the rows of the group of
/// the indicator zero come first and the scores of the rows of the group of
/// the indicator one come last.
fn est_scores(
  change : Array[Int32],
  moment : TargetMoment,
  x_eval : @utils.Matrix,
  y_eval : Array[Double],
  t_eval : Array[Double],
  x_train : @utils.Matrix,
  y_train : Array[Double],
  t_train : Array[Double],
  change_method : ChangeMethod,
  regressor : Regressor,
  classifier : ClassificationModel,
  all_indep : Bool,
  crop : Double,
) -> Array[Double] {
  let n = t_eval.length()
  let n0 = count_indicator(t_eval, 0.0)
  let n1 = count_indicator(t_eval, 1.0)
  let groups = simplify_change(change, all_indep)
  let num_groups = groups.length() - 1
  let rows_0 = rows_with(t_eval, 0.0)
  let rows_1 = rows_with(t_eval, 1.0)
  if num_groups <= 0 {
    // Every variable is in the same group, so the change is the difference of
    // the means of the target.
    let group = groups[0].0
    let rows = rows_with(t_eval, group.to_double())
    let scores_0 : Array[Double] = []
    let scores_1 : Array[Double] = []
    if group == 1 {
      for _ in rows_0 {
        scores_0.push(0.0)
      }
      for row in rows {
        scores_1.push(
          apply_moment(moment, y_eval[row]) * n.to_double() / n1.to_double(),
        )
      }
    } else {
      for row in rows {
        scores_0.push(
          apply_moment(moment, y_eval[row]) * n.to_double() / n0.to_double(),
        )
      }
      for _ in rows_1 {
        scores_1.push(0.0)
      }
    }
    return concat_scores(scores_0, scores_1)
  }
  match change_method {
    Regression => {
      let regressors = train_regressions(
        groups, num_groups, x_train, y_train, t_train, moment, regressor,
      )
      let group = groups[0]
      let rows = rows_with(t_eval, group.0.to_double())
      let predictions = regressors[0].predict(select(x_eval, rows, group.1))
      let scores_0 : Array[Double] = []
      let scores_1 : Array[Double] = []
      if group.0 == 1 {
        for _ in rows_0 {
          scores_0.push(0.0)
        }
        for value in predictions {
          scores_1.push(value * n.to_double() / n1.to_double())
        }
      } else {
        for value in predictions {
          scores_0.push(value * n.to_double() / n0.to_double())
        }
        for _ in rows_1 {
          scores_1.push(0.0)
        }
      }
      concat_scores(scores_0, scores_1)
    }
    Reweighting => {
      let classifiers = train_classifiers(
        groups, num_groups, x_train, t_train, classifier,
      )
      let ratio = n1.to_double() / n0.to_double()
      let alphas = compute_alphas(
        groups, num_groups, classifiers, x_eval, t_eval, ratio, crop,
      )
      let last = num_groups - 1
      let group = groups[num_groups]
      let rows = rows_with(t_eval, group.0.to_double())
      let weights = alphas[last]
      let scores_0 : Array[Double] = []
      let scores_1 : Array[Double] = []
      if group.0 == 1 {
        for _ in rows_0 {
          scores_0.push(0.0)
        }
        for i in 0..<rows.length() {
          scores_1.push(
            weights[i] *
            apply_moment(moment, y_eval[rows[i]]) *
            n.to_double() /
            n1.to_double(),
          )
        }
      } else {
        for i in 0..<rows.length() {
          scores_0.push(
            weights[i] *
            apply_moment(moment, y_eval[rows[i]]) *
            n.to_double() /
            n0.to_double(),
          )
        }
        for _ in rows_1 {
          scores_1.push(0.0)
        }
      }
      concat_scores(scores_0, scores_1)
    }
    MultiplyRobust => {
      let regressors = train_regressions(
        groups, num_groups, x_train, y_train, t_train, moment, regressor,
      )
      let classifiers = train_classifiers(
        groups, num_groups, x_train, t_train, classifier,
      )
      let ratio = n1.to_double() / n0.to_double()
      let alphas = compute_alphas(
        groups, num_groups, classifiers, x_eval, t_eval, ratio, crop,
      )
      let scores_0 : Array[Double] = []
      let scores_1 : Array[Double] = []
      for _ in rows_0 {
        scores_0.push(0.0)
      }
      for _ in rows_1 {
        scores_1.push(0.0)
      }
      // The estimate of the regression.
      let group = groups[0]
      let rows = rows_with(t_eval, group.0.to_double())
      let predictions = regressors[0].predict(select(x_eval, rows, group.1))
      if group.0 == 1 {
        for i in 0..<rows.length() {
          scores_1[i] = scores_1[i] + predictions[i]
        }
      } else {
        for i in 0..<rows.length() {
          scores_0[i] = scores_0[i] + predictions[i]
        }
      }
      // The terms that correct the bias of the regression.
      for k in 0..<num_groups {
        let group = groups[k + 1]
        let rows = if group.0 == 1 { rows_1 } else { rows_0 }
        let columns = group_columns(groups, k)
        let scores = if group.0 == 1 { scores_1 } else { scores_0 }
        if k < num_groups - 1 {
          let next_columns = group_columns(groups, k + 1)
          let next_predictions = regressors[k + 1].predict(
            select(x_eval, rows, next_columns),
          )
          let predictions = regressors[k].predict(select(x_eval, rows, columns))
          for i in 0..<rows.length() {
            scores[i] = scores[i] +
              alphas[k][i] * (next_predictions[i] - predictions[i])
          }
        } else {
          let predictions = regressors[num_groups - 1].predict(
            select(x_eval, rows, columns),
          )
          for i in 0..<rows.length() {
            scores[i] = scores[i] +
              alphas[k][i] *
              (apply_moment(moment, y_eval[rows[i]]) - predictions[i])
          }
        }
      }
      for i in 0..<scores_0.length() {
        scores_0[i] = scores_0[i] * n.to_double() / n0.to_double()
      }
      for i in 0..<scores_1.length() {
        scores_1[i] = scores_1[i] * n.to_double() / n1.to_double()
      }
      concat_scores(scores_0, scores_1)
    }
  }
}

///|
/// The nested regressions of the estimator.
///
/// This is the port of `ThetaC._train_reg`. The regression of the last group
/// is fitted on the samples of the group of the outcome, and every other
/// regression is fitted on the fitted values of the regression above it.
fn train_regressions(
  groups : Array[(Int32, Array[Int32])],
  num_groups : Int32,
  x_train : @utils.Matrix,
  y_train : Array[Double],
  t_train : Array[Double],
  moment : TargetMoment,
  regressor : Regressor,
) -> Array[Regressor] {
  let regressors : Array[Regressor] = []
  for _ in 0..<num_groups {
    regressors.push(regressor)
  }
  let last = num_groups - 1
  let mut columns = group_columns(groups, last)
  let rows = rows_with(t_train, groups[num_groups].0.to_double())
  let targets : Array[Double] = []
  for row in rows {
    targets.push(apply_moment(moment, y_train[row]))
  }
  regressors[last] = regressor.fit(select(x_train, rows, columns), targets)
  for k in 2..<=num_groups {
    let group = num_groups - k
    let rows = rows_with(t_train, groups[num_groups + 1 - k].0.to_double())
    let new_columns = group_columns(groups, num_groups - k)
    let predictions = regressors[group + 1].predict(
      select(x_train, rows, columns),
    )
    regressors[group] = regressor.fit(
      select(x_train, rows, new_columns),
      predictions,
    )
    columns = new_columns
  }
  regressors
}

///|
/// The classifiers of the estimator.
///
/// This is the port of `ThetaC._train_cla`. Every classifier is fitted on the
/// variables of the groups up to its own, and it tells the probability that a
/// row belongs to the second data set.
fn train_classifiers(
  groups : Array[(Int32, Array[Int32])],
  num_groups : Int32,
  x_train : @utils.Matrix,
  t_train : Array[Double],
  classifier : ClassificationModel,
) -> Array[ClassificationModel] {
  let classifiers : Array[ClassificationModel] = []
  for _ in 0..<num_groups {
    classifiers.push(classifier)
  }
  let rows : Array[Int32] = []
  let labels : Array[String] = []
  for i in 0..<t_train.length() {
    rows.push(i)
    labels.push(if t_train[i] == 0.0 { "0" } else { "1" })
  }
  for k in 0..<num_groups {
    let columns = group_columns(groups, k)
    classifiers[k] = classifier.fit(select(x_train, rows, columns), labels)
  }
  classifiers
}

///|
/// The weights of the estimator.
///
/// This is the port of `ThetaC._get_alphas`. The weight of a group is the
/// ratio of the densities of the two data sets, and the weight of every group
/// is the product of the weights of the two groups before it.  The weights are
/// standardised, so that they sum to the number of the rows of the group.
fn compute_alphas(
  groups : Array[(Int32, Array[Int32])],
  num_groups : Int32,
  classifiers : Array[ClassificationModel],
  x_eval : @utils.Matrix,
  t_eval : Array[Double],
  ratio : Double,
  crop : Double,
) -> Array[Array[Double]] {
  let alphas : Array[Array[Double]] = []
  for _ in 0..<num_groups {
    alphas.push([])
  }
  for k in 0..<num_groups {
    let group = groups[k + 1]
    let rows = rows_with(t_eval, group.0.to_double())
    let weights : Array[Double] = []
    if k == 0 {
      // The first group has no variables before it, so its weight is the
      // density of the marginal.
      let probabilities = positive_probabilities(
        classifiers[0],
        select(x_eval, rows, groups[0].1),
        crop,
      )
      for probability in probabilities {
        if group.0 == 1 {
          weights.push((1.0 - probability) / probability * ratio)
        } else {
          weights.push(probability / (1.0 - probability) / ratio)
        }
      }
    } else {
      // The weight of the group is the weight of the joint density of its
      // variables divided by the weight of the density of the variables
      // before it.
      let joint = positive_probabilities(
        classifiers[k],
        select(x_eval, rows, group_columns(groups, k)),
        crop,
      )
      let conditional = positive_probabilities(
        classifiers[k - 1],
        select(x_eval, rows, group_columns(groups, k - 1)),
        crop,
      )
      for i in 0..<rows.length() {
        let joint_weight = if group.0 == 1 {
          (1.0 - joint[i]) / joint[i]
        } else {
          joint[i] / (1.0 - joint[i])
        }
        let conditional_weight = if group.0 == 1 {
          conditional[i] / (1.0 - conditional[i])
        } else {
          (1.0 - conditional[i]) / conditional[i]
        }
        weights.push(joint_weight * conditional_weight)
      }
    }
    // The weights of the two groups before are multiplied in.
    if k >= 2 {
      let previous = alphas[k - 2]
      for i in 0..<weights.length() {
        weights[i] = weights[i] * previous[i]
      }
    }
    alphas[k] = weights
  }
  // Only the weights of the last group are standardised.  The upstream
  // standardises the weights outside its loop over the groups, so the weights
  // of the other groups keep their scale.
  let last = num_groups - 1
  let weights = alphas[last]
  let mut sum = 0.0
  for weight in weights {
    sum = sum + weight
  }
  let mean = if weights.length() == 0 {
    0.0
  } else {
    sum / weights.length().to_double()
  }
  for i in 0..<weights.length() {
    weights[i] = weights[i] / mean
  }
  alphas
}

///|
/// The probability that a row belongs to the second data set, trimmed to the
/// given bounds.
fn positive_probabilities(
  classifier : ClassificationModel,
  x : @utils.Matrix,
  crop : Double,
) -> Array[Double] {
  let out : Array[Double] = []
  for probabilities in classifier.predict_probabilities(x) {
    let probability = probabilities[1]
    let mut value = probability
    if value < crop {
      value = crop
    }
    if value > 1.0 - crop {
      value = 1.0 - crop
    }
    out.push(value)
  }
  out
}

///|
/// The groups of the variables of the change vector.
///
/// This is the port of `ThetaC._simplify_C`. The variables of the change
/// vector are grouped by their value: the groups of the consecutive variables
/// are the groups of the estimator, and the group of the outcome is the last
/// one.  When all the variables are independent, the groups are the values of
/// the change vector instead.
fn simplify_change(
  change : Array[Int32],
  all_indep : Bool,
) -> Array[(Int32, Array[Int32])] {
  if all_indep {
    let values : Array[Int32] = []
    for value in change {
      if !values.contains(value) {
        values.push(value)
      }
    }
    values.sort_by(fn(a, b) { a - b })
    let groups : Array[(Int32, Array[Int32])] = []
    for value in values {
      let indices : Array[Int32] = []
      for i in 0..<change.length() {
        if change[i] == value {
          indices.push(i)
        }
      }
      groups.push((value, indices))
    }
    // The groups are ordered by the largest index of their variables.
    groups.sort_by(fn(a, b) { largest_index(a.1) - largest_index(b.1) })
    groups
  } else {
    let groups : Array[(Int32, Array[Int32])] = []
    let mut i = 0
    while i < change.length() {
      let value = change[i]
      let indices : Array[Int32] = []
      while i < change.length() && change[i] == value {
        indices.push(i)
        i = i + 1
      }
      groups.push((value, indices))
    }
    groups
  }
}

///|
/// The largest index of a list of indices.
fn largest_index(indices : Array[Int32]) -> Int32 {
  if indices.length() == 0 {
    return 0
  }
  indices[indices.length() - 1]
}

///|
/// The variables of the groups up to the given one.
fn group_columns(
  groups : Array[(Int32, Array[Int32])],
  last : Int32,
) -> Array[Int32] {
  let columns : Array[Int32] = []
  for k in 0..<=last {
    for index in groups[k].1 {
      columns.push(index)
    }
  }
  columns
}

///|
/// The rows of a matrix, the columns of the given list.
fn select(
  x : @utils.Matrix,
  rows : Array[Int32],
  columns : Array[Int32],
) -> @utils.Matrix {
  let out = @utils.Matrix::zeros(rows.length(), columns.length())
  for i in 0..<rows.length() {
    for j in 0..<columns.length() {
      out.set(i, j, x.get(rows[i], columns[j]))
    }
  }
  out
}

///|
/// The rows of a matrix, the rows of the given list.
fn select_matrix_rows(x : @utils.Matrix, rows : Array[Int32]) -> @utils.Matrix {
  let out = @utils.Matrix::zeros(rows.length(), x.ncols())
  for i in 0..<rows.length() {
    for j in 0..<x.ncols() {
      out.set(i, j, x.get(rows[i], j))
    }
  }
  out
}

///|
/// The values of an array, the entries of the given list.
fn select_array_values(
  values : Array[Double],
  rows : Array[Int32],
) -> Array[Double] {
  let out : Array[Double] = []
  for row in rows {
    out.push(values[row])
  }
  out
}

///|
/// The rows whose indicator is the given value.
fn rows_with(t : Array[Double], value : Double) -> Array[Int32] {
  let rows : Array[Int32] = []
  for i in 0..<t.length() {
    if t[i] == value {
      rows.push(i)
    }
  }
  rows
}

///|
/// The number of the entries of an array that are the given value.
fn count_indicator(t : Array[Double], value : Double) -> Int32 {
  let mut count = 0
  for entry in t {
    if entry == value {
      count = count + 1
    }
  }
  count
}

///|
/// The moment of the target the estimator of the change works with.
fn apply_moment(moment : TargetMoment, value : Double) -> Double {
  match moment {
    First => value
    Second => value * value
  }
}

///|
/// The scores of the two groups of the indicator, the first one first.
fn concat_scores(
  first : Array[Double],
  second : Array[Double],
) -> Array[Double] {
  let out = first.copy()
  for value in second {
    out.push(value)
  }
  out
}

///|
/// The folds of the cross-fitting.
///
/// This is the port of the `StratifiedKFold` of scikit-learn: the rows are
/// shuffled and the rows of the two groups of the indicator are dealt over the
/// folds, so that every fold holds the same share of both groups.  When the
/// cross-fitting is not used, the upstream splits the data in two and keeps
/// the first split.
fn stratified_folds(
  t : Array[Double],
  xfit_folds : Int32,
  random_state : Int32,
  xfit : Bool,
  train_size : Double,
) -> Array[(Array[Int32], Array[Int32])] {
  let n = t.length()
  let mut folds = xfit_folds
  if !xfit {
    // The upstream splits the data in one over the share of the training set
    // and keeps the first of the splits.
    let share = 1.0 / (1.0 - train_size)
    folds = share.to_int()
    if folds < 2 {
      folds = 2
    }
  }
  if folds < 2 {
    folds = 2
  }
  let rng = @utils.Random::new(random_state.to_uint64())
  let values : Array[Double] = []
  for i in 0..<n {
    values.push(i.to_double())
  }
  let shuffled = rng.shuffle(values)
  let zeros : Array[Int32] = []
  let ones : Array[Int32] = []
  for value in shuffled {
    let index = value.to_int()
    if t[index] == 0.0 {
      zeros.push(index)
    } else {
      ones.push(index)
    }
  }
  let test_rows : Array[Array[Int32]] = []
  for _ in 0..<folds {
    test_rows.push([])
  }
  deal_rows(zeros, test_rows)
  deal_rows(ones, test_rows)
  let out : Array[(Array[Int32], Array[Int32])] = []
  for i in 0..<folds {
    let test_fold = test_rows[i].copy()
    let in_test : Array[Bool] = []
    for _ in 0..<n {
      in_test.push(false)
    }
    for row in test_fold {
      in_test[row] = true
    }
    let train : Array[Int32] = []
    for j in 0..<n {
      if !in_test[j] {
        train.push(j)
      }
    }
    out.push((train, test_fold))
  }
  if xfit {
    out
  } else {
    // Only the first split is used.
    [out[0]]
  }
}

///|
/// The rows of a group over the folds.
fn deal_rows(rows : Array[Int32], folds : Array[Array[Int32]]) -> Unit {
  for i in 0..<rows.length() {
    folds[i % folds.length()].push(rows[i])
  }
}

///|
/// The nodes of the graph in a topological order, with the names of the nodes
/// as the tie break.
///
/// This is the port of `networkx.lexicographical_topological_sort`.
fn lexicographical_topological_order(
  graph : @graph.DirectedGraph,
) -> Array[String] {
  let nodes = graph.node_list()
  let placed : Set[String] = Set::Set([])
  let order : Array[String] = []
  while order.length() < nodes.length() {
    // The smallest node whose predecessors are all placed already.
    let mut chosen = ""
    for node in nodes {
      if placed.contains(node) {
        continue
      }
      let mut ready = true
      for parent in graph.predecessors(node) {
        if !placed.contains(parent) {
          ready = false
          break
        }
      }
      if ready && (chosen == "" || node.lexical_compare(chosen) < 0) {
        chosen = node
      }
    }
    if chosen == "" {
      // The graph has a cycle, so there is no topological order.
      break
    }
    placed.add(chosen)
    order.push(chosen)
  }
  order
}
