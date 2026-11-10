///|
/// The readers of the temporal graphs of the upstream.
///
/// This is the port of `create_graph_from_csv` and of
/// `create_graph_from_dot_format` of `dowhy.utils.timeseries`. The upstream
/// reads the CSV and the DOT from a file, and this library has no file system,
/// so the port takes the text of the file.

///|
/// The graph of a CSV text.
///
/// The CSV holds the columns `node1`, `node2` and `time_lag`, and every row is
/// an edge from `node1` to `node2` with the time lag `time_lag`. Two rows that
/// share the same pair of nodes are merged into one edge whose time lags are
/// the lags of the rows, in the order of the rows.
///
/// The result is absent when a time lag is not a number, which is the answer
/// of the upstream when the `time_lag` of a row cannot be read as an integer.
///
/// The reader understands the plain form of a CSV: the fields are separated by
/// commas and no field is quoted. The upstream reads the file with
/// `pandas.read_csv`, which understands the quoted fields as well.
pub fn create_graph_from_csv_text(csv : String) -> TemporalGraph? {
  let lines = text_lines(csv)
  let mut index = 0
  let mut header : Array[String] = []
  while index < lines.length() {
    if !is_blank(lines[index]) {
      header = split_by(lines[index], ',')
      index = index + 1
      break
    }
    index = index + 1
  }
  if header.length() == 0 {
    abort("the CSV of a temporal graph holds no header")
  }
  let source_column = csv_column(header, "node1")
  let target_column = csv_column(header, "node2")
  let lag_column = csv_column(header, "time_lag")
  let graph = TemporalGraph::new()
  while index < lines.length() {
    let line = lines[index]
    index = index + 1
    if is_blank(line) {
      continue
    }
    let fields = split_by(line, ',')
    let source = match csv_field(fields, source_column) {
      Some(value) => value
      None => return None
    }
    let target = match csv_field(fields, target_column) {
      Some(value) => value
      None => return None
    }
    let lag = match csv_field(fields, lag_column) {
      Some(text) =>
        match parse_time_lag(text) {
          Some(value) => value
          None => return None
        }
      None => return None
    }
    graph.add_edge(source, target, lag)
  }
  Some(graph)
}

///|
/// The graph of a DOT text.
///
/// This is the port of `create_graph_from_dot_format` of
/// `dowhy.utils.timeseries`. The upstream reads the DOT from a file, and this
/// library has no file system, so the port takes the text of the file.
///
/// Every edge of the DOT carries its time lags in its `label` attribute, the
/// lags written between parentheses and separated by commas, the way the
/// upstream writes them: `(5)` or `(5,3)`. An edge without a label is left
/// out of the graph, the way the upstream leaves it out.
///
/// Two entries of the same edge are merged into one edge whose time lags are
/// the lags of the entries without their duplicates. The upstream merges them
/// with a set, whose order is the order of the set of the interpreter, and the
/// port keeps the order of the first occurrence of every lag.
///
/// The result is absent when a label does not hold numbers, which is the
/// answer of the upstream when the label of an edge cannot be read as a list
/// of integers.
pub fn create_graph_from_dot_text(dot : String) -> TemporalGraph? {
  let graph = TemporalGraph::new()
  for edge in @graph.parse_dot_edges(dot) {
    let label = match edge.label {
      Some(value) => value
      None => continue
    }
    let lags = match dot_label_lags(label) {
      Some(values) => values
      None => return None
    }
    if graph.has_edge(edge.source, edge.target) {
      let merged = graph.time_lags_of(edge.source, edge.target)
      for lag in lags {
        if !merged.contains(lag) {
          merged.push(lag)
        }
      }
      graph.set_time_lags(edge.source, edge.target, merged)
    } else {
      graph.add_edge_with_lags(edge.source, edge.target, lags)
    }
  }
  Some(graph)
}

///|
/// The index of the column with the given name.
///
/// The upstream reads the columns of the CSV by their name, and a CSV without
/// one of them is an error of the upstream. The port aborts with a message of
/// the same kind, because MoonBit cannot catch an error.
fn csv_column(header : Array[String], name : String) -> Int32 {
  for i = 0; i < header.length(); i = i + 1 {
    if header[i].trim() == name {
      return i
    }
  }
  abort("the CSV of a temporal graph holds no column " + name)
}

///|
/// The field of the given index, when the row holds it.
fn csv_field(fields : Array[String], index : Int32) -> String? {
  if index < 0 || index >= fields.length() {
    return None
  }
  Some(fields[index])
}

///|
/// Whether a line of a CSV holds nothing.
fn is_blank(line : String) -> Bool {
  let chars = line.to_array()
  for character in chars {
    if !character.is_whitespace() {
      return false
    }
  }
  true
}

///|
/// The lines of a text, without their line endings.
fn text_lines(text : String) -> Array[String] {
  let lines : Array[String] = []
  let chars = text.to_array()
  let mut current : Array[Char] = []
  let mut i = 0
  while i < chars.length() {
    let character = chars[i]
    if character == '\n' {
      lines.push(String::from_array(current))
      current = []
      i = i + 1
      continue
    }
    current.push(character)
    i = i + 1
  }
  if current.length() > 0 {
    lines.push(String::from_array(current))
  }
  let out : Array[String] = []
  for line in lines {
    out.push(strip_carriage_return(line))
  }
  out
}

///|
/// The text without the carriage return at its end.
fn strip_carriage_return(line : String) -> String {
  let chars = line.to_array()
  if chars.length() == 0 || chars[chars.length() - 1] != '\r' {
    return line
  }
  let out : Array[Char] = []
  for i = 0; i < chars.length() - 1; i = i + 1 {
    out.push(chars[i])
  }
  String::from_array(out)
}

///|
/// The parts of a text, split at every separator.
fn split_by(text : String, separator : Char) -> Array[String] {
  let parts : Array[String] = []
  let chars = text.to_array()
  let mut current : Array[Char] = []
  let mut i = 0
  while i < chars.length() {
    let character = chars[i]
    if character == separator {
      parts.push(String::from_array(current))
      current = []
      i = i + 1
      continue
    }
    current.push(character)
    i = i + 1
  }
  parts.push(String::from_array(current))
  parts
}

///|
/// The number a time lag holds, when it holds a number.
///
/// The rules are the ones of the `int` of the upstream: the text may hold
/// white space around the number, the number may be negative, and a number
/// that is written with a fraction or with an exponent is truncated toward
/// zero, the way `int` truncates a float.
fn parse_time_lag(text : String) -> Int32? {
  let chars = trimmed_chars(text)
  if chars.length() == 0 {
    return None
  }
  let mut i = 0
  let mut negative = false
  if chars[0] == '+' || chars[0] == '-' {
    negative = chars[0] == '-'
    i = 1
  }
  let mut digits = ""
  let mut fraction = 0
  let mut seen = false
  while i < chars.length() && chars[i].is_ascii_digit() {
    seen = true
    digits = digits + chars[i].to_string()
    i = i + 1
  }
  if !seen {
    return None
  }
  if i < chars.length() && chars[i] == '.' {
    i = i + 1
    while i < chars.length() && chars[i].is_ascii_digit() {
      seen = true
      digits = digits + chars[i].to_string()
      fraction = fraction + 1
      i = i + 1
    }
  }
  let mut exponent = 0
  if i < chars.length() && (chars[i] == 'e' || chars[i] == 'E') {
    i = i + 1
    let mut exponent_negative = false
    if i < chars.length() && (chars[i] == '+' || chars[i] == '-') {
      exponent_negative = chars[i] == '-'
      i = i + 1
    }
    let mut exponent_digits = ""
    while i < chars.length() && chars[i].is_ascii_digit() {
      exponent_digits = exponent_digits + chars[i].to_string()
      i = i + 1
    }
    if exponent_digits.length() == 0 {
      return None
    }
    exponent = parse_digits(exponent_digits)
    if exponent_negative {
      exponent = 0 - exponent
    }
  }
  if i != chars.length() {
    return None
  }
  if fraction == 0 && exponent == 0 {
    let value = parse_digits(digits)
    return Some(if negative { 0 - value } else { value })
  }
  let mut mantissa = 0.0
  for character in digits.to_array() {
    mantissa = mantissa * 10.0 + (character.to_int() - 48).to_double()
  }
  let mut value = mantissa * @math.pow(10.0, (exponent - fraction).to_double())
  if negative {
    value = 0.0 - value
  }
  Some(value.trunc().to_int())
}

///|
/// The number a text of digits holds.
fn parse_digits(digits : String) -> Int32 {
  let mut value = 0
  for character in digits.to_array() {
    value = value * 10 + (character.to_int() - 48)
  }
  value
}

///|
/// The characters of a text without the white space around them.
fn trimmed_chars(text : String) -> Array[Char] {
  let chars = text.to_array()
  let mut start = 0
  let mut end = chars.length()
  while start < end && chars[start].is_whitespace() {
    start = start + 1
  }
  while end > start && chars[end - 1].is_whitespace() {
    end = end - 1
  }
  let out : Array[Char] = []
  for i = start; i < end; i = i + 1 {
    out.push(chars[i])
  }
  out
}

///|
/// The time lags of the label of an edge, when the label holds numbers.
///
/// The upstream reads the label of an edge with
/// `tuple(map(int, label.strip("()").split(",")))`, so the label holds the
/// lags between parentheses, separated by commas.
fn dot_label_lags(label : String) -> Array[Int32]? {
  let lags : Array[Int32] = []
  for part in split_by(strip_parentheses(label), ',') {
    match parse_time_lag(part) {
      Some(value) => lags.push(value)
      None => return None
    }
  }
  Some(lags)
}

///|
/// The text without the parentheses around it.
///
/// The upstream strips the parentheses with `strip("()")`, which takes every
/// parenthesis at both ends of the text.
fn strip_parentheses(text : String) -> String {
  let chars = text.to_array()
  let mut start = 0
  let mut end = chars.length()
  while start < end && (chars[start] == '(' || chars[start] == ')') {
    start = start + 1
  }
  while end > start && (chars[end - 1] == '(' || chars[end - 1] == ')') {
    end = end - 1
  }
  let out : Array[Char] = []
  for i = start; i < end; i = i + 1 {
    out.push(chars[i])
  }
  String::from_array(out)
}
