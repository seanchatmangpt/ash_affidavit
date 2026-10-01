# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT

exclude =
  if System.get_env("ASH_AFFIDAVIT_PACK_ROOT") in [nil, ""] do
    IO.puts(
      :stderr,
      "ash_affidavit tests: excluding :pack_root (live consume.sh regeneration); " <>
        "ASH_AFFIDAVIT_PACK_ROOT is unset"
    )

    [:pack_root]
  else
    []
  end

ExUnit.start(exclude: exclude)
