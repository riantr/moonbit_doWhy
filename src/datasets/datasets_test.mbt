/// Tests for the deterministic data sets that mirror the fixtures of DoWhy's
/// test suite.
///
/// The sales data set of the port mirrors `tests/test_datasets.py`, whose case
/// compares the two fixtures of the sales data set of the upstream.
///
/// The data set `xy_dataset` of the port mirrors `dowhy.datasets.xy_dataset`,
/// which the upstream does not test.  The reference script
/// `_verify/xy_dataset_reference.py` runs the upstream data set with the
/// generator of numpy and prints the rows the port has to reproduce.
/// The cases of this file mirror the data set of the sales of the notebook of the upstream.  The notebook `sales_attribution_intervention.ipynb`.

///|
/// Whether two numeric columns hold the same values.
fn same_values(a : Array[Double], b : Array[Double]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  let mut i = 0
  while i < a.length() {
    if a[i] != b[i] {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// Whether every value of the column is zero or one.
fn is_binary(values : Array[Double]) -> Bool {
  let mut i = 0
  while i < values.length() {
    if values[i] != 0.0 && values[i] != 1.0 {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// The mean of the column over the rows the mask selects.
fn masked_mean(values : Array[Double], mask : Array[Bool]) -> Double {
  let mut sum = 0.0
  let mut count = 0
  let mut i = 0
  while i < values.length() {
    if mask[i] {
      sum = sum + values[i]
      count = count + 1
    }
    i = i + 1
  }
  if count == 0 {
    0.0
  } else {
    sum / count.to_double()
  }
}

///|
test "the confounded fixture has the shape of the python fixture" {
  let df = @datasets.confounded_data(42, 500)
  assert_eq(df.nrows(), 500)
  let columns = df.column_names()
  assert_eq(columns.length(), 3)
  assert_eq(columns[0], "W0")
  assert_eq(columns[1], "v0")
  assert_eq(columns[2], "y")
}

///|
test "the fixture without confounding has the shape of the python fixture" {
  let df = @datasets.no_confounding_data(42, 500)
  assert_eq(df.nrows(), 500)
  let columns = df.column_names()
  assert_eq(columns.length(), 2)
  assert_eq(columns[0], "v0")
  assert_eq(columns[1], "y")
}

///|
test "the effect modifier fixture has the shape of the python fixture" {
  let df = @datasets.effect_modifier_data(42, 500)
  assert_eq(df.nrows(), 500)
  let columns = df.column_names()
  assert_eq(columns.length(), 3)
  assert_eq(columns[0], "X0")
  assert_eq(columns[1], "v0")
  assert_eq(columns[2], "y")
}

///|
test "the instrumental variable fixture has the shape of the python fixture" {
  let df = @datasets.instrumental_variable_data(42, 500)
  assert_eq(df.nrows(), 500)
  let columns = df.column_names()
  assert_eq(columns.length(), 4)
  assert_eq(columns[0], "Z0")
  assert_eq(columns[1], "W0")
  assert_eq(columns[2], "v0")
  assert_eq(columns[3], "y")
}

///|
test "the frontdoor fixture has the shape of the python fixture" {
  let df = @datasets.frontdoor_data(42, 500)
  assert_eq(df.nrows(), 500)
  let columns = df.column_names()
  assert_eq(columns.length(), 4)
  assert_eq(columns[0], "FD0")
  assert_eq(columns[1], "W0")
  assert_eq(columns[2], "v0")
  assert_eq(columns[3], "y")
}

///|
test "the treatment of the binary fixtures is zero or one" {
  assert_true(is_binary(@datasets.confounded_data(1, 200).numeric("v0")))
  assert_true(is_binary(@datasets.no_confounding_data(1, 200).numeric("v0")))
  assert_true(is_binary(@datasets.effect_modifier_data(1, 200).numeric("v0")))
  assert_true(
    is_binary(@datasets.instrumental_variable_data(1, 200).numeric("v0")),
  )
  assert_true(is_binary(@datasets.frontdoor_data(1, 200).numeric("v0")))
}

///|
test "the same seed gives the same data" {
  let first = @datasets.confounded_data(7, 200)
  let second = @datasets.confounded_data(7, 200)
  assert_true(same_values(first.numeric("W0"), second.numeric("W0")))
  assert_true(same_values(first.numeric("v0"), second.numeric("v0")))
  assert_true(same_values(first.numeric("y"), second.numeric("y")))
}

///|
test "the same seed gives the same data for every fixture" {
  assert_true(
    same_values(
      @datasets.no_confounding_data(9, 100).numeric("y"),
      @datasets.no_confounding_data(9, 100).numeric("y"),
    ),
  )
  assert_true(
    same_values(
      @datasets.effect_modifier_data(9, 100).numeric("X0"),
      @datasets.effect_modifier_data(9, 100).numeric("X0"),
    ),
  )
  assert_true(
    same_values(
      @datasets.instrumental_variable_data(9, 100).numeric("Z0"),
      @datasets.instrumental_variable_data(9, 100).numeric("Z0"),
    ),
  )
  assert_true(
    same_values(
      @datasets.frontdoor_data(9, 100).numeric("FD0"),
      @datasets.frontdoor_data(9, 100).numeric("FD0"),
    ),
  )
}

///|
test "different seeds give different data" {
  let first = @datasets.confounded_data(1, 200)
  let second = @datasets.confounded_data(2, 200)
  assert_false(same_values(first.numeric("y"), second.numeric("y")))
  assert_false(same_values(first.numeric("v0"), second.numeric("v0")))
}

///|
test "the true treatment effect of the confounded fixture is the beta" {
  let dataset = @datasets.confounded_dataset(42, 500)
  assert_true((dataset.ate - 10.0).abs() < 0.1)
}

///|
test "the true treatment effect of the fixture without confounding is the beta" {
  let dataset = @datasets.no_confounding_dataset(42, 500)
  assert_true((dataset.ate - 10.0).abs() < 0.1)
}

///|
test "the true treatment effect of the instrumental variable fixture is the beta" {
  let dataset = @datasets.instrumental_variable_dataset(42, 500)
  assert_true((dataset.ate - 10.0).abs() < 1.0e-9)
}

///|
test "the true treatment effect of the frontdoor fixture is the mediated effect" {
  let dataset = @datasets.frontdoor_dataset(42, 500)
  assert_true(dataset.ate > 0.0)
  assert_true(dataset.ate < 25.0)
}

///|
test "the true treatment effect of the effect modifier fixture stays positive" {
  let dataset = @datasets.effect_modifier_dataset(42, 500)
  assert_true(dataset.ate > 0.0)
  assert_true(dataset.ate < 20.0)
}

///|
test "the outcome of the confounded fixture responds to the treatment" {
  let df = @datasets.confounded_data(5, 2000)
  let treatment = df.numeric("v0")
  let outcome = df.numeric("y")
  let treated : Array[Bool] = []
  let control : Array[Bool] = []
  let mut i = 0
  while i < treatment.length() {
    treated.push(treatment[i] == 1.0)
    control.push(treatment[i] == 0.0)
    i = i + 1
  }
  let difference = masked_mean(outcome, treated) - masked_mean(outcome, control)
  assert_true(difference > 5.0)
  assert_true(difference < 15.0)
}

///|
test "the common cause of the confounded fixture is associated with the treatment" {
  let df = @datasets.confounded_data(5, 2000)
  let treatment = df.numeric("v0")
  let cause = df.numeric("W0")
  let treated : Array[Bool] = []
  let control : Array[Bool] = []
  let mut i = 0
  while i < treatment.length() {
    treated.push(treatment[i] == 1.0)
    control.push(treatment[i] == 0.0)
    i = i + 1
  }
  // The common cause shifts the treatment, so the two groups differ.
  assert_true(
    (masked_mean(cause, treated) - masked_mean(cause, control)).abs() > 0.01,
  )
}

///|
test "the discretised common causes are categorical" {
  let dataset = @datasets.linear_dataset(
    3,
    200,
    @datasets.LinearConfig::discrete_common_causes(),
  )
  let columns = dataset.df.column_names()
  assert_eq(columns.length(), 7)
  assert_eq(columns[0], "Z0")
  assert_eq(columns[1], "Z1")
  assert_eq(columns[2], "W0")
  assert_eq(columns[3], "W1")
  assert_eq(columns[4], "W2")
  assert_eq(columns[5], "v0")
  assert_eq(columns[6], "y")
  let levels = dataset.df.discrete("W1")
  assert_eq(levels.length(), 200)
  let mut i = 0
  while i < levels.length() {
    assert_true(
      levels[i] == "0" ||
      levels[i] == "1" ||
      levels[i] == "2" ||
      levels[i] == "3",
    )
    i = i + 1
  }
  // The first common cause stays continuous.
  assert_eq(dataset.df.numeric("W0").length(), 200)
}

///|
test "the metadata of the data sets names the columns" {
  let dataset = @datasets.linear_dataset(
    11,
    100,
    @datasets.LinearConfig::instrumental_variable(),
  )
  assert_eq(dataset.treatment_names, ["v0"])
  assert_eq(dataset.outcome_name, "y")
  assert_eq(dataset.common_cause_names, ["W0"])
  assert_eq(dataset.instrument_names, ["Z0"])
  assert_eq(dataset.effect_modifier_names, [])
  assert_eq(dataset.frontdoor_names, [])
}

///|
/// The number of the shopping events of the frame.
fn count_events(df : @api.DataFrame) -> Int32 {
  let flags = df.discrete("Shopping Event?")
  let mut count = 0
  let mut i = 0
  while i < flags.length() {
    if flags[i] == "true" {
      count = count + 1
    }
    i = i + 1
  }
  count
}

///|
/// Whether two numbers are within a relative distance of each other.
fn close_to(actual : Double, expected : Double, tolerance : Double) -> Bool {
  (actual - expected).abs() <= tolerance * expected.abs()
}

///|
test "the sales data set has the columns of the python fixture" {
  let df = @datasets.sales_dataset(
    2024,
    365,
    @datasets.SalesConfig::ten_events(),
  )
  assert_eq(df.nrows(), 365)
  let columns = df.column_names()
  assert_eq(columns.length(), 9)
  assert_eq(columns[0], "Date")
  assert_eq(columns[1], "Shopping Event?")
  assert_eq(columns[2], "Ad Spend")
  assert_eq(columns[3], "Page Views")
  assert_eq(columns[4], "Unit Price")
  assert_eq(columns[5], "Sold Units")
  assert_eq(columns[6], "Revenue")
  assert_eq(columns[7], "Operational Cost")
  assert_eq(columns[8], "Profit")
  // The range of the upstream runs over the year of 2021.
  assert_eq(df.discrete("Date")[0], "2021-01-01")
  assert_eq(df.discrete("Date")[364], "2021-12-31")
}

///|
test "the sales data set holds the number of shopping events of the upstream" {
  let first = @datasets.sales_dataset(
    2024,
    365,
    @datasets.SalesConfig::ten_events(),
  )
  let second = @datasets.sales_dataset(
    2024,
    365,
    @datasets.SalesConfig::discounted(),
  )
  assert_eq(count_events(first), 10)
  assert_eq(count_events(second), 10)
}

///|
test "the sales data set reproduces the relations of the upstream fixture" {
  let first = @datasets.sales_dataset(
    2024,
    365,
    @datasets.SalesConfig::ten_events(),
  )
  let second = @datasets.sales_dataset(
    2024,
    365,
    @datasets.SalesConfig::discounted(),
  )
  // The discount makes the profit of the day smaller, the page visitors fewer
  // and the sold units more numerous, which is what the upstream case of the
  // sales data set asserts.
  assert_true(first.mean("Profit") > second.mean("Profit"))
  assert_true(first.mean("Page Views") > second.mean("Page Views"))
  assert_true(first.mean("Sold Units") < second.mean("Sold Units"))
}

///|
test "the sales data set has the statistics of the python fixture" {
  let first = @datasets.sales_dataset(
    2024,
    365,
    @datasets.SalesConfig::ten_events(),
  )
  let second = @datasets.sales_dataset(
    2024,
    365,
    @datasets.SalesConfig::discounted(),
  )
  // The numbers of the upstream, which the reference script prints.  The
  // upstream draws its numbers with the global generator of NumPy, so its own
  // numbers move by less than a percent from one seed to the other.
  assert_true(close_to(first.mean("Ad Spend"), 1332.72, 0.02))
  assert_true(close_to(first.mean("Page Views"), 11973.82, 0.02))
  assert_true(close_to(first.mean("Unit Price"), 996.74, 0.02))
  assert_true(close_to(first.mean("Sold Units"), 2463.99, 0.02))
  assert_true(close_to(first.mean("Revenue"), 2443307.50, 0.02))
  assert_true(close_to(first.mean("Operational Cost"), 1733336.73, 0.02))
  assert_true(close_to(first.mean("Profit"), 709970.77, 0.02))
  assert_true(close_to(second.mean("Page Views"), 10177.26, 0.02))
  assert_true(close_to(second.mean("Sold Units"), 2829.00, 0.02))
  assert_true(close_to(second.mean("Profit"), 617295.22, 0.02))
}

///|
/// Whether the column of the frame holds the given values.
///
/// The comparison has a tolerance, because the sum of the products of the
/// upstream is a matrix product of BLAS and the sum of the port is a loop, and
/// the two differ in the last bit of the result.
fn column_matches(
  df : @api.DataFrame,
  name : String,
  expected : Array[Double],
) -> Bool {
  let values = df.numeric(name)
  if values.length() < expected.length() {
    return false
  }
  let mut i = 0
  while i < expected.length() {
    let difference = (values[i] - expected[i]).abs()
    if difference > 1.0e-12 * (1.0 + expected[i].abs()) {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// test "the data set of the hidden confounder reproduces the rows of the upstream"
///
/// The numbers are the ones the reference script
/// `_verify/xy_dataset_reference.py` prints for the upstream
/// `dowhy.datasets.xy_dataset`.
test "the data set of the hidden confounder reproduces the rows of the upstream" {
  let dataset = @datasets.xy_dataset(2025, 6)
  let df = dataset.frame()
  assert_eq(df.nrows(), 6)
  assert_eq(df.column_names(), ["Treatment", "Outcome", "w0", "s"])
  assert_eq(dataset.treatments(), ["Treatment"])
  assert_eq(dataset.outcome(), "Outcome")
  assert_eq(dataset.common_causes(), ["w0"])
  assert_eq(dataset.instruments(), [])
  // The upstream holds no true effect for this data set, so the port reports
  // the coefficient of the treatment in the outcome equation.
  assert_true(dataset.average_treatment_effect() == 1.0)
  assert_true(
    column_matches(df, "Treatment", [
      2.0205588839428206, 11.00180305457012, 5.7296250188167175, 6.213842951590536,
    ]),
  )
  assert_true(
    column_matches(df, "Outcome", [
      5.527216031660575, 21.061949405260172, 13.661719348845189, 13.296161578383336,
    ]),
  )
  assert_true(
    column_matches(df, "w0", [
      -3.887050938717114, 4.267517482751913, 1.1685070439547012, 0.8772649765337284,
    ]),
  )
  assert_true(
    column_matches(df, "s", [
      6.663921049033288, 9.875329108598164, 4.682704060744283, 1.2328737952635438,
    ]),
  )
}

///|
/// test "the data set with more common causes reproduces the rows of the upstream"
test "the data set with more common causes reproduces the rows of the upstream" {
  let dataset = @datasets.xy_dataset(2025, 6, num_common_causes=3)
  let df = dataset.frame()
  assert_eq(df.column_names(), ["Treatment", "Outcome", "w0", "s", "w1", "w2"])
  assert_eq(dataset.common_causes(), ["w0", "w1", "w2"])
  assert_true(
    column_matches(df, "Treatment", [
      2.383742313428007, 10.463526364165974, 6.154614807476208, 6.55393086189053,
    ]),
  )
  assert_true(
    column_matches(df, "Outcome", [
      6.087632602840931, 20.257058940065306, 14.352476976126635, 13.720581587049445,
    ]),
  )
  assert_true(
    column_matches(df, "w1", [
      0.618876524448694, -0.6083631838044913, 1.144371250108472, -0.6263282241105661,
    ]),
  )
  assert_true(
    column_matches(df, "w2", [
      0.07642738260428648, -0.2889001915268885, -0.14947563888159301, 0.7572075899265837,
    ]),
  )
}

///|
/// test "the data set without an effect reproduces the rows of the upstream"
test "the data set without an effect reproduces the rows of the upstream" {
  let dataset = @datasets.xy_dataset(2025, 6, effect=false)
  let df = dataset.frame()
  assert_true(dataset.average_treatment_effect() == 0.0)
  // The treatment does not change, because the error terms of the treatment do
  // not depend on the effect.
  assert_true(
    column_matches(df, "Treatment", [
      2.0205588839428206, 11.00180305457012, 5.7296250188167175, 6.213842951590536,
    ]),
  )
  assert_true(
    column_matches(df, "Outcome", [
      5.61960620900064, 20.327663833441967, 15.100601373983173, 13.959583603326529,
    ]),
  )
}

///|
/// test "the data set of the non-linear relation reproduces the rows of the upstream"
test "the data set of the non-linear relation reproduces the rows of the upstream" {
  let dataset = @datasets.xy_dataset(2025, 6, is_linear=false)
  let df = dataset.frame()
  assert_true(
    column_matches(df, "Treatment", [
      21.016774822841533, 24.94599103741143, 5.92652668663377, 6.10617181410953,
    ]),
  )
  assert_true(
    column_matches(df, "Outcome", [
      43.519647909458, 48.95032537094279, 14.055522684479293, 13.080819303421324,
    ]),
  )
}

///|
/// test "the data set with a wider error reproduces the rows of the upstream"
test "the data set with a wider error reproduces the rows of the upstream" {
  let dataset = @datasets.xy_dataset(2025, 6, sd_error=2.5)
  let df = dataset.frame()
  assert_true(
    column_matches(df, "Treatment", [
      1.8819736179327222, 12.103231412297431, 3.5713019811097415, 5.218709914175745,
    ]),
  )
  assert_true(
    column_matches(df, "Outcome", [
      7.479192895302779, 21.852321064894696, 12.648777240248867, 12.60860901635715,
    ]),
  )
}

///|
/// test "the hidden confounder of the data set is the parabola of its side of the
/// fifth unit"
test "the hidden confounder of the data set is the parabola of its side of the fifth unit" {
  let dataset = @datasets.xy_dataset(2025, 200)
  let df = dataset.frame()
  let w0 = df.numeric("w0")
  let s = df.numeric("s")
  let mut i = 0
  while i < w0.length() {
    assert_true(s[i] >= 0.0 && s[i] <= 10.0)
    // The first parabola of the confounder is zero on the right of the fifth
    // unit and the second one is zero on the left of it, so the confounder is
    // the first parabola below the fifth unit and the second one above it.
    if s[i] <= 5.0 {
      let first = 4.0 - (s[i] - 3.0) * (s[i] - 3.0)
      assert_true((w0[i] - first).abs() < 1.0e-12)
    } else {
      let second = (s[i] - 7.0) * (s[i] - 7.0) - 4.0
      assert_true((w0[i] - second).abs() < 1.0e-12)
    }
    i = i + 1
  }
}
