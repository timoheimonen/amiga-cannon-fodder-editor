; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; A0: at most 63 bytes followed by NUL/FF. Return exact length in D0, or 64.
browser_text_length:
        moveq   #0,d0
.next:
        tst.b   (a0,d0.w)
        beq.s   .done
        cmpi.b  #$FF,(a0,d0.w)
        beq.s   .done
        addq.w  #1,d0
        cmpi.w  #64,d0
        blo.s   .next
.done:
        rts

; A0/D0.l title of 1..63 bytes -> A1 output64, D2.w available width: the
; hill-font projection of text_preflight with explicit upper case. Returns
; its results; preserves D3-D7/A0-A6.
browser_text_project:
        move.l  d3,-(sp)
        moveq   #0,d1
        moveq   #1,d3
        bsr.s   text_preflight
        move.l  (sp)+,d3
        rts
