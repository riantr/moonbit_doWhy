# moonbit_dowhy

A MoonBit port of [DoWhy 0.14](https://github.com/py-why/dowhy) (PyWhy) -- causal
graph construction, effect identification, effect estimation and refutation, with
**zero external runtime dependencies**.

[![CI](https://github.com/riantr/moonbit_doWhy/actions/workflows/check.yml/badge.svg)](https://github.com/riantr/moonbit_doWhy/actions/workflows/check.yml)
[![MoonBit](https://mooncakes.io/assets/badge/riantr/moonbit_dowhy-v0.0.7.svg)](https://mooncakes.io/riantr/moonbit_dowhy)

The package ships as `riantr/moonbit_dowhy` and runs on `native`, `wasm`,
`wasm-gc` and `js`. The test suite executes on all four.

## Status

| Area | Upstream | This port |
| --- | --- | --- |
| Causal graph, d-separation | `dowhy.graph`, `dowhy.causal_graph` | ported |
| Identification | `dowhy.causal_identifier` | ported (backdoor, frontdoor, general adjustment, IV, mediation) |
| Estimation | `dowhy.causal_estimators` | ported (linear regression, generalised linear model, propensity score weighting / matching / stratification, doubly robust, instrumental variable, two stage, regression discontinuity) |
| Refutation | `dowhy.causal_refuters` | ported (bootstrap, placebo treatment, data subset, dummy outcome, random common cause, unobserved common cause) |
| Synthetic data | `dowhy.datasets` | ported (`linear_dataset` and the fixtures the upstream tests use) |
| Categorical encoding | `dowhy.utils.encoding` | ported (the one-hot encoder and the encoder registry of the estimators) |
| Dimensionality reduction | `dowhy.data_transformers` | ported (the PCA reducer) |
| Intervention sampling | `dowhy.do_sampler`, `dowhy.do_samplers` | ported (the weighting, multivariate weighting and kernel density samplers) -- the MCMC sampler is **not ported**, it needs an inference engine upstream takes from PyMC3 |
| Time series | `dowhy.timeseries` | ported (the temporal graph and the temporal shift) |
| Causal discovery | `dowhy.graph_learners` | ported (the PC algorithm with the Fisher-z test of conditional independence) |
| Causal discovery | `dowhy.graph_learners` (GES, CDT, LiNGAM) | **not ported** -- upstream delegates those to `causal-learn` / `cdt` / `lingam`, which this dependency-free port does not wrap |
| Graphical causal models | `dowhy.gcm` | **partially ported** -- the configuration, the general helpers, the p-value merging, the F-test, the marginal expectation, the bootstrap confidence intervals, the Kullback-Leibler divergences, the kernel density estimator, the Shapley values, the independence tests (the regression, the generalised covariance measure and the **kernel based** one), the prediction models, the causal mechanisms, the probabilistic causal models, the fitting of a causal model, the automatic assignment of the mechanisms, the **what-if queries** and the **validation** layer are ported; the **model evaluation**, the **uncertainty** estimates, the **anomaly** scorers and the **distribution change** tests are **not ported** |
| Causal prediction | `dowhy.causal_prediction` | **not ported** -- upstream depends on PyTorch |

Everything that is listed as ported is covered by tests that compare against
the numbers the upstream implementation produces. The rows marked *not
ported* are stated plainly rather than approximated: a wrong answer is worse
than a missing one.

## Install

```shell
moon add riantr/moonbit_dowhy
```

## Quick start

```moonbit
import "riantr/moonbit_dowhy"
import "riantr/moonbit_dowhy/datasets"

/// Build a confounded data set: `W0 -> v0`, `W0 -> y`, `v0 -> y`.
let dataset = @datasets.linear_dataset(
  42,
  1000,
  @datasets.LinearConfig::confounded(),
)

/// Build the model. The graph is derived from the semantic roles of the
/// variables when no explicit graph is given.
let model = @moonbit_dowhy.CausalModel::new(
  dataset.frame(),
  dataset.treatments(),
  [dataset.outcome()],
  None,
  dataset.common_causes(),
  dataset.instruments(),
  dataset.effect_modifiers(),
  dataset.frontdoor_variables(),
)

/// Identify the effect with the backdoor criterion.
let estimand = model.identify_effect("backdoor")

/// Estimate the average treatment effect.
let estimate = model.estimate_effect(
  "backdoor.linear_regression",
  1.0,
  0.0,
  "ate",
  [],
)

println("ATE: " + estimate.estimate().to_string())
println("95% CI: [" + estimate.confidence_interval_lower().to_string() +
  ", " + estimate.confidence_interval_upper().to_string() + "]")
```

A runnable version of this snippet lives in [`examples/quick_start.mbt`](examples/quick_start.mbt).

## Package layout

| Package | Import path | Ports |
| --- | --- | --- |
| `api` | `riantr/moonbit_dowhy/api` | the subset of `pandas.DataFrame` the estimators use, plus the one-hot encoder |
| `utils` | `riantr/moonbit_dowhy/utils` | matrices, least squares, generalised linear models, distributions, descriptive statistics, a deterministic generator |
| `graph` | `riantr/moonbit_dowhy/graph` | `dowhy.graph`, `dowhy.causal_graph` |
| `identifiers` | `riantr/moonbit_dowhy/identifiers` | `dowhy.causal_identifier` |
| `model` | `riantr/moonbit_dowhy/model` | `dowhy.causal_model`, `dowhy.causal_estimator` (the estimate objects) |
| `estimators` | `riantr/moonbit_dowhy/estimators` | `dowhy.causal_estimators` |
| `refuters` | `riantr/moonbit_dowhy/refuters` | `dowhy.causal_refuters` |
| `datasets` | `riantr/moonbit_dowhy/datasets` | `dowhy.datasets` and the deterministic test fixtures |
| `data_transformers` | `riantr/moonbit_dowhy/data_transformers` | `dowhy.data_transformers` (the PCA reducer) |
| `do_samplers` | `riantr/moonbit_dowhy/do_samplers` | `dowhy.do_sampler`, `dowhy.do_samplers` |
| `timeseries` | `riantr/moonbit_dowhy/timeseries` | `dowhy.timeseries` (the temporal graph and the temporal shift) |
| `cm` | `riantr/moonbit_dowhy/cm` | the PC causal discovery algorithm and the Fisher-z independence test |
| `gcm` | `riantr/moonbit_dowhy/gcm` | the portable core of `dowhy.gcm`: the statistics, the confidence intervals, the divergences, the density estimators, the Shapley values, the independence tests, the prediction models, the causal mechanisms, the fitting of a causal model, the what-if queries and the validation layer |
| `tests` | `riantr/moonbit_dowhy/tests` | the cross-package integration tests |
| `examples` | `riantr/moonbit_dowhy/examples` | the runnable quick start |

The root package `riantr/moonbit_dowhy` holds `CausalModel`, the entry point
that ties the data, the graph and the estimators together.

## Numerical conventions

The port reproduces the numbers of DoWhy, so the conventions of NumPy, pandas,
statsmodels and scikit-learn are deliberate rather than accidental:

- `variance` uses `ddof = 0` unless another degree of freedom is asked for;
  `cov` uses `ddof = 1`, like `numpy.cov`.
- `percentile` uses the linear interpolation of NumPy.
- `average_rank` reproduces `pandas.Series.rank(ascending=True)`, so ties get
  the mean rank -- the propensity score stratification estimator depends on it.
- `round_half_even` reproduces `numpy.round` and `pandas.Series.round(0)`.
- A rank deficient design is solved with the Moore-Penrose pseudo inverse,
  the minimum norm solution, like `statsmodels.OLS`, which uses `pinv`.
- The residual variance uses `df_resid = n - rank`.
- The logistic regression minimises `sum_i log_loss(y_i, p_i) + 1/(2C) ||w||^2`,
  the convention of `sklearn.linear_model.LogisticRegression` with its default
  `penalty="l2"` and `C=1.0`.
- The generalised linear model is fitted with iteratively reweighted least
  squares and **without** a penalty, the convention of `statsmodels.api.GLM`;
  the covariance of its coefficients is the pseudo inverse of the weighted
  Gram matrix, and the dispersion of the binomial and the poisson family is
  fixed at one.
- The one-hot encoder drops the first category of every column, like
  `pandas.get_dummies` and like the `Encoders` helper of upstream, and it
  learns its categories in lexicographic order, like `numpy.unique`.
- The prediction model of the `gcm` package fits the way
  `sklearn.linear_model.LinearRegression` does: it centres the features and the
  target before the least squares fit and computes the intercept from the
  offsets. The centring matters, because the one-hot encoding of a categorical
  parent and the intercept are collinear and the two conventions spread the
  same fit over the columns differently. The least squares fit of the `utils`
  package has no intercept at all, so the two are not interchangeable.
- The eigen decomposition of the `utils` package stops when the off-diagonal
  part of the matrix is negligible **against the matrix itself**. The criterion
  is relative, because an absolute one leaves the off-diagonal elements at a
  size of about `3e-8`, and the eigenvalues of a nearly degenerate matrix are
  then only accurate to about `1e-9`. The conditional kernel test of the `gcm`
  package regresses on a nearly degenerate kernel matrix, so the criterion is
  the difference between a p-value that is off by `1.6e-09` and one that agrees
  with the upstream to `8e-12`.

## Deliberate differences from upstream

Five behaviours of the core differ on purpose, and each one is a case where
the upstream code is order-dependent rather than wrong in an absolute sense:

- The backdoor identifier enumerates its candidate adjustment variables in
  sorted order. Upstream iterates over a Python `set`, so its order depends
  on the hash seed; the sets it returns are the same.
- The frontdoor identifier returns the **smallest** valid set. Upstream breaks
  out of its loop after the first match it finds and therefore returns the
  largest one.
- The efficient backdoor criterion (the Smucler-Sapienza-Rotnitzky min-cut)
  is not implemented. It returns an empty adjustment set together with a
  message that says so, instead of returning a wrong one.
- The propensity score estimators compute the scores of the data they are
  asked about with the model and the encoder that were fitted on the training
  data, so the scores follow the rows of that data. Upstream assigns the
  scores of the training data to the new rows by position, which mixes two
  different rows up. The scores of the training data itself are the same
  either way.
- The generalised linear model estimator reports the analytic confidence
  interval and standard error of the effect, computed with the delta method
  from the covariance of the coefficients. Upstream leaves the interval to
  the bootstrap, because a link function other than the identity makes the
  effect a function of the coefficients rather than one of them.

The `do_samplers`, `timeseries` and `gcm` packages differ from upstream in the
following ways:

- `do_samplers` replaces the `df.causal.do(...)` accessor of the pandas
  extension with a plain function, because the port has no accessor mechanism.
  The continuous treatment and the kernel density sampler use a Gaussian
  conditional density around the least squares fit where upstream uses
  `KDEMultivariateConditional`, and the categorical treatment uses the one
  versus rest logistic regression of upstream. The **MCMC sampler is not
  ported**: upstream samples a Bayesian network with PyMC3 and NUTS, and a
  hand written sampler would quietly change the numbers, so the method
  reports that it is unavailable instead of returning a wrong answer.
- `timeseries` keeps the link types of the upstream array representation as
  their label strings (`"-->"`, `"<--"`, `"o-o"`, `"x-x"`), because the
  toolchain cannot construct the variants of an enum of another package. The
  CSV and DOT readers are not ported, because the library has no file IO;
  `create_graph_from_edges` is the data form they feed.
- `gcm` carries the two settings of `dowhy.gcm.config` in a `Config` value
  that the functions take as an argument, because MoonBit has no mutable
  global for them to live in, and it runs nothing in parallel.
- `gcm` detects a categorical input from the numeric shape instead of from
  the numpy dtype, so a distinct number is a category of the categorical
  divergence and `auto_estimate_kl_divergence` does not dispatch to it.
  The `GaussianMixtureDensityEstimator` is **not ported**, because upstream
  uses the variational inference of `sklearn.mixture.BayesianGaussianMixture`;
  the kernel density estimator is ported exactly.
- `gcm` draws the folds of the regression based independence test with its
  own generator instead of numpy's shuffled `KFold`, so its p-value differs
  from the upstream's on the same rows, and it regresses on the conditioning
  variable with the ordinary least squares fit where upstream selects a model
  automatically. Both make the same decision on the same data.
- `gcm` always uses the median trick for the kernel width of the kernel based
  independence test and always approximates the null distribution with a gamma
  distribution. Upstream takes the width from the caller (`est_width`) and can
  also simulate the null distribution instead of approximating it, which the
  port does not do. The median trick draws a random subset of at most 1000 rows
  when there are more rows than that, so the kernel width -- and with it the
  p-value -- depends on the generator; upstream draws the subset from the
  global generator of numpy, the port from the generator it is given.
- `gcm` runs the bootstrap runs of the kernel based independence test one
  after another and draws their randomness from the generator it is given.
  Upstream runs them in a process pool with `joblib` and draws from the global
  generator of numpy, and its `bootstrap_n_jobs` parameter has no counterpart.
- `gcm` encodes nothing for the kernel based independence test, because the
  matrices of the port hold numbers only. Upstream one-hot encodes the
  categorical data it is given, which the port cannot represent.
- `gcm` controls the false discovery rate with the Benjamini-Hochberg step-up
  procedure of `statsmodels`, which is the method the upstream validation uses
  by default. Upstream passes the name of the method to `multipletests`, which
  knows several of them; the port has the one the upstream uses.
- `gcm` computes the inverse of the regressor of the conditional kernel test
  with the Gauss-Jordan elimination of the `utils` package, where upstream
  computes it with the singular value decomposition of `numpy.linalg.pinv`. The
  regressor is nearly singular and its eigenvalues are clustered, so the eigen
  decomposition of the port pairs them wrongly and the pseudo inverse turns
  its absolute error into a relative error of `6.6e-06`. The elimination
  solves the system directly and agrees with the upstream to `8e-12`.
- `gcm` always fits a linear regressor for the automatic assignment of a
  mechanism, so the validation of the invertible model of a non-linear
  relation rejects the model in the port and does not in upstream, which picks
  its model by cross validation out of a zoo of estimators and can capture the
  relation. The validation of a linear relation agrees in both.
- `gcm` draws a seed for every bootstrap resample and hands it to the
  estimation function, instead of seeding the global generator of numpy
  before the call, and its F-test adds the intercept column itself, because
  the least squares fit of the `utils` package has none.
- `gcm` has **one prediction model per kind**: the linear regression and the
  logistic regression. Upstream wraps the whole zoo of the scikit-learn
  estimators and picks one of them by cross validation, so the mechanism that
  is fitted can be a random forest or a support vector machine; the port fits
  the model the kind of the target asks for.
- `gcm` draws the randomness of a causal model from an explicit generator
  instead of the global generator of numpy, so the samples of a model are
  reproducible.
- `gcm` has one causal model type. The upstream distinguishes the
  probabilistic causal model from the structural one, but every mechanism of
  the port is a functional causal model, so the two are the same here.
- `gcm` encodes the discrete parents of a node with the categories the
  encoder was fitted on and encodes a category it has not seen with zeros,
  like the `OneHotEncoder(handle_unknown="ignore")` of upstream; the encoder
  of `dowhy.utils.encoding` drops the first category instead, because that is
  what the upstream helper of the estimators does.
- `gcm` does not select the distribution of a root node automatically. The
  upstream compares every continuous family of scipy against the data and
  keeps the one with the smallest divergence; the port uses the distribution
  it was given.
- `gcm` has three parametric noise distributions -- the normal, the Laplace
  and the uniform -- and the empirical one. Upstream has a parametric
  distribution of every family of scipy and a Bayesian Gaussian mixture, which
  the port does not have, because the mixture needs the variational inference
  of `sklearn.mixture.BayesianGaussianMixture`.
- `gcm` keeps an intervention in a map of functions of a **single value**, not
  of a numpy array. A node of a causal model holds either a number or a
  category, so the value of an intervention is a `CausalValue` that is one of
  the two. The upstream intervention is a function of an array, so it can
  change the shape of a column; the port's cannot.
- `gcm` has **one causal query signature**: the query of `fit_and_compute` takes
  the causal model alone and returns the numbers of the attribution. The
  upstream query takes any number of further arguments and returns a dictionary,
  and the upstream `bootstrap_sampling` alias is a `functools.partial`; the port
  has neither, because the `confidence_intervals` of the port hands the seed of
  the resample to the estimation function already.

## Development

The gate that a release has to pass:

```shell
moon check --deny-warn     # a warning is a failure
moon test --deny-warn
moon fmt --check
typos
```

The cross-package tests live in `src/tests/` rather than inside the
implementation packages, so that a published package never carries a test-only
dependency on `datasets`.

The Python helpers under `_verify/` are the tooling that produced the upstream
reference numbers the tests are compared against.

## License

MIT. See [LICENSE](LICENSE).
