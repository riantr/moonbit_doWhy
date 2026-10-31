///|
/// The anomaly scorers of the `gcm` package.
///
/// This is the port of `dowhy.gcm.anomaly_scorers` and of the detection part of
/// `dowhy.gcm.anomaly`. A scorer turns a sample into a number that grows with
/// the rarity of the sample in the distribution the scorer was fitted with.

///|
/// The smallest possible value, which is used for the numerical stability of
/// the rescaled median CDF quantile scorer.
///
/// This is the port of `dowhy.gcm.constant.EPS`.
const ANOMALY_SCORER_EPS : Double = 2.220446049250313e-16

///|
/// The normalisation of the median absolute deviation, which is the third
/// quartile of the standard normal distribution.
///
/// The median absolute deviation of the upstream is the median of the absolute
/// deviations divided by this number, like `statsmodels.robust.mad` computes it.
const ANOMALY_MAD_NORMALISATION : Double = 0.6744897501960817

///|
/// The kind of an anomaly scorer.
enum AnomalyScorerKind {
  /// The score of the median of the cumulative distribution function.
  MedianCDFQuantile
  /// The negative logarithm of the score of the median CDF quantile scorer.
  RescaledMedianCDFQuantile
  /// The score of the rank of the sample in the distribution.
  RankBased
  /// The negative logarithm of the tail probability of the score of another
  /// scorer.
  IT
  /// The distance of the sample to the mean of the distribution.
  MeanDeviation
  /// The distance of the sample to the median of the distribution.
  MedianDeviation
  /// The inverse of the density of the sample.
  InverseDensity
}

///|
/// The sorted samples of a distribution, with the number of the samples that
/// are not a number.
///
/// The samples that are not a number come last, because they are neither
/// smaller nor greater than any other sample.
struct SortedDistribution {
  samples : Array[Double]
  num_not_a_number : Int32
}

///|
/// A factory of the scorers of the anomaly scores.
///
/// This is the port of the argument `anomaly_scorer_factory` of the upstream,
/// which is a callable that returns a scorer that is not fitted yet.
pub type AnomalyScorerFactory = () -> AnomalyScorer

///|
/// An anomaly scorer, fitted with the samples of a distribution.
///
/// This is the port of `dowhy.gcm.anomaly_scorer.AnomalyScorer` and of the
/// scorers of `dowhy.gcm.anomaly_scorers`. The upstream scorers are classes
/// with a `fit` and a `score` method; the port is a single struct with a kind,
/// because MoonBit has no inheritance. The fit returns a new scorer, so a
/// scorer that is not fitted stays as it is.
pub struct AnomalyScorer {
  kind : AnomalyScorerKind
  /// The kind of the wrapped scorer, for the information theoretic scorer.
  base_kind : AnomalyScorerKind?
  /// The sorted samples of the distribution the scorer was fitted with.
  distribution : SortedDistribution
  /// The mean of the distribution.
  mean : Double
  /// The standard deviation of the distribution.
  standard_deviation : Double
  /// The median of the distribution.
  median : Double
  /// The median absolute deviation of the distribution.
  mad : Double
  /// The scores of the distribution samples, which the information theoretic
  /// scorer needs.
  scores_of_distribution_samples : Array[Double]
  /// The density estimator, which the inverse density scorer needs.
  density_estimator : DensityEstimator
}

///|
/// A scorer of the given kind that is not fitted yet.
fn AnomalyScorer::new(kind : AnomalyScorerKind) -> AnomalyScorer {
  {
    kind,
    base_kind: None,
    distribution: { samples: [], num_not_a_number: 0, },
    mean: 0.0,
    standard_deviation: 0.0,
    median: 0.0,
    mad: 0.0,
    scores_of_distribution_samples: [],
    density_estimator: DensityEstimator::kernel_1d(),
  }
}

///|
/// A scorer of the median of the cumulative distribution function.
///
/// This is the port of
/// `dowhy.gcm.anomaly_scorers.MedianCDFQuantileScorer`.
pub fn AnomalyScorer::median_cdf_quantile() -> AnomalyScorer {
  AnomalyScorer::new(MedianCDFQuantile)
}

///|
/// A scorer of the negative logarithm of the score of the median CDF quantile
/// scorer.
///
/// This is the port of
/// `dowhy.gcm.anomaly_scorers.RescaledMedianCDFQuantileScorer`.
pub fn AnomalyScorer::rescaled_median_cdf_quantile() -> AnomalyScorer {
  AnomalyScorer::new(RescaledMedianCDFQuantile)
}

///|
/// A scorer of the rank of the sample in the distribution.
///
/// This is the port of `dowhy.gcm.anomaly_scorers.RankBasedAnomalyScorer`.
pub fn AnomalyScorer::rank_based() -> AnomalyScorer {
  AnomalyScorer::new(RankBased)
}

///|
/// A scorer of the negative logarithm of the tail probability of the score of
/// another scorer.
///
/// This is the port of `dowhy.gcm.anomaly_scorers.ITAnomalyScorer`. The scorer
/// it wraps is the one of the argument, like the scorer of the upstream.
pub fn AnomalyScorer::information_theoretic(
  base : AnomalyScorer,
) -> AnomalyScorer {
  let base_kind = match base.base_kind {
    Some(kind) => kind
    None => base.kind
  }
  let scorer = AnomalyScorer::new(IT)
  {
    kind: scorer.kind,
    base_kind: Some(base_kind),
    distribution: scorer.distribution,
    mean: scorer.mean,
    standard_deviation: scorer.standard_deviation,
    median: scorer.median,
    mad: scorer.mad,
    scores_of_distribution_samples: scorer.scores_of_distribution_samples,
    density_estimator: scorer.density_estimator,
  }
}

///|
/// A scorer of the distance of the sample to the mean of the distribution.
///
/// This is the port of `dowhy.gcm.anomaly_scorers.MeanDeviationScorer`.
pub fn AnomalyScorer::mean_deviation() -> AnomalyScorer {
  AnomalyScorer::new(MeanDeviation)
}

///|
/// A scorer of the distance of the sample to the median of the distribution.
///
/// This is the port of `dowhy.gcm.anomaly_scorers.MedianDeviationScorer`.
pub fn AnomalyScorer::median_deviation() -> AnomalyScorer {
  AnomalyScorer::new(MedianDeviation)
}

///|
/// A scorer of the inverse of the density of the sample.
///
/// This is the port of `dowhy.gcm.anomaly_scorers.InverseDensityScorer`.
pub fn AnomalyScorer::inverse_density() -> AnomalyScorer {
  AnomalyScorer::new(InverseDensity)
}

///|
/// Fit the scorer with the samples of the distribution it scores.
///
/// The result is a new scorer; the scorer the fit is called on stays as it is.
pub fn AnomalyScorer::fit(
  self : AnomalyScorer,
  distribution_samples : Array[Double],
) -> AnomalyScorer {
  if distribution_samples.length() == 0 {
    abort("an anomaly scorer cannot be fitted on an empty sample")
  }
  let fitted = {
    kind: self.kind,
    base_kind: self.base_kind,
    distribution: sort_distribution(distribution_samples),
    mean: @utils.mean(distribution_samples),
    standard_deviation: @utils.std(distribution_samples),
    median: median_of(distribution_samples),
    mad: mad_of(distribution_samples),
    scores_of_distribution_samples: [],
    density_estimator: DensityEstimator::kernel_1d().fit(distribution_samples),
  }
  match fitted.kind {
    IT => {
      let base_scores = fitted.base_scores(
        fitted.base_kind,
        fitted.distribution.samples,
      )
      {
        kind: fitted.kind,
        base_kind: fitted.base_kind,
        distribution: fitted.distribution,
        mean: fitted.mean,
        standard_deviation: fitted.standard_deviation,
        median: fitted.median,
        mad: fitted.mad,
        scores_of_distribution_samples: base_scores,
        density_estimator: fitted.density_estimator,
      }
    }
    _ => fitted
  }
}

///|
/// The anomaly score of every given sample.
///
/// The higher the score, the more anomalous the sample is.
pub fn AnomalyScorer::score(
  self : AnomalyScorer,
  samples : Array[Double],
) -> Array[Double] {
  match self.kind {
    MedianCDFQuantile => median_cdf_scores(self.distribution, samples)
    RescaledMedianCDFQuantile =>
      rescaled_median_cdf_scores(self.distribution, samples)
    RankBased => rank_based_scores(self.distribution, samples)
    IT => self.information_theoretic_scores(self.base_kind, samples)
    MeanDeviation =>
      mean_deviation_scores(self.mean, self.standard_deviation, samples)
    MedianDeviation => median_deviation_scores(self.median, self.mad, samples)
    InverseDensity => inverse_density_scores(self.density_estimator, samples)
  }
}

///|
/// The scores of the wrapped scorer, which the information theoretic scorer
/// needs.
fn AnomalyScorer::base_scores(
  self : AnomalyScorer,
  base : AnomalyScorerKind?,
  samples : Array[Double],
) -> Array[Double] {
  match base {
    Some(MedianCDFQuantile) => median_cdf_scores(self.distribution, samples)
    Some(RescaledMedianCDFQuantile) =>
      rescaled_median_cdf_scores(self.distribution, samples)
    Some(RankBased) => rank_based_scores(self.distribution, samples)
    Some(MeanDeviation) =>
      mean_deviation_scores(self.mean, self.standard_deviation, samples)
    Some(MedianDeviation) =>
      median_deviation_scores(self.median, self.mad, samples)
    Some(InverseDensity) =>
      inverse_density_scores(self.density_estimator, samples)
    Some(IT) | None =>
      abort("the information theoretic scorer needs a scorer that it wraps")
  }
}

///|
/// The information theoretic score of every given sample.
///
/// The score is the negative logarithm of the probability to get the same or a
/// higher score with the samples of the distribution.
fn AnomalyScorer::information_theoretic_scores(
  self : AnomalyScorer,
  base : AnomalyScorerKind?,
  samples : Array[Double],
) -> Array[Double] {
  let base_scores = self.base_scores(base, samples)
  let total = self.scores_of_distribution_samples.length().to_double()
  let out : Array[Double] = []
  for score in base_scores {
    let mut count = 0.0
    for distribution_score in self.scores_of_distribution_samples {
      if distribution_score >= score {
        count = count + 1.0
      }
    }
    out.push(-@math.ln((count + 0.5) / (total + 0.5)))
  }
  out
}

///|
/// The score of the median of the cumulative distribution function.
///
/// This is the port of
/// `dowhy.gcm.anomaly_scorers.MedianCDFQuantileScorer`. The score of a sample
/// is one minus twice the smaller of the two tail probabilities of the sample,
/// where a sample that equals a sample of the distribution contributes half of
/// its count to either side.
fn median_cdf_scores(
  distribution : SortedDistribution,
  samples : Array[Double],
) -> Array[Double] {
  let total = (distribution.samples.length() + 1).to_double()
  let out : Array[Double] = []
  for sample in samples {
    let (equal, greater, smaller) = counts_of(distribution, sample)
    let half = (equal.to_double() + 1.0) / 2.0
    let above = greater.to_double() + half
    let below = smaller.to_double() + half
    let tail = if above < below { above } else { below }
    out.push(1.0 - 2.0 * tail / total)
  }
  out
}

///|
/// The negative logarithm of the score of the median CDF quantile scorer.
///
/// This is the port of
/// `dowhy.gcm.anomaly_scorers.RescaledMedianCDFQuantileScorer`. The score
/// amplifies the differences of the score of the median CDF quantile scorer,
/// which is why a score of zero becomes the smallest possible value.
fn rescaled_median_cdf_scores(
  distribution : SortedDistribution,
  samples : Array[Double],
) -> Array[Double] {
  let out : Array[Double] = []
  for score in median_cdf_scores(distribution, samples) {
    let probability = 1.0 - score
    let probability = if probability == 0.0 {
      ANOMALY_SCORER_EPS
    } else {
      probability
    }
    out.push(-@math.ln(probability))
  }
  out
}

///|
/// The score of the rank of the sample in the distribution.
///
/// This is the port of `dowhy.gcm.anomaly_scorers.RankBasedAnomalyScorer`. The
/// score is the negative logarithm of the p-value of the rank of the sample
/// under the assumption that the samples are exchangeable.
fn rank_based_scores(
  distribution : SortedDistribution,
  samples : Array[Double],
) -> Array[Double] {
  let total = (distribution.samples.length() + 1).to_double()
  let out : Array[Double] = []
  for sample in samples {
    let (equal, greater, smaller) = counts_of(distribution, sample)
    let counted = equal.to_double() + 1.0
    let from_above = 2.0 * (greater.to_double() + counted) / total
    let from_below = 2.0 * (smaller.to_double() + counted) / total
    let mut p_value = from_above
    if from_below < p_value {
      p_value = from_below
    }
    if 1.0 < p_value {
      p_value = 1.0
    }
    out.push(-@math.ln(p_value))
  }
  out
}

///|
/// The distance of the sample to the mean of the distribution, scaled by the
/// standard deviation of the distribution.
///
/// This is the port of `dowhy.gcm.anomaly_scorers.MeanDeviationScorer`.
fn mean_deviation_scores(
  mean : Double,
  standard_deviation : Double,
  samples : Array[Double],
) -> Array[Double] {
  let out : Array[Double] = []
  for sample in samples {
    out.push((sample - mean).abs() / standard_deviation)
  }
  out
}

///|
/// The distance of the sample to the median of the distribution, scaled by the
/// median absolute deviation of the distribution.
///
/// This is the port of `dowhy.gcm.anomaly_scorers.MedianDeviationScorer`.
fn median_deviation_scores(
  median : Double,
  mad : Double,
  samples : Array[Double],
) -> Array[Double] {
  let out : Array[Double] = []
  for sample in samples {
    out.push((sample - median).abs() / mad)
  }
  out
}

///|
/// The inverse of the density of the sample.
///
/// This is the port of `dowhy.gcm.anomaly_scorers.InverseDensityScorer`. The
/// upstream uses the Bayesian Gaussian mixture of the upstream by default; the
/// port uses the kernel based density estimator of the upstream.
fn inverse_density_scores(
  density_estimator : DensityEstimator,
  samples : Array[Double],
) -> Array[Double] {
  let out : Array[Double] = []
  for density in density_estimator.density(samples) {
    out.push(1.0 / density)
  }
  out
}

///|
/// The conditional anomaly score of every target sample.
///
/// This is the port of `dowhy.gcm.anomaly.conditional_anomaly_scores`. The
/// score of a target sample is the score of the sample in the conditional
/// distribution of the target, which is estimated with the samples the causal
/// mechanism draws for the parents of the sample.
pub fn conditional_anomaly_scores(
  parent_samples : @utils.Matrix,
  target_samples : Array[Double],
  causal_mechanism : CausalMechanism,
  scorer_factory : AnomalyScorerFactory,
  num_samples_conditional : Int32,
  rng : @utils.Random,
) -> Array[Double] {
  if parent_samples.nrows() != target_samples.length() {
    abort("there should be as many parent samples as target samples")
  }
  let out : Array[Double] = []
  for i = 0; i < parent_samples.nrows(); i = i + 1 {
    let row = parent_samples.row(i)
    let rows : Array[Array[Double]] = []
    for _ in 0..<num_samples_conditional {
      rows.push(row.copy())
    }
    let repeated = @utils.Matrix::from_rows(rows)
    let samples = causal_mechanism.draw_samples(repeated, rng)
    let scorer = scorer_factory().fit(samples)
    out.push(scorer.score([target_samples[i]])[0])
  }
  out
}

///|
/// The anomaly score of every node of the causal model.
///
/// This is the port of `dowhy.gcm.anomaly.anomaly_scores`. A root node is
/// scored against the distribution of the model, and a node with parents is
/// scored against the conditional distribution of the node, which is estimated
/// with the mechanism of the node.
pub fn anomaly_scores(
  causal_model : ProbabilisticCausalModel,
  anomaly_data : @api.DataFrame,
  num_samples_conditional : Int32,
  num_samples_unconditional : Int32,
  scorer_factory : AnomalyScorerFactory,
  rng : @utils.Random,
) -> Map[String, Array[Double]] {
  validate_causal_dag(causal_model)
  let results : Map[String, Array[Double]] = Map([])
  for node in causal_model.nodes() {
    if is_root_node(causal_model, node) {
      let root_model = match causal_model.root_model(node) {
        Some(model) => model
        None =>
          abort(
            "the node " +
            node +
            " is a root and needs a distribution, but it has none",
          )
      }
      let samples = root_model.draw_samples(num_samples_unconditional, rng)
      let scorer = scorer_factory().fit(samples)
      results.set(node, scorer.score(anomaly_data.numeric(node)))
    } else {
      let parents = causal_model.graph.predecessors(node)
      let parent_samples = design_matrix_of(
        causal_model, node, anomaly_data, parents,
      )
      let target_samples = anomaly_data.numeric(node)
      let mechanism = match causal_model.causal_mechanism(node) {
        Some(mechanism) => mechanism
        None =>
          abort(
            "the node " +
            node +
            " has parents and needs a causal mechanism, but it has none",
          )
      }
      results.set(
        node,
        conditional_anomaly_scores(
          parent_samples, target_samples, mechanism, scorer_factory, num_samples_conditional,
          rng,
        ),
      )
    }
  }
  results
}

///|
/// The sorted samples of the distribution, where the samples that are not a
/// number come last.
fn sort_distribution(samples : Array[Double]) -> SortedDistribution {
  let values : Array[Double] = []
  let mut num_not_a_number = 0
  for sample in samples {
    if @utils.is_nan(sample) {
      num_not_a_number = num_not_a_number + 1
    } else {
      values.push(sample)
    }
  }
  values.sort_by(fn(a, b) { @utils.compare_double(a, b) })
  for _ in 0..<num_not_a_number {
    values.push(@utils.nan())
  }
  { samples: values, num_not_a_number, }
}

///|
/// The number of the samples of the distribution that are equal to the given
/// sample, the number of the samples that are greater than it and the number of
/// the samples that are smaller than it.
///
/// The samples that are not a number are neither greater nor smaller than the
/// given sample, and they are equal to it only when it is not a number as well,
/// like the comparisons of numpy compare them.
fn counts_of(
  distribution : SortedDistribution,
  sample : Double,
) -> (Int32, Int32, Int32) {
  if @utils.is_nan(sample) {
    return (distribution.num_not_a_number, 0, 0)
  }
  let values = distribution.samples
  let num_values = values.length() - distribution.num_not_a_number
  // The index of the first sample that is not smaller than the sample.
  let mut lo = 0
  let mut hi = num_values
  while lo < hi {
    let mid = (lo + hi) / 2
    if values[mid] < sample {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  let lower = lo
  // The index of the first sample that is greater than the sample.
  lo = lower
  hi = num_values
  while lo < hi {
    let mid = (lo + hi) / 2
    if values[mid] <= sample {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  let upper = lo
  (upper - lower, num_values - upper, lower)
}

///|
/// The median of the samples, which is not a number when one of the samples is
/// not a number, like the median of numpy.
fn median_of(samples : Array[Double]) -> Double {
  for sample in samples {
    if @utils.is_nan(sample) {
      return sample
    }
  }
  @utils.median(samples)
}

///|
/// The median absolute deviation of the samples, which is the median of their
/// absolute deviations divided by the normalisation of the median absolute
/// deviation, like `statsmodels.robust.mad` computes it.
fn mad_of(samples : Array[Double]) -> Double {
  let centre = median_of(samples)
  if @utils.is_nan(centre) {
    return centre
  }
  let deviations : Array[Double] = []
  for sample in samples {
    deviations.push((sample - centre).abs())
  }
  @utils.median(deviations) / ANOMALY_MAD_NORMALISATION
}
