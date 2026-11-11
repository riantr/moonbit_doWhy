///|
/// The automatic assignment of the causal mechanisms of a causal model.
///
/// This is the port of `dowhy.gcm.auto`. The upstream picks the causal
/// mechanism of every node of a causal model from the data: a root node gets
/// the empirical distribution of its column, and a node with parents gets the
/// additive noise model, the discrete additive noise model or the categorical
/// model, depending on the kind of the data of the column.
///
/// The port follows the same rules. The upstream selects the model of a node
/// by cross validation out of a whole zoo of scikit-learn estimators; the port
/// selects it out of the models of the `gcm` package, the selection being the
/// port of `dowhy.gcm.auto.select_model`. The `BEST` quality of the upstream
/// needs the optional AutoGluon dependency, so the port replaces the model of
/// the upstream with the model that selects itself out of the models of the
/// `gcm` package.

///|
/// The quality of the automatic model selection.
///
/// This is the port of `dowhy.gcm.auto.AssignmentQuality`. The upstream uses
/// the quality to choose how large the zoo of the models that the selection
/// evaluates is: the `Good` quality evaluates a small zoo, the `Better`
/// quality a larger one and the `Best` quality uses an AutoGluon model, which
/// needs the optional AutoGluon dependency.
///
/// The deviation of the port is that its zoo holds the models of the `gcm`
/// package, so the `Good` quality and the `Better` quality differ by the
/// polynomial regression alone. The `Best` quality holds the model that
/// selects itself out of the models of the `gcm` package, which is the port
/// of the model of AutoGluon that the upstream uses for it.
pub enum AssignmentQuality {
  ///
  /// The small set of models of the upstream.
  Good
  ///
  /// The larger set of models of the upstream.
  Better
  ///
  /// The model that selects itself, which the port has instead of the model of
  /// AutoGluon.
  Best
}

///|
/// The small set of models of the upstream.
///
/// This is the port of `AssignmentQuality.GOOD` of `dowhy.gcm.auto`.
pub fn AssignmentQuality::good() -> AssignmentQuality {
  Good
}

///|
/// The larger set of models of the upstream.
///
/// This is the port of `AssignmentQuality.BETTER` of `dowhy.gcm.auto`.
pub fn AssignmentQuality::better() -> AssignmentQuality {
  Better
}

///|
/// The model that selects itself.
///
/// This is the port of `AssignmentQuality.BEST` of `dowhy.gcm.auto`. The
/// upstream needs the optional AutoGluon dependency for it; the port uses the
/// model that selects itself out of the models of the `gcm` package.
pub fn AssignmentQuality::best() -> AssignmentQuality {
  Best
}

///|
/// The summary of the automatic assignment.
///
/// This is the port of `dowhy.gcm.auto.AutoAssignmentSummary`. The upstream
/// keeps the messages and the performances of the models of every node in a
/// dictionary; the port keeps an entry for every node, in the order the nodes
/// were assigned.
pub struct AutoAssignmentSummary {
  /// The entries of the nodes, in the order the nodes were assigned.
  entries : Array[SummaryEntry]
}

///|
/// The summary of one node of the automatic assignment.
pub struct SummaryEntry {
  /// The name of the node.
  node : String
  /// The messages of the node.
  messages : Array[String]
  /// The performances of the models that were evaluated for the node.
  performances : Array[ModelPerformance]
}

///|
/// The messages of every node, in the order the nodes were assigned.
///
/// The returned array is a copy, so a caller may modify it without changing
/// the summary.
pub fn AutoAssignmentSummary::messages(
  self : AutoAssignmentSummary,
) -> Array[String] {
  let out : Array[String] = []
  for entry in self.entries {
    for message in entry.messages {
      out.push(message)
    }
  }
  out
}

///|
/// The names of the nodes, in the order the nodes were assigned.
pub fn AutoAssignmentSummary::nodes(
  self : AutoAssignmentSummary,
) -> Array[String] {
  let out : Array[String] = []
  for entry in self.entries {
    out.push(entry.node)
  }
  out
}

///|
/// The messages of one node.
///
/// The returned array is a copy, so a caller may modify it without changing
/// the summary.
pub fn AutoAssignmentSummary::messages_of(
  self : AutoAssignmentSummary,
  node : String,
) -> Array[String] {
  for entry in self.entries {
    if entry.node == node {
      return entry.messages.copy()
    }
  }
  []
}

///|
/// The performances of the models that were evaluated for one node.
///
/// The returned array is a copy, so a caller may modify it without changing
/// the summary. A root node has no performances, because the upstream
/// evaluates no model for it.
pub fn AutoAssignmentSummary::model_performances_of(
  self : AutoAssignmentSummary,
  node : String,
) -> Array[ModelPerformance] {
  for entry in self.entries {
    if entry.node == node {
      return entry.performances.copy()
    }
  }
  []
}

///|
/// A readable description of the summary.
///
/// This is the port of `dowhy.gcm.auto.AutoAssignmentSummary.__str__`. The
/// upstream describes the kinds of the mechanisms it considers, the nodes it
/// assigned and the performances of the models it evaluated for them.
pub fn AutoAssignmentSummary::to_string(self : AutoAssignmentSummary) -> String {
  let mut out = "When using this auto assignment function, the given data is used to automatically assign a causal mechanism to each node. Note that causal mechanisms can also be customized and assigned manually.\n"
  out = out +
    "The following types of causal mechanisms are considered for the automatic selection:\n"
  out = out + "\nIf root node:\n"
  out = out +
    "An empirical distribution, i.e., the distribution is represented by randomly sampling from the provided data. This provides a flexible and non-parametric way to model the marginal distribution and is valid for all types of data modalities.\n"
  out = out + "\nIf non-root node and the data is continuous:\n"
  out = out +
    "Additive Noise Models (ANM) of the form X_i = f(PA_i) + N_i, where PA_i are the parents of X_i and the unobserved noise N_i is assumed to be independent of PA_i.To select the best model for f, different regression models are evaluated and the model with the smallest mean squared error is selected.Note that minimizing the mean squared error here is equivalent to selecting the best choice of an ANM.\n"
  out = out + "\nIf non-root node and the data is discrete:\n"
  out = out +
    "Discrete Additive Noise Models have almost the same definition as non-discrete ANMs, but come with an additional constraint for f to only return discrete values.\nNote that 'discrete' here refers to numerical values with an order. If the data is categorical, consider representing them as strings to ensure proper model selection.\n"
  out = out + "\nIf non-root node and the data is categorical:\n"
  out = out +
    "A functional causal model based on a classifier, i.e., X_i = f(PA_i, N_i).\nHere, N_i follows a uniform distribution on [0, 1] and is used to randomly sample a class (category) using the conditional probability distribution produced by a classification model. Here, different model classes are evaluated using the log loss metric and the best performing model class is selected.\n"
  out = out +
    "\nIn total, " +
    self.nodes().length().to_string() +
    " nodes were analyzed:\n"
  for entry in self.entries {
    out = out + "\n--- Node: " + entry.node + "\n"
    for message in entry.messages {
      out = out + message + "\n"
    }
    if entry.performances.length() > 0 {
      out = out +
        "For the model selection, the following models were evaluated on the " +
        entry.performances[0].metric() +
        " metric:\n"
      for performance in entry.performances {
        out = out +
          performance.model() +
          ": " +
          performance.performance().to_string() +
          "\n"
      }
    }
  }
  out = out + "\n===Note===\n"
  out = out +
    "Note, based on the selected auto assignment quality, the set of evaluated models changes.\n"
  out = out +
    "For more insights toward the quality of the fitted graphical causal model, consider using the evaluate_causal_model function after fitting the causal mechanisms."
  out
}

///|
/// Assign a causal mechanism to every node of the model.
///
/// This is the port of `dowhy.gcm.auto.assign_causal_mechanisms`. The nodes
/// are visited in the topological order of the graph of the model, so that a
/// node is assigned after its parents. A node that already has a causal
/// mechanism or a distribution is left alone when `override_models` is false,
/// and its assignment is validated against the graph instead; it is assigned
/// again when `override_models` is true.
///
/// The deviations from the upstream are the following ones. The upstream
/// reports the performances of the models it evaluated; the port reports them
/// as well, and they are the performances of the models of the port. The
/// upstream takes the experimental flag `experimental_allow_nans`, which the
/// port takes as well: the assignment stops when the data holds a missing
/// value and the flag is not set, the way the upstream raises. The upstream
/// fits its models on the rows that hold no missing value in their target and
/// keeps the rows whose features hold a missing value, because its histogram
/// gradient boosting model reads them; the port has no model that reads them,
/// so it drops the rows that hold a missing value in a feature as well. The
/// upstream shuffles the rows of the cross validation of the selection with
/// the global generator of numpy; the port shuffles them with its own
/// generator, whose seed is the argument of the function.
pub fn assign_causal_mechanisms(
  causal_model : ProbabilisticCausalModel,
  based_on : @api.DataFrame,
  quality : AssignmentQuality,
  override_models : Bool,
  seed~ : UInt64 = 0UL,
  allow_nans~ : Bool = false,
) -> AutoAssignmentSummary {
  if !allow_nans && based_on.has_missing_values() {
    abort(
      "Data contains NaN! This is currently only supported when setting experimental_allow_nans to True and only for missing data in numerical features. Note that not all GCM features support missing data yet!",
    )
  }
  let summary : AutoAssignmentSummary = { entries: [], }
  for node in causal_model.graph.topological_order() {
    if !override_models && causal_model.has_causal_mechanism(node) {
      validate_causal_model_assignment(causal_model, node)
      summary.entries.push({
        node,
        messages: [
          "Node " +
          node +
          " already has a causal mechanism assigned and the override parameter is False. Skipping this node.",
        ],
        performances: [],
      })
      continue
    }
    let performances = assign_causal_mechanism_node(
      causal_model,
      node,
      based_on,
      quality,
      seed~,
    )
    let messages : Array[String] = []
    messages.push(auto_kind_of_data_message(causal_model, node))
    if !is_root_node(causal_model, node) {
      messages.push(auto_relationship_message(causal_model, node))
    }
    messages.push(auto_assigned_model_message(causal_model, node))
    summary.entries.push({ node, messages, performances, })
  }
  summary
}

///|
/// Assign a causal mechanism to one node of the model.
///
/// This is the port of `dowhy.gcm.auto.assign_causal_mechanism_node`. A root
/// node gets the marginal distribution of its column, which is the empirical
/// distribution of the column, or the empirical categorical distribution when
/// the column holds strings. A node with parents gets the model the selection
/// picked, which is the additive noise model, the discrete additive noise
/// model when every value of the column is a whole number, or the categorical
/// model when the column holds strings.
///
/// The function returns the performances of the models the selection
/// evaluated, the way the upstream returns them.
pub fn assign_causal_mechanism_node(
  causal_model : ProbabilisticCausalModel,
  node : String,
  based_on : @api.DataFrame,
  quality : AssignmentQuality,
  seed~ : UInt64 = 0UL,
) -> Array[ModelPerformance] {
  if is_root_node(causal_model, node) {
    if based_on.is_discrete(node) {
      causal_model.set_root_model(
        node,
        StochasticModel::empirical_categorical(),
      )
    } else {
      causal_model.set_root_model(node, StochasticModel::empirical())
    }
    return []
  }
  let parents = causal_model.graph.ordered_predecessors(node)
  // The rows that hold a missing value are left out of the selection, the way
  // the upstream leaves the rows whose target holds a missing value out of it.
  let frame = based_on.select(parents + [node])
  let complete = frame.complete_rows()
  let selection = select_model(
    frame.select(parents).take_rows(complete),
    frame.select([node]).take_rows(complete),
    quality,
    seed,
  )
  let performances = selection.performances()
  match selection.model() {
    SelectedModel::Classification(classifier) =>
      causal_model.set_causal_mechanism(
        node,
        CausalMechanism::classifier(classifier),
      )
    SelectedModel::Regression(regression) =>
      if is_discrete(based_on.numeric(node)) {
        causal_model.set_causal_mechanism(
          node,
          CausalMechanism::discrete_additive_noise(regression),
        )
      } else {
        causal_model.set_causal_mechanism(
          node,
          CausalMechanism::additive_noise(regression),
        )
      }
  }
  performances
}

///|
/// The message that names the kind of the data of the node and the model that
/// was assigned to it.
fn auto_kind_of_data_message(
  causal_model : ProbabilisticCausalModel,
  node : String,
) -> String {
  if is_root_node(causal_model, node) {
    return "Node " +
      node +
      " is a root node. Therefore, assigning '" +
      auto_root_model_name(causal_model, node) +
      "' to the node representing the marginal distribution."
  }
  "Node " +
  node +
  " is a non-root node with " +
  auto_data_type(causal_model, node) +
  " data. Assigning '" +
  auto_mechanism_name(causal_model, node) +
  "' to the node."
}

///|
/// The kind of the data of the node, as the upstream names it.
fn auto_data_type(
  causal_model : ProbabilisticCausalModel,
  node : String,
) -> String {
  match causal_model.causal_mechanism(node) {
    Some(mechanism) => {
      let kind = mechanism.kind()
      if is_classifier_kind(kind) {
        "categorical"
      } else if is_discrete_additive_noise_kind(kind) {
        "discrete"
      } else {
        "continuous"
      }
    }
    None => "continuous"
  }
}

///|
/// The message that shows the causal relationship of the node.
fn auto_relationship_message(
  causal_model : ProbabilisticCausalModel,
  node : String,
) -> String {
  let parents = auto_parent_names(causal_model, node)
  let categorical = match causal_model.causal_mechanism(node) {
    Some(mechanism) => is_classifier_kind(mechanism.kind())
    None => false
  }
  let discrete = match causal_model.causal_mechanism(node) {
    Some(mechanism) => is_discrete_additive_noise_kind(mechanism.kind())
    None => false
  }
  let mut out = if discrete {
    "This represents the discrete causal relationship as "
  } else {
    "This represents the causal relationship as "
  }
  out = out + node
  out = out + " := f("
  out = out + parents
  if categorical {
    out = out + ",N)."
  } else {
    out = out + ") + N."
  }
  out
}

///|
/// The parents of the node, separated by commas.
fn auto_parent_names(
  causal_model : ProbabilisticCausalModel,
  node : String,
) -> String {
  let mut names = ""
  let parents = causal_model.graph.ordered_predecessors(node)
  for i = 0; i < parents.length(); i = i + 1 {
    if i > 0 {
      names = names + ","
    }
    names = names + parents[i]
  }
  names
}

///|
/// The message that names the model that was assigned to the node.
fn auto_assigned_model_message(
  causal_model : ProbabilisticCausalModel,
  node : String,
) -> String {
  if is_root_node(causal_model, node) {
    return "Assigning '" +
      auto_root_model_name(causal_model, node) +
      "' to the node representing the marginal distribution."
  }
  "Assigning '" + auto_mechanism_name(causal_model, node) + "' to the node."
}

///|
/// The name of the distribution of a root node.
fn auto_root_model_name(
  causal_model : ProbabilisticCausalModel,
  node : String,
) -> String {
  match causal_model.root_model(node) {
    Some(model) =>
      match model.kind() {
        Empirical => "Empirical Distribution"
        // The upstream has a single empirical distribution, which samples the
        // discrete values of a column of categories as well, so the port names
        // the categorical distribution the same way.
        EmpiricalCategorical => "Empirical Distribution"
        Normal => "norm distribution"
        Laplace => "laplace distribution"
        Uniform => "uniform distribution"
        Beta => "beta distribution"
      }
    None => "no distribution"
  }
}

///|
/// The name of the causal mechanism of a node.
fn auto_mechanism_name(
  causal_model : ProbabilisticCausalModel,
  node : String,
) -> String {
  match causal_model.causal_mechanism(node) {
    Some(mechanism) =>
      match mechanism.kind() {
        AdditiveNoise =>
          "AdditiveNoiseModel using " +
          regression_model_name(mechanism.prediction_model())
        DiscreteAdditiveNoise =>
          "Discrete AdditiveNoiseModel using " +
          regression_model_name(mechanism.prediction_model())
        PostNonlinear =>
          "PostNonlinearModel with " +
          regression_model_name(mechanism.prediction_model()) +
          " and an identity"
        Classifier =>
          "Classifier FCM based on " +
          classification_model_name(mechanism.classifier_model())
      }
    None => "no causal mechanism"
  }
}
