#!/usr/bin/env python3.11
# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
"""Prints the source fingerprint of a pack directory.

Same construction as ggen-marketplace scripts/marketplace.py fingerprint_paths (sha256 over, per file sorted by
posix relative path: 8-byte big-endian length and bytes of the path, 8-byte big-endian length and bytes of the
content), over every file of the pack directory except interpreter caches (`__pycache__`, `*.pyc`), which are
runtime residue and never part of a pack export. A pin carries `sha256:<hex>`.

Usage: pack_fingerprint.py PACK_DIR
"""
import hashlib
import sys
from pathlib import Path


def fingerprint(base: Path) -> str:
    paths = [
        p
        for p in base.rglob("*")
        if p.is_file() and "__pycache__" not in p.parts and p.suffix != ".pyc"
    ]
    digest = hashlib.sha256()
    for path in sorted(paths, key=lambda p: p.relative_to(base).as_posix()):
        rel = path.relative_to(base).as_posix().encode("utf-8")
        data = path.read_bytes()
        digest.update(len(rel).to_bytes(8, "big"))
        digest.update(rel)
        digest.update(len(data).to_bytes(8, "big"))
        digest.update(data)
    return digest.hexdigest()


if __name__ == "__main__":
    if len(sys.argv) != 2 or not Path(sys.argv[1]).is_dir():
        print("usage: pack_fingerprint.py PACK_DIR", file=sys.stderr)
        sys.exit(64)
    print("sha256:" + fingerprint(Path(sys.argv[1])))
