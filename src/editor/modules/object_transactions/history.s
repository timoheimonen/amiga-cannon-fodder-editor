; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Closed mixed history: A0=4096-byte ring, A1=next/count words,
; D7.l=MAP cell count 1..7500. All buffers are owned, aligned and disjoint.
; No active terrain operation may exist. No authored state is changed here.
; All public routines preserve D1-D7/A0-A6; D0 is result, CCR is volatile.
; validate: D0=0 valid/-1 invalid.
; append: A2=one complete group, D0.w=bytes 16..4096; returns bytes/-1.
; peek: A2=4096-byte output; returns newest group's bytes, 0 empty/-1 invalid.
; drop: removes newest group after caller publication; returns bytes/0/-1.
; Refusals leave every output untouched. Append evicts only complete old groups.
        section .text,code
        xdef oh_end
        ifnd OH_VALIDATE_ONLY
        xdef oh_validate,oh_append,oh_peek,oh_drop
oh_validate:
        movem.l d1-d7/a0-a6,-(sp)
        bsr oh_ring
        movem.l (sp)+,d1-d7/a0-a6
        rts

oh_append:
        movem.l d1-d7/a0-a6,-(sp)
        move.l d0,-(sp)
        bsr oh_ring
        tst.l d0
        bne .return
        moveq #0,d3
        move.w 2(sp),d3
        cmpi.w #16,d3
        blo .invalid
        cmpi.w #4096,d3
        bhi.s .invalid
        move.w d3,d0
        andi.w #15,d0
        bne.s .invalid
        lsr.w #4,d3
        moveq #0,d4
        movea.l a2,a4
        bsr oh_scan
        tst.l d0
        bne.s .return
        move.w 2(sp),d1
        lsr.w #4,d1
        cmp.w d1,d5
        bne.s .invalid
.space:
        move.w 2(a1),d2
        add.w d1,d2
        cmpi.w #256,d2
        bls.s .copy
        move.w (a1),d3
        sub.w 2(a1),d3
.drop_oldest:
        subq.w #1,2(a1)
        addq.w #1,d3
        andi.w #255,d3
        tst.w 2(a1)
        beq.s .space
        move.w d3,d4
        lsl.w #4,d4
        tst.w 0(a0,d4.w)
        bpl.s .drop_oldest
        bra.s .space
.copy:
        movea.l a2,a3
        move.w (a1),d3
        move.w d1,d2
        subq.w #1,d2
.record:
        move.w d3,d4
        lsl.w #4,d4
        lea 0(a0,d4.w),a4
        move.l (a3)+,(a4)+
        move.l (a3)+,(a4)+
        move.l (a3)+,(a4)+
        move.l (a3)+,(a4)+
        addq.w #1,d3
        andi.w #255,d3
        dbra d2,.record
        move.w d3,(a1)
        add.w d1,2(a1)
        moveq #0,d0
        move.w 2(sp),d0
        bra.s .return
.invalid:
        moveq #-1,d0
.return:
        addq.l #4,sp
        movem.l (sp)+,d1-d7/a0-a6
        rts

oh_peek:
        movem.l d1-d7/a0-a6,-(sp)
        bsr.s oh_ring
        tst.l d0
        bne.s .return
        tst.w d5
        beq.s .return
        move.w (a1),d3
        sub.w d5,d3
        andi.w #255,d3
        move.w d5,d2
        subq.w #1,d2
        movea.l a2,a5
.record:
        move.w d3,d4
        lsl.w #4,d4
        lea 0(a0,d4.w),a3
        move.l (a3)+,(a5)+
        move.l (a3)+,(a5)+
        move.l (a3)+,(a5)+
        move.l (a3)+,(a5)+
        addq.w #1,d3
        andi.w #255,d3
        dbra d2,.record
        moveq #0,d0
        move.w d5,d0
        lsl.w #4,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        rts

oh_drop:
        movem.l d1-d7/a0-a6,-(sp)
        bsr.s oh_ring
        tst.l d0
        bne.s .return
        tst.w d5
        beq.s .return
        sub.w d5,(a1)
        andi.w #255,(a1)
        sub.w d5,2(a1)
        moveq #0,d0
        move.w d5,d0
        lsl.w #4,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        rts

        endif

; Read-only ring bounds and canonical records. D5=newest group record count.
oh_ring:
        moveq #-1,d0
        moveq #0,d5
        tst.l d7
        beq.s .return
        cmpi.l #7500,d7
        bhi.s .return
        cmpi.w #255,(a1)
        bhi.s .return
        cmpi.w #256,2(a1)
        bhi.s .return
        move.w 2(a1),d3
        beq.s .empty
        move.w (a1),d4
        sub.w d3,d4
        andi.w #255,d4
        movea.l a0,a4
        bra.s oh_scan
.empty:
        moveq #0,d0
.return:
        rts

; A4=record array, D4=first ring slot, D3=count. D5=last group count.
; Every group contains only terrain or only object records. Object groups <=4.
oh_scan:
        moveq #-1,d0
        move.w d4,d2
        lsl.w #4,d2
        tst.w 0(a4,d2.w)
        bpl .return
        moveq #0,d5
        moveq #0,d6
.record:
        move.w d4,d2
        lsl.w #4,d2
        lea 0(a4,d2.w),a3
        move.w (a3),d1
        bpl.s .same_group
        moveq #0,d5
        moveq #0,d6
.same_group:
        andi.w #$7fff,d1
        cmpi.w #1,d1
        beq.s .terrain
        cmpi.w #2,d1
        blo.s .return
        cmpi.w #4,d1
        bhi.s .return
        cmpi.w #1,d6
        beq.s .return
        moveq #2,d6
        cmpi.w #4,d5
        bhs.s .return
        cmpi.w #43,2(a3)
        bhs.s .return
        tst.w 14(a3)
        bne.s .return
        cmpi.w #2,d1
        beq.s .insertion
        cmpi.w #$6e,12(a3)
        bhi.s .return
        bra.s .next
.insertion:
        tst.l 4(a3)
        bne.s .return
        bra.s .zero_tail
.terrain:
        cmpi.w #2,d6
        beq.s .return
        moveq #1,d6
        move.w 2(a3),d2
        cmp.w d7,d2
        bhs.s .return
.zero_tail:
        tst.l 8(a3)
        bne.s .return
        tst.l 12(a3)
        bne.s .return
.next:
        addq.w #1,d5
        addq.w #1,d4
        andi.w #255,d4
        subq.w #1,d3
        bne .record
        moveq #0,d0
.return:
        rts
oh_end:
