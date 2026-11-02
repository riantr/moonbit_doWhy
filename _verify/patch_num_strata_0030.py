"""Give the stratification estimator the automatic number of strata of the upstream."""

p = r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\src\estimators\estimator.mbt"
s = open(p, encoding="utf-8", newline="").read()


def replace(old, new, count=1):
    global s
    assert s.count(old) == count, (s.count(old), old[:80])
    s = s.replace(old, new)


# 1. The enumeration.
replace(
    """///|
/// The inverse propensity score weighting scheme.
pub fn WeightingScheme::ips_weight() -> WeightingScheme {
""",
    """///|
/// The number of strata of the propensity score stratification estimator.
///
/// The upstream takes the string `"auto"`, which searches for the number of
/// strata, and an integer, which is the number of strata.
pub enum NumStrata {
  /// The given number of strata.
  Fixed(Int32)
  /// The number of strata is searched for, the way the upstream searches for
  /// it.
  Auto
}

///|
/// The inverse propensity score weighting scheme.
pub fn WeightingScheme::ips_weight() -> WeightingScheme {
""",
)

# 2. The field of the estimator.
replace(
    """  /// The number of strata, used by the stratification estimator.
  mut num_strata : Int32
""",
    """  /// The number of strata, used by the stratification estimator.
  mut num_strata : NumStrata
""",
)

# 3. The constructor of the estimator.
replace(
    """pub fn CausalEstimator::propensity_score_stratification(
  estimand : @identifiers.IdentifiedEstimand,
  num_strata : Int32,
  clipping_threshold : Int32,
) -> CausalEstimator {
""",
    """pub fn CausalEstimator::propensity_score_stratification(
  estimand : @identifiers.IdentifiedEstimand,
  num_strata : NumStrata,
  clipping_threshold : Int32,
) -> CausalEstimator {
""",
)

# 4. The default of the estimator.
replace(
    """    num_strata: 5,
""",
    """    num_strata: NumStrata::Fixed(5),
""",
)

open(p, "w", encoding="utf-8", newline="").write(s)
print("patched")
