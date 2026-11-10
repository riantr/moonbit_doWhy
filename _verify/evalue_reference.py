"""Print the numbers of the upstream E-value analyzer.

`tests/causal_refuters/test_add_unobserved_common_cause.py` drives the analyzer
of the upstream with a few numbers and compares its results with the examples of
the R package `EValue`:

  * `_evalue_OLS(0.293, 0.196, 17.405)`,
  * `_evalue_MD(0.5, 0.25)`,
  * `_evalue_OR(0.86, 0.75, 0.99, rare=False)`,
  * `_evalue_RR(0.8, 0.71, 0.91)`,
  * `_observed_covariate_e_value(2, 4)`, `(4, 2)` and `(0.8, 0.9)`.

Those are the numbers the port reproduces.  The analyzer of the upstream needs an
estimate to be built, so this script builds one on a frame of the same shape as
the fixture of the upstream: five common causes, a coefficient of ten and a
binary treatment.  The frame is built by hand, because the
`dowhy.datasets.linear_dataset` of the upstream converts its binary treatment
with the `np.vectorize(convert_to_binary)` of that branch, which numpy 2.5.1
refuses with `ValueError: setting an array element with a sequence`.

Run: python _verify/evalue_reference.py
"""

import sys

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

import numpy as np
import pandas as pd

from dowhy import CausalModel
from dowhy.causal_refuters.evalue_sensitivity_analyzer import EValueSensitivityAnalyzer

CAUSES = ["W0", "W1", "W2", "W3", "W4"]
BETA = 10.0
NUM_SAMPLES = 1000


def gml_graph():
    """The graph of the fixture: every common cause acts on the treatment and on
    the outcome, and the treatment acts on the outcome."""
    parts = [
        'graph[directed 1node[ id "y" label "y"]',
        'node[ id "v0" label "v0"]',
    ]
    for name in CAUSES:
        parts.append('node[ id "{}" label "{}"]'.format(name, name))
    parts.append('edge[source "v0" target "y"]')
    for name in CAUSES:
        parts.append('edge[ source "{}" target "v0"]'.format(name))
        parts.append('edge[ source "{}" target "y"]'.format(name))
    parts.append("]")
    return "".join(parts)


def build_frame(seed=42):
    """The fixture of the upstream, built with the generator of numpy."""
    rng = np.random.default_rng(seed)
    rows = NUM_SAMPLES
    means = rng.uniform(-1, 1, len(CAUSES))
    range_c = 0.5 + np.max(np.absolute(BETA)) * 0.5
    causes = rng.normal(0, 1, (rows, len(CAUSES))) + means
    c1 = rng.uniform(0, range_c, len(CAUSES))
    c2 = rng.uniform(0, range_c, len(CAUSES))
    latent = rng.normal(0, 1, rows) + causes @ c1
    treatment = (rng.random(rows) < 1.0 / (1.0 + np.exp(-latent))).astype(float)
    outcome = BETA * treatment + causes @ c2 + rng.normal(0, 0.01, rows)
    frame = pd.DataFrame(causes, columns=CAUSES)
    frame["v0"] = treatment
    frame["y"] = outcome
    return frame


def show(title, stats):
    print(title)
    for key in (
        "converted_estimate",
        "converted_lower_ci",
        "converted_upper_ci",
        "evalue_estimate",
        "evalue_lower_ci",
        "evalue_upper_ci",
    ):
        value = stats[key]
        if value is None:
            print("  {:22s} None".format(key))
        else:
            print("  {:22s} {!r}".format(key, float(value)))


def main():
    frame = build_frame()
    model = CausalModel(
        data=frame,
        treatment=["v0"],
        outcome="y",
        graph=gml_graph(),
        test_significance=None,
    )
    estimand = model.identify_effect(proceed_when_unidentifiable=True)
    estimate = model.estimate_effect(estimand, method_name="backdoor.linear_regression")

    analyzer = EValueSensitivityAnalyzer(
        estimate=estimate,
        estimand=estimand,
        data=frame,
        treatment_name="v0",
        outcome_name="y",
    )

    print("=" * 70)
    print("the fixture")
    print("=" * 70)
    print("the standard deviation of the outcome:", float(np.std(frame["y"])))
    print("the estimate:", float(estimate.value))
    print("the standard error:", float(estimate.get_standard_error()[0]))
    print(
        "the treatment and the control value of the estimator:",
        estimate.estimator._treatment_value,
        estimate.estimator._control_value,
    )

    print()
    print("=" * 70)
    print("the numbers of the upstream test file")
    print("=" * 70)
    show("_evalue_OLS(0.293, 0.196, 17.405)", analyzer._evalue_OLS(0.293, 0.196, 17.405))
    show("_evalue_MD(0.5, 0.25)", analyzer._evalue_MD(0.5, 0.25))
    show(
        "_evalue_OR(0.86, 0.75, 0.99, rare=False)",
        analyzer._evalue_OR(0.86, 0.75, 0.99, rare=False),
    )
    show("_evalue_RR(0.8, 0.71, 0.91)", analyzer._evalue_RR(0.8, 0.71, 0.91))
    print()
    print(
        "_observed_covariate_e_value(2, 4)   ->",
        float(analyzer._observed_covariate_e_value(2, 4)),
    )
    print(
        "_observed_covariate_e_value(4, 2)   ->",
        float(analyzer._observed_covariate_e_value(4, 2)),
    )
    print(
        "_observed_covariate_e_value(0.8, 0.9)->",
        float(analyzer._observed_covariate_e_value(0.8, 0.9)),
    )

    print()
    print("=" * 70)
    print("the E-value of the estimate of the fixture")
    print("=" * 70)
    analyzer.check_sensitivity(frame, plot=False)
    show("the statistics of the analyzer", analyzer.stats)
    print()
    print("the benchmarking results of the analyzer:")
    print(analyzer.benchmarking_results)


main()
