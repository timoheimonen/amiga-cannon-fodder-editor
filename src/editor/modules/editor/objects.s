; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Render validated canonical SPT without constructing or updating entities.
; No active reversible preview; owned assets and qualified metadata are required.
; Build at most 43 private depth records on the stack; never reorder canonical SPT.
; Negative/positive layers retain source order, ordinary parts sort by runtime Y.
; Existing sprites stay in world-aligned ring positions across one-tile scrolls.
; Repaint changed tiles before this call; a removed/moved object needs full repaint.
op_draw_placed:
        movem.l d0-d7/a0-a6,-(sp)
        bsr restore_item
        st preview_state+pv_pad
        lea -258(sp),sp
        movea.l sp,a4
        movea.l a4,a6
        lea 258(a4),a2
        moveq #0,d7
        move.w EDITOR_METADATA_BASE+CFMD_SPT_BYTES+PCREL(pc),d7
        cmp.w #430,d7
        bhi .done
        divu #10,d7
        move.l d7,d0
        swap d0
        tst.w d0
        bne .done
        subq.w #1,d7
        bmi .done
        moveq #0,d6
        lea EDITOR_SPT_BASE+PCREL(pc),a5
.root:
        ifd AUR_OBJECT_VIEW
        move.w d6,d0
        lsr.w #8,d0
        cmp.w OBJECT_DRAG_INDEX,d0
        beq.s .next_root
        endif
        cmpi.w #$7fef,4(a5)
        bhi.s .next_root
        tst.w 6(a5)
        bmi.s .next_root
        move.w 8(a5),d0
        cmp.w #110,d0
        bhi.s .next_root
        add.w d0,d0
        lea op_part_index(pc),a0
        move.w 0(a0,d0.w),d0
        beq.s .next_root
        lea 0(a0,d0.w),a3
        move.w (a3)+,d4
        beq.s .next_root
        subq.w #1,d4
        moveq #0,d5
.part:
        move.b 4(a3),d2
        ext.w d2
        add.w 6(a5),d2
        cmpi.w #$3c,8(a5)
        bne.s .append
        tst.w d5
        beq.s .append
        cmpi.w #$7fef,14(a5)
        bhi.s .next_part
        tst.w 16(a5)
        bmi.s .next_part
        move.w 16(a5),d2
.append:
        cmpa.l a2,a6
        bhs .done
        move.b 5(a3),d1
        ext.w d1
        move.w d1,(a6)+
        move.w d2,(a6)+
        move.w d6,d3
        or.w d5,d3
        move.w d3,(a6)+
.next_part:
        lea 6(a3),a3
        addq.w #1,d5
        dbra d4,.part
.next_root:
        lea 10(a5),a5
        addi.w #256,d6
        dbra d7,.root
        cmpa.l a4,a6
        beq .done
        lea 6(a4),a0
.sort_next:
        cmpa.l a6,a0
        bhs.s .draw_start
        move.w (a0),d0
        move.w 2(a0),d1
        move.w 4(a0),d2
        movea.l a0,a1
.compare:
        cmpa.l a4,a1
        beq.s .insert
        move.w -6(a1),d3
        cmp.w d0,d3
        bgt.s .shift
        blt.s .insert
        tst.w d0
        bne.s .insert
        move.w -4(a1),d3
        cmp.w d1,d3
        ble.s .insert
.shift:
        move.l -6(a1),(a1)
        move.w -2(a1),4(a1)
        subq.l #6,a1
        bra.s .compare
.insert:
        move.w d0,(a1)
        move.w d1,2(a1)
        move.w d2,4(a1)
        lea 6(a0),a0
        bra.s .sort_next
.draw_start:
        movea.l a4,a5
.draw:
        moveq #0,d0
        move.w 4(a5),d6
        move.w d6,d0
        lsr.w #8,d0
        mulu #10,d0
        lea EDITOR_SPT_BASE+PCREL(pc),a3
        adda.w d0,a3
        move.w 8(a3),d0
        add.w d0,d0
        lea op_part_index(pc),a0
        move.w 0(a0,d0.w),d0
        lea 2(a0,d0.w),a2
        andi.w #255,d6
        move.w d6,d0
        mulu #6,d0
        adda.w d0,a2
        ifd OBJECT_ANCHOR_ENABLED
        cmpi.w #$18,8(a3)
        bne.s .native_descriptor
        lea OBJECT_ANCHOR_DESC,a1
        bra.s .descriptor_ready
.native_descriptor:
        endif
        moveq #0,d0
        move.b (a2),d0
        lsl.w #2,d0
        lea editor_game_sprites,a1
        movea.l 0(a1,d0.w),a1
        moveq #0,d0
        move.b 1(a2),d0
        lsl.w #4,d0
        adda.w d0,a1
        ifd OBJECT_ANCHOR_ENABLED
.descriptor_ready:
        endif
        move.l a1,parts
        move.b 2(a2),d0
        ext.w d0
        move.w d0,parts+4
        move.b 3(a2),d0
        ext.w d0
        move.w d0,parts+6
        cmpi.w #$3c,8(a3)
        bne.s .show
        tst.w d6
        beq.s .show
        move.w 14(a3),d0
        sub.w 4(a3),d0
        add.w d0,parts+4
        move.w 16(a3),d0
        sub.w 6(a3),d0
        add.w d0,parts+6
.show:
        bsr op_part_visible
        tst.w d0
        beq.s .advance
        moveq #1,d0
        bsr set_item
        tst.l d0
        bne.s .advance
        moveq #0,d0
        moveq #0,d1
        move.w 4(a3),d0
        addi.w #16,d0
        move.w 6(a3),d1
        bsr update_item
        clr.b preview_state+pv_drawn
.advance:
        lea 6(a5),a5
        cmpa.l a6,a5
        blo .draw
        clr.w preview_state+pv_count
        bsr publish_ring
.done:
        clr.b preview_state+pv_pad
        lea 258(sp),sp
        movem.l (sp)+,d0-d7/a0-a6
        rts

; Restrict permanent stamping to terrain pixels redrawn by the caller.
; Reversible previews independently restore full-view clipping before drawing.
op_clip_full:
        clr.l preview_state+pv_clip_left
        move.l #$013000c0,preview_state+pv_clip_right
        rts
; D4/D6: changed tile row/column. Preserve all registers.
op_clip_cell:
        movem.l d0-d1,-(sp)
        move.w d6,d0
        lsl.w #4,d0
        move.w d0,preview_state+pv_clip_left
        add.w #16,d0
        move.w d0,preview_state+pv_clip_right
        move.w d4,d1
        lsl.w #4,d1
        move.w d1,preview_state+pv_clip_top
        add.w #16,d1
        move.w d1,preview_state+pv_clip_bottom
        movem.l (sp)+,d0-d1
        rts
; D7/D5: one-tile horizontal/vertical delta. A diagonal uses the full view.
op_clip_scroll:
        bsr.s op_clip_full
        tst.w d7
        beq.s .vertical
        tst.w d5
        bne.s .done
        tst.w d7
        bmi.s .left
        move.w #288,preview_state+pv_clip_left
        rts
.left:
        move.w #16,preview_state+pv_clip_right
        rts
.vertical:
        tst.w d5
        beq.s .done
        bmi.s .top
        move.w #176,preview_state+pv_clip_top
        rts
.top:
        move.w #16,preview_state+pv_clip_bottom
.done:
        rts

; Cull against the changed terrain rectangle before preview setup/mask work.
; A3 is the validated source root; parts holds the selected static descriptor.
; Long intermediates keep imported off-view anchors from wrapping into the view.
op_part_visible:
        movea.l parts+PCREL(pc),a1
        moveq #0,d0
        move.w 4(a3),d0
        add.l #16,d0
        move.w parts+4+PCREL(pc),d2
        ext.l d2
        add.l d2,d0
        move.b DESC_ANCHOR_X(a1),d2
        ext.w d2
        ext.l d2
        add.l d2,d0
        moveq #0,d2
        move.w view_origin_x+PCREL(pc),d2
        lsl.l #4,d2
        sub.l d2,d0
        moveq #0,d2
        move.w preview_state+pv_clip_right+PCREL(pc),d2
        cmp.l d2,d0
        bge.s .hidden
        moveq #0,d2
        move.w DESC_WORDS(a1),d2
        subq.w #1,d2
        lsl.w #4,d2
        add.l d2,d0
        moveq #0,d2
        move.w preview_state+pv_clip_left+PCREL(pc),d2
        cmp.l d2,d0
        ble.s .hidden
        moveq #0,d1
        move.w 6(a3),d1
        move.w parts+6+PCREL(pc),d2
        ext.l d2
        add.l d2,d1
        move.b DESC_ANCHOR_Y(a1),d2
        ext.w d2
        ext.l d2
        add.l d2,d1
        moveq #0,d2
        move.w view_origin_y+PCREL(pc),d2
        lsl.l #4,d2
        sub.l d2,d1
        moveq #0,d2
        move.w preview_state+pv_clip_top+PCREL(pc),d2
        cmp.l d2,d1
        ble.s .hidden
        moveq #0,d2
        move.w DESC_ROWS(a1),d2
        sub.l d2,d1
        moveq #0,d2
        move.w preview_state+pv_clip_bottom+PCREL(pc),d2
        cmp.l d2,d1
        bge.s .hidden
        moveq #1,d0
        rts
.hidden:
        moveq #0,d0
        rts
