<!-- Cannon Fodder In-Game Level Editor V1.1
Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
Licensed under the MIT License. See the LICENSE file for details. -->

# Resize Overlay

`resize.s` is the `RSZE` overlay, installed as `cf_resize.mod`. It uses the
16 KiB code partition and the existing authored-session page request. Entry
requires pending page kind 3 with candidate `$FFFF`, valid authored metadata
and a successful `Custom` directory inspection. The editor releases its viewport
before dispatch.

The dimension dialog limits the proposal to 19×15 or larger and at most 7,500
cells. An unchanged size returns without clearing undo. Other changes require
confirmation, including expansions with no removed objects. The removal list
shows each logical owner with the object palette's name of its type (the type
in hexadecimal when the palette has no such root) and its cell. Empty results
and malformed companion groups are refused without changing the draft.

The dialogs (`dialog.s`) are three dialogs of the Slave's dialog service on one
band: the size with repeating steppers, the confirmation that lists the removed
objects one at a time and says that Undo is cleared, and the refusal. They own
UI bytes 0-247; Continue stages the placements in WORK256..715 while the
dialog is open. After the dialog returns, the overlay recomputes placement staging,
stages the complete MAP in READBACK and computes both CRCs. A final Escape
check precedes the first canonical write. Publication copies both
payloads, updates lengths and CRCs, clears undo, clamps the camera and marks the
phase dirty. It then returns normally with a by-value receipt requesting EDTR.
No pointers or return addresses into RSZE survive replacement.

Receipt statuses are 0 for unchanged, 1 for committed, 14 for cancelled and
-41 for pre-commit failure after the dialog has closed.

## MAP Staging

`map.s` supplies `resize_map_stage`, a leaf routine that builds a resized MAP
in a separate buffer. It keeps the top-left overlap byte for byte, fills new
cells with the selected tile, and preserves every header byte except the two
dimension words. It does not modify the source, placements, metadata or undo.

| Register | Input |
|---|---|
| A0 | Even pointer to the complete source MAP |
| D0.l | Exact source length, 98-15,096 bytes |
| A1 | Even pointer to a distinct writable staging buffer |
| D1.l | Staging capacity in bytes |
| D2.w / D3.w | New width / height; at least 19×15, at most 7,500 cells |
| D4.w | Selected graphic tile, 0-398 |

D0.l returns the staged byte count on success or `-1` on refusal. All other
registers, SP and SR control bits are preserved; condition codes are not.
The routine uses 56 stack bytes plus the caller's four-byte return address.
Interrupt stack requirements belong to the surrounding execution environment.

Both buffer extents must refer to RAM owned by the caller and must not alias
the code, stack or other owners. The routine checks even addresses, 24-bit
extent ends, source/destination overlap, the `cfed` signature, exact source
geometry, target geometry, capacity and tile index before any destination
store. Touching buffer boundaries are allowed. Resource names and the complete
phase require separate structural validation by the caller.

Imported source dimensions may be below the authoring minimum. Cropping
preserves all bits of retained cells, including reserved and marker bits.
The fill word has no marker bits. No byte after the returned extent is written.
This routine stages geometry only; publishing a resized authored phase also
requires the caller's placement policy, confirmation and transaction ownership.

## Placement Staging

`spt.s` supplies `resize_spt_stage`. A0/D0.l are the source pointer and exact
SPT length (10-430 bytes, divisible by ten); A1/D1.l are a separate destination
and its capacity; D2.w/D3.w are the new grid dimensions. The same destination
geometry and RAM ownership rules apply. D0.l returns the retained SPT byte
count, `-1` on refused input/buffers, or `-2` if no logical object would remain.
Every other register, SP and SR control bit is preserved. The stack frame is
56 bytes plus the caller's return address. No destination writes occur on refusal.

The routine groups each owner with its exact consecutive companion suffix and
clips by the owner's `(stored_x+16, stored_y)` world anchor. It preserves or
removes the whole group, keeping retained bytes and order unchanged. Companion
coordinates are never independently clipped or repaired. An incomplete/wrong
suffix or ambiguous root anchor (`stored_x > $7FEF` or `stored_y >= $8000`)
refuses the operation. These operation checks do not establish PLAY eligibility.

The staged result has this layout:

| Offset | Bytes | Contents |
|---|---|---|
| 0 | 2 | Retained SPT byte length |
| 2 | 2 | Removed logical item count |
| 4 | 4 | Removed original records 0-31, bit 0 is record 0 |
| 8 | 4 | Removed original records 32-42, bit 0 is record 32 |
| 12 | 10-430 | Retained raw SPT records |

The maximum output is 442 bytes; the unused destination tail stays untouched.
The removal mask describes the unchanged source, allowing confirmation to list
complete logical items before publication. It is a staging envelope, never an
SPT file format or persistent reference. A surviving object need not be a troop.
