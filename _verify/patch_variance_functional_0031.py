"""Fixes the variance functional of the port of the robust change attribution.

The upstream writes the functional of the variance as

    return (
        ThetaC(C, h_fn=lambda y: np.square(y)).est_theta(...)[0]
        - ThetaC(C).est_theta(...)[0]
        ** 2
    )

The parentheses make it look like the square of the difference, but the
exponent of Python binds tighter than the subtraction, so the upstream
computes the second moment of the target **minus the square of the first
moment** of the target.  The port computed the square of the difference, which
is a different functional, and its attributions were about twenty times the
ones of the upstream.

The patch replaces the two lines of the port with the functional of the
upstream and documents the reason.
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

old = """          let difference = second - first
          difference * difference
        }"""

new = """          // The upstream computes the second moment of the target minus the
          // square of the first moment of the target.  Its parentheses make it
          // look like the square of the difference of the two moments, but the
          // exponent of Python binds tighter than the subtraction, so the
          // upstream squares the first moment alone.  The port keeps the
          // functional of the upstream.
          second - first * first
        }"""

if old not in source:
    raise SystemExit("the functional of the variance was not found")
source = source.replace(old, new)

with io.open(PATH, "w", encoding="utf-8", newline="") as handle:
    handle.write(source)

print("patched", PATH)
