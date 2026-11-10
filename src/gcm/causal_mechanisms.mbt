///|
/// The causal mechanisms of the `gcm` package.
///
/// This is the port of `dowhy.gcm.causal_mechanisms` and of the stochastic
/// models of `dowhy.gcm.stochastic_models`. A causal mechanism describes how
/// the value of a node with parents comes from the values of its parents.

///|
/// The kind of a distribution of a noise term.
pub enum StochasticModelKind {
  ///
  /// The distribution is represented by the samples it was fitted on.
  Empirical
  ///
  /// The distribution is a normal distribution.
  Normal
  ///
  /// The distribution is a Laplace distribution.
  Laplace
  ///
  /// The distribution is a uniform distribution.
  Uniform
  ///
  /// The distribution is a beta distribution.
  Beta
  ///
  /// The distribution is represented by the categories it was fitted on.
  EmpiricalCategorical
}

///|
/// The distribution of the noise term of a causal mechanism.
///
/// This is the port of `dowhy.gcm.stochastic_models.StochasticModel`. The
/// upstream has a parametric distribution of every scipy family and a Bayesian
/// Gaussian mixture; the port has the empirical distribution and three
/// parametric families.
pub struct StochasticModel {
  kind : StochasticModelKind
  /// The samples of an empirical distribution.
  samples : Array[Double]
  /// The categories of a categorical distribution.
  categories : Array[String]
  /// The location of a parametric distribution.
  loc : Double
  /// The scale of a parametric distribution.
  scale : Double
  /// The first shape parameter of a beta distribution.
  shape_a : Double
  /// The second shape parameter of a beta distribution.
  shape_b : Double
  /// Whether the parameters of a parametric distribution are fixed.
  fixed_parameters : Bool
  /// Whether the model has been fitted.
  fitted : Bool
}

///|
/// An unfitted empirical distribution.
///
/// This is the port of `dowhy.gcm.stochastic_models.EmpiricalDistribution`. The
/// distribution is represented by the samples it is fitted on, so it can model
/// every kind of data but never produces a value that was not observed.
pub fn StochasticModel::empirical() -> StochasticModel {
  {
    kind: Empirical,
    samples: [],
    categories: [],
    loc: 0.0,
    scale: 0.0,
    shape_a: 1.0,
    shape_b: 1.0,
    fixed_parameters: false,
    fitted: false,
  }
}

///|
/// An unfitted categorical distribution.
///
/// This is the port of the categorical case of
/// `dowhy.gcm.stochastic_models.EmpiricalDistribution`. The distribution draws
/// one of the categories it was fitted on.
pub fn StochasticModel::empirical_categorical() -> StochasticModel {
  {
    kind: EmpiricalCategorical,
    samples: [],
    categories: [],
    loc: 0.0,
    scale: 0.0,
    shape_a: 1.0,
    shape_b: 1.0,
    fixed_parameters: false,
    fitted: false,
  }
}

///|
/// A normal distribution with the given location and scale.
///
/// This is the port of
/// `dowhy.gcm.stochastic_models.ScipyDistribution(scipy.stats.norm, ...)`.
pub fn StochasticModel::normal(loc : Double, scale : Double) -> StochasticModel {
  {
    kind: Normal,
    samples: [],
    categories: [],
    loc,
    scale,
    shape_a: 1.0,
    shape_b: 1.0,
    fixed_parameters: true,
    fitted: true,
  }
}

///|
/// A Laplace distribution with the given location and scale.
///
/// This is the port of
/// `dowhy.gcm.stochastic_models.ScipyDistribution(scipy.stats.laplace, ...)`.
pub fn StochasticModel::laplace(
  loc : Double,
  scale : Double,
) -> StochasticModel {
  {
    kind: Laplace,
    samples: [],
    categories: [],
    loc,
    scale,
    shape_a: 1.0,
    shape_b: 1.0,
    fixed_parameters: true,
    fitted: true,
  }
}

///|
/// A uniform distribution with the given location and scale.
///
/// This is the port of
/// `dowhy.gcm.stochastic_models.ScipyDistribution(scipy.stats.uniform, ...)`.
/// The support of the distribution is the interval that goes from the location
/// to the location plus the scale, like the one of scipy, so that
/// `uniform(0.0, 1.0)` is the uniform distribution on `[0, 1]`.
pub fn StochasticModel::uniform(
  loc : Double,
  scale : Double,
) -> StochasticModel {
  {
    kind: Uniform,
    samples: [],
    categories: [],
    loc,
    scale,
    shape_a: 1.0,
    shape_b: 1.0,
    fixed_parameters: true,
    fitted: true,
  }
}

///|
/// A beta distribution with the given shapes.
///
/// This is the port of
/// `dowhy.gcm.stochastic_models.ScipyDistribution(scipy.stats.beta, a=..., b=...)`.
/// The support of the distribution is the interval that goes from the location
/// to the location plus the scale, like the support of scipy, so that
/// `beta(2.0, 2.0)` is the beta distribution on `[0, 1]`.
pub fn StochasticModel::beta(a : Double, b : Double) -> StochasticModel {
  {
    kind: Beta,
    samples: [],
    categories: [],
    loc: 0.0,
    scale: 1.0,
    shape_a: a,
    shape_b: b,
    fixed_parameters: true,
    fitted: true,
  }
}

///|
/// The kind of the distribution.
pub fn StochasticModel::kind(self : StochasticModel) -> StochasticModelKind {
  self.kind
}

///|
/// Whether the model has been fitted.
pub fn StochasticModel::is_fitted(self : StochasticModel) -> Bool {
  self.fitted
}

///|
/// The samples of an empirical distribution.
pub fn StochasticModel::samples(self : StochasticModel) -> Array[Double] {
  self.samples.copy()
}

///|
/// The location of a parametric distribution.
pub fn StochasticModel::loc(self : StochasticModel) -> Double {
  self.loc
}

///|
/// The scale of a parametric distribution.
pub fn StochasticModel::scale(self : StochasticModel) -> Double {
  self.scale
}

///|
/// The first shape parameter of a beta distribution.
pub fn StochasticModel::shape_a(self : StochasticModel) -> Double {
  self.shape_a
}

///|
/// The second shape parameter of a beta distribution.
pub fn StochasticModel::shape_b(self : StochasticModel) -> Double {
  self.shape_b
}

///|
/// The parameters of the distribution.
///
/// This is the port of the `parameters` property of
/// `dowhy.gcm.stochastic_models.ScipyDistribution`. The parameters of a beta
/// distribution are its two shapes, and every parametric distribution of the
/// port has a location and a scale.
pub fn StochasticModel::parameters(
  self : StochasticModel,
) -> Map[String, Double] {
  let parameters : Map[String, Double] = Map([])
  match self.kind {
    Beta => {
      let _ = parameters.set("a", self.shape_a)
      let _ = parameters.set("b", self.shape_b)
    }
    _ => ()
  }
  let _ = parameters.set("loc", self.loc)
  let _ = parameters.set("scale", self.scale)
  parameters
}

///|
/// The distribution whose parameters are estimated when it is fitted.
///
/// This is the port of
/// `dowhy.gcm.stochastic_models.ScipyDistribution(distribution)` without the
/// parameters: the upstream estimates them from the data, and so does the
/// port. A distribution whose parameters were given keeps them, which is what
/// the upstream does as well.
pub fn StochasticModel::with_estimated_parameters(
  self : StochasticModel,
) -> StochasticModel {
  {
    kind: self.kind,
    samples: self.samples.copy(),
    categories: self.categories.copy(),
    loc: self.loc,
    scale: self.scale,
    shape_a: self.shape_a,
    shape_b: self.shape_b,
    fixed_parameters: false,
    fitted: false,
  }
}

///|
/// Fit the distribution on the given samples.
///
/// The result is a new model; the model the fit is called on stays as it is.
/// The parameters of a parametric distribution are estimated the way scipy
/// estimates them, so that a distribution that is fitted on the samples of
/// another one gets the same parameters.
pub fn StochasticModel::fit(
  self : StochasticModel,
  x : Array[Double],
) -> StochasticModel {
  if self.fixed_parameters {
    // The upstream keeps the parameters of a distribution that was given them,
    // and only fits the ones that were left open.
    return {
      kind: self.kind,
      samples: self.samples.copy(),
      categories: self.categories.copy(),
      loc: self.loc,
      scale: self.scale,
      shape_a: self.shape_a,
      shape_b: self.shape_b,
      fixed_parameters: true,
      fitted: true,
    }
  }
  match self.kind {
    Empirical =>
      {
        kind: Empirical,
        samples: x.copy(),
        categories: self.categories.copy(),
        loc: self.loc,
        scale: self.scale,
        shape_a: self.shape_a,
        shape_b: self.shape_b,
        fixed_parameters: false,
        fitted: true,
      }
    EmpiricalCategorical =>
      {
        kind: EmpiricalCategorical,
        samples: self.samples.copy(),
        categories: self.categories.copy(),
        loc: self.loc,
        scale: self.scale,
        shape_a: self.shape_a,
        shape_b: self.shape_b,
        fixed_parameters: false,
        fitted: true,
      }
    Normal => {
      let loc = @utils.mean(x)
      let scale = @utils.std(x)
      {
        kind: Normal,
        samples: self.samples.copy(),
        categories: self.categories.copy(),
        loc,
        scale,
        shape_a: self.shape_a,
        shape_b: self.shape_b,
        fixed_parameters: false,
        fitted: true,
      }
    }
    Laplace => {
      let loc = median(x)
      let deviations : Array[Double] = []
      for value in x {
        deviations.push((value - loc).abs())
      }
      let scale = @utils.mean(deviations)
      {
        kind: Laplace,
        samples: self.samples.copy(),
        categories: self.categories.copy(),
        loc,
        scale,
        shape_a: self.shape_a,
        shape_b: self.shape_b,
        fixed_parameters: false,
        fitted: true,
      }
    }
    Uniform => {
      // The maximum likelihood estimate of the uniform distribution of scipy
      // is the smallest and the largest of the samples, so that the support of
      // the fitted distribution is the range of the samples.
      let mut lowest = x[0]
      let mut highest = x[0]
      for value in x {
        if value < lowest {
          lowest = value
        }
        if value > highest {
          highest = value
        }
      }
      let scale = highest - lowest
      {
        kind: Uniform,
        samples: self.samples.copy(),
        categories: self.categories.copy(),
        loc: lowest,
        scale,
        shape_a: self.shape_a,
        shape_b: self.shape_b,
        fixed_parameters: false,
        fitted: true,
      }
    }
    Beta => {
      // The support of the fitted beta distribution is the range of the
      // samples, and the shapes are the method of moments estimates of the
      // samples that are normalised with that support. The upstream estimates
      // the four parameters with the maximum likelihood, which gives the same
      // shapes up to the tolerance of its test.
      let mut lowest = x[0]
      let mut highest = x[0]
      for value in x {
        if value < lowest {
          lowest = value
        }
        if value > highest {
          highest = value
        }
      }
      let scale = highest - lowest
      if scale <= 0.0 {
        abort(
          "the samples of a beta distribution have to hold two different values",
        )
      }
      let normalised : Array[Double] = []
      for value in x {
        normalised.push((value - lowest) / scale)
      }
      let mean = @utils.mean(normalised)
      let variance = @utils.variance(normalised, 0)
      // The mean and the variance of a beta distribution with the shapes `a`
      // and `b` are `a / (a + b)` and `a * b / ((a + b) * (a + b + 1))`, which
      // gives the shapes of the method of moments.
      let factor = mean * (1.0 - mean) / variance - 1.0
      let a = mean * factor
      let b = (1.0 - mean) * factor
      {
        kind: Beta,
        samples: self.samples.copy(),
        categories: self.categories.copy(),
        loc: lowest,
        scale,
        shape_a: a,
        shape_b: b,
        fixed_parameters: false,
        fitted: true,
      }
    }
  }
}

///|
/// Draw samples from the distribution.
///
/// The upstream draws them from the global numpy generator; the port draws them
/// from the given generator, so that the same generator always gives the same
/// samples.
pub fn StochasticModel::draw_samples(
  self : StochasticModel,
  num_samples : Int32,
  rng : @utils.Random,
) -> Array[Double] {
  if !self.fitted {
    abort("the stochastic model has not been fitted")
  }
  let out : Array[Double] = []
  match self.kind {
    Empirical => {
      if self.samples.length() == 0 {
        abort("the empirical distribution has no sample to draw from")
      }
      for value in rng.sample_with_replacement(self.samples, num_samples) {
        out.push(value)
      }
    }
    Normal =>
      for _ in 0..<num_samples {
        out.push(self.loc + self.scale * rng.next_normal())
      }
    Laplace =>
      for _ in 0..<num_samples {
        // The inverse of the cumulative distribution of the Laplace
        // distribution, which is what scipy draws from as well.
        let u = rng.next_double() - 0.5
        let magnitude = (1.0 - 2.0 * u.abs()).abs()
        let sign = if u < 0.0 { -1.0 } else { 1.0 }
        out.push(self.loc - self.scale * sign * @math.ln(magnitude))
      }
    Uniform =>
      for _ in 0..<num_samples {
        // The support of the uniform distribution is the interval that goes
        // from the location to the location plus the scale, like the one of
        // scipy.
        out.push(self.loc + self.scale * rng.next_double())
      }
    Beta =>
      for _ in 0..<num_samples {
        // A beta variate is the ratio of two gamma variates with the shapes
        // of the distribution, the way the ratio of two independent gamma
        // variates has the beta distribution. numpy draws its beta variates
        // with the algorithm of Johnk, so the samples of the port and of the
        // upstream are different numbers of the same distribution.
        let first = rng.next_gamma(self.shape_a, 1.0)
        let second = rng.next_gamma(self.shape_b, 1.0)
        out.push(self.loc + self.scale * first / (first + second))
      }
    EmpiricalCategorical =>
      abort("a categorical distribution draws categorical samples")
  }
  out
}

///|
/// The continuous distribution that fits the given samples the best.
///
/// This is the port of
/// `dowhy.gcm.stochastic_models.ScipyDistribution.find_suitable_continuous_distribution`.
/// Every family the port knows is fitted on the samples, samples are drawn
/// from the fitted distribution, and the two samples are compared with the
/// Kullback-Leibler divergence of the nearest neighbour estimator. The first
/// family whose divergence is below the threshold is the one that is returned,
/// and the family with the smallest divergence is the one that is returned when
/// no family reaches the threshold.
///
/// The upstream fits every continuous distribution of scipy, the port fits the
/// four families it knows.
pub fn find_suitable_continuous_distribution(
  samples : Array[Double],
  rng : @utils.Random,
  divergence_threshold : Double,
) -> StochasticModel {
  if samples.length() == 0 {
    abort("the samples of a distribution cannot be empty")
  }
  let observed = @utils.Matrix::from_columns([samples])
  let candidates : Array[StochasticModel] = [
    StochasticModel::normal(0.0, 1.0),
    StochasticModel::laplace(0.0, 1.0),
    StochasticModel::uniform(0.0, 1.0),
    StochasticModel::beta(1.0, 1.0),
  ]
  let mut best = candidates[0].with_estimated_parameters().fit(samples)
  let mut smallest = 1.0e308
  for candidate in candidates {
    let fitted = candidate.with_estimated_parameters().fit(samples)
    let generated = fitted.draw_samples(samples.length(), rng)
    let divergence = estimate_kl_divergence_continuous_knn(
      observed,
      @utils.Matrix::from_columns([generated]),
      1,
      true,
    )
    if divergence < divergence_threshold {
      return fitted
    }
    if divergence < smallest {
      smallest = divergence
      best = fitted
    }
  }
  best
}

///|
/// The categories of a categorical distribution.
pub fn StochasticModel::categories(self : StochasticModel) -> Array[String] {
  self.categories.copy()
}

///|
/// Fit a categorical distribution on the given categories.
///
/// The result is a new model; the model the fit is called on stays as it is.
pub fn StochasticModel::fit_categorical(
  self : StochasticModel,
  x : Array[String],
) -> StochasticModel {
  {
    kind: EmpiricalCategorical,
    samples: self.samples.copy(),
    categories: x.copy(),
    loc: self.loc,
    scale: self.scale,
    shape_a: self.shape_a,
    shape_b: self.shape_b,
    fixed_parameters: false,
    fitted: true,
  }
}

///|
/// Draw samples of the categories of a categorical distribution.
///
/// The upstream draws them from the global numpy generator; the port draws them
/// from the given generator, so that the same generator always gives the same
/// samples.
pub fn StochasticModel::draw_category_samples(
  self : StochasticModel,
  num_samples : Int32,
  rng : @utils.Random,
) -> Array[String] {
  if !self.fitted {
    abort("the stochastic model has not been fitted")
  }
  if self.categories.length() == 0 {
    abort("the categorical distribution has no category to draw from")
  }
  let out : Array[String] = []
  for _ in 0..<num_samples {
    out.push(self.categories[rng.next_int(self.categories.length())])
  }
  out
}

///|
/// A copy of the model.
///
/// This is the port of `dowhy.gcm.stochastic_models.ScipyDistribution.clone`
/// and of `dowhy.gcm.stochastic_models.EmpiricalDistribution.clone`. The clone
/// of a distribution is not fitted: the samples of an empirical distribution
/// and the estimated parameters of a parametric one are the result of a fit.
/// The parameters that were given to a distribution are its hyper parameters,
/// so the clone of such a distribution keeps them.
pub fn StochasticModel::clone(self : StochasticModel) -> StochasticModel {
  if self.fixed_parameters {
    return {
      kind: self.kind,
      samples: [],
      categories: [],
      loc: self.loc,
      scale: self.scale,
      shape_a: self.shape_a,
      shape_b: self.shape_b,
      fixed_parameters: true,
      fitted: true,
    }
  }
  {
    kind: self.kind,
    samples: [],
    categories: [],
    loc: 0.0,
    scale: 0.0,
    shape_a: 1.0,
    shape_b: 1.0,
    fixed_parameters: false,
    fitted: false,
  }
}

///|
/// The kind of a causal mechanism.
pub enum CausalMechanismKind {
  ///
  /// The continuous additive noise model `Y = f(X) + N`.
  AdditiveNoise
  ///
  /// The discrete additive noise model `Y = round(f(X)) + N`.
  DiscreteAdditiveNoise
  ///
  /// The post non-linear model `Y = g(f(X) + N)`.
  PostNonlinear
  ///
  /// The categorical model `Y = f(X, N)`, which draws a class with the
  /// probabilities of a classifier.
  Classifier
}

///|
/// The generative model of a node that has parents.
///
/// This is the port of `dowhy.gcm.causal_mechanisms.FunctionalCausalModel` and
/// of its subclasses. The upstream models are classes; the port is a single
/// struct with a kind, because MoonBit has no inheritance.
pub struct CausalMechanism {
  kind : CausalMechanismKind
  /// The model of the mean of the target.
  prediction_model : PredictionModel
  /// The classifier of the categorical model.
  classifier_model : ClassificationModel
  /// The distribution of the noise.
  noise_model : StochasticModel
  /// The function that is applied to the sum of the prediction and the noise.
  invertible_function : InvertibleFunction
}

///|
/// An additive noise model `Y = f(X) + N` with an empirical noise.
///
/// This is the port of `dowhy.gcm.causal_mechanisms.AdditiveNoiseModel`.
pub fn CausalMechanism::additive_noise(
  prediction_model : PredictionModel,
) -> CausalMechanism {
  CausalMechanism::additive_noise_with(
    prediction_model,
    StochasticModel::empirical(),
  )
}

///|
/// An additive noise model `Y = f(X) + N` with the given noise.
///
/// This is the port of `dowhy.gcm.causal_mechanisms.AdditiveNoiseModel`.
pub fn CausalMechanism::additive_noise_with(
  prediction_model : PredictionModel,
  noise_model : StochasticModel,
) -> CausalMechanism {
  {
    kind: AdditiveNoise,
    prediction_model,
    classifier_model: ClassificationModel::logistic(),
    noise_model,
    invertible_function: Identity,
  }
}

///|
/// A discrete additive noise model `Y = round(f(X)) + N` with an empirical
/// noise.
///
/// This is the port of
/// `dowhy.gcm.causal_mechanisms.DiscreteAdditiveNoiseModel`.
pub fn CausalMechanism::discrete_additive_noise(
  prediction_model : PredictionModel,
) -> CausalMechanism {
  {
    kind: DiscreteAdditiveNoise,
    prediction_model,
    classifier_model: ClassificationModel::logistic(),
    noise_model: StochasticModel::empirical(),
    invertible_function: Identity,
  }
}

///|
/// A post non-linear model `Y = g(f(X) + N)`.
///
/// This is the port of `dowhy.gcm.causal_mechanisms.PostNonlinearModel`.
pub fn CausalMechanism::post_nonlinear(
  prediction_model : PredictionModel,
  noise_model : StochasticModel,
  invertible_function : InvertibleFunction,
) -> CausalMechanism {
  {
    kind: PostNonlinear,
    prediction_model,
    classifier_model: ClassificationModel::logistic(),
    noise_model,
    invertible_function,
  }
}

///|
/// A categorical model `Y = f(X, N)` that draws a class with the probabilities
/// of a classifier.
///
/// This is the port of `dowhy.gcm.causal_mechanisms.ClassifierFCM`.
pub fn CausalMechanism::classifier(
  classifier_model : ClassificationModel,
) -> CausalMechanism {
  {
    kind: Classifier,
    prediction_model: PredictionModel::linear(),
    classifier_model,
    noise_model: StochasticModel::empirical(),
    invertible_function: Identity,
  }
}

///|
/// The kind of the mechanism.
pub fn CausalMechanism::kind(self : CausalMechanism) -> CausalMechanismKind {
  self.kind
}

///|
/// The model of the mean of the target.
pub fn CausalMechanism::prediction_model(
  self : CausalMechanism,
) -> PredictionModel {
  self.prediction_model
}

///|
/// The classifier of the categorical model.
pub fn CausalMechanism::classifier_model(
  self : CausalMechanism,
) -> ClassificationModel {
  self.classifier_model
}

///|
/// The distribution of the noise.
pub fn CausalMechanism::noise_model(self : CausalMechanism) -> StochasticModel {
  self.noise_model
}

///|
/// The function that is applied to the sum of the prediction and the noise.
pub fn CausalMechanism::invertible_function(
  self : CausalMechanism,
) -> InvertibleFunction {
  self.invertible_function
}

///|
/// Fit the mechanism on the given data.
///
/// The result is a new mechanism; the mechanism the fit is called on stays as
/// it is. The prediction is fitted on the target, or on the inverse of the
/// target when the mechanism has an invertible function, and the noise is the
/// residual of that fit.
pub fn CausalMechanism::fit(
  self : CausalMechanism,
  x : @utils.Matrix,
  y : Array[Double],
) -> CausalMechanism {
  if is_classifier_kind(self.kind) {
    abort("a classifier mechanism is fitted with categorical labels")
  }
  if is_discrete_additive_noise_kind(self.kind) && !is_discrete(y) {
    abort(
      "a discrete additive noise model cannot be fitted to a continuous target",
    )
  }
  match self.kind {
    DiscreteAdditiveNoise => {
      let prediction_model = self.prediction_model.fit(x, y)
      let residuals = residual_differences(
        y,
        rounded_predictions(prediction_model, x),
      )
      {
        kind: self.kind,
        prediction_model,
        classifier_model: self.classifier_model.clone(),
        noise_model: self.noise_model.fit(residuals),
        invertible_function: self.invertible_function,
      }
    }
    _ => {
      let inverse = self.invertible_function.evaluate_inverse(y)
      let prediction_model = self.prediction_model.fit(x, inverse)
      let residuals = residual_differences(inverse, prediction_model.predict(x))
      {
        kind: self.kind,
        prediction_model,
        classifier_model: self.classifier_model.clone(),
        noise_model: self.noise_model.fit(residuals),
        invertible_function: self.invertible_function,
      }
    }
  }
}

///|
/// Fit the categorical mechanism on the given labels.
///
/// The result is a new mechanism; the mechanism the fit is called on stays as
/// it is.
pub fn CausalMechanism::fit_categorical(
  self : CausalMechanism,
  x : @utils.Matrix,
  y : Array[String],
) -> CausalMechanism {
  if !is_classifier_kind(self.kind) {
    abort("a continuous mechanism is fitted with continuous values")
  }
  {
    kind: self.kind,
    prediction_model: self.prediction_model.clone(),
    classifier_model: self.classifier_model.fit(x, y),
    noise_model: self.noise_model.clone(),
    invertible_function: self.invertible_function,
  }
}

///|
/// The noise that the given target and parents imply.
///
/// This is the port of
/// `dowhy.gcm.causal_mechanisms.InvertibleFunctionalCausalModel.estimate_noise`.
pub fn CausalMechanism::estimate_noise(
  self : CausalMechanism,
  y : Array[Double],
  x : @utils.Matrix,
) -> Array[Double] {
  if is_classifier_kind(self.kind) {
    abort("a classifier mechanism has no continuous noise")
  }
  match self.kind {
    DiscreteAdditiveNoise =>
      residual_differences(y, rounded_predictions(self.prediction_model, x))
    _ => {
      let inverse = self.invertible_function.evaluate_inverse(y)
      residual_differences(inverse, self.prediction_model.predict(x))
    }
  }
}

///|
/// The value of the target for the given parents and noise.
///
/// This is the port of
/// `dowhy.gcm.causal_mechanisms.FunctionalCausalModel.evaluate`.
pub fn CausalMechanism::evaluate(
  self : CausalMechanism,
  x : @utils.Matrix,
  noise : Array[Double],
) -> Array[Double] {
  if is_classifier_kind(self.kind) {
    abort("a classifier mechanism is evaluated with categorical labels")
  }
  match self.kind {
    DiscreteAdditiveNoise => {
      let predictions = rounded_predictions(self.prediction_model, x)
      let out : Array[Double] = []
      for i = 0; i < predictions.length(); i = i + 1 {
        out.push(predictions[i] + noise[i])
      }
      out
    }
    _ => {
      let predictions = self.prediction_model.predict(x)
      let sums : Array[Double] = []
      for i = 0; i < predictions.length(); i = i + 1 {
        sums.push(predictions[i] + noise[i])
      }
      self.invertible_function.evaluate(sums)
    }
  }
}

///|
/// The class of the target for the given parents and noise.
///
/// This is the port of
/// `dowhy.gcm.causal_mechanisms.ClassifierFCM.evaluate`. The noise is a value
/// on `[0, 1]`; the class is the first one whose cumulative probability
/// reaches it.
pub fn CausalMechanism::evaluate_categorical(
  self : CausalMechanism,
  x : @utils.Matrix,
  noise : Array[Double],
) -> Array[String] {
  if !is_classifier_kind(self.kind) {
    abort("a continuous mechanism is evaluated with continuous values")
  }
  let classes = self.classifier_model.classes()
  let probabilities = self.classifier_model.predict_probabilities(x)
  let out : Array[String] = []
  for i = 0; i < probabilities.length(); i = i + 1 {
    let row = probabilities[i]
    let mut index = 0
    let mut cumulative = row[0]
    if cumulative < noise[i] {
      index = 1
      cumulative = cumulative + row[1]
      if cumulative < noise[i] {
        // No class reaches the noise, which is what the upstream does as well:
        // the first class is taken.
        index = 0
      }
    }
    out.push(classes[index])
  }
  out
}

///|
/// Draw samples of the target for the given parents.
///
/// The upstream draws the noise from the distribution of the mechanism; the
/// port draws it from the given generator, so that the same generator always
/// gives the same samples.
pub fn CausalMechanism::draw_samples(
  self : CausalMechanism,
  x : @utils.Matrix,
  rng : @utils.Random,
) -> Array[Double] {
  if is_classifier_kind(self.kind) {
    abort("a classifier mechanism draws categorical samples")
  }
  let noise = self.noise_model.draw_samples(x.nrows(), rng)
  self.evaluate(x, noise)
}

///|
/// The noise of a categorical mechanism, drawn uniformly on `[0, 1]`.
///
/// This is the port of
/// `dowhy.gcm.causal_mechanisms.ClassifierFCM.draw_noise_samples`. The noise of
/// a categorical mechanism is uniform on `[0, 1]`, which is what the upstream
/// does as well.
pub fn CausalMechanism::draw_categorical_noise(
  self : CausalMechanism,
  count : Int32,
  rng : @utils.Random,
) -> Array[Double] {
  if !is_classifier_kind(self.kind) {
    abort("a continuous mechanism has no categorical noise")
  }
  let noise : Array[Double] = []
  for _ in 0..<count {
    noise.push(rng.next_double())
  }
  noise
}

///|
/// Draw samples of the class of the target for the given parents.
///
/// The noise of a categorical mechanism is uniform on `[0, 1]`, which is what
/// the upstream does as well.
pub fn CausalMechanism::draw_categorical_samples(
  self : CausalMechanism,
  x : @utils.Matrix,
  rng : @utils.Random,
) -> Array[String] {
  if !is_classifier_kind(self.kind) {
    abort("a continuous mechanism draws continuous samples")
  }
  self.evaluate_categorical(x, self.draw_categorical_noise(x.nrows(), rng))
}

///|
/// A copy of the mechanism.
///
/// This is the port of `dowhy.gcm.causal_mechanisms.AdditiveNoiseModel.clone`,
/// of its discrete and of its post non-linear counterpart. The clone of a
/// mechanism is not fitted, because the prediction model and the noise model it
/// holds are cloned without their fit.
pub fn CausalMechanism::clone(self : CausalMechanism) -> CausalMechanism {
  {
    kind: self.kind,
    prediction_model: self.prediction_model.clone(),
    classifier_model: self.classifier_model.clone(),
    noise_model: self.noise_model.clone(),
    invertible_function: self.invertible_function,
  }
}

///|
/// Whether the kind is the kind of the categorical model.
pub fn is_classifier_kind(kind : CausalMechanismKind) -> Bool {
  match kind {
    Classifier => true
    _ => false
  }
}

///|
/// Whether the kind is the kind of the discrete additive noise model.
pub fn is_discrete_additive_noise_kind(kind : CausalMechanismKind) -> Bool {
  match kind {
    DiscreteAdditiveNoise => true
    _ => false
  }
}

///|
/// The predictions of the model, rounded to whole numbers.
fn rounded_predictions(
  prediction_model : PredictionModel,
  x : @utils.Matrix,
) -> Array[Double] {
  let out : Array[Double] = []
  for value in prediction_model.predict(x) {
    out.push(@utils.round_half_even(value))
  }
  out
}

///|
/// The difference of the target and the prediction, row by row.
fn residual_differences(
  y : Array[Double],
  predictions : Array[Double],
) -> Array[Double] {
  let out : Array[Double] = []
  let n = if y.length() < predictions.length() {
    y.length()
  } else {
    predictions.length()
  }
  for i = 0; i < n; i = i + 1 {
    out.push(y[i] - predictions[i])
  }
  out
}

///|
/// The median of the values.
fn median(values : Array[Double]) -> Double {
  if values.length() == 0 {
    return 0.0
  }
  let sorted = values.copy()
  sorted.sort_by(fn(a, b) { if a < b { -1 } else if a > b { 1 } else { 0 } })
  let middle = sorted.length() / 2
  if sorted.length() % 2 == 1 {
    sorted[middle]
  } else {
    (sorted[middle - 1] + sorted[middle]) / 2.0
  }
}
