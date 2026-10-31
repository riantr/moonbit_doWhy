///|
/// The smallest positive double, like `numpy.finfo(numpy.float64).eps`.
///
/// The upstream `dowhy.gcm.constant.EPS` uses it to guard the divisions that
/// would otherwise be by zero, for instance when a probability of a category
/// is smoothed before a logarithm is taken.
pub const EPS : Double = 2.220446049250313e-16
