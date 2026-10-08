; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Grouped terrain undo with bounded records and atomic operation admission.
; A0=cell words, A1=4096-byte log, A2=next/count words, A3=flags/count words.
; D7.l=cell count 1..7500. Caller supplies disjoint owned aligned allocations.
; All public routines preserve D1-D7/A0-A6. D0=0 no change,1 changed,
; 2 confirmation required,-1 invalid. No engine calls, allocations or pointers
; are stored in the log. An active operation must close before overlay eviction.
        section .text,code
        xdef tu_begin,tu_change,tu_end,tu_confirm_large,tu_undo
        xdef tu_start,tu_finish
TU_BEGIN        equ $8000
TU_CELL         equ 1
TU_OPEN         equ 1
TU_UNLOGGED     equ 3
tu_start:

tu_begin:
        movem.l d1-d7/a0-a6,-(sp)
        bsr tu_validate
        bne.s .return
        tst.w (a3)
        bne.s .invalid
        move.w #TU_OPEN,(a3)
        clr.w 2(a3)
        bra.s .return
.invalid:
        moveq #-1,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.l d0
        rts

; D1.w=cell index; D2.w=complete replacement word. Paint's caller composes
; (old & $FE00) | checked_tile, retaining markers and uninterpreted bits.
tu_change:
        movem.l d1-d7/a0-a6,-(sp)
        bsr tu_validate
        bne .return
        cmp.w d7,d1
        bhs .invalid
        tst.w (a3)
        beq .invalid
        move.w d1,d4
        add.w d4,d4
        move.w 0(a0,d4.w),d3
        cmp.w d2,d3
        beq.s .return
        cmpi.w #TU_UNLOGGED,(a3)
        beq.s .write_cell
        cmpi.w #256,2(a3)
        bne.s .space
        moveq #2,d0
        bra.s .return
.space:
        cmpi.w #256,2(a2)
        bne.s .append
        ; The oldest group is discarded whole. Validation already checked
        ; all records, and a 256-cell active group was refused above.
        move.w (a2),d5
        moveq #0,d6
.drop:
        addq.w #1,d6
        addq.w #1,d5
        andi.w #255,d5
        cmp.w 2(a2),d6
        beq.s .drop_done
        move.w d5,d0
        lsl.w #4,d0
        tst.w 0(a1,d0.w)
        bpl.s .drop
.drop_done:
        sub.w d6,2(a2)
.append:
        move.w (a2),d0
        lsl.w #4,d0
        lea 0(a1,d0.w),a4
        move.w #TU_CELL,(a4)
        tst.w 2(a3)
        bne.s .record
        ori.w #TU_BEGIN,(a4)
.record:
        move.w d1,2(a4)
        move.w d3,4(a4)
        move.w d2,6(a4)
        clr.l 8(a4)
        clr.l 12(a4)
        addq.w #1,(a2)
        andi.w #255,(a2)
        addq.w #1,2(a2)
        addq.w #1,2(a3)
.write_cell:
        move.w d2,0(a0,d4.w)
        moveq #1,d0
        bra.s .return
.invalid:
        moveq #-1,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.l d0
        rts

tu_end:
        movem.l d1-d7/a0-a6,-(sp)
        bsr tu_validate
        bne.s .return
        tst.w (a3)
        beq.s .invalid
        clr.l (a3)
        bra.s .return
.invalid:
        moveq #-1,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.l d0
        rts

; Call only after explicit confirmation. For a discovered large fill this is
; before the first cell mutation; for a long stroke it permits further cells.
; Declining a stroke extension ends the existing undoable stroke unchanged.
tu_confirm_large:
        movem.l d1-d7/a0-a6,-(sp)
        bsr.s tu_validate
        bne.s .return
        cmpi.w #TU_OPEN,(a3)
        bne.s .invalid
        clr.l (a2)
        move.w #TU_UNLOGGED,(a3)
        clr.w 2(a3)
        bra.s .return
.invalid:
        moveq #-1,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.l d0
        rts

tu_undo:
        movem.l d1-d7/a0-a6,-(sp)
        bsr.s tu_validate
        bne.s .return
        tst.w (a3)
        bne.s .invalid
        tst.w 2(a2)
        beq.s .return
        ; The object dispatcher handles object groups through private reversal.
        ; Refuse them here so a wrong caller cannot index MAP using SPT records.
        move.w (a2),d0
        subq.w #1,d0
        andi.w #255,d0
        lsl.w #4,d0
        move.w 0(a1,d0.w),d1
        andi.w #$7fff,d1
        cmpi.w #TU_CELL,d1
        bne.s .invalid
        ; Validate the entire live log before any authored or index write.
        ; Repeated cells restore in reverse order, including full high bits.
.record:
        subq.w #1,(a2)
        andi.w #255,(a2)
        subq.w #1,2(a2)
        move.w (a2),d0
        lsl.w #4,d0
        lea 0(a1,d0.w),a4
        move.w 2(a4),d1
        add.w d1,d1
        move.w 4(a4),0(a0,d1.w)
        tst.w (a4)
        bpl.s .record
        moveq #1,d0
        bra.s .return
.invalid:
        moveq #-1,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.l d0
        rts

; Validate mixed closed history plus the active terrain stroke contract.
; Object groups can precede a terrain stroke, but cannot be its active group.
tu_validate:
        movem.l d1-d6/a0-a4,-(sp)
        moveq #-1,d0
        move.w (a3),d1
        beq.s .zero_count
        cmpi.w #TU_OPEN,d1
        beq.s .scan
        cmpi.w #TU_UNLOGGED,d1
        bne.s .return
        tst.l (a2)
        bne.s .return
.zero_count:
        tst.w 2(a3)
        bne.s .return
.scan:
        move.w 2(a3),-(sp)
        movea.l a1,a0
        movea.l a2,a1
        bsr.s oh_ring
        move.w (sp)+,d1
        tst.l d0
        bne.s .return
        tst.w d1
        beq.s .return
        moveq #-1,d0
        cmp.w d1,d5
        bne.s .return
        cmpi.w #1,d6
        bne.s .return
        moveq #0,d0
.return:
        movem.l (sp)+,d1-d6/a0-a4
        tst.l d0
        rts
tu_finish:
OH_VALIDATE_ONLY equ 1
        include "history.s"
