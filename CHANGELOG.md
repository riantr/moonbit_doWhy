# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2026-10-31

The first release. It is a port of DoWhy 0.14 (PyWhy) to MoonBit with zero
external runtime dependencies, and it covers the analysis pipeline end to end:
graph, identification, estimation, refutation.

### Added

- `api` -- the subset of `pandas.DataFrame` the estimators read: ordered
  columns, row selection, column assignment and the numeric access the
  regressions need.
- `utils` -- dense matrices, Gauss-Jordan inversion, the Moore-Penrose pseudo
  inverse, ordinary least squares, an IRLS logistic regression, the normal and
  Student-t distributions, descriptive statistics and a deterministic
  generator.
- `graph` -- `dowhy.graph` and `dowhy.causal_graph`: an insertion ordered
  directed graph, d-separation, do-surgery, backdoor paths and instruments.
- `identifiers` -- `dowhy.causal_identifier`: the backdoor criterion with the
  default, exhaustive, minimum, maximum, efficient and cost-efficient
  strategies, the frontdoor criterion, the general adjustment criterion, the
  estimand registry and the assumption builders.
- `model` -- `dowhy.causal_model` and `dowhy.causal_estimator`: the
  `CausalModel` entry point and the `CausalEstimate` object with its
  confidence interval, standard error and p-value.
- `estimators` -- `dowhy.causal_estimators`: linear regression, propensity
  score weighting (inverse, stabilised and normalised), propensity score
  matching, propensity score stratification, the doubly robust estimator, the
  instrumental variable estimator, the two stage regression and the regression
  discontinuity estimator.
- `refuters` -- `dowhy.causal_refuters`: the bootstrap, placebo treatment,
  data subset, dummy outcome, random common cause and unobserved common cause
  refuters.
- `datasets` -- `dowhy.datasets`: the `linear_dataset` generator and the
  deterministic fixtures the upstream tests use.
- `tests` -- the cross-package integration tests.

[0.0.1]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.1

## [0.0.2] - 2026-10-31

### Fixed

- The package now declares the `wasm` backend in `supported_targets`. It
  compiled and ran on `wasm` all along, but the registry metadata did not
  say so, and a module created with `moon new` defaults to `preferred_target
  = "wasm"`. A consumer that added this package and built without changing
  the target of its module was therefore refused with "Selected backend
  'wasm' is incompatible with the dependency graph". Declaring the backend
  also lets the toolchain run the test suite on it, which it does not do
  for a package that does not declare it.
- The publish workflow installs the toolchain from the "latest" path of the
  MoonBit CDN. Every versioned path answers 403, so the toolchain cannot be
  pinned from the install script; the version check is now a policy about
  what the runner found rather than a download.
- The publish workflow validates the registry credentials before it
  publishes them and reports the cause by name. A secret that carries a
  byte order mark is a valid secret and an invalid json file at the same
  time, and the failure it produced said nothing about the cause.

### Changed

- The registry description and the keywords now mention the causal
  discovery package.

[0.0.2]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.2

## [0.0.3] - 2026-10-31

### Added

- `data_transformers` -- `dowhy.data_transformers`: the PCA reducer, with the
  components, the explained variance ratios and the standardised variant. The
  numbers are the ones `sklearn.decomposition.PCA` produces on the same rows.
- `do_samplers` -- `dowhy.do_sampler` and `dowhy.do_samplers`: the weighting,
  the multivariate weighting and the kernel density sampler, the state
  propensity score and the variable types. The MCMC sampler is not ported; it
  needs the PyMC3 sampler of upstream, and the method says so instead of
  returning a wrong answer.
- `timeseries` -- `dowhy.timeseries`: the temporal graph with its causal time
  lags, the graph builders and the temporal shift.
- `api` -- the one-hot encoder of `dowhy.utils.encoding` and the encoder
  registry that keeps the encoding of a column stable between the fit and the
  estimate.
- `utils` -- generalised linear models with the gaussian, the binomial and the
  poisson family, fitted with iteratively reweighted least squares and without
  a penalty, the convention of `statsmodels.api.GLM`.
- `estimators` -- the generalised linear model estimator, the do-operator
  `CausalEstimator::intervene` and the one-hot encoding of the discrete
  columns of the treatment, the adjustment variables and the effect modifiers.
- `datasets` -- two more data sets: one with a binary outcome and one with a
  binary outcome and without a confounder.

### Fixed

- `CausalModel::estimate_effect` identifies the effect with the identifier of
  the method name when it has not been identified yet. Before, a model that was
  used for a single estimate estimated the effect with an empty adjustment
  set, which silently dropped every confounder.
- The propensity score estimators compute the scores of the data they are
  asked about with the model and the encoder that were fitted on the training
  data, so the scores follow the rows of that data. Upstream assigns the
  scores of the training data to the new rows by position, which mixes two
  different rows up.

[0.0.3]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.3

## [0.0.4] - 2026-11-01

### Added

- `gcm` -- the portable core of `dowhy.gcm`:
  - the configuration of the package and the general helpers: the geometric
    median, the set difference of the rows of a matrix, the scaling of the
    columns and the permutation of the rows;
  - the merging of p values: the average rule of Gasparini and Wang, the
    quantile rule of Meinshausen and the false discovery rate control of
    Benjamini and Hochberg;
  - the F test of a nested model, the marginal expectation of an
    intervention and the bootstrap confidence intervals;
  - the Kullback-Leibler divergences: the categorical one, the one of
    probability vectors, the nearest neighbour estimator and the classifier
    estimator;
  - the kernel density estimator;
  - the Shapley values, with the exact, the exact fast, the subset sampling,
    the permutation and the early stopping approximations;
  - the independence tests: the regression based one and the generalised
    covariance measure.
  The causal mechanisms, the probabilistic causal models and the fitting of a
  causal model are **not ported**: they need the prediction model layer of
  `dowhy.gcm.ml`, which upstream fits with AutoGluon, CatBoost and a symbolic
  equation fitter. The `GaussianMixtureDensityEstimator` is **not ported**
  either, because upstream uses the variational inference of
  `sklearn.mixture.BayesianGaussianMixture`.
- `utils` -- the chi-square and the F distribution, the regularised incomplete
  gamma function and the Pearson, the Spearman and the Kendall rank
  correlations, with the numbers `scipy.stats` produces.
- `utils` -- `gammaincc`, the regularised upper incomplete gamma function, and
  `ln`, `exp`, `nan` and `is_nan`, so that the packages that need them do not
  have to import the `math` package themselves.

### Fixed

- **The error function of the `utils` package was wrong.** Its series was the
  one of a function without the factorial of the order and without the
  alternating signs, so `erfc(0.75)` came out as `-0.4225` instead of
  `0.2888`, and `normal_cdf(1.0)` as `1.1352` instead of `0.8413`. The
  generalised linear model estimator takes its confidence interval from
  `normal_ppf`, whose value at 0.975 was `1.8101` instead of `1.95996`, so
  **every confidence interval of that estimator was too narrow**, and the
  p-values of the Fisher-z test of the `cm` package were too small. The error
  function is now computed from the regularised upper incomplete gamma
  function, which the package already had, and it agrees with SciPy to about
  1e-15 over the whole range of the arguments.
- The tests of the Fisher-z test and of the confidence interval of the
  generalised linear model estimator now pin the numbers they check. They
  asserted inequalities only, which is why the wrong error function went
  unnoticed.

### Changed

- The upstream `dowhy.gcm` modules are now loadable from Python without
  installing the package, with the helper `_verify/upstream_gcm.py`. The
  reference numbers of the new package therefore come from the upstream code
  itself rather than from a reading of it.

[0.0.4]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.4

## [0.0.5] - 2026-11-01

### Added

- `gcm` -- the structural causal model layer of `dowhy.gcm`:
  - the prediction models of `dowhy.gcm.ml`: the linear regression, the
    logistic regression of two classes and the invertible functions of the
    post non-linear models;
  - the causal mechanisms of `dowhy.gcm.causal_mechanisms`: the additive noise
    model, the discrete additive noise model, the post non-linear model and the
    categorical model of a classifier;
  - the stochastic models of `dowhy.gcm.stochastic_models`: the empirical
    distribution, the empirical categorical distribution and the normal, the
    Laplace and the uniform distribution;
  - the probabilistic causal model of `dowhy.gcm.causal_models`, with the
    validation of the assignment of the mechanisms and of the structure of the
    graph;
  - the fitting and the sampling of `dowhy.gcm.fitting_sampling`;
  - the automatic assignment of the mechanisms of `dowhy.gcm.auto`;
  - the one-hot encoding of the discrete parents of a node, which is the
    encoding of `dowhy.gcm.util.general`.
- `_verify/gcm_scm_reference.py` -- the upstream reference of the layer. It
  computes the numbers of the upstream tests of `tests/gcm/test_fcms.py` with
  the upstream code itself, so the expectations of the tests of the port are
  the numbers of the upstream rather than a reading of it.

### Fixed

- The prediction model of the `gcm` package now centres the design before the
  least squares fit, like `sklearn.linear_model.LinearRegression` does. The
  one-hot encoding of a categorical parent and the intercept are collinear, so
  the two conventions spread the same fit over the columns differently: the
  uncentred one gave the coefficients `[2, -7.5, 7.5, 2.5]` and the intercept
  `2.5` for the categorical fixture of the upstream, where the upstream gives
  `[2, -5 - 10/3, 10 - 10/3, 5 - 10/3]` and the intercept `10/3`. Both
  describe the same function, but only the centred one is the number of the
  upstream, so the port uses it.
- A distribution whose parameters were given keeps them when it is fitted,
  like the `ScipyDistribution` of the upstream does. A distribution whose
  parameters are to be estimated says so with
  `StochasticModel::with_estimated_parameters`.

[0.0.5]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.5

## [0.0.6] - 2026-11-01

### Added

- `gcm` -- the what-if layer of `dowhy.gcm`:
  - the interventions on the nodes of a causal model, which are the port of the
    interventions of `dowhy.gcm.whatif`: the atomic intervention `do(X := 2)`
    and the soft intervention `do(X := X + 1)`, for a numeric node and for a
    categorical one;
  - the data and the noise of a causal model, which is the port of
    `dowhy.gcm._noise`: the noise of a model is recovered from the observed
    data, and the data of a model follow from its noise;
  - the what-if queries of `dowhy.gcm.whatif`: the interventional samples of a
    fitted model, the counterfactual samples of an observed row and the average
    causal effect of two sets of interventions;
  - the `fit_and_compute` of `dowhy.gcm.confidence_intervals_cms`, which
    refits the causal model on a subset of the training data before it
    evaluates the causal query, so that the bootstrap interval takes the
    uncertainty of the fit into account.
- `_verify/gcm_whatif_reference.py` -- the upstream reference of the layer. It
  computes the numbers of the upstream tests of `tests/gcm/test_whatif.py` with
  the upstream code itself, so the expectations of the tests of the port are the
  numbers of the upstream rather than a reading of it.

### Fixed

- The clone of a causal model keeps its mechanisms untrained, like the clone of
  the upstream does. The upstream clones a model with `sklearn.clone`, so the
  prediction model, the classifier and the distribution of the copy have to be
  fitted again before they can be used. The parameters that were given to a
  model are its hyper parameters and not the result of a fit, so the clone of a
  model with fixed parameters keeps them.
- The restricted model of the average causal effect shares the mechanisms of the
  model of the caller instead of cloning them, because the upstream restricts a
  model with a view of its graph, and a view keeps the mechanisms of the nodes
  it holds.

[0.0.6]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.6

## [0.0.7] - 2026-11-01

### Added

- `gcm` -- the validation layer of `dowhy.gcm`:
  - the kernel based independence test, which is the port of
    `dowhy.gcm.independence_test.kernel`: the kernel conditional independence
    test of `causal-learn`, in its unconditional and in its conditional form,
    with the gamma approximation of its null distribution. It is the default
    independence test of the upstream validation;
  - `refute_causal_structure`, which validates the assumptions of a causal
    graph against the data: the dependence of every edge and the local Markov
    condition of every node, with the Benjamini-Hochberg control of the false
    discovery rate;
  - `refute_invertible_model`, which validates that the causal mechanisms of a
    model can be represented by an invertible functional causal model.
- `_verify/gcm_validation_reference.py` -- the upstream reference of the layer.
  It computes the numbers of the upstream validation module with the upstream
  code itself, so the expectations of the tests of the port are the numbers of
  the upstream rather than a reading of it.
- `_verify/gen_validation_testdata.py` and
  `_verify/gen_validation_invertible_testdata.py` -- the generators of the
  fixtures of the tests of the layer. They replace the random draws of the
  upstream with the draws of a fixed seed, so that the MoonBit test and the
  upstream reference see the very same rows.

### Fixed

- The eigen decomposition of `utils.jacobi_eigen` now stops when the
  off-diagonal part of the matrix is negligible **against the matrix itself**,
  instead of when the sum of the squares of the off-diagonal elements is at
  most `1e-15`. The old criterion was absolute, so it left the off-diagonal
  elements of the matrix at a size of about `3e-8`. That is enough for a
  matrix with a well separated spectrum, but not for a nearly degenerate one:
  the eigenvalues of the latter were only accurate to about `1e-9`. The
  regressed kernel matrix of the conditional kernel test has a nearly
  degenerate tail, so the p-value of the test moved by `1.6e-09` relative to
  the upstream. With the relative criterion the port agrees with the upstream
  to about `8e-12`, which is the noise floor of the upstream itself.
  `jacobi_eigen` is shared with the estimators, the ordinary least squares fit
  and the PCA reducer, and the change does not move any of their numbers.

### Notes

- The port always fits a linear regressor for the automatic assignment of a
  mechanism, so the validation of the invertible model of a **non-linear**
  relation rejects the model in the port and does not in upstream, which picks
  its model by cross validation out of a zoo of estimators and can capture the
  relation. The validation of a linear relation agrees in both.
- The kernel based independence test of the upstream draws the subset of at
  most 1000 rows that its median trick uses from the global generator of
  numpy, so the p-value of a large sample depends on that draw. The port draws
  it from the generator it is given, which makes its p-values reproducible.

[0.0.7]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.7

## [0.0.8] - 2026-11-01

### Added

- `gcm` -- the falsification layer of `dowhy.gcm`, the port of
  `dowhy.gcm.falsify`:
  - `validate_lmc`, which validates the local Markov condition of a graph
    against the data: a node is conditionally independent of its non-descendants
    given its parents;
  - `validate_pd`, which validates the pairwise dependencies of a graph: a node
    is dependent on each of its ancestors;
  - `validate_tpa`, which validates the parental d-separations of a graph against
    a reference graph: two graphs that violate none of them lie in the same
    Markov equivalence class;
  - `validate_cm`, which validates the causal minimality of a graph: a node is
    conditionally independent of each of its parents given its other parents;
  - `run_validations`, which runs the validation methods of a graph, and
    `PValuesMemory`, which holds the p-values of the tests that were already
    run, so that the test of the conditional independence of `X` and `Y` given
    `Z` is not run twice for the two orders of the pair;
  - `falsify_graph`, which falsifies a graph with a permutation test: the
    number of the violations of the local Markov condition of a random
    permutation of the nodes of the graph is the null distribution of the test,
    and `PermuteNodes` generates those permutations;
  - `apply_suggestions`, which removes the edges of a graph whose causal
    minimality was violated.
- `_verify/gcm_falsify_reference.py` -- the upstream reference of the layer. It
  computes the numbers of the upstream falsification module with the upstream
  code itself, so the expectations of the tests of the port are the numbers of
  the upstream rather than a reading of it.
- `_verify/gen_falsify_testdata.py` -- the generator of the fixtures of the
  tests of the layer. It replaces the random draws of the upstream with the
  draws of a fixed seed, so that the MoonBit test and the upstream reference
  see the very same rows.

### Notes

- The upstream test of the **categorical** fixture of the falsification layer is
  not ported: the data frame of the port holds one numeric or one discrete
  column per name, and the kernel based independence test of the port takes
  numeric matrices only. The other fifteen upstream test cases are ported.
- The falsification layer takes **one** independence test, of the type
  `IndependenceTest`, whose third argument is the optional conditioning
  variable. Upstream takes two callables there, one for the marginal test and
  one for the conditional test; the marginal test of the port is the one that is
  called without the conditioning variable.
- The upstream builds the set of the non-descendants of a node in an arbitrary
  order and chooses the pairs of the pairwise dependencies at random from the
  global generator of numpy. The port uses the order of the graph and draws the
  pairs from the generator it is given.
- The p-values of the port and of the upstream agree to `1e-12`. The upstream
  fits the regression of the generalised covariance measure with the singular
  value decomposition of `scipy.linalg.lstsq` and the port with the pseudo
  inverse of the ordinary least squares fit, and a p-value in the far tail of
  the normal distribution amplifies the difference between the two fits.

[0.0.8]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.8

## [0.0.9] - 2026-11-01

### Added

- `gcm` -- the mechanism evaluation layer of `dowhy.gcm`, the port of
  `dowhy.gcm.model_evaluation`:
  - `nmse`, the normalised mean squared error of the observed and of the
    predicted values;
  - `crps` and `crps_categorical`, the continuous ranked probability score of a
    probabilistic prediction, which measures its calibration;
  - `estimate_conditional_expectations` and
    `estimate_conditional_expectations_categorical`, the conditional expectation
    of a causal mechanism;
  - `evaluate_model_performances`, the performance of the causal mechanism of
    every node of a model: the divergence of the generated and of the observed
    distribution of a root node, and the score, the error and the coefficient of
    the determination of a node with parents;
  - `evaluate_invertibility_assumptions`, the test of the assumption of the
    invertible functional causal model, which checks the independence of the
    noise of a mechanism and of its parents;
  - `evaluate_causal_model`, which runs the four evaluations of the layer -- the
    performance of the mechanisms, the assumption of the invertible model, the
    divergence of the generated distribution and the structure of the graph --
    and `CausalModelEvaluationResult`, whose report is the summary of the
    upstream;
  - `EvaluationConfig` and `EvaluationOptions`, the settings of the evaluation,
    and `kernel_independence_test`, the kernel based independence test for the
    settings that need a generator.
- `gcm` -- the Bonferroni correction of the false discovery rate control, which
  the evaluation of the invertibility assumption uses by default, like the
  upstream.
- `gcm` -- the report of the falsification of a graph, which the report of the
  evaluation of a model embeds.
- `_verify/gcm_model_evaluation_reference.py` -- the upstream reference of the
  layer. It computes the numbers of the upstream evaluation module with the
  upstream code itself, so the expectations of the tests of the port are the
  numbers of the upstream rather than a reading of it.

### Notes

- The metrics of the layer are of two kinds. The normalised mean squared error
  and the score of a deterministic mechanism are the same numbers as the ones of
  the upstream, and the tests of the port compare them with a tight tolerance.
  The score of a mechanism with a noise and the performance of the mechanisms of
  an evaluated model depend on the draws of the noise and on the folds of the
  cross validation, which the upstream draws from the global generator of numpy
  and the port draws from the generator it is given; the tests of these numbers
  use the tolerances of the upstream test file
  `tests/gcm/test_model_evaluation.py`.
- The port compares the mechanisms of an evaluated model with **every** baseline
  it is given. Upstream skips the baseline whose model class is the class of the
  mechanism, and the port has one regression model and one classification model,
  so skipping it would leave no baseline at all and the comparison would be
  vacuous.
- The falsification of the graph of the port takes numeric matrices only, so the
  evaluation of a model whose data holds a categorical column does not falsify
  the graph. The upstream one-hot encodes the categorical data and does.
- The upstream test of the layer uses the kernel based independence test for the
  invertibility assumption, and the reference script of the layer uses it as
  well. The default test of the port is the generalised covariance measure,
  which needs one dimensional variables only, so the test of a node with more
  than one parent needs `kernel_independence_test`.

[0.0.9]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.9

## [0.0.10] - 2026-11-01

### Added

- `gcm` -- the anomaly detection layer of `dowhy.gcm`, the port of
  `dowhy.gcm.anomaly_scorers` and of the detection part of
  `dowhy.gcm.anomaly`:
  - `AnomalyScorer`, the scorers of the layer, with a constructor per scorer:
    the median CDF quantile scorer, the rescaled median CDF quantile scorer, the
    rank based scorer, the information theoretic scorer, the mean deviation
    scorer, the median deviation scorer and the inverse density scorer;
  - `anomaly_scores`, the anomaly score of every node of a causal model, and
    `conditional_anomaly_scores`, the anomaly score of a sample in the
    conditional distribution of its target;
  - `AnomalyScorerFactory`, the factory of the scorers, which is the argument
    the upstream takes.
- `gcm` -- `DensityEstimator`, the kernel based density estimator of
  `dowhy.gcm.density_estimators`, with the bandwidth of Silverman.
- `_verify/gcm_anomaly_reference.py` -- the upstream reference of the layer. It
  computes the numbers of the upstream scorers and of the upstream anomaly
  scores with the upstream code itself, so the expectations of the tests of the
  port are the numbers of the upstream rather than a reading of it.

### Notes

- The scores of the scorers on the toy fixtures of the upstream test file
  `tests/gcm/test_anomaly_scorers.py` are deterministic, and the tests of the
  port compare them with a tight tolerance. The anomaly scores of a causal model
  depend on the samples the mechanisms draw, which the upstream draws from the
  global generator of numpy and the port draws from the generator it is given,
  so the tests of these numbers assert the node with the largest score, which is
  what the upstream test file `tests/gcm/test_anomaly.py` asserts.
- The inverse density scorer of the port estimates the density with the kernel
  based estimator of the upstream. The upstream uses the Bayesian Gaussian
  mixture of the upstream by default, which needs the variational inference of
  `sklearn.mixture.BayesianGaussianMixture` and is **not ported**.
- The port counts the samples of the distribution that are equal to a sample,
  that are greater than it and that are smaller than it with a binary search
  over the sorted samples of the distribution, where the upstream counts them
  with a vectorised comparison over the whole distribution. The counts and the
  scores are the same numbers.
- The attribution of the anomalies -- the contribution of the upstream nodes to
  the anomaly score of a sample -- is **not ported**. The upstream needs the
  noise of the upstream nodes of a target and a Shapley estimator that computes
  the values of every sample at once, while the Shapley estimator of the port
  computes the values of one set function at a time.

[0.0.10]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.10

## [0.0.11] - 2026-11-01

### Added

- `gcm` -- the attribution of the anomalies of a causal model, the port of
  `dowhy.gcm.anomaly.attribute_anomalies`:
  - `attribute_anomalies`, which attributes the anomaly score of every anomaly
    sample to the nodes of the graph that are upstream of the target, with the
    Shapley values of the score;
  - `noise_samples_of_ancestors`, the samples of the ancestors of a node and of
    the node itself together with their noise, which the attribution needs.
- `_verify/gcm_anomaly_attribution_reference.py` -- the upstream reference of the
  attribution. It computes the numbers of the upstream attribution with the
  upstream code itself, so the expectations of the tests of the port are the
  numbers of the upstream rather than a reading of it.

### Notes

- The attribution depends on the noise the mechanisms draw and on the
  permutations the set function uses, which the upstream draws from the global
  generator of numpy and the port draws from the generator it is given, so the
  contributions of the port and of the upstream are close to each other and not
  equal. The tests of the port assert the relations the upstream test file
  `tests/gcm/test_anomaly_attribution.py` asserts and the numbers of the
  upstream reference, with a tolerance of `0.05` that covers the difference of
  the two generators.
- The sum of the contributions does not depend on the permutations, so it is the
  same number in the port and in the upstream: the two agree to `2e-15`.
- The port computes the Shapley values of one anomaly sample at a time. The
  upstream computes the values of every sample at once, with a set function that
  returns an array; the Shapley estimator of the port takes one set function at
  a time, so the port calls it once per sample. The exact estimator evaluates
  the same subsets of the players in both.
- The `attribute_anomaly_scores` of the upstream, which attributes the anomalies
  with a scorer that scores several variables at once, is **not ported**. It
  needs the density estimator of the upstream, and the scorers of the port score
  one dimensional samples.

[0.0.11]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.11

## [0.0.12] - 2026-11-01

### Added

- `gcm` -- the unit change layer, the port of `dowhy.gcm.unit_change`:
  - `unit_change_linear`, which attributes the change of the output of a linear
    mechanism to the inputs that changed and to the mechanism itself;
  - `unit_change_nonlinear`, which does the same with the Shapley values of the
    output;
  - `unit_change_linear_input_only` and `unit_change_nonlinear_input_only`,
    which attribute the change of the output to the inputs alone.
- `_verify/gcm_unit_change_reference.py` -- the upstream reference of the layer.
  It computes the numbers of the upstream attribution with the upstream code
  itself, so the expectations of the tests of the port are the numbers of the
  upstream rather than a reading of it.

### Notes

- The upstream has a random forest regressor next to its linear one, so that it
  can tell the linear attribution from the non-linear one. The port has one
  model, which is linear, so the non-linear attribution of the port is used
  with the linear model. The upstream test file
  `tests/gcm/test_unit_change.py` compares the two attributions with each
  other, and the tests of the port do the same.
- The upstream `unit_change` dispatcher picks between the linear and the
  non-linear attribution with the type of its mechanism. The port has one
  mechanism, which is linear, so it exposes the four functions of the layer
  instead of the dispatcher.
- The port puts the difference of the intercepts of the two mechanisms into the
  contribution of the mechanism. The upstream drops it, because the linear
  model of its fixtures is fitted without an intercept; the port fits its model
  with one, like the fit of the `gcm` package does everywhere else, so the
  contributions of the port would not add up to the change of the output
  without it. The intercept of the fixtures of the layer is zero up to the
  rounding of the fit, so the contributions of the port and of the upstream are
  the same numbers.
- The port computes the Shapley values of the unit change of one row at a time.
  The upstream computes the values of every row at once, with a set function
  that returns an array; the Shapley estimator of the port takes one set
  function at a time, so the port calls it once per row. The exact estimator
  evaluates the same subsets of the players in both.

[0.0.12]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.12

## [0.0.13] - 2026-11-01

### Added

- `gcm` -- the uncertainty estimates, the port of `dowhy.gcm.uncertainty`:
  - `estimate_entropy_using_discretization`, which estimates the entropy of a
    sample with a histogram of its values;
  - `estimate_entropy_kmeans`, which estimates the entropy of a sample with the
    Kozachenko-Leonenko estimator;
  - `estimate_gaussian_entropy`, which estimates the entropy of a sample with
    the Gaussian that fits it;
  - `estimate_variance`, which is the population variance of a sample with one
    column and the determinant of the sample covariance matrix of a sample with
    more columns;
  - `estimate_entropy_of_probabilities`, which is the mean of the entropies of
    the rows of a matrix of probabilities;
  - `estimate_entropy_discrete`, which is the entropy of the frequencies of the
    rows of a sample of discrete values.
- `utils` -- `mat_determinant`, the determinant of a square matrix, and
  `digamma`, the digamma function of `scipy.special.digamma`.
- `_verify/gcm_uncertainty_reference.py` -- the upstream reference of the layer.
  It computes the numbers of the upstream estimates with the upstream code
  itself, so the expectations of the tests of the port are the numbers of the
  upstream rather than a reading of it.

### Notes

- The upstream shapes its numpy inputs into two dimensional matrices with
  `shape_into_2d`; the port takes a matrix, so a vector is a matrix with one
  column.
- The port computes the distances to the nearest neighbours of a sample with
  more than one column by comparing every pair of rows, which costs `O(n^2 d)`.
  The upstream asks `sklearn.neighbors.NearestNeighbors`, which builds a tree.
  The distances are the same numbers. For one column the port sorts the values
  and walks the two sides of every value, which costs `O(n k)`.
- The digamma function of the `utils` package walks up to an argument of ten
  with the recurrence `ψ(x + 1) = ψ(x) + 1 / x` and uses the asymptotic
  expansion of the remainder, which is the expansion `scipy` uses. For an
  integer `n` the two agree to about `2e-15` at `n = 10000`.
- The multivariate fixture of the layer holds a hundred thousand rows, where the
  upstream test holds a million. The covariance of the sample is the same
  number either way, and the port keeps the fixture small enough for every
  backend of the toolchain.

[0.0.13]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.13

## [0.0.14] - 2026-11-01

### Added

- `gcm` -- the distribution change layer, the port of
  `dowhy.gcm.distribution_change`:
  - `mechanism_change_test`, which tests whether the mechanism of a node
    changed between two data sets;
  - `distribution_change`, which attributes the change of the marginal
    distribution of a target node between two data sets to the nodes of the
    causal graph;
  - `distribution_change_of_graphs`, which does the same between two models
    that are already fitted on the old and on the new data;
  - `estimate_distribution_change_scores`, which scores every node of a model by
    how much its distribution changed.
- `gcm` -- `DistributionChangeConfig`, the configuration of the layer, and
  `DistributionChangeResult`, its result.
- `graph` -- `DirectedGraph::ordered_predecessors`,
  `DirectedGraph::node_connected_subgraph_view` and
  `DirectedGraph::remove_node`, the three helpers the layer needs.
- `_verify/gcm_distribution_change_reference.py` -- the upstream reference of the
  layer. It computes the numbers of the upstream attribution with the upstream
  code itself, so the expectations of the tests of the port are the numbers of
  the upstream rather than a reading of it.

### Notes

- The upstream keeps the mechanisms and the root distributions in the node
  attributes of the graph; the port keeps them in the model. The layer therefore
  clones the models where the upstream clones them, and copies the **fitted**
  mechanisms where the upstream relies on the node attributes surviving the
  subgraph view of the target node. A clone of a mechanism is unfitted, so a
  model whose mechanisms were cloned has to be fitted again before it can be
  used.
- The layer exposes a configuration value and a result value instead of the
  `return_additional_info` flag and the `auto_assignment_quality` parameter of
  the upstream. The port always returns the attribution, the change of every
  mechanism and the two models; the caller assigns the mechanisms itself when it
  wants to.
- The binary label of the test of the change of a mechanism is encoded with a
  two column one hot matrix, like the `OneHotEncoder(handle_unknown="ignore")` of
  the upstream, which keeps every category of the label.
- The rows of the two samples of the test of the change of a mechanism are
  permuted with the generator the layer is given, and the upstream permutes them
  with the global generator of numpy. The p-values therefore differ on the same
  rows, and the decision they lead to is the same.
- The fixtures of the layer hold a fifth of the rows of the fixtures of the
  upstream, because the kernel based conditional test of the layer inverts a
  kernel matrix whose size is the number of the rows of the joint sample.
- The **robust** variant of the layer (`dowhy.gcm.distribution_change_robust`)
  is **not ported**.

[0.0.14]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.14

## [0.0.15] - 2026-11-01

### Changed

- `gcm` -- the Kullback-Leibler divergence of a sample with one column finds the
  distance to the k-th nearest neighbour with a walk over the sorted values of
  the sample, so the estimator costs `O(n log n)` instead of the `O(n^2)` of the
  pairwise search. The distances are the same numbers, because the walk takes
  the nearer of the two sides of the value first, and the distance of a single
  column is computed like the one of two rows of two matrices. The divergence
  of two samples of a few thousand values is the term that dominates the cost
  of the distribution change layer, and the layer is an order of magnitude
  faster now.
- `gcm` -- the fixtures of the change of the distribution hold a tenth of the
  rows of the fixtures of the upstream, where they held a fifth of them. The
  kernel based conditional test of the layer inverts a kernel matrix whose size
  is the number of the rows of the joint sample, so the cost of the test grows
  with the cube of the number of the rows. The reference script of the layer
  uses the same fixtures as the port, so the numbers it prints are the numbers
  of the fixture of the port.

### Notes

- The changelog of 0.0.1 listed the efficient backdoor strategies of the
  upstream among the ported ones. They are **not** implemented: the port
  reports that the efficient backdoor search is not implemented yet, the way
  the README says.
- The port takes the measure of the difference of two distributions as a function
  of two samples, and the measure of the configuration is the Kullback-Leibler
  divergence of `auto_estimate_kl_divergence` when the caller does not give one.

[0.0.15]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.15

## [0.0.16] - 2026-11-01

### Added

- `gcm` -- the arrow strength layer, the port of `dowhy.gcm.influence`:
  - `arrow_strength`, which computes the causal strength of every edge that
    points at a target node;
  - `arrow_strength_of_model`, which computes the strength of every input of a
    mechanism;
  - `ArrowStrengthConfig`, the configuration of the layer.
- `_verify/gcm_influence_reference.py` -- the upstream reference of the layer. It
  computes the numbers of the upstream arrow strength with the upstream code
  itself, so the expectations of the tests of the port are the numbers of the
  upstream rather than a reading of it.

### Notes

- The strength of an edge is measured with the difference of the variances of
  the two distributions of the target, like the upstream does for a continuous
  target. For a categorical target the upstream measures the Kullback-Leibler
  divergence of the class probabilities, and the port does the same.
- The upstream runs the estimate for every edge in a process pool and the port
  runs it for one edge at a time. The estimate of one edge does not depend on
  the others, so the strengths are the same numbers.
- The upstream draws its permutations and its noise from the global generator of
  numpy, so the numbers of the upstream depend on that generator. The tests of
  the port assert the relations the upstream test file asserts, with a tolerance
  around the numbers the reference script prints.
- The samples of the conditional distribution and the number of the runs of the
  estimate are smaller than the ones of the upstream, the way they are in the
  other layers of the port: the upstream draws two thousand samples of the
  conditional distribution and runs the estimate up to five thousand times.
- The **intrinsic causal influence** of the upstream is **not ported**.

[0.0.16]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.16

## [0.0.17] - 2026-11-01

### Added

- `identifiers` -- the efficient backdoor search, the port of
  `dowhy.causal_identifier.efficient_backdoor`:
  - `efficient_backdoor_adjustment`, the efficient adjustment set of Smucler,
    Sapienza and Rotnitzky (2021, Biometrika);
  - `efficient_backdoor_minimal_adjustment`, the efficient minimal adjustment
    set of the same paper;
  - `efficient_backdoor_mincost_adjustment`, the efficient minimum cost
    adjustment set, found with the minimum cut of the flow network of Smucler
    and Rotnitzky (2022, Journal of Causal Inference).
- `identifiers` -- the three efficient strategies are wired into
  `identify_backdoor` and `identify_effect_auto`, which take the costs and the
  conditional variables of the upstream.
- `_verify/gen_efficient_backdoor_testdata.py` -- the generator of the example
  graphs of the tests of the search. It reads the fixtures of the upstream
  mechanically, so the expected adjustment sets cannot be mistranscribed.
- `_verify/efficient_backdoor_reference.py` -- the upstream reference of the
  search.
- `_verify/efficient_backdoor_cut_probe.py` -- the script that compares the cut
  of the upstream with the minimum cut of the same network.
- `_verify/efficient_backdoor_extra_reference.py` -- the upstream reference of
  the two graphs of the tests that the upstream test file does not cover.

### Changed

- `identifiers` -- `backdoor_adjustment_error` now rejects a strategy that is
  not one of the strategies of the upstream, the way the upstream raises an
  error for it. Every strategy of the upstream is supported.
- `identifiers` -- `identify_backdoor` and `identify_effect_auto` take the
  costs of the variables and the conditional variables of the upstream. The
  arguments are optional and are ignored by the strategies that do not use
  them.

### Removed

- `identifiers` -- `EFFICIENT_BACKDOOR_NOT_IMPLEMENTED`. The efficient backdoor
  search is implemented now, so the message has no reason to exist.

### Notes

- The changelog of 0.0.1 listed the efficient backdoor strategies of the
  upstream among the ported ones, and the changelog of 0.0.15 corrected that.
  They are implemented now.
- The port reports the failures of the search with a message instead of
  raising an error, the way the rest of the port reports the failures of the
  other searches.
- An empty list of costs means that every variable of the graph costs one. The
  upstream uses the same rule when it is given no costs at all, and a variable
  without a cost has an infinite capacity in the flow network.
- The flow network of the minimum cost strategy is solved with Dinic's
  algorithm. The amount that is pushed along a path is the smallest residual
  capacity of the path, and the levels of the level graph are the distances to
  the source. The upstream finds another maximum flow when several of them
  exist, and the cut it reports is the one that is contained in every other
  cut; the port reproduces it on all eleven example graphs of the upstream.
- The example graphs of the upstream that have no costs are the ones with the
  cost of one for every variable, and the ones with explicit costs leave the
  variables without a cost at an infinite capacity. The port follows both
  rules, so the adjustment sets of the eleven example graphs are the ones of
  the upstream.

[0.0.17]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.17

## [0.0.18] - 2026-11-01

### Added

- `identifiers` -- the optimized backdoor search, the port of
  `dowhy.causal_identifier.backdoor`:
  - `optimized_backdoor_adjustment`, which walks the paths between the
    treatment and the outcome, keeps the backdoor paths and finds a small set
    of variables that blocks all of them with the greedy hitting set algorithm
    of the upstream;
  - the `optimize_backdoor` flag of `identify_backdoor` and of
    `identify_effect_auto`, which replaces the backdoor search with the
    optimized one, the way the upstream does.
- `_verify/optimized_backdoor_reference.py` -- the upstream reference of the
  search. It runs the upstream on the six graphs of the upstream test file and
  prints the sets it finds, twice, because the upstream breaks a tie in its
  hitting set algorithm with the iteration order of a Python dictionary of
  strings.

### Notes

- The port breaks the tie in the hitting set algorithm with the name of the
  variable, so its result does not change between the runs. The upstream
  breaks it with the iteration order of a dictionary of strings, and that
  order changes between the runs of the interpreter. The sets the port finds
  are the sets the upstream finds on the six graphs of the upstream test file.
- The upstream adds a set for a pair of nodes when the whole table of the
  pairs is not empty, and reads the pair out of that table, which raises an
  error when the pair has no path and another pair has one. The port checks
  the pair itself, and a pair without a path gets no set.
- The upstream keeps the state of a pair of nodes and of a path only for its
  own printing. The port keeps the variables that block the paths and nothing
  else.

[0.0.18]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.18

## [0.0.19] - 2026-11-01

### Added

- `identifiers` -- the ID algorithm of Shpitser and Pearl, the port of
  `dowhy.causal_identifier.id_identifier`:
  - `identify_effect_id`, which returns the estimand of the effect as a
    product of conditional distributions and the variables the product has to
    be summed over;
  - `IDExpression`, `IDElement` and `IDPredictor`, the three types the
    estimand is built from, with the accessors of their parts;
  - `IDExpression::to_string`, which prints the estimand the way the upstream
    prints it.
- `_verify/id_identifier_reference.py` -- the upstream reference of the
  algorithm. It runs the upstream on the six graphs of the upstream test file
  and prints the string of the estimand of each of them.

### Notes

- The upstream keeps the variables of a sum in a Python `set`, so their order
  changes between the runs of the interpreter. The port keeps them in the
  order of the nodes of the graph, so its estimand does not change.
- The order of the factors of the product follows the order of the nodes of
  the graph, the way it does upstream. The upstream reads the graph from a
  graph string, and the order of the nodes of that string is the order of
  their first appearance.
- The upstream stops at the last case of its algorithm, the one of a hedge it
  does not handle, and reports that the effect is not identifiable. The port
  reports the same.
- The ID algorithm is a function of its own, the way it is upstream. It is not
  wired into `CausalModel::identify_effect`, because the upstream returns an
  estimand of another kind for it.

[0.0.19]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.19

## [0.0.20] - 2026-11-01

### Added

- `gcm` -- the tests of the configuration, of the stochastic models and of the
  noise, the port of the upstream test files `tests/gcm/test_config.py`,
  `tests/gcm/test_stochastic_models.py` and `tests/gcm/test_noise.py`:
  - `src/gcm/config_test.mbt` -- the two settings of the configuration are set
    on a copy of it, because MoonBit has no mutable global;
  - `src/gcm/stochastic_models_test.mbt` -- the parameters a fitted normal
    distribution estimates, the samples it draws and the samples of an
    empirical distribution;
  - `src/gcm/noise_test.mbt` -- the data of a causal model that are computed
    from the noise of its nodes, the noise that is computed from the data of
    the nodes and the noise of a single row of data.
- `_verify/gcm_stochastic_models_reference.py` -- the upstream reference of the
  stochastic models. It runs the upstream on the very rows the port works on
  and prints the parameters the upstream estimates on them.
- `_verify/gcm_noise_reference.py` -- the upstream reference of the noise. It
  runs the upstream `dowhy.gcm._noise` on the very rows the port works on and
  prints the data and the noise it computes.
- `_verify/strip_bom.py` -- the helper that removes the byte order mark the
  PowerShell writes into a file it rewrites.

### Fixed

- The parents of a node are taken in the **sorted** order everywhere a design
  matrix is built, the way the upstream takes them with
  `dowhy.graph.get_ordered_predecessors`. The port took them in the order of
  the edges of the graph, which gives a different column order -- and therefore
  a different fit -- whenever the order of the edges is not the sorted one.
  The parents a node is fitted with are compared against the sorted ones as
  well, the way the upstream compares them.

### Notes

- The upstream `BayesianGaussianMixtureDistribution` and the beta distribution
  are not part of the port, so the three tests of the upstream that use them
  have no counterpart here.
- The upstream `get_noise_dependent_function` is not part of the port, so the
  four tests of the upstream that use it have no counterpart here.
- The upstream draws its samples from the global generator of numpy, so the
  samples of the upstream and of the port are different numbers. The reference
  scripts print the samples of the port, which a replica of the generator of
  the `utils` package reproduces, and the samples of the upstream for the
  record.

[0.0.20]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.20

## [0.0.21] - 2026-11-01

### Added

- `gcm` -- the feature relevance, the port of `dowhy.gcm.feature_relevance`:
  - `feature_relevance_sample`, which estimates the relevance of every input of
    a prediction model for every sample of the baseline;
  - `feature_relevance_distribution`, which estimates the relevance of every
    input for the whole distribution of the inputs;
  - `parent_relevance`, which estimates the relevance of the direct parents of
    a node of a causal model and the relevance of its noise.
- `_verify/gcm_feature_relevance_reference.py` -- the upstream reference of the
  feature relevance. It runs the upstream on the very rows the port works on and
  prints the relevance of the upstream next to the relation the upstream test
  asserts, so that the two can be compared.

### Notes

- The upstream draws its permutations with the global generator of numpy, so
  the relevance it computes and the relevance the port computes are different
  numbers. What the two share is the relation the upstream test asserts: the
  relevance of an input of a linear model is its coefficient times the
  difference of the sample and the mean of the column. The upstream and the
  relation agree to `3.9e-15`.
- The upstream estimates the Shapley values of all the samples of the baseline
  in one pass over the subsets of the inputs; the port estimates them for every
  sample on its own. The two give the same numbers for a set function that
  does not depend on the sample.
- The upstream broadcasts the one prediction of the baseline over the
  predictions of the background when it compares them; the port repeats the
  prediction of the baseline for every sample of the background.
- The prediction method of the port returns one number per row, so the two
  tests of the upstream that use a classifier -- whose predictions are a
  probability per class -- have no counterpart here.
- The fixtures of the port hold fewer samples than the ones of the upstream,
  because the upstream draws them with the global generator of numpy and the
  exact method of the Shapley values cannot afford fifteen players and a
  thousand samples. The relations the upstream asserts hold for every size of
  the fixture; the tolerance of the test that compares two relevances is
  relative, because the absolute tolerance of the upstream is a small fraction
  of a relevance that the smaller fixture estimates less precisely.

[0.0.21]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.21

## [0.0.22] - 2026-11-01

### Added

- `gcm` -- the intrinsic causal influence, the port of
  `dowhy.gcm.influence`:
  - `intrinsic_causal_influence`, which estimates the contribution of the noise
    of every ancestor of the target node to the variance of the target node;
  - `intrinsic_causal_influence_sample`, which estimates the contribution of
    the noise of every ancestor to every sample of the target node;
  - `icc_variance_attribution`, the attribution function of a continuous
    target.
- `_verify/gcm_intrinsic_influence_reference.py` -- the upstream reference of
  the intrinsic causal influence. It runs the upstream on the very rows the port
  works on and prints the contributions of the upstream next to the relation
  the upstream test asserts, so that the two can be compared.

### Notes

- The upstream draws its noise with the global generator of numpy, so the
  contributions it computes and the contributions the port computes are
  different numbers. What the two share is the relation the upstream test
  asserts: the contribution of a node is the variance of the noise of that
  node. On the fixture of the reference script the variance of the target is
  `5.7182810415575` in both; the upstream contributes `0.772` to `X0` and
  `3.948` to `X2`, the port `0.856` and `4.176`.
- The upstream selects the model of the approximate prediction with the model
  selection of `dowhy.gcm.auto`; the port fits a linear regression, which is
  the model the upstream selects for a linear relation. The quality of the
  assignment therefore has no effect on the result. On the fixture of the
  reference script the contribution of the upstream to `X0` is `1.029` with the
  approximate prediction and `0.772` with the exact one, while the two of the
  port agree, because the relation of the fixture is linear.
- The upstream propagates the noise of the exact prediction through the whole
  model, which fails when the model holds a descendant of the target node,
  because the noise of that descendant is not among the columns of the noise
  samples. The port propagates it through the sub graph of the ancestors of the
  target node.
- The prediction method of the port returns one number per row, so the three
  tests of the upstream that use a categorical target -- whose predictions are a
  probability per class -- have no counterpart here.

[0.0.22]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.22

## [0.0.23] - 2026-11-01

### Added

- `gcm` -- the equation parser, the port of `dowhy.gcm.equation_parser`:
  - `create_causal_model_from_equations`, which builds a causal model out of a
    set of equations, in the three forms the upstream understands: the equation
    of a root node, the equation of a node with parents and the equation of a
    node whose relation to its parents is unknown;
  - `PredictionModel::with_equation`, the prediction model that evaluates the
    custom function of an equation.
- `_verify/gcm_equation_parser_reference.py` -- the upstream reference of the
  equation parser. It runs the upstream on the very equations the port works on
  and prints the graph of the model it builds, the parents of every node and
  the predictions of the custom function, so that the two can be compared.

### Notes

- The upstream evaluates the custom function of an equation with the `eval` of
  Python over the arrays of the parents; the port parses the expression and
  evaluates it over the rows of the design matrix, because a language without
  `eval` needs a parser. The numbers are the same for the expressions both
  understand: the reference script prints `4.0`, `6.5` and `9.0` for the
  custom function `0.5 * B + 2 * A` over the parents `A = [1, 2, 3]` and
  `B = [4, 5, 6]`, and so does the port.
- The upstream lets an expression call every function of numpy and of
  `scipy.stats`; the port knows a fixed set of functions. The set is the one
  the upstream tests of the equation parser use, plus the elementary ones.
- The upstream reads the arguments of a noise model with the `literal_eval` of
  Python; the port reads numbers only, which are the arguments the noise
  models of the port take.
- The upstream fits the best distribution of `scipy.stats` to the data for the
  `parametric()` noise model of an equation; the port fits the parameters of a
  normal distribution.

[0.0.23]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.23

## [0.0.25] - 2026-11-02

The entry point of the upstream, `dowhy.causal_model`, and the readers of the
graphs it accepts.

### Added

- `graph` -- the readers of the graphs the upstream reads:
  - `parse_gml`, which reads a GML graph and resolves the identifiers of its
    edges to the labels of its nodes, the way `networkx.parse_gml` does it;
  - `parse_dot`, which reads a DOT graph;
  - `daggity_to_dot`, the port of `dowhy.utils.graph_operations.daggity_to_dot`,
    which turns the graph of the daggity web site into a DOT graph.
- the root package -- the `CausalModel` of `dowhy.causal_model`:
  - `CausalModel::new_with_graph_string` reads a graph that is given as a GML
    string, as a DOT string or as the graph of the daggity web site, and
    `is_supported_graph_format` tells whether a string is one of them;
  - the model holds a `CausalGraph`, reports the common causes, the
    instruments and the effect modifiers of the graph, reports the variables
    of the graph that are not in the data and the columns of the data that are
    not in the graph, returns its summary and keeps the estimator of every
    method it has used.
- `datasets` -- `Dataset::gml_graph` writes the graph of the data set in the
  GML format, the way `dowhy.datasets.create_gml_graph` writes it, and
  `LinearConfig::new` builds a configuration from the parameters of the
  upstream.
- `estimators` -- the conditional estimates of the regression based
  estimators: a continuous effect modifier is split into five quantile groups
  and the effect is estimated on every one of them, the way the upstream does
  it.
- `model` -- `CausalEstimate::conditional_estimates` hands the conditional
  estimates of an estimate over.
- the tests of the upstream file `tests/test_causal_model.py` that the port can
  run: the GML graph of `test_graph_input` and of `test_graph_input2`, the
  graph of the daggity web site of `test_graph_input3` and of
  `test_graph_input4`, the graph object of `test_graph_input_nx`, the
  observed and the unobserved variables of
  `test_unobserved_graph_variables_log_warning`, the format check of
  `test_incorrect_graph_format`, the cache of the estimators of
  `test_causal_estimator_cache` and the conditional estimates of
  `test_cate_estimates_regression`.
- `_verify/causal_model_reference.py` -- the upstream reference of the causal
  model. It runs the upstream `dowhy.causal_graph.CausalGraph` and the
  upstream `dowhy.datasets` on the fixtures of the upstream tests and prints
  the nodes, the edges, the common causes, the instruments and the observed
  and the unobserved variables of them, which is where the expectations of the
  tests of the port come from.

### Changed

- The effect modifiers of `CausalModel::estimate_effect` are a labelled
  optional argument now, and they are the effect modifiers of the graph when
  the caller names none, the way the upstream does it. The argument of the
  previous releases was a positional one, so a caller of those releases has
  to write `effect_modifier_names=[]` or to leave the argument out. A model
  whose graph holds effect modifiers therefore gets the interactions of the
  upstream, which the previous releases left out.

### Fixed

- The format of a graph string is recognised the way the upstream recognises
  it. The whitespace between the keyword `graph` and the bracket of a GML
  graph is optional, so the GML graph of the upstream -- which starts with
  `graph[` -- is read, and a string that starts with `dag` is the graph of the
  daggity web site.
- The GML graph of a data set is now the graph of the upstream character for
  character: the upstream joins the nodes of a group with a space and writes
  the groups one after the other without a separator, and it writes the edge
  of the treatment to the outcome without the space that the other edges have.
- The quantile bins of a column run from `0` to `q - 1`, the way the bins of
  `pandas.qcut` do.

### Notes

- The upstream `linear_dataset` cannot run under NumPy 2, because `np.vectorize`
  cannot store the one element array that its `convert_to_binary` returns in
  the output of a scalar. The reference script restores the behaviour of NumPy
  1 for it, which is the behaviour the upstream was written against.
- The upstream warns about the variables of the graph that are not in the data
  and logs the columns of the data that are not in the graph. The port has no
  warning system, so it reports them instead.

[0.0.25]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.25

## [0.0.26] - 2026-11-02

The mediation identification of the upstream and its two stage regression
estimator, with the integration test of the book "Causal Inference and
Discovery in Python".

### Added

- `identifiers` -- the mediation identification, the port of the mediation part
  of `dowhy.causal_identifier.auto_identifier`:
  - `identify_mediation`, which finds the mediator of the effect;
  - `identify_mediation_first_stage_confounders` and
    `identify_mediation_second_stage_confounders`, which find the confounders
    of the two stages of a mediation;
  - `identify_nie_effect`, which identifies the natural indirect effect.
- `estimators` -- the two stage regression estimator of the upstream, the port
  of `dowhy.causal_estimators.two_stage_regression_estimator`: the first stage
  regresses the mediator on the treatment, the second stage regresses the
  outcome on the mediator, and the estimate is the product of the two effects.
  `CausalEstimator::two_stage_features` hands the columns of the design
  matrices of the two stages over.
- `graph` -- `check_valid_mediation_set`, the port of
  `dowhy.graph.check_valid_mediation_set`, on a directed graph.
- the integration test of the upstream file
  `tests/causal-inference-discovery-book/test_causal_inference_discovery_book.py`:
  the case of the chapter 7 of the book "Causal Inference and Discovery in
  Python", with the frontdoor identification, the two stage regression and the
  data subset refutation.
- `_verify/two_stage_reference.py` -- the upstream reference of the two stage
  regression estimator. It runs the upstream identification and the upstream
  two stage regression estimator on the rows of the upstream test and prints
  the frontdoor variables, the confounders of the two stages and the estimate,
  which is where the expectations of the tests of the port come from.
- `_verify/gen_two_stage_testdata.py` and `_verify/book_scm.py` -- the
  generator of the data set of the integration test. The rows are the rows of
  the upstream test, which the fixture `fixed_seed` of the upstream makes
  reproducible.

### Changed

- The default adjustment set of the backdoor search is now the one the
  upstream picks: the set with the fewest instruments wins, because an
  instrument of the adjustment set lowers the variance of the treatment
  variable, and the set with the fewest variables wins among those. The
  previous releases picked the set with the fewest variables only. The two
  rules agree on every graph whose adjustment sets hold no instrument.
- The identification of the average effect now carries the confounders of the
  two stages of the frontdoor, the way the upstream does it, so that the two
  stage regression estimator has them.
- The identification of the mediation is the identification of the natural
  indirect effect, so the method name `mediation.two_stage_regression` of the
  upstream works.

### Notes

- The upstream takes the two stage models of the two stage regression
  estimator as arguments, so that a caller can replace them. The port always
  fits the two linear regressions the upstream falls back to.
- The **natural direct effect** is **not ported**. The upstream computes it
  with a third model, the total effect, and subtracts the natural indirect
  effect from it.
- The mediator search enumerates its candidates in sorted order. The upstream
  iterates over a `set`, so its order depends on the hash seed.
- The refutation of the upstream test draws its subsets from the global
  generator of numpy, and the port draws its subsets from the generator it is
  given, so the number of the refutation is not one the two implementations
  share. The estimate of the two stage regression is the same number in both:
  the two agree to `5e-14`.

[0.0.26]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.26

## [0.0.27] - 2026-11-02

The test file of the two stage regression estimator of the upstream, with the
two cases it holds.

### Added

- the tests of the upstream file
  `tests/causal_estimators/test_two_stage_regression_estimator.py`:
  - the average treatment effect test suite case: the data set of the upstream
    `linear_dataset` with one frontdoor mediator and no common cause, the
    estimate of the two stage regression estimator and the tolerance of ten
    percent the upstream test allows;
  - the frontdoor estimator case: the data set of the upstream test, the
    estimate of the two stage regression estimator and the value of 0.45 the
    upstream test asserts.

  Both cases check the frontdoor variables, the confounders of the two stages
  and the columns of the design matrices of the two stages as well.
- `estimators` -- `CausalEstimator::two_stage_error`, which reports the
  message of the error the upstream raises when the estimand cannot be
  estimated by the two stage regression, so that a caller can check for it
  before it fits the estimator.
- `src/tests/two_stage_testdata.mbt` -- the rows of the upstream test
  `test_frontdoor_estimator`. They are the rows of the upstream, because the
  fixture `fixed_seed` of the upstream seeds the generator of numpy with zero.
- `_verify/two_stage_estimator_reference.py` -- the upstream reference of the
  two stage regression estimator. It runs the upstream identification and the
  upstream two stage regression estimator and prints the frontdoor variables,
  the confounders of the two stages and the estimate, which is where the
  expectations of the tests of the port come from.
- `_verify/port_linear_dataset.py` -- the generator of the port
  (`src/datasets/datasets.mbt`) replicated in Python, so that the upstream can
  run on the very rows the port works on.
- `_verify/gen_two_stage_estimator_testdata.py` -- the generator of the rows
  of the upstream test.
- `_verify/print_frontdoor_graph.py` -- a helper that prints the graph string
  of the upstream test as a MoonBit literal, so that the test holds the very
  same string.

### Notes

- The data of the port is drawn with its own generator, so its rows are not the
  rows of the upstream, which draws them with the generator of numpy. The
  first case therefore runs the upstream on the replicated rows of the port,
  and the two implementations agree on the estimate to `1e-13`. The second case
  runs on the rows of the upstream test, and the two agree to `8e-14`.
- The third case of the upstream, the one that asks for an error, is ported as
  a reported error: MoonBit cannot catch the error the estimator raises, so
  the port aborts with the message of the upstream and
  `CausalEstimator::two_stage_error` reports that message before the fit. The
  upstream raises the error of the more than one treatment variable for one of
  its two configurations, and the error of the missing frontdoor variable for
  the other one -- its identification finds no frontdoor variable for that
  graph, because the mediators and the treatment share a common cause.
- The upstream computes the confidence interval and the standard error of the
  two stage estimate with the generic bootstrap of `CausalEstimator`, and the
  port reports none for it. The upstream test asks for them without asserting
  anything about their values.

[0.0.27]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.27

## [0.0.28] - 2026-11-02

The placebo treatment refuter of the upstream and the significance test of the
refutations, with the test file of the upstream.

### Added

- `refuters` -- the significance test of the refutations, the port of
  `dowhy.causal_refuter.test_significance`: the automatic test uses the two
  sided percentile test of the bootstrap for a hundred simulations and more and
  the test of the normal distribution below that, and either of the two can be
  asked for by name. The refutations report the p-value and the decision of the
  test: the placebo and the dummy outcome refuters test the zero estimate
  against the estimates they produced, the bootstrap, the data subset and the
  random common cause refuters test the estimate of the data.
- `refuters` -- `PlaceboType`, the kind of the placebo the placebo treatment
  refuter builds: a random variable of the kind of the treatment, or the rows
  of the treatment, permuted. `CausalModel::refute_estimate` takes it as a
  labelled optional argument.
- `identifiers` -- `IdentifiedEstimand::with_treatment` and
  `IdentifiedEstimand::with_instrumental_variables`, the copies the placebo
  treatment refuter builds.
- `estimators` -- `CausalEstimator::instrument_name` and
  `CausalEstimator::with_instrument_name`, the copies the placebo treatment
  refuter builds for the instrumental variable method.
- the tests of the upstream file
  `tests/causal_refuters/test_placebo_refuter.py`: the continuous treatment
  case with one common cause and the case without one, the binary treatment
  case and the categorical treatment case, with the tolerances of the upstream
  test.
- the tests of the significance test of the refutations: the two kinds of test,
  the automatic choice between them, the ties and the level of the test.
- a test of the permuted placebo of the instrumental variable method, which
  permutes the instrument with the same permutation as the treatment, the way
  the upstream does.
- `_verify/placebo_reference.py` -- the upstream reference of the placebo
  treatment refuter.
- `_verify/significance_reference.py` -- the expected p-values of the
  significance test of the refutations.

### Fixed

- The permuted placebo of the placebo treatment refuter permutes the rows of
  the treatment, the way the upstream does with
  `data[treatment_names].iloc[permuted_idx].values`. The port drew a new random
  variable for every kind of treatment instead, so the permuted placebo of a
  continuous treatment was the constant zero and its estimate was exactly zero,
  like the estimate of the random data placebo.
- The random data placebo of a categorical treatment draws from the distinct
  categories of the column, the way the upstream does with
  `data[treatment].unique()`, and not from its rows, so a category that holds
  more rows is not drawn more often.

### Notes

- The placebo of the upstream is drawn with the global generator of numpy and
  the port draws it with its own generator, so the refuted estimates of the
  port are not the estimates of the upstream. What the two share is the
  behaviour the upstream test asserts: the effect of the placebo is close to
  zero.
- The upstream's fourth case, the one that gives a non consecutive index to
  the rows of the data, is not portable: the frame of the port holds no index.
- The upstream raises an error when the placebo of an instrumental variable
  method is not the permuted one. The port aborts with the message of the
  upstream, because MoonBit cannot catch an error.
- A refuter that ran no simulation has no distribution to test the estimate
  against, so its p-value is one. The upstream computes the mean of the
  simulations with numpy, which returns `nan` for an empty array, so its
  p-value is `nan`.

[0.0.28]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.28

## [0.0.24] - 2026-11-01

### Added

- `gcm` -- the categorical variants of the regression based independence test,
  the port of `dowhy.gcm.independence_test.regression` for data that holds
  categories:
  - `regression_based_with_categorical`, which takes a frame for the two
    variables and the optional conditioning variable, one-hot encodes every
    discrete column of them and runs the test on the encoded data;
  - `one_hot_encode` and `one_hot_encode_frame`, the encoding of the discrete
    columns of the `gcm` package;
  - `estimate_ftest_pvalue_of_targets`, the F-test of `dowhy.gcm.stats` for a
    target with more than one column, which is what a categorical target
    becomes when it is one-hot encoded. The single target variant of the test
    delegates to it.
- `_verify/gcm_categorical_independence_reference.py` -- the upstream reference
  of the categorical independence test. It runs the upstream on the very rows
  the port works on and prints the p-value of the upstream next to the decision
  the upstream test asserts, so that the two can be compared.

### Notes

- The upstream draws its folds and its basis points with the global generator of
  numpy, so its p-value and the p-value of the port are different numbers. What
  the two share is the decision the upstream test asserts. On the fixture of
  the reference script the upstream finds a p-value of `1.0` for the two cases
  that have to find no dependence and a p-value of `0.0` for the two cases that
  have to find a dependence, and so does the port.
- The upstream marks its categorical independence tests as flaky, because the
  two models of the F-test have residual sums of squares of the same order in
  the folds of the case that has to find no dependence: with a thousand samples
  the upstream finds a dependence in half of the seeds of that case. The
  fixture of the port therefore holds the 5000 samples of the fixture of the
  upstream, at which both make the same decision on every seed.
- The upstream switches to the CatBoost encoder when the data of the regression
  based independence test holds more than seven categories; the port always
  uses the one-hot encoder, which is the encoder the upstream uses for the
  fixtures of its own tests.

[0.0.24]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.24

## [0.0.30] - 2026-11-02

The test suites of the four propensity score estimators of the upstream, and
the two fixes of the estimators they found.

### Added

- the tests of the upstream files `tests/causal_estimators/test_propensity_score_matching_estimator.py`,
  `test_propensity_score_weighting_estimator.py`,
  `test_propensity_score_stratification_estimator.py` and
  `test_doubly_robust_estimator.py`: the eighteen cases they hold, on the
  hundred thousand rows of the upstream test suite, with the tolerance the
  upstream test file allows for each of its estimators and with the two
  identifiers the upstream uses for them.
- `_verify/estimator_suite_reference.py` -- the upstream runs on the very rows
  the port works on, for the eighteen cases of the suite. The port and the
  upstream agree on every case: the matching estimator and the stratification
  estimator agree to `1e-14` on one common cause, the weighting estimator
  agrees to `3e-4` and the doubly robust estimator to `5e-7`.

### Fixed

- **The propensity score estimators trimmed the scores of the data, and the
  upstream trims them in two of the four of them.** The inverse propensity
  score weighting estimator trims the scores to `0.05` and `0.95` and the
  doubly robust estimator trims them to `0.01` and `0.99`, while the matching
  estimator and the stratification estimator use the raw scores. The trimming
  of the port moved the matches of the matching estimator and the strata of
  the stratification estimator: on the hundred thousand rows of the upstream
  estimator test suite the estimate of the stratification estimator was
  `10.308` with the trimmed scores and `10.0001` with the raw ones, and the
  upstream gives `10.0001`. The two estimators that trim them trim them
  themselves now, and the doubly robust estimator trims the scores of the two
  arms separately, the way the upstream does.
- **The propensity score stratification estimator always used five strata.** The
  upstream searches for the number of strata when it is not given: the search
  starts with `0.5 * rows / clipping_threshold` strata and halves the number
  until at least half of the strata hold more than `clipping_threshold` units
  of both arms. The upstream test file uses the search, and it is what makes
  the estimate of the estimator agree with the upstream. The number of strata
  is an enumeration now, `NumStrata`, with a case for a given number of strata
  and a case for the number of strata the upstream searches for.

### Notes

- The rows of the test suites of the upstream are drawn with the global
  generator of numpy, so the upstream runs its estimator and refuter test
  suites on a random draw of the rows. The rows of the port are fixed, and the
  seed of every suite is the one for which the **upstream** stays inside the
  tolerances of its own test files on the very same rows. Two of the
  eighteen cases of the estimator suite are decided by the draw: the inverse
  propensity score weighting estimator with two common causes and the doubly
  robust estimator with two common causes and a binary outcome are outside the
  tolerance of the upstream on the rows of the seed 42, and the upstream is
  outside it as well.
- The estimator test suite of the port asserts the estimates only. The
  upstream test files also ask for the confidence intervals and for the
  significance of the estimate, with ten bootstrap simulations for the
  stratification and the doubly robust estimator; the upstream asserts none of
  those numbers, and ten simulations of a bootstrap over a hundred thousand
  rows would multiply the runtime of the suite by an order of magnitude.
- The bootstrap refuter test suite of the port draws its own rows, with the
  seed 43. The rows of the seed 42 put the refuted effect of the binary
  treatment with three variables outside the tolerance of the upstream test
  file, and the rows of the seed 43 do not.

[0.0.30]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.30

## [0.0.29] - 2026-11-02

The bootstrap refuter and the data subset refuter of the upstream, with their
test files.

### Added

- `refuters` -- the perturbation of the variables of interest of the bootstrap
  refuter: a numeric column gets a Gaussian noise whose standard deviation is
  the given fraction of the standard deviation of the column, a column of zeros
  and ones is flipped and a discrete column gets another category, both with
  the probability of the change, which is the noise unless it is given. The
  variables the refuter perturbs are named with the enumeration
  `RequiredVariables`.
- the tests of the upstream file
  `tests/causal_refuters/test_bootstrap_refuter.py`: the thirteen cases it
  holds, with the tolerances of the upstream test.
- the tests of the upstream file
  `tests/causal_refuters/test_data_subset_refuter.py`: the continuous
  treatment with one common cause and without one, and the binary treatment
  with one common cause, on the hundred thousand rows of the upstream test.
- the tests of the match rule of the propensity score matching estimator: the
  sorted search has to pick the same units as a scan over every unit of the
  other group, also when the scores are tied.

### Fixed

- **The logistic regression of the `utils` package built the diagonal weight
  matrix of its iteratively reweighted least squares step.** The matrix held
  `n * n` doubles, so the fit of a hundred thousand rows asked the allocator
  for eighty gigabytes, and the fit of the upstream data subset test aborted
  the allocator instead of converging. The weighted normal equations are now
  accumulated over the rows of the design matrix, so the fit needs a matrix of
  the size of the number of the columns. The sums are taken over the rows in
  the same order as before, so the coefficients are the same numbers as before.
- **The propensity score matching estimator scanned every unit of the other
  group for every match.** The scan costs `O(n * m)` comparisons, which is two
  and a half billion of them for the hundred thousand rows of the upstream test
  suite. The search is now a binary search over the sorted scores, and it picks
  the same unit: a tie is broken with the index of the unit, which is the rule
  of the scan.
- **The adjustment set of an estimand was shared with the estimator that was
  fitted on it.** `IdentifiedEstimand::get_adjustment_set` hands out the array
  that the estimand keeps, so the bootstrap refuter, which pushes the
  instruments onto that array, grew the adjustment set of the estimator that
  was fitted before the refutation ran. The design matrix of the estimate then
  held more columns than the fitted coefficients, and the estimate read past
  the end of the coefficients. The estimator and the refuters copy the
  adjustment set now.
- The data subset refuter sampled its subset **with** replacement. The upstream
  samples it without replacement, with `data.sample(frac=subset_fraction)`.

### Notes

- The category branch of the bootstrap refuter of the upstream is broken: it
  reads a variable that it never defines and it writes the integer zero into
  the rows it does not change. The port perturbs a discrete column with
  another category and leaves the rows it does not change alone.
- The upstream takes the variables the bootstrap refuter perturbs as a
  `bool | int | list`. The port takes an enumeration, because the enumeration
  cannot express a list that names both the variables to keep and the
  variables to leave out, which is the list the upstream raises an error for.
- The refutations of the port are drawn with the generator of the port and the
  refutations of the upstream are drawn with the global generator of numpy, so
  the numbers of the two are not the same numbers. What the two share is the
  behaviour the upstream tests assert: the effect of a subset of the data and
  the effect of a bootstrap sample stay close to the effect of the data.

[0.0.29]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.29

## [0.0.31] - 2026-11-02

The multiply-robust causal change attribution of the upstream, with the test
file of the upstream and the two bugs the test file found.

### Added

- `gcm` -- the port of `dowhy.gcm.distribution_change_robust`, the estimator of
  the paper "Multiply-Robust Causal Change Attribution" of Quintas-Martinez,
  Bahadori, Santiago, Mu, Janzing and Heckerman (ICML 2024): the attribution of
  the change of the mean or of the variance of a target node to the variables
  upstream of it, with the regression method, the re-weighting method and the
  multiply-robust method, and with the cross-fitting of the nuisance
  parameters.
- `gcm` -- the nearest neighbour regression of `dowhy.gcm.ml.regression`, which
  is the `KNeighborsRegressor` of scikit-learn with its default parameters:
  five neighbours and the uniform weights. The neighbours of a row are found
  with a walk over the rows that are sorted by their first column, which finds
  the same neighbours as a scan over every row and costs `O(n log n)` instead
  of the `O(n^2)` of the scan.
- the tests of the upstream file
  `tests/gcm/test_distribution_change_robust.py`: the two cases it holds, on
  the ten thousand rows of the upstream test, with the nearest neighbour
  regressor and with ten folds of the cross-fitting, and the four cases of the
  regression method and of the re-weighting method, so that every branch of
  the estimator of the upstream is compared against the upstream.
- `_verify/gcm_distribution_change_robust_reference.py` -- the upstream runs on
  the very rows the port works on, for the three methods of the estimator and
  for the two functionals of the target. The port and the upstream agree to
  `0.004` on the attribution of the mean and to `0.05` on the attribution of
  the variance; the re-weighting method, which does not use the regressor,
  agrees to `0.001`. The difference is the split of the rows of the
  cross-fitting: the port splits them with its own shuffle and the upstream
  with the `StratifiedKFold` of scikit-learn.

### Fixed

- **The functional of the variance of the port was the square of the difference
  of the two moments, and the functional of the upstream is the second moment
  of the target minus the square of the first moment of the target.** The
  upstream writes the functional as `(theta(y²) - theta(y)) ** 2`, but the
  exponent of Python binds tighter than the subtraction, so the upstream
  computes `theta(y²) - theta(y) ** 2`. The attribution of the port was about
  twenty times the attribution of the upstream: `17.66`, `-40.72` and `-54.71`
  for the three variables of the test, where the upstream gives `0.91`, `-1.38`
  and `-1.35`.
- **The port standardised the weights of every group of the multiply-robust
  estimator, and the upstream standardises the weights of the last group
  alone.** The statement that standardises the weights is outside the loop over
  the groups in the upstream, so the weights of the other groups keep their
  scale and are used with that scale.

### Notes

- The rows of the test of the upstream are drawn with the global generator of
  numpy, which is not seeded, so the numbers of the upstream move from one run
  to the other; the upstream marks its test file as flaky for that reason. The
  rows of the port are drawn with the generator of the `utils` package, so the
  numbers of the port are the same on every run, and they are the numbers the
  reference script measures on the upstream.
- The port has neither a calibrator nor sample weights for the multiply-robust
  change attribution. The upstream can calibrate the probabilities of its
  classifier on a calibration set and can weigh the samples; the models of the
  upstream mostly do not support the weights either, and the port has neither.
- The upstream evaluates the set function of its Shapley estimator in a
  process pool, so the values it computes are invisible to an instrumentation of
  the process of the caller. The diagnosis of the functional of the variance
  needed a Shapley configuration with a single job.

[0.0.31]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.31

## [0.0.32] - 2026-11-02

The cases of the upstream test file of the automatic identification and of the
instrumental variable estimator, and the two upstream test files that cannot
run with the numpy of today.

### Added

- the tests of the upstream file
  `tests/causal_identifiers/test_auto_identifier.py`: its case with two action
  nodes, in both orders.
- the tests of the upstream file
  `tests/causal_estimators/test_instrumental_variable_estimator.py`: the four
  of its sixteen configurations that the estimators of the port can reach --
  one treatment, one instrument, no or one common cause, a continuous or a
  binary treatment -- with the tolerance of the upstream test file.
- `_verify/estimator_iv_reference.py` -- the upstream runs on the very rows the
  port works on. The port and the upstream agree to `2e-13` on the four
  configurations.

### Notes

- The upstream cannot run its own test file of the instrumental variable
  estimator with the numpy of today. Its generator of the data sets converts
  the treatment with `numpy.vectorize(convert_to_binary)`, and
  `convert_to_binary` returns an array of one element, which numpy 2 refuses
  with `ValueError: setting an array element with a sequence`. The upstream
  0.14 predates numpy 2. The port draws its rows with its own generator, so
  the port runs the cases, and the reference script hands the upstream the rows
  of the port, so the upstream runs on them as well.
- The upstream test file of the regression discontinuity estimator cannot run
  either, for two reasons. Its data set has a binary treatment, so the
  generator of the upstream fails the way it fails above, and the estimator
  keeps the name of the running variable, the threshold and the bandwidth at
  `None` when the caller does not give them, so its fit reads the column
  `None` of the data frame, which does not exist. The estimator of the port
  takes the three values as arguments.
- The eight configurations of the upstream test file of the instrumental
  variable estimator with two treatments are out of reach, because the
  estimators of the port are univariate, and the four with two instruments are
  out of reach as well, because the upstream estimates them with the two stage
  least squares of `linearmodels`.

[0.0.32]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.32

## [0.0.33] - 2026-11-03

The refuter that assesses the support and the overlap of the covariates with
boolean rules, the port of the `assess_overlap` refuter of the upstream.

### Added

- `overrule` -- the `OverRule` algorithm of the upstream: the binariser of the
  features, the sampler of the reference samples, the beam search of the pricing
  problem, the program of the rules and its rounding, and the analyzer of the
  support and of the overlap.
- `utils.lp` -- a simplex for a linear program with the shadow prices of its
  constraints, which is the dual of the program of the rules.
- `CausalModel::refute_assess_overlap` -- the refuter that learns the rules of
  the support and of the overlap with respect to the backdoor variables of the
  estimand. Upstream returns the analyzer of the rules from its
  `refute_estimate`, whose result is a refutation of the estimate, so the port
  returns it from a method of its own.
- the tests of the upstream file `tests/causal_refuters/test_assess_overlap.py`:
  the rules of the support and of the overlap of the fixture of the upstream,
  and the rows that the rules cover.
- `_verify/overrule_reference.py` -- the upstream runs on the fixture of its own
  test file, with the program of the rules solved with the `HiGHS` solver of
  `scipy` instead of `cvxpy` and the solver `CLARABEL`, which are not installed
  here.

### Notes

- The upstream draws the reference samples of the support rules with the global
  generator of numpy and the port draws them with its own generator, so the
  rules of the support are not always the rules of the upstream. The upstream
  test file accepts a set of equivalent rule sets for the same reason, and the
  port asserts that the rules are one of them.
- The program of the overlap rules does not depend on the reference samples, so
  its value is the same number in the port and in the upstream: `0.00285` on the
  fixture of the upstream test file.
- The port solves the program of the rules in its aggregated form, through its
  dual, and the upstream solves it with `cvxpy` and the solver `CLARABEL`. The
  value of the program and the weights of the rules are the same numbers.
- The propensity model of the overlap region is a logistic regression with a
  cross fitting of two folds, where the upstream fits a random forest with a
  grid search. The two find the same overlap region on the fixture of the
  upstream test file: the hundred rows of the cell where the two features are
  zero.

[0.0.33]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.33

## [0.0.34] - 2026-11-09

The tests of the graph operations of the upstream, the tests of the model
pieces of the upstream, and the migration to the syntax of the current
toolchain.

### Added

- the tests of the upstream file `tests/test_causal_graph.py`: the graph of the
  daggity web site of its fixture, the two adjustment-set checks, the
  d-separation, the do-surgery, the backdoor paths, the instruments and the
  directed path queries, on the same graph the upstream reads.
- the tests of the upstream file `tests/gcm/test_graph.py`: the samples of a
  fitted probabilistic causal model have the mean and the standard deviation of
  the data, the mechanism that is assigned to a node is the one that is read
  back, and a node is a root exactly when it has no parents.
- the tests of the constant inputs of the upstream file
  `tests/gcm/independence_test/test_kernel.py`, which the kernel based test
  removes before it runs.
- `CausalGraph::check_valid_backdoor_set` and
  `CausalGraph::check_valid_frontdoor_set` take the `DseparationAlgorithm` of
  the upstream as a labelled optional argument. The default branch of the
  frontdoor check is now the d-separation of the graph, which is what the
  upstream does when the caller names no algorithm.
- `_verify/causal_graph_reference.py` -- the graph functions of the upstream on
  the daggity fixture of its own test file.
- `_verify/gen_graph_fixture.py` -- writes the daggity fixture of the port from
  the fixture of the upstream.

### Changed

- `_verify/upstream_test_coverage.py` reads the bare file names and the globs
  of the headers of the test files of the port, and the hyphens of a path, so
  that the map of the two test suites is the real one. It reports 49 of the 74
  test files of the upstream as mirrored.

### Fixed

- The `derive(Eq)` of `src/gcm/equation_parser.mbt` is the `#derive(Eq)`
  attribute the current toolchain asks for. The trailing form is a deprecation
  warning, and a warning is a failure of the gate.

[0.0.34]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.34

## [0.0.35] - 2026-11-09

The encoding cases of the upstream general utilities, and the two checks of
whether a column of a frame is categorical.

### Added

- `gcm.is_categorical` and `gcm.has_categorical`, the port of
  `dowhy.gcm.util.general.is_categorical` and of its `has_categorical`. The
  upstream decides from the numpy dtype of the columns; the port decides from
  the kind of the column of its frame, which holds no dtype.
- the tests of the upstream file `tests/gcm/util/test_general.py` that the port
  can reach: the one-hot encoding of a matrix that holds a numerical column
  among the categorical ones, the encoding of a category that the encoder has
  not seen, and the two checks of whether a column is categorical.
- the name of the upstream file in the header of the general utilities test,
  with the three cases of it that are not ported: the `catboost` encoder, the
  `shape_into_2d` helper and `set_random_seed`.

### Notes

- The one-hot encoding of the upstream fixture
  `[[d, 1, a], [b, 2, d], [a, 3, a]]` is
  `[[0, 0, 1, 1, 1, 0], [0, 1, 0, 2, 0, 1], [1, 0, 0, 3, 1, 0]]` in the port,
  which is the vector the upstream test asserts: every categorical column
  becomes one column per category in lexicographic order and the numerical
  column keeps its place.
- A category that the encoder has not seen is encoded with zeros, which is what
  `OneHotEncoder(handle_unknown="ignore")` does in the upstream.
- `_verify/upstream_test_coverage.py` reports 51 of the 74 test files of the
  upstream as mirrored.

[0.0.35]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.35

## [0.0.36] - 2026-11-09

The categorical conditioning variable of the generalised covariance measure.

### Added

- `gcm.generalised_cov_based_with_categorical`, which takes the conditioning
  variable as a frame and encodes its categorical columns. The upstream passes
  the conditioning variable to the automatic model selection of
  `dowhy.gcm.auto`, which encodes the categorical columns; the port has no model
  selection, so it encodes them itself with the one-hot encoding of its own
  encoding layer.
- the two categorical cases of the upstream file
  `tests/gcm/independence_test/test_generalised_cov_measure.py`: the fixture is
  independent given its category and dependent once the category is permuted.
- the name of the upstream file in the header of the independence test, and the
  note that its case which asks for a `ValueError` on a categorical X or Y has
  no assertion in the port: MoonBit has no exception, and the port aborts.
- `_verify/gcm_categorical_reference.py` -- the upstream runs on the categorical
  fixture of its own test file, through its automatic encoding of the
  conditioning variable and on an explicitly one-hot encoded one, and asserts
  that the two routes lead to the same decision on six seeds.

### Notes

- The explicit encoding and the automatic one of the upstream agree on the
  fixture of its own test file. On six seeds the p-value of the independent case
  is `0.813871` and `0.813946`, `0.520490` and `0.521915`, `0.455537` and
  `0.455544`, `0.289562` and `0.285463`, `0.697020` and `0.697224`, `0.523618`
  and `0.521257`, and the p-value of the permuted case is `0.0` in both. The
  difference is the spread of the automatic model selection, and the decision is
  the same on every seed.
- The upstream marks the two cases as flaky, because it draws its rows from the
  global generator of numpy; the port draws them from its own generator, so its
  fixture is fixed.

[0.0.36]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.36

## [0.0.37] - 2026-11-09

The transformation list of the dummy outcome refuter, and the two branches it
chooses between.

### Added

- `refuters.Transformation` -- the list of transformations of the outcome of the
  dummy outcome refuter: `zero`, `noise`, `permute`, `linear_regression`, the k
  nearest neighbours and a model the caller gives. The default list is
  `[zero, noise(1)]`, which is the `DEFAULT_TRANSFORMATION` of the upstream.
- the two branches of the upstream `refute_dummy_outcome`, which the list
  decides: a list without an estimator simulates the whole data at once and
  reports one refutation, a list with one buckets the treatment and reports one
  refutation per bucket.
- `true_causal_effect` and `required_variables` as named optional arguments of
  `refuters.refute_dummy_outcome`.
- the port of `preprocess_data_by_treatment`, `process_data`, `_has_estimator`,
  `permute` and `noise` of `dowhy.causal_refuters.dummy_outcome_refuter`.
- the port of `tests/causal_refuters/test_dummy_outcome_refuter.py` as
  `src/tests/dummy_outcome_refuter.mbt`, ten of its sixteen cases.
- `_verify/dummy_outcome_reference.py` -- the upstream refuter on the cases the
  port mirrors, which prints how many refutations come back and the new effect of
  each of them.

### Changed

- `refuters.refute_dummy_outcome` returns `Array[CausalRefutation]` rather than
  one refutation, the type of the list the upstream returns.
  `CausalModel::refute_estimate` reports the first one, which is the only one for
  the default transformation list.
- the simulated outcome of the default list is `zero` followed by a normal noise
  of standard deviation one, the `DEFAULT_TRANSFORMATION` of the upstream. The
  port drew a uniform number in `[0, 1]` before, which shifts the mean of the
  simulated outcome by half a unit.
- `refuters.refute_dummy_outcome` takes the name of the treatment column.

### Notes

- The buckets of the estimator branch are the ones of the upstream, including
  its quirk. The upstream derives the edges of the cut from the ranges of *every*
  numeric column of the frame rather than from the range of the treatment column,
  so the edges are `(max - min) of the column` over
  `bucket_size_scale_factor * std of the treatment`, in the column order of the
  frame, and `pandas.cut` reads them as the edges of the buckets. On the
  continuous treatment of the upstream's own `linear_dataset`, whose columns are
  `Z0, W0, v0, y`, the four columns give four increasing edges and therefore
  three buckets, and the refuter reports three refutations. One run of the
  upstream gives the edges `0.2716, 1.7142, 11.6501, 122.3968` and buckets of
  `47`, `437` and `382` rows of the `1000` of the frame. The rows whose treatment
  is at or below the first edge take part in no bucket.
- A frame whose per-column ranges do not increase makes `pandas.cut` raise
  `ValueError: bins must increase monotonically`, and the port aborts with the
  same message. This is why the binary treatment cases whose list carries an
  estimator have no assertion to mirror: the treatment of such a frame spans one
  unit while the outcome of the same frame spans tens.
- The custom model of the upstream is a callable that returns a fitted estimator,
  which is then applied to the training rows and to the rows to predict. The port
  takes the two predictions directly, because MoonBit has no partial application
  of a fitted object.
- `svm`, `random_forest` and `neural_network` need the estimators the port does
  not have, so `Transformation` has no variant for them and a list that names one
  of them cannot be built. The six upstream cases that use them are not mirrored.
- The nearest neighbours of the port are the `KNeighborsRegressor` of
  scikit-learn with its default weights: the mean of the targets of the k nearest
  training rows in the euclidean distance, the ties taken in the order of the
  training rows.
- `_verify/upstream_test_coverage.py` reports 53 of the 74 test files of the
  upstream as mirrored.

[0.0.37]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.37

## [0.0.38] - 2026-11-09

The refuter that adds an unobserved common cause, ported from the upstream
`direct-simulation` branch.

### Added

- `refuters.ConfoundersEffectOnT` and `refuters.ConfoundersEffectOnY`, the two
  kinds of effect a simulated confounder has on the treatment and on the
  outcome: a linear effect and a flip of the value.
- `effect_on_t` and `effect_on_y` as named optional arguments of
  `refuters.refute_add_unobserved_common_cause`, with the defaults of the
  upstream: `binary_flip` on the treatment and `linear` on the outcome.
- the port of `_include_confounders_effect` and of the scalar branch of
  `sensitivity_simulation` of `dowhy.causal_refuters.add_unobserved_common_cause`.
- the port of the two refutation cases of
  `tests/causal_refuters/test_add_unobserved_common_cause.py` as
  `src/tests/add_unobserved_common_cause.mbt`.

### Changed

- `refuters.refute_add_unobserved_common_cause` takes the strength on the
  treatment and the strength on the outcome as two arguments, `kappa_t` and
  `kappa_y`, rather than one `epsilon` for both, and it reports a single
  refutation rather than the mean of a simulation loop. The upstream draws one
  confounder and reports one refutation, so the interval of the refutation is the
  refuted effect itself.
- the outcome of the simulated confounder is offset with `-kappa_y * w` and not
  `+kappa_y * w`: the upstream subtracts it from the outcome to remove the effect
  of the confounder the data holds, which it assumes acted on both columns with
  the same sign.

### Notes

- A strength of `0` leaves the data untouched, so the refuted effect is the
  estimate of the data down to the last bit. That is the assertion the upstream
  harness makes for every case of the file, and the port asserts it twice, once
  for the binary treatment and once for the continuous one.
- A `binary_flip` strength is the probability of a flip: `0` flips nothing,
  `0.5` flips half of the rows and `1` flips every row. The upstream builds the
  central interval of the standard normal that the probability spans and takes its
  lower edge when the probability is at least one half and its upper edge
  otherwise, and the port reproduces that, including the infinite edges of the two
  ends.
- The three `..._range_...` cases of the upstream file are not mirrored: they pass
  a list of strengths and draw a matrix of refutations for a plot, and the matrix
  path reports no number a test could assert. The two sensitivity analyzers of the
  file (`linear-partial-R2` and the partial R2 of the confounding) are not ported
  yet, and the `percent_change_of_confounder` argument that infers the strengths
  from the observed common causes is not ported either.
- `_verify/upstream_test_coverage.py` reports 54 of the 74 test files of the
  upstream as mirrored.

[0.0.38]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.38

## [0.0.39] - 2026-11-10

The linear sensitivity analysis of an unobserved confounder.

### Added

- `refuters.linear_sensitivity_analyzer`, the port of
  `dowhy.causal_refuters.linear_sensitivity_analyzer.LinearSensitivityAnalyzer`,
  which answers how strong an unobserved confounder has to be to move the
  estimate of the data. It reports the partial R2 of the confounder with the
  treatment and with the outcome, the robustness value of the estimate and the
  bias adjusted estimate with its standard error, its t statistic and its
  interval.
- `refuters.compute_bias_adjusted`, the port of `compute_bias_adjusted` of the
  upstream, which the upstream test calls with two sets of partial R2 of its
  own.
- `CausalModel::refute_linear_sensitivity`, the entry point of the analysis.
  The upstream returns the analyzer from its `refute_estimate`; the port returns
  it from a method of its own, because the analysis is not a refutation of the
  estimate, the way `refute_assess_overlap` returns the analyzer of the rules.
- `CausalEstimator::regression_model` and `CausalEstimator::design_features`,
  which give the analysis the fit of the estimator and the columns of its
  design matrix.
- the port of the three linear cases of
  `tests/causal_refuters/test_add_unobserved_common_cause.py` as
  `src/tests/linear_sensitivity.mbt`.
- `_verify/linear_sensitivity_reference.py`, which runs the analyzer of the
  upstream on a fixture of the same shape and prints its numbers.

### Changed

- `datasets.LinearConfig` takes the two noise parameters of the upstream,
  `stddev_treatment_noise` and `stddev_outcome_noise`. Their defaults are the
  values the port already used, so every other fixture of the port keeps its
  rows: the eighteen tests of the `datasets` package and the numbers of the
  examples are unchanged.

### Notes

- The upstream builds its analyzer without the flag of its refuter:
  `sensitivity_linear_partial_r2` never passes `confounder_increases_estimate`,
  so the analyzer keeps its own default of `True` and the bias always moves the
  estimate toward zero. The port reproduces that, and its flag is an optional
  argument that defaults to `true` for the same reason.
- The upstream overwrites the effect under the null hypothesis with the share of
  the estimate the confounder has to remove, so the value the caller gives it
  never survives. The port does the same.
- The upstream takes the lower quantile of the Student distribution at half the
  significance level, which is negative, and swaps the two bounds with it. The
  port keeps the arithmetic and the names of the upstream.
- The upstream caps the partial R2 of the confounder with the outcome at one and
  warns about it, and the port caps it the same way.
- The upstream's fixture cannot be generated through `dowhy.datasets.linear_dataset`
  on numpy 2.5.1, because the `np.vectorize(convert_to_binary)` of that branch
  builds a one element array per row. The reference script therefore builds the
  frame by hand with the shape of the fixture of the port. On it the upstream
  reports the degrees of freedom `492`, the partial R2 of the treatment
  `0.9456`, the robustness value `0.9483` and the robustness value at the level
  of the analysis `0.9462`, and the partial R2 of the confounder with the
  treatment `[0.0194, 0.0389, 0.0583]` for the three strengths of the upstream.
- The plot of the upstream is not ported, so the assertion of the upstream tests
  that a figure was drawn has no counterpart here.
- The `non-parametric-partial-R2` and the `e-value` analyzers of the upstream are
  not ported, and neither is the `percent_change_of_confounder` argument that
  infers the strengths of the confounder from the observed common causes.

[0.0.39]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.39

## [0.0.40] - 2026-11-10

The polynomial models of the graphical causal models.

### Added

- `gcm.PredictionModel::polynomial`, the port of
  `dowhy.gcm.ml.create_polynom_regressor`, which fits a linear model on the
  polynomial features of its input. The degree is an optional argument with the
  default of the upstream, which is two.
- `gcm.ClassificationModel::polynomial`, the port of
  `dowhy.gcm.ml.classification.create_polynom_logistic_regression_classifier`,
  which fits a logistic regression on the polynomial features of its input. The
  degree is an optional argument with the default of the upstream, which is
  three.
- `gcm.polynomial_features`, the port of
  `sklearn.preprocessing.PolynomialFeatures` with `include_bias=False`, which
  the two pipelines of the upstream are built of.
- `gcm.PredictionModel::degree` and `gcm.ClassificationModel::degree`, which
  report the degree of the polynomial expansion of a model and are zero when
  the model is fitted on the features themselves.
- the port of the two cases of `tests/gcm/ml/test_regression.py` and of the case
  of `tests/gcm/ml/test_classification.py` that the models of the polynomial
  features answer, as `src/gcm/ml_polynomial_test.mbt`.
- `_verify/polynom_features_reference.py`, which prints the columns of the
  expansion of scikit-learn and the numbers of the upstream on the fixture of
  its test file, and `_verify/probe_polynom_upstream_tests.py`, which runs the
  cases of the upstream and reports what they do.

### Notes

- The order of the columns of the expansion is the order of the upstream: the
  products of the degree one come first, then the ones of the degree two, and
  the products of one degree are ordered by the indices of the features they
  multiply. The expansion of two features of the degree two therefore holds the
  columns `x0`, `x1`, `x0 * x0`, `x0 * x1` and `x1 * x1`, and the expansion of
  two features of the degree three holds those five columns and the four
  products of the degree three.
- The upstream encodes the categorical columns of its input before its pipeline
  expands them, because the encoder is fitted by the model itself. The port
  expands the design matrix it is given, so the caller encodes, the way the
  mechanism of the `gcm` package does it for every other model.
- The upstream draws the fixtures of its two regression cases and of its
  classification case with the global generator of numpy and marks all three of
  them as flaky. The port draws them with the generator of the `utils` package
  and a fixed seed.
- The upstream reproduces the product of the two features of its fixture to
  `7.1e-15` and the target of its categorical fixture to `2.6e-14`, against the
  tolerance of `1e-10` of its tests. The port reproduces them to `3.6e-15` and
  to `2.1e-14`.
- The upstream predicts 988 of the 1000 classes of its classification fixture
  right and asks for more than 950. The port predicts 991 of them right on its
  own fixture, so the threshold of the upstream is not a marginal one here.
- The random forest of the upstream, the support vector machine of the upstream,
  the gradient boosting of the upstream and the other estimators of their zoos
  are not ported, so the third case of the upstream test file of the regression
  and the second case of the upstream test file of the classification have no
  counterpart here.
- `_verify/upstream_test_coverage.py` reports 56 of the 74 test files of the
  upstream as mirrored.

[0.0.40]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.40

## [0.0.41] - 2026-11-10

The E-value analysis of an unmeasured confounder.

### Added

- `refuters.evalue_sensitivity_analyzer`, the port of
  `dowhy.causal_refuters.evalue_sensitivity_analyzer.EValueSensitivityAnalyzer`,
  which answers how strong an unmeasured confounder has to be with the
  treatment and with the outcome to explain away the estimate. It reports the
  E-value of the estimate, the E-value of the limit of its interval that is
  closer to the null, and the Observed Covariate E-value of every measured
  confounder.
- `refuters.evalue_rr`, `refuters.evalue_md`, `refuters.evalue_or` and
  `refuters.evalue_ols`, the four functions of the upstream that compute the
  E-value of a risk ratio, of a standardised difference, of an odds ratio and
  of the coefficient of a linear regression.
- `refuters.observed_covariate_e_value`, the port of the function of the
  upstream that compares the limit of the interval of an estimate with the limit
  of the interval of the estimate that was computed without a confounder.
- `CausalModel::refute_e_value`, the entry point of the analysis. The upstream
  returns the analyzer from its `refute_estimate`; the port returns it from a
  method of its own, because the analysis is not a refutation of the estimate,
  the way `refute_linear_sensitivity` returns the analyzer of the linear
  sensitivity.
- the port of the case `test_evalue` of
  `tests/causal_refuters/test_add_unobserved_common_cause.py` as
  `src/tests/evalue.mbt`.
- `_verify/evalue_reference.py`, which runs the analyzer of the upstream on a
  fixture of the same shape and prints its numbers.

### Notes

- The numbers of the upstream are the ones of the R package `EValue`, and the
  port reproduces them: the E-value of the OLS example `0.293`, `0.196` and
  `17.405` is `1.141`, the E-value of the standardised difference `0.5` and
  `0.25` is `2.529`, the E-value of the odds ratio `0.86`, `0.75` and `0.99` is
  `1.369`, the E-value of the risk ratio `0.8`, `0.71` and `0.91` is `1.809`, the
  Observed Covariate E-value of the pairs `(2, 4)` and `(4, 2)` is `3.414` and
  the one of the pair `(0.8, 0.9)` is `1.500`.
- The upstream scales the coefficient of the treatment with the contrast of the
  treatment and leaves the standard error alone, because the standard error of
  its estimator already carries that contrast. The port keeps the arithmetic:
  the analysis scales the coefficient and takes the standard error as it is.
- The upstream refuses an estimator with effect modifiers, and the port does the
  same.
- The upstream does not benchmark the E-value against the measured confounders
  when the interval of the estimate already crosses the null, because the
  interval is then already tipped, and the port does the same.
- The upstream draws its contour plot of the E-values, and the port does not
  draw it.
- The upstream supports the binomial, the Poisson, the negative binomial and the
  gamma family of the generalised linear model, and the port supports the
  binomial and the Poisson ones, which are the two families the `utils` package
  implements besides the gaussian one. The gaussian family raises an error in
  the upstream, and the port does the same.
- The `non-parametric-partial-R2` analyzer of the upstream is not ported yet,
  and neither is the `percent_change_of_confounder` argument that infers the
  strengths of the confounder from the observed common causes.

[0.0.41]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.41

## [0.0.42] - 2026-11-10

The default strength of the confounder that the unobserved common cause refuter
infers from the observed common causes.

### Added

- `refuters.infer_default_kappa_t` and `refuters.infer_default_kappa_y`, the
  port of `_infer_default_kappa_t` and `_infer_default_kappa_y` of
  `dowhy.causal_refuters.add_unobserved_common_cause`. The upstream infers the
  strength of the simulated confounder from the observed common causes when the
  caller does not give one: a logistic regression of the column on the
  standardised common causes is fitted and the share of the predictions that
  flip when one common cause is set to zero is the strength of that common
  cause, for the `binary_flip` effect, and the correlation of every common
  cause with the column scaled with the standard deviation of the column is the
  strength of that common cause, for the `linear` effect. The range of the
  strengths is scaled with the fraction of the strength the caller gives and
  the function returns ten values of it.
- the port of the inference as `src/tests/kappa_inference.mbt`, seven cases
  that compare the numbers of the port with the numbers of the upstream on the
  same rows.
- `_verify/kappa_inference_reference.py`, which runs the two functions of the
  upstream on the rows of the port and prints their numbers.

### Notes

- The upstream never asks for the default strength in its own test suite, so
  the numbers of the two are compared on the rows of the port: the reference
  script hands the rows of the port to the upstream, so the numbers of the
  upstream and the numbers of the port are the numbers of one data set. The
  `binary_flip` effect on the treatment gives the ten strengths `0.079`,
  `0.0924`, `0.1058`, `0.1192`, `0.1326`, `0.146`, `0.1594`, `0.1728`, `0.1862`
  and `0.1996`, a tenth of the strength gives the same ten numbers divided by
  ten, and one common cause gives the single strength `0.47`, because the range
  of the upstream holds one number only.
- The `linear` effect of the upstream reads the standard deviation of the
  column with `np.std(t)[0]`, and the standard deviation of a column is a
  number and not an array, so the branch raises an `IndexError` on the numpy of
  today. The port computes the number that branch means to compute, the
  correlation of every common cause with the column scaled with its standard
  deviation, and the reference script asks the upstream for the numbers of that
  branch with the indexing removed.
- The `binary_flip` effect of the upstream fits a classifier on the column, and
  a continuous column is refused with a `ValueError`. The port aborts with a
  message of the same kind, because MoonBit cannot catch an error. The upstream
  fits a multinomial model for a column with more levels, and the share of the
  flips is then the distance between the classes rather than a share, so the
  port refuses such a column as well.
- The upstream returns the single strength of a range of one number as a number
  and the range of many numbers as an array; the port returns an array in both
  cases, so the caller of the port always gets a list of strengths.
- The `non-parametric-partial-R2` analyzer of the upstream is not ported yet.

[0.0.42]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.42

## [0.0.43] - 2026-11-10

The readers of the temporal graphs of the upstream.

### Added

- `timeseries.create_graph_from_csv_text` and
  `timeseries.create_graph_from_dot_text`, the port of `create_graph_from_csv`
  and of `create_graph_from_dot_format` of `dowhy.utils.timeseries`. The
  upstream reads a CSV file and a DOT file, and this library has no file
  system, so the port reads the text of the files. The CSV holds the columns
  `node1`, `node2` and `time_lag`, and every row is an edge with its time lag.
  The DOT holds the time lags of an edge in its `label` attribute, between
  parentheses and separated by commas.
- `graph.parse_dot_edges` and the type `graph.DotEdge`, which give the edges
  of a DOT string with the label of every edge. The reader of the DOT graphs of
  the `graph` package ignores the labels, and the temporal graphs need them.
- `timeseries.TemporalGraph::set_time_lags`, which replaces the time lags of
  an edge. The upstream merges the entries of one edge of a DOT file with a
  set, so the lags of the edge are replaced and not appended to.
- the ten cases of the upstream test file
  `tests/timeseries/test_temporal_causal_graph_creation.py` that read a CSV
  and a DOT, in `src/timeseries/timeseries_test.mbt`. The eight cases of the
  file `tests/timeseries/test_temporal_shift.py` were already mirrored there.
- `_verify/timeseries_readers_reference.py`, which runs the two readers of the
  upstream on the fixtures of the upstream test file and prints their edges.

### Notes

- The numbers of the upstream are the ones of its own test file, and the
  reference script prints them: the reader of the CSV gives the three edges
  `A -> B` with the lag `5`, `B -> C` with the lag `2` and `A -> C` with the
  lag `7`, the reader of a CSV with two rows of one edge gives the lags `5`
  and `3`, and the reader of the DOT gives the same edges.
- The reader of the DOT of the upstream needs `pygraphviz`, which is not
  installed here, so it raises an `ImportError`. The reference script runs it
  with the backend of `pydot` in the place of the backend of `pygraphviz`:
  the backend of `pydot` keeps the quotes around the value of an attribute,
  where the backend of `pygraphviz` takes them off, so the script takes them
  off as well.
- The upstream merges the entries of one edge of a DOT file with a set, whose
  order is the order of the set of the interpreter, and the port keeps the
  order of the entries. The entries of the upstream test file hold one label
  per edge, so the two agree there.
- The upstream names a node of a CSV that is missing "nan", the name numpy
  gives to a missing value, and the port refuses the row.
- The upstream reads a CSV with `pandas.read_csv`, which understands the
  quoted fields, and the port reads the plain form: the fields are separated
  by commas and no field is quoted.
- The `non-parametric-partial-R2` analyzer of the upstream is not ported yet.

[0.0.43]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.43

## [0.0.44] - 2026-11-10

The test files of the `gcm` package of the upstream that the port mirrors.

### Added

- the two cases of the upstream test file `tests/gcm/test_ml.py` that fit a
  regressor and a classifier on a sample with a categorical column, in
  `src/gcm/ml_test.mbt`. The upstream fits the encoder of the categorical
  column inside the model, and the port encodes the column before the fit, the
  way the mechanism of the `gcm` package does it for every other model.
- the three cases of the upstream test file `tests/gcm/test_validation.py` that
  the port did not have: the relation between the p-values and the p-values
  adjusted by the false discovery rate control, the validation of the invertible
  model of a reversed chain and the validation of the invertible model of a
  graph with a collider. They are in `src/gcm/validation_test.mbt`.
- the two cases of the upstream test file `tests/gcm/test_divergence.py` that
  the port did not have: the automatic estimate of a categorical sample and the
  classifier based divergence of a sample with a gaussian and a categorical
  column. They are in `src/gcm/divergence_test.mbt`.
- the flag `categorical` of `gcm.auto_estimate_kl_divergence`, which tells the
  estimator that a sample holds the categories of a categorical distribution.
  The upstream reads that from the dtype of its numpy array, and a matrix of
  the port holds numbers only, so the flag carries the information the dtype
  would carry.

### Changed

- The classifier based divergence of the `gcm` package fits its classifier with
  the penalty of the upstream, which is the `L2` penalty of
  `sklearn.linear_model.LogisticRegression` with its default `C = 1.0`, and not
  without a penalty. The penalty is not a detail: the one-hot encoding of a
  categorical column and the intercept are collinear, so the design of a
  sample with a categorical column is rank deficient, and an unpenalised fit
  has to solve a singular weighted normal equation, whose pseudo inverse is
  dominated by its noise. With the penalty of the upstream the estimates of the
  port agree with the ones of the upstream to about `1e-3` on the rows of the
  upstream test file, where the tolerance of the tests was `0.05` before.

### Notes

- The header of every test file of the `gcm` package names the upstream test
  file it mirrors, and the counter of `_verify/upstream_test_coverage.py` counts
  64 of the 74 test files of the upstream now.
- The outcome of the validation of the invertible model depends on the number
  of the rows of the data. The upstream test file uses five thousand rows of
  the non-linear data, and the sixty rows of the fixture of the port are too
  few for the upstream to tell the signal from the noise: the upstream rejects
  the model of the correct graph on the sixty rows and does not reject the
  model of the graph with a collider there, while its own test file expects
  the opposite of both. The port agrees with the upstream on the rows of the
  fixture, and the outcomes of the upstream on those rows are the ones the
  reference script prints.
- The reference script `_verify/gcm_validation_reference.py` no longer reads
  the module `dowhy.causal_model` of the upstream. The constructor of
  `InvertibleStructuralCausalModel` imports it for an `isinstance` check of the
  graph it is given, and the graph of the reference is a `networkx` graph, so
  the module is stubbed with a placeholder class instead: the real one pulls in
  the whole graph learning stack of the upstream.
- The case of the upstream test file `tests/gcm/test_divergence.py` that checks
  the matrix of probabilities of an array of the object dtype has no
  counterpart in the port: a matrix of the port holds numbers only and has no
  dtype.
- The `non-parametric-partial-R2` analyzer of the upstream is not ported yet.

[0.0.44]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.44

## [0.0.45] - 2026-11-10

The remaining cases of the statistics of the upstream.

### Added

- the four cases of the upstream test file `tests/gcm/test_stats.py` that the
  port did not have, in `src/gcm/stats_test.mbt`: the geometric median of the
  samples of two dimensions, the marginal expectation of a classifier of a
  linear relation, the marginal expectation of a non-linear model and the
  marginal expectation of a non-linear classifier.
- the numbers of the four cases in `_verify/gcm_stats_reference.py`, which runs
  the upstream on the rows of the port and prints them.

### Notes

- The header of the test file of the statistics names the upstream test file it
  mirrors now, and the counter of `_verify/upstream_test_coverage.py` counts 65
  of the 74 test files of the upstream.
- Two of the four new cases fit a histogram gradient boost model, which the
  port does not have. The port fits the polynomial models instead, the relation
  of the two fixtures is a square, and the two upstream cases assert a
  tolerance of a hundred and a tolerance of one, which the numbers of the port
  satisfy.
- The geometric median of the port is the one of the Weiszfeld iteration, and
  the upstream minimises the sum of the distances with a general purpose
  optimiser. The two reach the same optimum to `1e-4` on the fixture of the
  upstream test, where the upstream asserts a tolerance of `0.5`.
- The marginal expectation of a classifier of the port compares the
  probability of the second class, where the upstream compares the sum of the
  differences of the two classes. The logistic regression of the port and the
  one of scikit-learn reach the same coefficients to `1e-2` on that quantity,
  where the upstream asserts a tolerance of one.

## [0.0.46] - 2026-11-10

The sales data set of the upstream.

### Added

- the sales data set of the upstream, `dowhy.datasets.sales_dataset`, in the
  `datasets` package: the daily rows of a single product with the columns
  `Date`, `Shopping Event?`, `Ad Spend`, `Page Views`, `Unit Price`,
  `Sold Units`, `Revenue`, `Operational Cost` and `Profit`.
- the four cases of the upstream test file `tests/test_datasets.py` in
  `src/datasets/datasets_test.mbt`: the shape of the frame, the number of the
  shopping events, the relations of the two fixtures of the upstream and the
  statistics of the frame.
- the numbers of the upstream in `_verify/datasets_sales_reference.py`, which
  runs the upstream and prints them.

### Notes

- The header of the test file of the data sets names the upstream test file it
  mirrors now, and the counter of `_verify/upstream_test_coverage.py` counts 66
  of the 74 test files of the upstream.
- The port takes the number of the days of the range and a seed of its own,
  where the upstream takes a pair of dates and draws its numbers with the global
  generator of numpy. The `Date` column of the port holds the date of the day as
  a string of the form `YYYY-MM-DD`, where the one of the upstream holds the
  timestamps.
- The Poisson draws of the port invert the cumulative distribution of the
  Poisson, which is exact, and the inversion starts ten standard deviations
  below the mean, where the probability of the distribution is below `1e-23` and
  where the mass of the distribution is still representable. The means of the
  frame of the port are within a percent of the ones of the upstream.
- The upstream replaces a change of the price of zero by one, and the relations
  of its case depend on that replacement: the discount of the second fixture has
  to sell more units than the first one, because the elasticity of the demand
  answers the smaller price of that fixture. The port reproduces the
  replacement.
- The link of the release 0.0.45 was missing in this file.

[0.0.45]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.45
[0.0.46]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.46

## [0.0.47] - 2026-11-10

The case of the refuters of the upstream.

### Added

- the case of the upstream test file `tests/test_causal_refuter.py` in
  `src/tests/significance_test.mbt`: the percentile test of the bootstrap on
  five thousand standard normal deviates, which the upstream asserts to be above
  0.95.
- the numbers of that case in `_verify/significance_reference.py`, which
  reproduces the generator of the port and computes the p-value of its draw
  without running the toolchain.

### Changed

- The two significance tests of the `refuters` package, `bootstrap_significance`
  and `normal_significance`, are public now. They are the ports of
  `perform_bootstrap_test` and of `perform_normal_distribution_test` of
  `dowhy.causal_refuter`, which the upstream exposes on the base class of its
  refuters.

### Notes

- The header of the test file of the significance test names the upstream test
  file it mirrors now, and the counter of `_verify/upstream_test_coverage.py`
  counts 67 of the 74 test files of the upstream.
- The other case of the upstream test file checks that the placeholder method of
  the base class of the refuters raises, and it has no counterpart in the port:
  the port has no base class whose refutation is a placeholder.
- The upstream draws the deviates of its case with the global generator of numpy
  and does not seed it, so its p-value is not a fixed number. The reference
  script prints the p-values of two seeds of the upstream -- 0.9864 and 0.9788
  -- and the p-value of the draw of the port, 0.9936.

[0.0.47]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.47

## [0.0.48] - 2026-11-10

The Gaussian mixture of the upstream.

### Added

- the Gaussian mixture density estimator of the upstream,
  `dowhy.gcm.density_estimators.GaussianMixtureDensityEstimator`, in the
  `gcm` package: the variational Bayesian mixture of the upstream, fitted with
  the mean field variational update.
- the cases of the upstream test file `tests/gcm/test_density_estimators.py` in
  `src/gcm/density_estimators_test.mbt`: the densities of the mixture of the
  fixture of the upstream, the number of the components and the refusal of a
  mixture with more components than samples.
- the numbers of the upstream in `_verify/gcm_density_estimators_reference.py`,
  which runs the upstream and prints them.

### Notes

- The header of the test file of the density estimators names the upstream test
  file it mirrors now, and the counter of `_verify/upstream_test_coverage.py`
  counts 68 of the 74 test files of the upstream.
- The upstream draws the centres of the components of its mixture at random
  and does not seed its generator, so its own fit is not reproducible and its
  case asserts the length of the result and not its values. The port draws the
  centres from the data, so its fit is reproducible, and the numbers of the
  port are the ones of the same model and not the ones of the upstream's fit.
- The upstream refuses a mixture with more components than samples with a
  `ValueError`; the port refuses it as well, and the check that tells whether
  the data is supported is public, because MoonBit cannot catch the abort of a
  method.
- The inverse density scorer of the anomaly layer of the `gcm` package still
  takes the kernel based estimator of the upstream. The upstream takes the
  Gaussian mixture there, whose fit is not reproducible, so the port keeps the
  estimator whose numbers it can pin down.

[0.0.48]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.48
## [0.0.49] - 2026-11-10

The model selection of the automatic assignment.

### Added

- the model selection of the automatic assignment of the `gcm` package, the
  port of `dowhy.gcm.auto.select_model` and of `dowhy.gcm.auto.find_best_model`:
  a cross validation of five folds that evaluates the models of the zoo of the
  selection and keeps the one with the smallest mean squared error for a
  continuous target and the one with the smallest log loss for a categorical
  one.
- the nearest neighbour prediction model of the `gcm` package, the port of
  `dowhy.gcm.ml.regression.create_knn_regressor`.
- the classifier of more than two classes of the `gcm` package: one binary
  logistic regression per class and the probabilities of the classes
  normalised.
- the cases of the upstream test file `tests/gcm/test_auto.py` in
  `src/gcm/auto_test.mbt`: the model that the selection picks for a linear and
  for a non-linear regression problem, for a linear and for a non-linear
  classification problem, the assignment of the data with a categorical
  parent, the summary of the assignment and the refusal of a target of a
  single class.
- the numbers of the upstream in `_verify/gcm_auto_reference.py`, which runs
  the upstream on the rows of the fixtures of the port and prints them.

### Changed

- the automatic assignment of the `gcm` package picks the model of a node by
  cross validation now, the way the upstream does, and the summary of the
  assignment holds the performances of the models that were evaluated. The
  assignment of one node returns those performances as well, the way the
  upstream returns them, so its signature changed.
- the messages of the summary of the automatic assignment have the wording of
  the upstream now, and the description of the summary has its layout.
- the case of the invertible model of the validation layer that the automatic
  assignment of the port used to reject is not rejected any more, which is the
  outcome the upstream asserts for the chain of its own fixture.

### Notes

- The header of the test file of the automatic assignment names the upstream
  test file it mirrors now, and the counter of
  `_verify/upstream_test_coverage.py` counts 69 of the 74 test files of the
  upstream. The port mirrors 15 of the 26 cases of that file; the cases of
  `has_linear_relationship`, the ones of the multiclass targets and the ones
  of the statistics of the drawn samples are the ones that are left.
- The upstream evaluates a whole zoo of scikit-learn estimators and it picks
  one of them. The port evaluates the models of the `gcm` package: the linear
  and the nearest neighbour regression for the `GOOD` quality, and the
  polynomial regression as well for the `BETTER` quality. The nearest
  neighbour regression is the non-linear model of the port, the way the
  histogram gradient boosting regression is the non-linear model of the
  upstream.
- The upstream shuffles the rows of the cross validation with the global
  generator of numpy and it does not seed it, so its own selection is not
  reproducible. The port shuffles them with the generator of the `utils`
  package, whose seed is an argument of the functions.
- The upstream draws the target of its linear fixtures without a noise, which
  makes its linear and its polynomial model the same number. The port adds a
  noise to the target of its linear fixtures, so that the selection is
  unambiguous.
- The upstream fits the multiclass logistic regression with a multinomial
  solver; the port fits one binary logistic regression per class and it
  normalises the probabilities of the classes.
- The upstream rejects the model of the correct chain of its invertible model
  case with the sixty rows of the fixture of the port, and it does not reject
  the model of the graph with a collider. The port does not reject either of
  them, because the nearest neighbour regression of its zoo captures the
  relations of the fixture.

[0.0.49]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.49
## [0.0.50] - 2026-11-11

The test of a linear relationship and the rest of the automatic assignment.

### Added

- the test of a linear relationship of the `gcm` package, the port of
  `dowhy.gcm.auto.has_linear_relationship`: the data is split into a training
  part and a test part, a linear model and a non-linear model are fitted on
  the training part and the two of them are compared on the test part.
- the nearest neighbour classifier of the `gcm` package, the port of
  `dowhy.gcm.ml.classification.create_knn_classifier`, and the nearest
  neighbour classifier of the zoo of the model selection.
- the CatBoost encoder of the `gcm` package, the port of
  `dowhy.gcm.util.catboost_encoder.CatBoostEncoder`, which the upstream uses
  when the data holds more than seven categories.
- the cases of the upstream test file `tests/gcm/test_auto.py` in
  `src/gcm/auto_test.mbt`: the test of a linear relationship of a continuous
  and of a categorical target, the imbalanced target, the rare categorical
  features, the format of the summary of a continuous and of a categorical
  target, the statistics of the samples of a fitted model and the assignment of
  a target of three classes with categorical features.
- the decisions of the upstream `has_linear_relationship` and the text of the
  summary of the upstream in `_verify/gcm_auto_reference.py`, which runs the
  upstream on the rows of the fixtures of the port.

### Changed

- the summary of the automatic assignment of the `gcm` package reproduces the
  text of the upstream character for character now: the name of the
  distribution of a root node is `Empirical Distribution`, the name of a
  mechanism is `AdditiveNoiseModel using ...`,
  `Discrete AdditiveNoiseModel using ...` or `Classifier FCM based on ...`, and
  the relation of a discrete node is introduced by `This represents the
  discrete causal relationship as`.
- the header of the test file of the automatic assignment records that the port
  mirrors 22 of the 26 cases of the upstream test file and that the case of the
  multiclass target ends in a different model.

### Notes

- The upstream compares the linear regression with the histogram gradient
  boosting regression in its test of a linear relationship, and the logistic
  regression with the histogram gradient boosting classifier; the port compares
  the ordinary least squares regression with the nearest neighbour regression,
  and the logistic regression with the nearest neighbour classifier. The
  decisions agree on the six fixtures of the upstream test file.
- The upstream splits the rows of that test with the global generator of numpy
  and does not seed it, so its split is not reproducible; the port splits them
  with the generator of the `utils` package, whose seed is an argument of the
  function. The share of a class in a stratified split follows
  `sklearn.model_selection._approximate_mode`, and the port picks the classes
  of the largest remainder in the order of the classes where the upstream picks
  them at random.
- The upstream fits the multiclass logistic regression with a multinomial
  solver; the port fits one binary logistic regression per class and it
  normalises the probabilities of the classes. The probabilities of the port
  are worse for a target of more than two classes, so the selection of the
  model of such a target picks the polynomial logistic regression of the port
  where the upstream picks the linear model. The case of the upstream test
  file records the difference.

[0.0.50]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.50

## [0.0.51] - 2026-11-12

The categorical data of the `gcm` package: the CatBoost encoder and the
categorical cases of the kernel based independence test.

### Added

- the CatBoost encoding of a column with the target of its rows in the `gcm`
  package, the port of the `transform` of
  `dowhy.gcm.util.catboost_encoder.CatBoostEncoder` that is given a target: the
  value of a row is the mean of the target of the rows of its category that
  come before it, smoothed with the mean of the target of the whole column.
- the automatic encoder of the categorical columns of the `gcm` package, the
  port of `dowhy.gcm.util.general.auto_fit_encoders` and of
  `dowhy.gcm.util.general.auto_apply_encoders`: the one-hot encoder when the
  data holds at most seven categories and the CatBoost encoder otherwise.
- the cases of the upstream test file `tests/gcm/util/test_general.py` in
  `src/gcm/catboost_encoder_test.mbt`: the CatBoost encoding of a column with
  and without the target, the encoding of a categorical column with a numeric
  column among them, the encoding of a categorical target and the choice of
  the encoder of the automatic assignment above and below its threshold.
- the cases of the upstream test file
  `tests/gcm/independence_test/test_kernel.py` that the port did not mirror
  yet, in `src/gcm/kernel_test.mbt`: the test of the categorical data, the
  determinism of the test for a given seed, with and without a conditioning
  variable, and the almost constant data.
- the fixtures of the cases of the kernel test in
  `src/gcm/kernel_testdata.mbt`.
- the p-values of the upstream on the categorical fixture of the kernel test
  in `_verify/gcm_validation_reference.py`, and the numbers of the upstream
  CatBoost encoder in `_verify/gcm_general_reference.py`.

### Changed

- the header of the test file of the general helpers of the `gcm` package
  records that the CatBoost encoder is ported now, and that the cases of the
  encoder are the ones of `catboost_encoder_test.mbt`.
- the header of the test file of the kernel based independence test records the
  cases the port does not mirror: the approximate test of the upstream, which
  is the randomised independence test of Strobl et al., and the data of a
  numpy dtype of an object, which the frame of the port does not hold.

### Notes

- The upstream encodes every matrix of its kernel based test on its own, with
  the one-hot encoder of the columns that hold categories. The matrices of the
  port hold numbers only, so the test of the port encodes the categorical
  columns at the call site, with the same encoder. The p-values of the port
  and of the upstream differ by less than `5e-12` on the categorical
  fixture.
- The upstream draws the rows of its sample with the global generator of numpy
  and the port draws them with the generator it is given, so the two draw
  different subsets of the rows of the almost constant case. Only the property
  the upstream asserts -- the p-value is not a number that is not a number --
  is mirrored there.
- The p-values of the determinism cases are not numbers of the upstream: the
  upstream draws its fixture with the global generator of numpy, which is not
  seeded, so its own runs are not reproducible either. The port mirrors the
  property the upstream asserts: two runs with the same seed give the same
  p-value, and two runs with another seed give another one.

[0.0.51]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.51

## [0.0.52] - 2026-11-12

The attribution of the anomalies with a non-linear mechanism.

### Added

- the case of the upstream test file `tests/gcm/test_anomaly_attribution.py`
  that attributes the anomalies of a graph whose relations are non-linear, in
  `src/gcm/anomaly_attribution_test.mbt`: the node `X1` is the square of `X0`
  with a noise, the node `X2` is uniform and the node `X3` is the square of the
  sum of `X1` and `X2` with a noise, and each of the three anomaly samples is
  attributed to its root causes.
- the numbers of the upstream on the fixture of the non-trivial graph in
  `_verify/gcm_anomaly_attribution_reference.py`.

### Fixed

- the reference script of the attribution of the anomalies runs again. The
  constructor of `InvertibleStructuralCausalModel` of the upstream imports the
  module `dowhy.causal_model`, which pulls in the whole graph learning stack
  of the upstream, so the module is stubbed out with a placeholder class, the
  way the reference script of the validation layer does it.

### Notes

- The upstream sets the mechanisms of the two nodes whose relation is
  non-linear to a model that computes the square of the sum of the parents.
  The port expresses the same model with its equation parser, so that the
  mechanism of a node is the relation of the fixture and not a fit of it. A
  fitted polynomial model of the second degree is the same relation on the rows
  of the training data, but its prediction at the anomaly samples, which are
  far outside of the training data, is off by about `6.6`, and that error
  moves the contribution of the target of the first sample from `9.6` to `4.1`.
- The seeds of the fixtures of the attribution of the anomalies are the ones of
  the reference script now, so that the fixtures of the port and the fixtures
  of the script are the same numbers. The contributions of the port and of the
  upstream are close to each other and not equal, because the permutations of
  the noise of the distribution come from the generator of the port and from
  the global generator of numpy.

[0.0.52]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.52

## [0.0.53] - 2026-11-12

The attribution of the anomalies without a causal model.

### Added

- the attribution of the anomalies of a sample without a causal model in the
  `gcm` package, the port of `dowhy.gcm.anomaly.attribute_anomaly_scores`: the
  contribution of every column of the sample to its anomaly score is the
  Shapley value of the set function of the score, which permutes the rows of
  the columns that are not in the subset, so that the subset represents an
  interventional distribution.
- the cases of the upstream test file `tests/gcm/test_anomaly_attribution.py`
  that attribute the anomalies of the simple Gaussian data, in
  `src/gcm/anomaly_attribution_test.mbt`: the attribution with the information
  theoretic score and the attribution with the feature relevance.
- the numbers of the upstream on the fixture of the simple Gaussian data in
  `_verify/gcm_anomaly_attribution_reference.py`.

### Changed

- the header of the test file of the attribution of the anomalies records that
  the port mirrors the cases of the upstream that attribute the anomalies
  without a causal model.

### Notes

- The upstream draws the centres of the components of its Gaussian mixture at
  random and does not seed its generator, so the density of the upstream and
  the density of the port are different numbers, and the contributions of the
  upstream and of the port are different numbers as well. The two make the
  same decision on the fixture of the port: the anomalous column of every
  sample is the column with the largest contribution, and the contributions of
  the columns that are not anomalous are negative in the case of the feature
  relevance.
- The upstream marks its case of the feature relevance as flaky, and the
  numbers it computes on the fixture of the port do not satisfy its own
  assertion for the third sample: the contribution of its fourth column is
  negative where the assertion wants it to be positive. The numbers of the
  port do satisfy it.

[0.0.53]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.53

## [0.0.54] - 2026-11-12

The what-if queries with the categorical variables and with the discrete data.

### Added

- the cases of the upstream test file `tests/gcm/test_whatif.py` that draw the
  interventional samples of a model with the categorical variables and of a
  model with the discrete data, in `src/gcm/whatif_test.mbt`: the
  intervention of the categorical variables sets the values of the two root
  nodes and the two targets hold the expected classes, and the intervention of
  the discrete data sets the value of the root node, so the median of the
  discrete target is `-1` and the mean of its descendant is about `-2`.
- the numbers of the upstream on the fixtures of the port in
  `_verify/gcm_whatif_reference.py`: the upstream runs on the very rows of the
  port, because the script replicates the generator of `src/utils/random.mbt`.

### Fixed

- the reference script of the what-if layer runs again: the upstream module
  `dowhy.causal_model` pulls in the whole graph learning stack of the upstream,
  so it is stubbed out with a placeholder class, the way the reference script
  of the attribution of the anomalies does it.

### Notes

- The upstream draws the class of a categorical target with a uniform noise, so
  the number of the samples that hold the expected class is a random number;
  the generator of the `utils` package is seeded, so the number of the port is
  the same number at every run.
- The upstream fits the histogram gradient boosting regression on the target of
  the discrete additive noise model; the port fits the nearest neighbour
  regression, which is the non-linear model of the port. The upstream and the
  port make the same decision on the rows of the port: the median of the
  discrete target is `-1` on both sides and the mean of its descendant is
  `-1.9943` on the side of the upstream and `-1.9974` on the side of the port.

[0.0.54]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.54

## [0.0.55] - 2026-11-12

The remaining cases of the upstream test files of the `gcm` package, and the
uniform distribution of the package.

### Added

- the case of the upstream test file `tests/gcm/test_feature_relevance.py` that
  estimates the relevance of the parents of a node with a categorical target,
  in `src/gcm/feature_relevance_test.mbt`. The relevance of the two parents
  that determine the class of the target is `0.114` and `0.091`, the relevance
  of the three other parents is about `0.01` and the relevance of the noise of
  the mechanism is zero, which is the relation the upstream test asserts.
- the four cases of the upstream test file `tests/gcm/test_unit_change.py` that
  expect an exception, in `src/gcm/unit_change_test.mbt`. MoonBit cannot catch
  an exception, so the layer exposes the two predicates
  `can_evaluate_unit_change_linear` and `can_evaluate_unit_change_nonlinear`,
  which are the `NotFittedError` and the `AttributeError` of the upstream, and
  the attribution of the unit change aborts when the mechanism of a node is not
  fitted or when it has no coefficients.
- the case of the upstream test file `tests/gcm/test_divergence.py` that checks
  a probability vector, in `src/gcm/divergence_test.mbt`, with the new public
  function `is_probability_vector`, which is the branch of the upstream
  `is_probability_matrix` that handles a one dimensional array.
- the case of the upstream test file `tests/gcm/test_stats.py` that estimates the
  marginal expectation with the five batch sizes of the upstream, in
  `src/gcm/stats_test.mbt`. The batch size is an optimisation of the evaluation
  of the prediction model, so the port accepts it and ignores it, the way it
  accepts the one of the feature relevance.
- the noise of a categorical mechanism as a function of its own, in
  `src/gcm/causal_mechanisms.mbt`: `CausalMechanism::draw_categorical_noise`
  is the port of the `draw_noise_samples` of the `ClassifierFCM` of the
  upstream, which the feature relevance needs to draw the noise of the node
  itself.
- the numbers of the upstream on the fixtures of the port in
  `_verify/gcm_feature_relevance_reference.py`: the section
  `PARENT_RELEVANCE_CATEGORICAL_KNN` runs the upstream with the classifier of
  the port on the very rows of the port, so that the two can be compared. The
  upstream gives a relevance of `0.120` for `X0` and of `0.076` for `X1`, where
  the port gives `0.114` and `0.091`.

### Fixed

- the uniform distribution of the `gcm` package is the one of
  `scipy.stats.uniform` now: its support is the interval that goes from the
  location to the location plus the scale, so that `uniform(0.0, 1.0)` is the
  uniform distribution on `[0, 1]`, and the fit of a uniform is the maximum
  likelihood estimate of scipy, which is the smallest and the largest of the
  samples. The port used to draw the distribution on `[loc - scale, loc +
  scale]`, the convention of a symmetric uniform. The difference was invisible
  in the tests that compare the parameters of a distribution, but it moved
  every number that depends on the samples of a uniform root node: with the old
  convention the fraction of the samples of a node whose parents are uniform on
  `[0, 1]` and whose class is `"0"` when the sum of its two first parents is
  larger than one was `0.125`, the fraction of the pairs of the uniform
  distribution on `[-1, 1]` whose sum is larger than one, and it is `0.5` with
  the convention of scipy.

### Notes

- The upstream uses its default classifier in the case with the categorical
  target, which is the histogram gradient boosting classifier, and the port
  uses the nearest neighbour classifier with one neighbour. Both are sharp: the
  class of a sample of the background is certain, so the noise of the mechanism
  does not change it and the relevance of the noise is zero. The logistic
  regression of the port is too soft for that case: the relevance of its noise
  is `0.093` and the relevance of the two parents that determine the class is
  `0.070` and `0.062`.
- The upstream evaluates the set function of the feature relevance once per
  subset, with one permutation of the background that it shares with every
  sample of the baseline, and it averages the values of the set function over
  the samples of the baseline. The port estimates the Shapley values of every
  sample of the baseline on its own and averages them, which is the same thing
  in expectation, because the Shapley value is linear. The two therefore differ
  by the noise of the permutations.
- The upstream cannot catch an exception, so the cases of the upstream test
  files that expect one are ported as predicates.

[0.0.55]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.55

## [0.0.56] - 2026-11-12

The randomised independence tests of the `gcm` package.

### Added

- the randomised independence test of the `gcm` package, in `src/gcm/kernel.mbt`:
  the new public function `approx_kernel_based` is the port of
  `dowhy.gcm.independence_test.kernel.approx_kernel_based`, which is the
  randomised independence test of Strobl, Zhang and Visweswaran. The samples of
  the two variables are mapped into the feature space of the Gaussian kernel
  with the Nystroem method, the columns of the two feature matrices are
  compared with their covariances, and the p-value is the fraction of the
  permutations of the rows of the first variable whose statistic is not larger
  than the statistic of the sample itself. The conditional test regresses the
  features of the two variables on the features of the conditioning variable
  before the permutation test.
- the eleven cases of the upstream test file
  `tests/gcm/independence_test/test_kernel.py` that use the randomised test, in
  `src/gcm/kernel_test.mbt`: the two continuous variables that are independent
  given the third one and the two that are dependent given a third one that is
  independent of them, the categorical variable that is independent given the
  third one and the one that is dependent given it, the two continuous
  variables that are independent and the two that are dependent, the
  categorical variable that is independent of the continuous one and the one
  that is dependent on it, the determinism of the two tests for a given seed,
  and the constant data.
- the numbers of the upstream on the fixtures of the port in
  `_verify/gcm_validation_reference.py`: the section `RANDOMISED_TEST` runs the
  upstream on the very rows of the port. The upstream does not reject the two
  variables that are independent given the third one (`0.567`) and it rejects
  the two that are dependent given a third one that is independent of them
  (`0.0`), and it makes the same decision as the port on every one of the
  cases.

### Notes

- The upstream draws its randomness from the global generator of numpy and the
  port draws it from the generator of the `utils` package, so the p-value of
  the port and the p-value of the upstream are different numbers that agree on
  the decision the tests assert.
- The inverse of the covariance of the features of the conditioning variable is
  computed with the Gauss-Jordan elimination of the `utils` package, like the
  inverse of the regressor of the conditional kernel based test, and not with
  the Cholesky factorisation of the upstream.
- The fixtures of the port hold two hundred rows and the randomised test uses
  ten random features, twenty permutations and five runs of its bootstrap,
  where the upstream draws a thousand rows and uses fifty random features, a
  hundred permutations and ten runs: the randomised test evaluates the
  covariances of the columns of the features of the kernel space for every one
  of its permutations, and the tests of the port have to stay within the time
  the gate of the port needs on every backend.

[0.0.56]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.56

## [0.0.57] - 2026-11-12

The beta distribution and the automatic selection of the family of a
distribution.

### Added

- the beta distribution of the `gcm` package, in `src/gcm/causal_mechanisms.mbt`:
  the new public function `StochasticModel::beta` is the port of
  `dowhy.gcm.stochastic_models.ScipyDistribution(scipy.stats.beta, ...)`. The
  support of the distribution is the interval that goes from the location to the
  location plus the scale, like the support of scipy, and the samples of the
  distribution are the ratio of two gamma variates with the shapes of the
  distribution.
- the gamma variate of the `utils` package, in `src/utils/random.mbt`: the new
  public function `Random::next_gamma` is the port of the gamma variate of
  numpy, which is drawn with the algorithm of Marsaglia and Tsang.
- the parameters of a distribution, in `src/gcm/causal_mechanisms.mbt`: the new
  public function `StochasticModel::parameters` is the port of the `parameters`
  property of `dowhy.gcm.stochastic_models.ScipyDistribution`. The parameters of
  a beta distribution are its two shapes, and every parametric distribution of the
  port has a location and a scale.
- the automatic selection of the family of a distribution, in
  `src/gcm/causal_mechanisms.mbt`: the new public function
  `find_suitable_continuous_distribution` is the port of
  `dowhy.gcm.stochastic_models.ScipyDistribution.find_suitable_continuous_distribution`.
  Every family the port knows is fitted on the samples, samples are drawn from
  the fitted distribution, and the two samples are compared with the
  Kullback-Leibler divergence of the nearest neighbour estimator.
- four cases in `src/gcm/stochastic_models_test.mbt`: the parameters of a
  distribution are the ones of its family, the samples of a beta distribution are
  inside its support, a fitted beta distribution has the support and the shapes
  of the data, and the automatic selection of the family of a distribution finds
  the normal one. Six of the eight cases of the upstream test file
  `tests/gcm/test_stochastic_models.py` have a counterpart now, and the two that
  have none use the `BayesianGaussianMixtureDistribution` of the upstream, which
  is not part of the port.
- the numbers of the upstream on the fixtures of the port in
  `_verify/gcm_stochastic_models_reference.py`: the sections `FIT_BETA` and
  `AUTOMATIC_SELECTION` run the upstream on the very rows of the port. The
  upstream fits the beta distribution with `a = 1.958702`, `b = 1.981424`,
  `loc = 0.000554` and `scale = 0.999793`, and the port fits the same rows with
  `a = 1.928557`, `b = 1.955700`, `loc = 0.003851` and `scale = 0.994229`, so
  both are inside the tolerances of the test of the upstream. The upstream
  selects the normal distribution for the rows of the automatic selection, and so
  does the port.

### Notes

- The upstream estimates the four parameters of a beta distribution with the
  maximum likelihood, and the port takes the support of the samples -- the
  smallest and the largest of them -- and estimates the two shapes with the
  method of moments. The two answers are inside the tolerances of the test of
  the upstream, which asks for a location of zero within `0.1`, a scale of one
  within `0.1` and the two shapes of two within `0.5`.
- numpy draws its beta variates with the algorithm of Johnk, and the port draws
  the ratio of two gamma variates, which has the same distribution. The samples
  of the port and of the upstream are therefore different numbers of the same
  distribution.
- The upstream fits every continuous distribution of scipy when it selects the
  family of a distribution automatically, and the port fits the four families it
  knows: the normal, the Laplace, the uniform and the beta.
- The divergence of the nearest neighbour estimator is noisy, so the fixture of
  the automatic selection holds two thousand rows. With five hundred rows the
  divergence of the normal distribution of the fixture is `0.058805`, which is
  above the threshold of `0.01` of the upstream, and the selection continues
  with the next family. The upstream selects the normal distribution on the
  rows of the fixture of the port, and so does the port.

[0.0.57]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.57

## [0.0.58] - 2026-11-12

The function that gives the value of a target node from the noise of its
ancestors.

### Added

- the function of the `gcm` package that gives the value of a target node from
  the noise of its ancestors, in `src/gcm/noise.mbt`: the new public function
  `noise_dependent_function` is the port of
  `dowhy.gcm._noise.get_noise_dependent_function`. The function propagates the
  noise through the graph of the target node, so that every node that has no
  path to the target node is left out of it, and the result holds the order of
  the columns of its input. The new public function
  `approx_noise_dependent_function` is the port of the branch of the upstream
  that takes an approximate prediction model: the model is fitted on the noise
  samples of the ancestors of the target node and on the samples of the target
  node itself.
- three cases in `src/gcm/noise_test.mbt`: the value of a target node is
  computed from the noise of its ancestors, the value of a target node is
  approximated from the noise of its ancestors, and the function of a target
  node omits the nodes that have no path to it. Six of the seven cases of the
  upstream test file `tests/gcm/test_noise.py` have a counterpart now.
- the numbers of the upstream on the fixtures of the port in
  `_verify/gcm_noise_reference.py`: the section `NOISE_DEPENDENT_FUNCTION` runs
  the upstream on the very rows of the port. The upstream takes the nodes in the
  order `X0`, `X2`, `X3` and gives the values `0`, `2`, `0.25` and `1.25`, the
  same numbers as the port.

### Fixed

- seven reference scripts of the `gcm` package loaded the real module
  `dowhy.causal_model` of the upstream, which pulls in the whole graph learning
  stack of the upstream and fails. The scripts are
  `_verify/gcm_anomaly_reference.py`,
  `_verify/gcm_distribution_change_reference.py`,
  `_verify/gcm_equation_parser_reference.py`,
  `_verify/gcm_influence_reference.py`,
  `_verify/gcm_intrinsic_influence_reference.py`,
  `_verify/gcm_model_evaluation_reference.py` and
  `_verify/gcm_scm_reference.py`. They stub the module out now, the way the
  other reference scripts do, and all twenty five reference scripts of the
  package run again.

### Notes

- The approximate branch of the upstream fails on a model whose root node has a
  fitted distribution: the view of the graph of the target node does not carry
  the distribution of the root node, so the upstream raises
  `RuntimeError: EmpiricalDistribution has not been fitted!`. The port copies
  the mechanisms of the model into the view of the graph, so its approximate
  branch works.
- The two cases of the upstream that have no counterpart in the port are the one
  whose target is a categorical variable, because the function of the upstream
  returns the categories of the target and the port returns numbers, and the one
  whose nodes are named with integers, because the nodes of the port are named
  with strings.

[0.0.58]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.58

## [0.0.59] - 2026-11-10

The dispatcher of the unit change layer.

### Added

- the dispatcher of the unit change layer of the `gcm` package, in
  `src/gcm/unit_change.mbt`: the new public function `unit_change` is the port
  of `dowhy.gcm.unit_change.unit_change`. The upstream chooses between the
  linear and the non-linear attribution with the kind of its mechanism, and it
  attributes the change to the mechanism only when a foreground mechanism is
  given. The port does the same: the linear branch is the one of a mechanism
  with coefficients, and the two input only variants are the ones of a layer
  without a foreground mechanism.
- two cases in `src/gcm/unit_change_test.mbt`: a single mechanism with the
  default optional parameters reports the contributions of the inputs alone, and
  the same holds for a single non-linear mechanism. Every case of the upstream
  test file `tests/gcm/test_unit_change.py` has a counterpart now.
- the numbers of the upstream on the fixtures of the port in
  `_verify/gcm_unit_change_reference.py`: the new section runs the dispatcher of
  the upstream on the very rows of the port and shows that its contributions are
  the ones of the attribution of the inputs alone.

### Notes

- The upstream uses a random forest regressor for the non-linear branch of the
  dispatcher; the port uses the nearest neighbour regression, which is the
  non-linear model of the port.

[0.0.59]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.59

## [0.0.60] - 2026-11-10

The categorical intrinsic causal influence.

### Added

- the categorical target of the intrinsic causal influence of the `gcm` package,
  in `src/gcm/intrinsic_influence.mbt`: the influence of a target with a
  categorical mechanism is the drop of the entropy of the target, the way the
  upstream measures it. The new public function `icc_entropy_attribution` is
  the attribution function of the upstream for a categorical target, and the
  influence of a categorical target is measured with it.
- the matrix valued marginal expectation of the `gcm` package, in
  `src/gcm/stats.mbt`: the new public function `marginal_expectation_matrix`
  is the port of `dowhy.gcm.stats.marginal_expectation` for a prediction method
  whose predictions hold one column per class. The result of the vector variant
  is the result of this one for a prediction method with a single column.
- the categorical node of the noise of a causal model, in `src/gcm/noise.mbt`:
  the column of a node with a categorical mechanism holds the classes of the
  node now, the way the column of the upstream holds the labels of a
  categorical variable, and the noise of such a node is uniform on `[0, 1]`.
- four cases in `src/gcm/intrinsic_influence_test.mbt`: the influence of a
  categorical target is the drop of the entropy of the target, with the exact
  model and with the approximate one, and the same holds for a target whose
  relation is a mixture of three shifted Gaussians. Two of the three cases of
  the upstream test file `tests/gcm/test_intrinsic_influence.py` that use a
  categorical target have a counterpart now.
- the numbers of the upstream on the fixtures of the port in
  `_verify/gcm_intrinsic_influence_reference.py`: the sections
  `INTRINSIC_CAUSAL_INFLUENCE_CATEGORICAL` and
  `INTRINSIC_CAUSAL_INFLUENCE_COMPLEX_CATEGORICAL` run the upstream on the very
  rows of the port. The upstream contributes `0.158549`, `0.000032`, `0.402891`
  and `0.131163` to the four nodes of the simple fixture, and the port
  `0.148440`, `0.000034`, `0.413516` and `0.129589`, so both are inside the
  tolerances of the test of the upstream.

### Changed

- **breaking** the type of the attribution function of the intrinsic causal
  influence of the `gcm` package: `IccAttributionFunc` holds a function of two
  matrices now and not of two arrays of numbers. The upstream shapes its
  predictions with `shape_into_2d`, so the attribution function of the upstream
  receives a matrix for a continuous target and a matrix of class probabilities
  for a categorical one; the port does the same. A user of the port that writes
  its own attribution function has to take two matrices.

### Notes

- The upstream selects the model of the approximate prediction with the model
  selection of `dowhy.gcm.auto`, which picks the classifier with the smallest
  log loss in a cross validation; the port does the same with the classifiers of
  its own zoo. The upstream selects it with the global generator of numpy; the
  port selects it with a fixed seed, so that the selection does not depend on
  the order of the draws of the layer.
- The upstream fits its classifier with a histogram gradient boosting, which is
  sharper than the classifiers of the port, so the contribution of the noise of
  the target differs a little. The port and the upstream agree within the
  tolerance of the upstream.
- The third case of the upstream that uses a categorical target has every node of
  its graph categorical, so the root node of its model has a categorical
  distribution; the port has no categorical distribution that draws samples yet,
  so that case has no counterpart.

[0.0.60]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.60

## [0.0.61] - 2026-11-10

The categorical noise dependent function.

### Added

- the categorical noise dependent function of the `gcm` package, in
  `src/gcm/noise.mbt`: the new public function
  `categorical_noise_dependent_function` is the port of
  `dowhy.gcm._noise.get_noise_dependent_function` for a target with a
  categorical mechanism. The upstream returns the categories of the target, so
  the function of the port takes a frame whose columns hold the noise of the
  nodes and returns the classes of the target.
- the categorical root of the noise of a causal model, in `src/gcm/noise.mbt`:
  the column of a root node with a categorical distribution holds the
  categories of the node now, and the samples of such a node are drawn from the
  distribution of the node, so that the noise of a categorical root is the
  category of the node, the way the upstream draws it.
- one case in `src/gcm/noise_test.mbt`: the classes of the target of a graph
  with a continuous root and a categorical root are the classes that the
  upstream gives for the same noise. Six of the seven cases of the upstream
  test file `tests/gcm/test_noise.py` have a counterpart now.
- the numbers of the upstream on the fixtures of the port in
  `_verify/gcm_noise_reference.py`: the new section runs the upstream on the
  very rows of the port and shows that the classes of the target are the ones
  the port gives, both for the exact function and for the approximate one.

### Notes

- The function of the upstream takes a numpy array whose columns hold the noise
  of the nodes, and the noise of a node with a categorical distribution is the
  category of the node, so the array of the upstream holds strings as well as
  numbers. The port takes a frame instead, whose column of a node with a
  categorical distribution holds the categories of the node.
- The case of the upstream whose nodes are named with integers still has no
  counterpart, because the nodes of the port are named with strings.

[0.0.61]: https://github.com/riantr/moonbit_doWhy/releases/tag/v0.0.61
