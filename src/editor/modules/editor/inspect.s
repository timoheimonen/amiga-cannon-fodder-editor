; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Read-only attributes of the cell under the cursor for the information
; line: its tile, the complete hexadecimal HIT and SWP words and the two BHT
; classes. The BHT mask is drawn beside the line by inspect_mask.
; A0 output; returns A0 on the terminator. Clobbers D0-D2/A1.
terrain_inspect_compose:
        movem.l d3-d4,-(sp)
        lea inspect_tile_text(pc),a1
        bsr bar_append
        bsr terrain_marker_word
        andi.w #$1FF,d0
        move.w d0,d3
        moveq #2,d1
        bsr bar_digits
        cmpi.w #400,d3
        bhs.s .invalid
        add.w d3,d3
        lea inspect_hit_text(pc),a1
        bsr bar_append
        lea editor_hit_table,a1
        move.w 0(a1,d3.w),d0
        move.w d0,d4
        moveq #3,d1
        bsr.s inspect_hex
        lea inspect_swp_text(pc),a1
        bsr bar_append
        lea editor_swp_table,a1
        move.w 0(a1,d3.w),d0
        moveq #3,d1
        bsr.s inspect_hex
        lea inspect_class_text(pc),a1
        bsr bar_append
        move.w d4,d0
        ror.w #4,d0
        moveq #0,d1
        bsr.s inspect_hex
        move.b #'/',(a0)+
        move.w d4,d0
        lsl.w #8,d0
        moveq #0,d1
        bsr.s inspect_hex
        clr.b (a0)
        bra.s .return
.invalid:
        lea inspect_bad_text(pc),a1
        bsr bar_append
.return:
        movem.l (sp)+,d3-d4
        rts

; D0 holds left-aligned hex digits; D1+1 digits are written to A0.
; Clobbers D0-D2.
inspect_hex:
        rol.w #4,d0
        move.w d0,d2
        andi.w #15,d2
        addi.b #'0',d2
        cmpi.b #'9',d2
        bls.s .digit
        addq.b #7,d2
.digit:
        move.b d2,(a0)+
        dbra d1,inspect_hex
        rts

; D7=validated tile0..399. Expand eight mask bytes into a 16x16 bar image.
inspect_mask:
        lsl.w #3,d7
        lea editor_bht_table,a0
        adda.w d7,a0
        lea BAR_BITMAP+BAR_UI_ROWS*UI_ROW_BYTES+36,a1
        moveq #7,d7
.row:
        move.b (a0)+,d0
        moveq #0,d1
        moveq #7,d2
.bit:
        lsl.w #2,d1
        add.b d0,d0
        bcc.s .zero
        ori.w #3,d1
.zero:
        dbra d2,.bit
        move.w terrain_font_ink+PCREL(pc),d0
        movea.l a1,a2
        moveq #3,d2
.plane:
        lsr.w #1,d0
        bcc.s .blank
        or.w d1,(a2)
        or.w d1,40(a2)
.blank:
        adda.w #BAR_PLANE,a2
        dbra d2,.plane
        adda.w #80,a1
        dbra d7,.row
        rts

inspect_tile_text: dc.b "Tile ",0
inspect_hit_text: dc.b " HIT ",0
inspect_swp_text: dc.b " SWP ",0
inspect_class_text: dc.b " Class ",0
inspect_bad_text: dc.b " no attributes",0
        even
