<!-- Cannon Fodder In-Game Level Editor V1.0
Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
Licensed under the MIT License. See the LICENSE file for details. -->

# Current Phase Metadata

MENU hosts this private metadata service. BEGIN copies the complete current
metadata and authoring owner. The Mission and phase settings dialog
(`dialog.s`, a dialog of the Slave's dialog service) edits only a candidate
and shows every field at once: the two titles with Rename, the eight
objectives as toggle buttons with the completion rule of the last one
changed, steppers for recruits, recruit rank and the aggression range that
repeat while held and are disabled at their limits, and toggles for grenades,
rockets, enemy grenades, the overview map and the final-map countdown. Done
(also Return) and Cancel (also Escape) close it. Rename opens the shared
title entry, which checks both native display-width limits. Objective order
is retained; removing the last objective is refused with a message.

Done records intent before the dialog closes. MENU then inspects the
`Custom` directory, verifies the `CFEDITOR` identity, restores the private
snapshots after inspection and calls COMMIT. COMMIT rejects changed owners or metadata, publishes only the
editable fields, marks actual changes dirty and consumes its authority once.
Cancel invalidates private state. MAP, SPT and undo history remain untouched.

Private title, metadata and owner copies occupy serializer WORK384 through
WORK1215, outside the dialog's scratch. During post-modal inspection MENU
temporarily preserves WORK448 through WORK1215 in READBACK, which no dialog
uses. The inspector does
not write READBACK, and restoration occurs on both success and failure.
