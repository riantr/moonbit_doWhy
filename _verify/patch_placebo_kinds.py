"""Fixes the two problems of the placebo refuter patch.

The enumeration of the placebo type has no `Eq` implementation, so the
comparisons of the port use a match instead of the operators, and the kind of
the treatment column is private, because it does not occur in a public
signature.

Usage:
    python _verify/patch_placebo_kinds.py
"""

from __future__ import annotations

import os

PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "src",
    "refuters",
    "refuters.mbt",
)

HELPER = '''///|
/// Whether the placebo is the permuted one.
///
/// The enumeration of the placebo type carries no `Eq` implementation, so the
/// comparison is a match.
fn is_permute(placebo_type : PlaceboType) -> Bool {
  match placebo_type {
    PlaceboType::Permute => true
    PlaceboType::RandomData => false
  }
}

'''


def main() -> None:
    with open(PATH, encoding="utf-8") as handle:
        text = handle.read()
    if "fn is_permute" in text:
        print("already patched")
        return
    text = text.replace(
        "if identifier == \"iv\" && placebo_type != PlaceboType::Permute {",
        "if identifier == \"iv\" && !is_permute(placebo_type) {",
    )
    text = text.replace(
        "let permutation = if placebo_type == PlaceboType::Permute {",
        "let permutation = if is_permute(placebo_type) {",
    )
    text = text.replace("enum TreatmentKind {", "priv enum TreatmentKind {", 1)
    anchor = "///|\n/// The kind of the treatment column of the placebo refuter."
    text = text.replace(anchor, HELPER + anchor, 1)
    with open(PATH, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)
    print("patched", PATH)


if __name__ == "__main__":
    main()
