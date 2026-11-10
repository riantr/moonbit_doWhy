"""Print the default strengths of the confounder of the upstream.

`dowhy.causal_refuters.add_unobserved_common_cause` infers the strength of the
simulated confounder on the treatment and on the outcome from the observed
common causes, when the caller does not give one:

  * `_infer_default_kappa_t` and `_infer_default_kappa_y` fit a logistic
    regression of the column on the standardised common causes and count the
    share of the predictions that flip when one common cause is set to zero, for
    the `binary_flip` effect,
  * they take the correlation of every common cause with the column, scaled with
    the standard deviation of the column, for the `linear` effect,
  * they scale the range with the fraction of the strength the caller gives and
    return ten values of it.

The rows of this script are the rows of the port: the fixture is the data set of
`src/datasets/datasets.mbt` with five common causes, a binary treatment and a
continuous outcome, and it is drawn by the replication of the generator of the
port in `port_linear_dataset.py`.  The upstream is then run on those rows, so
the numbers of the upstream and the numbers of the port are the numbers of one
data set.

The `linear` branch of the upstream is broken: it reads the standard deviation
of the column with `np.std(t)[0]`, and the standard deviation of a column is a
number and not an array, so the indexing raises an `IndexError`.  The script
reports that instead of hiding it.

The `binary_flip` branch of the upstream needs a binary column: it fits a
classifier on the column, and a continuous column is refused with
`ValueError: Unknown label type: continuous`.  The script reports that too.

Run: python _verify/kappa_inference_reference.py
"""

import sys

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")
sys.path.insert(0, r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\_verify")

import numpy as np
import pandas as pd

from dowhy import CausalModel
from dowhy.causal_refuters.add_unobserved_common_cause import (
    _infer_default_kappa_t,
    _infer_default_kappa_y,
)

from port_linear_dataset import binary_treatment_dataset

SEED = 42
ROWS = 1000
NUM_CAUSES = 5
BETA = 10.0


def build_frame():
    """The rows of the port: five common causes, a binary treatment."""
    data = binary_treatment_dataset(
        SEED,
        ROWS,
        num_common_causes=NUM_CAUSES,
        beta=BETA,
        num_instruments=0,
        outcome_is_binary=False,
        treatment_is_binary=True,
    )
    frame = pd.DataFrame(
        {name: data["columns"][name] for name in data["column_order"]}
    )
    return frame, data


def show(title, values):
    print(title)
    print("  ", np.asarray(values).tolist())


def attempt(title, call):
    try:
        show(title, call())
    except Exception as error:  # noqa: BLE001 - the upstream raises several kinds
        print(title)
        print("   the upstream raises {}: {}".format(type(error).__name__, error))


def intended_linear_strengths(frame, estimand, column_name, frac=1.0):
    """The numbers the `linear` branch of the upstream means to compute.

    The branch reads the standard deviation of the column with `np.std(t)[0]`,
    and the standard deviation of a column is a number and not an array, so the
    branch raises an `IndexError` before it returns anything.  This is the
    branch with the indexing removed: the correlation of every common cause
    with the column, scaled with the standard deviation of the column.
    """
    from sklearn.preprocessing import StandardScaler

    causes = frame[estimand.get_adjustment_set()]
    causes = StandardScaler().fit_transform(causes)
    column = frame[column_name]
    correlations = np.corrcoef(causes, column, rowvar=False)[-1, :-1]
    standard_deviation = np.std(column)
    coefficients = correlations * standard_deviation
    smallest = frac * min(coefficients)
    largest = frac * max(coefficients)
    step = (largest - smallest) / 10
    if np.equal(largest, smallest):
        return largest
    return np.arange(smallest, largest, step)


def main():
    frame, data = build_frame()
    model = CausalModel(
        data=frame,
        treatment=data["treatment_names"],
        outcome=data["outcome_name"],
        graph=data["gml_graph"],
        test_significance=None,
    )
    estimand = model.identify_effect(proceed_when_unidentifiable=True)

    print("=" * 70)
    print("the default strengths of the upstream, on the rows of the port")
    print("=" * 70)
    print("the adjustment set:", estimand.get_adjustment_set())
    print("the treatment:", data["treatment_names"], "the outcome:", data["outcome_name"])
    attempt(
        "kappa_t with the binary_flip effect:",
        lambda: _infer_default_kappa_t(frame, estimand, data["treatment_names"], "binary_flip", 1.0),
    )
    attempt(
        "kappa_y with the binary_flip effect:",
        lambda: _infer_default_kappa_y(frame, estimand, [data["outcome_name"]], "binary_flip", 1.0),
    )
    attempt(
        "kappa_t with the linear effect:",
        lambda: _infer_default_kappa_t(frame, estimand, data["treatment_names"], "linear", 1.0),
    )
    attempt(
        "kappa_y with the linear effect:",
        lambda: _infer_default_kappa_y(frame, estimand, [data["outcome_name"]], "linear", 1.0),
    )

    print()
    print("the same with a tenth of the strength")
    attempt(
        "kappa_t:",
        lambda: _infer_default_kappa_t(frame, estimand, data["treatment_names"], "binary_flip", 0.1),
    )
    attempt(
        "kappa_y:",
        lambda: _infer_default_kappa_y(frame, estimand, [data["outcome_name"]], "binary_flip", 0.1),
    )

    print()
    print("the numbers the linear branch of the upstream means to compute")
    show(
        "kappa_t with the linear effect:",
        intended_linear_strengths(frame, estimand, data["treatment_names"][0]),
    )
    show(
        "kappa_y with the linear effect:",
        intended_linear_strengths(frame, estimand, data["outcome_name"]),
    )

    print()
    print("one common cause: the range of the upstream is a single number")
    one = binary_treatment_dataset(
        SEED,
        ROWS,
        num_common_causes=1,
        beta=BETA,
        num_instruments=0,
        outcome_is_binary=False,
        treatment_is_binary=True,
    )
    one_frame = pd.DataFrame(
        {name: one["columns"][name] for name in one["column_order"]}
    )
    one_model = CausalModel(
        data=one_frame,
        treatment=one["treatment_names"],
        outcome=one["outcome_name"],
        graph=one["gml_graph"],
        test_significance=None,
    )
    one_estimand = one_model.identify_effect(proceed_when_unidentifiable=True)
    print("the adjustment set:", one_estimand.get_adjustment_set())
    attempt(
        "kappa_t with the binary_flip effect:",
        lambda: _infer_default_kappa_t(
            one_frame, one_estimand, one["treatment_names"], "binary_flip", 1.0
        ),
    )
    show(
        "kappa_t with the linear effect:",
        intended_linear_strengths(one_frame, one_estimand, one["treatment_names"][0]),
    )


main()
