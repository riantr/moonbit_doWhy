///|
/// The tests of the data generating processes of the upstream.
///
/// The upstream has no test file for its data generating processes, so the
/// expected numbers of the port are the numbers of the upstream, which the
/// script `_verify/dgp_reference.py` prints.
///
/// The numbers of the upstream are the numbers of numpy, which the upstream
/// draws from the global generator of numpy, so the port draws them from its
/// own generator of numpy with the seed of the process.

///|
/// The tolerance of the comparison of the numbers of the data.
///
/// The upstream computes the mean of a column with the pairwise sum of numpy
/// and the port computes it with a plain sum, and the upstream computes the
/// product of its matrices with the library of linear algebra and the port
/// computes it with a plain loop, so the numbers of the port and the numbers
/// of the upstream differ in the last digits.
const DGP_TOLERANCE : Double = 1.0e-9

///|
/// Whether two numbers agree to the tolerance of the comparison.
fn dgp_agrees(a : Double, b : Double) -> Bool {
  (a - b).abs() <= DGP_TOLERANCE
}

///|
/// The configuration of the data generating processes of the tests.
fn dgp_config(binary~ : Bool = false) -> @datasets.DgpConfig {
  @datasets.DgpConfig::new(
    ["t1"],
    ["y"],
    ["w1", "w2"],
    ["x1"],
    Some(42),
    binary,
  )
}

///|
/// Whether the column of the data holds the expected values.
///
/// The script of the reference prints the first rows of every column, so the
/// comparison holds the rows that the script prints.
fn dgp_column_is(
  data : @api.DataFrame,
  name : String,
  expected : Array[Double],
) -> Bool {
  let values = data.numeric(name)
  if values.length() < expected.length() {
    return false
  }
  for index in 0..<expected.length() {
    if !dgp_agrees(values[index], expected[index]) {
      return false
    }
  }
  true
}

///|
test "the data of the linear process is the data of the upstream" {
  let process = @datasets.DataGeneratingProcess::new_linear(dgp_config())
  let data = process.generate_data(10)
  assert_eq(data.nrows(), 10)
  assert_eq(data.column_names(), ["x1", "w1", "w2", "t1", "y"])
  // The linear process of the upstream has no effect modifier.
  assert_true(
    dgp_column_is(data, "x1", [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]),
  )
  assert_true(
    dgp_column_is(data, "w1", [
      -0.4694743859349521, -0.46341769281246226, 0.24196227156603412, -1.7249178325130328,
      -1.0128311203344238,
    ]),
  )
  assert_true(
    dgp_column_is(data, "w2", [
      0.5425600435859647, -0.46572975357025687, -1.913280244657798, -0.5622875292409727,
      0.3142473325952739,
    ]),
  )
  assert_true(
    dgp_column_is(data, "t1", [
      -46.27707572514659, -45.22004254339585, 25.558457800635246, -169.83933905918983,
      -100.26393318258944,
    ]),
  )
  assert_true(
    dgp_column_is(data, "y", [
      -34.82256821097615, -35.996122045562885, 16.22221560565819, -133.93227270877566,
      -77.21757613499511,
    ]),
  )
}

///|
test "the effect of the linear process is the effect of the upstream" {
  let process = @datasets.DataGeneratingProcess::new_linear(dgp_config())
  let _ = process.generate_data(10)
  let effect = process.effect()
  assert_eq(effect.length(), 1)
  assert_true(dgp_agrees(effect[0], -0.23413695694918263))
}

///|
test "the weights of the linear process are the weights of the upstream" {
  let process = @datasets.DataGeneratingProcess::new_linear(dgp_config())
  let _ = process.generate_data(10)
  let sets = process.weights_of_powers()
  assert_eq(sets.length(), 1)
  let weights = sets[0]
  // The linear process of the upstream raises the weight of the first
  // confounder by a hundred.
  assert_true(
    dgp_agrees(weights.confounder_to_treatment.get(0, 0), 100.49671415301123),
  )
  assert_true(
    dgp_agrees(weights.confounder_to_treatment.get(1, 0), -0.13826430117118466),
  )
  assert_true(
    dgp_agrees(weights.confounder_to_outcome.get(0, 0), 100.6476885381007),
  )
  assert_true(
    dgp_agrees(weights.confounder_to_outcome.get(1, 0), 1.5230298564080254),
  )
  assert_true(
    dgp_agrees(
      weights.effect_modifier_to_outcome.get(0, 0),
      -0.23415337472333597,
    ),
  )
  assert_true(
    dgp_agrees(weights.treatment_to_outcome.get(0, 0), -0.23413695694918055),
  )
  let biases = process.bias_of_powers()
  assert_eq(biases.length(), 1)
  assert_true(
    dgp_agrees(biases[0].confounder_to_treatment[0], 1.5792128155073915),
  )
  assert_true(
    dgp_agrees(biases[0].confounder_to_outcome[0], 0.7674347291529088),
  )
}

///|
test "the data of the quadratic process is the data of the upstream" {
  let process = @datasets.DataGeneratingProcess::new_quadratic(dgp_config())
  let data = process.generate_data(10)
  assert_eq(data.nrows(), 10)
  assert_eq(data.column_names(), ["x1", "w1", "w2", "t1", "y"])
  // The quadratic process of the upstream draws its effect modifier.
  assert_true(
    dgp_column_is(data, "x1", [
      1.465648768921554, -0.22577630048653566, 0.06752820468792384, -1.4247481862134568,
      -0.5443827245251827,
    ]),
  )
  assert_true(
    dgp_column_is(data, "w1", [
      0.4967141530112327, 0.6476885381006925, -0.23415337472333597, 1.5792128155073915,
      -0.4694743859349521,
    ]),
  )
  assert_true(
    dgp_column_is(data, "w2", [
      -0.13826430117118466, 1.5230298564080254, -0.23413695694918055, 0.7674347291529088,
      0.5425600435859647,
    ]),
  )
  assert_true(
    dgp_column_is(data, "t1", [
      -1.674302592904217, 2.8370813322138657, 0.6545350313027494, 0.851511689830984,
      1.3806732874264123,
    ]),
  )
  assert_true(
    dgp_column_is(data, "y", [
      -1.2447463075332204, -17.658960829501886, -3.1886330966450855, -13.175260166217855,
      -8.310871727362787,
    ]),
  )
  let effect = process.effect()
  assert_eq(effect.length(), 1)
  assert_true(dgp_agrees(effect[0], -3.2748114534376915))
}

///|
test "the weights of the quadratic process are the weights of the upstream" {
  let process = @datasets.DataGeneratingProcess::new_quadratic(dgp_config())
  let _ = process.generate_data(10)
  // The upstream keeps the weights of every power in a list whose entries are
  // the same dictionary, so every set of the list holds the weights of the
  // last power.
  let sets = process.weights_of_powers()
  assert_eq(sets.length(), 2)
  for index in 0..<sets.length() {
    let weights = sets[index]
    assert_true(
      dgp_agrees(weights.confounder_to_treatment.get(0, 0), -0.8392175232226385),
    )
    assert_true(
      dgp_agrees(weights.confounder_to_treatment.get(1, 0), -0.3092123758512146),
    )
    assert_true(
      dgp_agrees(weights.confounder_to_outcome.get(0, 0), 0.33126343140356396),
    )
    assert_true(
      dgp_agrees(weights.confounder_to_outcome.get(1, 0), 0.9755451271223592),
    )
    assert_true(
      dgp_agrees(
        weights.effect_modifier_to_outcome.get(0, 0),
        -0.47917423784528995,
      ),
    )
    assert_true(
      dgp_agrees(weights.treatment_to_outcome.get(0, 0), -0.18565897666381712),
    )
  }
}

///|
test "the data of the cubic process is the data of the upstream" {
  let process = @datasets.DataGeneratingProcess::new_cubic(dgp_config())
  let data = process.generate_data(10)
  assert_eq(data.nrows(), 10)
  assert_eq(data.column_names(), ["x1", "w1", "w2", "t1", "y"])
  assert_true(
    dgp_column_is(data, "x1", [
      1.465648768921554, -0.22577630048653566, 0.06752820468792384, -1.4247481862134568,
      -0.5443827245251827,
    ]),
  )
  assert_true(
    dgp_column_is(data, "w1", [
      0.4967141530112327, 0.6476885381006925, -0.23415337472333597, 1.5792128155073915,
      -0.4694743859349521,
    ]),
  )
  assert_true(
    dgp_column_is(data, "t1", [
      2.8725675577875327, -11.200538220043157, -0.1851006266477178, 0.3275605075849982,
      -0.49566071888045726,
    ]),
  )
  assert_true(
    dgp_column_is(data, "y", [
      -1.490872994171099, 10.906313450298622, -6.642369677147254, -23.058426729679557,
      -5.03527531932976,
    ]),
  )
  let effect = process.effect()
  assert_eq(effect.length(), 1)
  assert_true(dgp_agrees(effect[0], -13.206825405846313))
}

///|
test "the weights of the cubic process are the weights of the upstream" {
  let process = @datasets.DataGeneratingProcess::new_cubic(dgp_config())
  let _ = process.generate_data(10)
  let sets = process.weights_of_powers()
  assert_eq(sets.length(), 3)
  for index in 0..<sets.length() {
    let weights = sets[index]
    assert_true(
      dgp_agrees(
        weights.confounder_to_treatment.get(0, 0),
        -0.07201012158033385,
      ),
    )
    assert_true(
      dgp_agrees(weights.confounder_to_treatment.get(1, 0), 1.0035328978920242),
    )
    assert_true(
      dgp_agrees(weights.confounder_to_outcome.get(0, 0), 0.36163602504763415),
    )
    assert_true(
      dgp_agrees(weights.confounder_to_outcome.get(1, 0), -0.6451197546051243),
    )
    assert_true(
      dgp_agrees(
        weights.effect_modifier_to_outcome.get(0, 0),
        0.36139560550841393,
      ),
    )
    assert_true(
      dgp_agrees(weights.treatment_to_outcome.get(0, 0), 1.5380365664659692),
    )
  }
  let biases = process.bias_of_powers()
  assert_eq(biases.length(), 3)
  for index in 0..<biases.length() {
    assert_true(
      dgp_agrees(biases[index].confounder_to_treatment[0], -0.03582603910995154),
    )
    assert_true(
      dgp_agrees(biases[index].confounder_to_outcome[0], 1.5646436558140062),
    )
  }
}

///|
test "the data of the binary treatment is the data of the upstream" {
  let process = @datasets.DataGeneratingProcess::new_linear(
    dgp_config(binary=true),
  )
  let data = process.generate_data(10)
  assert_eq(data.nrows(), 10)
  assert_eq(data.column_names(), ["x1", "w1", "w2", "t1", "y"])
  // The treatment of the upstream is converted with a Bernoulli for every row
  // and a second Bernoulli for every row that it flips.
  assert_true(
    dgp_column_is(data, "t1", [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0]),
  )
  assert_true(
    dgp_column_is(data, "y", [
      -45.657741897768766, -46.58380519978607, 22.206395139412972, -173.69793872635447,
      -100.69306834212257,
    ]),
  )
  let effect = process.effect()
  assert_true(dgp_agrees(effect[0], -0.23413695694918263))
}

///|
test "the deterministic conversion of the treatment is the conversion of the upstream" {
  let process = @datasets.DataGeneratingProcess::new_linear(dgp_config())
  let data = process.generate_data(10)
  let treatment = data.numeric("t1")
  let binary = @datasets.DataGeneratingProcess::new_linear(
    dgp_config(binary=true),
  )
  let converted = binary.convert_to_binary(treatment, deterministic=true)
  assert_eq(converted.length(), 10)
  // The upstream passes the percentile of the process, which is a fraction, to
  // the percentile of numpy, which expects a number between zero and a
  // hundred, so the upstream takes the percentile of a fraction of a percent.
  let threshold = @utils.percentile(treatment, 0.9)
  assert_true(dgp_agrees(threshold, -165.48673410882924))
  for index in 0..<converted.length() {
    let expected = if treatment[index] <= threshold { 1.0 } else { 0.0 }
    assert_eq(converted[index], expected)
  }
  assert_eq(converted[3], 1.0)
  assert_eq(converted[0], 0.0)
}
