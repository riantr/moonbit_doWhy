"""Extend `_verify/port_linear_dataset.py` with the configuration of the
upstream estimator test suite.

The upstream estimator test files run on a data set with one or two common
causes, no instrument, no effect modifier, no frontdoor mediator, one binary
treatment and a continuous outcome.  The function `binary_treatment_dataset`
replicates the generator of the port for that configuration, so that the
upstream can be run on the very rows the port works on.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "_verify" / "port_linear_dataset.py"

ANCHOR = """if __name__ == "__main__":
    data = frontdoor_dataset(42, 2000)"""

NEW = '''def sigmoid(value: float) -> float:
    """The `sigmoid` of `src/utils`, the one of `src/datasets`."""

    if value >= 0.0:
        return 1.0 / (1.0 + math.exp(-value))
    exponential = math.exp(value)
    return exponential / (1.0 + exponential)


def bernoulli(rng: "Rng", probability: float) -> float:
    """The Bernoulli draw of `src/datasets`, as a zero or a one."""

    return 1.0 if rng.uniform01() < probability else 0.0


def binary_treatment_dataset(
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

    # ---- the common causes ------------------------------------------------
    means = [rng.uniform(-1.0, 1.0) for _ in range(num_common_causes)]
    w = [
        [means[j] + rng.normal() for j in range(num_common_causes)]
        for _ in range(rows)
    ]
    c1 = [
        [rng.uniform(0.0, range_c)]
        for _ in range(num_common_causes)
    ]
    c2 = [rng.uniform(0.0, range_c) for _ in range(num_common_causes)]

    # ---- the treatment ----------------------------------------------------
    treatment = []
    for i in range(rows):
        value = rng.normal()
        for j in range(num_common_causes):
            value += w[i][j] * c1[j][0]
        treatment.append([bernoulli(rng, sigmoid(value))])

    # ---- the outcome ------------------------------------------------------
    outcome = []
    for i in range(rows):
        value = rng.normal() * 0.01
        value += treatment[i][0] * beta * 1.0
        for j in range(num_common_causes):
            value += w[i][j] * c2[j]
        outcome.append(value)

    # ---- the true average treatment effect ---------------------------------
    def outcome_at(value: float) -> list[float]:
        values = []
        for i in range(rows):
            total = rng.normal() * 0.01
            total += value * beta * 1.0
            for j in range(num_common_causes):
                total += w[i][j] * c2[j]
            values.append(total)
        return values

    treated = outcome_at(1.0)
    control = outcome_at(0.0)
    ate = 0.0
    if rows > 0:
        ate = sum(treated[i] - control[i] for i in range(rows)) / rows

    # ---- the frame and the graph ------------------------------------------
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


def gml_graph_of_common_causes(
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


if __name__ == "__main__":
    data = frontdoor_dataset(42, 2000)'''


def main() -> None:
    text = TARGET.read_text(encoding="utf-8")
    if "def binary_treatment_dataset" in text:
        raise SystemExit("the function is already there")
    if text.count(ANCHOR) != 1:
        raise SystemExit("the anchor is not unique")
    TARGET.write_text(text.replace(ANCHOR, NEW), encoding="utf-8", newline="")
    print("patched", TARGET)


if __name__ == "__main__":
    main()
