/// The symbolic estimators of the upstream.
///
/// The upstream builds the symbolic estimator of an estimator when it is
/// fitted, keeps it in the attribute `symbolic_estimator` and hands it to the
/// estimate as the `realized_estimand_expr` of the estimate.
///
/// Every estimator of the upstream but the instrumental variable one builds a
/// plain string. The instrumental variable estimator builds the expressions of
/// the sympy of the upstream, so the port gives `None` for it.

///|
/// The symbolic estimator of the estimator.
///
/// The base estimator of the upstream does not build one and raises a
/// `NotImplementedError` when it is asked for, so the port gives `None` for
/// it, and so does the port for the instrumental variable estimator, whose
/// symbolic estimator of the upstream holds the expressions of the sympy.
///
/// The regression discontinuity estimator of the upstream builds the empty
/// string, so the port builds the empty string too.
///
/// The upstream builds the symbolic estimator when the estimator is fitted, and
/// the port computes it when it is asked for, so the effect modifiers of the
/// estimator are the ones of its last fit.
pub fn CausalEstimator::symbolic_estimator(self : CausalEstimator) -> String? {
  match self.kind {
    Base => None
    InstrumentalVariable => None
    RegressionDiscontinuity => Some("")
    LinearRegression => Some(self.regression_symbolic_estimator(",", false))
    GeneralizedLinearModel =>
      Some(self.regression_symbolic_estimator(",", true))
    PropensityScoreWeighting => Some(self.simple_symbolic_estimator(","))
    PropensityScoreMatching => Some(self.simple_symbolic_estimator(", "))
    PropensityScoreStratification => Some(self.simple_symbolic_estimator(","))
    DoublyRobust => Some(self.simple_symbolic_estimator(","))
    DistanceMatching => Some(self.simple_symbolic_estimator(", "))
    TwoStageRegression => self.two_stage_symbolic_estimator()
  }
}

///|
/// The variables of the symbolic estimator of the estimator.
///
/// The upstream takes the treatment of the estimand and the adjustment set of
/// the estimand.
fn CausalEstimator::symbolic_variables(self : CausalEstimator) -> Array[String] {
  let variables : Array[String] = []
  for name in self.target_estimand.treatment() {
    variables.push(name)
  }
  let adjustment = self.target_estimand.get_adjustment_set(
    self.target_estimand.identifier_method(),
  )
  for name in adjustment {
    variables.push(name)
  }
  variables
}

///|
/// The interaction terms of the symbolic estimator of the estimator.
///
/// The upstream adds one term for every pair of a treatment and an effect
/// modifier, the treatment first.
fn CausalEstimator::symbolic_interactions(
  self : CausalEstimator,
) -> Array[String] {
  let terms : Array[String] = []
  for treatment in self.target_estimand.treatment() {
    for modifier in self.effect_modifier_names {
      terms.push(treatment + "*" + modifier)
    }
  }
  terms
}

///|
/// The symbolic estimator of the estimators that build no model of their own.
///
/// The upstream joins the outcome variables with the given separator and the
/// treatment and the adjustment variables with a plus.
fn CausalEstimator::simple_symbolic_estimator(
  self : CausalEstimator,
  separator : String,
) -> String {
  "b: " +
  self.target_estimand.outcome().join(separator) +
  "~" +
  self.symbolic_variables().join("+")
}

///|
/// The symbolic estimator of the regression based estimators.
///
/// The generalised linear model estimator of the upstream wraps the variables
/// in a sigmoid and the linear regression estimator does not.
fn CausalEstimator::regression_symbolic_estimator(
  self : CausalEstimator,
  separator : String,
  sigmoid : Bool,
) -> String {
  let head = "b: " + self.target_estimand.outcome().join(separator) + "~"
  let variables = self.symbolic_variables()
  for term in self.symbolic_interactions() {
    variables.push(term)
  }
  if sigmoid {
    head + "Sigmoid(" + variables.join("+") + ")"
  } else {
    head + variables.join("+")
  }
}

///|
/// The symbolic estimator of the two stage regression estimator.
///
/// The upstream builds the symbolic estimators of the two stages and composes
/// them into the natural indirect effect, the product of the two. The port
/// estimates the natural indirect effect, so it builds the same expression.
///
/// The upstream builds the symbolic estimator of the natural direct effect as
/// well, when the estimand asks for it. The port does not estimate the natural
/// direct effect, so it does not build that expression either.
fn CausalEstimator::two_stage_symbolic_estimator(
  self : CausalEstimator,
) -> String? {
  let first = match self.first_stage {
    Some(stage) => stage
    None => return None
  }
  let second = match self.second_stage {
    Some(stage) => stage
    None => return None
  }
  let first_expression = stage_symbolic_estimator(
    first,
    self.effect_modifier_names,
  )
  let second_expression = stage_symbolic_estimator(
    second,
    self.effect_modifier_names,
  )
  Some("(" + first_expression + ")*(" + second_expression + ")")
}

///|
/// The symbolic estimator of one stage of the two stage regression estimator.
///
/// The stage of the upstream is a linear regression, so its symbolic estimator
/// is the one of the linear regression: the treatment of the stage, its
/// adjustment set and the interaction of its treatment with every effect
/// modifier.
fn stage_symbolic_estimator(
  stage : TwoStageModel,
  effect_modifier_names : Array[String],
) -> String {
  let variables : Array[String] = [stage.treatment_name]
  for name in stage.adjustment_names {
    variables.push(name)
  }
  let treatments = [stage.treatment_name]
  for treatment in treatments {
    for modifier in effect_modifier_names {
      variables.push(treatment + "*" + modifier)
    }
  }
  "b: " + stage.outcome_name + "~" + variables.join("+")
}
