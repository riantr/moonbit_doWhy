"""Generates the daggity fixture of the upstream test as a MoonBit literal.

The upstream test file `tests/test_causal_graph.py` reads the graph of the
daggity web site from the file `tests/sample_dag.txt`.  The port has no file
system, so the fixture is a literal of the port.

The script writes `src/graph/daggity_fixture.mbt`; do not edit that file by
hand.

Usage:
    python _verify/gen_graph_fixture.py
"""

from __future__ import annotations

import io
import os

UPSTREAM_ROOT = os.environ.get(
    "DOWHY_UPSTREAM_ROOT",
    r"D:\src\MiniMax\git\dowhy\dowhy-0.14",
)
PORT_ROOT = os.environ.get(
    "MOONBIT_DOWHY_ROOT",
    r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy",
)
SOURCE = os.path.join(UPSTREAM_ROOT, "tests", "sample_dag.txt")
TARGET = os.path.join(PORT_ROOT, "src", "graph", "daggity_fixture.mbt")

HEADER = '''/// The daggity fixture of the upstream test file `tests/test_causal_graph.py`.
///
/// The graph is the one of the file `tests/sample_dag.txt` of the upstream: the
/// treatment `v0` has the outcome `y`, the common causes `W0` and the four
/// features `X0`, `X1` and `X2` are its parents, `Z0` is its instrument and
/// `Unobserved Confounders` is an unobserved common cause of the treatment and
/// of the outcome.
///
/// The fixture comes from `_verify/gen_graph_fixture.py`, which reads the file
/// of the upstream; do not edit it by hand.

///|
/// The graph of the daggity web site, as the upstream writes it.
pub fn daggity_fixture() -> String {
  let mut out = ""
'''

FOOTER = """  out
}
"""


def main() -> None:
    with io.open(SOURCE, "r", encoding="utf-8") as handle:
        lines = handle.read().split("\n")
    body = []
    for line in lines:
        escaped = line.replace("\\", "\\\\").replace('"', '\\"')
        body.append('  out = out + "%s\\n"\n' % escaped)
    with io.open(TARGET, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(HEADER)
        handle.write("".join(body))
        handle.write(FOOTER)
    print("wrote %s (%d lines of fixture)" % (TARGET, len(body)))


if __name__ == "__main__":
    main()
