/// The sales data set of DoWhy, with the daily rows of a single product.
///
/// This is the port of `dowhy.datasets.sales_dataset`.  The upstream builds
/// the data set from a date range and draws its numbers with the global
/// generator of NumPy, so the port takes the number of the days of the range
/// and a seed of its own.  The data has the same shape and the same
/// statistical properties: the same columns, the same kind of values and the
/// same relations between the columns.
///
/// The `Date` column of the upstream holds the timestamps of the days.  The
/// port holds the date of the day as a string of the form `YYYY-MM-DD`, and
/// the range starts at the first of January of 2021, which is the start date
/// of the upstream.

///|
/// The parameters of the sales data set.
///
/// This is the port of the keyword arguments of
/// `dowhy.datasets.sales_dataset`.  The defaults are the defaults of the
/// upstream: fifteen shopping events, a price of a thousand, a production
/// cost of five hundred, an ad spending of a thousand, an unchanged price, a
/// demand that answers the price with an elasticity of 1.25 and the unchanged
/// number of the page visitors.
pub struct SalesConfig {
  /// The number of the special shopping events of the range.
  num_shopping_events : Int32
  /// The price of the product before the change of the price.
  original_product_price : Double
  /// The cost of producing one unit of the product.
  product_production_cost : Double
  /// The spending on the ad campaigns of a day.
  based_ad_spending : Double
  /// The factor by which the price changes.
  change_of_price : Double
  /// The factor by which the demand answers a change of the price.
  change_of_demand : Double
  /// The factor by which the number of the page visitors changes.
  page_visitor_factor : Double
  /// The year of the first day of the range.
  start_year : Int32
  /// The month of the first day of the range.
  start_month : Int32
  /// The day of the month of the first day of the range.
  start_day : Int32
}

///|
/// A configuration of the sales data set, built from the parameters of the
/// upstream.
pub fn SalesConfig::new(
  num_shopping_events~ : Int32 = 15,
  original_product_price~ : Double = 1000.0,
  product_production_cost~ : Double = 500.0,
  based_ad_spending~ : Double = 1000.0,
  change_of_price~ : Double = 1.0,
  change_of_demand~ : Double = 1.25,
  page_visitor_factor~ : Double = 1.0,
  start_year~ : Int32 = 2021,
  start_month~ : Int32 = 1,
  start_day~ : Int32 = 1,
) -> SalesConfig {
  {
    num_shopping_events,
    original_product_price,
    product_production_cost,
    based_ad_spending,
    change_of_price,
    change_of_demand,
    page_visitor_factor,
    start_year,
    start_month,
    start_day,
  }
}

///|
/// The configuration of the first fixture of the upstream test: ten shopping
/// events and the default parameters otherwise.
pub fn SalesConfig::ten_events() -> SalesConfig {
  {
    num_shopping_events: 10,
    original_product_price: 1000.0,
    product_production_cost: 500.0,
    based_ad_spending: 1000.0,
    change_of_price: 1.0,
    change_of_demand: 1.25,
    page_visitor_factor: 1.0,
    start_year: 2021,
    start_month: 1,
    start_day: 1,
  }
}

///|
/// The configuration of the second fixture of the upstream test: ten shopping
/// events, a price that is a tenth lower and a fifteenth fewer page visitors.
pub fn SalesConfig::discounted() -> SalesConfig {
  {
    num_shopping_events: 10,
    original_product_price: 1000.0,
    product_production_cost: 500.0,
    based_ad_spending: 1000.0,
    change_of_price: 0.9,
    change_of_demand: 1.25,
    page_visitor_factor: 0.85,
    start_year: 2021,
    start_month: 1,
    start_day: 1,
  }
}

///|
/// The sales data set, with the parameters of the upstream.
pub fn sales_data(seed : Int32, days : Int32) -> @api.DataFrame {
  sales_dataset(seed, days, SalesConfig::new())
}

///|
/// The port of `dowhy.datasets.sales_dataset`.
///
/// The generator draws the days of the shopping events, the ad spending, the
/// page views, the price, the sold units and the operational cost in the same
/// order as the Python fixture, so that the data has the same shape and the
/// same statistical properties.  The columns of the frame are `Date`,
/// `Shopping Event?`, `Ad Spend`, `Page Views`, `Unit Price`, `Sold Units`,
/// `Revenue`, `Operational Cost` and `Profit`, in the order of the columns of
/// the Python data frame.
pub fn sales_dataset(
  seed : Int32,
  days : Int32,
  config : SalesConfig,
) -> @api.DataFrame {
  let rng = Rng::new(seed)
  let rows = if days < 0 { 0 } else { days }
  let base_price = config.original_product_price * config.change_of_price
  let factor = config.page_visitor_factor

  // ---- the shopping events ------------------------------------------------
  let is_event = sample_event_days(rng, rows, config.num_shopping_events)

  // ---- the ad spending ----------------------------------------------------
  // The upstream draws the two uniforms of the whole column before it uses
  // them, so the port does the same.
  let event_ad_spend : Array[Double] = []
  let other_ad_spend : Array[Double] = []
  for _ in 0..<rows {
    event_ad_spend.push(rng.uniform(1000.0, 2000.0))
  }
  for _ in 0..<rows {
    other_ad_spend.push(rng.uniform(100.0, 500.0))
  }
  let ad_spend : Array[Double] = []
  for i in 0..<rows {
    let extra = if is_event[i] { event_ad_spend[i] } else { other_ad_spend[i] }
    ad_spend.push(config.based_ad_spending + extra)
  }

  // ---- the page views -----------------------------------------------------
  // The page views are the sum of a Poisson draw, of a uniform draw of the
  // days of a shopping event, of a half normal draw that the ad spending
  // scales and of a half normal draw of its own.
  let visit_poisson : Array[Double] = []
  let visit_event : Array[Double] = []
  let visit_ad : Array[Double] = []
  let visit_half : Array[Double] = []
  for _ in 0..<rows {
    visit_poisson.push(poisson_draw(rng, 10000.0 * factor).to_double())
  }
  for _ in 0..<rows {
    visit_event.push(rng.uniform(5000.0 * factor, 5000.0 * factor + 5000.0))
  }
  for _ in 0..<rows {
    visit_ad.push(half_normal(rng, 0.5 * factor, 0.01))
  }
  for _ in 0..<rows {
    visit_half.push(half_normal(rng, 1000.0 * factor, 100.0))
  }
  let page_views : Array[Double] = []
  for i in 0..<rows {
    let mut value = visit_poisson[i]
    if is_event[i] {
      value = value + visit_event[i]
    }
    value = value + visit_ad[i] * ad_spend[i]
    value = value + visit_half[i]
    // The upstream truncates the column towards zero.
    page_views.push(value.to_int().to_double())
  }

  // ---- the price ----------------------------------------------------------
  // The price is the base price, a uniform discount of the days of a shopping
  // event and a small discount of two percent of the days.
  let event_discount : Array[Double] = []
  let has_small_discount : Array[Bool] = []
  let small_discount : Array[Double] = []
  for _ in 0..<rows {
    event_discount.push(rng.uniform(-200.0, 0.0))
  }
  for _ in 0..<rows {
    has_small_discount.push(rng.bernoulli(0.02))
  }
  for _ in 0..<rows {
    small_discount.push(rng.uniform(-20.0, 0.0))
  }
  let price : Array[Double] = []
  for i in 0..<rows {
    let mut value = base_price
    if is_event[i] {
      value = value + event_discount[i]
    }
    if has_small_discount[i] {
      value = value + small_discount[i]
    }
    price.push(value)
  }

  // ---- the demand ---------------------------------------------------------
  // The change of the price is measured against the original price and not
  // against the base price, so a day whose price is the original one has no
  // change of the price at all.  The upstream replaces such a change by one,
  // which makes the ratio of the demand and of the change the elasticity of
  // the demand on those days.
  let price_changes : Array[Double] = []
  let demand_changes : Array[Double] = []
  for i in 0..<rows {
    let mut change = 1.0 - price[i] / config.original_product_price
    let mut demand = change * config.change_of_demand * (1.0 + change)
    if change == 0.0 {
      demand = 1.0
      change = 1.0
    }
    price_changes.push(change)
    demand_changes.push(demand)
  }

  // ---- the sold units -----------------------------------------------------
  // The upstream draws the uniform of the day and the Poisson draw of the day
  // one after the other, so the port does the same.
  let sold_units : Array[Double] = []
  for i in 0..<rows {
    let extra = rng.uniform(100.0, 1100.0)
    let event_bonus = if is_event[i] { extra } else { 0.0 }
    let mu = demand_changes[i] / price_changes[i] * 0.2 * page_views[i] +
      event_bonus
    sold_units.push(poisson_draw(rng, mu).to_double())
  }

  // ---- the revenue, the operational cost and the profit --------------------
  let revenue : Array[Double] = []
  for i in 0..<rows {
    revenue.push(price[i] * sold_units[i])
  }
  let cost_noise : Array[Double] = []
  for _ in 0..<rows {
    cost_noise.push(half_normal(rng, 500000.0, 10.0))
  }
  let operational_cost : Array[Double] = []
  let profit : Array[Double] = []
  for i in 0..<rows {
    let cost = ad_spend[i] +
      config.product_production_cost * sold_units[i] +
      cost_noise[i]
    operational_cost.push(cost)
    profit.push(revenue[i] - cost)
  }

  // ---- the dates and the frame ---------------------------------------------
  let first_day = days_from_civil(
    config.start_year,
    config.start_month,
    config.start_day,
  )
  let dates : Array[String] = []
  let event_flags : Array[String] = []
  for i in 0..<rows {
    let (year, month, day) = civil_from_days(first_day + i)
    dates.push(format_date(year, month, day))
    event_flags.push(if is_event[i] { "true" } else { "false" })
  }
  let columns : Array[(String, @api.Column)] = [
    ("Date", @api.Column::discrete(dates)),
    ("Shopping Event?", @api.Column::discrete(event_flags)),
    ("Ad Spend", @api.Column::numeric(ad_spend)),
    ("Page Views", @api.Column::numeric(page_views)),
    ("Unit Price", @api.Column::numeric(price)),
    ("Sold Units", @api.Column::numeric(sold_units)),
    ("Revenue", @api.Column::numeric(revenue)),
    ("Operational Cost", @api.Column::numeric(operational_cost)),
    ("Profit", @api.Column::numeric(profit)),
  ]
  frame_from_columns(columns)
}

// ---------------------------------------------------------------------------
// The draws of the sales data set
// ---------------------------------------------------------------------------

///|
/// The days of the range that hold a shopping event.
///
/// The upstream draws the days of the shopping events without replacement, so
/// every day of the range holds at most one event.
fn sample_event_days(rng : Rng, days : Int32, count : Int32) -> Array[Bool] {
  let is_event : Array[Bool] = []
  for _ in 0..<days {
    is_event.push(false)
  }
  let take = if count < 0 { 0 } else if count > days { days } else { count }
  // A partial shuffle of the days of the range.
  let order : Array[Int32] = []
  for i in 0..<days {
    order.push(i)
  }
  let mut k = 0
  while k < take {
    let j = k + (rng.uniform01() * (days - k).to_double()).to_int()
    let tmp = order[k]
    order[k] = order[j]
    order[j] = tmp
    is_event[order[k]] = true
    k = k + 1
  }
  is_event
}

///|
/// A draw from the half normal distribution, like
/// `scipy.stats.halfnorm.rvs(loc, scale)`: the location plus the scale times
/// the absolute value of a standard normal deviate.
fn half_normal(rng : Rng, loc : Double, scale : Double) -> Double {
  loc + scale * rng.normal().abs()
}

///|
/// A Poisson draw with the given mean.
///
/// The port inverts the cumulative distribution of the Poisson, which is
/// exact: the probability of a value is the mass of the distribution.  The
/// inversion starts ten standard deviations below the mean, where the
/// probability of the distribution is below 1e-23 and where the mass of the
/// distribution is still representable; the small means are drawn with the
/// method of Knuth, which is exact as well.
fn poisson_draw(rng : Rng, mu : Double) -> Int32 {
  if mu <= 0.0 {
    return 0
  }
  if mu < 30.0 {
    // The method of Knuth.
    let limit = @math.exp(-mu)
    let mut product = 1.0
    let mut k = 0
    while product > limit {
      product = product * rng.uniform01()
      k = k + 1
    }
    return k - 1
  }
  // The inversion of the cumulative distribution.
  let deviation = mu.sqrt()
  let log_mu = @math.ln(mu)
  let mut k = (mu - 10.0 * deviation).floor().to_int()
  if k < 0 {
    k = 0
  }
  // The mass of the first value of the inversion.
  let mut mass = @math.exp(
    k.to_double() * log_mu - mu - @utils.ln_gamma(k.to_double() + 1.0),
  )
  let mut cumulative = mass
  let target = rng.uniform01()
  let limit = k + (20.0 * deviation).to_int() + 20
  while target > cumulative && k < limit {
    k = k + 1
    mass = mass * mu / k.to_double()
    cumulative = cumulative + mass
  }
  k
}

// ---------------------------------------------------------------------------
// The calendar
// ---------------------------------------------------------------------------

///|
/// The number of the days between the epoch of the calendar and the given
/// date.
///
/// This is the algorithm of Howard Hinnant, which counts the days of the
/// proleptic Gregorian calendar.
fn days_from_civil(year : Int32, month : Int32, day : Int32) -> Int32 {
  let y = year - (if month <= 2 { 1 } else { 0 })
  let era = (if y >= 0 { y } else { y - 399 }) / 400
  let yoe = y - era * 400
  let shifted = month + (if month > 2 { -3 } else { 9 })
  let doy = (153 * shifted + 2) / 5 + day - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  era * 146097 + doe - 719468
}

///|
/// The date of the given number of the days after the epoch.
fn civil_from_days(days : Int32) -> (Int32, Int32, Int32) {
  let z = days + 719468
  let era = (if z >= 0 { z } else { z - 146096 }) / 146097
  let doe = z - era * 146097
  let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
  let y = yoe + era * 400
  let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
  let mp = (5 * doy + 2) / 153
  let d = doy - (153 * mp + 2) / 5 + 1
  let m = mp + (if mp < 10 { 3 } else { -9 })
  let year = y + (if m <= 2 { 1 } else { 0 })
  (year, m, d)
}

///|
/// A date as a string of the form `YYYY-MM-DD`.
fn format_date(year : Int32, month : Int32, day : Int32) -> String {
  year.to_string() + "-" + pad_two(month) + "-" + pad_two(day)
}

///|
/// A number of two digits.
fn pad_two(value : Int32) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}
