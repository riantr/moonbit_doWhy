/// The `do` operation of Pearl (2000).
///
/// The upstream code exposes the operation as the `df.causal.do(...)`
/// accessor of `pandas.DataFrame`. MoonBit has no accessor mechanism, so the
/// operation is a plain function here.

///|
/// Sample from the interventional distribution of the outcome.
///
/// The function is the port of the `df.causal.do(...)` accessor of
/// `dowhy.api.causal_data_frame`:
///
/// - `graph` is the causal graph of the analysis. When it is `None` the
///   graph is built from the treatment, the outcome and the common causes,
///   exactly like the accessor does it.
/// - `x` names the treatment variables and `outcome` the outcome variables.
/// - `variable_types` holds the type of every variable. An empty map infers
///   the types from the data, like the accessor does it: a numeric column is
///   continuous and a discrete column is discrete.
/// - `method_name` names the sampler: `"weighting"`,
///   `"multivariate_weighting"` or `"kernel_density"`.
/// - `random` is the generator the sampler draws from, so that the result is
///   reproducible.
///
/// The treatment keeps the values it has in the data, unless
/// `treatment_values` gives the value the intervention imposes on it. The
/// returned frame holds the sampled outcome and the other columns of the
/// data.
pub fn do_sample(
  data : @api.DataFrame,
  graph : @graph.DirectedGraph?,
  x : Array[String],
  outcome : Array[String],
  variable_types : Map[String, VariableType],
  common_causes : Array[String],
  method_name : String,
  random : @utils.Random,
  treatment_values~ : Map[String, Double] = Map([]),
) -> @api.DataFrame {
  let built = match graph {
    Some(g) => g.copy()
    None => @graph.build_graph(x, outcome, common_causes, [], [], [])
  }
  let observed = built.node_list()
  let types = if map_size(variable_types) == 0 {
    infer_variable_types(data)
  } else {
    variable_types
  }
  let keep_original = map_size(treatment_values) == 0
  let sampler = match method_name {
    "weighting" =>
      DoSampler::weighting(
        built,
        x,
        outcome,
        observed,
        data,
        types,
        random,
        keep_original_treatment=keep_original,
      )
    "multivariate_weighting" =>
      DoSampler::multivariate_weighting(
        built,
        x,
        outcome,
        observed,
        data,
        types,
        random,
        keep_original_treatment=keep_original,
      )
    "kernel_density" =>
      DoSampler::kernel_density(
        built,
        x,
        outcome,
        observed,
        data,
        types,
        random,
        keep_original_treatment=keep_original,
      )
    _ => abort("The method " + method_name + " is not an existing do sampler.")
  }
  sampler.do_sample(treatment_values)
}

///|
/// The types of the variables of a data frame.
///
/// This is the port of the type inference of the accessor: a numeric column
/// is continuous and a discrete column is discrete, which is the mapping
/// `convert_to_custom_type` does for the pandas dtypes.
fn infer_variable_types(data : @api.DataFrame) -> Map[String, VariableType] {
  let types : Map[String, VariableType] = Map([])
  for name in data.column_names() {
    match data.column(name) {
      Some(@api.Column::Discrete(_)) => types.set(name, VariableType::Discrete)
      _ => types.set(name, VariableType::Continuous)
    }
  }
  types
}
