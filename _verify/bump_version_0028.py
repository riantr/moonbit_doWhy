"""Bump the version of the manifest.

The manifest is written by Python, so that it keeps its line endings and does
not gain a byte order mark: the toolchain refuses a manifest that has one.
"""

import io
import sys

PATH = r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\moon.mod"
OLD = 'version = "0.0.27"'
NEW = 'version = "0.0.28"'

raw = io.open(PATH, "rb").read()
if raw.startswith(b"\xef\xbb\xbf"):
    sys.exit("moon.mod already carries a byte order mark")
text = raw.decode("utf-8")
if text.count(OLD) != 1:
    sys.exit("the version field was not found exactly once")
text = text.replace(OLD, NEW)
io.open(PATH, "w", encoding="utf-8", newline="\n").write(text)
print("bumped")
