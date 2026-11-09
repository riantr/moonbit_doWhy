/// The causal model: the entry point of the library.
///
/// This is the port of `dowhy.causal_model.CausalModel`. It ties the data,
/// the causal graph and the estimators together:
///
/// ```moonbit
/// let model = CausalModel::new(data, ["treatment"], ["outcome"], None, ["confounder"], [], [], [])
/// let estimand = model.identify_effect("backdoor")
/// let estimate = model.estimate_effect("backdoor.linear_regression", 1.0, 0.0, "ate")
/// ```
///
/// The upstream accepts a graph as a networkx graph, as a GML string, as a DOT
/// string, as the graph of the daggity web site and as the graph of a
/// probabilistic causal model. The port accepts a graph as a directed graph
/// and as a GML string, a DOT string or a daggity string.

///|
/// A causal model.
pub struct CausalModel {
  /// The data the analysis runs on.
  data : @api.DataFrame
  /// The treatment variables.
  treatment : Array[String]
  /// The outcome variables.
  outcome : Array[String]
  /// The causal graph, with the semantic role of every node.
  graph : @graph.CausalGraph
  /// The observed nodes of the graph, which are the columns of the data.
  observed_nodes : Array[String]
  /// The estimand the identification produced.
  mut estimand : @identifiers.IdentifiedEstimand
  /// The estimators the model has built, keyed by the name of the method.
  ///
  /// The estimators are stored by reference, so the estimator the cache hands
  /// out is the estimator that the estimate was computed with.
  estimator_cache : Map[String, @estimators.CausalEstimator]
  /// Whether the identification may proceed when the effect is not
  /// identifiable.
  proceed_when_unidentifiable : Bool
  /// Whether the common causes and the instruments are read from the graph.
  identify_vars : Bool
  /// The kind of the estimand the model asks for.
  estimand_type : String
}

///|
/// Build a causal model.
///
/// When `graph` is `None` the graph is built from the semantic roles of the
/// variables.
///
/// The `missing_nodes_as_confounders` flag adds the columns of the data that
/// are not part of the graph as common causes of the treatment and of the
/// outcome, the way the upstream does it.
pub fn CausalModel::new(
  data : @api.DataFrame,
  treatment : Array[String],
  outcome : Array[String],
  graph : @graph.DirectedGraph?,
  common_causes : Array[String],
  instruments : Array[String],
  effect_modifiers : Array[String],
  mediators : Array[String],
  missing_nodes_as_confounders~ : Bool = false,
  identify_vars~ : Bool = false,
  proceed_when_unidentifiable~ : Bool = false,
  estimand_type~ : String = "nonparametric-ate",
) -> CausalModel {
  let observed = data.column_names()
  let causal = @graph.CausalGraph::new(
    treatment, outcome, graph, common_causes, instruments, effect_modifiers, mediators,
    observed,
  )
  build_model(
    data, treatment, outcome, causal, observed, missing_nodes_as_confounders, identify_vars,
    proceed_when_unidentifiable, estimand_type,
  )
}

///|
/// Build a causal model whose graph is given as a string.
///
/// The string is a GML graph, a DOT graph or the graph of the daggity web
/// site. The upstream reads a graph file as well; the port has no access to
/// the file system, so the caller reads the file and hands its content to the
/// model.
///
/// The model aborts when the string is not a graph the port can read; the
/// function `is_supported_graph_format` tells whether a string is one.
pub fn CausalModel::new_with_graph_string(
  data : @api.DataFrame,
  treatment : Array[String],
  outcome : Array[String],
  graph : String,
  common_causes : Array[String],
  instruments : Array[String],
  effect_modifiers : Array[String],
  missing_nodes_as_confounders~ : Bool = false,
  identify_vars~ : Bool = false,
  proceed_when_unidentifiable~ : Bool = false,
  estimand_type~ : String = "nonparametric-ate",
) -> CausalModel {
  let parsed = match parse_graph_string(graph) {
    Some(directed) => directed
    None =>
      abort(
        "Incorrect format: Please provide graph as a GML string, a DOT string or the graph of the daggity web site.",
      )
  }
  let observed = data.column_names()
  let causal = @graph.CausalGraph::new(
    treatment,
    outcome,
    Some(parsed),
    common_causes,
    instruments,
    effect_modifiers,
    [],
    observed,
  )
  build_model(
    data, treatment, outcome, causal, observed, missing_nodes_as_confounders, identify_vars,
    proceed_when_unidentifiable, estimand_type,
  )
}

///|
/// The common model of the two constructors.
fn build_model(
  data : @api.DataFrame,
  treatment : Array[String],
  outcome : Array[String],
  causal : @graph.CausalGraph,
  observed : Array[String],
  missing_nodes_as_confounders : Bool,
  identify_vars : Bool,
  proceed_when_unidentifiable : Bool,
  estimand_type : String,
) -> CausalModel {
  if missing_nodes_as_confounders {
    let _ = causal.add_missing_nodes_as_common_causes(observed)
  }
  let estimand = @identifiers.IdentifiedEstimand::new(treatment, outcome)
  estimand.set_estimand_type(estimand_type)
  {
    data,
    treatment,
    outcome,
    graph: causal,
    observed_nodes: observed,
    estimand,
    estimator_cache: Map([]),
    proceed_when_unidentifiable,
    identify_vars,
    estimand_type,
  }
}

///|
/// Whether the identification may proceed when the effect is not identifiable.
///
/// This is the port of the `proceed_when_unidentifiable` flag of the upstream.
pub fn CausalModel::proceeds_when_unidentifiable(self : CausalModel) -> Bool {
  self.proceed_when_unidentifiable
}

///|
/// Whether the common causes and the instruments are read from the graph.
///
/// This is the port of the `identify_vars` flag of the upstream.
pub fn CausalModel::identifies_variables(self : CausalModel) -> Bool {
  self.identify_vars
}

///|
/// The kind of the estimand the model asks for.
pub fn CausalModel::estimand_type(self : CausalModel) -> String {
  self.estimand_type
}

///|
/// Whether the given string is a graph the port can read.
///
/// The strings are the GML graphs, the DOT graphs and the graphs of the
/// daggity web site, which are the formats the upstream reads as well.
pub fn is_supported_graph_format(graph : String) -> Bool {
  match parse_graph_string(graph) {
    Some(_) => true
    None => false
  }
}

///|
/// The graph of a string, when the string holds a graph the port can read.
///
/// The graph of the daggity web site is turned into a DOT graph first, the
/// way the upstream does it.
fn parse_graph_string(graph : String) -> @graph.DirectedGraph? {
  let text = graph.trim().to_owned()
  // The upstream looks for the `dag` prefix with the regular expression
  // `^dag`.
  if text.has_prefix("dag") {
    return Some(@graph.parse_dot(@graph.daggity_to_dot(text)))
  }
  // The upstream replaces the newlines of the string before it looks at it.
  let flat = text.replace_all(old="\n", new=" ")
  // The upstream looks for the DOT graph with the regular expression
  // `.*graph\s*\{.*\}\s*` and for the GML graph with the regular
  // expression `.*graph\s*\[.*\]\s*`, so the whitespace between the
  // keyword and the bracket is optional.
  if holds_graph_bracket(flat, '{') && flat.contains("}") {
    return Some(@graph.parse_dot(flat))
  }
  if holds_graph_bracket(flat, '[') && flat.contains("]") {
    return Some(@graph.parse_gml(flat))
  }
  None
}

///|
/// Whether the string holds a `graph` keyword that is followed by the given
/// bracket, with any amount of whitespace in between.
///
/// This is the port of the two regular expressions `graph\s*\{` and
/// `graph\s*\[` of the upstream.
fn holds_graph_bracket(text : String, bracket : Char) -> Bool {
  let chars = text.to_array()
  let mut i = 0
  while i + 5 <= chars.length() {
    if chars[i] == 'g' &&
      chars[i + 1] == 'r' &&
      chars[i + 2] == 'a' &&
      chars[i + 3] == 'p' &&
      chars[i + 4] == 'h' {
      let mut j = i + 5
      while j < chars.length() && chars[j].is_whitespace() {
        j = j + 1
      }
      if j < chars.length() && chars[j] == bracket {
        return true
      }
    }
    i = i + 1
  }
  false
}

///|
/// The data of the model.
pub fn CausalModel::data(self : CausalModel) -> @api.DataFrame {
  self.data
}

///|
/// The causal graph of the model.
pub fn CausalModel::causal_graph(self : CausalModel) -> @graph.DirectedGraph {
  self.graph.directed_graph()
}

///|
/// The causal graph of the model, with the semantic role of every node.
pub fn CausalModel::graph_with_roles(self : CausalModel) -> @graph.CausalGraph {
  self.graph
}

///|
/// The estimand the identification produced.
pub fn CausalModel::identified_estimand(
  self : CausalModel,
) -> @identifiers.IdentifiedEstimand {
  self.estimand
}

///|
/// The common causes of the treatment and of the outcome.
///
/// This is the port of `dowhy.causal_model.CausalModel.get_common_causes`,
/// which asks the graph for the common causes of the two variables.
pub fn CausalModel::get_common_causes(self : CausalModel) -> Array[String] {
  self.graph.get_common_causes(self.treatment, self.outcome)
}

///|
/// The instruments of the treatment.
///
/// This is the port of `dowhy.causal_model.CausalModel.get_instruments`.
pub fn CausalModel::get_instruments(self : CausalModel) -> Array[String] {
  self.graph.get_instruments(self.treatment, self.outcome)
}

///|
/// The effect modifiers of the treatment.
///
/// This is the port of `dowhy.causal_model.CausalModel.get_effect_modifiers`.
pub fn CausalModel::get_effect_modifiers(self : CausalModel) -> Array[String] {
  self.graph.get_effect_modifiers(self.treatment, self.outcome)
}

///|
/// The summary of the model.
///
/// This is the port of `dowhy.causal_model.CausalModel.summary`. The upstream
/// prints the summary and logs it; the port returns it.
pub fn CausalModel::summary(self : CausalModel) -> String {
  "Model to find the causal effect of treatment " +
  render_names(self.treatment) +
  " on outcome " +
  render_names(self.outcome)
}

///|
/// The names of the variables, the way the upstream renders a list of names.
fn render_names(names : Array[String]) -> String {
  let mut out = "["
  for i = 0; i < names.length(); i = i + 1 {
    if i > 0 {
      out = out + ", "
    }
    out = out + "'" + names[i] + "'"
  }
  out + "]"
}

///|
/// The variables of the graph that are not columns of the data.
///
/// The upstream warns about them when the model is built. The port has no
/// warning system, so it reports them instead.
pub fn CausalModel::unobserved_graph_variables(
  self : CausalModel,
) -> Array[String] {
  let out : Array[String] = []
  for node in self.graph.get_all_nodes(true) {
    if !self.observed_nodes.contains(node) {
      out.push(node)
    }
  }
  out.sort_by(fn(a, b) { compare_names(a, b) })
  out
}

///|
/// The columns of the data that are not variables of the graph.
///
/// The upstream logs them when the model is built. The port reports them
/// instead.
pub fn CausalModel::unused_data_variables(self : CausalModel) -> Array[String] {
  let out : Array[String] = []
  for node in self.observed_nodes {
    if !self.graph.get_all_nodes(true).contains(node) {
      out.push(node)
    }
  }
  out.sort_by(fn(a, b) { compare_names(a, b) })
  out
}

///|
/// The comparison of two names, the way the upstream sorts a list of names.
fn compare_names(a : String, b : String) -> Int32 {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
/// The estimator the model has built for the given method, when it has one.
///
/// This is the port of `dowhy.causal_model.CausalModel.get_estimator`. The
/// upstream keys the cache by the whole name of the method.
pub fn CausalModel::get_estimator(
  self : CausalModel,
  method_name : String,
) -> @estimators.CausalEstimator? {
  self.estimator_cache.get(method_name)
}

///|
/// Identify the causal effect.
///
/// `method_name` selects the identifier: `"backdoor"` (the default),
/// `"frontdoor"`, `"mediation"`, `"iv"` or `"general_adjustment"`.
///
/// The kind of the estimand is the one of the model, the way the upstream uses
/// the kind it was built with. The mediation of the effect is the natural
/// indirect effect, which the upstream identifies with its own function.
pub fn CausalModel::identify_effect(
  self : CausalModel,
  method_name : String,
) -> @identifiers.IdentifiedEstimand {
  let estimand = @identifiers.identify_effect_auto(
    self.graph.directed_graph(),
    self.treatment,
    self.outcome,
    self.observed_nodes,
    estimand_type_of(self.estimand_type, method_name),
    backdoor_strategy_of(method_name),
  )
  self.estimand = estimand
  estimand
}

///|
/// The kind of the estimand the method name asks for.
///
/// The mediation of the effect is the natural indirect effect, the one the
/// upstream identifies with `identify_nie_effect`.
fn estimand_type_of(estimand_type : String, method_name : String) -> String {
  if first_segment(method_name) == "mediation" {
    "nonparametric-nie"
  } else {
    estimand_type
  }
}

///|
/// The backdoor strategy that the given identifier method uses.
///
/// The method names of the model are the identifiers of the upstream, and the
/// upstream passes the name of the backdoor strategy to the identifier. A name
/// that is not a strategy of the upstream uses the default backdoor strategy,
/// the way the upstream does when it is given no strategy at all.
fn backdoor_strategy_of(method_name : String) -> String {
  if @identifiers.is_backdoor_strategy(method_name) {
    method_name
  } else {
    @identifiers.BACKDOOR_DEFAULT
  }
}

///|
/// Build the estimator the method name refers to.
fn CausalModel::build_estimator(
  self : CausalModel,
  method_name : String,
) -> @estimators.CausalEstimator {
  let estimand = self.estimand
  match method_name {
    "backdoor.linear_regression" =>
      @estimators.CausalEstimator::linear_regression(estimand)
    "backdoor.propensity_score_weighting" =>
      @estimators.CausalEstimator::propensity_score_weighting(
        estimand,
        0.05,
        0.95,
        @estimators.WeightingScheme::ips_weight(),
      )
    "backdoor.propensity_score_matching" =>
      @estimators.CausalEstimator::propensity_score_matching(estimand)
    "backdoor.propensity_score_stratification" =>
      @estimators.CausalEstimator::propensity_score_stratification(
        estimand,
        @estimators.NumStrata::auto(),
        10,
      )
    "backdoor.doubly_robust" =>
      @estimators.CausalEstimator::doubly_robust(estimand, 0.01, 0.99)
    "iv.instrumental_variable" =>
      @estimators.CausalEstimator::instrumental_variable(estimand, "")
    "frontdoor.two_stage_regression" =>
      @estimators.CausalEstimator::two_stage_regression(estimand)
    "mediation.two_stage_regression" =>
      @estimators.CausalEstimator::two_stage_regression(estimand)
    "backdoor.generalized_linear_model" =>
      @estimators.CausalEstimator::generalized_linear_model(
        estimand,
        @utils.GlmFamily::gaussian(),
      )
    "backdoor.generalized_linear_model.gaussian" =>
      @estimators.CausalEstimator::generalized_linear_model(
        estimand,
        @utils.GlmFamily::gaussian(),
      )
    "backdoor.generalized_linear_model.binomial" =>
      @estimators.CausalEstimator::generalized_linear_model(
        estimand,
        @utils.GlmFamily::binomial(),
      )
    "backdoor.generalized_linear_model.poisson" =>
      @estimators.CausalEstimator::generalized_linear_model(
        estimand,
        @utils.GlmFamily::poisson(),
      )
    _ =>
      abort(
        "The method " + method_name + " is not supported by this port of DoWhy",
      )
  }
}

///|
/// Estimate the causal effect.
///
/// `method_name` names the estimator, e.g. `"backdoor.linear_regression"`.
/// The first segment of the name selects the identifier, exactly like
/// `dowhy` does.
///
/// When the effect has not been identified yet, it is identified with the
/// identifier of the method name, so that a model that is used for a single
/// estimate does not need an explicit `identify_effect` call.
///
/// The effect modifiers of the estimate are the effect modifiers of the graph
/// when the caller names none, the way the upstream does it. The regression
/// based estimators then report a conditional estimate for every group of the
/// effect modifier.
///
/// The estimator the estimate is computed with is kept in the cache of the
/// model, keyed by the name of the method, the way the upstream keeps it. When
/// `fit_estimator` is false the cached estimator is used as it is, without a
/// new fit, which is what the upstream does when the estimator is asked for
/// on new data.
pub fn CausalModel::estimate_effect(
  self : CausalModel,
  method_name : String,
  treatment_value : Double,
  control_value : Double,
  target_units : String,
  effect_modifier_names~ : Array[String] = [],
  fit_estimator~ : Bool = true,
) -> @model.CausalEstimate {
  // The identifier of the estimator is the first segment of its name.
  let identifier = first_segment(method_name)
  if !self.estimand.has_estimand(identifier) {
    let _ = self.identify_effect(identifier)
  }
  self.estimand.set_identifier_method(identifier)
  let cached = self.estimator_cache.get(method_name)
  let estimator = match cached {
    Some(existing) => existing
    None => {
      let built = self.build_estimator(method_name)
      self.estimator_cache.set(method_name, built)
      built
    }
  }
  // The upstream takes the effect modifiers of the graph when the caller does
  // not name any.
  let modifiers = if effect_modifier_names.length() == 0 {
    self.graph.get_effect_modifiers(self.treatment, self.outcome)
  } else {
    effect_modifier_names
  }
  if fit_estimator {
    estimator.fit(self.data, modifiers)
  }
  estimator.estimate_effect(
    self.data,
    treatment_value,
    control_value,
    target_units,
  )
}

///|
/// Refute the estimate.
///
/// `refuter_name` is one of `"bootstrap"`, `"placebo"`, `"subset"`,
/// `"dummy_outcome"`, `"random_common_cause"` or
/// `"add_unobserved_common_cause"`.
///
/// `placebo_type` chooses the kind of the placebo the placebo treatment
/// refuter builds: a random variable of the kind of the treatment, or the rows
/// of the treatment, permuted.  The upstream forwards it as a keyword argument
/// of its own method.
pub fn CausalModel::refute_estimate(
  self : CausalModel,
  method_name : String,
  estimate : @model.CausalEstimate,
  refuter_name : String,
  num_simulations : Int32,
  random : @utils.Random,
  placebo_type~ : @refuters.PlaceboType = @refuters.PlaceboType::random_data(),
) -> @refuters.CausalRefutation {
  let estimator = self.build_estimator(method_name)
  estimator.fit(self.data, [])
  let estimand = self.estimand
  // The identifier of the estimator is the first segment of its name, the way
  // the estimate sets it.
  estimand.set_identifier_method(first_segment(method_name))
  match refuter_name {
    "bootstrap" =>
      @refuters.refute_bootstrap(
        estimator,
        estimand,
        self.data,
        num_simulations,
        1.0,
        estimate.control_value,
        estimate.treatment_value,
        "ate",
        random,
      )
    "placebo" =>
      @refuters.refute_placebo_treatment(
        estimator,
        estimand,
        self.data,
        self.treatment[0],
        num_simulations,
        estimate.treatment_value,
        estimate.control_value,
        "ate",
        random,
        placebo_type~,
      )
    "subset" =>
      @refuters.refute_data_subset(
        estimator,
        estimand,
        self.data,
        0.8,
        num_simulations,
        estimate.treatment_value,
        estimate.control_value,
        "ate",
        random,
      )
    "dummy_outcome" =>
      // The dummy outcome refuter reports one refutation per bucket of the
      // treatment. The default transformation list carries no estimator, so
      // there is exactly one, and the first one is the refutation the caller
      // gets.
      @refuters.refute_dummy_outcome(
        estimator,
        estimand,
        self.data,
        self.outcome[0],
        self.treatment[0],
        num_simulations,
        estimate.treatment_value,
        estimate.control_value,
        "ate",
        random,
      )[0]
    "random_common_cause" =>
      @refuters.refute_random_common_cause(
        estimator,
        estimand,
        self.data,
        num_simulations,
        estimate.treatment_value,
        estimate.control_value,
        "ate",
        random,
      )
    "add_unobserved_common_cause" =>
      @refuters.refute_add_unobserved_common_cause(
        estimator,
        estimand,
        self.data,
        self.treatment[0],
        self.outcome[0],
        0.05,
        0.05,
        estimate.treatment_value,
        estimate.control_value,
        "ate",
        random,
      )
    _ => abort("The refuter " + refuter_name + " is not supported")
  }
}

///|
/// Assess the support and the overlap of the covariates with boolean rules.
///
/// This is the port of the `assess_overlap` refuter of the upstream. The
/// upstream returns the analyzer of the rules from its `refute_estimate`, and
/// the port returns it from a method of its own, because the rules are not a
/// refutation of the estimate.
///
/// The rules are learned with respect to the backdoor variables of the estimand,
/// the way the upstream takes them.
pub fn CausalModel::refute_assess_overlap(
  self : CausalModel,
  support_config~ : @overrule.SupportConfig = @overrule.SupportConfig::new(),
  overlap_config~ : @overrule.OverlapConfig = @overrule.OverlapConfig::new(),
  overlap_eps~ : Double = 0.1,
  support_only~ : Bool = false,
  overlap_only~ : Bool = false,
) -> @overrule.OverlapAnalyzer {
  let backdoor = self.estimand.get_backdoor_variables(
    self.estimand.default_backdoor_id(),
  )
  let names = self.data.numeric_column_names()
  let columns : Array[Array[Double]] = []
  for name in names {
    columns.push(self.data.numeric(name))
  }
  @overrule.refute_assess_overlap(
    columns,
    names,
    backdoor,
    self.treatment[0],
    support_config,
    overlap_config,
    overlap_eps,
    support_only,
    overlap_only,
  )
}

///|
/// The first segment of a dotted name.
fn first_segment(name : String) -> String {
  let parts = name.split(".")
  match parts.next() {
    Some(first) => first.to_owned()
    None => name
  }
}
