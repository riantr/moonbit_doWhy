"""Runs every reference script of the directory and reports the result.

The reference scripts run the upstream of DoWhy on the very rows the MoonBit
port works on, and they print the numbers the port has to reproduce. They need
the checkout of the upstream, which is not part of this repository, so they are
local artefacts: this runner is the way to check that all of them still run.

Usage:
    python _verify/run_reference_scripts.py
    python _verify/run_reference_scripts.py --only gcm_
    python _verify/run_reference_scripts.py --list
"""

from __future__ import annotations

import argparse
import os
import pathlib
import subprocess
import sys
import time


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", default="", help="the scripts whose name holds this text")
    parser.add_argument("--list", action="store_true", help="the scripts that would run")
    arguments = parser.parse_args()

    directory = pathlib.Path(__file__).resolve().parent
    scripts = sorted(path for path in directory.glob("*_reference.py") if arguments.only in path.name)
    if arguments.list:
        for script in scripts:
            print(script.name)
        return 0

    failures: list[tuple[str, str]] = []
    started = time.time()
    # The scripts print the numbers of the upstream, and some of them print a
    # character that the locale of the machine cannot encode. The child is told
    # to write UTF-8 and the parent decodes UTF-8, so the pair does not depend
    # on the code page of the machine. Without this the reader thread of the
    # pipe dies with a UnicodeDecodeError and the failure of the script is
    # reported as a crash of the runner.
    environment = dict(os.environ, PYTHONIOENCODING="utf-8")
    for script in scripts:
        result = subprocess.run(
            [sys.executable, str(script)],
            capture_output=True,
            encoding="utf-8",
            errors="replace",
            env=environment,
        )
        if result.returncode == 0:
            print(f"{script.name}: ok")
            continue
        message = ""
        for line in reversed(result.stderr.strip().splitlines()):
            if line.strip():
                message = line.strip()
                break
        print(f"{script.name}: FAILED ({message})")
        failures.append((script.name, message))

    print(f"{len(scripts) - len(failures)} of {len(scripts)} reference scripts ran in {time.time() - started:.1f} s")
    for name, message in failures:
        print(f"  {name}: {message}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
