name = "riantr/moonbit_dowhy"

version = "0.0.77"

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
  "overlap",
  "identifiers",
  "estimators",
  "shapley-values",
  "independence-test",
  "structural-causal-model",
  "causal-mechanism",
  "what-if",
  "counterfactual",
]

description = "MoonBit port of DoWhy 0.14 (PyWhy). Causal graph construction and analysis, effect identification (backdoor / frontdoor / complete adjustment), estimation (linear regression, generalized linear model, propensity score weighting / matching / stratification, doubly robust, instrumental variable, two stage, regression discontinuity), refutation (bootstrap, placebo treatment, data subset, dummy outcome, unobserved common cause, the assess overlap refuter that learns the rules of the support and of the overlap with boolean rules), intervention sampling (do samplers), temporal graphs, causal discovery (the PC algorithm with the Fisher-z test) and the portable core of the graphical causal models (the p-value merging, the bootstrap confidence intervals, the Kullback-Leibler divergences, the density estimators, the Shapley values, the independence tests, the prediction models, the causal mechanisms, the automatic assignment of the causal mechanisms with the selection of the model of a node by cross validation, the fitting of a causal model, the what-if queries (the interventional samples, the counterfactual samples and the average causal effect), the validation layer (the kernel based conditional independence test, the validation of a causal structure and the validation of an invertible model) and the falsification layer (the local Markov condition, the pairwise dependencies, the parental d-separations, the causal minimality and the permutation test of a graph) and the model evaluation layer (the normalised mean squared error, the continuous ranked probability score, the performance of the causal mechanisms, the test of the invertibility assumption and the report of the evaluation) and the distribution change layer (the test of the change of a mechanism, the attribution of the change of the distribution of a target node, the multiply-robust attribution of the change of the mean or of the variance of a target node and the scores of the change of the distribution of every node). Pure MoonBit with zero external runtime dependencies."

source = "src"

preferred_target = "native"

supported_targets = [ "js", "wasm", "wasm-gc", "native" ]
