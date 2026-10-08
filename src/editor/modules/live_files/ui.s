; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Project a title by value before parser scratch becomes modal backing storage.
browser_files_ui_prepare:
        tst.w d0
        beq.s .generation
        moveq #0,d0
.length:
        cmpi.b #$FF,0(a0,d0.w)
        beq.s .project
        addq.w #1,d0
        cmpi.w #63,d0
        blo.s .length
.project:
        lea LF_TITLE,a1
        moveq #0,d1
        move.w #TITLE_HILL_WIDTH,d2
        moveq #1,d3
        bsr text_preflight
        tst.w d0
        bne.s .generation
        lea LF_TITLE,a0
.end:
        cmpi.b #$FF,(a0)+
        bne.s .end
        clr.b -1(a0)
        moveq #0,d0
        rts
.generation:
        lea BF_NAME,a0
        lea LF_TITLE,a1
        moveq #7,d1
.hex:
        move.b (a0)+,d0
        andi.b #$DF,d0
        cmpi.b #'A',d0
        bhs.s .copy
        ori.b #$20,d0
.copy:
        move.b d0,(a1)+
        dbf d1,.hex
        clr.b (a1)
        moveq #0,d0
        rts

; D0=0..150, A1=output. Callers preserve no arithmetic temporaries.
files_decimal:
        moveq #100,d2
        divu d2,d0
        move.w d0,d2
        beq.s .tens
        addi.b #'0',d2
        move.b d2,(a1)+
.tens:
        swap d0
        andi.l #$FFFF,d0
        divu #10,d0
        tst.w d2
        bne.s .ten
        tst.w d0
        beq.s .unit
.ten:
        addi.b #'0',d0
        move.b d0,(a1)+
.unit:
        swap d0
        addi.b #'0',d0
        move.b d0,(a1)+
        rts
