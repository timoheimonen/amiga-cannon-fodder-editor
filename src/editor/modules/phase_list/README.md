<!-- Cannon Fodder In-Game Level Editor V1.0
Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
Licensed under the MIT License. See the LICENSE file for details. -->

# Phase list

PHAS (`cf_phase.mod`, authoring page 12) edits a mission's one to six logical
phases in the Mission phases dialog of the Slave's dialog service (`list.s`):
one row per phase (number, title, size and the phase being edited), Edit,
Move up, Move down, Delete, Add copy, Add blank..., Add template...,
Settings..., Done (also Return) and Cancel (also Escape). Buttons that cannot
act are disabled. Moving and deleting other phases remain private until Done;
while such changes are pending, the actions that leave the list are disabled
and the status line says so. Edit, Add copy, Add blank, Add template and
Delete of the edited phase pass through the ordinary Save/Discard/Cancel
guard; Settings... opens the current phase's settings in MENU. Add blank
uses the shared New dialog. An unsaved phase must be saved before it can
become an unselected source.

The last 1,344 bytes of the 16 KiB module window hold snapshots and staging;
executable code is limited to 15,040 bytes. A replacement checks source identity,
directory consistency, payloads and the unchanged author before publishing.
It retains mission fields, clears current Undo and reacquires terrain assets.
Map-only Done retains Undo. Private TESTED bits follow logical reorder/delete;
appended phases start untested and cancellation preserves the original mask.

No overlay pointer survives a page change. Module identity, page, candidate,
entered result and owner state must all agree before a receipt is consumed.
