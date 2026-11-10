"""The numbers of the data generating processes of the upstream.

The upstream has no test file for its data generating processes, so the expected
numbers of the port are the numbers of the upstream, which this script prints.

The processes of the upstream draw their randomness from the global generator of
numpy, which their constructor seeds with the seed of the process, so the
numbers of the script are the numbers of the upstream for that seed.

Usage:

    python _verify/dgp_reference.py
"""

from __future__ import annotations

import sys

import numpy as np

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

from dowhy.utils.dgps.cubic_dgp import CubicDataGeneratingProcess
from dowhy.utils.dgps.linear_dgp import LinearDataGeneratingProcess
from dowhy.utils.dgps.quadratic_dgp import QuadraticDataGeneratingProcess

TREATMENT = ["t1"]
OUTCOME = ["y"]
CONFOUNDER = ["w1", "w2"]
EFFECT_MODIFIER = ["x1"]


def show_weights(weights) -> None:
    """Print the weights of a process.

    The linear process keeps the weights in a dictionary. The quadratic and the
    cubic process replace it with a list of the dictionaries of the powers, and
    every entry of that list is the same dictionary, because the upstream keeps
    a reference to one dictionary and rewrites it.
    """
    groups = [weights] if isinstance(weights, dict) else list(weights)
    for index, group in enumerate(groups):
        if isinstance(weights, dict):
            print("   the weights:")
        else:
            print("   the weights of the power %d:" % index)
        for key in (
            "confounder=>treatment",
            "confounder=>outcome",
            "effect_modifier=>outcome",
            "treatment=>outcome",
        ):
            print("      %s:" % key)
            print("         ", np.array(group[key]).tolist())


def show_bias(bias) -> None:
    groups = [bias] if isinstance(bias, dict) else list(bias)
    for index, group in enumerate(groups):
        if isinstance(bias, dict):
            print("   the biases:")
        else:
            print("   the biases of the power %d:" % index)
        for key in ("confounder=>treatment", "confounder=>outcome"):
            print("      %s:" % key)
            print("         ", [float(v) for v in group[key]])


def show(name: str, process, sample_size: int) -> None:
    print("=" * 70)
    print("%s with the seed %s" % (name, process.seed))
    print("=" * 70)
    data = process.generate_data(sample_size)
    print("the columns of the data:", list(data.columns))
    print("the shape of the data:", data.values.shape)
    for column in data.columns:
        print("   the column %s:" % column)
        print("      ", [float(v) for v in data[column].values[:5]])
    print("the value of the effect:", [float(v) for v in process.true_value])
    show_weights(process.weights)
    show_bias(process.bias)
    print()


def show_deterministic() -> None:
    """Print the numbers of the deterministic conversion of the treatment.

    The upstream converts the treatment of a continuous process with the
    percentile of the process, which is the text `NA` for such a process, so
    the conversion only works for a binary process. The treatment of the
    continuous process and the treatment of the binary process are the same,
    because the numbers of the continuous treatment are drawn before the
    conversion.
    """
    print("=" * 70)
    print("the deterministic conversion of the treatment")
    print("=" * 70)
    continuous = LinearDataGeneratingProcess(
        treatment=TREATMENT,
        outcome=OUTCOME,
        confounder=CONFOUNDER,
        effect_modifier=EFFECT_MODIFIER,
        seed=42,
        treatment_is_binary=False,
    )
    treatment = continuous.generate_data(10)["t1"].values
    binary = LinearDataGeneratingProcess(
        treatment=TREATMENT,
        outcome=OUTCOME,
        confounder=CONFOUNDER,
        effect_modifier=EFFECT_MODIFIER,
        seed=42,
        treatment_is_binary=True,
    )
    print("the treatment:", [float(v) for v in treatment])
    print("the percentile of the process:", binary.percentile)
    print(
        "the percentile of the treatment:",
        float(np.percentile(treatment, binary.percentile)),
    )
    print(
        "the deterministic conversion:",
        [float(v) for v in binary.convert_to_binary(treatment, deterministic=True)],
    )
    print()


def main() -> None:
    for name, kind in (
        ("the linear data generating process", LinearDataGeneratingProcess),
        ("the quadratic data generating process", QuadraticDataGeneratingProcess),
        ("the cubic data generating process", CubicDataGeneratingProcess),
    ):
        process = kind(
            treatment=TREATMENT,
            outcome=OUTCOME,
            confounder=CONFOUNDER,
            effect_modifier=EFFECT_MODIFIER,
            seed=42,
            treatment_is_binary=False,
        )
        show(name, process, 10)

    # The binary treatment of the upstream goes through the conversion of the
    # treatment, which draws a Bernoulli for every row of the treatment and a
    # second Bernoulli for every row that it flips.
    process = LinearDataGeneratingProcess(
        treatment=TREATMENT,
        outcome=OUTCOME,
        confounder=CONFOUNDER,
        effect_modifier=EFFECT_MODIFIER,
        seed=42,
        treatment_is_binary=True,
    )
    show("the linear data generating process with a binary treatment", process, 10)
    show_deterministic()


if __name__ == "__main__":
    main()
