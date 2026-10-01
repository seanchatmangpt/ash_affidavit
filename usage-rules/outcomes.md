<!--
SPDX-FileCopyrightText: 2026 ash_affidavit contributors

SPDX-License-Identifier: MIT
-->

# AshAffidavit outcomes

`AshAffidavit.call/2` returns one of four shapes. Keep them distinct.

| result | meaning | caller action |
|---|---|---|
| `{:ok, map}` | engine answered `"ok" => true` | use the response as an observation |
| `{:refused, refusal}` | bad input, engine identity refused, or a resource bound | change the input or the bytes |
| `{:trap, refusal}` | engine or host failed at run time | retry may help; the host recycles the instance |
| `{:unsupported, refusal}` | unknown op, or an engine error code this library does not know | do not retry |

- `refusal.code` is from a closed set (`AshAffidavit.Refusal.codes/0`). Match the code, not the message.
- In an Ash action, `AshAffidavit.Change.Receipt` turns any non-ok outcome into an
  `AshAffidavit.Error.Refused`. Recover the outcome with `AshAffidavit.Error.Refused.outcome/1` and
  the code with `AshAffidavit.Error.Refused.code/1`.
- The telemetry event `[:ash_affidavit, :op, :stop]` carries `outcome` as `:ok`, `:refused`, `:trap` or
  `:unsupported`.
