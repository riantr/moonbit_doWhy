///|
/// The reducers of the dimensionality of a data set.
///
/// This is the port of `dowhy.data_transformer` and of
/// `dowhy.data_transformers`, the part of DoWhy that reduces the number of
/// columns of a data set before the estimators see it.
///
/// The reducer follows the convention of `sklearn.decomposition.PCA`: the
/// data is centred, the components are the eigenvectors of the covariance
/// matrix ordered by descending eigenvalue, and the sign of every component
/// is fixed the way `sklearn.utils.extmath.svd_flip` fixes it, so that the
/// largest entry of a component is positive.
pub enum ReducerKind {
  /// The base reducer of the upstream, whose reduction is not implemented.
  ///
  /// The base class `DimensionalityReducer` of the upstream raises a
  /// `NotImplementedError` when its reduction is called.
  Base
  /// The principal component analysis.
  PCA
}

///|
/// A reducer of the dimensionality of a data set.
pub struct DimensionalityReducer {
  /// The data to reduce.
  data : @utils.Matrix
  /// The number of dimensions to keep.
  ndims : Int32
  /// The algorithm of the reducer.
  kind : ReducerKind
  /// Whether the columns are standardised before the reduction.
  mut standardize : Bool
}

///|
/// A reducer that projects the data onto fewer dimensions.
pub fn DimensionalityReducer::new(
  data : @utils.Matrix,
  ndims : Int32,
  kind : ReducerKind,
) -> DimensionalityReducer {
  { data, ndims, kind, standardize: true, }
}

///|
/// A principal component analysis reducer.
///
/// This is the port of `dowhy.data_transformers.pca_reducer.PCAReducer`.
/// Upstream standardises the data by default; pass `false` to leave the
/// scale of the columns alone.
pub fn DimensionalityReducer::pca(
  data : @utils.Matrix,
  ndims : Int32,
  standardize : Bool,
) -> DimensionalityReducer {
  let reducer = DimensionalityReducer::new(data, ndims, ReducerKind::PCA)
  reducer.standardize = standardize
  reducer
}

///|
/// The base reducer of the upstream.
///
/// This is the port of the base class `DimensionalityReducer` of the upstream,
/// whose reduction raises a `NotImplementedError`. The port reports it with
/// the predicate `supports_reduction` and with a `None` return, because
/// MoonBit cannot catch the abort of a method.
pub fn DimensionalityReducer::base(
  data : @utils.Matrix,
  ndims : Int32,
) -> DimensionalityReducer {
  DimensionalityReducer::new(data, ndims, ReducerKind::Base)
}

///|
/// Whether the reducer reduces the data.
///
/// This is the port of the `reduce` of the upstream. The base reducer of the
/// upstream does not reduce the data and raises a `NotImplementedError` when
/// it is called, and the principal component analysis of the upstream does
/// reduce it.
pub fn DimensionalityReducer::supports_reduction(
  self : DimensionalityReducer,
) -> Bool {
  match self.kind {
    Base => false
    PCA => true
  }
}

///|
/// The number of dimensions the reducer keeps.
pub fn DimensionalityReducer::dimensions(self : DimensionalityReducer) -> Int32 {
  let columns = self.data.ncols()
  if self.ndims < columns {
    self.ndims
  } else {
    columns
  }
}

///|
/// The data the reducer was built for.
pub fn DimensionalityReducer::data(
  self : DimensionalityReducer,
) -> @utils.Matrix {
  self.data.copy()
}

///|
/// Whether the columns are standardised before the reduction.
pub fn DimensionalityReducer::is_standardized(
  self : DimensionalityReducer,
) -> Bool {
  self.standardize
}

///|
/// Set whether the columns are standardised before the reduction.
pub fn DimensionalityReducer::set_standardize(
  self : DimensionalityReducer,
  flag : Bool,
) -> Unit {
  self.standardize = flag
}

///|
/// Reduce the data to fewer dimensions.
///
/// The reduced data has one row per row of the input and one column per
/// component that was kept.
///
/// The base reducer of the upstream does not reduce the data and raises a
/// `NotImplementedError` when it is called, so the port gives `None` for it.
pub fn DimensionalityReducer::reduce(
  self : DimensionalityReducer,
) -> @utils.Matrix? {
  match self.kind {
    Base => None
    PCA => Some(self.reduce_pca())
  }
}

///|
/// The fraction of the variance that every component explains.
///
/// The fractions are in descending order and add up to one, like the
/// `explained_variance_ratio_` of `sklearn.decomposition.PCA`.
pub fn DimensionalityReducer::explained_variance_ratio(
  self : DimensionalityReducer,
) -> Array[Double] {
  let prepared = self.prepare()
  let covariance = covariance_matrix(prepared)
  let (values, _) = @utils.jacobi_eigen(covariance)
  let order = descending_order(values)
  let mut total = 0.0
  for index in order {
    total = total + values[index]
  }
  let ratios : Array[Double] = []
  for index in order {
    if total > 0.0 {
      ratios.push(values[index] / total)
    } else {
      ratios.push(0.0)
    }
  }
  ratios
}

///|
/// The components of the reduction, one column per component.
pub fn DimensionalityReducer::components(
  self : DimensionalityReducer,
) -> @utils.Matrix {
  let prepared = self.prepare()
  let covariance = covariance_matrix(prepared)
  let (values, vectors) = @utils.jacobi_eigen(covariance)
  let order = descending_order(values)
  flip_signs(vectors)
  let kept = self.dimensions()
  let components = @utils.Matrix::zeros(vectors.nrows(), kept)
  for j = 0; j < kept; j = j + 1 {
    for i = 0; i < vectors.nrows(); i = i + 1 {
      components.set(i, j, vectors.get(i, order[j]))
    }
  }
  components
}

///|
/// The principal component analysis of the data.
fn DimensionalityReducer::reduce_pca(
  self : DimensionalityReducer,
) -> @utils.Matrix {
  let prepared = self.prepare()
  let covariance = covariance_matrix(prepared)
  let (values, vectors) = @utils.jacobi_eigen(covariance)
  let order = descending_order(values)
  flip_signs(vectors)
  let kept = self.dimensions()
  let components = @utils.Matrix::zeros(vectors.nrows(), kept)
  for j = 0; j < kept; j = j + 1 {
    for i = 0; i < vectors.nrows(); i = i + 1 {
      components.set(i, j, vectors.get(i, order[j]))
    }
  }
  prepared.mul(components)
}

///|
/// The centred data, standardised when the reducer asks for it.
///
/// `sklearn.preprocessing.scale` divides by the population standard
/// deviation, and leaves a column without variance alone.
fn DimensionalityReducer::prepare(
  self : DimensionalityReducer,
) -> @utils.Matrix {
  let rows = self.data.nrows()
  let columns = self.data.ncols()
  let prepared = @utils.Matrix::zeros(rows, columns)
  for j = 0; j < columns; j = j + 1 {
    let column = self.data.col(j)
    let mean = @utils.mean(column)
    let mut scale = 1.0
    if self.standardize {
      let deviation = @utils.std(column)
      if deviation > 0.0 {
        scale = deviation
      }
    }
    for i = 0; i < rows; i = i + 1 {
      prepared.set(i, j, (column[i] - mean) / scale)
    }
  }
  prepared
}

///|
/// The covariance matrix of the data, with the `n - 1` denominator that
/// `numpy.cov` uses.
fn covariance_matrix(data : @utils.Matrix) -> @utils.Matrix {
  let rows = data.nrows()
  let columns = data.ncols()
  let denominator = if rows > 1 { (rows - 1).to_double() } else { 1.0 }
  let covariance = @utils.Matrix::zeros(columns, columns)
  for j = 0; j < columns; j = j + 1 {
    for l = 0; l < columns; l = l + 1 {
      let mut sum = 0.0
      for i = 0; i < rows; i = i + 1 {
        sum = sum + data.get(i, j) * data.get(i, l)
      }
      covariance.set(j, l, sum / denominator)
    }
  }
  covariance
}

///|
/// The indices of the eigenvalues in descending order.
fn descending_order(values : Array[Double]) -> Array[Int32] {
  let order : Array[Int32] = []
  for i = 0; i < values.length(); i = i + 1 {
    order.push(i)
  }
  order.sort_by(fn(a, b) { @utils.compare_double(values[b], values[a]) })
  order
}

///|
/// Fix the sign of every component the way `svd_flip` does.
///
/// The entry of a component with the largest absolute value is made
/// positive, which removes the freedom of sign that an eigenvector has.
fn flip_signs(vectors : @utils.Matrix) -> Unit {
  for j = 0; j < vectors.ncols(); j = j + 1 {
    let mut best = 0
    let mut best_value = vectors.get(0, j).abs()
    for i = 1; i < vectors.nrows(); i = i + 1 {
      let value = vectors.get(i, j).abs()
      if value > best_value {
        best_value = value
        best = i
      }
    }
    if vectors.get(best, j) < 0.0 {
      for i = 0; i < vectors.nrows(); i = i + 1 {
        vectors.set(i, j, -vectors.get(i, j))
      }
    }
  }
}
