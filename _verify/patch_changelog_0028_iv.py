"""Add the instrumental variable case to the CHANGELOG entry of v0.0.28."""

import io
import sys

PATH = r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\CHANGELOG.md"

OLD = """- the tests of the significance test of the refutations: the two kinds of test,
  the automatic choice between them, the ties and the level of the test.
"""

NEW = """- the tests of the significance test of the refutations: the two kinds of test,
  the automatic choice between them, the ties and the level of the test.
- a test of the permuted placebo of the instrumental variable method, which
  permutes the instrument with the same permutation as the treatment, the way
  the upstream does.
"""

text = io.open(PATH, encoding="utf-8").read()
if text.count(OLD) != 1:
    sys.exit("marker not found exactly once")
text = text.replace(OLD, NEW)
io.open(PATH, "w", encoding="utf-8", newline="\n").write(text)
print("patched")
