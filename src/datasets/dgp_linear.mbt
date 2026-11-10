///|
/// The data of the linear process of the upstream.
///
/// This is the port of `generate_data` of the linear process of the upstream.
/// The upstream draws the weights of the process, the confounder and the noise
/// of the treatment. Its effect modifier is a column of zeros, the linear
/// process of the upstream has no effect modifier.
fn DataGeneratingProcess::generate_linear(
  self : DataGeneratingProcess,
  sample_size : Int32,
) -> @api.DataFrame {
  let config = self.config
  self.generation_process()
  let confounder_count = config.confounder.length()
  let treatment_count = config.treatment.length()
  let modifier_count = config.effect_modifier.length()
  let confounder = self.generator.randn(sample_size, confounder_count)
  let effect_modifier = dgp_zeros(sample_size, modifier_count)
  let noise = self.generator.randn(sample_size, treatment_count)
  let treatment = dgp_add_bias(
    dgp_add(confounder.mul(self.weights.confounder_to_treatment), noise),
    self.bias.confounder_to_treatment,
  )
  let treated = self.dgp_treatment(treatment)
  // The outcome of the data, the outcome of the treatment that is zero and the
  // outcome of the treatment that is one. The upstream holds the last two to
  // compute the value of the effect.
  let base = dgp_add(
    confounder.mul(self.weights.confounder_to_outcome),
    effect_modifier.mul(self.weights.effect_modifier_to_outcome),
  )
  let outcome = dgp_add_bias(
    dgp_add(base, treated.mul(self.weights.treatment_to_outcome)),
    self.bias.confounder_to_outcome,
  )
  let control = dgp_add_bias(
    dgp_add(
      base,
      dgp_zeros(sample_size, treatment_count).mul(
        self.weights.treatment_to_outcome,
      ),
    ),
    self.bias.confounder_to_outcome,
  )
  let treated_outcome = dgp_add_bias(
    dgp_add(
      base,
      dgp_ones(sample_size, treatment_count).mul(
        self.weights.treatment_to_outcome,
      ),
    ),
    self.bias.confounder_to_outcome,
  )
  self.true_value = dgp_mean_columns(dgp_subtract(treated_outcome, control))
  dgp_frame([
    (config.effect_modifier, effect_modifier),
    (config.confounder, confounder),
    (config.treatment, treated),
    (config.outcome, outcome),
  ])
}
