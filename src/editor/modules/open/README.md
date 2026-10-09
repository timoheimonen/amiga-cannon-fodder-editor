<!-- Cannon Fodder In-Game Level Editor V1.1
Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
Licensed under the MIT License. See the LICENSE file for details. -->

# Custom Package Staging

`stage.s` provides `open_stage` for a caller that has released its viewport and
qualified the `Custom` directory. D0.w is the selected phase, 0-5. A0 must equal
`STORAGE_CONTEXT`, containing a manifest basename and the expected `CFEDITOR`
disk ID. D0.w returns zero on success or a parser, payload or reader status.
All other registers and SP are preserved.

The helper validates the manifest schema and every phase's raw MAP/SPT, with the
selected phase last. Gameplay errors do not make a structurally valid draft
unopenable; the result combines the package's gameplay errors and reviews.
A single directory fingerprint must hold across all dependency reads, in
addition to the reader's identity, size, CRC and directory checks.

The last 4,928 bytes of the 16 KiB module partition are reserved data:

| Offset | Bytes | Content |
|---|---:|---|
| 0 | 4,096 | Manifest |
| 4,096 | 430 | Padded selected SPT |
| 4,526 | 2 | Alignment gap |
| 4,528 | 384 | Selected metadata |
| 4,912 | 16 | Guard/reserve |

READBACK ends with the selected MAP. WORK alternates between raw-reader scratch,
parser output/scratch and payload validation result/scratch. These owners are
not concurrent. The helper's private stack frame is 60 bytes plus saved registers
and nested calls.

Canonical MAP/SPT/metadata, AUR, undo, manifest workspace and campaign state stay
unchanged. Failure makes all staging disposable. The caller must check success,
recheck its ownership and publish atomically at its own logical commit boundary;
this helper does not dispatch modules, draw a browser or start the engine.

# Live Open Overlay

`open.s` packages the helper and browser as `cf_open.mod` (`OPEN`). MENU releases
its display and establishes page ownership before dispatch. The overlay requires
that exact AUR page and an empty incoming result. It uses the 256-byte UI record
for private selection, source selector, disk identity, capacity and validation
status. The reserved tail alternates between catalog rows and the staged
package.

`dialog.s` shows Open as a dialog of the Slave's dialog service (see
[dialog](../dialog/README.md)). The title strip shows the `CFEDITOR` marker
name, the line below the room left in files and bytes. Four list rows show
title, phase count and status in columns: a damaged manifest shows Damaged,
and a selection that Open refused shows Blocked. Selecting a row checks
nothing; Open stages and validates every phase, opens Invalid and Review
drafts, and marks a structural or read failure Blocked, after which Open is
disabled for that selection. Titles are measured in the
hill font against the limit title entry enforces (`TITLE_HILL_WIDTH`), so
every title it accepts is listed; a row shows the first 27 characters, which
end before the Phases column. A wider title, or one with glyphs outside the
game font, is listed as `LONG TITLE` while its stored bytes remain unchanged.
When no mission is listed, the list area says so.

Up and Down (buttons or keys) change the selection, clamping at either
end; a click on a row selects it, and a double click opens it. The selection
moves in place; another page rereads its manifests while the dialog stays
open. New... enters the ordinary guarded New dialog, Open (default, also
Return) accepts, Files... enters private Delete/Recover at the selected
mission, and Back or Escape
cancels. New keeps the current draft and its source until
the New dialog commits. Each inspection first clears the previous private
identity, name, capacity and catalog selection, so a rejected directory cannot
retain the previous header or an eligible selection.

The dialog closes before staging. A page change reads its manifests with
the dialog open and rebuilds the row texts, whose scratch the reads reuse,
before any button is redrawn. Open stages the whole package before
publication; a refused candidate is discarded and the catalog rebuilt. No
reference to a dialog, reader scratch record or evicted overlay is retained.

Publication copies the candidate into canonical allocations, resets history,
retains the new manifest, adopts its disk and source identity and phase mapping,
and returns a clean Open receipt. The editor reloads terrain assets before
reacquiring the viewport. Failed reads and cancellation leave the old authored
data, source and undo intact. The original campaign snapshot stays unchanged.
