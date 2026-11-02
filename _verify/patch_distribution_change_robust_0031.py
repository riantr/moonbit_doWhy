"""Patch the port of the multiply-robust causal change attribution.

The patch does three things:

1.  It renames the field and the parameters that were called ``method``,
    because ``method`` is a reserved word of the toolchain and a warning is a
    failure in this repository.

2.  It renames the helpers ``select_rows`` and ``select_values``, because the
    ``gcm`` package already has a helper of each name (``independence.mbt`` and
    ``model_evaluation.mbt``) and two files of one package may not define the
    same name.

3.  It moves the standardisation of the weights of the estimator out of the
    loop over the groups.  The upstream standardises only the last weight,
    because the statement that does it is outside its loop; the port
    standardised every weight, which is a different estimator.

The patch also removes the ``mut`` of the bindings whose value is never
rebound, because the toolchain reports it as a warning.
"""

import io
import os

PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "src",
    "gcm",
    "distribution_change_robust.mbt",
)

with io.open(PATH, encoding="utf-8", newline="") as handle:
    source = handle.read()

lines = source.split("\n")
out = []
for line in lines:
    stripped = line.strip()
    indent = line[: len(line) - len(stripped)]
    if stripped in ("method : ChangeMethod", "method : ChangeMethod,"):
        line = indent + "change_method" + stripped[len("method") :]
    elif stripped == "method: ChangeMethod::MultiplyRobust,":
        line = indent + "change_method: ChangeMethod::MultiplyRobust,"
    elif stripped == "method: self.method,":
        line = indent + "change_method: self.change_method,"
    elif stripped == "method,":
        line = indent + "change_method,"
    elif stripped == "match method {":
        line = indent + "match change_method {"
    elif stripped == "let mut y : Array[Double] = []":
        line = indent + "let y : Array[Double] = []"
    elif stripped == "let mut t : Array[Double] = []":
        line = indent + "let t : Array[Double] = []"
    elif stripped == "let mut attributions : Array[Double] = []":
        line = indent + "let attributions : Array[Double] = []"
    elif stripped == "let mut test_rows : Array[Array[Int32]] = []":
        line = indent + "let test_rows : Array[Array[Int32]] = []"
    elif stripped.startswith("fn select_rows("):
        line = indent + "fn select_matrix_rows(" + stripped[len("fn select_rows(") :]
    elif stripped.startswith("fn select_values("):
        line = indent + "fn select_array_values(" + stripped[len("fn select_values(") :]
    elif stripped.startswith("select_rows("):
        line = indent + "select_matrix_rows(" + stripped[len("select_rows(") :]
    elif stripped.startswith("select_values("):
        line = indent + "select_array_values(" + stripped[len("select_values(") :]
    elif stripped == "let test = test_rows[i].copy()":
        line = indent + "let test_fold = test_rows[i].copy()"
    elif stripped == "for row in test {":
        line = indent + "for row in test_fold {"
    elif stripped == "out.push((train, test))":
        line = indent + "out.push((train, test_fold))"
    out.append(line)

source = "\n".join(out)

# The standardisation of the weights moves out of the loop over the groups.
old = """    // The weights of the two groups before are multiplied in.
    if k >= 2 {
      let previous = alphas[k - 2]
      for i in 0..<weights.length() {
        weights[i] = weights[i] * previous[i]
      }
    }
    // The weights are standardised.
    let mut sum = 0.0
    for weight in weights {
      sum = sum + weight
    }
    let mean = if weights.length() == 0 {
      0.0
    } else {
      sum / weights.length().to_double()
    }
    for i in 0..<weights.length() {
      weights[i] = weights[i] / mean
    }
    alphas[k] = weights
  }
  alphas
}"""

new = """    // The weights of the two groups before are multiplied in.
    if k >= 2 {
      let previous = alphas[k - 2]
      for i in 0..<weights.length() {
        weights[i] = weights[i] * previous[i]
      }
    }
    alphas[k] = weights
  }
  // Only the weights of the last group are standardised.  The upstream
  // standardises the weights outside its loop over the groups, so the weights
  // of the other groups keep their scale.
  let last = num_groups - 1
  let weights = alphas[last]
  let mut sum = 0.0
  for weight in weights {
    sum = sum + weight
  }
  let mean = if weights.length() == 0 {
    0.0
  } else {
    sum / weights.length().to_double()
  }
  for i in 0..<weights.length() {
    weights[i] = weights[i] / mean
  }
  alphas
}"""

if old not in source:
    raise SystemExit("the block of the standardisation was not found")
source = source.replace(old, new)

with io.open(PATH, "w", encoding="utf-8", newline="") as handle:
    handle.write(source)

print("patched", PATH)
