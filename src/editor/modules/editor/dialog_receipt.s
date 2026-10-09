; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Release the viewport before requesting a by-value dialog receipt.
exit_ui_blitter_idle:
        btst #6,amiga_dmacon_read
        bne.s exit_ui_blitter_idle
        rts
edtr_request_large:
        swap d0
        move.w d0,-(sp)
        move.w #AUR_PAGE_LARGE,-(sp)
        bra edtr_request_page
; Called only after an entered MENU confirmation and one-time receipt removal.
; D4.w=cell index. Tile and unchanged canonical cell supply the replacement.
edtr_large_commit:
        movem.l d1-d7/a0-a6,-(sp)
        clr.l TERRAIN_OP
        move.w d4,d1
        bsr terrain_context
        cmp.w d7,d1
        bhs.s .invalid
        move.w d1,d0
        add.w d0,d0
        move.w 0(a0,d0.w),d2
        andi.w #$FE00,d2
        or.w AUR_BASE+AUR_TILE+PCREL(pc),d2
        bsr tu_begin
        bmi.s .return
        bsr tu_confirm_large
        bmi.s .return
        bsr tu_change
        bmi.s .return
        bsr.s aur_mark_edit_result
        bsr tu_end
        bra.s .return
.invalid:
        moveq #-1,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
