///|
/// A group of the rows of the master program.
///
/// The rows of the program that cover the same covariates are the same row of
/// the program, so they are collapsed into one group with a weight.
priv struct RowGroup {
  rows : Array[Int32]
  coverage : Array[Double]
}

///|
/// The estimator of a boolean rule set, the port of the `OverlapBooleanRule`
/// of the upstream.
///
/// The rules are learned with a column generation: a program is solved, the
/// conjunctions that are worth adding are searched for with a beam search, and
/// the program is solved again with the new conjunctions. The coefficients of
/// the program are rounded into rules at the end.
pub struct BooleanRule {
  alpha : Double
  lambda0 : Double
  lambda1 : Double
  k : Int32
  d : Int32
  b : Int32
  iter_max : Int32
  eps : Double
  rounding : RoundingStrategy
  mut w : Array[Double]
  mut w_raw : Array[Double]
  mut z : Array[Array[Bool]]
  mut lp_objective : Double
}

///|
/// The tolerance of the coefficients of the program.
///
/// The solver of the upstream reports the coefficients that are not used with
/// the noise of its own arithmetic, so the coefficients below the tolerance
/// are read as zero.
const RULE_COEFFICIENT_TOLERANCE : Double = 0.000000001

///|
/// The estimator of a boolean rule set.
pub fn BooleanRule::new(
  alpha : Double,
  lambda0 : Double,
  lambda1 : Double,
  k : Int32,
  d : Int32,
  b : Int32,
  iter_max : Int32,
  eps : Double,
  rounding : RoundingStrategy,
) -> BooleanRule {
  {
    alpha,
    lambda0,
    lambda1,
    k,
    d,
    b,
    iter_max,
    eps,
    rounding,
    w: [],
    w_raw: [],
    z: [],
    lp_objective: 0.0,
  }
}

///|
/// The coverage of every row by a conjunction.
fn conjunction_coverage(
  data : BinarizedData,
  indicator : Array[Bool],
) -> Array[Double] {
  let out : Array[Double] = []
  for row = 0; row < data.n_rows; row = row + 1 {
    let mut holds = true
    for literal = 0; literal < indicator.length(); literal = literal + 1 {
      if indicator[literal] && data.columns[literal][row] == 0.0 {
        holds = false
        break
      }
    }
    out.push(if holds { 1.0 } else { 0.0 })
  }
  out
}

///|
/// The number of the literals of a conjunction.
fn literal_count(indicator : Array[Bool]) -> Double {
  let mut count = 0
  for held in indicator {
    if held {
      count = count + 1
    }
  }
  count.to_double()
}

///|
/// Collapse the rows of the program that cover the same covariates.
fn group_rows(
  rows : Array[Int32],
  coverage : Array[Array[Double]],
  num_columns : Int32,
) -> Array[RowGroup] {
  let groups : Array[RowGroup] = []
  let keys : Array[String] = []
  for row in rows {
    let mut key : String = ""
    for j = 0; j < num_columns; j = j + 1 {
      key = key + (if coverage[j][row] == 1.0 { "1" } else { "0" })
    }
    let mut found = -1
    for g = 0; g < keys.length(); g = g + 1 {
      if keys[g] == key {
        found = g
        break
      }
    }
    if found < 0 {
      keys.push(key)
      groups.push({
        rows: [row],
        coverage: coverage_column(coverage, num_columns, row),
      })
    } else {
      groups[found].rows.push(row)
    }
  }
  groups
}

///|
/// The coverage of one row by every conjunction.
fn coverage_column(
  coverage : Array[Array[Double]],
  num_columns : Int32,
  row : Int32,
) -> Array[Double] {
  let out : Array[Double] = []
  for j = 0; j < num_columns; j = j + 1 {
    out.push(coverage[j][row])
  }
  out
}

///|
/// The solution of the program of the rules.
priv struct RuleProgram {
  /// The weights of the conjunctions.
  weights : Array[Double]
  /// The shadow price of every group of the positive rows.
  groups : Array[Double]
  /// The value of the program.
  objective : Double
}

///|
/// Solve the program of the rules.
///
/// The program minimises the share of the rows that must not be covered plus
/// the regularisation of the conjunctions, under the constraint that the rules
/// cover at least the share `alpha` of the positive rows. It is solved
/// through its dual, because the dual has a feasible basis.
fn BooleanRule::solve_program(
  self : BooleanRule,
  coverage : Array[Array[Double]],
  positive : Array[Int32],
  negative : Array[Int32],
  background : Array[Int32],
  lambdas : Array[Double],
) -> RuleProgram {
  let num_columns = coverage.length()
  let groups = group_rows(positive, coverage, num_columns)
  let num_groups = groups.length()
  // The rows the rules have to avoid: the background if there is one, the
  // negative rows otherwise.
  let avoided = if background.length() > 0 { background } else { negative }
  let num_avoided = avoided.length()
  let costs : Array[Double] = []
  for j = 0; j < num_columns; j = j + 1 {
    let mut sum = 0.0
    for row in avoided {
      sum = sum + coverage[j][row]
    }
    costs.push(sum / num_avoided.to_double() + lambdas[j])
  }
  // The dual of the program.
  let rows : Array[Array[Double]] = []
  let b_ub : Array[Double] = []
  for j = 0; j < num_columns; j = j + 1 {
    let row : Array[Double] = []
    for g = 0; g < num_groups; g = g + 1 {
      row.push(groups[g].coverage[j])
    }
    row.push(0.0)
    rows.push(row)
    b_ub.push(costs[j])
  }
  for g = 0; g < num_groups; g = g + 1 {
    let row : Array[Double] = []
    for h = 0; h < num_groups; h = h + 1 {
      row.push(if h == g { 1.0 } else { 0.0 })
    }
    row.push(-groups[g].rows.length().to_double())
    rows.push(row)
    b_ub.push(0.0)
  }
  let objective_coefficients : Array[Double] = []
  for g = 0; g < num_groups; g = g + 1 {
    objective_coefficients.push(-1.0)
  }
  objective_coefficients.push(
    (1.0 - self.alpha) * positive.length().to_double(),
  )
  let solution = @utils.solve_lp(
    objective_coefficients,
    @utils.Matrix::from_rows(rows),
    b_ub,
  )
  // The weights of the conjunctions are the shadow prices of the constraints
  // of the columns, with the sign of a minimisation.
  let weights : Array[Double] = []
  for j = 0; j < num_columns; j = j + 1 {
    let weight = -solution.duals[j]
    weights.push(
      if weight.abs() < RULE_COEFFICIENT_TOLERANCE {
        0.0
      } else {
        weight
      },
    )
  }
  let group_duals : Array[Double] = []
  for g = 0; g < num_groups; g = g + 1 {
    group_duals.push(solution.x[g])
  }
  { weights, groups: group_duals, objective: -solution.objective, }
}

///|
/// Learn the rules of the given rows.
///
/// The labels of the rows are one for the rows that have to be covered, zero
/// for the rows that have to be avoided and minus one for the background, the
/// way the upstream labels them.
pub fn BooleanRule::fit(
  self : BooleanRule,
  data : BinarizedData,
  y : Array[Double],
) -> Unit {
  let positive : Array[Int32] = []
  let negative : Array[Int32] = []
  let background : Array[Int32] = []
  for i = 0; i < y.length(); i = i + 1 {
    if y[i] > 0.0 {
      positive.push(i)
    } else if y[i] == 0.0 {
      negative.push(i)
    } else {
      background.push(i)
    }
  }
  // The conjunctions of the program: the empty one and the singletons.
  let z : Array[Array[Bool]] = []
  let empty : Array[Bool] = []
  for i = 0; i < data.literals.length(); i = i + 1 {
    empty.push(false)
  }
  z.push(empty)
  let lambdas : Array[Double] = []
  lambdas.push(0.0)
  for literal = 0; literal < data.literals.length(); literal = literal + 1 {
    let indicator : Array[Bool] = []
    for i = 0; i < data.literals.length(); i = i + 1 {
      indicator.push(i == literal)
    }
    z.push(indicator)
    lambdas.push(self.lambda0 + self.lambda1)
  }
  let coverage : Array[Array[Double]] = []
  let ones : Array[Double] = []
  for i = 0; i < data.n_rows; i = i + 1 {
    ones.push(1.0)
  }
  coverage.push(ones)
  for literal = 0; literal < data.literals.length(); literal = literal + 1 {
    coverage.push(data.columns[literal].copy())
  }
  let mut iteration = 0
  let mut program = self.solve_program(
    coverage, positive, negative, background, lambdas,
  )
  while true {
    // The residuals of the rows: the shadow prices of the positive rows and
    // the share of the rows that have to be avoided.
    let r = residuals_of(
      data, program, positive, negative, background, coverage,
    )
    // The bound of the conjunctions that are worth searching for.
    let mut smallest = 0.0
    for j = 0; j < coverage.length(); j = j + 1 {
      let mut sum = 0.0
      for i = 0; i < r.length(); i = i + 1 {
        sum = sum + r[i] * coverage[j][i]
      }
      let value = sum + lambdas[j]
      if j == 0 || value < smallest {
        smallest = value
      }
    }
    let ub = if smallest < 0.0 { smallest } else { 0.0 }
    let result = beam_search(
      r,
      data,
      self.lambda0,
      self.lambda1,
      self.k,
      ub,
      self.eps,
      self.b,
      self.d,
      0.5,
    )
    // The search stops when no conjunction is worth adding any more.
    let mut worth = false
    for value in result.values {
      if value < -self.eps {
        worth = true
        break
      }
    }
    if !worth || iteration >= self.iter_max {
      break
    }
    iteration = iteration + 1
    for j = 0; j < result.z.length(); j = j + 1 {
      z.push(result.z[j])
      lambdas.push(self.lambda0 + self.lambda1 * literal_count(result.z[j]))
      coverage.push(conjunction_coverage(data, result.z[j]))
    }
    program = self.solve_program(
      coverage, positive, negative, background, lambdas,
    )
  }
  self.z = z
  self.w_raw = program.weights
  self.lp_objective = program.objective
  self.w = self.round_rules(coverage, y, positive, negative, background)
}

///|
/// The residuals of the rows.
fn residuals_of(
  data : BinarizedData,
  program : RuleProgram,
  positive : Array[Int32],
  negative : Array[Int32],
  background : Array[Int32],
  coverage : Array[Array[Double]],
) -> Array[Double] {
  let r : Array[Double] = []
  for i = 0; i < data.n_rows; i = i + 1 {
    r.push(0.0)
  }
  // The shadow price of every group of the positive rows is shared by the
  // rows of the group.
  let groups = group_rows(positive, coverage, coverage.length())
  for g = 0; g < groups.length(); g = g + 1 {
    let dual = program.groups[g] / groups[g].rows.length().to_double()
    for row in groups[g].rows {
      r[row] = -dual
    }
  }
  let avoided = if background.length() > 0 { background } else { negative }
  let share = 1.0 / avoided.length().to_double()
  for row in avoided {
    r[row] = share
  }
  r
}

///|
/// Round the coefficients of the program into rules.
fn BooleanRule::round_rules(
  self : BooleanRule,
  coverage : Array[Array[Double]],
  y : Array[Double],
  positive : Array[Int32],
  negative : Array[Int32],
  background : Array[Int32],
) -> Array[Double] {
  let weights : Array[Double] = []
  for j = 0; j < coverage.length(); j = j + 1 {
    weights.push(0.0)
  }
  let greedy = match self.rounding {
    RoundingStrategy::Greedy => true
    RoundingStrategy::GreedySweep => false
  }
  if greedy {
    let used = self.greedy_round(
      coverage, y, positive, negative, background, 0.5,
    )
    for column in used {
      weights[column] = 1.0
    }
    return weights
  }
  // The sweep over the reward of the positive samples.
  let mut best_xi = 0.01
  let mut best_auc = 0.0
  for step = 0; step < 20; step = step + 1 {
    let exponent = -2.0 + (0.5 + 2.0) * step.to_double() / 19.0
    let xi = pow10(exponent)
    let used = self.greedy_round(
      coverage, y, positive, negative, background, xi,
    )
    let scores = scores_of(coverage, used)
    let auc = roc_auc(y, scores)
    // The tolerance breaks the ties in favour of the larger reward.
    if auc > best_auc - 0.001 {
      best_xi = xi
    }
    if auc > best_auc {
      best_auc = auc
    }
  }
  let used = self.greedy_round(
    coverage, y, positive, negative, background, best_xi,
  )
  for column in used {
    weights[column] = 1.0
  }
  weights
}

///|
/// The power of ten of an exponent.
fn pow10(exponent : Double) -> Double {
  @math.pow(10.0, exponent)
}

///|
/// The rules that cover the positive rows, chosen greedily.
///
/// The conjunctions that the program uses are the candidates. The one with the
/// smallest cost is taken, and the search stops when the rules cover the
/// share `alpha` of the positive rows.
fn BooleanRule::greedy_round(
  self : BooleanRule,
  coverage : Array[Array[Double]],
  y : Array[Double],
  positive : Array[Int32],
  negative : Array[Int32],
  background : Array[Int32],
  xi : Double,
) -> Array[Int32] {
  let mut candidates : Array[Int32] = []
  for j = 0; j < coverage.length(); j = j + 1 {
    if self.w_raw[j] > 0.0 {
      candidates.push(j)
    }
  }
  let covered : Array[Bool] = []
  for i = 0; i < y.length(); i = i + 1 {
    covered.push(false)
  }
  let used : Array[Int32] = []
  let mut iterations = 0
  while iterations < 1000 {
    let mut covered_positive = 0
    for row in positive {
      if covered[row] {
        covered_positive = covered_positive + 1
      }
    }
    if covered_positive.to_double() / positive.length().to_double() >=
      self.alpha {
      break
    }
    let mut best = -1
    let mut best_cost = 0.0
    for c = 0; c < candidates.length(); c = c + 1 {
      let column = candidates[c]
      let cost = cost_of(
        coverage,
        column,
        covered,
        positive,
        negative,
        background,
        xi,
        self.lambda1,
        self.z,
      )
      if best < 0 || cost < best_cost {
        best = c
        best_cost = cost
      }
    }
    if best < 0 {
      break
    }
    let column = candidates[best]
    for i = 0; i < covered.length(); i = i + 1 {
      if coverage[column][i] == 1.0 {
        covered[i] = true
      }
    }
    used.push(column)
    let rest : Array[Int32] = []
    for c = 0; c < candidates.length(); c = c + 1 {
      if c != best {
        rest.push(candidates[c])
      }
    }
    candidates = rest
    iterations = iterations + 1
  }
  used
}

///|
/// The cost of a conjunction: the share of the rows it must not cover and the
/// regularisation, less the reward of the positive rows it covers.
fn cost_of(
  coverage : Array[Array[Double]],
  column : Int32,
  covered : Array[Bool],
  positive : Array[Int32],
  negative : Array[Int32],
  background : Array[Int32],
  xi : Double,
  lambda1 : Double,
  z : Array[Array[Bool]],
) -> Double {
  let mut negative_cover = 0.0
  if negative.length() > 0 {
    let mut sum = 0.0
    for row in negative {
      sum = sum + coverage[column][row]
    }
    negative_cover = sum / negative.length().to_double()
  }
  let mut background_cover = 0.0
  if background.length() > 0 {
    let mut sum = 0.0
    for row in background {
      sum = sum + coverage[column][row]
    }
    background_cover = sum / background.length().to_double()
  }
  let mut newly_covered = 0
  for row in positive {
    if !covered[row] {
      newly_covered = newly_covered + 1
    }
  }
  let mut positive_cover = 0.0
  if newly_covered > 0 {
    let mut sum = 0.0
    for row in positive {
      if !covered[row] {
        sum = sum + coverage[column][row] + 0.00000001
      }
    }
    positive_cover = sum / newly_covered.to_double()
  }
  let literals = literals_of(z, column)
  negative_cover + background_cover + lambda1 * literals - xi * positive_cover
}

///|
/// The number of the literals of a conjunction of the program.
fn literals_of(z : Array[Array[Bool]], column : Int32) -> Double {
  if column < z.length() {
    literal_count(z[column])
  } else {
    0.0
  }
}

///|
/// The score of every row: one when a rule covers the row.
fn scores_of(
  coverage : Array[Array[Double]],
  used : Array[Int32],
) -> Array[Double] {
  let scores : Array[Double] = []
  for i = 0; i < coverage[0].length(); i = i + 1 {
    let mut score = 0.0
    for column in used {
      if coverage[column][i] == 1.0 {
        score = 1.0
      }
    }
    scores.push(score)
  }
  scores
}

///|
/// The area under the curve of the scores of the positive rows against the
/// scores of the other rows.
fn roc_auc(y : Array[Double], scores : Array[Double]) -> Double {
  let mut positives = 0
  let mut negatives = 0
  for i = 0; i < y.length(); i = i + 1 {
    if y[i] == 1.0 {
      positives = positives + 1
    } else {
      negatives = negatives + 1
    }
  }
  if positives == 0 || negatives == 0 {
    return 0.0
  }
  let mut sum = 0.0
  for i = 0; i < y.length(); i = i + 1 {
    if y[i] != 1.0 {
      continue
    }
    for j = 0; j < y.length(); j = j + 1 {
      if y[j] == 1.0 {
        continue
      }
      if scores[i] > scores[j] {
        sum = sum + 1.0
      } else if scores[i] == scores[j] {
        sum = sum + 0.5
      }
    }
  }
  sum / (positives * negatives).to_double()
}

///|
/// The rules of the estimator.
pub fn BooleanRule::rules(
  self : BooleanRule,
  literals : Array[Literal],
) -> RuleSet {
  let out : RuleSet = []
  for j = 0; j < self.w.length(); j = j + 1 {
    if self.w[j] == 0.0 {
      continue
    }
    let rule : Rule = []
    if j < self.z.length() {
      for literal = 0; literal < self.z[j].length(); literal = literal + 1 {
        if self.z[j][literal] {
          let description = literals[literal]
          let value = match description.operation {
            LiteralOperation::Binary => ""
            LiteralOperation::Negation => ""
            _ => description.value.to_string()
          }
          rule.push({
            feature: description.feature,
            operation: description.operation.name(),
            value,
          })
        }
      }
    }
    out.push(rule)
  }
  out
}

///|
/// Whether a rule covers the given row.
pub fn BooleanRule::covers(
  self : BooleanRule,
  coverage : Array[Double],
) -> Bool {
  for j = 0; j < self.w.length(); j = j + 1 {
    if self.w[j] != 0.0 && coverage[j] == 1.0 {
      return true
    }
  }
  false
}

///|
/// Whether the rules cover every row of the given covariates.
pub fn BooleanRule::predict(
  self : BooleanRule,
  data : BinarizedData,
) -> Array[Bool] {
  let out : Array[Bool] = []
  for row = 0; row < data.n_rows; row = row + 1 {
    let mut covered = false
    for j = 0; j < self.w.length() && !covered; j = j + 1 {
      if self.w[j] == 0.0 || j >= self.z.length() {
        continue
      }
      let mut holds = true
      for literal = 0; literal < self.z[j].length(); literal = literal + 1 {
        if self.z[j][literal] && data.columns[literal][row] == 0.0 {
          holds = false
          break
        }
      }
      if holds {
        covered = true
      }
    }
    out.push(covered)
  }
  out
}

///|
/// The value of the program of the rules.
pub fn BooleanRule::lp_value(self : BooleanRule) -> Double {
  self.lp_objective
}
