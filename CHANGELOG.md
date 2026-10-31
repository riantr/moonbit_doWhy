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
