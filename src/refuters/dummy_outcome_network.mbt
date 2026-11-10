///|
/// The neural network of the dummy outcome refuter.
///
/// This is the port of the `MLPRegressor` of scikit-learn, which the upstream
/// builds when the transformation list of the refuter names the
/// `neural_network` estimator. The network has the hidden layers of the caller,
/// the ReLU activation on them, the identity activation on its output, and it
/// is fitted on the sum of the squared errors of the rows with the penalty of
/// `alpha` on the weights, the way scikit-learn fits it.
///
/// The loss of the port is the one of scikit-learn, down to its factor of one
/// half and to the divisor of the number of the rows:
///
/// `0.5 * mean((y - f)^2) + 0.5 * alpha * ||W||^2 / n`
///
/// and so is its gradient, which the test of the package checks against the
/// gradient of scikit-learn at the same parameters, the numbers of which the
/// reference script of the package prints.
///
/// The optimiser of the port is a limited memory BFGS with the two loop
/// recursion and a backtracking line search of the Armijo condition, which is
/// the family of the L-BFGS-B of scipy that scikit-learn uses. The objective is
/// not convex - the ReLU activation is not convex - so the two reach a nearby
/// but not identical point of it, the way two optimisers of a non convex
/// problem do. The port draws the initialisation of its network with its own
/// generator, whose seed is the argument of the function, while scikit-learn
/// draws it with the global generator of numpy, which it does not seed, so the
/// two networks start from a different point as well.

///|
/// The number of the corrections the limited memory BFGS of the port keeps.
///
/// This is the default of scipy, whose L-BFGS-B the solver of scikit-learn is.
const NETWORK_HISTORY : Int32 = 10

///|
/// The number of the iterations of the limited memory BFGS of the port.
///
/// This is the default of the `max_iter` of scikit-learn, which its L-BFGS-B
/// solver uses as its budget of the iterations.
const NETWORK_MAX_ITER : Int32 = 200

///|
/// The tolerance of the gradient of the limited memory BFGS of the port.
///
/// This is the default of the `tol` of scikit-learn, which its L-BFGS-B solver
/// uses as its tolerance of the gradient.
const NETWORK_TOL : Double = 0.0001

///|
/// The number of the steps the backtracking line search of the port takes.
const NETWORK_LINE_SEARCH_STEPS : Int32 = 40

///|
/// The constant of the Armijo condition of the line search of the port.
const NETWORK_ARMIJO : Double = 0.0001

///|
/// A fitted network.
priv struct NeuralNetwork {
  /// The number of the units of every layer, the input and the output included.
  sizes : Array[Int32]
  /// The parameters of the network, the weights of every layer first and the
  /// bias of every layer after them, the way scikit-learn packs them.
  parameters : Array[Double]
}

///|
/// The sizes of the layers of the network.
///
/// The input comes first and the output, which holds one unit, comes last.
fn network_sizes(features : Int32, hidden : Array[Int32]) -> Array[Int32] {
  let sizes : Array[Int32] = [features]
  for size in hidden {
    sizes.push(size)
  }
  sizes.push(1)
  sizes
}

///|
/// The number of the layers of the network, the ones that hold weights.
fn network_layer_count(sizes : Array[Int32]) -> Int32 {
  sizes.length() - 1
}

///|
/// The number of the weights of the network.
fn network_weight_count(sizes : Array[Int32]) -> Int32 {
  let mut count = 0
  for layer = 0; layer < network_layer_count(sizes); layer = layer + 1 {
    count = count + sizes[layer] * sizes[layer + 1]
  }
  count
}

///|
/// The offset of the weights of the layer in the parameter vector.
fn network_weight_offset(sizes : Array[Int32], layer : Int32) -> Int32 {
  let mut offset = 0
  for index = 0; index < layer; index = index + 1 {
    offset = offset + sizes[index] * sizes[index + 1]
  }
  offset
}

///|
/// The offset of the bias of the layer in the parameter vector.
///
/// The bias of every layer comes after the weights of every layer, the way
/// scikit-learn packs them.
fn network_bias_offset(sizes : Array[Int32], layer : Int32) -> Int32 {
  let mut offset = network_weight_count(sizes)
  for index = 0; index < layer; index = index + 1 {
    offset = offset + sizes[index + 1]
  }
  offset
}

///|
/// The number of the parameters of the network.
fn network_parameter_count(sizes : Array[Int32]) -> Int32 {
  let mut count = network_weight_count(sizes)
  for layer = 0; layer < network_layer_count(sizes); layer = layer + 1 {
    count = count + sizes[layer + 1]
  }
  count
}

///|
/// A number of the interval `[-bound, bound)`.
fn network_uniform(rng : @utils.Random, bound : Double) -> Double {
  -bound + 2.0 * bound * rng.next_double()
}

///|
/// The initialisation of the network.
///
/// This is the initialisation of Glorot of scikit-learn: the weights of a layer
/// and its bias are drawn from the interval `[-bound, bound]`, where the bound
/// is the square root of six over the sum of the numbers of the units of the
/// layer and of the layer before it.
fn network_initial(sizes : Array[Int32], rng : @utils.Random) -> Array[Double] {
  let parameters : Array[Double] = []
  for _ in 0..<network_parameter_count(sizes) {
    parameters.push(0.0)
  }
  for layer = 0; layer < network_layer_count(sizes); layer = layer + 1 {
    let fan_in = sizes[layer]
    let fan_out = sizes[layer + 1]
    let bound = (6.0 / (fan_in.to_double() + fan_out.to_double())).sqrt()
    let weights = network_weight_offset(sizes, layer)
    for k = 0; k < fan_in; k = k + 1 {
      for j = 0; j < fan_out; j = j + 1 {
        parameters[weights + k * fan_out + j] = network_uniform(rng, bound)
      }
    }
    let bias = network_bias_offset(sizes, layer)
    for j = 0; j < fan_out; j = j + 1 {
      parameters[bias + j] = network_uniform(rng, bound)
    }
  }
  parameters
}

///|
/// The covariates of the frame as the rows of a flat array, the number of the
/// rows and the number of the columns.
fn network_matrix(x : @api.DataFrame) -> (Array[Double], Int32, Int32) {
  let columns : Array[Array[Double]] = []
  for name in x.numeric_column_names() {
    columns.push(x.numeric(name))
  }
  let features = columns.length()
  let rows = if features == 0 { 0 } else { columns[0].length() }
  let flat : Array[Double] = []
  for i = 0; i < rows; i = i + 1 {
    for j = 0; j < features; j = j + 1 {
      flat.push(columns[j][i])
    }
  }
  (flat, rows, features)
}

///|
/// The activations of the network, one array per layer.
///
/// The first array holds the covariates and the last one the output of the
/// network. The hidden layers hold the ReLU of their pre-activation and the
/// output holds its pre-activation, the activation of the output of
/// scikit-learn being the identity.
fn network_forward(
  x : Array[Double],
  rows : Int32,
  sizes : Array[Int32],
  parameters : Array[Double],
) -> Array[Array[Double]] {
  let layers = network_layer_count(sizes)
  let activations : Array[Array[Double]] = []
  activations.push(x)
  for layer = 0; layer < layers; layer = layer + 1 {
    let fan_in = sizes[layer]
    let fan_out = sizes[layer + 1]
    let weights = network_weight_offset(sizes, layer)
    let bias = network_bias_offset(sizes, layer)
    let previous = activations[layer]
    let current = network_zeros(rows * fan_out)
    // the bias of every unit of the layer
    for i = 0; i < rows; i = i + 1 {
      for j = 0; j < fan_out; j = j + 1 {
        current[i * fan_out + j] = parameters[bias + j]
      }
    }
    // the contribution of every unit of the layer before, which is added in the
    // order of the units, so that the sum is the one of the term after the
    // other
    for i = 0; i < rows; i = i + 1 {
      for k = 0; k < fan_in; k = k + 1 {
        let value = previous[i * fan_in + k]
        for j = 0; j < fan_out; j = j + 1 {
          let index = i * fan_out + j
          current[index] = current[index] +
            value * parameters[weights + k * fan_out + j]
        }
      }
    }
    // the ReLU of the hidden layers
    if layer < layers - 1 {
      for index = 0; index < current.length(); index = index + 1 {
        if current[index] < 0.0 {
          current[index] = 0.0
        }
      }
    }
    activations.push(current)
  }
  activations
}

///|
/// The loss of the network and its gradient.
///
/// The loss is the one of scikit-learn: the half of the mean of the squared
/// errors of the rows plus the half of the penalty of the weights times their
/// squared length over the number of the rows. The gradient is the one of
/// scikit-learn, the delta of the output layer carrying no factor of the
/// number of the rows, which is divided in at the end.
fn network_loss_and_gradient(
  x : Array[Double],
  rows : Int32,
  y : Array[Double],
  sizes : Array[Int32],
  alpha : Double,
  parameters : Array[Double],
) -> (Double, Array[Double]) {
  let layers = network_layer_count(sizes)
  let activations = network_forward(x, rows, sizes, parameters)
  let prediction = activations[layers]
  // the loss
  let mut squared = 0.0
  for i = 0; i < rows; i = i + 1 {
    let difference = y[i] - prediction[i]
    squared = squared + difference * difference
  }
  let mut loss = 0.5 * squared / rows.to_double()
  let mut values = 0.0
  for layer = 0; layer < layers; layer = layer + 1 {
    let offset = network_weight_offset(sizes, layer)
    let count = sizes[layer] * sizes[layer + 1]
    for index = 0; index < count; index = index + 1 {
      let weight = parameters[offset + index]
      values = values + weight * weight
    }
  }
  loss = loss + 0.5 * alpha * values / rows.to_double()
  // the backward pass
  let gradient : Array[Double] = []
  for _ in 0..<network_parameter_count(sizes) {
    gradient.push(0.0)
  }
  let mut delta : Array[Double] = []
  for i = 0; i < rows; i = i + 1 {
    delta.push(prediction[i] - y[i])
  }
  for layer = layers - 1; layer >= 0; layer = layer - 1 {
    let fan_in = sizes[layer]
    let fan_out = sizes[layer + 1]
    let weights = network_weight_offset(sizes, layer)
    let bias = network_bias_offset(sizes, layer)
    let previous = activations[layer]
    // the gradient of the weights of the layer, whose sums run over the rows in
    // the order of the rows
    let totals = network_zeros(fan_in * fan_out)
    for i = 0; i < rows; i = i + 1 {
      for k = 0; k < fan_in; k = k + 1 {
        let value = previous[i * fan_in + k]
        for j = 0; j < fan_out; j = j + 1 {
          let index = k * fan_out + j
          totals[index] = totals[index] + value * delta[i * fan_out + j]
        }
      }
    }
    for k = 0; k < fan_in; k = k + 1 {
      for j = 0; j < fan_out; j = j + 1 {
        let index = weights + k * fan_out + j
        gradient[index] = (totals[k * fan_out + j] + alpha * parameters[index]) /
          rows.to_double()
      }
    }
    // the gradient of the bias of the layer
    for j = 0; j < fan_out; j = j + 1 {
      let mut total = 0.0
      for i = 0; i < rows; i = i + 1 {
        total = total + delta[i * fan_out + j]
      }
      gradient[bias + j] = total / rows.to_double()
    }
    // the delta of the layer before, the ReLU cutting the negative entries
    if layer > 0 {
      let previous_delta = network_zeros(rows * fan_in)
      for i = 0; i < rows; i = i + 1 {
        for j = 0; j < fan_out; j = j + 1 {
          let value = delta[i * fan_out + j]
          for k = 0; k < fan_in; k = k + 1 {
            let index = i * fan_in + k
            previous_delta[index] = previous_delta[index] +
              value * parameters[weights + k * fan_out + j]
          }
        }
      }
      for i = 0; i < rows; i = i + 1 {
        for k = 0; k < fan_in; k = k + 1 {
          if previous[i * fan_in + k] == 0.0 {
            previous_delta[i * fan_in + k] = 0.0
          }
        }
      }
      delta = previous_delta
    }
  }
  (loss, gradient)
}

///|
/// The dot product of two vectors.
fn network_dot(a : Array[Double], b : Array[Double]) -> Double {
  let mut total = 0.0
  for i = 0; i < a.length(); i = i + 1 {
    total = total + a[i] * b[i]
  }
  total
}

///|
/// A vector of the given length.
fn network_zeros(length : Int32) -> Array[Double] {
  let out : Array[Double] = []
  for _ in 0..<length {
    out.push(0.0)
  }
  out
}

///|
/// The vector `base + step * direction`.
fn network_step(
  base : Array[Double],
  direction : Array[Double],
  step : Double,
) -> Array[Double] {
  let out : Array[Double] = []
  for i = 0; i < base.length(); i = i + 1 {
    out.push(base[i] + step * direction[i])
  }
  out
}

///|
/// The direction of the two loop recursion of the limited memory BFGS.
///
/// The recursion builds the product of the inverse of the approximated Hessian
/// with the gradient out of the pairs of the corrections, the oldest one first.
fn network_direction(
  gradient : Array[Double],
  s_history : Array[Array[Double]],
  y_history : Array[Array[Double]],
) -> Array[Double] {
  let count = s_history.length()
  let q = gradient.copy()
  let alphas : Array[Double] = []
  for step = 0; step < count; step = step + 1 {
    let index = count - 1 - step
    let curvature = network_dot(y_history[index], y_history[index])
    let alpha = network_dot(s_history[index], q) / curvature
    alphas.push(alpha)
    for i = 0; i < q.length(); i = i + 1 {
      q[i] = q[i] - alpha * y_history[index][i]
    }
  }
  let r = network_zeros(gradient.length())
  if count == 0 {
    for i = 0; i < r.length(); i = i + 1 {
      r[i] = q[i]
    }
  } else {
    let last = count - 1
    let curvature = network_dot(y_history[last], y_history[last])
    let gamma = network_dot(s_history[last], y_history[last]) / curvature
    for i = 0; i < r.length(); i = i + 1 {
      r[i] = gamma * q[i]
    }
  }
  for index = 0; index < count; index = index + 1 {
    let curvature = network_dot(y_history[index], y_history[index])
    let beta = network_dot(y_history[index], r) / curvature
    let alpha = alphas[count - 1 - index]
    for i = 0; i < r.length(); i = i + 1 {
      r[i] = r[i] + s_history[index][i] * (alpha - beta)
    }
  }
  for i = 0; i < r.length(); i = i + 1 {
    r[i] = -r[i]
  }
  r
}

///|
/// The largest absolute value of a vector.
fn network_max_abs(values : Array[Double]) -> Double {
  let mut largest = 0.0
  for value in values {
    let magnitude = value.abs()
    if magnitude > largest {
      largest = magnitude
    }
  }
  largest
}

///|
/// Fit the network on the covariates and the outcome.
///
/// The optimiser is the limited memory BFGS of the port, the two loop
/// recursion with a backtracking line search of the Armijo condition.
fn network_fit(
  x : @api.DataFrame,
  y : Array[Double],
  hidden : Array[Int32],
  alpha : Double,
  rng : @utils.Random,
) -> NeuralNetwork {
  if x.nrows() != y.length() {
    abort(
      "The outcome has " +
      y.length().to_string() +
      " values for " +
      x.nrows().to_string() +
      " rows",
    )
  }
  let (flat, rows, features) = network_matrix(x)
  let sizes = network_sizes(features, hidden)
  let mut parameters = network_initial(sizes, rng)
  let (initial_value, initial_gradient) = network_loss_and_gradient(
    flat, rows, y, sizes, alpha, parameters,
  )
  let mut value = initial_value
  let mut gradient = initial_gradient
  let s_history : Array[Array[Double]] = []
  let y_history : Array[Array[Double]] = []
  for _ in 0..<NETWORK_MAX_ITER {
    let mut direction = network_direction(gradient, s_history, y_history)
    let mut slope = network_dot(gradient, direction)
    if slope >= 0.0 {
      // the direction is not a descent direction, so the steepest descent is
      // taken and the corrections are dropped
      direction = network_zeros(gradient.length())
      for i = 0; i < direction.length(); i = i + 1 {
        direction[i] = -gradient[i]
      }
      slope = network_dot(gradient, direction)
    }
    // the backtracking line search of the Armijo condition
    let mut step = 1.0
    let mut trial = parameters
    let mut trial_value = value
    let mut trial_gradient = gradient
    let mut accepted = false
    for _ in 0..<NETWORK_LINE_SEARCH_STEPS {
      trial = network_step(parameters, direction, step)
      let (candidate, candidate_gradient) = network_loss_and_gradient(
        flat, rows, y, sizes, alpha, trial,
      )
      if candidate <= value + NETWORK_ARMIJO * step * slope {
        trial_value = candidate
        trial_gradient = candidate_gradient
        accepted = true
        break
      }
      step = step * 0.5
    }
    if !accepted {
      break
    }
    // the corrections of the step, which are kept when they are positive
    let s = network_step(parameters, direction, step)
    let correction = network_zeros(parameters.length())
    for i = 0; i < correction.length(); i = i + 1 {
      correction[i] = trial_gradient[i] - gradient[i]
    }
    parameters = trial
    value = trial_value
    gradient = trial_gradient
    if network_max_abs(gradient) < NETWORK_TOL {
      break
    }
    if s_history.length() >= NETWORK_HISTORY {
      let _ = s_history.remove(0)
      let _ = y_history.remove(0)
    }
    if network_dot(s, correction) > 0.0 {
      s_history.push(s)
      y_history.push(correction)
    }
  }
  { sizes, parameters, }
}

///|
/// The loss and the gradient of the network are the ones of scikit-learn.
///
/// The fixture is the one of `_verify/neural_network_reference.py`, which
/// computes the loss and the gradient of the `MLPRegressor` of scikit-learn at
/// the same parameters with its private `_loss_grad_lbfgs` and prints them next
/// to the ones of the port. The two agree to the last bits of the double, up to
/// the order of the summations: numpy sums with the pairwise summation of its
/// `dot` and the port sums one term after the other.
test "the loss and the gradient of the network are the ones of scikit-learn" {
  let x : Array[Double] = [
    0.3, -1.2, 0.7, 2.1, -0.4, 1.5, 0.9, -0.6, -1.1, 0.2, 1.8, -0.8, 0.4, 1.1,
  ]
  let y : Array[Double] = [1.0, -2.0, 0.5, 3.0, -1.0, 2.0, 0.25]
  let sizes = [2, 3, 2, 1]
  let parameters : Array[Double] = []
  for i = 0; i < 20; i = i + 1 {
    parameters.push((i * 37 % 23 - 11).to_double() * 0.17 + 0.3)
  }
  let (loss, gradient) = network_loss_and_gradient(
    x, 7, y, sizes, 0.0001, parameters,
  )
  // The tolerance is the size of the last bits of a double.
  assert_true((loss - 17.153361774652414).abs() < 0.000000000001)
  let expected : Array[Double] = [
    1.0345624771931432, 0.8929555714285715, 2.8396286523417156, -1.8882831869737138,
    -0.3968621428571429, -6.105626248477717, -1.5315291268914284, 8.060745442285711,
    0.000026142857142857144, 0.48616268571428584, -0.7365525839360002, 16.385012037257145,
    1.209022267663999, 17.668258409080003, -2.500933661485714, 0.49608, 10.034374471897147,
    -0.6454460685714285, 9.576627428571427, 4.788313714285714,
  ]
  assert_eq(gradient.length(), expected.length())
  for i = 0; i < expected.length(); i = i + 1 {
    assert_true((gradient[i] - expected[i]).abs() < 0.000000000001)
  }
}

///|
/// The prediction of the network on the covariates of the frame.
fn network_predict(
  network : NeuralNetwork,
  x : @api.DataFrame,
) -> Array[Double] {
  let (flat, rows, _) = network_matrix(x)
  let activations = network_forward(
    flat,
    rows,
    network.sizes,
    network.parameters,
  )
  activations[network_layer_count(network.sizes)].copy()
}
