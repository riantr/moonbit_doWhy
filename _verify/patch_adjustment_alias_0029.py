"""Copy the adjustment set of an estimand where it is stored or extended.

`IdentifiedEstimand::get_adjustment_set` hands out the array that the estimand
keeps, so every caller that stores it or pushes onto it shares the state of the
estimand.  The bootstrap refuter pushes the instruments onto that array, which
grew the adjustment set of the estimator that was fitted before the refutation
ran, and the design matrix of the estimate then held more columns than the
fitted coefficients.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

EDITS = [
    (
        ROOT / "src" / "estimators" / "fit.mbt",
        """  self.adjustment_names = self.target_estimand.get_adjustment_set(
    self.target_estimand.identifier_method(),
  )
""",
        """  self.adjustment_names = self
    .target_estimand
    .get_adjustment_set(self.target_estimand.identifier_method())
    .copy()
""",
    ),
    (
        ROOT / "src" / "refuters" / "refuters.mbt",
        """  let out = estimand.get_adjustment_set(estimand.identifier_method())
""",
        """  // The array of the adjustment set belongs to the estimand, so it is copied
  // before the instruments are pushed onto it.
  let out = estimand.get_adjustment_set(estimand.identifier_method()).copy()
""",
    ),
    (
        ROOT / "src" / "do_samplers" / "do_sampler.mbt",
        """    adjustment_names: adjustment,
""",
        """    adjustment_names: adjustment.copy(),
""",
    ),
]


def main() -> None:
    for path, old, new in EDITS:
        text = path.read_text(encoding="utf-8")
        count = text.count(old)
        if count != 1:
            raise SystemExit(f"expected one occurrence in {path}, found {count}")
        path.write_text(text.replace(old, new), encoding="utf-8", newline="")
        print("patched", path)


if __name__ == "__main__":
    main()
