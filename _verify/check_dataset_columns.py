import sys, types
import numpy as np
ROOT = r"D:\src\MiniMax\git\dowhy\dowhy-0.14"
sys.path.insert(0, ROOT)
pkg = types.ModuleType("dowhy")
pkg.__path__ = [ROOT + r"\dowhy"]
sys.modules["dowhy"] = pkg
import dowhy.datasets as ds

# numpy 2.x cannot np.vectorize a function that returns a length-1 array.
def convert_to_binary(x, stochastic=True):
    p = 1.0 / (1.0 + np.exp(-x))
    if stochastic:
        return np.random.choice([0, 1], p=[1 - p, p])
    return int(p > 0.5)
ds.convert_to_binary = convert_to_binary

res = ds.linear_dataset(beta=1.0, num_common_causes=3, num_samples=200,
                         num_instruments=2, num_discrete_common_causes=2)
df = res["df"]
print("COLUMNS:", list(df.columns))
print("N_COLS:", len(df.columns))
print("DTYPES:", {k: str(v) for k, v in df.dtypes.items()})
print("W1 head:", list(df["W1"].head(8)))
print("common_causes:", res["common_causes_names"])
print("instruments:", res["instrument_names"])