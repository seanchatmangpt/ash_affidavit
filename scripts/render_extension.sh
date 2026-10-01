#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT
#
# Renders the Spark/Igniter extension surface from ontology/affidavit-extension.ttl with the pinned
# ash-extension-pack (ext_pack_* keys of consumer-pack.pin). The pack is read from an export and never
# written to; ggen runs in a scratch directory; only the six projected files are copied out, then
# `mix format` normalizes them (the pack templates emit unformatted Elixir; formatting is deterministic).
# Fails closed: a pack export whose content digest differs from the pin writes nothing.
#
# Usage: scripts/render_extension.sh [--out DIR] [--pack-root DIR] [--check]
#   --out DIR        project into DIR instead of this repository
#   --pack-root DIR  directory holding packs/ash-extension-pack (default: $ASH_AFFIDAVIT_EXT_PACK_ROOT, else
#                    git archive of ext_pack_base_commit from $MARKETPLACE_REPO, default ~/ggen-marketplace)
#   --check          render twice into scratch and refuse unless the two runs are byte-identical and equal
#                    the files on disk in this repository
# Exit: 0 ok, 64 usage, 65 no pack source, 66 pack digest mismatch, 67 ggen failed, 68 check failed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT=""; CHECK=0; PACK_ROOT="${ASH_AFFIDAVIT_EXT_PACK_ROOT:-}"
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="$2"; shift 2;;
    --pack-root) PACK_ROOT="$2"; shift 2;;
    --check) CHECK=1; shift;;
    *) echo "unknown arg $1" >&2; exit 64;;
  esac
done

pin() { sed -n "s/^$1 *= *\"\(.*\)\"/\1/p" "$ROOT/consumer-pack.pin" | head -1; }
FILES="lib/ash_affidavit/resource.ex lib/ash_affidavit/persist.ex lib/ash_affidavit/verify.ex lib/ash_affidavit/info.ex lib/mix/tasks/ash_affidavit.install.ex test/ash_affidavit_composition_test.exs"

SCRATCH="$(mktemp -d)"; trap 'rm -rf "$SCRATCH"' EXIT

if [ -z "$PACK_ROOT" ]; then
  REPO="${MARKETPLACE_REPO:-$HOME/ggen-marketplace}"
  COMMIT="$(pin ext_pack_base_commit)"
  [ -d "$REPO/.git" ] || { echo "render_extension.sh: no pack source; set ASH_AFFIDAVIT_EXT_PACK_ROOT or MARKETPLACE_REPO" >&2; exit 65; }
  mkdir -p "$SCRATCH/export"
  git -C "$REPO" archive "$COMMIT" packs/ash-extension-pack | tar -x -C "$SCRATCH/export"
  PACK_ROOT="$SCRATCH/export"
fi
PACK="$PACK_ROOT/packs/ash-extension-pack"
[ -d "$PACK" ] || { echo "render_extension.sh: $PACK missing" >&2; exit 65; }

digest="$(cd "$PACK" && find . -type f ! -path './fixture/*' | LC_ALL=C sort | xargs shasum -a 256 | shasum -a 256 | cut -d' ' -f1)"
want="$(pin ext_pack_content_digest)"
if [ "$digest" != "$want" ]; then
  echo "REFUSED:EXT_PACK_DIGEST_MISMATCH pack=$digest pin=$want" >&2; exit 66
fi

# One render: scratch capsule with this repo's ggen.toml + ontology and a copy of the pack.
render() {
  local dest="$1" cap
  cap="$(mktemp -d "$SCRATCH/cap.XXXXXX")"
  mkdir -p "$cap/ontology" "$cap/vendor" "$cap/templates"
  cp "$ROOT/ggen.toml" "$cap/ggen.toml"
  cp "$ROOT/ontology/affidavit-extension.ttl" "$cap/ontology/"
  cp -R "$PACK" "$cap/vendor/ash-extension-pack"
  rm -rf "$cap/vendor/ash-extension-pack/fixture"
  (cd "$cap" && ggen sync run >"$cap/ggen.log" 2>&1) || { cat "$cap/ggen.log" >&2; exit 67; }
  mkdir -p "$dest"
  local f
  for f in $FILES; do
    [ -f "$cap/$f" ] || { echo "render_extension.sh: ggen did not project $f" >&2; exit 67; }
    mkdir -p "$dest/$(dirname "$f")"; cp "$cap/$f" "$dest/$f"
  done
  # mix format needs the project's plugins; format in place under the repository formatter config.
  # Two passes: the first pass over raw template output is not yet a fixed point (heredoc call arguments).
  local pass
  for pass in 1 2; do
    (cd "$ROOT" && mix format --dot-formatter "$ROOT/.formatter.exs" $(for f in $FILES; do printf '%s ' "$dest/$f"; done)) >/dev/null
  done
}

if [ "$CHECK" = 1 ]; then
  render "$SCRATCH/run1"; render "$SCRATCH/run2"
  diff -r "$SCRATCH/run1" "$SCRATCH/run2" >/dev/null || { echo "REFUSED:NONDETERMINISTIC two renders differ" >&2; exit 68; }
  for f in $FILES; do
    cmp -s "$SCRATCH/run1/$f" "$ROOT/$f" || { echo "REFUSED:DRIFT $f differs from the projection" >&2; exit 68; }
  done
  echo "render_extension: 2 renders byte-identical, 6 files equal the tree (pack $digest)"
  exit 0
fi

DEST="${OUT:-$ROOT}"
render "$SCRATCH/final"
for f in $FILES; do mkdir -p "$DEST/$(dirname "$f")"; cp "$SCRATCH/final/$f" "$DEST/$f"; done
echo "rendered 6 files into $DEST (pack $digest)"
