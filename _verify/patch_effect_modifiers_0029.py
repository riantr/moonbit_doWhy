"""The accessor of the effect modifiers of the estimator.

The bootstrap refuter perturbs the effect modifiers of the estimator, the way
the upstream does, so it needs to read them from outside the package of the
estimators.
"""

import io
import sys

PATH = r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\src\estimators\estimator.mbt"

OLD = """///|
/// The adjustment variables the estimator uses.
pub fn CausalEstimator::adjustment_set(self : CausalEstimator) -> Array[String] {
  self.adjustment_names.copy()
}
"""

NEW = """///|
/// The adjustment variables the estimator uses.
pub fn CausalEstimator::adjustment_set(self : CausalEstimator) -> Array[String] {
  self.adjustment_names.copy()
}

///|
/// The effect modifiers the estimator uses.
///
/// The bootstrap refuter perturbs them, the way the upstream does.
pub fn CausalEstimator::effect_modifiers(
  self : CausalEstimator,
) -> Array[String] {
  self.effect_modifier_names.copy()
}
"""

text = io.open(PATH, encoding="utf-8").read()
if text.count(OLD) != 1:
    sys.exit("marker not found exactly once")
text = text.replace(OLD, NEW)
io.open(PATH, "w", encoding="utf-8", newline="\n").write(text)
print("patched")
