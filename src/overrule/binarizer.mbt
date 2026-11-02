///|
/// The binariser of the features, the port of the `FeatureBinarizer` of the
/// upstream.
///
/// Every feature is turned into a set of literals, and every literal holds for
/// the rows whose value of the feature satisfies it. A feature with at most two
/// distinct values becomes one literal and, with the negations, its negation.
/// A feature with more distinct values becomes one literal per threshold, and
/// the thresholds are the quantiles of the values.
pub struct FeatureBinarizer {
  names : Array[String]
  negations : Bool
  num_thresholds : Int32
  kind : Array[FeatureKind]
  levels : Array[Array[Double]]
  thresholds : Array[Array[Double]]
}

///|
/// A binariser of the features that is not fitted yet.
pub fn FeatureBinarizer::new(
  names : Array[String],
  num_thresholds : Int32,
  negations : Bool,
) -> FeatureBinarizer {
  {
    names: names.copy(),
    negations,
    num_thresholds,
    kind: [],
    levels: [],
    thresholds: [],
  }
}

///|
/// Learn the literals of the features from the given rows.
///
/// The binariser keeps the distinct values of the binary features and the
/// thresholds of the ordinal ones, so that it can transform other rows with
/// the same literals.
pub fn FeatureBinarizer::fit(
  self : FeatureBinarizer,
  columns : Array[Array[Double]],
) -> Unit {
  for c = 0; c < columns.length(); c = c + 1 {
    let uniq = distinct_values(columns[c])
    if uniq.length() <= 2 {
      self.kind.push(FeatureKind::Binary)
      self.levels.push(uniq)
      self.thresholds.push([])
    } else {
      self.kind.push(FeatureKind::Ordinal)
      self.levels.push([])
      self.thresholds.push(self.thresholds_of(uniq))
    }
  }
}

///|
/// The thresholds of an ordinal feature.
///
/// A feature with few distinct values is cut at every value but the largest
/// one, and a feature with many distinct values is cut at the quantiles of the
/// values, the way the upstream does it.
fn FeatureBinarizer::thresholds_of(
  self : FeatureBinarizer,
  uniq : Array[Double],
) -> Array[Double] {
  if uniq.length() <= self.num_thresholds + 1 {
    let out : Array[Double] = []
    for i = 0; i < uniq.length() - 1; i = i + 1 {
      out.push(uniq[i])
    }
    return out
  }
  let out : Array[Double] = []
  for k = 1; k <= self.num_thresholds; k = k + 1 {
    let probability = k.to_double() / (self.num_thresholds + 1).to_double()
    let quantile = @utils.percentile(uniq, probability * 100.0)
    if out.length() == 0 || out[out.length() - 1] != quantile {
      out.push(quantile)
    }
  }
  out
}

///|
/// Turn the given rows into the literals of the features.
pub fn FeatureBinarizer::transform(
  self : FeatureBinarizer,
  columns : Array[Array[Double]],
) -> BinarizedData {
  let literals : Array[Literal] = []
  let values : Array[Array[Double]] = []
  let feature_of : Array[Int32] = []
  let n_rows = if columns.length() == 0 { 0 } else { columns[0].length() }
  for c = 0; c < columns.length(); c = c + 1 {
    let binary = match self.kind[c] {
      FeatureKind::Binary => true
      FeatureKind::Ordinal => false
    }
    if binary {
      // The values are renamed to zero and one, in the order of their size.
      let levels = self.levels[c]
      let mapped : Array[Double] = []
      for value in columns[c] {
        let index = index_of_value(levels, value)
        mapped.push(if index < 0 { 0.0 } else { index.to_double() })
      }
      literals.push({
        feature: self.names[c],
        operation: LiteralOperation::Binary,
        value: 0.0,
      })
      values.push(mapped)
      feature_of.push(c)
      if self.negations {
        let negated : Array[Double] = []
        for value in mapped {
          negated.push(1.0 - value)
        }
        literals.push({
          feature: self.names[c],
          operation: LiteralOperation::Negation,
          value: 0.0,
        })
        values.push(negated)
        feature_of.push(c)
      }
    } else {
      let thresholds = self.thresholds[c]
      let less : Array[Array[Double]] = []
      for threshold in thresholds {
        let column : Array[Double] = []
        for value in columns[c] {
          column.push(if value <= threshold { 1.0 } else { 0.0 })
        }
        less.push(column)
      }
      for k = 0; k < thresholds.length(); k = k + 1 {
        literals.push({
          feature: self.names[c],
          operation: LiteralOperation::LessEqual,
          value: thresholds[k],
        })
        values.push(less[k])
        feature_of.push(c)
      }
      if self.negations {
        for k = 0; k < thresholds.length(); k = k + 1 {
          let column : Array[Double] = []
          for value in less[k] {
            column.push(1.0 - value)
          }
          literals.push({
            feature: self.names[c],
            operation: LiteralOperation::Greater,
            value: thresholds[k],
          })
          values.push(column)
          feature_of.push(c)
        }
      }
    }
  }
  { literals, columns: values, feature_of, n_rows, }
}

///|
/// Draw the reference samples of the upstream, the port of
/// `sample_reference`.
///
/// The reference samples are drawn uniformly over the range of every column,
/// and they are the background the rules are learned against. A column with
/// two distinct values is drawn from its two values, and a column with more
/// distinct values is drawn uniformly between its smallest and its largest
/// value, the way the upstream does it with a generator of its own for every
/// column.
pub fn sample_reference(
  columns : Array[Array[Double]],
  n : Int32,
  random : @utils.Random,
  seed : Int32,
) -> Array[Array[Double]] {
  let out : Array[Array[Double]] = []
  let mut counter = seed
  for c = 0; c < columns.length(); c = c + 1 {
    let uniq = distinct_values(columns[c])
    let column : Array[Double] = []
    if uniq.length() < 2 {
      for i = 0; i < n; i = i + 1 {
        column.push(uniq[0])
      }
    } else if uniq.length() == 2 {
      for i = 0; i < n; i = i + 1 {
        column.push(uniq[random.next_int(2)])
      }
    } else {
      let low = uniq[0]
      let high = uniq[uniq.length() - 1]
      let generator = @utils.Random::new(counter.to_uint64())
      for i = 0; i < n; i = i + 1 {
        column.push(low + (high - low) * generator.next_double())
      }
      counter = counter + 1
    }
    out.push(column)
  }
  out
}
