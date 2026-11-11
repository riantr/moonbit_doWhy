/// The distance matching estimator of the upstream.
///
/// The upstream matches every unit of the treated arm with the units of the
/// control arm whose common causes are the closest ones, and it reports the
/// difference of the outcomes of the matched units.
///
/// The estimator does not fit a model: it only checks the treatment and the
/// common causes and encodes the common causes, exactly like the upstream.

///|
/// The distance metric of the distance matching estimator.
///
/// The upstream hands the name of the metric to the `NearestNeighbors` of
/// scikit-learn, which uses the Minkowski metric with an exponent of two by
/// default. The port supports the Minkowski family, which is the family the
/// upstream uses with its default settings.
pub enum DistanceMetric {
  /// The Minkowski metric with the exponent `p`.
  Minkowski(Double)
  /// The Euclidean distance, the Minkowski metric with the exponent two.
  Euclidean
  /// The Manhattan distance, the Minkowski metric with the exponent one.
  Manhattan
  /// The Chebyshev distance, the Minkowski metric with the exponent infinity.
  Chebyshev
}

///|
/// The Minkowski metric with the given exponent.
pub fn DistanceMetric::minkowski(exponent : Double) -> DistanceMetric {
  Minkowski(exponent)
}

///|
/// The Euclidean distance.
pub fn DistanceMetric::euclidean() -> DistanceMetric {
  Euclidean
}

///|
/// The Manhattan distance.
pub fn DistanceMetric::manhattan() -> DistanceMetric {
  Manhattan
}

///|
/// The Chebyshev distance.
pub fn DistanceMetric::chebyshev() -> DistanceMetric {
  Chebyshev
}

///|
/// The sum of the powers of the differences of the covariates of two rows.
///
/// The number is the distance raised to the exponent of the Minkowski metric.
/// It is the number the search of the upstream compares, and the root of it is
/// a monotone function, so the two order the candidates the same way.
fn powered_distance(
  covariates : @utils.Matrix,
  i : Int32,
  j : Int32,
  columns : Int32,
  exponent : Double,
) -> Double {
  let mut total = 0.0
  for c = 0; c < columns; c = c + 1 {
    let difference = (covariates.get(i, c) - covariates.get(j, c)).abs()
    if exponent == 1.0 {
      total = total + difference
    } else if exponent == 2.0 {
      total = total + difference * difference
    } else {
      total = total + @math.pow(difference, exponent)
    }
  }
  total
}

///|
/// The distance between the covariates of two rows.
///
/// The distance is the Minkowski distance of the upstream, which is the
/// Euclidean distance for its default exponent of two.
fn reduced_distance(
  covariates : @utils.Matrix,
  i : Int32,
  j : Int32,
  metric : DistanceMetric,
) -> Double {
  let columns = covariates.ncols()
  match metric {
    Chebyshev => {
      let mut largest = 0.0
      for c = 0; c < columns; c = c + 1 {
        let difference = (covariates.get(i, c) - covariates.get(j, c)).abs()
        if difference > largest {
          largest = difference
        }
      }
      largest
    }
    Minkowski(p) => powered_distance(covariates, i, j, columns, p)
    Euclidean => powered_distance(covariates, i, j, columns, 2.0)
    Manhattan => powered_distance(covariates, i, j, columns, 1.0)
  }
}

///|
/// The rows of the candidates that are the closest ones to the given row.
///
/// The candidates are scanned in the order of the rows and the closest ones
/// are kept in the order of their distance. Two candidates at the same
/// distance are ordered by the rows: the search of the upstream is a ball tree
/// of scikit-learn and it breaks such a tie by the order of the traversal of
/// the tree, which the port does not reproduce.
fn nearest_rows(
  covariates : @utils.Matrix,
  query : Int32,
  candidates : Array[Int32],
  num_matches : Int32,
  metric : DistanceMetric,
) -> Array[Int32] {
  if num_matches > candidates.length() {
    abort(
      "Expected n_neighbors <= n_samples_fit, but n_neighbors = " +
      num_matches.to_string() +
      ", n_samples_fit = " +
      candidates.length().to_string(),
    )
  }
  let distances : Array[Double] = []
  let rows : Array[Int32] = []
  for row in candidates {
    let distance = reduced_distance(covariates, query, row, metric)
    if rows.length() < num_matches {
      insert_match(distances, rows, distance, row)
    } else if distance < distances[num_matches - 1] {
      let last = num_matches - 1
      distances[last] = distance
      rows[last] = row
      bubble_match(distances, rows)
    }
  }
  rows
}

///|
/// Insert a candidate into the list of the closest ones.
///
/// The list is ordered by the distance and by the rows. The candidates arrive
/// in the order of the rows, so a candidate at the same distance as one of the
/// list goes after it.
fn insert_match(
  distances : Array[Double],
  rows : Array[Int32],
  distance : Double,
  row : Int32,
) -> Unit {
  distances.push(distance)
  rows.push(row)
  bubble_match(distances, rows)
}

///|
/// Move the last match to its place in the list of the closest ones.
///
/// The list is ordered by the distance and by the rows, and the last match is
/// the only one that is out of place, so it moves to the left until it is
/// after the matches that are at the same distance.
fn bubble_match(distances : Array[Double], rows : Array[Int32]) -> Unit {
  let mut index = distances.length() - 1
  while index > 0 && distances[index] < distances[index - 1] {
    let distance = distances[index]
    distances[index] = distances[index - 1]
    distances[index - 1] = distance
    let row = rows[index]
    rows[index] = rows[index - 1]
    rows[index - 1] = row
    index = index - 1
  }
}

///|
/// The covariates of the common causes of the data.
///
/// The common causes are encoded with the encoder of the estimator, which was
/// fitted when the estimator was fitted, so that the encoding of a column does
/// not depend on the order the rows arrive in.
///
/// The upstream caches the encoded common causes when the estimator is fitted
/// and pairs them with the outcomes of the data of the estimate, so an estimate
/// on other data pairs the covariates of the fitted data with the outcomes of
/// the other data. The port encodes the data of the estimate instead, so that
/// the covariates and the outcomes belong to the same rows.
fn CausalEstimator::covariates_of(
  self : CausalEstimator,
  data : @api.DataFrame,
) -> @utils.Matrix {
  let encoded = self.encoders.encode(
    data.select(self.adjustment_names),
    "observed_common_causes",
  )
  let columns : Array[Array[Double]] = []
  for name in encoded.numeric_column_names() {
    columns.push(encoded.numeric(name))
  }
  @utils.Matrix::from_columns(columns)
}

///|
/// The message of the error the upstream raises when the distance matching
/// estimator does not fit the data.
///
/// The upstream raises an exception when the treatment is not binary and when
/// the estimand has no common cause. MoonBit cannot catch the abort of a
/// function, so the port reports the two cases with this function, which
/// returns `None` when the estimator fits the data.
pub fn CausalEstimator::distance_matching_error(
  self : CausalEstimator,
  data : @api.DataFrame,
) -> String? {
  let adjustment = self.target_estimand.get_adjustment_set(
    self.target_estimand.identifier_method(),
  )
  if adjustment.length() == 0 {
    return Some(
      "No common causes/confounders present. Distance matching methods are not applicable",
    )
  }
  let treatment = self.target_estimand.treatment()
  if treatment.length() == 0 {
    return None
  }
  let name = treatment[0]
  if data.is_discrete(name) {
    return Some(
      "Distance Matching method is applicable only for binary treatments.",
    )
  }
  for value in data.numeric(name) {
    if value != 0.0 && value != 1.0 {
      return Some(
        "Distance Matching method is applicable only for binary treatments.",
      )
    }
  }
  None
}

///|
/// Fit the distance matching estimator.
///
/// The estimator does not fit a model: it checks the treatment and the common
/// causes and encodes the common causes, exactly like the upstream.
fn CausalEstimator::fit_distance_matching(
  self : CausalEstimator,
  data : @api.DataFrame,
) -> Unit {
  match self.distance_matching_error(data) {
    Some(message) => abort(message)
    None => ()
  }
  // The encoder of the common causes is fitted here, so that the encoding of
  // the data does not depend on the order the rows arrive in.
  let _ = self.covariates_of(data)
}

///|
/// The rows of the treated arm and the rows of the control arm.
///
/// The upstream splits the data on the value one and the value zero of the
/// treatment, so a row whose treatment holds another value belongs to neither
/// arm.
fn CausalEstimator::arms_of(
  self : CausalEstimator,
  data : @api.DataFrame,
) -> (Array[Int32], Array[Int32]) {
  let treatment = data.numeric(self.treatment_name)
  let treated : Array[Int32] = []
  let control : Array[Int32] = []
  for i = 0; i < treatment.length(); i = i + 1 {
    if treatment[i] == 1.0 {
      treated.push(i)
    } else if treatment[i] == 0.0 {
      control.push(i)
    }
  }
  (treated, control)
}

///|
/// The average treatment effect on the treated.
///
/// Every treated unit is matched with the control units whose common causes
/// are the closest ones, and the effect of the unit is its outcome minus the
/// mean of the outcomes of its matches.
fn CausalEstimator::effect_on_the_treated(
  self : CausalEstimator,
  covariates : @utils.Matrix,
  treated : Array[Int32],
  control : Array[Int32],
  outcome : Array[Double],
) -> Double {
  let mut total = 0.0
  for row in treated {
    let matched = nearest_rows(
      covariates,
      row,
      control,
      self.num_matches_per_unit,
      self.distance_metric,
    )
    let mut mean = 0.0
    for match_row in matched {
      mean = mean + outcome[match_row]
    }
    mean = mean / matched.length().to_double()
    total = total + outcome[row] - mean
  }
  total / treated.length().to_double()
}

///|
/// The average treatment effect on the control.
///
/// Every control unit is matched with the treated units whose common causes
/// are the closest ones, and the effect of the unit is the mean of the
/// outcomes of its matches minus its own outcome.
fn CausalEstimator::effect_on_the_control(
  self : CausalEstimator,
  covariates : @utils.Matrix,
  control : Array[Int32],
  treated : Array[Int32],
  outcome : Array[Double],
) -> Double {
  let mut total = 0.0
  for row in control {
    let matched = nearest_rows(
      covariates,
      row,
      treated,
      self.num_matches_per_unit,
      self.distance_metric,
    )
    let mut mean = 0.0
    for match_row in matched {
      mean = mean + outcome[match_row]
    }
    mean = mean / matched.length().to_double()
    total = total + mean - outcome[row]
  }
  total / control.length().to_double()
}

///|
/// The effect of the distance matching estimator.
///
/// The average treatment effect on the treated and the average treatment
/// effect on the control are the two effects the upstream computes, and the
/// average treatment effect is the average of the two, weighted by the number
/// of the units of the two arms.
fn CausalEstimator::estimate_distance_matching(
  self : CausalEstimator,
  data : @api.DataFrame,
  target_units : String,
) -> @model.CausalEstimate {
  let fit_treated = target_units == "att" || target_units == "ate"
  let fit_control = target_units == "atc" || target_units == "ate"
  if !fit_treated && !fit_control {
    abort("Target units string value not supported")
  }
  let outcome = data.numeric(self.outcome_name)
  let (treated, control) = self.arms_of(data)
  if treated.length() == 0 || control.length() == 0 {
    abort(
      "The distance matching estimator needs both treated and control units",
    )
  }
  let covariates = self.covariates_of(data)
  let mut treated_effect = 0.0
  if fit_treated {
    treated_effect = self.effect_on_the_treated(
      covariates, treated, control, outcome,
    )
  }
  let mut control_effect = 0.0
  if fit_control {
    control_effect = self.effect_on_the_control(
      covariates, control, treated, outcome,
    )
  }
  let value = match target_units {
    "att" => treated_effect
    "atc" => control_effect
    "ate" =>
      (
        treated_effect * treated.length().to_double() +
        control_effect * control.length().to_double()
      ) /
      (treated.length() + control.length()).to_double()
    _ => abort("Target units string value not supported")
  }
  @model.CausalEstimate::new(
    value,
    self.treatment_name,
    self.outcome_name,
    self.target_estimand.identifier_method(),
    self.control_value,
    self.treatment_value,
  )
}
