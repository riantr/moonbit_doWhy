name = "riantr/moonbit_dowhy"

version = "0.0.2"

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
]

description = "MoonBit port of DoWhy 0.14 (PyWhy). Causal graph construction and analysis, effect identification (backdoor / frontdoor / complete adjustment), estimation (linear regression, propensity score weighting / matching / stratification, doubly robust, generalized linear model, instrumental variable, two stage, regression discontinuity), refutation (bootstrap, placebo treatment, data subset, dummy outcome, unobserved common cause) and causal discovery (the PC algorithm with the Fisher-z test). Pure MoonBit with zero external runtime dependencies."

source = "src"

preferred_target = "native"

supported_targets = [ "js", "wasm", "wasm-gc", "native" ]
