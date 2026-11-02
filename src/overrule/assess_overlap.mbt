/// The refuter that assesses the support and the overlap of the covariates.
///
/// This is the port of `dowhy.causal_refuters.assess_overlap.AssessOverlap` and
/// of its `assess_support_and_overlap_overrule` function.

///|
/// The index of a column in the list of the names, or minus one when the name is
/// not among them.
fn index_of_name(names : Array[String], name : String) -> Int32 {
  for i = 0; i < names.length(); i = i + 1 {
    if names[i] == name {
      return i
    }
  }
  -1
}

///|
/// Learn the rules of the support and of the overlap of the covariates.
///
/// The rules are learned with respect to the backdoor variables only, and the
/// treatment is the column of the treatment, the way the upstream takes them.
/// The columns that are not named are left out of the rules.
pub fn refute_assess_overlap(
  columns : Array[Array[Double]],
  names : Array[String],
  backdoor_vars : Array[String],
  treatment_name : String,
  support_config : SupportConfig,
  overlap_config : OverlapConfig,
  overlap_eps : Double,
  support_only : Bool,
  overlap_only : Bool,
) -> OverlapAnalyzer {
  let covariates : Array[Array[Double]] = []
  let covariate_names : Array[String] = []
  for name in backdoor_vars {
    let index = index_of_name(names, name)
    if index >= 0 {
      covariates.push(columns[index])
      covariate_names.push(name)
    }
  }
  let treatment_index = index_of_name(names, treatment_name)
  let treatment = if treatment_index >= 0 {
    columns[treatment_index]
  } else {
    []
  }
  let analyzer = OverlapAnalyzer::new(
    covariate_names,
    treatment_name,
    support_config,
    overlap_config,
    overlap_eps~,
    support_only~,
    overlap_only~,
  )
  analyzer.fit(covariates, treatment)
  analyzer
}
