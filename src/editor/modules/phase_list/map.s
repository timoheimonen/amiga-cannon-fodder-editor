; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Edit a private eight-byte phase map: six source indices, count, selection.
; A0=trusted aligned eight-byte candidate, D0.l=operation, D1.l=from/index,
; D2.l=destination for MOVE. Operations:0 MOVE,1 DELETE OTHER,2 COPY SOURCE.
; The selected phase stays resident; its logical index follows every move.
; COPY SOURCE appends a reference to an existing saved phase. A current
; unsaved $FF phase cannot be copied. Selected-phase deletion needs a separate
; staged replacement and is deliberately refused here.
; D0=1 changed,0 unchanged,-1 malformed state,-2 invalid operation/index.
; Preserve D1-D7/A0-A6/SP and SR control. Refusals preserve all candidate bytes.
; This helper grants no owner/directory authority and never edits canonical AUR.
        section .text,code
        xdef plm_start,plm_apply,plm_end
plm_start:
plm_apply:
        movem.l d1-d7/a0-a6,-(sp)
        move.l d0,d7
        movea.l a0,a5
        subq.l #8,sp
        move.l (a0),(sp)
        move.l 4(a0),4(sp)
        movea.l sp,a0
        bsr plm_valid
        bne plm_return
        moveq #-2,d0
        cmpi.l #2,d7
        bhi plm_return
        moveq #0,d3
        move.b 6(a0),d3
        cmp.l d3,d1
        bhs plm_return
        tst.l d7
        beq.s .move
        cmpi.w #1,d7
        beq.s .delete
        cmpi.w #6,d3
        bhs plm_return
        move.b (a0,d1.w),d4
        cmpi.b #$FF,d4
        beq plm_return
        move.b d4,(a0,d3.w)
        addq.b #1,6(a0)
        bra .check
.delete:
        cmpi.w #1,d3
        beq plm_return
        moveq #0,d4
        move.b 7(a0),d4
        cmp.w d4,d1
        beq plm_return
        blo.s .earlier
        bra.s .shift_delete
.earlier:
        subq.b #1,7(a0)
.shift_delete:
        move.w d1,d5
        subq.w #1,d3
.delete_loop:
        cmp.w d3,d5
        bhs.s .deleted
        move.b 1(a0,d5.w),(a0,d5.w)
        addq.w #1,d5
        bra.s .delete_loop
.deleted:
        move.b #$FF,(a0,d3.w)
        move.b d3,6(a0)
        bra.s .check
.move:
        cmp.l d3,d2
        bhs.s plm_return
        cmp.w d1,d2
        beq.s .unchanged
        move.w d1,d5
        move.b (a0,d1.w),d6
        moveq #0,d4
        move.b 7(a0),d4
        cmp.w d1,d4
        bne.s .other_selected
        move.b d2,7(a0)
        bra.s .shift_move
.other_selected:
        cmp.w d1,d2
        blo.s .moving_left
        cmp.w d1,d4
        bls.s .shift_move
        cmp.w d2,d4
        bhi.s .shift_move
        subq.b #1,7(a0)
        bra.s .shift_move
.moving_left:
        cmp.w d2,d4
        blo.s .shift_move
        cmp.w d1,d4
        bhs.s .shift_move
        addq.b #1,7(a0)
.shift_move:
        cmp.w d2,d5
        beq.s .moved
        bhi.s .left
        move.b 1(a0,d5.w),(a0,d5.w)
        addq.w #1,d5
        bra.s .shift_move
.left:
        move.b -1(a0,d5.w),(a0,d5.w)
        subq.w #1,d5
        bra.s .shift_move
.moved:
        move.b d6,(a0,d2.w)
.check:
        bsr.s plm_valid
        bne.s plm_return
        move.l (a0),(a5)
        move.l 4(a0),4(a5)
        moveq #1,d0
        bra.s plm_return
.unchanged:
        moveq #0,d0
plm_return:
        addq.l #8,sp
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; A0=private eight-byte phase map. D0 result; clobber D3/D4 only.
plm_valid:
        moveq #-1,d0
        moveq #0,d3
        move.b 6(a0),d3
        subq.w #1,d3
        cmpi.w #5,d3
        bhi.s .return
        addq.w #1,d3
        cmp.b 7(a0),d3
        bls.s .return
        moveq #0,d4
.loop:
        cmp.w d3,d4
        bhs.s .unused
        cmpi.b #6,(a0,d4.w)
        blo.s .next
        cmp.b 7(a0),d4
        bne.s .return
.unused:
        cmpi.b #$FF,(a0,d4.w)
        bne.s .return
.next:
        addq.w #1,d4
        cmpi.w #6,d4
        blo.s .loop
        moveq #0,d0
.return:
        tst.w d0
        rts
plm_end:
