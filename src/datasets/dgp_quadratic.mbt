///|
/// The data of the quadratic process of the upstream.
///
/// This is the port of `generate_data` of the quadratic process of the upstream.
/// The upstream draws the confounder, the effect modifier, the weights of the
/// process and the noise of the treatment. It draws the weights of the process
/// again at the end of every power, so the weights of the process are the
/// weights of the last power, and the outcome of every power holds the weights
/// of the power before it.
fn DataGeneratingProcess::generate_quadratic(
  self : DataGeneratingProcess,
  sample_size : Int32,
) -> @api.DataFrame {
  let config = self.config
  let confounder_count = config.confounder.length()
  let treatment_count = config.treatment.length()
  let modifier_count = config.effect_modifier.length()
  let confounder = self.generator.randn(sample_size, confounder_count)
  // The quadratic process of the upstream draws its effect modifier, the
  // linear process of the upstream does not.
  let effect_modifier = self.generator.randn(sample_size, modifier_count)
  self.generation_process_plain()
  let noise = self.generator.randn(sample_size, treatment_count)
  let treatment = dgp_add_bias(
    dgp_add(confounder.mul(self.weights.confounder_to_treatment), noise),
    self.bias.confounder_to_treatment,
  )
  let outcomes : Array[@utils.Matrix] = []
  let controls : Array[@utils.Matrix] = []
  let treatments : Array[@utils.Matrix] = []
  for _ in 0..<2 {
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
    treatments.push(
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
    self.generation_process_plain()
  }
  let treated = self.dgp_treatment(treatment)
  let outcome = dgp_multiply(outcomes[0], outcomes[1])
  let control = dgp_multiply(controls[0], controls[1])
  let treated_outcome = dgp_multiply(treatments[0], treatments[1])
  self.true_value = dgp_mean_columns(dgp_subtract(treated_outcome, control))
  dgp_frame([
    (config.effect_modifier, effect_modifier),
    (config.confounder, confounder),
    (config.treatment, treated),
    (config.outcome, outcome),
  ])
}
