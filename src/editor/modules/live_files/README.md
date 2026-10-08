<!-- Cannon Fodder In-Game Level Editor V1.0
Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
Licensed under the MIT License. See the LICENSE file for details. -->

# Live file operations

`core.s` is a headerless synchronous composition of the browser's file
classifier and record-set deletion service for an already published authoring
session. The caller supplies a private BRW1 and BDQ1, owns display entry and
return, and must close the file-operation guard before module replacement. This
component does not supply a confirmation UI or a dispatcher entry.

`private.i` reserves the final 2,304 bytes of the 16 KiB code partition. BRW1,
delete bitmaps/state and catalog masks/records live there. The exact directory
snapshot occupies READBACK +8,320 through +14,463. The caller may use the first
8,320 READBACK bytes for a modal while no file operation runs; it must release
that modal before deleting files. Canonical draft and history allocations
are never scratch. The existing BDQ1 request occupies the inactive SAVE record.

The owner must have a valid retained AUR1, mode 2, stopped gameplay, its campaign
snapshot, Editor purpose and a pending Open page without a result or transport
error. Selection and commit both protect every selected record sharing the open
source generation under the same `CFEDITOR` identity, even if its manifest is
damaged. Status 16 denotes that refusal. No confirmation helper in this core
grants permission; all initial-browser entry conditions remain unchanged in the
default build.

`files.s` installs this composition as `cf_files.mod` (FOPS). Live Open supplies
only the request tag and the source selector (zero) by value. The installed
owner requires pending Files page 7; the standalone core retains its Open-page
entry contract.
`dialog.s` shows the service as a dialog of the Slave's dialog service (see
[dialog](../dialog/README.md)), which keeps no bitmap backup, so the exact
directory snapshot stays untouched. It shows the marker name, the position,
the title or generation and Up, Down, Delete..., Recover... and Back; the
confirmation names the files and generations in red.

Only a fresh click on Delete in the confirmation deletes. Return and Escape
choose Cancel. The directory and identity checks run every frame while the
dialog is open, and again after it closed and before the first file is
removed. "Files deleted" follows a completely verified deletion. A refusal to
delete the open source says the files belong to the mission open in the
editor; status 5 (a failed host delete) says writing to Custom failed; any
other failure shows its status. The complete selected set is checked against the retained source both
during selection and at commit. Recovery BACK returns to the normal list; normal
BACK returns through a typed FOPS receipt to EDTR. No modal holds pointers into
another overlay.
