; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Terrain input, painting, grouped undo and tool dispatch.
; Persistent state is AUR; UI0..79 is transient and dead during a modal.
        xdef terrain_input,terrain_end
        xdef terrain_start,terrain_finish
terrain_start:

; D0.w=0 idle,1 SAVE,2 MENU,3 TILE,4 FILL,5 marker warning,6 limit,
; 7 large-stroke confirmation,8 object view/Undo,9 object palette,-1 invariant.
; For4 D0.high=seed.
; Other registers preserved. Function-key translated edge codes start at $D0.
; The cursor sprite has bitmap X=logical X+16, with offsets zeroed by view.
terrain_input:
        movem.l d1-d7/a0-a6,-(sp)
        bsr terrain_context
        move.w native_left_pressed,d5
        clr.w native_left_pressed
        move.w native_right_pressed,d3
        clr.w native_right_pressed
        move.w native_last_key,d0
        clr.w native_last_key
        cmpi.w #$C5,d0
        beq .menu
        cmpi.w #'U',d0
        beq .undo
        cmpi.w #'T',d0
        beq .tiles
        cmpi.w #'O',d0
        beq .palette
        subi.w #$D0,d0
        cmpi.w #4,d0
        bls .tool
        bsr terrain_scroll
        bmi .invalid
        tst.w native_left_down
        bne.s .pointer
        clr.w TERRAIN_STROKE_BLOCK
        bsr terrain_end
        bmi .invalid
.pointer:
        move.w native_mouse_x,d0
        addi.w #16,d0
        move.w native_mouse_y,d2
        ; A press off the map (the bar or the border right of it) starts no
        ; stroke when the pointer then moves onto the map.
        tst.w d5
        beq.s .located
        cmpi.w #304,d0
        bhs.s .off_map
        cmpi.w #192,d2
        blo.s .located
.off_map:
        move.w #1,TERRAIN_STROKE_BLOCK
.located:
        cmpi.w #304,d0
        bhs .outside
        cmpi.w #192,d2
        bhs .bar
        move.w d0,-(sp)
        moveq #-1,d0
        bsr bar_hover
        move.w (sp)+,d0
        move.w d0,d6
        lsr.w #4,d6
        move.w d2,d4
        lsr.w #4,d4
        move.w d6,d0
        add.w view_origin_x+PCREL(pc),d0
        cmp.w editor_map_width,d0
        bhs .outside
        move.w d4,d2
        add.w view_origin_y+PCREL(pc),d2
        cmp.w editor_map_height,d2
        bhs .outside
        cmp.w TERRAIN_CURSOR_X+PCREL(pc),d0
        bne.s .cursor
        cmp.w TERRAIN_CURSOR_Y+PCREL(pc),d2
        beq.s .index
.cursor:
        move.w d0,TERRAIN_CURSOR_X
        move.w d2,TERRAIN_CURSOR_Y
        ; Marker and Inspect describe the cell; the other tools only move X/Y.
        ori.w #4,TERRAIN_BAR_DIRTY
        cmpi.w #3,AUR_BASE+AUR_TOOL
        blo.s .index
        ori.w #1,TERRAIN_BAR_DIRTY
.index:
        mulu editor_map_width,d2
        add.l d0,d2
        move.w d2,d1
        add.w d2,d2
        move.w 0(a0,d2.w),d2
        cmpi.w #4,AUR_BASE+AUR_TOOL
        beq .idle
        cmpi.w #3,AUR_BASE+AUR_TOOL
        beq .marker
        tst.w d3
        bne .pick
        tst.w native_left_down
        beq .idle
        tst.w TERRAIN_STROKE_BLOCK
        bne .idle
        tst.w AUR_BASE+AUR_TOOL
        bne.s .fill
        tst.w TERRAIN_OP
        bne.s .paint
        bsr tu_begin
        bmi .invalid
.paint:
        andi.w #$FE00,d2
        or.w AUR_BASE+AUR_TILE+PCREL(pc),d2
        bsr tu_change
        bmi .invalid
        cmpi.w #2,d0
        beq .large
        tst.w d0
        beq .idle
        bsr aur_mark_edited
        bsr restore_item
        bsr paint_cell
        bsr op_clip_cell
        bsr publish_ring
        bsr terrain_objects
        ori.w #1,TERRAIN_BAR_DIRTY
        bra .idle
.fill:
        cmpi.w #1,AUR_BASE+AUR_TOOL
        bne .invalid
        tst.w d5
        beq .idle
        bsr terrain_end
        bmi .invalid
        move.w d1,d0
        swap d0
        move.w #4,d0
        bra .return
.tool:
        move.w d0,d1
        bsr terrain_end
        bmi .invalid
        move.w d1,AUR_BASE+AUR_TOOL
        move.w #1,TERRAIN_STROKE_BLOCK
        ori.w #1,TERRAIN_BAR_DIRTY
        cmpi.w #2,d1
        beq .object_page
        cmpi.w #3,d1
        bne .idle
        moveq #5,d0
        bra .return
.marker:
        moveq #0,d0
        tst.w d3
        bne.s .marker_prepare
        tst.w d5
        beq .idle
        moveq #1,d0
.marker_prepare:
        bsr marker_prepare
        bmi .invalid
        tst.w d0
        beq .idle
        cmpi.w #2,d0
        bne.s .marker_commit
        moveq #6,d0
        bra .return
.marker_commit:
        bsr tu_begin
        bmi .invalid
        bsr tu_change
        cmpi.w #1,d0
        bne .invalid
        bsr tu_end
        bmi .invalid
        bsr aur_mark_edited
        ori.w #1,TERRAIN_BAR_DIRTY
        bra .idle
.pick:
        bsr terrain_end
        bmi .invalid
        move.w #1,TERRAIN_STROKE_BLOCK
        andi.w #$1FF,d2
        cmpi.w #399,d2
        bhs .idle
        move.w d2,AUR_BASE+AUR_TILE
        ori.w #1,TERRAIN_BAR_DIRTY
        bra .idle
.bar:
        move.w d2,d1
        subi.w #192,d1
        bsr bar_hit
        bsr bar_hover
        tst.w d5
        beq .idle
        tst.w d0
        bmi .idle
        move.w d0,d1
        bsr terrain_end
        bmi .invalid
        move.w #1,TERRAIN_STROKE_BLOCK
        cmpi.w #BAR_INSPECT,d1
        bhi.s .command
        ; Clicking the active Paint or Fill tool again chooses its tile.
        cmp.w AUR_BASE+AUR_TOOL,d1
        bne.s .choose_tool
        cmpi.w #BAR_FILL,d1
        bls.s .tiles
.choose_tool:
        move.w d1,d0
        bra .tool
.command:
        subi.w #BAR_UNDO,d1
        add.w d1,d1
        move.w .bar_actions(pc,d1.w),d1
        jmp .bar_actions(pc,d1.w)
.bar_actions:
        dc.w .undo-.bar_actions,.tiles-.bar_actions,.validation-.bar_actions
        dc.w .test-.bar_actions,.save-.bar_actions,.menu-.bar_actions
        dc.w .tiles-.bar_actions
.save:
        moveq #1,d0
        bra .return
.test:
        moveq #11,d0
        bra .return
.validation:
        moveq #10,d0
        bra .return
.palette:
        bsr terrain_end
        bmi .invalid
        moveq #9,d0
        bra .return
.tiles:
        bsr terrain_end
        bmi .invalid
        moveq #3,d0
        bra .return
.menu:
        bsr terrain_end
        bmi.s .invalid
        moveq #2,d0
        bra.s .return
.undo:
        bsr terrain_end
        bmi.s .invalid
        move.w #1,TERRAIN_STROKE_BLOCK
        tst.w AUR_BASE+AUR_UNDO_COUNT
        beq.s .idle
        move.w AUR_BASE+AUR_UNDO_NEXT+PCREL(pc),d0
        subq.w #1,d0
        andi.w #255,d0
        lsl.w #4,d0
        move.w 0(a1,d0.w),d0
        andi.w #$7FFF,d0
        cmpi.w #1,d0
        bne.s .object_page
        bsr tu_undo
        bmi.s .invalid
        tst.w d0
        beq.s .idle
        bsr aur_mark_edited
        bsr render_view
        bsr.s terrain_objects
        ori.w #1,TERRAIN_BAR_DIRTY
        bra.s .idle
.object_page:
        moveq #8,d0
        bra.s .return
.large:
        moveq #0,d0
        move.w d1,d0
        swap d0
        move.w #7,d0
        bra.s .return
.outside:
        moveq #-1,d0
        bsr bar_hover
.idle:
        tst.w TERRAIN_BAR_DIRTY
        beq.s .unchanged
        bsr draw_toolbar
.unchanged:
        moveq #0,d0
        bra.s .return
.invalid:
        moveq #-1,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

terrain_context:
        lea editor_map_grid,a0
        lea EDITOR_UNDO_BASE+PCREL(pc),a1
        lea AUR_BASE+AUR_UNDO_NEXT+PCREL(pc),a2
        lea TERRAIN_OP+PCREL(pc),a3
        moveq #0,d7
        move.w editor_map_width,d7
        mulu editor_map_height,d7
        rts

terrain_objects:
        bra op_draw_placed

terrain_end:
        movem.l d1-d7/a0-a6,-(sp)
        bsr.s terrain_context
        moveq #0,d0
        tst.w TERRAIN_OP
        beq.s .return
        bsr tu_end
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; Append exactly D1+1 zero-padded decimal digits, maximum value7499.
terrain_digits:
        movea.l a0,a1
        adda.w d1,a1
        addq.l #1,a1
        move.l a1,-(sp)
.digit:
        andi.l #$FFFF,d0
        divu #10,d0
        swap d0
        addi.b #'0',d0
        move.b d0,-(a1)
        swap d0
        dbra d1,.digit
        movea.l (sp)+,a0
        rts

        include "bar.s"

; Terrain bar texts: the cell readout, the tile class, the marker class or
; the inspect data, the phase and unsaved state, or the SAVED notice.
; Preserves all registers.
bar_compose:
        movem.l d0-d2/a0-a1,-(sp)
        bsr bar_compose_xy
        tst.w AUR_BASE+AUR_UNDO_COUNT
        bne.s .undo
        moveq #BAR_UNDO,d0
        moveq #UI_DISABLED,d1
        bsr bar_set_state
.undo:
        lea BAR_INFO_TEXT,a0
        lea bar_saved_text(pc),a1
        cmpi.w #-1,TERRAIN_CURSOR_X
        beq.s .notice
        cmpi.w #4,AUR_BASE+AUR_TOOL
        beq.s .inspect
        cmpi.w #3,AUR_BASE+AUR_TOOL
        beq.s .marker
        lea bar_tile_text(pc),a1
        bsr bar_append
        move.w AUR_BASE+AUR_TILE,d0
        moveq #2,d1
        bsr bar_digits
        move.b #' ',(a0)+
        move.w AUR_BASE+AUR_TILE,d0
        bsr bar_class_name
        bsr bar_append
        bra.s .phase
.marker:
        lea bar_marker_text(pc),a1
        bsr bar_append
        bsr terrain_marker_word
        lsr.w #8,d0
        lsr.w #5,d0
        moveq #0,d1
        bsr bar_digits
.phase:
        bsr bar_append_phase
        bra.s .done
.inspect:
        bsr terrain_inspect_compose
        bra.s .done
.notice:
        bsr bar_append
        clr.b (a0)
.done:
        movem.l (sp)+,d0-d2/a0-a1
        rts

; The selected tile (or the tile under the cursor for Marker and Inspect)
; and, for Inspect, the BHT mask of that tile. Preserves all registers.
bar_band_extra:
        movem.l d0-d7/a0-a2,-(sp)
        moveq #0,d0
        move.w AUR_BASE+AUR_TILE,d0
        cmpi.w #3,AUR_BASE+AUR_TOOL
        blo.s .thumbnail
        bsr.s terrain_marker_word
        andi.l #$1FF,d0
.thumbnail:
        move.l d0,d7
        cmpi.w #399,d0
        bhs.s .return
        lsl.l #7,d0
        lea editor_tile_data,a0
        adda.l d0,a0
        lea BAR_BITMAP+BAR_UI_ROWS*UI_ROW_BYTES,a1
        moveq #16,d1
        jsr editor_tile_blit
        cmpi.w #4,AUR_BASE+AUR_TOOL
        bne.s .return
        bsr inspect_mask
.return:
        movem.l (sp)+,d0-d7/a0-a2
        rts

bar_tile_text: dc.b "Tile ",0
bar_marker_text: dc.b "Marker class ",0
        even
; Cursor bounds have been checked by terrain_input; acquire initializes0,0.
terrain_marker_word:
        moveq #0,d0
        move.w TERRAIN_CURSOR_Y+PCREL(pc),d0
        mulu editor_map_width,d0
        add.w TERRAIN_CURSOR_X+PCREL(pc),d0
        add.w d0,d0
        move.l a1,-(sp)
        lea editor_map_grid,a1
        move.w 0(a1,d0.w),d0
        movea.l (sp)+,a1
        rts
terrain_finish:
