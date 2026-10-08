; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Contrast of the terrain palette's colours with colour 0, scored 2R+4G+B.

; D0.w = the colour 1..15 that contrasts most with colour 0 (the first one on
; a tie), or 0 when every colour scores like colour 0; CCR from D0.
; Preserves D1-D7/A0-A6.
contrast_ink:
        movem.l d1-d2/d4-d7/a0,-(sp)
        lea editor_base_palette,a0
        move.w (a0)+,d2
        bsr.s palette_luma
        move.w d0,d6
        moveq #0,d4
        moveq #0,d5
        moveq #1,d7
.colour:
        move.w (a0)+,d2
        bsr.s palette_luma
        sub.w d6,d0
        bpl.s .positive
        neg.w d0
.positive:
        cmp.w d4,d0
        bls.s .next
        move.w d0,d4
        move.w d7,d5
.next:
        addq.w #1,d7
        cmpi.w #16,d7
        blo.s .colour
        move.w d5,d0
        movem.l (sp)+,d1-d2/d4-d7/a0
        rts

; RGB4 colour D2 ($0RGB) -> score 2R+4G+B in D0. Clobbers D1/D2.
palette_luma:
        moveq #15,d0
        and.w d2,d0
        move.w d2,d1
        lsr.w #2,d1
        andi.w #$3c,d1
        add.w d1,d0
        lsr.w #7,d2
        andi.w #$1e,d2
        add.w d2,d0
        rts
