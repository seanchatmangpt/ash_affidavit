# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT

defmodule AshAffidavit.ExtensionRenderTest do
  # Regeneration court for the Spark/Igniter surface: the real ggen runs the pinned ash-extension-pack over
  # ontology/affidavit-extension.ttl and the result equals the files in the tree. Needs
  # ASH_AFFIDAVIT_EXT_PACK_ROOT (a directory holding packs/ash-extension-pack) and ggen on PATH.
  use ExUnit.Case, async: false

  @root Path.expand("..", __DIR__)
  @script Path.join(@root, "scripts/render_extension.sh")
  @tag :ext_pack
  @tag timeout: 600_000
  test "render_extension.sh --check: two renders are byte-identical and equal the tree" do
    {log, status} =
      System.cmd("bash", [@script, "--check", "--pack-root", System.fetch_env!("ASH_AFFIDAVIT_EXT_PACK_ROOT")],
        stderr_to_stdout: true,
        env: [{"MIX_BUILD_ROOT", System.get_env("MIX_BUILD_ROOT") || "_build"}]
      )

    assert status == 0, log
    assert log =~ "byte-identical"
  end

  @tag :ext_pack
  test "a pack export whose content differs from the pin is refused and nothing is written" do
    src = Path.join(System.fetch_env!("ASH_AFFIDAVIT_EXT_PACK_ROOT"), "packs/ash-extension-pack")
    dir = Path.join(System.tmp_dir!(), "ash_affidavit_extpack_#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf(dir) end)
    File.mkdir_p!(Path.join(dir, "packs"))
    File.cp_r!(src, Path.join(dir, "packs/ash-extension-pack"))
    File.write!(Path.join(dir, "packs/ash-extension-pack/ontology.ttl"), "# tampered\n", [:append])
    out = Path.join(dir, "out")

    {log, status} = System.cmd("bash", [@script, "--out", out, "--pack-root", dir], stderr_to_stdout: true)

    assert status == 66, log
    assert log =~ "REFUSED:EXT_PACK_DIGEST_MISMATCH"
    refute File.exists?(out)
  end

  # Docs-truth: every lib file is either projected from RDF (qri pack or ash-extension-pack) or hand-written and
  # then carries the UNSUPPORTED(generator-capability) header and a row in HANDWRITTEN.md. Never both, never neither.
  test "each lib file has exactly one authority: a projection or a ledgered residue" do
    ledger = File.read!(Path.join(@root, "HANDWRITTEN.md"))
    pin = File.read!(Path.join(@root, "consumer-pack.pin"))
    qri = for [_, f] <- Regex.scan(~r/^"((?:lib|priv)\/[^"]+)" = "/m, pin), do: f

    extension =
      ~w(lib/ash_affidavit/resource.ex lib/ash_affidavit/persist.ex lib/ash_affidavit/verify.ex lib/ash_affidavit/info.ex lib/mix/tasks/ash_affidavit.install.ex)

    assert qri != []
    assert Enum.sort(qri ++ extension) == Enum.sort(Enum.uniq(qri ++ extension))

    for f <- Path.wildcard(Path.join(@root, "lib/**/*.ex")) |> Enum.map(&Path.relative_to(&1, @root)) do
      header? = File.read!(Path.join(@root, f)) =~ "UNSUPPORTED(generator-capability)"

      if f in qri or f in extension do
        refute header?, "#{f} is projected but carries a hand-written header"
        assert ledger =~ f or ledger =~ Path.basename(f), "#{f} is projected but not named in HANDWRITTEN.md"
      else
        assert header?, "#{f} is hand-written but lacks the UNSUPPORTED(generator-capability) header"
        assert ledger =~ f, "#{f} is hand-written but has no HANDWRITTEN.md row"
      end
    end
  end
end
