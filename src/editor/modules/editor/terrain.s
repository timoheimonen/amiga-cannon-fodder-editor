; Cannon Fodder In-Game Level Editor V1.2.5
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Terrain input, painting, grouped undo and tool dispatch.
; Persistent state is AUR; UI0..79 is transient and dead during a modal.
        xdef terrain_input,terrain_end
        xdef terrain_start,terrain_finish
terrain_start:

; D0.w=0 idle,1 SAVE,2 MENU,3 TILE,4 FILL,5 unused,6 limit,
; 7 large stroke or rectangle confirmation,8 object view/Undo,
; 9 object palette,10 Check,11 Test,12 Help,-1 invariant.
; For 4 and 7 D0.high=cell.
; Other registers preserved. Function-key translated edge codes start at $D0.
; The cursor sprite has bitmap X=logical X+16, with offsets zeroed by view.
terrain_input:
        movem.l d1-d7/a0-a6,-(sp)
        bsr terrain_context
        move.w native_left_pressed,d5
        clr.w native_left_pressed
        move.w native_right_pressed,d3
        clr.w native_right_pressed
        ; A press ends the notice of a copy or a recall.
        move.w d5,d0
        or.w d3,d0
        beq.s .noticed
        tst.w TERRAIN_BLOCK_NOTICE
        beq.s .noticed
        clr.w TERRAIN_BLOCK_NOTICE
        ori.w #1,TERRAIN_BAR_DIRTY
.noticed:
        move.w native_last_key,d0
        clr.w native_last_key
        cmpi.w #$C5,d0
        beq .menu
        ; The Help key.
        cmpi.w #$DF,d0
        beq .help
        cmpi.w #'U',d0
        beq .undo
        cmpi.w #'V',d0
        beq .recall
        cmpi.w #'T',d0
        beq .tiles
        cmpi.w #'O',d0
        beq .palette
        ; C, G and S act as the Check, Test and Save buttons.
        moveq #BAR_CHECK,d1
        cmpi.w #'C',d0
        beq .button
        moveq #BAR_TEST,d1
        cmpi.w #'G',d0
        beq .button
        moveq #BAR_SAVE,d1
        cmpi.w #'S',d0
        beq .button
        subi.w #$D0,d0
        cmpi.w #4,d0
        bls .tool
        bsr terrain_scroll
        bmi .invalid
        ; The selection of an area ends when its button rises: the right
        ; button copies the area, the left one paints it.
        move.w TERRAIN_SELECT,d0
        beq.s .selected
        subq.w #1,d0
        bne.s .rectangle
        tst.w native_right_down
        bne.s .selected
        bsr block_copy
        bra.s .selected
.rectangle:
        tst.w d3
        beq.s .held
        ; The right button gives the rectangle up.
        clr.w TERRAIN_SELECT
        moveq #0,d3
        ori.w #1,TERRAIN_BAR_DIRTY
        bra.s .selected
.held:
        tst.w native_left_down
        bne.s .selected
        bsr block_paint
        bmi .invalid
        beq.s .selected
        cmpi.w #2,d0
        beq .large_area
        bsr aur_mark_edited
        bsr render_view
        bsr terrain_objects
.selected:
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
        bclr #0,TERRAIN_ON_BAR-EDITOR_UI_BASE(a3)
        beq.s .on_map
        ori.w #1,TERRAIN_BAR_DIRTY
.on_map:
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
        tst.w TERRAIN_MARKER_HINT
        beq.s .hinted
        subq.w #1,TERRAIN_MARKER_HINT
.hinted:
        ; Marker and Inspect describe the cell and a selection its size; the
        ; other tools only move X/Y.
        ori.w #4,TERRAIN_BAR_DIRTY
        tst.w TERRAIN_SELECT
        bne.s .described
        cmpi.w #3,AUR_BASE+AUR_TOOL
        blo.s .index
.described:
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
        tst.w AUR_BASE+AUR_TOOL
        bne .tile
        ; Paint: an area is being selected, Shift with the right button
        ; starts to select one, or the brush is a block.
        tst.w TERRAIN_SELECT
        bne .idle
        tst.w d3
        beq.s .brush
        move.w native_raw_key,d4
        lsr.w #1,d4
        cmpi.w #$30,d4
        bne .pick
        moveq #1,d4
.select:
        bsr terrain_end
        bmi .invalid
        move.w #1,TERRAIN_STROKE_BLOCK
        move.l TERRAIN_CURSOR_X,TERRAIN_SELECT_X
        move.w d4,TERRAIN_SELECT
        ori.w #1,TERRAIN_BAR_DIRTY
        bra .idle
.brush:
        tst.w TERRAIN_BLOCK_W
        beq.s .tile
        ; A block is stamped once per press.
        tst.w d5
        beq .idle
        tst.w TERRAIN_STROKE_BLOCK
        bne .idle
        move.w #1,TERRAIN_STROKE_BLOCK
        bsr terrain_end
        bmi .invalid
        bsr block_stamp
        bmi .invalid
        beq .idle
        bsr aur_mark_edited
        bsr render_view
        bsr terrain_objects
        ori.w #1,TERRAIN_BAR_DIRTY
        bra .idle
.tile:
        tst.w d3
        bne .pick
        tst.w native_left_down
        beq .idle
        tst.w TERRAIN_STROKE_BLOCK
        bne .idle
        tst.w AUR_BASE+AUR_TOOL
        bne .fill
        ; Shift held when the button goes down starts a rectangle.
        tst.w d5
        beq.s .stroke
        move.w native_raw_key,d0
        lsr.w #1,d0
        cmpi.w #$30,d0
        bne.s .stroke
        moveq #2,d4
        bra .select
.stroke:
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
        ; The key V: the copied block becomes Paint's brush.
.recall:
        clr.w TERRAIN_SELECT
        bsr block_recall
        tst.w TERRAIN_BLOCK_W
        bne.s .recalled
        bsr terrain_end
        bmi .invalid
        move.w #1,TERRAIN_STROKE_BLOCK
        bra .idle
.recalled:
        moveq #0,d0
        bra.s .tool_chosen
.tool:
        ; A block is the brush only until another tool is chosen.
        clr.l TERRAIN_BLOCK_W
        clr.w TERRAIN_SELECT
.tool_chosen:
        move.w d0,d1
        bsr terrain_end
        bmi .invalid
        move.w AUR_BASE+AUR_TOOL,d0
        move.w d1,AUR_BASE+AUR_TOOL
        move.w #1,TERRAIN_STROKE_BLOCK
        ori.w #1,TERRAIN_BAR_DIRTY
        cmpi.w #2,d1
        beq .object_page
        ; Choosing Marker shows what markers do in the bar, not in a dialog.
        cmpi.w #3,d1
        bne.s .other_tool
        move.w #2,TERRAIN_MARKER_HINT
        cmpi.w #3,d0
        beq .idle
        bra.s .markers
.other_tool:
        cmpi.w #3,d0
        bne .idle
        ; The map shows the marker cells in the Marker tool alone.
.markers:
        bsr render_view
        bsr terrain_objects
        bra .idle
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
        bsr restore_item
        bsr paint_cell
        bsr op_clip_cell
        bsr publish_ring
        bsr terrain_objects
        ori.w #1,TERRAIN_BAR_DIRTY
        bra .idle
.pick:
        bsr terrain_end
        bmi .invalid
        move.w #1,TERRAIN_STROKE_BLOCK
        ; The brush is one tile again.
        clr.l TERRAIN_BLOCK_W
        ori.w #1,TERRAIN_BAR_DIRTY
        andi.w #$1FF,d2
        cmpi.w #399,d2
        bhs .idle
        move.w d2,AUR_BASE+AUR_TILE
        bra .idle
.bar:
        move.w d2,d1
        subi.w #192,d1
        bsr bar_hit
        bsr bar_hover
        bset #0,TERRAIN_ON_BAR-EDITOR_UI_BASE(a3)
        bne.s .on_bar
        ori.w #1,TERRAIN_BAR_DIRTY
.on_bar:
        tst.w d5
        beq .idle
        tst.w d0
        bmi .idle
        move.w d0,d1
.button:
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
        bmi .invalid
        moveq #2,d0
        bra .return
.help:
        bsr terrain_end
        bmi .invalid
        moveq #12,d0
        bra .return
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
        clr.w AREA_PENDING
.large_area:
        moveq #0,d0
        move.w d1,d0
        swap d0
        move.w #7,d0
        bra.s .return
.outside:
        moveq #-1,d0
        bsr bar_hover
.idle:
        bsr block_frame_update
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

; Terrain bar texts: the cell readout, the tile class or the block's size,
; the marker class (the marker count while the pointer is on the bar) or the
; inspect data, the phase and unsaved state, or a notice.
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
        ; Why a copy or a recall did nothing, or the size of the area being
        ; selected or of the block that is the brush.
        move.w TERRAIN_BLOCK_NOTICE,d0
        beq.s .block
        add.w d0,d0
        lea block_notices(pc),a1
        adda.w -2(a1,d0.w),a1
        bra .notice
.block:
        bsr block_compose
        bne .phase
        lea bar_saved_text(pc),a1
        cmpi.w #-1,TERRAIN_CURSOR_X
        beq .notice
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
        lea bar_marker_hint(pc),a1
        tst.w TERRAIN_MARKER_HINT
        bne.s .notice
        btst #0,TERRAIN_ON_BAR
        bne.s .marker_total
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
; On the tool bar the line counts the phase's marker cells of the ten.
.marker_total:
        lea bar_markers_text(pc),a1
        bsr bar_append
        bsr.s marker_count
        bsr bar_number
        move.b #'/',(a0)+
        moveq #10,d0
        bsr bar_number
        bra.s .phase

; D0.w = the number of cells with a marker. Preserves other registers.
marker_count:
        movem.l d1/a0,-(sp)
        lea editor_map_grid,a0
        move.w editor_map_width,d1
        mulu editor_map_height,d1
        moveq #0,d0
        bra.s .next
.cell:
        cmpi.w #$2000,(a0)+
        blo.s .next
        addq.w #1,d0
.next:
        dbra d1,.cell
        movem.l (sp)+,d1/a0
        rts

bar_markers_text: dc.b "Markers ",0
        even

; A2 = the graphics of a cell's tile, D1.w = the cell's map word, D4/D6 =
; the cell's row and column in the view. In the Marker tool a cell with a
; marker class is drawn with a frame and its class number: A2 then points
; at a marked copy of the tile. In the other tools a cell on the edge of the
; block frame gets that edge (block_frame_tile). The outer frame and
; the number have the bar's text colour and the inner frame and the number's
; box colour 0, so the mark shows on every tile.
; Clobbers D0/D1/A0/A1; preserves the other registers.
MARKER_TILE     equ edtr_state_end
        ifgt MARKER_TILE+128-EDITOR_READBACK_BASE-EDITOR_READBACK_BYTES
        fail "The marked tile exceeds readback"
        endif
marker_tile:
        cmpi.w #3,AUR_BASE+AUR_TOOL
        bne block_frame_tile
        rol.w #3,d1
        andi.w #7,d1
        bne.s .marked
.plain:
        rts
.marked:
        movem.l d2-d6/a3,-(sp)
        ; The game's blitter copy of the previous marked cell may still run.
        btst #6,$DFF002
.blitter:
        btst #6,$DFF002
        bne.s .blitter
        mulu #7,d1
        lea marker_digits-7(pc),a3
        adda.w d1,a3
        lea marker_rows(pc),a0
        lea MARKER_TILE,a1
        moveq #0,d3
.row:
        move.w (a0)+,d0
        move.w (a0)+,d2
        ; The number's seven rows start two rows down.
        move.w d3,d4
        subq.w #4,d4
        cmpi.w #12,d4
        bhi.s .planes
        moveq #0,d4
        move.b (a3)+,d4
        lsl.w #8,d4
        add.w d4,d4
        or.w d4,d2
.planes:
        bsr.s marker_planes
        addq.w #2,d3
        cmpi.w #32,d3
        blo.s .row
        movea.l a1,a2
        movem.l (sp)+,d2-d6/a3
        rts

; Write one pixel row of a marked tile: D3.w = the row's offset in a plane,
; A2 = the tile, A1 = the copy, D0.w = the pixels the mark replaces and
; D2.w = those of them in the text colour. Clobbers D0/D1/D4-D6.
marker_planes:
        not.w d0
        move.w terrain_font_ink+PCREL(pc),d5
        move.w d3,d4
        moveq #3,d1
.plane:
        move.w 0(a2,d4.w),d6
        and.w d0,d6
        lsr.w #1,d5
        bcc.s .store
        or.w d2,d6
.store:
        move.w d6,0(a1,d4.w)
        addi.w #32,d4
        dbra d1,.plane
        rts

; Per pixel row: the pixels the mark replaces, and those of them in the text
; colour. The number's box is seven pixels wide and nine high.
marker_rows:
        dc.w $FFFF,$FFFF,$FFFF,$8001
        dc.w $FF03,$8001,$FF03,$8001,$FF03,$8001,$FF03,$8001
        dc.w $FF03,$8001,$FF03,$8001,$FF03,$8001,$FF03,$8001
        dc.w $C003,$8001,$C003,$8001,$C003,$8001,$C003,$8001
        dc.w $FFFF,$8001,$FFFF,$FFFF
; The numbers 1 to 7, five pixels wide and seven high.
marker_digits:
        dc.b $04,$0C,$04,$04,$04,$04,$0E
        dc.b $0E,$11,$01,$02,$04,$08,$1F
        dc.b $1E,$01,$01,$0E,$01,$01,$1E
        dc.b $02,$06,$0A,$12,$1F,$02,$02
        dc.b $1F,$10,$1E,$01,$01,$11,$0E
        dc.b $06,$08,$10,$1E,$11,$11,$0E
        dc.b $1F,$01,$02,$04,$08,$08,$08
        even

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
bar_marker_hint: dc.b "Markers change enemy sight: test the phase.",0
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
        include "block.s"

terrain_finish:
