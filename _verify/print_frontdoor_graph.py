"""Prints the graph string of the upstream test as a MoonBit array literal.

The upstream test of the frontdoor estimator builds the graph as a triple
quoted string and removes its newlines, so the graph the upstream reads is one
long line.  The script writes the lines of that line back, so that the MoonBit
test can hold the very same string without a transcription error.

Usage:
    python _verify/print_frontdoor_graph.py
"""

from __future__ import annotations

import os

UPSTREAM = (
    r"D:\src\MiniMax\git\dowhy\dowhy-0.14"
    r"\tests\causal_estimators\test_two_stage_regression_estimator.py"
)


def main() -> None:
    source = open(UPSTREAM, encoding="utf-8").read()
    start = source.find('graph = """')
    stop = source.find('""".replace', start)
    block = source[start + len('graph = """') : stop]
    flat = block.replace("\n", "")
    print("length:", len(flat))
    print("flat:", repr(flat))
    print()
    print("the MoonBit literal:")
    for line in block.split("\n"):
        escaped = line.replace("\\", "\\\\").replace('"', '\\"')
        print(f'    "{escaped}",')
    print()
    print("the joined string has the same length:", len("".join(block.split("\n"))))


if __name__ == "__main__":
    main()
