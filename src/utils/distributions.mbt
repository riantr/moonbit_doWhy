/// The chi-square and the F distribution.
///
/// These are the two distributions that the graphical causal model package of
/// upstream needs and that the port did not have yet. The conventions follow
/// `scipy.stats`: the survival function is `1 - cdf`, and the quantile
/// function inverts the distribution function.
///
/// The chi-square distribution is a gamma distribution with the shape
/// `k / 2` and the scale `2`, so its distribution function is the regularised
/// lower incomplete gamma function. The F distribution is the ratio of two
/// chi-square distributions, so its survival function is the regularised
/// incomplete beta function, which the port already has.

///|
/// The regularised lower incomplete gamma function.
///
/// It is `P(a, x)`, the probability that a gamma distributed variable with the
/// shape `a` and the scale `1` is at most `x`.
pub fn gammainc(a : Double, x : Double) -> Double {
  if x < 0.0 || a <= 0.0 {
    return 0.0
  }
  if x == 0.0 {
    return 0.0
  }
  if x < a + 1.0 {
    // The series converges quickly for a small `x`.
    let mut sum = 1.0 / a
    let mut term = sum
    let mut n = 0
    while n < 1000 {
      n = n + 1
      term = term * x / (a + n.to_double())
      sum = sum + term
      if term.abs() < sum.abs() * 1.0e-16 {
        break
      }
    }
    sum * @math.exp(-x + a * @math.ln(x) - ln_gamma(a))
  } else {
    // The continued fraction converges quickly for a large `x`.
    1.0 - gammaq_continued_fraction(a, x)
  }
}

///|
/// The regularised upper incomplete gamma function.
///
/// It is `Q(a, x)`, the probability that a gamma distributed variable with the
/// shape `a` and the scale `1` is *more* than `x`. It is the complement of
/// `gammainc`, and it is computed without the subtraction of the two, so it
/// keeps its precision where the complement of `gammainc` would lose it.
pub fn gammaincc(a : Double, x : Double) -> Double {
  if x <= 0.0 {
    return 1.0
  }
  if a <= 0.0 {
    return nan()
  }
  if x < a + 1.0 {
    // The lower part is small here, so the complement of it does not lose any
    // precision.
    return 1.0 - gammainc(a, x)
  }
  gammaq_continued_fraction(a, x)
}

///|
/// The continued fraction of the regularised upper incomplete gamma function.
fn gammaq_continued_fraction(a : Double, x : Double) -> Double {
  let tiny = 1.0e-300
  let mut b = x + 1.0 - a
  let mut c = 1.0 / tiny
  let mut d = 1.0 / b
  let mut h = d
  let mut i = 1
  while i < 1000 {
    let an = -i.to_double() * (i.to_double() - a)
    b = b + 2.0
    d = an * d + b
    if d.abs() < tiny {
      d = tiny
    }
    c = b + an / c
    if c.abs() < tiny {
      c = tiny
    }
    d = 1.0 / d
    let del = d * c
    h = h * del
    if (del - 1.0).abs() < 1.0e-16 {
      break
    }
    i = i + 1
  }
  h * @math.exp(-x + a * @math.ln(x) - ln_gamma(a))
}

///|
/// The cumulative distribution function of the chi-square distribution.
pub fn chi2_cdf(x : Double, df : Double) -> Double {
  if x <= 0.0 {
    return 0.0
  }
  gammainc(df / 2.0, x / 2.0)
}

///|
/// The survival function of the chi-square distribution.
pub fn chi2_sf(x : Double, df : Double) -> Double {
  if x <= 0.0 {
    return 1.0
  }
  1.0 - chi2_cdf(x, df)
}

///|
/// The quantile function of the chi-square distribution.
///
/// The quantile `p` is the `x` for which the distribution function is `p`.
pub fn chi2_ppf(p : Double, df : Double) -> Double {
  if p <= 0.0 {
    return 0.0
  }
  if p >= 1.0 {
    return @double.infinity
  }
  // The distribution function is increasing, so a bisection finds the quantile.
  let mut lower = 0.0
  let mut upper = 1.0
  while chi2_cdf(upper, df) < p && upper < 1.0e12 {
    upper = upper * 2.0
  }
  let mut iteration = 0
  while upper - lower > 1.0e-14 * (upper + 1.0) && iteration < 200 {
    iteration = iteration + 1
    let middle = 0.5 * (lower + upper)
    if chi2_cdf(middle, df) < p {
      lower = middle
    } else {
      upper = middle
    }
  }
  0.5 * (lower + upper)
}

///|
/// The cumulative distribution function of the F distribution.
pub fn f_cdf(f : Double, df1 : Double, df2 : Double) -> Double {
  if f <= 0.0 {
    return 0.0
  }
  1.0 - f_sf(f, df1, df2)
}

///|
/// The survival function of the F distribution.
pub fn f_sf(f : Double, df1 : Double, df2 : Double) -> Double {
  if f <= 0.0 {
    return 1.0
  }
  betainc(df2 / 2.0, df1 / 2.0, df2 / (df2 + df1 * f))
}

///|
/// The quantile function of the F distribution.
pub fn f_ppf(p : Double, df1 : Double, df2 : Double) -> Double {
  if p <= 0.0 {
    return 0.0
  }
  if p >= 1.0 {
    return @double.infinity
  }
  let mut lower = 0.0
  let mut upper = 1.0
  while f_cdf(upper, df1, df2) < p && upper < 1.0e12 {
    upper = upper * 2.0
  }
  let mut iteration = 0
  while upper - lower > 1.0e-14 * (upper + 1.0) && iteration < 200 {
    iteration = iteration + 1
    let middle = 0.5 * (lower + upper)
    if f_cdf(middle, df1, df2) < p {
      lower = middle
    } else {
      upper = middle
    }
  }
  0.5 * (lower + upper)
}

///|
/// The Pearson correlation of two samples.
pub fn pearson_corr(x : Array[Double], y : Array[Double]) -> Double {
  let n = x.length()
  if n != y.length() || n == 0 {
    abort("The two samples must have the same length")
  }
  let mean_x = mean(x)
  let mean_y = mean(y)
  let mut numerator = 0.0
  let mut sum_x = 0.0
  let mut sum_y = 0.0
  for i = 0; i < n; i = i + 1 {
    let dx = x[i] - mean_x
    let dy = y[i] - mean_y
    numerator = numerator + dx * dy
    sum_x = sum_x + dx * dx
    sum_y = sum_y + dy * dy
  }
  let denominator = (sum_x * sum_y).sqrt()
  if denominator == 0.0 {
    return 0.0
  }
  numerator / denominator
}

///|
/// The Spearman rank correlation of two samples.
///
/// It is the Pearson correlation of the ranks, and the ranks of a tie get the
/// mean rank, exactly like `pandas.Series.rank`.
pub fn spearman_corr(x : Array[Double], y : Array[Double]) -> Double {
  if x.length() != y.length() {
    abort("The two samples must have the same length")
  }
  pearson_corr(average_rank(x), average_rank(y))
}

///|
/// The Kendall rank correlation of two samples.
///
/// It is the tau-b variant, the one `scipy.stats.kendalltau` computes by
/// default.
pub fn kendall_tau(x : Array[Double], y : Array[Double]) -> Double {
  let n = x.length()
  if n != y.length() {
    abort("The two samples must have the same length")
  }
  let mut concordant = 0
  let mut discordant = 0
  let mut ties_x = 0
  let mut ties_y = 0
  let mut ties_both = 0
  let mut i = 0
  while i < n {
    let mut j = i + 1
    while j < n {
      let dx = x[i] - x[j]
      let dy = y[i] - y[j]
      let product = dx * dy
      if product > 0.0 {
        concordant = concordant + 1
      } else if product < 0.0 {
        discordant = discordant + 1
      } else if dx == 0.0 && dy == 0.0 {
        ties_both = ties_both + 1
      } else if dx == 0.0 {
        ties_x = ties_x + 1
      } else {
        ties_y = ties_y + 1
      }
      j = j + 1
    }
    i = i + 1
  }
  let total = n.to_double() * (n.to_double() - 1.0) / 2.0
  let numerator = (concordant - discordant).to_double()
  let denominator = ((total - ties_x.to_double()) * (total - ties_y.to_double())).sqrt()
  if denominator == 0.0 {
    return 0.0
  }
  numerator / denominator
}
