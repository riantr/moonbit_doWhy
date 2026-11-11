/// The text of a number.
///
/// MoonBit writes an integral number without a decimal point, and Python writes
/// one with it. The helpers of this file write the numbers the way the
/// upstream writes them, so the text of a number of the port is the text of
/// the number of the upstream.

///|
/// The text of a number, the way Python writes it.
///
/// The text of an integral number gets a decimal point, the text of a number
/// that has an exponent keeps it, and the text of a number that is neither a
/// number nor an infinity is the one of MoonBit.
pub fn float_text(value : Double) -> String {
  if value.is_nan() {
    return "nan"
  }
  if value.is_inf() {
    return if value > 0.0 { "inf" } else { "-inf" }
  }
  let text = value.to_string()
  if text.contains(".") || text.contains("e") || text.contains("E") {
    return text
  }
  text + ".0"
}
