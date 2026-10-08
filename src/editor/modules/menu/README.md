<!-- Cannon Fodder In-Game Level Editor V1.0 -->
<!-- Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me> -->
<!-- Licensed under the MIT License. See the LICENSE file for details. -->

# Authoring Menu

`cf_menu.mod` is the `MENU` overlay in the 16 KiB code partition. Entry requires
module ABI 2 and the exact AUR1 MENU page request, with gameplay stopped and
all viewport owners released. The module returns normally before another
overlay loads; canonical data, undo and campaign snapshot remain outside it.

The menu provides guarded New and Template, Open, Save, Save as, Resize, the
mission phases and guarded Exit. Every MENU modal is a dialog of the Slave's
dialog service (see [dialogs](../dialog/README.md)). Unavailable actions
return an explanatory message without changing authored data. A Save that
`Custom` refused names its cause (150 files, or no room left) and the remedy;
other failures show Editor error and the status number. Escape or Close closes
the menu. Save and Resize dispatch their existing services by value.
An entered MENU receipt distinguishes a clean Exit or explicit Discard from
cancellation, failure or an unentered module load.

Save as asks for a private title typed on the keyboard; Space, Delete and
Clear are also buttons. The dialog shows the measured width against the limit
and names a refused character. Input must fit both hill and briefing screens.
Cancel leaves the title unchanged. Accept publishes the title as a dirty edit
before requesting a new mission from SAVE. A subsequent write failure retains
that edit and the old verified source; only a successful verified receipt
adopts the new mission. Undo is preserved.

The dialogs use WORK160..383 for their texts and command lists; the title
occupies WORK512..575 and the bounded picker UI96..255. No bitmap is backed up:
the Slave restores the display it borrowed before every normal dispatch, and
no file access or payload staging runs while a dialog is open.

New asks Save/Discard/Cancel for unsaved work. Discard opens the New dialog
without changing the old draft; cancelling it retains that work.
Save continues only after its verified receipt. Accepted choices build a complete
candidate in scratch and pass structural validation before canonical publication.
Publication clears old undo/source state and creates a dirty one-phase mission.
A typed receipt requires EDTR to reload terrain assets before opening the view.
The campaign snapshot remains the original session snapshot throughout.

Template uses the same unsaved guard and a distinct verified Save continuation.
It dispatches `cf_tmpl.mod` with a Template page receipt. The Template overlay
owns original mission/phase selection, staged import and the final `Custom`
directory check; MENU retains no pointer or return address into that overlay.

Open shares the unsaved guard and uses its own verified Save continuation.
It dispatches `cf_open.mod` with an Open page receipt. Selection and staging use
private allocations; successful publication adopts a clean saved source and
requires terrain asset reload before the authored view resumes.

Live Open can request this same New flow by returning normally with MENU page
candidate 2. The ordinary New guard runs again for a retained dirty draft;
verified-Save continuations are already clean and go directly to the picker.
Cancelling keeps the old draft and returns to the menu. The draft keeps its
source until the New picker commits a replacement.

If a live game-resource load is cancelled, the menu instead shows Terrain
graphics missing with Save, Exit and Retry. Retry (also Escape/Enter) asks the editor
to reload all resources before restoring the viewport. Save retains the asset
state and returns here; Exit uses the ordinary unsaved-work guard. Save and Exit
can complete without loading graphics, but only after a verified save. A failed
save retains the draft. Tool pages and replacement actions are unavailable
until resources are complete. The state lives in AUR1 offset 126 and survives
normal overlay changes; no stack or executable pointer is retained by MENU.
