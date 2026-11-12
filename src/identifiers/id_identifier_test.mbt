///|
/// The tests of the ID algorithm of the `identifiers` package.
///
/// This is the port of the test file
/// `tests/causal_identifiers/test_id_identifier.py` of the upstream. The
/// upstream test file compares the string of the estimand with a fixed one;
/// the tests of the port do the same, and the script
/// `_verify/id_identifier_reference.py` computes the strings with the upstream
/// code itself.
/// The six graphs of the notebook of the upstream are the six graphs of the cases of this file.  The notebook `identifying_effects_using_id_algorithm.ipynb`.

///|
/// The graph of the edges and the nodes of the upstream test file.
///
/// The nodes are in the order of the graph string of the upstream, because
/// the order of the nodes of the graph decides the order of the factors of
/// the estimand.
fn id_graph(
  edges : Array[String],
  nodes : Array[String],
) -> @graph.DirectedGraph {
  let graph = @graph.DirectedGraph::new()
  for node in nodes {
    graph.add_node(node)
  }
  for edge in edges {
    let parts = edge.split("->")
    match parts.next() {
      Some(source) =>
        match parts.next() {
          Some(target) => graph.add_edge(source.to_owned(), target.to_owned())
          None => ()
        }
      None => ()
    }
  }
  graph
}

///|
/// The estimand of the effect of the treatment on the outcome.
fn id_estimand(
  edges : Array[String],
  nodes : Array[String],
) -> (@identifiers.IDExpression?, String) {
  let graph = id_graph(edges, nodes)
  @identifiers.identify_effect_id(graph, ["T"], ["Y"])
}

///|
/// The predictor of the given element, when it has one.
fn id_predictor_of(
  element : @identifiers.IDElement,
) -> @identifiers.IDPredictor? {
  element.as_predictor()
}

///|
/// The expression of the given element, when it has one.
fn id_expression_of(
  element : @identifiers.IDElement,
) -> @identifiers.IDExpression? {
  element.as_expression()
}

///|
test "given a graph with one edge when identifying the effect with the ID algorithm then find the distribution of the outcome" {
  let (estimand, message) = id_estimand(["T->Y"], ["T", "Y"])
  assert_eq(message, "")
  match estimand {
    Some(expression) => assert_eq(expression.to_string(), "Predictor: P(Y|T)")
    None => assert_true(false)
  }
}

///|
test "given a graph with a cycle when identifying the effect with the ID algorithm then report that the graph has to be acyclic" {
  let (estimand, message) = id_estimand(["T->Y", "Y->T"], ["T", "Y"])
  assert_true(estimand is None)
  assert_eq(message, @identifiers.ID_NOT_A_DAG)
}

///|
test "given a graph with a mediator when identifying the effect with the ID algorithm then find the product of the distributions of the mediator and of the outcome" {
  let (estimand, message) = id_estimand(["T->X1", "X1->Y"], ["T", "X1", "Y"])
  assert_eq(message, "")
  match estimand {
    Some(expression) =>
      assert_eq(
        expression.to_string(),
        "Sum over {X1}:\n\tPredictor: P(X1|T)\n\tPredictor: P(Y|T,X1)",
      )
    None => assert_true(false)
  }
}

///|
test "given a graph with a mediator and a direct effect when identifying the effect with the ID algorithm then find the product of the distributions of the outcome and of the mediator" {
  let (estimand, message) = id_estimand(["T->Y", "T->X1", "X1->Y"], [
    "T", "Y", "X1",
  ])
  assert_eq(message, "")
  match estimand {
    Some(expression) =>
      assert_eq(
        expression.to_string(),
        "Sum over {X1}:\n\tPredictor: P(Y|T,X1)\n\tPredictor: P(X1|T)",
      )
    None => assert_true(false)
  }
}

///|
test "given a graph with two confounds when identifying the effect with the ID algorithm then find the product of the distributions of the outcome and of the confound" {
  let (estimand, message) = id_estimand(["T->Y", "X1->T", "X1->Y", "X2->T"], [
    "T", "Y", "X1", "X2",
  ])
  assert_eq(message, "")
  match estimand {
    Some(expression) => {
      assert_eq(
        expression.to_string(),
        "Sum over {X1}:\n\tPredictor: P(Y|X1,X2,T)\n\tPredictor: P(X1)",
      )
      // The upstream test file also checks the structure of the estimand.
      let outer = id_expression_of(expression.product()[0]).unwrap()
      assert_eq(outer.sum(), ["X1"])
      let first = id_expression_of(outer.product()[0]).unwrap()
      let first_predictor = id_predictor_of(first.product()[0]).unwrap()
      assert_eq(first_predictor.outcome_vars(), ["Y"])
      assert_true(first_predictor.condition_vars().contains("X1"))
      assert_true(first_predictor.condition_vars().contains("X2"))
      assert_true(first_predictor.condition_vars().contains("T"))
      let second = id_expression_of(outer.product()[1]).unwrap()
      let second_predictor = id_predictor_of(second.product()[0]).unwrap()
      assert_eq(second_predictor.outcome_vars(), ["X1"])
      assert_eq(second_predictor.condition_vars(), [])
    }
    None => assert_true(false)
  }
}

///|
test "given a graph with a treatment that is not an ancestor of the outcome when identifying the effect with the ID algorithm then find the marginal distribution of the outcome" {
  let (estimand, message) = id_estimand(["X1->Y"], ["T", "X1", "Y"])
  assert_eq(message, "")
  match estimand {
    Some(expression) =>
      assert_eq(expression.to_string(), "Sum over {X1}:\n\tPredictor: P(X1,Y)")
    None => assert_true(false)
  }
}
