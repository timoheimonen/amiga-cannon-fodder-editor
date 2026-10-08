; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Cancellable four-neighbor flood discovery without MAP mutation.
; A0=MAP words, A1=word queue, A2=visited bits, A3=16-byte result.
; D1.w=width, D2.w=height, D3.w=seed, D7.l=cell count.
; A4=owned latched cancel word, A5=trusted raw-key byte.
; A4 must be nonzero/even, A5 nonzero; all pointers are disjoint owned inputs.
; The raw source is native_raw_key+1 ($814E5); the caller also latches translated Escape.
; D0=0 complete,14 cancelled,-1 invalid. All other registers/SP preserved.
; Invalid and entry-cancelled calls leave output scratch unchanged. Later
; cancellation invalidates ALL scratch authority, even a complete final queue.
; MAP/undo are never written. The helper never clears an existing cancel latch.
        section .text,code
        xdef fc_discover,fc_start,fc_finish,fc_visit,fc_poll
fc_start:
fc_discover:
        movem.l d1-d7/a0-a6,-(sp)
        moveq #-1,d0
        tst.l d7
        beq .return
        cmpi.l #7500,d7
        bhi .return
        moveq #0,d4
        move.w d1,d4
        beq .return
        tst.w d2
        beq .return
        mulu d2,d4
        cmp.l d7,d4
        bne .return
        cmp.w d7,d3
        bhs .return
        move.l a4,d4
        beq .return
        btst #0,d4
        bne .return
        move.l a5,d4
        beq .return
        movea.l a4,a6
.poll_entry:
        bsr fc_poll
        bne .cancel
        move.w d1,(a3)
        move.w d2,2(a3)
        move.w d7,4(a3)
        clr.l 8(a3)
        clr.l 12(a3)
        move.w d1,d6
        moveq #0,d5
        move.w d3,d5
        add.w d5,d5
        move.w 0(a0,d5.w),d5
        andi.w #$1FF,d5
        move.w d5,6(a3)
        move.w d7,d0
        addq.w #7,d0
        lsr.w #3,d0
        subq.w #1,d0
        movea.l a2,a4
.clear:
        bsr fc_poll
        bne.s .cancel
        clr.b (a4)+
        dbra d0,.clear
        move.w d3,d0
        bsr.s fc_visit
        moveq #0,d4
.next:
        bsr fc_poll
        bne.s .cancel
        cmp.w 8(a3),d4
        beq.s .done
        move.w d4,d0
        add.w d0,d0
        move.w 0(a1,d0.w),d3
        moveq #0,d2
        move.w d3,d2
        divu d6,d2
        swap d2
        tst.w d2
        beq.s .right
        move.w d3,d0
        subq.w #1,d0
        bsr.s fc_visit
.right:
        addq.w #1,d2
        cmp.w d6,d2
        beq.s .above
        move.w d3,d0
        addq.w #1,d0
        bsr.s fc_visit
.above:
        cmp.w d6,d3
        blo.s .below
        move.w d3,d0
        sub.w d6,d0
        bsr.s fc_visit
.below:
        move.w d3,d0
        add.w d6,d0
        cmp.w d7,d0
        bhs.s .processed
        bsr.s fc_visit
.processed:
        addq.w #1,d4
        move.w d4,10(a3)
        bra.s .next
.done:
        bsr.s fc_poll
        bne.s .cancel
        moveq #0,d0
        bra.s .return
.cancel:
        moveq #14,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.l d0
        rts

; Unchanged neighbor visitation: mark tested cells before queueing matches.
fc_visit:
        move.w d0,d1
        lsr.w #3,d1
        btst d0,0(a2,d1.w)
        bne.s .return
        bset d0,0(a2,d1.w)
        move.w d0,d1
        add.w d1,d1
        move.w 0(a0,d1.w),d1
        andi.w #$1FF,d1
        cmp.w d5,d1
        bne.s .return
        move.w 8(a3),d1
        add.w d1,d1
        move.w d0,0(a1,d1.w)
        addq.w #1,8(a3)
.return:
        rts

; No D/A register changes. An already latched cancellation remains exact.
; Z=1 continue, Z=0 cancel. Raw reads are byte-sized; the caller supplies the
; verified native raw-key byte and owns the latch through both discoveries.
fc_poll:
        tst.w (a6)
        bne.s .return
        cmpi.b #$45,(a5)
        bne.s .done
        move.w #1,(a6)
.done:
        tst.w (a6)
.return:
        rts
fc_finish:
