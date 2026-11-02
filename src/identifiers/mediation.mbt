/// The mediation identification of a causal graph.
///
/// This is the port of the mediation part of
/// `dowhy.causal_identifier.auto_identifier`: the search of a mediator of
/// `identify_mediation`, the two searches of the confounders of the two stages
/// of a mediation and the estimand of `identify_nie_effect`.
///
/// One deliberate difference to the Python code is documented where it occurs:
/// the candidate mediators are enumerated in sorted order, while the Python
/// code iterates over a `set`, so its order is hash dependent.

///|
/// The mediator variables of the graph.
///
/// The mediator is the descendant of the treatment that blocks one of the
/// directed paths from the treatment to the outcome; the first one in sorted
/// order wins. The result is empty when the graph holds no such variable.
///
/// This is the port of `identify_mediation` of the upstream.
pub fn identify_mediation(
  graph : @graph.DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
) -> Array[String] {
  let mediation_paths = @graph.get_all_directed_paths(
    graph, action_nodes, outcome_nodes,
  )
  let excluded : Set[String] = Set::Set([])
  for node in outcome_nodes {
    excluded.add(node)
  }
  // The eligible variables are the descendants of the treatment without the
  // outcome.
  let eligible : Array[String] = []
  for node in graph.descendants_of(action_nodes).to_array() {
    if excluded.contains(node) {
      continue
    }
    eligible.push(node)
  }
  let eligible = sorted_unique(eligible)
  for candidate in eligible {
    if @graph.check_valid_mediation_set(
        graph,
        action_nodes,
        outcome_nodes,
        [candidate],
        mediation_paths,
      ) {
      return [candidate]
    }
  }
  []
}

///|
/// The confounders of the first stage of a mediation.
///
/// The first stage regresses the mediator on the treatment, so its confounders
/// are the backdoor adjustment set of the treatment and the mediator.
///
/// This is the port of `identify_mediation_first_stage_confounders` of the
/// upstream. The registry holds every set the search found, keyed by its name,
/// and the default set of them under the plain `backdoor` name.
pub fn identify_mediation_first_stage_confounders(
  graph : @graph.DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
  mediator_nodes : Array[String],
  observed_nodes : Array[String],
  backdoor_adjustment : String,
) -> Map[String, Array[String]] {
  mediation_stage_confounders(
    graph, action_nodes, mediator_nodes, action_nodes, outcome_nodes, observed_nodes,
    backdoor_adjustment,
  )
}

///|
/// The confounders of the second stage of a mediation.
///
/// The second stage regresses the outcome on the mediator, so its confounders
/// are the backdoor adjustment set of the mediator and the outcome.
///
/// This is the port of `identify_mediation_second_stage_confounders` of the
/// upstream. The registry holds every set the search found, keyed by its name,
/// and the default set of them under the plain `backdoor` name.
pub fn identify_mediation_second_stage_confounders(
  graph : @graph.DirectedGraph,
  action_nodes : Array[String],
  mediator_nodes : Array[String],
  outcome_nodes : Array[String],
  observed_nodes : Array[String],
  backdoor_adjustment : String,
) -> Map[String, Array[String]] {
  mediation_stage_confounders(
    graph, mediator_nodes, outcome_nodes, action_nodes, outcome_nodes, observed_nodes,
    backdoor_adjustment,
  )
}

///|
/// The confounders of one stage of a mediation.
///
/// The stage regresses `stage_outcome` on `stage_treatment`, so its confounders
/// are the backdoor adjustment set of the two. The default set of the registry
/// is the one the upstream picks with the treatment and the outcome of the
/// whole effect, so the two stages use the same rule.
fn mediation_stage_confounders(
  graph : @graph.DirectedGraph,
  stage_treatment : Array[String],
  stage_outcome : Array[String],
  default_treatment : Array[String],
  default_outcome : Array[String],
  observed_nodes : Array[String],
  backdoor_adjustment : String,
) -> Map[String, Array[String]] {
  let (sets, message) = identify_backdoor(
    graph, stage_treatment, stage_outcome, observed_nodes, backdoor_adjustment,
  )
  if message != "" {
    abort(message)
  }
  let registry = adjustment_registry(sets, observed_nodes)
  let default_id = default_adjustment_set_id(
    graph, default_treatment, default_outcome, registry,
  )
  let confounders : Map[String, Array[String]] = Map([])
  for entry in registry {
    let (key, variables) = entry
    confounders.set(key, variables)
  }
  let default_variables = match confounders.get(default_id) {
    Some(variables) => variables
    None => []
  }
  confounders.set("backdoor", default_variables)
  confounders
}

///|
/// The estimand of the natural indirect effect.
///
/// This is the port of `identify_nie_effect` of the upstream: the registry of
/// the estimands holds the mediation estimand only, and the confounders of the
/// two stages of the mediation are the ones the two stage regression estimator
/// uses.
///
/// The natural direct effect is not ported; the upstream computes it with a
/// third model, which the port does not have.
pub fn identify_nie_effect(
  graph : @graph.DirectedGraph,
  action_nodes : Array[String],
  outcome_nodes : Array[String],
  observed_nodes : Array[String],
  backdoor_adjustment : String,
) -> IdentifiedEstimand {
  let (backdoor_sets, message) = identify_backdoor(
    graph, action_nodes, outcome_nodes, observed_nodes, backdoor_adjustment,
  )
  if message != "" {
    abort(message)
  }
  let estimand = IdentifiedEstimand::new(action_nodes, outcome_nodes)
  estimand.set_estimand_type("nonparametric-nie")
  // The backdoor sets are kept, but they are not part of the registry of the
  // estimands: the upstream resets the registry before it looks for the
  // mediators.
  let registry = adjustment_registry(backdoor_sets, observed_nodes)
  let default_id = default_adjustment_set_id(
    graph, action_nodes, outcome_nodes, registry,
  )
  for entry in registry {
    let (key, variables) = entry
    estimand.set_adjustment_set(variables, key)
  }
  let mut default_variables : Array[String] = []
  for entry in registry {
    let (key, variables) = entry
    if key == default_id {
      default_variables = variables
    }
  }
  estimand.set_adjustment_set(default_variables, "backdoor")
  // The mediator of the effect and the two stages that estimate it.
  let mediators = identify_mediation(graph, action_nodes, outcome_nodes)
  estimand.set_mediator_variables(mediators.copy())
  if mediators.length() > 0 {
    estimand.set_estimand(
      "mediation",
      mediation_assumptions(action_nodes, outcome_nodes, mediators),
    )
    let first_stage = identify_mediation_first_stage_confounders(
      graph, action_nodes, outcome_nodes, mediators, observed_nodes, backdoor_adjustment,
    )
    let second_stage = identify_mediation_second_stage_confounders(
      graph, action_nodes, mediators, outcome_nodes, observed_nodes, backdoor_adjustment,
    )
    estimand.set_mediation_first_stage_confounders(first_stage)
    estimand.set_mediation_second_stage_confounders(second_stage)
  }
  estimand
}

///|
/// The assumptions of a mediation estimand.
///
/// This is the port of `construct_mediation_estimand` of the upstream.
fn mediation_assumptions(
  treatment_names : Array[String],
  outcome_names : Array[String],
  mediator_names : Array[String],
) -> Array[String] {
  let treatment = join_names(treatment_names)
  let outcome = join_names(outcome_names)
  let first_outcome = outcome_names[0]
  let mediator = join_names(mediator_names)
  [
    "Mediation: " +
    mediator +
    " intercepts (blocks) all directed paths from " +
    treatment +
    " to " +
    outcome +
    " except the path {" +
    treatment +
    "}→{" +
    outcome +
    "}.",
    "First-stage-unconfoundedness: If U→{" +
    treatment +
    "} and U→{" +
    mediator +
    "} then P(" +
    mediator +
    "|" +
    treatment +
    ",U) = P(" +
    mediator +
    "|" +
    treatment +
    ")",
    "Second-stage-unconfoundedness: If U→{" +
    mediator +
    "} and U→" +
    first_outcome +
    " then P(" +
    first_outcome +
    "|" +
    mediator +
    ", " +
    treatment +
    ", U) = P(" +
    first_outcome +
    "|" +
    mediator +
    ", " +
    treatment +
    ")",
  ]
}
