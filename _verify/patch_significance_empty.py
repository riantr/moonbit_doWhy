"""Guard the significance test against an empty distribution.

The upstream computes the mean and the standard deviation of the simulations
with numpy, and numpy returns `nan` for an empty array, so the p-value of a
refuter that ran no simulation is `nan` upstream.  The port returns the
p-value of a test that cannot reject, which is one.
"""

import io
import sys

PATH = r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\src\refuters\refuters.mbt"


def replace(text, old, new):
    if text.count(old) != 1:
        sys.exit("marker not found exactly once:\n" + old[:300])
    return text.replace(old, new)


OLD = """fn normal_significance(
  estimate : Double,
  simulations : Array[Double],
) -> Double {
  let mean = @utils.mean(simulations)
"""

NEW = """fn normal_significance(
  estimate : Double,
  simulations : Array[Double],
) -> Double {
  if simulations.length() == 0 {
    return 1.0
  }
  let mean = @utils.mean(simulations)
"""

OLD_BOOTSTRAP_DOC = """///|
/// The two sided percentile p-value of the bootstrap test.
"""

NEW_BOOTSTRAP_DOC = """///|
/// The two sided percentile p-value of the bootstrap test.
///
/// A refuter that ran no simulation has no distribution to test the estimate
/// against, so the p-value is one.  The upstream computes the mean and the
/// standard deviation of the simulations with numpy, which returns `nan` for an
/// empty array, so its p-value is `nan` in that case.
"""

text = io.open(PATH, encoding="utf-8").read()
text = replace(text, OLD, NEW)
text = replace(text, OLD_BOOTSTRAP_DOC, NEW_BOOTSTRAP_DOC)
io.open(PATH, "w", encoding="utf-8", newline="\n").write(text)
print("patched")
