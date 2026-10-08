<!-- Cannon Fodder In-Game Level Editor V1.0
Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
Licensed under the MIT License. See the LICENSE file for details. -->

# MAP/SPT Payload Validator

`payload.s` exports the position-independent 68000 subroutine
`cf_payload_validate`. It checks one selected phase's raw MAP/SPT pair against
the lengths, CRCs and policy in a previously validated `CFMD` record. It performs
no disk I/O, decompression, game calls, module loading or user-interface work.

## Calling Convention

| Register | Input |
|---|---|
| A0 | Even address of raw MAP bytes |
| D0.l | Exact MAP length, 1 through 15,096 bytes |
| A1 | Even address of raw SPT bytes |
| D1.l | Exact SPT length, 1 through 430 bytes |
| A2 | Even address of the selected, schema-validated 256-byte `CFMD` record |
| A3 | Even address of a writable 32-byte result span |
| A4 | Even address of a writable 128-byte scratch span |

All five spans must be addressable, nonzero and mutually disjoint. Alignment,
32-bit address wrap, length bounds and all ten pairwise overlaps are checked
before scratch changes. The caller must keep the spans outside executing code,
the active stack and other live owners. Byte reads on the 68000 use aligned bus
words, so odd-length inputs need an addressable padding byte; that byte is not
part of the CRC or parsed content.

D0.w returns structural status. D1 and CCR are unspecified; D2-D7 and A0-A6
are preserved and A7 is balanced. Raw MAP/SPT bytes and metadata never change.

| Status | Meaning |
|---|---|
| 0 | Structurally valid pair; inspect result error and review masks |
| -1 | Invalid pointer-span, alignment or input-length argument |
| -2 | Invalid CFMD magic, ABI, size, phase bounds, objective mask or flag bits |
| -3 | Exact input length differs from the selected CFMD reference |
| -4 | MAP or SPT CRC-32/ISO-HDLC mismatch |
| -5 | Invalid MAP header, dimensions, cell count or exact payload length |
| -6 | Unsupported terrain resource pair |
| -7 | SPT length is not a multiple of ten, or a type exceeds `$6E` |

An overlay that never reads the result defines `PAYLOAD_STRUCTURAL_ONLY`
before including `payload.s`. That variant leaves out the gameplay checks and
their tables: the statuses above are unchanged, but status 0 publishes no
result. The Storage, Open and Test overlays read the result and use the full
validator. The validation overlay defines `PAYLOAD_DIAGNOSTICS`: each finding
is then also passed to its `vald_emit` list with its location class.

Every negative return preserves all 32 output bytes. Scratch may change after
argument validation. Error categories are not a priority guarantee for inputs
with multiple defects. The CFMD checks defend the fields used here; they do not
replace complete CFMI schema validation, filename resolution or directory identity
checks. A positive SPT length remains mandatory, including editable drafts.

## Result Layout

`payload.i` defines offsets, statuses and bit numbers. Multi-byte values are
big-endian. The result is pointer-free and may be copied before module eviction.

| Offset | Bytes | Contents |
|---|---:|---|
| `$00` | 4 | Magic `CFVR` |
| `$04` | 2 | Result ABI, 1 |
| `$06` | 2 | Result size, 32 |
| `$08` | 4 | Gameplay error mask |
| `$0C` | 4 | Review mask |
| `$10` | 2 | MAP width in cells |
| `$12` | 2 | MAP height in cells |
| `$14` | 2 | Serialized SPT record count, 1 through 43 |
| `$16` | 2 | Active type-0 placements in the first 30 slots |
| `$18` | 2 | Nonzero MAP marker-cell count |
| `$1A` | 1 | Resource-pair index, 0 through 5 |
| `$1B` | 1 | Selected zero-based phase index copied from CFMD |
| `$1C` | 4 | Reserved, zero |

Resource indices are `(junbase,junsub0)`, `(junbase,junsub1)`,
`(icebase,icesub0)`, `(desbase,dessub0)`, `(morbase,morsub0)` and
`(intbase,intsub0)`, in that order. Names are exact, case-sensitive and terminated
within their 16-byte MAP slots. Opaque bytes following the terminator, other
header fields, ignored SPT words and cell flags are retained unchanged.

### Gameplay Error Bits

Each bit stands for one diagnostic code. Repeated per-record findings collapse
to one bit; no record pointer is retained.

| Bit | Diagnostic code |
|---:|---|
| 0 | `grid_below_authoring_floor` |
| 1 | `tile_outside_resources` |
| 2 | `marker_capacity` |
| 3 | `companion_suffix` |
| 4 | `bundle_render_boundary` |
| 5 | `bundle_primary_boundary` |
| 6 | `runtime_sentinel` |
| 7 | `disabled_without_bundle` |
| 8 | `transformed_x` |
| 9 | `disabled_counted_type` |
| 10 | `negative_y` |
| 11 | `primary_slot` |
| 12 | `no_assignable_troop` |
| 13 | `troop_capacity` |
| 14 | `no_positive_objective` |
| 15 | `label_objective_dependencies` |
| 16 | `missing_computer_target` |
| 17 | `missing_rescue_target` |
| 18 | `missing_rescue_destination` |
| 19 | `missing_civilian_home` |
| 20 | `countdown_overview` |

### Review Bits

| Bit | Diagnostic code |
|---:|---|
| 0 | `tile_399` |
| 1 | `reserved_cell_bits` |
| 2 | `unexposed_marker_class` |
| 3 | `marker_line_of_sight` |
| 4 | `off_map_anchor` |
| 5 | `empty_enemy_gate` |
| 6 | `empty_building_gate` |
| 7 | `factory_target_review` |
| 8 | `multiple_rescue_destinations` |
| 9 | `civilian_home_review` |
| 10 | `runtime_playtest_required` |

Structural return zero does **not** mean playable. A nonzero error mask is
invalid gameplay data; without errors, the result still requires review and
playtesting. Bit 10 is always set. Footprints, runtime effects, recruit/name
availability, edge scrolling and mission solvability are outside these checks.

## Bounds And Ownership

MAP dimensions must be nonzero, their product at most 7,500, and the file exactly
96 plus twice that product bytes. The header signature is lowercase `cfed`.
The 19-by-15 authoring floor is a gameplay error, not structural rejection.
Tiles use the low nine bits; values over 399 are errors and 399 is review-only.
More than ten marker cells is an error. Imported reserved bits and marker
classes remain visible as review items rather than being rewritten.

SPT contains only ten-byte records, with at most 43 records and type `$00..$6E`.
An ignored-word prefix that spells `RNC` is still raw SPT, not compressed input.
Active state uses the signed runtime X after 16-bit `storedX+16`. Coordinate
errors distinguish the runtime sentinel, unsupported inactive values and wrap.
Off-map review intentionally uses the original stored X and Y, not biased X.
Negative active Y is an error and does not also generate off-map review.

Companion membership is authorized only after an exact consecutive type suffix
has been matched for an active owner. Disabled `$8000` placements are accepted
only for authorized type `$04` or `$29` companions. All original companion
recipes and all 111 serialized types participate. Owner working spans and active
primary placements are checked against the 43-slot and first-30-slot limits.
Objective checks count active types and preserve the distinctions between errors
and review items, including empty gates that later spawns might populate.

Scratch is cleared after argument validation: bytes 0..31 stage the result,
32..74 hold companion membership, 75..81 hold type counters, 82..83 hold policy,
84..91 hold pixel bounds, and 92..99 hold input lengths. Bytes 100..127 are zero
reserve. No pointers are stored there. The successful result copy is not an
atomic interrupt-visible publication; the caller controls its ready state and
must not expose a partially validated mission.

The deepest stack write is 96 bytes below the caller's SP, including its `JSR`
return address. Reserve at least 128 bytes for this call in addition to the
caller's, module wrapper's and interrupts' needs. A packaged module must account
for this code together with its parser, reader, wrappers, headers and tables
within its code limit.

The caller must validate every referenced phase before publishing a playable
package, retain independently owned bytes or records as needed, and confirm that
directory identity has not changed. This subroutine neither implements that
controller nor preserves campaign state on its behalf.
