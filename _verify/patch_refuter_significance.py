"""Adds the significance test of the refutations to the port.

The upstream reports the p-value of every refutation that tests an estimate
against the distribution of the estimates it produced, the port of
`test_significance` of `dowhy.causal_refuter`. The script adds the helper and
the p-value to the refuters of the port that the upstream gives one.

Usage:
    python _verify/patch_refuter_significance.py
"""

from __future__ import annotations

import os

PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "src",
    "refuters",
    "refuters.mbt",
)

HELPER = '''///|
/// The kind of test the significance test of a refutation uses.
pub enum SignificanceTestType {
  /// The bootstrap test for a hundred simulations and more, the test of the
  /// normal distribution below that.
  Auto
  /// The two sided percentile test of the bootstrap.
  Bootstrap
  /// The test of the normal distribution.
  Normal
}

///|
/// The automatic kind of test.
pub fn SignificanceTestType::auto() -> SignificanceTestType {
  SignificanceTestType::Auto
}

///|
/// The two sided percentile test of the bootstrap.
pub fn SignificanceTestType::bootstrap() -> SignificanceTestType {
  SignificanceTestType::Bootstrap
}

///|
/// The test of the normal distribution.
pub fn SignificanceTestType::normal() -> SignificanceTestType {
  SignificanceTestType::Normal
}

///|
/// The p-value of the significance test of a refutation and whether the
/// estimate is significant at the given level.
///
/// This is the port of `test_significance` of `dowhy.causal_refuter`: the
/// estimate is tested against the distribution of the estimates the refuter
/// produced. The refutations that sever the causal relation test the zero
/// estimate against it, the ones that leave the relation alone test the
/// estimate of the data against it.
pub fn test_significance(
  estimate : Double,
  simulations : Array[Double],
  test_type~ : SignificanceTestType = SignificanceTestType::auto(),
  significance_level~ : Double = 0.05,
) -> (Double, Bool) {
  let p_value = match test_type {
    SignificanceTestType::Auto =>
      if simulations.length() >= 100 {
        bootstrap_significance(estimate, simulations)
      } else {
        normal_significance(estimate, simulations)
      }
    SignificanceTestType::Bootstrap => bootstrap_significance(estimate, simulations)
    SignificanceTestType::Normal => normal_significance(estimate, simulations)
  }
  (p_value, p_value <= significance_level)
}

///|
/// The two sided percentile p-value of the bootstrap test.
fn bootstrap_significance(
  estimate : Double,
  simulations : Array[Double],
) -> Double {
  if simulations.length() == 0 {
    return 1.0
  }
  let mut half = 0.0
  for value in simulations {
    if value > estimate {
      half = half + 1.0
    } else if value == estimate {
      half = half + 0.5
    }
  }
  half = half / simulations.length().to_double()
  let other = 1.0 - half
  if half < other {
    2.0 * half
  } else {
    2.0 * other
  }
}

///|
/// The p-value of the test of the normal distribution.
fn normal_significance(
  estimate : Double,
  simulations : Array[Double],
) -> Double {
  let mean = @utils.mean(simulations)
  let deviation = @utils.variance(simulations, 0).sqrt()
  let z_score = (estimate - mean) / deviation
  if z_score > 0.0 {
    1.0 - @utils.normal_cdf(z_score)
  } else {
    @utils.normal_cdf(z_score)
  }
}

'''

ANCHOR = "///|\n/// The bootstrap refuter."

ORIGINAL_TAIL = """  refutation.new_effect_lower = @utils.percentile(estimates, 2.5)
  refutation.new_effect_upper = @utils.percentile(estimates, 97.5)
  refutation
}"""

ORIGINAL_TAIL_WITH_SIGNIFICANCE = """  refutation.new_effect_lower = @utils.percentile(estimates, 2.5)
  refutation.new_effect_upper = @utils.percentile(estimates, 97.5)
  let (p_value, significant) = test_significance(
    estimator
      .estimate_effect(data, treatment_value, control_value, target_units)
      .estimate(),
    estimates,
  )
  refutation.p_value = p_value
  refutation.is_significant = significant
  refutation
}"""

ZERO_TAIL_WITH_SIGNIFICANCE = """  refutation.new_effect_lower = @utils.percentile(estimates, 2.5)
  refutation.new_effect_upper = @utils.percentile(estimates, 97.5)
  // The dummy outcome severs the causal relation, so the zero estimate is the
  // one the refutation tests against the estimates it produced.
  let (p_value, significant) = test_significance(0.0, estimates)
  refutation.p_value = p_value
  refutation.is_significant = significant
  refutation
}"""

BOOTSTRAP_ORIGINAL_TAIL = """  refutation.new_effect_lower = lower
  refutation.new_effect_upper = upper
  refutation
}"""

BOOTSTRAP_TAIL = """  refutation.new_effect_lower = lower
  refutation.new_effect_upper = upper
  let (p_value, significant) = test_significance(
    estimator
      .estimate_effect(data, treatment_value, control_value, target_units)
      .estimate(),
    estimates,
  )
  refutation.p_value = p_value
  refutation.is_significant = significant
  refutation
}"""


def patch_function(text: str, name: str, old: str, new: str) -> str:
    """Replaces a tail inside one function of the file."""
    start = text.index("pub fn " + name)
    end = text.index("\n}\n", start) + 3
    body = text[start:end]
    if new.strip() in body:
        return text
    if old not in body:
        raise RuntimeError(f"the tail of {name} was not found")
    body = body.replace(old, new, 1)
    return text[:start] + body + text[end:]


def main() -> None:
    with open(PATH, encoding="utf-8") as handle:
        text = handle.read()
    if "pub enum SignificanceTestType" in text:
        print("already patched")
        return
    text = text.replace(ANCHOR, HELPER + ANCHOR, 1)
    text = patch_function(
        text,
        "refute_bootstrap",
        BOOTSTRAP_ORIGINAL_TAIL,
        BOOTSTRAP_TAIL,
    )
    text = patch_function(
        text,
        "refute_data_subset",
        ORIGINAL_TAIL,
        ORIGINAL_TAIL_WITH_SIGNIFICANCE,
    )
    text = patch_function(
        text,
        "refute_dummy_outcome",
        ORIGINAL_TAIL,
        ZERO_TAIL_WITH_SIGNIFICANCE,
    )
    text = patch_function(
        text,
        "refute_random_common_cause",
        ORIGINAL_TAIL,
        ORIGINAL_TAIL_WITH_SIGNIFICANCE,
    )
    with open(PATH, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)
    print("patched", PATH)


if __name__ == "__main__":
    main()
