# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT

# Live courts need an external pack export; each is excluded with a stderr reason when its variable is unset.
# Each variable names the marketplace EXPORT ROOT (the directory that contains packs/), not a pack directory.
courts = [
  {:pack_root, "ASH_AFFIDAVIT_PACK_ROOT", "live consume.sh regeneration and the pack fingerprint court"},
  {:ext_pack, "ASH_AFFIDAVIT_EXT_PACK_ROOT", "live render_extension.sh regeneration"}
]

exclude =
  for {tag, var, what} <- courts, System.get_env(var) in [nil, ""] do
    IO.puts(:stderr, "ash_affidavit tests: excluding :#{tag} (#{what}); #{var} is unset")
    tag
  end

ExUnit.start(exclude: exclude)
