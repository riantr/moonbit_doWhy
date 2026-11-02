"""Let `CausalModel::refute_estimate` choose the kind of the placebo.

The upstream's `CausalModel.refute_estimate` forwards its keyword arguments to
the refuter, and `placebo_type` is one of them.  The port exposes it as a
labelled optional argument of the method.
"""

import io
import sys

PATH = r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\src\causal_model.mbt"


def replace(text, old, new):
    if text.count(old) != 1:
        sys.exit("marker not found exactly once:\n" + old[:300])
    return text.replace(old, new)


OLD_SIGNATURE = """pub fn CausalModel::refute_estimate(
  self : CausalModel,
  method_name : String,
  estimate : @model.CausalEstimate,
  refuter_name : String,
  num_simulations : Int32,
  random : @utils.Random,
) -> @refuters.CausalRefutation {
"""

NEW_SIGNATURE = """pub fn CausalModel::refute_estimate(
  self : CausalModel,
  method_name : String,
  estimate : @model.CausalEstimate,
  refuter_name : String,
  num_simulations : Int32,
  random : @utils.Random,
  placebo_type~ : @refuters.PlaceboType = @refuters.PlaceboType::random_data(),
) -> @refuters.CausalRefutation {
"""

OLD_PLACEBO = """    "placebo" =>
      @refuters.refute_placebo_treatment(
        estimator,
        estimand,
        self.data,
        self.treatment[0],
        num_simulations,
        estimate.treatment_value,
        estimate.control_value,
        "ate",
        random,
      )
"""

NEW_PLACEBO = """    "placebo" =>
      @refuters.refute_placebo_treatment(
        estimator,
        estimand,
        self.data,
        self.treatment[0],
        num_simulations,
        estimate.treatment_value,
        estimate.control_value,
        "ate",
        random,
        placebo_type=placebo_type,
      )
"""

OLD_DOC = """/// `refuter_name` is one of `"bootstrap"`, `"placebo"`, `"subset"`,
/// `"dummy_outcome"`, `"random_common_cause"` or
/// `"add_unobserved_common_cause"`.
"""

NEW_DOC = """/// `refuter_name` is one of `"bootstrap"`, `"placebo"`, `"subset"`,
/// `"dummy_outcome"`, `"random_common_cause"` or
/// `"add_unobserved_common_cause"`.
///
/// `placebo_type` chooses the kind of the placebo the placebo treatment
/// refuter builds: a random variable of the kind of the treatment, or the rows
/// of the treatment, permuted.  The upstream forwards it as a keyword argument
/// of its own method.
"""

text = io.open(PATH, encoding="utf-8").read()
text = replace(text, OLD_SIGNATURE, NEW_SIGNATURE)
text = replace(text, OLD_PLACEBO, NEW_PLACEBO)
text = replace(text, OLD_DOC, NEW_DOC)
io.open(PATH, "w", encoding="utf-8", newline="\n").write(text)
print("patched")
