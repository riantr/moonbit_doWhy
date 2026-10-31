///|
/// The one-hot encoding of the discrete columns of a data frame.
///
/// This is the port of `dowhy.utils.encoding`, which replaces pandas'
/// `get_dummies` with `sklearn.preprocessing.OneHotEncoder` so that new data
/// can be encoded with the encoder that was fitted on the old data, and the
/// encodings stay consistent.
///
/// The categories of a column are its distinct values in lexicographic
/// order, which is what `numpy.unique` and the sorted categories of pandas
/// produce, and the name of an encoded column is `<column>_<category>`.
pub struct OneHotEncoder {
  /// The names of the encoded columns.
  columns : Array[String]
  /// The categories of every encoded column, in lexicographic order.
  categories : Array[Array[String]]
  /// Whether the first category of every column is dropped.
  drop_first : Bool
}

///|
/// The one-hot encoder of a data frame.
///
/// This is the port of `sklearn.preprocessing.OneHotEncoder` as the upstream
/// encoding helper uses it: the categories are learned from the data, and
/// the encoder can then encode other data with the same categories.
pub fn OneHotEncoder::fit(
  data : DataFrame,
  columns : Array[String],
  drop_first : Bool,
) -> OneHotEncoder {
  let categories : Array[Array[String]] = []
  for name in columns {
    categories.push(sorted_distinct(data.discrete(name)))
  }
  { columns: columns.copy(), categories, drop_first, }
}

///|
/// The names of the encoded columns.
pub fn OneHotEncoder::encoded_columns(self : OneHotEncoder) -> Array[String] {
  self.columns.copy()
}

///|
/// The categories of an encoded column, in lexicographic order.
pub fn OneHotEncoder::categories_of(
  self : OneHotEncoder,
  column : String,
) -> Array[String] {
  for i = 0; i < self.columns.length(); i = i + 1 {
    if self.columns[i] == column {
      return self.categories[i].copy()
    }
  }
  []
}

///|
/// The names of the columns the encoder produces.
///
/// The name of an encoded column is `<column>_<category>`, and the name of
/// the first category of a column is missing when the encoder drops it.
pub fn OneHotEncoder::get_feature_names_out(
  self : OneHotEncoder,
) -> Array[String] {
  let names : Array[String] = []
  for i = 0; i < self.columns.length(); i = i + 1 {
    let categories = self.categories[i]
    for j = 0; j < categories.length(); j = j + 1 {
      if self.drop_first && j == 0 {
        continue
      }
      names.push(self.columns[i] + "_" + categories[j])
    }
  }
  names
}

///|
/// Encode a data frame with the encoder.
///
/// The columns that are not encoded are kept, in the order they have in the
/// data, and the encoded columns follow them. A value that the encoder has
/// not seen is an error, exactly like it is for `sklearn`.
pub fn OneHotEncoder::transform(
  self : OneHotEncoder,
  data : DataFrame,
) -> DataFrame {
  let order : Array[String] = []
  let columns : Map[String, Column] = Map([])
  for name in data.column_names() {
    if self.encoded_columns().contains(name) {
      continue
    }
    match data.column(name) {
      Some(Numeric(values)) => {
        columns.set(name, Column::Numeric(values.copy()))
        order.push(name)
      }
      Some(Discrete(values)) => {
        columns.set(name, Column::Discrete(values.copy()))
        order.push(name)
      }
      None => ()
    }
  }
  for i = 0; i < self.columns.length(); i = i + 1 {
    let name = self.columns[i]
    let values = data.discrete(name)
    let categories = self.categories[i]
    for j = 0; j < categories.length(); j = j + 1 {
      if self.drop_first && j == 0 {
        continue
      }
      let category = categories[j]
      let encoded : Array[Double] = []
      for value in values {
        if value == category {
          encoded.push(1.0)
        } else {
          if !categories.contains(value) {
            abort(
              "The category " +
              value +
              " of the column " +
              name +
              " was not seen when the encoder was fitted",
            )
          }
          encoded.push(0.0)
        }
      }
      let encoded_name = name + "_" + category
      columns.set(encoded_name, Column::Numeric(encoded))
      order.push(encoded_name)
    }
  }
  DataFrame::new(order, columns)
}

///|
/// Encode the discrete columns of a data frame.
///
/// The result is the encoded frame and the encoder that produced it, so that
/// other data can be encoded with it.
pub fn one_hot_encode(
  data : DataFrame,
  columns : Array[String],
  drop_first : Bool,
) -> (DataFrame, OneHotEncoder) {
  let encoder = OneHotEncoder::fit(data, columns, drop_first)
  let encoded = encoder.transform(data)
  (encoded, encoder)
}

///|
/// Encode a data frame with an encoder that was fitted on other data.
pub fn one_hot_encode_with(
  data : DataFrame,
  encoder : OneHotEncoder,
) -> DataFrame {
  encoder.transform(data)
}

///|
/// The names of the discrete columns of a data frame.
pub fn discrete_columns(data : DataFrame) -> Array[String] {
  let names : Array[String] = []
  for name in data.column_names() {
    match data.column(name) {
      Some(Discrete(_)) => names.push(name)
      _ => ()
    }
  }
  names
}

///|
/// A registry of the one-hot encoders of a data set.
///
/// This is the port of `dowhy.utils.encoding.Encoders`: every named set of
/// variables gets its own encoder, so that the same variables are encoded
/// the same way every time.
pub struct Encoders {
  /// Whether the first category of every column is dropped.
  drop_first : Bool
  /// The encoders, keyed by their name.
  mut encoders : Map[String, OneHotEncoder]
}

///|
/// A registry of encoders.
///
/// The first category of every column is dropped unless `drop_first` is
/// false.
pub fn Encoders::new(drop_first : Bool) -> Encoders {
  { drop_first, encoders: Map([]), }
}

///|
/// Forget every encoder, so that the next encoding creates new ones.
pub fn Encoders::reset(self : Encoders) -> Unit {
  self.encoders = Map([])
}

///|
/// The names of the encoders the registry holds.
pub fn Encoders::names(self : Encoders) -> Array[String] {
  let names : Array[String] = []
  for name in self.encoders.keys() {
    names.push(name)
  }
  names
}

///|
/// Encode the discrete columns of a data frame.
///
/// The encoder of the given name is created when it does not exist yet and
/// is reused afterwards, so that the encoding of a column does not depend on
/// the order the data arrives in.
pub fn Encoders::encode(
  self : Encoders,
  data : DataFrame,
  encoder_name : String,
) -> DataFrame {
  let existing = match self.encoders.get(encoder_name) {
    Some(encoder) => Some(encoder)
    None => None
  }
  match existing {
    Some(encoder) => encoder.transform(data)
    None => {
      let encoder = OneHotEncoder::fit(
        data,
        discrete_columns(data),
        self.drop_first,
      )
      let encoded = encoder.transform(data)
      self.encoders.set(encoder_name, encoder)
      encoded
    }
  }
}

///|
/// The distinct values of a column, in lexicographic order.
fn sorted_distinct(values : Array[String]) -> Array[String] {
  let distinct : Array[String] = []
  for value in values {
    if !distinct.contains(value) {
      distinct.push(value)
    }
  }
  distinct.sort_by(fn(a, b) { a.lexical_compare(b) })
  distinct
}
