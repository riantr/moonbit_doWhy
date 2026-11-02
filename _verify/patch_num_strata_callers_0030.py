"""Fix the loop of the strata helper and use the automatic strata in the model."""

edits = [
    (
        r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\src\estimators\propensity_score.mbt",
        [
            (
                "    for k in i; k <= j; k = k + 1 {\n      group.push(order[k])\n    }",
                "    for k = i; k <= j; k = k + 1 {\n      group.push(order[k])\n    }",
            ),
        ],
    ),
    (
        r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\src\causal_model.mbt",
        [
            (
                """    "backdoor.propensity_score_stratification" =>
      @estimators.CausalEstimator::propensity_score_stratification(
        estimand, 5, 10,
      )""",
                """    "backdoor.propensity_score_stratification" =>
      @estimators.CausalEstimator::propensity_score_stratification(
        estimand,
        @estimators.NumStrata::Auto,
        10,
      )""",
            ),
        ],
    ),
]

for path, replacements in edits:
    s = open(path, encoding="utf-8", newline="").read()
    for old, new in replacements:
        assert s.count(old) == 1, (path, s.count(old), old[:60])
        s = s.replace(old, new)
    open(path, "w", encoding="utf-8", newline="").write(s)
    print("patched", path)
