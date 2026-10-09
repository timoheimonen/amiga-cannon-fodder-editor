; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; The object page in the terrain palette, which the original sprites of the
; preview need: five category tabs and thirteen catalog rows drawn by the
; Slave's text service in colours chosen from the terrain palette, the
; preview at X208..303, Y40..183, and the 48-line bar of the tile page.

; D0: current type. Unsupported imported roots start at SOLDIER; no authored
; state changes until the caller accepts a successful by-value selection.
pal_initial:
        lea pal_catalog(pc),a0
        moveq #0,d2
.find:
        cmp.w (a0),d0
        beq.s .found
        addq.l #4,a0
        addq.w #1,d2
        cmpi.w #PAL_ROOT_COUNT,d2
        blo.s .find
        moveq #0,d2
.found:
        moveq #0,d0
        lea pal_category_ranges(pc),a0
.category:
        move.w (a0),d1
        add.w 2(a0),d1
        cmp.w d1,d2
        blo.s .ready
        addq.l #4,a0
        addq.w #1,d0
        bra.s .category
.ready:
        bsr.s pal_set_category
        sub.w pal_first,d2
        move.w d2,page_hover
        move.w d2,page_top
        bra.s pal_clamp_top

; D0 category0..4; only transient page state changes.
pal_set_category:
        move.w d0,pal_category
        lsl.w #2,d0
        lea pal_category_ranges(pc),a0
        move.l 0(a0,d0.w),pal_first
        clr.w page_top
        clr.w page_hover
        rts
pal_clamp_top:
        move.w pal_count,d0
        subi.w #PAL_VISIBLE_ROWS,d0
        bpl.s .limit
        moveq #0,d0
.limit:
        cmp.w page_top,d0
        bhs.s .done
        move.w d0,page_top
.done:
        rts

; Colours of the page from the terrain palette: colour 0 behind, the most
; contrasting colour (terrain_font_ink) as ink, and for the selected and the
; hovered row and for dim text the colours nearest to a quarter, a sixth and
; a half of the way from colour 0 to the ink. Preserves all registers.
pal_prepare:
        movem.l d0-d7/a0-a1,-(sp)
        lea editor_base_palette,a0
        move.w (a0),d2
        bsr palette_luma
        move.w d0,d6
        move.w terrain_font_ink,d0
        add.w d0,d0
        move.w 0(a0,d0.w),d2
        bsr palette_luma
        sub.w d6,d0
        move.w d0,d7
        lea PAL_ROLES,a1
        move.w terrain_font_ink,d1
        moveq #15,d0
.ink:
        move.b d1,(a1)+
        dbra d0,.ink
        lea PAL_ROLES,a1
        clr.b UI_BG(a1)
        clr.b UI_PANEL(a1)
        clr.b UI_FACE(a1)
        clr.b UI_SHADOW(a1)
        moveq #4,d5
        bsr.s .nearest
        move.b d0,UI_SELECT(a1)
        moveq #6,d5
        bsr.s .nearest
        move.b d0,UI_FACE_HOVER(a1)
        moveq #2,d5
        bsr.s .nearest
        move.b d0,UI_DIM(a1)
        movem.l (sp)+,d0-d7/a0-a1
        rts
; D5 divisor: D0 = the colour 1..15 other than the ink whose luma is
; nearest to colour 0's plus D7/D5.
.nearest:
        movem.l d1-d4/a0,-(sp)
        move.w d7,d3
        ext.l d3
        divs d5,d3
        add.w d6,d3
        moveq #-1,d4
        moveq #1,d0
        moveq #1,d1
        lea editor_base_palette+2,a0
.candidate:
        move.w (a0)+,d2
        cmp.w terrain_font_ink,d1
        beq.s .skip
        movem.l d0/d1,-(sp)
        bsr palette_luma
        sub.w d3,d0
        bpl.s .distance
        neg.w d0
.distance:
        move.w d0,d2
        movem.l (sp)+,d0/d1
        cmp.w d4,d2
        bhs.s .skip
        move.w d2,d4
        move.w d1,d0
.skip:
        addq.w #1,d1
        cmpi.w #16,d1
        blo.s .candidate
        movem.l (sp)+,d1-d4/a0
        rts

pal_render:
        movem.l d0-d7/a0-a6,-(sp)
        lea preview_state,a4
        bsr preview_restore
        bsr pal_blitter_idle
        lea CANVAS,a0
        moveq #3,d1
.plane:
        move.w #192*40/4-1,d0
.clear:
        clr.l (a0)+
        dbra d0,.clear
        adda.w #DISPLAY_PLANE-192*40,a0
        dbra d1,.plane
        move.l #CANVAS,display_draw_buffer
        move.l #-1,PAL_TAB_DRAWN
        move.l #-1,PAL_TAB_DRAWN+4
        move.w #-1,PAL_TAB_DRAWN+8
        bsr pal_tabs_refresh
        bsr.s pal_rows
        bsr pal_preview
        bsr publish_ring
        bsr pal_bar_refresh
        movem.l (sp)+,d0-d7/a0-a6
        rts

; The visible catalog rows; the highlighted one is selected.
pal_rows:
        movem.l d0-d7/a0-a1,-(sp)
        moveq #0,d7
.row:
        move.w page_top,d0
        add.w d7,d0
        cmp.w pal_count,d0
        bhs.s .done
        moveq #UI_NORMAL,d6
        cmp.w page_hover,d0
        bne.s .state
        moveq #UI_ACTIVE,d6
.state:
        add.w pal_first,d0
        lsl.w #2,d0
        lea pal_catalog(pc),a1
        move.w 2(a1,d0.w),d0
        adda.w d0,a1
        lea PAL_COMMAND,a0
        move.w #UI_ROW_AT,(a0)+
        move.w #2,(a0)+
        move.w d7,d0
        mulu #PAL_ROW_PITCH,d0
        addi.w #PAL_LIST_Y,d0
        move.w d0,(a0)+
        move.w #PAL_LIST_WIDTH-2,(a0)+
        move.w #PAL_ROW_PITCH-1,(a0)+
        move.w d6,(a0)+
        move.l a1,(a0)+
        clr.w (a0)
        lea PAL_COMMAND,a0
        lea pal_target_page(pc),a1
        bsr pal_ui
        addq.w #1,d7
        cmpi.w #PAL_VISIBLE_ROWS,d7
        blo.s .row
.done:
        movem.l (sp)+,d0-d7/a0-a1
        rts

; D0.w = the index of the button under the pointer in the table at A0 of
; D1.w buttons whose rows start at screen row D2.w, or -1. Preserves D1-D7/A0-A6.
pal_hit:
        movem.l d1-d4/a0,-(sp)
        move.w native_mouse_y,d3
        sub.w d2,d3
        bcs.s .none
        move.w native_mouse_x,d2
        addi.w #16,d2
        move.w d1,d4
        moveq #0,d0
.button:
        move.w 2(a0),d1
        cmp.w d1,d2
        blo.s .next
        add.w 6(a0),d1
        cmp.w d1,d2
        bhs.s .next
        move.w 4(a0),d1
        cmp.w d1,d3
        blo.s .next
        add.w 8(a0),d1
        cmp.w d1,d3
        blo.s .found
.next:
        lea PAL_BUTTON_BYTES(a0),a0
        addq.w #1,d0
        cmp.w d4,d0
        blo.s .button
.none:
        moveq #-1,d0
.found:
        movem.l (sp)+,d1-d4/a0
        rts
pal_tab_hit:
        movem.l d1-d2/a0,-(sp)
        lea pal_tabs(pc),a0
        moveq #PAL_TABS,d1
        moveq #0,d2
        bsr.s pal_hit
        movem.l (sp)+,d1-d2/a0
        rts
pal_bar_hit:
        movem.l d1-d2/a0,-(sp)
        lea pal_bar_buttons(pc),a0
        moveq #PAL_BAR_BUTTONS,d1
        move.w #PAL_BAR_Y,d2
        bsr.s pal_hit
        movem.l (sp)+,d1-d2/a0
        rts

; The tabs: the category active, the one under the pointer hovered. Draws
; them when a state changed. Preserves all registers.
pal_tabs_refresh:
        movem.l d0-d3/a0-a1,-(sp)
        bsr.s pal_tab_hit
        move.w d0,d3
        lea PAL_TAB_STATES,a0
        lea PAL_TAB_DRAWN,a1
        moveq #0,d1
        moveq #0,d2
.tab:
        moveq #UI_NORMAL,d0
        cmp.w d1,d3
        bne.s .current
        moveq #UI_HOVER,d0
.current:
        cmp.w pal_category,d1
        bne.s .set
        moveq #UI_ACTIVE,d0
.set:
        move.w d0,(a0)+
        cmp.w (a1),d0
        beq.s .same
        moveq #1,d2
.same:
        move.w d0,(a1)+
        addq.w #1,d1
        cmpi.w #PAL_TABS,d1
        blo.s .tab
        tst.w d2
        beq.s .done
        lea pal_tabs(pc),a0
        lea pal_target_page(pc),a1
        bsr pal_ui
.done:
        movem.l (sp)+,d0-d3/a0-a1
        rts

; The whole bar is drawn again from the current state.
draw_toolbar:
        bsr.s pal_bar_invalidate
        bra.s pal_bar_refresh

; Redraw the whole bar on the next refresh. Preserves all registers.
pal_bar_invalidate:
        move.l #-1,PAL_BAR_DRAWN
        move.l #-1,PAL_BAR_DRAWN+4
        move.w #-1,PAL_DRAWN_ROW
        rts

; The bar: buttons and the row range in the UI band, the highlighted type in
; the terrain band. Draws what changed. Preserves all registers.
pal_bar_refresh:
        movem.l d0-d7/a0-a1,-(sp)
        bsr pal_bar_hit
        move.w d0,d7
        move.w pal_count,d5
        subi.w #PAL_VISIBLE_ROWS,d5
        bpl.s .last
        moveq #0,d5
.last:
        lea PAL_BAR_STATES,a0
        moveq #0,d1
.state:
        moveq #UI_NORMAL,d2
        cmp.w d1,d7
        bne.s .limit
        moveq #UI_HOVER,d2
.limit:
        tst.w d1
        bne.s .down
        tst.w page_top
        bne.s .set
        moveq #UI_DISABLED,d2
        bra.s .set
.down:
        cmpi.w #1,d1
        bne.s .set
        cmp.w page_top,d5
        bne.s .set
        moveq #UI_DISABLED,d2
.set:
        move.w d2,(a0)+
        addq.w #1,d1
        cmpi.w #PAL_BAR_BUTTONS,d1
        blo.s .state
        lea PAL_BAR_STATES,a0
        lea PAL_BAR_DRAWN,a1
        moveq #PAL_BAR_BUTTONS-1,d1
        moveq #0,d2
.compare:
        move.w (a0)+,d0
        cmp.w (a1),d0
        sne d3
        or.b d3,d2
        move.w d0,(a1)+
        dbra d1,.compare
        move.w pal_category,d0
        lsl.w #8,d0
        or.w page_top,d0
        cmp.w PAL_DRAWN_TOP,d0
        sne d3
        or.b d3,d2
        move.w d0,PAL_DRAWN_TOP
        tst.b d2
        beq.s .lower
        lea PAL_READOUT,a0
        lea pal_rows_text(pc),a1
        bsr pal_append
        move.w page_top,d0
        addq.w #1,d0
        bsr pal_decimal
        move.b #'-',(a0)+
        move.w page_top,d0
        addi.w #PAL_VISIBLE_ROWS,d0
        cmp.w pal_count,d0
        bls.s .end
        move.w pal_count,d0
.end:
        bsr pal_decimal
        lea pal_of_text(pc),a1
        bsr pal_append
        move.w pal_count,d0
        bsr pal_decimal
        lea pal_bar_list(pc),a0
        lea pal_target_ui(pc),a1
        bsr.s pal_ui
.lower:
        move.w pal_category,d0
        lsl.w #8,d0
        or.w page_hover,d0
        cmp.w PAL_DRAWN_ROW,d0
        beq.s .done
        move.w d0,PAL_DRAWN_ROW
        move.w page_hover,d0
        add.w pal_first,d0
        lsl.w #2,d0
        lea pal_catalog(pc),a1
        move.w 2(a1,d0.w),d0
        adda.w d0,a1
        lea PAL_TEXT,a0
.copy:
        move.b (a1)+,d0
        cmpi.b #$ff,d0
        beq.s .copied
        move.b d0,(a0)+
        bra.s .copy
.copied:
        clr.b (a0)
        lea pal_band_list(pc),a0
        lea pal_target_band(pc),a1
        bsr.s pal_ui
.done:
        movem.l (sp)+,d0-d7/a0-a1
        rts

; A0 command list, A1 target. Preserves D1-D7/A0-A6.
pal_ui:
        bsr.s pal_blitter_idle
        move.l d1,-(sp)
        moveq #0,d1
        moveq #UI_OPERATION,d0
        jsr EDITOR_BACKEND_ENTRY
        move.l (sp)+,d1
        rts
pal_blitter_idle:
        btst #6,amiga_dmacon_read
        bne.s pal_blitter_idle
        rts

; Copy the zero-terminated string A1 to A0; A0 ends on the terminator.
pal_append:
        move.b (a1)+,(a0)+
        bne.s pal_append
        subq.l #1,a0
        rts

; D0.w 0..99 in decimal at A0, which ends on the terminator. Clobbers D0-D1.
pal_decimal:
        andi.l #$ffff,d0
        divu #10,d0
        tst.w d0
        beq.s .ones
        addi.b #'0',d0
        move.b d0,(a0)+
.ones:
        swap d0
        addi.b #'0',d0
        move.b d0,(a0)+
        clr.b (a0)
        rts

; Show one original static item at the geometric centre of X208..303,Y40..183.
; Aggregate bounds are checked before any preview pixel is drawn.
pal_preview:
        move.w page_hover,d0
        cmp.w pal_count,d0
        bhs .error
        add.w pal_first,d0
        lsl.w #2,d0
        lea pal_catalog(pc),a0
        move.w 0(a0,d0.w),d0
        lea parts,a0
        lea editor_game_sprites,a1
        bsr op_parts
        tst.l d0
        ble .error
        lea preview_state,a4
        bsr preview_set_item
        tst.l d0
        bne .error
        move.w #32767,d2
        move.w d2,d3
        move.w #-32768,d4
        move.w d4,d5
        lea parts,a0
        move.w pv_count(a4),d6
        subq.w #1,d6
.part:
        movea.l (a0)+,a1
        move.w (a0)+,d0
        move.b DESC_ANCHOR_X(a1),d7
        ext.w d7
        add.w d7,d0
        cmp.w d2,d0
        bge.s .left
        move.w d0,d2
.left:
        move.w DESC_WORDS(a1),d7
        subq.w #1,d7
        lsl.w #4,d7
        add.w d7,d0
        cmp.w d4,d0
        ble.s .right
        move.w d0,d4
.right:
        move.w (a0)+,d1
        move.b DESC_ANCHOR_Y(a1),d7
        ext.w d7
        add.w d7,d1
        cmp.w d5,d1
        ble.s .bottom
        move.w d1,d5
.bottom:
        sub.w DESC_ROWS(a1),d1
        cmp.w d3,d1
        bge.s .top
        move.w d1,d3
.top:
        dbra d6,.part
        sub.w d2,d4
        cmpi.w #96,d4
        bhi.s .error
        sub.w d3,d5
        cmpi.w #144,d5
        bhi.s .error
        moveq #96,d0
        sub.w d4,d0
        lsr.w #1,d0
        addi.w #208,d0
        sub.w d2,d0
        move.w #144,d1
        sub.w d5,d1
        lsr.w #1,d1
        addi.w #40,d1
        sub.w d3,d1
        bsr preview_update
        rts
.error:
        move.w #PAGE_RENDER_ERROR,page_error
        rts

; Return D0=0 none,1 select,2 cancel. Each category/scroll request is bounded.
pal_input:
        move.w native_last_key,d0
        clr.w native_last_key
        move.w native_left_pressed,d5
        clr.w native_left_pressed
        move.w native_right_pressed,d6
        clr.w native_right_pressed
        cmpi.w #$c5,d0
        beq .cancel
        tst.w d6
        bne .cancel
        cmpi.w #$c4,d0
        beq.s .choose
        move.w page_hover,d7
        bsr pal_hover_update
        bsr pal_tabs_refresh
        bsr pal_bar_refresh
        tst.w d5
        beq.s .held
        bsr pal_tab_hit
        tst.w d0
        bpl.s .change_category
        bsr pal_bar_hit
        tst.w d0
        bmi.s .list
        moveq #-1,d1
        tst.w d0
        beq .scroll
        moveq #1,d1
        cmpi.w #1,d0
        beq .scroll
        cmpi.w #2,d0
        beq.s .choose
        bra .cancel
.list:
        bsr pal_row_at
        bmi .hover
        move.w d0,page_hover
.choose:
        move.w page_hover,d1
        cmp.w pal_count,d1
        bhs .hover
        add.w pal_first,d1
        lsl.w #2,d1
        lea pal_catalog(pc),a0
        move.w 0(a0,d1.w),page_choice
        moveq #1,d0
        rts
.change_category:
        cmp.w pal_category,d0
        beq .idle
        bsr pal_set_category
        bra .render
.held:
        moveq #-1,d1
        cmpi.w #$4c,native_raw_key
        beq.s .repeat
        moveq #1,d1
        cmpi.w #$4d,native_raw_key
        beq.s .repeat
        moveq #-2,d1
        cmpi.w #$4f,native_raw_key
        beq.s .repeat
        moveq #2,d1
        cmpi.w #$4e,native_raw_key
        beq.s .repeat
        ; The tabs fill the top of the pointer's range, so only the bottom
        ; scrolls with the pointer, and only after the pointer has been
        ; above it since the page opened.
        moveq #0,d1
        cmpi.w #UI_SCROLL_DOWN_Y,native_mouse_y
        bhs.s .bottom
        move.w #1,page_armed
        bra.s .repeat
.bottom:
        tst.w page_armed
        beq.s .repeat
        moveq #1,d1
.repeat:
        tst.w d1
        beq .no_direction
        cmp.w page_direction,d1
        bne.s .apply_direction
        subq.w #1,page_repeat
        bpl .hover
.apply_direction:
        move.w d1,page_direction
        move.w #7,page_repeat
        cmpi.w #-2,d1
        beq.s .previous_category
        cmpi.w #2,d1
        beq.s .next_category
.scroll:
        move.w page_top,d0
        add.w d1,d0
        bmi.s .hover
        move.w pal_count,d2
        subi.w #PAL_VISIBLE_ROWS,d2
        bmi.s .hover
        cmp.w d2,d0
        bhi.s .hover
        move.w d0,page_top
        bsr pal_hover_update
        ; Footer/key scrolling keeps a visible highlighted row even when
        ; the pointer is outside the list.
        move.w page_top,d0
        cmp.w page_hover,d0
        bls.s .check_last_highlight
        move.w d0,page_hover
.check_last_highlight:
        addi.w #PAL_VISIBLE_ROWS-1,d0
        cmp.w page_hover,d0
        bhs.s .render
        move.w d0,page_hover
        bra.s .render
.previous_category:
        move.w pal_category,d0
        subq.w #1,d0
        bmi.s .hover
        bra .change_category
.next_category:
        move.w pal_category,d0
        addq.w #1,d0
        cmpi.w #4,d0
        bls .change_category
        bra.s .hover
.no_direction:
        clr.w page_direction
        clr.w page_repeat
.hover:
        cmp.w page_hover,d7
        beq.s .idle
.render:
        bsr pal_render
.idle:
        moveq #0,d0
        rts
.cancel:
        moveq #2,d0
        rts

; D0.w = the catalog row (category index) under the pointer, or -1.
pal_row_at:
        move.w native_mouse_x,d0
        addi.w #16,d0
        cmpi.w #PAL_LIST_WIDTH,d0
        bhs.s .none
        move.w native_mouse_y,d0
        subi.w #PAL_LIST_Y,d0
        bcs.s .none
        cmpi.w #PAL_VISIBLE_ROWS*PAL_ROW_PITCH,d0
        bhs.s .none
        andi.l #$ffff,d0
        divu #PAL_ROW_PITCH,d0
        add.w page_top,d0
        cmp.w pal_count,d0
        bhs.s .none
        tst.w d0
        rts
.none:
        moveq #-1,d0
        rts

; Leaving the list preserves the last highlighted item and its preview.
pal_hover_update:
        bsr.s pal_row_at
        bmi.s .done
        move.w d0,page_hover
.done:
        rts

pal_target_page:
        dc.l CANVAS,DISPLAY_PLANE,PAL_ROLES
pal_target_ui:
        dc.l BAR_BITMAP,BAR_PLANE,pal_ui_roles
pal_target_band:
        dc.l BAR_BITMAP,BAR_PLANE,PAL_ROLES
pal_ui_roles:
        dc.b 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15

pal_tabs:
        dc.w UI_BUTTON_REF,2,2,46,13
        dc.l PAL_TAB_STATES,pal_player_label
        dc.w UI_BUTTON_REF,50,2,50,13
        dc.l PAL_TAB_STATES+2,pal_enemies_label
        dc.w UI_BUTTON_REF,102,2,60,13
        dc.l PAL_TAB_STATES+4,pal_buildings_label
        dc.w UI_BUTTON_REF,164,2,54,13
        dc.l PAL_TAB_STATES+6,pal_vehicles_label
        dc.w UI_BUTTON_REF,220,2,82,13
        dc.l PAL_TAB_STATES+8,pal_items_label
        dc.w UI_END

; Rows 0..31 of the bar use the UI palette, rows 32..47 the terrain palette.
pal_bar_list:
        dc.w UI_RECT,0,0,320,32,UI_BG
pal_bar_buttons:
        dc.w UI_BUTTON_REF,2,2,44,13
        dc.l PAL_BAR_STATES,pal_up_label
        dc.w UI_BUTTON_REF,48,2,50,13
        dc.l PAL_BAR_STATES+2,pal_down_label
        dc.w UI_BUTTON_REF,196,2,58,13
        dc.l PAL_BAR_STATES+4,pal_choose_label
        dc.w UI_BUTTON_REF,256,2,46,13
        dc.l PAL_BAR_STATES+6,pal_cancel_label
        dc.w UI_TEXT_AT,100,5,92,UI_DIM,UI_CENTER
        dc.l PAL_READOUT
        dc.w UI_TEXT,4,20,296,UI_DIM,UI_LEFT
        dc.b "Click a row to choose it. Right click: cancel.",0
        even
        dc.w UI_END
pal_band_list:
        dc.w UI_RECT,0,32,320,16,UI_BG
        dc.w UI_TEXT_AT,4,36,296,UI_INK,UI_LEFT
        dc.l PAL_TEXT
        dc.w UI_END
pal_player_label: dc.b "Player",0
pal_enemies_label: dc.b "Enemies",0
pal_buildings_label: dc.b "Buildings",0
pal_vehicles_label: dc.b "Vehicles",0
pal_items_label: dc.b "Items/terrain",0
pal_up_label: dc.b "Up",0
pal_down_label: dc.b "Down",0
pal_choose_label: dc.b "Choose",0
pal_cancel_label: dc.b "Cancel",0
pal_rows_text: dc.b "Rows ",0
pal_of_text: dc.b " of ",0
        even
