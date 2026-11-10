///|
/// The tests of the generator of numpy.
///
/// The upstream of DoWhy draws its randomness from the global generator of
/// numpy, and the generator has no test file of its own in the upstream, so
/// the expected numbers of the port are the numbers of numpy, which the
/// script `_verify/numpy_random_reference.py` prints.

///|
/// Whether two numbers of the generator are the same number.
///
/// The numbers that come out of the logarithm may differ by one unit in the
/// last place between the backends of the toolchain, so they are compared
/// with a tolerance. The other numbers are compared with the equality.
fn numpy_near(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-14
}

///|
/// The generator of numpy, advanced by the given number of doubles.
fn after_doubles(
  generator : @utils.NumpyRandom,
  count : Int32,
) -> @utils.NumpyRandom {
  for _ in 0..<count {
    let _ = generator.next_double()
  }
  generator
}

///|
/// The generator of numpy, advanced by the given number of uniforms.
fn after_uniforms(
  generator : @utils.NumpyRandom,
  count : Int32,
) -> @utils.NumpyRandom {
  for _ in 0..<count {
    let _ = generator.uniform(-1.0, 1.0)
  }
  generator
}

///|
/// The generator of numpy, advanced by the given number of normal variates.
fn after_normals(
  generator : @utils.NumpyRandom,
  count : Int32,
) -> @utils.NumpyRandom {
  for _ in 0..<count {
    let _ = generator.standard_normal()
  }
  generator
}

///|
/// The generator of numpy, advanced by the given number of Bernoulli trials.
fn after_trials(
  generator : @utils.NumpyRandom,
  count : Int32,
) -> @utils.NumpyRandom {
  for _ in 0..<count {
    let _ = generator.bernoulli(0.3)
  }
  generator
}

///|
/// The generator of numpy, advanced by the given number of integers of the
/// range of ten numbers.
fn after_integers(
  generator : @utils.NumpyRandom,
  count : Int32,
) -> @utils.NumpyRandom {
  for _ in 0..<count {
    let _ = generator.randint(10)
  }
  generator
}

///|
/// The generator of numpy, at the point where the Bernoulli of numpy starts.
///
/// The script of the reference draws six doubles, five uniforms and ten
/// normal variates before the Bernoulli.
fn at_the_trials(generator : @utils.NumpyRandom) -> @utils.NumpyRandom {
  after_normals(
    after_normals(after_uniforms(after_doubles(generator, 6), 5), 5),
    5,
  )
}

///|
test "the doubles of the generator are the doubles of numpy" {
  let generator = @utils.NumpyRandom::new(42)
  let expected = [
    0.3745401188473625, 0.9507143064099162, 0.7319939418114051, 0.5986584841970366,
    0.15601864044243652, 0.15599452033620265,
  ]
  for i in 0..<6 {
    assert_true(generator.next_double() == expected[i])
  }
}

///|
test "the uniforms of the generator are the uniforms of numpy" {
  let generator = after_doubles(@utils.NumpyRandom::new(42), 6)
  let expected = [
    -0.8838327756636011, 0.7323522915498704, 0.2022300234864176, 0.416145155592091,
    -0.9588310114083951,
  ]
  for i in 0..<5 {
    assert_true(generator.uniform(-1.0, 1.0) == expected[i])
  }
}

///|
test "the normal variates of the generator are the ones of numpy" {
  let generator = after_uniforms(
    after_doubles(@utils.NumpyRandom::new(42), 6),
    5,
  )
  let expected = [
    -0.580878134023515, -0.5251698071781478, -0.5713801657541415, -0.9240828377471049,
    -2.6125490126936013,
  ]
  for i in 0..<5 {
    assert_true(numpy_near(generator.standard_normal(), expected[i]))
  }
}

///|
test "the normal distribution of the generator is the one of numpy" {
  let generator = after_normals(
    after_uniforms(after_doubles(@utils.NumpyRandom::new(42), 6), 5),
    5,
  )
  let expected = [
    2.4751848411984514, 2.4082225404756636, 1.2380620011920696, 1.7859769679118829,
    1.6287965814404137,
  ]
  for i in 0..<5 {
    assert_true(numpy_near(generator.normal(2.0, 0.5), expected[i]))
  }
}

///|
test "the Bernoulli trials of the generator are the ones of numpy" {
  let generator = at_the_trials(@utils.NumpyRandom::new(42))
  let expected = [0, 0, 1, 0, 0, 0, 0, 0, 0, 0]
  for i in 0..<10 {
    assert_eq(generator.bernoulli(0.3), expected[i])
  }
}

///|
test "the integers of the generator are the integers of numpy" {
  let generator = after_trials(at_the_trials(@utils.NumpyRandom::new(42)), 10)
  let expected = [3, 8, 1, 9, 8, 9, 4, 1, 3, 6]
  for i in 0..<10 {
    assert_eq(generator.randint(10), expected[i])
  }
}

///|
test "the permutation of the generator is the permutation of numpy" {
  let generator = after_integers(
    after_trials(at_the_trials(@utils.NumpyRandom::new(42)), 10),
    10,
  )
  let expected = [6, 8, 4, 9, 1, 3, 0, 5, 2, 7]
  let values = generator.permutation(10)
  assert_eq(values.length(), 10)
  for i in 0..<10 {
    assert_eq(values[i], expected[i])
  }
}

///|
test "the generator of another seed is the generator of numpy" {
  let generator = @utils.NumpyRandom::new(7)
  let doubles = [
    0.07630828937395717, 0.7799187922401146, 0.4384092314408935, 0.7234651778309412,
    0.9779895119966027, 0.5384958704104337,
  ]
  for i in 0..<6 {
    assert_true(generator.next_double() == doubles[i])
  }
  let uniforms = [
    0.002240927319875796, -0.8558977332804769, -0.46312203979625766, -0.00023499834888007776,
    0.35845999224188096,
  ]
  for i in 0..<5 {
    assert_true(generator.uniform(-1.0, 1.0) == uniforms[i])
  }
  let normals = [
    -0.47693169954525966, 1.2167323487819706, -0.16313207477419955, -0.3342375899769537,
    -0.014968207048865785,
  ]
  for i in 0..<5 {
    assert_true(numpy_near(generator.standard_normal(), normals[i]))
  }
  // The script of the reference draws ten normal variates before the
  // Bernoulli.
  let generator = after_normals(generator, 5)
  let trials = [1, 0, 0, 1, 0, 0, 1, 0, 0, 0]
  for i in 0..<10 {
    assert_eq(generator.bernoulli(0.3), trials[i])
  }
  let integers = [7, 7, 9, 3, 0, 7, 7, 7, 0, 5]
  for i in 0..<10 {
    assert_eq(generator.randint(10), integers[i])
  }
  let permutation = [2, 9, 0, 7, 5, 6, 8, 1, 3, 4]
  let values = generator.permutation(10)
  for i in 0..<10 {
    assert_eq(values[i], permutation[i])
  }
}

///|
test "the multivariate normal of the generator is the one of numpy" {
  let generator = @utils.NumpyRandom::new(42)
  let means = [-0.250919762305275, 0.9014286128198323, 0.4639878836228102]
  // The script of the reference draws the means before the values.
  for _ in 0..<3 {
    let _ = generator.uniform(-1.0, 1.0)
  }
  let values = generator.multivariate_normal_identity(means, 4)
  let expected = [
    [-1.3627998803521955, 1.2203307975092157, 0.7430291758229479],
    [0.7595955225012514, 0.3205504787963174, -0.06118192355533758],
    [-0.8222999280594165, -0.022654224927272537, -2.1485611290707913],
    [0.6994499200916281, 1.7178736937711596, -1.0598881139930507],
  ]
  assert_eq(values.nrows(), 4)
  assert_eq(values.ncols(), 3)
  for i in 0..<4 {
    for j in 0..<3 {
      assert_true(numpy_near(values.get(i, j), expected[i][j]))
    }
  }
}
