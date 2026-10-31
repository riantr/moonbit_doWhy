///|
/// The fitting and the sampling of the graphical causal models of the `gcm`
/// package.
///
/// This is the port of `dowhy.gcm.fitting_sampling`. The upstream module fits
/// the causal mechanism of every node of a model on the data and draws new
/// joint samples from the fitted model.
///
/// The upstream fits the mechanisms with the mechanisms of
/// `dowhy.gcm.causal_mechanisms` and encodes the discrete parents with the
/// one-hot encoder of `dowhy.gcm.util.general`; the port fits them with the
/// mechanisms of `causal_mechanisms.mbt` and encodes the discrete parents with
/// the `ParentEncoder` of `encoding.mbt`, which is the same encoding.

///|
/// Fit the causal mechanism of every node of the model on the given data.
///
/// This is the port of `dowhy.gcm.fitting_sampling.fit`. The mechanism of
/// every node is fitted on its own, because of the modularity assumption: a
/// root node is fitted on the column of the node itself, and a node with
/// parents is fitted on the design matrix of its parents and on the column of
/// the node.
///
/// The model is changed in place, like the upstream one: the mechanisms of the
/// model are replaced by the fitted ones. A model that has to be kept
/// unchanged is a copy of the model, which `ProbabilisticCausalModel::clone`
/// builds.
///
/// The data has to hold a column for every node of the graph; the node whose
/// column is missing stops the fit. `has_data_for_every_node` tells whether
/// the data is complete.
pub fn fit(
  causal_model : ProbabilisticCausalModel,
  data : @api.DataFrame,
) -> Unit {
  for node in causal_model.graph.topological_order() {
    if !data.has_column(node) {
      abort(
        "could not find data for the node " +
        node +
        " in the given training data; there should be a column with the samples of the node " +
        node,
      )
    }
    fit_causal_model_of_target(causal_model, node, data)
  }
}

///|
/// Fit the causal mechanism of one node of the model on the given data.
///
/// This is the port of
/// `dowhy.gcm.fitting_sampling.fit_causal_model_of_target`. The mechanism of
/// the node is fitted on the column of the node, and on the design matrix of
/// its parents when the node has parents. The parents a node is fitted with
/// are recorded, so that the structure of the graph can be validated before
/// the model is sampled.
pub fn fit_causal_model_of_target(
  causal_model : ProbabilisticCausalModel,
  target_node : String,
  training_data : @api.DataFrame,
) -> Unit {
  validate_causal_model_assignment(causal_model, target_node)
  let parents = causal_model.graph.predecessors(target_node)
  if is_root_node(causal_model, target_node) {
    let root_model = match causal_model.root_model(target_node) {
      Some(model) => model
      None =>
        abort(
          "the node " +
          target_node +
          " is a root and needs a distribution, but it has none",
        )
    }
    if training_data.is_discrete(target_node) {
      if !fitting_is_categorical(root_model) {
        abort(
          "the root model of the node " +
          target_node +
          " has to be a categorical distribution, because the column of the node holds strings",
        )
      }
      let fitted = root_model.fit_categorical(
        training_data.discrete(target_node),
      )
      causal_model.set_root_model(target_node, fitted)
    } else {
      if fitting_is_categorical(root_model) {
        abort(
          "the root model of the node " +
          target_node +
          " has to be a continuous distribution, because the column of the node holds numbers",
        )
      }
      let fitted = root_model.fit(training_data.numeric(target_node))
      causal_model.set_root_model(target_node, fitted)
    }
  } else {
    let encoder = ParentEncoder::fit(training_data, parents)
    causal_model.set_encoder(target_node, encoder)
    let x = encoder.design_matrix(training_data, parents)
    let mechanism = match causal_model.causal_mechanism(target_node) {
      Some(mechanism) => mechanism
      None =>
        abort(
          "the node " +
          target_node +
          " has parents and needs a causal mechanism, but it has none",
        )
    }
    if training_data.is_discrete(target_node) {
      if !is_classifier_kind(mechanism.kind()) {
        abort(
          "the causal mechanism of the node " +
          target_node +
          " has to be a classifier, because the column of the node holds strings",
        )
      }
      let fitted = mechanism.fit_categorical(
        x,
        training_data.discrete(target_node),
      )
      causal_model.set_causal_mechanism(target_node, fitted)
    } else {
      if is_classifier_kind(mechanism.kind()) {
        abort(
          "the causal mechanism of the node " +
          target_node +
          " has to be a continuous mechanism, because the column of the node holds numbers",
        )
      }
      let fitted = mechanism.fit(x, training_data.numeric(target_node))
      causal_model.set_causal_mechanism(target_node, fitted)
    }
  }
  causal_model.set_parents_during_fit(target_node, parents)
}

///|
/// Draw new joint samples from the model.
///
/// This is the port of `dowhy.gcm.fitting_sampling.draw_samples`. The samples
/// of the root nodes are drawn first and the causal effects are propagated
/// through the graph afterwards, so the result holds one row per drawn sample
/// and one column per node of the graph.
///
/// The upstream draws the samples from the global numpy generator; the port
/// draws them from the given generator, so that the same generator always
/// gives the same samples.
pub fn draw_samples(
  causal_model : ProbabilisticCausalModel,
  num_samples : Int32,
  rng : @utils.Random,
) -> @api.DataFrame {
  validate_causal_dag(causal_model)
  let nodes = causal_model.graph.topological_order()
  let mut frame = @api.DataFrame::new([], Map([]))
  for node in nodes {
    let parents = causal_model.graph.predecessors(node)
    if is_root_node(causal_model, node) {
      let root_model = match causal_model.root_model(node) {
        Some(model) => model
        None =>
          abort(
            "the node " +
            node +
            " is a root and needs a distribution, but it has none",
          )
      }
      if fitting_is_categorical(root_model) {
        frame = frame.with_discrete(
          node,
          root_model.draw_category_samples(num_samples, rng),
        )
      } else {
        frame = frame.with_numeric(
          node,
          root_model.draw_samples(num_samples, rng),
        )
      }
    } else {
      let encoder = match causal_model.encoder_of(node) {
        Some(encoder) => encoder
        None =>
          abort(
            "the node " +
            node +
            " has parents and needs an encoder, but it has none; fit the causal model first",
          )
      }
      let x = encoder.design_matrix(frame, parents)
      let mechanism = match causal_model.causal_mechanism(node) {
        Some(mechanism) => mechanism
        None =>
          abort(
            "the node " +
            node +
            " has parents and needs a causal mechanism, but it has none",
          )
      }
      if is_classifier_kind(mechanism.kind()) {
        frame = frame.with_discrete(
          node,
          mechanism.draw_categorical_samples(x, rng),
        )
      } else {
        frame = frame.with_numeric(node, mechanism.draw_samples(x, rng))
      }
    }
  }
  frame
}

///|
/// Whether the data has a column for every node of the model.
///
/// This is the predicate of the check the upstream `fit` does for every node
/// of the graph. A fit of a model whose data misses a column stops at that
/// node, and MoonBit cannot catch the stop of a function, so the check is
/// available on its own.
pub fn has_data_for_every_node(
  causal_model : ProbabilisticCausalModel,
  data : @api.DataFrame,
) -> Bool {
  for node in causal_model.graph.node_list() {
    if !data.has_column(node) {
      return false
    }
  }
  true
}

///|
/// Whether the distribution of a root node draws categories.
fn fitting_is_categorical(model : StochasticModel) -> Bool {
  match model.kind() {
    EmpiricalCategorical => true
    _ => false
  }
}
