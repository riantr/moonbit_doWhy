"""Print the numbers of the upstream linear sensitivity analyzer.

`tests/causal_refuters/test_add_unobserved_common_cause.py` drives the analyzer
through `refute_estimate(method_name="add_unobserved_common_cause",
simulation_method="linear-partial-R2", benchmark_common_causes=["W3"],
effect_fraction_on_treatment=[1, 2, 3])` and asserts

  * every partial R2 of the benchmarking results is between 0 and 1,
  * `stats["r2yt_w"]` and `stats["robustness_value"]` are between 0 and 1,
  * the bias adjusted estimates lie on the far side of the estimate from zero, in
    the direction `confounder_increases_estimate` names,
  * `compute_bias_adjusted` reports the two sets of partial R2 it is given, and
    the adjusted estimate of the first set is farther from the original estimate
    than the adjusted estimate of the second.

None of those is an exact number, so this script is the evidence that the
assertions hold on the upstream for a fixture of the same shape, and it prints
the statistics the port reproduces in kind.

The upstream fixture cannot be generated through `dowhy.datasets.linear_dataset`
here: that function defaults to `treatment_is_binary=True`, and the
`np.vectorize(convert_to_binary)` of that branch builds a one element array per
row, which numpy 2.5.1 refuses with `ValueError: setting an array element with
a sequence`. The frame is therefore built by hand with the shape of the fixture
of the port: six common causes, a coefficient of ten, a treatment noise of ten
and an outcome noise of one, and a treatment that is the draw of a Bernoulli
whose probability is the logistic of the treatment of the confounder.

Run: python _verify/linear_sensitivity_reference.py
"""

import sys

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

import numpy as np
import pandas as pd

from dowhy import CausalModel

CAUSES = ["W0", "W1", "W2", "W3", "W4", "W5"]
BETA = 10.0
NUM_SAMPLES = 500


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
    """The fixture of the port, built with the generator of the upstream."""
    rng = np.random.default_rng(seed)
    rows = NUM_SAMPLES
    # The upstream draws the means of the common causes from the uniform
    # interval of minus one and one, and the coefficients of their effects from
    # the uniform interval of zero and `0.5 + max|beta| * 0.5`.
    means = rng.uniform(-1, 1, len(CAUSES))
    range_c = 0.5 + np.max(np.absolute(BETA)) * 0.5
    causes = rng.normal(0, 1, (rows, len(CAUSES))) + means
    c1 = rng.uniform(0, range_c, len(CAUSES))
    c2 = rng.uniform(0, range_c, len(CAUSES))
    latent = rng.normal(0, 10, rows) + causes @ c1
    treatment = (rng.random(rows) < 1.0 / (1.0 + np.exp(-latent))).astype(float)
    outcome = BETA * treatment + causes @ c2 + rng.normal(0, 1, rows)
    frame = pd.DataFrame(causes, columns=CAUSES)
    frame["v0"] = treatment
    frame["y"] = outcome
    return frame


def main():
    frame = build_frame()
    print("=" * 70)
    print("the fixture, built by hand with the shape of the fixture of the port")
    print("=" * 70)
    print("columns:", list(frame.columns))
    print("shape  :", frame.shape)
    print("treatment mean:", float(frame["v0"].mean()))

    model = CausalModel(
        data=frame,
        treatment=["v0"],
        outcome="y",
        graph=gml_graph(),
        test_significance=None,
    )
    estimand = model.identify_effect(proceed_when_unidentifiable=True)
    estimate = model.estimate_effect(estimand, method_name="backdoor.linear_regression")
    print()
    print("ate:", estimate.value)
    print("observed common causes:", list(estimate.estimator._observed_common_causes.columns))

    refute = model.refute_estimate(
        estimand,
        estimate,
        method_name="add_unobserved_common_cause",
        simulation_method="linear-partial-R2",
        benchmark_common_causes=["W3"],
        effect_fraction_on_treatment=[1, 2, 3],
        plot_estimate=False,
    )
    print()
    print("=" * 70)
    print("what the analyzer reports")
    print("=" * 70)
    print("confounder_increases_estimate:", refute.confounder_increases_estimate)
    print("stats:")
    for key, value in refute.stats.items():
        print("  {:22s} {}".format(key, value))
    print("benchmarking_results:")
    for key, value in refute.benchmarking_results.items():
        print("  {:24s} {}".format(key, np.asarray(value).tolist()))

    print()
    print("=" * 70)
    print("the assertions of the upstream test file, on this run")
    print("=" * 70)
    results = refute.benchmarking_results
    print(
        "  r2tu_w in [0, 1]     ->",
        all(0.0 <= float(v) <= 1.0 for v in np.atleast_1d(results["r2tu_w"])),
    )
    print(
        "  r2yu_tw in [0, 1]    ->",
        all(0.0 <= float(v) <= 1.0 for v in np.atleast_1d(results["r2yu_tw"])),
    )
    print("  r2yt_w in [0, 1]     ->", 0.0 <= float(refute.stats["r2yt_w"]) <= 1.0)
    print(
        "  robustness in [0, 1] ->",
        0.0 <= float(refute.stats["robustness_value"]) <= 1.0,
    )
    adjusted = np.atleast_1d(results["bias_adjusted_estimate"])
    if refute.confounder_increases_estimate:
        print("  adjusted below the estimate ->", bool(np.all(adjusted <= float(estimate.value))))
    else:
        print("  adjusted above the estimate ->", bool(np.all(adjusted >= float(estimate.value))))

    print()
    print("compute_bias_adjusted with the two sets of partial R2 of the upstream:")
    terms = refute.compute_bias_adjusted(
        r2tu_w=np.array([0.7, 0.2]), r2yu_tw=np.array([0.9, 0.3])
    )
    for key, value in terms.items():
        print("  {:24s} {}".format(key, np.asarray(value).tolist()))
    first = float(np.atleast_1d(terms["bias_adjusted_estimate"])[0])
    second = float(np.atleast_1d(terms["bias_adjusted_estimate"])[1])
    print(
        "  the first adjusted estimate is farther from the estimate ->",
        abs(float(estimate.value) - first) > abs(float(estimate.value) - second),
    )


main()
