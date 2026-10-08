<!-- Cannon Fodder In-Game Level Editor V1.0 -->
<!-- Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me> -->
<!-- Licensed under the MIT License. See the LICENSE file for details. -->

# Custom Session Controller

`controller.mod` is the `CTRL` overlay. It requires module ABI 2 (`D0.w=2`,
`A0=EDITOR_SESSION_BASE`) and the 16 KiB serialization code partition. It
returns normally to permanent code; it never retains an overlay continuation
or changes the main lifecycle stack itself.

## Entry And Publication

Every entry except Test routing first checks the storage request's CANCEL field
and inspects the `Custom` directory, including its `CFEDITOR` marker. Initial
play additionally requires a zero source selector, the browser's disk ID and
directory fingerprint, an unchanged selected manifest name, and a successful
complete storage validation. Gameplay
errors block play. Review warnings remain playable and retain their bitset in
`STORAGE_REVIEWS`.

The controller checks the resident MAP/SPT lengths and CRCs. Both authored
titles are projected into independent 64-byte buffers at metadata offsets 256
and 320. The projection accepts briefing-font letters, digits, space and
apostrophe, explicitly uppercases ASCII lowercase, and checks centered ink
against the 320-pixel display width. Unsupported or overwide text is an error;
the authored strings are never changed or truncated.

Before modifying the campaign, an independent empty-roster preflight checks
the first 30 SPT placements, at most eight assigned troops, available recruits,
and the 360-name bound. The controller then captures the original campaign,
initializes the custom campaign, and captures its retry checkpoint. A final
cancellation check publishes action PREPARE while interrupts are excluded. No
file access occurs in that short publication interval.

Initial failure leaves the original hill's graphics untouched. If initialization
already captured a campaign, the stable original bytes are restored first.
The controller returns a normal DISPATCH request for `cf_browser.mod`, with
`REQ_RESULT_ID=CTRL` and `REQ_LAST_RESULT` containing the error. A browser must
recognize that numeric result before presenting another play action.

The resident restarts the front-end song (song 0) when it captures a custom
outcome, as the skipped native results screen would; otherwise the victory or
defeat tune keeps looping on the result screen and in the editor after Test.

An active custom session accepts HILL and OUTCOME events only. HILL rechecks
the selection, payload, titles and troop bounds, then returns PREPARE without
capturing or initializing the campaign again. OUTCOME presents the phase
result, a dialog of the Slave's dialog service: Phase complete, Phase ended or
Squad lost, with Retry, eligible Next phase and Return to hill (default). The
Slave restores the display it borrowed before
returning; the controller independently rechecks the selected operation.
RETURN uses the permanent bridge, never a browser whose hill resources are no
longer installed.

RETRY and NEXT request `cf_storage.mod` through a normal resident dispatch.
The service returns a fixed CTRL request. Every reply must match the pinned
mission identity, generation, revision, recruit budget, phase count and manifest
size/CRC. RETRY additionally matches the complete saved 40-byte phase policy.
Failed validation cannot resume play: the inactive MAP may contain scratch data.
Only successful payload/title/allocation checks can publish PREPARE. Service
errors may be retried or abandoned with RETURN.

Completed phases are counted once using the captured native SR.Z result.
Survivors, remaining recruits, ranks and earned completion counts carry to NEXT;
no original campaign-boundary recruit bonus is applied. Final successful
completion promotes each nonempty survivor by its earned count, capped at rank
15, then clears that count. Unassigned survivors retain earned promotions.
Repeated result entry or storage retries never duplicate this accounting.

## Owned State

The snapshot stores 3688 bytes for audit, but restoration copies only the
3664-byte stable campaign suffix. The 24-byte live IRQ/display prefix is not
replayed. Initialization establishes the native roster tail, score state,
death-list pointers and terminators before publishing the exact snapshot tag
and custom mode. Snapshot bytes remain immutable until the session ends.

The pointer-free controller transaction occupies session offsets 72 through 95;
offsets 64 through 71 are not used by the controller. Checkpoint helpers
occupy session offsets 96 through 367. They retain roster,
scalar, policy, hall-of-fame, death-list pointer and counter state. Restore
checks all 40 policy/identity bytes before writing, validates bounded aligned
append pointers, restores list terminators, and rebuilds native binding
sentinels. A rejected checkpoint replacement preserves the prior valid copy;
successful replacement invalidates and republishes its tag inside the bounded
copy transaction. Retry restores rather than recaptures that checkpoint.

For play transactions, the file service owns serial-work bytes 0 through 863. Initial name
preflight temporarily uses bytes 864 through 959 for an empty roster after
inspection returns. The metadata candidate at 1032 through 1287 and undo area
remain untouched by CTRL. During result presentation, UI bytes 0 through 223
and readback bytes 0 through 14079 hold transient display state and a hidden
bitmap band backup. No readback value survives across that UI call; subsequent
storage reconstructs its own workspace. No additional resident region is
allocated. Metadata projection buffers are separate from the authored
256-byte CFMD record.

All controller and checkpoint public entries preserve D1-D7/A0-A6 and SP.
Controller D0 is zero or a signed error. Reader errors retain their positive
status categories. Controller errors -20 through -23 identify state, selected
record, payload and title failures; checkpoint errors -1 through -6 identify
state, list, policy, roster, capacity and SPT failures. SR control bits survive
all bounded memory transactions. Native graphics/font installation remains
owned by the normal resident-to-engine preparation path.

## Initial Draft Entry

Editor New runs two normal controller passes. The first presents the terrain
and size controls or the original Template picker while the campaign and draft
buffers remain untouched. The second runs only after campaign capture and
native lifecycle preparation, with BRW1 authority and no live AUR1 document.
Blank New constructs the chosen grid and a centered troop; Template reads the
selected original MAP/SPT and builds an explicit one-phase custom policy.

The first pass shows the New dialog shared with the editor menu
(`dialog/new_mission.s`) with an extra Template... button, and the Template
list shared with the TMPL module (`dialog/template_list.s`), both dialogs of
the WHDLoad Slave's dialog service. The list shows the game's own mission
titles, eight at a time, then the chosen mission's phases; Previous and Next
step one title and wrap, Use or a click on the selected row moves on, and Back
or Escape returns from phases to missions, then to New.
Selection crosses the controller passes as mission/phase/map numbers with a
distinct tag, never a pointer into an overlay. Import reads the original MAP
and SPT from the game disks through the native logical drives, trying drives 0
to 3 in turn, while a "Loading template" dialog is shown. If none supplies the
files, the shared game-disk dialog names disk 2 or 3 with a drive choice (DF0
to DF3), Retry and Cancel. The read-only original transport
and bounded RNC decoder own READBACK and 400 bytes of serializer scratch. Both
files must come from a game-disk directory with the same CRC. Authored titles
preserve the original bytes, while recruit, rank, ammunition, aggression,
objectives, overview and countdown are explicit policy.

Blank New first builds its complete MAP in READBACK and its SPT/metadata in
serializer WORK, then copies the accepted candidate into canonical storage.
These initial constructors clear undo/manifest state after successful
construction. They do not replace an existing authored document. The dialogs
need no hill font, masks or palette; the fade state is saved in UI storage and
held at full brightness while they are open, because the SOFT IRQ consumes
Escape at fade level 16. EDTR performs structural validation and asset
setup before publishing AUR1. Import failure or cancellation returns through
the resident lifecycle to restore the campaign.
