/// The reader of the DOT graphs of the upstream.
///
/// This is the port of the DOT branch of `dowhy.causal_graph.CausalGraph`,
/// which reads a graph with `pygraphviz` and falls back to `pydot`, and of
/// `dowhy.utils.graph_operations.daggity_to_dot`, which turns the graph of the
/// daggity web site into a DOT graph.
///
/// The reader understands the subset of DOT the upstream writes and reads: a
/// `digraph` block that holds statements of the form `a -> b;` and node
/// declarations with the attributes of the daggity graph. The attributes of a
/// node are read, but they do not change the graph: the upstream overwrites
/// the `observed` attribute of every node with the columns of the data anyway.

///|
/// The graph of a DOT string.
///
/// The graph is directed, like the `networkx.DiGraph` the upstream builds.
pub fn parse_dot(text : String) -> DirectedGraph {
  let graph = DirectedGraph::new()
  for statement in dot_statements(text) {
    if statement.is_edge() {
      graph.add_edge(statement.source, statement.target)
      continue
    }
    if statement.source != "" {
      graph.add_node(statement.source)
    }
  }
  graph
}

///|
/// The statements of a DOT string.
///
/// A statement is an edge of the graph or the declaration of a node.
priv struct DotStatement {
  /// The name of the node the statement starts at.
  source : String
  /// The name of the node the statement ends at, when it is an edge.
  target : String
  /// Whether the statement is an edge.
  edge : Bool
}

///|
/// Whether the statement is an edge.
fn DotStatement::is_edge(self : DotStatement) -> Bool {
  self.edge
}

///|
/// The keywords of a DOT string, which are not names of nodes.
fn is_dot_keyword(name : String) -> Bool {
  name == "digraph" ||
  name == "graph" ||
  name == "node" ||
  name == "edge" ||
  name == "strict" ||
  name == "subgraph"
}

///|
/// The statements of a DOT string.
fn dot_statements(text : String) -> Array[DotStatement] {
  let statements : Array[DotStatement] = []
  let chars = text.to_array()
  let mut i = 0
  while i < chars.length() {
    let character = chars[i]
    if character == '"' {
      let (name, next) = dot_read_quoted(chars, i)
      i = dot_handle_name(chars, next, name, statements)
    } else if character == '[' {
      i = dot_skip_block(chars, i)
    } else if is_dot_name_start(character) {
      let (name, next) = dot_read_identifier(chars, i)
      if is_dot_keyword(name) {
        i = next
      } else {
        i = dot_handle_name(chars, next, name, statements)
      }
    } else {
      i = i + 1
    }
  }
  statements
}

///|
/// The statement of a name of a DOT string.
///
/// A name that is followed by an arrow is the source of an edge, and a name
/// that is not is the declaration of a node.
fn dot_handle_name(
  chars : Array[Char],
  position : Int32,
  name : String,
  statements : Array[DotStatement],
) -> Int32 {
  let mut j = position
  while j < chars.length() && chars[j].is_whitespace() {
    j = j + 1
  }
  if j + 1 < chars.length() && chars[j] == '-' && chars[j + 1] == '>' {
    let mut i = j + 2
    while i < chars.length() && chars[i].is_whitespace() {
      i = i + 1
    }
    let target = if i < chars.length() && chars[i] == '"' {
      let (value, next) = dot_read_quoted(chars, i)
      i = next
      value
    } else {
      let (value, next) = dot_read_identifier(chars, i)
      i = next
      value
    }
    statements.push({ source: name, target, edge: true, })
    return i
  }
  statements.push({ source: name, target: "", edge: false, })
  position
}

///|
/// The quoted name at the given position, and the position after it.
fn dot_read_quoted(chars : Array[Char], position : Int32) -> (String, Int32) {
  let start = position + 1
  let mut end = start
  while end < chars.length() && chars[end] != '"' {
    end = end + 1
  }
  let name = dot_chars_to_string(chars, start, end)
  let next = if end < chars.length() { end + 1 } else { end }
  (name, next)
}

///|
/// The bare name at the given position, and the position after it.
fn dot_read_identifier(
  chars : Array[Char],
  position : Int32,
) -> (String, Int32) {
  let start = position
  let mut end = position
  while end < chars.length() && is_dot_name_character(chars[end]) {
    end = end + 1
  }
  (dot_chars_to_string(chars, start, end), end)
}

///|
/// The position after the attribute block at the given position.
fn dot_skip_block(chars : Array[Char], position : Int32) -> Int32 {
  let mut depth = 0
  let mut i = position
  while i < chars.length() {
    if chars[i] == '[' {
      depth = depth + 1
    } else if chars[i] == ']' {
      depth = depth - 1
      i = i + 1
      if depth <= 0 {
        break
      }
      continue
    }
    i = i + 1
  }
  i
}

///|
/// Whether the character starts a name.
fn is_dot_name_start(character : Char) -> Bool {
  character.is_ascii_alphabetic() || character == '_'
}

///|
/// Whether the character is part of a name.
fn is_dot_name_character(character : Char) -> Bool {
  character.is_ascii_digit() ||
  character.is_ascii_lowercase() ||
  character.is_ascii_uppercase() ||
  character == '_'
}

///|
/// The graph of a daggity string, in the DOT format.
///
/// This is the port of `dowhy.utils.graph_operations.daggity_to_dot`, which
/// turns the graph of the daggity web site into a DOT graph: every line
/// becomes a statement, the `dag` keyword becomes `digraph`, the `outcome`,
/// `adjusted` and `exposure` attributes are dropped and the `latent` attribute
/// becomes the `observed` attribute of the node.
pub fn daggity_to_dot(daggity : String) -> String {
  let text = daggity.replace_all(old="\n", new="; ")
  let text = replace_prefix(text, "dag ", "digraph ")
  let text = text.replace_all(old="{;", new="{")
  let text = text.replace_all(old="};", new="}")
  // The upstream drops the attributes with the regular expressions
  // `outcome,*,`, `adjusted,*` and `exposure,*`, which take the commas that
  // follow the keyword with them, and it turns the `latent` attribute into
  // the `observed` attribute with the regular expression `latent,*`. The
  // `outcome` attribute needs at least one comma, the other two do not need
  // any.
  let text = replace_keyword_and_commas(text, "outcome", "", 1)
  let text = replace_keyword_and_commas(text, "adjusted", "", 0)
  let text = replace_keyword_and_commas(text, "exposure", "", 0)
  let text = replace_keyword_and_commas(text, "latent", "observed=\"no\",", 0)
  let text = text.replace_all(old=",]", new="]")
  text
}

///|
/// The text with every occurrence of the given keyword replaced, together with
/// the commas that follow it.
///
/// This is the port of the regular expressions `outcome,*,`, `adjusted,*`,
/// `exposure,*` and `latent,*` of the upstream. The keyword is only replaced
/// when it is followed by at least `minimum_commas` commas.
fn replace_keyword_and_commas(
  text : String,
  keyword : String,
  replacement : String,
  minimum_commas : Int32,
) -> String {
  let chars = text.to_array()
  let key = keyword.to_array()
  let replacement_chars = replacement.to_array()
  let out : Array[Char] = []
  let mut i = 0
  while i < chars.length() {
    if dot_starts_with(chars, i, key) {
      let mut j = i + key.length()
      let mut commas = 0
      while j < chars.length() && chars[j] == ',' {
        j = j + 1
        commas = commas + 1
      }
      if commas >= minimum_commas {
        for character in replacement_chars {
          out.push(character)
        }
        i = j
        continue
      }
    }
    out.push(chars[i])
    i = i + 1
  }
  String::from_array(out)
}

///|
/// Whether the characters hold the given key at the given position.
fn dot_starts_with(
  chars : Array[Char],
  position : Int32,
  key : Array[Char],
) -> Bool {
  if position + key.length() > chars.length() {
    return false
  }
  let mut i = 0
  while i < key.length() {
    if chars[position + i] != key[i] {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// The text with the given prefix replaced.
fn replace_prefix(
  text : String,
  prefix : String,
  replacement : String,
) -> String {
  match text.strip_prefix(prefix) {
    Some(suffix) => replacement + suffix.to_owned()
    None => text
  }
}

///|
/// The text of a range of characters.
fn dot_chars_to_string(
  chars : Array[Char],
  start : Int32,
  end : Int32,
) -> String {
  let out : Array[Char] = []
  for i in start..<end {
    out.push(chars[i])
  }
  String::from_array(out)
}
