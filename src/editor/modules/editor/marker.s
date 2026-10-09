; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        xdef marker_prepare

; Read-only marker edit preparation. A0=MAP grid, D7.l=cell count (1..7500),
; D1.w=cell index, D0.w=0 clear or 1 cycle. The caller owns an aligned grid.
; D0=0 unchanged, 1 replacement ready, 2 marker capacity, -1 invalid bounds.
; D2.w=complete replacement on 0/1; all other registers are preserved.
; Tile/reserved bits survive. Imported classes5..7 cycle to0; new classes
; are limited to1..4. Every nonzero class counts toward the ten-cell limit.
; No mutation occurs here: the caller commits through the shared undo log.
marker_prepare:
        movem.l d3-d5/a1,-(sp)
        cmpi.w #1,d0
        bhi.s .invalid
        tst.l d7
        beq.s .invalid
        cmpi.l #7500,d7
        bhi.s .invalid
        cmp.w d7,d1
        bhs.s .invalid
        move.w d1,d3
        add.w d3,d3
        move.w 0(a0,d3.w),d2
        move.w d2,d5
        andi.w #$1FFF,d2
        tst.w d0
        beq.s .compare
        move.w d5,d3
        lsr.w #8,d3
        lsr.w #5,d3
        bne.s .cycle
        movea.l a0,a1
        move.w d7,d3
        subq.w #1,d3
        moveq #0,d4
.count:
        move.w (a1)+,d0
        andi.w #$E000,d0
        beq.s .next
        addq.w #1,d4
        cmpi.w #10,d4
        bhs.s .full
.next:
        dbra d3,.count
        moveq #0,d3
.cycle:
        addq.w #1,d3
        cmpi.w #4,d3
        bhi.s .compare
        lsl.w #8,d3
        lsl.w #5,d3
        or.w d3,d2
.compare:
        moveq #0,d0
        cmp.w d5,d2
        beq.s .return
        moveq #1,d0
        bra.s .return
.full:
        moveq #2,d0
        bra.s .return
.invalid:
        moveq #-1,d0
.return:
        movem.l (sp)+,d3-d5/a1
        tst.w d0
        rts
