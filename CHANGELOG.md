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
