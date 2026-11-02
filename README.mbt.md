# moonbit_dowhy

A MoonBit port of [DoWhy 0.14](https://github.com/py-why/dowhy) (PyWhy) -- causal
graph construction, effect identification, effect estimation and refutation, with
**zero external runtime dependencies**.

[![CI](https://github.com/riantr/moonbit_doWhy/actions/workflows/check.yml/badge.svg)](https://github.com/riantr/moonbit_doWhy/actions/workflows/check.yml)
[![MoonBit](https://mooncakes.io/assets/badge/riantr/moonbit_dowhy-v0.0.26.svg)](https://mooncakes.io/riantr/moonbit_dowhy)

The package ships as `riantr/moonbit_dowhy` and runs on `native`, `wasm`,
`wasm-gc` and `js`. The test suite executes on all four.

## Status

| Area | Upstream | This port |
| --- | --- | --- |
| Causal graph, d-separation | `dowhy.graph`, `dowhy.causal_graph` | ported (the graph, the d-separation, the backdoor and the frontdoor paths, and the readers of the GML graphs, of the DOT graphs and of the graphs of the daggity web site) |
| Causal model | `dowhy.causal_model` | ported (the entry point, the graph given as a graph or as a string, the common causes, the instruments and the effect modifiers of the graph, the cache of the estimators, the conditional estimates of the regression based estimators) |
| Identification | `dowhy.causal_identifier` | ported (backdoor -- default, exhaustive, minimal, maximal, the three efficient strategies of Smucler-Sapienza-Rotnitzky and the optimized search -- frontdoor, general adjustment, IV, mediation -- the mediator, the confounders of its two stages and the natural indirect effect --, and the **ID algorithm** of Shpitser-Pearl) |
| Estimation | `dowhy.causal_estimators` | ported (linear regression, generalised linear model, propensity score weighting / matching / stratification, doubly robust, instrumental variable, two stage regression -- the two stages of the frontdoor and of the mediation estimand --, regression discontinuity) |
| Refutation | `dowhy.causal_refuters` | ported (bootstrap, placebo treatment, data subset, dummy outcome, random common cause, unobserved common cause) |
| Synthetic data | `dowhy.datasets` | ported (`linear_dataset` and the fixtures the upstream tests use) |
| Categorical encoding | `dowhy.utils.encoding` | ported (the one-hot encoder and the encoder registry of the estimators) |
| Dimensionality reduction | `dowhy.data_transformers` | ported (the PCA reducer) |
| Intervention sampling | `dowhy.do_sampler`, `dowhy.do_samplers` | ported (the weighting, multivariate weighting and kernel density samplers) -- the MCMC sampler is **not ported**, it needs an inference engine upstream takes from PyMC3 |
| Time series | `dowhy.timeseries` | ported (the temporal graph and the temporal shift) |
| Causal discovery | `dowhy.graph_learners` | ported (the PC algorithm with the Fisher-z test of conditional independence) |
| Causal discovery | `dowhy.graph_learners` (GES, CDT, LiNGAM) | **not ported** -- upstream delegates those to `causal-learn` / `cdt` / `lingam`, which this dependency-free port does not wrap |
| Graphical causal models | `dowhy.gcm` | **partially ported** -- the configuration, the general helpers, the p-value merging, the F-test, the marginal expectation, the bootstrap confidence intervals, the Kullback-Leibler divergences, the kernel density estimator, the Shapley values, the independence tests (the regression, **with and without categorical data**, the generalised covariance measure and the **kernel based** one), the prediction models, the causal mechanisms, the stochastic models, the noise of a causal model, the **feature relevance**, the **intrinsic causal influence**, the **equation parser**, the probabilistic causal models, the fitting of a causal model, the automatic assignment of the mechanisms, the **what-if queries**, the **validation** layer, the **falsification** layer, the **model evaluation** layer, the **anomaly detection** layer (the detection and the attribution), the **unit change** layer, the **uncertainty** estimates, the **distribution change** layer and the **arrow strength** layer are ported; the **robust** variant of the distribution change layer is **not ported** |
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
| `graph` | `riantr/moonbit_dowhy/graph` | `dowhy.graph`, `dowhy.causal_graph`, and the readers of the GML graphs, of the DOT graphs and of the graphs of the daggity web site |
| `identifiers` | `riantr/moonbit_dowhy/identifiers` | `dowhy.causal_identifier`, with the mediation identification and the natural indirect effect |
| `model` | `riantr/moonbit_dowhy/model` | `dowhy.causal_estimator` (the estimate objects) |
| `estimators` | `riantr/moonbit_dowhy/estimators` | `dowhy.causal_estimators`, with the conditional estimates of the regression based ones and the two stage regression of the frontdoor and of the mediation estimand |
| `refuters` | `riantr/moonbit_dowhy/refuters` | `dowhy.causal_refuters` |
| `datasets` | `riantr/moonbit_dowhy/datasets` | `dowhy.datasets` and the deterministic test fixtures |
| `data_transformers` | `riantr/moonbit_dowhy/data_transformers` | `dowhy.data_transformers` (the PCA reducer) |
| `do_samplers` | `riantr/moonbit_dowhy/do_samplers` | `dowhy.do_sampler`, `dowhy.do_samplers` |
| `timeseries` | `riantr/moonbit_dowhy/timeseries` | `dowhy.timeseries` (the temporal graph and the temporal shift) |
| `cm` | `riantr/moonbit_dowhy/cm` | the PC causal discovery algorithm and the Fisher-z independence test |
| `gcm` | `riantr/moonbit_dowhy/gcm` | the portable core of `dowhy.gcm`: the statistics, the confidence intervals, the divergences, the density estimators, the Shapley values, the independence tests, the prediction models, the causal mechanisms, the feature relevance, the intrinsic causal influence, the equation parser, the fitting of a causal model, the what-if queries, the validation layer, the falsification layer, the model evaluation layer, the anomaly detection layer, the unit change layer, the uncertainty estimates, the distribution change layer and the arrow strength layer |
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
- The parents of a node are taken in the **sorted** order everywhere a design
  matrix is built, the way the upstream takes them with
  `dowhy.graph.get_ordered_predecessors`. The order of the edges of a graph is
  no convention of the upstream, and a design matrix whose columns are in the
  order of the edges fits a different model.
- The two stage regression estimator fits two ordinary least squares models and
  multiplies their effects: the effect of the treatment on the mediator and the
  effect of the mediator on the outcome. The upstream reports no confidence
  interval for it, and so does the port. On the data set of the upstream test
  `test_dowhy_chapter_7` the estimate of the port and the estimate of the
  upstream agree to `5e-14`.
- The default adjustment set of the backdoor search is the set with the fewest
  instruments, and the set with the fewest variables among those. An instrument
  of the adjustment set lowers the variance of the treatment variable, which is
  the reason the upstream prefers it.
- The generalised covariance measure of the `gcm` package regresses X and Y on
  Z with the ordinary least squares fit **with an intercept**, which is the
  `sklearn.linear_model.LinearRegression` of the upstream, and it takes the
  standard deviation of the products of the residuals with `ddof = 0`, like
  `numpy.std`. The upstream takes the prediction model from its caller, so the
  upstream test of the falsification layer fits a linear regressor, and the
  p-values of the port and of the upstream agree to `1e-12`.
- The conditional expectation of a causal mechanism of the `gcm` package is the
  prediction of its model with the noise of zero, because every continuous
  model of the upstream is a post non-linear model -- the additive noise model
  of the upstream is a subclass of it. The normalised mean squared error
  divides the root mean squared error by the standard deviation of the
  observed values, like the `nmse` of the upstream, and the F1 measure is the
  macro average of the measures of the classes, like the `f1_score` of
  scikit-learn with `average="macro"` and `zero_division=0`.
- The continuous ranked probability score of the `gcm` package divides the
  target values by their standard deviation, like the `crps` of the upstream, and
  the categorical score is the mean of the scores of the classes, which is the
  Brier score of the classes. The score of the upstream is estimated from a
  hundred samples of the conditional, and so is the score of the port.
- The median absolute deviation of the `gcm` package is the median of the
  absolute deviations divided by the third quartile of the standard normal
  distribution, like `statsmodels.robust.mad` computes it. The divisor is
  `0.6744897501960817`, so the deviation of the port is the one of the upstream
  and not the plain median of the absolute deviations.
- The bandwidth of the kernel density estimator of the `gcm` package is the one
  of Silverman, which is the standard deviation of the samples times the fifth
  root of four thirds of the inverse of their number, like the upstream. The
  density is the sum of the Gaussian kernels of the samples divided by the
  number of the samples and by the bandwidth, which is the density of the
  `KernelDensity` of scikit-learn.
- The anomaly scorers of the `gcm` package count the samples of the distribution
  that are equal to a sample, that are greater than it and that are smaller than
  it with a binary search over the sorted samples of the distribution, so the
  counts are the counts of the upstream and the scores are the same numbers. The
  samples that are not a number are equal to each other and are neither greater
  nor smaller than any other sample, like the comparisons of numpy count them.
- The attribution of the anomalies of the `gcm` package takes the noise of the
  nodes that are in the subset of the set function from the anomaly sample and
  permutes the noise of the nodes that are not in it, and the value of the subset
  is the logarithm of the relative frequency of the scores of the distribution
  that are at least the score of the anomaly sample. The sum of the
  contributions is therefore the logarithm of the inverse of that relative
  frequency, which is the anomaly score of the target, and the two agree to
  `2e-15`.
- The unit change layer of the `gcm` package puts the difference of the
  intercepts of the two mechanisms into the contribution of the mechanism. The
  upstream drops it, because the linear model of its fixtures is fitted without
  an intercept; the port fits its model with one, like the fit of the `gcm`
  package does everywhere else, so the contributions of the port would not add
  up to the change of the output without it. The intercept of the fixtures of
  the layer is zero up to the rounding of the fit, so the contributions of the
  port and of the upstream are the same numbers.
- The entropy of the `gcm` package is the entropy of `scipy.stats.entropy`, so
  it is measured in nats and the probabilities are normalised by their sum
  before the entropy is computed. The digamma function of the `utils` package
  is the port of `scipy.special.digamma`: the port walks up to an argument of
  ten with the recurrence `ψ(x + 1) = ψ(x) + 1 / x` and uses the asymptotic
  expansion of the remainder, which is the expansion `scipy` uses. For an
  integer `n` the two agree to about `2e-15` at `n = 10000`.
- The estimator of Kozachenko-Leonenko of the `gcm` package uses the distance
  from every row of the sample to its `k`-th nearest neighbour, where `k` is the
  square root of the number of the rows. The upstream asks
  `sklearn.neighbors.NearestNeighbors` for the `k + 1` nearest neighbours of
  every row and keeps the largest of the distances, which is the distance to
  the `k`-th nearest neighbour that is not the row itself. The port computes
  the same distances: for one column it sorts the values and walks the two
  sides of every value, and for more columns it compares every pair of rows.

## Deliberate differences from upstream

Seven behaviours of the core differ on purpose, and each one is a case where
the upstream code is order-dependent rather than wrong in an absolute sense:

- The backdoor identifier enumerates its candidate adjustment variables in
  sorted order. Upstream iterates over a Python `set`, so its order depends
  on the hash seed; the sets it returns are the same.
- The frontdoor identifier returns the **smallest** valid set. Upstream breaks
  out of its loop after the first match it finds and therefore returns the
  largest one.
- The efficient backdoor criterion (the Smucler-Sapienza-Rotnitzky min-cut) is
  ported. It reports a message instead of raising an error, so a search that
  fails returns an empty adjustment set together with the reason. An empty list
  of costs means that every variable costs one, the way the upstream assumes it
  when no costs are given.
- The optimized backdoor search breaks a tie in its hitting set algorithm with
  the name of the variable. Upstream breaks it with the iteration order of a
  Python dictionary of strings, and the order of the strings changes between
  the runs of the interpreter.
- The ID algorithm keeps the variables of a sum in the order of the nodes of
  the graph. Upstream keeps them in a Python `set`, so their order changes
  between the runs of the interpreter.
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

Three behaviours of the mediation differ on purpose:

- The mediator search enumerates its candidates in sorted order. Upstream
  iterates over a Python `set`, so its order depends on the hash seed.
- The two stage regression estimator always fits the two linear regressions
  the upstream falls back to. Upstream takes its two stage models as
  arguments, so that a caller can replace them.
- The **natural direct effect** is **not ported**. Upstream computes it with a
  third model, the total effect, and subtracts the natural indirect effect
  from it.

The `CausalModel` of the root package differs from upstream in the following
ways:

- The graph of the model is a `DirectedGraph` of the `graph` package, or a
  string: a GML graph, a DOT graph or the graph of the daggity web site. The
  upstream also takes a `networkx` graph, a `ProbabilisticCausalModel` and the
  path of a file. The port has no file system and no dynamic import, so the
  caller reads the file and hands its content over.
- The format of a graph string is recognised the way the upstream recognises
  it: a string that starts with `dag` is the graph of the daggity web site, a
  string that holds `graph` followed by a bracket is a GML graph and a string
  that holds `graph` followed by a brace is a DOT graph. The whitespace
  between the keyword and the bracket is optional in the upstream, and it is
  optional here as well.
- The variables of the graph that are not columns of the data and the columns
  of the data that are not variables of the graph are **reported** by
  `unobserved_graph_variables` and `unused_data_variables` instead of being
  warned about. The port has no warning system, and the names of the variables
  are the names the upstream warns about.
- The summary of the model is **returned** by `summary` instead of being
  printed. The upstream prints it and logs it.
- The effect modifiers of an estimate are the effect modifiers of the graph
  when the caller names none, the way the upstream does it. The argument is a
  labelled optional one, so it is written `effect_modifier_names=[...]` or
  left out. The key of a conditional estimate is the index of the quantile
  group of the effect modifier, while the upstream labels a group with the
  interval of its values.

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
- `gcm` takes a frame for the regression based independence test with
  categorical data, because a matrix of the port holds numbers only, and it
  one-hot encodes every discrete column of it. Upstream takes an array and
  encodes the columns whose values are strings. Upstream switches to the
  CatBoost encoder when the data holds more than seven categories; the port
  always uses the one-hot encoder, which is the encoder the upstream uses for
  the fixtures of its own tests.
- The upstream marks its categorical independence tests as flaky, because the
  two models of the F-test have residual sums of squares of the same order in
  the folds of the case that has to find no dependence, so the decision of
  that case depends on the folds the generator draws. The port draws its
  folds with its own generator, so its fixture of the categorical tests holds
  the 5000 samples of the fixture of the upstream, which is the size at which
  both make the same decision on every seed. The reference script prints the
  decision of the upstream on the very rows of the fixture of the port.
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
- `gcm` estimates the Shapley values of the feature relevance of every sample of
  the baseline on its own, and it compares the predictions of a randomized
  subset with the predictions of the baseline repeated for every sample of the
  background. Upstream estimates the Shapley values of all the samples in one
  pass over the subsets, and it broadcasts the one prediction of the baseline
  over the predictions of the background. The two give the same numbers for a
  set function that does not depend on the sample, and the same numbers in
  expectation for the others. The prediction method of the port returns one
  number per row, so the two tests of the upstream that use a classifier -- whose
  predictions are a probability per class -- have no counterpart.
- `gcm` draws the noise of the intrinsic causal influence from the generator it
  is given and not from the global generator of numpy, so the contributions it
  computes and the contributions the upstream computes are different numbers.
  What the two share is the relation the upstream test asserts: the contribution
  of a node is the variance of the noise of that node. On the fixture of the
  reference script the variance of the target is `5.7182810415575` in both, the
  upstream contributes `0.772` to `X0` and `3.948` to `X2`, the port `0.856` and
  `4.176`.
- `gcm` fits a linear regression for the approximate prediction of the intrinsic
  causal influence, where upstream picks a model with the model selection of
  `dowhy.gcm.auto`; the quality of the assignment therefore has no effect on
  the result.
- `gcm` propagates the noise of the exact prediction of the intrinsic causal
  influence through the sub graph of the ancestors of the target node. Upstream
  propagates it through the whole model, which fails when the model holds a
  descendant of the target node, because the noise of that descendant is not
  among the columns of the noise samples.
- The prediction method of the port returns one number per row, so the three
  tests of the upstream that use a categorical target -- whose predictions are a
  probability per class -- have no counterpart here.
- `gcm` parses the expression of an equation and evaluates it over the rows of
  the design matrix, where upstream evaluates the text of the equation with the
  `eval` of Python. The port knows a fixed set of functions -- `abs`, `acos`,
  `asin`, `atan`, `ceil`, `cos`, `cosh`, `exp`, `floor`, `log`, `log10`, `log2`,
  `pow`, `round`, `sign`, `sin`, `sinh`, `sqrt`, `tan`, `tanh` and `trunc` --
  where upstream lets an expression call every function of numpy and of
  `scipy.stats`. The numbers are the same for the expressions both understand.
- `gcm` reads the arguments of a noise model as numbers only, where upstream
  reads them with the `literal_eval` of Python. The noise models of the port
  take numbers only.
- `gcm` fits the parameters of a normal distribution for the `parametric()`
  noise model of an equation, where upstream fits the best distribution of
  `scipy.stats` to the data.
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
- `gcm` takes **one** independence test for the falsification layer, of the type
  `IndependenceTest`, whose third argument is the optional conditioning
  variable. Upstream takes two callables there, one for the marginal test and
  one for the conditional test; the marginal test of the port is the one that is
  called without the conditioning variable.
- `gcm` builds the set of the non-descendants of a node in the order of the
  graph. Upstream builds it in an arbitrary order, because it iterates over a
  Python `set`; the triples of the parental d-separations are the same.
- `gcm` chooses the pairs of the pairwise dependencies with the generator it is
  given, and it runs the tests of a validation one after another. Upstream
  chooses the pairs from the global generator of numpy and runs the tests in a
  process pool with `joblib`.
- `gcm` reports the summaries of the falsification layer in structures with
  named fields. Upstream reports them in dictionaries that are keyed by the
  constants of its `FalsifyConst` enumeration, and it binds the data and the
  parameters of a method with a `partial` object; the port passes the methods
  and the data separately.
- `gcm` **does not plot** the result of a falsification. The plotting
  functions of the upstream are not ported, because the port has no plotting.
- `gcm` cannot represent the categorical fixture of the upstream test of the
  falsification layer, so that test case is not ported: the data frame of the
  port holds one numeric or one discrete column per name, and the kernel based
  independence test of the port takes numeric matrices only.
- `gcm` exposes `data_covers_graph` instead of raising when the data is only
  available for a subset of the nodes of the graph and the caller does not
  allow it. MoonBit has no exceptions, so the check is a public function and
  the function that needs it aborts.
- `gcm` compares the mechanisms of an evaluated model with **every** baseline it
  is given. Upstream skips the baseline whose model class is the class of the
  mechanism, and the port has one regression model and one classification
  model, so skipping it would leave no baseline at all and the comparison would
  be vacuous.
- `gcm` takes the settings of the evaluation of a model in a configuration
  object and the parts of the model to evaluate in an options object. Upstream
  takes the parts in the arguments of its `evaluate_causal_model`.
- `gcm` has no parameter that limits the number of the samples of the
  evaluation of a model. Upstream has one, but its code does not use it to take
  a subset of the data: it permutes the data instead.
- `gcm` does not plot the histogram of the falsification in the report of the
  evaluation of a model. The plotting of the upstream is not ported.
- `gcm` uses the generalised covariance measure as the independence test of the
  invertibility assumption and of the falsification by default. Upstream uses
  the kernel based test, which takes a generator and is cubic in the number of
  the samples; `kernel_independence_test` builds one, and the test of the
  invertibility assumption of a node with more than one parent needs it,
  because the generalised covariance measure needs one dimensional variables
  only.
- `gcm` cannot falsify the graph of a model whose data holds a categorical
  column, because the falsification layer of the port takes numeric matrices
  only. The evaluation of such a model does not falsify the graph.
- `gcm` writes the numbers of the report of the falsification with the text of
  the number, which is the shortest text that reads the number back. Upstream
  writes them with two decimals and with one decimal.
- `gcm` estimates the density of the inverse density scorer with the kernel
  density estimator of the upstream. Upstream uses the Bayesian Gaussian mixture
  of the upstream by default, which needs the variational inference of
  `sklearn.mixture.BayesianGaussianMixture` and is **not ported**; the scorer of
  the port takes the kernel based estimator.
- `gcm` builds its anomaly scorers with a constructor per scorer instead of a
  class per scorer, because MoonBit has no inheritance. The information
  theoretic scorer of the port takes the scorer it wraps, like the upstream
  does.
- `gcm` counts the samples of the distribution that are equal to a sample, that
  are greater than it and that are smaller than it with a binary search over the
  sorted samples of the distribution, where the upstream counts them with a
  vectorised comparison over the whole distribution. The counts and the scores
  are the same numbers.
- `gcm` draws the samples of the anomaly scores of a causal model from the
  generator it is given. Upstream draws them from the global generator of
  numpy, so the scores of the port and of the upstream differ on the same rows;
  they agree on the node with the largest score, which is what the upstream test
  asserts.
- `gcm` does **not** attribute the anomalies of a sample with a scorer that scores
  several variables at once. The upstream `attribute_anomaly_scores` takes such a
  scorer and scores the multivariate samples of the distribution, which needs
  the density estimator of the upstream; the scorers of the port score one
  dimensional samples, so the port attributes the anomalies with the
  `attribute_anomalies` of the upstream, which reduces the samples of the
  distribution to the values of the target before it scores them.
- `gcm` computes the Shapley values of the attribution of one anomaly sample at
  a time. The upstream computes the values of every sample at once, with a set
  function that returns an array; the Shapley estimator of the port takes one
  set function at a time, so the port calls it once per sample. The exact
  estimator evaluates the same subsets of the players in both, so the
  contributions are the same numbers.
- `gcm` exposes the four functions of the unit change layer -- the linear
  attribution, the non-linear attribution and the two input only variants --
  instead of the `unit_change` dispatcher of the upstream. The dispatcher picks
  between the linear and the non-linear attribution with the type of its
  mechanism, and the port has one mechanism, which is linear, so the dispatch
  would always take the same branch.
- `gcm` computes the Shapley values of the unit change of one row at a time.
  The upstream computes the values of every row at once, with a set function
  that returns an array; the Shapley estimator of the port takes one set
  function at a time, so the port calls it once per row. The exact estimator
  evaluates the same subsets of the players in both, so the contributions are
  the same numbers.
- `gcm` has no random forest regressor, so the non-linear attribution of the
  unit change layer is used with the linear model of the port. The upstream
  test file `tests/gcm/test_unit_change.py` compares the linear attribution
  with the non-linear one, and the port compares them as well.
- `gcm` takes a matrix where the upstream takes a numpy array, because
  `shape_into_2d` of the upstream turns every input into a two dimensional
  matrix anyway. A vector is a matrix with one column.
- `gcm` computes the distances to the nearest neighbours of a sample with more
  than one column by comparing every pair of rows, which costs `O(n^2 d)`. The
  upstream asks `sklearn.neighbors.NearestNeighbors`, which builds a tree; the
  distances are the same numbers, and the one column case of the port sorts the
  values instead, which costs `O(n k)`.
- `gcm` computes the distance to the k-th nearest neighbour of a sample with
  one column with a walk over the sorted values, so the Kullback-Leibler
  divergence of two samples of a few thousand values costs `O(n log n)` instead
  of the `O(n^2)` of the pairwise search. The distances are the same numbers,
  because the walk takes the nearer of the two sides of the value first.
- `gcm` computes the entropy of a sample of discrete values by counting the
  distinct rows, like `numpy.unique(x, axis=0)`. The rows are identified by
  their values, so two rows that hold the same numbers are the same row.
- `gcm` keeps the mechanisms and the root distributions of a causal model in the
  model itself, where the upstream keeps them in the node attributes of the
  graph. The distribution change layer therefore clones the two models where the
  upstream clones them, and copies the **fitted** mechanisms where the upstream
  relies on the node attributes surviving the subgraph view of the target node.
  A clone of a mechanism is unfitted, so a model whose mechanisms were cloned has
  to be fitted again before it can be used.
- `gcm` exposes the distribution change layer with a configuration value and a
  result value instead of the `return_additional_info` flag and the
  `auto_assignment_quality` parameter of the upstream. The port always returns
  the attribution, the change of every mechanism and the two models; the caller
  assigns the mechanisms itself when it wants to.
- `gcm` encodes the binary label of the test of the change of a mechanism with a
  two column one hot matrix, like the `OneHotEncoder(handle_unknown="ignore")` of
  the upstream, which keeps every category of the label.
- `gcm` permutes the rows of the two samples of the test of the change of a
  mechanism with the generator it is given, and the upstream permutes them with
  the global generator of numpy. The p-values therefore differ on the same rows,
  and the decision they lead to is the same.
- `gcm` takes the measure of the difference of two distributions as a function of
  two samples, and the measure of the configuration is the Kullback-Leibler
  divergence of `auto_estimate_kl_divergence` when the caller does not give one.
- `gcm` measures the strength of an edge with the difference of the variances of
  the two distributions of the target, like the upstream does for a continuous
  target. For a categorical target the upstream measures the Kullback-Leibler
  divergence of the class probabilities, and the port does the same.
- `gcm` runs the estimate of the strength of an edge for one edge at a time,
  while the upstream runs it for every edge in a process pool. The estimate of
  one edge does not depend on the others, so the strengths are the same numbers.

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
