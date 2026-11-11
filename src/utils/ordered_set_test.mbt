///|
/// The cases of the ordered set of the upstream.
///
/// The upstream has no test file for `dowhy.utils.ordered_set`, so the cases
/// of the port are its own. Every one of them asserts a number that the
/// reference script `_verify/utilities_reference.py` prints for the upstream.

///|
test "the ordered set keeps the order of its names" {
  let set = @utils.OrderedSet::of(["b", "a", "b", "c"])
  assert_eq(set.length(), 3)
  let names = set.get_all()
  assert_eq(names.length(), 3)
  assert_eq(names[0], "b")
  assert_eq(names[1], "a")
  assert_eq(names[2], "c")
  assert_true(set.contains("a"))
  assert_false(set.contains("z"))
  assert_false(set.is_empty())
  assert_true(@utils.OrderedSet::new().is_empty())
}

///|
test "the ordered set holds the name with the given index" {
  let set = @utils.OrderedSet::of(["b", "a", "c"])
  assert_eq(set.at(1), "a")
  // The upstream raises an error when the index is out of range; the port
  // returns the empty string.
  assert_eq(set.at(9), "")
}

///|
test "the union of an ordered set keeps the order of the two of them" {
  let set = @utils.OrderedSet::of(["b", "a", "c"])
  let union = set.union(["d", "a"])
  let names = union.get_all()
  assert_eq(names.length(), 4)
  assert_eq(names[0], "b")
  assert_eq(names[1], "a")
  assert_eq(names[2], "c")
  assert_eq(names[3], "d")
}

///|
test "the intersection and the difference of an ordered set" {
  let set = @utils.OrderedSet::of(["b", "a", "c"])
  let intersection = set.intersection(["a", "c", "z"])
  let names = intersection.get_all()
  assert_eq(names.length(), 2)
  assert_eq(names[0], "a")
  assert_eq(names[1], "c")
  let difference = set.difference(["a", "c"])
  let kept = difference.get_all()
  assert_eq(kept.length(), 1)
  assert_eq(kept[0], "b")
}

///|
test "the text of an ordered set is the text of the upstream" {
  let set = @utils.OrderedSet::of(["b", "a", "c"])
  assert_eq(set.to_text(), "OrderedSet(b,a,c)")
}
