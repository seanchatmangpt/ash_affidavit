# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT

import Config

# UNSUPPORTED(generator-capability): hand-written config.
# Ash requires an explicit string length counting mode for the fixture resources under test/support.
config :ash, default_string_length_count: :codepoints

# git_ops generates CHANGELOG.md entries from conventional commits. manage_mix_version? is false:
# the version is CalVer (YY.M.D) and is bumped by hand, never derived from commit types.
config :git_ops,
  mix_project: Mix.Project.get!(),
  changelog_file: "CHANGELOG.md",
  repository_url: "https://github.com/seanchatmangpt/ash_affidavit",
  manage_mix_version?: false,
  manage_readme_version: false,
  version_tag_prefix: "v"
