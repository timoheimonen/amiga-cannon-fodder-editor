; Cannon Fodder In-Game Level Editor V1.2.5
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
; D4.w=cell index. Tile and unchanged canonical cell supply the replacement:
; one cell of a long stroke, or the cells of a rectangle that asked first.
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
        cmpi.w #AREA_TAG,AREA_PENDING
        beq.s .area
        bsr tu_change
        bmi.s .return
.result:
        bsr aur_mark_edit_result
        bsr tu_end
        bra.s .return
; A rectangle that asked first: D1.w is its top left cell, and its size
; must lie inside the map.
.area:
        clr.w AREA_PENDING
        moveq #0,d0
        move.w d1,d0
        divu editor_map_width,d0
        move.w AREA_WIDTH,d2
        beq.s .invalid
        move.w AREA_HEIGHT,d3
        beq.s .invalid
        move.w d0,d4
        add.w d3,d4
        cmp.w editor_map_height,d4
        bhi.s .invalid
        swap d0
        add.w d2,d0
        cmp.w editor_map_width,d0
        bhi.s .invalid
        bsr block_fill
        bmi.s .return
        bra.s .result
.invalid:
        moveq #-1,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
