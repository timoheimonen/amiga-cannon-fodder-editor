; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Qualified authored commits invalidate only the selected logical phase.
; The original DIRTY OR remains last, including its CCR. Preserve all registers.
        ifd TESTED_RESULT_ENTRY
aur_mark_edit_result:
        cmpi.w #1,d0
        bne.s aur_mark_dirty
        endif
aur_mark_edited:
        move.w d0,-(sp)
        move.b AUR_BASE+AUR_SELECTED+PCREL(pc),d0
        bclr d0,E7_TESTED
        move.w (sp)+,d0
aur_mark_dirty:
        ori.w #AUR_DIRTY,AUR_BASE+AUR_FLAGS
        rts
