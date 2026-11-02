"""Replaces the local `np.vectorize` workaround of the causal model reference
script with the shared helper of the upstream loader.

The workaround is the same one, but it lives in one place now, so that the two
reference scripts cannot drift apart.

Usage:
    python _verify/patch_causal_model_reference.py
"""

from __future__ import annotations

import os

PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "causal_model_reference.py",
)

OLD_IMPORT = "from upstream_gcm import load  # noqa: E402"

NEW_IMPORT = (
    "from upstream_gcm import linear_dataset as upstream_linear_dataset  # noqa: E402\n"
    "from upstream_gcm import load  # noqa: E402"
)

START = "_real_vectorize = np.vectorize"

END = "        np.vectorize = _real_vectorize"

REPLACEMENT = (
    "def linear_dataset(**kwargs):\n"
    '    """The upstream `linear_dataset`, with the `np.vectorize` of NumPy 1.x."""\n'
    "    return upstream_linear_dataset(datasets, **kwargs)"
)


def main() -> None:
    with open(PATH, encoding="utf-8") as handle:
        text = handle.read()
    if NEW_IMPORT in text:
        print("already patched")
        return
    start = text.index(START)
    end = text.index(END) + len(END)
    text = text[:start] + REPLACEMENT + text[end:]
    text = text.replace(OLD_IMPORT, NEW_IMPORT, 1)
    with open(PATH, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)
    print("patched", PATH)


if __name__ == "__main__":
    main()
