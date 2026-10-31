"""An independent reference for the one-hot encoding of the port.

This script prints what `pandas.get_dummies` and
`sklearn.preprocessing.OneHotEncoder` produce for the data set the encoding
tests of the port use, so that the expected values of the MoonBit tests can
be checked against the two libraries upstream relies on.

Usage:
    python _verify/encoding_reference.py
"""

from __future__ import annotations

import pandas as pd
from sklearn.preprocessing import OneHotEncoder

DISCRETE = ["X", "Y", "Z", "X", "Y", "Z"]
NUMERIC = [1, 2, 3, 4, 5, 6]


def main() -> None:
    frame = pd.DataFrame({"C": DISCRETE, "N": NUMERIC})

    dummies = pd.get_dummies(frame, drop_first=True).astype(float)
    print("GET_DUMMIES")
    print("  columns:", list(dummies.columns))
    for index in range(len(dummies)):
        print("  row:", [float(value) for value in dummies.iloc[index]])

    encoder = OneHotEncoder(drop="first", sparse_output=False)
    encoded = encoder.fit_transform(frame[["C"]])
    print("ONEHOT_ENCODER")
    print("  names:", list(encoder.get_feature_names_out(["C"])))
    for row in encoded:
        print("  row:", [float(value) for value in row])
    print("  categories:", [list(c) for c in encoder.categories_])


if __name__ == "__main__":
    main()
