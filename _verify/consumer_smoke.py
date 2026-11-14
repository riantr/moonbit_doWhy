"""The quick start of the README, run against the published package.

The gate of the repository tests the source tree of the port, so it never
builds the package the way a user gets it: the package of the registry, with
the imports of the `moon.pkg` and the program of the `main.mbt`. This script
does exactly that.

It takes the quick start of the README -- the `moon.pkg` of the program and the
program itself -- builds a throwaway project around them, installs the
published package of the registry with `moon add`, and runs the program on the
four targets of the package. The program of the README has to build without a
warning and has to print the average treatment effect of the confounded data
set of the fixture.

The script needs the network and the `moon` of the toolchain, so it is not a
step of the gate of the repository. It runs after a release:

    python _verify/consumer_smoke.py
    python _verify/consumer_smoke.py --version 0.0.89
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent

# The package of the registry and the targets it runs on.
PACKAGE = "riantr/moonbit_dowhy"
TARGETS = ("native", "wasm", "wasm-gc", "js")

# The number of the lines the script prints of the output of a target.
PRINTED_LINES = 6


def version_of_the_repository() -> str:
    """The version of the package of the repository."""
    text = (ROOT / "moon.mod").read_text(encoding="utf-8", newline="")
    match = re.search(r'version\s*=\s*"([^"]+)"', text)
    assert match is not None, "the version of the package is not in moon.mod"
    return match.group(1)


def blocks_of_the_readme() -> tuple[str, str]:
    """The `moon.pkg` and the program of the quick start of the README.

    The README holds the two blocks of the quick start: the one with the
    imports of the package and the one with the program. The script takes them
    from the README itself, so that the quick start of the README is the one
    that is run.
    """
    text = (ROOT / "README.mbt.md").read_text(encoding="utf-8", newline="")
    blocks = re.findall(r"```moonbit\n(.*?)```", text, re.DOTALL)
    manifest = [b for b in blocks if "import {" in b]
    program = [b for b in blocks if "fn main" in b]
    assert len(manifest) == 1, f"the README holds {len(manifest)} manifests"
    assert len(program) == 1, f"the README holds {len(program)} programs"
    return manifest[0], program[0]


def build_the_project(directory: Path, manifest: str, program: str) -> None:
    """The throwaway project: the manifest of the package and the program."""
    subprocess.run(
        ["moon", "new", "app"],
        cwd=directory,
        check=True,
        capture_output=True,
        text=True,
    )
    package = directory / "app" / "cmd" / "main"
    package.mkdir(parents=True, exist_ok=True)
    (package / "moon.pkg").write_text(manifest, encoding="utf-8", newline="")
    (package / "main.mbt").write_text(program, encoding="utf-8", newline="")


def install_the_package(directory: Path, version: str) -> None:
    """The published package of the registry, installed into the project."""
    subprocess.run(
        ["moon", "add", f"{PACKAGE}@{version}"],
        cwd=directory / "app",
        check=True,
        capture_output=True,
        text=True,
    )


def run_the_program(directory: Path, target: str) -> str:
    """Run the program of the README on one target and return its output."""
    result = subprocess.run(
        ["moon", "run", "cmd/main", "--target", target],
        cwd=directory / "app",
        capture_output=True,
        text=True,
    )
    output = (result.stdout + result.stderr).strip()
    if result.returncode != 0:
        print(f"--- {target}: exit {result.returncode}")
        print(output)
        raise SystemExit(f"the quick start of the README fails on {target}")
    if "Warning" in output or "warning" in output:
        print(f"--- {target}")
        print(output)
        raise SystemExit(f"the quick start of the README warns on {target}")
    return output


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--version",
        default=None,
        help="the version of the published package to install",
    )
    args = parser.parse_args()

    if shutil.which("moon") is None:
        raise SystemExit("the `moon` of the toolchain is not on the PATH")

    version = args.version or version_of_the_repository()
    manifest, program = blocks_of_the_readme()
    print(f"=== the quick start of the README against {PACKAGE}@{version}")

    with tempfile.TemporaryDirectory(prefix="moonbit_dowhy_smoke_") as name:
        directory = Path(name)
        build_the_project(directory, manifest, program)
        install_the_package(directory, version)
        for target in TARGETS:
            output = run_the_program(directory, target)
            print(f"--- {target}")
            for line in output.splitlines()[-PRINTED_LINES:]:
                print("  " + line)

    print("the quick start of the README builds and runs on every target")


if __name__ == "__main__":
    main()
