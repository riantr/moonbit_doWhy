"""Bump the version of the module manifest to 0.0.29.

The manifest is read by the registry, and the README badge has to name the same
version, so the two are bumped together.  The file is written back without a
byte order mark, because a manifest that starts with one is refused.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "moon.mod"

OLD = 'version = "0.0.28"'
NEW = 'version = "0.0.29"'


def main() -> None:
    raw = TARGET.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"):
        raise SystemExit("the manifest starts with a byte order mark")
    text = raw.decode("utf-8")
    if text.count(OLD) != 1:
        raise SystemExit(f"expected one occurrence of {OLD!r}")
    TARGET.write_bytes(text.replace(OLD, NEW).encode("utf-8"))
    print("bumped the manifest to", NEW)


if __name__ == "__main__":
    main()
