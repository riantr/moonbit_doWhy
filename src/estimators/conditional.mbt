/// The conditional estimates of the effect of the treatment.
///
/// This is the port of the `_estimate_conditional_effects` of the upstream, which
/// the regression based estimators of the upstream use. A continuous effect
/// modifier is split into `NUM_QUANTILES_TO_DISCRETIZE_CONT_COLS` quantile
/// groups first, the way `pandas.qcut` does it, and the effect is estimated on
/// every group with the model that was fitted on the whole data.

///|
/// The conditional estimates of the effect, one per group of the effect
/// modifier.
///
/// The key of a group is the value of the discretised effect modifier, or the
/// values of the discretised effect modifiers when there is more than one.
/// The list is empty when the estimator has no effect modifier, which is what
/// the upstream reports as a `None`.
pub fn CausalEstimator::estimate_conditional_effects(
  self : CausalEstimator,
  data : @api.DataFrame,
  treatment_value : Double,
  control_value : Double,
) -> Array[(String, Double)] {
  let out : Array[(String, Double)] = []
  if self.effect_modifier_names.length() == 0 {
    return out
  }
  let (keys, groups) = self.group_by_effect_modifiers(data)
  let mut i = 0
  while i < groups.length() {
    let subset = data.take_rows(groups[i])
    let treated = self.interventional_outcomes(subset, treatment_value)
    let control = self.interventional_outcomes(subset, control_value)
    out.push((keys[i], @utils.mean(treated) - @utils.mean(control)))
    i = i + 1
  }
  out
}

///|
/// The conditional estimates of the effect, attached to the estimate.
///
/// The upstream computes the conditional estimates of the regression based
/// estimators and hands them to the estimate, so that the estimate carries
/// them.
fn CausalEstimator::add_conditional_estimates(
  self : CausalEstimator,
  estimate : @model.CausalEstimate,
  data : @api.DataFrame,
) -> Unit {
  let conditional = self.estimate_conditional_effects(
    data,
    self.treatment_value,
    self.control_value,
  )
  for entry in conditional {
    let (key, value) = entry
    estimate.add_conditional_estimate(key, value)
  }
}

///|
/// The groups of the rows of the data, keyed by the value of the effect
/// modifiers.
///
/// The groups are in the order of their key, like the groups of the upstream.
fn CausalEstimator::group_by_effect_modifiers(
  self : CausalEstimator,
  data : @api.DataFrame,
) -> (Array[String], Array[Array[Int32]]) {
  let n = data.nrows()
  let columns = self.effect_modifier_columns(data)
  let order : Array[Int32] = []
  for i = 0; i < n; i = i + 1 {
    order.push(i)
  }
  order.sort_by(fn(a, b) { compare_effect_modifier_rows(columns, a, b) })
  let keys : Array[String] = []
  let groups : Array[Array[Int32]] = []
  let mut i = 0
  while i < order.length() {
    let row = order[i]
    let group : Array[Int32] = []
    let mut j = i
    while j < order.length() && same_effect_modifier_row(columns, row, order[j]) {
      group.push(order[j])
      j = j + 1
    }
    keys.push(effect_modifier_key(columns, row))
    groups.push(group)
    i = j
  }
  (keys, groups)
}

///|
/// The value of the effect modifier of every row, one column per effect
/// modifier.
///
/// A continuous effect modifier is discretised into quantile groups, the way
/// `pandas.qcut` does it, and a discrete effect modifier keeps its value.
fn CausalEstimator::effect_modifier_columns(
  self : CausalEstimator,
  data : @api.DataFrame,
) -> Array[Array[Double]] {
  let columns : Array[Array[Double]] = []
  for name in self.effect_modifier_names {
    if data.is_discrete(name) {
      columns.push(discrete_level_indices(data.discrete(name)))
    } else {
      columns.push(data.qcut(name, NUM_QUANTILES_TO_DISCRETIZE_CONT_COLS))
    }
  }
  columns
}

///|
/// The index of the level of every row, in the order the levels appear.
fn discrete_level_indices(values : Array[String]) -> Array[Double] {
  let levels : Array[String] = []
  let index_of : Map[String, Int32] = Map([])
  let column : Array[Double] = []
  for value in values {
    let index = match index_of.get(value) {
      Some(position) => position
      None => {
        let position = levels.length()
        levels.push(value)
        index_of.set(value, position)
        position
      }
    }
    column.push(index.to_double())
  }
  column
}

///|
/// The comparison of two rows, by the value of their effect modifiers.
fn compare_effect_modifier_rows(
  columns : Array[Array[Double]],
  a : Int32,
  b : Int32,
) -> Int32 {
  let mut i = 0
  while i < columns.length() {
    let left = columns[i][a]
    let right = columns[i][b]
    if left < right {
      return -1
    }
    if left > right {
      return 1
    }
    i = i + 1
  }
  0
}

///|
/// Whether two rows have the same value of every effect modifier.
fn same_effect_modifier_row(
  columns : Array[Array[Double]],
  a : Int32,
  b : Int32,
) -> Bool {
  let mut i = 0
  while i < columns.length() {
    if columns[i][a] != columns[i][b] {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// The key of a group: the value of the effect modifiers of the row.
fn effect_modifier_key(columns : Array[Array[Double]], row : Int32) -> String {
  let mut key = ""
  let mut i = 0
  while i < columns.length() {
    if i > 0 {
      key = key + ","
    }
    key = key + columns[i][row].to_int().to_string()
    i = i + 1
  }
  key
}
