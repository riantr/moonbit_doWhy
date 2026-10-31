/// Tests for the deterministic data sets that mirror the fixtures of DoWhy's
/// test suite.

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
