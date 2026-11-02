"""Derive the probability of the change of the bootstrap refuter from the noise.

The upstream takes `probability_of_change` as an optional argument and derives
it from `noise` when it is not given: the probability of the change of a boolean
or a categorical column is the noise, unless the noise is greater than one,
which is an error.  The port took a fixed default of `0.1`, so a caller that
raised the noise without raising the probability got a different behaviour than
the upstream.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "src" / "refuters" / "refuters.mbt"

OLD_SIGNATURE = """  required_variables~ : RequiredVariables = RequiredVariables::all(),
  noise~ : Double = 0.1,
  probability_of_change~ : Double = 0.1,
) -> CausalRefutation {
  let n = data.nrows()
  let sample_size = (sample_size_fraction * n.to_double()).to_int()
  let variables = choose_variables(
"""

NEW_SIGNATURE = """  required_variables~ : RequiredVariables = RequiredVariables::all(),
  noise~ : Double = 0.1,
  probability_of_change~ : Option[Double] = None,
) -> CausalRefutation {
  let n = data.nrows()
  let sample_size = (sample_size_fraction * n.to_double()).to_int()
  // The probability of the change of a boolean or a categorical column is the
  // noise, unless it is given, the way the upstream derives it.
  let probability = match probability_of_change {
    Some(probability) => {
      if probability > 1.0 {
        abort("Probability of Flip cannot be greater than 1")
      }
      probability
    }
    None => {
      if noise > 1.0 {
        abort("The value for Binary Flip cannot be greater than 1")
      }
      noise
    }
  }
  let variables = choose_variables(
"""

OLD_CALL = """    let perturbed = perturb_variables(
      resampled, variables, noise, probability_of_change, random,
    )
"""

NEW_CALL = """    let perturbed = perturb_variables(
      resampled, variables, noise, probability, random,
    )
"""

OLD_DOC = """/// The noise of a numeric column has the standard deviation of the given
/// fraction of the standard deviation of the column, the way the upstream
/// perturbs it. A column of zeros and ones is flipped and a discrete column
/// gets another one of its categories, both with the given probability.
"""

NEW_DOC = """/// The noise of a numeric column has the standard deviation of the given
/// fraction of the standard deviation of the column, the way the upstream
/// perturbs it. A column of zeros and ones is flipped and a discrete column
/// gets another one of its categories, both with the probability of the change,
/// which is the noise unless it is given.
"""


def main() -> None:
    text = TARGET.read_text(encoding="utf-8")
    for old, new in ((OLD_SIGNATURE, NEW_SIGNATURE), (OLD_CALL, NEW_CALL), (OLD_DOC, NEW_DOC)):
        count = text.count(old)
        if count != 1:
            raise SystemExit(f"expected one occurrence, found {count}: {old[:60]!r}")
        text = text.replace(old, new)
    TARGET.write_text(text, encoding="utf-8", newline="")
    print("patched", TARGET)


if __name__ == "__main__":
    main()
