"""Replicates the generator of `src/datasets/datasets.mbt` in Python.

The port draws its synthetic data sets with a hand written xorshift64
generator, so that the rows do not depend on the random number implementation
of the toolchain.  This module replicates that generator and the
`dowhy.datasets.linear_dataset` port of `src/datasets/datasets.mbt` exactly, so
that the rows the port builds can be handed to the upstream code.

Only the configuration the tests of the two stage regression estimator use is
replicated: one frontdoor mediator, one continuous treatment, one continuous
outcome and no common cause, no instrument and no effect modifier.  The draw
order of the port is the one of the Python fixture: the treatment first, then
the coefficients of the frontdoor mediators, then the noise of the mediators,
then the outcome and finally the two counterfactual outcomes the true average
treatment effect is the mean of.

Usage:
    python -c "import sys; sys.path.insert(0, '_verify'); \\
        from port_linear_dataset import frontdoor_dataset; print(frontdoor_dataset(42, 2000)['ate'])"
"""

from __future__ import annotations

import math

MASK64 = (1 << 64) - 1
GOLDEN = 0x9E3779B97F4A7C15
TWO_POW_53 = 9007199254740992.0


class Rng:
    """The `Rng` of `src/datasets/datasets.mbt`."""

    def __init__(self, seed: int) -> None:
        state = GOLDEN ^ (seed & MASK64)
        for _ in range(8):
            state = self.step(state)
        if state == 0:
            state = GOLDEN
        self.state = state

    @staticmethod
    def step(state: int) -> int:
        x = state & MASK64
        x ^= (x << 13) & MASK64
        x ^= x >> 7
        x ^= (x << 17) & MASK64
        return x

    def next_u64(self) -> int:
        self.state = self.step(self.state)
        return self.state

    def uniform01(self) -> float:
        bits = self.next_u64() >> 11
        return bits * (1.0 / TWO_POW_53)

    def uniform(self, low: float, high: float) -> float:
        return low + (high - low) * self.uniform01()

    def normal(self) -> float:
        u1 = self.uniform01()
        u2 = self.uniform01()
        safe_u1 = u1 if u1 > 0.0 else 2.0 / TWO_POW_53
        variance = -2.0 * math.log(safe_u1)
        radius = math.sqrt(variance)
        return radius * math.cos(2.0 * math.pi * u2)


def frontdoor_dataset(
    seed: int,
    num_rows: int,
    beta: float = 10.0,
    num_treatments: int = 1,
    num_frontdoor_variables: int = 1,
) -> dict:
    """The data set of the port with one frontdoor mediator.

    The result holds the columns of the frame, the true average treatment
    effect, the names of the columns and the GML graph of the data set, the
    four things the port's `Dataset` holds.
    """
    rng = Rng(seed)
    rows = num_rows if num_rows > 0 else 0
    beta_abs = abs(beta)
    range_cfd = beta_abs * 0.5

    # ---- the treatment ----------------------------------------------------
    treatment = [[rng.normal() for _ in range(num_treatments)] for _ in range(rows)]

    # ---- the frontdoor mediators -----------------------------------------
    cfd1 = [
        [rng.uniform(0.0, range_cfd) for _ in range(num_frontdoor_variables)]
        for _ in range(num_treatments)
    ]
    cfd2 = [rng.uniform(0.0, range_cfd) for _ in range(num_frontdoor_variables)]
    fd_noise = [
        [rng.normal() for _ in range(num_frontdoor_variables)] for _ in range(rows)
    ]
    fd = []
    for i in range(rows):
        row = []
        for f in range(num_frontdoor_variables):
            value = fd_noise[i][f]
            for k in range(num_treatments):
                value += treatment[i][k] * cfd1[k][f]
            row.append(value)
        fd.append(row)

    # ---- the outcome ------------------------------------------------------
    outcome = []
    for i in range(rows):
        value = rng.normal() * 0.01
        for f in range(num_frontdoor_variables):
            value += fd[i][f] * cfd2[f]
        outcome.append(value)

    # ---- the true average treatment effect ---------------------------------
    def outcome_at(value: float) -> list[float]:
        values = []
        for i in range(rows):
            total = rng.normal() * 0.01
            for f in range(num_frontdoor_variables):
                mediator = fd_noise[i][f]
                for k in range(num_treatments):
                    mediator += value * cfd1[k][f]
                total += mediator * cfd2[f]
            values.append(total)
        return values

    treated = outcome_at(1.0)
    control = outcome_at(0.0)
    ate = 0.0
    if rows > 0:
        ate = sum(treated[i] - control[i] for i in range(rows)) / rows

    # ---- the frame and the graph ------------------------------------------
    frontdoor_names = [f"FD{f}" for f in range(num_frontdoor_variables)]
    treatment_names = [f"v{k}" for k in range(num_treatments)]
    columns = {
        name: [fd[i][f] for i in range(rows)]
        for f, name in enumerate(frontdoor_names)
    }
    for k, name in enumerate(treatment_names):
        columns[name] = [treatment[i][k] for i in range(rows)]
    columns["y"] = outcome

    return {
        "columns": columns,
        "column_order": frontdoor_names + treatment_names + ["y"],
        "ate": ate,
        "treatment_names": treatment_names,
        "outcome_name": "y",
        "frontdoor_names": frontdoor_names,
        "gml_graph": gml_graph(treatment_names, "y", frontdoor_names),
        "cfd1": cfd1,
        "cfd2": cfd2,
    }


def gml_graph(
    treatments: list[str],
    outcome: str,
    frontdoor_variables: list[str],
) -> str:
    """The GML graph of the port, the one of `create_gml_graph`."""

    def node(name: str) -> str:
        return f'node[ id "{name}" label "{name}"]'

    def edge(source: str, target: str) -> str:
        return f'edge[ source "{source}" target "{target}"]'

    out = "graph[directed 1" + node(outcome)
    out += " ".join(node(name) for name in frontdoor_variables)
    for treatment in treatments:
        out += node(treatment)
        if not frontdoor_variables:
            out += f'edge[source "{treatment}" target "{outcome}"]'
        out += " ".join(edge(treatment, name) for name in frontdoor_variables)
    out += " ".join(edge(name, outcome) for name in frontdoor_variables)
    return out + "]"


def sigmoid(value: float) -> float:
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
    num_instruments: int = 0,
    outcome_is_binary: bool = False,
    treatment_is_binary: bool = True,
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

    The upstream test file of the instrumental variable estimator also holds
    configurations with a continuous treatment.  A continuous treatment is the
    linear predictor itself and the draw of the Bernoulli is not made at all,
    so every draw after the treatment moves.
    """
    rng = Rng(seed)
    rows = num_rows if num_rows > 0 else 0
    beta_abs = abs(beta)
    range_c = 0.5 + beta_abs * 0.5
    range_cz = 1.0 + beta_abs

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

    # ---- the instruments --------------------------------------------------
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
        if treatment_is_binary:
            treatment.append([bernoulli(rng, sigmoid(value))])
        else:
            # A continuous treatment is the linear predictor itself, and the
            # draw of the Bernoulli is not made at all.
            treatment.append([value])

    # ---- the outcome ------------------------------------------------------
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

    # ---- the true average treatment effect ---------------------------------
    def outcome_at(value: float) -> list[float]:
        values = []
        for i in range(rows):
            total = rng.normal() * 0.01
            total += value * beta * 1.0
            for j in range(num_common_causes):
                total += w[i][j] * c2[j]
            values.append(discretise(total))
        return values

    treated = outcome_at(1.0)
    control = outcome_at(0.0)
    ate = 0.0
    if rows > 0:
        ate = sum(treated[i] - control[i] for i in range(rows)) / rows

    # ---- the frame and the graph ------------------------------------------
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


def gml_graph_of_common_causes(
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


if __name__ == "__main__":
    data = frontdoor_dataset(42, 2000)
    print("columns:", data["column_order"])
    print("ate:", repr(data["ate"]))
    print("gml:", data["gml_graph"])
    for name in data["column_order"]:
        values = data["columns"][name]
        print(f"  {name}: first={values[0]!r} third={values[2]!r}")
