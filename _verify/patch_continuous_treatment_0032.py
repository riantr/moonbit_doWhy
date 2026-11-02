"""Adds a continuous treatment to the replication of the port's data sets.

The upstream test file of the instrumental variable estimator holds
configurations with a continuous treatment, and the replication of the port
needs to draw the same rows for them.  A continuous treatment is the linear
predictor itself, and the Bernoulli draw of a binary treatment is not made at
all, so every draw after the treatment moves.
"""

import io
import os

PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "port_linear_dataset.py",
)

with io.open(PATH, encoding="utf-8", newline="") as handle:
    source = handle.read()

OLD_SIGNATURE = """    num_instruments: int = 0,
    outcome_is_binary: bool = False,
) -> dict:"""

NEW_SIGNATURE = """    num_instruments: int = 0,
    outcome_is_binary: bool = False,
    treatment_is_binary: bool = True,
) -> dict:"""

OLD_TREATMENT = """        treatment.append([bernoulli(rng, sigmoid(value))])"""

NEW_TREATMENT = """        if treatment_is_binary:
            treatment.append([bernoulli(rng, sigmoid(value))])
        else:
            # A continuous treatment is the linear predictor itself, and the
            # draw of the Bernoulli is not made at all.
            treatment.append([value])"""

OLD_DOC = """    finally the two counterfactual outcomes the true average treatment effect
    is the mean of.
    \"\"\""""

NEW_DOC = """    finally the two counterfactual outcomes the true average treatment effect
    is the mean of.

    The upstream test file of the instrumental variable estimator also holds
    configurations with a continuous treatment.  A continuous treatment is the
    linear predictor itself and the draw of the Bernoulli is not made at all,
    so every draw after the treatment moves.
    \"\"\""""

for old, new in (
    (OLD_SIGNATURE, NEW_SIGNATURE),
    (OLD_TREATMENT, NEW_TREATMENT),
    (OLD_DOC, NEW_DOC),
):
    count = source.count(old)
    if count != 1:
        raise SystemExit(
            "the anchor is present %d times:\n%s" % (count, old[:200])
        )
    source = source.replace(old, new)

with io.open(PATH, "w", encoding="utf-8", newline="") as handle:
    handle.write(source)

print("patched", PATH)
