"""Print the temporal graphs the upstream reads from a CSV and from a DOT.

`dowhy.utils.timeseries` reads a temporal graph from a CSV file with
`create_graph_from_csv` and from a DOT file with `create_graph_from_dot_format`.
The upstream reads the files, and this library has no file system, so the port
of the two readers takes the text of the file.

This script runs the two functions of the upstream on the contents of the
fixtures of the upstream test file
`tests/timeseries/test_temporal_causal_graph_creation.py` and prints the edges
they give, so that the port has something to compare against.

The reader of the DOT of the upstream needs `pygraphviz`, which is not
installed here, so the script reports the error of the upstream and then runs
the reader with the `pydot` backend of networkx in its place.  The backend of
`pydot` keeps the quotes around the value of an attribute, where the backend
of `pygraphviz` takes them off, so the script takes them off as well: the
upstream reads the label of an edge with `label.strip("()").split(",")`, and a
label that still holds its quotes is not a number.

Run: python _verify/timeseries_readers_reference.py
"""

import os
import sys
import tempfile

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

import networkx as nx
from networkx.drawing import nx_pydot

from dowhy.utils.timeseries import create_graph_from_csv, create_graph_from_dot_format

CSV_BASIC = """node1,node2,time_lag
A,B,5
B,C,2
A,C,7"""

CSV_MULTIPLE = """node1,node2,time_lag
A,B,5
A,B,3
A,C,7"""

CSV_INVALID = """node1,node2,time_lag
A,B,five
B,C,2
A,C,7"""

CSV_EMPTY = """node1,node2,time_lag"""

CSV_SELF_LOOP = """node1,node2,time_lag
A,A,5"""

DOT_BASIC = """digraph G {
  A -> B [label="(5)"];
  B -> C [label="(2)"];
  A -> C [label="(7)"];
}"""

DOT_MULTIPLE = """digraph G {
  A -> B [label="(5,3)"];
  A -> C [label="(7)"];
}"""

DOT_PARALLEL = """digraph G {
  A -> B [label="(5)"];
  A -> B [label="(3)"];
  A -> C [label="(7)"];
}"""

DOT_INVALID = """digraph G {
  A -> B [label="(five)"];
  B -> C [label="(2)"];
  A -> C [label="(7)"];
}"""

DOT_EMPTY = "digraph G {}"

DOT_SELF_LOOP = """digraph G {
  A -> A [label="(5)"];
}"""


def read_dot_without_pygraphviz(path):
    """The reader of the DOT with the `pydot` backend in the place of the
    backend of `pygraphviz`.

    The backend of `pydot` keeps the quotes around the value of an attribute,
    where the backend of `pygraphviz` takes them off.
    """
    graph = nx_pydot.read_dot(path)
    for _, _, data in graph.edges(data=True):
        for key, value in list(data.items()):
            if (
                isinstance(value, str)
                and len(value) >= 2
                and value.startswith('"')
                and value.endswith('"')
            ):
                data[key] = value[1:-1]
    return graph


def show(title, graph):
    print(title)
    if graph is None:
        print("   the upstream gives no graph")
        return
    print("   ", len(graph.edges()), "edges")
    for u, v, data in sorted(graph.edges(data=True)):
        print("   ", u, "->", v, data.get("time_lag"))


def with_file(content, suffix, call):
    with tempfile.TemporaryDirectory() as folder:
        path = os.path.join(folder, "temporal" + suffix)
        with open(path, "w") as handle:
            handle.write(content)
        return call(path)


def main():
    print("=" * 70)
    print("the CSV reader of the upstream")
    print("=" * 70)
    for name, content in [
        ("the basic fixture", CSV_BASIC),
        ("the fixture of several lags", CSV_MULTIPLE),
        ("the fixture of an invalid lag", CSV_INVALID),
        ("the empty fixture", CSV_EMPTY),
        ("the fixture of a self loop", CSV_SELF_LOOP),
    ]:
        show(
            name + ":",
            with_file(content, ".csv", create_graph_from_csv),
        )

    print()
    print("=" * 70)
    print("the DOT reader of the upstream")
    print("=" * 70)
    print("the reader of the upstream needs pygraphviz:")
    try:
        with_file(DOT_BASIC, ".dot", create_graph_from_dot_format)
    except Exception as error:  # noqa: BLE001 - the upstream raises several kinds
        print("   the upstream raises {}: {}".format(type(error).__name__, error))

    print()
    print("the same reader with the backend of pydot:")
    nx.drawing.nx_agraph.read_dot = read_dot_without_pygraphviz
    for name, content in [
        ("the basic fixture", DOT_BASIC),
        ("the fixture of several lags", DOT_MULTIPLE),
        ("the fixture of two edges of one pair", DOT_PARALLEL),
        ("the fixture of an invalid lag", DOT_INVALID),
        ("the empty fixture", DOT_EMPTY),
        ("the fixture of a self loop", DOT_SELF_LOOP),
    ]:
        show(
            name + ":",
            with_file(content, ".dot", create_graph_from_dot_format),
        )


main()
