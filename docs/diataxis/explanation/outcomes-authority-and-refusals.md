# Explanation: Outcomes, Authority and Refusals

Why `AshAffidavit.call/2` returns four outcomes instead of `{:ok, map} | {:error, term}`,
and why the package keeps repeating that a response grants no authority.

## The four outcomes

`lib/ash_affidavit.ex` (`classify/1`) maps everything the host can report into exactly
four shapes:

| result | meaning | retry? |
|---|---|---|
| `{:ok, response}` | engine answered `"ok" => true` (and no authority above NONE) | — |
| `{:refused, %AshAffidavit.Refusal{}}` | bad input, or a host refusal (digest pin, import surface, size bound, saturation) | only with a different input |
| `{:trap, %AshAffidavit.Refusal{}}` | engine or host failed at run time; the host recycles the instance | the host retries with backoff |
| `{:unsupported, %AshAffidavit.Refusal{}}` | unknown op, or an engine error code this library does not know | no — the engine cannot do it |

The mapping is `AshAffidavit.Refusal.outcome/1`: the six refusal classes
`:refused_input`, `:refused_identity`, `:refused_authority`,
`:blocked_resource` all collapse to `:refused`; `:trap` and `:unsupported`
stay themselves. A response with `"ok" => false` is *not* an error — the engine
answered lawfully about your input — so it lands in `:refused`, not `:trap`.

Why four and not two: a caller that could not distinguish refusal from trap
would either retry an input that can never succeed, or treat a recycled
instance as its own bug. The distinction is load-bearing for the Ash
integrations too: `AshAffidavit.Change.Receipt` fails the action on all three
negative outcomes but keeps the typed refusal recoverable through
`AshAffidavit.Error.Refused.code/1` and `outcome/1`.

## Authority is NONE, always

The package grants no execution authority. `{:ok, response}` is the engine's
computation over exactly the request you sent — not an authorization, not a DO
receipt, not a standing. This is not a disclaimer bolted onto the docs; it is
enforced in code at `lib/ash_affidavit.ex:132-143`: any `{:ok, _}` whose
`authority` (read at the top level and inside `evidence` only, because every
other field echoes caller input and is data) states something above `NONE`
becomes `{:refused, %AshAffidavit.Refusal{code: :authority_escalation}}`. No
change, validation, calculation or notifier can therefore carry such a response
into a resource.

The DSL-level `ceiling` on `operation` (`:observe | :select | :construct`) is
declarative bookkeeping. `AshAffidavit.Resource.Validate` checks it at compile
time, and the docs of every generated module repeat it: declaring a ceiling
grants no authority. Routing is not authority either: `AshAffidavit.Pool`
picks the member with the shortest mailbox, nothing more.

## Refusals are typed and closed

`AshAffidavit.Refusal` (`lib/ash_affidavit/refusal.ex`) has a closed code set:
host codes (a fixed map in the module) plus engine codes read at compile time
from `priv/affidavit/capability-registry.json` `error_codes`. The module
raises at compile time if a registry code is not classified — the taxonomy
cannot silently drift from the engine. Atoms are created from the registry
list at compile time, never from engine output; a code the library does not
know becomes `:engine_unclassified` (class `:unsupported`) with the original
object kept in `raw`.

A refusal is an observation about one exact input. It grants and withdraws no
authority — the same ceiling applies in both directions.

## Admission is identity, not trust

Before any instance exists, the engine bytes are judged
(`lib/ash_affidavit/engine_load.ex`): SHA-256 against the
`priv/affidavit/MANIFEST.json` pin, compile, import surface (exactly
`environ_get`, `environ_sizes_get`, `fd_write`, `proc_exit` from
`wasi_snapshot_preview1`), required exports (`af_alloc`, `af_call`,
`af_free`, `af_abi_version`, `memory`). This is an identity check: it proves
you are talking to the pinned engine, not that the engine's answers are
authorizations. A missing or unloadable engine never crashes the host start;
it becomes a typed refusal (`:blocked_resource` class) on every call.

## Provenance of the code itself

Most of `lib/` is generated from RDF ontologies, each projection pinned:
the host files (`abi`, `wasm_config`, `engine_load`, `host`, `pool`, and the
`vendor`/`verify` Mix tasks) come from `ontology/affidavit-binding.ttl` and
`ontology/affidavit-contract.ttl`; the extension files (`resource`,
`persist`, `verify`, `info`, `install`) come from
`ontology/affidavit-extension.ttl`. The hand-written residue — the public API
in `AshAffidavit`, the refusal taxonomy, and the Ash integrations — is listed
with reasons in `HANDWRITTEN.md`. Change the ontology, not the generated files.

## See Also

`docs/diataxis/reference/public-api.md` ·
`docs/diataxis/tutorials/run-your-first-receipt.md` ·
`docs/diataxis/how-to/use-the-ash-extension.md`
