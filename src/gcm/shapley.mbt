///|
/// The Shapley values of a set function.
///
/// This is the port of `dowhy.gcm.shapley`. A set function takes a subset of
/// the players and returns the utility of that subset; the Shapley values
/// attribute the utility of the whole set to the players, which is often a
/// set of features or variables.
///
/// The upstream draws its randomness from the global numpy generator. The
/// port draws it from the seed of the configuration, so that the same
/// configuration always gives the same values.

///|
/// The way the Shapley values are estimated.
///
/// This is the port of `dowhy.gcm.shapley.ShapleyApproximationMethods`.
pub enum ShapleyApproximationMethod {
  ///
  /// The exact method for five players or less, the permutation method above.
  Auto
  ///
  /// All the subsets are evaluated and the Shapley values are the weighted
  /// sum of the differences of the set function, which is Eq. (2) in
  /// Janzing, Minorics and Bloebaum (2020).
  Exact
  ///
  /// All the subsets are evaluated and the Shapley values are the solution of
  /// a weighted least squares regression. This can be faster, but it is
  /// numerically less stable.
  ExactFast
  ///
  /// Randomly drawn subsets are evaluated and the Shapley values are the
  /// solution of a weighted least squares regression.
  SubsetSampling
  ///
  /// The Shapley values are estimated from a fixed number of random
  /// permutations of the players.
  Permutation
  ///
  /// The Shapley values are estimated from random permutations of the
  /// players, and the estimation stops when the values change less than the
  /// threshold for two runs in a row.
  EarlyStopping
}

///|
/// The automatic method, which is the exact one for five players or less.
pub fn ShapleyApproximationMethod::auto() -> ShapleyApproximationMethod {
  Auto
}

///|
/// The exact method.
pub fn ShapleyApproximationMethod::exact() -> ShapleyApproximationMethod {
  Exact
}

///|
/// The exact method with the least squares regression.
pub fn ShapleyApproximationMethod::exact_fast() -> ShapleyApproximationMethod {
  ExactFast
}

///|
/// The method that samples random subsets.
pub fn ShapleyApproximationMethod::subset_sampling() -> ShapleyApproximationMethod {
  SubsetSampling
}

///|
/// The method that samples random permutations.
pub fn ShapleyApproximationMethod::permutation() -> ShapleyApproximationMethod {
  Permutation
}

///|
/// The method that samples random permutations and stops early.
pub fn ShapleyApproximationMethod::early_stopping() -> ShapleyApproximationMethod {
  EarlyStopping
}

///|
/// The name of the method, like the name of the upstream enumeration.
pub fn ShapleyApproximationMethod::name(
  self : ShapleyApproximationMethod,
) -> String {
  match self {
    Auto => "AUTO"
    Exact => "EXACT"
    ExactFast => "EXACT_FAST"
    SubsetSampling => "SUBSET_SAMPLING"
    Permutation => "PERMUTATION"
    EarlyStopping => "EARLY_STOPPING"
  }
}

///|
/// The configuration of the estimation of the Shapley values.
///
/// This is the port of `dowhy.gcm.shapley.ShapleyConfig`. The upstream keeps
/// the number of parallel jobs in the configuration; the port runs everything
/// in one process and carries the seed of the random generator instead, so
/// that the random methods are reproducible.
pub struct ShapleyConfig {
  approximation_method : ShapleyApproximationMethod
  num_permutations : Int32
  num_subset_samples : Int32
  min_percentage_change_threshold : Double
  seed : UInt64
}

///|
/// The configuration of the given approximation method, with the defaults of
/// the upstream code.
///
/// The upstream uses twenty five permutations, five thousand sampled subsets
/// and a threshold of five percent for the early stopping.
pub fn ShapleyConfig::new(
  approximation_method : ShapleyApproximationMethod,
) -> ShapleyConfig {
  {
    approximation_method,
    num_permutations: 25,
    num_subset_samples: 5000,
    min_percentage_change_threshold: 0.05,
    seed: 0UL,
  }
}

///|
/// A copy of the configuration with the given number of permutations.
///
/// The number of permutations is only used by the permutation method and the
/// early stopping method. It is the maximum number of permutations that are
/// evaluated; the early stopping method may stop before it is reached.
pub fn ShapleyConfig::with_num_permutations(
  self : ShapleyConfig,
  value : Int32,
) -> ShapleyConfig {
  {
    approximation_method: self.approximation_method,
    num_permutations: value,
    num_subset_samples: self.num_subset_samples,
    min_percentage_change_threshold: self.min_percentage_change_threshold,
    seed: self.seed,
  }
}

///|
/// A copy of the configuration with the given number of sampled subsets.
///
/// The number of sampled subsets is only used by the subset sampling method.
pub fn ShapleyConfig::with_num_subset_samples(
  self : ShapleyConfig,
  value : Int32,
) -> ShapleyConfig {
  {
    approximation_method: self.approximation_method,
    num_permutations: self.num_permutations,
    num_subset_samples: value,
    min_percentage_change_threshold: self.min_percentage_change_threshold,
    seed: self.seed,
  }
}

///|
/// A copy of the configuration with the given threshold of the early stopping.
///
/// The threshold is the minimum relative change of the Shapley values between
/// two runs that the early stopping method accepts. The change has to stay
/// below the threshold for two runs in a row.
pub fn ShapleyConfig::with_min_percentage_change_threshold(
  self : ShapleyConfig,
  value : Double,
) -> ShapleyConfig {
  {
    approximation_method: self.approximation_method,
    num_permutations: self.num_permutations,
    num_subset_samples: self.num_subset_samples,
    min_percentage_change_threshold: value,
    seed: self.seed,
  }
}

///|
/// A copy of the configuration with the given seed.
///
/// The seed is the seed of the random generator that the random methods draw
/// their permutations and their subsets from.
pub fn ShapleyConfig::with_seed(
  self : ShapleyConfig,
  value : UInt64,
) -> ShapleyConfig {
  {
    approximation_method: self.approximation_method,
    num_permutations: self.num_permutations,
    num_subset_samples: self.num_subset_samples,
    min_percentage_change_threshold: self.min_percentage_change_threshold,
    seed: value,
  }
}

///|
/// The Shapley values of the players of a set function.
///
/// The set function takes the players of a subset as a vector of flags and
/// returns the utility of that subset. The values are the Shapley values of
/// the players, i.e. there are as many values as there are players, and the
/// value of the i-th player belongs to the i-th player.
///
/// The automatic method uses the exact method for five players or less and
/// the permutation method above, like the upstream code.
pub fn estimate_shapley_values(
  set_func : (Array[Bool]) -> Double,
  num_players : Int32,
  config : ShapleyConfig,
) -> Array[Double] {
  if num_players <= 0 {
    abort(
      "the number of players has to be positive, but it is " +
      num_players.to_string(),
    )
  }
  let approximation = resolve_approximation_method(
    config.approximation_method,
    num_players,
  )
  let rng = @utils.Random::new(config.seed)
  match approximation {
    Exact => shapley_values_exact(set_func, num_players)
    Permutation =>
      shapley_values_with_permutations(
        set_func,
        num_players,
        config.num_permutations,
        rng,
      )
    EarlyStopping =>
      shapley_values_with_early_stopping(
        set_func,
        num_players,
        config.num_permutations,
        config.min_percentage_change_threshold,
        rng,
      )
    SubsetSampling =>
      shapley_values_with_least_squares(
        set_func,
        num_players,
        true,
        config.num_subset_samples,
        rng,
      )
    ExactFast =>
      shapley_values_with_least_squares(set_func, num_players, false, -1, rng)
    Auto => abort("the automatic method has to be resolved before it is used")
  }
}

///|
/// The method that is used for the given number of players.
///
/// The automatic method is the exact one for five players or less and the
/// permutation method above, like the upstream code.
fn resolve_approximation_method(
  approximation : ShapleyApproximationMethod,
  num_players : Int32,
) -> ShapleyApproximationMethod {
  match approximation {
    Auto => if num_players <= 5 { Exact } else { Permutation }
    Exact => Exact
    ExactFast => ExactFast
    SubsetSampling => SubsetSampling
    Permutation => Permutation
    EarlyStopping => EarlyStopping
  }
}

///|
/// The Shapley values of Eq. (2) in
/// Janzing, D., Minorics, L., & Bloebaum, P. (2020).
/// Feature relevance quantification in explainable AI: A causal problem.
/// In International Conference on Artificial Intelligence and Statistics
/// (pp. 2907-2916). PMLR.
///
/// Every subset of the players is evaluated once, and the value of a player
/// is the weighted sum of the differences of the set function over all the
/// subsets of the other players. The weight of a subset of `k` players is
/// `1 / (n * C(n - 1, k))`.
fn shapley_values_exact(
  set_func : (Array[Bool]) -> Double,
  num_players : Int32,
) -> Array[Double] {
  let values = evaluate_all_subsets(set_func, num_players)
  let shapley : Array[Double] = []
  for _ in 0..<num_players {
    shapley.push(0.0)
  }
  let others = num_players - 1
  for player = 0; player < num_players; player = player + 1 {
    let mut total = 0.0
    // The subsets of the other players, in the order of the upstream code:
    // the first of the other players is the most significant one.
    for pattern = 0; pattern < 1 << others; pattern = pattern + 1 {
      let mut mask = 0
      let mut size = 0
      for k = 0; k < others; k = k + 1 {
        let other = if k < player { k } else { k + 1 }
        if ((pattern >> (others - 1 - k)) & 1) == 1 {
          mask = mask | (1 << (num_players - 1 - other))
          size = size + 1
        }
      }
      let weight = 1.0 / (num_players.to_double() * binomial(others, size))
      let with_player = mask | (1 << (num_players - 1 - player))
      total = total + weight * (values[with_player] - values[mask])
    }
    shapley[player] = total
  }
  shapley
}

///|
/// The value of the set function for every subset of the players.
///
/// The subsets are numbered like the upstream code numbers them, i.e. the
/// first player is the most significant bit of the number of a subset.
fn evaluate_all_subsets(
  set_func : (Array[Bool]) -> Double,
  num_players : Int32,
) -> Array[Double] {
  if num_players > 30 {
    abort(
      "the exact method needs at most 30 players, but " +
      num_players.to_string() +
      " were given",
    )
  }
  let values : Array[Double] = []
  for mask = 0; mask < 1 << num_players; mask = mask + 1 {
    values.push(set_func(subset_of_mask(mask, num_players)))
  }
  values
}

///|
/// The Shapley values that are estimated from random permutations.
///
/// The players are put in a random order, and the contribution of a player is
/// the difference of the set function between the players before it and the
/// players up to it. The values are the average over the permutations.
///
/// The upstream draws the permutations from a Halton sequence, which fills the
/// sample space more uniformly than random permutations do. The port draws
/// random permutations from the generator it is given, because the Halton
/// sequence of scipy cannot be reproduced here.
fn shapley_values_with_permutations(
  set_func : (Array[Bool]) -> Double,
  num_players : Int32,
  num_permutations : Int32,
  rng : @utils.Random,
) -> Array[Double] {
  let full = set_func(subset_of_all(true, num_players))
  let empty = set_func(subset_of_all(false, num_players))
  let total = factorial(num_players)
  let count = if total < num_permutations.to_double() {
    total.to_int()
  } else {
    num_permutations
  }
  if count <= 0 {
    abort("the number of permutations has to be positive")
  }
  let permutations : Array[Array[Int32]] = []
  for _ in 0..<count {
    permutations.push(random_permutation(rng, num_players))
  }
  let evaluated = evaluate_prefix_subsets(set_func, permutations, num_players)
  let shapley : Array[Double] = []
  for _ in 0..<num_players {
    shapley.push(0.0)
  }
  for permutation in permutations {
    let contributions = shapley_values_of_permutation(
      permutation, evaluated, full, empty, num_players,
    )
    for i = 0; i < num_players; i = i + 1 {
      shapley[i] = shapley[i] + contributions[i]
    }
  }
  for i = 0; i < num_players; i = i + 1 {
    shapley[i] = shapley[i] / count.to_double()
  }
  shapley
}

///|
/// The Shapley values that are estimated from random permutations, with an
/// early stopping.
///
/// The estimation stops when the Shapley values change less than the given
/// threshold for two runs in a row, or when the maximum number of
/// permutations is reached.
fn shapley_values_with_early_stopping(
  set_func : (Array[Bool]) -> Double,
  num_players : Int32,
  max_num_permutations : Int32,
  min_percentage_change_threshold : Double,
  rng : @utils.Random,
) -> Array[Double] {
  let permutations_per_run = 5
  let num_consecutive_converged_runs = 2
  let full = set_func(subset_of_all(true, num_players))
  let empty = set_func(subset_of_all(false, num_players))
  let evaluated : Map[Int32, Double] = Map([])
  let shapley : Array[Double] = []
  for _ in 0..<num_players {
    shapley.push(0.0)
  }
  let mut old_proxy : Array[Double] = []
  for _ in 0..<num_players {
    old_proxy.push(0.0)
  }
  let mut num_generated_permutations = 0
  let mut run_counter = 0
  let mut converged_runs = 0
  let mut running = true
  while running {
    run_counter = run_counter + 1
    let permutations : Array[Array[Int32]] = []
    for _ in 0..<permutations_per_run {
      permutations.push(random_permutation(rng, num_players))
    }
    // The subsets of the permutations that have not been evaluated yet.
    let pending : Map[Int32, Bool] = Map([])
    for permutation in permutations {
      let mut mask = 0
      for i = 0; i < permutation.length() - 1; i = i + 1 {
        mask = mask | (1 << (num_players - 1 - permutation[i]))
        if !evaluated.contains(mask) {
          pending.set(mask, true)
        }
      }
    }
    for mask in pending.keys() {
      evaluated.set(mask, set_func(subset_of_mask(mask, num_players)))
    }
    for permutation in permutations {
      num_generated_permutations = num_generated_permutations + 1
      let contributions = shapley_values_of_permutation(
        permutation, evaluated, full, empty, num_players,
      )
      for i = 0; i < num_players; i = i + 1 {
        shapley[i] = shapley[i] + contributions[i]
      }
    }
    if run_counter * permutations_per_run > max_num_permutations {
      running = false
    } else {
      // The current values are the average of the estimated ones.
      let new_proxy : Array[Double] = []
      for i = 0; i < num_players; i = i + 1 {
        new_proxy.push(shapley[i] / num_generated_permutations.to_double())
      }
      if run_counter > 1 {
        if check_convergence(
            new_proxy, old_proxy, min_percentage_change_threshold,
          ) {
          converged_runs = converged_runs + 1
        } else if converged_runs < num_consecutive_converged_runs {
          converged_runs = 0
        }
        if converged_runs >= num_consecutive_converged_runs {
          running = false
        }
      }
      old_proxy = new_proxy
    }
  }
  for i = 0; i < num_players; i = i + 1 {
    shapley[i] = shapley[i] / num_generated_permutations.to_double()
  }
  shapley
}

///|
/// The Shapley values that are the solution of a weighted least squares
/// regression.
///
/// The regression uses the indicators of the subsets as the features and the
/// value of the set function as the target, like the upstream code does.
///
/// The upstream fits the regression with `sklearn.linear_model.LinearRegression`
/// and its sample weights, which centres the features and the target with the
/// weighted means and solves the regression with the weighted samples. The
/// port does the same and solves the regression with the pseudo inverse of
/// the `utils` package.
fn shapley_values_with_least_squares(
  set_func : (Array[Bool]) -> Double,
  num_players : Int32,
  use_subset_approximation : Bool,
  num_subset_samples : Int32,
  rng : @utils.Random,
) -> Array[Double] {
  let high_weight = 1.0e20
  let (subsets, weights) = if use_subset_approximation {
    sampled_subsets_and_weights(
      num_players, high_weight, num_subset_samples, rng,
    )
  } else {
    exact_subsets_and_weights(num_players, high_weight)
  }
  let design = @utils.Matrix::zeros(subsets.length(), num_players)
  let targets : Array[Double] = []
  for i = 0; i < subsets.length(); i = i + 1 {
    for j = 0; j < num_players; j = j + 1 {
      design.set(i, j, if subsets[i][j] { 1.0 } else { 0.0 })
    }
    targets.push(set_func(subsets[i]))
  }
  weighted_least_squares(design, targets, weights)
}

///|
/// All the subsets of the players with their weights.
///
/// The empty subset and the full subset get a very high weight, which stands
/// for an infinite one; the other subsets get the weight of Section 4.1.1 in
/// Janzing, Minorics and Bloebaum (2020).
fn exact_subsets_and_weights(
  num_players : Int32,
  high_weight : Double,
) -> (Array[Array[Bool]], Array[Double]) {
  let subsets : Array[Array[Bool]] = []
  let weights : Array[Double] = []
  let num_iterations = (num_players + 1) / 2
  for i = 0; i < num_iterations; i = i + 1 {
    add_subsets_of_size(subsets, weights, num_players, i, high_weight)
    add_subsets_of_size(
      subsets,
      weights,
      num_players,
      num_players - i,
      high_weight,
    )
    if i == num_iterations - 1 && num_players % 2 == 0 {
      add_subsets_of_size(subsets, weights, num_players, i + 1, high_weight)
    }
  }
  (subsets, weights)
}

///|
/// The subsets of the given size with their weights.
fn add_subsets_of_size(
  subsets : Array[Array[Bool]],
  weights : Array[Double],
  num_players : Int32,
  size : Int32,
  high_weight : Double,
) -> Unit {
  for combination in combinations(num_players, size) {
    let subset : Array[Bool] = []
    for _ in 0..<num_players {
      subset.push(false)
    }
    for index in combination {
      subset[index] = true
    }
    subsets.push(subset)
    weights.push(weight_of_subset(size, num_players, high_weight))
  }
}

///|
/// The weight of a subset of the given size.
///
/// The empty subset and the full subset get the high weight, which stands for
/// an infinite one. The other subsets get the weight of Section 4.1.1 in
/// Janzing, Minorics and Bloebaum (2020).
fn weight_of_subset(
  size : Int32,
  num_players : Int32,
  high_weight : Double,
) -> Double {
  if size == 0 || size == num_players {
    return high_weight
  }
  (num_players - 1).to_double() /
  (
    binomial(num_players, size) *
    size.to_double() *
    (num_players - size).to_double()
  )
}

///|
/// Randomly drawn subsets of the players with their weights.
///
/// The size of a subset is drawn from the distribution of the upstream code,
/// and the players of the subset are drawn without replacement. The weight of
/// a subset is the number of times it was drawn.
fn sampled_subsets_and_weights(
  num_players : Int32,
  high_weight : Double,
  num_subset_samples : Int32,
  rng : @utils.Random,
) -> (Array[Array[Bool]], Array[Double]) {
  let subsets : Array[Array[Bool]] = [
    subset_of_all(false, num_players),
    subset_of_all(true, num_players),
  ]
  let weights : Array[Double] = [high_weight, high_weight]
  let index_of : Map[Int32, Int32] = Map([])
  index_of.set(0, 0)
  index_of.set(mask_of_all(num_players), 1)
  let probabilities = subset_size_probabilities(num_players)
  for _ in 0..<num_subset_samples {
    let size = draw_subset_size(probabilities, rng)
    let indices = choose_without_replacement(rng, num_players, size)
    let mask = mask_of(indices, num_players)
    let subset : Array[Bool] = []
    for j = 0; j < num_players; j = j + 1 {
      subset.push(((mask >> (num_players - 1 - j)) & 1) == 1)
    }
    if index_of.contains(mask) {
      let index = index_of.get(mask).unwrap()
      weights[index] = weights[index] + 1.0
    } else {
      index_of.set(mask, subsets.length())
      subsets.push(subset)
      weights.push(1.0)
    }
  }
  (subsets, weights)
}

///|
/// The probability of the size of a randomly drawn subset.
///
/// The empty subset and the full subset are never drawn, so their probability
/// is zero.
fn subset_size_probabilities(num_players : Int32) -> Array[Double] {
  let probabilities : Array[Double] = []
  let mut total = 0.0
  for i = 0; i <= num_players; i = i + 1 {
    if i == 0 || i == num_players {
      probabilities.push(0.0)
    } else {
      let probability = (num_players - 1).to_double() /
        (i.to_double() * (num_players - i).to_double())
      probabilities.push(probability)
      total = total + probability
    }
  }
  for i = 0; i < probabilities.length(); i = i + 1 {
    probabilities[i] = probabilities[i] / total
  }
  probabilities
}

///|
/// The size of a randomly drawn subset.
fn draw_subset_size(
  probabilities : Array[Double],
  rng : @utils.Random,
) -> Int32 {
  let draw = rng.next_double()
  let mut cumulative = 0.0
  let mut size = 1
  for i = 1; i < probabilities.length() - 1; i = i + 1 {
    cumulative = cumulative + probabilities[i]
    size = i
    if draw < cumulative {
      return i
    }
  }
  size
}

///|
/// A random choice of `size` of the `n` numbers, without replacement.
fn choose_without_replacement(
  rng : @utils.Random,
  n : Int32,
  size : Int32,
) -> Array[Int32] {
  let pool : Array[Int32] = []
  for i = 0; i < n; i = i + 1 {
    pool.push(i)
  }
  let chosen : Array[Int32] = []
  for i = 0; i < size; i = i + 1 {
    let j = i + rng.next_int(n - i)
    let tmp = pool[i]
    pool[i] = pool[j]
    pool[j] = tmp
    chosen.push(pool[i])
  }
  chosen
}

///|
/// The solution of the weighted least squares regression of the targets on the
/// features.
///
/// The features and the target are centred with the weighted means and the
/// samples are weighted with the square root of their weight, like the
/// upstream code does.
fn weighted_least_squares(
  design : @utils.Matrix,
  targets : Array[Double],
  weights : Array[Double],
) -> Array[Double] {
  let n = design.nrows()
  let p = design.ncols()
  let mut total_weight = 0.0
  for weight in weights {
    total_weight = total_weight + weight
  }
  let x_offset : Array[Double] = []
  for j = 0; j < p; j = j + 1 {
    let mut sum = 0.0
    for i = 0; i < n; i = i + 1 {
      sum = sum + weights[i] * design.get(i, j)
    }
    x_offset.push(sum / total_weight)
  }
  let mut target_sum = 0.0
  for i = 0; i < n; i = i + 1 {
    target_sum = target_sum + weights[i] * targets[i]
  }
  let y_offset = target_sum / total_weight
  let centred = @utils.Matrix::zeros(n, p)
  let centred_targets : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    let scale = weights[i].sqrt()
    for j = 0; j < p; j = j + 1 {
      centred.set(i, j, (design.get(i, j) - x_offset[j]) * scale)
    }
    centred_targets.push((targets[i] - y_offset) * scale)
  }
  @utils.lstsq(centred, centred_targets)
}

///|
/// The values of the set function for the subsets of the permutations.
///
/// Only the proper prefixes of the permutations are evaluated; the empty
/// subset and the full subset are evaluated by the caller.
fn evaluate_prefix_subsets(
  set_func : (Array[Bool]) -> Double,
  permutations : Array[Array[Int32]],
  num_players : Int32,
) -> Map[Int32, Double] {
  let masks : Map[Int32, Bool] = Map([])
  for permutation in permutations {
    let mut mask = 0
    for i = 0; i < permutation.length() - 1; i = i + 1 {
      mask = mask | (1 << (num_players - 1 - permutation[i]))
      masks.set(mask, true)
    }
  }
  let evaluated : Map[Int32, Double] = Map([])
  for mask in masks.keys() {
    evaluated.set(mask, set_func(subset_of_mask(mask, num_players)))
  }
  evaluated
}

///|
/// The contribution of every player in one permutation.
///
/// The contribution of a player is the difference of the set function between
/// the players before it and the players up to it.
fn shapley_values_of_permutation(
  permutation : Array[Int32],
  evaluated : Map[Int32, Double],
  full : Double,
  empty : Double,
  num_players : Int32,
) -> Array[Double] {
  let shapley : Array[Double] = []
  for _ in 0..<num_players {
    shapley.push(0.0)
  }
  let mut mask = 0
  let mut previous = empty
  for i = 0; i < permutation.length() - 1; i = i + 1 {
    let player = permutation[i]
    mask = mask | (1 << (num_players - 1 - player))
    let current = evaluated.get(mask).unwrap()
    shapley[player] = current - previous
    previous = current
  }
  let last = permutation[permutation.length() - 1]
  shapley[last] = full - previous
  shapley
}

///|
/// Whether the Shapley values changed less than the threshold.
///
/// A value that was zero before and is zero now counts as converged, a value
/// that was zero before and is not zero now does not.
fn check_convergence(
  new_proxy : Array[Double],
  old_proxy : Array[Double],
  threshold : Double,
) -> Bool {
  let mut converging = true
  for i = 0; i < new_proxy.length(); i = i + 1 {
    if old_proxy[i] != 0.0 {
      let change = (1.0 - new_proxy[i] / old_proxy[i]).abs()
      if change >= threshold {
        converging = false
      }
    } else if new_proxy[i] != old_proxy[i] {
      converging = false
    }
  }
  converging
}

///|
/// The subset of the players that the given number stands for.
///
/// The first player is the most significant bit, like in the upstream code.
fn subset_of_mask(mask : Int32, num_players : Int32) -> Array[Bool] {
  let subset : Array[Bool] = []
  for j = 0; j < num_players; j = j + 1 {
    subset.push(((mask >> (num_players - 1 - j)) & 1) == 1)
  }
  subset
}

///|
/// The subset that holds all the players or none of them.
fn subset_of_all(value : Bool, num_players : Int32) -> Array[Bool] {
  let subset : Array[Bool] = []
  for _ in 0..<num_players {
    subset.push(value)
  }
  subset
}

///|
/// The number of the subset that holds all the players.
fn mask_of_all(num_players : Int32) -> Int32 {
  (1 << num_players) - 1
}

///|
/// The number of the subset that holds the given players.
fn mask_of(indices : Array[Int32], num_players : Int32) -> Int32 {
  let mut mask = 0
  for index in indices {
    mask = mask | (1 << (num_players - 1 - index))
  }
  mask
}

///|
/// The binomial coefficient of `n` and `k`.
///
/// The numbers the Shapley values use are small, so the product is exact.
fn binomial(n : Int32, k : Int32) -> Double {
  if k < 0 || k > n {
    return 0.0
  }
  let smaller = if k < n - k { k } else { n - k }
  let mut result = 1.0
  for i = 1; i <= smaller; i = i + 1 {
    result = result * (n - smaller + i).to_double() / i.to_double()
  }
  result
}

///|
/// The factorial of the given number.
///
/// The upstream uses it to cap the number of permutations of the players.
fn factorial(n : Int32) -> Double {
  let mut result = 1.0
  for i = 2; i <= n; i = i + 1 {
    result = result * i.to_double()
  }
  result
}

///|
/// All the subsets of the given size, in the order of the upstream code.
fn combinations(num_players : Int32, size : Int32) -> Array[Array[Int32]] {
  let out : Array[Array[Int32]] = []
  if size < 0 || size > num_players {
    return out
  }
  let current : Array[Int32] = []
  for i = 0; i < size; i = i + 1 {
    current.push(i)
  }
  if size == 0 {
    out.push(current.copy())
    return out
  }
  let mut more = true
  while more {
    out.push(current.copy())
    let mut k = size - 1
    while k >= 0 && current[k] == num_players - size + k {
      k = k - 1
    }
    if k < 0 {
      more = false
    } else {
      current[k] = current[k] + 1
      let mut j = k + 1
      while j < size {
        current[j] = current[j - 1] + 1
        j = j + 1
      }
    }
  }
  out
}
