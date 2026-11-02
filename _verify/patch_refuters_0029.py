"""The refuters of the v0.0.29 release.

Two divergences of the port are fixed:

  * the data subset refuter sampled the rows of the data with replacement,
    while the upstream samples a subset of them, without replacement;
  * the bootstrap refuter only resampled the data, while the upstream also
    perturbs the variables of interest -- the confounders, the instruments and
    the effect modifiers -- with a noise.

The selection of the variables the bootstrap refuter perturbs is the port of
`dowhy.causal_refuter.choose_variables`, and the argument of the upstream that
names the variables becomes an enumeration, because the enumeration cannot hold
a list that selects and a list that deselects at the same time -- the case the
upstream raises an error for.
"""

import io
import sys

PATH = r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\src\refuters\refuters.mbt"


def replace(text, old, new):
    if text.count(old) != 1:
        sys.exit("marker not found exactly once:\n" + old[:300])
    return text.replace(old, new)


OLD_BOOTSTRAP = """///|
/// The bootstrap refuter.
///
/// The data is resampled with replacement and the effect is re-estimated on
/// every resample; the refutation reports the mean of the resampled estimates
/// and the interval they span.
pub fn refute_bootstrap(
  estimator : @estimators.CausalEstimator,
  estimand : @identifiers.IdentifiedEstimand,
  data : @api.DataFrame,
  num_simulations : Int32,
  sample_size_fraction : Double,
  treatment_value : Double,
  control_value : Double,
  target_units : String,
  random : @utils.Random,
) -> CausalRefutation {
  let n = data.nrows()
  let sample_size = (sample_size_fraction * n.to_double()).to_int()
  let estimates : Array[Double] = []
  for i = 0; i < num_simulations; i = i + 1 {
    let rows = random.sample_with_replacement(index_column(n), sample_size)
    let resampled = take_rows(data, rows)
    let effect = reestimate(
      estimator, estimand, resampled, treatment_value, control_value, target_units,
    )
    estimates.push(effect)
  }
"""

NEW_BOOTSTRAP = """///|
/// The variables the bootstrap refuter perturbs.
///
/// This is the port of the `required_variables` argument of the upstream: a
/// boolean asks for every variable of interest or for none of them, an integer
/// asks for that many of them and a list names them. The upstream takes the
/// three of them in one argument and raises an error when a list selects and
/// deselects at the same time; the enumeration of the port cannot hold such a
/// list.
pub enum RequiredVariables {
  /// Every variable of interest.
  All
  /// No variable at all.
  None
  /// That many variables of interest, chosen at random.
  Count(Int32)
  /// The named variables of interest.
  Named(Array[String])
  /// Every variable of interest but the named ones.
  Others(Array[String])
}

///|
/// Every variable of interest.
pub fn RequiredVariables::all() -> RequiredVariables {
  RequiredVariables::All
}

///|
/// No variable at all.
pub fn RequiredVariables::none() -> RequiredVariables {
  RequiredVariables::None
}

///|
/// That many variables of interest, chosen at random.
pub fn RequiredVariables::count(count : Int32) -> RequiredVariables {
  RequiredVariables::Count(count)
}

///|
/// The named variables of interest.
pub fn RequiredVariables::named(names : Array[String]) -> RequiredVariables {
  RequiredVariables::Named(names)
}

///|
/// Every variable of interest but the named ones.
pub fn RequiredVariables::others(names : Array[String]) -> RequiredVariables {
  RequiredVariables::Others(names)
}

///|
/// The variables the refuters perturb.
///
/// This is the port of the `_variables_of_interest` of the upstream: the
/// adjustment set of the estimand, its instruments and the effect modifiers of
/// the estimator.
fn variables_of_interest(
  estimator : @estimators.CausalEstimator,
  estimand : @identifiers.IdentifiedEstimand,
) -> Array[String] {
  let out = estimand.get_adjustment_set(estimand.identifier_method())
  for name in estimand.get_instrumental_variables() {
    out.push(name)
  }
  for name in estimator.effect_modifiers() {
    out.push(name)
  }
  out
}

///|
/// The variables the refuter perturbs.
///
/// This is the port of `dowhy.causal_refuter.choose_variables`.
fn choose_variables(
  selection : RequiredVariables,
  variables_of_interest : Array[String],
  random : @utils.Random,
) -> Array[String] {
  match selection {
    RequiredVariables::All => variables_of_interest.copy()
    RequiredVariables::None => []
    RequiredVariables::Count(count) => {
      if count > variables_of_interest.length() {
        abort(
          "The number of variables in the required_variables is greater than the number of confounders, instrumental variables and effect modifiers",
        )
      }
      let shuffled = random.shuffle(index_column(variables_of_interest.length()))
      let out : Array[String] = []
      for i = 0; i < count; i = i + 1 {
        out.push(variables_of_interest[shuffled[i].to_int()])
      }
      out
    }
    RequiredVariables::Named(names) => {
      for name in names {
        if !variables_of_interest.contains(name) {
          abort(
            "At least one of required_variables is not a valid variable name, or it is not a confounder, instrumental variable or effect modifier",
          )
        }
      }
      names.copy()
    }
    RequiredVariables::Others(names) => {
      let out : Array[String] = []
      for name in variables_of_interest {
        if !names.contains(name) {
          out.push(name)
        }
      }
      out
    }
  }
}

///|
/// The bootstrap refuter.
///
/// The data is resampled with replacement and the variables of interest are
/// perturbed with a noise; the effect is re-estimated on every resample and the
/// refutation reports the mean of the resampled estimates and the interval they
/// span.
///
/// The noise of a numeric column has the standard deviation of the given
/// fraction of the standard deviation of the column, the way the upstream
/// perturbs it. A column of zeros and ones is flipped and a discrete column
/// gets another one of its categories, both with the given probability.
pub fn refute_bootstrap(
  estimator : @estimators.CausalEstimator,
  estimand : @identifiers.IdentifiedEstimand,
  data : @api.DataFrame,
  num_simulations : Int32,
  sample_size_fraction : Double,
  treatment_value : Double,
  control_value : Double,
  target_units : String,
  random : @utils.Random,
  required_variables~ : RequiredVariables = RequiredVariables::all(),
  noise~ : Double = 0.1,
  probability_of_change~ : Double = 0.1,
) -> CausalRefutation {
  let n = data.nrows()
  let sample_size = (sample_size_fraction * n.to_double()).to_int()
  let variables = choose_variables(
    required_variables,
    variables_of_interest(estimator, estimand),
    random,
  )
  let estimates : Array[Double] = []
  for i = 0; i < num_simulations; i = i + 1 {
    let rows = random.sample_with_replacement(index_column(n), sample_size)
    let resampled = take_rows(data, rows)
    let perturbed = perturb_variables(
      resampled,
      variables,
      noise,
      probability_of_change,
      random,
    )
    let effect = reestimate(
      estimator, estimand, perturbed, treatment_value, control_value, target_units,
    )
    estimates.push(effect)
  }
"""

OLD_SUBSET_LOOP = """  for i = 0; i < num_simulations; i = i + 1 {
    let rows = random.sample_with_replacement(index_column(n), subset_size)
    let subset = take_rows(data, rows)
"""

NEW_SUBSET_LOOP = """  for i = 0; i < num_simulations; i = i + 1 {
    // The upstream samples a subset of the rows of the data, without
    // replacement, and not a resample of them.
    let rows = random.sample_without_replacement(index_column(n), subset_size)
    let subset = take_rows(data, rows)
"""

OLD_SUBSET_DOC = """///|
/// The data subset refuter.
///
/// The effect is re-estimated on random subsets of the data; a robust
/// estimate does not depend on the subset.
"""

NEW_SUBSET_DOC = """///|
/// The data subset refuter.
///
/// The effect is re-estimated on random subsets of the data; a robust
/// estimate does not depend on the subset. The subset holds no row twice, the
/// way the upstream samples it.
"""

# The perturbation helpers are appended at the end of the file.
HELPERS = """

///|
/// The perturbation of the chosen variables of the bootstrap refuter.
///
/// A numeric column gets a Gaussian noise whose standard deviation is the
/// given fraction of the standard deviation of the column, a column of zeros
/// and ones gets its values flipped and a discrete column gets another one of
/// its categories.
///
/// The upstream perturbs the three kinds of column the same way, but it picks
/// them by the dtype of the column and its column of categories is broken: it
/// reads a variable it never defines when no boolean column came before it,
/// and it writes the integer zero into the rows it does not change. The port
/// picks the kind of the column the way the placebo refuter does and leaves
/// the rows it does not change alone.
fn perturb_variables(
  data : @api.DataFrame,
  variables : Array[String],
  noise : Double,
  probability_of_change : Double,
  random : @utils.Random,
) -> @api.DataFrame {
  let mut out = data
  for name in variables {
    if !out.has_column(name) {
      continue
    }
    if out.is_discrete(name) {
      let values = perturb_categories(
        out.discrete(name),
        probability_of_change,
        random,
      )
      out = out.with_discrete(name, values)
    } else {
      let values = out.numeric(name)
      if is_binary_column(values) {
        out = out.with_numeric(
          name,
          flip_values(values, probability_of_change, random),
        )
      } else {
        out = out.with_numeric(name, add_noise(values, noise, random))
      }
    }
  }
  out
}

///|
/// Whether the values of a column are all zeros and ones.
fn is_binary_column(values : Array[Double]) -> Bool {
  if values.length() == 0 {
    return false
  }
  for value in values {
    if value != 0.0 && value != 1.0 {
      return false
    }
  }
  true
}

///|
/// The values of a column with a Gaussian noise added to them.
///
/// The standard deviation of the noise is the given fraction of the standard
/// deviation of the column, the way the upstream scales its noise.
fn add_noise(
  values : Array[Double],
  noise : Double,
  random : @utils.Random,
) -> Array[Double] {
  let scale = noise * @utils.variance(values, 1).sqrt()
  let out : Array[Double] = []
  for value in values {
    out.push(value + random.next_normal() * scale)
  }
  out
}

///|
/// The values of a column with some of them flipped.
fn flip_values(
  values : Array[Double],
  probability_of_change : Double,
  random : @utils.Random,
) -> Array[Double] {
  let out : Array[Double] = []
  for value in values {
    if random.next_double() < probability_of_change {
      out.push(1.0 - value)
    } else {
      out.push(value)
    }
  }
  out
}

///|
/// The values of a discrete column with some of them replaced by another one
/// of its categories.
fn perturb_categories(
  values : Array[String],
  probability_of_change : Double,
  random : @utils.Random,
) -> Array[String] {
  let categories = distinct_categories(values)
  let out : Array[String] = []
  for value in values {
    if random.next_double() < probability_of_change && categories.length() > 1 {
      // The upstream draws one of the categories that are not the value of the
      // row.
      let others : Array[String] = []
      for category in categories {
        if category != value {
          others.push(category)
        }
      }
      out.push(others[random.next_int(others.length())])
    } else {
      out.push(value)
    }
  }
  out
}
"""

text = io.open(PATH, encoding="utf-8").read()
text = replace(text, OLD_BOOTSTRAP, NEW_BOOTSTRAP)
text = replace(text, OLD_SUBSET_LOOP, NEW_SUBSET_LOOP)
text = replace(text, OLD_SUBSET_DOC, NEW_SUBSET_DOC)
text = text.rstrip("\n") + "\n" + HELPERS
io.open(PATH, "w", encoding="utf-8", newline="\n").write(text)
print("patched")
