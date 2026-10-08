; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Private ordered-SPT deletion. No engine calls or canonical publication.
; A0=source; D0.w=source bytes; D1.w=logical root index.
; A1=430-byte candidate; A2=64-byte inverse-record candidate.
; Caller supplies disjoint, aligned, owned ranges. Inputs are read-only.
; D0.l=new byte length, D1.l=inverse count on success;
; D0=-1 malformed/not a root, -2 last logical item; D1=0 on refusal.
; D2-D7/A0-A6 preserved. Both outputs remain untouched on refusal.
        section .text,code
        xdef ot_delete,ot_delete_end
ot_delete:
        movem.l d2-d7/a0-a6,-(sp)
        moveq #0,d7
        move.w d0,d7
        moveq #0,d6
        move.w d1,d6
        cmpi.w #10,d7
        blo .invalid
        cmpi.w #430,d7
        bhi .invalid
        move.l d7,d0
        divu.w #10,d0
        move.w d0,d5
        swap d0
        tst.w d0
        bne .invalid
        cmp.w d5,d6
        bhs .invalid
        moveq #0,d2
        moveq #0,d3
        movea.l a0,a4
.scan:
        moveq #0,d0
        move.w 8(a4),d0
        cmpi.w #$6e,d0
        bhi .invalid
        lsl.w #2,d0
        lea ot_shared_recipes(pc),a5
        adda.w d0,a5
        moveq #0,d4
        move.b (a5)+,d4
        andi.w #3,d4
        move.w d3,d0
        addq.w #1,d0
        add.w d4,d0
        cmp.w d5,d0
        bhi .invalid
        cmp.w d6,d3
        bne.s .next_root
        move.w d4,d2
        addq.w #1,d2
.next_root:
        addq.w #1,d3
        adda.w #10,a4
        tst.w d4
        beq.s .root_done
.suffix:
        moveq #0,d0
        move.b (a5)+,d0
        cmp.w 8(a4),d0
        bne.s .invalid
        addq.w #1,d3
        adda.w #10,a4
        subq.w #1,d4
        bne.s .suffix
.root_done:
        cmp.w d5,d3
        blo.s .scan
        tst.w d2
        beq.s .invalid
        cmp.w d5,d2
        beq.s .last

        ; Validate all records before writing either private candidate.
        move.w d6,d3
        mulu.w #10,d3
        movea.l a0,a3
        move.w d3,d4
        lsr.w #1,d4
        beq.s .prefix_done
        subq.w #1,d4
.prefix:
        move.w (a3)+,(a1)+
        dbra d4,.prefix
.prefix_done:
        move.w d2,d4
        subq.w #1,d4
        move.w #$8003,d0
.inverse:
        move.w d0,(a2)+
        move.w d6,(a2)+
        move.l (a3)+,(a2)+
        move.l (a3)+,(a2)+
        move.w (a3)+,(a2)+
        clr.w (a2)+
        moveq #3,d0
        dbra d4,.inverse
        move.w d2,d4
        mulu.w #10,d4
        move.l d7,d0
        sub.l d4,d0
        sub.l d3,d7
        sub.l d4,d7
        lsr.w #1,d7
        beq.s .success
        subq.w #1,d7
.tail:
        move.w (a3)+,(a1)+
        dbra d7,.tail
.success:
        moveq #0,d1
        move.w d2,d1
        bra.s .return
.last:
        moveq #-2,d0
        bra.s .refused
.invalid:
        moveq #-1,d0
.refused:
        moveq #0,d1
.return:
        movem.l (sp)+,d2-d7/a0-a6
        rts

ot_delete_end:
