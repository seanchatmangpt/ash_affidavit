# Generated API reference (doc-hdit)

GENERATED — do not edit by hand. The tables in `reference.md` are rendered
from the Elixir code surface; the only agent-writable region in any file
here is the fenced `AGENT-COMMENTARY` slot.

## Regenerate

```sh
python3 /Users/sac/ggen-marketplace/scripts/gen_doc_surface.py code /Users/sac/ash_affidavit \
  > /tmp/hdit/ash_affidavit.code.v3.json
/Users/sac/ggen-marketplace/packs/rust-doc-hdit-pack/target/release/doc-hdit scaffold \
  --code /tmp/hdit/ash_affidavit.code.v3.json \
  --templates /Users/sac/ggen-marketplace/packs/rust-doc-hdit-pack/templates \
  --out docs/diataxis/reference/generated
```

## Audit

```sh
# Merge grounded claims (one per surface item) into the surface JSON, then:
doc-hdit audit /tmp/hdit/ash_affidavit.inputs.after.json
```

Last audit (v3 surface, 37 modules, 344 items):

| gate        | value  | threshold |
| ----------- | ------ | --------- |
| S_coverage  | 1.0000 | >= 0.9000 |
| Phi_halluc  | 0.0000 | <= 0.0010 |
| Q_density   | 1.0000 | >= 0.6500 |
