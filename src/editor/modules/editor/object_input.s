; Cannon Fodder In-Game Level Editor V1.2.6
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

OBJECT_LAST_RAW equ EDITOR_UI_BASE+80
OBJECT_DRAG_INDEX equ EDITOR_UI_BASE+82
OBJECT_GRAB_X equ EDITOR_UI_BASE+84
OBJECT_GRAB_Y equ EDITOR_UI_BASE+86
        ifgt OBJECT_GRAB_Y+2-EDITOR_UI_BASE-EDITOR_UI_BYTES
        fail "Object input state exceeds UI scratch"
        endif
; D0=0 idle,1 Save,2 Menu,3 Tiles,4 Objects,5 terrain Undo,6 tool change,
; 7 Check,8 Test.
; Negative results leave the restored view for EDTR's status receiver.
; Raw Delete is Amiga key$46; a held key produces one deletion until released.
object_input:
        movem.l d1-d7/a0-a6,-(sp)
        move.w native_left_pressed,d5
        clr.w native_left_pressed
        move.w native_right_pressed,d4
        clr.w native_right_pressed
        move.w d5,d0
        or.w d4,d0
        beq.s .noticed
        tst.w TERRAIN_BLOCK_NOTICE
        beq.s .noticed
        clr.w TERRAIN_BLOCK_NOTICE
        ori.w #1,TERRAIN_BAR_DIRTY
.noticed:
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
        cmpi.w #'Y',d0
        beq .redo
        cmpi.w #'T',d0
        beq .tiles
        cmpi.w #'O',d0
        beq .objects
        ; V recalls a copied terrain block and switches to Paint.
        moveq #9,d1
        cmpi.w #'V',d0
        beq .command
        ; C, G and S act as the Check, Test and Save buttons.
        moveq #7,d1
        cmpi.w #'C',d0
        beq .command
        moveq #8,d1
        cmpi.w #'G',d0
        beq .command
        moveq #1,d1
        cmpi.w #'S',d0
        beq .command
        ; The Help key or H leaves as a message does; M opens Overview.
        moveq #EDTR_HELP,d1
        cmpi.w #$DF,d0
        beq .command
        cmpi.w #'H',d0
        beq .command
        cmpi.w #'M',d0
        beq .overview
        ; Tab selects the next object (Shift+Tab or B selects the previous).
        cmpi.w #$C2,d0
        beq .tab
        cmpi.w #'B',d0
        beq .prev
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
        bclr #0,TERRAIN_ON_BAR
        beq.s .on_map
        ori.w #1,TERRAIN_BAR_DIRTY
.on_map:
        move.w d0,-(sp)
        moveq #-1,d0
        bsr bar_hover
        bsr bar_press_cancel
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
        tst.w TERRAIN_CURSOR_X
        bpl.s .cursor_store
        ori.w #1,TERRAIN_BAR_DIRTY
.cursor_store:
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
        bne .repaint
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
        ; object where it was and says why in the bar.
        cmpi.l #-1,d0
        beq.s .move_refused
        tst.l d0
        bmi .edit_refused
        bra .repaint
.move_refused:
        move.w #1,TERRAIN_BLOCK_NOTICE
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
        bset #0,TERRAIN_ON_BAR
        bne.s .on_bar
        ori.w #1,TERRAIN_BAR_DIRTY
.on_bar:
        bsr bar_press_step
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
; A command key: D1.w is its result. It ends a drag instead, as Esc does.
.command:
        tst.w OBJECT_DRAG_INDEX
        bpl.s .cancel_drag
        move.w d1,d0
        bra .return
.outside:
        move.w d0,-(sp)
        moveq #-1,d0
        bsr bar_hover
        bsr bar_press_cancel
        move.w (sp)+,d0
        bsr restore_item
        tst.w OBJECT_DRAG_INDEX
        bmi .idle
        tst.w native_left_down
        bne .idle
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
        bmi .error
        beq.s .idle
        cmpi.w #2,d0
        bne.s .repaint
        moveq #5,d0
        bra .return
.redo:
        tst.w OBJECT_DRAG_INDEX
        bpl.s .cancel_drag
        bsr restore_item
        bsr object_redo_edit
        tst.l d0
        bmi .error
        beq.s .idle
        cmpi.w #2,d0
        bne.s .repaint
        moveq #10,d0
        bra .return
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
        bra .return
.deleted:
        tst.l d0
        bmi .edit_refused
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
        bra .return
.menu:
        moveq #2,d0
        bra .return
.overview:
        tst.w OBJECT_DRAG_INDEX
        bpl .cancel_drag
        bsr overview_show
        bra .idle
.tiles:
        moveq #3,d0
        bra .return
.objects:
        moveq #4,d0
        bra .return
.edit_refused:
        moveq #OBJECT_EDIT_REFUSED,d0
        bra .return
.no_room:
        bsr object_counts
        move.w AUR_BASE+AUR_OBJECT_TYPE,d3
        bne.s .chk_parts
        cmpi.w #8,d2
        blo.s .chk_parts
        moveq #OBJECT_NO_SQUAD,d0
        bra.s .return
.chk_parts:
        lsl.w #2,d3
        lea ot_shared_recipes(pc),a0
        move.b 0(a0,d3.w),d4
        moveq #3,d3
        and.w d4,d3
        addq.w #1,d3
        add.w d3,d0
        cmpi.w #43,d0
        bls.s .chk_units
        moveq #OBJECT_NO_PARTS,d0
        bra.s .return
.chk_units:
        tst.b d4
        bpl.s .generic_room
        add.w d3,d1
        cmpi.w #30,d1
        bls.s .generic_room
        moveq #OBJECT_NO_UNITS,d0
        bra.s .return
.generic_room:
        moveq #OBJECT_NO_ROOM,d0
        bra.s .return
.error:
        moveq #EDTR_VISUAL_ERROR,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
; Tab: next object (Shift+Tab or B: previous object), selected and brought
; to the middle of the view. Ends a drag instead, as a command key does.
.tab:
        move.w OBJECT_LAST_RAW,d1
        lsr.w #1,d1
        cmpi.w #$30,d1
        beq.s .prev
.next:
        tst.w OBJECT_DRAG_INDEX
        bpl .cancel_drag
        bsr object_next
        bra.s .focus_found
.prev:
        tst.w OBJECT_DRAG_INDEX
        bpl .cancel_drag
        bsr object_prev
.focus_found:
        bmi .idle
        bsr restore_item
        clr.w preview_state+pv_count
        move.w d0,AUR_BASE+AUR_OBJECT_INDEX
        move.w 8(a0),AUR_BASE+AUR_OBJECT_TYPE
        move.w 4(a0),d0
        addi.w #16,d0
        lsr.w #4,d0
        subi.w #9,d0
        move.w 6(a0),d1
        lsr.w #4,d1
        subq.w #6,d1
        bsr scroll_clamp
        bsr set_camera
        bne .error
        bra .repaint

; D0.w=the selectable object before the selected one, or the last of all when
; none precedes (or none is selected), -1 when the phase has none; A0=record.
object_prev:
        movem.l d1-d7/a1-a6,-(sp)
        moveq #0,d6
        move.w EDITOR_METADATA_BASE+CFMD_SPT_BYTES,d6
        divu #10,d6
        move.w AUR_BASE+AUR_OBJECT_INDEX,d5
        moveq #-1,d3
        suba.l a3,a3
        moveq #-1,d4
        suba.l a4,a4
        moveq #0,d7
        lea EDITOR_SPT_BASE,a5
.root:
        cmp.w d6,d7
        bhs.s .done
        move.w 8(a5),d0
        move.w d0,d1
        add.w d1,d1
        lea op_part_index(pc),a0
        tst.w 0(a0,d1.w)
        beq.s .step
        cmpi.w #$7FEF,4(a5)
        bhi.s .step
        tst.w 6(a5)
        bmi.s .step
        move.w d7,d3
        movea.l a5,a3
        tst.w d5
        bmi.s .step
        cmp.w d5,d7
        bge.s .step
        move.w d7,d4
        movea.l a5,a4
.step:
        lsl.w #2,d0
        lea ot_shared_recipes(pc),a0
        move.b 0(a0,d0.w),d0
        andi.w #3,d0
        addq.w #1,d0
        add.w d0,d7
        mulu #10,d0
        adda.w d0,a5
        bra.s .root
.done:
        tst.w d4
        bpl.s .have_prev
        move.w d3,d4
        movea.l a3,a4
.have_prev:
        movea.l a4,a0
        move.w d4,d0
        movem.l (sp)+,d1-d7/a1-a6
        tst.w d0
        rts

; Draw corner brackets around the selected placed object (AUR_OBJECT_INDEX)
; in screen space, clipped to pv_clip_*. Skipped while dragging or unselected.
object_draw_selection:
        movem.l d0-d7/a0-a6,-(sp)
        tst.w OBJECT_DRAG_INDEX
        bpl .out
        move.w AUR_BASE+AUR_OBJECT_INDEX,d0
        bmi .out
        moveq #0,d1
        move.w EDITOR_METADATA_BASE+CFMD_SPT_BYTES,d1
        divu #10,d1
        cmp.w d1,d0
        bhs .out
        mulu #10,d0
        lea EDITOR_SPT_BASE,a5
        adda.w d0,a5
        move.w 8(a5),d0
        cmpi.w #110,d0
        bhi .out
        add.w d0,d0
        lea op_part_index(pc),a0
        move.w 0(a0,d0.w),d0
        beq .out
        adda.w d0,a0
        move.w (a0)+,d4
        beq .out
        subq.w #1,d4
        movea.l a0,a6
        moveq #0,d5
        ; Accumulate union screen box: (D2=x0, D3=y0, D6=x1, D7=y1) as words.
        move.w #$7FFF,d2
        move.w #$7FFF,d3
        move.w #$8000,d6
        move.w #$8000,d7
        moveq #0,d1
.part_box:
        movea.l a5,a3
        cmpi.w #$3C,8(a5)
        bne.s .box_anchor
        tst.w d5
        beq.s .box_anchor
        lea 10(a5),a3
.box_anchor:
        cmpi.w #$7FEF,4(a3)
        bhi .box_next
        tst.w 6(a3)
        bmi .box_next
        cmpi.w #$18,8(a5)
        bne.s .box_native
        lea OBJECT_ANCHOR_DESC,a1
        bra.s .box_desc
.box_native:
        moveq #0,d0
        move.b (a6),d0
        lsl.w #2,d0
        lea editor_game_sprites,a1
        movea.l 0(a1,d0.w),a1
        moveq #0,d0
        move.b 1(a6),d0
        lsl.w #4,d0
        adda.w d0,a1
.box_desc:
        ; Screen left = 4(a3)+16 + dx + anchor_x - view_origin_x*16
        moveq #0,d0
        move.w 4(a3),d0
        addi.l #16,d0
        move.b 2(a6),d1
        ext.w d1
        ext.l d1
        add.l d1,d0
        move.b DESC_ANCHOR_X(a1),d1
        ext.w d1
        ext.l d1
        add.l d1,d0
        moveq #0,d1
        move.w view_origin_x,d1
        lsl.l #4,d1
        sub.l d1,d0
        cmpi.l #-2048,d0
        blt .box_next
        cmpi.l #2048,d0
        bgt .box_next
        cmp.w d2,d0
        bge.s .x0_ok
        move.w d0,d2
.x0_ok:
        moveq #0,d1
        move.w DESC_WORDS(a1),d1
        subq.w #1,d1
        lsl.w #4,d1
        add.w d1,d0
        cmp.w d6,d0
        ble.s .x1_ok
        move.w d0,d6
.x1_ok:
        ; Screen bottom = 6(a3) + dy + anchor_y - view_origin_y*16
        moveq #0,d0
        move.w 6(a3),d0
        move.b 3(a6),d1
        ext.w d1
        ext.l d1
        add.l d1,d0
        move.b DESC_ANCHOR_Y(a1),d1
        ext.w d1
        ext.l d1
        add.l d1,d0
        moveq #0,d1
        move.w view_origin_y,d1
        lsl.l #4,d1
        sub.l d1,d0
        cmpi.l #-2048,d0
        blt.s .box_next
        cmpi.l #2048,d0
        bgt.s .box_next
        cmp.w d7,d0
        ble.s .y1_ok
        move.w d0,d7
.y1_ok:
        sub.w DESC_ROWS(a1),d0
        cmp.w d3,d0
        bge.s .box_next
        move.w d0,d3
.box_next:
        lea 6(a6),a6
        addq.w #1,d5
        dbra d4,.part_box
        ; Inclusive [x0..x1-1] x [y0..y1-1]; reject empty or off-screen boxes.
        subq.w #1,d6
        subq.w #1,d7
        cmp.w d6,d2
        bgt .out
        cmp.w d7,d3
        bgt .out
        cmpi.w #304,d2
        bge .out
        tst.w d6
        bmi .out
        cmpi.w #192,d3
        bge .out
        tst.w d7
        bmi .out
        tst.w d2
        bpl.s .cx0
        moveq #0,d2
.cx0:
        cmpi.w #303,d6
        ble.s .cx1
        move.w #303,d6
.cx1:
        tst.w d3
        bpl.s .cy0
        moveq #0,d3
.cy0:
        cmpi.w #191,d7
        ble.s .cy1
        move.w #191,d7
.cy1:
        ; Arm length = min(4, (x1-x0)/2, (y1-y0)/2).
        moveq #4,d4
        move.w d6,d0
        sub.w d2,d0
        lsr.w #1,d0
        cmp.w d4,d0
        bhs.s .arm_y
        move.w d0,d4
.arm_y:
        move.w d7,d0
        sub.w d3,d0
        lsr.w #1,d0
        cmp.w d4,d0
        bhs.s .arm_ok
        move.w d0,d4
.arm_ok:
        bsr exit_ui_blitter_idle
        ; Draw the 4 corners: inner colour-0 shadow first, then terrain_font_ink.
        move.w d2,d0
        move.w d3,d1
        moveq #1,d5
        movea.w #1,a4
        bsr.s .corner
        move.w d6,d0
        move.w d3,d1
        moveq #-1,d5
        movea.w #1,a4
        bsr.s .corner
        move.w d2,d0
        move.w d7,d1
        moveq #1,d5
        movea.w #-1,a4
        bsr.s .corner
        move.w d6,d0
        move.w d7,d1
        moveq #-1,d5
        movea.w #-1,a4
        bsr.s .corner
.out:
        movem.l (sp)+,d0-d7/a0-a6
        rts

; Draw one corner at (D0.w, D1.w) extending by D4.w pixels along D5.w (dx)
; and A4.w (dy): inner shadow in colour 0, outer bracket in terrain_font_ink.
.corner:
        movem.l d0-d3/d6-d7,-(sp)
        move.w d0,d6
        move.w d1,d7
        cmpi.w #2,d4
        blo.s .outer
        ; Inner shadow shifted 1 pixel inward along (dx, dy).
        moveq #0,d2
        move.w d4,d3
        subq.w #1,d3
        move.w d6,d0
        add.w d5,d0
        move.w d7,d1
        add.w a4,d1
.sh_h:
        bsr.s .plot
        add.w d5,d0
        dbra d3,.sh_h
        move.w d4,d3
        subq.w #1,d3
        move.w d6,d0
        add.w d5,d0
        move.w d7,d1
        add.w a4,d1
.sh_v:
        bsr.s .plot
        add.w a4,d1
        dbra d3,.sh_v
.outer:
        move.w terrain_font_ink,d2
        move.w d4,d3
        move.w d6,d0
        move.w d7,d1
.in_h:
        bsr.s .plot
        add.w d5,d0
        dbra d3,.in_h
        move.w d4,d3
        move.w d6,d0
        move.w d7,d1
.in_v:
        bsr.s .plot
        add.w a4,d1
        dbra d3,.in_v
        movem.l (sp)+,d0-d3/d6-d7
        rts

; Plot screen pixel (D0.w, D1.w) in colour D2.w, clipped to pv_clip_*.
.plot:
        cmp.w preview_state+pv_clip_left,d0
        blt.s .p_out
        cmp.w preview_state+pv_clip_right,d0
        bge.s .p_out
        cmp.w preview_state+pv_clip_top,d1
        blt.s .p_out
        cmp.w preview_state+pv_clip_bottom,d1
        bge.s .p_out
        movem.l d3-d4/a0,-(sp)
        move.w d1,d3
        mulu #ROW_BYTES,d3
        move.w d0,d4
        lsr.w #3,d4
        add.w d4,d3
        add.w ring_base,d3
        cmpi.w #RING_BYTES,d3
        blo.s .p_in
        subi.w #RING_BYTES,d3
.p_in:
        moveq #7,d4
        and.w d0,d4
        neg.w d4
        addq.w #7,d4
        lea CANVAS,a0
        adda.w d3,a0
        moveq #0,d3
.p_plane:
        btst d3,d2
        beq.s .p_clr
        bset d4,(a0)
        bra.s .p_next
.p_clr:
        bclr d4,(a0)
.p_next:
        adda.w #DISPLAY_PLANE,a0
        addq.w #1,d3
        cmpi.w #4,d3
        blo.s .p_plane
        movem.l (sp)+,d3-d4/a0
.p_out:
        rts

; D0.w=the first object after the selected one that a click could select,
; the first of all when none follows, -1 when the phase has none; A0=its
; record. An object is its root record: the companions of a bundle follow
; it and are stepped over. Preserves the other registers.
object_next:
        movem.l d1-d7/a1-a6,-(sp)
        moveq #0,d6
        move.w EDITOR_METADATA_BASE+CFMD_SPT_BYTES,d6
        divu #10,d6
        move.w AUR_BASE+AUR_OBJECT_INDEX,d5
        moveq #-1,d3
        suba.l a3,a3
        moveq #0,d7
        lea EDITOR_SPT_BASE,a5
.root:
        cmp.w d6,d7
        bhs.s .wrap
        move.w 8(a5),d0
        move.w d0,d1
        add.w d1,d1
        lea op_part_index(pc),a0
        tst.w 0(a0,d1.w)
        beq.s .step
        cmpi.w #$7FEF,4(a5)
        bhi.s .step
        tst.w 6(a5)
        bmi.s .step
        tst.w d3
        bpl.s .seen
        move.w d7,d3
        movea.l a5,a3
.seen:
        cmp.w d5,d7
        bgt.s .found
.step:
        lsl.w #2,d0
        lea ot_shared_recipes(pc),a0
        move.b 0(a0,d0.w),d0
        andi.w #3,d0
        addq.w #1,d0
        add.w d0,d7
        mulu #10,d0
        adda.w d0,a5
        bra.s .root
.wrap:
        move.w d3,d7
        movea.l a3,a5
.found:
        movea.l a5,a0
        move.w d7,d0
        movem.l (sp)+,d1-d7/a1-a6
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
