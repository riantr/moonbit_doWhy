"""Run the two upstream test cases of the polynom models and report what they do.

The upstream marks both of the tests of `tests/gcm/ml/test_regression.py` as
flaky, and the second one uses a categorical column, which the upstream encodes
before the polynomial expansion.  The port has to know whether the second case
reproduces, and what the upstream's expansion looks like after the encoding.

Run: python _verify/probe_polynom_upstream_tests.py
"""

import sys

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

import numpy as np

from dowhy.gcm.ml.regression import create_polynom_regressor
from dowhy.gcm.ml.classification import create_polynom_logistic_regression_classifier
from dowhy.gcm.util.general import auto_fit_encoders, auto_apply_encoders

print("=" * 70)
print("the categorical regression case of the upstream")
print("=" * 70)


def generate_data():
    X = np.column_stack(
        [np.random.choice(2, 100, replace=True).astype(str), np.random.normal(0, 1, (100, 2)).astype(object)]
    ).astype(object)
    Y = []
    for i in range(X.shape[0]):
        Y.append(X[i, 1] * X[i, 2] if X[i, 0] == "0" else X[i, 1] + X[i, 2])
    return X, np.array(Y)


np.random.seed(2024)
X_training, Y_training = generate_data()
X_test, Y_test = generate_data()

encoders = auto_fit_encoders(X_training, Y_training)
print("the encoders:", {k: type(v).__name__ for k, v in encoders.items()})
encoded = auto_apply_encoders(X_training, encoders)
print("the shape of the encoded training data:", encoded.shape, encoded.dtype)

model = create_polynom_regressor(degree=3)
model.fit(X_training, Y_training)
steps = model.sklearn_model.named_steps
print("the features of the model:", steps["polynomialfeatures"].get_feature_names_out())
print("the coefficients of the model:", steps["linearregression"].coef_)
prediction = model.predict(X_test).reshape(-1)
print("the maximum error of the prediction:", float(np.max(np.abs(prediction - Y_test))))
print("the upstream's tolerance is 1e-10, so the case passes:", bool(np.max(np.abs(prediction - Y_test)) < 1e-10))

print()
print("=" * 70)
print("the classification case of the upstream")
print("=" * 70)


def generate_classes():
    X = np.random.normal(0, 1, (1000, 2))
    Y = []
    for x in X:
        Y.append("Class 0" if x[0] * x[1] > 0 else "Class 1")
    return X, np.array(Y)


np.random.seed(2024)
X_training, Y_training = generate_classes()
X_test, Y_test = generate_classes()

classifier = create_polynom_logistic_regression_classifier()
classifier.fit(X_training, Y_training)
predicted = classifier.predict(X_test).reshape(-1)
print("the number of the correct predictions:", int(np.sum(predicted == Y_test)), "of", len(Y_test))
print("the upstream asks for more than 950")

print()
print("the same fit with the degree two")
classifier2 = create_polynom_logistic_regression_classifier(degree=2)
classifier2.fit(X_training, Y_training)
predicted2 = classifier2.predict(X_test).reshape(-1)
print("the number of the correct predictions:", int(np.sum(predicted2 == Y_test)), "of", len(Y_test))
