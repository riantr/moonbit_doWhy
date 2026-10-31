///|
/// The Fisher z test of conditional independence.
///
/// This is the port of the `fisherz` test of `causal-learn`, the test the
/// upstream `dowhy.cm.pc.PC` used under the hood. The partial correlation of
/// two variables given a conditioning set is read from the inverse of the
/// correlation sub matrix of the two variables and of the conditioning set,
/// and the Fisher transform `z = 0.5 * ln((1 + r) / (1 - r))` is divided by
/// its standard error `1 / sqrt(n - |S| - 3)` to give the normal statistic
/// that is compared against the critical value of the significance level. The
/// same standard error is used by `dowhy.utils.cit.compute_ci`.
pub struct FisherZ {
  /// The correlation matrix of the variables.
  corr : @utils.Matrix
  /// The number of observations behind the correlation matrix.
  n : Int32
  /// The significance level of the test.
  alpha : Double
}

///|
/// The outcome of a conditional independence test.
pub struct IndependenceTest {
  /// The partial correlation of the two variables.
  correlation : Double
  /// The Fisher transform of the partial correlation.
  z : Double
  /// The normal statistic of the test.
  statistic : Double
  /// The two sided p value of the test.
  p_value : Double
}

///|
/// Build a Fisher z test for the given correlation matrix.
///
/// `n` is the number of observations the correlation matrix was computed
/// from and `alpha` the significance level of the test.
pub fn FisherZ::new(corr : @utils.Matrix, n : Int32, alpha : Double) -> FisherZ {
  { corr, n, alpha, }
}

///|
/// The number of observations behind the correlation matrix.
pub fn FisherZ::sample_size(self : FisherZ) -> Int32 {
  self.n
}

///|
/// The significance level of the test.
pub fn FisherZ::alpha(self : FisherZ) -> Double {
  self.alpha
}

///|
/// The critical value of the normal distribution for the significance level.
pub fn FisherZ::critical_value(self : FisherZ) -> Double {
  @utils.normal_ppf(1.0 - self.alpha / 2.0)
}

///|
/// The partial correlation of the two variables.
pub fn IndependenceTest::correlation(self : IndependenceTest) -> Double {
  self.correlation
}

///|
/// The Fisher transform of the partial correlation.
pub fn IndependenceTest::z(self : IndependenceTest) -> Double {
  self.z
}

///|
/// The normal statistic of the test.
pub fn IndependenceTest::statistic(self : IndependenceTest) -> Double {
  self.statistic
}

///|
/// The two sided p value of the test.
pub fn IndependenceTest::p_value(self : IndependenceTest) -> Double {
  self.p_value
}

///|
/// The partial correlation of `x` and `y` given the conditioning set `s`.
///
/// The partial correlation is read from the inverse `P` of the correlation
/// sub matrix of `x`, `y` and `s` as `r = -P_xy / sqrt(P_xx * P_yy)`. A
/// singular sub matrix falls back to the Moore-Penrose pseudo inverse, which
/// is what `causal-learn` does as well.
fn FisherZ::partial_correlation(
  self : FisherZ,
  x : Int32,
  y : Int32,
  s : Array[Int32],
) -> Double {
  let indices = [x, y] + s
  let size = indices.length()
  let sub = @utils.Matrix::zeros(size, size)
  for i = 0; i < size; i = i + 1 {
    for j = 0; j < size; j = j + 1 {
      sub.set(i, j, self.corr.get(indices[i], indices[j]))
    }
  }
  let inv = match @utils.mat_inverse(sub) {
    Some(m) => m
    None => @utils.mat_pinv(sub)
  }
  let denominator = (inv.get(0, 0) * inv.get(1, 1)).sqrt()
  if denominator <= 0.0 {
    return 0.0
  }
  -inv.get(0, 1) / denominator
}

///|
/// Test whether `x` and `y` are conditionally independent given `s`.
///
/// The result carries the partial correlation, the Fisher transform, the
/// normal statistic and the two sided p value of the test.
pub fn FisherZ::check(
  self : FisherZ,
  x : Int32,
  y : Int32,
  s : Array[Int32],
) -> IndependenceTest {
  let r = self.partial_correlation(x, y, s)
  // A correlation of exactly one would make the Fisher transform infinite,
  // so the value is kept strictly inside the open unit interval.
  let eps = 1.0e-12
  let clipped = if r >= 1.0 - eps {
    1.0 - eps
  } else if r <= -1.0 + eps {
    -1.0 + eps
  } else {
    r
  }
  let z = 0.5 * @math.ln((1.0 + clipped) / (1.0 - clipped))
  let df = self.n - s.length() - 3
  let se = if df > 0 { 1.0 / df.to_double().sqrt() } else { 1.0 }
  let statistic = z / se
  let p_value = 2.0 * (1.0 - @utils.normal_cdf(statistic.abs()))
  { correlation: r, z, statistic, p_value, }
}

///|
/// Whether `x` and `y` are conditionally independent given `s`.
///
/// Independence is accepted when the absolute value of the normal statistic
/// stays below the critical value of the significance level.
pub fn FisherZ::is_independent(
  self : FisherZ,
  x : Int32,
  y : Int32,
  s : Array[Int32],
) -> Bool {
  let result = self.check(x, y, s)
  result.statistic.abs() < self.critical_value()
}
