"""An independent reference for the generalised linear models of the port.

This script fits `statsmodels.api.GLM` on the very data set the `glm` module of
the port fits, and prints the numbers the MoonBit implementation has to
reproduce. The data set is generated with a Python replica of the xorshift
generator of `src/utils/random.mbt`, so the two data sets are the same rows and
not merely the same distribution.

The fixture is the one of `src/utils/glm_test.mbt`: two continuous
confounders, a binary treatment and two responses, a binary one and a count
one.

Usage:
    python _verify/glm_reference.py
"""

from __future__ import annotations

import math
import os
import sys

import numpy as np
import statsmodels.api as sm

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from pc_reference import Xorshift  # noqa: E402

ROWS = 800
SEED = 2024


def sigmoid(x: float) -> float:
    """The `sigmoid` of `src/utils/linalg.mbt`, branch for branch."""
    if x >= 0.0:
        return 1.0 / (1.0 + math.exp(-x))
    e = math.exp(x)
    return e / (1.0 + e)


def fixture(rows: int, seed: int) -> dict[str, np.ndarray]:
    """The fixture of `src/utils/glm_test.mbt`."""
    rng = Xorshift(seed)
    const, treatment, first, second = [], [], [], []
    binary, count = [], []
    # The smallest distance of a uniform draw from the boundary that decides
    # the response. A distance that is close to zero would make the two
    # implementations disagree, because their exponential functions differ in
    # the last bit.
    binary_margin = 1.0
    count_margin = 1.0
    for _ in range(rows):
        x1 = rng.next_normal()
        x2 = rng.next_normal()
        u = rng.next_double()
        t = 1.0 if u < sigmoid(-0.2 + 0.9 * x1 - 0.4 * x2) else 0.0
        u = rng.next_double()
        probability = sigmoid(0.3 + 0.8 * t - 0.5 * x1 + 0.6 * x2)
        binary_margin = min(binary_margin, abs(u - probability))
        y_bin = 1.0 if u < probability else 0.0
        u = rng.next_double()
        rate = u * math.exp(0.4 + 0.5 * t + 0.3 * x1)
        count_margin = min(count_margin, abs(rate - round(rate)))
        y_count = float(math.floor(rate))
        const.append(1.0)
        treatment.append(t)
        first.append(x1)
        second.append(x2)
        binary.append(y_bin)
        count.append(y_count)
    print(f"BINARY_MARGIN {binary_margin:.3e}")
    print(f"COUNT_MARGIN {count_margin:.3e}")
    return {
        "const": np.array(const),
        "treatment": np.array(treatment),
        "x1": np.array(first),
        "x2": np.array(second),
        "binary": np.array(binary),
        "count": np.array(count),
    }


def main() -> None:
    data = fixture(ROWS, SEED)
    design = np.column_stack(
        [data["const"], data["treatment"], data["x1"], data["x2"]]
    )

    for label, family, response in [
        ("BINOMIAL", sm.families.Binomial(), data["binary"]),
        ("POISSON", sm.families.Poisson(), data["count"]),
    ]:
        model = sm.GLM(response, design, family=family).fit()
        print(label)
        print("  params " + " ".join(f"{v:.15f}" for v in model.params))
        print("  bse    " + " ".join(f"{v:.15f}" for v in model.bse))
        print("  scale  " + f"{model.scale:.15f}")
        predicted = model.predict(design)
        print("  mu     " + " ".join(f"{v:.15f}" for v in predicted[:5]))
        print("  mean   " + f"{predicted.mean():.15f}")
        # The covariance of the coefficients is the inverse of the weighted
        # Gram matrix, which is what the port computes. The mean of the
        # response is the inverse of the link applied to the linear predictor;
        # `Family.predict` is the link itself, so the inverse is used here.
        eta = design @ model.params
        mu = family.link.inverse(eta)
        weights = mu * (1.0 - mu) if label == "BINOMIAL" else mu
        gram = design.T @ (design * weights[:, None])
        print("  cov00  " + f"{np.linalg.inv(gram)[0, 0]:.15f}")


if __name__ == "__main__":
    main()
