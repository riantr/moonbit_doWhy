"""Print the loss and the gradient scikit-learn computes for the network of the
dummy outcome refuter, and compare them with the ones of the port.

The port of the neural network of the dummy outcome refuter fits the
`MLPRegressor` of scikit-learn, whose loss is

    0.5 * mean((y - f)^2) + 0.5 * alpha * ||W||^2 / n

and whose gradient is the one of the backpropagation of scikit-learn, the delta
of the output layer carrying no factor of the number of the rows.

This script computes the loss and the gradient of scikit-learn at one fixed set
of parameters, with the private `_loss_grad_lbfgs` of its `MLPRegressor`, and
prints them next to the values the port produces for the same parameters. The
values of the port are the ones the test of the package asserts, so the two
agree to the last bits of the double, up to the order of the summations: numpy
sums with the pairwise summation of its `dot` and the port sums one term after
the other, which moves the last bits of the result.

Run: python _verify/neural_network_reference.py
"""

import numpy as np
from sklearn.neural_network import MLPRegressor

# The fixture of the port: the sizes of the layers, the covariates, the outcome,
# the penalty of the weights and the parameters.
SIZES = [2, 3, 2, 1]
X = np.array(
    [
        [0.3, -1.2],
        [0.7, 2.1],
        [-0.4, 1.5],
        [0.9, -0.6],
        [-1.1, 0.2],
        [1.8, -0.8],
        [0.4, 1.1],
    ]
)
Y = np.array([1.0, -2.0, 0.5, 3.0, -1.0, 2.0, 0.25])
ALPHA = 0.0001
PARAMETERS = np.array([((i * 37 % 23) - 11) * 0.17 + 0.3 for i in range(20)])

# The loss and the gradient scikit-learn computes for the fixture above.
SKLEARN_LOSS = 17.153361774652414
SKLEARN_GRADIENT = [
    1.0345624771931432,
    0.8929555714285715,
    2.8396286523417156,
    -1.8882831869737138,
    -0.3968621428571429,
    -6.105626248477717,
    -1.5315291268914284,
    8.060745442285711,
    2.6142857142857144e-05,
    0.48616268571428584,
    -0.7365525839360002,
    16.385012037257145,
    1.209022267663999,
    17.668258409080003,
    -2.500933661485714,
    0.49608,
    10.034374471897147,
    -0.6454460685714285,
    9.576627428571427,
    4.788313714285714,
]

# The loss and the gradient the port produces for the fixture above.
PORT_LOSS = 17.153361774652417
PORT_GRADIENT = [
    1.0345624771931434,
    0.8929555714285715,
    2.8396286523417156,
    -1.8882831869737136,
    -0.3968621428571429,
    -6.105626248477717,
    -1.5315291268914284,
    8.060745442285711,
    0.000026142857142857144,
    0.486162685714286,
    -0.7365525839360002,
    16.385012037257145,
    1.2090222676639988,
    17.668258409080003,
    -2.5009336614857136,
    0.49608,
    10.034374471897147,
    -0.6454460685714285,
    9.57662742857143,
    4.788313714285715,
]

# The tolerance of the comparison, the size of the last bits of a double.
TOLERANCE = 1e-12


def sklearn_loss_and_gradient():
    """The loss and the gradient of scikit-learn at the fixture's parameters."""
    mlp = MLPRegressor(
        hidden_layer_sizes=(3, 2),
        activation="relu",
        solver="lbfgs",
        alpha=ALPHA,
        max_iter=1,
    )
    layer_sizes = list(SIZES)
    mlp.n_layers_ = len(layer_sizes)
    mlp.out_activation_ = "identity"
    # the index of the weights and of the bias of every layer, the way the fit of
    # scikit-learn builds them before it calls the optimiser
    mlp._coef_indptr = []
    mlp._intercept_indptr = []
    start = 0
    for i in range(mlp.n_layers_ - 1):
        end = start + layer_sizes[i] * layer_sizes[i + 1]
        mlp._coef_indptr.append((start, end, (layer_sizes[i], layer_sizes[i + 1])))
        start = end
    for i in range(mlp.n_layers_ - 1):
        end = start + layer_sizes[i + 1]
        mlp._intercept_indptr.append((start, end))
        start = end
    mlp.coefs_ = [
        np.zeros((layer_sizes[i], layer_sizes[i + 1]))
        for i in range(mlp.n_layers_ - 1)
    ]
    mlp.intercepts_ = [
        np.zeros(layer_sizes[i + 1]) for i in range(mlp.n_layers_ - 1)
    ]
    n_samples = X.shape[0]
    activations = [X] + [
        np.zeros((n_samples, layer_sizes[i + 1])) for i in range(mlp.n_layers_ - 1)
    ]
    deltas = [
        np.zeros((n_samples, layer_sizes[i + 1])) for i in range(mlp.n_layers_ - 1)
    ]
    coef_grads = [
        np.zeros((layer_sizes[i], layer_sizes[i + 1]))
        for i in range(mlp.n_layers_ - 1)
    ]
    intercept_grads = [
        np.zeros(layer_sizes[i + 1]) for i in range(mlp.n_layers_ - 1)
    ]
    return mlp._loss_grad_lbfgs(
        PARAMETERS.copy(),
        X,
        Y.reshape(-1, 1),
        None,
        activations,
        deltas,
        coef_grads,
        intercept_grads,
    )


def main():
    loss, gradient = sklearn_loss_and_gradient()
    print("=" * 78)
    print("the loss and the gradient of scikit-learn at the fixture's parameters")
    print("=" * 78)
    print("loss = {!r}".format(loss))
    for value in gradient:
        print("g = {!r}".format(value))

    print()
    print("=" * 78)
    print("the difference between scikit-learn and the port")
    print("=" * 78)
    print("loss: sklearn {!r} port {!r}".format(loss, PORT_LOSS))
    print("loss difference = {!r}".format(abs(loss - PORT_LOSS)))
    difference = np.max(np.abs(np.asarray(gradient) - np.asarray(PORT_GRADIENT)))
    print("gradient difference = {!r}".format(difference))
    print("the loss of the fixture of the script = {!r}".format(SKLEARN_LOSS))
    if abs(loss - SKLEARN_LOSS) > TOLERANCE:
        print("THE SCRIPT AND SCIKIT-LEARN DISAGREE")
        return 1
    if abs(loss - PORT_LOSS) > TOLERANCE or difference > TOLERANCE:
        print("THE PORT AND SCIKIT-LEARN DISAGREE")
        return 1
    print("the port and scikit-learn agree to the tolerance")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
