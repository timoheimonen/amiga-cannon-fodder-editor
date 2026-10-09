<!-- Cannon Fodder In-Game Level Editor V1.1 -->
<!-- Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me> -->
<!-- Licensed under the MIT License. See the LICENSE file for details. -->

# Mission Browser

`browser.s` is the `BROW` catalog overlay, loaded as `cf_browser.mod`. It uses
the 16 KiB serialization code partition. Its entry requires module ABI 2:
`D0.w = 2`, `A0 = EDITOR_SESSION_BASE`, and purpose 1 (Editor) or 2 (Custom
levels). It must be called from the active recruitment hill.

The browser is a full-height dialog of the WHDLoad Slave's dialog service
(`ui.s`, see [dialog](../dialog/README.md)) over black; the hill's display is
untouched and returns when the browser leaves. It lists the missions in the
install's `Custom` directory, four per page: each row shows the title and a
detail line with the phase count and whether the manifest is damaged. The
title strip shows the purpose (Custom levels, Editor or Interrupted saves) and
the name stored in the `CFEDITOR` marker; below it the room left in files and
bytes. A status line reports the storage check in words. Up and Down buttons,
cursor keys and row clicks change the selection in place: only the rows and
buttons that change are redrawn, and another page rereads its four manifests
while the list stays on screen. Selecting a mission requests no check; Play
and Edit request the complete storage check of the selection first and go on
by themselves when it allows them.

The action row depends on the purpose:

- Custom levels: Play, disabled once a check refused the selection, and Back.
- Editor: Edit, disabled once a check refused the selection, New..., and Back.

Return or a double click on a mission (two clicks on its row within
`DIALOG_DOUBLE_CLICK` fields) activates the first action; Back or Escape
returns to the hill. The lower
row offers Delete... when missions are listed and Recover... when unreferenced
files exist; unavailable buttons are disabled. Delete... asks in a red
confirmation (`files_ui.s`) where only a click on Delete confirms. The browser
requests the controller to prepare gameplay or authoring; it never starts the
native phase itself or emits `REQ_ACTION_PREPARE`. Deletion and recovery never
enter gameplay, and the browser never modifies MAP or SPT contents.

## Catalog and Display

Inspection requires a qualified `Custom` directory with a valid `CFEDITOR`
marker (see `storage/READ.md`). Only canonical eight-hex-digit `.cmi` names are
catalog entries, matched with ASCII case folding while preserving the stored
spelling. The checked names are copied before another read can overwrite the
directory cache. The linked file reader and CFMI parser classify every manifest,
including every phase's schema, before publishing file-management actions. The
page parser projects the displayed titles. Neither operation reads MAP/SPT
dependencies; full payload validation remains limited to the selected mission.

`OK` means the manifest is structurally valid, not that its mission is playable.
`DAMAGED` means the manifest's size or contents fail validation, or a page read
failed for another reason than cancellation or a changed directory (those abort
the page). Any read error during file classification aborts it instead of
granting recovery authority over unread files. Damaged entries cannot request
payload validation, but may be deleted by generation. Full validation results
are displayed separately as INVALID, REVIEW or VALIDATION FAILED.

All text uses native font group 13. Display projection converts ASCII lowercase
to uppercase; stored marker and manifest bytes are never changed. The safe glyph
set is `A` through `Z`, `0` through `9`, and space. Every string is measured,
including the native `A` ink overhang. Catalog titles must fit 288 pixels,
the limit title entry enforces (`TITLE_HILL_WIDTH`).
Unsupported and overwide titles receive the literal fallbacks UNSUPPORTED TITLE
and TITLE TOO WIDE. Their manifest status remains independent, and
`BROWSER_DISPLAY_SAFE` is false. A caller must not treat successful payload
validation alone as permission to play.

## Normal-Return Protocol

The browser preserves session bytes 0 through 23 and 64 through the end.
On BACK it leaves `REQ_ACTION_RETURN`. Before the check that Play or Edit
requests it marks the selection PENDING and the action as waiting
(`BROWSER_ACT`, word 100 of the browser record), restores the hill, then
returns with this pointer-free request:

- `REQ_NAME = cf_storage.mod`, ID `STG1`, capacity 16384, action DISPATCH.
- Storage command VALIDATE, selected phase zero and composite READY zero.
- The storage read request contains the selected canonical basename and the
  `CFEDITOR` disk ID.

The pending service tag is `STG1`. The storage overlay returns to BROW with
`REQ_RESULT_ID = STG1` and `REQ_LAST_RESULT` set to its status. A successful
result requires returned status zero, storage status zero, composite READY one,
CFMD magic, and the same selected basename in resident metadata. The browser
copies the aggregate error bitset before reusing the storage request.
It then inspects the directory again and requires the same disk ID and
directory fingerprint; any mismatch invalidates the displayed result. Catalog
rebuilding locates the selected basename again instead of trusting its former
row index. No continuation pointer is read from a file or retained across
overlay eviction.

Each service result is consumed once, clearing its pending tag and session
result tag. Success becomes INVALID when any phase has a gameplay error and
REVIEW otherwise: every phase carries the playtest review, because static
checks cannot prove a phase can be won. A transport error or inconsistent
result becomes FAILED. When the result allows the waiting action, the
browser requests the controller without drawing the list again; otherwise it
clears the waiting action and shows the result. Only a Play or Edit on an
unchecked selection requests a check, so reloading the catalog after a result
cannot start a service loop. A changed selection permits another check; every
draw publishes the selected row's basename in `BROWSER_SELECTED_NAME`.

A `CTRL` handback is accepted when the pending tag is `CTRL`. It preserves the
selection's validation and aggregate error bitset and keeps the signed 16-bit
controller status separately. A nonzero result displays "Could not start" with
its decimal magnitude. This disables PLAY and EDIT until an explicit validation
retry or selection change clears the failure. It never relaunches the
controller automatically.

PLAY requires purpose 2, a nonempty selection, REVIEW, zero gameplay
errors and operation/controller status, no pending service, a display-safe
title, and matching resident CFMD magic and basename. EDIT requires purpose 1,
a successful storage result (INVALID or REVIEW) and the same selection
checks except gameplay errors and title safety. Both restore the hill and return
a request for `controller.mod`, ID `CTRL`, capacity 16384, action DISPATCH, with
pending tag `CTRL`; word 124 of the browser record carries the authoring
operation (0 play, 1 New, 2 Open). NEW is available in Editor purpose outside
the recovery and error views while no custom session, campaign snapshot or
gameplay is active. The controller independently verifies identity, directory,
payload and display preconditions before it can emit PREPARE. Only a check
that Play or Edit requested is followed by its action.

A fresh entry has no recognized pending service result and resets browser
state. Before consuming that state or owning the display, the browser inspects
the `Custom` directory; a failure returns its status with action UNENTERED to
the resident, which shows CHECK CUSTOM DIR. CANCEL in the storage request is
checked before reads and requests, and the file reader checks it again during
each transaction.

When inspection or catalog building fails inside the browser, the error view
shows CHECK CUSTOM DIRECTORY with RETRY and BACK. Return or RETRY clears the
cancellation latch and validation authority, inspects the directory again and
rebuilds the catalog. A deletion is never retried automatically.

## Delete And Recover

DELETE on a valid manifest selects every valid manifest with the same mission
ID and all canonical CMI/MAP/SPT files under those generation prefixes.
Revision numbers do not choose a winner. Payload-invalid or incomplete
generations still belong to an explicitly identified mission. DELETE on a
damaged manifest is limited to its selected eight-hex generation; it never
uses a damaged title or ID to infer another generation.

RECOVER lists canonical generation files not referenced by a valid manifest.
Each row shows a generation and file count. A valid manifest protects itself
and its exact declared references even if a payload is missing or corrupt.
Extra files under a valid prefix therefore form a recovery set without the
valid manifest or its referenced files. Other names, modules and the marker are
never recovery targets. BACK or Escape returns from recovery to the mission
list; an empty recovery view shows NO FILES.

Every deletion requires a fresh confirmation showing the marker name, the
mission title or generation, and generation and file counts. Unsupported or
overwide mission titles fall back to the generation; an unsupported marker name
is replaced by CUSTOM DIR and the full 32-hex-digit disk ID on two lines.
Return answers NO and Escape cancels. Opening and closing mouse presses are
drained; a held press never authorizes YES.

Click rectangles use logical X (bitmap X minus 16):

| Row | Y | Columns |
|---|---|---|
| Actions, Custom levels, recovery and error views | 190..203 | first action 0..183, BACK 184..287 |
| Actions, Editor | 190..203 | EDIT/VALIDATE 0..95, NEW 96..191, BACK 192..287 |
| File actions | 208..221 | DELETE 0..95, RECOVER 96..191 |
| Confirmation | 144..157 | YES 0..143, NO 144..287 |

The file-action row is empty in the recovery and error views.

`browser_delete.i` defines the fixed 128-byte BDQ1 request at I/O + 352. The
adapter admits only stopped, snapshot-free session mode 0, purpose 1 or 2, four
display planes, interrupt priority 0 and a zero source selector. Opening it
inspects the directory and pins all 64 `CFEDITOR` bytes. The complete 6,144-byte
catalog and exact record masks remain live through confirmation. Before any
file is removed, the deletion core requires a fresh catalog to equal that
snapshot byte for byte. It then removes the selected manifests first and their
payload files afterwards, one verified file at a time, checking after every file
that all other records are unchanged (see `storage/DELETE.md`).

ATTEMPTED and VERIFIED are separate result words. A refused operation makes no
change; an attempted but unverified operation may already have removed files.
A cancellation after verified removals refreshes the catalog and reports FILES
DELETED. Unattempted Escape declines quietly. All successful changes invalidate
old PLAY/EDIT and service authority and rebuild selection and capacity. An
interruption leaves only unreferenced payload files, which RECOVER can remove.

## Resident Record

`browser.i` allocates 128 bytes at `EDITOR_IO_BASE + 224`. All values are
big-endian; the record contains no pointers.

| Offset | Bytes | Value |
|---|---:|---|
| 0 | 4 | `BRW1` magic |
| 4 | 2 | Record version 1 |
| 6 | 2 | Entry purpose |
| 8 | 2 | Source selector, zero (the `Custom` directory) |
| 10, 12, 14 | 2 each | Selected index, first page index, mission count |
| 16 | 16 | `CFEDITOR` disk ID |
| 32 | 32 | Marker name, NUL-padded |
| 64 | 4 | Remaining quota in bytes |
| 68, 70 | 2 each | Free directory records, directory record count |
| 72 | 4 | Directory fingerprint |
| 76 | 16 | Selected canonical basename, NUL-padded |
| 92, 94 | 2 each | Validation state, last operation status |
| 96 | 4 | Aggregate gameplay errors |
| 100 | 4 | Reserved, zero |
| 104 | 2 | Selected title is display-safe |
| 106, 108, 110 | 2 each | Page count, reserved, scan index |
| 112 | 2 | Pending-result resumption flag |
| 114 | 2 | Signed controller status, zero when no launch failure is pending |
| 116 | 4 | Pending service ID: zero, `STG1` or `CTRL` |
| 120 | 2 | Signed file-operation status; -1 means verified late cancellation |
| 122 | 2 | Recovery-view flag, zero for the normal mission list |
| 124 | 2 | Authoring operation for the controller: 0 play, 1 New, 2 Open |
| 126 | 2 | Reserved, zero |

After an accepted New setup, offsets 64..71 carry the New parameters (width,
height, terrain family and tag, or the Template mission, phase and map) by value
between the two controller passes.

The validation values are NONE 0, INVALID 2, REVIEW 3, FAILED 4 and PENDING 5;
value 1 is unused. The display flag cannot independently authorize gameplay.
REVIEW does not itself prohibit gameplay; INVALID does.

## Buffer Ownership

| Region | Owned bytes and lifetime |
|---|---|
| Module base | At most 16384 immutable code/constants bytes |
| Readback + 0 | At most 4096 raw manifest bytes per read |
| Readback + 4096 | 150 copied filenames, 16 bytes each |
| Readback + 6496 | Four 72-byte projected catalog rows |
| Readback + 8192 | 512-byte parser scratch |
| Serial work + 0 | File service's first 864 bytes, then parser output in the first 512 |
| Serial work + 864 | Two 64-byte text buffers and six control bytes |
| UI + 0 | 96-byte transient hill display restoration record |

File classification and confirmation sequentially reuse these slices:

| Region | Owned bytes and lifetime |
|---|---|
| I/O + 352 | 128-byte BDQ1 request and bounded diagnostics |
| Readback + 4096 | 512-byte parser scratch during classification only |
| Readback + 6144 | 6144-byte confirmed catalog |
| Readback + 12288 | Deletion masks and state, ending before offset 13064 |
| Readback + 13064 | Three 20-byte protected, selected and recovery masks |
| Readback + 13124 | 150 six-byte classification records |
| Readback + 14024 | 150 two-byte recovery view entries; end offset 14324 |
| UI + 96 | 64-byte projected confirmation title |
| UI + 160 | Prepared/actions/title-kind/intent words, copied name and held-input word; end offset 186 |

Normal-page names and rows overlap the old catalog snapshot. The file guard
must close before names are copied forward and the normal page is rebuilt.
Never call the normal page parser or renderer while a confirmation retains
that snapshot. UI bytes 186..255 are unused by file management.

The parser output is never published to resident mission metadata by this
module. Resident metadata, SPT, canonical MAP, undo storage and the manifest
workspace remain unchanged. Readback and serial work are expendable on the
next overlay request. Assembly assertions bound all local allocations.

The original visible hill bitmap is preserved as the restoration source.
The browser exclusively uses the other native bitmap, suppresses the
sidebar sprites, installs the font masks and renders without running the
hill animation. Before any normal return it reinstalls the prior mask
table and mode, restores display globals and copper sprite pointers,
republishes the original visible image, and copies that image into the hidden
bitmap. Thus the visible hill is byte-exact; the old hidden image is
deliberately rebuilt from it, not independently preserved. The native hill loop
resumes only after this paired restoration. The game's keep-drive-selected word
is restored as well. UI storage is then available to another owner.

## Shared Character Picker

`picker.s` is an include-only library, independent of the BROW catalog entry.
Link it with the controller's `text.s` for the common `text_preflight` helper.
It uses UI bytes 96..255, leaving the caller's first 96 display-owner bytes
unchanged. Do not run it concurrently with another UI owner.

`text_picker_run` accepts A0 pointing to a mutable, addressable 64-byte
NUL-terminated string, D0.w maximum length 1..63, D1.w hill-font width 1..288,
and D2.w optional briefing-font width 0..320. Zero skips briefing measurement.
The source span must not overlap the picker context. Its caller exclusively owns
a linear four-plane display and has already installed hill group 13, masks,
zero space substitution/alternate mode and active cursor/input. The picker
clears and redraws that bitmap; it does not switch or restore display resources.
Gameplay, a fifth plane and interrupt priority 3 or higher are refused.

The grid offers A-Z and 0-9, with SPACE, DEL, CLEAR, OK and CANCEL. Escape cancels;
Return accepts a nonempty value. No keyboard text entry is implemented.
Insertions exceeding either measured font width or the length limit are refused.
ASCII lowercase in an existing string projects to uppercase for display without
changing the stored bytes. Unsupported initial glyphs are refused before drawing.
For mission and phase titles, supply every required screen-width constraint
through this interface or the caller's additional checks.

Only accepted edits update the source, including its NUL terminator; its unused
tail is unchanged. D0 returns 1 accepted, 2 cancelled, or a negative argument/
initial-content error. D1-D7/A0-A6 and SP are preserved. Opening and closing
mouse presses are drained. The complete context and code must remain live until
return; no pointers survive eviction as valid picker state.

`text_picker_begin` exposes the same non-rendering edit initialization.
`text_picker_event` takes ASCII in D0.w or -1 backspace, -2 clear, -3 accept,
-4 cancel. It returns 0 edited, 1 accepted, 2 cancelled; errors are -1 argument,
-2 glyph, -3 width, -5 length, -6 empty acceptance. Rejected insertion preserves
the draft and its measured width. Accept/cancel invalidate the edit context.
