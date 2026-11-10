///| Tests for the default strength of the confounder.
///
/// The cases mirror the default strengths of the upstream, which
/// `dowhy.causal_refuters.add_unobserved_common_cause` infers from the observed
/// common causes when the caller does not give one:
/// `_infer_default_kappa_t` and `_infer_default_kappa_y`. The upstream test
/// file `tests/causal_refuters/test_add_unobserved_common_cause.py` never asks
/// for them, because the cases of that file always give their strengths; the
/// sibling test file of the port, `src/tests/add_unobserved_common_cause.mbt`,
/// covers the refuter itself.
///
/// The reference script `_verify/kappa_inference_reference.py` runs the two
/// functions of the upstream on the rows of the port and prints their numbers.
/// The fixture is the data set of `src/datasets/datasets.mbt` with five common
/// causes, a binary treatment and a continuous outcome, so the numbers of the
/// upstream and the numbers of the port are the numbers of one data set:
///
/// * the `binary_flip` effect on the treatment gives the ten strengths
///   `0.079`, `0.0924`, `0.1058`, `0.1192`, `0.1326`, `0.146`, `0.1594`,
///   `0.1728`, `0.1862` and `0.1996`,
/// * a tenth of the strength gives the same ten numbers divided by ten,
/// * one common cause gives the single strength `0.47`, because the range of
///   the upstream holds one number only.
///
/// Two branches of the upstream do not return a number, and the port reports
/// what they mean instead:
///
/// * the `linear` effect reads the standard deviation of the column with
///   `np.std(t)[0]`, and the standard deviation of a column is a number and not
///   an array, so the branch raises an `IndexError`. The port computes the
///   number the branch means to compute, the correlation of every common cause
///   with the column scaled with its standard deviation,
/// * the `binary_flip` effect fits a classifier on the column, and a
///   continuous column is refused with a `ValueError`. The port aborts with a
///   message of the same kind, because MoonBit cannot catch an error.
///
/// The upstream returns the single strength of a range of one number as a
/// number and the range of many numbers as an array; the port returns an array
/// in both cases, so the caller of the port always gets a list of strengths.
///
/// The port has no entry point for these two functions yet: the refuter of the
/// upstream takes the strengths of the caller or infers them itself, and the
/// port of the refuter takes the strengths of its caller as well. The
/// functions are public, so a caller of the port can use them.

///|
/// The fixture: five common causes, a binary treatment and a continuous
/// outcome.
fn kappa_fixture() -> @datasets.Dataset {
  @datasets.linear_dataset(
    SEED,
    1000,
    @datasets.LinearConfig::five_common_causes_no_instrument(),
  )
}

///|
/// The fixture with one common cause, whose range of strengths holds one
/// number only.
fn kappa_one_cause_fixture() -> @datasets.Dataset {
  @datasets.linear_dataset(
    SEED,
    1000,
    @datasets.LinearConfig::new(num_common_causes=1),
  )
}

///|
/// Whether two numbers are close to each other.
fn kappa_near(a : Double, b : Double, tolerance : Double) -> Bool {
  (a - b).abs() <= tolerance
}

///|
/// Whether two lists of numbers are close to each other.
fn kappa_list_near(
  a : Array[Double],
  b : Array[Double],
  tolerance : Double,
) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i = 0; i < a.length(); i = i + 1 {
    if !kappa_near(a[i], b[i], tolerance) {
      return false
    }
  }
  true
}

///|
test "the default strength of the confounder on the treatment is the one of the upstream" {
  let dataset = kappa_fixture()
  let estimand = backdoor_estimand(dataset)
  let strengths = @refuters.infer_default_kappa_t(
    dataset.frame(),
    estimand,
    dataset.treatments()[0],
    @refuters.ConfoundersEffectOnT::binary_flip(),
    1.0,
    10,
  )
  assert_eq(strengths.length(), 10)
  assert_true(
    kappa_list_near(
      strengths,
      [
        0.079, 0.0924, 0.1058, 0.1192, 0.1326, 0.146, 0.1594, 0.1728, 0.1862, 0.1996,
      ],
      1.0e-9,
    ),
  )
}

///|
test "the default strength of the confounder on the treatment scales with the fraction of the strength" {
  let dataset = kappa_fixture()
  let estimand = backdoor_estimand(dataset)
  let strengths = @refuters.infer_default_kappa_t(
    dataset.frame(),
    estimand,
    dataset.treatments()[0],
    @refuters.ConfoundersEffectOnT::binary_flip(),
    0.1,
    10,
  )
  assert_eq(strengths.length(), 10)
  assert_true(
    kappa_list_near(
      strengths,
      [
        0.0079, 0.00924, 0.01058, 0.01192, 0.01326, 0.0146, 0.01594, 0.01728, 0.01862,
        0.01996,
      ],
      1.0e-9,
    ),
  )
}

///|
test "the default strength of the confounder on the treatment grows with the strength" {
  let dataset = kappa_fixture()
  let estimand = backdoor_estimand(dataset)
  let weak = @refuters.infer_default_kappa_t(
    dataset.frame(),
    estimand,
    dataset.treatments()[0],
    @refuters.ConfoundersEffectOnT::binary_flip(),
    0.1,
    10,
  )
  let strong = @refuters.infer_default_kappa_t(
    dataset.frame(),
    estimand,
    dataset.treatments()[0],
    @refuters.ConfoundersEffectOnT::binary_flip(),
    1.0,
    10,
  )
  for i = 0; i < strong.length(); i = i + 1 {
    assert_true(strong[i] > weak[i])
    assert_true(strong[i] <= 1.0)
  }
}

///|
test "the default strength of the confounder on the treatment with one common cause is a single number" {
  let dataset = kappa_one_cause_fixture()
  let estimand = backdoor_estimand(dataset)
  let strengths = @refuters.infer_default_kappa_t(
    dataset.frame(),
    estimand,
    dataset.treatments()[0],
    @refuters.ConfoundersEffectOnT::binary_flip(),
    1.0,
    10,
  )
  // The range of the upstream holds one number, so it returns that number and
  // not an array of ten numbers.
  assert_eq(strengths.length(), 1)
  assert_true(kappa_near(strengths[0], 0.47, 1.0e-9))
}

///|
test "the default strength of the confounder with a linear effect is the correlation of the upstream" {
  let dataset = kappa_fixture()
  let estimand = backdoor_estimand(dataset)
  let strengths = @refuters.infer_default_kappa_t(
    dataset.frame(),
    estimand,
    dataset.treatments()[0],
    @refuters.ConfoundersEffectOnT::linear(),
    1.0,
    10,
  )
  assert_eq(strengths.length(), 10)
  assert_true(
    kappa_list_near(
      strengths,
      [
        0.07745909681124524, 0.09358478422168222, 0.1097104716321192, 0.12583615904255618,
        0.14196184645299315, 0.1580875338634301, 0.1742132212738671, 0.1903389086843041,
        0.20646459609474105, 0.222590283505178,
      ],
      1.0e-12,
    ),
  )
}

///|
test "the default strength of the confounder on the outcome with a linear effect is the correlation of the upstream" {
  let dataset = kappa_fixture()
  let estimand = backdoor_estimand(dataset)
  let strengths = @refuters.infer_default_kappa_y(
    dataset.frame(),
    estimand,
    dataset.outcome(),
    @refuters.ConfoundersEffectOnY::linear(),
    1.0,
    10,
  )
  assert_eq(strengths.length(), 10)
  assert_true(
    kappa_list_near(
      strengths,
      [
        1.6643424063022958, 2.0834975769509048, 2.5026527475995137, 2.9218079182481227,
        3.3409630888967317, 3.7601182595453406, 4.17927343019395, 4.598428600842558,
        5.017583771491168, 5.436738942139776,
      ],
      1.0e-12,
    ),
  )
}

///|
test "the default strength of the confounder with one common cause and a linear effect is a single number" {
  let dataset = kappa_one_cause_fixture()
  let estimand = backdoor_estimand(dataset)
  let strengths = @refuters.infer_default_kappa_t(
    dataset.frame(),
    estimand,
    dataset.treatments()[0],
    @refuters.ConfoundersEffectOnT::linear(),
    1.0,
    10,
  )
  assert_eq(strengths.length(), 1)
  assert_true(kappa_near(strengths[0], 0.06842252560731886, 1.0e-12))
}
