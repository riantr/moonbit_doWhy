///|
/// Dense row-major matrix used by the estimation routines.
///
/// This mirrors the small subset of `numpy` that the DoWhy estimators rely on:
/// a design matrix is built from a data frame, a model is fitted against a
/// response vector and the fitted coefficients / standard errors are read back.
pub struct Matrix {
  rows : Int32
  cols : Int32
  data : Array[Double]
}

///|
/// Build a zero filled matrix of the given shape.
pub fn Matrix::zeros(rows : Int32, cols : Int32) -> Matrix {
  let data : Array[Double] = []
  for i = 0; i < rows * cols; i = i + 1 {
    data.push(0.0)
  }
  { rows, cols, data, }
}

///|
/// Build the identity matrix of size `n`.
pub fn Matrix::identity(n : Int32) -> Matrix {
  let m = Matrix::zeros(n, n)
  for i = 0; i < n; i = i + 1 {
    m.data[i * n + i] = 1.0
  }
  m
}

///|
/// Build a matrix from a list of rows.
pub fn Matrix::from_rows(rows : Array[Array[Double]]) -> Matrix {
  let n = rows.length()
  let cols = if n == 0 { 0 } else { rows[0].length() }
  let data : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    let row = rows[i]
    for j = 0; j < cols; j = j + 1 {
      data.push(if j < row.length() { row[j] } else { 0.0 })
    }
  }
  { rows: n, cols, data, }
}

///|
/// Build a matrix from a flat array in row-major order.
pub fn Matrix::from_flat(
  rows : Int32,
  cols : Int32,
  data : Array[Double],
) -> Matrix {
  { rows, cols, data, }
}

///|
/// Build a matrix whose rows are the given vectors.
pub fn Matrix::from_columns(columns : Array[Array[Double]]) -> Matrix {
  let p = columns.length()
  let n = if p == 0 { 0 } else { columns[0].length() }
  let data : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    for j = 0; j < p; j = j + 1 {
      data.push(columns[j][i])
    }
  }
  { rows: n, cols: p, data, }
}

///|
/// Number of rows.
pub fn Matrix::nrows(self : Matrix) -> Int32 {
  self.rows
}

///|
/// Number of columns.
pub fn Matrix::ncols(self : Matrix) -> Int32 {
  self.cols
}

///|
/// Element access.
pub fn Matrix::get(self : Matrix, i : Int32, j : Int32) -> Double {
  self.data[i * self.cols + j]
}

///|
/// Element assignment.
pub fn Matrix::set(self : Matrix, i : Int32, j : Int32, v : Double) -> Unit {
  self.data[i * self.cols + j] = v
}

///|
/// Row `i` as an array.
pub fn Matrix::row(self : Matrix, i : Int32) -> Array[Double] {
  let out : Array[Double] = []
  for j = 0; j < self.cols; j = j + 1 {
    out.push(self.data[i * self.cols + j])
  }
  out
}

///|
/// Column `j` as an array.
pub fn Matrix::col(self : Matrix, j : Int32) -> Array[Double] {
  let out : Array[Double] = []
  for i = 0; i < self.rows; i = i + 1 {
    out.push(self.data[i * self.cols + j])
  }
  out
}

///|
/// A copy of the matrix.
pub fn Matrix::copy(self : Matrix) -> Matrix {
  { rows: self.rows, cols: self.cols, data: self.data.copy(), }
}

///|
/// Transpose of the matrix.
pub fn Matrix::transpose(self : Matrix) -> Matrix {
  let out = Matrix::zeros(self.cols, self.rows)
  for i = 0; i < self.rows; i = i + 1 {
    for j = 0; j < self.cols; j = j + 1 {
      out.data[j * self.rows + i] = self.data[i * self.cols + j]
    }
  }
  out
}

///|
/// Matrix product `self * other`.
pub fn Matrix::mul(self : Matrix, other : Matrix) -> Matrix {
  let out = Matrix::zeros(self.rows, other.cols)
  for i = 0; i < self.rows; i = i + 1 {
    for k = 0; k < self.cols; k = k + 1 {
      let a = self.data[i * self.cols + k]
      if a != 0.0 {
        for j = 0; j < other.cols; j = j + 1 {
          out.data[i * other.cols + j] = out.data[i * other.cols + j] +
            a * other.data[k * other.cols + j]
        }
      }
    }
  }
  out
}

///|
/// Matrix-vector product `self * v`.
pub fn Matrix::matvec(self : Matrix, v : Array[Double]) -> Array[Double] {
  let out : Array[Double] = []
  for i = 0; i < self.rows; i = i + 1 {
    let mut s = 0.0
    for j = 0; j < self.cols; j = j + 1 {
      s = s + self.data[i * self.cols + j] * v[j]
    }
    out.push(s)
  }
  out
}

///|
/// Transpose-vector product `self^T * v`.
pub fn Matrix::matvec_t(self : Matrix, v : Array[Double]) -> Array[Double] {
  let out : Array[Double] = []
  for j = 0; j < self.cols; j = j + 1 {
    let mut s = 0.0
    for i = 0; i < self.rows; i = i + 1 {
      s = s + self.data[i * self.cols + j] * v[i]
    }
    out.push(s)
  }
  out
}

///|
/// `self^T * other`.
pub fn Matrix::mul_t(self : Matrix, other : Matrix) -> Matrix {
  self.transpose().mul(other)
}
