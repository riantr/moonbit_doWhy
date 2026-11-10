"""Print the columns of the `PolynomialFeatures` of scikit-learn.

The upstream builds its polynom regressor with
`make_pipeline(PolynomialFeatures(degree=degree, include_bias=False),
LinearRegression())`, so the order of the columns of the expansion decides
which coefficient is which, and the port has to use the same order.

This script prints the columns of the expansion of two and of three features
for the degrees two and three, and it fits the upstream's own polynom regressor
on the fixture of `tests/gcm/ml/test_regression.py`, whose target is the product
of the two features, so that the port has the numbers to compare against.

Run: python _verify/polynom_features_reference.py
"""

import sys

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

import numpy as np
from sklearn.preprocessing import PolynomialFeatures

print("=" * 70)
print("the columns of the expansion")
print("=" * 70)
for n in (2, 3):
    for degree in (2, 3):
        x = np.arange(1.0, n + 1.0).reshape(1, n)
        poly = PolynomialFeatures(degree=degree, include_bias=False)
        expanded = poly.fit_transform(x)
        names = []
        for exponents in poly.powers_:
            parts = []
            for index, value in enumerate(exponents):
                if value == 1:
                    parts.append("x{}".format(index))
                elif value == 2:
                    parts.append("x{}*x{}".format(index, index))
                elif value == 3:
                    parts.append("x{}*x{}*x{}".format(index, index, index))
            names.append(" + ".join(parts))
        print(
            "n={} degree={} -> {} columns: {}".format(
                n, degree, expanded.shape[1], names
            )
        )

print()
print("=" * 70)
print("the fit of the upstream on the fixture of its test file")
print("=" * 70)
from dowhy.gcm.ml.regression import create_polynom_regressor

rng = np.random.default_rng(2024)
x = rng.normal(0, 1, (100, 2))
y = x[:, 0] * x[:, 1]
model = create_polynom_regressor(degree=2)
model.fit(x, y)
x_test = rng.normal(0, 1, (100, 2))
y_test = x_test[:, 0] * x_test[:, 1]
prediction = model.predict(x_test).reshape(-1)
print("the maximum error of the prediction:", float(np.max(np.abs(prediction - y_test))))
print("the coefficients of the model:", model.sklearn_model.named_steps["linearregression"].coef_)
print("the intercept of the model:", model.sklearn_model.named_steps["linearregression"].intercept_)
print("the features of the model:", model.sklearn_model.named_steps["polynomialfeatures"].get_feature_names_out())

print()
print("the same with the degree three")
model3 = create_polynom_regressor(degree=3)
model3.fit(x, y)
prediction3 = model3.predict(x_test).reshape(-1)
print("the maximum error of the prediction:", float(np.max(np.abs(prediction3 - y_test))))
print("the coefficients of the model:", model3.sklearn_model.named_steps["linearregression"].coef_)
