; Cannon Fodder In-Game Level Editor V1.2.5
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Clipboard service (backend operation 13, see ui.i). The Slave keeps one
; record of at most CLIPBOARD_BYTES bytes for the editor modules, from a put
; until the next put or until the game is quit: it outlives every module
; load, a Save and a change of mission. The Slave does not read the record;
; the module that gets it checks it.
; D1.w = CLIPBOARD_PUT: A0 = the record, D2.w = its length, even and at most
; CLIPBOARD_BYTES. D0 = 0 kept, 10 refused.
; D1.w = CLIPBOARD_GET: A0 = a target of CLIPBOARD_BYTES bytes. D0.w = the
; length of the record copied there, 0 when none is kept.
; A0 is even. Other registers are preserved.
clipboard_service:
        movem.l d2/a0-a1,-(sp)
        lea clipboard_length(pc),a1
        cmpi.w #CLIPBOARD_GET,d1
        beq.s .get
        moveq #10,d0
        tst.w d1
        bne.s .return
        btst #0,d2
        bne.s .return
        tst.w d2
        beq.s .return
        cmpi.w #CLIPBOARD_BYTES,d2
        bhi.s .return
        move.w d2,(a1)+
        lsr.w #1,d2
        subq.w #1,d2
.put:
        move.w (a0)+,(a1)+
        dbra d2,.put
        moveq #0,d0
        bra.s .return
.get:
        moveq #0,d0
        move.w (a1)+,d0
        move.w d0,d2
        lsr.w #1,d2
        beq.s .return
        subq.w #1,d2
.copy:
        move.w (a1)+,(a0)+
        dbra d2,.copy
.return:
        movem.l (sp)+,d2/a0-a1
        tst.w d0
        rts

clipboard_length:   dc.w 0
clipboard_record:   ds.b CLIPBOARD_BYTES
        even
