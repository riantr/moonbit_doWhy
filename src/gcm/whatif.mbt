///|
/// The what-if questions of a fitted causal model.
///
/// This is the port of `dowhy.gcm.whatif`. The upstream answers three kinds of
/// what-if questions on a fitted causal model: the samples of an
/// interventional distribution, the counterfactual samples of an observed
/// sample, and the average causal effect of two sets of interventions.
///
/// The upstream keeps the interventions in a dictionary of functions of a numpy
/// array; the port keeps them in a map of functions of a single value, which is
/// the `Intervention` of `intervention.mbt`.

///|
/// The values of a node, either numbers or categories.
///
/// A node of a causal model holds either a number or a category, and the
/// intervention of a node is applied to the values of the node, so the values
/// of a node are carried in one of the two variants.
priv enum WhatIfValues {
  ///
  /// The values of a node that holds numbers.
  Numbers(Array[Double])
  ///
  /// The values of a node that holds categories.
  Categories(Array[String])
}

///|
/// The samples of the interventional distribution.
///
/// This is the port of `dowhy.gcm.whatif.interventional_samples`. The nodes
/// that are affected by an intervention are the nodes of the interventions and
/// all their descendants. The affected nodes are visited in the topological
/// order of the graph: a root node keeps the values it has in the data and a
/// node with parents is drawn again from its causal mechanism, with the values
/// its parents have after the intervention. The intervention of a node is then
/// applied to the values of the node.
///
/// Either the observed data or the number of samples to draw has to be given,
/// and not both; `has_valid_query_arguments` tells whether the arguments are
/// the ones the upstream accepts. When the number of samples to draw is given,
/// the data the intervention is performed on is drawn from the model first.
pub fn interventional_samples(
  causal_model : ProbabilisticCausalModel,
  interventions : Map[String, Intervention],
  observed_data : @api.DataFrame?,
  num_samples_to_draw : Int32?,
  rng : @utils.Random,
) -> @api.DataFrame {
  validate_causal_dag(causal_model)
  whatif_validate_interventions(causal_model, interventions)
  let has_observed_data = match observed_data {
    Some(_) => true
    None => false
  }
  let has_num_samples_to_draw = match num_samples_to_draw {
    Some(_) => true
    None => false
  }
  if !has_valid_query_arguments(has_observed_data, has_num_samples_to_draw) {
    abort(
      "either the observed data or the number of samples to draw has to be given, not both",
    )
  }
  let data = match (observed_data, num_samples_to_draw) {
    (Some(observed), _) => observed
    (None, Some(count)) => draw_samples(causal_model, count, rng)
    (None, None) =>
      abort(
        "either the observed data or the number of samples to draw has to be given, not both",
      )
  }
  whatif_interventional_samples(causal_model, data, interventions, rng)
}

///|
/// The estimated counterfactual data.
///
/// This is the port of `dowhy.gcm.whatif.counterfactual_samples`. The noise of
/// the model is recovered from the observed data when it is not given, which is
/// the abduction step of Pearl. The action and the prediction steps follow:
/// the nodes are visited in the topological order of the graph, a root node
/// takes the value of its noise and a node with parents takes the value its
/// causal mechanism gives for the values of its parents and for its noise. The
/// intervention of a node is then applied to the value of the node.
///
/// Either the observed data or the noise data has to be given, and not both.
pub fn counterfactual_samples(
  causal_model : ProbabilisticCausalModel,
  interventions : Map[String, Intervention],
  observed_data : @api.DataFrame?,
  noise_data : @api.DataFrame?,
) -> @api.DataFrame {
  validate_causal_dag(causal_model)
  whatif_validate_interventions(causal_model, interventions)
  let has_observed_data = match observed_data {
    Some(_) => true
    None => false
  }
  let has_noise_data = match noise_data {
    Some(_) => true
    None => false
  }
  if !has_valid_query_arguments(has_observed_data, has_noise_data) {
    abort(
      "either the observed data or the noise data has to be given, not both",
    )
  }
  let noise = match (observed_data, noise_data) {
    (Some(observed), None) => compute_noise_from_data(causal_model, observed)
    (None, Some(noise)) => noise
    (None, None) =>
      abort(
        "either the observed data or the noise data has to be given, not both",
      )
    (Some(_), Some(_)) =>
      abort(
        "either the observed data or the noise data has to be given, not both",
      )
  }
  whatif_counterfactual_samples(causal_model, interventions, noise)
}

///|
/// The estimated average causal effect of two sets of interventions.
///
/// This is the port of `dowhy.gcm.whatif.average_causal_effect`. The effect is
/// the mean of the target under the alternative interventions minus its mean
/// under the reference interventions.
///
/// Only the nodes that have a directed path to the target node matter, so the
/// model is restricted to the connected sub graph of the target node before
/// the effect is estimated.
///
/// The target node can be a continuous variable or a categorical variable with
/// at most two classes; the categories of a categorical target are counted as
/// zero and one, the way the upstream counts them.
pub fn average_causal_effect(
  causal_model : ProbabilisticCausalModel,
  target_node : String,
  interventions_alternative : Map[String, Intervention],
  interventions_reference : Map[String, Intervention],
  observed_data : @api.DataFrame?,
  num_samples_to_draw : Int32?,
  rng : @utils.Random,
) -> Double {
  let restricted = whatif_restricted_model(
    causal_model,
    whatif_ancestors_of(causal_model, target_node),
  )
  validate_causal_dag(restricted)
  whatif_validate_interventions(restricted, interventions_alternative)
  whatif_validate_interventions(restricted, interventions_reference)
  let has_observed_data = match observed_data {
    Some(_) => true
    None => false
  }
  let has_num_samples_to_draw = match num_samples_to_draw {
    Some(_) => true
    None => false
  }
  if !has_valid_query_arguments(has_observed_data, has_num_samples_to_draw) {
    abort(
      "either the observed data or the number of samples to draw has to be given, not both",
    )
  }
  let data = match (observed_data, num_samples_to_draw) {
    (Some(observed), _) => observed
    (None, Some(count)) => draw_samples(restricted, count, rng)
    (None, None) =>
      abort(
        "either the observed data or the number of samples to draw has to be given, not both",
      )
  }
  let alternative = whatif_interventional_samples(
    restricted, data, interventions_alternative, rng,
  )
  let reference = whatif_interventional_samples(
    restricted, data, interventions_reference, rng,
  )
  let alternative_values = whatif_target_values(
    restricted, target_node, alternative,
  )
  let reference_values = whatif_target_values(
    restricted, target_node, reference,
  )
  @utils.mean(alternative_values) - @utils.mean(reference_values)
}

///|
/// Whether the arguments of a query are the ones the upstream accepts.
///
/// This is the port of the checks of `dowhy.gcm.whatif.interventional_samples`,
/// of `dowhy.gcm.whatif.counterfactual_samples` and of
/// `dowhy.gcm.whatif.average_causal_effect`. The upstream raises a
/// `ValueError` when neither or both of the observed data and the number of
/// samples to draw are given. MoonBit cannot catch an `abort`, so the check is
/// available on its own.
pub fn has_valid_query_arguments(
  has_observed_data : Bool,
  has_num_samples_to_draw : Bool,
) -> Bool {
  has_observed_data != has_num_samples_to_draw
}

///|
/// The samples of the interventional distribution of the given data.
///
/// This is the port of `dowhy.gcm.whatif._interventional_samples`.
fn whatif_interventional_samples(
  causal_model : ProbabilisticCausalModel,
  data : @api.DataFrame,
  interventions : Map[String, Intervention],
  rng : @utils.Random,
) -> @api.DataFrame {
  let affected = whatif_affected_nodes(causal_model, interventions)
  let mut samples = data.copy()
  for node in causal_model.graph.topological_order() {
    if !affected.contains(node) {
      continue
    }
    let values = whatif_node_values(causal_model, node, samples, rng)
    samples = whatif_store_values(samples, node, interventions, values)
  }
  samples
}

///|
/// The counterfactual samples of the given noise.
///
/// This is the port of `dowhy.gcm.whatif._counterfactual_samples`.
fn whatif_counterfactual_samples(
  causal_model : ProbabilisticCausalModel,
  interventions : Map[String, Intervention],
  noise_data : @api.DataFrame,
) -> @api.DataFrame {
  let mut samples = @api.DataFrame::new([], Map([]))
  for node in causal_model.graph.topological_order() {
    let values = whatif_counterfactual_values(
      causal_model, node, samples, noise_data,
    )
    samples = whatif_store_values(samples, node, interventions, values)
  }
  samples
}

///|
/// The values of a node of the interventional distribution.
///
/// A root node keeps the values it has in the data and a node with parents is
/// drawn again from its causal mechanism, with the values its parents have
/// after the intervention.
fn whatif_node_values(
  causal_model : ProbabilisticCausalModel,
  node : String,
  samples : @api.DataFrame,
  rng : @utils.Random,
) -> WhatIfValues {
  if is_root_node(causal_model, node) {
    if samples.is_discrete(node) {
      return Categories(samples.discrete(node))
    }
    return Numbers(samples.numeric(node))
  }
  let parents = causal_model.graph.predecessors(node)
  let x = whatif_design_matrix(causal_model, node, samples, parents)
  let mechanism = whatif_mechanism(causal_model, node)
  if is_classifier_kind(mechanism.kind()) {
    Categories(mechanism.draw_categorical_samples(x, rng))
  } else {
    Numbers(mechanism.draw_samples(x, rng))
  }
}

///|
/// The values of a node of the counterfactual distribution.
///
/// A root node takes the value of its noise and a node with parents takes the
/// value its causal mechanism gives for the values of its parents and for its
/// noise.
fn whatif_counterfactual_values(
  causal_model : ProbabilisticCausalModel,
  node : String,
  samples : @api.DataFrame,
  noise_data : @api.DataFrame,
) -> WhatIfValues {
  if is_root_node(causal_model, node) {
    if noise_data.is_discrete(node) {
      return Categories(noise_data.discrete(node))
    }
    return Numbers(noise_data.numeric(node))
  }
  let parents = causal_model.graph.predecessors(node)
  let x = whatif_design_matrix(causal_model, node, samples, parents)
  let mechanism = whatif_mechanism(causal_model, node)
  let noise = noise_data.numeric(node)
  if is_classifier_kind(mechanism.kind()) {
    Categories(mechanism.evaluate_categorical(x, noise))
  } else {
    Numbers(mechanism.evaluate(x, noise))
  }
}

///|
/// The values of a node, with the intervention of the node applied to them.
///
/// The values of a node that is affected by an intervention replace the values
/// of the data, even when the node has no intervention of its own, because the
/// node is drawn again from its causal mechanism.
fn whatif_store_values(
  samples : @api.DataFrame,
  node : String,
  interventions : Map[String, Intervention],
  values : WhatIfValues,
) -> @api.DataFrame {
  match values {
    Numbers(numbers) =>
      match interventions.get(node) {
        Some(intervention) =>
          samples.with_numeric(node, apply_to_numbers(intervention, numbers))
        None => samples.with_numeric(node, numbers)
      }
    Categories(categories) =>
      match interventions.get(node) {
        Some(intervention) =>
          samples.with_discrete(
            node,
            apply_to_categories(intervention, categories),
          )
        None => samples.with_discrete(node, categories)
      }
  }
}

///|
/// The nodes that are affected by an intervention.
///
/// This is the port of `dowhy.gcm.whatif._get_nodes_affected_by_intervention`.
/// The affected nodes are the nodes of the interventions and all their
/// descendants.
fn whatif_affected_nodes(
  causal_model : ProbabilisticCausalModel,
  interventions : Map[String, Intervention],
) -> Set[String] {
  let affected : Set[String] = Set::Set([])
  for node in interventions.keys() {
    affected.add(node)
  }
  for node in causal_model.graph.topological_order() {
    for target in interventions.keys() {
      if causal_model.graph.has_path(target, node) {
        affected.add(node)
      }
    }
  }
  affected
}

///|
/// The nodes of the graph that have a directed path to the target node.
///
/// This is the port of `dowhy.graph.node_connected_subgraph_view`, which the
/// upstream uses to restrict the model to the ancestors of the target node.
fn whatif_ancestors_of(
  causal_model : ProbabilisticCausalModel,
  target_node : String,
) -> Array[String] {
  let ancestors = causal_model.graph.ancestors(target_node)
  let names : Array[String] = []
  for node in causal_model.graph.topological_order() {
    if node == target_node || ancestors.contains(node) {
      names.push(node)
    }
  }
  names
}

///|
/// The model that is restricted to the given nodes.
///
/// This is the port of the `node_connected_subgraph_view` of the upstream, which
/// is a view of the graph of the model: the view keeps the mechanisms of the
/// nodes it holds, so the restricted model shares them with the model of the
/// caller and uses the fitted ones.
fn whatif_restricted_model(
  causal_model : ProbabilisticCausalModel,
  names : Array[String],
) -> ProbabilisticCausalModel {
  let graph = causal_model.graph.subgraph(names)
  let model = ProbabilisticCausalModel::new(graph)
  for node in names {
    match causal_model.causal_mechanism(node) {
      Some(mechanism) => model.set_causal_mechanism(node, mechanism)
      None => ()
    }
    match causal_model.root_model(node) {
      Some(root_model) => model.set_root_model(node, root_model)
      None => ()
    }
    match causal_model.encoder_of(node) {
      Some(encoder) => model.set_encoder(node, encoder)
      None => ()
    }
  }
  model
}

///|
/// The values of the target node, as numbers.
///
/// A categorical target is counted as zero and one, the way the upstream
/// counts the classes of a binary target.
fn whatif_target_values(
  causal_model : ProbabilisticCausalModel,
  target_node : String,
  samples : @api.DataFrame,
) -> Array[Double] {
  if !samples.is_discrete(target_node) {
    return samples.numeric(target_node)
  }
  let classes = whatif_target_classes(causal_model, target_node, samples)
  if classes.length() != 2 {
    abort(
      "the target node of the average causal effect has to be a continuous variable or a categorical variable with two classes",
    )
  }
  let values : Array[Double] = []
  for value in samples.discrete(target_node) {
    if value == classes[0] {
      values.push(0.0)
    } else if value == classes[1] {
      values.push(1.0)
    } else {
      abort(
        "the target node holds a class that its causal mechanism does not know",
      )
    }
  }
  values
}

///|
/// The classes of a categorical target node.
///
/// This is the port of the class names of the upstream, which are the classes
/// of the classifier of the target node.
fn whatif_target_classes(
  causal_model : ProbabilisticCausalModel,
  target_node : String,
  samples : @api.DataFrame,
) -> Array[String] {
  match causal_model.causal_mechanism(target_node) {
    Some(mechanism) =>
      if is_classifier_kind(mechanism.kind()) {
        mechanism.classifier_model().classes()
      } else {
        whatif_distinct_labels(samples.discrete(target_node))
      }
    None => whatif_distinct_labels(samples.discrete(target_node))
  }
}

///|
/// The distinct values of the labels, in lexicographic order.
fn whatif_distinct_labels(labels : Array[String]) -> Array[String] {
  let distinct : Array[String] = []
  for label in labels {
    if !distinct.contains(label) {
      distinct.push(label)
    }
  }
  distinct.sort_by(fn(a, b) { a.lexical_compare(b) })
  distinct
}

///|
/// Check that every node of the interventions is in the graph of the model.
///
/// This is the port of `dowhy.graph.validate_node_in_graph`.
fn whatif_validate_interventions(
  causal_model : ProbabilisticCausalModel,
  interventions : Map[String, Intervention],
) -> Unit {
  for node in interventions.keys() {
    if !causal_model.graph.has_node(node) {
      abort("the node " + node + " is not in the graph of the causal model")
    }
  }
}

///|
/// The design matrix of the parents of a node.
fn whatif_design_matrix(
  causal_model : ProbabilisticCausalModel,
  node : String,
  data : @api.DataFrame,
  parents : Array[String],
) -> @utils.Matrix {
  match causal_model.encoder_of(node) {
    Some(encoder) => encoder.design_matrix(data, parents)
    None =>
      abort(
        "the node " +
        node +
        " has parents and needs an encoder, but it has none; fit the causal model first",
      )
  }
}

///|
/// The causal mechanism of a node.
fn whatif_mechanism(
  causal_model : ProbabilisticCausalModel,
  node : String,
) -> CausalMechanism {
  match causal_model.causal_mechanism(node) {
    Some(mechanism) => mechanism
    None =>
      abort(
        "the node " +
        node +
        " has parents and needs a causal mechanism, but it has none",
      )
  }
}
