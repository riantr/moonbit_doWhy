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
original. Three of these cost real debugging time here:

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
| `gcm` | the portable core of `dowhy.gcm`: the statistics, the confidence intervals, the divergences, the density estimators, the Shapley values, the independence tests, the prediction models, the causal mechanisms and the fitting of a causal model |
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
