/// Descriptive statistics and probability distributions.
///
/// The conventions follow NumPy so that the ported estimators reproduce the
/// numbers DoWhy produces:
/// - `std`/`var` use `ddof=0` by default (population) and accept `ddof=1`;
/// - `percentile` uses NumPy's linear interpolation;
/// - `rank` returns the *average* rank, which is what
///   `pandas.Series.rank(ascending=True)` computes and what the propensity
///   score stratification estimator depends on.

///|
/// Arithmetic mean of an array.
pub fn mean(values : Array[Double]) -> Double {
  if values.length() == 0 {
    return 0.0
  }
  let mut s = 0.0
  for i = 0; i < values.length(); i = i + 1 {
    s = s + values[i]
  }
  s / values.length().to_double()
}

///|
/// Sample variance with the given delta degrees of freedom.
pub fn variance(values : Array[Double], ddof : Int32) -> Double {
  let n = values.length()
  if n - ddof <= 0 {
    return 0.0
  }
  let m = mean(values)
  let mut s = 0.0
  for i = 0; i < n; i = i + 1 {
    let d = values[i] - m
    s = s + d * d
  }
  s / (n - ddof).to_double()
}

///|
/// Population variance (`ddof=0`).
pub fn var_pop(values : Array[Double]) -> Double {
  variance(values, 0)
}

///|
/// Sample variance (`ddof=1`).
pub fn var_sample(values : Array[Double]) -> Double {
  variance(values, 1)
}

///|
/// Population standard deviation (`ddof=0`).
pub fn std(values : Array[Double]) -> Double {
  variance(values, 0).sqrt()
}

///|
/// Sample standard deviation (`ddof=1`).
pub fn std_sample(values : Array[Double]) -> Double {
  variance(values, 1).sqrt()
}

///|
/// Sample covariance (`ddof=1`, matching `numpy.cov`).
pub fn cov(x : Array[Double], y : Array[Double]) -> Double {
  let n = x.length()
  if n < 2 {
    return 0.0
  }
  let mx = mean(x)
  let my = mean(y)
  let mut s = 0.0
  for i = 0; i < n; i = i + 1 {
    s = s + (x[i] - mx) * (y[i] - my)
  }
  s / (n - 1).to_double()
}

///|
/// Compare two doubles, returning a negative / zero / positive integer.
pub fn compare_double(a : Double, b : Double) -> Int32 {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
/// Median of an array.
pub fn median(values : Array[Double]) -> Double {
  percentile(values, 50.0)
}

///|
/// Linear-interpolation percentile of an array, matching `numpy.percentile`.
///
/// `q` is expressed in the 0..100 range.
pub fn percentile(values : Array[Double], q : Double) -> Double {
  if values.length() == 0 {
    return 0.0
  }
  let sorted = values.copy()
  sorted.sort_by(fn(a, b) { compare_double(a, b) })
  if q <= 0.0 {
    return sorted[0]
  }
  if q >= 100.0 {
    return sorted[sorted.length() - 1]
  }
  let pos = q / 100.0 * (sorted.length() - 1).to_double()
  let lo = pos.floor().to_int()
  let hi = pos.ceil().to_int()
  if lo == hi {
    return sorted[lo]
  }
  let frac = pos - lo.to_double()
  sorted[lo] * (1.0 - frac) + sorted[hi] * frac
}

///|
/// Average ranks of the values, matching `pandas.Series.rank(ascending=True)`.
///
/// Tied values receive the mean of the ranks they span.
pub fn average_rank(values : Array[Double]) -> Array[Double] {
  let n = values.length()
  let order : Array[Int32] = []
  for i = 0; i < n; i = i + 1 {
    order.push(i)
  }
  order.sort_by(fn(a, b) { compare_double(values[a], values[b]) })
  let ranks : Array[Double] = []
  for k = 0; k < n; k = k + 1 {
    ranks.push(0.0)
  }
  let mut i = 0
  while i < n {
    let mut j = i
    while j + 1 < n && values[order[j + 1]] == values[order[i]] {
      j = j + 1
    }
    let avg = (i + j).to_double() / 2.0 + 1.0
    for k = i; k <= j; k = k + 1 {
      ranks[order[k]] = avg
    }
    i = j + 1
  }
  ranks
}

///|
/// Round half to even, matching `numpy.round` / `pandas.Series.round(0)`.
pub fn round_half_even(x : Double) -> Double {
  let floor_x = x.floor()
  let diff = x - floor_x
  if diff.abs() == 0.5 {
    // Tie: round to the even neighbour.
    if (floor_x / 2.0).trunc() != floor_x / 2.0 {
      floor_x + 1.0
    } else {
      floor_x
    }
  } else {
    x.round()
  }
}

///|
/// Complementary error function.
///
/// A continued fraction / series split gives close to machine precision for
/// the whole range of arguments.
pub fn erfc(x : Double) -> Double {
  let ax = x.abs()
  if ax < 1.0 {
    // Series expansion of erf.
    let xx = x * x
    let mut sum = 1.0
    let mut term = 1.0
    let mut n = 0
    while n < 300 {
      term = term * xx / (n * 2 + 1).to_double()
      sum = sum + term
      if term.abs() < 1.0e-18 * sum.abs() {
        break
      }
      n = n + 1
    }
    let erf = x * sum * 2.0 / @math.PI.sqrt()
    return 1.0 - erf
  }
  // Continued fraction for erfc(x) = exp(-x^2)/(x*sqrt(pi)) * F
  let xx = x * x
  let tiny = 1.0e-300
  let mut b = xx + 1.0
  let mut c = 1.0 / tiny
  let mut d = 1.0 / b
  let mut h = d
  let mut i = 1
  while i < 300 {
    let an = -i.to_double() * (i.to_double() - 1.0)
    b = b + 2.0
    d = an * d + b
    if d.abs() < 1.0e-300 {
      d = 1.0e-300
    }
    c = b + an / c
    if c.abs() < 1.0e-300 {
      c = 1.0e-300
    }
    d = 1.0 / d
    let del = d * c
    h = h * del
    if (del - 1.0).abs() < 1.0e-17 {
      break
    }
    i = i + 1
  }
  let q = @math.exp(-xx) * h / @math.PI.sqrt()
  if x > 0.0 {
    q
  } else {
    2.0 - q
  }
}

///|
/// Error function.
pub fn erf(x : Double) -> Double {
  1.0 - erfc(x)
}

///|
/// Cumulative distribution function of the standard normal distribution.
pub fn normal_cdf(z : Double) -> Double {
  0.5 * erfc(-z / 2.0.sqrt())
}

///|
/// Inverse of the standard normal cumulative distribution function.
pub fn normal_ppf(p : Double) -> Double {
  if p <= 0.0 {
    return @double.neg_infinity
  }
  if p >= 1.0 {
    return @double.infinity
  }
  // Acklam's inverse normal CDF, refined with one Halley step.
  let a = [
    -3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02, 1.383577518672690e+02,
    -3.066479806614716e+01, 2.506628277459239e+00,
  ]
  let b = [
    -5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02, 6.680131188771972e+01,
    -1.328068155288572e+01,
  ]
  let c = [
    -7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00, -2.549732539343734e+00,
    4.374664141464968e+00, 2.938163982698783e+00,
  ]
  let d = [
    7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00, 3.754408661907416e+00,
  ]
  let plow = 0.02425
  let phigh = 1.0 - plow
  let mut x = 0.0
  if p < plow {
    let q = (-2.0 * @math.ln(p)).sqrt()
    x = (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
      ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1.0)
  } else if p <= phigh {
    let q = p - 0.5
    let r = q * q
    x = (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) *
      q /
      (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1.0)
  } else {
    let q = (-2.0 * @math.ln(1.0 - p)).sqrt()
    x = -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
      ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1.0)
  }
  let e = normal_cdf(x) - p
  let u = e * (2.0 * @math.PI).sqrt() * @math.exp(x * x / 2.0)
  x = x - u / (1.0 + x * u / 2.0)
  x
}

///|
/// Regularised incomplete beta function `I_x(a, b)`.
pub fn betainc(a : Double, b : Double, x : Double) -> Double {
  if x <= 0.0 {
    return 0.0
  }
  if x >= 1.0 {
    return 1.0
  }
  let lbeta = ln_gamma(a + b) - ln_gamma(a) - ln_gamma(b)
  let front = @math.exp(lbeta + a * @math.ln(x) + b * @math.ln(1.0 - x))
  if x < (a + 1.0) / (a + b + 2.0) {
    front * betacf(a, b, x) / a
  } else {
    1.0 - front * betacf(b, a, 1.0 - x) / b
  }
}

///|
/// Continued fraction for the incomplete beta function.
fn betacf(a : Double, b : Double, x : Double) -> Double {
  let tiny = 1.0e-300
  let qab = a + b
  let qap = a + 1.0
  let qam = a - 1.0
  let mut c = 1.0
  let mut d = 1.0 - qab * x / qap
  if d.abs() < tiny {
    d = tiny
  }
  d = 1.0 / d
  let mut h = d
  let mut m = 1
  while m < 300 {
    let m2 = (2 * m).to_double()
    let aa = m.to_double() * (b - m.to_double()) * x / ((qam + m2) * (a + m2))
    d = 1.0 + aa * d
    if d.abs() < tiny {
      d = tiny
    }
    c = 1.0 + aa / c
    if c.abs() < tiny {
      c = tiny
    }
    d = 1.0 / d
    h = h * d * c
    let aa = -(a + m.to_double()) *
      (qab + m.to_double()) *
      x /
      ((a + m2) * (qap + m2))
    d = 1.0 + aa * d
    if d.abs() < tiny {
      d = tiny
    }
    c = 1.0 + aa / c
    if c.abs() < tiny {
      c = tiny
    }
    d = 1.0 / d
    let del = d * c
    h = h * del
    if (del - 1.0).abs() < 3.0e-16 {
      break
    }
    m = m + 1
  }
  h
}

///|
/// Natural logarithm of the gamma function (Lanczos approximation).
pub fn ln_gamma(x : Double) -> Double {
  let g = 7.0
  let c = [
    0.99999999999980993, 676.5203681218851, -1259.1392167224028, 771.32342877765313,
    -176.61502916214059, 12.507343278686905, -0.13857109526572012, 9.9843695780195716e-6,
    1.5056327351493116e-7,
  ]
  if x < 0.5 {
    // Reflection formula.
    @math.ln(@math.PI / @math.sin(@math.PI * x)) - ln_gamma(1.0 - x)
  } else {
    let z = x - 1.0
    let mut a = c[0]
    let t = z + g + 0.5
    let mut i = 1
    while i < 9 {
      a = a + c[i] / (z + i.to_double())
      i = i + 1
    }
    0.5 * @math.ln(2.0 * @math.PI) + (z + 0.5) * @math.ln(t) - t + @math.ln(a)
  }
}

///|
/// Cumulative distribution function of Student's t distribution.
pub fn t_cdf(t : Double, df : Double) -> Double {
  if df <= 0.0 {
    return if t < 0.0 { 0.0 } else { 1.0 }
  }
  let x = df / (df + t * t)
  let ib = betainc(df / 2.0, 0.5, x)
  if t > 0.0 {
    1.0 - ib / 2.0
  } else {
    ib / 2.0
  }
}

///|
/// Two sided p-value of a t statistic.
pub fn t_pvalue(t : Double, df : Double) -> Double {
  2.0 * (1.0 - t_cdf(t.abs(), df))
}

///|
/// Quantile of the Student's t distribution.
pub fn t_ppf(p : Double, df : Double) -> Double {
  if p <= 0.0 {
    return @double.neg_infinity
  }
  if p >= 1.0 {
    return @double.infinity
  }
  if df <= 0.0 {
    return normal_ppf(p)
  }
  // Bisection on the monotone CDF.
  let mut lo = -1.0e4
  let mut hi = 1.0e4
  let mut iter = 0
  while iter < 200 {
    let mid = (lo + hi) / 2.0
    if t_cdf(mid, df) < p {
      lo = mid
    } else {
      hi = mid
    }
    iter = iter + 1
  }
  (lo + hi) / 2.0
}
