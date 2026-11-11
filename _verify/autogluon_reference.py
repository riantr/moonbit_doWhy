"""The numbers of the upstream's model that selects itself.

The upstream wraps the `TabularPredictor` of AutoGluon, which needs the
optional AutoGluon dependency, so the script fits the model that the `LR`
hyperparameter of AutoGluon means, which is the linear regression of
scikit-learn and the logistic regression of scikit-learn, and it prints the
numbers that the tests of the port assert.

The script draws the fixtures of the upstream with the global generator of
numpy, so the rows of the port and the rows of the upstream are the same rows.

Usage:

    python _verify/autogluon_reference.py
"""

from __future__ import annotations

import sys

import numpy as np
from sklearn.linear_model import LinearRegression, LogisticRegression

sys.path.insert(0, r"D:\src\MiniMax\git\dowhy\dowhy-0.14")

SEED = 42


def generate_linear_data(num_samples, noise_std):
    """The fixture of the upstream, `_generate_linear_data`."""
    num_features = int(np.random.choice(20, 1)[0] + 1)
    coefficients = np.random.uniform(-5, 5, num_features)
    x = np.random.normal(0, 1, (num_samples, num_features))
    y = np.sum(coefficients * x, axis=1) + np.random.normal(0, noise_std, num_samples)
    return x, y, coefficients


def generate_linear_classification_data(num_samples, noise_std):
    """The fixture of the upstream, `_generate_linear_classification_data`."""
    x, y, _ = generate_linear_data(num_samples, noise_std)
    return x, (y > np.median(y)).astype(str)


def train_test_split(x, y):
    """The split of the upstream, `train_test_split` with a test size of a half."""
    permutation = np.random.permutation(len(x))
    test_size = int(np.ceil(0.5 * len(x)))
    test = permutation[:test_size]
    train = permutation[test_size:]
    return x[train], y[train], x[test], y[test]


print("=== the accuracy of the linear classifier")
np.random.seed(SEED)
x, y = generate_linear_classification_data(1000, 0.2)
x_train, y_train, x_test, y_test = train_test_split(x, y)
classifier = LogisticRegression().fit(x_train, y_train)
predicted = classifier.predict(x_test)
print(np.sum(predicted == y_test) / x_test.shape[0])
print("--- the classes of the target")
print(sorted(set(y)))
print("--- the number of the features")
print(x.shape[1])
print()

print("=== the deviation of the linear regression")
np.random.seed(SEED)
x, y, _ = generate_linear_data(2000, 0.2)
x_train, y_train, x_test, y_test = train_test_split(x, y)
regressor = LinearRegression().fit(x_train, y_train)
print(np.std(regressor.predict(x_test) - y_test))
print("--- the number of the features")
print(x.shape[1])
print()

print("=== the fixture of the categorical model")
np.random.seed(SEED)
x = np.random.normal(0, 1, (100, 3))
labels = np.random.choice(3, 100, replace=True).astype(str)
print(sorted(set(labels)))
print(x.shape)
print()

print("=== the fixture of the additive noise model")
np.random.seed(SEED)
x = np.random.normal(0, 1, (100, 3))
y = np.random.normal(0, 1, (100, 1))
print(x.shape)
print(y.shape)
