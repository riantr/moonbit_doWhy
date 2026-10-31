"""Compare the ported minimal-d-separator algorithm with networkx.

The MoonBit port of `find_minimal_d_separator` is transliterated here so
that the two can be compared on the same graphs.  The transliteration follows
`src/identifiers/identify.mbt` exactly.
"""

import sys
import types
from pathlib import Path

import networkx as nx

UPSTREAM = Path(r"D:\src\MiniMax\git\dowhy\dowhy-0.14")
sys.path.insert(0, str(UPSTREAM))
sys.path.insert(0, str(UPSTREAM / "tests"))

from tests.causal_identifiers.example_graphs import (  # noqa: E402
    TEST_GRAPH_SOLUTIONS_COMPLETE_ADJUSTMENT,
)

# `dowhy/__init__.py` pulls in the causal discovery stack, which needs
# `causallearn`.  Import the graph module directly instead.
_pkg = types.ModuleType("dowhy")
_pkg.__path__ = [str(UPSTREAM / "dowhy")]
sys.modules["dowhy"] = _pkg

from dowhy.graph import (  # noqa: E402
    get_proper_backdoor_graph,
    get_proper_causal_path_nodes,
)


# --- the port, transliterated ------------------------------------------------


def port_ancestors(graph, name):
    """`DirectedGraph::ancestors` -- strict ancestors."""
    seen = set()
    stack = list(graph.predecessors(name))
    while stack:
        node = stack.pop()
        if node not in seen:
            seen.add(node)
            stack.extend(graph.predecessors(node))
    return seen


def port_descendants(graph, name):
    seen = set()
    stack = list(graph.successors(name))
    while stack:
        node = stack.pop()
        if node not in seen:
            seen.add(node)
            stack.extend(graph.successors(node))
    return seen


def port_descendants_of(graph, names):
    out = set()
    for name in names:
        out |= port_descendants(graph, name)
    return out


def port_ancestors_of(graph, names):
    out = set()
    for name in names:
        out |= port_ancestors(graph, name)
    return out


def port_do_surgery(graph, node_names, remove_outgoing, remove_incoming):
    new_graph = graph.copy()
    for node_name in node_names:
        if remove_outgoing:
            for child in list(new_graph.successors(node_name)):
                new_graph.remove_edge(node_name, child)
        if remove_incoming:
            for parent in list(new_graph.predecessors(node_name)):
                new_graph.remove_edge(parent, node_name)
    return new_graph


def port_proper_causal_path_nodes(graph, action_nodes, outcome_nodes):
    post_intervention = port_do_surgery(graph, action_nodes, False, True)
    with_sinks = port_do_surgery(graph, action_nodes, True, False)
    descendants = port_descendants_of(post_intervention, action_nodes)
    descendants |= set(action_nodes)
    ancestors = port_ancestors_of(with_sinks, outcome_nodes)
    ancestors |= set(outcome_nodes)
    return {node for node in descendants if node not in action_nodes and node in ancestors}


def port_proper_backdoor_graph(graph, action_nodes, outcome_nodes):
    pcp = port_proper_causal_path_nodes(graph, action_nodes, outcome_nodes)
    graph_pbd = graph.copy()
    for action in action_nodes:
        for node in pcp:
            if graph_pbd.has_edge(action, node):
                graph_pbd.remove_edge(action, node)
    return graph_pbd


def port_ball_passes(incoming, v, forward, node, ancestors, z):
    if node not in ancestors:
        return False
    collider = incoming and not forward
    return (v not in z) or collider


def port_reachable(graph, x, ancestors, z):
    processed = set()
    reached = set()
    queue = []
    for node in x:
        if graph.predecessors(node):
            queue.append((True, node))
        if graph.successors(node):
            queue.append((False, node))
    for state in queue:
        processed.add(state)
        reached.add(state[1])
    head = 0
    while head < len(queue):
        e, v = queue[head]
        head += 1
        for node in graph.predecessors(v):
            state = (False, node)
            if state not in processed and port_ball_passes(e, v, False, node, ancestors, z):
                queue.append(state)
                processed.add(state)
                reached.add(node)
        for node in graph.successors(v):
            state = (True, node)
            if state not in processed and port_ball_passes(e, v, True, node, ancestors, z):
                queue.append(state)
                processed.add(state)
                reached.add(node)
    return reached


def port_find_minimal_d_separator(graph, x, y, restricted):
    nodeset = set(x) | set(y)
    ancestors = set(nodeset)
    for node in nodeset:
        ancestors |= port_ancestors(graph, node)
    z_init = {
        node for node in restricted if node in ancestors and node not in x and node not in y
    }
    x_closure = port_reachable(graph, x, ancestors, z_init)
    for node in y:
        if node in x_closure:
            return None
    z_updated = z_init & x_closure
    y_closure = port_reachable(graph, y, ancestors, z_updated)
    return z_updated & y_closure


def port_generalized(graph, action_nodes, outcome_nodes, observed_nodes):
    graph_pbd = port_proper_backdoor_graph(graph, action_nodes, outcome_nodes)
    pcp_nodes = port_proper_causal_path_nodes(graph, action_nodes, outcome_nodes)
    excluded = set(pcp_nodes)
    excluded |= port_descendants_of(graph, list(pcp_nodes))
    restricted = {
        node for node in graph_pbd.nodes if node not in excluded and node in observed_nodes
    }
    separator = port_find_minimal_d_separator(graph_pbd, action_nodes, outcome_nodes, restricted)
    if separator is None:
        return []
    return [separator]


def upstream_generalized(graph, action_nodes, outcome_nodes, observed_nodes):
    graph_pbd = get_proper_backdoor_graph(graph, action_nodes, outcome_nodes)
    pcp_nodes = get_proper_causal_path_nodes(graph, action_nodes, outcome_nodes)
    dpcp_nodes = set()
    for node in pcp_nodes:
        dpcp_nodes |= set(nx.descendants(graph, node))
    dpcp_nodes |= set(pcp_nodes)
    restricted = (set(graph_pbd.nodes) - dpcp_nodes) & set(observed_nodes)
    separator = nx.algorithms.find_minimal_d_separator(
        graph_pbd, set(action_nodes), set(outcome_nodes), restricted=restricted
    )
    if separator is None:
        return []
    return [separator]


def build_graph(graph_str):
    import re

    graph = nx.DiGraph()
    if "digraph" in graph_str:
        for node in re.findall(r"([A-Za-z0-9_]+);", graph_str.split("{", 1)[1]):
            graph.add_node(node)
        for src, dst in re.findall(r"([A-Za-z0-9_]+)->([A-Za-z0-9_]+)", graph_str):
            graph.add_edge(src, dst)
        return graph
    for node in re.findall(r'node\[id "([^"]+)"', graph_str):
        graph.add_node(node)
    for src, dst in re.findall(r'edge\[source "([^"]+)"\s+target "([^"]+)"', graph_str):
        graph.add_edge(src, dst)
    return graph


def main():
    for name, solution in TEST_GRAPH_SOLUTIONS_COMPLETE_ADJUSTMENT.items():
        graph = build_graph(solution["graph_str"])
        action = solution["action_nodes"]
        outcome = solution["outcome_nodes"]
        observed = solution["observed_variables"]

        upstream = upstream_generalized(graph, action, outcome, observed)
        port = port_generalized(graph, action, outcome, observed)

        up_pbd = get_proper_backdoor_graph(graph, action, outcome)
        pt_pbd = port_proper_backdoor_graph(graph, action, outcome)
        up_pcp = set(get_proper_causal_path_nodes(graph, action, outcome))
        pt_pcp = port_proper_causal_path_nodes(graph, action, outcome)

        print(f"--- {name}")
        print(f"    upstream pcp  = {sorted(up_pcp)}")
        print(f"    port    pcp  = {sorted(pt_pcp)}")
        print(f"    upstream pbd edges = {sorted(up_pbd.edges())}")
        print(f"    port    pbd edges = {sorted(pt_pbd.edges())}")
        print(f"    upstream result   = {upstream}")
        print(f"    port    result   = {port}")
        print(f"    MATCH = {upstream == port}")


if __name__ == "__main__":
    main()
