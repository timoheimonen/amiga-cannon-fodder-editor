; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Shared image of private edits, canonical publication and object Undo.
; Each entry retains its source contract; no module ownership is acquired here.
        include "delete.s"
        include "move.s"
        include "insert.s"
        include "publish.s"
        include "object_undo.s"
        include "reverse.s"
        include "history.s"
; Companion recipes by object type: suffix count (bit 7: a primary slot)
; followed by up to three exact type IDs.
ot_shared_recipes:
        include "insert_companions.i"
ot_pipeline_end:
