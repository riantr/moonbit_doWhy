/// The daggity fixture of the upstream test file `tests/test_causal_graph.py`.
///
/// The graph is the one of the file `tests/sample_dag.txt` of the upstream: the
/// treatment `v0` has the outcome `y`, the common causes `W0` and the four
/// features `X0`, `X1` and `X2` are its parents, `Z0` is its instrument and
/// `Unobserved Confounders` is an unobserved common cause of the treatment and
/// of the outcome.
///
/// The fixture comes from `_verify/gen_graph_fixture.py`, which reads the file
/// of the upstream; do not edit it by hand.

///|
/// The graph of the daggity web site, as the upstream writes it.
pub fn daggity_fixture() -> String {
  let mut out = ""
  out = out + "dag {\n"
  out = out + "\"Unobserved Confounders\" [pos=\"0.491,-1.056\"]\n"
  out = out + "W0\n"
  out = out + "X0 [pos=\"-2.109,0.057\"]\n"
  out = out + "X1 [adjusted, pos=\"-0.453,-1.562\"]\n"
  out = out + "X2 [pos=\"-2.268,-1.210\"]\n"
  out = out + "Z0 [pos=\"-1.918,-1.735\"]\n"
  out = out + "v0 [pos=\"-1.525,-1.293\"]\n"
  out = out + "y [outcome, pos=\"-1.164,-0.116\"]\n"
  out = out + "\"Unobserved Confounders\" -> v0\n"
  out = out + "\"Unobserved Confounders\" -> y\n"
  out = out + "W0 -> v0\n"
  out = out + "W0 -> y\n"
  out = out + "X0 -> v0\n"
  out = out + "X0 -> y\n"
  out = out + "X1 -> v0\n"
  out = out + "X1 -> y\n"
  out = out + "X2 -> v0\n"
  out = out + "X2 -> y\n"
  out = out + "Z0 -> v0\n"
  out = out + "v0 -> y\n"
  out = out + "}\n"
  out = out + "\n"
  out
}
