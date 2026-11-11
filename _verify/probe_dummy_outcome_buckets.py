"""Measure the bucketing of the upstream DummyOutcomeRefuter on its own dataset.

An earlier probe built the linear dataset by hand and concluded that
`pd.cut(frame[treatment], num_bins)` raises `ValueError: bins must increase
monotonically`, because `num_bins` is a Series with one entry per column.
Running the upstream's own continuous-treatment internal-estimator test showed
that the branch does run and returns one refutation per treatment bucket, so
the hand-built frame differs from the real one in a way that matters.

This script prints the real frame: its columns, dtypes, per-column ranges, the
`num_bins` Series, the bucket edges and the size of every group.  That is what
the port has to reproduce.

The binary treatment is a different matter.  The upstream casts it to the dtype
of a boolean (`data.astype({tname: "bool"})`), so its `preprocess_data_by_treatment`
takes the branch of the booleans, which groups the rows by the values of the
treatment, and the upstream never cuts it.  The frame of the last section of
this script builds its binary treatment as a column of floats, so the cut of
that frame does raise `ValueError: bins must increase monotonically`; that is a
property of the hand built frame and not of the upstream.  The ten binary
cases of `tests/causal_refuters/test_dummy_outcome_refuter.py` run, and
`_verify/dummy_outcome_binary_reference.py` runs them and prints their numbers.

Run: python _verify/probe_dummy_outcome_buckets.py
"""

import sys

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

import numpy as np
import pandas as pd

import dowhy.datasets
from dowhy import CausalModel
from dowhy.causal_refuters import dummy_outcome_refuter as dor

for binary in (False,):
    data = dowhy.datasets.linear_dataset(
        beta=10,
        num_common_causes=1,
        num_instruments=1,
        num_samples=1000,
        treatment_is_binary=binary,
    )
    frame = data["df"]
    print("=" * 70)
    print("the frame of linear_dataset, treatment_is_binary =", binary)
    print("=" * 70)
    print("treatment_name:", data["treatment_name"])
    print("outcome_name  :", data["outcome_name"])
    print("columns       :", list(frame.columns))
    print("dtypes        :", {c: str(t) for c, t in frame.dtypes.items()})
    print("shapes        :", frame.shape)

    treatment = data["treatment_name"][0]
    print()
    print("per-column max - min:", [round(float(v), 4) for v in (frame.max() - frame.min()).values])
    std_dev = frame[treatment].std()
    print("std of the treatment:", std_dev)
    num_bins = (frame.max() - frame.min()) / (0.5 * std_dev)
    print("num_bins series     :", [round(float(v), 4) for v in num_bins.values])
    print("num_bins values     :", [round(float(v), 4) for v in np.asarray(num_bins).ravel()])
    print()
    print("pd.cut with the Series:")
    try:
        cut = pd.cut(frame[treatment], num_bins)
        print("  ok, categories:", len(cut.cat.categories))
        print("  categories    :", [str(c) for c in cut.cat.categories])
        print("  group sizes   :", list(cut.value_counts().sort_index().values))
    except Exception as exc:  # noqa: BLE001
        print("  raised {}: {}".format(type(exc).__name__, exc))

    print()
    print("what the upstream function itself groups by, by instrumenting it:")
    original = dor.preprocess_data_by_treatment

    def traced(data, treatment_name, unobserved_confounder_values, bucket_size_scale_factor, chosen_variables):
        variable_type = data[treatment_name[0]].dtypes
        print("  variable_type      :", variable_type, "| name:", variable_type.name)
        print("  bool == variable_type ->", bool == variable_type)
        std = data[treatment_name[0]].std()
        bins_expr = (data.max() - data.min()) / (bucket_size_scale_factor * std)
        print("  bucket_size_scale_factor:", bucket_size_scale_factor)
        print("  num_bins           :", [round(float(v), 4) for v in np.asarray(bins_expr).ravel()])
        groups = original(
            data, treatment_name, unobserved_confounder_values, bucket_size_scale_factor, chosen_variables
        )
        sizes = groups.size()
        print("  groups             :", len(sizes))
        print("  group sizes        :", list(sizes.values))
        return groups

    dor.preprocess_data_by_treatment = traced

    model = CausalModel(
        data=frame,
        treatment=data["treatment_name"],
        outcome=data["outcome_name"],
        graph=data["gml_graph"],
        proceed_when_unidentifiable=True,
        test_significance=None,
    )
    estimand = model.identify_effect(method_name="exhaustive-search")
    estimand.set_identifier_method("iv")
    estimate = model.estimate_effect(
        identified_estimand=estimand,
        method_name="iv.instrumental_variable",
        test_significance=None,
    )
    refs = model.refute_estimate(
        estimand,
        estimate,
        method_name="dummy_outcome_refuter",
        transformation_list=[("linear_regression", {}), ("zero", ""), ("noise", {"std_dev": 1})],
        num_simulations=3,
    )
    print()
    print("returned", len(refs), "refutations")
    for i, ref in enumerate(refs):
        print("  [{}] estimated={: .6f} new={: .6f}".format(i, ref.estimated_effect, ref.new_effect))
    dor.preprocess_data_by_treatment = original

print()
print("=" * 70)
print("does the bucketing survive a BINARY treatment in the same column order?")
print("(the frame below is built by hand and its binary treatment is a column of")
print(" floats, so it is not the frame of the upstream, whose binary treatment is")
print(" a column of booleans and is grouped by its values, not cut)")
print("=" * 70)
print("`linear_dataset` with a binary treatment cannot be called on numpy 2.5.1,")
print("because `convert_to_binary` returns the one element array of")
print("`np.random.choice([0, 1], 1, p=...)`, which `np.vectorize` refuses. The")
print("frame is therefore built by hand, in the column order the upstream produces")
print("(`Z0, W0, v0, y`), with the same kind of columns.")
for n in (1000, 20000):
    for binary in (False, True):
        rng = np.random.default_rng(11)
        w = rng.normal(0, 1, n)
        z = rng.binomial(1, 0.5, n).astype(float)
        treatment = rng.normal(0, 1, n) * 3 + w + z
        if binary:
            treatment = (treatment > 0).astype(float)
        y = 10.0 * treatment + 2.0 * w + rng.normal(0, 1, n)
        frame = pd.DataFrame({"Z0": z, "W0": w, "v0": treatment, "y": y})
        std_dev = frame["v0"].std()
        edges = (frame.max() - frame.min()) / (0.5 * std_dev)
        label = "binary" if binary else "continuous"
        try:
            cut = pd.cut(frame["v0"], edges)
            print(
                "  n={:6d} {:10s} edges={} -> {} buckets".format(
                    n,
                    label,
                    [round(float(v), 3) for v in edges.values],
                    len(cut.cat.categories),
                )
            )
        except Exception as exc:  # noqa: BLE001
            print(
                "  n={:6d} {:10s} edges={} -> {}: {}".format(
                    n,
                    label,
                    [round(float(v), 3) for v in edges.values],
                    type(exc).__name__,
                    exc,
                )
            )

