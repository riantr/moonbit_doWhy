/// Deterministic random numbers and the synthetic data sets that DoWhy's test
/// suite builds with `numpy.random`.
///
/// The port keeps the shape and the statistical properties of the Python
/// fixtures: the same column names, the same value ranges and the same
/// treatment / outcome relationship.  The numbers themselves differ from
/// NumPy's, but the data is reproducible: the same seed always yields the
/// same rows, on every platform.

// ---------------------------------------------------------------------------
// Random numbers
// ---------------------------------------------------------------------------

///|
/// A deterministic xorshift64 generator.
///
/// The generator is written by hand so that the generated data does not
/// depend on the toolchain's own random number implementation.
priv struct Rng {
  mut state : UInt64
}

///|
/// A generator for the given seed.
fn Rng::new(seed : Int32) -> Rng {
  let mut state = 0x9E37_79B9_7F4A_7C15UL ^
    seed.to_int64().reinterpret_as_uint64()
  // A few rounds of the generator's own mixing function make neighbouring
  // seeds produce unrelated streams.
  let mut round = 0
  while round < 8 {
    state = Rng::step(state)
    round = round + 1
  }
  if state == 0UL {
    state = 0x9E37_79B9_7F4A_7C15UL
  }
  { state, }
}

///|
/// One round of xorshift64.
fn Rng::step(state : UInt64) -> UInt64 {
  let mut x = state
  x = x.lxor(x << 13)
  x = x.lxor(x >> 7)
  x = x.lxor(x << 17)
  x
}

///|
/// The next raw 64 bit value.
fn Rng::next_u64(self : Rng) -> UInt64 {
  self.state = Rng::step(self.state)
  self.state
}

///|
/// A uniform value in `[0, 1)`.
fn Rng::uniform01(self : Rng) -> Double {
  // The 53 high bits carry the full precision of a double.
  let bits = self.next_u64() >> 11
  bits.to_double() * (1.0 / 9007199254740992.0)
}

///|
/// A uniform value in `[low, high)`.
fn Rng::uniform(self : Rng, low : Double, high : Double) -> Double {
  low + (high - low) * self.uniform01()
}

///|
/// A standard normal deviate, via the Box-Muller transform.
fn Rng::normal(self : Rng) -> Double {
  let u1 = self.uniform01()
  let u2 = self.uniform01()
  // `uniform01` may return exactly zero; move it away from the singularity
  // of the logarithm.
  let safe_u1 = if u1 <= 0.0 { 2.0 / 9007199254740992.0 } else { u1 }
  let variance = -2.0 * @math.ln(safe_u1)
  let radius = variance.sqrt()
  radius * @math.cos(2.0 * @math.PI * u2)
}

///|
/// A Bernoulli draw that is `true` with probability `p`.
fn Rng::bernoulli(self : Rng, p : Double) -> Bool {
  self.uniform01() < p
}

///|
/// A three level categorical draw, like
/// `dowhy.datasets.stochastically_convert_to_three_level_categorical`.
fn Rng::three_level_category(self : Rng, p : Double) -> Int32 {
  let low = 0.8 * (1.0 - p)
  let middle = low + 0.8 * p
  let u = self.uniform01()
  if u < low {
    0
  } else if u < middle {
    1
  } else {
    2
  }
}

// ---------------------------------------------------------------------------
// Data sets
// ---------------------------------------------------------------------------

///|
/// A generated data set together with the metadata that `dowhy.datasets`
/// returns next to the frame.
pub struct Dataset {
  /// The data frame.
  df : @api.DataFrame
  /// The true average treatment effect of the data set.
  ate : Double
  /// The names of the treatment columns.
  treatment_names : Array[String]
  /// The name of the outcome column.
  outcome_name : String
  /// The names of the common cause columns.
  common_cause_names : Array[String]
  /// The names of the instrument columns.
  instrument_names : Array[String]
  /// The names of the effect modifier columns.
  effect_modifier_names : Array[String]
  /// The names of the frontdoor mediator columns.
  frontdoor_names : Array[String]
}

///|
/// The data frame of the data set.
pub fn Dataset::frame(self : Dataset) -> @api.DataFrame {
  self.df
}

///|
/// The true average treatment effect of the data set.
pub fn Dataset::average_treatment_effect(self : Dataset) -> Double {
  self.ate
}

///|
/// The names of the treatment columns.
pub fn Dataset::treatments(self : Dataset) -> Array[String] {
  self.treatment_names.copy()
}

///|
/// The name of the outcome column.
pub fn Dataset::outcome(self : Dataset) -> String {
  self.outcome_name
}

///|
/// The names of the common cause columns.
pub fn Dataset::common_causes(self : Dataset) -> Array[String] {
  self.common_cause_names.copy()
}

///|
/// The names of the instrument columns.
pub fn Dataset::instruments(self : Dataset) -> Array[String] {
  self.instrument_names.copy()
}

///|
/// The names of the effect modifier columns.
pub fn Dataset::effect_modifiers(self : Dataset) -> Array[String] {
  self.effect_modifier_names.copy()
}

///|
/// The names of the frontdoor mediator columns.
pub fn Dataset::frontdoor_variables(self : Dataset) -> Array[String] {
  self.frontdoor_names.copy()
}

///|
/// The names of every column of the data frame.
pub fn Dataset::observed_nodes(self : Dataset) -> Array[String] {
  self.df.column_names()
}

///|
/// The graph of the data set, in the GML format.
///
/// This is the port of `dowhy.datasets.create_gml_graph`, which writes the
/// graph of the data set as a GML string. The upstream hands the string to
/// `networkx.parse_gml`, which names a node after its `label` attribute, so
/// the graph of the port has the same nodes and the same edges as the graph of
/// the upstream.
pub fn Dataset::gml_graph(self : Dataset) -> String {
  create_gml_graph(
    self.treatment_names,
    self.outcome_name,
    self.common_cause_names,
    self.instrument_names,
    self.effect_modifier_names,
    self.frontdoor_names,
  )
}

///|
/// The graph of the data set, in the GML format.
///
/// This is the port of `dowhy.datasets.create_gml_graph`.
fn create_gml_graph(
  treatments : Array[String],
  outcome : String,
  common_causes : Array[String],
  instruments : Array[String],
  effect_modifiers : Array[String],
  frontdoor_variables : Array[String],
) -> String {
  let mut out = "graph[directed 1" + gml_node(outcome)
  // The upstream joins the nodes of a group with a space and writes the
  // groups one after the other, without a separator.
  out = out + gml_node_group(common_causes)
  out = out + gml_node_group(instruments)
  out = out + gml_node_group(frontdoor_variables)
  for treatment in treatments {
    out = out + gml_node(treatment)
    if frontdoor_variables.length() == 0 {
      out = out + gml_edge_of_the_treatment(treatment, outcome)
    }
    out = out + gml_edge_group_to(common_causes, treatment)
    out = out + gml_edge_group_to(instruments, treatment)
    out = out + gml_edge_group_from(frontdoor_variables, treatment)
  }
  out = out + gml_edge_group_to(common_causes, outcome)
  out = out + gml_effect_modifier_group(effect_modifiers, outcome)
  out = out + gml_edge_group_to(frontdoor_variables, outcome)
  for cause in common_causes {
    out = out + gml_edge_group_from(frontdoor_variables, cause)
  }
  out + "]"
}

///|
/// The GML declaration of a node.
fn gml_node(name : String) -> String {
  "node[ id \"" + name + "\" label \"" + name + "\"]"
}

///|
/// The GML declaration of the nodes of a group, joined with a space.
fn gml_node_group(names : Array[String]) -> String {
  let parts : Array[String] = []
  for name in names {
    parts.push(gml_node(name))
  }
  parts.join(" ")
}

///|
/// The GML declaration of an edge.
fn gml_edge(source : String, target : String) -> String {
  "edge[ source \"" + source + "\" target \"" + target + "\"]"
}

///|
/// The GML declaration of the edge of the treatment to the outcome.
///
/// The upstream writes this one edge without the space that the other edges
/// have.
fn gml_edge_of_the_treatment(source : String, target : String) -> String {
  "edge[source \"" + source + "\" target \"" + target + "\"]"
}

///|
/// The GML declaration of the edges of the given nodes to the target, joined
/// with a space.
fn gml_edge_group_to(names : Array[String], target : String) -> String {
  let parts : Array[String] = []
  for name in names {
    parts.push(gml_edge(name, target))
  }
  parts.join(" ")
}

///|
/// The GML declaration of the edges of the source to the given nodes, joined
/// with a space.
fn gml_edge_group_from(names : Array[String], source : String) -> String {
  let parts : Array[String] = []
  for name in names {
    parts.push(gml_edge(source, name))
  }
  parts.join(" ")
}

///|
/// The GML declaration of the effect modifiers and of their edges to the
/// outcome, joined with a space.
fn gml_effect_modifier_group(names : Array[String], outcome : String) -> String {
  let parts : Array[String] = []
  for name in names {
    parts.push(gml_node(name) + " " + gml_edge(name, outcome))
  }
  parts.join(" ")
}

///|
/// The parameters of `dowhy.datasets.linear_dataset`.
///
/// The defaults follow the fixture that DoWhy's estimator tests use:
/// a treatment effect of ten, a binary treatment and a continuous outcome.
pub struct LinearConfig {
  /// The coefficient of the treatment in the outcome equation.
  beta : Double
  /// The number of common causes (`W` columns).
  num_common_causes : Int32
  /// The number of instrumental variables (`Z` columns).
  num_instruments : Int32
  /// The number of effect modifiers (`X` columns).
  num_effect_modifiers : Int32
  /// The number of frontdoor mediators (`FD` columns).
  num_frontdoor_variables : Int32
  /// The number of treatments (`v` columns).
  num_treatments : Int32
  /// The number of trailing common causes that are discretised.
  num_discrete_common_causes : Int32
  /// The number of trailing effect modifiers that are discretised.
  num_discrete_effect_modifiers : Int32
  /// Whether the treatment is binary.
  treatment_is_binary : Bool
  /// Whether the treatment is a three level category.
  treatment_is_category : Bool
  /// Whether the outcome is binary.
  outcome_is_binary : Bool
}

///|
/// A configuration of the generator, built from the parameters of the
/// upstream.
///
/// This is the port of the keyword arguments of `dowhy.datasets.linear_dataset`,
/// which the upstream takes one by one. The named constructors of the package
/// are the configurations of the fixtures of the upstream test suite; this
/// constructor is for the fixtures that are not among them.
///
/// The defaults follow the fixture that DoWhy's estimator tests use: a
/// treatment effect of ten, a binary treatment and a continuous outcome.
pub fn LinearConfig::new(
  beta~ : Double = 10.0,
  num_common_causes~ : Int32 = 0,
  num_instruments~ : Int32 = 0,
  num_effect_modifiers~ : Int32 = 0,
  num_frontdoor_variables~ : Int32 = 0,
  num_treatments~ : Int32 = 1,
  num_discrete_common_causes~ : Int32 = 0,
  num_discrete_effect_modifiers~ : Int32 = 0,
  treatment_is_binary~ : Bool = true,
  treatment_is_category~ : Bool = false,
  outcome_is_binary~ : Bool = false,
) -> LinearConfig {
  {
    beta,
    num_common_causes,
    num_instruments,
    num_effect_modifiers,
    num_frontdoor_variables,
    num_treatments,
    num_discrete_common_causes,
    num_discrete_effect_modifiers,
    treatment_is_binary,
    treatment_is_category,
    outcome_is_binary,
  }
}

///|
/// One common cause: the confounded scenario.
pub fn LinearConfig::confounded() -> LinearConfig {
  {
    beta: 10.0,
    num_common_causes: 1,
    num_instruments: 0,
    num_effect_modifiers: 0,
    num_frontdoor_variables: 0,
    num_treatments: 1,
    num_discrete_common_causes: 0,
    num_discrete_effect_modifiers: 0,
    treatment_is_binary: true,
    treatment_is_category: false,
    outcome_is_binary: false,
  }
}

///|
/// A binary outcome: the confounded scenario whose outcome is a binary
/// variable, the scenario the generalised linear model estimator of the
/// upstream test suite uses.
pub fn LinearConfig::binary_outcome() -> LinearConfig {
  {
    beta: 2.0,
    num_common_causes: 1,
    num_instruments: 0,
    num_effect_modifiers: 0,
    num_frontdoor_variables: 0,
    num_treatments: 1,
    num_discrete_common_causes: 0,
    num_discrete_effect_modifiers: 0,
    treatment_is_binary: true,
    treatment_is_category: false,
    outcome_is_binary: true,
  }
}

///|
/// No common cause at all and a binary outcome.
pub fn LinearConfig::no_confounding_binary_outcome() -> LinearConfig {
  {
    beta: 2.0,
    num_common_causes: 0,
    num_instruments: 0,
    num_effect_modifiers: 0,
    num_frontdoor_variables: 0,
    num_treatments: 1,
    num_discrete_common_causes: 0,
    num_discrete_effect_modifiers: 0,
    treatment_is_binary: true,
    treatment_is_category: false,
    outcome_is_binary: true,
  }
}

///|
/// Two common causes: the confounded scenario with a wider confounder set.
pub fn LinearConfig::two_common_causes() -> LinearConfig {
  {
    beta: 10.0,
    num_common_causes: 2,
    num_instruments: 0,
    num_effect_modifiers: 0,
    num_frontdoor_variables: 0,
    num_treatments: 1,
    num_discrete_common_causes: 0,
    num_discrete_effect_modifiers: 0,
    treatment_is_binary: true,
    treatment_is_category: false,
    outcome_is_binary: false,
  }
}

///|
/// No common cause at all.
pub fn LinearConfig::no_confounding() -> LinearConfig {
  {
    beta: 10.0,
    num_common_causes: 0,
    num_instruments: 0,
    num_effect_modifiers: 0,
    num_frontdoor_variables: 0,
    num_treatments: 1,
    num_discrete_common_causes: 0,
    num_discrete_effect_modifiers: 0,
    treatment_is_binary: true,
    treatment_is_category: false,
    outcome_is_binary: false,
  }
}

///|
/// One effect modifier, one common cause and one instrument.
pub fn LinearConfig::effect_modifier() -> LinearConfig {
  {
    beta: 10.0,
    num_common_causes: 0,
    num_instruments: 0,
    num_effect_modifiers: 1,
    num_frontdoor_variables: 0,
    num_treatments: 1,
    num_discrete_common_causes: 0,
    num_discrete_effect_modifiers: 0,
    treatment_is_binary: true,
    treatment_is_category: false,
    outcome_is_binary: false,
  }
}

///|
/// One instrument and one common cause.
pub fn LinearConfig::instrumental_variable() -> LinearConfig {
  {
    beta: 10.0,
    num_common_causes: 1,
    num_instruments: 1,
    num_effect_modifiers: 0,
    num_frontdoor_variables: 0,
    num_treatments: 1,
    num_discrete_common_causes: 0,
    num_discrete_effect_modifiers: 0,
    treatment_is_binary: true,
    treatment_is_category: false,
    outcome_is_binary: false,
  }
}

///|
/// Five common causes and one instrument.
///
/// This is the configuration of the fixture of the upstream tests of the
/// causal model, `dowhy.datasets.linear_dataset` with five common causes, one
/// instrument and one binary treatment.
pub fn LinearConfig::five_common_causes_one_instrument() -> LinearConfig {
  {
    beta: 10.0,
    num_common_causes: 5,
    num_instruments: 1,
    num_effect_modifiers: 0,
    num_frontdoor_variables: 0,
    num_treatments: 1,
    num_discrete_common_causes: 0,
    num_discrete_effect_modifiers: 0,
    treatment_is_binary: true,
    treatment_is_category: false,
    outcome_is_binary: false,
  }
}

///|
/// Five common causes and no instrument.
///
/// This is the configuration of the fixture of the upstream tests of the
/// causal model, `dowhy.datasets.linear_dataset` with five common causes and
/// one binary treatment.
pub fn LinearConfig::five_common_causes_no_instrument() -> LinearConfig {
  {
    beta: 10.0,
    num_common_causes: 5,
    num_instruments: 0,
    num_effect_modifiers: 0,
    num_frontdoor_variables: 0,
    num_treatments: 1,
    num_discrete_common_causes: 0,
    num_discrete_effect_modifiers: 0,
    treatment_is_binary: true,
    treatment_is_category: false,
    outcome_is_binary: false,
  }
}

///|
/// One frontdoor mediator and one common cause.
pub fn LinearConfig::frontdoor() -> LinearConfig {
  {
    beta: 10.0,
    num_common_causes: 1,
    num_instruments: 0,
    num_effect_modifiers: 0,
    num_frontdoor_variables: 1,
    num_treatments: 1,
    num_discrete_common_causes: 0,
    num_discrete_effect_modifiers: 0,
    treatment_is_binary: true,
    treatment_is_category: false,
    outcome_is_binary: false,
  }
}

///|
/// Three common causes, the trailing two of them discretised, and two
/// instruments: the configuration of DoWhy's categorical encoding test.
pub fn LinearConfig::discrete_common_causes() -> LinearConfig {
  {
    beta: 1.0,
    num_common_causes: 3,
    num_instruments: 2,
    num_effect_modifiers: 0,
    num_frontdoor_variables: 0,
    num_treatments: 1,
    num_discrete_common_causes: 2,
    num_discrete_effect_modifiers: 0,
    treatment_is_binary: true,
    treatment_is_category: false,
    outcome_is_binary: false,
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

///|
/// The quartile cut points of a column, like `numpy.quantile`.
fn quartile_bins(column : Array[Double]) -> Array[Double] {
  let bins : Array[Double] = []
  bins.push(@utils.percentile(column, 25.0))
  bins.push(@utils.percentile(column, 50.0))
  bins.push(@utils.percentile(column, 75.0))
  bins
}

///|
/// The bin index of a value, like `numpy.digitize`.
fn digitize(value : Double, bins : Array[Double]) -> Int32 {
  let mut index = 0
  let mut i = 0
  while i < bins.length() {
    if value >= bins[i] {
      index = index + 1
    }
    i = i + 1
  }
  index
}

///|
/// Replace the columns that are marked as discrete by their quartile bin,
/// like `dowhy.datasets.convert_to_categorical`.
fn discretise(matrix : Array[Array[Double]], discrete : Array[Bool]) -> Unit {
  let rows = matrix.length()
  let cols = if rows == 0 { 0 } else { matrix[0].length() }
  let mut j = 0
  while j < cols {
    if discrete[j] {
      let column : Array[Double] = []
      let mut i = 0
      while i < rows {
        column.push(matrix[i][j])
        i = i + 1
      }
      let bins = quartile_bins(column)
      let mut k = 0
      while k < rows {
        matrix[k][j] = digitize(matrix[k][j], bins).to_double()
        k = k + 1
      }
    }
    j = j + 1
  }
}

///|
/// The values of one column of a matrix.
fn numeric_column(
  matrix : Array[Array[Double]],
  index : Int32,
) -> Array[Double] {
  let values : Array[Double] = []
  for row in matrix {
    values.push(row[index])
  }
  values
}

///|
/// The values of one column of a matrix, as the level names of a categorical
/// column.
fn discrete_column(
  matrix : Array[Array[Double]],
  index : Int32,
) -> Array[String] {
  let values : Array[String] = []
  for row in matrix {
    values.push(row[index].to_int().to_string())
  }
  values
}

///|
/// A frame whose columns are the given ones, in the given order.
fn frame_from_columns(columns : Array[(String, @api.Column)]) -> @api.DataFrame {
  let order : Array[String] = []
  let payload : Map[String, @api.Column] = Map([])
  for entry in columns {
    let (name, column) = entry
    order.push(name)
    payload.set(name, column)
  }
  @api.DataFrame::new(order, payload)
}

///|
/// The pieces of the outcome equation of a generated data set.
priv struct Equation {
  n : Int32
  w : Array[Array[Double]]
  x : Array[Array[Double]]
  fd_noise : Array[Array[Double]]
  c2 : Array[Double]
  ce : Array[Double]
  cfd1 : Array[Array[Double]]
  cfd2 : Array[Double]
  beta : Double
  num_treatments : Int32
  num_common_causes : Int32
  num_effect_modifiers : Int32
  num_frontdoor_variables : Int32
  outcome_is_binary : Bool
}

///|
/// The outcome of everybody who is treated (`treatment` = 1) or of nobody who
/// is treated (`treatment` = 0), like the `_compute_y` helper of
/// `dowhy.datasets`.
fn outcome_at(rng : Rng, eq : Equation, treatment : Double) -> Array[Double] {
  let y : Array[Double] = []
  let mut i = 0
  while i < eq.n {
    // The outcome noise of the original fixture.
    let mut value = rng.normal() * 0.01
    if eq.num_frontdoor_variables > 0 {
      let mut f = 0
      while f < eq.num_frontdoor_variables {
        let mut mediator = eq.fd_noise[i][f]
        let mut k = 0
        while k < eq.num_treatments {
          mediator = mediator + treatment * eq.cfd1[k][f]
          k = k + 1
        }
        value = value + mediator * eq.cfd2[f]
        f = f + 1
      }
    } else {
      value = value + treatment * eq.beta * eq.num_treatments.to_double()
    }
    if eq.num_common_causes > 0 {
      let mut j = 0
      while j < eq.num_common_causes {
        value = value + eq.w[i][j] * eq.c2[j]
        j = j + 1
      }
    }
    if eq.num_effect_modifiers > 0 {
      let mut modifier = 0.0
      let mut j = 0
      while j < eq.num_effect_modifiers {
        modifier = modifier + eq.x[i][j] * eq.ce[j]
        j = j + 1
      }
      // The effect modifiers only act on the rows that are treated.
      let product = if treatment == 0.0 { 0.0 } else { 1.0 }
      value = value + modifier * product
    }
    if eq.outcome_is_binary {
      value = if rng.bernoulli(@utils.sigmoid(value)) { 1.0 } else { 0.0 }
    }
    y.push(value)
    i = i + 1
  }
  y
}

// ---------------------------------------------------------------------------
// The generators
// ---------------------------------------------------------------------------

///|
/// The port of `dowhy.datasets.linear_dataset`.
///
/// The generator draws the common causes (`W`), the instruments (`Z`), the
/// effect modifiers (`X`), the treatment (`v`), the frontdoor mediators
/// (`FD`) and the outcome (`y`) in the same order as the Python fixture, so
/// that the data has the same shape and the same statistical properties.
/// The columns of the frame are ordered `FD`, `X`, `Z`, `W`, `v`, `y`, like
/// the columns of the Python data frame.
pub fn linear_dataset(
  seed : Int32,
  n : Int32,
  config : LinearConfig,
) -> Dataset {
  let rng = Rng::new(seed)
  let rows = if n < 0 { 0 } else { n }
  let num_treatments = if config.num_treatments < 1 {
    1
  } else {
    config.num_treatments
  }
  let beta = config.beta
  let beta_abs = beta.abs()
  // The ranges the coefficients of the original fixture are drawn from.
  let range_c = 0.5 + beta_abs * 0.5
  let range_ce = 0.5 + beta_abs * 0.5
  let range_cfd = beta_abs * 0.5
  let range_cz = 1.0 + beta_abs

  // ---- the common causes ------------------------------------------------
  let num_cc = config.num_common_causes
  let w : Array[Array[Double]] = []
  let w_discrete : Array[Bool] = []
  let c1 : Array[Array[Double]] = []
  let c2 : Array[Double] = []
  if num_cc > 0 {
    let means : Array[Double] = []
    let mut j = 0
    while j < num_cc {
      means.push(rng.uniform(-1.0, 1.0))
      w_discrete.push(j >= num_cc - config.num_discrete_common_causes)
      j = j + 1
    }
    let mut i = 0
    while i < rows {
      let row : Array[Double] = []
      let mut k = 0
      while k < num_cc {
        row.push(means[k] + rng.normal())
        k = k + 1
      }
      w.push(row)
      i = i + 1
    }
    discretise(w, w_discrete)
    let mut j = 0
    while j < num_cc {
      let coefficients : Array[Double] = []
      let mut k = 0
      while k < num_treatments {
        coefficients.push(rng.uniform(0.0, range_c))
        k = k + 1
      }
      c1.push(coefficients)
      j = j + 1
    }
    let mut j = 0
    while j < num_cc {
      c2.push(rng.uniform(0.0, range_c))
      j = j + 1
    }
  }

  // ---- the instruments --------------------------------------------------
  let num_z = config.num_instruments
  let z : Array[Array[Double]] = []
  let cz : Array[Array[Double]] = []
  if num_z > 0 {
    let probabilities : Array[Double] = []
    let mut k = 0
    while k < num_z {
      probabilities.push(rng.uniform(0.0, 1.0))
      k = k + 1
    }
    let mut i = 0
    while i < rows {
      let row : Array[Double] = []
      let mut k = 0
      while k < num_z {
        // The odd instruments are continuous, the even ones binary.
        if k % 2 == 0 {
          row.push(if rng.bernoulli(probabilities[k]) { 1.0 } else { 0.0 })
        } else {
          row.push(rng.uniform(0.0, 1.0))
        }
        k = k + 1
      }
      z.push(row)
      i = i + 1
    }
    let mut k = 0
    while k < num_z {
      let coefficients : Array[Double] = []
      let mut c = 0
      while c < num_treatments {
        coefficients.push(
          rng.uniform(range_cz - range_cz * 0.05, range_cz + range_cz * 0.05),
        )
        c = c + 1
      }
      cz.push(coefficients)
      k = k + 1
    }
  }

  // ---- the effect modifiers ---------------------------------------------
  let num_em = config.num_effect_modifiers
  let x : Array[Array[Double]] = []
  let x_discrete : Array[Bool] = []
  let ce : Array[Double] = []
  if num_em > 0 {
    let means : Array[Double] = []
    let mut j = 0
    while j < num_em {
      means.push(rng.uniform(-1.0, 1.0))
      x_discrete.push(j >= num_em - config.num_discrete_effect_modifiers)
      j = j + 1
    }
    let mut i = 0
    while i < rows {
      let row : Array[Double] = []
      let mut k = 0
      while k < num_em {
        row.push(means[k] + rng.normal())
        k = k + 1
      }
      x.push(row)
      i = i + 1
    }
    discretise(x, x_discrete)
    let mut j = 0
    while j < num_em {
      ce.push(rng.uniform(0.0, range_ce))
      j = j + 1
    }
  }

  // ---- the treatment ----------------------------------------------------
  let t : Array[Array[Double]] = []
  let mut i = 0
  while i < rows {
    let row : Array[Double] = []
    let mut k = 0
    while k < num_treatments {
      row.push(rng.normal())
      k = k + 1
    }
    if num_cc > 0 {
      let mut j = 0
      while j < num_cc {
        let mut k = 0
        while k < num_treatments {
          row[k] = row[k] + w[i][j] * c1[j][k]
          k = k + 1
        }
        j = j + 1
      }
    }
    if num_z > 0 {
      let mut k = 0
      while k < num_z {
        let mut c = 0
        while c < num_treatments {
          row[c] = row[c] + z[i][k] * cz[k][c]
          c = c + 1
        }
        k = k + 1
      }
    }
    let mut k = 0
    while k < num_treatments {
      if config.treatment_is_category {
        let level = rng.three_level_category(@utils.sigmoid(row[k]))
        row[k] = level.to_double()
      } else if config.treatment_is_binary {
        row[k] = if rng.bernoulli(@utils.sigmoid(row[k])) { 1.0 } else { 0.0 }
      }
      k = k + 1
    }
    t.push(row)
    i = i + 1
  }

  // ---- the frontdoor mediators -----------------------------------------
  let num_fd = config.num_frontdoor_variables
  let fd : Array[Array[Double]] = []
  let fd_noise : Array[Array[Double]] = []
  let cfd1 : Array[Array[Double]] = []
  let cfd2 : Array[Double] = []
  let c1_frontdoor : Array[Array[Double]] = []
  if num_fd > 0 {
    let mut k = 0
    while k < num_treatments {
      let coefficients : Array[Double] = []
      let mut f = 0
      while f < num_fd {
        coefficients.push(rng.uniform(0.0, range_cfd))
        f = f + 1
      }
      cfd1.push(coefficients)
      k = k + 1
    }
    let mut f = 0
    while f < num_fd {
      cfd2.push(rng.uniform(0.0, range_cfd))
      f = f + 1
    }
    if num_cc > 0 {
      let mut j = 0
      while j < num_cc {
        let coefficients : Array[Double] = []
        let mut f = 0
        while f < num_fd {
          coefficients.push(rng.uniform(0.0, range_c / 10.0))
          f = f + 1
        }
        c1_frontdoor.push(coefficients)
        j = j + 1
      }
    }
    let mut i = 0
    while i < rows {
      let row : Array[Double] = []
      let mut f = 0
      while f < num_fd {
        row.push(rng.normal())
        f = f + 1
      }
      fd_noise.push(row.copy())
      i = i + 1
    }
    let mut i = 0
    while i < rows {
      let row : Array[Double] = []
      let mut f = 0
      while f < num_fd {
        let mut value = fd_noise[i][f]
        let mut k = 0
        while k < num_treatments {
          value = value + t[i][k] * cfd1[k][f]
          k = k + 1
        }
        if num_cc > 0 {
          let mut j = 0
          while j < num_cc {
            value = value + w[i][j] * c1_frontdoor[j][f]
            j = j + 1
          }
        }
        row.push(value)
        f = f + 1
      }
      fd.push(row)
      i = i + 1
    }
  }

  // ---- the outcome ------------------------------------------------------
  let y : Array[Double] = []
  let mut i = 0
  while i < rows {
    let mut value = rng.normal() * 0.01
    if num_fd > 0 {
      let mut f = 0
      while f < num_fd {
        value = value + fd[i][f] * cfd2[f]
        f = f + 1
      }
    } else {
      let mut k = 0
      while k < num_treatments {
        value = value + t[i][k] * beta
        k = k + 1
      }
    }
    if num_cc > 0 {
      let mut j = 0
      while j < num_cc {
        value = value + w[i][j] * c2[j]
        j = j + 1
      }
    }
    if num_em > 0 {
      let mut modifier = 0.0
      let mut j = 0
      while j < num_em {
        modifier = modifier + x[i][j] * ce[j]
        j = j + 1
      }
      let mut product = 1.0
      let mut k = 0
      while k < num_treatments {
        product = product * t[i][k]
        k = k + 1
      }
      value = value + modifier * product
    }
    if config.outcome_is_binary {
      value = if rng.bernoulli(@utils.sigmoid(value)) { 1.0 } else { 0.0 }
    }
    y.push(value)
    i = i + 1
  }

  // ---- the true average treatment effect ---------------------------------
  let equation : Equation = {
    n: rows,
    w,
    x,
    fd_noise,
    c2,
    ce,
    cfd1,
    cfd2,
    beta,
    num_treatments,
    num_common_causes: num_cc,
    num_effect_modifiers: num_em,
    num_frontdoor_variables: num_fd,
    outcome_is_binary: config.outcome_is_binary,
  }
  let mut ate = 0.0
  {
    let y1 = outcome_at(rng, equation, 1.0)
    let y0 = outcome_at(rng, equation, 0.0)
    let mut sum = 0.0
    let mut i = 0
    while i < rows {
      sum = sum + (y1[i] - y0[i])
      i = i + 1
    }
    if rows > 0 {
      ate = sum / rows.to_double()
    }
  }

  // ---- the frame ---------------------------------------------------------
  let columns : Array[(String, @api.Column)] = []
  let frontdoor_names : Array[String] = []
  let mut f = 0
  while f < num_fd {
    let name = "FD" + f.to_string()
    frontdoor_names.push(name)
    columns.push((name, @api.Column::numeric(numeric_column(fd, f))))
    f = f + 1
  }
  let effect_modifier_names : Array[String] = []
  let mut j = 0
  while j < num_em {
    let name = "X" + j.to_string()
    effect_modifier_names.push(name)
    if x_discrete[j] {
      columns.push((name, @api.Column::discrete(discrete_column(x, j))))
    } else {
      columns.push((name, @api.Column::numeric(numeric_column(x, j))))
    }
    j = j + 1
  }
  let instrument_names : Array[String] = []
  let mut k = 0
  while k < num_z {
    let name = "Z" + k.to_string()
    instrument_names.push(name)
    columns.push((name, @api.Column::numeric(numeric_column(z, k))))
    k = k + 1
  }
  let common_cause_names : Array[String] = []
  let mut j = 0
  while j < num_cc {
    let name = "W" + j.to_string()
    common_cause_names.push(name)
    if w_discrete[j] {
      columns.push((name, @api.Column::discrete(discrete_column(w, j))))
    } else {
      columns.push((name, @api.Column::numeric(numeric_column(w, j))))
    }
    j = j + 1
  }
  let treatment_names : Array[String] = []
  let mut k = 0
  while k < num_treatments {
    let name = "v" + k.to_string()
    treatment_names.push(name)
    if config.treatment_is_category {
      columns.push((name, @api.Column::discrete(discrete_column(t, k))))
    } else {
      columns.push((name, @api.Column::numeric(numeric_column(t, k))))
    }
    k = k + 1
  }
  columns.push(("y", @api.Column::numeric(y)))

  {
    df: frame_from_columns(columns),
    ate,
    treatment_names,
    outcome_name: "y",
    common_cause_names,
    instrument_names,
    effect_modifier_names,
    frontdoor_names,
  }
}

///|
/// The port of `dowhy.datasets.simple_iv_dataset`.
///
/// The data set holds a single continuous instrument (`Z0`), a single
/// confounder (`W0`), a binary treatment (`v0`) and the outcome (`y`).  The
/// true average treatment effect of the fixture is exactly the coefficient
/// of the treatment, because the outcome equation has no noise term.
pub fn simple_iv_dataset(seed : Int32, n : Int32) -> Dataset {
  let rng = Rng::new(seed)
  let rows = if n < 0 { 0 } else { n }
  let beta = 10.0
  let range_cz = 1.0 + beta.abs()
  let c1 = rng.uniform(0.0, 1.0)
  let c2 = rng.uniform(0.0, 1.0)
  let cz = rng.uniform(range_cz - range_cz * 0.05, range_cz + range_cz * 0.05)
  let w : Array[Double] = []
  let z : Array[Double] = []
  let mut i = 0
  while i < rows {
    w.push(rng.uniform(0.0, 1.0))
    z.push(rng.normal())
    i = i + 1
  }
  let t : Array[Double] = []
  let mut i = 0
  while i < rows {
    let value = rng.normal() + z[i] * cz + w[i] * c1
    t.push(if rng.bernoulli(@utils.sigmoid(value)) { 1.0 } else { 0.0 })
    i = i + 1
  }
  let y : Array[Double] = []
  let mut i = 0
  while i < rows {
    y.push(t[i] * beta + w[i] * c2)
    i = i + 1
  }
  let columns : Array[(String, @api.Column)] = [
    ("Z0", @api.Column::numeric(z)),
    ("W0", @api.Column::numeric(w)),
    ("v0", @api.Column::numeric(t)),
    ("y", @api.Column::numeric(y)),
  ]
  {
    df: frame_from_columns(columns),
    ate: beta,
    treatment_names: ["v0"],
    outcome_name: "y",
    common_cause_names: ["W0"],
    instrument_names: ["Z0"],
    effect_modifier_names: [],
    frontdoor_names: [],
  }
}

// ---------------------------------------------------------------------------
// The scenarios
// ---------------------------------------------------------------------------

///|
/// Confounded data: one common cause, one binary treatment and a continuous
/// outcome.
///
/// Mirrors `dowhy.datasets.linear_dataset(beta=10, num_common_causes=1,
/// num_samples=n)`.  The columns are `W0`, `v0` and `y`.
pub fn confounded_dataset(seed : Int32, n : Int32) -> Dataset {
  linear_dataset(seed, n, LinearConfig::confounded())
}

///|
/// The data frame of the confounded scenario.
pub fn confounded_data(seed : Int32, n : Int32) -> @api.DataFrame {
  confounded_dataset(seed, n).df
}

///|
/// Data without any confounding: one binary treatment and a continuous
/// outcome.
///
/// Mirrors `dowhy.datasets.linear_dataset(beta=10, num_common_causes=0,
/// num_samples=n)`.  The columns are `v0` and `y`.
pub fn no_confounding_dataset(seed : Int32, n : Int32) -> Dataset {
  linear_dataset(seed, n, LinearConfig::no_confounding())
}

///|
/// The data frame of the scenario without confounding.
pub fn no_confounding_data(seed : Int32, n : Int32) -> @api.DataFrame {
  no_confounding_dataset(seed, n).df
}

///|
/// Data with an effect modifier: the modifier only changes the effect of the
/// treatment on the outcome.
///
/// Mirrors `dowhy.datasets.linear_dataset(beta=10, num_effect_modifiers=1,
/// num_samples=n)`.  The columns are `X0`, `v0` and `y`.
pub fn effect_modifier_dataset(seed : Int32, n : Int32) -> Dataset {
  linear_dataset(seed, n, LinearConfig::effect_modifier())
}

///|
/// The data frame of the effect modifier scenario.
pub fn effect_modifier_data(seed : Int32, n : Int32) -> @api.DataFrame {
  effect_modifier_dataset(seed, n).df
}

///|
/// Instrumental variable data: one instrument, one confounder, one binary
/// treatment and a continuous outcome.
///
/// Mirrors `dowhy.datasets.simple_iv_dataset(beta=10, num_samples=n)`.  The
/// columns are `Z0`, `W0`, `v0` and `y`.
pub fn instrumental_variable_dataset(seed : Int32, n : Int32) -> Dataset {
  simple_iv_dataset(seed, n)
}

///|
/// The data frame of the instrumental variable scenario.
pub fn instrumental_variable_data(seed : Int32, n : Int32) -> @api.DataFrame {
  simple_iv_dataset(seed, n).df
}

///|
/// Mediation data: the treatment acts on the outcome through a frontdoor
/// mediator, while a common cause acts on both of them.
///
/// Mirrors `dowhy.datasets.linear_dataset(beta=10, num_frontdoor_variables=1,
/// num_common_causes=1, num_samples=n)`.  The columns are `FD0`, `W0`, `v0`
/// and `y`.
pub fn frontdoor_dataset(seed : Int32, n : Int32) -> Dataset {
  linear_dataset(seed, n, LinearConfig::frontdoor())
}

///|
/// The data frame of the frontdoor scenario.
pub fn frontdoor_data(seed : Int32, n : Int32) -> @api.DataFrame {
  frontdoor_dataset(seed, n).df
}
