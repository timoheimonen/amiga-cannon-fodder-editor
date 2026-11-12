; Cannon Fodder In-Game Level Editor V1.2.5
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Areas of the map in the Paint tool. Shift with the left button selects an
; area that gets the selected tile. Shift with the right button selects an
; area to copy: its tiles become Paint's brush and go to the Slave's
; clipboard, from where the key V takes them back, also in another mission.
; A block holds the tile numbers alone: a stamp keeps the other bits of the
; cells it changes, as painting does.

; The block that is the brush, as the clipboard keeps it (see ui.i).
BLOCK_RECORD    equ MARKER_TILE+128
        ifgt BLOCK_RECORD+CLIPBOARD_BYTES-EDITOR_READBACK_BASE-EDITOR_READBACK_BYTES
        fail "The block record exceeds readback"
        endif
; The frame drawn on the map: the area being selected, or the cells a stamp
; at the cursor would change. Left column, top row, width and height in
; cells; no frame while the width is zero.
BLOCK_FRAME     equ BLOCK_RECORD+CLIPBOARD_BYTES
        ifgt BLOCK_FRAME+8-EDITOR_READBACK_BASE-EDITOR_READBACK_BYTES
        fail "The block frame exceeds readback"
        endif
BLOCK_TOO_LARGE equ 1
BLOCK_NONE      equ 2
BLOCK_FOREIGN   equ 3

; The selected area: D0.w/D1.w = its left column and top row, D2.w/D3.w =
; its width and height in cells. Preserves the other registers.
block_area:
        move.w TERRAIN_SELECT_X,d0
        move.w TERRAIN_CURSOR_X,d2
        cmp.w d0,d2
        bhs.s .columns
        exg d0,d2
.columns:
        sub.w d0,d2
        addq.w #1,d2
        move.w TERRAIN_SELECT_Y,d1
        move.w TERRAIN_CURSOR_Y,d3
        cmp.w d1,d3
        bhs.s .rows
        exg d1,d3
.rows:
        sub.w d1,d3
        addq.w #1,d3
        rts

; The selection has ended: its tiles become the brush and the clipboard's
; record, or the information line says that the area is too large.
; Preserves all registers.
block_copy:
        movem.l d0-d6/a0-a1,-(sp)
        clr.w TERRAIN_SELECT
        ori.w #1,TERRAIN_BAR_DIRTY
        bsr.s block_area
        move.w d2,d4
        mulu d3,d4
        cmpi.w #BLOCK_MAX_CELLS,d4
        bls.s .fits
        move.w #BLOCK_TOO_LARGE,TERRAIN_BLOCK_NOTICE
        bra.s .done
.fits:
        lea BLOCK_RECORD,a1
        move.l #BLOCK_MAGIC,(a1)+
        move.w d2,(a1)+
        move.w d3,(a1)+
        move.l map_file_buffer+16,(a1)+
        move.l map_file_buffer+20,(a1)+
        move.w d2,TERRAIN_BLOCK_W
        move.w d3,TERRAIN_BLOCK_H
        mulu editor_map_width,d1
        add.w d0,d1
        add.l d1,d1
        lea editor_map_grid,a0
        adda.l d1,a0
        move.w editor_map_width,d5
        sub.w d2,d5
        add.w d5,d5
        subq.w #1,d3
.row:
        move.w d2,d6
        subq.w #1,d6
.cell:
        ; A number that is no tile is tile 0, as the map shows it.
        move.w (a0)+,d0
        andi.w #$1FF,d0
        cmpi.w #399,d0
        blo.s .tile
        moveq #0,d0
.tile:
        move.w d0,(a1)+
        dbra d6,.cell
        adda.w d5,a0
        dbra d3,.row
        lea BLOCK_RECORD,a0
        move.w d4,d2
        add.w d2,d2
        addi.w #BLOCK_CELLS,d2
        moveq #CLIPBOARD_PUT,d1
        moveq #CLIPBOARD_OPERATION,d0
        jsr EDITOR_BACKEND_ENTRY
.done:
        movem.l (sp)+,d0-d6/a0-a1
        rts

; Give the cells of an area the selected tile. D1.w = the cell index of the
; area's top left cell, D2.w/D3.w = its width and height, inside the map.
; The caller has the terrain context in A0-A3/D7 and an open operation whose
; log tu_begin has checked. D0 = 0 nothing changed, 1 changed, -1 invalid.
; Preserves D1-D7/A0-A6.
block_fill:
        movem.l d1-d6,-(sp)
        move.w d2,d4
        move.w editor_map_width,d5
        sub.w d4,d5
        moveq #0,d6
.row:
        swap d3
        move.w d4,d3
.cell:
        move.w d1,d2
        add.w d2,d2
        move.w 0(a0,d2.w),d2
        andi.w #$FE00,d2
        or.w AUR_BASE+AUR_TILE,d2
        bsr tu_change_checked
        bmi.s .return
        or.w d0,d6
        addq.w #1,d1
        subq.w #1,d3
        bne.s .cell
        add.w d5,d1
        swap d3
        subq.w #1,d3
        bne.s .row
        moveq #1,d0
        and.w d6,d0
.return:
        movem.l (sp)+,d1-d6
        tst.w d0
        rts

; The rectangle has ended: its cells get the selected tile as one undo
; operation. An area of more than 256 cells asks first: its size is kept
; for the answer and D1.w is the cell index of its top left cell.
; The caller has the terrain context in A0-A3/D7 and no open operation.
; D0 = 0 nothing changed, 1 changed, 2 ask first, -1 invalid.
; Clobbers D1; preserves D2-D7/A0-A6.
block_paint:
        movem.l d2-d4,-(sp)
        clr.w TERRAIN_SELECT
        ori.w #1,TERRAIN_BAR_DIRTY
        bsr block_area
        mulu editor_map_width,d1
        add.w d0,d1
        move.w d2,d4
        mulu d3,d4
        cmpi.l #BLOCK_MAX_CELLS,d4
        bhi.s .large
        bsr tu_begin
        bmi.s .return
        bsr.s block_fill
        move.w d0,d4
        bsr tu_end
        bmi.s .return
        move.w d4,d0
        bra.s .return
.large:
        move.w #AREA_TAG,AREA_PENDING
        move.w d2,AREA_WIDTH
        move.w d3,AREA_HEIGHT
        moveq #2,d0
.return:
        movem.l (sp)+,d2-d4
        tst.w d0
        rts

; The key V: the clipboard's block becomes the brush when it is a block of
; this terrain; otherwise the brush stays a tile and the information line
; says why. The record comes from outside the mission and is checked in
; full. Preserves all registers.
block_recall:
        movem.l d0-d3/a0-a1,-(sp)
        clr.l TERRAIN_BLOCK_W
        ori.w #1,TERRAIN_BAR_DIRTY
        lea BLOCK_RECORD,a0
        moveq #CLIPBOARD_GET,d1
        moveq #CLIPBOARD_OPERATION,d0
        jsr EDITOR_BACKEND_ENTRY
        moveq #BLOCK_NONE,d3
        cmpi.w #BLOCK_CELLS+2,d0
        blo.s .refuse
        cmpi.l #BLOCK_MAGIC,(a0)
        bne.s .refuse
        move.w BLOCK_WIDTH(a0),d1
        beq.s .refuse
        move.w BLOCK_HEIGHT(a0),d2
        beq.s .refuse
        mulu d2,d1
        cmpi.l #BLOCK_MAX_CELLS,d1
        bhi.s .refuse
        move.w d1,d2
        add.w d2,d2
        addi.w #BLOCK_CELLS,d2
        cmp.w d2,d0
        bne.s .refuse
        lea BLOCK_CELLS(a0),a1
        subq.w #1,d1
.tile:
        cmpi.w #399,(a1)+
        bhs.s .refuse
        dbra d1,.tile
        moveq #BLOCK_FOREIGN,d3
        move.l map_file_buffer+16,d0
        cmp.l BLOCK_TERRAIN(a0),d0
        bne.s .refuse
        move.l map_file_buffer+20,d0
        cmp.l BLOCK_TERRAIN+4(a0),d0
        bne.s .refuse
        move.l BLOCK_WIDTH(a0),TERRAIN_BLOCK_W
        moveq #0,d3
.refuse:
        move.w d3,TERRAIN_BLOCK_NOTICE
        movem.l (sp)+,d0-d3/a0-a1
        rts

; Stamp the brush's block with its top left cell on the cursor cell, as one
; undo operation; the part beyond the map's edge is left out. The caller has
; the terrain context in A0-A3/D7 and no open operation.
; D0 = 0 nothing changed, 1 changed, -1 invalid. Preserves D1-D7/A0-A6.
block_stamp:
        movem.l d1-d6/a4,-(sp)
        bsr tu_begin
        bmi.s .return
        lea BLOCK_RECORD+BLOCK_CELLS,a4
        moveq #0,d6
        move.w TERRAIN_CURSOR_Y,d4
        move.w TERRAIN_BLOCK_H,d5
.row:
        cmp.w editor_map_height,d4
        bhs.s .end
        move.w d4,d1
        mulu editor_map_width,d1
        move.w TERRAIN_CURSOR_X,d3
        add.w d3,d1
        swap d5
        move.w TERRAIN_BLOCK_W,d5
.cell:
        cmp.w editor_map_width,d3
        bhs.s .next
        move.w d1,d2
        add.w d2,d2
        move.w 0(a0,d2.w),d2
        andi.w #$FE00,d2
        or.w (a4),d2
        ; tu_begin has checked the log; checking it again for every cell
        ; would hold the view for most of a second.
        bsr tu_change_checked
        bmi.s .failed
        or.w d0,d6
.next:
        addq.l #2,a4
        addq.w #1,d1
        addq.w #1,d3
        subq.w #1,d5
        bne.s .cell
        swap d5
        addq.w #1,d4
        subq.w #1,d5
        bne.s .row
.end:
        bsr tu_end
        bmi.s .return
        moveq #1,d0
        and.w d6,d0
        bra.s .return
.failed:
        bsr tu_end
        moveq #-1,d0
.return:
        movem.l (sp)+,d1-d6/a4
        tst.w d0
        rts

; Append "Area " or "Block " and the size to the information line at A0
; while an area is being selected or the brush is a block. Z clear when the
; line was written. Clobbers D0-D1/A1.
block_compose:
        movem.l d2-d3,-(sp)
        tst.w TERRAIN_SELECT
        beq.s .brush
        lea block_area_text(pc),a1
        bsr bar_append
        bsr block_area
        bra.s .size
.brush:
        move.w TERRAIN_BLOCK_W,d2
        beq.s .none
        move.w TERRAIN_BLOCK_H,d3
        lea block_brush_text(pc),a1
        bsr bar_append
.size:
        move.w d2,d0
        bsr block_number
        move.b #'x',(a0)+
        move.w d3,d0
        bsr block_number
        moveq #1,d0
.none:
        movem.l (sp)+,d2-d3
        rts

; The edges of the frame at A0 that a cell has: D0.w/D1.w = the cell's map
; column and row. D7.w = bit 0 top, 1 bottom, 2 left, 3 right; Z set when
; none. Clobbers D0/D1.
block_edges:
        moveq #0,d7
        sub.w (a0),d0
        cmp.w 4(a0),d0
        bhs.s .done
        sub.w 2(a0),d1
        cmp.w 6(a0),d1
        bhs.s .done
        tst.w d1
        bne.s .bottom
        bset #0,d7
.bottom:
        addq.w #1,d1
        cmp.w 6(a0),d1
        bne.s .left
        bset #1,d7
.left:
        tst.w d0
        bne.s .right
        bset #2,d7
.right:
        addq.w #1,d0
        cmp.w 4(a0),d0
        bne.s .done
        bset #3,d7
.done:
        tst.w d7
        rts

; A2 = the graphics of a cell's tile, D4/D6 = the cell's row and column in
; the view. A cell on the edge of the frame is drawn with that edge: two
; lines, the outer in the bar's text colour and the inner in colour 0, so
; the frame shows on every tile. A2 then points at the framed copy.
; Clobbers D0/D1/A0/A1; preserves the other registers.
block_frame_tile:
        tst.w BLOCK_FRAME+4
        bne.s .frame
        rts
.frame:
        movem.l d2-d7,-(sp)
        move.w view_origin_x,d0
        add.w d6,d0
        move.w view_origin_y,d1
        add.w d4,d1
        lea BLOCK_FRAME,a0
        bsr.s block_edges
        beq.s .plain
        ; The game's blitter copy of the previous framed cell may still run.
        btst #6,$DFF002
.blitter:
        btst #6,$DFF002
        bne.s .blitter
        lea MARKER_TILE,a1
        moveq #0,d3
.row:
        moveq #0,d0
        moveq #0,d2
        btst #2,d7
        beq.s .right
        move.w #$C000,d0
        move.w #$8000,d2
.right:
        btst #3,d7
        beq.s .top
        ori.w #$0003,d0
        ori.w #$0001,d2
.top:
        btst #0,d7
        beq.s .bottom
        tst.w d3
        beq.s .line
        cmpi.w #2,d3
        beq.s .inner
.bottom:
        btst #1,d7
        beq.s .write
        cmpi.w #30,d3
        beq.s .line
        cmpi.w #28,d3
        bne.s .write
.inner:
        moveq #-1,d0
        bra.s .write
.line:
        moveq #-1,d0
        moveq #-1,d2
.write:
        bsr marker_planes
        addq.w #2,d3
        cmpi.w #32,d3
        blo.s .row
        movea.l a1,a2
.plain:
        movem.l (sp)+,d2-d7
        rts

; Bring the frame on the map up to date, once a field: the area being
; selected, else the cells of the map that a stamp at the cursor would
; change, else none. The cells whose edges change are painted again.
; Preserves all registers.
block_frame_update:
        movem.l d0-d7/a0-a4,-(sp)
        tst.w TERRAIN_SELECT
        beq.s .brush
        bsr block_area
        bra.s .wanted
.brush:
        moveq #0,d0
        moveq #0,d1
        moveq #0,d2
        moveq #0,d3
        tst.w TERRAIN_BLOCK_W
        beq.s .wanted
        move.w TERRAIN_CURSOR_X,d0
        bmi.s .none
        move.w TERRAIN_CURSOR_Y,d1
        ; The part of the block inside the map.
        move.w editor_map_width,d2
        sub.w d0,d2
        cmp.w TERRAIN_BLOCK_W,d2
        bls.s .width
        move.w TERRAIN_BLOCK_W,d2
.width:
        move.w editor_map_height,d3
        sub.w d1,d3
        cmp.w TERRAIN_BLOCK_H,d3
        bls.s .wanted
        move.w TERRAIN_BLOCK_H,d3
        bra.s .wanted
.none:
        moveq #0,d0
.wanted:
        lea BLOCK_FRAME,a0
        cmp.w (a0),d0
        bne.s .changed
        cmp.w 2(a0),d1
        bne.s .changed
        cmp.w 4(a0),d2
        bne.s .changed
        cmp.w 6(a0),d3
        beq.s .return
.changed:
        ; The old frame stays on the stack while the cells are compared.
        move.l 4(a0),-(sp)
        move.l (a0),-(sp)
        movem.w d0-d3,(a0)
        bsr restore_item
        moveq #0,d4
.row:
        moveq #0,d6
.cell:
        move.w view_origin_x,d0
        add.w d6,d0
        move.w view_origin_y,d1
        add.w d4,d1
        movea.l sp,a0
        bsr block_edges
        move.w d7,d3
        move.w view_origin_x,d0
        add.w d6,d0
        move.w view_origin_y,d1
        add.w d4,d1
        lea BLOCK_FRAME,a0
        bsr block_edges
        cmp.w d3,d7
        beq.s .next
        bsr paint_cell
.next:
        addq.w #1,d6
        cmpi.w #19,d6
        blo.s .cell
        addq.w #1,d4
        cmpi.w #12,d4
        blo.s .row
        addq.l #8,sp
        bsr op_clip_full
        bsr publish_ring
        bsr terrain_objects
.return:
        movem.l (sp)+,d0-d7/a0-a4
        rts

; D0.w value up to 999, A0 output: no leading zeros. Clobbers D0-D1/A1.
block_number:
        cmpi.w #100,d0
        blo bar_number
        moveq #2,d1
        bra bar_digits

block_area_text: dc.b "Area ",0
block_brush_text: dc.b "Block ",0
block_notices:
        dc.w .large-block_notices,.none-block_notices,.foreign-block_notices
.large: dc.b "Area too large: 256 cells at most.",0
.none: dc.b "Nothing has been copied.",0
.foreign: dc.b "Copied from another terrain.",0
        even
