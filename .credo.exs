# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT

# Generated projections are not linted: their text is owned by the pack template, and a style finding is repaired
# in the ontology or the template, never in the projection (see HANDWRITTEN.md). Defaults apply to everything else.
%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/", "mix.exs"],
        excluded: [
          ~r"/_build/",
          ~r"/_build-[^/]*/",
          ~r"/deps/",
          # ash-extension-pack projections (scripts/render_extension.sh)
          "lib/ash_affidavit/resource.ex",
          "lib/ash_affidavit/persist.ex",
          "lib/ash_affidavit/verify.ex",
          "lib/ash_affidavit/info.ex",
          "lib/mix/tasks/ash_affidavit.install.ex",
          "test/ash_affidavit_composition_test.exs"
        ]
      },
      strict: true
    }
  ]
}
