///|
/// The unit change layer of the `gcm` package.
///
/// This is the port of `dowhy.gcm.unit_change`. The layer attributes the
/// change of the output of a deterministic mechanism, between a background and a
/// foreground situation, to the inputs that changed and to the mechanism itself.
///
/// The method is described in the research paper *Explaining the root causes of
/// unit-level changes* of Kailash Budhathoki, George Michailidis and Dominik
/// Janzing.

///|
/// The contribution of the mechanism to the change of the output.
///
/// The upstream names the column of the mechanism `f`.
const UNIT_CHANGE_MECHANISM_COLUMN : String = "f"

///|
/// The contributions of the inputs and of the mechanism to the change of the
/// output of a linear mechanism.
///
/// This is the port of `dowhy.gcm.unit_change.unit_change_linear`. The
/// contribution of an input is the half of the sum of the coefficients of the
/// two mechanisms times the change of the input, and the contribution of the
/// mechanism is the half of the difference of the coefficients times the sum of
/// the inputs.
///
/// The upstream ignores the intercept of the mechanisms, because the linear
/// model of the upstream is fitted without one in the fixtures of the layer.
/// The port fits its linear model with an intercept, so the difference of the
/// intercepts belongs to the contribution of the mechanism; without it the
/// contributions would not add up to the change of the output.
pub fn unit_change_linear(
  background_mechanism : PredictionModel,
  background_data : @api.DataFrame,
  foreground_mechanism : PredictionModel,
  foreground_data : @api.DataFrame,
  input_column_names : Array[String],
) -> @api.DataFrame {
  check_input_columns(background_data, foreground_data, input_column_names)
  check_fitted(background_mechanism)
  check_fitted(foreground_mechanism)
  check_coefficients(background_mechanism)
  check_coefficients(foreground_mechanism)
  let background_coefficients = background_mechanism.coefficients()
  let foreground_coefficients = foreground_mechanism.coefficients()
  let background_inputs = inputs_of(background_data, input_column_names)
  let foreground_inputs = inputs_of(foreground_data, input_column_names)
  let num_rows = background_data.nrows()
  let num_inputs = input_column_names.length()

  let contributions : Map[String, Array[Double]] = Map([])
  for j in 0..<num_inputs {
    let values : Array[Double] = []
    for k in 0..<num_rows {
      let total = background_coefficients[j] + foreground_coefficients[j]
      let difference = foreground_inputs[j][k] - background_inputs[j][k]
      values.push(0.5 * total * difference)
    }
    contributions.set(input_column_names[j], values)
  }

  let mechanism : Array[Double] = []
  for k in 0..<num_rows {
    let mut total = foreground_mechanism.intercept() -
      background_mechanism.intercept()
    for j in 0..<num_inputs {
      let difference = foreground_coefficients[j] - background_coefficients[j]
      total = total +
        0.5 * difference * (foreground_inputs[j][k] + background_inputs[j][k])
    }
    mechanism.push(total)
  }

  frame_of(contributions, mechanism, input_column_names)
}

///|
/// The contributions of the inputs to the change of the output of a linear
/// mechanism, without the mechanism as a player.
///
/// This is the port of
/// `dowhy.gcm.unit_change.unit_change_linear_input_only`. The contribution of
/// an input is the coefficient of the mechanism times the change of the input.
pub fn unit_change_linear_input_only(
  mechanism : PredictionModel,
  background_data : @api.DataFrame,
  foreground_data : @api.DataFrame,
  input_column_names : Array[String],
) -> @api.DataFrame {
  check_input_columns(background_data, foreground_data, input_column_names)
  check_fitted(mechanism)
  check_coefficients(mechanism)
  let coefficients = mechanism.coefficients()
  let background_inputs = inputs_of(background_data, input_column_names)
  let foreground_inputs = inputs_of(foreground_data, input_column_names)
  let num_rows = background_data.nrows()
  let num_inputs = input_column_names.length()

  let contributions : Map[String, Array[Double]] = Map([])
  for j in 0..<num_inputs {
    let values : Array[Double] = []
    for k in 0..<num_rows {
      let difference = foreground_inputs[j][k] - background_inputs[j][k]
      values.push(coefficients[j] * difference)
    }
    contributions.set(input_column_names[j], values)
  }
  frame_of(contributions, [], input_column_names)
}

///|
/// The contributions of the inputs and of the mechanism to the change of the
/// output of a non-linear mechanism.
///
/// This is the port of `dowhy.gcm.unit_change.unit_change_nonlinear`. The
/// contribution of a player is the Shapley value of the set function of the
/// output, where the inputs that are in the subset are taken from the
/// foreground and the mechanism that is in the subset is the foreground
/// mechanism.
///
/// The upstream computes the Shapley values of every row at once, with a set
/// function that returns an array; the Shapley estimator of the port takes one
/// set function at a time, so the port computes the values of every row on its
/// own. The exact estimator of the port evaluates the same subsets of the
/// players as the upstream, so the contributions are the same numbers.
pub fn unit_change_nonlinear(
  background_mechanism : PredictionModel,
  background_data : @api.DataFrame,
  foreground_mechanism : PredictionModel,
  foreground_data : @api.DataFrame,
  input_column_names : Array[String],
  shapley_config : ShapleyConfig,
) -> @api.DataFrame {
  check_input_columns(background_data, foreground_data, input_column_names)
  let background_inputs = inputs_of(background_data, input_column_names)
  let foreground_inputs = inputs_of(foreground_data, input_column_names)
  let num_rows = background_data.nrows()
  let num_inputs = input_column_names.length()

  let contributions : Map[String, Array[Double]] = Map([])
  for j in 0..<num_inputs {
    contributions.set(input_column_names[j], [])
  }
  let mechanism : Array[Double] = []

  for k in 0..<num_rows {
    let values = unit_change_row(
      background_mechanism, foreground_mechanism, background_inputs, foreground_inputs,
      k, shapley_config,
    )
    for j in 0..<num_inputs {
      contributions.get(input_column_names[j]).unwrap().push(values[j])
    }
    mechanism.push(values[num_inputs])
  }
  frame_of(contributions, mechanism, input_column_names)
}

///|
/// The contributions of the inputs to the change of the output of a non-linear
/// mechanism, without the mechanism as a player.
///
/// This is the port of
/// `dowhy.gcm.unit_change.unit_change_nonlinear_input_only`. The inputs that
/// are in the subset are taken from the foreground and the ones that are not in
/// it are taken from the background.
pub fn unit_change_nonlinear_input_only(
  mechanism : PredictionModel,
  background_data : @api.DataFrame,
  foreground_data : @api.DataFrame,
  input_column_names : Array[String],
  shapley_config : ShapleyConfig,
) -> @api.DataFrame {
  check_input_columns(background_data, foreground_data, input_column_names)
  let background_inputs = inputs_of(background_data, input_column_names)
  let foreground_inputs = inputs_of(foreground_data, input_column_names)
  let num_rows = background_data.nrows()
  let num_inputs = input_column_names.length()

  let contributions : Map[String, Array[Double]] = Map([])
  for j in 0..<num_inputs {
    contributions.set(input_column_names[j], [])
  }

  for k in 0..<num_rows {
    let values = unit_change_row(
      mechanism, mechanism, background_inputs, foreground_inputs, k, shapley_config,
    )
    for j in 0..<num_inputs {
      contributions.get(input_column_names[j]).unwrap().push(values[j])
    }
  }
  frame_of(contributions, [], input_column_names)
}

///|
/// The contributions of the inputs and of the mechanism to the change of the
/// output of a mechanism.
///
/// This is the port of `dowhy.gcm.unit_change.unit_change`. The upstream chooses
/// between the linear and the non-linear attribution with the kind of the
/// mechanism, and it attributes the change to the mechanism only when a
/// foreground mechanism is given.
///
/// The upstream fits the linear model of the mechanism without an intercept in
/// the fixtures of the layer; the port fits its model with an intercept, like
/// the fit of the `gcm` package does everywhere else. The intercept of the
/// fixtures of the layer is zero up to the rounding of the fit, so the
/// contributions of the port and of the upstream agree to the tolerance of the
/// tests.
pub fn unit_change(
  background_mechanism : PredictionModel,
  background_data : @api.DataFrame,
  foreground_data : @api.DataFrame,
  input_column_names : Array[String],
  foreground_mechanism : PredictionModel?,
  shapley_config : ShapleyConfig?,
) -> @api.DataFrame {
  match foreground_mechanism {
    Some(foreground) =>
      if can_evaluate_unit_change_linear(background_mechanism) {
        unit_change_linear(
          background_mechanism, background_data, foreground, foreground_data, input_column_names,
        )
      } else {
        unit_change_nonlinear(
          background_mechanism,
          background_data,
          foreground,
          foreground_data,
          input_column_names,
          unit_change_shapley_config_of(shapley_config),
        )
      }
    None =>
      if can_evaluate_unit_change_linear(background_mechanism) {
        unit_change_linear_input_only(
          background_mechanism, background_data, foreground_data, input_column_names,
        )
      } else {
        unit_change_nonlinear_input_only(
          background_mechanism,
          background_data,
          foreground_data,
          input_column_names,
          unit_change_shapley_config_of(shapley_config),
        )
      }
  }
}

///|
/// The given configuration, or the default configuration of the layer.
///
/// The default configuration is the one of the upstream, which is the automatic
/// method of the Shapley estimator.
fn unit_change_shapley_config_of(
  shapley_config : ShapleyConfig?,
) -> ShapleyConfig {
  match shapley_config {
    Some(config) => config
    None => ShapleyConfig::new(ShapleyApproximationMethod::auto())
  }
}

///|
/// The contributions of the players to the change of the output of the given
/// row.
///
/// The players are the inputs and the mechanism, so the set function has one
/// more player than the number of the inputs.
fn unit_change_row(
  background_mechanism : PredictionModel,
  foreground_mechanism : PredictionModel,
  background_inputs : Array[Array[Double]],
  foreground_inputs : Array[Array[Double]],
  row : Int32,
  shapley_config : ShapleyConfig,
) -> Array[Double] {
  let num_inputs = background_inputs.length()
  let set_function = fn(subset : Array[Bool]) -> Double {
    let columns : Array[Array[Double]] = []
    for j in 0..<num_inputs {
      let source = if subset[j] {
        foreground_inputs[j]
      } else {
        background_inputs[j]
      }
      columns.push([source[row]])
    }
    let mechanism = if subset[num_inputs] {
      foreground_mechanism
    } else {
      background_mechanism
    }
    mechanism.predict(@utils.Matrix::from_columns(columns))[0]
  }
  estimate_shapley_values(set_function, num_inputs + 1, shapley_config)
}

///|
/// The columns of the given inputs of the given data.
fn inputs_of(
  data : @api.DataFrame,
  input_column_names : Array[String],
) -> Array[Array[Double]] {
  let columns : Array[Array[Double]] = []
  for name in input_column_names {
    columns.push(data.numeric(name))
  }
  columns
}

///|
/// The frame of the given contributions, with the column of the mechanism when
/// there is one.
fn frame_of(
  contributions : Map[String, Array[Double]],
  mechanism : Array[Double],
  input_column_names : Array[String],
) -> @api.DataFrame {
  let order : Array[String] = []
  let payload : Map[String, Array[Double]] = Map([])
  for name in input_column_names {
    order.push(name)
    payload.set(name, contributions.get(name).unwrap().copy())
  }
  if mechanism.length() > 0 {
    order.push(UNIT_CHANGE_MECHANISM_COLUMN)
    payload.set(UNIT_CHANGE_MECHANISM_COLUMN, mechanism.copy())
  }
  @api.DataFrame::from_numeric(order, payload)
}

///|
/// Whether the given mechanism can be used by the linear attribution.
///
/// The upstream raises a `NotFittedError` when the mechanism has not been
/// fitted and an `AttributeError` when it is not a linear model, because it
/// reads the coefficients of the model of scikit-learn. MoonBit cannot catch
/// either of them, so the check is available on its own.
pub fn can_evaluate_unit_change_linear(mechanism : PredictionModel) -> Bool {
  mechanism.is_fitted() && !mechanism.is_nearest_neighbour()
}

///|
/// Whether the given mechanism can be used by the non-linear attribution.
///
/// The upstream raises a `NotFittedError` when the mechanism has not been
/// fitted, because the set function of the attribution evaluates the model.
/// MoonBit cannot catch it, so the check is available on its own.
pub fn can_evaluate_unit_change_nonlinear(mechanism : PredictionModel) -> Bool {
  mechanism.is_fitted()
}

///|
/// Check that the given mechanism has been fitted.
///
/// The upstream raises `NotFittedError` when the mechanism of a linear
/// attribution has not been fitted, because it reads the coefficients of the
/// model of scikit-learn; the port raises here for the same reason.
fn check_fitted(mechanism : PredictionModel) -> Unit {
  if !mechanism.is_fitted() {
    abort("the prediction model has not been fitted")
  }
}

///|
/// Check that the given mechanism has the coefficients the linear attribution
/// needs.
///
/// The upstream raises an `AttributeError` when the mechanism of a linear
/// attribution is not a linear model, because it reads the coefficients of the
/// model of scikit-learn; the port raises here for the same reason.
fn check_coefficients(mechanism : PredictionModel) -> Unit {
  if mechanism.is_nearest_neighbour() {
    abort(
      "the linear attribution needs the coefficients of the mechanism, and the nearest neighbour model has none",
    )
  }
}

///|
/// Check that the given inputs are columns of both of the given data.
fn check_input_columns(
  background_data : @api.DataFrame,
  foreground_data : @api.DataFrame,
  input_column_names : Array[String],
) -> Unit {
  for name in input_column_names {
    if !background_data.has_column(name) || !foreground_data.has_column(name) {
      abort(
        "the input column " +
        name +
        " is not in the background or in the foreground data",
      )
    }
  }
}
