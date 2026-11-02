/// The reader of the GML graphs of the upstream.
///
/// This is the port of the GML branch of `dowhy.causal_graph.CausalGraph`,
/// which reads a graph with `networkx.parse_gml`. The upstream accepts a GML
/// string, a DOT string, a networkx graph and a probabilistic causal model;
/// the port accepts a GML string and a graph that the caller has built.
///
/// The reader understands the subset of GML the upstream writes and reads: a
/// `graph` block that holds `node` blocks and `edge` blocks. A node is named
/// after its `label` attribute when it has one, and after its `id` attribute
/// otherwise, which is the convention of `networkx.read_gml` with its default
/// `label="label"`. An edge joins the node of its `source` attribute to the
/// node of its `target` attribute.
///
/// The upstream wraps the graph it reads in a `networkx.DiGraph`, so a GML
/// graph that is not directed is directed in the end. The graph of the port is
/// always directed.

///|
/// The graph of a GML string.
///
/// The graph is directed, like the `networkx.DiGraph` the upstream builds.
///
/// The edges of a GML graph name the `id` of their nodes, while the name of a
/// node is its `label`, so the edges are resolved with the labels of the nodes
/// the way `networkx.parse_gml` resolves them.
pub fn parse_gml(text : String) -> DirectedGraph {
  let graph = DirectedGraph::new()
  let tokens = tokenize_gml(text)
  let names : Map[String, String] = Map([])
  let mut position = 0
  while position < tokens.length() {
    let token = tokens[position]
    if token.is_word("node") {
      position = position + 1
      let attributes = read_gml_block(tokens, position)
      position = attributes.next
      let name = match attributes.label {
        Some(label) => label
        None =>
          match attributes.id {
            Some(id) => id
            None => ""
          }
      }
      if name != "" {
        graph.add_node(name)
        match attributes.id {
          Some(id) => names.set(id, name)
          None => ()
        }
      }
      continue
    }
    if token.is_word("edge") {
      position = position + 1
      let attributes = read_gml_block(tokens, position)
      position = attributes.next
      match (attributes.source, attributes.target) {
        (Some(source), Some(target)) =>
          graph.add_edge(
            resolve_gml_name(names, source),
            resolve_gml_name(names, target),
          )
        _ => ()
      }
      continue
    }
    position = position + 1
  }
  graph
}

///|
/// The name of the node with the given id.
///
/// A node whose id is not known keeps the id as its name, which is what a
/// graph whose edges name a node that is not declared holds.
fn resolve_gml_name(names : Map[String, String], id : String) -> String {
  match names.get(id) {
    Some(name) => name
    None => id
  }
}

///|
/// The attributes of a `node` or an `edge` block of a GML string.
priv struct GmlAttributes {
  /// The position of the token after the block.
  mut next : Int32
  /// The `id` attribute.
  mut id : String?
  /// The `label` attribute.
  mut label : String?
  /// The `source` attribute.
  mut source : String?
  /// The `target` attribute.
  mut target : String?
}

///|
/// The attributes of a block, read from the tokens that follow the opening
/// bracket of the block.
fn read_gml_block(tokens : Array[GmlToken], position : Int32) -> GmlAttributes {
  let result = {
    next: position,
    id: None,
    label: None,
    source: None,
    target: None,
  }
  let mut index = position
  let mut depth = 0
  while index < tokens.length() {
    let token = tokens[index]
    if token.is_open() {
      depth = depth + 1
      index = index + 1
      continue
    }
    if token.is_close() {
      depth = depth - 1
      index = index + 1
      if depth <= 0 {
        break
      }
      continue
    }
    if token.is_word("id") && index + 1 < tokens.length() {
      result.id = tokens[index + 1].as_value()
      index = index + 2
      continue
    }
    if token.is_word("label") && index + 1 < tokens.length() {
      result.label = tokens[index + 1].as_value()
      index = index + 2
      continue
    }
    if token.is_word("source") && index + 1 < tokens.length() {
      result.source = tokens[index + 1].as_value()
      index = index + 2
      continue
    }
    if token.is_word("target") && index + 1 < tokens.length() {
      result.target = tokens[index + 1].as_value()
      index = index + 2
      continue
    }
    index = index + 1
  }
  result.next = index
  result
}

///|
/// A token of a GML string.
priv struct GmlToken {
  /// The word of the token, when it is a word.
  word : String
  /// The value of the token, when it is a quoted string or a number.
  value : String
  /// Whether the token is an opening bracket.
  open : Bool
  /// Whether the token is a closing bracket.
  close : Bool
}

///|
/// Whether the token is the given word.
fn GmlToken::is_word(self : GmlToken, word : String) -> Bool {
  self.word == word
}

///|
/// Whether the token is an opening bracket.
fn GmlToken::is_open(self : GmlToken) -> Bool {
  self.open
}

///|
/// Whether the token is a closing bracket.
fn GmlToken::is_close(self : GmlToken) -> Bool {
  self.close
}

///|
/// The value of the token, when it holds one.
fn GmlToken::as_value(self : GmlToken) -> String? {
  if self.value == "" {
    None
  } else {
    Some(self.value)
  }
}

///|
/// The tokens of a GML string.
///
/// A token is a word, a quoted string, a number, an opening bracket or a
/// closing bracket.
fn tokenize_gml(text : String) -> Array[GmlToken] {
  let tokens : Array[GmlToken] = []
  let chars = text.to_array()
  let mut i = 0
  while i < chars.length() {
    let character = chars[i]
    if character.is_whitespace() {
      i = i + 1
    } else if character == '[' {
      tokens.push(gml_token("", "", true, false))
      i = i + 1
    } else if character == ']' {
      tokens.push(gml_token("", "", false, true))
      i = i + 1
    } else if character == '"' {
      let start = i + 1
      let mut end = start
      while end < chars.length() && chars[end] != '"' {
        end = end + 1
      }
      tokens.push(
        gml_token("", gml_chars_to_string(chars, start, end), false, false),
      )
      i = if end < chars.length() { end + 1 } else { end }
    } else if character == '-' || character.is_ascii_digit() {
      let start = i
      i = i + 1
      while i < chars.length() &&
            (
              chars[i].is_ascii_digit() ||
              chars[i] == '.' ||
              chars[i] == 'e' ||
              chars[i] == 'E' ||
              chars[i] == '-' ||
              chars[i] == '+'
            ) {
        i = i + 1
      }
      tokens.push(
        gml_token("", gml_chars_to_string(chars, start, i), false, false),
      )
    } else {
      let start = i
      while i < chars.length() &&
            !chars[i].is_whitespace() &&
            chars[i] != '[' &&
            chars[i] != ']' &&
            chars[i] != '"' {
        i = i + 1
      }
      tokens.push(
        gml_token(gml_chars_to_string(chars, start, i), "", false, false),
      )
    }
  }
  tokens
}

///|
/// A token of a GML string.
fn gml_token(
  word : String,
  value : String,
  open : Bool,
  close : Bool,
) -> GmlToken {
  { word, value, open, close, }
}

///|
/// The text of a range of characters.
fn gml_chars_to_string(
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
