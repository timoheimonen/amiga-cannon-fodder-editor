; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Type$18 spawns from an invisible anchor. Show an editor-only H at its position.
; Reuse the owned, recolored H glyph cache; no additional Chip allocation.
; The selected static catalog emits at most four eight-byte parts; bytes48..63
; retain this descriptor until the complete object view is released.
object_anchor_prepare:
        movem.l d0/a0-a1,-(sp)
        lea font_frames+7*16,a0
        lea OBJECT_ANCHOR_DESC,a1
        moveq #3,d0
.copy:
        move.l (a0)+,(a1)+
        dbra d0,.copy
        clr.l OBJECT_ANCHOR_DESC+DESC_MASK
        move.w #$F806,OBJECT_ANCHOR_DESC+DESC_ANCHOR_X
        movem.l (sp)+,d0/a0-a1
        rts
        ifgt OBJECT_ANCHOR_DESC+16-edtr_state
        fail "Object anchor descriptor exceeds part scratch"
        endif
