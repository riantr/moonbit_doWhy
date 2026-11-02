"""Runs the upstream of the refuter that assesses the support and the overlap.

The upstream test file `tests/causal_refuters/test_assess_overlap.py` holds one
data set: two binary features and a binary treatment, where the cell of the two
features that are both one is empty, and where the treatment only happens in
the cell where both features are zero.

The upstream solves the program of its rules with `cvxpy` and the solver
`CLARABEL`, and neither of them is installed here, so the program is solved with
`scipy`'s `HiGHS` instead.  Everything else is the upstream's own code: the beam
search of the pricing problem, the greedy rounding, the binariser of the
features and the sampler of the reference samples.

The script prints the rules of the support and of the overlap, the weights of
the program and the value of the program, so that the numbers of the port can be
compared with them.

Usage:
    python _verify/overrule_reference.py
"""

from __future__ import annotations

import os
import sys
import types

UPSTREAM_ROOT = os.environ.get(
    "DOWHY_UPSTREAM_ROOT",
    r"D:\src\MiniMax\git\dowhy\dowhy-0.14",
)
if UPSTREAM_ROOT not in sys.path:
    sys.path.insert(0, UPSTREAM_ROOT)

# The module of the rules of the upstream imports `cvxpy` when it is loaded, and
# the program is solved with `scipy` below, so a stub is enough to import it.
sys.modules.setdefault("cvxpy", types.ModuleType("cvxpy"))

import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from scipy.optimize import linprog  # noqa: E402

from dowhy.causal_refuters.assess_overlap_overrule import (  # noqa: E402
    OverlapConfig,
    OverruleAnalyzer,
    SupportConfig,
)
from dowhy.causal_refuters.overrule.BCS.beam_search import beam_search  # noqa: E402
from dowhy.causal_refuters.overrule.BCS.overlap_boolean_rule import (  # noqa: E402
    OverlapBooleanRule,
)


def solve_lp(A, O, N, U, lambdas, alpha, nO):
    """The program of the upstream, solved with `HiGHS`.

    The program minimises the share of the rows that must not be covered plus
    the regularisation of the conjunctions, under the constraint that the rules
    cover at least the share `alpha` of the positive rows.
    """
    m = A.shape[1]
    c = np.zeros(m + nO)
    neg = U if len(U) > 0 else N
    n_neg = len(neg)
    c[:m] = A[neg, :].sum(axis=0) / n_neg + lambdas

    A_ub = np.zeros((1 + nO, m + nO))
    b_ub = np.zeros(1 + nO)
    A_ub[0, m:] = 1.0
    b_ub[0] = (1 - alpha) * nO
    if nO:
        A_ub[1:, :m] = -A[O, :]
        A_ub[1:, m:] = -np.eye(nO)
        b_ub[1:] = -1.0

    res = linprog(
        c,
        A_ub=A_ub,
        b_ub=b_ub,
        bounds=[(0, None)] * (m + nO),
        method="highs",
    )
    if not res.success:
        raise RuntimeError(res.message)
    return res.x[:m], res.ineqlin.marginals[1:], res.fun


def fit_with_scipy(self, X, y):
    """The `fit` of the upstream, with the program solved by `HiGHS`."""
    y = np.asarray(y).ravel()
    O = np.where(y > 0)[0]
    N = np.where(y == 0)[0]
    U = np.where(y < 0)[0]
    nO = len(O)

    z = pd.DataFrame(np.eye(X.shape[1], X.shape[1] + 1, 1, dtype=int), index=X.columns)
    A = np.hstack((np.ones((X.shape[0], 1), dtype=int), X))
    self.it = 0

    lambdas = self.lambda0 + self.lambda1 * z.sum().values
    lambdas[0] = 0

    w, duals, obj = solve_lp(A, O, N, U, lambdas, self.alpha, nO)
    r = np.zeros_like(y, dtype=float)
    r[O] = duals
    if len(U) > 0:
        r[U] = 1.0 / len(U)
    else:
        r[N] = 1.0 / len(N)

    UB = min((np.dot(r, A) + lambdas).min(), 0)
    v, zNew, Anew = beam_search(
        r, X, self.lambda0, self.lambda1, K=self.K, UB=UB, eps=self.eps, B=self.B, D=self.D
    )

    while (v < -self.eps).any() and (self.it < self.iterMax):
        self.it += 1
        z = pd.concat([z, zNew], axis=1, ignore_index=True)
        A = np.concatenate((A, Anew), axis=1)
        lambdas = np.concatenate((lambdas, self.lambda0 + self.lambda1 * zNew.sum().values))
        w, duals, obj = solve_lp(A, O, N, U, lambdas, self.alpha, nO)
        r = np.zeros_like(y, dtype=float)
        r[O] = duals
        if len(U) > 0:
            r[U] = 1.0 / len(U)
        else:
            r[N] = 1.0 / len(N)
        UB = min((np.dot(r, A) + lambdas).min(), 0)
        v, zNew, Anew = beam_search(
            r, X, self.lambda0, self.lambda1, K=self.K, UB=UB, eps=self.eps, B=self.B, D=self.D
        )

    self.z = z
    self.w_raw = w
    self.lp_obj_value = obj
    self.round_(X, y, scoring=self.rounding)


def dummy_data():
    """The data set of the upstream test file."""
    return pd.DataFrame(
        np.array(
            [
                [0, 0, 1, 0],
                [0, 0, 0, 1],
                [0, 1, 0, 0],
                [1, 0, 0, 0],
            ]
            * 50
        ),
        columns=["X1", "X2", "T", "Y"],
    )


def main() -> None:
    OverlapBooleanRule.fit = fit_with_scipy
    data = dummy_data()
    analyzer = OverruleAnalyzer(
        backdoor_vars=["X1", "X2"],
        treatment_name="T",
        support_config=SupportConfig(seed=0),
        overlap_config=OverlapConfig(),
    )
    analyzer.fit(data)
    support = analyzer.RS_support_estimator
    overlap = analyzer.RS_overlap_estimator
    print("support rules   :", support.rules())
    print("overlap rules   :", overlap.rules())
    print("support w_raw   :", np.round(support.M.w_raw, 6))
    print("overlap w_raw   :", np.round(overlap.M.w_raw, 6))
    print("support value   :", round(support.M.lp_obj_value, 6))
    print("overlap value   :", round(overlap.M.lp_obj_value, 6))
    print("support columns :", list(support.M.z.index))
    print("overlap rows    :", int(analyzer.raw_overlap_set.sum()))
    print("overlap cover   :", int(analyzer.overlap_indicator.sum()))


if __name__ == "__main__":
    main()
