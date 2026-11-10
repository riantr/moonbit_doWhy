///|
/// The fixtures of the kernel based independence test.
///
/// The frames of this file hold the data of the cases of the upstream test
/// file `tests/gcm/independence_test/test_kernel.py` that the port mirrors.

///|
/// The seed of the generator of the categorical fixture.
const KERNEL_CATEGORICAL_SEED : UInt64 = 20240201UL

///|
/// The number of the rows of the categorical fixture.
///
/// The upstream draws a thousand rows, and its kernel test needs an eigen
/// decomposition of a matrix of the size of the rows, so the port draws two
/// hundred of them.
const KERNEL_CATEGORICAL_ROWS : Int32 = 200

///|
/// The number of the rows of the fixture of the determinism.
const KERNEL_DETERMINISM_ROWS : Int32 = 1000

///|
/// The number of the rows of the almost constant fixture.
const KERNEL_ALMOST_CONSTANT_ROWS : Int32 = 100

///|
/// The categorical fixture of the kernel test.
///
/// The fixture is the one of the upstream: the column `X` holds normal
/// deviates, the column `Z` holds the class of the sign of `X`, the column `Y`
/// holds the number of the class of `Z` with a noise, and the column `R` holds
/// a class that does not depend on `X`.
///
/// The upstream draws all the values of `X` before it draws the noise of `Y`,
/// and the port draws them row by row, so the two fixtures hold different
/// numbers. The reference script `_verify/gcm_validation_reference.py` draws
/// the fixture of the port, so the two agree.
pub fn kernel_categorical_frame() -> @api.DataFrame {
  let rng = @utils.Random::new(KERNEL_CATEGORICAL_SEED)
  let first : Array[Double] = []
  let second : Array[Double] = []
  let third : Array[String] = []
  let fourth : Array[String] = []
  for _ in 0..<KERNEL_CATEGORICAL_ROWS {
    let value = rng.next_normal()
    let klass = if value > 0.0 { 0.0 } else { 1.0 }
    first.push(value)
    second.push(klass + rng.next_normal())
    third.push(if value > 0.0 { "Class 1" } else { "Class 2" })
    fourth.push(if rng.next_double() < 0.5 { "Class 1" } else { "Class 2" })
  }
  @api.DataFrame::new(
    ["X", "Y", "Z", "R"],
    Map([
      ("X", @api.Column::numeric(first)),
      ("Y", @api.Column::numeric(second)),
      ("Z", @api.Column::discrete(third)),
      ("R", @api.Column::discrete(fourth)),
    ]),
  )
}

///|
/// The fixture of the pairwise determinism of the kernel test.
///
/// This is the fixture of the upstream test file: the column `X` holds normal
/// deviates and the column `Y` holds the column `X` with a noise.
pub fn kernel_determinism_frame() -> @api.DataFrame {
  let rng = @utils.Random::new(KERNEL_CATEGORICAL_SEED + 1UL)
  let first : Array[Double] = []
  let second : Array[Double] = []
  for _ in 0..<KERNEL_DETERMINISM_ROWS {
    let value = rng.next_normal()
    first.push(value)
    second.push(value + rng.next_normal())
  }
  @api.DataFrame::new(
    ["X", "Y"],
    Map([
      ("X", @api.Column::numeric(first)),
      ("Y", @api.Column::numeric(second)),
    ]),
  )
}

///|
/// The fixture of the conditional determinism of the kernel test.
///
/// This is the fixture of the upstream test file: the column `Z` holds normal
/// deviates, and the columns `X` and `Y` hold the exponential of `Z` with a
/// uniform deviate.
pub fn kernel_conditional_determinism_frame() -> @api.DataFrame {
  let rng = @utils.Random::new(KERNEL_CATEGORICAL_SEED + 2UL)
  let first : Array[Double] = []
  let second : Array[Double] = []
  let third : Array[Double] = []
  for _ in 0..<KERNEL_DETERMINISM_ROWS {
    let value = rng.next_normal()
    first.push(@math.exp(value + rng.next_double()))
    second.push(@math.exp(value + rng.next_double()))
    third.push(value)
  }
  @api.DataFrame::new(
    ["X", "Y", "Z"],
    Map([
      ("X", @api.Column::numeric(first)),
      ("Y", @api.Column::numeric(second)),
      ("Z", @api.Column::numeric(third)),
    ]),
  )
}

///|
/// The almost constant fixture of the kernel test.
///
/// The column `C` holds a single value and zeros, and the columns `N` and `M`
/// hold normal deviates. This is the fixture of the upstream test file, whose
/// almost constant column holds one value and ninety nine zeros.
pub fn kernel_almost_constant_frame() -> @api.DataFrame {
  let rng = @utils.Random::new(KERNEL_CATEGORICAL_SEED + 3UL)
  let constant : Array[Double] = []
  let noise : Array[Double] = []
  let other : Array[Double] = []
  for i in 0..<KERNEL_ALMOST_CONSTANT_ROWS {
    constant.push(if i == 0 { 1.0 } else { 0.0 })
    noise.push(rng.next_normal())
    other.push(rng.next_normal())
  }
  @api.DataFrame::new(
    ["C", "N", "M"],
    Map([
      ("C", @api.Column::numeric(constant)),
      ("N", @api.Column::numeric(noise)),
      ("M", @api.Column::numeric(other)),
    ]),
  )
}
