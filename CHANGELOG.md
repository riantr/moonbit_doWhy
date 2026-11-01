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
