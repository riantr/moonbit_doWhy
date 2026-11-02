"""Replace the n x n weight matrix of `utils.logistic_fit` with a direct
accumulation of the weighted normal equations.

The upstream test suite of the refuters fits a propensity score model on a
hundred thousand rows.  The weight matrix of the IRLS step held `n * n`
doubles, which is eighty gigabytes at that size, so the fit aborted the
allocator instead of converging.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "src" / "utils" / "linalg.mbt"

OLD = """    // Weighted least squares step with the ridge term on the slopes.
    let xt = x.transpose()
    let wmat = Matrix::zeros(n, n)
    for i = 0; i < n; i = i + 1 {
      wmat.set(i, i, w[i])
    }
    let h = xt.mul(wmat).mul(x)
    for j = 1; j < p; j = j + 1 {
      h.set(j, j, h.get(j, j) + lambda)
    }
    let rhs = xt.mul(wmat).matvec(z)
"""

NEW = """    // Weighted least squares step with the ridge term on the slopes.
    //
    // The weighted normal equations are accumulated over the rows of the
    // design matrix: `h` is `X^T W X` and `rhs` is `X^T W z`.  The diagonal
    // weight matrix would hold `n * n` doubles, which is eighty gigabytes for
    // the hundred thousand rows of the upstream test suite, so it is never
    // built.
    let h_data : Array[Double] = []
    for k = 0; k < p * p; k = k + 1 {
      h_data.push(0.0)
    }
    let rhs : Array[Double] = []
    for k = 0; k < p; k = k + 1 {
      rhs.push(0.0)
    }
    for i = 0; i < n; i = i + 1 {
      let wi = w[i]
      let zi = z[i]
      for k = 0; k < p; k = k + 1 {
        let xk = x.get(i, k)
        rhs[k] = rhs[k] + xk * wi * zi
        let xkw = xk * wi
        for j = 0; j < p; j = j + 1 {
          h_data[k * p + j] = h_data[k * p + j] + xkw * x.get(i, j)
        }
      }
    }
    let h = Matrix::from_flat(p, p, h_data)
    for j = 1; j < p; j = j + 1 {
      h.set(j, j, h.get(j, j) + lambda)
    }
"""


def main() -> None:
    text = TARGET.read_text(encoding="utf-8")
    count = text.count(OLD)
    if count != 1:
        raise SystemExit(f"expected one occurrence of the block, found {count}")
    TARGET.write_text(text.replace(OLD, NEW), encoding="utf-8", newline="")
    print("patched", TARGET)


if __name__ == "__main__":
    main()
