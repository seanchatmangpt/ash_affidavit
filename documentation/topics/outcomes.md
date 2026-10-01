<!--
SPDX-FileCopyrightText: 2026 ash_affidavit contributors

SPDX-License-Identifier: MIT
-->

# Outcomes

`AshAffidavit.call/2` returns `{:ok, map}`, `{:refused, refusal}`, `{:trap, refusal}` or
`{:unsupported, refusal}`.

| result | meaning |
|---|---|
| `{:ok, map}` | the engine answered `"ok" => true` |
| `{:refused, %AshAffidavit.Refusal{}}` | bad input, a refused engine identity, or a resource bound |
| `{:trap, %AshAffidavit.Refusal{}}` | the engine or host failed at run time |
| `{:unsupported, %AshAffidavit.Refusal{}}` | unknown op, or an engine code the library does not know |

Inside an Ash action, `AshAffidavit.Change.Receipt` adds an `AshAffidavit.Error.Refused` for every
non-ok outcome. The telemetry event `[:ash_affidavit, :op, :stop]` carries the outcome.
