# moonbit_dowhy — working agreements

MoonBit port of [DoWhy 0.14](https://github.com/py-why/dowhy) (PyWhy).

## Toolchain conventions in this repository

These are properties of the MoonBit toolchain this repository builds with
(`moon 0.1.20261104`, `moonc v0.10.20+65efd5b93`); they are easy to get wrong
and costly to debug.

- **A derived trait is declared with `#derive(...)` before the type, not with
  `derive(...)` after it.** The trailing form is a deprecation warning on the
  current toolchain, and a warning is a failure in this repository. The
  `extend Type with Eq::{equal, not_equal}` declaration stays: the derived
  methods are promoted as ordinary methods, which is deprecated as well.

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
- **`do` is a reserved word**, so the port calls the do operator of the
  estimator and of the model `do_operator`.
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
- **A native crash says nothing; run the same test on `wasm`.** A native
  access violation surfaces as a bare `PanicError` with `at moonbit_panic` and
  `???` frames, the exit code `0xc0000005`, and **no output of the tests that
  ran before the crash**, because the standard output of the process is lost
  with it. The `wasm` target reports the actual error instead: a
  `RuntimeError: unreachable` under `tlsf/prepareSize` is the allocator that
  cannot satisfy a request, and the stack of the wasm runtime names the
  function that asked for it. The same is true of the index out of bounds,
  which the wasm runtime reports with the frames of the access. A native
  crash is therefore a *symptom*, and the wasm run of the same test is the
  diagnosis.

## Aliasing hazards

MoonBit's containers are mutable and a struct copy copies the *references* to
them, so a "copy" that only copies the struct shares its state with the
original. Five of these cost real debugging time here:

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
- **`IdentifiedEstimand::get_adjustment_set` hands out the array the estimand
  keeps.** Every caller that stores it or pushes onto it shares the state of
  the estimand: the estimator keeps it as its adjustment names, and the
  bootstrap refuter pushes the instruments onto it. The second one grew the
  adjustment set of the estimator that had been fitted before the refutation
  ran, so the design matrix of the estimate held more columns than the fitted
  coefficients. The getter keeps its behaviour -- it is documented in the
  upstream as well -- so the callers copy the array.

## Numerical conventions

The port reproduces DoWhy's numbers, so the following NumPy / pandas /
statsmodels / scikit-learn conventions are deliberate:

- The upstream draws its randomness from the global generator of numpy. The
  `utils` package carries that generator, the Mersenne Twister of numpy with
  its double, its normal variate, its Bernoulli and its integer, so a port
  that takes the seed of the upstream draws its numbers exactly. The double of
  numpy is built out of two words with the recipe of Python: the first word
  gives the high 27 bits and the second word gives the low 26 bits. The normal
  variate is the polar method of Marsaglia, which keeps the second variate of
  a pair for the next call. The Bernoulli is the binomial of one trial, which
  is the case the upstream uses; the binomial of more trials of numpy uses the
  algorithm of Kachitvichyanukul and Schmeiser, which is not ported. The
  multivariate normal of numpy needs the singular values and the singular
  vectors of the covariance, so the port takes the identity as its covariance,
  which is the covariance the upstream uses.
- The numbers that come out of a logarithm may differ by one unit in the last
  place between the backends of the toolchain, so the tests that compare such
  numbers use a tolerance.
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
- The E-value analysis of the `refuters` package follows two conventions of
  the upstream. The **standard deviation of the outcome** is the one of NumPy,
  with `ddof = 0`, and the **contrast of the treatment** scales the coefficient
  of the treatment and not its standard error, because the standard error of the
  estimator of the upstream already carries that contrast. The upstream reads
  the coefficient and the standard error of the *effect*, and the port reads
  the coefficient of the treatment and the standard error of the effect, which
  is the same arithmetic.
- The polynomial models of the `gcm` package expand their features the way
  `sklearn.preprocessing.PolynomialFeatures` with `include_bias=False` does,
  and the **order of the columns** of the expansion is the order of the
  upstream: the products of the degree one come first, then the ones of the
  degree two, and the products of one degree are ordered by the indices of the
  features they multiply. The expansion of two features of the degree two holds
  the columns `x0`, `x1`, `x0 * x0`, `x0 * x1` and `x1 * x1`; the expansion of
  three features of the degree three holds nineteen columns. The expansion
  happens **before** the centring of the fit, because the pipeline of the
  upstream expands the features before its linear regression sees them.
- The upstream fits the one-hot encoder of its categorical columns **inside**
  the model, so the expansion of the upstream sees the encoded columns; the
  port expands the design matrix it is given, so the caller encodes. The
  mechanism of the `gcm` package encodes before the fit, the way it does it for
  every other model.
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
- The randomised independence test of the `gcm` package is the port of
  `dowhy.gcm.independence_test.kernel.approx_kernel_based`, which is the
  randomised independence test of Strobl, Zhang and Visweswaran. The samples are
  mapped into the feature space of the Gaussian kernel with the Nystroem method,
  whose precision is the inverse of the median of the distances between the rows
  -- the median trick -- and the normalisation of the transformer inverts the
  square root of the kernel matrix of the basis points, like the normalisation
  of the Nystroem transformer of the regression based test. The inverse of the
  covariance of the features of the conditioning variable is computed with the
  Gauss-Jordan elimination of the `utils` package, like the inverse of the
  regressor of the conditional kernel based test, and not with the Cholesky
  factorisation of the upstream. The upstream draws its randomness from the
  global generator of numpy, so the p-value of the port and the p-value of the
  upstream are different numbers that agree on the decision the tests assert.
- The Bayesian Gaussian mixture distribution of the `gcm` package is the port of
  `dowhy.gcm.stochastic_models.BayesianGaussianMixtureDistribution`. The
  **number of the components** is chosen the way the upstream chooses it: the
  candidates are the numbers of the clusters of a k-means of the samples, the
  score of a candidate is the **silhouette score** of its clustering, and the
  search keeps the candidate with the best score and stops after three
  candidates in a row that do not improve it. The upstream draws the centres
  of its k-means at random and does not seed its generator, so the number of
  the components of the upstream is not reproducible; the port draws the
  centres from the samples that are the farthest apart, so the number of the
  components of the port is. The **fit** is the mean field variational update
  of the density estimator of the package, which is the model of the upstream:
  the upstream fits it with the variational inference of
  `sklearn.mixture.BayesianGaussianMixture`, whose centres it draws at random.
  The **samples** are drawn from the components with their weights, and the
  sample of a component is its mean plus the factor of the component applied to
  a standard normal vector; the factor is the product of the eigenvectors of
  the precision of the component with the inverse of the square roots of its
  eigenvalues, which is the square root of the covariance of the component.
- The stochastic models of the `gcm` package are the port of the distributions of
  `dowhy.gcm.stochastic_models`. The fit of the **beta** distribution takes the
  support of the samples -- the smallest and the largest of them -- and estimates
  the two shapes with the **method of moments**, where the upstream estimates the
  four parameters with the maximum likelihood. Both answers are inside the
  tolerances of the test of the upstream, which asks for a location of zero
  within `0.1`, a scale of one within `0.1` and the two shapes of two within
  `0.5`. The **automatic selection** of the family of a distribution fits every
  family the port knows -- the normal, the Laplace, the uniform and the beta --
  where the upstream fits every continuous distribution of scipy, and it keeps
  the first family whose Kullback-Leibler divergence of the nearest neighbour
  estimator is below the threshold. That divergence is noisy: with five hundred
  rows the divergence of the normal distribution of the fixture of the port is
  `0.058805`, which is above the threshold of `0.01` of the upstream, so the
  fixture of the port holds two thousand rows, where the divergence stays below
  the threshold and the normal distribution is selected like the upstream does.
- The function of the `gcm` package that gives the value of a target node from
  the noise of its ancestors is the port of
  `dowhy.gcm._noise.get_noise_dependent_function`. The noise is propagated
  through the graph of the target node, so that every node that has no path to
  the target node is left out of it, and the columns of the input of the
  function hold the noise of the nodes in the topological order of that graph.
  The **approximate branch** of the upstream fits its model on the samples of
  the **global generator of numpy**, while the port draws them from the
  generator it is given. The upstream raises
  `RuntimeError: EmpiricalDistribution has not been fitted!` on a model whose
  root node has a fitted distribution, because the view of the graph of the
  target node does not carry the distribution of the root node; the port copies
  the mechanisms of the model into the view, so its approximate branch works.
- The **noise of a root node with a categorical distribution** is the category
  of the node itself, the way the upstream draws it: the upstream copies the
  column of the noise into the column of the node, so the noise of a
  categorical root is a category and not a number. The port keeps the
  categories in the discrete column of the node, so the frame of the noise
  holds the numbers of the continuous nodes and the categories of the
  categorical ones in two kinds of column. The function of the target node of a
  categorical target therefore takes a frame and not an array of numbers, and it
  returns the categories of the target.
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
- The uniform distribution of the `gcm` package is the one of
  `scipy.stats.uniform`, whose support is the interval that goes **from the
  location to the location plus the scale**, so that `uniform(0.0, 1.0)` is the
  uniform distribution on `[0, 1]`. The port used to draw it on `[loc - scale,
  loc + scale]`, which is the convention of a symmetric uniform, and the
  upstream draws it on `[0, 1]`. The difference is invisible in the tests that
  compare the parameters of a distribution, but it moves every number that
  depends on the samples of a uniform root node: with the old convention the
  fraction of the samples of a node whose parents are uniform on `[0, 1]` and
  whose class is `"0"` when the sum of its two first parents is larger than one
  was `0.125` -- the fraction of the pairs of the uniform distribution on
  `[-1, 1]` whose sum is larger than one -- and it is `0.5` with the convention
  of scipy. The fit of a uniform is the maximum likelihood estimate of scipy as
  well, so the location is the smallest and the scale the range of the
  samples.
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
- The `unit_change` dispatcher of the `gcm` package is the port of
  `dowhy.gcm.unit_change.unit_change`. The upstream picks the linear
  attribution when its mechanism is a `LinearPredictionModel` and the non-linear
  attribution otherwise, and it attributes the change to the mechanism only when
  a foreground mechanism is given. The port picks the linear branch when the
  mechanism has coefficients, which means every model of the port but the
  nearest neighbour one, because the linear attribution reads the coefficients
  of the mechanism.
- The intrinsic causal influence of the `gcm` package is matrix valued: the
  attribution function receives the predictions of the target as a matrix and
  not as an array of numbers, the way the upstream shapes them with
  `shape_into_2d`. The predictions of a continuous target hold one number per
  row and the predictions of a categorical target hold one probability per class
  and per row, so the attribution function of a categorical target is the
  negative entropy of the probabilities of the classes.
- The noise of a node with a categorical mechanism is uniform on `[0, 1]` and it
  selects the class of the sample, and the column of such a node holds the
  classes of the node and not numbers. The upstream draws the noise of a
  categorical node from a uniform distribution and its column holds the labels
  of the node.
- The number of the rows of a unit change attribution is the number of the rows
  of the data, and **not** the number of the input columns. `inputs_of` returns
  the columns of the data, so `background_inputs.length()` is the number of the
  inputs; the row count is `background_data.nrows()`.
- The partial correlation of the `utils` package is the one of the upstream
  `dowhy.utils.cit`: the covariance of the columns drops the degree of freedom,
  the pseudo inverse of the covariance matrix cuts its eigenvalues off at
  `1e-15` of the largest one, the p-value of the Student-t test is rounded to
  five decimals and the confidence interval of the Fisher z transform to
  three. The upstream writes the binary column of a node of its random graph
  with `numpy.vectorize(convert_to_binary)`, and the function it vectorizes
  returns an array of one element, so the call fails with the numpy of the
  version two; the port draws the column the way the upstream means it, with
  one Bernoulli variate per row.
- The conditional mutual information of the `utils` package is the number of
  the upstream: the upstream reads the *names* of the columns of the two
  variables and not their values, so its number is the negative entropy of the
  conditioning columns. The port reproduces that number, because the verdict
  of the graph refuter of the upstream depends on it. The upstream hashes the
  key of the result of a conditional independence with a list of the variables
  that are conditioned on, which cannot be hashed, so the port keys the results
  with the text of the two variables and of the variables that are conditioned
  on.
- The do operator of the `estimators` package and of the root package is the
  port of `dowhy.causal_estimator.CausalEstimator.do` and of
  `dowhy.causal_model.CausalModel.do`: it returns the mean of the
  interventional outcomes of the data, which is the value of the outcome under
  the intervention and not the difference between the two arms. The upstream
  keeps the data it was fitted on in its estimator, and the port keeps no data
  in the estimator, so the data is an argument of the method. The name of the
  upstream is `do`, and `do` is a reserved word of the toolchain, so the port
  calls the method `do_operator`.
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
- The classifier based divergence of the `gcm` package fits its classifier with
  the penalty of the upstream, which is the `L2` penalty of
  `sklearn.linear_model.LogisticRegression` with its default `C = 1.0`. The
  penalty is not a detail: the one-hot encoding of a categorical column and the
  intercept are collinear, so the design of a sample with a categorical column
  is rank deficient. The penalty of the upstream lifts that degeneracy, while
  an unpenalised fit has to solve a singular weighted normal equation, and the
  pseudo inverse of it is then dominated by its noise: the estimate of such a
  sample came out as zero or as a value of ten, where the upstream gives
  `0.428` and `0.712`.
- The automatic divergence of the `gcm` package asks the caller whether the
  sample is a categorical one, with the flag `categorical` of
  `auto_estimate_kl_divergence`. The upstream detects it from the dtype of its
  numpy array, and a matrix of the port holds numbers only, so the flag
  carries the information the dtype would carry.
- The geometric median of the `gcm` package is the one of the Weiszfeld
  iteration, while the upstream minimises the sum of the distances with
  `scipy.optimize.minimize`. The two reach the same optimum, but not to the
  last digit: on the fixture of the upstream test file `tests/gcm/test_stats.py`
  they agree to `5e-6`, where the upstream asserts a tolerance of `0.5`.
- The marginal expectation of a classifier of the `gcm` package compares the
  probability of the second class, where the upstream compares the sum of the
  differences of the two classes. The logistic regression of the port and the
  one of scikit-learn reach the same coefficients to `1e-2` on that quantity,
  where the upstream asserts a tolerance of one.
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
- The placebo of the placebo treatment refuter of the `refuters` package is
  built the way the upstream builds it: a continuous treatment becomes the
  constant zero, a binary treatment becomes a random Bernoulli variable with
  the probability of a half, and a categorical treatment becomes a random draw
  of one of the **distinct** categories of the column. The permuted placebo
  takes the rows of the treatment and permutes them. The kind of the treatment
  follows the column and not a dtype, because the frame of the port holds no
  dtype: a discrete column is a categorical treatment, a numeric column whose
  values are all zero and one is a binary treatment and every other numeric
  column is a continuous one.
- The significance test of a refutation is the port of
  `dowhy.causal_refuter.test_significance`: the automatic test uses the two
  sided percentile test of the bootstrap for a hundred simulations and more and
  the test of the normal distribution below that. The bootstrap test counts the
  estimates that are above the estimate and the half of the ones that are equal
  to it, and the normal test takes the z-score of the estimate against the mean
  and the standard deviation of the simulations, with `ddof = 0`. The
  refutations that sever the causal relation -- the placebo and the dummy
  outcome -- test the **zero** estimate against the estimates they produced,
  the other ones test the estimate of the data.
- The bootstrap refuter of the `refuters` package resamples the rows of the data
  **with** replacement and perturbs the variables of interest, the way the
  upstream does: a numeric column gets a Gaussian noise whose standard
  deviation is the given fraction of the standard deviation of the column, a
  column of zeros and ones is flipped and a discrete column gets another
  category, both with the probability of the change. The probability of the
  change is the noise unless it is given, the way the upstream derives it. The
  data subset refuter samples its subset **without** replacement, the way the
  upstream does with `data.sample(frac=subset_fraction)`.
- The variables the bootstrap refuter perturbs are named with an enumeration,
  `RequiredVariables`, and not with the `bool | int | list` of the upstream.
  The enumeration holds a case for every variable of interest, for no variable
  at all, for a number of them, for a list of names and for a list of the names
  to leave out. The upstream raises an error for a list that names both the
  variables to keep and the variables to leave out, and the enumeration cannot
  express such a list.
- The propensity score matching estimator of the `estimators` package matches
  every treated unit with the control unit whose propensity score is the
  closest, and a tie is broken with the index of the unit: the first unit with
  the smallest distance wins, which is the rule of a scan over the units. The
  search is a binary search over the sorted scores, so it costs `O(log n)` per
  unit instead of the `O(n)` of the scan, and it picks the same unit.
- The logistic regression of the `utils` package is fitted with the iteratively
  reweighted least squares, and the weighted normal equations of a step are
  accumulated over the rows of the design matrix. The diagonal weight matrix
  would hold `n * n` doubles, which is eighty gigabytes for the hundred
  thousand rows of the upstream test suite, so it is never built.
- The propensity scores of the `estimators` package are **not** trimmed by
  default. The upstream trims them in the inverse propensity score weighting
  estimator (to `0.05` and `0.95`) and in the doubly robust estimator (to
  `0.01` and `0.99`), and it does not trim them in the matching estimator and
  in the stratification estimator. The trimming creates huge groups of equal
  scores, which moves the strata of the stratification estimator and the
  matches of the matching estimator: on the hundred thousand rows of the
  upstream estimator test suite the estimate of the stratification estimator
  is `10.0001` with the raw scores and `10.308` with the trimmed ones, while
  the upstream gives `10.0001`. The two estimators that trim them trim them
  themselves, and the doubly robust estimator trims the scores of the two arms
  separately, the way the upstream does.
- The number of strata of the propensity score stratification estimator of the
  `estimators` package is either given or searched for, the way the upstream
  searches for it: the search starts with `0.5 * rows / clipping_threshold`
  strata and halves the number until at least half of the strata hold more
  than `clipping_threshold` units of both arms. The upstream test file uses
  the search, and it is what makes the estimate of the estimator agree with
  the upstream to `1e-14` on one common cause.
- The rows of the data sets of the upstream test suites are drawn by the
  upstream with the global generator of numpy, so the upstream runs its
  estimator and refuter test suites on a random draw of the rows. The rows of
  the port are fixed, and the seed of every suite is the one for which the
  **upstream** stays inside the tolerances of its own test files on the very
  same rows: `_verify/estimator_suite_reference.py` runs the upstream on the
  rows of the port. Two of the eighteen cases of the estimator suite are
  decided by the draw: the inverse propensity score weighting estimator with
  two common causes and the doubly robust estimator with two common causes and
  a binary outcome are both outside the tolerance of the upstream on the rows
  of the seed 42, and the upstream is outside it as well.
- The multiply-robust causal change attribution of the `gcm` package is the port
  of `dowhy.gcm.distribution_change_robust`, and three details of it decide
  whether the attribution is the one of the upstream:
  - **the functional of the variance is the second moment of the target minus
    the square of the first moment of the target.** The upstream writes it as
    `(theta(y²) - theta(y)) ** 2`, but the exponent of Python binds tighter
    than the subtraction, so the upstream computes `theta(y²) - theta(y) ** 2`.
    The port computes the functional of the upstream, and the attribution of the
    variance is about twenty times smaller than the square of the difference
    would give.
  - **only the weights of the last group of the estimator are standardised.**
    The upstream standardises the weights outside its loop over the groups, so
    the weights of the other groups keep their scale. The port standardises the
    last weight alone, the way the upstream does.
  - **the estimate of the change is the mean of the scores of the estimator,
    and its standard error is the one of
    `statsmodels.stats.weightstats.DescrStatsW` with the weights of one**, so
    the standard error is the standard deviation of the scores with `ddof = 0`
    divided by the square root of the number of the scores less one.
- The nearest neighbour regression of the `gcm` package finds the neighbours of
  a row with a walk over the rows that are sorted by their first column. The
  walk stops as soon as the rows that are left are further away than the
  neighbours that were found already, which is the exact rule of a scan over
  every row, and it costs `O(n log n)` instead of the `O(n^2)` of the scan.
- **The upstream cannot build a data set with a binary treatment with the
  numpy of today.** Its `dowhy.datasets.linear_dataset` converts the treatment
  with `numpy.vectorize(convert_to_binary)`, and `convert_to_binary` returns
  an array of one element, which numpy 2 refuses with `ValueError: setting an
  array element with a sequence`. The upstream 0.14 predates numpy 2. Every
  upstream test file that uses a binary treatment therefore fails in the
  upstream itself: the test file of the instrumental variable estimator for
  its eight binary configurations, and the test file of the regression
  discontinuity estimator for its only configuration. The port draws its rows
  with its own generator, so the port runs the cases, and the reference
  scripts hand the upstream the rows of the port, so the upstream runs on them
  as well.
- **The upstream test file of the regression discontinuity estimator is broken
  a second time.** The estimator of the upstream keeps the name of the running
  variable, the threshold and the bandwidth at `None` when the caller does not
  give them, and its fit reads `data[None]`, which is a column of the data
  frame that does not exist. The estimator of the port takes the three values
  as arguments.
- The rows of the cross-fitting of the multiply-robust change attribution are
  split by the port with its own shuffle and by the upstream with the
  `StratifiedKFold` of scikit-learn. The two splits differ, so the attribution
  of the port and the attribution of the upstream are close to each other and
  not equal to each other: on the ten thousand rows of the upstream test file
  they agree to `0.004` for the mean and to `0.05` for the variance. The
  re-weighting method, which does not use the regressor, agrees to `0.001`.

- The program of the rules of the `overrule` package is solved in its
  **aggregated** form: the rows of the program that cover the same covariates
  are collapsed into one group with a weight, and the program is solved through
  its dual, because the dual has a feasible basis. The aggregation keeps the
  value of the program and the weights of the rules, and the shadow price of a
  group is shared by its rows, so the residuals of the rows of a group are the
  same number. The upstream solves the program with `cvxpy` and the solver
  `CLARABEL`, and the reference script solves it with the `HiGHS` solver of
  `scipy` instead.
- The cross fitting of the propensity model of the `overrule` package fits the
  model of a fold on the rows of the **other** fold and predicts the rows of
  its own fold. The design matrix and the target of a fold therefore hold the
  same rows, which is the convention of
  `sklearn.model_selection.cross_val_predict`.
- The rules of the `overrule` package are learned with the generator of the
  port, and the reference samples of the upstream are drawn with the global
  generator of numpy, so the rules of the port and the rules of the upstream are
  not always the same rules. The upstream test file accepts a set of equivalent
  rule sets for the same reason, and the port asserts that the rules are one of
  them. The program of the **overlap** rules does not depend on the reference
  samples, so its value is the same number in the port and in the upstream:
  `0.00285` on the fixture of the upstream test file.

- The check of a backdoor set and of a frontdoor set take the algorithm of
  the upstream as an enumeration, `DseparationAlgorithm`, instead of the string
  `dseparation_algo`. The default branch of the frontdoor check asks for the
  d-separation of the graph, which is what the upstream does when the caller
  names no algorithm, and the naive branch asks for every directed path from
  the treatment to the outcome to be blocked.
- The graph of the daggity web site of the upstream test file
  `tests/test_causal_graph.py` is a literal of the port, `daggity_fixture`,
  because the library has no file system. It is generated from the upstream
  file `tests/sample_dag.txt` by `_verify/gen_graph_fixture.py`.

- The `is_categorical` and `has_categorical` of the `gcm` package decide
  whether a column is categorical from the kind of the column of the frame, and
  not from a numpy dtype, because the frame of the port holds no dtype: a
  discrete column is categorical and a numeric one is not. The upstream asks
  the same question of the dtype and refuses a categorical input that holds
  missing values; the frame of the port holds no missing value.
- The one-hot encoding of a matrix that holds a numerical column among the
  categorical ones expands every categorical column into one column per
  category in lexicographic order and keeps the numerical column in place, so
  the fixture of the upstream test
  `[[d, 1, a], [b, 2, d], [a, 3, a]]` becomes
  `[[0, 0, 1, 1, 1, 0], [0, 1, 0, 2, 0, 1], [1, 0, 0, 3, 1, 0]]`.

- The generalised covariance measure of the `gcm` package takes its
  conditioning variable as a frame in `generalised_cov_based_with_categorical`
  and encodes its categorical columns itself, with the one-hot encoding of the
  package. The upstream passes the conditioning variable to the automatic model
  selection of `dowhy.gcm.auto`, which encodes it; the two routes agree to about
  `1e-3` on the categorical fixture of the upstream test file
  `tests/gcm/independence_test/test_generalised_cov_measure.py` and lead to the
  same decision on six seeds.

- The default strength of the confounder of the `refuters` package is the port
  of `_infer_default_kappa_t` and `_infer_default_kappa_y` of the upstream, and
  three conventions of the upstream decide whether the port reproduces its
  numbers:
  - **the common causes are the adjustment set of the estimand, encoded and
    standardised.** The discrete columns are one-hot encoded with the first
    category of every column dropped, the way the upstream encodes them, and
    every column is standardised with the mean and the standard deviation of its
    rows, the way the `StandardScaler` of the upstream standardises them.
  - **the `binary_flip` effect counts the flips of the predictions of a logistic
    regression.** The regression is fitted on the standardised common causes
    with the column as the response, the intercept is not penalised, the way
    scikit-learn does not penalise it, and the strength of a common cause is
    the share of the rows whose prediction changes when the common cause is set
    to zero. The classification of a row is the one of scikit-learn: the class
    of the larger probability, and the first class when the two probabilities
    are the same.
  - **the `linear` effect scales the correlation of every common cause with the
    standard deviation of the column.** The upstream reads that standard
    deviation with `np.std(t)[0]`, and the standard deviation of a column is a
    number and not an array, so the branch raises an `IndexError` on the numpy
    of today. The port computes the number the branch means to compute.

- The readers of the temporal graphs of the `timeseries` package take the text
  of the files the upstream reads, because the library has no file system.
  Three conventions of the upstream decide whether the port reproduces its
  numbers:
  - **the CSV holds the columns `node1`, `node2` and `time_lag`.** The columns
    are found by their name, the way the upstream reads them by their name, and
    a time lag that is not a number makes the reader give no graph, the way the
    upstream returns `None` when it cannot read the lag of a row. A time lag
    that is written with a fraction or with an exponent is truncated toward
    zero, the way `int` truncates a float.
  - **the DOT holds the time lags of an edge in its `label` attribute.** The
    lags are written between parentheses and separated by commas, the way the
    upstream writes them, and the reader takes the parentheses off and reads
    every part as an integer. An edge without a label is left out of the graph,
    the way the upstream leaves it out.
  - **the entries of one edge are merged in two ways.** The reader of a CSV
    appends the lag of a row to the lags of the edge, and the reader of a DOT
    replaces them with the lags of all the entries without their duplicates.
    The upstream merges the entries of a DOT file with a set, whose order is
    the order of the set of the interpreter, and the port keeps the order of
    the entries.

- The sales data set of the `datasets` package is the port of
  `dowhy.datasets.sales_dataset`, and four conventions of the upstream decide
  whether the port reproduces its numbers:
  - **the range is a number of days and not a pair of dates.** The upstream takes
    a start date, an end date and a frequency and builds the range with
    `pandas.date_range`; the port takes the number of the days and a seed of its
    own, because it draws its numbers with the generator of the package and not
    with the global generator of numpy. The `Date` column holds the date of the
    day as a string of the form `YYYY-MM-DD`, where the one of the upstream holds
    the timestamps.
  - **the change of the price is measured against the original price and not
    against the base price.** A day whose price is the original one therefore has
    no change of the price at all, and the upstream replaces such a change by
    one, which makes the ratio of the demand and of the change the elasticity of
    the demand on those days. The port reproduces the replacement, because the
    relations of the upstream case depend on it: the discount of the second
    fixture has to sell *more* units than the first one, because the elasticity
    answers the smaller price of that fixture.
  - **the Poisson draws invert the cumulative distribution.** The inversion starts
    ten standard deviations below the mean, where the probability of the
    distribution is below `1e-23` and where the mass of the distribution is still
    representable; a mean below thirty is drawn with the method of Knuth. The
    means of the frame of the port are within a percent of the ones of the
    upstream.
  - **the days of the shopping events are drawn without replacement**, so every
    day of the range holds at most one event.

- The model selection of the automatic assignment of the `gcm` package is the
  port of `dowhy.gcm.auto.select_model` and of
  `dowhy.gcm.auto.find_best_model`. The folds of the cross validation are the
  same for every model of the zoo, they are the folds of a k-fold cross
  validation for a continuous target and the folds of a stratified k-fold cross
  validation for a categorical one, and the score of a model is the mean of the
  metric over the folds: the mean squared error for a regression and the log
  loss for a classification. The encoder of the parents is fitted on the
  training rows of a fold and applied to its held out rows, the way the
  upstream fits its encoders. The zoo of the port holds the linear and the
  nearest neighbour regression for the `GOOD` quality and the polynomial
  regression as well for the `BETTER` quality; the nearest neighbour
  regression is the non-linear model of the port, the way the histogram
  gradient boosting regression is the non-linear model of the upstream. The
  port shuffles the rows with the generator of the `utils` package, whose seed
  is an argument of the functions, because the upstream uses the global
  generator of numpy and does not seed it.
- The test of a linear relationship of the `gcm` package is the port of
  `dowhy.gcm.auto.has_linear_relationship`. The upstream compares the linear
  regression with the histogram gradient boosting regression for a continuous
  target, and the logistic regression with the histogram gradient boosting
  classifier for a categorical one; the port compares the ordinary least
  squares regression with the nearest neighbour regression, and the logistic
  regression with the nearest neighbour classifier. The nearest neighbour model
  is the non-linear model of the port here as well: it is decisively worse than
  the linear model on a linear relation and decisively better on a curved one,
  while the polynomial regression is a numerical tie with the linear one on a
  linear relation.
- The split of the test of a linear relationship follows the split of
  `sklearn.model_selection.train_test_split`: seventy percent of the rows are
  the training part, the rows that are left are the test part and the part of a
  categorical target is stratified. The share of a class in a stratified split
  is the share of its rows, the shares are rounded down and the rows that are
  left over go to the classes whose share has the largest remainder, the way
  `sklearn.model_selection._approximate_mode` gives them; the upstream picks
  the classes of the largest remainder at random when several of them have the
  same remainder and the port picks them in the order of the classes. A class
  that holds a single row is duplicated before the split, the way the upstream
  duplicates it, so that the stratified split can put one of its rows in each
  part.
- The encoder of the test of a linear relationship is the one of
  `dowhy.gcm.util.general.auto_fit_encoders`: the one-hot encoder when the
  data holds at most seven categories and the CatBoost encoder otherwise. The
  CatBoost encoder of the `gcm` package is the port of
  `dowhy.gcm.util.catboost_encoder.CatBoostEncoder`: the value of a category is
  the mean of the target of its rows and the mean of the target of the whole
  column, and a category that holds a single row takes the mean of the whole
  column.
- The CatBoost encoder of the `gcm` package has two forms, and they are not
  the same number. The encoding without the target is the mean of the target of
  the rows of the category, smoothed with the mean of the target of the whole
  column, and a category that holds a single row takes the mean of the whole
  column. The encoding with the target leaves the row itself out of the mean of
  its category: the value of a row is the mean of the target of the rows of its
  category that come before it, smoothed with the mean of the target of the
  whole column. That is the equation (1) of the CatBoost paper, the way
  `dowhy.gcm.util.catboost_encoder.CatBoostEncoder` computes it with a
  cumulative sum over the rows of the category.
- The noise of a root node with a categorical distribution is a category, so
  the noise samples of the ancestors of the target of the intrinsic causal
  influence hold a column of categories. The layer encodes such a column with
  the one-hot encoder, the way the upstream encodes the data of its
  independence tests, and the layout of the encoding tells which columns of
  the matrix hold the noise term of which node. The randomization of the noise
  terms permutes the rows of all the columns of a node in the same way, so the
  one-hot columns of a node stay consistent.
- The categorical data of the kernel based independence test of the `gcm`
  package is encoded with the one-hot encoder of
  `sklearn.preprocessing.OneHotEncoder`, the way the upstream encodes every
  matrix of its test on its own: the categories of a column are in
  lexicographic order and every category becomes a column of its own. The
  matrices of the port hold numbers only, so the encoding happens at the call
  site of the test. The p-values of the port and of the upstream differ by less than
  `5e-12` on the categorical fixture of the test.
- The falsification layer of the `gcm` package encodes the columns that hold
  categories with the one-hot encoder before it builds the design matrix of a
  test, the way the upstream encodes every matrix of its independence test on
  its own. The p-values of the port and of the upstream agree to `2e-12` on the
  categorical fixture of the upstream test of the layer. The assertions of that
  case use the tolerance of the kernel test of the package, which is `1e-10`
  relative, and not the tolerance of the other tests of the layer, which is
  `1e-12`: the upstream draws a random permutation of the rows and the port
  draws them in the order of their indices.
- The attribution of the anomalies without a causal model of the `gcm` package
  is the port of `dowhy.gcm.anomaly.attribute_anomaly_scores`. The set function
  of the score permutes the rows of the columns that are not in the subset, so
  that the subset represents an interventional distribution, and it replaces the
  columns that are in the subset with the values of the anomaly sample. The
  score of a sample is either the information theoretic score, which is the
  logarithm of the relative frequency of the scores of the distribution that
  are at least the score of the anomaly, or the deviation of the score from its
  expectation, which is the feature relevance of the upstream. The upstream
  draws the centres of the components of its Gaussian mixture at random and does
  not seed its generator, so the contributions of the upstream and of the port
  are different numbers; the two make the same decision on the fixture of the
  port.
- The feature relevance of the parents of a node with a categorical target of the
  `gcm` package is the port of `dowhy.gcm.feature_relevance.parent_relevance`.
  The upstream evaluates the set function once per subset, with one permutation
  of the background that it shares with every sample of the baseline, and it
  averages the values of the set function over the samples of the baseline; the
  port estimates the Shapley values of every sample of the baseline on its own
  and averages them, which is the same thing in expectation, because the
  Shapley value is linear. The port compares the **indices** of the classes of
  the target and the upstream compares the labels themselves, which is the same
  comparison.
- The **sharpness** of the classifier decides the relevance of the noise of a
  categorical target. The upstream draws the class of a sample with a uniform
  noise, so a classifier whose probabilities are certain leaves the noise
  without any influence and the relevance of the noise is zero, while a soft
  classifier lets the noise flip the class and the relevance of the noise grows.
  The upstream uses its default classifier in that case, which is the histogram
  gradient boosting classifier, and the port uses the nearest neighbour
  classifier with one neighbour, which is sharp in the same way. The logistic
  regression of the port is too soft for that case: its relevance of the noise
  is `0.093` and its relevance of the two parents that determine the class is
  `0.070` and `0.062`, while the nearest neighbour classifier gives `0.000` for
  the noise and `0.114` and `0.091` for the two parents.
- The upstream cannot catch an exception, so the cases of the upstream test files
  that expect one are ported as **predicates**. The unit change layer exposes
  `can_evaluate_unit_change_linear` and `can_evaluate_unit_change_nonlinear`,
  which are the `AttributeError` and the `NotFittedError` of the upstream, and
  the layer aborts when the mechanism of a node is not fitted or when it has no
  coefficients, which is the `AttributeError` of the upstream.
- The mechanism of a node of the `gcm` package can be the model of an equation
  of the port, which is the relation of the node itself and not a fit of it.
  The upstream sets such a mechanism to a model of its own, and the port
  expresses the same model with its equation parser. The difference matters
  outside of the rows of the training data: a fitted polynomial model of the
  second degree is the same relation on the rows of the training data, but its
  prediction at an anomaly sample, which is far outside of them, is off by
  about `6.6`, and that error moves the contribution of the target of the
  attribution of the anomalies from `9.6` to `4.1`.
- The what-if queries of the `gcm` package with the categorical variables and
  with the discrete data follow the upstream `dowhy.gcm.whatif`. The class of a
  categorical target is drawn with a uniform noise on `[0, 1]`, and the class is
  the first one whose cumulative probability reaches the noise, so the number of
  the samples that hold the expected class is a random number; the generator of
  the `utils` package is seeded, so the number is the same number at every run.
  The upstream fits the histogram gradient boosting regression on the target of
  the discrete additive noise model; the port fits the nearest neighbour
  regression, which is the non-linear model of the port. The upstream `dowhy.gcm`
  is run on the very rows of the port by `_verify/gcm_whatif_reference.py`, which
  replicates the generator of `src/utils/random.mbt`; the two make the same
  decision on them: the median of the target of the discrete fixture is `-1` on
  both sides and the mean of its descendant is about `-2` on both sides.
- The summary of the automatic assignment of the `gcm` package reproduces the
  text of `dowhy.gcm.auto.AutoAssignmentSummary.__str__` character for
  character: the name of the distribution of a root node is `Empirical
  Distribution`, the name of a mechanism is `AdditiveNoiseModel using ...`,
  `Discrete AdditiveNoiseModel using ...` or `Classifier FCM based on ...`,
  and the relation of a discrete node is introduced by `This represents the
  discrete causal relationship as`.
- The Gaussian mixture of the `gcm` package is fitted with the mean field
  variational update of Bishop: the responsibilities of the components use the
  expectations of the log weights, of the log determinant of the precisions and
  of the quadratic form of the precisions, and the parameters of the components
  use the responsibilities. The upstream fits the same model with the
  variational inference of `sklearn.mixture.BayesianGaussianMixture`, whose
  centres it draws at random, so the numbers of the upstream are not
  reproducible: the numbers of the port are the ones of the same model and not
  the ones of the upstream's fit.
- The **missing values** of the `gcm` package follow the experimental flag of
  the upstream, `experimental_allow_nans`, which the port takes as the optional
  argument `allow_nans` of `assign_causal_mechanisms`. The upstream raises
  when the data holds a missing value and the flag is not set; the port
  aborts, because MoonBit cannot catch an error, so the predicate of the
  check is a function of its own, `DataFrame::has_missing_values`. The
  upstream drops the rows whose **target** holds a missing value and keeps the
  rows whose **features** hold one, because its histogram gradient boosting
  model reads them; the port has no model that reads them, so it drops the
  rows that hold a missing value in a feature as well. The rows that are left
  out are the rows of `DataFrame::complete_rows`, and both the selection of
  the model of a node and the fit of the mechanism of a node use them, so the
  two agree on the model they fit.
- The **random forest** of the `refuters` package is the port of the
  `RandomForestRegressor` of scikit-learn: a hundred trees, a sample of the
  training rows with replacement for every tree, the square root of the number
  of the features at every split, the sum of the squared errors as the
  criterion of a split and the mean of the samples as the value of a leaf. The
  upstream draws the samples of every tree and the features of every split
  with the global generator of numpy, which it does not seed; the port draws
  them with its own generator, so a forest of the port is the same forest on
  every run. The nodes of a tree are held in one array and the children of a
  node are named by their index in that array: the tree is grown with the
  array as an argument, so the index of a node is known as soon as it is built
  and the children of a node never have to be moved.
- The **neural network** of the `refuters` package is the port of the
  `MLPRegressor` of scikit-learn: the loss is the half of the mean of the
  squared errors of the rows plus the half of the penalty of the weights times
  their squared length over the number of the rows, and the gradient is the one
  of the backpropagation of scikit-learn, whose delta of the output layer
  carries no factor of the number of the rows. The two agree with scikit-learn
  to `3.6e-15` and to `1.8e-15` on the fixture of
  `_verify/neural_network_reference.py`, the difference of the order of the
  summations. The optimiser of the port is a limited memory BFGS with the two
  loop recursion and a backtracking line search of the Armijo condition, which
  is the family of the L-BFGS-B of scipy that scikit-learn uses; the objective
  of a network with a ReLU activation is not convex, so the two reach a nearby
  but not identical point of it. The upstream draws the initialisation of
  Glorot of its network with the global generator of numpy, which it does not
  seed; the port draws it with its own generator, so a network of the port is
  the same network on every run.

- The **support vector regressor** of the `refuters` package is the port of the
  `SVR` of scikit-learn: the radial basis kernel, whose width is the inverse of
  the number of the features times the variance of the training data with
  `ddof = 0`, the penalty `C` and the width of the tube of the epsilon
  insensitive loss of the caller. The solver is the one of libsvm, the library
  scikit-learn uses: the rows are duplicated, the first copy of every row
  carries the label +1 and the second one the label -1, the matrix of the kernel
  is signed, the linear term of the copy with the label +1 is `epsilon - y` and
  the one of the copy with the label -1 is `epsilon + y`, and the solver updates
  two variables at a time until the spread of the signed gradient of the copies
  falls below its tolerance, which is the tolerance of scikit-learn. The kernel
  is computed row by row and never held in memory, so a fit needs the memory of
  the rows and not the memory of their matrix. The dual of the epsilon
  insensitive loss is not strictly convex, so two solvers of the same tolerance
  reach a nearby but not identical point of the tube; the port and scikit-learn
  agree to `6.9e-8` on the fixture of
  `_verify/support_vector_machine_reference.py`.

- The **decision tree** of the `gcm` package is the port of the
  `DecisionTreeClassifier` of scikit-learn with its default parameters: the gini
  impurity as the criterion, every feature of the design matrix at every split,
  a node of at least two samples and a leaf of at least one sample. The tree
  grows greedily and the threshold of a feature is the middle of two
  consecutive values of it, so a row goes to the left child of a node when the
  value of the feature is at most the threshold. The tree of scikit-learn breaks
  the tie of two splits of the same impurity at random, because it takes its
  randomness from the global generator of numpy, which it does not seed; the
  tree of the port breaks the tie the other way, the first feature and the first
  threshold of it win. The decision tree is the non-linear classifier of the zoo
  of the port, the way the histogram gradient boosting classifier is the
  non-linear classifier of the zoo of the upstream.

- The plotting layer of the library draws nothing: MoonBit has neither
  Graphviz nor matplotlib, so the port computes the attributes the two
  backends of the upstream compute -- the width of the arrow of an edge,
  the label and the colour of the nodes and of the edges, the layer of
  every node and the error bars of a bar plot -- and it writes the
  attributes of the Graphviz backend as a Graphviz DOT document. The
  width of an arrow is `0.1 + 4.0 * abs(strength) / max_strength`, and it
  is `4.1` when the graph holds no strength; the upstream refuses a
  negative largest strength, so the width of the port is `None` there.
  The label of an edge is the strength truncated towards zero to two
  decimals, so the label of the strength `0.29` is ` 0.28`, and it is
  `Inf` for an infinite strength, whose arrow is drawn with the width of
  the strength of a hundred.
- The count of the nodes vertically of the networkx backend of the
  upstream is the maximum of the numbers of the layers and of their
  counts, because it takes the maximum of the pairs of the layer and of
  the count. The port does the same.
- The data generating processes of the `datasets` package are the port of
  `dowhy.utils.dgp` and of the three processes of `dowhy.utils.dgps`, and the
  **order of the draws** of the upstream is a part of its numbers. The linear
  process draws the weights of the process, the confounder and the noise of the
  treatment. The quadratic process draws the confounder, the effect modifier,
  the weights and the noise of the treatment. The cubic process draws the
  confounder, the effect modifier and then the weights and the noise of the
  treatment of every power. The linear process raises the weight of the first
  confounder by a hundred, the quadratic and the cubic process do not.
- The Bernoulli of the generator of numpy is the binomial of numpy with one
  trial, and the binomial of numpy takes the complement of the probability when
  the probability is greater than one half, so the trial of the complement runs
  the other way. A trial of a probability of at most one half is a one when the
  double is greater than the complement of the probability, and a trial of a
  probability above one half is a one when the double is at most the
  probability. The threshold of the comparison is the one of numpy, which
  takes the logarithm of the probability and the exponential of it, so the
  threshold and the probability differ by one unit in the last place.
- The distance matching estimator of the `estimators` package compares the
  candidates with the **sum of the powers of the differences** of their
  covariates, which is the distance raised to the exponent of the Minkowski
  metric. It is the number the ball tree of scikit-learn compares, and the root
  of it is a monotone function, so the two order the candidates the same way.
  The port searches with an exact scan and breaks a tie between two candidates
  at the same distance with the **order of the rows**; the upstream breaks it
  with the order of the traversal of its ball tree. The fixture of
  `_verify/distance_matching_reference.py` holds no pair of candidates at the
  same distance, so the numbers of the port and of the upstream are the same.
- The distance matching estimator encodes the data of the estimate with the
  encoder that was fitted with the estimator. The upstream caches the encoded
  common causes when the estimator is fitted and pairs them with the outcomes
  of the data of the estimate, so an estimate on other data pairs the
  covariates of the fitted data with the outcomes of the other data.
- The stratum of every row of the data is the rounded rank of the propensity
  score, scaled by the number of the strata, and the number of the strata is
  searched for the way the upstream searches for it: the search starts with
  `0.5 * rows / clipping_threshold` strata and halves the number until at
  least half of the strata hold more units of both arms than the threshold.
  The upstream adds the stratum to the data as a column, and the port keeps it
  out of the data of the caller.
- The balance of the `interpreters` package takes the difference of the two
  means of a common cause as the absolute difference, because the upstream
  takes it as the difference of the largest and the smallest of them. The
  standard deviation of a common cause is the one of numpy, with `ddof = 0`.
- The graph operations of the `graph` package are the port of
  `dowhy.utils.graph_operations`. The graph of an adjacency matrix holds the
  edges whose weight is larger than `0.01` in absolute value, the label of an
  edge is its weight, and the upstream draws the edges from the column to the
  row of the matrix, the way its own loop over the indices of the matrix does.
  The port draws them the same way.
- The text of a number is the text of Python, so an integral number keeps its
  decimal point. The helper is the public function `utils::float_text`, and the
  `plotting` package takes it from there.
- The ordered set of the `utils` package is the port of
  `dowhy.utils.ordered_set.OrderedSet`. The set of the upstream holds any
  hashable value and the set of the port holds names, which are the values the
  upstream uses it with. The upstream raises an error when the index of the
  set is out of range; the port returns the empty string.
- The polynomial functions of the `utils` package are the port of
  `dowhy.utils.regression.create_polynomial_function`. The upstream closes
  over the loop variable of the loop that builds them, so every function of
  the list it returns raises the column to the highest degree of the list. The
  port closes over the degree of its own function, so every function of the
  list raises the column to its own degree.
- The symbolic estimators of the `estimators` package are the strings of the
  upstream, which the upstream builds when the estimator is fitted. The port
  builds them when they are asked for, so the effect modifiers of the
  estimator are the ones of its last fit. The upstream joins the outcome
  variables with a comma, and the propensity score matching estimator and the
  distance matching estimator join them with a comma and a space. The
  generalised linear model estimator wraps its variables in a sigmoid, the
  regression discontinuity estimator builds the empty string, and the two
  stage regression estimator builds the product of the symbolic estimators of
  its two stages. The instrumental variable estimator builds the expressions
  of the sympy of the upstream and the base estimator raises a
  `NotImplementedError`, so the port gives `None` for the two of them.

## Package layout

| Package | Ports |
| --- | --- |
| the root package (`src/`) | `dowhy.causal_model`: the `CausalModel` entry point |
| `api` | the subset of `pandas.DataFrame` the estimators use, plus the one-hot encoder and **the numeric features** |
| `utils` | matrices, least squares, generalised linear models, distributions, descriptive statistics, **the generator of numpy**, the tests of the conditional independence, **the text of a number** and **the ordered set** |
| `graph` | `dowhy.graph`, `dowhy.causal_graph`, the readers of the GML graphs, of the DOT graphs and of the graphs of the daggity web site, and **the graph operations** of `dowhy.utils.graph_operations` |
| `identifiers` | `dowhy.causal_identifier`, with the mediation identification and the natural indirect effect |
| `model` | `dowhy.causal_estimator` (the estimate objects) |
| `interpreters` | `dowhy.interpreters` (the sentence that reads an estimate, the balance of the common causes and the distribution of a confounder) |
| `estimators` | `dowhy.causal_estimators`, with the conditional estimates of the regression based ones, the two stage regression of the frontdoor and of the mediation estimand, the do operator, the distance matching estimator, the symbolic estimators and the base estimator of the upstream |
| `refuters` | `dowhy.causal_refuters`, with the significance test of the refutations and the graph refutation |
| `overrule` | the `OverRule` algorithm of the refuter that assesses the support and the overlap: the binariser of the features, the sampler of the reference samples, the beam search of the pricing problem, the program of the rules and its rounding |
| `cm` | the PC causal discovery algorithm and the Fisher-z test |
| `gcm` | the portable core of `dowhy.gcm`: the statistics, the confidence intervals, the divergences, the density estimators, the Shapley values, the independence tests, the **CatBoost encoder** of the categorical columns, the prediction models, the causal mechanisms, the automatic assignment of the mechanisms with the selection of the model by cross validation and the test of a linear relationship, the feature relevance, the intrinsic causal influence, the equation parser, the fitting of a causal model, the what-if queries, the validation layer, the falsification layer, the model evaluation layer, the anomaly detection layer, the unit change layer, the uncertainty estimates, the distribution change layer -- the plain one and the multiply-robust one -- and the arrow strength layer |
| `datasets` | `dowhy.datasets` (the random graph data set), the **data generating processes** of `dowhy.utils.dgp` and of `dowhy.utils.dgps`, and the deterministic test fixtures |
| `data_transformers` | `dowhy.data_transformers` (the PCA reducer and the base reducer of the upstream) |
| `do_samplers` | `dowhy.do_sampler`, `dowhy.do_samplers`, with **the propensity score of the treatment** |
| `timeseries` | `dowhy.timeseries` (the temporal graph and the temporal shift) |
| `plotting` | `dowhy.utils.plotting`, `dowhy.utils.graphviz_plotting` and `dowhy.utils.networkx_plotting` (the width of the arrows, the label and the colour of the nodes and of the edges, the layer of every node, the error bars of a bar plot and the graph of an adjacency matrix) |
| `tests` | the cross-package integration tests, including the cases of the upstream test files of the causal model, of the estimators, of the two stage regression estimator, of the placebo treatment refuter, of the bootstrap refuter and of the data subset refuter |
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
- `datasets_sales_reference.py` runs the upstream `dowhy.datasets.sales_dataset`
  the way the upstream test `tests/test_datasets.py` runs it and prints the
  numbers of the two fixtures -- the number of the shopping events, the mean of
  the profit, of the page views, of the sold units, of the ad spending, of the
  price, of the revenue and of the operational cost -- which are the numbers the
  tests of the `datasets` package compare against. It prints the draws of the
  upstream as well, so that the sampler of the port can be checked against the
  ones of SciPy.
- `numpy_random_reference.py` prints the numbers of the generator of numpy for
  the seeds of the tests of the `utils` package -- the doubles, the uniforms,
  the normal variates, the Bernoulli trials, the integers and the permutation --
  and the values of the multivariate normal of numpy with the identity as its
  covariance. It is the evidence for the generator of numpy of the `utils`
  package. Its last section prints the Bernoulli trials of the probabilities
  above one half and the Bernoulli trials of an array of the probabilities,
  which are the numbers the rule of the complement of the binomial of numpy
  gives.
- `dgp_reference.py` runs the three data generating processes of the upstream
  -- the linear, the quadratic and the cubic one -- with the seed 42, and
  prints the data, the value of the effect, the weights and the bias of every
  one of them, the data of the process with a binary treatment and the numbers
  of the deterministic conversion of the treatment. It is the evidence for the
  data generating processes of the `datasets` package.
- `interpreter_reference.py` runs the three interpreters of the upstream: the
  textual one, whose sentence the port reproduces, the propensity balance one,
  whose standardized mean differences the port reproduces, and the confounder
  distribution one, whose counts and sums of the weights the port reproduces.
  The fixtures hold the propensity scores of their rows, so the two sides build
  the very same strata and the very same weights.
- `graph_operations_reference.py` runs the thirteen functions of
  `dowhy.utils.graph_operations` on the fixtures of the port and prints what
  they return: the adjacency list of a matrix, the graph of a matrix and its
  compact form, the ancestors of a node, the induced graph, the C-components,
  the simple ordered tree, the connectivity of a graph, its undirected graph,
  a predecessor, the removal and the addition of an edge and a random pair of
  nodes.
- `utilities_reference.py` runs the functions of
  `dowhy.utils.ordered_set`, of `dowhy.utils.regression` and of
  `dowhy.utils.propensity_score` on the fixtures of the port and prints what
  they return: the elements of an ordered set and its union, its intersection
  and its difference, the polynomial functions of a matrix, the moment function
  of a treatment, the indices of the numeric columns of a data frame and the
  propensity score of a treatment.
- `symbolic_estimators_reference.py` fits every estimator of the upstream that
  builds a symbolic estimator and prints the string it builds -- with one
  outcome and with two, with an effect modifier and without a common cause --
  and it prints the string of the two stage regression estimator of the
  frontdoor estimand. It is the evidence for the symbolic estimators of the
  `estimators` package.
- `distance_matching_reference.py` runs the distance matching estimator of
  the upstream -- the class
  `dowhy.causal_estimators.distance_matching_estimator.DistanceMatchingEstimator`
  -- on the fixture of the port and prints the average treatment effect on the
  treated, the average treatment effect on the control and the average
  treatment effect, with one match per unit and with two. It prints the number
  of the queries whose two nearest candidates are at the same distance, which
  is the number of the ties the search of the upstream and the search of the
  port may break differently. It is the evidence for the distance matching
  estimator of the `estimators` package.
- `abstract_bases_reference.py` runs the base classes of the upstream -- the class
  `CausalEstimator` and the class `DimensionalityReducer` -- and prints the
  messages of the `NotImplementedError` they raise, and it walks the classes of
  the upstream to tell which ones implement the do operator and which ones
  implement the symbolic estimator. It is the evidence for the predicates of
  the base estimator and of the base reducer.
- `gcm_general_reference.py` runs the upstream `dowhy.gcm.util.general` on the
  fixtures of the tests of the port and prints the numbers it produces -- the
  geometric median, the set difference of the rows, the scaling of the columns
  and the differences of the means -- and the numbers of the CatBoost encoder
  of the categorical columns, with and without the target of the rows, with a
  categorical target and with the automatic encoder of the upstream, which is
  where the expectations of the tests of the encoder come from.
- `gcm_density_estimators_reference.py` runs the upstream
  `dowhy.gcm.density_estimators` on the fixtures of the tests of the port and
  prints the numbers it produces -- the densities of the Gaussian mixture of the
  upstream for five seeds, the densities of the kernel based estimator of one
  dimension and the error of the upstream when the mixture is given more
  components than samples. It is the evidence for the density estimators of the
  `gcm` package: the fit of the upstream draws the centres of the components at
  random and does not seed its generator, so its own numbers move from one seed
  to the other.
- `gcm_auto_reference.py` runs the upstream `dowhy.gcm.auto` on the rows of
  the fixtures of the tests of the port -- it reproduces the generator of the
  `utils` package, so it runs the upstream on the very same rows -- and prints
  the model the upstream picks and the score of every model of its zoo. It is
  the evidence for the model selection of the `gcm` package: the upstream
  shuffles the rows of its cross validation with the global generator of numpy
  and does not seed it, so the script prints the result of several seeds. The
  script also runs the upstream `has_linear_relationship` on the fixtures of
  the tests of the port and prints its decisions -- they are the evidence for
  the decisions of the port -- and it prints the text of the summary of the
  upstream, so that the format of the summary of the port can be compared with
  it character for character.
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
- `interpreter_reference.py` runs the upstream `TextualEffectInterpreter` on
  the rows of the fixture of the tests of the port and prints the sentence it
  writes and the value of the estimate it holds. It is the evidence for the
  interpretation of the port.
- `do_operator_reference.py` runs the upstream `LinearRegressionEstimator` on
  the rows of the fixture of the tests of the port and prints the value of its
  do operator, on the rows in their order and on the rows in another order. It
  is the evidence for the do operator of the port, and its two numbers are the
  numbers of the port.
- `cit_reference.py` runs the upstream `dowhy.utils.cit` on the rows of the
  fixture of the tests of the `utils` package and prints the partial
  correlation, the Spearman one, the confidence interval of a correlation, the
  entropy of a categorical variable and the conditional mutual information.
  Every number of the script is the number of the port.
- `graph_refuter_reference.py` runs the upstream
  `dowhy.causal_refuters.graph_refuter` on the rows of the fixture of the
  tests of the port and prints the p-value and the verdict of every
  conditional independence, the number of the constraints the model entails and
  the number of them the data satisfies. Every number of the script is the
  number of the port.
- `plotting_reference.py` runs the upstream `dowhy.utils.plotting` and the
  upstream `dowhy.utils.networkx_plotting` on the very graph and on the very
  values the port works on, and it prints the widths of the arrows, the
  error bars of the bar plots, the attributes of the two backends and the
  graph of the adjacency matrix. The Graphviz backend of the upstream is
  exercised with a stub of `pygraphviz`, because the package is an optional
  dependency of the upstream. It is the evidence for the `plotting` package.
- `gcm_scm_reference.py` computes the numbers of the causal mechanisms, of the
  fitting of a causal model and of the sampling from it with the upstream
  `dowhy.gcm` code, which is where the expectations of the tests of the
  structural causal model layer come from.
- `gcm_whatif_reference.py` computes the numbers of the what-if layer -- the
  interventional samples, the counterfactual samples, the average causal
  effect, the noise of a model and the data of a model -- with the upstream
  `dowhy.gcm` code, which is where the expectations of the tests of the
  what-if queries come from. The two fixtures with the categorical variables and
  with the discrete data are the very rows the port works on: the script
  replicates the generator of `src/utils/random.mbt`, so the two sides work on
  the same rows.
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
- `gcm_stats_reference.py` computes the numbers of the statistics -- the
  merging of the p-values with the three methods, the p-value of the F-test,
  the marginal expectation of a linear model and of a classifier and the
  geometric median -- with the upstream `dowhy.gcm.stats` code, which is where
  the expectations of the tests of the statistics come from. The fixtures of
  the script are drawn with the generator of the `utils` package of the port,
  and the script reproduces that generator in Python, so that the fixtures of
  the port and the fixtures of the script are the same numbers.
- `gcm_divergence_reference.py` computes the numbers of the divergence
  estimators -- the nearest neighbour estimator, the categorical estimator, the
  estimator of the probabilities, the classifier based estimator and the
  automatic estimate -- with the upstream `dowhy.gcm.divergence` code, which is
  where the expectations of the tests of the divergences come from. The
  fixtures of the script are drawn with the generator of the `utils` package of
  the port, and the script reproduces that generator in Python, so that the
  fixtures of the port and the fixtures of the script are the same numbers. The
  upstream draws the folds of its cross validation with the global generator of
  numpy, so the script seeds it before every call of the classifier based
  estimator.
- `gcm_validation_reference.py` computes the numbers of the validation layer --
  the p-values of the kernel based independence test on every fixture, the
  outcome and the summary of the validation of the causal structure and the
  outcome of the validation of the invertible model -- with the upstream
  `dowhy.gcm` code, which is where the expectations of the tests of the
  validation layer come from. It computes the p-values of the categorical
  fixture of the kernel based test as well, which is where the expectations of
  the categorical cases of that test come from. The upstream needs the `causal-learn` package
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
  of the tests of the layer come from. It computes the numbers of the non-trivial
  graph, whose relations are non-linear, and the numbers of the attribution
  without a causal model, as well. The constructor of
  `InvertibleStructuralCausalModel` of the upstream imports the module
  `dowhy.causal_model`, which pulls in the whole graph learning stack of the
  upstream, so the module is stubbed out with a placeholder class, the way the
  script of the validation layer does it. The attribution permutes the samples of
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
  and the two agree to `3.9e-15`. The script runs the case with a categorical
  target with the classifier of the port as well, so that the numbers of the two
  sides can be compared: the upstream gives a relevance of `0.120` for the first
  parent and of `0.076` for the second one, where the port gives `0.114` and
  `0.091`. The workers of the process pool of the upstream cannot import the
  stubbed packages, so the number of the jobs has to be set to one.
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
- `placebo_reference.py` runs the upstream placebo treatment refuter on the cases
  of the upstream test file `tests/causal_refuters/test_placebo_refuter.py` and
  prints the estimate, the refuted estimate, the p-value and the decision of the
  significance test, which is where the expectations of the tests of the port
  come from. The placebo of the upstream is drawn with the global generator of
  numpy and the port draws it with its own generator, so the numbers of the two
  are not the same numbers; what the two share is the behaviour the upstream
  test asserts, that the effect of the placebo is close to zero.
- `significance_reference.py` computes the p-values of the two kinds of the
  significance test of the refutations with the formulas of the upstream, so
  that the expectations of the tests of the port are written down and not
  transcribed. It also reproduces the generator of the port -- the xorshift64 of
  `utils.Random` and its Box-Muller transform -- so that the p-value of the case
  of the upstream test file `tests/test_causal_refuter.py` is computed here
  independently of the toolchain, and it runs the function of the upstream
  itself, which gives 0.9864 on the draw of the upstream and 0.9936 on the draw
  of the port.
- The tests of the bootstrap refuter and of the data subset refuter assert the
  **property** the upstream tests assert, that the effect of a resample and the
  effect of a subset stay close to the effect of the data, and not the numbers
  of the upstream: the resamples of the upstream are drawn with the global
  generator of numpy and the ones of the port with the generator of the port,
  so the two draw different subsets. The tolerances of the upstream tests are
  the ones the port uses.
- `causal_graph_reference.py` runs the graph functions of the upstream on the
  daggity fixture of the upstream test file `tests/test_causal_graph.py` with
  the `pydot` reader, because `pygraphviz` is not installed here. It prints the
  nodes, the edges, the answers of the two adjustment-set checks, the backdoor
  paths in the order the upstream gives them, the instruments and the directed
  path queries, which are the numbers the tests of the port are compared
  against.
- `gen_graph_fixture.py` writes `src/graph/daggity_fixture.mbt` mechanically
  from the fixture of the upstream, so the graph string cannot be
  mistranscribed.
- `gcm_categorical_reference.py` runs the upstream on the categorical fixture of
  its own independence test, both through the automatic encoding of the
  conditioning variable and on an explicitly one-hot encoded one, and asserts
  that the two routes lead to the same decision on six seeds. That assertion is
  the evidence that `generalised_cov_based_with_categorical` reproduces the
  upstream, whose model selection the port does not have.
- `upstream_test_coverage.py` maps the test files of the port to the test files
  of the upstream. It reads a name of a header in three forms -- a path, a bare
  file name and a glob -- because a test file of the port names the upstream
  file it mirrors one by one, by its bare name, or through a glob such as
  `tests/causal_estimators/test_*_estimator.py`.
- `overrule_reference.py` runs the upstream of the refuter that assesses the
  support and the overlap on the fixture of the upstream test file, with the
  program of the rules solved with the `HiGHS` solver of `scipy` instead of
  `cvxpy` and the solver `CLARABEL`, which are not installed here. It prints
  the rules of the support and of the overlap, the weights of the program and
  the value of the program, which are the numbers the tests of the port are
  compared against.
- The test file of the data subset refuter runs on the **hundred thousand
  rows** of the upstream test, so the port has to fit a propensity score model
  and to match a hundred thousand units. Two things make that possible: the
  logistic regression of the `utils` package accumulates the weighted normal
  equations over the rows instead of building the diagonal weight matrix of
  the IRLS step, and the propensity score matching estimator searches the
  sorted scores instead of scanning every unit of the other group.
- `dummy_outcome_reference.py` runs the dummy outcome refuter of the upstream on
  the cases the port mirrors and prints how many refutations come back and the
  new effect of each of them. It runs the refuter through the module function
  `dowhy.causal_refuters.dummy_outcome_refuter.refute_dummy_outcome` rather than
  through `CausalModel.refute_estimate`, because `DummyOutcomeRefuter` cannot be
  instantiated on its own (its base class asks for the estimand and the estimate)
  and because the module function takes the transformation list explicitly.
- The buckets of the estimator branch of the dummy outcome refuter are the
  upstream's quirk, measured rather than inferred: the edges of the cut are the
  ranges `(max - min)` of **every numeric column** of the frame, divided by
  `bucket_size_scale_factor * std of the treatment column`, in the column order
  of the frame, and `pandas.cut` reads the resulting Series as the edges of the
  buckets. On the continuous treatment of the upstream's own `linear_dataset`,
  whose columns are `Z0, W0, v0, y`, the four columns give four increasing edges
  and therefore three buckets, and the refuter reports three refutations; one run
  gives the edges `0.2716, 1.7142, 11.6501, 122.3968` and buckets of `47`, `437`
  and `382` of the `1000` rows. The exact numbers vary between runs, because the
  upstream draws its frame with the global generator of numpy; the three buckets
  do not. A frame whose ranges do not increase makes `pandas.cut` raise
  `ValueError: bins must increase monotonically`, which is why no binary
  treatment case of the upstream file whose list carries an estimator can pass:
  a binary treatment spans one unit while the outcome of the same frame spans
  tens. Measured on a hand built frame in the same column order, at `1000` and
  at `20000` rows: the continuous treatment gives three buckets, and the binary
  one gives the edges `4.06, 26.048, 4.06, 93.103` (`4.027, 30.372, 4.027,
  111.648` at the larger frame) and the `ValueError`. The port aborts with the
  same message.
- The upstream conversion `np.vectorize(convert_to_binary)` of
  `dowhy.datasets.linear_dataset` is broken on numpy 2.5.1: `convert_to_binary`
  returns the one element array of `np.random.choice([0, 1], 1, p=...)`, so
  every element of the vectorised call is an array and numpy refuses it with
  `ValueError: setting an array element with a sequence`. The reference scripts
  of this repository therefore build the rows of the port in Python instead of
  calling `linear_dataset` when the treatment is binary, and a case of the
  upstream that needs that dataset cannot be run here at all.
- `permute` of the upstream refuter writes into the array it is given, so a case
  that permutes a read-only array raises `ValueError: output array is read-only`
  on numpy 2.x. The upstream's own permutation cases of the dummy outcome
  refuter therefore fail in this environment, and the port's own permutation
  cases are the only evidence for that branch.
- The refuter of the unobserved common cause shares one confounder between the
  treatment and the outcome: `_include_confounders_effect` draws a single
  `w_random` and uses it for both, adds `kappa_t * w` to the treatment and
  **subtracts** `kappa_y * w` from the outcome. The subtraction is deliberate
  upstream -- the confounder of the data is assumed to have acted on both
  columns, so removing it from the outcome is what undoes its effect -- and the
  port keeps the sign.
- The `binary_flip` strength of that refuter is a probability of a flip, read
  through the central interval of the standard normal: `alpha` is
  `2 * kappa - 1` above one half and `1 - 2 * kappa` below it, the edge is the
  lower quantile of the interval above one half and the upper quantile below it,
  and every row whose draw is at or beyond the edge flips. With the infinite
  edges of the two ends, that gives `0` flips nothing, `0.5` flips half of the
  rows and `1` flips every row. A strength of `0` therefore leaves the data
  untouched, which is the only assertion the upstream harness makes about this
  refuter, and the port asserts it bit for bit.
- The refuter of the unobserved common cause reports **one** refutation, not the
  mean of a loop: the upstream `sensitivity_simulation` draws one confounder,
  refits once and returns, so there is no interval to report and the port sets
  the two bounds of the refutation to the refuted effect.
- The linear sensitivity analysis of the upstream has three quirks that the port
  reproduces, and all three are **not** visible in the signature of the upstream:
  1. `sensitivity_linear_partial_r2` builds the analyzer **without** the
     `confounder_increases_estimate` flag of its refuter, so the analyzer keeps
     its own default of `True` and the bias always moves the estimate toward
     zero. The port's flag is an optional argument that defaults to `true`.
  2. The analyzer **overwrites** the effect under the null hypothesis with
     `estimate * (1 - percent_change_estimate)` (or `1 +` when the confounder
     does not increase the estimate), so the value the caller gives it never
     survives.
  3. The interval of the bias adjusted estimate takes the **lower** quantile of
     the Student distribution at half the significance level, which is negative,
     and swaps the two bounds with it: `lower_CI = adjusted + num_se * se` and
     `upper_CI = adjusted - num_se * se`. The port keeps the arithmetic and the
     names of the upstream.
- The partial R2 of a coefficient of the upstream analyzer is the scalar branch
  of `partial_r2_func`, `t^2 / (t^2 + df_resid)`. The group branch, which the
  upstream uses for a group of covariates, is not ported: the benchmark of the
  upstream is a single common cause.
- The upstream caps the partial R2 of the confounder with the outcome at one and
  warns about it, and the port caps it the same way. The cap is reached easily:
  on the fixture of the upstream file the value is one for every strength, so
  the standard error of the bias adjusted estimate is zero and its t statistic
  is infinite.
- The upstream's fixture of the linear sensitivity cases cannot be generated
  through `dowhy.datasets.linear_dataset` on numpy 2.5.1, because the
  `np.vectorize(convert_to_binary)` of that branch builds a one element array
  per row. The reference script therefore builds the frame by hand with the
  shape of the fixture of the port. The two noise parameters of the upstream
  (`stddev_treatment_noise` and `stddev_outcome_noise`) were added to
  `datasets.LinearConfig` for the port's own fixture; their defaults are the
  values the port already used, so every other fixture keeps its rows.

