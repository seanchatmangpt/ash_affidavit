#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
#
# Consumes ontology/affidavit-binding.ttl + ontology/affidavit-contract.ttl with the pinned
# qri-consumer-binding-pack (from consumer-pack.pin) and writes the generated files. Nothing generated is
# ever hand-edited. The pack is read from an export, never written to.
# Usage: scripts/consume.sh [--out DIR] [--pack-root DIR]
#   --out DIR        write the projected tree (default: install into lib/ and priv/ of this repo)
#   --pack-root DIR  directory holding packs/ (default: git archive of pack_commit from $MARKETPLACE_REPO,
#                    or $PACK_ROOT when set; the scratch export is acceptable while pack_commit is PENDING)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT=""; PACK_ROOT="${PACK_ROOT:-}"
while [ $# -gt 0 ]; do
  case "$1" in --out) OUT="$2"; shift 2;; --pack-root) PACK_ROOT="$2"; shift 2;; *) echo "unknown arg $1" >&2; exit 64;; esac
done

pin() { sed -n "s/^$1 *= *\"\(.*\)\"/\1/p" "$ROOT/consumer-pack.pin" | head -1; }
SCRATCH="$(mktemp -d)"; trap 'rm -rf "$SCRATCH"' EXIT

if [ -z "$PACK_ROOT" ]; then
  COMMIT="$(pin pack_commit)"
  REPO="${MARKETPLACE_REPO:-}"
  if [ "$COMMIT" = "PENDING_COORDINATOR" ] || [ -z "$REPO" ]; then
    echo "consume.sh: no pack source (pack_commit=$COMMIT); set PACK_ROOT or MARKETPLACE_REPO" >&2; exit 65
  fi
  mkdir -p "$SCRATCH/mkt"; git -C "$REPO" archive "$COMMIT" packs/qri-consumer-binding-pack packs/qri-qualification-profile-pack | tar -x -C "$SCRATCH/mkt"
  PACK_ROOT="$SCRATCH/mkt"
fi
PACK="$PACK_ROOT/packs/qri-consumer-binding-pack"

# One binding graph = binding + contract (Turtle permits concatenation; prefixes repeat harmlessly).
cp "$ROOT/ontology/affidavit-binding.ttl" "$SCRATCH/binding.ttl"
cat "$ROOT/ontology/affidavit-contract.ttl" >> "$SCRATCH/binding.ttl"

GEN="$SCRATCH/out"
python3.11 "$PACK/runners/consume.py" --binding "$SCRATCH/binding.ttl" --out "$GEN" >"$SCRATCH/consume.json"

DEST="${OUT:-$ROOT}"
mkdir -p "$DEST/lib/ash_affidavit" "$DEST/lib/mix/tasks" "$DEST/priv/affidavit"
G="$GEN/beam-host"
cp "$G/abi.ex"         "$DEST/lib/ash_affidavit/abi.ex"
cp "$G/wasm_config.ex" "$DEST/lib/ash_affidavit/wasm_config.ex"
cp "$G/engine_load.ex" "$DEST/lib/ash_affidavit/engine_load.ex"
cp "$G/host.ex"        "$DEST/lib/ash_affidavit/host.ex"
cp "$G/pool.ex"        "$DEST/lib/ash_affidavit/pool.ex"
cp "$G/vendor_task.ex" "$DEST/lib/mix/tasks/ash_affidavit.vendor.ex"
cp "$G/verify_task.ex" "$DEST/lib/mix/tasks/ash_affidavit.verify.ex"
cp "$GEN/MANIFEST.json" "$DEST/priv/affidavit/MANIFEST.json"
echo "consumed 8 files into $DEST"
