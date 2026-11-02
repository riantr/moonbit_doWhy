"""Copies the extended test file of the robust change attribution into the source.

The extended file adds the two cases of the regression method and of the
re-weighting method to the two cases of the multiply-robust method, so that
every branch of the estimator of the upstream is compared against the numbers
the upstream produces on the very same rows.
"""

import io
import os
import shutil

SOURCE = r"C:\Users\31379\AppData\Local\Temp\distribution_change_robust_test_v2.mbt"
TARGET = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "src",
    "gcm",
    "distribution_change_robust_test.mbt",
)

with io.open(SOURCE, encoding="utf-8", newline="") as handle:
    content = handle.read()

if "\r\n" in content:
    raise SystemExit("the source file has windows line endings")

with io.open(TARGET, "w", encoding="utf-8", newline="") as handle:
    handle.write(content)

print("copied", TARGET, len(content))
