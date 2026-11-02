"""Extend the replication of the generator of the port with the instruments.

The upstream estimator test files use a data set with an instrument for the
doubly robust estimator and a data set with a binary outcome for the complete
adjustment criterion of the same estimator.  This patch adds both to
`binary_treatment_dataset`, so that the upstream can run on the rows of the
port for those cases as well.
"""

import re

p = r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\_verify\port_linear_dataset.py"
s = open(p, encoding="utf-8", newline="").read()

old_signature = '''def binary_treatment_dataset(
    seed: int,
    num_rows: int,
    num_common_causes: int = 2,
    beta: float = 10.0,
) -> dict:
    """The data set of the port with common causes and a binary treatment.

    This is the configuration the upstream estimator test files use: one or two
    common causes, no instrument, no effect modifier, no frontdoor mediator,
    one binary treatment and a continuous outcome.  The draw order of the port
    is the one of `src/datasets/datasets.mbt`: the means of the common causes,
    the rows of the common causes, the coefficients of the common causes, the
    rows of the treatment, the outcome and finally the two counterfactual
    outcomes the true average treatment effect is the mean of.
    """
    rng = Rng(seed)
    rows = num_rows if num_rows > 0 else 0
    beta_abs = abs(beta)
    range_c = 0.5 + beta_abs * 0.5
'''

new_signature = '''def binary_treatment_dataset(
    seed: int,
    num_rows: int,
    num_common_causes: int = 2,
    beta: float = 10.0,
    num_instruments: int = 0,
    outcome_is_binary: bool = False,
) -> dict:
    """The data set of the port with common causes and a binary treatment.

    This is the configuration the upstream estimator test files use: one or two
    common causes, no effect modifier, no frontdoor mediator, one binary
    treatment and a continuous outcome.  The doubly robust estimator of the
    upstream test file also uses an instrument and a binary outcome.  The draw
    order of the port is the one of `src/datasets/datasets.mbt`: the means of
    the common causes, the rows of the common causes, the coefficients of the
    common causes, the probabilities and the rows of the instruments, the
    coefficients of the instruments, the rows of the treatment, the outcome and
    finally the two counterfactual outcomes the true average treatment effect
    is the mean of.
    """
    rng = Rng(seed)
    rows = num_rows if num_rows > 0 else 0
    beta_abs = abs(beta)
    range_c = 0.5 + beta_abs * 0.5
    range_cz = 1.0 + beta_abs
'''

assert s.count(old_signature) == 1
s = s.replace(old_signature, new_signature)

old_treatment = '''    # ---- the treatment ----------------------------------------------------
    treatment = []
    for i in range(rows):
        value = rng.normal()
        for j in range(num_common_causes):
            value += w[i][j] * c1[j][0]
        treatment.append([bernoulli(rng, sigmoid(value))])
'''

new_treatment = '''    # ---- the instruments --------------------------------------------------
    z = []
    cz = []
    if num_instruments > 0:
        probabilities = [rng.uniform(0.0, 1.0) for _ in range(num_instruments)]
        for _ in range(rows):
            row = []
            for k in range(num_instruments):
                if k % 2 == 0:
                    row.append(1.0 if rng.uniform01() < probabilities[k] else 0.0)
                else:
                    row.append(rng.uniform(0.0, 1.0))
            z.append(row)
        for _ in range(num_instruments):
            cz.append(
                [
                    rng.uniform(
                        range_cz - range_cz * 0.05,
                        range_cz + range_cz * 0.05,
                    )
                ]
            )

    # ---- the treatment ----------------------------------------------------
    treatment = []
    for i in range(rows):
        value = rng.normal()
        for j in range(num_common_causes):
            value += w[i][j] * c1[j][0]
        for k in range(num_instruments):
            value += z[i][k] * cz[k][0]
        treatment.append([bernoulli(rng, sigmoid(value))])
'''

assert s.count(old_treatment) == 1
s = s.replace(old_treatment, new_treatment)

old_outcome = '''    # ---- the outcome ------------------------------------------------------
    outcome = []
    for i in range(rows):
        value = rng.normal() * 0.01
        value += treatment[i][0] * beta * 1.0
        for j in range(num_common_causes):
            value += w[i][j] * c2[j]
        outcome.append(value)
'''

new_outcome = '''    # ---- the outcome ------------------------------------------------------
    def discretise(value: float) -> float:
        if outcome_is_binary:
            return bernoulli(rng, sigmoid(value))
        return value

    outcome = []
    for i in range(rows):
        value = rng.normal() * 0.01
        value += treatment[i][0] * beta * 1.0
        for j in range(num_common_causes):
            value += w[i][j] * c2[j]
        outcome.append(discretise(value))
'''

assert s.count(old_outcome) == 1
s = s.replace(old_outcome, new_outcome)

old_ate = '''    def outcome_at(value: float) -> list[float]:
        values = []
        for i in range(rows):
            total = rng.normal() * 0.01
            total += value * beta * 1.0
            for j in range(num_common_causes):
                total += w[i][j] * c2[j]
            values.append(total)
        return values
'''

new_ate = '''    def outcome_at(value: float) -> list[float]:
        values = []
        for i in range(rows):
            total = rng.normal() * 0.01
            total += value * beta * 1.0
            for j in range(num_common_causes):
                total += w[i][j] * c2[j]
            values.append(discretise(total))
        return values
'''

assert s.count(old_ate) == 1
s = s.replace(old_ate, new_ate)

old_frame = '''    # ---- the frame and the graph ------------------------------------------
    common_cause_names = [f"W{j}" for j in range(num_common_causes)]
    treatment_names = ["v0"]
    columns = {
        name: [w[i][j] for i in range(rows)]
        for j, name in enumerate(common_cause_names)
    }
    columns["v0"] = [treatment[i][0] for i in range(rows)]
    columns["y"] = outcome

    return {
        "columns": columns,
        "column_order": common_cause_names + treatment_names + ["y"],
        "ate": ate,
        "treatment_names": treatment_names,
        "outcome_name": "y",
        "common_cause_names": common_cause_names,
        "instrument_names": [],
        "effect_modifier_names": [],
        "frontdoor_names": [],
        "gml_graph": gml_graph_of_common_causes(
            treatment_names, "y", common_cause_names
        ),
    }
'''

new_frame = '''    # ---- the frame and the graph ------------------------------------------
    common_cause_names = [f"W{j}" for j in range(num_common_causes)]
    instrument_names = [f"Z{k}" for k in range(num_instruments)]
    treatment_names = ["v0"]
    columns = {
        name: [w[i][j] for i in range(rows)]
        for j, name in enumerate(common_cause_names)
    }
    for k, name in enumerate(instrument_names):
        columns[name] = [z[i][k] for i in range(rows)]
    columns["v0"] = [treatment[i][0] for i in range(rows)]
    columns["y"] = outcome

    return {
        "columns": columns,
        "column_order": (
            instrument_names + common_cause_names + treatment_names + ["y"]
        ),
        "ate": ate,
        "treatment_names": treatment_names,
        "outcome_name": "y",
        "common_cause_names": common_cause_names,
        "instrument_names": instrument_names,
        "effect_modifier_names": [],
        "frontdoor_names": [],
        "gml_graph": gml_graph_of_common_causes(
            treatment_names, "y", common_cause_names, instrument_names
        ),
    }
'''

assert s.count(old_frame) == 1
s = s.replace(old_frame, new_frame)

old_graph = '''def gml_graph_of_common_causes(
    treatments: list[str],
    outcome: str,
    common_causes: list[str],
) -> str:
    """The GML graph of the port, the one of `create_gml_graph`."""

    def node(name: str) -> str:
        return f'node[ id "{name}" label "{name}"]'

    def edge(source: str, target: str) -> str:
        return f'edge[ source "{source}" target "{target}"]'

    out = "graph[directed 1" + node(outcome)
    out += " ".join(node(name) for name in common_causes)
    for treatment in treatments:
        out += node(treatment)
        out += f'edge[source "{treatment}" target "{outcome}"]'
        out += " ".join(edge(name, treatment) for name in common_causes)
    out += " ".join(edge(name, outcome) for name in common_causes)
    return out + "]"
'''

new_graph = '''def gml_graph_of_common_causes(
    treatments: list[str],
    outcome: str,
    common_causes: list[str],
    instruments: list[str] | None = None,
) -> str:
    """The GML graph of the port, the one of `create_gml_graph`."""

    def node(name: str) -> str:
        return f'node[ id "{name}" label "{name}"]'

    def edge(source: str, target: str) -> str:
        return f'edge[ source "{source}" target "{target}"]'

    if instruments is None:
        instruments = []
    out = "graph[directed 1" + node(outcome)
    out += " ".join(node(name) for name in instruments)
    out += " ".join(node(name) for name in common_causes)
    for treatment in treatments:
        out += node(treatment)
        out += f'edge[source "{treatment}" target "{outcome}"]'
        out += " ".join(edge(name, treatment) for name in common_causes)
        out += " ".join(edge(name, treatment) for name in instruments)
    out += " ".join(edge(name, outcome) for name in common_causes)
    return out + "]"
'''

assert s.count(old_graph) == 1
s = s.replace(old_graph, new_graph)

open(p, "w", encoding="utf-8", newline="").write(s)
print("patched")
