///|
/// A small deterministic pseudo random generator.
///
/// The refuters need reproducible randomness, so the port carries its own
/// generator instead of relying on the platform entropy of the toolchain. It
/// is a 64 bit xorshift, which is enough for the resampling and the noise the
/// refuters add.
pub struct Random {
  mut state : UInt64
}

///|
/// A generator with the given seed.
pub fn Random::new(seed : UInt64) -> Random {
  // A zero state would stay zero, so it is replaced by a constant.
  let state = if seed == 0UL { 0x9E3779B97F4A7C15UL } else { seed }
  { state, }
}

///|
/// The next raw 64 bit value.
pub fn Random::next_u64(self : Random) -> UInt64 {
  let mut x = self.state
  x = x ^ (x << 13)
  x = x ^ (x >> 7)
  x = x ^ (x << 17)
  self.state = x
  x
}

///|
/// The next value in `[0, 1)`.
pub fn Random::next_double(self : Random) -> Double {
  let bits = self.next_u64() >> 11
  bits.to_double() / 9007199254740992.0
}

///|
/// The next value in `[0, bound)`.
pub fn Random::next_int(self : Random, bound : Int32) -> Int32 {
  if bound <= 0 {
    return 0
  }
  (self.next_u64() % bound.to_uint64()).to_int()
}

///|
/// The next value from the standard normal distribution.
///
/// Box-Muller transform; the second variate is discarded.
pub fn Random::next_normal(self : Random) -> Double {
  let u1 = self.next_double()
  let u2 = self.next_double()
  let u1 = if u1 < 1.0e-12 { 1.0e-12 } else { u1 }
  (-2.0 * @math.ln(u1)).sqrt() * @math.cos(2.0 * @math.PI * u2)
}

///|
/// The next value from a gamma distribution.
///
/// This is the port of the gamma variate of numpy, which is drawn with the
/// algorithm of Marsaglia and Tsang. A gamma variate with the shape `a` and
/// the scale `b` has the mean `a * b` and the variance `a * b * b`.
///
/// The shape has to be positive. A shape that is smaller than one is drawn
/// from the shape that is one greater, which is the way the algorithm of
/// Marsaglia and Tsang is extended to the shapes below one.
pub fn Random::next_gamma(
  self : Random,
  shape : Double,
  scale : Double,
) -> Double {
  if shape <= 0.0 {
    abort("the shape of a gamma distribution has to be positive")
  }
  if shape < 1.0 {
    // The algorithm of Marsaglia and Tsang needs a shape of at least one, so
    // the variate of a smaller shape is the variate of the shape that is one
    // greater, multiplied with the power of a uniform variate.
    let uniform = self.next_double()
    let powered = if uniform < 1.0e-12 {
      1.0e-12
    } else {
      @math.pow(uniform, 1.0 / shape)
    }
    return self.next_gamma(shape + 1.0, scale) * powered
  }
  let d = shape - 1.0 / 3.0
  let c = 1.0 / (9.0 * d).sqrt()
  let mut value = 0.0
  let mut accepted = false
  while !accepted {
    let x = self.next_normal()
    let v = (1.0 + c * x) * (1.0 + c * x) * (1.0 + c * x)
    if v > 0.0 {
      let u = self.next_double()
      let log_u = if u < 1.0e-12 { -27.631021 } else { @math.ln(u) }
      if log_u < 0.5 * x * x + d * (1.0 - v + @math.ln(v)) {
        value = d * v
        accepted = true
      }
    }
  }
  value * scale
}

///|
/// A random permutation of the given values.
pub fn Random::shuffle(self : Random, values : Array[Double]) -> Array[Double] {
  let out = values.copy()
  let n = out.length()
  let mut i = n - 1
  while i > 0 {
    let j = self.next_int(i + 1)
    let tmp = out[i]
    out[i] = out[j]
    out[j] = tmp
    i = i - 1
  }
  out
}

///|
/// A sample of `size` values drawn with replacement.
pub fn Random::sample_with_replacement(
  self : Random,
  values : Array[Double],
  size : Int32,
) -> Array[Double] {
  let out : Array[Double] = []
  for i = 0; i < size; i = i + 1 {
    out.push(values[self.next_int(values.length())])
  }
  out
}

///|
/// A sample of `size` values drawn without replacement.
///
/// The sample holds no value twice, so it is a subset of the given values. A
/// size that is larger than the number of the values gives the values
/// themselves.
pub fn Random::sample_without_replacement(
  self : Random,
  values : Array[Double],
  size : Int32,
) -> Array[Double] {
  let count = if size > values.length() { values.length() } else { size }
  let pool = self.shuffle(values)
  let out : Array[Double] = []
  for i = 0; i < count; i = i + 1 {
    out.push(pool[i])
  }
  out
}
