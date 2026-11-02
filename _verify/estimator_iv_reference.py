"""Runs the upstream instrumental variable estimator on the rows of the port.

The upstream test file `tests/causal_estimators/test_instrumental_variable_estimator.py`
holds sixteen configurations.  The four of them that the estimators of the port
can reach are the ones with one treatment and one instrument: with no or with
one common cause, and with a continuous or with a binary treatment.

The upstream cannot run the configurations with a binary treatment here: its
own generator of the data sets calls `numpy.vectorize` on a function that
returns an array, which numpy 2 refuses, so the data set is never built.  The
script therefore measures the configurations with a continuous treatment, and
it reports the failure of the binary ones.

The rows of the port are replicated by `_verify/port_linear_dataset.py`, so
the upstream runs on the same rows and the two numbers can be compared
directly.

Usage:
    python _verify/estimator_iv_reference.py
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from port_linear_dataset import binary_treatment_dataset  # noqa: E402

UPSTREAM_ROOT = os.environ.get(
    "DOWHY_UPSTREAM_ROOT",
    r"D:\src\MiniMax\git\dowhy\dowhy-0.14",
)
if UPSTREAM_ROOT not in sys.path:
    sys.path.insert(0, UPSTREAM_ROOT)

import pandas as pd  # noqa: E402

from dowhy import EstimandType, identify_effect_auto  # noqa: E402
from dowhy.causal_estimators.instrumental_variable_estimator import (  # noqa: E402
    InstrumentalVariableEstimator,
)
from dowhy.graph import build_graph_from_str  # noqa: E402

SEED = 44
NUM_ROWS = 100000
TOLERANCE = 0.4


def measure(data: dict, name: str) -> None:
    truth = data["ate"]
    frame = pd.DataFrame(data["columns"])
    estimand = identify_effect_auto(
        build_graph_from_str(data["gml_graph"]),
        observed_nodes=list(frame.columns),
        action_nodes=data["treatment_names"],
        outcome_nodes=data["outcome_name"],
        estimand_type=EstimandType.NONPARAMETRIC_ATE,
    )
    estimand.set_identifier_method("iv")
    estimator = InstrumentalVariableEstimator(identified_estimand=estimand)
    estimator.fit(frame, effect_modifier_names=data["effect_modifier_names"])
    estimate = estimator.estimate_effect(
        frame,
        control_value=0,
        treatment_value=1,
        test_significance=False,
        evaluate_effect_strength=False,
        confidence_intervals=False,
        target_units="ate",
    )
    error = abs(estimate.value - truth)
    share = error / abs(truth)
    verdict = "ok" if share < TOLERANCE else "OVER"
    print(
        "  %s: %r truth=%r error=%r share=%.4f tolerance=%s %s"
        % (name, estimate.value, truth, error, share, TOLERANCE, verdict)
    )


def main() -> None:
    for num_common_causes in (0, 1):
        for treatment_is_binary in (False, True):
            print()
            print(
                "iv %d common cause(s), binary treatment %r"
                % (num_common_causes, treatment_is_binary)
            )
            data = binary_treatment_dataset(
                SEED,
                NUM_ROWS,
                num_common_causes=num_common_causes,
                num_instruments=1,
                treatment_is_binary=treatment_is_binary,
            )
            try:
                measure(data, "iv")
            except Exception as error:  # noqa: BLE001
                print("  iv: failed: %s: %s" % (type(error).__name__, error))


if __name__ == "__main__":
    main()
