name = "riantr/moonbit_dowhy"

version = "0.0.6"

readme = "README.mbt.md"

repository = "https://gitee.com/ren-yongxiang/moonbit_doWhy"

license = "MIT"

keywords = [
  "causal-inference",
  "dowhy",
  "causal-graph",
  "causal-discovery",
  "backdoor",
  "frontdoor",
  "propensity-score",
  "treatment-effect",
  "refutation",
  "identifiers",
  "estimators",
  "shapley-values",
  "independence-test",
  "structural-causal-model",
  "causal-mechanism",
  "what-if",
  "counterfactual",
]

description = "MoonBit port of DoWhy 0.14 (PyWhy). Causal graph construction and analysis, effect identification (backdoor / frontdoor / complete adjustment), estimation (linear regression, generalized linear model, propensity score weighting / matching / stratification, doubly robust, instrumental variable, two stage, regression discontinuity), refutation (bootstrap, placebo treatment, data subset, dummy outcome, unobserved common cause), intervention sampling (do samplers), temporal graphs, causal discovery (the PC algorithm with the Fisher-z test) and the portable core of the graphical causal models (the p-value merging, the bootstrap confidence intervals, the Kullback-Leibler divergences, the density estimators, the Shapley values, the independence tests, the prediction models, the causal mechanisms, the fitting of a causal model and the what-if queries (the interventional samples, the counterfactual samples and the average causal effect). Pure MoonBit with zero external runtime dependencies."

source = "src"

preferred_target = "native"

supported_targets = [ "js", "wasm", "wasm-gc", "native" ]
