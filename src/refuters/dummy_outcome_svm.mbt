///|
/// The support vector regressor of the dummy outcome refuter.
///
/// This is the port of the `SVR` of scikit-learn, which the upstream builds
/// when the transformation list of the refuter names the `svm` estimator. The
/// regressor has the radial basis kernel of scikit-learn, the penalty `C` and
/// the width of the tube of the epsilon insensitive loss of the caller, and it
/// is fitted on the dual of that loss.
///
/// The solver is the one of libsvm, the library scikit-learn uses: the rows
/// are duplicated, the first copy of every row carries the label +1 and the
/// second one the label -1, the matrix of the kernel is signed, and the linear
/// term of the copy with the label +1 is `epsilon - y` and the one of the copy
/// with the label -1 is `epsilon + y`. The solver keeps the gradient of the
/// objective and updates two variables at a time, and it stops when the spread
/// of the signed gradient of the copies falls below its tolerance.
///
/// The kernel is computed row by row and never held in memory, so a fit needs
/// the memory of the rows and not the memory of their matrix.
///
/// The dual of the epsilon insensitive loss is not strictly convex, so two
/// solvers of the same tolerance reach a nearby but not identical point of the
/// tube. The port and scikit-learn therefore agree to the tolerance of the
/// solver, which is the tolerance of scikit-learn.

///|
/// The tolerance of the solver of the port.
///
/// This is the default of the `tol` of scikit-learn, whose solver of the
/// support vector machine the port follows.
const SVR_TOL : Double = 0.001

///|
/// The smallest quadratic coefficient the solver of the port divides by.
///
/// This is the `TAU` of libsvm, the library scikit-learn uses.
const SVR_TAU : Double = 0.000000000001

///|
/// The number of the iterations the solver of the port takes at most.
const SVR_MAX_ITER : Int32 = 1000000

///|
/// A fitted support vector regressor.
priv struct SupportVectorMachine {
  /// The coefficient of every row of the training data, which is zero for the
  /// rows that are not support vectors.
  coefficients : Array[Double]
  /// The rows of the training data, as a flat array.
  rows : Array[Double]
  /// The number of the features.
  features : Int32
  /// The gamma of the kernel.
  gamma : Double
  /// The bias of the model, which the prediction adds to its sum.
  bias : Double
}

///|
/// The radial basis kernel of two rows of two flat arrays of covariates.
fn svm_kernel(
  a : Array[Double],
  b : Array[Double],
  features : Int32,
  gamma : Double,
  a_row : Int32,
  b_row : Int32,
) -> Double {
  let mut total = 0.0
  for k = 0; k < features; k = k + 1 {
    let difference = a[a_row * features + k] - b[b_row * features + k]
    total = total + difference * difference
  }
  @math.exp(-gamma * total)
}

///|
/// The gamma of the kernel of scikit-learn.
///
/// This is the `scale` of scikit-learn: the inverse of the number of the
/// features times the variance of the training data, the variance of numpy
/// and not the one of a sample.
fn svm_gamma(flat : Array[Double], features : Int32) -> Double {
  let variance = @utils.variance(flat, 0)
  if variance == 0.0 {
    return 1.0
  }
  1.0 / (features.to_double() * variance)
}

///|
/// The row of the signed matrix of the kernel of the given row.
///
/// The matrix has two rows for every row of the training data: the first one
/// carries the label +1 and the second one the label -1, and the kernel of two
/// of its rows is the kernel of the training data signed by the two labels.
fn svm_signed_row(
  flat : Array[Double],
  features : Int32,
  gamma : Double,
  l : Int32,
  index : Int32,
  row_sign : Double,
  out : Array[Double],
) -> Unit {
  // The two copies of a row of the training data share their kernel, so it is
  // computed once for the two of them.
  for point = 0; point < l; point = point + 1 {
    let value = row_sign * svm_kernel(flat, flat, features, gamma, index, point)
    out[point] = value
    out[point + l] = -value
  }
}

///|
/// The bias of the model of the solver.
///
/// This is the `calculate_rho` of libsvm: the average of the signed gradient
/// of the copies that are free. The bias of the model is the other way round,
/// because the prediction of libsvm subtracts it.
fn svm_rho(
  alpha : Array[Double],
  gradient : Array[Double],
  c : Double,
  l : Int32,
) -> Double {
  let n = alpha.length()
  let mut free = 0
  let mut total = 0.0
  let mut upper = @double.infinity
  let mut lower = @double.neg_infinity
  for t = 0; t < n; t = t + 1 {
    let sign = if t < l { 1.0 } else { -1.0 }
    let value = sign * gradient[t]
    if alpha[t] >= c {
      if sign < 0.0 {
        if value < upper {
          upper = value
        }
      } else if value > lower {
        lower = value
      }
    } else if alpha[t] <= 0.0 {
      if sign > 0.0 {
        if value < upper {
          upper = value
        }
      } else if value > lower {
        lower = value
      }
    } else {
      free = free + 1
      total = total + value
    }
  }
  if free > 0 {
    total / free.to_double()
  } else {
    (upper + lower) / 2.0
  }
}

///|
/// Fit the support vector regressor on the covariates and the outcome.
///
/// This is the port of the fit of the `SVR` of scikit-learn, which the
/// upstream builds when the transformation list of the dummy outcome refuter
/// names the `svm` estimator.
fn svm_fit(
  x : @api.DataFrame,
  y : Array[Double],
  c : Double,
  epsilon : Double,
) -> SupportVectorMachine {
  let (flat, rows, features) = covariate_matrix(x)
  let l = rows
  let n = 2 * l
  let alpha : Array[Double] = []
  let gradient : Array[Double] = []
  for _ in 0..<n {
    alpha.push(0.0)
    gradient.push(0.0)
  }
  // The linear term of the two copies of every row: the copy with the label
  // +1 carries `epsilon - y` and the one with the label -1 carries
  // `epsilon + y`.
  for t = 0; t < l; t = t + 1 {
    gradient[t] = epsilon - y[t]
    gradient[t + l] = epsilon + y[t]
  }
  let row_i : Array[Double] = []
  let row_j : Array[Double] = []
  for _ in 0..<n {
    row_i.push(0.0)
    row_j.push(0.0)
  }
  let gamma = svm_gamma(flat, features)
  let mut iteration = 0
  while iteration < SVR_MAX_ITER {
    // The working set: the variable that violates the conditions of the
    // optimum the most, and the one that repairs them the cheapest.
    let mut g_max = @double.neg_infinity
    let mut i = -1
    for t = 0; t < n; t = t + 1 {
      if t < l {
        if alpha[t] < c && -gradient[t] >= g_max {
          g_max = -gradient[t]
          i = t
        }
      } else if alpha[t] > 0.0 && gradient[t] >= g_max {
        g_max = gradient[t]
        i = t
      }
    }
    if i < 0 {
      break
    }
    let i_point = if i < l { i } else { i - l }
    let i_sign = if i < l { 1.0 } else { -1.0 }
    svm_signed_row(flat, features, gamma, l, i_point, i_sign, row_i)
    let mut g_max2 = @double.neg_infinity
    let mut j = -1
    let mut best = @double.infinity
    for t = 0; t < n; t = t + 1 {
      if t < l {
        if alpha[t] > 0.0 {
          let difference = g_max + gradient[t]
          if gradient[t] >= g_max2 {
            g_max2 = gradient[t]
          }
          if difference > 0.0 {
            let quadratic = 2.0 - 2.0 * i_sign * row_i[t]
            let value = -(difference * difference) /
              (if quadratic > 0.0 { quadratic } else { SVR_TAU })
            if value <= best {
              j = t
              best = value
            }
          }
        }
      } else if alpha[t] < c {
        let difference = g_max - gradient[t]
        if -gradient[t] >= g_max2 {
          g_max2 = -gradient[t]
        }
        if difference > 0.0 {
          let quadratic = 2.0 + 2.0 * i_sign * row_i[t]
          let value = -(difference * difference) /
            (if quadratic > 0.0 { quadratic } else { SVR_TAU })
          if value <= best {
            j = t
            best = value
          }
        }
      }
    }
    if g_max + g_max2 < SVR_TOL || j < 0 {
      break
    }
    // The update of the two variables, which keeps the sum of the copies of
    // every row at zero and respects the bounds.
    let j_point = if j < l { j } else { j - l }
    let j_sign = if j < l { 1.0 } else { -1.0 }
    svm_signed_row(flat, features, gamma, l, j_point, j_sign, row_j)
    let old_i = alpha[i]
    let old_j = alpha[j]
    if (i < l) != (j < l) {
      let quadratic = 2.0 + 2.0 * row_i[j]
      let coefficient = if quadratic > 0.0 { quadratic } else { SVR_TAU }
      let delta = (-gradient[i] - gradient[j]) / coefficient
      let difference = alpha[i] - alpha[j]
      alpha[i] = alpha[i] + delta
      alpha[j] = alpha[j] + delta
      if difference > 0.0 {
        if alpha[j] < 0.0 {
          alpha[j] = 0.0
          alpha[i] = difference
        }
      } else if alpha[i] < 0.0 {
        alpha[i] = 0.0
        alpha[j] = -difference
      }
      if difference > c {
        if alpha[i] > c {
          alpha[i] = c
          alpha[j] = c - difference
        }
      } else if alpha[j] > c {
        alpha[j] = c
        alpha[i] = c + difference
      }
    } else {
      let quadratic = 2.0 - 2.0 * row_i[j]
      let coefficient = if quadratic > 0.0 { quadratic } else { SVR_TAU }
      let delta = (gradient[i] - gradient[j]) / coefficient
      let total = alpha[i] + alpha[j]
      alpha[i] = alpha[i] - delta
      alpha[j] = alpha[j] + delta
      if total > c {
        if alpha[i] > c {
          alpha[i] = c
          alpha[j] = total - c
        }
      } else if alpha[j] < 0.0 {
        alpha[j] = 0.0
        alpha[i] = total
      }
      if total > c {
        if alpha[j] > c {
          alpha[j] = c
          alpha[i] = total - c
        }
      } else if alpha[i] < 0.0 {
        alpha[i] = 0.0
        alpha[j] = total
      }
    }
    // The gradient of the objective, which the two changes move.
    let change_i = alpha[i] - old_i
    let change_j = alpha[j] - old_j
    for k = 0; k < n; k = k + 1 {
      gradient[k] = gradient[k] + row_i[k] * change_i + row_j[k] * change_j
    }
    iteration = iteration + 1
  }
  // The coefficients of the support vectors and the bias of the model.
  let coefficients : Array[Double] = []
  for t = 0; t < l; t = t + 1 {
    coefficients.push(alpha[t] - alpha[t + l])
  }
  let bias = -svm_rho(alpha, gradient, c, l)
  { coefficients, rows: flat, features, gamma, bias, }
}

///|
/// The predictions of the regressor are the ones of scikit-learn.
///
/// The fixture is the one of `_verify/support_vector_machine_reference.py`,
/// which fits the `SVR` of scikit-learn on the same forty rows and prints its
/// predictions. The two agree to about `5e-8`, the difference of the order of
/// the last bits of the double: the dual of the epsilon insensitive loss is not
/// strictly convex, so the two solvers of the same tolerance reach a nearby
/// but not identical point of the tube.
test "the predictions of the support vector regressor are the ones of scikit-learn" {
  let first : Array[Double] = []
  let second : Array[Double] = []
  let outcome : Array[Double] = []
  for i = 0; i < 40; i = i + 1 {
    let x0 = (i % 7).to_double() * 0.5 - 1.5
    let x1 = (i % 5).to_double() * 0.4 - 0.8
    first.push(x0)
    second.push(x1)
    outcome.push(2.0 * x0 - 1.5 * x1 + 0.1 * (i % 3).to_double())
  }
  let columns : Map[String, Array[Double]] = Map([("x0", first), ("x1", second)])
  let frame = @api.DataFrame::from_numeric(["x0", "x1"], columns)
  let model = svm_fit(frame, outcome, 1.0, 0.2)
  let prediction = svm_predict(model, frame)
  let expected : Array[Double] = [
    -1.6000291150547172, -1.5002650424978834, -0.9591828170207148, -0.5680699193424744,
    -0.00017512702744853365, 2.907081641927581, 3.1351985301848084, -2.700265081831824,
    -2.600343213247115, -1.9409656822851769, 1.1001476426455838, 1.8192288036960953,
    2.2403065395758524, 2.269981663368614, -2.8841111006042497, -0.9820648006353359,
    -0.3409561241675776, 0.12043134934802235, 0.47609582515335297, 1.0416270898937536,
    3.0442259221916728, -2.1852490323392377, -2.0966550616568997, -1.5996937134197298,
    -0.9998869177838592, 2.0999195029537754, 2.7877260427482327, 2.799988093089249,
    -2.997176620791011, -2.726763218686284, 0.05323871874801889, 0.7653661823867038,
    1.1676393889330283, 1.5890245043644786, 1.700603083930852, -1.6000291150547172,
    -1.5002650424978834, -0.9591828170207148, -0.5680699193424744, -0.00017512702744853365,
  ]
  assert_eq(prediction.length(), expected.length())
  for i = 0; i < expected.length(); i = i + 1 {
    assert_true((prediction[i] - expected[i]).abs() < 0.000001)
  }
  assert_true((model.bias - 0.05294372054950625).abs() < 0.000001)
}

///|
/// The prediction of the regressor on the covariates of the frame.
fn svm_predict(
  model : SupportVectorMachine,
  x : @api.DataFrame,
) -> Array[Double] {
  let (flat, rows, _) = covariate_matrix(x)
  let out : Array[Double] = []
  for i = 0; i < rows; i = i + 1 {
    let mut total = 0.0
    for s = 0; s < model.coefficients.length(); s = s + 1 {
      let coefficient = model.coefficients[s]
      if coefficient != 0.0 {
        total = total +
          coefficient *
          svm_kernel(model.rows, flat, model.features, model.gamma, s, i)
      }
    }
    out.push(total + model.bias)
  }
  out
}
