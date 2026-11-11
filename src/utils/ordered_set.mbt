/// The ordered set of the upstream.
///
/// This is the port of `dowhy.utils.ordered_set.OrderedSet`: a set of names
/// that keeps the order in which they were added. The upstream uses it for the
/// ancestors of a node and for the components of a graph, where the order of
/// the names is a part of the answer.
///
/// The set of the upstream holds any hashable value; the set of the port holds
/// names, which are the values the upstream uses it with.

///|
/// An ordered set of names.
pub struct OrderedSet {
  elements : Array[String]
  seen : Set[String]
}

///|
/// A new empty set.
pub fn OrderedSet::new() -> OrderedSet {
  { elements: [], seen: Set::Set([]), }
}

///|
/// A set that holds the given names, in the order they are given.
pub fn OrderedSet::of(names : Array[String]) -> OrderedSet {
  let set = OrderedSet::new()
  for name in names {
    set.add(name)
  }
  set
}

///|
/// Add a name to the set, ignoring the names it already holds.
pub fn OrderedSet::add(self : OrderedSet, name : String) -> Unit {
  if !self.seen.contains(name) {
    self.seen.add(name)
    self.elements.push(name)
  }
}

///|
/// Whether the set holds the name.
pub fn OrderedSet::contains(self : OrderedSet, name : String) -> Bool {
  self.seen.contains(name)
}

///|
/// The names of the set, in the order they were added.
///
/// The returned array is a copy, so a caller may modify it without changing
/// the set.
pub fn OrderedSet::get_all(self : OrderedSet) -> Array[String] {
  self.elements.copy()
}

///|
/// The number of the names of the set.
pub fn OrderedSet::length(self : OrderedSet) -> Int32 {
  self.elements.length()
}

///|
/// Whether the set is empty.
pub fn OrderedSet::is_empty(self : OrderedSet) -> Bool {
  self.elements.length() == 0
}

///|
/// The name with the given index.
///
/// The upstream raises an error when the index is out of range; the port
/// returns the empty string.
pub fn OrderedSet::at(self : OrderedSet, index : Int32) -> String {
  if index < 0 || index >= self.elements.length() {
    return ""
  }
  self.elements[index]
}

///|
/// The union of the set and the given names.
///
/// The names of the set come first, in their own order, and the names of the
/// argument follow, the ones the set already holds being left out.
pub fn OrderedSet::union(
  self : OrderedSet,
  names : Array[String],
) -> OrderedSet {
  let result = OrderedSet::of(self.elements.copy())
  for name in names {
    result.add(name)
  }
  result
}

///|
/// The names of the set that are among the given names.
pub fn OrderedSet::intersection(
  self : OrderedSet,
  names : Array[String],
) -> OrderedSet {
  let result = OrderedSet::new()
  for name in self.elements {
    if names.contains(name) {
      result.add(name)
    }
  }
  result
}

///|
/// The names of the set that are not among the given names.
pub fn OrderedSet::difference(
  self : OrderedSet,
  names : Array[String],
) -> OrderedSet {
  let result = OrderedSet::new()
  for name in self.elements {
    if !names.contains(name) {
      result.add(name)
    }
  }
  result
}

///|
/// The text of the set, the way the upstream writes it.
pub fn OrderedSet::to_text(self : OrderedSet) -> String {
  "OrderedSet(" + self.elements.join(",") + ")"
}
