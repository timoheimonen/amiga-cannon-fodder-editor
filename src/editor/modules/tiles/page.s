; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Ordinal tile grid; canonical MAP/SPT and AUR are read-only here.
tile_render:
        movem.l d0-d7/a0-a6,-(sp)
        moveq #0,d4
.row:
        moveq #0,d6
.column:
        bsr.s tile_grid_cell
        addq.w #1,d6
        cmpi.w #PAGE_COLS,d6
        blo.s .column
        addq.w #1,d4
        cmpi.w #PAGE_VISIBLE_ROWS,d4
        blo.s .row
        bsr.s tile_mark_selected
        bsr publish_ring
        bsr tile_hover_update
        bsr tile_bar_refresh
        movem.l (sp)+,d0-d7/a0-a6
        rts

tile_grid_cell:
        moveq #0,d0
        move.w page_top,d0
        add.w d4,d0
        mulu #PAGE_COLS,d0
        add.w d6,d0
        cmpi.w #PAGE_TILE_COUNT,d0
        bhs.s .invalid
        lsl.l #7,d0
        lea editor_tile_data,a0
        adda.l d0,a0
        move.w d4,d0
        mulu #640,d0
        add.w d6,d0
        add.w d6,d0
        lea CANVAS,a1
        adda.w d0,a1
        moveq #16,d1
        jsr editor_tile_blit
        rts
.invalid:
        move.w #PAGE_RENDER_ERROR,page_error
        rts

; Corners in the ink colour mark the selected tile when it is on the page.
tile_mark_selected:
        bsr tile_blitter_idle
        moveq #0,d0
        move.w AUR_BASE+AUR_TILE,d0
        divu #PAGE_COLS,d0
        sub.w page_top,d0
        cmpi.w #PAGE_VISIBLE_ROWS,d0
        bhs.s .return
        move.w d0,d1
        mulu #640,d1
        swap d0
        add.w d0,d1
        add.w d0,d1
        lea CANVAS,a0
        adda.l d1,a0
        move.w TILE_INK,d2
        moveq #3,d3
.plane:
        lea tile_corners(pc),a1
        movea.l a0,a2
        moveq #15,d4
.line:
        move.w (a1)+,d5
        move.w d5,d6
        not.w d6
        and.w d6,(a2)
        btst #0,d2
        beq.s .next
        or.w d5,(a2)
.next:
        lea 40(a2),a2
        dbra d4,.line
        lsr.w #1,d2
        adda.w #DISPLAY_PLANE,a0
        dbra d3,.plane
.return:
        rts
tile_corners:
        dc.w $F00F,$8001,$8001,$8001,0,0,0,0
        dc.w 0,0,0,0,$8001,$8001,$8001,$F00F

; D0=0 no intent,1 chosen,2 cancel. Status comes from persistent page_error.
tile_input:
        move.w native_last_key,d0
        clr.w native_last_key
        move.w native_left_pressed,d5
        clr.w native_left_pressed
        move.w native_right_pressed,d6
        clr.w native_right_pressed
        cmpi.w #$C5,d0
        beq .cancel
        tst.w d6
        bne .cancel
        bsr tile_hover_update
        bsr tile_bar_refresh
        tst.w d5
        beq.s .held_scroll
        cmpi.w #AUR_PAGE_NONE,page_hover
        beq.s .controls
        move.w page_hover,page_choice
        moveq #1,d0
        rts
.controls:
        bsr tile_bar_hit
        moveq #-1,d1
        tst.w d0
        bmi .idle
        beq.s .scroll_now
        moveq #1,d1
        cmpi.w #1,d0
        beq.s .scroll_now
        bra .cancel
.held_scroll:
        moveq #-1,d1
        cmpi.w #$4C,native_raw_key
        beq.s .repeat
        moveq #1,d1
        cmpi.w #$4D,native_raw_key
        beq.s .repeat
        moveq #0,d1
        move.w native_mouse_y,d0
        cmpi.w #UI_SCROLL_DOWN_Y,d0
        bhs.s .bottom
        cmpi.w #8,d0
        bhs.s .outside
        moveq #-1,d1
        bra.s .armed
.bottom:
        moveq #1,d1
.armed:
        ; The pointer scrolls only after it has been outside both zones since
        ; the page opened: the selected-tile image that opens it lies in the
        ; bottom zone.
        tst.w page_armed
        bne.s .repeat
        moveq #0,d1
        bra.s .repeat
.outside:
        move.w #1,page_armed
.repeat:
        tst.w d1
        beq.s .no_direction
        cmp.w page_direction,d1
        bne.s .scroll_now
        subq.w #1,page_repeat
        bpl.s .idle
.scroll_now:
        move.w d1,page_direction
        move.w #7,page_repeat
        move.w page_top,d0
        add.w d1,d0
        cmpi.w #PAGE_LAST_TOP,d0
        bhi.s .idle
        move.w d0,page_top
        bsr tile_render
        bra.s .idle
.no_direction:
        clr.w page_direction
        clr.w page_repeat
.idle:
        moveq #0,d0
        rts
.cancel:
        moveq #2,d0
        rts

tile_hover_update:
        move.w #AUR_PAGE_NONE,page_hover
        move.w native_mouse_x,d0
        addi.w #16,d0
        cmpi.w #304,d0
        bhs.s .return
        move.w native_mouse_y,d1
        cmpi.w #TILE_BAR_Y,d1
        bhs.s .return
        lsr.w #4,d0
        lsr.w #4,d1
        add.w page_top,d1
        mulu #PAGE_COLS,d1
        add.w d0,d1
        cmpi.w #PAGE_TILE_COUNT,d1
        bhs.s .return
        move.w d1,page_hover
.return:
        rts

; Choose the most contrasting terrain colour against colour 0 as the ink of
; the corners and of the terrain band. D0=0 ready, PAGE_RENDER_ERROR without
; contrast. Preserves D1-D7/A0-A6.
tile_bar_prepare:
        movem.l d1/a1,-(sp)
        bsr contrast_ink
        beq.s .flat
        move.w d0,TILE_INK
        lea TILE_ROLES,a1
        moveq #15,d1
.role:
        move.b d0,(a1)+
        dbra d1,.role
        clr.b TILE_ROLES+UI_BG
        moveq #0,d0
        bra.s .return
.flat:
        moveq #PAGE_RENDER_ERROR,d0
.return:
        movem.l (sp)+,d1/a1
        tst.w d0
        rts

; The whole bar is drawn again from the current state.
draw_toolbar:
        bsr.s tile_bar_invalidate
        bra.s tile_bar_refresh

; Redraw the whole bar on the next refresh. Preserves all registers.
tile_bar_invalidate:
        move.l #-1,TILE_DRAWN_STATES
        move.l #-1,TILE_DRAWN_STATES+4
        move.w #-1,TILE_DRAWN_TILE
        rts

; D0.w = the bar button under the pointer, or -1. Preserves D1-D7/A0-A6.
tile_bar_hit:
        movem.l d1-d3/a0,-(sp)
        move.w native_mouse_y,d1
        subi.w #TILE_BAR_Y,d1
        bcs.s .none
        move.w native_mouse_x,d2
        addi.w #16,d2
        lea tile_bar_buttons(pc),a0
        moveq #0,d0
.button:
        move.w 2(a0),d3
        cmp.w d3,d2
        blo.s .next
        add.w 6(a0),d3
        cmp.w d3,d2
        bhs.s .next
        move.w 4(a0),d3
        cmp.w d3,d1
        blo.s .next
        add.w 8(a0),d3
        cmp.w d3,d1
        blo.s .found
.next:
        lea TILE_BUTTON_BYTES(a0),a0
        addq.w #1,d0
        cmpi.w #TILE_BUTTONS,d0
        blo.s .button
.none:
        moveq #-1,d0
.found:
        movem.l (sp)+,d1-d3/a0
        rts

; Draw what differs from the bar on screen: the buttons and the row range
; in the upper band, the tile under the pointer (or the selected one) in the
; terrain band. Preserves all registers.
tile_bar_refresh:
        movem.l d0-d7/a0-a2,-(sp)
        bsr.s tile_bar_hit
        move.w d0,d7
        lea TILE_STATES,a0
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
        cmpi.w #PAGE_LAST_TOP,page_top
        bne.s .set
        moveq #UI_DISABLED,d2
.set:
        move.w d2,(a0)+
        addq.w #1,d1
        cmpi.w #TILE_BUTTONS,d1
        blo.s .state
        lea TILE_STATES,a0
        lea TILE_DRAWN_STATES,a1
        moveq #TILE_BUTTONS-1,d1
        moveq #0,d2
.compare:
        move.w (a0)+,d0
        cmp.w (a1),d0
        sne d3
        or.b d3,d2
        move.w d0,(a1)+
        dbra d1,.compare
        move.w page_top,d0
        cmp.w TILE_DRAWN_TOP,d0
        sne d3
        or.b d3,d2
        move.w d0,TILE_DRAWN_TOP
        tst.b d2
        beq.s .lower
        lea TILE_READOUT,a0
        lea tile_rows_text(pc),a1
        bsr tile_append
        move.w page_top,d0
        addq.w #1,d0
        bsr tile_decimal
        move.b #'-',(a0)+
        move.w page_top,d0
        addi.w #PAGE_VISIBLE_ROWS,d0
        bsr tile_decimal
        lea tile_of_text(pc),a1
        bsr tile_append
        lea tile_bar_list(pc),a0
        lea tile_target_ui(pc),a1
        bsr.s tile_ui
.lower:
        moveq #0,d6
        move.w page_hover,d6
        cmpi.w #AUR_PAGE_NONE,d6
        bne.s .shown
        move.w AUR_BASE+AUR_TILE,d6
.shown:
        cmp.w TILE_DRAWN_TILE,d6
        beq.s .done
        move.w d6,TILE_DRAWN_TILE
        lea TILE_TEXT,a0
        lea tile_tile_text(pc),a1
        bsr.s tile_append
        move.w d6,d0
        moveq #2,d1
        bsr.s tile_digits
        move.b #' ',(a0)+
        move.w d6,d0
        bsr bar_class_name
        bsr.s tile_append
        cmp.w AUR_BASE+AUR_TILE,d6
        bne.s .text
        lea tile_selected_text(pc),a1
        bsr.s tile_append
.text:
        lea tile_band_list(pc),a0
        lea tile_target_band(pc),a1
        bsr.s tile_ui
        cmpi.w #PAGE_TILE_COUNT,d6
        bhs.s .done
        move.l d6,d0
        lsl.l #7,d0
        lea editor_tile_data,a0
        adda.l d0,a0
        lea BAR_BITMAP+32*UI_ROW_BYTES,a1
        moveq #16,d1
        jsr editor_tile_blit
.done:
        movem.l (sp)+,d0-d7/a0-a2
        rts

; A0 command list, A1 target. Preserves D1-D7/A0-A6.
tile_ui:
        bsr.s tile_blitter_idle
        move.l d1,-(sp)
        moveq #0,d1
        moveq #UI_OPERATION,d0
        jsr EDITOR_BACKEND_ENTRY
        move.l (sp)+,d1
        rts

; Copy the zero-terminated string A1 to A0; A0 ends on the terminator.
tile_append:
        move.b (a1)+,(a0)+
        bne.s tile_append
        subq.l #1,a0
        rts

; D0.w 0..99 in decimal at A0, which ends on the terminator. Clobbers D0-D1/A1.
tile_decimal:
        moveq #0,d1
        cmpi.w #10,d0
        blo.s tile_digits
        moveq #1,d1
; D0.w value, D1.w digits-1, A0 output: zero-padded digits and a terminator;
; A0 ends on the terminator. Clobbers D0/A1.
tile_digits:
        movea.l a0,a1
        adda.w d1,a1
        addq.l #1,a1
        clr.b (a1)
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

tile_blitter_idle:
        btst #6,amiga_dmacon_read
        bne.s tile_blitter_idle
        rts

tile_target_ui:
        dc.l BAR_BITMAP,BAR_PLANE,tile_ui_roles
tile_target_band:
        dc.l BAR_BITMAP,BAR_PLANE,TILE_ROLES
tile_ui_roles:
        dc.b 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15

; Rows 0..31 of the bar use the UI palette, rows 32..47 the terrain palette.
tile_bar_list:
        dc.w UI_RECT,0,0,320,32,UI_BG
tile_bar_buttons:
        dc.w UI_BUTTON_REF,2,2,44,13
        dc.l TILE_STATES,tile_up_label
        dc.w UI_BUTTON_REF,48,2,50,13
        dc.l TILE_STATES+2,tile_down_label
        dc.w UI_BUTTON_REF,256,2,46,13
        dc.l TILE_STATES+4,tile_cancel_label
        dc.w UI_TEXT_AT,104,5,148,UI_DIM,UI_CENTER
        dc.l TILE_READOUT
        dc.w UI_TEXT,4,20,296,UI_DIM,UI_LEFT
        dc.b "Click a tile to choose it. Right click: cancel.",0
        even
        dc.w UI_END
tile_band_list:
        dc.w UI_RECT,0,32,320,16,UI_BG
        dc.w UI_TEXT_AT,20,36,280,UI_INK,UI_LEFT
        dc.l TILE_TEXT
        dc.w UI_END
tile_up_label: dc.b "Up",0
tile_down_label: dc.b "Down",0
tile_cancel_label: dc.b "Cancel",0
tile_rows_text: dc.b "Rows ",0
tile_of_text: dc.b " of 21",0
tile_tile_text: dc.b "Tile ",0
tile_selected_text: dc.b "  (selected)",0
        even
        include "../editor/tile_class.s"
        ifne PAGE_ROWS-21
        fail "The row readout names 21 rows"
        endif
