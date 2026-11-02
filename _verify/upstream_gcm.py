"""Loads the upstream `dowhy` modules without installing the package.

The upstream `dowhy` distribution cannot be imported as it is: its
`dowhy/__init__.py` pulls in `causallearn`, which is a heavy dependency that
the reference scripts do not need. The modules of `dowhy.gcm` that the port
covers only need numpy, scipy, scikit-learn, statsmodels and networkx, so
they are loaded straight from their files with the package chain stubbed out.

Loading a module also makes it reachable under its dotted name, so that the
`from dowhy.gcm import config` of the upstream code finds it.

The modules of the causal model are loaded the same way: `dowhy.causal_graph`,
`dowhy.datasets` and `dowhy.utils.plotting` are the three that the reference
script of the causal model needs on top of the ones of the list below.

The path of the upstream checkout is taken from the `DOWHY_SRC` environment
variable and falls back to the checkout that sits next to this repository.

Usage:
    from upstream_gcm import load

    general = load("dowhy.gcm.util.general")
"""

from __future__ import annotations

import importlib.util
import os
import sys
import types
from pathlib import Path

_DEFAULT_ROOTS = [
    r"D:\src\MiniMax\git\dowhy\dowhy-0.14",
    os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "dowhy", "dowhy-0.14"),
]

# The upstream modules, in the order they have to be loaded in. Every entry
# names the module and the file it lives in, relative to the `dowhy` package.
_ORDER: list[tuple[str, str]] = [
    ("dowhy.gcm.constant", "gcm/constant.py"),
    ("dowhy.gcm.config", "gcm/config.py"),
    ("dowhy.gcm.density_estimator", "gcm/density_estimator.py"),
    ("dowhy.gcm.anomaly_scorer", "gcm/anomaly_scorer.py"),
    ("dowhy.gcm.util.catboost_encoder", "gcm/util/catboost_encoder.py"),
    ("dowhy.gcm.util.general", "gcm/util/general.py"),
    ("dowhy.gcm.stats", "gcm/stats.py"),
    ("dowhy.gcm.confidence_intervals", "gcm/confidence_intervals.py"),
    ("dowhy.gcm.ml.prediction_model", "gcm/ml/prediction_model.py"),
    ("dowhy.gcm.ml.regression", "gcm/ml/regression.py"),
    ("dowhy.gcm.ml.classification", "gcm/ml/classification.py"),
    ("dowhy.gcm.ml", "gcm/ml/__init__.py"),
    ("dowhy.gcm.stochastic_models", "gcm/stochastic_models.py"),
    ("dowhy.gcm.causal_mechanisms", "gcm/causal_mechanisms.py"),
    ("dowhy.gcm.causal_models", "gcm/causal_models.py"),
    ("dowhy.utils.api", "utils/api.py"),
    ("dowhy.utils.ordered_set", "utils/ordered_set.py"),
    ("dowhy.utils.graph_operations", "utils/graph_operations.py"),
    ("dowhy.graph", "graph.py"),
    ("dowhy.gcm.auto", "gcm/auto.py"),
    ("dowhy.gcm.divergence", "gcm/divergence.py"),
    ("dowhy.gcm.density_estimators", "gcm/density_estimators.py"),
    ("dowhy.gcm.shapley", "gcm/shapley.py"),
    ("dowhy.gcm.independence_test.regression", "gcm/independence_test/regression.py"),
    ("dowhy.gcm.independence_test.generalised_cov_measure", "gcm/independence_test/generalised_cov_measure.py"),
    ("dowhy.utils.plotting", "utils/plotting.py"),
    ("dowhy.causal_graph", "causal_graph.py"),
    ("dowhy.datasets", "datasets.py"),
    ("dowhy.utils.encoding", "utils/encoding.py"),
    ("dowhy.causal_identifier.adjustment_set", "causal_identifier/adjustment_set.py"),
    ("dowhy.causal_identifier.identified_estimand", "causal_identifier/identified_estimand.py"),
    ("dowhy.causal_identifier.efficient_backdoor", "causal_identifier/efficient_backdoor.py"),
    ("dowhy.causal_identifier.auto_identifier", "causal_identifier/auto_identifier.py"),
    ("dowhy.causal_identifier", "causal_identifier/__init__.py"),
    ("dowhy.causal_estimator", "causal_estimator.py"),
    ("dowhy.causal_estimators.regression_estimator", "causal_estimators/regression_estimator.py"),
    ("dowhy.causal_estimators.linear_regression_estimator", "causal_estimators/linear_regression_estimator.py"),
    (
        "dowhy.causal_estimators.two_stage_regression_estimator",
        "causal_estimators/two_stage_regression_estimator.py",
    ),
]

_PATHS = dict(_ORDER)


def upstream_root() -> Path:
    """The root of the upstream checkout."""
    configured = os.environ.get("DOWHY_SRC")
    if configured:
        root = Path(configured)
        if root.is_dir():
            return root
        raise RuntimeError(f"DOWHY_SRC points at {configured}, which is not a directory")
    for candidate in _DEFAULT_ROOTS:
        if Path(candidate).is_dir():
            return Path(candidate)
    raise RuntimeError("the upstream checkout was not found; set DOWHY_SRC to its path")


def _stub_packages() -> None:
    """Creates the empty `dowhy` packages the upstream modules import from."""
    for name in (
        "dowhy",
        "dowhy.gcm",
        "dowhy.gcm.util",
        "dowhy.gcm.ml",
        "dowhy.gcm.independence_test",
        "dowhy.utils",
        "dowhy.interpreters",
    ):
        if name not in sys.modules:
            module = types.ModuleType(name)
            module.__path__ = []  # type: ignore[attr-defined]
            module._upstream_stub = True  # type: ignore[attr-defined]
            sys.modules[name] = module


def _register(name: str, module: types.ModuleType) -> None:
    """Puts the module under its dotted name and under its parent."""
    sys.modules[name] = module
    if "." in name:
        parent, _, child = name.rpartition(".")
        if parent in sys.modules:
            setattr(sys.modules[parent], child, module)


def _load_file(name: str, path: Path, depth: int = 0) -> types.ModuleType:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"{path} could not be loaded")
    module = importlib.util.module_from_spec(spec)
    _register(name, module)
    try:
        spec.loader.exec_module(module)
    except ModuleNotFoundError as error:
        missing = getattr(error, "name", "") or ""
        if missing in _PATHS and missing != name and depth < 20:
            # The upstream modules import each other in a chain that the order
            # of this file does not always follow, so the missing one is
            # loaded first and the import is tried again.
            sys.modules.pop(name, None)
            _load_file(missing, upstream_root() / "dowhy" / _PATHS[missing], depth + 1)
            return _load_file(name, path, depth + 1)
        sys.modules.pop(name, None)
        raise
    except Exception:
        sys.modules.pop(name, None)
        raise
    return module


def load(name: str) -> types.ModuleType:
    """Loads an upstream module by its dotted name and returns it."""
    _stub_packages()
    existing = sys.modules.get(name)
    if existing is not None and not getattr(existing, "_upstream_stub", False):
        return existing
    if name not in _PATHS:
        raise KeyError(f"{name} is not one of the upstream modules this loader knows")
    return _load_file(name, upstream_root() / "dowhy" / _PATHS[name])
