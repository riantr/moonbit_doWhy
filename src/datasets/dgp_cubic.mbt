///|
/// The data of the cubic process of the upstream.
///
/// This is the port of `generate_data` of the cubic process of the upstream.
/// The upstream draws the confounder and the effect modifier, and then it
/// draws the weights of the process and the noise of the treatment of every
/// power. The outcome of a power holds the treatment of that power, and the
/// treatment of the data is the product of the treatments of the powers.
fn DataGeneratingProcess::generate_cubic(
  self : DataGeneratingProcess,
  sample_size : Int32,
) -> @api.DataFrame {
  let config = self.config
  let confounder_count = config.confounder.length()
  let treatment_count = config.treatment.length()
  let modifier_count = config.effect_modifier.length()
  let confounder = self.generator.randn(sample_size, confounder_count)
  let effect_modifier = self.generator.randn(sample_size, modifier_count)
  let treatments : Array[@utils.Matrix] = []
  let outcomes : Array[@utils.Matrix] = []
  let controls : Array[@utils.Matrix] = []
  let treated_outcomes : Array[@utils.Matrix] = []
  for _ in 0..<3 {
    // The upstream draws the weights of the process at the start of every
    // power.
    self.generation_process_plain()
    let noise = self.generator.randn(sample_size, treatment_count)
    let treatment = dgp_add_bias(
      dgp_add(confounder.mul(self.weights.confounder_to_treatment), noise),
      self.bias.confounder_to_treatment,
    )
    treatments.push(treatment)
    // The outcome of the power, the outcome of the treatment that is zero and
    // the outcome of the treatment that is one.
    let base = dgp_add(
      confounder.mul(self.weights.confounder_to_outcome),
      effect_modifier.mul(self.weights.effect_modifier_to_outcome),
    )
    outcomes.push(
      dgp_add_bias(
        dgp_add(base, treatment.mul(self.weights.treatment_to_outcome)),
        self.bias.confounder_to_outcome,
      ),
    )
    controls.push(
      dgp_add_bias(
        dgp_add(
          base,
          dgp_zeros(sample_size, treatment_count).mul(
            self.weights.treatment_to_outcome,
          ),
        ),
        self.bias.confounder_to_outcome,
      ),
    )
    treated_outcomes.push(
      dgp_add_bias(
        dgp_add(
          base,
          dgp_ones(sample_size, treatment_count).mul(
            self.weights.treatment_to_outcome,
          ),
        ),
        self.bias.confounder_to_outcome,
      ),
    )
  }
  let treatment = dgp_multiply(
    dgp_multiply(treatments[0], treatments[1]),
    treatments[2],
  )
  let treated = self.dgp_treatment(treatment)
  let outcome = dgp_multiply(
    dgp_multiply(outcomes[0], outcomes[1]),
    outcomes[2],
  )
  let control = dgp_multiply(
    dgp_multiply(controls[0], controls[1]),
    controls[2],
  )
  let treated_outcome = dgp_multiply(
    dgp_multiply(treated_outcomes[0], treated_outcomes[1]),
    treated_outcomes[2],
  )
  self.true_value = dgp_mean_columns(dgp_subtract(treated_outcome, control))
  dgp_frame([
    (config.effect_modifier, effect_modifier),
    (config.confounder, confounder),
    (config.treatment, treated),
    (config.outcome, outcome),
  ])
}
