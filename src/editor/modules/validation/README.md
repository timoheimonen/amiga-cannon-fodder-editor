<!-- Cannon Fodder In-Game Level Editor V1.1
Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
Licensed under the MIT License. See the LICENSE file for details. -->

# Validation list

VALD (`cf_valid.mod`, authoring page 13) streams bounded ERROR and REVIEW records
from the current authored phase and the mission's saved phase sources. Issue
counts and ordinals are 32-bit values; pages are recomputed without retaining an
unbounded list. The last 2,048 bytes of its 16 KiB window are private state,
leaving 14,336 bytes for code.

Current metadata is cloned before normalizing edited payload CRCs. Saved sources
retain exact manifest, `CFEDITOR` identity and directory pins. A failed read
cannot publish partial diagnostic state or alter the draft. The dialog closes
before the next page is staged, which reuses READBACK for its row texts.

The Check results dialog (`list.s`, a dialog of the Slave's dialog service)
shows eight issues per page: severity, phase, place and the problem in words,
with the selected issue's explanation and remedy below. A click or the Up
and Down keys select an issue on the page. Show on map (the default, also a
double click on an issue with a place) focuses a cell or object issue: it selects the relevant phase and
clamps its camera to the map. Global issues have no location action.
Cross-phase focus uses the ordinary unsaved-changes guard and survives
source-map normalization after Save. The pointer-free session record carries
the logical phase and coordinates; EDTR consumes the completed focus receipt
only after assets are available.

The title counts errors and issues to review; the line below shows the visible
range and the phases tested in this session. Winning a Test sets the selected
bit. Edits and Undo clear affected status; mission-wide metadata changes clear
all bits. No TESTED value is serialized into a mission.
