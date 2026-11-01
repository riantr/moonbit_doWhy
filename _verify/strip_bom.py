"""Strips the byte order mark of a file.

The PowerShell 5.1 `Set-Content -Encoding utf8` writes a byte order mark, which
the MoonBit toolchain does not accept in `moon.mod` and which is not wanted in
the reference scripts either.

Usage:
    python _verify/strip_bom.py <path> [<path> ...]
"""

from __future__ import annotations

import pathlib
import sys


def strip(path: pathlib.Path) -> None:
    data = path.read_bytes()
    if data.startswith(b"\xef\xbb\xbf"):
        path.write_bytes(data[3:])
        print(f"stripped {path}")
    else:
        print(f"clean {path}")


def main() -> None:
    for name in sys.argv[1:]:
        strip(pathlib.Path(name))


if __name__ == "__main__":
    main()
