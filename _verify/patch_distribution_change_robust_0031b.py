"""Patch the port of the multiply-robust causal change attribution, second pass.

The first pass renamed the helpers, but it only renamed the lines that start
with the name of the helper, so the call sites, which are the right hand side
of a binding, kept the old name.  This pass renames the call sites, renames
the field of the configuration that the callers read, and removes the ``mut``
of the binding of the folds, whose value is never rebound.
"""

import io
import os

PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "src",
    "gcm",
    "distribution_change_robust.mbt",
)

with io.open(PATH, encoding="utf-8", newline="") as handle:
    source = handle.read()

source = source.replace("select_rows(", "select_matrix_rows(")
source = source.replace("select_values(", "select_array_values(")
source = source.replace("config.method,", "config.change_method,")
source = source.replace(
    "let mut out : Array[(Array[Int32], Array[Int32])] = []",
    "let out : Array[(Array[Int32], Array[Int32])] = []",
)

with io.open(PATH, "w", encoding="utf-8", newline="") as handle:
    handle.write(source)

print("patched", PATH)
