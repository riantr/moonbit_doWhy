///|
/// The generator of numpy.
///
/// The upstream of DoWhy draws its randomness from the global generator of
/// numpy, so a data set of the upstream is only reproducible with the seed it
/// was drawn with. This module is the port of that generator: the Mersenne
/// Twister of numpy, with the double, the normal variate, the Bernoulli and
/// the integer of numpy.
///
/// The port takes the seed as an argument, the way the upstream takes the
/// seed of its `np.random.seed`, and the numbers it draws are the numbers of
/// numpy for that seed.
///
/// The double of numpy is built out of two words of the Twister with the
/// recipe of Python: the first word gives the high 27 bits and the second
/// word gives the low 26 bits. The normal variate is the one of the polar
/// method of Marsaglia, which keeps the second variate of a pair for the
/// next call. The Bernoulli and the integer of numpy take the low bits of a
/// word and throw the value away when it is out of their range.
///
/// The binomial of numpy is the port of the Bernoulli of one trial, which is
/// the case the upstream uses. The binomial of more trials of numpy uses the
/// algorithm of Kachitvichyanukul and Schmeiser, which is not ported.
///
/// The binomial of numpy with one trial takes the complement of the
/// probability when the probability is greater than one half, and the trial of
/// the complement runs the other way. A trial of a probability of at most one
/// half is a one when the double is greater than the complement of the
/// probability, and a trial of a probability above one half is a one when the
/// double is at most the probability. The port follows that rule, because the
/// upstream draws its binary treatment this way.

///|
/// The number of the words of the state of the generator.
const NUMPY_RANDOM_STATE_LEN : Int32 = 624

///|
/// The distance of the words of the twist of the generator.
const NUMPY_RANDOM_M : Int32 = 397

///|
/// The matrix of the twist of the generator.
const NUMPY_RANDOM_MATRIX_A : UInt64 = 0x9908B0DF

///|
/// The high bit of the mask of the twist of the generator.
const NUMPY_RANDOM_UPPER_MASK : UInt64 = 0x80000000

///|
/// The low bits of the mask of the twist of the generator.
const NUMPY_RANDOM_LOWER_MASK : UInt64 = 0x7FFFFFFF

///|
/// The mask of the tempering of the generator.
const NUMPY_RANDOM_MASK : UInt64 = 0xFFFFFFFF

///|
/// The scale of the double of the generator.
const NUMPY_RANDOM_TWO_POW_53 : Double = 9007199254740992.0

///|
/// The generator of numpy.
///
/// The state of the generator is the state of the Mersenne Twister of numpy,
/// and the two flags are the ones of the normal variate, which keeps the
/// second variate of a pair for the next call.
pub struct NumpyRandom {
  /// The words of the state of the Twister.
  state : Array[UInt64]
  /// The word the next call reads.
  mut index : Int32
  /// Whether the generator holds the second variate of a pair.
  mut has_gauss : Bool
  /// The second variate of the pair of the last call of the normal variate.
  mut gauss : Double
}

///|
/// The generator of numpy for the given seed.
///
/// The seed is the one of `np.random.seed`.
pub fn NumpyRandom::new(seed : UInt64) -> NumpyRandom {
  let state : Array[UInt64] = [seed & NUMPY_RANDOM_MASK]
  for i in 1..<NUMPY_RANDOM_STATE_LEN {
    let previous = state[i - 1]
    let mixed = previous ^ (previous >> 30)
    let next = (1812433253UL * mixed + i.to_uint64()) & NUMPY_RANDOM_MASK
    state.push(next)
  }
  { state, index: NUMPY_RANDOM_STATE_LEN, has_gauss: false, gauss: 0.0, }
}

///|
/// The next word of the generator.
///
/// This is the port of `mt19937_next` of numpy.
pub fn NumpyRandom::next_uint32(self : NumpyRandom) -> UInt64 {
  if self.index >= NUMPY_RANDOM_STATE_LEN {
    self.twist()
  }
  let mut y = self.state[self.index]
  self.index = self.index + 1
  y = y ^ (y >> 11)
  y = y ^ ((y << 7) & 0x9D2C5680)
  y = y ^ ((y << 15) & 0xEFC60000)
  y = y ^ (y >> 18)
  y & NUMPY_RANDOM_MASK
}

///|
/// The next 64 bit value of the generator.
///
/// This is the port of `rk_ulong` of numpy, which builds the value out of two
/// words of the Twister.
pub fn NumpyRandom::next_uint64(self : NumpyRandom) -> UInt64 {
  let high = self.next_uint32()
  let low = self.next_uint32()
  (high << 32) | low
}

///|
/// The next value in `[0, 1)`.
///
/// This is the port of `rk_double` of numpy, the recipe of Python.
pub fn NumpyRandom::next_double(self : NumpyRandom) -> Double {
  let high = (self.next_uint32() >> 5).to_double()
  let low = (self.next_uint32() >> 6).to_double()
  (high * 67108864.0 + low) / NUMPY_RANDOM_TWO_POW_53
}

///|
/// The next value of the standard normal distribution.
///
/// This is the port of `legacy_gauss` of numpy, the polar method of
/// Marsaglia. The method keeps the second variate of a pair for the next
/// call, so a pair of variates costs four words of the Twister.
pub fn NumpyRandom::standard_normal(self : NumpyRandom) -> Double {
  if self.has_gauss {
    let value = self.gauss
    self.has_gauss = false
    self.gauss = 0.0
    return value
  }
  let mut result = 0.0
  let mut found = false
  while !found {
    let x1 = 2.0 * self.next_double() - 1.0
    let x2 = 2.0 * self.next_double() - 1.0
    let r2 = x1 * x1 + x2 * x2
    if r2 < 1.0 && r2 != 0.0 {
      let factor = (-2.0 * @math.ln(r2) / r2).sqrt()
      self.gauss = factor * x1
      self.has_gauss = true
      result = factor * x2
      found = true
    }
  }
  result
}

///|
/// The next value of the normal distribution of the given mean and deviation.
pub fn NumpyRandom::normal(
  self : NumpyRandom,
  loc : Double,
  scale : Double,
) -> Double {
  loc + scale * self.standard_normal()
}

///|
/// The next value of the uniform distribution on `[low, high)`.
pub fn NumpyRandom::uniform(
  self : NumpyRandom,
  low : Double,
  high : Double,
) -> Double {
  low + (high - low) * self.next_double()
}

///|
/// The next Bernoulli trial with the given probability of a one.
///
/// This is the port of the binomial of numpy with one trial. The upstream
/// draws its binary treatment this way.
///
/// The binomial of numpy takes the complement of the probability when the
/// probability is greater than one half, and the trial of the complement runs
/// the other way. A trial of a probability of at most one half is a one when
/// the double is greater than the complement of the probability, and a trial of
/// a probability above one half is a one when the double is at most the
/// probability.
///
/// The threshold of the comparison is the one of numpy, which takes the
/// logarithm of the probability and the exponential of it. The two differ from
/// the probability by one unit in the last place, so the two trials differ only
/// when the double falls between them.
pub fn NumpyRandom::bernoulli(self : NumpyRandom, p : Double) -> Int32 {
  let value = self.next_double()
  if p <= 0.5 {
    if value > @math.exp(@math.ln(1.0 - p)) {
      1
    } else {
      0
    }
  } else if value <= @math.exp(@math.ln(p)) {
    1
  } else {
    0
  }
}

///|
/// The next Bernoulli trials with a probability of a one for every row.
///
/// This is the port of the binomial of numpy with one trial and an array of
/// the probabilities. The upstream draws its binary treatment this way.
pub fn NumpyRandom::bernoulli_array(
  self : NumpyRandom,
  probabilities : Array[Double],
) -> Array[Int32] {
  let values : Array[Int32] = []
  for probability in probabilities {
    values.push(self.bernoulli(probability))
  }
  values
}

///|
/// The next Bernoulli trials with the same probability of a one.
///
/// This is the port of the binomial of numpy with one trial and a size.
pub fn NumpyRandom::bernoulli_repeated(
  self : NumpyRandom,
  p : Double,
  count : Int32,
) -> Array[Int32] {
  let values : Array[Int32] = []
  for _ in 0..<count {
    values.push(self.bernoulli(p))
  }
  values
}

///|
/// The next values of the standard normal distribution in a matrix.
///
/// This is the port of `np.random.randn` of numpy. The matrix has one row per
/// row of the sample and one column per column of the sample, and the variates
/// are drawn in the order of the rows.
pub fn NumpyRandom::randn(
  self : NumpyRandom,
  rows : Int32,
  cols : Int32,
) -> Matrix {
  let values : Array[Array[Double]] = []
  for _ in 0..<rows {
    let row : Array[Double] = []
    for _ in 0..<cols {
      row.push(self.standard_normal())
    }
    values.push(row)
  }
  Matrix::from_rows(values)
}

///|
/// The next integer of `[0, high)`.
///
/// This is the port of `random_interval` of numpy: the low bits of a word of
/// the Twister give the value, and a value that is out of the range is
/// thrown away.
pub fn NumpyRandom::randint(self : NumpyRandom, high : Int32) -> Int32 {
  if high <= 1 {
    return 0
  }
  let rng = high - 1
  let mask = mask_of(rng)
  let mut result = 0
  let mut found = false
  while !found {
    let value = (self.next_uint32() & mask).to_int()
    if value <= rng {
      result = value
      found = true
    }
  }
  result
}

///|
/// The next permutation of the numbers of `[0, count)`.
///
/// This is the port of the permutation of numpy, which shuffles the numbers
/// from the last one to the second one.
pub fn NumpyRandom::permutation(
  self : NumpyRandom,
  count : Int32,
) -> Array[Int32] {
  let values : Array[Int32] = []
  for i in 0..<count {
    values.push(i)
  }
  let mut i = count - 1
  while i > 0 {
    let j = self.randint(i + 1)
    let held = values[i]
    values[i] = values[j]
    values[j] = held
    i = i - 1
  }
  values
}

///|
/// The next values of the multivariate normal distribution whose covariance
/// is the identity.
///
/// This is the port of `np.random.multivariate_normal` with the identity as
/// its covariance, which is the covariance the upstream uses. The covariance
/// of numpy is turned into the singular values and the singular vectors of
/// its decomposition, and the port takes the identity as it is.
///
/// The matrix has one row per row of the sample and one column per mean.
pub fn NumpyRandom::multivariate_normal_identity(
  self : NumpyRandom,
  means : Array[Double],
  rows : Int32,
) -> Matrix {
  let width = means.length()
  let values : Array[Array[Double]] = []
  for _ in 0..<rows {
    let row : Array[Double] = []
    for j in 0..<width {
      row.push(means[j] + self.standard_normal())
    }
    values.push(row)
  }
  Matrix::from_rows(values)
}

///|
/// The twist of the state of the generator.
///
/// This is the port of `mt19937_gen` of numpy.
fn NumpyRandom::twist(self : NumpyRandom) -> Unit {
  let state = self.state
  let mut i = 0
  while i < NUMPY_RANDOM_STATE_LEN - NUMPY_RANDOM_M {
    let y = (state[i] & NUMPY_RANDOM_UPPER_MASK) |
      (state[i + 1] & NUMPY_RANDOM_LOWER_MASK)
    state[i] = (state[i + NUMPY_RANDOM_M] ^ (y >> 1) ^ matrix_of(y)) &
      NUMPY_RANDOM_MASK
    i = i + 1
  }
  while i < NUMPY_RANDOM_STATE_LEN - 1 {
    let y = (state[i] & NUMPY_RANDOM_UPPER_MASK) |
      (state[i + 1] & NUMPY_RANDOM_LOWER_MASK)
    state[i] = (
        state[i + NUMPY_RANDOM_M - NUMPY_RANDOM_STATE_LEN] ^
        (y >> 1) ^
        matrix_of(y)
      ) &
      NUMPY_RANDOM_MASK
    i = i + 1
  }
  let last = NUMPY_RANDOM_STATE_LEN - 1
  let y = (state[last] & NUMPY_RANDOM_UPPER_MASK) |
    (state[0] & NUMPY_RANDOM_LOWER_MASK)
  state[last] = (state[NUMPY_RANDOM_M - 1] ^ (y >> 1) ^ matrix_of(y)) &
    NUMPY_RANDOM_MASK
  self.index = 0
}

///|
/// The matrix of the twist for a word whose low bit is set.
fn matrix_of(y : UInt64) -> UInt64 {
  if (y & 1UL) == 1UL {
    NUMPY_RANDOM_MATRIX_A
  } else {
    0UL
  }
}

///|
/// The smallest mask of bits that holds the given number.
///
/// This is the port of `gen_mask` of numpy.
fn mask_of(rng : Int32) -> UInt64 {
  let mut mask = rng.to_uint64()
  mask = mask | (mask >> 1)
  mask = mask | (mask >> 2)
  mask = mask | (mask >> 4)
  mask = mask | (mask >> 8)
  mask = mask | (mask >> 16)
  mask
}
