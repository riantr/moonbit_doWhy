///|
/// The distribution change layer of the `gcm` package.
///
/// This is the port of `dowhy.gcm.distribution_change`. The layer attributes
/// the change of the marginal distribution of a target node, between a set of
/// old observations and a set of new ones, to the nodes of the causal graph
/// that are upstream of the target.
///
/// The method is described in the research paper *Why did the distribution
/// change?* of Kailash Budhathoki, Dominik Janzing, Patrick Bloebaum and Hoiyi
/// Ng.

///|
/// The configuration of the distribution change layer.
pub struct DistributionChangeConfig {
  num_samples : Int32
  num_joint_samples : Int32
  max_num_evaluation_samples : Int32
  early_stopping_percentage : Double
  difference_estimation_func : ((Array[Double], Array[Double]) -> Double)?
  mechanism_change_test_significance_level : Double
  fdr_control_method : FdrControlMethod?
  shapley_config : ShapleyConfig
}

///|
/// The configuration with the defaults of the upstream.
///
/// The upstream draws two thousand samples, uses the Kullback-Leibler divergence
/// as the measure of the difference of the distributions, tests the change of a
/// mechanism at the five percent level and controls the false discovery rate
/// with the procedure of Benjamini and Hochberg.
pub fn DistributionChangeConfig::new(
  shapley_config : ShapleyConfig,
) -> DistributionChangeConfig {
  {
    num_samples: 2000,
    num_joint_samples: 500,
    max_num_evaluation_samples: 1000,
    early_stopping_percentage: 0.01,
    difference_estimation_func: None,
    mechanism_change_test_significance_level: 0.05,
    fdr_control_method: Some(FdrBh),
    shapley_config,
  }
}

///|
/// A copy of the configuration with the given number of samples.
pub fn DistributionChangeConfig::with_num_samples(
  self : DistributionChangeConfig,
  value : Int32,
) -> DistributionChangeConfig {
  {
    num_samples: value,
    num_joint_samples: self.num_joint_samples,
    max_num_evaluation_samples: self.max_num_evaluation_samples,
    early_stopping_percentage: self.early_stopping_percentage,
    difference_estimation_func: self.difference_estimation_func,
    mechanism_change_test_significance_level: self.mechanism_change_test_significance_level,
    fdr_control_method: self.fdr_control_method,
    shapley_config: self.shapley_config,
  }
}

///|
/// A copy of the configuration with the given number of the joint samples.
///
/// The joint samples are the samples that the old and the new mechanism draw
/// for one sample of the parents.
pub fn DistributionChangeConfig::with_num_joint_samples(
  self : DistributionChangeConfig,
  value : Int32,
) -> DistributionChangeConfig {
  {
    num_samples: self.num_samples,
    num_joint_samples: value,
    max_num_evaluation_samples: self.max_num_evaluation_samples,
    early_stopping_percentage: self.early_stopping_percentage,
    difference_estimation_func: self.difference_estimation_func,
    mechanism_change_test_significance_level: self.mechanism_change_test_significance_level,
    fdr_control_method: self.fdr_control_method,
    shapley_config: self.shapley_config,
  }
}

///|
/// A copy of the configuration with the given number of the evaluated samples.
pub fn DistributionChangeConfig::with_max_num_evaluation_samples(
  self : DistributionChangeConfig,
  value : Int32,
) -> DistributionChangeConfig {
  {
    num_samples: self.num_samples,
    num_joint_samples: self.num_joint_samples,
    max_num_evaluation_samples: value,
    early_stopping_percentage: self.early_stopping_percentage,
    difference_estimation_func: self.difference_estimation_func,
    mechanism_change_test_significance_level: self.mechanism_change_test_significance_level,
    fdr_control_method: self.fdr_control_method,
    shapley_config: self.shapley_config,
  }
}

///|
/// A copy of the configuration with the given threshold of the early stopping.
///
/// The evaluation stops when the score of the last run changed by less than the
/// threshold.
pub fn DistributionChangeConfig::with_early_stopping_percentage(
  self : DistributionChangeConfig,
  value : Double,
) -> DistributionChangeConfig {
  {
    num_samples: self.num_samples,
    num_joint_samples: self.num_joint_samples,
    max_num_evaluation_samples: self.max_num_evaluation_samples,
    early_stopping_percentage: value,
    difference_estimation_func: self.difference_estimation_func,
    mechanism_change_test_significance_level: self.mechanism_change_test_significance_level,
    fdr_control_method: self.fdr_control_method,
    shapley_config: self.shapley_config,
  }
}

///|
/// A copy of the configuration with the given measure of the difference of two
/// distributions.
///
/// The measure takes the samples of the old and of the new distribution of the
/// target and returns a number that is large when the two distributions differ.
pub fn DistributionChangeConfig::with_difference_estimation_func(
  self : DistributionChangeConfig,
  value : (Array[Double], Array[Double]) -> Double,
) -> DistributionChangeConfig {
  {
    num_samples: self.num_samples,
    num_joint_samples: self.num_joint_samples,
    max_num_evaluation_samples: self.max_num_evaluation_samples,
    early_stopping_percentage: self.early_stopping_percentage,
    difference_estimation_func: Some(value),
    mechanism_change_test_significance_level: self.mechanism_change_test_significance_level,
    fdr_control_method: self.fdr_control_method,
    shapley_config: self.shapley_config,
  }
}

///|
/// A copy of the configuration with the given significance level of the test of
/// the change of a mechanism.
pub fn DistributionChangeConfig::with_mechanism_change_test_significance_level(
  self : DistributionChangeConfig,
  value : Double,
) -> DistributionChangeConfig {
  {
    num_samples: self.num_samples,
    num_joint_samples: self.num_joint_samples,
    max_num_evaluation_samples: self.max_num_evaluation_samples,
    early_stopping_percentage: self.early_stopping_percentage,
    difference_estimation_func: self.difference_estimation_func,
    mechanism_change_test_significance_level: value,
    fdr_control_method: self.fdr_control_method,
    shapley_config: self.shapley_config,
  }
}

///|
/// A copy of the configuration with the given control of the false discovery
/// rate of the tests of the change of a mechanism.
///
/// `None` stands for no control at all: every test is compared with the
/// significance level on its own.
pub fn DistributionChangeConfig::with_fdr_control_method(
  self : DistributionChangeConfig,
  value : FdrControlMethod?,
) -> DistributionChangeConfig {
  {
    num_samples: self.num_samples,
    num_joint_samples: self.num_joint_samples,
    max_num_evaluation_samples: self.max_num_evaluation_samples,
    early_stopping_percentage: self.early_stopping_percentage,
    difference_estimation_func: self.difference_estimation_func,
    mechanism_change_test_significance_level: self.mechanism_change_test_significance_level,
    fdr_control_method: value,
    shapley_config: self.shapley_config,
  }
}

///|
/// The result of the distribution change layer.
pub struct DistributionChangeResult {
  attributions : Map[String, Double]
  mechanism_changes : Map[String, Bool]
  causal_model_old : ProbabilisticCausalModel
  causal_model_new : ProbabilisticCausalModel
}

///|
/// The contribution of every node to the change of the distribution of the
/// target.
pub fn DistributionChangeResult::attributions(
  self : DistributionChangeResult,
) -> Map[String, Double] {
  self.attributions.copy()
}

///|
/// Whether the mechanism of every node changed.
pub fn DistributionChangeResult::mechanism_changes(
  self : DistributionChangeResult,
) -> Map[String, Bool] {
  self.mechanism_changes.copy()
}

///|
/// The model whose mechanisms are fitted on the old data.
pub fn DistributionChangeResult::causal_model_old(
  self : DistributionChangeResult,
) -> ProbabilisticCausalModel {
  self.causal_model_old
}

///|
/// The model whose mechanisms are fitted on the new data.
pub fn DistributionChangeResult::causal_model_new(
  self : DistributionChangeResult,
) -> ProbabilisticCausalModel {
  self.causal_model_new
}

///|
/// The p-value of the null hypothesis that the two samples of the target come
/// from the same mechanism.
///
/// This is the port of
/// `dowhy.gcm.distribution_change.mechanism_change_test`. The test looks at the
/// dependency between the samples of the target and a binary label that tells
/// the old samples from the new ones: when the label tells nothing about the
/// target, the mechanism has not changed.
///
/// The samples of the parents are the conditioning variables of the test for a
/// node that has parents, so that a change of the parents does not count as a
/// change of the mechanism of the node.
///
/// The upstream draws the rows of the two samples without replacement, which
/// permutes them. The permutation is not a detail: when the two samples hold
/// the same rows, the label tells the two copies of every row apart, and the
/// test would find a dependency that is not there. The port draws the same
/// permutation from the generator it is given.
pub fn mechanism_change_test(
  target_original_data : Array[Double],
  target_new_data : Array[Double],
  parents_original_data : @utils.Matrix?,
  parents_new_data : @utils.Matrix?,
  rng : @utils.Random,
) -> Double {
  let original_parents_are_none = parents_original_data is None
  let new_parents_are_none = parents_new_data is None
  if original_parents_are_none != new_parents_are_none {
    abort(
      "the parents of the original data and the parents of the new data have to be given together",
    )
  }
  let num_samples = if target_original_data.length() < target_new_data.length() {
    target_original_data.length()
  } else {
    target_new_data.length()
  }
  if num_samples == 0 {
    return 1.0
  }
  let original_indices = shuffled_indices(target_original_data.length(), rng)
  let new_indices = shuffled_indices(target_new_data.length(), rng)
  // The joint sample of the target: the rows of the original data first and the
  // rows of the new data after them.
  let joint_target = @utils.Matrix::zeros(num_samples * 2, 1)
  for i in 0..<num_samples {
    joint_target.set(i, 0, target_original_data[original_indices[i]])
    joint_target.set(num_samples + i, 0, target_new_data[new_indices[i]])
  }
  // The label of every row. The upstream encodes the label with a one hot
  // encoder that keeps every category, so the label is a matrix with two
  // columns: the first one holds the rows of the new data and the second one
  // the rows of the original data.
  let labels = @utils.Matrix::zeros(num_samples * 2, 2)
  for i in 0..<(num_samples * 2) {
    if i < num_samples {
      labels.set(i, 1, 1.0)
    } else {
      labels.set(i, 0, 1.0)
    }
  }
  match parents_original_data {
    Some(parents_original) => {
      let parents_new = parents_new_data.unwrap()
      if parents_original.ncols() != parents_new.ncols() {
        abort(
          "the parents of the two samples have a different number of columns",
        )
      }
      let joint_parents = @utils.Matrix::zeros(
        num_samples * 2,
        parents_original.ncols(),
      )
      for i in 0..<num_samples {
        for j in 0..<parents_original.ncols() {
          joint_parents.set(i, j, parents_original.get(original_indices[i], j))
          joint_parents.set(
            num_samples + i,
            j,
            parents_new.get(new_indices[i], j),
          )
        }
      }
      kernel_based_conditional(joint_target, labels, joint_parents, rng)
    }
    None => kernel_based_unconditional(joint_target, labels, rng)
  }
}

///|
/// The given number of the indices of the rows, in a random order.
fn shuffled_indices(count : Int32, rng : @utils.Random) -> Array[Int32] {
  let values : Array[Double] = []
  for i in 0..<count {
    values.push(i.to_double())
  }
  let shuffled = rng.shuffle(values)
  let indices : Array[Int32] = []
  for value in shuffled {
    indices.push(value.to_int())
  }
  indices
}

///|
/// The change of the marginal distribution of the target node between the two
/// data sets.
///
/// This is the port of `dowhy.gcm.distribution_change.distribution_change`. The
/// layer creates two models out of the graph of the given model: one whose
/// mechanisms are fitted on the old data and one whose mechanisms are fitted on
/// the new data. The mechanisms whose change is significant are fitted on their
/// own data and the other ones on the joint data, so that the attribution
/// measures the change of the mechanism and not the change of the data.
///
/// The nodes of the `invariant_nodes` keep their mechanism, whatever the data
/// says: they are removed from the graph and their contribution is zero.
pub fn distribution_change(
  causal_model : ProbabilisticCausalModel,
  old_data : @api.DataFrame,
  new_data : @api.DataFrame,
  target_node : String,
  invariant_nodes : Array[String],
  config : DistributionChangeConfig,
  rng : @utils.Random,
) -> DistributionChangeResult {
  let graph_old = causal_model.graph.node_connected_subgraph_view(target_node)
  let model_old = ProbabilisticCausalModel::new(graph_old)
  clone_causal_models(causal_model, model_old)

  // Only the invariant nodes that are in the graph of the model are kept.
  let invariant : Array[String] = []
  for node in invariant_nodes {
    if model_old.graph.has_node(node) && !invariant.contains(node) {
      invariant.push(node)
    }
  }
  remove_invariant_nodes(invariant, model_old, old_data)

  let model_new = ProbabilisticCausalModel::new(model_old.graph.copy())
  clone_causal_models(model_old, model_new)

  let mechanism_changes = fit_accounting_for_mechanism_change(
    model_old, model_new, old_data, new_data, config, rng,
  )

  let attributions = distribution_change_of_graphs(
    model_old, model_new, target_node, config, rng,
  )
  for node in invariant {
    attributions.set(node, 0.0)
  }
  {
    attributions,
    mechanism_changes,
    causal_model_old: model_old,
    causal_model_new: model_new,
  }
}

///|
/// The change of the marginal distribution of the target node between the two
/// models.
///
/// This is the port of
/// `dowhy.gcm.distribution_change.distribution_change_of_graphs`. The two
/// models are assumed to have the same causal structure and to be fitted on the
/// old and on the new data.
pub fn distribution_change_of_graphs(
  causal_model_old : ProbabilisticCausalModel,
  causal_model_new : ProbabilisticCausalModel,
  target_node : String,
  config : DistributionChangeConfig,
  rng : @utils.Random,
) -> Map[String, Double] {
  validate_causal_dag(causal_model_old)
  validate_causal_dag(causal_model_new)
  let model_old = ProbabilisticCausalModel::new(
    causal_model_old.graph.node_connected_subgraph_view(target_node),
  )
  let model_new = ProbabilisticCausalModel::new(
    causal_model_new.graph.node_connected_subgraph_view(target_node),
  )
  copy_mechanisms(causal_model_old, model_old)
  copy_mechanisms(causal_model_new, model_new)
  estimate_marginal_distribution_change(
    model_old, model_new, target_node, config, rng,
  )
}

///|
/// The score of every node, which tells how much the distribution of the node
/// changed.
///
/// This is the port of
/// `dowhy.gcm.distribution_change.estimate_distribution_change_scores`. The
/// score of a node whose mechanism has not changed is zero, and the score of a
/// node whose mechanism has changed is the difference of the distributions of
/// the node under the old and under the new mechanism.
pub fn estimate_distribution_change_scores(
  causal_model : ProbabilisticCausalModel,
  original_data : @api.DataFrame,
  new_data : @api.DataFrame,
  config : DistributionChangeConfig,
  rng : @utils.Random,
) -> Map[String, Double] {
  validate_causal_dag(causal_model)
  let mechanism_changes = check_significant_mechanism_change(
    causal_model, original_data, new_data, config, rng,
  )
  let scores : Map[String, Double] = Map([])
  for node in causal_model.graph.node_list() {
    let changed = match mechanism_changes.get(node) {
      Some(value) => value
      None => false
    }
    if !changed {
      scores.set(node, 0.0)
      continue
    }
    if is_root_node(causal_model, node) {
      scores.set(
        node,
        difference_of(
          config,
          original_data.numeric(node),
          new_data.numeric(node),
          rng,
        ),
      )
    } else {
      let parents = causal_model.graph.ordered_predecessors(node)
      let mechanism = match causal_model.causal_mechanism(node) {
        Some(value) => value
        None => abort("the node " + node + " has no causal mechanism")
      }
      scores.set(
        node,
        estimate_distribution_change_score(
          original_data.design_matrix(parents),
          new_data.design_matrix(parents),
          new_data.numeric(node),
          mechanism,
          config,
          rng,
        ),
      )
    }
  }
  scores
}

///|
/// The difference of the two distributions, measured by the measure of the
/// configuration.
fn difference_of(
  config : DistributionChangeConfig,
  old_samples : Array[Double],
  new_samples : Array[Double],
  rng : @utils.Random,
) -> Double {
  match config.difference_estimation_func {
    Some(func) => func(old_samples, new_samples)
    None =>
      auto_estimate_kl_divergence(
        @utils.Matrix::from_columns([old_samples]),
        @utils.Matrix::from_columns([new_samples]),
        rng,
      )
  }
}

///|
/// The score of a node whose mechanism changed.
fn estimate_distribution_change_score(
  parent_original_data : @utils.Matrix,
  parent_new_data : @utils.Matrix,
  target_new_data : Array[Double],
  mechanism : CausalMechanism,
  config : DistributionChangeConfig,
  rng : @utils.Random,
) -> Double {
  // The old mechanism is the one of the causal model, which is fitted on the
  // old data, and the new mechanism is a copy of it that is fitted on the new
  // data.
  let mechanism_old = mechanism
  let mechanism_new = mechanism.clone().fit(parent_new_data, target_new_data)
  let num_old = parent_original_data.nrows()
  let num_new = parent_new_data.nrows()
  let num_joint = num_old + num_new
  let num_evaluation_samples = if num_joint < config.max_num_evaluation_samples {
    num_joint
  } else {
    config.max_num_evaluation_samples
  }
  // The samples of the parents of the two data sets, drawn without replacement.
  let candidates : Array[Double] = []
  for i in 0..<num_joint {
    candidates.push(i.to_double())
  }
  let shuffled = rng.shuffle(candidates)
  let mut total = 0.0
  let mut runs = 0
  for i in 0..<num_evaluation_samples {
    let old_total = total
    let index = shuffled[i].to_int()
    let parents = @utils.Matrix::zeros(
      config.num_joint_samples,
      parent_original_data.ncols(),
    )
    for k in 0..<config.num_joint_samples {
      for j in 0..<parent_original_data.ncols() {
        let value = if index < num_old {
          parent_original_data.get(index, j)
        } else {
          parent_new_data.get(index - num_old, j)
        }
        parents.set(k, j, value)
      }
    }
    let old_samples = mechanism_old.draw_samples(parents, rng)
    let new_samples = mechanism_new.draw_samples(parents, rng)
    total = total + difference_of(config, old_samples, new_samples, rng)
    runs = runs + 1
    if old_total != 0.0 &&
      1.0 - total / old_total <= config.early_stopping_percentage {
      break
    }
  }
  if runs == 0 {
    return 0.0
  }
  total / runs.to_double()
}

///|
/// The change of the marginal distribution of the target, attributed to the
/// nodes of the two models.
fn estimate_marginal_distribution_change(
  causal_model_old : ProbabilisticCausalModel,
  causal_model_new : ProbabilisticCausalModel,
  target_node : String,
  config : DistributionChangeConfig,
  rng : @utils.Random,
) -> Map[String, Double] {
  let nodes = sorted_nodes(causal_model_old.graph)
  let old_samples = draw_samples(causal_model_old, config.num_samples, rng)
  let target_samples_old = old_samples.numeric(target_node)

  let set_function = fn(subset : Array[Bool]) -> Double {
    let mut all_false = true
    for active in subset {
      if active {
        all_false = false
      }
    }
    if all_false {
      return 0.0
    }
    let model = ProbabilisticCausalModel::new(causal_model_old.graph.copy())
    copy_mechanisms(causal_model_old, model)
    copy_mechanisms(causal_model_new, model)
    // The mechanism of a node is the old one when the node is not in the subset
    // and the new one when it is.
    for i in 0..<nodes.length() {
      if subset[i] {
        match causal_model_new.causal_mechanism(nodes[i]) {
          Some(mechanism) => model.set_causal_mechanism(nodes[i], mechanism)
          None => ()
        }
        match causal_model_new.root_model(nodes[i]) {
          Some(root_model) => model.set_root_model(nodes[i], root_model)
          None => ()
        }
      } else {
        match causal_model_old.causal_mechanism(nodes[i]) {
          Some(mechanism) => model.set_causal_mechanism(nodes[i], mechanism)
          None => ()
        }
        match causal_model_old.root_model(nodes[i]) {
          Some(root_model) => model.set_root_model(nodes[i], root_model)
          None => ()
        }
      }
    }
    let new_samples = draw_samples(model, config.num_samples, rng)
    difference_of(
      config,
      target_samples_old,
      new_samples.numeric(target_node),
      rng,
    )
  }

  let values = estimate_shapley_values(
    set_function,
    nodes.length(),
    config.shapley_config,
  )
  let attributions : Map[String, Double] = Map([])
  for i in 0..<nodes.length() {
    attributions.set(nodes[i], values[i])
  }
  attributions
}

///|
/// Whether the mechanism of every node changed.
fn check_significant_mechanism_change(
  causal_model : ProbabilisticCausalModel,
  old_data : @api.DataFrame,
  new_data : @api.DataFrame,
  config : DistributionChangeConfig,
  rng : @utils.Random,
) -> Map[String, Bool] {
  let nodes = causal_model.graph.node_list()
  let p_values : Array[Double] = []
  for node in nodes {
    let parents = if is_root_node(causal_model, node) {
      None
    } else {
      Some(causal_model.graph.ordered_predecessors(node))
    }
    let parents_original = match parents {
      Some(names) => Some(old_data.design_matrix(names))
      None => None
    }
    let parents_new = match parents {
      Some(names) => Some(new_data.design_matrix(names))
      None => None
    }
    p_values.push(
      mechanism_change_test(
        old_data.numeric(node),
        new_data.numeric(node),
        parents_original,
        parents_new,
        rng,
      ),
    )
  }
  let rejections = match config.fdr_control_method {
    Some(fdr_method) => {
      let control = match fdr_method {
        FdrBh =>
          fdr_bh_adjust(
            p_values,
            config.mechanism_change_test_significance_level,
          )
        FdrBonferroni =>
          fdr_bonferroni_adjust(
            p_values,
            config.mechanism_change_test_significance_level,
          )
      }
      control.reject()
    }
    None => {
      let out : Array[Bool] = []
      for p_value in p_values {
        out.push(p_value <= config.mechanism_change_test_significance_level)
      }
      out
    }
  }
  let changes : Map[String, Bool] = Map([])
  for i in 0..<nodes.length() {
    changes.set(nodes[i], rejections[i])
  }
  changes
}

///|
/// The fit of the two models, which takes the change of the mechanisms into
/// account.
///
/// The mechanisms whose change is significant are fitted on their own data and
/// the other ones on the joint data, so that the attribution measures the
/// change of the mechanism and not the change of the data.
fn fit_accounting_for_mechanism_change(
  causal_model_old : ProbabilisticCausalModel,
  causal_model_new : ProbabilisticCausalModel,
  old_data : @api.DataFrame,
  new_data : @api.DataFrame,
  config : DistributionChangeConfig,
  rng : @utils.Random,
) -> Map[String, Bool] {
  let mechanism_changes = check_significant_mechanism_change(
    causal_model_old, old_data, new_data, config, rng,
  )
  let joint_data = joint_frame(old_data, new_data)
  for node in causal_model_new.graph.node_list() {
    let changed = match mechanism_changes.get(node) {
      Some(value) => value
      None => false
    }
    if changed {
      fit_causal_model_of_target(causal_model_old, node, old_data)
      fit_causal_model_of_target(causal_model_new, node, new_data)
    } else {
      fit_causal_model_of_target(causal_model_old, node, joint_data)
      fit_causal_model_of_target(causal_model_new, node, joint_data)
    }
  }
  mechanism_changes
}

///|
/// The removal of the invariant nodes from the graph.
///
/// An invariant node is removed from the graph and its parents are connected
/// to its children, so that the graph stays a directed acyclic graph. A node
/// with more than one child is left alone, because removing it would introduce
/// a hidden confounder.
fn remove_invariant_nodes(
  invariant_nodes : Array[String],
  causal_model : ProbabilisticCausalModel,
  old_data : @api.DataFrame,
) -> Unit {
  for node in invariant_nodes {
    let parents = causal_model.graph.ordered_predecessors(node)
    let children = causal_model.graph.successors(node)
    if children.length() > 1 {
      continue
    }
    causal_model.graph.remove_node(node)
    for parent in parents {
      for child in children {
        causal_model.graph.add_edge(parent, child)
      }
    }
    for child in children {
      assign_causal_mechanism_node(
        causal_model,
        child,
        old_data,
        AssignmentQuality::good(),
      )
    }
  }
}

///|
/// The copy of the mechanisms of the source model into the destination model.
///
/// This is the port of `dowhy.gcm.causal_models.clone_causal_models`. The
/// mechanisms are cloned and not copied, so the copy is not fitted yet; the
/// upstream fits it afterwards.
fn clone_causal_models(
  source : ProbabilisticCausalModel,
  destination : ProbabilisticCausalModel,
) -> Unit {
  for node in destination.graph.node_list() {
    match source.causal_mechanism(node) {
      Some(mechanism) =>
        destination.set_causal_mechanism(node, mechanism.clone())
      None => ()
    }
    match source.root_model(node) {
      Some(model) => destination.set_root_model(node, model.clone())
      None => ()
    }
  }
}

///|
/// The copy of the mechanisms of the source model into the destination model,
/// with the fit they have.
///
/// The upstream keeps the mechanisms of a node in the attributes of the node of
/// the graph, so the view of the graph that holds the nodes connected to the
/// target keeps the mechanisms and their fit. The port keeps the mechanisms in
/// the model, so they have to be copied.
fn copy_mechanisms(
  source : ProbabilisticCausalModel,
  destination : ProbabilisticCausalModel,
) -> Unit {
  for node in destination.graph.node_list() {
    match source.causal_mechanism(node) {
      Some(mechanism) => destination.set_causal_mechanism(node, mechanism)
      None => ()
    }
    match source.root_model(node) {
      Some(model) => destination.set_root_model(node, model)
      None => ()
    }
    match source.encoder_of(node) {
      Some(encoder) => destination.set_encoder(node, encoder)
      None => ()
    }
  }
}

///|
/// The frame of the rows of the two data sets, one after the other.
fn joint_frame(
  old_data : @api.DataFrame,
  new_data : @api.DataFrame,
) -> @api.DataFrame {
  let order : Array[String] = []
  let payload : Map[String, Array[Double]] = Map([])
  for name in old_data.column_names() {
    if !new_data.has_column(name) {
      continue
    }
    let values = old_data.numeric(name).copy()
    for value in new_data.numeric(name) {
      values.push(value)
    }
    order.push(name)
    payload.set(name, values)
  }
  @api.DataFrame::from_numeric(order, payload)
}

///|
/// The nodes of the graph, sorted by their name.
///
/// The upstream sorts the nodes of the graph before it attributes the change,
/// so that the order of the players of the Shapley estimator does not depend on
/// the order of the nodes of the graph.
fn sorted_nodes(graph : @graph.DirectedGraph) -> Array[String] {
  let nodes = graph.node_list()
  nodes.sort_by(fn(a, b) { a.lexical_compare(b) })
  nodes
}
