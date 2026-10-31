#!/usr/bin/env python3
"""Normalise and validate the registry credentials before `moon publish`.

The publish step writes the `MOONCAKES_RIANTR_TOKEN` secret straight to
`~/.moon/credentials.json`, which is what `moon publish` reads. The secret is
the JSON body of that file, so it has to BE json, and it has to arrive
without a byte order mark in front of it.

A byte order mark is the failure mode worth guarding against, because it is
invisible in every listing of the secret and it produces the opaque
"failed to parse registry credentials" from the registry client. A secret
that was piped through a tool that adds a BOM -- a PowerShell pipeline on
Windows does exactly that -- is a perfectly valid secret and an invalid
json file at the same time.

So this script:

1. strips a leading byte order mark if there is one,
2. parses the file and reports the parse error verbatim if it cannot,
3. checks that the object carries a non-empty "token" and a "username",
   because a bare token string is the other shape that fails, and
4. prints the keys it found, so the log records which shape was published.

The script exits non-zero on every failure, and the publish step runs before
`moon publish`, so the cause is named instead of guessed at.
"""

from __future__ import annotations

import json
import pathlib
import sys

BOM = b"\xef\xbb\xbf"


def main() -> int:
    path = pathlib.Path.home() / ".moon" / "credentials.json"
    if not path.exists():
        print("::error::the registry credentials file was not written")
        return 1

    raw = path.read_bytes()
    if raw.startswith(BOM):
        raw = raw[len(BOM) :]
        path.write_bytes(raw)

    try:
        credentials = json.loads(raw)
    except Exception as error:
        print(f"::error::the registry credentials are not valid JSON: {error}")
        return 1

    if not isinstance(credentials, dict):
        print(
            "::error::the registry credentials are not a JSON object but a "
            f"{type(credentials).__name__}; the secret has to be the whole "
            "body of ~/.moon/credentials.json, not a bare token"
        )
        return 1

    for key in ("token", "username"):
        if not credentials.get(key):
            print(f"::error::the registry credentials have no {key!r}")
            return 1

    print("registry credentials ok:", sorted(credentials))
    return 0


if __name__ == "__main__":
    sys.exit(main())
