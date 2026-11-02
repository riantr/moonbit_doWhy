"""Replace the brute force nearest neighbour search of the propensity score
matching estimator with a binary search over the sorted propensity scores.

The upstream test suite of the refuters matches a hundred thousand units, and a
scan over every unit of the other group costs `O(n * m)` comparisons, which is
two and a half billion of them for a single estimate.  The sorted search picks
the same unit: a tie is broken with the index of the unit, which is the rule of
the scan.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "src" / "estimators" / "propensity_score.mbt"

OLD = """  // The average treatment effect on the treated.
  let mut att_sum = 0.0
  for row in treated {
    let mut best = control[0]
    let mut best_distance = (ps[row] - ps[best]).abs()
    for candidate in control {
      let distance = (ps[row] - ps[candidate]).abs()
      if distance < best_distance {
        best_distance = distance
        best = candidate
      }
    }
    att_sum = att_sum + outcome[row] - outcome[best]
  }
  let att = att_sum / treated.length().to_double()
  // The average treatment effect on the control.
  let mut atc_sum = 0.0
  for row in control {
    let mut best = treated[0]
    let mut best_distance = (ps[row] - ps[best]).abs()
    for candidate in treated {
      let distance = (ps[row] - ps[candidate]).abs()
      if distance < best_distance {
        best_distance = distance
        best = candidate
      }
    }
    atc_sum = atc_sum + outcome[best] - outcome[row]
  }
"""

NEW = """  // The average treatment effect on the treated.
  //
  // Every treated unit is matched with the control unit whose propensity score
  // is the closest.  The control units are sorted by their score once and
  // every match is a binary search over that order, so a match costs
  // `O(log n)` instead of a scan over every control unit.
  let control_order = sorted_by_score(ps, control)
  let control_groups = equal_score_groups(control_order, ps)
  let mut att_sum = 0.0
  for row in treated {
    let best = nearest_score(control_order, control_groups, ps, ps[row])
    att_sum = att_sum + outcome[row] - outcome[best]
  }
  let att = att_sum / treated.length().to_double()
  // The average treatment effect on the control.
  let treated_order = sorted_by_score(ps, treated)
  let treated_groups = equal_score_groups(treated_order, ps)
  let mut atc_sum = 0.0
  for row in control {
    let best = nearest_score(treated_order, treated_groups, ps, ps[row])
    atc_sum = atc_sum + outcome[best] - outcome[row]
  }
"""

HELPERS = """

///|
/// The units of the given list, sorted by their propensity score.
///
/// The units that hold the same score are ordered by their index, so the first
/// unit of a group of equal scores is the one with the smallest index.
fn sorted_by_score(ps : Array[Double], units : Array[Int32]) -> Array[Int32] {
  let order = units.copy()
  order.sort_by(fn(a, b) {
    let c = @utils.compare_double(ps[a], ps[b])
    if c != 0 {
      c
    } else if a < b {
      -1
    } else if a > b {
      1
    } else {
      0
    }
  })
  order
}

///|
/// The first position of the group of equal scores of every unit.
///
/// The units of a group hold the same propensity score, so they all are at the
/// same distance from a score, and the unit with the smallest index of the
/// group is the one a scan over the units would pick.
fn equal_score_groups(order : Array[Int32], ps : Array[Double]) -> Array[Int32] {
  let m = order.length()
  let groups : Array[Int32] = []
  let mut i = 0
  while i < m {
    let mut j = i
    while j + 1 < m && ps[order[j + 1]] == ps[order[i]] {
      j = j + 1
    }
    for k = i; k <= j; k = k + 1 {
      groups.push(i)
    }
    i = j + 1
  }
  groups
}

///|
/// The unit whose propensity score is the closest to the given score.
///
/// The units of the search are sorted by their score, so the closest one is
/// either the unit below the score or the unit above it.  A tie is broken
/// with the index of the unit, which is the rule of a scan over the units: the
/// first unit with the smallest distance wins.
fn nearest_score(
  order : Array[Int32],
  groups : Array[Int32],
  ps : Array[Double],
  value : Double,
) -> Int32 {
  let m = order.length()
  // The first unit whose score is not smaller than the value.
  let mut lo = 0
  let mut hi = m
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    if ps[order[mid]] < value {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  let pos = lo
  let below = if pos > 0 { order[groups[pos - 1]] } else { -1 }
  let above = if pos < m { order[groups[pos]] } else { -1 }
  if below < 0 {
    return above
  }
  if above < 0 {
    return below
  }
  let below_distance = value - ps[below]
  let above_distance = ps[above] - value
  if below_distance < above_distance {
    below
  } else if above_distance < below_distance {
    above
  } else if below < above {
    below
  } else {
    above
  }
}
"""

ANCHOR = """///|
/// The effect of the propensity score stratification estimator.
"""


def main() -> None:
    text = TARGET.read_text(encoding="utf-8")
    for name in ("sorted_by_score", "equal_score_groups", "nearest_score"):
        if name in text:
            raise SystemExit(f"{name} is already defined in {TARGET}")
    count = text.count(OLD)
    if count != 1:
        raise SystemExit(f"expected one occurrence of the block, found {count}")
    if text.count(ANCHOR) != 1:
        raise SystemExit("the anchor of the helpers is not unique")
    text = text.replace(OLD, NEW)
    text = text.replace(ANCHOR, HELPERS.lstrip("\n") + "\n" + ANCHOR)
    TARGET.write_text(text, encoding="utf-8", newline="")
    print("patched", TARGET)


if __name__ == "__main__":
    main()
