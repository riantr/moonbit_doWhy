///|
/// The data generating processes of the upstream.
///
/// The upstream of DoWhy has a base class for the data generating processes
/// and three processes: a linear one, a quadratic one and a cubic one. The port
/// holds the three of them in one structure, the kind of the process tells
/// which one it is, and the process owns its generator of numpy. The upstream
/// draws from the global generator of numpy, which every object of the program
/// shares, so the data of the upstream depends on the other objects of the
/// program and the data of the port does not.
///
/// The processes of the upstream draw their numbers in an order that the port
/// follows exactly, because the numbers of the upstream are only reproducible
/// with the seed of the process. The linear process draws the weights of the
/// process, the confounder and the noise of the treatment. The quadratic
/// process draws the confounder, the effect modifier, the weights and the
/// noise of the treatment. The cubic process draws the confounder, the effect
/// modifier, and then the weights and the noise of the treatment of every
/// power.

///|
/// The percentile of the binary treatment of the upstream.
const DGP_DEFAULT_PERCENTILE : Double = 0.9

///|
/// The seed of the generator of numpy of a process without a seed.
const DGP_DEFAULT_SEED : Int64 = 0

///|
/// The kind of a data generating process.
pub enum DgpKind {
  /// The linear process of the upstream.
  Linear
  /// The quadratic process of the upstream.
  Quadratic
  /// The cubic process of the upstream.
  Cubic
}

///|
/// The weights of a data generating process.
///
/// The upstream holds the weights in a dictionary with four keys. The port
/// holds them in four matrices.
pub struct DgpWeights {
  /// The weights of the confounders on the treatment.
  mut confounder_to_treatment : @utils.Matrix
  /// The weights of the confounders on the outcome.
  mut confounder_to_outcome : @utils.Matrix
  /// The weights of the effect modifier on the outcome.
  mut effect_modifier_to_outcome : @utils.Matrix
  /// The weights of the treatment on the outcome.
  mut treatment_to_outcome : @utils.Matrix
}

///|
/// The bias of a data generating process.
///
/// The upstream holds the bias in a dictionary with two keys. The port holds
/// them in two vectors.
pub struct DgpBias {
  /// The bias of the treatment.
  mut confounder_to_treatment : Array[Double]
  /// The bias of the outcome.
  mut confounder_to_outcome : Array[Double]
}

///|
/// The configuration of a data generating process.
///
/// The configuration holds the names of the columns of the data, the seed of
/// the generator of numpy, the flag of the binary treatment and the percentile
/// of the binary treatment.
pub struct DgpConfig {
  /// The names of the columns of the treatment.
  treatment : Array[String]
  /// The names of the columns of the outcome.
  outcome : Array[String]
  /// The names of the columns of the confounders.
  confounder : Array[String]
  /// The names of the columns of the effect modifier.
  effect_modifier : Array[String]
  /// The seed of the generator of numpy.
  seed : Int64?
  /// Whether the treatment is binary.
  treatment_is_binary : Bool
  /// The percentile of the binary treatment.
  percentile : Double
}

///|
/// A data generating process of the upstream.
pub struct DataGeneratingProcess {
  /// The kind of the process.
  kind : DgpKind
  /// The configuration of the process.
  config : DgpConfig
  /// The generator of numpy of the process.
  generator : @utils.NumpyRandom
  /// The weights of the process.
  weights : DgpWeights
  /// The bias of the process.
  bias : DgpBias
  /// The value of the effect of the treatment.
  mut true_value : Array[Double]
}

///|
/// The configuration of a data generating process.
///
/// The seed of the configuration is the seed of the generator of numpy. The
/// percentile is the percentile of the binary treatment, and it is used only
/// when the treatment is binary. The upstream raises a `ValueError` when a
/// percentile is given for a treatment that is not binary, and it holds the
/// text `NA` as the percentile of such a treatment.
pub fn DgpConfig::new(
  treatment : Array[String],
  outcome : Array[String],
  confounder : Array[String],
  effect_modifier : Array[String],
  seed : Int64?,
  treatment_is_binary : Bool,
  percentile~ : Double = DGP_DEFAULT_PERCENTILE,
) -> DgpConfig {
  {
    treatment,
    outcome,
    confounder,
    effect_modifier,
    seed,
    treatment_is_binary,
    percentile,
  }
}

///|
/// Whether the percentile of the configuration is used by the process.
///
/// The upstream raises a `ValueError` when a percentile is given for a
/// treatment that is not binary, and it holds the text `NA` as the percentile
/// of such a treatment. The port holds the percentile in every configuration
/// and uses it only for a binary treatment.
pub fn DgpConfig::percentile_is_used(self : DgpConfig) -> Bool {
  self.treatment_is_binary
}

///|
/// The linear data generating process of the upstream.
///
/// This is the port of `LinearDataGeneratingProcess` of the upstream.
pub fn DataGeneratingProcess::new_linear(
  config : DgpConfig,
) -> DataGeneratingProcess {
  DataGeneratingProcess::new(DgpKind::Linear, config)
}

///|
/// The quadratic data generating process of the upstream.
///
/// This is the port of `QuadraticDataGeneratingProcess` of the upstream.
pub fn DataGeneratingProcess::new_quadratic(
  config : DgpConfig,
) -> DataGeneratingProcess {
  DataGeneratingProcess::new(DgpKind::Quadratic, config)
}

///|
/// The cubic data generating process of the upstream.
///
/// This is the port of `CubicDataGeneratingProcess` of the upstream.
pub fn DataGeneratingProcess::new_cubic(
  config : DgpConfig,
) -> DataGeneratingProcess {
  DataGeneratingProcess::new(DgpKind::Cubic, config)
}

///|
/// The data of the process for the given number of rows.
///
/// This is the port of `generate_data` of the upstream. The columns of the
/// data are the effect modifier, the confounders, the treatment and the
/// outcome, the way the upstream builds its frame.
pub fn DataGeneratingProcess::generate_data(
  self : DataGeneratingProcess,
  sample_size : Int32,
) -> @api.DataFrame {
  match self.kind {
    DgpKind::Linear => self.generate_linear(sample_size)
    DgpKind::Quadratic => self.generate_quadratic(sample_size)
    DgpKind::Cubic => self.generate_cubic(sample_size)
  }
}

///|
/// The value of the effect of the treatment.
///
/// This is the port of the `true_value` of the upstream. The upstream holds it
/// after the data of the process is drawn.
pub fn DataGeneratingProcess::effect(
  self : DataGeneratingProcess,
) -> Array[Double] {
  self.true_value.copy()
}

///|
/// The sets of the weights of the powers of the process.
///
/// The upstream holds the weights of the linear process in a dictionary and the
/// weights of the quadratic and the cubic process in a list of the
/// dictionaries of the powers. Every dictionary of that list is the same
/// dictionary, because the upstream keeps a reference to one dictionary and
/// rewrites it, so every set of the list of the port is the set of the weights
/// of the process.
pub fn DataGeneratingProcess::weights_of_powers(
  self : DataGeneratingProcess,
) -> Array[DgpWeights] {
  let sets : Array[DgpWeights] = []
  let count = match self.kind {
    DgpKind::Linear => 1
    DgpKind::Quadratic => 2
    DgpKind::Cubic => 3
  }
  for _ in 0..<count {
    sets.push(self.weights)
  }
  sets
}

///|
/// The sets of the bias of the powers of the process.
///
/// The bias follows the weights of the process, the way the bias of the
/// upstream follows its weights.
pub fn DataGeneratingProcess::bias_of_powers(
  self : DataGeneratingProcess,
) -> Array[DgpBias] {
  let sets : Array[DgpBias] = []
  let count = match self.kind {
    DgpKind::Linear => 1
    DgpKind::Quadratic => 2
    DgpKind::Cubic => 3
  }
  for _ in 0..<count {
    sets.push(self.bias)
  }
  sets
}

///|
/// The binary treatment of the given continuous one.
///
/// This is the port of `convert_to_binary` of the upstream. The upstream ranks
/// the rows of the treatment, draws a Bernoulli for every row whose
/// probability is the rank of the row divided by the number of the rows, and
/// then flips a part of the rows: the ones when the percentile is at least one
/// half, the zeros otherwise.
///
/// The upstream converts the first column of the treatment and returns a
/// treatment of one column, so a binary treatment of the upstream has one
/// treatment column.
///
/// The deterministic form of the conversion takes the percentile of the
/// treatment and holds a one for every row that is at most the percentile. The
/// upstream passes the percentile of the process, which is a fraction, to the
/// percentile of numpy, which expects a number between zero and a hundred, so
/// the upstream takes the percentile of a fraction of a percent. The port takes
/// the same number.
pub fn DataGeneratingProcess::convert_to_binary(
  self : DataGeneratingProcess,
  treatment : Array[Double],
  deterministic~ : Bool = false,
) -> Array[Double] {
  let count = treatment.length()
  if deterministic {
    let threshold = @utils.percentile(treatment, self.config.percentile)
    let values : Array[Double] = []
    for value in treatment {
      values.push(if value <= threshold { 1.0 } else { 0.0 })
    }
    return values
  }
  let order = dgp_argsort(treatment)
  let ranks : Array[Int32] = []
  for _ in 0..<count {
    ranks.push(0)
  }
  for index in 0..<count {
    ranks[order[index]] = index
  }
  let probabilities : Array[Double] = []
  for index in 0..<count {
    probabilities.push(ranks[index].to_double() / count.to_double())
  }
  let binary = self.generator.bernoulli_array(probabilities)
  if self.config.percentile >= 0.5 {
    let ones = dgp_rows_of(binary, 1)
    let mask = self.generator.bernoulli_repeated(
      (1.0 - self.config.percentile) * 2.0,
      ones.length(),
    )
    for index in 0..<ones.length() {
      binary[ones[index]] = mask[index]
    }
  } else {
    let zeros = dgp_rows_of(binary, 0)
    let mask = self.generator.bernoulli_repeated(
      1.0 - self.config.percentile * 2.0,
      zeros.length(),
    )
    for index in 0..<zeros.length() {
      binary[zeros[index]] = mask[index] + binary[zeros[index]]
    }
  }
  let values : Array[Double] = []
  for index in 0..<count {
    values.push(binary[index].to_double())
  }
  values
}

///|
/// The process of the given kind and configuration.
fn DataGeneratingProcess::new(
  kind : DgpKind,
  config : DgpConfig,
) -> DataGeneratingProcess {
  let seed = match config.seed {
    Some(value) => value
    None => DGP_DEFAULT_SEED
  }
  {
    kind,
    config,
    generator: @utils.NumpyRandom::new(seed.reinterpret_as_uint64()),
    weights: DgpWeights::empty(),
    bias: DgpBias::empty(),
    true_value: [],
  }
}

///|
/// The weights and the bias of the process.
///
/// This is the port of `generation_process` of the upstream. The upstream draws
/// the weights of the confounders on the treatment, the weights of the
/// confounders on the outcome, the weights of the effect modifier on the
/// outcome, the weights of the treatment on the outcome, the bias of the
/// treatment and the bias of the outcome.
///
/// The linear process of the upstream raises the weight of the first
/// confounder by a hundred, the quadratic and the cubic process of the
/// upstream do not.
fn DataGeneratingProcess::generation_process(
  self : DataGeneratingProcess,
) -> Unit {
  self.draw_weights()
  let treatment_count = self.config.treatment.length()
  let outcome_count = self.config.outcome.length()
  for column in 0..<treatment_count {
    let value = self.weights.confounder_to_treatment.get(0, column) + 100.0
    self.weights.confounder_to_treatment.set(0, column, value)
  }
  for column in 0..<outcome_count {
    let value = self.weights.confounder_to_outcome.get(0, column) + 100.0
    self.weights.confounder_to_outcome.set(0, column, value)
  }
}

///|
/// The weights and the bias of the process, without the weight of the first
/// confounder.
///
/// This is the port of the `generation_process` of the quadratic and the cubic
/// process of the upstream, which do not raise the weight of the first
/// confounder.
fn DataGeneratingProcess::generation_process_plain(
  self : DataGeneratingProcess,
) -> Unit {
  self.draw_weights()
}

///|
/// The weights and the bias of the process.
fn DataGeneratingProcess::draw_weights(self : DataGeneratingProcess) -> Unit {
  let confounder_count = self.config.confounder.length()
  let treatment_count = self.config.treatment.length()
  let outcome_count = self.config.outcome.length()
  let modifier_count = self.config.effect_modifier.length()
  self.weights.confounder_to_treatment = self.generator.randn(
    confounder_count, treatment_count,
  )
  self.weights.confounder_to_outcome = self.generator.randn(
    confounder_count, outcome_count,
  )
  self.weights.effect_modifier_to_outcome = self.generator.randn(
    modifier_count, outcome_count,
  )
  self.weights.treatment_to_outcome = self.generator.randn(
    treatment_count, outcome_count,
  )
  self.bias.confounder_to_treatment = self.generator
    .randn(treatment_count, 1)
    .col(0)
  self.bias.confounder_to_outcome = self.generator
    .randn(outcome_count, 1)
    .col(0)
}

///|
/// The weights of a process that has not drawn its weights yet.
fn DgpWeights::empty() -> DgpWeights {
  {
    confounder_to_treatment: @utils.Matrix::zeros(0, 0),
    confounder_to_outcome: @utils.Matrix::zeros(0, 0),
    effect_modifier_to_outcome: @utils.Matrix::zeros(0, 0),
    treatment_to_outcome: @utils.Matrix::zeros(0, 0),
  }
}

///|
/// The bias of a process that has not drawn its bias yet.
fn DgpBias::empty() -> DgpBias {
  { confounder_to_treatment: [], confounder_to_outcome: [], }
}

///|
/// The indices of the rows that hold the given value.
///
/// This is the port of the mask of the upstream, which holds the rows of the
/// treatment that hold the given value in the order of the rows.
fn dgp_rows_of(values : Array[Int32], wanted : Int32) -> Array[Int32] {
  let rows : Array[Int32] = []
  for index in 0..<values.length() {
    if values[index] == wanted {
      rows.push(index)
    }
  }
  rows
}

///|
/// The indices of the rows that sort the given values.
///
/// This is the port of the ranking of the upstream. The upstream sorts the
/// treatment with the quicksort of numpy, whose order of the rows that hold
/// the same value is not the order of the rows. The port sorts the rows that
/// hold the same value in the order of the rows, so the two differ only when
/// the treatment holds the same value twice.
fn dgp_argsort(values : Array[Double]) -> Array[Int32] {
  let order : Array[Int32] = []
  for index in 0..<values.length() {
    order.push(index)
  }
  order.sort_by(fn(a, b) { @utils.compare_double(values[a], values[b]) })
  order
}

///|
/// The matrix that holds the sum of the two matrices.
///
/// The two matrices have the same shape.
fn dgp_add(left : @utils.Matrix, right : @utils.Matrix) -> @utils.Matrix {
  let out = @utils.Matrix::zeros(left.nrows(), left.ncols())
  for row in 0..<left.nrows() {
    for column in 0..<left.ncols() {
      out.set(row, column, left.get(row, column) + right.get(row, column))
    }
  }
  out
}

///|
/// The matrix that holds the difference of the two matrices.
///
/// The two matrices have the same shape.
fn dgp_subtract(left : @utils.Matrix, right : @utils.Matrix) -> @utils.Matrix {
  let out = @utils.Matrix::zeros(left.nrows(), left.ncols())
  for row in 0..<left.nrows() {
    for column in 0..<left.ncols() {
      out.set(row, column, left.get(row, column) - right.get(row, column))
    }
  }
  out
}

///|
/// The matrix that holds the product of the two matrices.
///
/// The two matrices have the same shape, and the product is the product of
/// every pair of the rows and the columns.
fn dgp_multiply(left : @utils.Matrix, right : @utils.Matrix) -> @utils.Matrix {
  let out = @utils.Matrix::zeros(left.nrows(), left.ncols())
  for row in 0..<left.nrows() {
    for column in 0..<left.ncols() {
      out.set(row, column, left.get(row, column) * right.get(row, column))
    }
  }
  out
}

///|
/// The matrix that holds the sum of the matrix and the bias.
///
/// The bias is added to every row of the matrix, the way the upstream adds the
/// bias of the treatment to every row of its treatment.
fn dgp_add_bias(matrix : @utils.Matrix, bias : Array[Double]) -> @utils.Matrix {
  let out = @utils.Matrix::zeros(matrix.nrows(), matrix.ncols())
  for row in 0..<matrix.nrows() {
    for column in 0..<matrix.ncols() {
      out.set(row, column, matrix.get(row, column) + bias[column])
    }
  }
  out
}

///|
/// The mean of every column of the matrix.
///
/// This is the port of the mean of the upstream over the rows of the matrix.
fn dgp_mean_columns(matrix : @utils.Matrix) -> Array[Double] {
  let values : Array[Double] = []
  for column in 0..<matrix.ncols() {
    values.push(@utils.mean(matrix.col(column)))
  }
  values
}

///|
/// The frame of the columns of the data.
///
/// The columns of the frame are the effect modifier, the confounders, the
/// treatment and the outcome, the way the upstream builds its frame.
fn dgp_frame(parts : Array[(Array[String], @utils.Matrix)]) -> @api.DataFrame {
  let order : Array[String] = []
  let columns : Map[String, Array[Double]] = Map([])
  for part in parts {
    let (names, matrix) = part
    for index in 0..<names.length() {
      if index < matrix.ncols() {
        columns.set(names[index], matrix.col(index))
        order.push(names[index])
      }
    }
  }
  @api.DataFrame::from_numeric(order, columns)
}

///|
/// The matrix of the given number of ones.
fn dgp_ones(rows : Int32, cols : Int32) -> @utils.Matrix {
  let out = @utils.Matrix::zeros(rows, cols)
  for row in 0..<rows {
    for column in 0..<cols {
      out.set(row, column, 1.0)
    }
  }
  out
}

///|
/// The matrix of the given number of zeros.
fn dgp_zeros(rows : Int32, cols : Int32) -> @utils.Matrix {
  @utils.Matrix::zeros(rows, cols)
}

///|
/// The treatment of the data, the binary one when the treatment is binary.
///
/// This is the port of the conversion of the upstream, which is applied to the
/// treatment of the data when the treatment is binary.
fn DataGeneratingProcess::dgp_treatment(
  self : DataGeneratingProcess,
  treatment : @utils.Matrix,
) -> @utils.Matrix {
  if self.config.treatment_is_binary {
    let values = self.convert_to_binary(treatment.col(0))
    @utils.Matrix::from_columns([values])
  } else {
    treatment
  }
}
