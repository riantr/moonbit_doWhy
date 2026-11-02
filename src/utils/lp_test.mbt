///|
/// The cases of the linear program solver.
///
/// The expected values come from `scipy.optimize.linprog` with the HiGHS
/// solver, the way `_verify/lp_reference.py` computes them. The programs of
/// the first two cases have more than one optimum, so the tests assert the
/// value of the objective and the feasibility of the dual, and not the vertex
/// the solver happens to pick.
test "solve_lp::a_program_with_three_constraints" {
  let c = [-1.0, -1.0]
  let a_ub = @utils.Matrix::from_rows([[1.0, 1.0], [1.0, 0.0], [0.0, 1.0]])
  let solution = @utils.solve_lp(c, a_ub, [4.0, 3.0, 3.0])
  assert_true((solution.objective + 4.0).abs() < 1.0e-9)
  assert_true((solution.x[0] + solution.x[1] - 4.0).abs() < 1.0e-9)
  assert_true(solution.x[0] <= 3.0 + 1.0e-9)
  assert_true(solution.x[1] <= 3.0 + 1.0e-9)
  // The shadow prices of a minimisation are not positive.
  for dual in solution.duals {
    assert_true(dual <= 1.0e-9)
  }
}

///|
/// A program whose optimum is not unique.
test "solve_lp::a_degenerate_program" {
  let c = [-1.0, -1.0]
  let a_ub = @utils.Matrix::from_rows([
    [1.0, 1.0],
    [1.0, 0.0],
    [0.0, 1.0],
    [1.0, 2.0],
  ])
  let solution = @utils.solve_lp(c, a_ub, [1.0, 0.5, 0.5, 1.0])
  assert_true((solution.objective + 0.75).abs() < 1.0e-9)
  assert_true((solution.x[0] - 0.5).abs() < 1.0e-9)
  assert_true((solution.x[1] - 0.25).abs() < 1.0e-9)
  for dual in solution.duals {
    assert_true(dual <= 1.0e-9)
  }
}

///|
/// A program with a right hand side of zero.
test "solve_lp::a_program_with_a_zero_right_hand_side" {
  let c = [-1.0, 1.0]
  let a_ub = @utils.Matrix::from_rows([[1.0, -2.0], [1.0, 0.0]])
  let solution = @utils.solve_lp(c, a_ub, [0.0, 0.0])
  assert_true(solution.objective.abs() < 1.0e-9)
  for dual in solution.duals {
    assert_true(dual <= 1.0e-9)
  }
}

///|
/// The dual of the master program of the ruleset estimator, for the three
/// groups of the data of the upstream test.
///
/// The program is `max sum_g Y_g - Z B` under the constraints
/// `sum_g A_gj Y_g <= c_j` for every column `j` and `Y_g <= n_g Z` for every
/// group `g`. The shadow prices of the constraints of the columns are the
/// weights of the master program, with the sign of a minimisation.
test "solve_lp::the_dual_of_the_master_program" {
  let groups = @utils.Matrix::from_rows([
    [1.0, 0.0, 1.0, 0.0, 1.0],
    [1.0, 0.0, 1.0, 1.0, 0.0],
    [1.0, 1.0, 0.0, 0.0, 1.0],
  ])
  let sizes = [100.0, 50.0, 50.0]
  let budget = 4.0
  // The costs of the columns: the share of the background the column covers
  // and the regularisation of its literals.
  let costs = [1.0, 0.511, 0.511, 0.511, 0.511]
  let num_groups = 3
  let num_columns = 5
  let c : Array[Double] = []
  for g = 0; g < num_groups; g = g + 1 {
    c.push(-1.0)
  }
  c.push(budget)
  let rows : Array[Array[Double]] = []
  for j = 0; j < num_columns; j = j + 1 {
    let row : Array[Double] = []
    for g = 0; g < num_groups; g = g + 1 {
      row.push(groups.get(g, j))
    }
    row.push(0.0)
    rows.push(row)
  }
  for g = 0; g < num_groups; g = g + 1 {
    let row : Array[Double] = []
    for h = 0; h < num_groups; h = h + 1 {
      row.push(if h == g { 1.0 } else { 0.0 })
    }
    row.push(-sizes[g])
    rows.push(row)
  }
  let b_ub : Array[Double] = []
  for j = 0; j < num_columns; j = j + 1 {
    b_ub.push(costs[j])
  }
  for g = 0; g < num_groups; g = g + 1 {
    b_ub.push(0.0)
  }
  let solution = @utils.solve_lp(c, @utils.Matrix::from_rows(rows), b_ub)
  assert_true((solution.x[0] - 0.022).abs() < 1.0e-9)
  assert_true((solution.x[1] - 0.489).abs() < 1.0e-9)
  assert_true((solution.x[2] - 0.489).abs() < 1.0e-9)
  assert_true((solution.x[3] - 0.00978).abs() < 1.0e-9)
  assert_true((solution.objective + 0.96088).abs() < 1.0e-9)
  // The weights of the master program are the shadow prices of the
  // constraints of the columns, with the sign of a minimisation.
  let weights = [
    -solution.duals[0],
    -solution.duals[1],
    -solution.duals[2],
    -solution.duals[3],
    -solution.duals[4],
  ]
  assert_true((weights[0] - 0.92).abs() < 1.0e-9)
  assert_true(weights[1].abs() < 1.0e-9)
  assert_true(weights[2].abs() < 1.0e-9)
  assert_true(weights[3].abs() < 1.0e-9)
  assert_true((weights[4] - 0.08).abs() < 1.0e-9)
}
