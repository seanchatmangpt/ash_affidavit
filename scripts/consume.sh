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
#   ASH_AFFIDAVIT_PIN overrides the pin file path (used by the stale-pin court).
# Exit: 0 ok, 64 usage, 65 no pack source, 66 pack export does not match pack_fingerprint
# (REFUSED:PACK_FINGERPRINT_STALE; nothing is written).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT=""; PACK_ROOT="${PACK_ROOT:-}"
while [ $# -gt 0 ]; do
  case "$1" in --out) OUT="$2"; shift 2;; --pack-root) PACK_ROOT="$2"; shift 2;; *) echo "unknown arg $1" >&2; exit 64;; esac
done

PIN_FILE="${ASH_AFFIDAVIT_PIN:-$ROOT/consumer-pack.pin}"
pin() { sed -n "s/^$1 *= *\"\(.*\)\"/\1/p" "$PIN_FILE" | head -1; }
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

# Fail closed on a stale pin: the pack export must hash to pack_fingerprint before anything is projected.
# Nothing is written on refusal (exit 66).
WANT_FP="$(pin pack_fingerprint)"
HAVE_FP="$(python3.11 "$ROOT/scripts/pack_fingerprint.py" "$PACK")"
if [ "$HAVE_FP" != "$WANT_FP" ]; then
  echo "REFUSED:PACK_FINGERPRINT_STALE pack=$HAVE_FP pin=$WANT_FP" >&2; exit 66
fi

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
