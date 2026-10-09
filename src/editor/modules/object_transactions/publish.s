; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Publish one private object edit after proving its exact inverse.
; A0=canonical SPT430, A1=candidate430, A2=object inverse group64,
; A3=CFMD256, A4=AUR128, A5=history4096, D0.w=new SPT bytes,
; D1.w=inverse bytes, D7.l=cell count. Owned, aligned, disjoint spans.
; The caller has qualified metadata/AUR ownership and closed any terrain stroke.
; D0=1 changed,0 exact no-op,-1 refused; all other registers except CCR preserved.
; Refusal leaves canonical SPT, metadata, AUR and history untouched.
; Dirty payload CRCs retain their existing meaning and are refreshed by Save.
        section .text,code
        xdef op_publish,op_publish_end
op_publish:
        movem.l d1-d7/a0-a6,-(sp)
        lea -448(sp),sp
        movea.l sp,a6
        move.w d0,(a6)
        move.w d1,2(a6)
        move.w 38(a3),4(a6)
        move.l a0,8(a6)
        move.l a1,12(a6)
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
        move.w 4(a6),d2
        cmpi.w #10,d2
        blo .invalid
        cmpi.w #430,d2
        bhi .invalid
        ; Reverse into private memory, never the canonical destination.
        movea.l a1,a0
        lea 16(a6),a1
        bsr ot_reverse
        cmp.w 4(a6),d0
        bne .invalid
        tst.l d0
        bmi .invalid
        movea.l 8(a6),a0
        lea 16(a6),a1
        move.w d0,d2
        lsr.w #1,d2
        subq.w #1,d2
.compare_inverse:
        cmpm.w (a0)+,(a1)+
        bne.s .invalid
        dbra d2,.compare_inverse
        move.w (a6),d0
        cmp.w 4(a6),d0
        bne.s .changed
        movea.l 8(a6),a0
        movea.l 12(a6),a1
        move.w d0,d2
        lsr.w #1,d2
        subq.w #1,d2
.compare_candidate:
        cmpm.w (a0)+,(a1)+
        bne.s .changed
        dbra d2,.compare_candidate
        moveq #0,d0
        bra.s .return
.changed:
        ; All fallible work ends at append. IRQs do not consume authored history.
        movea.l a5,a0
        lea 100(a4),a1
        moveq #0,d0
        move.w 2(a6),d0
        bsr oh_append
        tst.l d0
        bmi.s .invalid
        movea.l 8(a6),a0
        movea.l 12(a6),a1
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
.invalid:
        moveq #-1,d0
.return:
        lea 448(sp),sp
        movem.l (sp)+,d1-d7/a0-a6
        rts
op_publish_end:
