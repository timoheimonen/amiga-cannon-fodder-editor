; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Authoring viewport and toolbar renderer. Mutable labels are scratch.
enter_view:
        movem.l d0-d7/a0-a6,-(sp)
        bsr display_acquire
        lea preview_state+PCREL(pc),a0
        move.w #PV_STATE_SIZE/2-1,d0
.clear_state:
        clr.w (a0)+
        dbra d0,.clear_state
        move.l #PREVIEW_MASK,pv_mask_row+preview_state
        move.w #1,pv_native_masks+preview_state
        bsr bar_clear
        move.w #3,TERRAIN_BAR_DIRTY
        bsr draw_toolbar
        bsr publish_ring
        movem.l (sp)+,d0-d7/a0-a6
        rts

render_view:
        bsr op_clip_full
        ori.w #3,TERRAIN_BAR_DIRTY
        movem.l d0-d7/a0-a6,-(sp)
        lea preview_state+PCREL(pc),a4
        bsr preview_restore
        bsr set_ring
        moveq #0,d4
.row:
        moveq #0,d6
.tile:
        bsr paint_cell
        addq.w #1,d6
        cmp.w #19,d6
        blo.s .tile
        addq.w #1,d4
        cmp.w #12,d4
        blo.s .row
        bsr publish_ring
        movem.l (sp)+,d0-d7/a0-a6
        rts

scroll_view:
        movem.l d0-d7/a0-a6,-(sp)
        lea preview_state+PCREL(pc),a4
        bsr preview_restore
        move.w view_origin_x+PCREL(pc),d7
        sub.w last_camera+PCREL(pc),d7
        move.w view_origin_y+PCREL(pc),d5
        sub.w last_camera+2+PCREL(pc),d5
        move.w d7,d0
        beq.s .check_y
        cmp.w #1,d0
        beq.s .check_y
        cmp.w #-1,d0
        bne.s .full
.check_y:
        move.w d5,d0
        beq.s .edges
        cmp.w #1,d0
        beq.s .edges
        cmp.w #-1,d0
        bne.s .full
.edges:
        bsr.s set_ring
        move.w #-1,changed_col
        tst.w d7
        beq.s .vertical
        moveq #0,d6
        tst.w d7
        bmi.s .column
        moveq #18,d6
.column:
        move.w d6,changed_col
        moveq #0,d4
.column_tile:
        bsr.s paint_cell
        addq.w #1,d4
        cmp.w #12,d4
        blo.s .column_tile
.vertical:
        tst.w d5
        beq.s .publish
        moveq #0,d4
        tst.w d5
        bmi.s .row
        moveq #11,d4
.row:
        moveq #0,d6
.row_tile:
        cmp.w changed_col+PCREL(pc),d6
        beq.s .skip
        bsr.s paint_cell
.skip:
        addq.w #1,d6
        cmp.w #19,d6
        blo.s .row_tile
.publish:
        bsr op_clip_scroll
        bsr publish_ring
        bra.s .done
.full:
        bsr render_view
.done:
        movem.l (sp)+,d0-d7/a0-a6
        rts

set_ring:
        moveq #0,d0
        move.w view_origin_x+PCREL(pc),d0
        lsl.l #4,d0
        divu #320,d0
        moveq #0,d1
        move.w view_origin_y+PCREL(pc),d1
        lsl.l #4,d1
        add.w d0,d1
        and.w #255,d1
        move.w d1,RING_Y
        clr.w RING_Y+2
        mulu #40,d1
        swap d0
        move.w d0,RING_X
        clr.w RING_X+2
        lsr.w #3,d0
        add.w d0,d1
        move.w d1,ring_base
        rts

; D4/D6 are logical tile row/column. Split a tile at physical row 256.
paint_cell:
        moveq #0,d0
        move.w view_origin_y+PCREL(pc),d0
        add.w d4,d0
        cmp.w editor_map_height,d0
        bhs.s .outside
        moveq #0,d1
        move.w view_origin_x+PCREL(pc),d1
        add.w d6,d1
        cmp.w editor_map_width,d1
        bhs.s .outside
        mulu editor_map_width,d0
        add.l d1,d0
        add.l d0,d0
        lea editor_map_grid,a0
        move.w 0(a0,d0.w),d0
        and.l #$1ff,d0
        cmpi.w #399,d0
        blo.s .tile_ready
.outside:
        moveq #0,d0
.tile_ready:
        lsl.l #7,d0
        lea editor_tile_data,a2
        adda.l d0,a2
        move.w d4,d3
        mulu #640,d3
        add.w d6,d3
        add.w d6,d3
        add.w ring_base+PCREL(pc),d3
        cmp.w #RING_BYTES,d3
        blo.s .inside
        sub.w #RING_BYTES,d3
.inside:
        moveq #0,d2
        move.w #RING_BYTES-1,d2
        sub.w d3,d2
        divu #ROW_BYTES,d2
        addq.w #1,d2
        cmp.w #16,d2
        bls.s .count
        moveq #16,d2
.count:
        movea.l a2,a0
        lea CANVAS,a1
        adda.w d3,a1
        move.w d2,d1
        jsr editor_tile_blit
        cmp.w #16,d2
        beq.s .done
        move.w d2,d0
        add.w d0,d0
        lea 0(a2,d0.w),a0
        moveq #16,d1
        sub.w d2,d1
        mulu #ROW_BYTES,d2
        add.w d2,d3
        sub.w #RING_BYTES,d3
        lea CANVAS,a1
        adda.w d3,a1
        jsr editor_tile_blit
.done:
        rts

set_item:
        movem.l a0/a4,-(sp)
        lea preview_state+PCREL(pc),a4
        lea parts+PCREL(pc),a0
        bsr preview_set_item
        movem.l (sp)+,a0/a4
        rts
update_item:
        movem.l d0-d7/a0-a4,-(sp)
        tst.l CAMERA_X
        bne .hide
        tst.l CAMERA_Y
        bne .hide
        moveq #0,d2
        move.w view_origin_x+PCREL(pc),d2
        lsl.l #4,d2
        sub.l d2,d0
        moveq #0,d2
        move.w view_origin_y+PCREL(pc),d2
        lsl.l #4,d2
        sub.l d2,d1
        move.w d0,d2
        ext.l d2
        cmp.l d2,d0
        bne .hide
        move.w d1,d2
        ext.l d2
        cmp.l d2,d1
        bne .hide
        lea preview_state+PCREL(pc),a4
        move.w pv_count(a4),d5
        beq .done
        subq.w #1,d5
        moveq #0,d6
        lea pv_parts(a4),a0
.part:
        movea.l part_desc(a0),a1
        move.w part_dx(a0),d2
        ext.l d2
        add.l d0,d2
        bsr camera_word_range
        bne.s .hide
        move.b DESC_ANCHOR_X(a1),d3
        ext.w d3
        ext.l d3
        add.l d3,d2
        bsr.s camera_word_range
        bne.s .hide
        move.l d2,d4
        move.w part_dy(a0),d2
        ext.l d2
        add.l d1,d2
        bsr.s camera_word_range
        bne.s .hide
        move.b DESC_ANCHOR_Y(a1),d3
        ext.w d3
        ext.l d3
        add.l d3,d2
        bsr.s camera_word_range
        bne.s .hide
        movea.l d2,a3
        moveq #0,d3
        move.w DESC_ROWS(a1),d3
        sub.l d3,d2
        bsr.s camera_word_range
        bne.s .hide
        movea.l d2,a2
        move.l d4,d2
        moveq #0,d3
        move.w DESC_WORDS(a1),d3
        subq.l #1,d3
        lsl.l #4,d3
        add.l d3,d2
        bsr.s camera_word_range
        bne.s .hide
        tst.l d2
        ble.s .next
        cmpi.l #VIEW_W,d4
        bge.s .next
        cmpa.l #VIEW_ROWS,a2
        bge.s .next
        cmpa.l #0,a3
        ble.s .next
        moveq #1,d6
.next:
        lea PART_SIZE(a0),a0
        dbra d5,.part
        tst.w d6
        beq.s .hide
        bsr preview_update
        bra.s .done
.hide:
        bsr.s restore_item
.done:
        movem.l (sp)+,d0-d7/a0-a4
        rts

; The compositor uses signed word intermediates even for clipped companions.
camera_word_range:
        move.w d2,d7
        ext.l d7
        cmp.l d7,d2
        rts

; D0.w/D1.w: tile origin. Change only validated coordinates, without drawing.
set_camera:
        cmp.w editor_map_width,d0
        bhs.s .reject
        cmp.w editor_map_height,d1
        bhs.s .reject
        move.w d0,view_origin_x
        move.w d1,view_origin_y
        moveq #0,d0
        rts
.reject:
        moveq #-1,d0
        rts
restore_item:
        move.l a4,-(sp)
        lea preview_state+PCREL(pc),a4
        bsr preview_restore
        movea.l (sp)+,a4
        rts

draw_toolbar:
        bra bar_draw

exit_view:
        movem.l d0-d7/a0-a6,-(sp)
        bsr.s restore_item
        ; Dialogs show this ring darkened behind them while it is unchanged.
        lea editor_base_palette,a0
        move.w ring_base+PCREL(pc),d2
        moveq #DIALOG_STAMP,d1
        moveq #DIALOG_OPERATION,d0
        jsr EDITOR_BACKEND_ENTRY
        bsr display_release
        movem.l (sp)+,d0-d7/a0-a6
        rts

        include "viewport/preview.s"
        include "../editor/display.s"
