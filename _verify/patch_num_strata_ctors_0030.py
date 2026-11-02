"""Add the constructors of the enumeration of the number of strata."""

edits = [
    (
        r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\src\estimators\estimator.mbt",
        [
            (
                """///|
/// The inverse propensity score weighting scheme.
pub fn WeightingScheme::ips_weight() -> WeightingScheme {
""",
                """///|
/// The given number of strata.
pub fn NumStrata::fixed(count : Int32) -> NumStrata {
  Fixed(count)
}

///|
/// The number of strata is searched for, the way the upstream searches for it.
pub fn NumStrata::auto() -> NumStrata {
  Auto
}

///|
/// The inverse propensity score weighting scheme.
pub fn WeightingScheme::ips_weight() -> WeightingScheme {
""",
            ),
        ],
    ),
    (
        r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\src\causal_model.mbt",
        [
            (
                "        @estimators.NumStrata::Auto,",
                "        @estimators.NumStrata::auto(),",
            ),
        ],
    ),
]

for path, replacements in edits:
    s = open(path, encoding="utf-8", newline="").read()
    for old, new in replacements:
        assert s.count(old) == 1, (path, s.count(old), old[:60])
        s = s.replace(old, new)
    open(path, "w", encoding="utf-8", newline="").write(s)
    print("patched", path)
