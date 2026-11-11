/// The distribution of a confounder before and after the weights.
///
/// This is the port of
/// `dowhy.interpreters.confounder_distribution_interpreter.ConfounderDistributionInterpreter`.
/// The upstream draws two bar charts of the counts of the categories of a
/// confounder, one before and one after the weights of the inverse propensity
/// score weighting, and the port returns the numbers of the two charts.

///|
/// The distribution of a confounder.
///
/// The counts are the numbers of the rows of the two arms, and the weighted
/// counts are the sums of the weights of the two arms.
///
/// The column of the categories holds the numbers of a numeric column of the
/// data and the texts of a discrete one, the way the upstream keeps the values
/// of the column it groups the rows with.
pub fn confounder_distribution_interpretation(
  estimate : @model.CausalEstimate,
  data : @api.DataFrame,
  var_name : String,
) -> @api.DataFrame {
  let treatment = data.numeric(estimate.treatment_name())
  let propensities = estimate.propensity_scores()
  let groups = category_groups(data, var_name)
  let untreated : Array[Double] = []
  let treated : Array[Double] = []
  let untreated_weight : Array[Double] = []
  let treated_weight : Array[Double] = []
  for group in groups {
    let mut untreated_count = 0.0
    let mut treated_count = 0.0
    let mut untreated_sum = 0.0
    let mut treated_sum = 0.0
    for row in group {
      let weight = weight_of(treatment[row], propensities[row])
      if treatment[row] == 1.0 {
        treated_count = treated_count + 1.0
        treated_sum = treated_sum + weight
      } else if treatment[row] == 0.0 {
        untreated_count = untreated_count + 1.0
        untreated_sum = untreated_sum + weight
      }
    }
    untreated.push(untreated_count)
    treated.push(treated_count)
    untreated_weight.push(untreated_sum)
    treated_weight.push(treated_sum)
  }
  let columns : Map[String, @api.Column] = Map([
    ("category", category_column(data, var_name)),
    ("untreated", @api.Column::numeric(untreated)),
    ("treated", @api.Column::numeric(treated)),
    ("untreated_weight", @api.Column::numeric(untreated_weight)),
    ("treated_weight", @api.Column::numeric(treated_weight)),
  ])
  @api.DataFrame::new(
    ["category", "untreated", "treated", "untreated_weight", "treated_weight"],
    columns,
  )
}

///|
/// The weight of a row of the inverse propensity score weighting.
///
/// The weight is the inverse of the propensity score of the arm the unit
/// received, the way the upstream computes it.
fn weight_of(treatment : Double, propensity : Double) -> Double {
  if treatment == 1.0 {
    1.0 / propensity
  } else if treatment == 0.0 {
    1.0 / (1.0 - propensity)
  } else {
    0.0
  }
}

///|
/// The rows of every category of the column, in the order the upstream groups
/// them.
///
/// The upstream groups the rows with the `groupby` of pandas, which sorts the
/// values of the column. The values of a discrete column are sorted as the
/// texts they are, and the values of a numeric column are sorted as the
/// numbers they are.
fn category_groups(
  data : @api.DataFrame,
  var_name : String,
) -> Array[Array[Int32]] {
  let groups : Array[Array[Int32]] = []
  if data.is_discrete(var_name) {
    let values = data.discrete(var_name)
    let categories : Array[String] = []
    for value in values {
      if !categories.contains(value) {
        categories.push(value)
      }
    }
    categories.sort_by(fn(a, b) { a.lexical_compare(b) })
    for category in categories {
      let rows : Array[Int32] = []
      for i = 0; i < values.length(); i = i + 1 {
        if values[i] == category {
          rows.push(i)
        }
      }
      groups.push(rows)
    }
    return groups
  }
  let values = data.numeric(var_name)
  let numbers : Array[Double] = []
  for value in values {
    if !numbers.contains(value) {
      numbers.push(value)
    }
  }
  numbers.sort_by(fn(a, b) { @utils.compare_double(a, b) })
  for number in numbers {
    let rows : Array[Int32] = []
    for i = 0; i < values.length(); i = i + 1 {
      if values[i] == number {
        rows.push(i)
      }
    }
    groups.push(rows)
  }
  groups
}

///|
/// The column of the categories of the distribution.
///
/// The column holds the numbers of a numeric column of the data and the texts
/// of a discrete one.
fn category_column(data : @api.DataFrame, var_name : String) -> @api.Column {
  if data.is_discrete(var_name) {
    let values = data.discrete(var_name)
    let categories : Array[String] = []
    for value in values {
      if !categories.contains(value) {
        categories.push(value)
      }
    }
    categories.sort_by(fn(a, b) { a.lexical_compare(b) })
    return @api.Column::discrete(categories)
  }
  let values = data.numeric(var_name)
  let numbers : Array[Double] = []
  for value in values {
    if !numbers.contains(value) {
      numbers.push(value)
    }
  }
  numbers.sort_by(fn(a, b) { @utils.compare_double(a, b) })
  @api.Column::numeric(numbers)
}
