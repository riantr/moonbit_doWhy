///|
/// The solution of a linear program.
pub struct LpSolution {
  /// The values of the variables.
  x : Array[Double]
  /// The value of the objective.
  objective : Double
  /// The shadow prices of the constraints.
  ///
  /// They are the derivatives of the objective with respect to the right hand
  /// sides of the constraints, so they are not positive for a minimisation.
  duals : Array[Double]
}

///|
/// The tolerance of the comparisons of the simplex.
const LP_TOLERANCE : Double = 0.000000001

///|
/// The number of the pivots after which the simplex switches to the rule of Bland.
///
/// The rule of Bland picks the smallest index of every candidate, so it never
/// cycles, but it needs more pivots than the rule of Dantzig.
const LP_BLAND_AFTER : Int32 = 400

///|
/// Solve the linear program that minimises `c^T x` under the constraints
/// `a_ub x <= b_ub` and `x >= 0`.
///
/// The program is solved with the simplex method of the tableau. The initial
/// basis is the slack basis, so the program has to be feasible for it, which
/// means that every right hand side has to be not negative.
///
/// The shadow prices of the constraints are the derivatives of the objective
/// with respect to the right hand sides of the constraints, the way
/// `scipy.optimize.linprog` reports them: they are not positive for a
/// minimisation.
pub fn solve_lp(
  c : Array[Double],
  a_ub : Matrix,
  b_ub : Array[Double],
) -> LpSolution {
  let m = a_ub.nrows()
  let n = a_ub.ncols()
  let width = n + m + 1
  // The rows of the tableau hold the constraints and the last row holds the
  // objective.
  let tab : Array[Array[Double]] = []
  for i = 0; i < m; i = i + 1 {
    let row : Array[Double] = []
    for j = 0; j < n; j = j + 1 {
      row.push(a_ub.get(i, j))
    }
    for j = 0; j < m; j = j + 1 {
      row.push(if j == i { 1.0 } else { 0.0 })
    }
    row.push(b_ub[i])
    tab.push(row)
  }
  let objective_row : Array[Double] = []
  for j = 0; j < n; j = j + 1 {
    objective_row.push(-c[j])
  }
  for j = 0; j < m; j = j + 1 {
    objective_row.push(0.0)
  }
  objective_row.push(0.0)
  tab.push(objective_row)
  // The column of the variable that is basic in every row.
  let basis : Array[Int32] = []
  for i = 0; i < m; i = i + 1 {
    basis.push(n + i)
  }
  let mut bland = false
  let mut pivots = 0
  while true {
    let row = tab[m]
    let mut entering = -1
    let mut best = LP_TOLERANCE
    // The slack variables are candidates as well, because their reduced costs
    // are the shadow prices of the constraints and they are not positive at
    // every feasible basis.
    for j = 0; j < n + m; j = j + 1 {
      if bland {
        if row[j] > LP_TOLERANCE {
          entering = j
          break
        }
      } else if row[j] > best {
        best = row[j]
        entering = j
      }
    }
    if entering < 0 {
      break
    }
    // The leaving row is the one with the smallest ratio of the right hand
    // side over the coefficient of the entering variable.
    let mut leaving = -1
    let mut best_ratio = 0.0
    for i = 0; i < m; i = i + 1 {
      if tab[i][entering] > LP_TOLERANCE {
        let ratio = tab[i][width - 1] / tab[i][entering]
        if leaving < 0 || ratio < best_ratio - LP_TOLERANCE {
          best_ratio = ratio
          leaving = i
        }
      }
    }
    if leaving < 0 {
      // The program is unbounded, which the callers of the solver do not
      // expect, so the search stops here.
      break
    }
    let pivot = tab[leaving][entering]
    for j = 0; j < width; j = j + 1 {
      tab[leaving][j] = tab[leaving][j] / pivot
    }
    for i = 0; i <= m; i = i + 1 {
      if i == leaving {
        continue
      }
      let factor = tab[i][entering]
      if factor == 0.0 {
        continue
      }
      for j = 0; j < width; j = j + 1 {
        tab[i][j] = tab[i][j] - factor * tab[leaving][j]
      }
    }
    basis[leaving] = entering
    pivots = pivots + 1
    if pivots > LP_BLAND_AFTER {
      bland = true
    }
  }
  // The values of the variables and the shadow prices.
  let x : Array[Double] = []
  for j = 0; j < n; j = j + 1 {
    x.push(0.0)
  }
  for i = 0; i < m; i = i + 1 {
    let column = basis[i]
    if column < n {
      x[column] = tab[i][width - 1]
    }
  }
  let duals : Array[Double] = []
  for j = 0; j < m; j = j + 1 {
    duals.push(tab[m][n + j])
  }
  { x, objective: tab[m][width - 1], duals, }
}
