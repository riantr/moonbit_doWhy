"""Replaces the placebo treatment refuter of the port with the faithful port.

The new refuter follows `dowhy.causal_refuters.placebo_treatment_refuter`:
the placebo is a random variable of the kind the dtype of the treatment asks
for, or a permutation of the rows of the treatment, and the refutation reports
the p-value of the significance test of the zero estimate against the
estimates of the refutation.

Usage:
    python _verify/patch_placebo_refuter.py
"""

from __future__ import annotations

import os

PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "src",
    "refuters",
    "refuters.mbt",
)

START = "///|\n/// The placebo treatment refuter."

END = "///|\n/// The data subset refuter."

NEW = '''///|
/// The kind of placebo the placebo treatment refuter builds.
pub enum PlaceboType {
  /// A random variable of the kind the treatment column asks for.
  RandomData
  /// The rows of the treatment, permuted.
  Permute
}

///|
/// The random data placebo: the treatment is replaced by a random variable.
pub fn PlaceboType::random_data() -> PlaceboType {
  PlaceboType::RandomData
}

///|
/// The permuted placebo: the rows of the treatment are permuted.
pub fn PlaceboType::permute() -> PlaceboType {
  PlaceboType::Permute
}

///|
/// The placebo treatment refuter.
///
/// The treatment is replaced by a placebo variable and the effect is estimated
/// again on every simulation; a causal estimate that survives the refutation is
/// not credible.
///
/// The random data placebo builds the placebo the way the upstream does: a
/// continuous treatment becomes a constant zero, a binary treatment becomes a
/// random draw of a Bernoulli variable with the probability of a half, and a
/// categorical treatment becomes a random draw of one of its categories. The
/// permuted placebo permutes the rows of the treatment.
///
/// The upstream reports the error it raises for the instrumental variable
/// method with the random data placebo; MoonBit cannot catch an error, so the
/// port aborts with the message of the upstream.
pub fn refute_placebo_treatment(
  estimator : @estimators.CausalEstimator,
  estimand : @identifiers.IdentifiedEstimand,
  data : @api.DataFrame,
  treatment_name : String,
  num_simulations : Int32,
  treatment_value : Double,
  control_value : Double,
  target_units : String,
  random : @utils.Random,
  placebo_type~ : PlaceboType = PlaceboType::random_data(),
) -> CausalRefutation {
  let identifier = estimand.identifier_method()
  if identifier == "iv" && placebo_type != PlaceboType::Permute {
    abort(
      "Only placebo_type='permute' is supported for creating placebo for instrumental variable estimation methods.",
    )
  }
  let n = data.nrows()
  let kind = treatment_kind(data, treatment_name)
  let instrument = if identifier == "iv" {
    Some(estimator.instrument_name())
  } else {
    None
  }
  let estimates : Array[Double] = []
  for i = 0; i < num_simulations; i = i + 1 {
    // The permuted placebo permutes the rows of the treatment; the random
    // data placebo draws a new value for every row.
    let permutation = if placebo_type == PlaceboType::Permute {
      random.shuffle(index_column(n))
    } else {
      index_column(n)
    }
    let mut placebo_data = data
    match kind {
      TreatmentKind::Categorical => {
        let values = placebo_categories(
          data.discrete(treatment_name),
          random,
          permutation,
        )
        placebo_data = placebo_data.with_discrete("placebo", values)
      }
      TreatmentKind::Binary => {
        let values = placebo_binary(random, permutation)
        placebo_data = placebo_data.with_numeric("placebo", values)
      }
      TreatmentKind::Continuous => {
        let values = placebo_constant(random, permutation)
        placebo_data = placebo_data.with_numeric("placebo", values)
      }
    }
    // The instrumental variable method replaces its instrument as well; the
    // upstream renames it after the placebo and permutes it with the same
    // permutation.
    let mut placebo_estimand = estimand.with_treatment(["placebo"])
    let mut placebo_estimator = estimator
    match instrument {
      Some(name) => {
        let values = permute_values(data.numeric(name), permutation)
        placebo_data = placebo_data.with_numeric("placebo_" + name, values)
        placebo_estimand = placebo_estimand.with_instrumental_variables([
          "placebo_" + name,
        ])
        placebo_estimator = estimator.with_instrument_name("placebo_" + name)
      }
      None => ()
    }
    let effect = reestimate(
      placebo_estimator,
      placebo_estimand,
      placebo_data,
      treatment_value,
      control_value,
      target_units,
    )
    estimates.push(effect)
  }
  let mean_effect = @utils.mean(estimates)
  let refutation = CausalRefutation::new(
    estimator
      .estimate_effect(data, treatment_value, control_value, target_units)
      .estimate(),
    mean_effect,
    "Refute: Use a Placebo Treatment",
  )
  refutation.new_effect_lower = @utils.percentile(estimates, 2.5)
  refutation.new_effect_upper = @utils.percentile(estimates, 97.5)
  // The upstream tests the zero estimate against the estimates of the
  // refutation, because the placebo severs the causal relation.
  let (p_value, significant) = test_significance(0.0, estimates)
  refutation.p_value = p_value
  refutation.is_significant = significant
  refutation
}

///|
/// The kind of the treatment column of the placebo refuter.
///
/// The upstream keys the placebo on the dtype of the column: a float becomes a
/// constant zero, a bool becomes a random Bernoulli variable, an int becomes a
/// random integer and a category becomes a random draw of one of its
/// categories. The frame of the port holds no dtype, so the port recognises
/// the binary treatment by its two values, which is what the data set of the
/// upstream holds for one.
enum TreatmentKind {
  Continuous
  Binary
  Categorical
}

///|
/// The kind of the treatment column of the placebo refuter.
fn treatment_kind(
  data : @api.DataFrame,
  treatment_name : String,
) -> TreatmentKind {
  if data.is_discrete(treatment_name) {
    return TreatmentKind::Categorical
  }
  let values = data.numeric(treatment_name)
  let mut binary = true
  for value in values {
    if value != 0.0 && value != 1.0 {
      binary = false
    }
  }
  if binary && values.length() > 0 {
    TreatmentKind::Binary
  } else {
    TreatmentKind::Continuous
  }
}

///|
/// The placebo of a binary treatment: a Bernoulli variable with the
/// probability of a half, the way the upstream draws it.
fn placebo_binary(
  random : @utils.Random,
  permutation : Array[Double],
) -> Array[Double] {
  let values : Array[Double] = []
  for _ in permutation {
    values.push(if random.next_double() < 0.5 { 0.0 } else { 1.0 })
  }
  values
}

///|
/// The placebo of a continuous treatment: the constant zero, the way the
/// upstream draws it with a normal distribution of a mean of zero and a
/// standard deviation of zero.
fn placebo_constant(
  random : @utils.Random,
  permutation : Array[Double],
) -> Array[Double] {
  let values : Array[Double] = []
  for _ in permutation {
    values.push(random.next_double() * 0.0)
  }
  values
}

///|
/// The placebo of a categorical treatment: a random draw of one of the
/// categories, the way the upstream draws it.
fn placebo_categories(
  categories : Array[String],
  random : @utils.Random,
  permutation : Array[Double],
) -> Array[String] {
  let values : Array[String] = []
  for _ in permutation {
    if categories.length() == 0 {
      values.push("")
    } else {
      values.push(categories[random.next_int(categories.length())])
    }
  }
  values
}

///|
/// The values of a column in the order of the given permutation of the rows.
fn permute_values(
  values : Array[Double],
  permutation : Array[Double],
) -> Array[Double] {
  let out : Array[Double] = []
  for row in permutation {
    out.push(values[row.to_int()])
  }
  out
}

'''


def main() -> None:
    with open(PATH, encoding="utf-8") as handle:
        text = handle.read()
    if "pub enum PlaceboType" in text:
        print("already patched")
        return
    start = text.index(START)
    end = text.index(END)
    text = text[:start] + NEW + text[end:]
    with open(PATH, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)
    print("patched", PATH)


if __name__ == "__main__":
    main()
