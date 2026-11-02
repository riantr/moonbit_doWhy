"""Fix the permuted placebo of the port.

The upstream's permuted placebo takes the original treatment column and
permutes its rows (`data[treatment_names].iloc[permuted_idx].values`).  The port
drew fresh random values for every kind of treatment instead, so the permuted
placebo of a continuous treatment was the constant zero and its estimate was
exactly zero, like the random data placebo.

The patch also makes the random data placebo of a categorical treatment draw
from the distinct categories of the column, the way the upstream does with
`data[treatment].unique()`, and not from its rows.
"""

import io
import sys

PATH = r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\src\refuters\refuters.mbt"


def replace(text, old, new):
    if text.count(old) != 1:
        sys.exit("marker not found exactly once:\n" + old[:200])
    return text.replace(old, new)


OLD_MATCH = '''    let mut placebo_data = data
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
'''

NEW_MATCH = '''    let mut placebo_data = data
    match kind {
      TreatmentKind::Categorical => {
        // The permuted placebo takes the rows of the treatment and permutes
        // them; the random data placebo draws one of the categories of the
        // treatment for every row.
        let values = if is_permute(placebo_type) {
          permute_categories(data.discrete(treatment_name), permutation)
        } else {
          placebo_categories(
            distinct_categories(data.discrete(treatment_name)),
            random,
            n,
          )
        }
        placebo_data = placebo_data.with_discrete("placebo", values)
      }
      TreatmentKind::Binary => {
        let values = if is_permute(placebo_type) {
          permute_values(data.numeric(treatment_name), permutation)
        } else {
          placebo_binary(random, n)
        }
        placebo_data = placebo_data.with_numeric("placebo", values)
      }
      TreatmentKind::Continuous => {
        let values = if is_permute(placebo_type) {
          permute_values(data.numeric(treatment_name), permutation)
        } else {
          placebo_constant(random, n)
        }
        placebo_data = placebo_data.with_numeric("placebo", values)
      }
    }
'''

OLD_HELPERS = '''///|
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
'''

NEW_HELPERS = '''///|
/// The placebo of a binary treatment: a Bernoulli variable with the
/// probability of a half, the way the upstream draws it.
fn placebo_binary(random : @utils.Random, n : Int32) -> Array[Double] {
  let values : Array[Double] = []
  for _ in 0..<n {
    values.push(if random.next_double() < 0.5 { 0.0 } else { 1.0 })
  }
  values
}

///|
/// The placebo of a continuous treatment: the constant zero, the way the
/// upstream draws it with a normal distribution of a mean of zero and a
/// standard deviation of zero.
fn placebo_constant(random : @utils.Random, n : Int32) -> Array[Double] {
  let values : Array[Double] = []
  for _ in 0..<n {
    values.push(random.next_double() * 0.0)
  }
  values
}

///|
/// The placebo of a categorical treatment: a random draw of one of its
/// categories, the way the upstream draws it.
fn placebo_categories(
  categories : Array[String],
  random : @utils.Random,
  n : Int32,
) -> Array[String] {
  let values : Array[String] = []
  for _ in 0..<n {
    if categories.length() == 0 {
      values.push("")
    } else {
      values.push(categories[random.next_int(categories.length())])
    }
  }
  values
}

///|
/// The distinct values of a discrete column, in the order of their first
/// appearance.
///
/// The upstream draws the random placebo of a categorical treatment from the
/// distinct categories of its column, and not from its rows, so a category
/// that holds more rows is not drawn more often.
fn distinct_categories(values : Array[String]) -> Array[String] {
  let categories : Array[String] = []
  for value in values {
    let mut found = false
    for category in categories {
      if category == value {
        found = true
      }
    }
    if !found {
      categories.push(value)
    }
  }
  categories
}

///|
/// The values of a discrete column in the order of the given permutation of
/// the rows.
fn permute_categories(
  values : Array[String],
  permutation : Array[Double],
) -> Array[String] {
  let out : Array[String] = []
  for row in permutation {
    out.push(values[row.to_int()])
  }
  out
}
'''

OLD_DOC = '''/// The random data placebo builds the placebo the way the upstream does: a
/// continuous treatment becomes a constant zero, a binary treatment becomes a
/// random draw of a Bernoulli variable with the probability of a half, and a
/// categorical treatment becomes a random draw of one of its categories. The
/// permuted placebo permutes the rows of the treatment.
'''

NEW_DOC = '''/// The random data placebo builds the placebo the way the upstream does: a
/// continuous treatment becomes a constant zero, a binary treatment becomes a
/// random draw of a Bernoulli variable with the probability of a half, and a
/// categorical treatment becomes a random draw of one of its categories. The
/// permuted placebo takes the rows of the treatment and permutes them.
'''

text = io.open(PATH, encoding="utf-8").read()
text = replace(text, OLD_MATCH, NEW_MATCH)
text = replace(text, OLD_HELPERS, NEW_HELPERS)
text = replace(text, OLD_DOC, NEW_DOC)
io.open(PATH, "w", encoding="utf-8", newline="\n").write(text)
print("patched")
