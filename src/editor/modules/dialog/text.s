; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Text helpers for dialogs. dialog_field needs a 32-byte EXIT_LIST in the
; including module's scratch.

; A1 source, A0 destination; copies at most 63 characters and the NUL and
; leaves A0 on the NUL, ready to append.
dialog_copy:
        moveq #62,d0
.copy:
        move.b (a1)+,(a0)+
        dbeq d0,.copy
        beq.s .end
        clr.b (a0)
        rts
.end:
        subq.l #1,a0
        rts

; D0.w unsigned value written in decimal at A0, which ends on the NUL.
dialog_number:
        movem.l d0-d1,-(sp)
        andi.l #$ffff,d0
        moveq #0,d1
.divide:
        divu #10,d0
        swap d0
        addi.w #'0',d0
        move.w d0,-(sp)
        addq.w #1,d1
        clr.w d0
        swap d0
        tst.w d0
        bne.s .divide
        subq.w #1,d1
.emit:
        move.w (sp)+,d0
        move.b d0,(a0)+
        dbra d1,.emit
        clr.b (a0)
        movem.l (sp)+,d0-d1
        rts

; Redraw one text field of the open dialog: A1 string, D1 X, D2 Y, D3 width,
; D4 colour role, D5 alignment. Clears the eight rows first. Uses EXIT_LIST.
dialog_field:
        movem.l d0/a0,-(sp)
        lea EXIT_LIST,a0
        move.w #UI_RECT,(a0)+
        move.w d1,(a0)+
        move.w d2,(a0)+
        move.w d3,(a0)+
        move.w #UI_LINE_HEIGHT,(a0)+
        move.w #UI_PANEL,(a0)+
        move.w #UI_TEXT_AT,(a0)+
        move.w d1,(a0)+
        move.w d2,(a0)+
        move.w d3,(a0)+
        move.w d4,(a0)+
        move.w d5,(a0)+
        move.l a1,(a0)+
        clr.w (a0)
        lea EXIT_LIST,a0
        bsr dialog_draw
        movem.l (sp)+,d0/a0
        rts

