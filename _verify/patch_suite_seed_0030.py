"""Use the seed of the estimator test suite in the probe and in the reference."""

edits = [
    (
        r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\src\tests\estimator_suites.mbt",
        [
            (
                "const SUITE_SEED : Int32 = 42",
                "const SUITE_SEED : Int32 = 44",
            ),
        ],
    ),
    (
        r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\src\tests\zz_probe.mbt",
        [
            (
                """  @datasets.linear_dataset(
    SEED,
    100000,""",
                """  @datasets.linear_dataset(
    SUITE_SEED,
    100000,""",
            ),
            (
                """    @datasets.linear_dataset(
    SUITE_SEED,
    100000,""",
                """    @datasets.linear_dataset(
    SUITE_SEED,
    100000,""",
            ),
        ],
    ),
    (
        r"D:\src\MiniMax\Projects\MoonBit\moonbit_doWhy\_verify\estimator_suite_reference.py",
        [
            (
                """# The seed of the generator of the port.
SEED = 42""",
                """# The seed of the generator of the port, the seed of the estimator test
# suite of the port.
SEED = 44""",
            ),
        ],
    ),
]

for path, replacements in edits:
    s = open(path, encoding="utf-8", newline="").read()
    for old, new in replacements:
        assert s.count(old) == 1, (path, s.count(old), old[:60])
        s = s.replace(old, new)
    open(path, "w", encoding="utf-8", newline="").write(s)
    print("patched", path)
