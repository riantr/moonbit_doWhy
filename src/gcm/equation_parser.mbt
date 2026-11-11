///|
/// The equation parser of the `gcm` package.
///
/// This is the port of `dowhy.gcm.equation_parser`. The upstream reads a set of
/// equations like
///
/// ```
/// X = empirical()
/// Z = norm(loc=0, scale=1)
/// Y = 12 * X + log(Z) + norm(loc=0, scale=1)
/// ```
///
/// and builds a causal model out of them. Three forms of an equation are
/// understood:
///
/// 1. the equation of a root node, whose right hand side is the call of a
///    noise model, like `empirical()` or `norm(loc=0, scale=1)`;
/// 2. the equation of a node with parents, whose right hand side is an
///    arithmetic expression of the parents, a `+` and the call of a noise
///    model, like `12 * X + log(Z) + norm(loc=0, scale=1)`;
/// 3. the equation of a node whose relation to its parents is not known, whose
///    right hand side is the list of its parents, like `Z->Y,A`.
///
/// The upstream evaluates the arithmetic expression with the `eval` of Python,
/// over the arrays of the parents, and it lets that expression call every
/// function of numpy and of `scipy.stats`. The port parses the expression and
/// evaluates it over the rows of the design matrix, because a language without
/// `eval` needs a parser, and it knows a fixed set of functions.

///|
/// An expression of the custom function of an equation.
pub enum EquationExpr {
  ///
  /// A constant.
  Number(Double)
  ///
  /// A node of the causal model.
  Variable(String)
  ///
  /// The negation of an expression.
  Neg(EquationExpr)
  ///
  /// The sum of two expressions.
  Add(EquationExpr, EquationExpr)
  ///
  /// The difference of two expressions.
  Sub(EquationExpr, EquationExpr)
  ///
  /// The product of two expressions.
  Mul(EquationExpr, EquationExpr)
  ///
  /// The quotient of two expressions.
  Div(EquationExpr, EquationExpr)
  ///
  /// The call of a function.
  Call(String, Array[EquationExpr])
}

///|
/// The custom function of an equation.
///
/// This is the port of `dowhy.gcm.equation_parser.CustomEquationModel`. The
/// upstream holds the text of the function and the names of its parents, and
/// it evaluates the text over the arrays of the parents; the port holds the
/// parsed expression, because a language without `eval` needs a parser.
///
/// The parents are the columns of the design matrix in the sorted order, which
/// is the order the upstream sorts them in as well.
pub struct EquationModel {
  /// The expression of the function.
  expression : EquationExpr
  /// The names of the parents, in the order of the columns of the design
  /// matrix.
  parents : Array[String]
}

///|
/// A prediction model that evaluates the custom function of an equation.
///
/// This is the port of `dowhy.gcm.equation_parser.CustomEquationModel` as a
/// prediction model. The model is fully defined, so it is never fitted.
pub fn PredictionModel::with_equation(
  expression : EquationExpr,
  parents : Array[String],
) -> PredictionModel {
  {
    coefficients: [],
    intercept: 0.0,
    fitted: true,
    fixed: true,
    equation: Some({ expression, parents: parents.copy(), }),
    degree: 0,
    neighbours: None,
    auto_ml: None,
  }
}

///|
/// The causal model of a set of equations.
///
/// This is the port of
/// `dowhy.gcm.equation_parser.create_causal_model_from_equations`. Every
/// equation of the text is one of the three forms the upstream understands; a
/// node that is only named as a parent and never given an equation of its own
/// becomes a root node with an empirical distribution, like it does upstream.
///
/// The upstream raises an error when a node is given two equations; the port
/// aborts with the same meaning.
pub fn create_causal_model_from_equations(
  node_equations : String,
) -> ProbabilisticCausalModel {
  let graph = @graph.DirectedGraph::new()
  let mechanisms : Map[String, CausalMechanism] = Map([])
  let root_models : Map[String, StochasticModel] = Map([])
  // The nodes that were given an equation, and whether their equation is fully
  // defined. A node whose equation names the parameters of its noise model is
  // fully defined, and the upstream records the parents it was fitted with.
  let defined : Map[String, Bool] = Map([])
  for line in node_equations.split("\n") {
    let equation = line.trim().to_owned()
    sanitize_equation(equation)
    if equation.is_empty() {
      continue
    }
    let (node_name, expression) = equation_components(equation)
    if defined.contains(node_name) {
      abort(
        "the node " + node_name + " is specified twice, which is not allowed",
      )
    }
    graph.add_node(node_name)
    match noise_model_call(expression) {
      Some((name, arguments)) => {
        // The equation of a root node: the right hand side is the call of a
        // noise model and nothing else.
        root_models.set(
          node_name,
          noise_model_of(name, parse_equation_arguments(arguments)),
        )
        defined.set(node_name, !arguments.trim().is_empty())
      }
      None =>
        if is_unknown_equation(equation, expression) {
          // The equation of a node whose relation to its parents is unknown.
          let parents = sorted_parents(split_text(expression, ","))
          for parent in parents {
            graph.add_edge(parent, node_name)
          }
          defined.set(node_name, false)
        } else {
          // The equation of a node with parents: the right hand side is an
          // arithmetic expression, a `+` and the call of a noise model.
          let (custom_function, noise) = split_noise(expression)
          let parents = parents_of_function(custom_function)
          for parent in parents {
            graph.add_edge(parent, node_name)
          }
          let (name, arguments) = match noise_model_call(noise) {
            Some(call) => call
            None =>
              abort("unable to recognise the format or function specified")
          }
          mechanisms.set(
            node_name,
            CausalMechanism::additive_noise_with(
              PredictionModel::with_equation(
                parse_equation(custom_function),
                parents,
              ),
              noise_model_of(name, parse_equation_arguments(arguments)),
            ),
          )
          defined.set(node_name, !arguments.trim().is_empty())
        }
    }
  }
  // The nodes that were never given an equation are root nodes with an
  // empirical distribution.
  for node in graph.node_list() {
    if !defined.contains(node) {
      root_models.set(node, StochasticModel::empirical())
    }
  }
  let model = ProbabilisticCausalModel::new(graph)
  for node in model.graph.node_list() {
    match root_models.get(node) {
      Some(root_model) => model.set_root_model(node, root_model)
      None => ()
    }
    match mechanisms.get(node) {
      Some(mechanism) => model.set_causal_mechanism(node, mechanism)
      None => ()
    }
    match defined.get(node) {
      Some(true) =>
        model.set_parents_during_fit(
          node,
          model.graph.ordered_predecessors(node),
        )
      _ => ()
    }
  }
  model
}

///|
/// The name of a node and the right hand side of its equation.
///
/// This is the port of `dowhy.gcm.equation_parser._extract_equation_components`.
/// The right hand side of an equation of an unknown relation is separated with
/// an arrow, the right hand side of every other equation with an equals sign.
fn equation_components(equation : String) -> (String, String) {
  let (name, expression) = match equation.split_once("->") {
    Some((name, expression)) => (name, expression)
    None =>
      match equation.split_once("=") {
        Some((name, expression)) => (name, expression)
        None => abort("the equation " + equation + " has no right hand side")
      }
  }
  (name.trim().to_owned(), expression.trim().to_owned())
}

///|
/// The name of a noise model and the text of its arguments.
///
/// This is the port of the regular expression
/// `^\s*([\w]+)\(([^)]*)\)\s*$` of the upstream, which recognises the call of a
/// noise model.
fn noise_model_call(expression : String) -> (String, String)? {
  let chars = expression.trim().to_owned().to_array()
  let mut open = -1
  for i in 0..<chars.length() {
    if chars[i] == '(' {
      open = i
      break
    }
  }
  if open < 0 || chars.length() == 0 {
    return None
  }
  if chars[chars.length() - 1] != ')' {
    return None
  }
  let name = chars_to_string(chars, 0, open)
  if name.is_empty() {
    return None
  }
  for character in name.to_array() {
    if !is_word_character(character) {
      return None
    }
  }
  // The closing parenthesis of the call has to be the one that closes the
  // opening one, so the arguments hold no parenthesis of their own. The
  // regular expression of the upstream says the same with `[^)]*`.
  for i in (open + 1)..<(chars.length() - 1) {
    if chars[i] == ')' {
      return None
    }
  }
  Some((name, chars_to_string(chars, open + 1, chars.length() - 1)))
}

///|
/// Whether an equation states an unknown relation to its parents.
///
/// This is the port of `dowhy.gcm.equation_parser._check_if_model_is_unknown`.
/// Only an equation with an arrow states an unknown relation, and its right hand
/// side is the list of its parents.
fn is_unknown_equation(equation : String, expression : String) -> Bool {
  if !equation.contains("->") {
    return false
  }
  let parts = split_text(expression, ",")
  if parts.length() == 0 {
    return false
  }
  for part in parts {
    let name = part.trim().to_owned()
    if name.is_empty() {
      return false
    }
    for character in name.to_array() {
      if !is_word_character(character) {
        return false
      }
    }
  }
  true
}

///|
/// The custom function of an equation and the call of its noise model.
///
/// This is the port of the `expression.rsplit("+", 1)` of the upstream, which
/// splits the right hand side of an equation at its last plus sign.
fn split_noise(expression : String) -> (String, String) {
  match expression.rev_split_once("+") {
    Some((custom_function, noise)) =>
      (custom_function.trim().to_owned(), noise.trim().to_owned())
    None => abort("unable to recognise the format or function specified")
  }
}

///|
/// The parents of the custom function of an equation.
///
/// This is the port of the two steps the upstream takes to find them: it
/// collects every name of the expression and drops the ones that are the name
/// of a function, and it sorts the rest. The port knows a fixed set of
/// functions, where the upstream knows every function of numpy and of
/// `scipy.stats`.
fn parents_of_function(custom_function : String) -> Array[String] {
  let names : Array[String] = []
  for name in names_of(custom_function) {
    if !is_equation_function(name) && !names.contains(name) {
      names.push(name)
    }
  }
  names.sort_by(fn(a, b) { a.lexical_compare(b) })
  names
}

///|
/// The parents of an equation of an unknown relation, sorted by their name.
///
/// This is the port of `dowhy.gcm.equation_parser._get_sorted_parent_nodes`.
fn sorted_parents(candidates : Array[String]) -> Array[String] {
  let names : Array[String] = []
  for candidate in candidates {
    let name = candidate.trim().to_owned()
    if !name.is_empty() && !names.contains(name) {
      names.push(name)
    }
  }
  names.sort_by(fn(a, b) { a.lexical_compare(b) })
  names
}

///|
/// Every name of an expression.
///
/// This is the port of the regular expression `[a-zA-Z_]\w*` of the upstream,
/// which finds every name of an expression.
fn names_of(expression : String) -> Array[String] {
  let names : Array[String] = []
  let chars = expression.to_array()
  let mut i = 0
  while i < chars.length() {
    if is_name_start(chars[i]) {
      let start = i
      while i < chars.length() && is_word_character(chars[i]) {
        i = i + 1
      }
      names.push(chars_to_string(chars, start, i))
    } else {
      i = i + 1
    }
  }
  names
}

///|
/// The arguments of a noise model.
///
/// This is the port of `dowhy.gcm.equation_parser._parse_args`, which reads
/// the arguments of a noise model with the `literal_eval` of Python. The port
/// reads numbers only, which are the arguments the noise models of the port
/// take.
fn parse_equation_arguments(arguments : String) -> Map[String, Double] {
  let parsed : Map[String, Double] = Map([])
  for argument in split_text(arguments, ",") {
    let text = argument.trim().to_owned()
    if text.is_empty() {
      continue
    }
    let pair = match text.split_once("=") {
      Some(pair) => pair
      None => abort("the argument " + text + " is not a name and a value")
    }
    let name = pair.0.trim().to_owned()
    let value = pair.1.trim().to_owned()
    parsed.set(name, parse_equation_number(value))
  }
  parsed
}

///|
/// The number of an argument of a noise model.
///
/// This is the port of the `literal_eval` of Python the upstream reads the
/// arguments of a noise model with. The port reads numbers only, which are the
/// arguments the noise models of the port take.
fn parse_equation_number(text : String) -> Double {
  let chars = text.to_array()
  let mut index = 0
  let mut sign = 1.0
  if index < chars.length() && (chars[index] == '-' || chars[index] == '+') {
    if chars[index] == '-' {
      sign = -1.0
    }
    index = index + 1
  }
  let mut value = 0.0
  while index < chars.length() && chars[index].is_ascii_digit() {
    value = value * 10.0 + (chars[index].to_int() - 48).to_double()
    index = index + 1
  }
  if index < chars.length() && chars[index] == '.' {
    index = index + 1
    let mut place = 0.1
    while index < chars.length() && chars[index].is_ascii_digit() {
      value = value + (chars[index].to_int() - 48).to_double() * place
      place = place * 0.1
      index = index + 1
    }
  }
  if index < chars.length() {
    abort("the value " + text + " of an argument is not a number")
  }
  sign * value
}

///|
/// The noise model of a name and its arguments.
///
/// This is the port of `dowhy.gcm.equation_parser._identify_noise_model`. The
/// upstream knows the empirical distribution, the Bayesian Gaussian mixture and
/// the parametric distribution of `scipy.stats`, and every distribution of
/// `scipy.stats` by its own name. The port knows the empirical distribution,
/// the normal, the Laplace and the uniform distribution, and it fits the
/// parameters of a distribution that was given none.
fn noise_model_of(
  name : String,
  arguments : Map[String, Double],
) -> StochasticModel {
  match name {
    "empirical" => StochasticModel::empirical()
    // The upstream maps the Bayesian Gaussian mixture to the empirical
    // distribution as well.
    "bayesiangaussianmixture" => StochasticModel::empirical()
    "parametric" =>
      StochasticModel::normal(0.0, 1.0).with_estimated_parameters()
    "norm" =>
      StochasticModel::normal(
        argument_of(arguments, "loc", 0.0),
        argument_of(arguments, "scale", 1.0),
      )
    "laplace" =>
      StochasticModel::laplace(
        argument_of(arguments, "loc", 0.0),
        argument_of(arguments, "scale", 1.0),
      )
    "uniform" =>
      StochasticModel::uniform(
        argument_of(arguments, "loc", 0.0),
        argument_of(arguments, "scale", 1.0),
      )
    _ => abort("unable to recognise the noise model: " + name)
  }
}

///|
/// The value of an argument of a noise model, or the given default.
fn argument_of(
  arguments : Map[String, Double],
  name : String,
  default : Double,
) -> Double {
  match arguments.get(name) {
    Some(value) => value
    None => default
  }
}

///|
/// The check of an equation for the characters the upstream bans.
///
/// This is the port of `dowhy.gcm.equation_parser._sanitize_input_expression`.
/// The upstream bans the characters that would allow an expression to reach
/// outside of the model, and it allows the full stop only in a decimal.
fn sanitize_equation(equation : String) -> Unit {
  for banned in [";", "[", "__", "import", "lambda"] {
    if equation.contains(banned) {
      abort(
        "'" +
        banned +
        "' in the expression '" +
        equation +
        "' is not allowed because of security reasons",
      )
    }
  }
  if equation.contains(":") {
    abort(
      "':' in the expression '" +
      equation +
      "' is not allowed because of security reasons",
    )
  }
}

///|
/// Whether a character is a letter, a digit or an underscore.
fn is_word_character(character : Char) -> Bool {
  character.is_ascii_alphabetic() ||
  character.is_ascii_digit() ||
  character == '_'
}

///|
/// Whether a character can start a name.
fn is_name_start(character : Char) -> Bool {
  character.is_ascii_alphabetic() || character == '_'
}

///|
/// The parts of a text, separated by a separator.
fn split_text(text : String, separator : String) -> Array[String] {
  let parts : Array[String] = []
  for part in text.split(separator) {
    parts.push(part.to_owned())
  }
  parts
}

///|
/// The text of a range of characters.
fn chars_to_string(chars : Array[Char], start : Int32, end : Int32) -> String {
  let out : Array[Char] = []
  for i in start..<end {
    out.push(chars[i])
  }
  String::from_array(out)
}

///|
/// The functions an equation may call.
///
/// The upstream lets an expression call every function of numpy and of
/// `scipy.stats`; the port knows the functions below.
fn is_equation_function(name : String) -> Bool {
  match name {
    "abs"
    | "acos"
    | "asin"
    | "atan"
    | "ceil"
    | "cos"
    | "cosh"
    | "exp"
    | "floor"
    | "log"
    | "log10"
    | "log2"
    | "pow"
    | "round"
    | "sign"
    | "sin"
    | "sinh"
    | "sqrt"
    | "tan"
    | "tanh"
    | "trunc" => true
    _ => false
  }
}

///|
/// The expression of the custom function of an equation.
///
/// This is the parser of the port, which replaces the `eval` of the upstream.
fn parse_equation(expression : String) -> EquationExpr {
  let parser = EqParser::{ tokens: tokenize_equation(expression), position: 0, }
  let result = parser.parse_sum()
  if parser.kind().not_equal(EqTokenKind::End) {
    abort("the expression '" + expression + "' could not be parsed")
  }
  result
}

///|
/// A token of the expression of an equation.
priv struct EqToken {
  /// The kind of the token.
  kind : EqTokenKind
  /// The value of a number.
  value : Double
  /// The name of an identifier.
  name : String
}

///|
/// The kind of a token of the expression of an equation.
#derive(Eq)
priv enum EqTokenKind {
  Number
  Identifier
  Plus
  Minus
  Star
  Slash
  LParen
  RParen
  Comma
  End
}

///|
extend EqTokenKind with Eq::{equal, not_equal}

///|
/// The parser of the expression of an equation.
///
/// The parser holds the tokens of the expression and the position it reads
/// them at.
priv struct EqParser {
  tokens : Array[EqToken]
  mut position : Int32
}

///|
/// The tokens of the expression of an equation.
fn tokenize_equation(expression : String) -> Array[EqToken] {
  let tokens : Array[EqToken] = []
  let chars = expression.to_array()
  let mut i = 0
  while i < chars.length() {
    let character = chars[i]
    if character.is_whitespace() {
      i = i + 1
    } else if character == '+' {
      tokens.push(eq_token(EqTokenKind::Plus, 0.0, ""))
      i = i + 1
    } else if character == '-' {
      tokens.push(eq_token(EqTokenKind::Minus, 0.0, ""))
      i = i + 1
    } else if character == '*' {
      tokens.push(eq_token(EqTokenKind::Star, 0.0, ""))
      i = i + 1
    } else if character == '/' {
      tokens.push(eq_token(EqTokenKind::Slash, 0.0, ""))
      i = i + 1
    } else if character == '(' {
      tokens.push(eq_token(EqTokenKind::LParen, 0.0, ""))
      i = i + 1
    } else if character == ')' {
      tokens.push(eq_token(EqTokenKind::RParen, 0.0, ""))
      i = i + 1
    } else if character == ',' {
      tokens.push(eq_token(EqTokenKind::Comma, 0.0, ""))
      i = i + 1
    } else if character.is_ascii_digit() {
      let start = i
      while i < chars.length() && chars[i].is_ascii_digit() {
        i = i + 1
      }
      if i < chars.length() && chars[i] == '.' {
        i = i + 1
        while i < chars.length() && chars[i].is_ascii_digit() {
          i = i + 1
        }
      }
      tokens.push(
        eq_token(
          EqTokenKind::Number,
          parse_equation_number(chars_to_string(chars, start, i)),
          "",
        ),
      )
    } else if is_name_start(character) {
      let start = i
      while i < chars.length() && is_word_character(chars[i]) {
        i = i + 1
      }
      tokens.push(
        eq_token(EqTokenKind::Identifier, 0.0, chars_to_string(chars, start, i)),
      )
    } else {
      abort(
        "the character '" +
        character.to_string() +
        "' is not allowed in an equation",
      )
    }
  }
  tokens.push(eq_token(EqTokenKind::End, 0.0, ""))
  tokens
}

///|
/// A token of the expression of an equation.
fn eq_token(kind : EqTokenKind, value : Double, name : String) -> EqToken {
  { kind, value, name, }
}

///|
/// A sum of two expressions.
fn EqParser::parse_sum(self : EqParser) -> EquationExpr {
  let mut left = self.parse_product()
  let mut going = true
  while going {
    if self.kind().equal(EqTokenKind::Plus) {
      self.position = self.position + 1
      left = EquationExpr::Add(left, self.parse_product())
    } else if self.kind().equal(EqTokenKind::Minus) {
      self.position = self.position + 1
      left = EquationExpr::Sub(left, self.parse_product())
    } else {
      going = false
    }
  }
  left
}

///|
/// A product of two expressions.
fn EqParser::parse_product(self : EqParser) -> EquationExpr {
  let mut left = self.parse_unary()
  let mut going = true
  while going {
    if self.kind().equal(EqTokenKind::Star) {
      self.position = self.position + 1
      left = EquationExpr::Mul(left, self.parse_unary())
    } else if self.kind().equal(EqTokenKind::Slash) {
      self.position = self.position + 1
      left = EquationExpr::Div(left, self.parse_unary())
    } else {
      going = false
    }
  }
  left
}

///|
/// A factor of an expression, which is a value with an optional sign.
fn EqParser::parse_unary(self : EqParser) -> EquationExpr {
  if self.kind().equal(EqTokenKind::Minus) {
    self.position = self.position + 1
    return EquationExpr::Neg(self.parse_unary())
  }
  if self.kind().equal(EqTokenKind::Plus) {
    self.position = self.position + 1
    return self.parse_unary()
  }
  self.parse_value()
}

///|
/// A value of an expression.
fn EqParser::parse_value(self : EqParser) -> EquationExpr {
  let token = self.tokens[self.position]
  match token.kind {
    EqTokenKind::Number => {
      self.position = self.position + 1
      EquationExpr::Number(token.value)
    }
    EqTokenKind::Identifier => {
      self.position = self.position + 1
      if self.kind().equal(EqTokenKind::LParen) {
        self.position = self.position + 1
        let arguments : Array[EquationExpr] = []
        if self.kind().not_equal(EqTokenKind::RParen) {
          arguments.push(self.parse_sum())
          while self.kind().equal(EqTokenKind::Comma) {
            self.position = self.position + 1
            arguments.push(self.parse_sum())
          }
        }
        if self.kind().not_equal(EqTokenKind::RParen) {
          abort(
            "the arguments of the call of '" + token.name + "' are not closed",
          )
        }
        self.position = self.position + 1
        EquationExpr::Call(token.name, arguments)
      } else {
        EquationExpr::Variable(token.name)
      }
    }
    EqTokenKind::LParen => {
      self.position = self.position + 1
      let inner = self.parse_sum()
      if self.kind().not_equal(EqTokenKind::RParen) {
        abort("the parentheses of an expression are not closed")
      }
      self.position = self.position + 1
      inner
    }
    _ => abort("an expression was expected")
  }
}

///|
/// The kind of the token the parser reads at.
fn EqParser::kind(self : EqParser) -> EqTokenKind {
  self.tokens[self.position].kind
}

///|
/// The predictions of the custom function of an equation.
///
/// This is the port of the `predict` of
/// `dowhy.gcm.equation_parser.CustomEquationModel`, which evaluates the
/// expression over the columns of the design matrix.
fn predict_equation(
  equation : EquationModel,
  x : @utils.Matrix,
) -> Array[Double] {
  let env : Map[String, Array[Double]] = Map([])
  for j in 0..<equation.parents.length() {
    if j < x.ncols() {
      env.set(equation.parents[j], x.col(j))
    }
  }
  evaluate_equation(equation.expression, env, x.nrows())
}

///|
/// The value of an expression for every row of the design matrix.
fn evaluate_equation(
  expression : EquationExpr,
  env : Map[String, Array[Double]],
  nrows : Int32,
) -> Array[Double] {
  match expression {
    EquationExpr::Number(value) => {
      let out : Array[Double] = []
      for _ in 0..<nrows {
        out.push(value)
      }
      out
    }
    EquationExpr::Variable(name) =>
      match env.get(name) {
        Some(values) => values.copy()
        None => abort("the node " + name + " is not a parent of the equation")
      }
    EquationExpr::Neg(inner) =>
      map_equation_values(evaluate_equation(inner, env, nrows), fn(value) {
        -value
      })
    EquationExpr::Add(left, right) =>
      combine_equation_values(
        evaluate_equation(left, env, nrows),
        evaluate_equation(right, env, nrows),
        fn(a, b) { a + b },
      )
    EquationExpr::Sub(left, right) =>
      combine_equation_values(
        evaluate_equation(left, env, nrows),
        evaluate_equation(right, env, nrows),
        fn(a, b) { a - b },
      )
    EquationExpr::Mul(left, right) =>
      combine_equation_values(
        evaluate_equation(left, env, nrows),
        evaluate_equation(right, env, nrows),
        fn(a, b) { a * b },
      )
    EquationExpr::Div(left, right) =>
      combine_equation_values(
        evaluate_equation(left, env, nrows),
        evaluate_equation(right, env, nrows),
        fn(a, b) { a / b },
      )
    EquationExpr::Call(name, arguments) => {
      let values : Array[Array[Double]] = []
      for argument in arguments {
        values.push(evaluate_equation(argument, env, nrows))
      }
      call_equation_function(name, values)
    }
  }
}

///|
/// The values of an expression with a function applied to every one of them.
fn map_equation_values(
  values : Array[Double],
  function : (Double) -> Double,
) -> Array[Double] {
  let out : Array[Double] = []
  for value in values {
    out.push(function(value))
  }
  out
}

///|
/// The values of two expressions combined one by one.
fn combine_equation_values(
  left : Array[Double],
  right : Array[Double],
  function : (Double, Double) -> Double,
) -> Array[Double] {
  let out : Array[Double] = []
  for i in 0..<left.length() {
    let other = if i < right.length() { right[i] } else { 0.0 }
    out.push(function(left[i], other))
  }
  out
}

///|
/// The call of a function of an equation.
///
/// This is the port of the `_allowed_callables` of the upstream, which holds
/// every function of numpy and of `scipy.stats`. The port knows the functions
/// below.
fn call_equation_function(
  name : String,
  arguments : Array[Array[Double]],
) -> Array[Double] {
  match name {
    "abs" => map_equation_values(arguments[0], fn(value) { value.abs() })
    "acos" => map_equation_values(arguments[0], fn(value) { @math.acos(value) })
    "asin" => map_equation_values(arguments[0], fn(value) { @math.asin(value) })
    "atan" => map_equation_values(arguments[0], fn(value) { @math.atan(value) })
    "ceil" => map_equation_values(arguments[0], fn(value) { value.ceil() })
    "cos" => map_equation_values(arguments[0], fn(value) { @math.cos(value) })
    "cosh" => map_equation_values(arguments[0], fn(value) { @math.cosh(value) })
    "exp" => map_equation_values(arguments[0], fn(value) { @math.exp(value) })
    "floor" => map_equation_values(arguments[0], fn(value) { value.floor() })
    "log" => map_equation_values(arguments[0], fn(value) { @math.ln(value) })
    "log10" =>
      map_equation_values(arguments[0], fn(value) { @math.log10(value) })
    "log2" => map_equation_values(arguments[0], fn(value) { @math.log2(value) })
    "pow" =>
      combine_equation_values(arguments[0], arguments[1], fn(a, b) {
        @math.pow(a, b)
      })
    "round" => map_equation_values(arguments[0], fn(value) { value.round() })
    "sign" => map_equation_values(arguments[0], fn(value) { value.signum() })
    "sin" => map_equation_values(arguments[0], fn(value) { @math.sin(value) })
    "sinh" => map_equation_values(arguments[0], fn(value) { @math.sinh(value) })
    "sqrt" => map_equation_values(arguments[0], fn(value) { value.sqrt() })
    "tan" => map_equation_values(arguments[0], fn(value) { @math.tan(value) })
    "tanh" => map_equation_values(arguments[0], fn(value) { @math.tanh(value) })
    "trunc" => map_equation_values(arguments[0], fn(value) { value.trunc() })
    _ => abort("the function " + name + " is not known")
  }
}
