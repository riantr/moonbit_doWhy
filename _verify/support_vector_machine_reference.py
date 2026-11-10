"""Print the predictions scikit-learn computes for the support vector regressor
of the dummy outcome refuter, and compare them with the ones of the port.

The port of the support vector regressor of the dummy outcome refuter fits the
`SVR` of scikit-learn with the radial basis kernel, the penalty `C` and the
width of the tube of the epsilon insensitive loss. This script fits the model
of scikit-learn on the fixture of the port and prints its predictions next to
the ones of the port.

The two do not agree exactly: the dual of the epsilon insensitive loss is not
strictly convex, so two solvers of the same tolerance reach a nearby but not
identical point of the tube. The tolerance of the solver of scikit-learn is
one thousandth, and the two solvers land within about `7e-8` of each other on
the fixture below, which is the order of the last bits of the double.

Run: python _verify/support_vector_machine_reference.py
"""

import numpy as np
from sklearn.svm import SVR

# The fixture of the port: forty rows, two features and the outcome.
N = 40
X = np.array(
    [
        [(i % 7) * 0.5 - 1.5, (i % 5) * 0.4 - 0.8]
        for i in range(N)
    ]
)
Y = np.array([2.0 * x0 - 1.5 * x1 + 0.1 * (i % 3) for i, (x0, x1) in enumerate(X)])

C = 1.0
EPSILON = 0.2

# The predictions and the bias the port produces for the fixture above.
PORT_PREDICTION = [
    -1.600029102394071,
    -1.5002650675325486,
    -0.95918287040111,
    -0.5680699216987348,
    -0.0001750954438943103,
    2.907081635516401,
    3.13519850453455,
    -2.7002650675325484,
    -2.600343279048355,
    -1.9409657149335002,
    1.1001476175191016,
    1.8192287936044018,
    2.24030652567968,
    2.269981652792149,
    -2.8841111426268693,
    -0.982064821419371,
    -0.3409561698985553,
    0.12043132841637667,
    0.47609583847076925,
    1.0416271051934376,
    3.0442259063098613,
    -2.1852490062328203,
    -2.0966551058786966,
    -1.599693764133888,
    -0.999886896851035,
    2.099919495570758,
    2.787726028134127,
    2.799988068295918,
    -2.9971766380073923,
    -2.726763287497542,
    0.05323868129784876,
    0.7653661548521691,
    1.1676393852131108,
    1.5890245033065082,
    1.700603091550565,
    -1.600029102394071,
    -1.5002650675325486,
    -0.95918287040111,
    -0.5680699216987348,
    -0.0001750954438943103,
]
PORT_BIAS = 0.05294371785606371


def main() -> int:
    model = SVR(C=C, epsilon=EPSILON, kernel="rbf", gamma="scale")
    model.fit(X, Y)
    prediction = model.predict(X)

    print("=" * 78)
    print("the predictions of scikit-learn on the fixture of the port")
    print("=" * 78)
    for value in prediction:
        print("p = {!r}".format(value))
    print("bias = {!r}".format(model.intercept_[0]))
    print("the gamma of scikit-learn = {!r}".format(model._gamma))
    variance = X.var()
    print(
        "the gamma of the scale = {!r}".format(1.0 / (X.shape[1] * variance))
    )
    print("the support vectors of scikit-learn = {}".format(len(model.support_)))

    print()
    print("=" * 78)
    print("the difference between scikit-learn and the port")
    print("=" * 78)
    port = np.asarray(PORT_PREDICTION)
    print("the bias: scikit-learn {!r} port {!r}".format(model.intercept_[0], PORT_BIAS))
    print("the bias difference = {!r}".format(abs(model.intercept_[0] - PORT_BIAS)))
    print("the largest difference of the predictions = {!r}".format(np.max(np.abs(prediction - port))))
    print("the rmse of scikit-learn = {!r}".format(np.sqrt(np.mean((prediction - Y) ** 2))))
    print("the rmse of the port = {!r}".format(np.sqrt(np.mean((port - Y) ** 2))))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
