# moonbit_dowhy — working agreements

MoonBit port of [DoWhy 0.14](https://github.com/py-why/dowhy) (PyWhy).

## Toolchain conventions in this repository

These are properties of the MoonBit toolchain this repository builds with
(`moon 0.1.20261028`); they are easy to get wrong and costly to debug.

- **Imports live in `moon.pkg`, never in `.mbt` files.** A file that starts
  with an `import { ... }` block does not compile.
  Each package directory holds a `moon.pkg` that lists the packages it uses.
- **Cross package references are qualified with `@`:** `@utils.mean(xs)`,
  `@graph.directed_graph(g)`. The qualifier is the last segment of the
  import path.
- **Packages are directories that contain a `moon.pkg`.** A directory without
  one is not a package and `moon check` silently reports "no work to do".
- **The module root is the repository root and `source = "src"`.** A package
  at `src/<name>/` is imported as `riantr/moonbit_dowhy/<name>`; the package
  at `src/` itself is `riantr/moonbit_dowhy`.
- **Assertions are plain functions, not macros:** `assert_true(x)`,
  `assert_false(x)`, `assert_eq(a, b)`, `assert_not_eq(a, b)`. There is no
  `assert_eq!`.
- **Test files must qualify the package under test:** `@graph.DirectedGraph`,
  not `DirectedGraph`.
- **Containers are mutated in place, so the binding does not need `mut`:**
  `let xs : Array[String] = []` then `xs.push(..)`. `mut` is only needed
  when a *value* is rebound (`let mut s = 0.0`).
- **Constructors:** `Array::new()` is deprecated, use `[]` with a type
  annotation; `Set::Set([])` for an empty set; `Map([])` for an empty map
  and `Map([(k, v)])` for a literal.
- **`Array::pop()` returns `Option`.** Use `xs[xs.length() - 1]` together
  with `let _ = xs.pop()` when a stack is needed.
- **Double maths:** `x.abs()`, `x.sqrt()`, `x.floor()`, `x.ceil()`,
  `x.round()`, `x.trunc()`, `x.signum()` are methods; `ln`, `exp`, `pow`
  live in the `math` package (`@math.ln(x)`); `@math.PI` is the constant.
- `var` is a reserved word — do not use it as an identifier.
- **`test` is a reserved word**, so it cannot be used as a method name either:
  the independence test of the `cm` package exposes `FisherZ::check(..)`, not
  `FisherZ::test(..)`.
- **`method` and `alias` are reserved words too.** The compiler only warns
  about them, but a warning is a failure in this repository, so a field or a
  binding may not be called `method`.
- **An `Option` has no `or` operator.** `or` is the operator of the booleans, so
  `value or 0` does not compile; the option has `unwrap_or(default)`.
- **`is_none()` is deprecated** in favour of `x is None`, and `x != None` needs
  the `Eq` trait, which the structs of the port do not implement, so a test for
  the presence of a value is a `match` on the option.
- **`String::to_string` of a `StringView` is deprecated** in favour of
  `to_owned`, which allocates the string the caller keeps.
- **A top level definition without `pub` is visible in the whole package**, so
  two files of one package may not define the same name. The helpers of the
  `gcm` package therefore carry a prefix (`falsify_parents_of`) when two files
  need the same one.
- **A public enumeration still warns about a variant that is never
  constructed**, so an enumeration holds only the variants that are built. The
  `FalsifyConst` of the `gcm` package therefore holds the four validation
  methods and not the field names of the upstream dictionaries. The warning does
  not go away when the variant is built in a `*_test.mbt` file, because
  `moon check` does not see that usage: a variant that only the tests build has
  to be built by a **non-test** source file, which is what the constructors of
  the anomaly scorers of the `gcm` package are for.
- **A `const` needs an upper case identifier.** A lower case name is a lexing
  error, and the message names a `let` as the alternative. The two constants of
  the anomaly scorers of the `gcm` package are therefore `ANOMALY_SCORER_EPS` and
  `ANOMALY_MAD_NORMALISATION`.
- **A struct with a `mut` field has reference semantics**: a copy of it shares
  its state with the original, and a function that takes it mutates the state
  of the caller. The generator of the `utils` package relies on it, so a
  generator may be handed to several functions and they all draw from it.
- **A source file must not be named `*_test.mbt`.** That pattern is the
  toolchain's test-file pattern, so the file is excluded from the package
  build and the types it defines stay unresolved. A package that implements
  its own test type lives in `independence.mbt`, not
  `independence_test.mbt`.
- **There is no top-level `let mut`.** A module level `let` and a `const` are
  allowed, but a mutable global is a parse error (`unexpected token 'mut'`).
  A setting that upstream keeps in a module global therefore has to be passed
  explicitly here: the `gcm` package carries the `show_progress_bars` and the
  `default_n_jobs` of `dowhy.gcm.config` in a `Config` value that the
  functions take as an argument.
- **The `for` loops are `for i in 0..<n { }` and `for i = 0; i < n; i = i + 1
  { }`.** The C style does not accept `_` as the variable name, and the
  inclusive range is `0..<=n`. `for i = 0..<n { }` is **not** the range loop:
  the `=` makes it a C style loop with no update, and the compiler reports
  `unused_loop_variable`.
- **There is no record update syntax.** `{ self, field: value }` does not
  compile; every field of a record literal has to be written out. The
  `ProbabilisticCausalModel` of the `gcm` package is the reason this is
  written down: a record that is built from another one has to spell out
  every field.
- **A struct field that holds a container does not need `mut`.** `Map::set`
  mutates the map in place, so `mut map : Map[String, Int]` warns with
  `unused_mut`. The `mut` is only for a field whose *value* is rebound.
- **`moon check` does not see the usage that comes from `*_test.mbt` files.**
  A package whose only sources are test files reports `unused_package` for
  every import. A package needs at least one real source file, or its
  `moon.pkg` must list nothing.
- **A multi-line `if` condition keeps its `{` on the same line as the last
  condition line.** A `{` on a line of its own after a wrapped condition is a
  parse error: `[3002] Unexpected line break here, missing '{'`.
- **The qualifier of a cross package reference is the last segment of the
  import path.** For the module's own root package that is the module name
  without the owner: `import "riantr/moonbit_dowhy"` is used as
  `@moonbit_dowhy.CausalModel::new(..)`, not as a bare `CausalModel`.
- **`moon.pkg` options use the call syntax**, not an assignment:
  `options("is-main": true,)`. `is-main = true` is a lexing error.
- **The module root must not carry a `moon.pkg`.** With `source = "src"` the
  root package is `src/`, and a stray manifest in the repository root
  shadows it.
- **`moon fmt` on this toolchain rewrites `Int` into `Int32` and `///` into
  `///|`.** The whole module has to be formatted with `moon fmt` before it is
  published, otherwise `moon fmt --check` fails in CI.

## Aliasing hazards

MoonBit's containers are mutable and a struct copy copies the *references* to
them, so a "copy" that only copies the struct shares its state with the
original. Four of these cost real debugging time here:

- **`Map::set` mutates the map in place.** Copy the map (`map.copy()`) before
  setting into it, or the "new" frame mutates the old one.
- **`Array::pop()` mutates the array it is called on.** An accessor that
  returns the graph's internal array lets the caller destroy the graph.
  `DirectedGraph::successors(..)` and `::predecessors(..)` return a copy.
- **A function whose name says "with" has to really return a copy.**
  `IdentifiedEstimand::with_adjustment_variables(..)` and
  `CausalEstimator::with_estimand(..)` returned `self` and mutated it in
  place, which silently corrupted the estimator the caller had handed in.
  The `cm` package and the refuters depend on the copy semantics.
- **A `clone` of a causal model keeps its mechanisms untrained.** The upstream
  clones a model with `sklearn.clone`, so the copy has to be fitted again
  before it can be used. The port follows that rule, which means a function
  that needs the *fitted* mechanisms of a model -- the restricted model of the
  average causal effect, for instance -- has to **share** them instead of
  cloning them.

## Numerical conventions

The port reproduces DoWhy's numbers, so the following NumPy / pandas /
statsmodels / scikit-learn conventions are deliberate:

- `variance` uses `ddof = 0` unless asked otherwise; `cov` uses `ddof = 1`
  like `numpy.cov`.
- `percentile` uses NumPy's linear interpolation.
- `average_rank` reproduces `pandas.Series.rank(ascending=True)` (ties get
  the mean rank) — the propensity score stratification estimator depends on
  it.
- `round_half_even` reproduces `numpy.round` / `pandas.Series.round(0)`.
- Rank deficient designs are solved with the Moore-Penrose pseudo inverse
  (minimum norm), like `statsmodels.OLS`, which uses `pinv`.
- The residual variance uses `df_resid = n - rank`.
- Logistic regression minimises `sum_i log_loss(y_i, p_i) + 1/(2C) ||w||²`,
  the convention of `sklearn.linear_model.LogisticRegression` with the
  default `penalty="l2"` and `C=1.0`.
- The prediction model of the `gcm` package **centres** its design, the way
  `sklearn.linear_model.LinearRegression` does: it centres the features and
  the target before the least squares fit and computes the intercept from the
  offsets. The centring matters, because the one-hot encoding of a
  categorical parent and the intercept are collinear, so the two conventions
  spread the same fit over the columns differently. The least squares fit of
  the `utils` package has no intercept at all, so the two are not
  interchangeable.
- The kernel based independence test of the `gcm` package reproduces the
  **gamma approximation** of `causal-learn`'s KCI test, the way the upstream
  validation uses it: the null distribution is a gamma distribution whose two
  parameters come from the trace and the sum of the squares of the centred
  kernel matrices. The median trick of the kernel width draws a random subset
  of at most 1000 rows when there are more rows than that, so the p-value of
  a large sample depends on the generator that draws it.
- The eigen decomposition of `utils.jacobi_eigen` stops when the off-diagonal
  part of the matrix is negligible **against the matrix itself**: the sum of
  the squares of the off-diagonal elements has to be at most the square of the
  machine epsilon times the sum of the squares of the elements. The criterion
  has to be relative. An absolute criterion leaves the off-diagonal elements at
  a size of about `3e-8`, which is enough for a matrix with a well separated
  spectrum but not for a nearly degenerate one: the eigenvalues of the latter
  are then only accurate to about `1e-9`, and the KCI test of the `gcm`
  package — whose regressed kernel matrix has a nearly degenerate tail — moves
  by `1.6e-09` in its p-value. `utils.jacobi_eigen` is shared with the
  estimators, the OLS fit and the PCA reducer, so the criterion is the one
  that all of them use.
- The inverse of the regressor of the regression centring of the KCI test is
  computed with the Gauss-Jordan elimination of `utils.mat_inverse`, not with
  an eigen decomposition. The regressor is nearly singular — its smallest
  eigenvalue is the shift of `1e-3` — and its eigenvalues are clustered, so
  the pseudo inverse divides by them and turns the absolute error of an eigen
  decomposition into a relative error of the inverse.
- The false discovery rate control of the `gcm` package is the
  Benjamini-Hochberg **step-up** procedure of
  `statsmodels.stats.multitest.multipletests(method="fdr_bh")`: the adjusted
  p-value of the `i`-th smallest p-value is the minimum of `m / j * p_j` over
  all `j >= i`, capped at 1, and a hypothesis is rejected when its adjusted
  p-value is at most the level. It is **not** the `merge_p_values_fdr` of the
  package, which is the port of the merging of the upstream and returns the
  smallest adjusted p-value.
- The generalised covariance measure of the `gcm` package regresses X and Y on
  Z with the ordinary least squares fit **with an intercept**, which is the
  `sklearn.linear_model.LinearRegression` of the upstream, and it takes the
  standard deviation of the products of the residuals with `ddof = 0`, like
  `numpy.std`. The upstream takes the prediction model from its caller, so the
  upstream test of the falsification layer fits a linear regressor. The
  p-values of the port and of the upstream agree to `1e-12`; the tolerance of
  the tests of the falsification layer is `1e-12`, because a p-value in the
  far tail of the normal distribution amplifies the difference between the
  two least squares fits.
- The conditional expectation of a causal mechanism of the `gcm` package is the
  prediction of its model with the noise of zero. Every continuous model of
  the upstream is a post non-linear model, because the additive noise model of
  the upstream is a subclass of it, so the upstream takes that branch for every
  continuous model and the port takes it for every continuous kind of the port.
  The normalised mean squared error divides the root mean squared error by the
  standard deviation of the observed values, like the `nmse` of the upstream,
  and the F1 measure is the macro average of the measures of the classes, like
  the `f1_score` of scikit-learn with `average="macro"` and `zero_division=0`.
  The continuous ranked probability score divides the target values by their
  standard deviation, like the `crps` of the upstream, and the categorical
  score is the mean of the scores of the classes, which is the Brier score of
  the classes.
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
  A **median** of the samples that holds a value that is not a number is a value
  that is not a number, like the median of numpy, and the port has to check for
  it itself, because the sort of the `utils` package does not order the values
  that are not a number.
- The attribution of the anomalies of the `gcm` package takes the noise of the
  nodes that are in the subset of the set function from the anomaly sample and
  permutes the noise of the nodes that are not in it, and the value of the
  subset is the logarithm of the relative frequency of the scores of the
  distribution that are at least the score of the anomaly sample. The sum of the
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
- The number of the rows of a unit change attribution is the number of the rows
  of the data, and **not** the number of the input columns. `inputs_of` returns
  the columns of the data, so `background_inputs.length()` is the number of the
  inputs; the row count is `background_data.nrows()`.

## Package layout

| Package | Ports |
| --- | --- |
| `api` | the subset of `pandas.DataFrame` the estimators use, plus the one-hot encoder |
| `utils` | matrices, least squares, generalised linear models, distributions, descriptive statistics |
| `graph` | `dowhy.graph`, `dowhy.causal_graph` |
| `identifiers` | `dowhy.causal_identifier` |
| `model` | `dowhy.causal_model`, `dowhy.causal_estimator` (estimate objects) |
| `estimators` | `dowhy.causal_estimators` |
| `refuters` | `dowhy.causal_refuters` |
| `cm` | the PC causal discovery algorithm and the Fisher-z test |
| `gcm` | the portable core of `dowhy.gcm`: the statistics, the confidence intervals, the divergences, the density estimators, the Shapley values, the independence tests, the prediction models, the causal mechanisms, the fitting of a causal model, the what-if queries, the validation layer, the falsification layer, the model evaluation layer, the anomaly detection layer and the unit change layer |
| `datasets` | `dowhy.datasets` and the deterministic test fixtures |
| `data_transformers` | `dowhy.data_transformers` (the PCA reducer) |
| `do_samplers` | `dowhy.do_sampler`, `dowhy.do_samplers` |
| `timeseries` | `dowhy.timeseries` (the temporal graph and the temporal shift) |
| `tests` | the cross-package integration tests |
| `examples` | the runnable quick start |

## Verification

The upstream reference numbers the tests are compared against are produced by
the Python helpers under `_verify/`. They are the evidence for the claims the
README makes, so they are tracked in the repository:

- `gen_identifier_testdata.py` generates `src/identifiers/test_graphs.mbt`
  mechanically from the upstream graph fixtures, so the expected adjustment
  sets cannot be mistranscribed.
- `cmp_minimal_d_separator.py` transliterates the ported minimal
  d-separator algorithm into Python and diffs it against networkx.
- `pc_reference.py` re-implements the PC algorithm and the fixture generator
  of the `cm` package in Python, and the two agree on the skeleton, the
  directed edges, the undirected edges and the v-structures.
- `check_dataset_columns.py` prints the columns of the upstream
  `linear_dataset`, which is how the column count of the `datasets` package
  was pinned.
- `identifier_reference.py` computes the upstream identification results with
  the upstream Python code, which is where the expected adjustment sets of
  `src/identifiers/test_graphs.mbt` come from.
- `gcm_scm_reference.py` computes the numbers of the causal mechanisms, of the
  fitting of a causal model and of the sampling from it with the upstream
  `dowhy.gcm` code, which is where the expectations of the tests of the
  structural causal model layer come from.
- `gcm_whatif_reference.py` computes the numbers of the what-if layer -- the
  interventional samples, the counterfactual samples, the average causal
  effect, the noise of a model and the data of a model -- with the upstream
  `dowhy.gcm` code, which is where the expectations of the tests of the
  what-if queries come from.
- `gen_validation_testdata.py` generates `src/gcm/validation_testdata.mbt`
  mechanically from the upstream fixtures of `tests/gcm/test_validation.py`,
  with the draws of the upstream replaced by the draws of a fixed seed, so the
  expected p-values cannot be mistranscribed.
- `gen_validation_invertible_testdata.py` generates
  `src/gcm/validation_invertible_testdata.mbt`, the linear fixture of the
  invertible model tests. It is a file of its own, because the non-linear
  fixture of `gen_validation_testdata.py` cannot be used for that: the
  automatic assignment of the port always fits a linear regressor and therefore
  cannot capture a non-linear relation.
- `gcm_validation_reference.py` computes the numbers of the validation layer --
  the p-values of the kernel based independence test on every fixture, the
  outcome and the summary of the validation of the causal structure and the
  outcome of the validation of the invertible model -- with the upstream
  `dowhy.gcm` code, which is where the expectations of the tests of the
  validation layer come from. The upstream needs the `causal-learn` package
  for its kernel based test, and its bootstrap runs have to be kept in one
  process (`dowhy.gcm.config.set_default_n_jobs(1)`), because the workers of a
  process pool cannot import the upstream package when it is read from its
  files.
- `gen_falsify_testdata.py` generates `src/gcm/falsify_testdata.mbt`
  mechanically from the fixtures of `tests/gcm/test_falsify.py`, with the
  draws of the upstream replaced by the draws of a fixed seed, so the
  expected p-values cannot be mistranscribed.
- `gcm_falsify_reference.py` computes the numbers of the falsification layer --
  the summary of every validation method of every fixture, with the p-value of
  every test, and the outcome of the falsification of the collider and of the
  chain -- with the upstream `dowhy.gcm` code, which is where the expectations
  of the tests of the falsification layer come from. The upstream module
  `dowhy.gcm.falsify` reaches the plotting module of `dowhy.gcm.util` and the
  prediction models of `dowhy.gcm.ml`, so the loader has to read the real
  `dowhy.gcm.util` and the real `dowhy.gcm.ml` **after** the stubbed packages
  exist, and the paths of the stubbed packages have to be pointed at the real
  directories of the upstream before they are read.
- `gcm_model_evaluation_reference.py` computes the numbers of the mechanism
  evaluation layer -- the normalised mean squared error, the continuous ranked
  probability score, the outcome of the test of the invertibility assumption and
  the performance of the mechanisms of an evaluated model -- with the upstream
  `dowhy.gcm.model_evaluation` code, which is where the expectations of the
  tests of the layer come from. The upstream module imports the names it needs
  from the package `dowhy.gcm`, which the loader stubs out, so the stub has to
  carry them **before** the module is read. The fixtures of the layer are drawn
  from the generator of the `utils` package of the port, and the script
  reproduces that generator in Python, so that the fixtures of the port and the
  fixtures of the script are the same numbers. The global generator of numpy is
  seeded before every fixture, because the noise the upstream draws and the
  folds of its cross validation come from it.
- `gcm_anomaly_reference.py` computes the numbers of the anomaly detection layer
  -- the scores of the six scorers on the toy fixtures, the score of the inverse
  density scorer with the kernel based estimator, the node with the largest
  anomaly score of every scorer of the causal model and the conditional anomaly
  score of the upstream -- with the upstream `dowhy.gcm.anomaly_scorers` and
  `dowhy.gcm.anomaly` code, which is where the expectations of the tests of the
  layer come from. The upstream module `dowhy.gcm.anomaly` imports the names it
  needs from the package `dowhy.gcm`, which the loader stubs out, so the stub
  has to carry them **before** the module is read. The assignment of the
  mechanisms of the upstream runs a process pool, whose workers cannot import
  the stubbed package, so the number of the jobs has to be set to one. The
  fixtures of the layer are drawn from the generator of the `utils` package of
  the port, and the script reproduces that generator in Python, so that the
  fixtures of the port and the fixtures of the script are the same numbers.
- `gcm_anomaly_attribution_reference.py` computes the numbers of the attribution
  of the anomalies -- the contribution of every upstream node to the anomaly
  score of every anomaly sample, with the information theoretic score and with
  the feature relevance, and the total anomaly score -- with the upstream
  `dowhy.gcm.anomaly.attribute_anomalies` code, which is where the expectations
  of the tests of the layer come from. The attribution permutes the samples of
  the distribution with the global generator of numpy, so its numbers depend on
  that generator and are only close to the numbers of the port, which draws its
  permutations from the generator it is given. The sum of the contributions does
  not depend on the permutations at all, so it is the same number in both.
- `gcm_unit_change_reference.py` computes the numbers of the unit change layer --
  the contributions of the inputs and of the mechanism to the change of the
  output of a linear and of a non-linear mechanism, and the contributions of the
  inputs alone -- with the upstream `dowhy.gcm.unit_change` code, which is where
  the expectations of the tests of the layer come from. The script uses the
  `ShapleyConfig` of one job, because the workers of a process pool cannot
  import the stubbed package. The fixtures of the layer are drawn from the
  generator of the `utils` package of the port, and the script reproduces that
  generator in Python, so that the fixtures of the port and the fixtures of the
  script are the same numbers. The script prints the first three rows of every
  frame and the sum of every column, so the tests of the port compare the first
  rows and the sums and not the whole column.
