; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Reverse and publish the newest object group in closed mixed history.
; A0=canonical SPT430, A3=qualified CFMD256, A4=qualified AUR128,
; A5=history4096, D7.l=MAP cell count. Owned aligned disjoint spans.
; Caller qualifies full owner/overlay state and closes active terrain strokes.
; D0=1 object undone,0 empty,2 terrain group pending,-1 refusal.
; All other registers except CCR preserved. Refusals leave authored state/log.
; Uses private stack candidate/group storage. Save refreshes dirty payload CRCs.
        section .text,code
        xdef op_undo,op_undo_end
op_undo:
        movem.l d1-d7/a0-a6,-(sp)
        lea -512(sp),sp
        movea.l sp,a6
        move.l a0,8(a6)
        cmpi.l #$43464d44,(a3)
        bne .invalid
        cmpi.w #1,4(a3)
        bne .invalid
        cmpi.l #$41555231,(a4)
        bne .invalid
        cmpi.w #1,4(a4)
        bne .invalid
        cmpi.w #15,6(a4)
        bhi .invalid
        btst #2,7(a4)
        bne .invalid
        movea.l a5,a0
        lea 100(a4),a1
        bsr oh_validate
        tst.l d0
        bne .invalid
        tst.w 102(a4)
        beq .return
        move.w 100(a4),d3
        moveq #0,d6
.find_first:
        subq.w #1,d3
        andi.w #255,d3
        move.w d3,d4
        lsl.w #4,d4
        lea 0(a5,d4.w),a1
        tst.w d6
        bne.s .count
        move.w (a1),d0
        andi.w #$7fff,d0
        subq.w #1,d0
        beq .terrain
.count:
        addq.w #1,d6
        tst.w (a1)
        bpl.s .find_first
        move.w d6,d1
        lsl.w #4,d1
        move.w d1,2(a6)
        lea 16(a6),a2
        subq.w #1,d6
.copy_group:
        move.w d3,d4
        lsl.w #4,d4
        lea 0(a5,d4.w),a1
        move.l (a1)+,(a2)+
        move.l (a1)+,(a2)+
        move.l (a1)+,(a2)+
        move.l (a1)+,(a2)+
        addq.w #1,d3
        andi.w #255,d3
        dbra d6,.copy_group
        movea.l 8(a6),a0
        lea 80(a6),a1
        lea 16(a6),a2
        moveq #0,d0
        move.w 38(a3),d0
        bsr.s ot_reverse
        tst.l d0
        bmi.s .invalid
        move.w d0,(a6)
        ; No input changed since validation. Drop is the last fallible step.
        movea.l a5,a0
        lea 100(a4),a1
        bsr oh_drop
        tst.l d0
        bmi.s .invalid
        movea.l 8(a6),a0
        lea 80(a6),a1
        move.w (a6),d2
        move.w #430,d3
        sub.w d2,d3
        lsr.w #1,d3
        lsr.w #1,d2
        subq.w #1,d2
        move.w sr,-(sp)
        ori.w #$0700,sr
.copy:
        move.w (a1)+,(a0)+
        dbra d2,.copy
        tst.w d3
        beq.s .metadata
        subq.w #1,d3
.clear_tail:
        clr.w (a0)+
        dbra d3,.clear_tail
.metadata:
        move.w (a6),38(a3)
        ori.w #2,6(a4)
        move.w #-1,98(a4)
        move.w (sp)+,sr
        moveq #1,d0
        bra.s .return
.terrain:
        moveq #2,d0
        bra.s .return
.invalid:
        moveq #-1,d0
.return:
        lea 512(sp),sp
        movem.l (sp)+,d1-d7/a0-a6
        rts
op_undo_end:
