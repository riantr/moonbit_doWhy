"""The upstream reference for the number of the neighbours of the kNN family.

The upstream builds its nearest neighbour estimators with scikit-learn, which
refuses a number of neighbours below one.  The port has to refuse it as well,
and this script prints what the upstream does, so that the port can be
compared against it.

The script covers the two places the upstream builds a nearest neighbour
estimator:

  * `dowhy.gcm.divergence.estimate_kl_divergence_continuous_knn`, which builds
    a `NearestNeighbors` with `k + 1` and with `k` neighbours,
  * the `KNeighborsRegressor` and the `KNeighborsClassifier` of scikit-learn,
    which the port models with `KnnModel` and `KnnClassifier`.

Usage:
    python _verify/knn_neighbours_reference.py
"""

from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from upstream_gcm import load  # noqa: E402


def load_upstream():
    """The upstream modules the divergence module needs, in the order they load."""
    for name in (
        "dowhy.gcm.constant",
        "dowhy.gcm.config",
        "dowhy.gcm.density_estimator",
        "dowhy.gcm.anomaly_scorer",
        "dowhy.gcm.util.catboost_encoder",
        "dowhy.gcm.util.general",
        "dowhy.gcm.stats",
        "dowhy.gcm.confidence_intervals",
        "dowhy.gcm.ml.prediction_model",
        "dowhy.gcm.ml.regression",
        "dowhy.gcm.ml.classification",
        "dowhy.gcm.ml",
        "dowhy.gcm.stochastic_models",
        "dowhy.gcm.causal_mechanisms",
        "dowhy.gcm.causal_models",
        "dowhy.gcm.auto",
    ):
        load(name)
    return load("dowhy.gcm.divergence")


def report(label, call):
    """Print what the upstream does with one input."""
    print(label)
    try:
        value = call()
    except Exception as exc:  # noqa: BLE001
        print("  raised %s: %s" % (type(exc).__name__, exc))
    else:
        print("  returned %r" % (value,))


def main() -> None:
    from sklearn.neighbors import KNeighborsClassifier, KNeighborsRegressor

    divergence = load_upstream()
    x = np.array([[0.0], [1.0], [2.0], [3.0]])
    y = np.array([[0.5], [1.5], [2.5]])

    print("DIVERGENCE")
    for k in (1, 0, -1, 2):
        report(
            "k=%d" % k,
            lambda k=k: divergence.estimate_kl_divergence_continuous_knn(
                x, y, k=k, remove_common_elements=False
            ),
        )

    print()
    print("KNEIGHBORSREGRESSOR")
    for k in (1, 0, -1):
        report(
            "n_neighbors=%d" % k,
            lambda k=k: KNeighborsRegressor(n_neighbors=k).fit(
                np.array([[0.0], [1.0], [2.0]]), np.array([0.0, 1.0, 2.0])
            ).predict(np.array([[0.5]])),
        )

    print()
    print("KNEIGHBORSCLASSIFIER")
    for k in (1, 0, -1):
        report(
            "n_neighbors=%d" % k,
            lambda k=k: KNeighborsClassifier(n_neighbors=k).fit(
                np.array([[0.0], [1.0], [2.0]]), np.array(["a", "b", "a"])
            ).predict(np.array([[0.5]])),
        )


if __name__ == "__main__":
    main()
