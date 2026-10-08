<!-- Cannon Fodder In-Game Level Editor V1.0
Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
Licensed under the MIT License. See the LICENSE file for details. -->

# Editor Modules

Overlay modules link at the fixed `EDITOR_MODULE_BASE` declared in
`include/layout.i`. Each module must return to resident code before another
module replaces it. Native briefing and map-overview routines own the same
memory outside editor mode. No module pointer may survive eviction.

Modules that show the menu, confirmations and messages include the shared
[dialog](dialog/README.md) sources; the WHDLoad Slave draws those dialogs and
owns the display while they are open.

The [phase list](phase_list/README.md), [validation list](validation/README.md)
and [Test lifecycle](test/README.md) use separate bounded overlays. Their private
tails remain inside the existing 16 KiB serializer window.

The build produces seventeen module files. They are installed in the `Custom`
directory next to the `CFEDITOR` marker:

| File | Identity | Source |
|---|---|---|
| `cf_browser.mod` | `BROW` | `browser/` |
| `cf_storage.mod` | `STG1` | `storage/storage.s` |
| `controller.mod` | `CTRL` | `controller/` |
| `cf_save.mod` | `SVR1` | `storage/save.s` |
| `cf_editor.mod` | `EDTR` | `editor/` |
| `cf_tiles.mod`, `cf_fill.mod`, `cf_object.mod` | `TILE`, `FILL`, `OBJV` | `tiles/`, `fill/`, `editor/object_view.s` |
| `cf_menu.mod`, `cf_resize.mod`, `cf_tmpl.mod`, `cf_open.mod` | `MENU`, `RSZE`, `TMPL`, `OPEN` | `menu/`, `resize/`, `template/`, `open/` |
| `cf_files.mod` | `FOPS` | `live_files/` |
| `cf_opal.mod` | `OPAL` | `object_palette/` |
| `cf_phase.mod`, `cf_valid.mod`, `cf_test.mod` | `PHAS`, `VALD`, `TST1` | `phase_list/`, `validation/`, `test/` |

## Module ABI 2

Images contain a 32-byte big-endian header followed by 68000 code and data:

| Offset | Type | Value |
|---|---|---|
| `$00` | Four bytes | `CFMO` |
| `$04` | Word | ABI 2 |
| `$06` | Word | Header size 32 |
| `$08` | Long | Module identity |
| `$0C` | Long | Linked load base |
| `$10` | Long | Complete even image size, including header |
| `$14` | Long | Even entry offset, at least 32 and below image size |
| `$18` | Long | Reflected IEEE CRC32 of bytes after the header |
| `$1C` | Long | Reserved, zero |

The resident dispatcher (`editor_custom_module_dispatch`, used by the resident
request loop, or the equivalent `editor_module_dispatch`) takes A0
pointing to a NUL-terminated filename of 1..14 ASCII letters, digits, periods,
hyphens or underscores, D1.l containing the expected identity, and D2.l
containing capacity 16,384 or 32,768. A call whose return address lies inside
the module window is refused. The filename is copied and zero-padded into the
first 16 bytes of the resident I/O partition before loading. Modules are never
decompressed.

The dispatcher hands that request to the WHDLoad Slave's module transport
through the resident backend veneer. The Slave lists `Custom` (at most 150
names, each a valid name, no two names equal after ASCII case folding), requires
`CFEDITOR` with that exact spelling and a valid 64-byte `CFDI` body, and refuses
a directory that contains the campaign save marker `CFSDISK`. The module file
must be present, even-sized, at least 34 bytes and no larger than the capacity.
It is loaded whole into the module window; its size and the marker's CRC are
checked again after loading. Later loads trust that directory check and load
the module by name, until the file service creates or deletes a file or an
operation of it fails; a load that goes wrong repeats the full check, which
reports the failure. The payload CRC of a module is computed on its first load
after a full check; when it matches the header, later loads publish that CRC
without reading the payload again. The resident then checks the header against
the expected identity, load base and size, and the body CRC, before it enters
the module.

Only the first 64 bytes of the resident I/O partition are private to transport.
Caller data at I/O offset 64 and beyond survives loading. A failed load can leave
a partial image in the module window, but its active identity remains clear and
the dispatcher never enters it. Callers must not execute or retain pointers into
that failed image.

The same resident transport also reads the game's own one-byte disk-marker
files and the campaign snapshot through the native logical-drive track
interface; those paths never load executable code.

## Entry and Requests

The module receives D0 = 2 and A0 pointing to the persistent session context in
`include/session.i`, and returns through RTS with its result in D0.w. ABI 1
modules are rejected. The dispatcher preserves D1-D7/A0-A6 and SP and clears
the active identity on return. Session offsets 0..23 belong to lifecycle state.

Requests contain a NUL-padded 16-byte filename at offset 24, expected identity
at 40 and capacity at 44. The word at offset 48 is the action: -1 means the
requested module has not been entered, 0 returns to the resident caller,
1 requests another module, and 2 requests prepared custom-phase entry. Only
resident code performs dispatch or lifecycle transfers, after the current
module returns normally. It sets action 0 immediately before the validated JSR;
the caller sets -1 before attempting transport. D0 alone cannot distinguish a
load error from an entered service's result.

Word 50 holds the transport status. Word 52 is the module source selector, which
is always zero (the `Custom` directory), and word 54 the game's selected drive
before the request; the resident reselects that drive after the request loop.
Word 56 is the purpose (1 Editor, 2 Custom levels, 4 Test). A service records
its result word at 58 and identity longword at 60 before requesting its caller's
reload. Loading that caller does not clear the pending service result. The
consumer acknowledges it by clearing the identity. Request names and service
results are values, not pointers into an evictable module.

Only trusted controller and resident code publish lifecycle state; main-stack
capture and restoration remain exclusively resident-owned. Continuation targets
are fixed code, not fields supplied by file data. Preparation requires validated
data and the session controller's own preconditions, not merely action 2 in a
request record.

When a lifecycle request cannot be loaded, the recruitment hill shows
CHECK CUSTOM DIR with OK (retry) and CANCEL.

## Load Statuses

An executed module's own D0.w status is returned unchanged. Load failures are:

| Status | Meaning |
|---:|---|
| -1 | Invalid filename |
| -2 | Invalid capacity |
| -5 | Invalid header, identity, load base or size |
| -6 | Body CRC mismatch |
| -8 | Caller return address inside the module window |
| 3 | Module file or `CFEDITOR` absent, or the module could not be loaded |
| 10 | Invalid transport request |
| 11 | Listing failed or exceeds 150 names; misspelled or invalid `CFEDITOR`; campaign save present; marker or size changed during loading |
| 12 | Invalid or case-folded duplicate name in `Custom` |
| 15 | Module size invalid for the capacity |

The native disk-marker and campaign-snapshot reads additionally use -3
(compressed record), -4 (size), -9 (directory, chain or track format) and 4
(refused during a custom session). CRC protects against accidental corruption,
not untrusted executable code.

## Shared Services

The FILES service uses identity FOPS and AUR page kind 7. Open passes its source
selector (zero) by value in the inactive SAVE request. The service retains a
private exact directory through confirmation and returns an ordinary typed
receipt to EDTR; it cannot publish replacement data. See `live_files/README.md`
for its state and snapshot ownership.

MENU also serves authoring messages on AUR page kind 8 and large-Paint
confirmation on kind 9. Requests carry a status word or bounded cell index;
the checked result is consumed once after the modal releases its display.

The object view uses identity OBJV and page kind 10 with candidate NONE.
Object placement, movement, deletion and Undo run in memory while this view
owns the display. A request with a terrain tool performs one object Undo
without acquiring the object display. Mixed Undo returns through EDTR when
the newest group contains terrain changes. Shared transaction sources live
in `object_transactions/`; both views use the same complete-group history.

OBJV uses the embedded `editor/viewport/preview.s` renderer with a 3,216-byte
state and 3,072-byte background save area. Its aligned longword copies use the
same private packing in save and restore. The caller waits for the blitter and
mirrors changed row-zero words into each display guard row after every preview
update or removal, so a copper fetch across the ring end sees current pixels.
Equal guard words remain untouched while the pointer and camera are stationary.

Every preview user supplies 1,536 bytes of Chip mask scratch. Clipped native
masks share one clipping row; the generated source-plane mask path handles
descriptors without native masks. The Terrain and Object views share the
48-line tool bar in `editor/bar.s`: one layout table drives drawing and hit testing, the Slave's
text service draws it, and only changed button states, the cell readout and the
information line are redrawn when their content changes. The TILE and OPAL
bars still draw the owned hill-font glyphs directly; none uses the native text
renderer, whose shared gameplay masks garble the bar. Object mode keeps the
owned glyph cache below the bar (row 48) for its invisible-anchor H marker.

The map view (EDTR, OBJV) and the tile and object pages (TILE, OPAL) take and
return the display through `editor/display.s`: `display_acquire` saves the
native display globals and the copper list, shows the canvas above the tool
bar and sets sprite colors 16-31 to the hill's pointer palette, a yellow arrow
with a dark outline; `display_release` restores all of it. The pages add
`editor/page_view.s`, which shows the canvas from its first row. No authoring
view regenerates the native masks while it is live, so `display_release`
rebuilds them only when another descriptor table was installed meanwhile;
this saves about 17 fields per page change.

Custom Desert phases use the Disk 2 terrain mask consistently, including when
assets are loaded from Disk 3. The permanent base-attribute loader applies this
policy only in custom sessions. Campaign mode retains its original disk-selected
mask; missing optional base masks still use the native zero-filled fallback.

The object palette uses identity OPAL and page kind 11. O opens the five-category
palette from scrolling tools; selection returns a supported root type by value,
and Cancel preserves the tool and selection. See `object_palette/README.md`.
