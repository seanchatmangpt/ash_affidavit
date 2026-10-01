#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
#
# Renders the beam-host file set from ontology/affidavit-contract.ttl with the qri pack, in a
# scratch copy (the pack is never written to), then copies the seven files into lib/.
# Usage: scripts/render_host.sh [PACK_DIR] [SCRATCH_DIR]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACK="${1:-$HOME/ggen-marketplace/packs/qri-qualification-profile-pack}"
SCRATCH="${2:-$(mktemp -d)/qri-for-affidavit}"

mkdir -p "$SCRATCH"
cp -R "$PACK/." "$SCRATCH/"
cp "$SCRATCH/ggen-beam-host.toml" "$SCRATCH/ggen.toml"
cp "$ROOT/ontology/affidavit-contract.ttl" "$SCRATCH/ontology/examples/ash-graphlaw-contract.ttl"
(cd "$SCRATCH" && ggen sync run >/dev/null)

G="$SCRATCH/generated/beam-host"
mkdir -p "$ROOT/lib/ash_affidavit" "$ROOT/lib/mix/tasks"
cp "$G/abi.ex"         "$ROOT/lib/ash_affidavit/abi.ex"
cp "$G/wasm_config.ex" "$ROOT/lib/ash_affidavit/wasm_config.ex"
cp "$G/engine_load.ex" "$ROOT/lib/ash_affidavit/engine_load.ex"
cp "$G/host.ex"        "$ROOT/lib/ash_affidavit/host.ex"
cp "$G/pool.ex"        "$ROOT/lib/ash_affidavit/pool.ex"
cp "$G/vendor_task.ex" "$ROOT/lib/mix/tasks/ash_affidavit.vendor.ex"
cp "$G/verify_task.ex" "$ROOT/lib/mix/tasks/ash_affidavit.verify.ex"
echo "rendered 7 files from $(shasum -a 256 "$ROOT/ontology/affidavit-contract.ttl" | cut -c1-16)"
