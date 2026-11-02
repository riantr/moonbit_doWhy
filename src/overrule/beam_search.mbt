///|
/// An instance of the pricing problem of the beam search.
///
/// An instance holds the rows that are still in the game, the literals that
/// may still be added to the conjunction and the value of the conjunction so
/// far.
priv struct PricingInstance {
  rp : Array[Double]
  rn : Array[Double]
  rp_rows : Array[Int32]
  rn_rows : Array[Int32]
  cols : Array[Int32]
  v0 : Double
  z0 : Array[Bool]
}

///|
/// A candidate of the beam search: a literal and the value of the conjunction
/// that it would produce.
priv struct Candidate {
  position : Int32
  value : Double
}

///|
/// The result of the beam search.
pub struct BeamSearchResult {
  /// The values of the conjunctions.
  values : Array[Double]
  /// The conjunctions: one indicator over the literals per conjunction.
  z : Array[Array[Bool]]
}

///|
/// The value of every singleton of the instance.
///
/// The value of a conjunction is the sum of the residuals of the rows it
/// covers and the regularisation of its literals, so the value of a singleton
/// is the value of the conjunction minus the residuals of the rows it drops.
fn PricingInstance::eval_singletons(
  self : PricingInstance,
  data : BinarizedData,
  lambda1 : Double,
) -> (Array[Double], Array[Double], Array[Double]) {
  let ncols = self.cols.length()
  let rp_values : Array[Double] = []
  let rn_values : Array[Double] = []
  let v1 : Array[Double] = []
  for j = 0; j < ncols; j = j + 1 {
    let column = data.columns[self.cols[j]]
    let mut sum_p = 0.0
    for t = 0; t < self.rp_rows.length(); t = t + 1 {
      sum_p = sum_p + self.rp[t] * (1.0 - column[self.rp_rows[t]])
    }
    let mut sum_n = 0.0
    for t = 0; t < self.rn_rows.length(); t = t + 1 {
      sum_n = sum_n + self.rn[t] * (1.0 - column[self.rn_rows[t]])
    }
    rp_values.push(sum_p)
    rn_values.push(sum_n)
    v1.push(self.v0 - sum_p - sum_n + lambda1)
  }
  (v1, rp_values, rn_values)
}

///|
/// The lower bounds of the conjunctions of a higher degree.
///
/// The bound of a conjunction of a higher degree is the value of the instance
/// minus the sum of the largest residuals it cannot cover any more, so it is
/// the same for every literal that is added to the instance.
fn PricingInstance::compute_LB(
  self : PricingInstance,
  v1 : Array[Double],
  rp_values : Array[Double],
  rn_values : Array[Double],
  lambda1 : Double,
) -> Array[Double] {
  let ncols = self.cols.length()
  let mut rp0 = 0.0
  for value in self.rp {
    rp0 = rp0 + value
  }
  // The cumulative sums of the residuals, from the largest to the smallest.
  let sorted_rp = rp_values.copy()
  sorted_rp.sort_by(fn(a, b) { @utils.compare_double(b, a) })
  let mut cumulative = 0.0
  let lb : Array[Double] = []
  for j = 0; j < sorted_rp.length(); j = j + 1 {
    cumulative = cumulative + sorted_rp[j]
    if j > 0 {
      lb.push(if cumulative < rp0 { cumulative } else { rp0 })
    }
  }
  // The residuals of the other sign, from the second largest to the smallest.
  let sorted_rn = rn_values.copy()
  sorted_rn.sort_by(fn(a, b) { @utils.compare_double(b, a) })
  for j = 1; j < sorted_rn.length(); j = j + 1 {
    lb[j - 1] = lb[j - 1] + sorted_rn[j]
  }
  for j = 0; j < lb.length(); j = j + 1 {
    lb[j] = lb[j] - lambda1 * (j + 2).to_double()
    lb[j] = self.v0 - lb[j]
  }
  // The bound of every singleton, which is never below the bound of the
  // higher degrees.
  let lb1 : Array[Double] = []
  let mut smallest = 0.0
  if lb.length() > 0 {
    smallest = lb[0]
    for value in lb {
      if value < smallest {
        smallest = value
      }
    }
  }
  for j = 0; j < ncols; j = j + 1 {
    let value = v1[j] + rp_values[j] - rp0 + lambda1
    lb1.push(if value < smallest { smallest } else { value })
  }
  lb1
}

///|
/// The candidates of an instance: the literals whose value is below the bound,
/// from the smallest value to the largest one.
fn candidates_of(
  v1 : Array[Double],
  threshold : Double,
  limit : Int32,
) -> Array[Candidate] {
  let indices : Array[Int32] = []
  for j = 0; j < v1.length(); j = j + 1 {
    if v1[j] < threshold {
      indices.push(j)
    }
  }
  indices.sort_by(fn(a, b) {
    let by_value = @utils.compare_double(v1[a], v1[b])
    if by_value != 0 {
      by_value
    } else {
      @utils.compare_double(a.to_double(), b.to_double())
    }
  })
  let out : Array[Candidate] = []
  for j = 0; j < indices.length(); j = j + 1 {
    if j >= limit {
      break
    }
    out.push({ position: indices[j], value: v1[indices[j]], })
  }
  out
}

///|
/// The indices of the smallest values, at most the given number of them.
fn smallest_indices(values : Array[Double], limit : Int32) -> Array[Int32] {
  let indices : Array[Int32] = []
  for j = 0; j < values.length(); j = j + 1 {
    indices.push(j)
  }
  indices.sort_by(fn(a, b) {
    let by_value = @utils.compare_double(values[a], values[b])
    if by_value != 0 {
      by_value
    } else {
      @utils.compare_double(a.to_double(), b.to_double())
    }
  })
  let out : Array[Int32] = []
  for j = 0; j < indices.length(); j = j + 1 {
    if j >= limit {
      break
    }
    out.push(indices[j])
  }
  out
}

///|
/// The key of a conjunction: the literals it holds for.
fn conjunction_key(indicator : Array[Bool]) -> String {
  let mut out : String = ""
  for held in indicator {
    out = out + (if held { "1" } else { "0" })
  }
  out
}

///|
/// Remove the duplicated conjunctions.
///
/// The conjunctions are ordered by their content, the way the upstream orders
/// them, and the first occurrence of every content is kept.
fn unique_conjunctions(
  values : Array[Double],
  z : Array[Array[Bool]],
) -> (Array[Double], Array[Array[Bool]]) {
  let keys : Array[String] = []
  let first : Array[Int32] = []
  for j = 0; j < z.length(); j = j + 1 {
    let key = conjunction_key(z[j])
    let mut seen = false
    for k = 0; k < keys.length(); k = k + 1 {
      if keys[k] == key {
        seen = true
        break
      }
    }
    if !seen {
      keys.push(key)
      first.push(j)
    }
  }
  let order : Array[Int32] = []
  for j = 0; j < keys.length(); j = j + 1 {
    order.push(j)
  }
  order.sort_by(fn(a, b) {
    let by_key = compare_string(keys[a], keys[b])
    if by_key != 0 {
      by_key
    } else {
      @utils.compare_double(first[a].to_double(), first[b].to_double())
    }
  })
  let out_values : Array[Double] = []
  let out_z : Array[Array[Bool]] = []
  for k = 0; k < order.length(); k = k + 1 {
    let index = first[order[k]]
    out_values.push(values[index])
    out_z.push(z[index])
  }
  (out_values, out_z)
}

///|
/// Compare two strings by their characters.
fn compare_string(a : String, b : String) -> Int32 {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i = 0; i < n; i = i + 1 {
    let cx = a.get(i)
    let cy = b.get(i)
    if cx < cy {
      return -1
    }
    if cx > cy {
      return 1
    }
  }
  if a.length() < b.length() {
    -1
  } else if a.length() > b.length() {
    1
  } else {
    0
  }
}

///|
/// The literals that may still be added to a conjunction that holds for the
/// given literal.
///
/// A literal of a threshold removes the literals of the same feature that it
/// implies, and every other literal removes all the literals of its feature.
fn remaining_literals(
  data : BinarizedData,
  cols : Array[Int32],
  literal : Int32,
) -> Array[Int32] {
  let feature = data.feature_of[literal]
  let operation = data.literals[literal].operation
  let value = data.literals[literal].value
  let out : Array[Int32] = []
  for column in cols {
    if data.feature_of[column] != feature {
      out.push(column)
      continue
    }
    let other = data.literals[column].operation.name()
    match operation.name() {
      "<=" =>
        if other == ">" && data.literals[column].value < value {
          out.push(column)
        }
      ">" =>
        if other == "<=" && data.literals[column].value > value {
          out.push(column)
        }
      _ => ()
    }
  }
  out
}

///|
/// The positions of the rows of an instance that the given literal holds for.
fn rows_holding(
  data : BinarizedData,
  rows : Array[Int32],
  literal : Int32,
) -> Array[Int32] {
  let column = data.columns[literal]
  let out : Array[Int32] = []
  for t = 0; t < rows.length(); t = t + 1 {
    if column[rows[t]] == 1.0 {
      out.push(t)
    }
  }
  out
}

///|
/// The rows of an instance at the given positions.
fn select_rows(rows : Array[Int32], positions : Array[Int32]) -> Array[Int32] {
  let out : Array[Int32] = []
  for position in positions {
    out.push(rows[position])
  }
  out
}

///|
/// Take the values of the given positions.
fn take_values(
  values : Array[Double],
  positions : Array[Int32],
) -> Array[Double] {
  let out : Array[Double] = []
  for position in positions {
    out.push(values[position])
  }
  out
}

///|
/// Search the conjunctions with a negative reduced cost, the port of the beam
/// search of the upstream.
///
/// The search starts from the empty conjunction and adds one literal at a
/// time, keeping the best candidates of every degree. The value of a
/// conjunction is the sum of the residuals of the rows it covers and the
/// regularisation of its literals, so the candidates are the literals that
/// make the value the smallest.
pub fn beam_search(
  r : Array[Double],
  data : BinarizedData,
  lambda0 : Double,
  lambda1 : Double,
  k : Int32,
  ub : Double,
  eps : Double,
  b : Int32,
  d : Int32,
  w_lb : Double,
) -> BeamSearchResult {
  let n_literals = data.literals.length()
  let mut values : Array[Double] = []
  let mut z : Array[Array[Bool]] = []
  // The rows with a positive and a negative residual.
  let rp_rows : Array[Int32] = []
  let rp : Array[Double] = []
  let rn_rows : Array[Int32] = []
  let rn : Array[Double] = []
  let mut total = 0.0
  for i = 0; i < r.length(); i = i + 1 {
    total = total + r[i]
    if r[i] > 0.0 {
      rp_rows.push(i)
      rp.push(r[i])
    } else if r[i] < 0.0 {
      rn_rows.push(i)
      rn.push(r[i])
    }
  }
  let all_cols : Array[Int32] = []
  let empty : Array[Bool] = []
  for i = 0; i < n_literals; i = i + 1 {
    all_cols.push(i)
    empty.push(false)
  }
  let mut instances : Array[PricingInstance] = [
    {
      rp,
      rn,
      rp_rows,
      rn_rows,
      cols: all_cols,
      v0: total + lambda0,
      z0: empty,
    },
  ]
  let mut bound = ub
  let mut degree = 0
  while instances.length() > 0 && degree < d {
    degree = degree + 1
    let mut next_values : Array[Double] = []
    let mut next_bound = 1.0e308
    let next_z : Array[Array[Bool]] = []
    let mut next_instances : Array[PricingInstance] = []
    for instance in instances {
      let (v1, rp_values, rn_values) = instance.eval_singletons(data, lambda1)
      let candidates = candidates_of(v1, bound - eps, k + b)
      if candidates.length() > 0 {
        for candidate in candidates {
          let indicator : Array[Bool] = []
          for i = 0; i < n_literals; i = i + 1 {
            indicator.push(instance.z0[i])
          }
          indicator[instance.cols[candidate.position]] = true
          values.push(candidate.value)
          z.push(indicator)
        }
        let (unique_values, unique_z) = unique_conjunctions(values, z)
        values = unique_values
        z = unique_z
        let best = smallest_indices(values, k)
        let kept_values : Array[Double] = []
        let kept_z : Array[Array[Bool]] = []
        for index in best {
          kept_values.push(values[index])
          kept_z.push(z[index])
        }
        values = kept_values
        z = kept_z
        bound = values[values.length() - 1]
      }
      let lb1 = instance.compute_LB(v1, rp_values, rn_values, lambda1)
      // The children of the instance.
      let child_positions : Array[Int32] = []
      let child_values : Array[Double] = []
      for j = 0; j < v1.length(); j = j + 1 {
        let value = (1.0 - w_lb) * v1[j] + w_lb * lb1[j]
        if lb1[j] < bound - eps && value < next_bound - eps {
          child_positions.push(j)
          child_values.push(value)
        }
      }
      let child_order = smallest_indices(child_values, 2 * b)
      let mut added = 0
      for j = 0; j < child_order.length(); j = j + 1 {
        let slot = child_order[j]
        let position = child_positions[slot]
        let literal = instance.cols[position]
        let indicator : Array[Bool] = []
        for i = 0; i < n_literals; i = i + 1 {
          indicator.push(instance.z0[i])
        }
        indicator[literal] = true
        // The conjunction may not be twice among the children.
        let mut duplicate = false
        for other in next_z {
          if conjunction_key(other) == conjunction_key(indicator) {
            duplicate = true
            break
          }
        }
        if duplicate {
          continue
        }
        next_values.push(child_values[slot])
        next_z.push(indicator)
        let kept_positions = rows_holding(data, instance.rp_rows, literal)
        let kept_negative_positions = rows_holding(
          data,
          instance.rn_rows,
          literal,
        )
        let kept_rows = select_rows(instance.rp_rows, kept_positions)
        let kept_negative_rows = select_rows(
          instance.rn_rows,
          kept_negative_positions,
        )
        let kept_cols = remaining_literals(data, instance.cols, literal)
        next_instances.push({
          rp: take_values(instance.rp, kept_positions),
          rn: take_values(instance.rn, kept_negative_positions),
          rp_rows: kept_rows,
          rn_rows: kept_negative_rows,
          cols: kept_cols,
          v0: v1[position],
          z0: indicator,
        })
        added = added + 1
        if added == b {
          break
        }
      }
      let best = smallest_indices(next_values, b)
      let kept_values : Array[Double] = []
      let kept_instances : Array[PricingInstance] = []
      for index in best {
        kept_values.push(next_values[index])
        kept_instances.push(next_instances[index])
      }
      next_values = kept_values
      next_instances = kept_instances
      if next_values.length() > 0 {
        next_bound = next_values[next_values.length() - 1]
      }
    }
    instances = next_instances
  }
  { values, z, }
}
