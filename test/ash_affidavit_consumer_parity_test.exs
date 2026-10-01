# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT

defmodule AshAffidavit.ConsumerParityTest do
  # Regeneration equality: the generated files in the tree are exactly what the pinned consumer pack
  # projects from ontology/affidavit-{binding,contract}.ttl. The pin-digest tests always run; the live
  # regeneration test runs real python3.11 + ggen and needs ASH_AFFIDAVIT_PACK_ROOT (a directory holding
  # packs/qri-consumer-binding-pack and packs/qri-qualification-profile-pack).
  use ExUnit.Case, async: false

  @root Path.expand("..", __DIR__)
  @generated ~w(
    lib/ash_affidavit/abi.ex lib/ash_affidavit/wasm_config.ex lib/ash_affidavit/engine_load.ex
    lib/ash_affidavit/host.ex lib/ash_affidavit/pool.ex lib/mix/tasks/ash_affidavit.vendor.ex
    lib/mix/tasks/ash_affidavit.verify.ex priv/affidavit/MANIFEST.json
  )

  defp sha256(path), do: :crypto.hash(:sha256, File.read!(Path.join(@root, path))) |> Base.encode16(case: :lower)

  defp pin do
    lines = @root |> Path.join("consumer-pack.pin") |> File.read!() |> String.split("\n")

    for line <- lines, [_, k, v] <- [Regex.run(~r/^"?([\w.\/-]+)"? = "?([^"]*)"?$/, line)], into: %{}, do: {k, v}
  end

  test "generated files equal the digests recorded in consumer-pack.pin" do
    pin = pin()
    for f <- @generated, do: assert(sha256(f) == pin[f], "#{f} drifted from consumer-pack.pin")
  end

  test "the pin binds the engine artifact and the NONE authority ceiling" do
    pin = pin()
    manifest = Path.join(@root, "priv/affidavit/MANIFEST.json") |> File.read!() |> Jason.decode!()
    assert pin["artifact_sha256"] == manifest["artifact"]["sha256"]
    assert pin["artifact_bytes"] == Integer.to_string(manifest["artifact"]["bytes"])
    assert pin["authority_ceiling"] == "NONE"
    assert pin["pack_base_commit"] =~ ~r/^[0-9a-f]{40}$/
  end

  test "no absolute home path in the ontology sources" do
    for f <- ~w(ontology/affidavit-contract.ttl ontology/affidavit-binding.ttl) do
      refute File.read!(Path.join(@root, f)) =~ "/Users/"
    end
  end

  # Live regeneration needs python3.11 + ggen and ASH_AFFIDAVIT_PACK_ROOT; test_helper.exs excludes
  # the :pack_root tag (with a stderr reason) when that variable is unset.
  @tag :pack_root
  @tag timeout: 300_000
  test "consume.sh regenerates the committed files byte-for-byte" do
    pack_root = System.fetch_env!("ASH_AFFIDAVIT_PACK_ROOT")
    out = Path.join(System.tmp_dir!(), "ash_affidavit_consume_#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf(out) end)

    {log, status} =
      System.cmd("bash", [Path.join(@root, "scripts/consume.sh"), "--out", out, "--pack-root", pack_root],
        stderr_to_stdout: true
      )

    assert status == 0, log

    for f <- @generated do
      assert File.read!(Path.join(out, f)) == File.read!(Path.join(@root, f)), "#{f} differs from regeneration"
    end
  end
end
