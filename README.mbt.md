# moonbit_dowhy

A MoonBit port of [DoWhy 0.14](https://github.com/py-why/dowhy) (PyWhy) -- causal
graph construction, effect identification, effect estimation and refutation, with
**zero external runtime dependencies**.

[![CI](https://github.com/riantr/moonbit_doWhy/actions/workflows/check.yml/badge.svg)](https://github.com/riantr/moonbit_doWhy/actions/workflows/check.yml)
[![MoonBit](https://mooncakes.io/assets/badge/riantr/moonbit_dowhy-v0.0.45.svg)](https://mooncakes.io/riantr/moonbit_dowhy)

The package ships as `riantr/moonbit_dowhy` and runs on `native`, `wasm`,
`wasm-gc` and `js`. The test suite executes on all four.

## Status

| Area | Upstream | This port |
| --- | --- | --- |
| Causal graph, d-separation | `dowhy.graph`, `dowhy.causal_graph` | ported (the graph, the d-separation, the backdoor and the frontdoor paths, and the readers of the GML graphs, of the DOT graphs and of the graphs of the daggity web site) |
| Causal model | `dowhy.causal_model` | ported (the entry point, the graph given as a graph or as a string, the common causes, the instruments and the effect modifiers of the graph, the cache of the estimators, the conditional estimates of the regression based estimators) |
| Identification | `dowhy.causal_identifier` | ported (backdoor -- default, exhaustive, minimal, maximal, the three efficient strategies of Smucler-Sapienza-Rotnitzky and the optimized search -- frontdoor, general adjustment, IV, mediation -- the mediator, the confounders of its two stages and the natural indirect effect --, and the **ID algorithm** of Shpitser-Pearl) |
| Estimation | `dowhy.causal_estimators` | ported (linear regression, generalised linear model, propensity score weighting / matching / stratification, doubly robust, instrumental variable, two stage regression -- the two stages of the frontdoor and of the mediation estimand --, regression discontinuity) |
| Refutation | `dowhy.causal_refuters` | ported (bootstrap, placebo treatment, data subset, dummy outcome -- with its list of transformations of the outcome and its two branches --, random common cause, unobserved common cause -- with its **linear sensitivity analysis**, its **E-value analysis** and the **default strength** it infers for its confounder --, the **significance test** of the refutations, and the **assess overlap** refuter, which learns the rules of the support and of the overlap with boolean rules) |
| Synthetic data | `dowhy.datasets` | ported (`linear_dataset` and the fixtures the upstream tests use) |
| Categorical encoding | `dowhy.utils.encoding` | ported (the one-hot encoder and the encoder registry of the estimators) |
| Dimensionality reduction | `dowhy.data_transformers` | ported (the PCA reducer) |
| Intervention sampling | `dowhy.do_sampler`, `dowhy.do_samplers` | ported (the weighting, multivariate weighting and kernel density samplers) -- the MCMC sampler is **not ported**, it needs an inference engine upstream takes from PyMC3 |
| Time series | `dowhy.timeseries` | ported (the temporal graph, its readers of a CSV and of a DOT, and the temporal shift) |
| Causal discovery | `dowhy.graph_learners` | ported (the PC algorithm with the Fisher-z test of conditional independence) |
| Causal discovery | `dowhy.graph_learners` (GES, CDT, LiNGAM) | **not ported** -- upstream delegates those to `causal-learn` / `cdt` / `lingam`, which this dependency-free port does not wrap |
| Graphical causal models | `dowhy.gcm` | **partially ported** -- the configuration, the general helpers, the p-value merging, the F-test, the marginal expectation, the bootstrap confidence intervals, the Kullback-Leibler divergences, the kernel density estimator, the Shapley values, the independence tests (the regression, **with and without categorical data**, the generalised covariance measure and the **kernel based** one), the prediction models -- the linear one and the **polynomial** ones --, the causal mechanisms, the stochastic models, the noise of a causal model, the **feature relevance**, the **intrinsic causal influence**, the **equation parser**, the probabilistic causal models, the fitting of a causal model, the automatic assignment of the mechanisms, the **what-if queries**, the **validation** layer, the **falsification** layer, the **model evaluation** layer, the **anomaly detection** layer (the detection and the attribution), the **unit change** layer, the **uncertainty** estimates, the **distribution change** layer -- the plain one and the **multiply-robust** one -- and the **arrow strength** layer are ported |
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
| `overrule` | `riantr/moonbit_dowhy/overrule` | the `OverRule` algorithm of the refuter that assesses the support and the overlap: the binariser of the features, the sampler of the reference samples, the beam search of the pricing problem, the program of the rules and its rounding |
| `datasets` | `riantr/moonbit_dowhy/datasets` | `dowhy.datasets` and the deterministic test fixtures |
| `data_transformers` | `riantr/moonbit_dowhy/data_transformers` | `dowhy.data_transformers` (the PCA reducer) |
| `do_samplers` | `riantr/moonbit_dowhy/do_samplers` | `dowhy.do_sampler`, `dowhy.do_samplers` |
| `timeseries` | `riantr/moonbit_dowhy/timeseries` | `dowhy.timeseries` (the temporal graph and the temporal shift) |
| `cm` | `riantr/moonbit_dowhy/cm` | the PC causal discovery algorithm and the Fisher-z independence test |
| `gcm` | `riantr/moonbit_dowhy/gcm` | the portable core of `dowhy.gcm`: the statistics, the confidence intervals, the divergences, the density estimators, the Shapley values, the independence tests, the prediction models, the causal mechanisms, the feature relevance, the intrinsic causal influence, the equation parser, the fitting of a causal model, the what-if queries, the validation layer, the falsification layer, the model evaluation layer, the anomaly detection layer, the unit change layer, the uncertainty estimates, the distribution change layer -- the plain one and the multiply-robust one -- and the arrow strength layer |
| `tests` | `riantr/moonbit_dowhy/tests` | the cross-package integration tests, including the cases of the upstream test files of the causal model, of the estimators, of the two stage regression estimator, of the placebo treatment refuter, of the bootstrap refuter, of the data subset refuter, of the dummy outcome refuter, of the unobserved common cause refuter, of the linear sensitivity analysis, of the E-value analysis and of the default strength of the confounder |
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
- The propensity score estimators trim the scores of the data only where the
  upstream trims them: the inverse propensity score weighting estimator trims
  them to `0.05` and `0.95` and the doubly robust estimator trims them to
  `0.01` and `0.99`, while the matching estimator and the stratification
  estimator use the raw scores. The trimming groups the scores of many rows
  together, which moves the matches of the matching estimator and the strata
  of the stratification estimator: on the hundred thousand rows of the upstream
  estimator test suite the estimate of the stratification estimator is
  `10.0001` with the raw scores and `10.308` with the trimmed ones, and the
  upstream gives `10.0001`.
- The number of strata of the propensity score stratification estimator is
  either given or searched for, the way the upstream searches for it: the
  search starts with `0.5 * rows / clipping_threshold` strata and halves the
  number until at least half of the strata hold more than `clipping_threshold`
  units of both arms. The upstream test file uses the search.
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
  effect of the mediator on the outcome. The upstream computes the confidence
  interval and the standard error of such an estimate with the generic
  bootstrap of `CausalEstimator`; the port reports none for it, because it has
  no bootstrap for this estimator. On the data set of the upstream test
  `test_dowhy_chapter_7` the estimate of the port and the estimate of the
  upstream agree to `5e-14`, and on the rows of the upstream test
  `test_frontdoor_estimator` they agree to `8e-14`.
- The synthetic data of the port is drawn with a hand written xorshift64
  generator, so that the rows do not depend on the random number implementation
  of the toolchain. The rows are therefore not the rows of the upstream, which
  draws them with the generator of numpy. The tests that compare the two
  implementations run the upstream on the rows of the port: the rows are
  replicated in Python by `_verify/port_linear_dataset.py`, and the two
  implementations agree on the estimate of the two stage regression to `1e-13`.
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
- The placebo of the placebo treatment refuter is built the way the upstream
  builds it: a continuous treatment becomes the constant zero, a binary
  treatment becomes a random Bernoulli variable with the probability of a half,
  and a categorical treatment becomes a random draw of one of the distinct
  categories of the column. The permuted placebo takes the rows of the
  treatment and permutes them.
- The significance test of a refutation is the port of
  `dowhy.causal_refuter.test_significance`: the automatic test uses the two
  sided percentile test of the bootstrap for a hundred simulations and more and
  the test of the normal distribution below that. The bootstrap test counts the
  estimates that are above the estimate and the half of the ones that are equal
  to it, and the normal test takes the z-score of the estimate against the mean
  and the standard deviation of the simulations, with `ddof = 0`.
- The bootstrap refuter resamples the rows of the data **with** replacement and
  perturbs the variables of interest, the way the upstream does: a numeric
  column gets a Gaussian noise whose standard deviation is the given fraction
  of the standard deviation of the column, a column of zeros and ones is
  flipped and a discrete column gets another category, both with the given
  probability of the change. The probability of the change is the noise unless
  it is given, the way the upstream derives it. The data subset refuter
  samples its subset **without** replacement, the way the upstream does with
  `data.sample(frac=subset_fraction)`.
- The propensity score matching estimator matches every treated unit with the
  control unit whose propensity score is the closest, and a tie is broken with
  the index of the unit: the first unit with the smallest distance wins. The
  search is a binary search over the sorted scores, which picks the same unit
  as a scan over every unit of the other group.
- The logistic regression of the `utils` package minimises
  `sum_i log_loss(y_i, p_i) + 1/(2C) ||w||²`, the convention of
  `sklearn.linear_model.LogisticRegression` with the default `penalty="l2"` and
  `C=1.0`, and it is fitted with the iteratively reweighted least squares. The
  weighted normal equations of a step are accumulated over the rows of the
  design matrix, so the fit of a hundred thousand rows needs a matrix of the
  size of the number of the columns and not one of the size of the square of
  the number of the rows.
- The program of the rules of the `overrule` package is solved in its
  **aggregated** form: the rows of the program that cover the same covariates
  are collapsed into one group with a weight, and the program is solved through
  its dual, because the dual has a feasible basis. The aggregation keeps the
  value of the program and the weights of the rules, and the shadow price of a
  group is shared by its rows, so the residuals of the rows of a group are the
  same number. The upstream solves the program with `cvxpy` and the solver
  `CLARABEL`, and the reference script solves it with the `HiGHS` solver of
  `scipy` instead.
- The propensity model of the overlap region of the `overrule` package is a
  logistic regression with a cross fitting of two folds, the way the upstream
  crosses the folds of its random forest. The two models find the same overlap
  region on the fixture of the upstream test file: the hundred rows of the cell
  where the two features are zero.
- The rules of the `overrule` package are learned with the generator of the
  port, and the reference samples of the upstream are drawn with the global
  generator of numpy, so the rules of the port and the rules of the upstream are
  not always the same rules. The upstream test file accepts a set of equivalent
  rule sets for the same reason, and the port asserts that the rules are one of
  them. The program of the **overlap** rules does not depend on the reference
  samples, so its value is the same number in the port and in the upstream:
  `0.00285` on the fixture of the upstream test file.
- The multiply-robust causal change attribution of the `gcm` package is the port
  of `dowhy.gcm.distribution_change_robust`, the estimator of the paper
  "Multiply-Robust Causal Change Attribution" of Quintas-Martinez, Bahadori,
  Santiago, Mu, Janzing and Heckerman (ICML 2024). Three details of it decide
  whether the attribution is the one of the upstream:
  - **the functional of the variance is the second moment of the target minus
    the square of the first moment of the target.** The upstream writes it as
    `(theta(y²) - theta(y)) ** 2`, but the exponent of Python binds tighter
    than the subtraction, so the upstream computes `theta(y²) - theta(y) ** 2`.
    The port computes the functional of the upstream: the attribution of the
    variance is about twenty times smaller than the square of the difference
    would give.
  - **only the weights of the last group of the estimator are standardised.**
    The upstream standardises the weights outside its loop over the groups, so
    the weights of the other groups keep their scale. The port standardises the
    last weight alone, the way the upstream does.
  - **the estimate of the change is the mean of the scores of the estimator,
    and its standard error is the one of
    `statsmodels.stats.weightstats.DescrStatsW` with the weights of one.** The
    standard error is therefore the standard deviation of the scores with
    `ddof = 0` divided by the square root of the number of the scores less one.

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

Four behaviours of the mediation differ on purpose:

- The mediator search enumerates its candidates in sorted order. Upstream
  iterates over a Python `set`, so its order depends on the hash seed.
- The two stage regression estimator always fits the two linear regressions
  the upstream falls back to. Upstream takes its two stage models as
  arguments, so that a caller can replace them.
- The **natural direct effect** is **not ported**. Upstream computes it with a
  third model, the total effect, and subtracts the natural indirect effect
  from it.
- The upstream raises an error when the estimand holds more than one treatment
  variable or more than one outcome variable, and when it holds no mediator
  variable or no frontdoor variable. The port aborts with the message of the
  upstream, and `CausalEstimator::two_stage_error` reports that message
  before the fit, because MoonBit cannot catch an abort.

- The check of a backdoor set and of a frontdoor set take the algorithm of
  the upstream as an enumeration, `DseparationAlgorithm`, instead of the string
  `dseparation_algo`: the default algorithm asks for the d-separation of the
  graph and the naive one asks for every path to be blocked. The default branch
  of the frontdoor check is the one the upstream takes when the caller names no
  algorithm, which is the d-separation of the graph rather than the blocking of
  the directed paths.

The `estimators` package and the test suites of the port differ from upstream
in the following ways:

- The number of strata of the propensity score stratification estimator is an
  enumeration, `NumStrata`, with a case for a given number of strata and a
  case for the number of strata the upstream searches for. The upstream takes
  the string `"auto"` and an integer.
- The estimator test suite and the bootstrap refuter test suite of the port
  draw their rows with the generator of the port, and the upstream draws its
  rows with the global generator of numpy, which the fixture of the upstream
  test suite seeds with zero. The rows of the port are therefore fixed, and
  the seed of every suite is the one for which the **upstream** stays inside
  the tolerances of its own test files on the very same rows.
  `_verify/estimator_suite_reference.py` runs the upstream on the rows of the
  port. Two of the eighteen cases of the estimator suite are decided by the
  draw: the inverse propensity score weighting estimator with two common
  causes and the doubly robust estimator with two common causes and a binary
  outcome are outside the tolerance of the upstream on the rows of the seed
  42, and the upstream is outside it as well.
- The estimator test suite of the port asserts the estimates only. The upstream
  test files also ask for the confidence intervals and for the significance of
  the estimate, with ten bootstrap simulations for the stratification and the
  doubly robust estimator; the upstream asserts none of those numbers, and ten
  simulations of a bootstrap over a hundred thousand rows would multiply the
  runtime of the suite by an order of magnitude.

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

The `refuters` package differs from upstream in the following ways:

- The placebo of the placebo treatment refuter is drawn with the generator of
  the port, which is a hand written xorshift64, and not with the global
  generator of numpy, so the refuted estimates of the port are not the
  estimates of the upstream. The behaviour the upstream test asserts is the
  same: the effect of the placebo is close to zero.
- The kind of the treatment is taken from the column itself, because the frame
  of the port holds no dtype. A discrete column is a categorical treatment, a
  numeric column whose values are all zero and one is a binary treatment, and
  every other numeric column is a continuous one. The upstream takes the kind
  from the dtype of the column.
- The upstream raises an error when the placebo of an instrumental variable
  method is not the permuted one. The port aborts with the message of the
  upstream, because MoonBit cannot catch an error.
- A refuter that ran no simulation has no distribution to test the estimate
  against, so its p-value is one. The upstream computes the mean of the
  simulations with numpy, which returns `nan` for an empty array, so its
  p-value is `nan`.
- The variables the bootstrap refuter perturbs are named with an enumeration,
  `RequiredVariables`, and not with the `bool | int | list` of the upstream.
  The enumeration has a case for every variable of interest, for no variable
  at all, for a number of them and for a list of names, and a list that names
  the variables to leave out. The upstream raises an error when a list names
  both the variables to keep and the variables to leave out; the enumeration
  cannot express such a list.
- The category branch of the bootstrap refuter of the upstream is broken: it
  reads a variable that it never defines and it writes the integer zero into
  the rows it does not change. The port perturbs a discrete column with
  another category and leaves the rows it does not change alone.
- The dummy outcome refuter takes the list of transformations of the outcome
  as `Transformation` values: `zero`, `noise`, `permute`, `linear_regression`,
  the k nearest neighbours and a model the caller gives. The default list is
  `[zero, noise(1)]`, the `DEFAULT_TRANSFORMATION` of the upstream, so the
  simulated outcome of the default refutation is zero followed by a normal
  noise, and not the uniform draw of `[0, 1]` the port used before 0.0.37.
- The list decides the branch, the way the `_has_estimator` of the upstream
  does: a list without an estimator simulates the whole data at once and
  reports one refutation, a list with one buckets the treatment and reports
  one refutation per bucket, so `refuters.refute_dummy_outcome` returns an
  array. `CausalModel::refute_estimate` reports the first refutation of the
  array.
- The buckets of the estimator branch keep the quirk of the upstream: the
  edges of the cut are the ranges `(max - min)` of every numeric column of the
  frame, divided by `bucket_size_scale_factor * std of the treatment`, in the
  column order of the frame, rather than the range of the treatment column
  alone, and they cut the treatment the way `pandas.cut` does, so a row whose
  treatment lies at or below the first edge takes part in no bucket. A frame
  whose ranges do not increase makes the port abort with the message of
  `pandas.cut`, `bins must increase monotonically.`
- `svm`, `random_forest` and `neural_network` need the estimators the port
  does not have, so `Transformation` has no variant for them and a list that
  names one of them cannot be built.
- The model of a custom transformation takes the covariates of the training
  rows, the outcome of the training rows and the covariates of the rows to
  predict, and returns the two predictions. The upstream takes a callable that
  returns a fitted estimator, which is then applied to both, because MoonBit
  has no partial application of a fitted object.
- The known causal effect of the simulated outcome is a function of the
  treatment column, `true_causal_effect`, and it defaults to zero for every
  row, the `DEFAULT_TRUE_CAUSAL_EFFECT` of the upstream.
- The refuter of the unobserved common cause takes the strength on the
  treatment and the strength on the outcome separately, as `kappa_t` and
  `kappa_y`, where the port used to take one `epsilon` for both, and it reports
  a single refutation rather than the mean of a simulation loop: the upstream
  draws one confounder and reports one refutation, so the port has no interval
  to report besides the refuted effect itself. The two kinds of effect are
  enumerations, `ConfoundersEffectOnT` and `ConfoundersEffectOnY`, with the
  defaults of the upstream: `binary_flip` on the treatment and `linear` on the
  outcome. The `binary_flip` strength is the probability of a flip and the port
  reproduces the edges of the upstream, so `0` flips nothing, `0.5` flips half
  of the rows and `1` flips every row.
- The `percent_change_of_confounder` argument of the upstream refuter, which
  infers the two strengths from the observed common causes, is not ported: the
  strengths are the two arguments of the port. The three `..._range_...` cases of
  the upstream test file are therefore not mirrored either, because they pass a
  list of strengths and draw a matrix of refutations for a plot. The sensitivity
  analyzers of the same upstream module (`linear-partial-R2`,
  `non-parametric-partial-R2` and `e-value`) are not ported yet.
- The **linear sensitivity analysis** of an unobserved confounder is ported, and
  it is a method of the model, `refute_linear_sensitivity`, because the upstream
  returns the analyzer of the analysis from its `refute_estimate` while the
  port's `refute_estimate` returns a refutation of the estimate. The analysis
  reports the partial R2 of the confounder with the treatment and with the
  outcome, the robustness value of the estimate and the bias adjusted estimate.
- The upstream builds its analyzer without the flag of its refuter, so the flag
  `confounder_increases_estimate` of the linear analysis is always `True` there
  and the bias always moves the estimate toward zero. The port reproduces that:
  the flag is an optional argument of the analysis that defaults to `true`.
- The upstream overwrites the effect under the null hypothesis of the analysis
  with the share of the estimate the confounder has to remove, so the value the
  caller gives it never survives. The port does the same.
- The `datasets` package takes the two noise parameters of the upstream,
  `stddev_treatment_noise` and `stddev_outcome_noise`. Their defaults are the
  values the port already used, so the fixtures of the port keep their rows.

The `overrule` package differs from upstream in the following ways:

- The propensity model of the overlap region is a logistic regression with a
  cross fitting of two folds, where upstream fits a random forest with a grid
  search over its depth, over the minimum size of its leaves and over its
  number of trees. The two find the same overlap region on the fixture of the
  upstream test file, and the port has neither a forest nor a grid search.
- The program of the rules is solved by the simplex of the `utils` package,
  through the aggregated form of the program, where upstream solves it with
  `cvxpy` and the solver `CLARABEL`. The value of the program and the weights
  of the rules are the same numbers.
- The reference samples of the support rules are drawn with the generator of the
  port, which is a hand written xorshift64, and not with the global generator
  of numpy, so the rules of the support are not always the rules of the
  upstream. The upstream test file accepts a set of equivalent rule sets for
  the same reason.
- The refuter of the overlap is a method of the model, `refute_assess_overlap`,
  which returns the analyzer of the rules. Upstream returns the analyzer from
  its `refute_estimate`, whose result is a refutation of the estimate.

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
  divergence, and `auto_estimate_kl_divergence` dispatches to it when the
  caller sets its flag `categorical`. The flag carries the information the
  dtype of the upstream would carry.
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
  the model the kind of the target asks for. The two cases of the upstream test
  file `tests/gcm/test_stats.py` that fit a histogram gradient boost model are
  mirrored with the polynomial models of the port, whose relation is the square
  of the upstream fixture, and the tolerances of the two upstream cases hold.
- `gcm` draws the randomness of a causal model from an explicit generator
  instead of the global generator of numpy, so the samples of a model are
  reproducible.
- `gcm` has one causal model type. The upstream distinguishes the
  probabilistic causal model from the structural one, but every mechanism of
  the port is a functional causal model, so the two are the same here.
- `gcm` encodes the categorical conditioning variable of the generalised
  covariance measure itself, with the one-hot encoding of its own encoding
  layer, where the upstream hands the conditioning variable to the automatic
  model selection of `dowhy.gcm.auto`, which encodes it. The two routes agree to
  about `1e-3` on the fixture of the upstream test file and lead to the same
  decision: the explicit encoding is how
  `generalised_cov_based_with_categorical` is exposed.
- `gcm` decides whether a column is categorical from the kind of the column
  of the frame and not from a numpy dtype, because the frame of the port holds
  no dtype: a discrete column is categorical and a numeric one is not.
  `is_categorical` asks whether every column is categorical and
  `has_categorical` whether any one of them is. The upstream refuses a
  categorical input that holds missing values, because only the missing values
  of a numerical variable are supported; the frame of the port holds no missing
  value, so there is no such check.
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
- `gcm` draws the folds of the cross validation of the classifier based
  divergence with the generator it is given, and the upstream draws them with
  the global generator of numpy. The two estimates therefore differ on the
  same rows, and they agree to about `1e-3` on the samples of the upstream test
  file `tests/gcm/test_divergence.py`. The classifier itself is fitted with the
  penalty of the upstream, the `L2` penalty of
  `sklearn.linear_model.LogisticRegression` with its default `C = 1.0`; the
  penalty is what keeps the fit of a sample with a categorical column stable,
  because the one-hot encoding of the column and the intercept are collinear.
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
- `gcm` has neither a calibrator nor sample weights for the multiply-robust
  change attribution. The upstream can calibrate the probabilities of its
  classifier on a calibration set and can weigh the samples; the models of the
  upstream mostly do not support the weights either, and the port has neither.
- The upstream cannot build a data set with a binary treatment with the numpy
  of today. Its `dowhy.datasets.linear_dataset` converts the treatment with
  `numpy.vectorize(convert_to_binary)`, and `convert_to_binary` returns an
  array of one element, which numpy 2 refuses with `ValueError: setting an
  array element with a sequence`. The upstream 0.14 predates numpy 2. Every
  upstream test file that uses a binary treatment therefore fails in the
  upstream itself: the test file of the instrumental variable estimator for
  its eight binary configurations, and the test file of the regression
  discontinuity estimator for its only configuration. The port draws its rows
  with its own generator, so the port runs the cases; the reference scripts
  hand the upstream the rows of the port, so the upstream runs on them as
  well.
- The upstream test file of the regression discontinuity estimator is broken a
  second time. The estimator of the upstream keeps the name of the running
  variable, the threshold and the bandwidth at `None` when the caller does not
  give them, and its fit reads `data[None]`, which is a column of the data
  frame that does not exist. The estimator of the port takes the three values
  as arguments.
- `refuters` computes the E-value of an estimate the way the upstream does,
  and it benchmarks it against the measured confounders the way the
  upstream does: every measured confounder is dropped, the estimator is
  refitted and the Observed Covariate E-value of the confounder is
  reported. The port does not draw the contour plot of the upstream.
- `gcm` expands the features of its polynomial models the way the upstream
  does, with the columns of `PolynomialFeatures(degree, include_bias=False)`
  in the order of the upstream, but the port expands the design matrix it is
  given instead of encoding it itself. The upstream fits the encoder of its
  categorical columns inside the model, so the expansion of the upstream sees
  the encoded columns; the port encodes before the fit, the way the mechanism
  of the `gcm` package does it for every other model.
- `gcm` splits the rows of the cross-fitting of the multiply-robust change
  attribution with its own shuffle, and the upstream splits them with the
  `StratifiedKFold` of scikit-learn. The two splits differ, so the attribution
  of the port and the attribution of the upstream are close to each other and
  not equal to each other: on the ten thousand rows of the upstream test file
  they agree to `0.004` for the mean and to `0.05` for the variance.
- `timeseries` reads the temporal graphs of a CSV and of a DOT from the text
  of the files, because the library has no file system. The upstream reads the
  files themselves.
- `timeseries` reads a CSV in its plain form, where the fields are separated by
  commas and no field is quoted. The upstream reads the file with
  `pandas.read_csv`, which understands the quoted fields as well.
- `timeseries` refuses a row of a CSV whose node names are missing. The
  upstream names them "nan", the name numpy gives to a missing value.
- `timeseries` keeps the order of the entries when it merges the entries of
  one edge of a DOT file. The upstream merges them with a set, whose order is
  the order of the set of the interpreter, so the two differ when the entries
  of one edge do not come in the order of their lags. The entries of the
  upstream test file hold one label per edge, so the two agree there.
- `refuters` infers the default strength of the confounder of the unobserved
  common cause refuter the way the upstream does: a logistic regression of the
  column on the standardised common causes is fitted, and the share of the
  predictions that flip when one common cause is set to zero is the strength of
  that common cause. The port and the upstream agree on every number of the
  fixture, because the reference script hands the rows of the port to the
  upstream.
- The `linear` effect of the upstream reads the standard deviation of the
  column with `np.std(t)[0]`, and the standard deviation of a column is a
  number and not an array, so the branch raises an `IndexError` on the numpy of
  today. The port computes the number that branch means to compute, the
  correlation of every common cause with the column scaled with its standard
  deviation.
- The `binary_flip` effect of the upstream fits a classifier on the column, and
  a continuous column is refused with a `ValueError`. The port aborts with a
  message of the same kind, because MoonBit cannot catch an error. The upstream
  fits a multinomial model for a column with more levels, and the share of the
  flips is then the distance between the classes rather than a share, so the
  port refuses such a column as well.
- The upstream returns the single strength of a range of one number as a number
  and the range of many numbers as an array; the port returns an array in both
  cases.
- The upstream runs a matrix of refutations when the inferred strength holds
  more than one number, and the port has no matrix of refutations: it reports
  one refutation.

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
