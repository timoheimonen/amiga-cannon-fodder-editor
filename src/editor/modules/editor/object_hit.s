; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; D0/D1.w=world pixel; return D0.w=logical root index or-1. Preserve others.
; Canonical SPT, bundle structure and descriptor assets are already validated.
; Pick the last painted part whose descriptor rectangle contains the point.
; Bounding rectangles deliberately include transparent pixels. No state writes.
object_hit:
        movem.l d1-d7/a0-a6,-(sp)
        lea -10(sp),sp
        move.w d0,(sp)
        move.w d1,2(sp)
        move.w #$8000,4(sp)
        clr.w 6(sp)
        move.w #-1,8(sp)
        moveq #0,d6
        move.w EDITOR_METADATA_BASE+CFMD_SPT_BYTES,d6
        divu #10,d6
        moveq #0,d7
        lea EDITOR_SPT_BASE,a5
.root:
        move.w 8(a5),d0
        add.w d0,d0
        lea op_part_index(pc),a0
        move.w 0(a0,d0.w),d0
        beq .next_root
        adda.w d0,a0
        move.w (a0)+,d4
        beq .next_root
        subq.w #1,d4
        movea.l a0,a6
        moveq #0,d5
.part:
        movea.l a5,a3
        cmpi.w #$3C,8(a5)
        bne.s .anchor
        tst.w d5
        beq.s .anchor
        lea 10(a5),a3
.anchor:
        cmpi.w #$7FEF,4(a3)
        bhi .next_part
        tst.w 6(a3)
        bmi .next_part
        cmpi.w #$18,8(a5)
        bne.s .native_descriptor
        lea OBJECT_ANCHOR_DESC,a0
        bra.s .descriptor_ready
.native_descriptor:
        moveq #0,d0
        move.b (a6),d0
        lsl.w #2,d0
        lea editor_game_sprites,a0
        movea.l 0(a0,d0.w),a0
        moveq #0,d0
        move.b 1(a6),d0
        lsl.w #4,d0
        adda.w d0,a0
.descriptor_ready:
        moveq #0,d0
        move.w 4(a3),d0
        addi.l #16,d0
        move.b 2(a6),d2
        ext.w d2
        ext.l d2
        add.l d2,d0
        move.b DESC_ANCHOR_X(a0),d2
        ext.w d2
        ext.l d2
        add.l d2,d0
        moveq #0,d2
        move.w (sp),d2
        sub.l d0,d2
        bmi.s .next_part
        moveq #0,d3
        move.w DESC_WORDS(a0),d3
        subq.w #1,d3
        lsl.w #4,d3
        cmp.l d3,d2
        bhs.s .next_part
        moveq #0,d0
        move.w 6(a3),d0
        move.b 3(a6),d2
        ext.w d2
        ext.l d2
        add.l d2,d0
        move.b DESC_ANCHOR_Y(a0),d2
        ext.w d2
        ext.l d2
        add.l d2,d0
        moveq #0,d2
        move.w 2(sp),d2
        sub.l d2,d0
        ble.s .next_part
        moveq #0,d3
        move.w DESC_ROWS(a0),d3
        cmp.l d3,d0
        bhi.s .next_part
        move.b 4(a6),d0
        ext.w d0
        add.w 6(a3),d0
        move.b 5(a6),d2
        ext.w d2
        cmp.w 4(sp),d2
        blt.s .next_part
        bgt.s .select
        tst.w d2
        bne.s .select
        cmp.w 6(sp),d0
        blt.s .next_part
.select:
        move.w d2,4(sp)
        move.w d0,6(sp)
        move.w d7,8(sp)
.next_part:
        lea 6(a6),a6
        addq.w #1,d5
        dbra d4,.part
.next_root:
        move.w 8(a5),d0
        lsl.w #2,d0
        lea ot_shared_recipes(pc),a0
        move.b 0(a0,d0.w),d0
        andi.w #3,d0
        addq.w #1,d0
        add.w d0,d7
        sub.w d0,d6
        ble.s .done
        mulu #10,d0
        adda.w d0,a5
        bra .root
.done:
        move.w 8(sp),d0
        ext.l d0
        lea 10(sp),sp
        movem.l (sp)+,d1-d7/a0-a6
        rts
