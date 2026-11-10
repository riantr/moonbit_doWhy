/// Tests for the deterministic data sets that mirror the fixtures of DoWhy's
/// test suite.
///
/// The sales data set of the port mirrors `tests/test_datasets.py`, whose case
/// compares the two fixtures of the sales data set of the upstream.

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
