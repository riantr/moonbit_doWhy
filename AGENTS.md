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
- **An optional argument is supplied by its label with `name=value`.** The
  `~` belongs to the declaration of the parameter (`name~ : Bool = false`) and
  to the positional form of the call (`f(x, name~)`); the labelled form of the
  call is `f(x, name=value)` and `name~=value` is a parse error.
- **There is no `&mut` parameter.** A function that has to change what its
  caller gave it takes a struct with a `mut` field, like the parser of the
  equation parser takes a `position : Int32` it advances itself.
- **`derive(Eq)` goes after the closing brace of the type.** The derived
  `equal` and `not_equal` are promoted as ordinary methods, which is
  deprecated, so the type needs an `extend Type with Eq::{equal, not_equal}`
  declaration. The methods then have to be used explicitly, because the
  operators `==` and `!=` do not count as a use of them and the unused ones are
  a warning, which is a failure in this repository.
- **A float literal has no exponent.** `1e-12` is a parse error; the tolerance
  is written out, `0.000000000001`.
- **`String::trim_space` is deprecated**, use `String::trim`, which takes the
  whitespace characters of the text by default.
- **`String::split` returns an iterator of `StringView`**, not an array of
  strings. A function that needs strings collects them with `to_owned`.
- **The bounds of a range need their parentheses** when they hold arithmetic:
  `for i in (start + 1)..<(end - 1)`. The bare form is a parse error, because
  the `+` and the `..<` are ambiguous.

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
- The regression based independence test of the `gcm` package is **numerically
  unstable** for a target that is a step function of a continuous variable,
  and the upstream marks its categorical tests as flaky because of it. The
  normalisation of the Nystroem transformer inverts the square root of the
  kernel matrix of the basis points, and that kernel matrix is rank deficient
  when the variable holds one dimension, so the null space is amplified by a
  factor of a million. The design matrix of the F-test is therefore ill
  conditioned, and the fit of the model with the kernel features explodes in
  some of the folds. The port solves the least squares problem the way the
  upstream does -- the pseudo inverse of the Gram matrix of the centred
  design matrix, which agrees with the singular value decomposition of
  `sklearn.linear_model.LinearRegression` to seven digits on the same design
  matrix -- so the two differ only in the folds their generators draw. The
  fixture of the categorical tests therefore holds the 5000 samples of the
  fixture of the upstream, which is the size at which both make the same
  decision on every seed.
- The parents of a node are taken in the **sorted** order everywhere a design
  matrix is built, the way the upstream takes them with
  `dowhy.graph.get_ordered_predecessors`. The order of the edges of a graph is
  no convention of the upstream, and a design matrix whose columns are in the
  order of the edges fits a different model. The parents a node is fitted with
  are compared against the sorted ones as well, the way the upstream compares
  them in `dowhy.gcm.causal_models.validate_local_structure`.
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
- The entropy of the `gcm` package is the entropy of `scipy.stats.entropy`, so
  it is measured in nats and the probabilities are normalised by their sum
  before the entropy is computed. The digamma function of the `utils` package
  is the port of `scipy.special.digamma`: the port walks up to an argument of
  ten with the recurrence `ψ(x + 1) = ψ(x) + 1 / x` and uses the asymptotic
  expansion of the remainder. For an integer `n` the two agree to about
  `2e-15` at `n = 10000`.
- The Kullback-Leibler divergence of a sample with one column of the `gcm`
  package finds the distance to the k-th nearest neighbour with a walk over
  the sorted values of the sample, so the estimator costs `O(n log n)` instead
  of the `O(n^2)` of the pairwise search. The distances are the same numbers,
  because the walk takes the nearer of the two sides of the value first, and
  the distance of a single column is computed like the one of two rows of two
  matrices, so the numbers of the walk and of the pairwise search are the same.
- The bins of the discretised entropy of the `gcm` package follow the
  convention of `numpy.histogram`: every bin but the last one is half open, so
  a value that sits exactly on an edge belongs to the bin on its right, and the
  last bin holds the largest value of the sample. The edges are the ones of
  `numpy.linspace(min_value, max_value, number_of_bins)`, which gives
  `number_of_bins - 1` bins, and a single edge gives no bin at all.
- The distribution change layer of the `gcm` package keeps the mechanisms of a
  causal model in the model, where the upstream keeps them in the node attributes
  of the graph. `clone_causal_models` therefore clones the models where the
  upstream clones them -- a clone of a mechanism is unfitted -- and the private
  `copy_mechanisms` copies the fitted ones where the upstream relies on the node
  attributes surviving the subgraph view of the target node.
- The binary label of the test of the change of a mechanism of the `gcm` package
  is a two column one hot matrix, like the
  `OneHotEncoder(handle_unknown="ignore")` of the upstream, which keeps every
  category of the label. A one hot encoder that drops a category would change
  the kernel matrix of the test.
- The rows of the two samples of the test of the change of a mechanism of the
  `gcm` package are permuted with the generator the layer is given, and the
  upstream permutes them with the global generator of numpy. The permutation is
  not a detail: when the two samples hold the same rows, the label tells the two
  copies of every row apart and the test finds a dependency that is not there.
- The strength of an edge of the arrow strength layer of the `gcm` package is
  measured with the difference of the variances of the two distributions of the
  target, like the upstream does for a continuous target, and with the
  Kullback-Leibler divergence of the class probabilities for a categorical
  target. The upstream runs the estimate for every edge in a process pool and
  the port runs it for one edge at a time; the estimate of one edge does not
  depend on the others, so the strengths are the same numbers.
- The measure of the difference of two distributions of the distribution change
  layer of the `gcm` package is a function of two samples, and the measure of
  the configuration is the Kullback-Leibler divergence of
  `auto_estimate_kl_divergence` when the caller does not give one.
- The efficient backdoor search of the `identifiers` package is the port of
  `dowhy.causal_identifier.efficient_backdoor`, and it has two conventions of
  the upstream that the port has to keep:
  - **an empty list of costs means that every variable of the graph costs
    one.** The upstream uses a cost of one for every variable when it is given
    no costs at all, and a variable without a cost has an infinite capacity in
    the flow network. Seven of the eleven example graphs of the upstream have
    no costs, so reading an empty list as "every variable is free" gives the
    wrong minimum cut.
  - **the minimum cut is the cut of the upstream, not just any minimum cut.**
    The upstream finds the cut that is contained in every other cut, and the
    port reproduces it on all eleven example graphs.
- The flow network of that search is solved with Dinic's algorithm, and three
  details of it decide whether the result is the one of the upstream:
  - **the levels of the level graph are the distances to the source**, so the
    breadth first search reads its queue from the front. A search that reads it
    from the back is a depth first search, and the levels it assigns are not
    the distances, so the blocking flow misses augmenting paths and the flow
    is too small.
  - **the unvisited sign of a level is minus one**, not zero, because the level
    of the source is zero.
  - **the limit of the amount that is pushed is passed down the path.** Every
    edge of the path is pushed that same amount, which is the smallest residual
    capacity of the path. Passing the amount back up instead pushes more on the
    edges near the source than on the edges near the sink, and the flow is not
    conserved.
- The optimized backdoor search of the `identifiers` package is the port of
  `dowhy.causal_identifier.backdoor`, and two details of it decide whether the
  result is the one of the upstream:
  - **the hitting set is computed over the pair that is complete, not over the
    pair that is written to.** When the search reaches a pair of nodes whose
    paths are known already, it takes the variables that block those paths and
    adds them to the pairs along the way. Taking the variables of the pair
    that is written to instead gives a different set.
  - **a tie in the hitting set is broken with the name of the variable.** The
    upstream breaks it with the iteration order of a Python dictionary of
    strings, and that order changes between the runs of the interpreter, so the
    upstream's own result is not reproducible. The port's is.
- The graph of the `CausalModel` of the root package is read from a string the
  way the upstream reads it, and three details of it decide whether the graph
  is the one of the upstream:
  - **the format is recognised with the regular expressions of the upstream.**
    A string that starts with `dag` is the graph of the daggity web site and
    is turned into a DOT graph first, a string that holds `graph` followed by
    a bracket is a GML graph and a string that holds `graph` followed by a
    brace is a DOT graph. The whitespace between the keyword and the bracket
    is optional, so `graph[` is a GML graph and `graph {` is a DOT graph.
  - **the GML graph resolves the identifiers of the edges to the labels of the
    nodes**, the way `networkx.parse_gml` does it. The edges of a GML graph
    name the `id` of their nodes while the node is labelled with its `label`,
    and the two are not the same in general.
  - **the GML graph of a data set is written character for character like the
    upstream writes it.** The upstream joins the nodes of a group with a space
    and writes the groups one after the other without a separator, and it
    writes the edge of the treatment to the outcome without the space that
    the other edges have.
- The conditional estimates of the `estimators` package are the port of the
  `_estimate_conditional_effects` of the upstream, and two details of them
  decide whether they are the ones of the upstream:
  - **a continuous effect modifier is split into five quantile groups**, the
    number of `CausalEstimator.NUM_QUANTILES_TO_DISCRETIZE_CONT_COLS` of the
    upstream. The bins of the port run from `0` to `q - 1`, the way the bins
    of `pandas.qcut` do, so the bin of a row is
    `floor((rank - 1) * q / n)`.
  - **the effect of a group is estimated with the model that was fitted on the
    whole data**, the way the upstream does it: the upstream applies its
    do-operator to the rows of the group and does not fit the model again.
- The two stage regression estimator of the `estimators` package is the port of
  the `TwoStageRegressionEstimator` of the upstream, and four details of it
  decide whether the estimate is the one of the upstream:
  - **the estimate is the product of the two stage effects.** The first stage
    regresses the mediator on the treatment and on the confounders of the first
    stage, the second stage regresses the outcome on the mediator and on the
    confounders of the second stage, and the estimate is the product of the two
    effects. A single stage regression is a different estimator.
  - **the outcome of the first stage is the mediator and the treatment of the
    second stage is the mediator**, the way the upstream replaces them in the
    estimands of its two stage models.
  - **the confounders of the two stages come from the mediation**, the way the
    upstream computes them in `identify_mediation_first_stage_confounders` and
    `identify_mediation_second_stage_confounders`. The default set of each
    stage is the one under the plain `backdoor` name of its registry.
  - **the upstream computes the confidence interval and the standard error of the
    two stage estimate with the generic bootstrap of `CausalEstimator`, and the
    port reports none for it**, because it has no bootstrap for this estimator.
    The upstream test asks for them without asserting anything about their
    values.
  - **the errors of the upstream are reported, not raised.** The upstream
    raises a `ValueError` when the estimand holds no mediator variable or more
    than one, and it raises an `Exception` when the estimand holds more than
    one treatment variable or more than one outcome variable. MoonBit cannot
    catch an error, so the port aborts with the message of the upstream, and
    `CausalEstimator::two_stage_error` reports that message before the fit.
    The messages live in the constants of `src/estimators/two_stage.mbt`, so
    that the fit and the accessor cannot drift apart.
- The synthetic data of the `datasets` package is drawn with a hand written
  xorshift64 generator, so that the rows do not depend on the random number
  implementation of the toolchain. The rows are therefore **not** the rows of
  the upstream, which draws them with the generator of numpy. A test that
  compares the port with the upstream on synthetic data therefore has to run
  the upstream on the rows of the port: the rows are replicated in Python by
  `_verify/port_linear_dataset.py`, which mirrors the generator of the port
  down to the last bit of every column. The rows of the port and the rows of
  the replication are the same numbers, but their **sums** are not: the native
  backend of the toolchain reassociates the reduction of a loop, so a sum of
  the port and the sum of the replication differ in the last bits. The
  estimate of the two stage regression is the same number in both, to `1e-13`.
- The default adjustment set of the backdoor search of the `identifiers`
  package is the set with the fewest instruments, and the set with the fewest
  variables among those, the way `get_default_adjustment_set_id` of the upstream
  picks it. An instrument of the adjustment set lowers the variance of the
  treatment variable, which is the reason the upstream prefers it. The two
  rules agree on every graph whose adjustment sets hold no instrument.

## Package layout

| Package | Ports |
| --- | --- |
| the root package (`src/`) | `dowhy.causal_model`: the `CausalModel` entry point |
| `api` | the subset of `pandas.DataFrame` the estimators use, plus the one-hot encoder |
| `utils` | matrices, least squares, generalised linear models, distributions, descriptive statistics |
| `graph` | `dowhy.graph`, `dowhy.causal_graph`, and the readers of the GML graphs, of the DOT graphs and of the graphs of the daggity web site |
| `identifiers` | `dowhy.causal_identifier`, with the mediation identification and the natural indirect effect |
| `model` | `dowhy.causal_estimator` (the estimate objects) |
| `estimators` | `dowhy.causal_estimators`, with the conditional estimates of the regression based ones and the two stage regression of the frontdoor and of the mediation estimand |
| `refuters` | `dowhy.causal_refuters` |
| `cm` | the PC causal discovery algorithm and the Fisher-z test |
| `gcm` | the portable core of `dowhy.gcm`: the statistics, the confidence intervals, the divergences, the density estimators, the Shapley values, the independence tests, the prediction models, the causal mechanisms, the feature relevance, the intrinsic causal influence, the equation parser, the fitting of a causal model, the what-if queries, the validation layer, the falsification layer, the model evaluation layer, the anomaly detection layer, the unit change layer, the uncertainty estimates, the distribution change layer and the arrow strength layer |
| `datasets` | `dowhy.datasets` and the deterministic test fixtures |
| `data_transformers` | `dowhy.data_transformers` (the PCA reducer) |
| `do_samplers` | `dowhy.do_sampler`, `dowhy.do_samplers` |
| `timeseries` | `dowhy.timeseries` (the temporal graph and the temporal shift) |
| `tests` | the cross-package integration tests, including the cases of the upstream test files of the causal model, of the estimators and of the two stage regression estimator |
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
- `check_networkx_gml.py` and `check_networkx_gml_labels.py` show how
  `networkx.parse_gml` reads a GML graph: the edges of the graph name the
  `id` of their nodes while the name of a node is its `label`, so a reader has
  to resolve the ids of the edges with the labels of the nodes. They are the
  evidence for the reader of the `graph` package.
- `causal_model_reference.py` computes the facts of the causal model -- the
  columns of the data set, the GML graph of the data set, the nodes and the
  edges of the graph of the upstream test `test_graph_input`, its common
  causes, its instruments, its observed and its unobserved variables, the DOT
  graph the upstream turns the graph of the daggity web site into and the
  observed and the unobserved variables of the fixture of the upstream test
  `test_unobserved_graph_variables_log_warning` -- with the upstream
  `dowhy.causal_graph.CausalGraph` and the upstream `dowhy.datasets`, which
  is where the expectations of the tests of the causal model come from. The
  upstream `linear_dataset` cannot run under NumPy 2, because `np.vectorize`
  cannot store the one element array that its `convert_to_binary` returns in
  the output of a scalar, so the script restores the behaviour of NumPy 1 for
  it.
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
- `gcm_distribution_change_reference.py` computes the numbers of the distribution
  change layer -- the p-value of the test of the change of a mechanism of every
  node, the attribution of the change of the distribution of the target and the
  attribution between two models that are fitted on the old and on the new data
  -- with the upstream `dowhy.gcm.distribution_change` code, which is where the
  expectations of the tests of the layer come from. The upstream draws its
  permutations from the global generator of numpy, so its p-values depend on that
  generator; the tests of the port therefore assert the decision the p-value
  leads to and the attribution with a tolerance, and the script prints the
  numbers of the upstream for the record. The fixtures of the test of the change
  of a mechanism hold a fifth of the rows of the fixtures of the upstream and
  the fixtures of the change of the distribution hold a tenth of them, because
  the kernel based conditional test of the layer inverts a kernel matrix whose
  size is the number of the rows of the joint sample.
- `gcm_influence_reference.py` computes the numbers of the arrow strength layer --
  the strength of every edge that points at the target node, with the default
  measure of the difference of the two distributions, with the Kullback-Leibler
  divergence and with the observed samples of the parents, and the strength of
  every input of a classifier -- with the upstream `dowhy.gcm.influence` code,
  which is where the expectations of the tests of the layer come from. The
  upstream draws its permutations and its noise from the global generator of
  numpy, so its numbers depend on that generator; the tests of the port
  therefore assert the relations the upstream test file asserts, with a
  tolerance around the numbers the script prints. The module of the upstream
  reads the feature relevance from the package of the upstream, which the
  loader stubs out, so the function is put on the stubbed package before the
  module is read.
- `gcm_uncertainty_reference.py` computes the numbers of the uncertainty
  estimates -- the entropy of a Gaussian sample with the three estimators, the
  variance of a Gaussian sample in one and in several dimensions, the entropy
  of the rows of a matrix of probabilities and the entropy of a sample of
  discrete values -- with the upstream `dowhy.gcm.uncertainty` code, which is
  where the expectations of the tests of the layer come from. The fixtures of
  the layer are drawn from the generator of the `utils` package of the port, and
  the script reproduces that generator in Python, so that the fixtures of the
  port and the fixtures of the script are the same numbers. The multivariate
  fixture of the script holds a hundred thousand rows, where the upstream test
  holds a million: the covariance of the sample is the same number either way,
  and the port keeps the fixture small enough for every backend of the
  toolchain.
- `gcm_stochastic_models_reference.py` computes the numbers of the stochastic
  models -- the parameters a fitted normal distribution estimates, the samples it
  draws and the samples of an empirical distribution -- with the upstream
  `dowhy.gcm.stochastic_models` code, which is where the expectations of the
  tests of the layer come from. The fixtures of the layer are drawn from the
  generator of the `utils` package of the port, and the script reproduces that
  generator in Python, so that the fixtures of the port and the fixtures of the
  script are the same rows and the upstream estimates its parameters on the very
  rows the port works on.
- `gcm_noise_reference.py` computes the numbers of the noise -- the data of a
  causal model that follow from the noise of its nodes and the noise that
  follows from the data of the nodes -- with the upstream `dowhy.gcm._noise`
  code, which is where the expectations of the tests of the layer come from.
  The fixture of the layer is drawn from the generator of the `utils` package of
  the port, and the script reproduces that generator in Python, so that the
  fixtures of the port and the fixtures of the script are the same rows. The
  script holds a second fixture whose node has two parents and whose edges are
  added in an order that is not the sorted one, because the upstream takes the
  parents of a node in the sorted order.
- `gcm_feature_relevance_reference.py` computes the numbers of the feature
  relevance -- the relevance of every input of a linear model for every sample
  of the baseline, and the relevance of the parents of a node of a causal model
  -- with the upstream `dowhy.gcm.feature_relevance` code, which is where the
  expectations of the tests of the layer come from. The fixtures of the layer
  are drawn from the generator of the `utils` package of the port, and the
  script reproduces that generator in Python, so that the fixtures of the port
  and the fixtures of the script are the same rows. The upstream draws its
  permutations with the global generator of numpy, so the relevance it computes
  and the relevance the port computes are different numbers; the script prints
  the relevance of the upstream next to the relation the upstream test asserts,
  and the two agree to `3.9e-15`. The workers of the process pool of the
  upstream cannot import the stubbed packages, so the number of the jobs has to
  be set to one.
- `gcm_intrinsic_influence_reference.py` computes the numbers of the intrinsic
  causal influence -- the contribution of the noise of every ancestor of the
  target node to the variance of the target, and the contribution of the noise
  of every ancestor to a single sample of the target -- with the upstream
  `dowhy.gcm.influence` code, which is where the expectations of the tests of
  the layer come from. The fixture of the layer is drawn from the generator of
  the `utils` package of the port, and the script reproduces that generator in
  Python, so that the fixtures of the port and the fixtures of the script are
  the same rows: the variance of the target of the chain is `5.7182810415575`
  in both. The upstream draws its noise with the global generator of numpy, so
  the contributions it computes and the contributions the port computes are
  different numbers; what the two share is the relation the upstream test
  asserts, which is that the contribution of a node is the variance of the
  noise of that node. The assignment of the mechanisms of the upstream selects
  a model with a cross validation, which splits the data with the global
  generator of numpy, so the script has to seed that generator **before** the
  model is fitted; otherwise the numbers of the script differ from one run to
  the next. The upstream module `dowhy.gcm.influence` imports the
  names it needs from the package `dowhy.gcm`, which the loader stubs out, so
  the stub has to carry them **before** the module is read. The workers of the
  process pool of the upstream cannot import the stubbed packages, so the
  number of the jobs has to be set to one, and the `ShapleyConfig` of one job
  has to be handed to the call.
- `gcm_equation_parser_reference.py` computes the numbers of the equation
  parser -- the graph of the model the upstream builds out of a set of
  equations, the parents of every node and the predictions of the custom
  function of a node -- with the upstream `dowhy.gcm.equation_parser` code,
  which is where the expectations of the tests of the layer come from. The
  upstream module imports the names it needs from the package `dowhy.gcm`,
  which the loader stubs out, so the stub has to carry them **before** the
  module is read, and the constructor of `StructuralCausalModel` imports
  `dowhy.causal_graph`, which the stubbed packages do not reach, so their
  paths have to be pointed at the real directories of the upstream before the
  module is read. The upstream evaluates the custom function with the `eval` of
  Python, which returns a two dimensional array, so the script has to flatten
  it before it prints the numbers.
- `gcm_categorical_independence_reference.py` computes the numbers of the
  categorical variants of the regression based independence test -- the
  p-value of the upstream and the decision the upstream test asserts -- with
  the upstream `dowhy.gcm.independence_test.regression` code, which is where
  the expectations of the tests of the layer come from. The number of the
  samples of the fixture is the argument of the script. The workers of the
  process pool of the upstream cannot import the stubbed packages, so the
  number of the jobs has to be set to one.
- `replicate_port_pipeline.py`, `port_categorical_harness.py`,
  `check_categorical_stability.py`, `check_upstream_categorical_stability.py`,
  `compare_fit_on_upstream_matrices.py`, `compare_nystroem_normalisation.py`,
  `compare_model_b_design.py`, `sweep_least_squares_cutoff.py`,
  `sweep_nystroem_cutoff.py` and `search_categorical_seed.py` are the
  instruments of the investigation of the instability of the categorical
  independence test. They replicate the pipeline of the port in Python, so
  that the numbers of the port can be traced without running the toolchain,
  and they compare them with the numbers of the upstream on the same design
  matrices. They are the evidence for the note on the instability above.
- `gen_efficient_backdoor_testdata.py` generates
  `src/identifiers/test_efficient_graphs.mbt` mechanically from the fixtures of
  `tests/causal_identifiers/example_graphs_efficient.py`, so the expected
  adjustment sets of the eleven example graphs cannot be mistranscribed.
- `efficient_backdoor_reference.py` runs the upstream `EfficientBackdoor` on the
  eleven example graphs and prints the adjustment sets of the three strategies,
  which is where the expectations of the tests of the search come from.
- `efficient_backdoor_cut_probe.py` prints the flow network of one example
  graph, the maximum flow of the upstream, the cut the upstream computes and
  the minimum cut of the same network. It is the script that showed that the
  cut of the upstream is the cut that is contained in every other cut, and not
  the cut that `networkx.minimum_cut` returns.
- `efficient_backdoor_extra_reference.py` runs the upstream on the two graphs
  of the tests of the port that the upstream test file does not cover: the
  graph in which the treatment is a neighbour of the outcome, so no adjustment
  set exists, and the graph whose observable variables are not the ancestors of
  the treatment and the outcome.
- `optimized_backdoor_reference.py` runs the upstream optimized backdoor
  search on the six graphs of `tests/causal_identifiers/test_optimize_backdoor.py`
  and prints the sets it finds. It prints them twice, because the upstream
  breaks a tie in its hitting set algorithm with the iteration order of a
  dictionary of strings, and that order changes between the runs of the
  interpreter.
- `id_identifier_reference.py` runs the upstream ID algorithm on the six graphs
  of `tests/causal_identifiers/test_id_identifier.py` and prints the string of
  the estimand of each of them, which is the number the tests of the port
  compare with. The graphs have to be built with the nodes in the order of the
  graph string of the upstream, because the order of the nodes of the graph
  decides the order of the factors of the estimand.
- `two_stage_reference.py` runs the upstream identification and the upstream
  `TwoStageRegressionEstimator` on the rows of the upstream test
  `test_dowhy_chapter_7` and prints the frontdoor variables, the confounders of
  the two stages of the mediation, the estimate and the coefficients of the two
  stages, which is where the expectations of the tests of the two stage
  regression estimator come from. The upstream `CausalModel` cannot be read
  here, because it pulls in the graph learners, which need the package
  `causallearn`, so the script reads the graph with `networkx.parse_gml`, the
  way the upstream reads it, and calls the identification and the estimator
  directly. The module of the interpreters of the upstream is stubbed out for
  the same reason.
- `book_scm.py` holds the structural causal model of the upstream test
  `test_dowhy_chapter_7` and the rows it draws, and `gen_two_stage_testdata.py`
  generates `src/tests/book_testdata.mbt` from them. The rows are the rows of
  the upstream, because the fixture `fixed_seed` of the upstream test class
  seeds the generator of numpy with zero, so the reference script and the
  MoonBit test see the very same rows.
- `two_stage_estimator_reference.py` runs the upstream identification and the
  upstream `TwoStageRegressionEstimator` on the two cases of the upstream test
  file `tests/causal_estimators/test_two_stage_regression_estimator.py` and
  prints the frontdoor variables, the confounders of the two stages and the
  estimate, which is where the expectations of the tests of the port come from.
  The first case runs on the rows of the port, so that the two implementations
  work on the very same rows.
- `port_linear_dataset.py` replicates the generator of the `datasets` package
  in Python -- the xorshift64 generator, the draw order of the
  `linear_dataset` and its GML graph -- so that the upstream can be run on the
  rows of the port. The replication has to be checked against the port
  itself: the values of the columns have to be the same numbers, down to the
  last bit, while the sums of the columns are allowed to differ, because the
  native backend of the toolchain reassociates the reduction of a loop.
- `gen_two_stage_estimator_testdata.py` generates
  `src/tests/two_stage_testdata.mbt`, the rows of the upstream test
  `test_frontdoor_estimator`. The rows are the rows of the upstream, because
  the fixture `fixed_seed` of the upstream test class seeds the generator of
  numpy with zero.
- `print_frontdoor_graph.py` prints the graph string of the upstream test as a
  MoonBit literal. The upstream removes the newlines of the string, so the
  graph it reads is one long line, and the literal is generated rather than
  transcribed.