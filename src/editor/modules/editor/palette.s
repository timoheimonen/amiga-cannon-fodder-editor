; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Terrain-palette font projection with deterministic contrast selection.
; Select a nonzero terrain color contrasting with background index0, then
; recolor only the two owned font strips. Preserve exact OR opacity and the
; original game font source. D0=0/-1; preserves D1-D7/A0-A6/SP.
        xdef terrain_font_palette,terrain_font_palette_end
terrain_font_palette:
        movem.l d1-d7/a0-a6,-(sp)
        bsr contrast_ink
        bne.s .ink
        moveq #-1,d0
        bra.s .return
.ink:
        move.w d0,terrain_font_ink
        lsr.b #1,d0
        scs d2
        ext.w d2
        lsr.b #1,d0
        scs d3
        ext.w d3
        lsr.b #1,d0
        scs d4
        ext.w d4
        lsr.b #1,d0
        scs d5
        ext.w d5
        lea BAR_BITMAP+BAR_FONT_STRIP,a0
        move.w #1040/2-1,d7
.word:
        move.w (a0),d1
        or.w BAR_PLANE(a0),d1
        or.w BAR_PLANE*2(a0),d1
        or.w BAR_PLANE*3(a0),d1
        move.w d1,d6
        and.w d2,d6
        move.w d6,(a0)
        move.w d1,d6
        and.w d3,d6
        move.w d6,BAR_PLANE(a0)
        move.w d1,d6
        and.w d4,d6
        move.w d6,BAR_PLANE*2(a0)
        and.w d5,d1
        move.w d1,BAR_PLANE*3(a0)
        addq.l #2,a0
        dbra d7,.word
        moveq #0,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

terrain_font_palette_end:
