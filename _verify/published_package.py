"""The published package of the registry against the source tree of the repository.

The zip of the registry holds the package a user gets. This script compares it
with the `src/` of the repository, so that the claim "the published package is
the port" is checked against the files of the registry and not against the
state of the repository alone.

The interface files of the packages -- the files `pkg.generated.mbti` -- are
written by the compiler while it builds, and they are not a part of the
source, so they are left out of the comparison.

The script needs the archive of the version in the cache of the registry,
which `moon add` writes:

    python _verify/published_package.py --version 0.0.89
"""

from __future__ import annotations

import argparse
import hashlib
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
CACHE = Path.home() / ".moon" / "registry" / "cache" / "riantr" / "moonbit_dowhy"

# The files the compiler writes while it builds, and that the registry does
# not hold.
GENERATED = "pkg.generated.mbti"


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def published_files(archive: Path) -> dict[str, bytes]:
    """The files of the source tree, as the archive of the registry holds them."""
    with zipfile.ZipFile(archive) as zip_file:
        return {
            name: zip_file.read(name)
            for name in zip_file.namelist()
            if not name.endswith("/")
            and name.startswith("src/")
            and not name.endswith(GENERATED)
        }


def local_files() -> dict[str, bytes]:
    """The files of the source tree of the repository."""
    files = {}
    for path in sorted((ROOT / "src").rglob("*")):
        if path.is_file() and not path.name == GENERATED:
            files[path.relative_to(ROOT).as_posix()] = path.read_bytes()
    return files


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", default="0.0.89")
    args = parser.parse_args()

    archive = CACHE / f"{args.version}.zip"
    if not archive.exists():
        raise SystemExit(
            f"the archive of the registry is missing: {archive}\n"
            "install the package once with `moon add riantr/moonbit_dowhy@"
            f"{args.version}` to write it into the cache"
        )

    published = published_files(archive)
    local = local_files()
    print(f"the archive holds {len(published)} file(s) of the source tree")
    print(f"the repository holds {len(local)} file(s) of the source tree")

    only_published = sorted(set(published) - set(local))
    only_local = sorted(set(local) - set(published))
    different = sorted(
        key
        for key in set(published) & set(local)
        if digest(published[key]) != digest(local[key])
    )

    for key in only_published:
        print(f"  only in the archive: {key}")
    for key in only_local:
        print(f"  only in the repository: {key}")
    for key in different:
        print(f"  different: {key}")

    if only_published or only_local or different:
        raise SystemExit(
            "the published package is not the source tree of the repository"
        )
    print(f"the published package {args.version} is the source tree of the repository")


if __name__ == "__main__":
    main()
