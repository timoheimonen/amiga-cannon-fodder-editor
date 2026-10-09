; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

OBJECT_LAST_RAW equ EDITOR_UI_BASE+80
OBJECT_DRAG_INDEX equ EDITOR_UI_BASE+82
OBJECT_GRAB_X equ EDITOR_UI_BASE+84
OBJECT_GRAB_Y equ EDITOR_UI_BASE+86
        ifgt OBJECT_GRAB_Y+2-EDITOR_UI_BASE-EDITOR_UI_BYTES
        fail "Object input state exceeds UI scratch"
        endif
; D0=0 idle,1 Save,2 Menu,3 Tiles,4 Objects,5 terrain Undo,6 tool change.
; Negative results leave the restored view for EDTR's status receiver.
; Raw Delete is Amiga key$46; a held key produces one deletion until released.
object_input:
        movem.l d1-d7/a0-a6,-(sp)
        move.w native_left_pressed,d5
        clr.w native_left_pressed
        move.w native_right_pressed,d4
        clr.w native_right_pressed
        move.w native_last_key,d0
        clr.w native_last_key
        cmpi.w #$C5,d0
        bne.s .key
        tst.w OBJECT_DRAG_INDEX
        bpl .cancel_drag
        bra .menu
.key:
        cmpi.w #'U',d0
        beq .undo
        cmpi.w #'T',d0
        beq .tiles
        cmpi.w #'O',d0
        beq .objects
        subi.w #$D0,d0
        cmpi.w #4,d0
        bhi.s .raw
        cmpi.w #2,d0
        beq.s .raw
        move.w d0,AUR_BASE+AUR_TOOL
        moveq #6,d0
        bra .return
.raw:
        move.w native_raw_key,d0
        move.w OBJECT_LAST_RAW,d1
        move.w d0,OBJECT_LAST_RAW
        cmp.w d1,d0
        beq.s .scroll
        cmpi.w #$46,d0
        beq .delete
.scroll:
        tst.w d4
        beq.s .scroll_step
        tst.w OBJECT_DRAG_INDEX
        bpl .cancel_drag
.scroll_step:
        bsr terrain_scroll
        bmi .error
        move.w native_mouse_x,d0
        addi.w #16,d0
        cmpi.w #304,d0
        bhs .outside
        move.w native_mouse_y,d1
        cmpi.w #192,d1
        bhs .bar
        move.w d0,-(sp)
        moveq #-1,d0
        bsr bar_hover
        move.w (sp)+,d0
        move.w view_origin_x,d2
        lsl.w #4,d2
        add.w d0,d2
        move.w view_origin_y,d3
        lsl.w #4,d3
        add.w d1,d3
        lsr.w #4,d0
        lsr.w #4,d1
        add.w view_origin_x,d0
        add.w view_origin_y,d1
        cmp.w TERRAIN_CURSOR_X,d0
        bne.s .cursor
        cmp.w TERRAIN_CURSOR_Y,d1
        beq.s .map_actions
.cursor:
        move.w d0,TERRAIN_CURSOR_X
        move.w d1,TERRAIN_CURSOR_Y
        ori.w #4,TERRAIN_BAR_DIRTY
.map_actions:
        tst.w OBJECT_DRAG_INDEX
        bpl .drag
        tst.w d4
        bne.s .hit
        tst.w d5
        beq .preview
.hit:
        move.w d2,d0
        move.w d3,d1
        bsr object_hit
        tst.w d0
        bmi.s .empty
        bsr restore_item
        clr.w preview_state+pv_count
        move.w d0,AUR_BASE+AUR_OBJECT_INDEX
        move.w d0,d1
        mulu #10,d1
        lea EDITOR_SPT_BASE,a0
        adda.w d1,a0
        move.w 8(a0),AUR_BASE+AUR_OBJECT_TYPE
        ori.w #1,TERRAIN_BAR_DIRTY
        tst.w d4
        bne .preview
        move.w d0,OBJECT_DRAG_INDEX
        sub.w 4(a0),d2
        subi.w #16,d2
        sub.w 6(a0),d3
        move.w d2,OBJECT_GRAB_X
        move.w d3,OBJECT_GRAB_Y
        bra .repaint
.empty:
        tst.w d4
        bne .preview
        bsr restore_item
        bsr object_clamp
        moveq #0,d1
        move.w AUR_BASE+AUR_OBJECT_TYPE,d0
        lsl.w #2,d0
        lea ot_shared_recipes(pc),a0
        tst.b 0(a0,d0.w)
        bmi.s .insert
        move.w EDITOR_METADATA_BASE+CFMD_SPT_BYTES,d1
        divu #10,d1
.insert:
        moveq #2,d0
        bsr object_edit
        ; On the map, a refused insertion means the phase is full.
        cmpi.l #-1,d0
        beq .no_room
        tst.l d0
        bmi .edit_refused
        bra .repaint
.drag:
        sub.w OBJECT_GRAB_X,d2
        sub.w OBJECT_GRAB_Y,d3
        bsr object_clamp
        tst.w native_left_down
        bne.s .preview
        move.w OBJECT_DRAG_INDEX,d1
        move.w #-1,OBJECT_DRAG_INDEX
        bsr restore_item
        moveq #1,d0
        bsr object_edit
        ; A refused move (a companion would leave the map) leaves the
        ; object where it was.
        cmpi.l #-1,d0
        beq .repaint
        tst.l d0
        bmi .edit_refused
        bra .repaint
.preview:
        bsr object_clamp
        moveq #0,d0
        moveq #0,d1
        move.w d2,d0
        move.w d3,d1
        ext.l d0
        ext.l d1
        bsr object_preview
        bra .idle
.bar:
        bsr restore_item
        tst.w OBJECT_DRAG_INDEX
        bpl.s .outside
        subi.w #192,d1
        bsr bar_hit
        bsr bar_hover
        tst.w d5
        beq .idle
        tst.w d0
        bmi .idle
        cmpi.w #BAR_INSPECT,d0
        bhi.s .bar_command
        ; The active Object tool opens the object page; the others switch.
        cmpi.w #BAR_OBJECT,d0
        beq .objects
        move.w d0,AUR_BASE+AUR_TOOL
        moveq #6,d0
        bra .return
.bar_command:
        subi.w #BAR_UNDO,d0
        add.w d0,d0
        move.w .bar_actions(pc,d0.w),d0
        jmp .bar_actions(pc,d0.w)
.bar_actions:
        dc.w .undo-.bar_actions,.delete-.bar_actions,.validation-.bar_actions
        dc.w .test-.bar_actions,.save-.bar_actions,.menu-.bar_actions
.save:
        moveq #1,d0
        bra .return
.test:
        moveq #8,d0
        bra .return
.validation:
        moveq #7,d0
        bra .return
.outside:
        move.w d0,-(sp)
        moveq #-1,d0
        bsr bar_hover
        move.w (sp)+,d0
        bsr restore_item
        tst.w OBJECT_DRAG_INDEX
        bmi.s .idle
        tst.w native_left_down
        bne.s .idle
.cancel_drag:
        bsr restore_item
        move.w #-1,OBJECT_DRAG_INDEX
        bra.s .repaint
.undo:
        tst.w OBJECT_DRAG_INDEX
        bpl.s .cancel_drag
        bsr restore_item
        bsr object_undo_edit
        tst.l d0
        bmi.s .error
        beq.s .idle
        cmpi.w #2,d0
        bne.s .repaint
        moveq #5,d0
        bra.s .return
.delete:
        tst.w OBJECT_DRAG_INDEX
        bpl.s .cancel_drag
        move.w AUR_BASE+AUR_OBJECT_INDEX,d1
        cmpi.w #-1,d1
        beq.s .idle
        bsr restore_item
        moveq #0,d0
        bsr object_edit
        cmpi.l #-2,d0
        bne.s .deleted
        moveq #OBJECT_LAST_ITEM,d0
        bra.s .return
.deleted:
        tst.l d0
        bmi.s .edit_refused
        beq.s .idle
.repaint:
        bsr render_view
        bsr terrain_objects
        ori.w #1,TERRAIN_BAR_DIRTY
.idle:
        bsr object_ring_guard
        tst.w TERRAIN_BAR_DIRTY
        beq.s .quiet
        bsr draw_toolbar
.quiet:
        moveq #0,d0
        bra.s .return
.menu:
        moveq #2,d0
        bra.s .return
.tiles:
        moveq #3,d0
        bra.s .return
.objects:
        moveq #4,d0
        bra.s .return
.edit_refused:
        moveq #OBJECT_EDIT_REFUSED,d0
        bra.s .return
.no_room:
        moveq #OBJECT_NO_ROOM,d0
        bra.s .return
.error:
        moveq #EDTR_VISUAL_ERROR,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; Keep the anchor D2/D3 (world X/Y) where an object can stand: X from 16,
; the SPT X bias, Y from 0, both within the map. Preserves other registers.
object_clamp:
        move.l d0,-(sp)
        cmpi.w #16,d2
        bge.s .left
        moveq #16,d2
.left:
        move.w editor_map_width,d0
        lsl.w #4,d0
        subq.w #1,d0
        cmp.w d0,d2
        ble.s .right
        move.w d0,d2
.right:
        tst.w d3
        bpl.s .top
        moveq #0,d3
.top:
        move.w editor_map_height,d0
        lsl.w #4,d0
        subq.w #1,d0
        cmp.w d0,d3
        ble.s .bottom
        move.w d0,d3
.bottom:
        move.l (sp)+,d0
        rts

; The placed renderer clears pv_count after using the shared part scratch.
; Rebuild only then; otherwise preview_update's unchanged check preserves idle.
object_preview:
        movem.l d0-d7/a0-a6,-(sp)
        tst.w preview_state+pv_count
        bne.s .ready
        move.w AUR_BASE+AUR_OBJECT_TYPE,d0
        lea parts,a0
        lea editor_game_sprites,a1
        bsr op_parts
        tst.l d0
        bmi.s .return
        cmpi.w #$3C,AUR_BASE+AUR_OBJECT_TYPE
        bne.s .set
        move.w OBJECT_DRAG_INDEX,d1
        bmi.s .set
        mulu #10,d1
        lea EDITOR_SPT_BASE,a0
        adda.w d1,a0
        cmpi.w #$7FEF,14(a0)
        bhi.s .one_part
        tst.w 16(a0)
        bmi.s .one_part
        move.w 14(a0),d1
        sub.w 4(a0),d1
        add.w d1,parts+12
        move.w 16(a0),d1
        sub.w 6(a0),d1
        add.w d1,parts+14
        bra.s .set
.one_part:
        moveq #1,d0
.set:
        bsr set_item
.ready:
        movem.l (sp)+,d0-d7/a0-a6
        bra update_item
.return:
        movem.l (sp)+,d0-d7/a0-a6
        rts

; The final display row fetch can cross into the 40-byte guard before the
; copper resets its pointer. Dynamic preview save/restore owns only the ring;
; mirror changed row-zero words here after all canvas writes. Equal words stay
; untouched, so stationary input performs no display writes.
object_ring_guard:
        movem.l d0-d2/a0-a1,-(sp)
        bsr.s exit_ui_blitter_idle
        lea CANVAS,a0
        lea CANVAS+RING_BYTES,a1
        moveq #3,d2
.plane:
        moveq #ROW_BYTES/4-1,d1
.word:
        move.l (a0)+,d0
        cmp.l (a1),d0
        beq.s .same
        move.l d0,(a1)
.same:
        addq.l #4,a1
        dbra d1,.word
        lea DISPLAY_PLANE-ROW_BYTES(a0),a0
        lea DISPLAY_PLANE-ROW_BYTES(a1),a1
        dbra d2,.plane
        movem.l (sp)+,d0-d2/a0-a1
        rts
