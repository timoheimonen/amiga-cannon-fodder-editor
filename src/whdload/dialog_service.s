; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Dialog service (backend operation 7, see dialog.i). A dialog is a
; full-width panel band in the UI palette. Above and below it the authoring
; map stays visible with a darkened palette when the canvas still holds the
; ring the view last published; otherwise those rows are black. The native
; copper list and the borrowed chip memory are kept in the expansion memory
; and restored on close.
DIALOG_COPPER_SAVE_BYTES equ $C00
DIALOG_BACKUP       equ DIALOG_COPPER_SAVE_BYTES
DIALOG_BACKUP_END   equ DIALOG_BACKUP+DIALOG_PANEL_ROWS*4*40+DIALOG_CHIP_END-DIALOG_COPPER
; WHDLoad allocates expansion memory in whole 4 KiB pages.
DIALOG_EXPMEM_BYTES equ (DIALOG_BACKUP_END+$fff)&-$1000
; A dialog that opens within this many fields of a left click that chose a
; button elsewhere takes no press until then, unless the pointer first moves
; this many pixels from where the dialog opened.
DIALOG_GUARD_FIELDS equ 20
DIALOG_GUARD_MOVE   equ 4
dialog_service:
        movem.l d1-d7/a0-a6,-(sp)
        cmpi.w #DIALOG_SET,d1
        bhi.s .refuse
        add.w d1,d1
        move.w .jump(pc,d1.w),d1
        jsr .jump(pc,d1.w)
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.l d0
        rts
.refuse:
        moveq #10,d0
        bra.s .return
.jump:
        dc.w dialog_stamp-.jump,dialog_open-.jump,dialog_poll-.jump
        dc.w dialog_close-.jump,dialog_draw-.jump,dialog_set-.jump

; A0=sixteen terrain colours, D2.w=ring byte offset of the first view row.
dialog_stamp:
        moveq #10,d0
        cmpi.w #DIALOG_RING_BYTES,d2
        bhs.s .out
        btst #0,d2
        bne.s .out
        lea dlg_ring(pc),a1
        move.w d2,(a1)
        lea dlg_dark(pc),a1
        moveq #15,d7
.colour:
        move.w (a0)+,d0
        moveq #0,d1
        moveq #2,d6
.component:
        move.w d0,d2
        andi.w #15,d2
        mulu #3,d2
        lsr.w #3,d2
        or.w d2,d1
        ror.w #4,d1
        lsr.w #4,d0
        dbra d6,.component
        ror.w #4,d1
        move.w d1,(a1)+
        dbra d7,.colour
        bsr dialog_blitter_idle
        bsr dialog_checksum
        lea dlg_sum(pc),a1
        move.l d0,(a1)
        lea dlg_stamped(pc),a1
        move.w #1,(a1)
        moveq #0,d0
.out:
        rts

; D0.l = checksum of the four ring planes, without the guard rows.
dialog_checksum:
        lea DIALOG_CANVAS,a0
        moveq #0,d0
        moveq #3,d2
.plane:
        move.w #DIALOG_RING_BYTES/4-1,d1
.long:
        add.l (a0)+,d0
        rol.l #1,d0
        dbra d1,.long
        lea DIALOG_CANVAS_PLANE-DIALOG_RING_BYTES(a0),a0
        dbra d2,.plane
        rts

dialog_blitter_idle:
        btst #6,$dff002
        bne.s dialog_blitter_idle
        rts

; A0=descriptor, D2.l=disabled-button mask. While a dialog is open, a
; descriptor with the same band replaces it in place.
dialog_open:
        moveq #10,d0
        move.l a0,d1
        btst #0,d1
        bne .out
        move.w DIALOG_TOP(a0),d3
        cmpi.w #8,d3
        blo .out
        move.w DIALOG_HEIGHT(a0),d4
        cmpi.w #24,d4
        blo .out
        add.w d3,d4
        cmpi.w #DIALOG_PANEL_ROWS,d4
        bhi .out
        move.w DIALOG_COUNT(a0),d5
        cmpi.w #DIALOG_MAX_BUTTONS,d5
        bhi .out
        lea dlg_open(pc),a1
        move.w (a1),d7
        beq.s .take
        cmp.w dlg_top(pc),d3
        bne .out
        move.w DIALOG_HEIGHT(a0),d1
        cmp.w dlg_height(pc),d1
        bne .out
.take:
        move.w #1,(a1)
        movea.l a0,a4
        ; Copy the header fields and the buttons; disabled buttons per D2.
        lea dlg_top(pc),a1
        move.w d3,(a1)+
        move.w DIALOG_HEIGHT(a4),(a1)+
        move.w DIALOG_DEFAULT(a4),(a1)+
        move.w DIALOG_CANCEL(a4),(a1)+
        move.w d5,(a1)+
        lea DIALOG_BUTTONS(a4),a0
        lea dlg_buttons(pc),a1
        lea dlg_states(pc),a2
        moveq #0,d6
        bra.s .button_next
.button:
        move.l (a0)+,(a1)+
        move.l (a0)+,(a1)+
        move.w (a0)+,(a1)+
        move.w (a0)+,d0
        move.w d0,d1
        lsr.w #8,d1
        lea dlg_flags(pc),a3
        move.b d1,0(a3,d6.w)
        andi.w #$ff,d0
        btst d6,d2
        beq.s .enabled
        moveq #UI_DISABLED,d0
        bra.s .state
.enabled:
        cmp.w DIALOG_DEFAULT(a4),d6
        bne.s .state
        moveq #UI_DEFAULT,d0
.state:
        move.w d0,(a1)+
        move.w d0,(a2)+
        move.l (a0)+,(a1)+
        addq.w #1,d6
.button_next:
        cmp.w d5,d6
        blo.s .button
        ; A key released while WHDLoad ran the OS (directory listings) stays
        ; held for the game, which then ignores the next press of that key.
        ; Start every dialog with no key held and no pending event.
        clr.w native_raw_key
        clr.w native_key_previous
        clr.w native_last_key
        lea dlg_hover(pc),a1
        move.w #-1,(a1)+
        move.w native_left_down,(a1)+
        move.w native_right_down,(a1)+
        move.w #-1,(a1)
        ; The second press of a double-click on the button that opened this
        ; dialog would choose the button now under the pointer (Don't save
        ; under Exit to hill). A different dialog opened by a recent click is
        ; guarded; one that replaces itself with the same descriptor (a list's
        ; next page) or opened by a key is not.
        lea dlg_descriptor(pc),a1
        lea dlg_click(pc),a2
        moveq #0,d0
        cmpa.l (a1),a4
        beq.s .guard
        move.l a4,(a1)
        tst.w (a2)
        beq.s .guard
        move.w native_field_counter,d0
        sub.w 2(a2),d0
        neg.w d0
        addi.w #DIALOG_GUARD_FIELDS,d0
        bgt.s .guard
        moveq #0,d0
.guard:
        clr.w (a2)
        lea dlg_guard(pc),a1
        move.w d0,(a1)+
        move.w native_mouse_x,(a1)+
        move.w native_mouse_y,(a1)
        ; A replacement keeps the display, the map and the borrowed memory.
        tst.w d7
        beq.s .first
        bsr dialog_draw_panel
        moveq #0,d0
        rts
.first:
        lea dlg_target(pc),a1
        move.l #DIALOG_PANEL,(a1)+
        move.l #DIALOG_PANEL_STRIDE,(a1)+
        lea dlg_roles(pc),a0
        move.l a0,(a1)
        bsr dialog_blitter_idle
        moveq #0,d0
        bsr dialog_exchange
        ; The canvas still holds the stamped ring: show it darkened.
        lea dlg_map(pc),a1
        clr.w (a1)
        move.w dlg_stamped(pc),d0
        beq.s .background
        bsr dialog_checksum
        cmp.l dlg_sum(pc),d0
        bne.s .background
        move.w #1,(a1)
.background:
        bsr dialog_draw_panel
        movea.l expmem(pc),a1
        lea editor_copper_list,a0
        move.w #DIALOG_COPPER_SAVE_BYTES/4-1,d0
.save:
        move.l (a0)+,(a1)+
        dbra d0,.save
        lea dlg_cursor_active(pc),a1
        move.w native_cursor_active,(a1)+
        move.l native_cursor_offsets,(a1)
        move.w native_copper_depth,d0
        andi.w #$0FFF,d0
        lea dlg_depth(pc),a1
        move.w d0,(a1)
        bsr dialog_build_copper
        bsr dialog_native_copper
        clr.l native_cursor_offsets
        move.w #-1,native_cursor_active
        moveq #0,d0
.out:
        rts

; Panel frame, title, body and buttons.
dialog_draw_panel:
        lea dlg_list(pc),a0
        move.w #UI_RECT,(a0)+
        clr.w (a0)+
        move.w dlg_top(pc),d0
        move.w d0,(a0)+
        move.w #320,(a0)+
        move.w dlg_height(pc),(a0)+
        move.w #UI_PANEL,(a0)+
        move.w #UI_RECT,(a0)+
        clr.w (a0)+
        addq.w #1,d0
        move.w d0,(a0)+
        move.w #320,(a0)+
        move.w #1,(a0)+
        move.w #UI_LIGHT,(a0)+
        move.w #UI_RECT,(a0)+
        clr.w (a0)+
        addq.w #1,d0
        move.w d0,(a0)+
        move.w #320,(a0)+
        move.w #11,(a0)+
        move.w DIALOG_TITLE_ROLE(a4),(a0)+
        move.w #UI_TEXT_AT,(a0)+
        move.w #8,(a0)+
        addq.w #2,d0
        move.w d0,(a0)+
        move.w #288,(a0)+
        move.w #UI_INK,(a0)+
        move.w #UI_LEFT,(a0)+
        move.l DIALOG_TITLE(a4),(a0)+
        move.w #UI_RECT,(a0)+
        clr.w (a0)+
        move.w dlg_top(pc),d0
        add.w dlg_height(pc),d0
        subq.w #1,d0
        move.w d0,(a0)+
        move.w #320,(a0)+
        move.w #1,(a0)+
        move.w #UI_SHADOW,(a0)+
        clr.w (a0)
        lea dlg_list(pc),a0
        bsr.s dialog_ui
        move.l DIALOG_BODY(a4),d0
        beq.s .buttons
        movea.l d0,a0
        bsr.s dialog_ui
.buttons:
        moveq #0,d7
        bra.s .next
.button:
        bsr.s dialog_draw_button
        addq.w #1,d7
.next:
        cmp.w dlg_count(pc),d7
        blo.s .button
        rts

; A0=command list for the panel bitmap.
dialog_ui:
        lea dlg_target(pc),a1
        moveq #0,d1
        bra ui_service

; D7.w=button index.
dialog_draw_button:
        move.w d7,d0
        lsl.w #4,d0
        lea dlg_buttons(pc),a1
        adda.w d0,a1
        lea dlg_list(pc),a0
        move.w #UI_BUTTON_AT,(a0)+
        lea dlg_flags(pc),a2
        btst #DIALOG_ROW_BIT-8,0(a2,d7.w)
        beq.s .button
        move.w #UI_ROW_AT,-2(a0)
.button:
        move.l DIALOG_BUTTON_X(a1),(a0)+
        move.l DIALOG_BUTTON_W(a1),(a0)+
        move.w DIALOG_BUTTON_STATE(a1),(a0)+
        move.l DIALOG_BUTTON_LABEL(a1),(a0)+
        clr.w (a0)
        lea dlg_list(pc),a0
        bra.s dialog_ui

; Top of the frame: darkened map or black, the dialog pointer colours, the
; empty sidebar sprites and a jump to the dialog copper list.
dialog_native_copper:
        lea native_copper_color0,a0
        lea dlg_dark(pc),a1
        moveq #15,d0
        move.w dlg_map(pc),d1
.dark:
        moveq #0,d2
        tst.w d1
        beq.s .black
        move.w (a1),d2
.black:
        addq.l #2,a1
        move.w d2,(a0)
        addq.l #4,a0
        dbra d0,.dark
        lea dlg_pointer(pc),a1
        moveq #15,d0
.pointer:
        move.w (a1)+,(a0)
        addq.l #4,a0
        dbra d0,.pointer
        ; The band has no fine scroll of its own: a scrolled game view (the
        ; result after a phase) would shift the panel to the right.
        clr.w editor_copper_scroll
        move.w dlg_depth(pc),d0
        tst.w d1
        beq.s .depth
        ori.w #$4000,d0
        moveq #0,d1
        move.w dlg_ring(pc),d1
        add.l #DIALOG_CANVAS,d1
        lea editor_copper_planes,a0
        moveq #3,d2
.planes:
        swap d1
        move.w d1,(a0)
        swap d1
        move.w d1,4(a0)
        add.l #DIALOG_CANVAS_PLANE,d1
        addq.l #8,a0
        dbra d2,.planes
.depth:
        move.w d0,native_copper_depth
        ; Crop the window to the view's 304 pixels, like the authoring view.
        move.b #$b1,editor_copper_fetch+1
        move.l #DIALOG_SPRITE,d1
        clr.l DIALOG_SPRITE
        clr.l DIALOG_SPRITE+4
        lea native_sidebar_pointer_high,a0
        moveq #5,d0
.sprites:
        swap d1
        move.w d1,(a0)
        swap d1
        move.w d1,4(a0)
        addq.l #8,a0
        dbra d0,.sprites
        lea editor_copper_tail,a0
        move.l #$00840000+(DIALOG_COPPER>>16),(a0)+
        move.l #$00860000+(DIALOG_COPPER&$ffff),(a0)+
        move.l #$008a0000,(a0)
        rts

; The band starts and ends with a blank line, during which the copper
; switches plane pointers and palette before the next fetch.
dialog_build_copper:
        lea DIALOG_COPPER,a0
        lea dlg_lower(pc),a1
        clr.w (a1)
        move.w dlg_top(pc),d3
        move.w d3,d4
        add.w dlg_height(pc),d4
        ; D5 = first screen row whose ring offset wraps to the ring start.
        moveq #0,d5
        move.w dlg_ring(pc),d5
        divu #40,d5
        neg.w d5
        addi.w #256,d5
        move.w dlg_map(pc),d6
        beq.s .top
        cmp.w d3,d5
        bhs.s .top
        move.w d5,d0
        bsr dialog_wrap
.top:
        move.w d3,d0
        subq.w #1,d0
        bsr dialog_wait_end
        bsr dialog_blank
        move.w d3,d0
        addq.w #1,d0
        mulu #40,d0
        add.l #DIALOG_PANEL,d0
        move.l #DIALOG_PANEL_STRIDE,d1
        bsr dialog_planes
        lea dlg_ui_palette(pc),a1
        bsr dialog_colours
        move.w d3,d0
        bsr dialog_wait_end
        bsr dialog_depth4
        ; A band reaching the bottom of the display window needs no end.
        cmpi.w #DIALOG_PANEL_ROWS,d4
        bhs .end
        move.w d4,d0
        subq.w #1,d0
        bsr dialog_wait_end
        bsr dialog_blank
        tst.w d6
        beq .end
        move.w d4,d0
        addq.w #1,d0
        cmpi.w #DIALOG_MAP_ROWS,d0
        bhs.s .end
        bsr dialog_ring_row
        move.l #DIALOG_CANVAS_PLANE,d1
        bsr dialog_planes
        lea dlg_dark(pc),a1
        bsr dialog_colours
        move.w d4,d0
        bsr dialog_wait_end
        move.w #$0180,(a0)+
        move.w dlg_dark(pc),(a0)+
        bsr dialog_depth4
        move.w d4,d0
        addq.w #1,d0
        cmp.w d0,d5
        bls.s .map_end
        cmpi.w #DIALOG_MAP_ROWS,d5
        bhs.s .map_end
        move.w d5,d0
        bsr.s dialog_wrap
.map_end:
        move.w #DIALOG_MAP_ROWS,d0
        bsr.s dialog_wait_start
        bsr.s dialog_blank
.end:
        move.l #$fffffffe,(a0)+
        rts

; D0.w screen row; the ring continues from its first row.
dialog_wrap:
        bsr.s dialog_wait_start
        moveq #0,d0
        move.w dlg_ring(pc),d0
        divu #40,d0
        swap d0
        ext.l d0
        add.l #DIALOG_CANVAS,d0
        move.l #DIALOG_CANVAS_PLANE,d1
        bra.s dialog_planes

; D0.w screen row -> D0.l address of that row in the ring.
dialog_ring_row:
        mulu #40,d0
        add.w dlg_ring(pc),d0
        cmpi.l #DIALOG_RING_BYTES,d0
        blo.s .inside
        subi.l #DIALOG_RING_BYTES,d0
.inside:
        add.l #DIALOG_CANVAS,d0
        rts

; Waits for screen row D0.w at the start or the end of its line. The first
; wait below raster line 255 is preceded by the usual wait for its end.
dialog_wait_start:
        bsr.s dialog_line
        addq.w #1,d0
        bra.s dialog_wait
dialog_wait_end:
        bsr.s dialog_line
        move.b #$df,d0
dialog_wait:
        move.w d0,(a0)+
        move.w #$fffe,(a0)+
        rts
dialog_line:
        addi.w #48,d0
        cmpi.w #256,d0
        blo.s .shift
        lea dlg_lower(pc),a1
        tst.w (a1)
        bne.s .shift
        move.w #1,(a1)
        move.l #$ffdffffe,(a0)+
.shift:
        lsl.w #8,d0
        rts

dialog_blank:
        move.w #$0100,(a0)+
        move.w dlg_depth(pc),(a0)+
        move.l #$01800000,(a0)+
        rts

dialog_depth4:
        move.w #$0100,(a0)+
        move.w dlg_depth(pc),d0
        ori.w #$4000,d0
        move.w d0,(a0)+
        rts

; D0.l plane 0 address, D1.l plane stride.
dialog_planes:
        move.w #$00e0,d2
        moveq #3,d7
.plane:
        swap d0
        move.w d2,(a0)+
        move.w d0,(a0)+
        addq.w #2,d2
        swap d0
        move.w d2,(a0)+
        move.w d0,(a0)+
        addq.w #2,d2
        add.l d1,d0
        dbra d7,.plane
        rts

; A1 sixteen colours; colours 1-15 (colour 0 belongs to the blank line).
dialog_colours:
        addq.l #2,a1
        move.w #$0182,d2
        moveq #14,d7
.colour:
        move.w d2,(a0)+
        move.w (a1)+,(a0)+
        addq.w #2,d2
        dbra d7,.colour
        rts

; One frame of input, see dialog.i.
dialog_poll:
        moveq #-2,d0
        move.w dlg_open(pc),d1
        beq .out
        move.w native_mouse_x,d1
        addi.w #16,d1
        move.w native_mouse_y,d2
        moveq #-1,d6
        moveq #0,d7
        lea dlg_buttons(pc),a1
        bra.s .test_next
.test:
        cmpi.w #UI_DISABLED,DIALOG_BUTTON_STATE(a1)
        beq.s .miss
        move.w d1,d0
        sub.w DIALOG_BUTTON_X(a1),d0
        cmp.w DIALOG_BUTTON_W(a1),d0
        bhs.s .miss
        move.w d2,d0
        sub.w DIALOG_BUTTON_Y(a1),d0
        cmp.w DIALOG_BUTTON_H(a1),d0
        bhs.s .miss
        move.w d7,d6
.miss:
        lea DIALOG_BUTTON_BYTES(a1),a1
        addq.w #1,d7
.test_next:
        cmp.w dlg_count(pc),d7
        blo.s .test
        ; D6 = button under the pointer. Move the hover highlight.
        move.w dlg_hover(pc),d7
        cmp.w d6,d7
        beq.s .keys
        tst.w d7
        bmi.s .highlight
        moveq #0,d0
        bsr dialog_set_hover
.highlight:
        move.w d6,d7
        bmi.s .moved
        moveq #1,d0
        bsr dialog_set_hover
.moved:
        lea dlg_hover(pc),a1
        move.w d6,(a1)
.keys:
        move.w native_last_key,d1
        clr.w native_last_key
        cmpi.w #$c4,d1
        bne.s .escape
        move.w dlg_default(pc),d7
        bmi.s .escape
        bsr dialog_button
        cmpi.w #UI_DISABLED,DIALOG_BUTTON_STATE(a1)
        beq.s .escape
        bra .code
.escape:
        cmpi.w #$c5,d1
        beq.s .cancel
        lea dlg_right_held(pc),a1
        tst.w native_right_down
        bne.s .right
        clr.w (a1)
        bra.s .left
.right:
        tst.w (a1)
        bne.s .left
        move.w #1,(a1)
.cancel:
        move.w dlg_cancel(pc),d0
        bpl .chosen
.left:
        lea dlg_guard(pc),a1
        tst.w (a1)
        beq.s .armed
        subq.w #1,(a1)+
        move.w native_mouse_x,d0
        sub.w (a1)+,d0
        bpl.s .guard_x
        neg.w d0
.guard_x:
        cmpi.w #DIALOG_GUARD_MOVE,d0
        bhs.s .moved_away
        move.w native_mouse_y,d0
        sub.w (a1),d0
        bpl.s .guard_y
        neg.w d0
.guard_y:
        cmpi.w #DIALOG_GUARD_MOVE,d0
        bhs.s .moved_away
        ; Still guarded: a press must be released and pressed again.
        tst.w native_left_down
        beq.s .armed
        lea dlg_held(pc),a1
        move.w #1,(a1)
        bra .none
.moved_away:
        lea dlg_guard(pc),a1
        clr.w (a1)
.armed:
        lea dlg_held(pc),a1
        tst.w native_left_down
        bne.s .down
        clr.w (a1)
        lea dlg_pressed(pc),a1
        move.w #-1,(a1)
        bra.s .none
.down:
        tst.w (a1)
        bne.s .held
        move.w #1,(a1)
        lea dlg_pressed(pc),a1
        move.w d6,(a1)+
        move.w #DIALOG_REPEAT_DELAY,(a1)
        move.w d6,d7
        bmi.s .none
        lea dlg_click(pc),a1
        move.w #1,(a1)+
        move.w native_field_counter,(a1)
        bra.s .chosen_button
        ; A repeating button held under the pointer is chosen again.
.held:
        move.w d6,d7
        bmi.s .none
        cmp.w dlg_pressed(pc),d7
        bne.s .none
        lea dlg_flags(pc),a1
        btst #0,0(a1,d7.w)
        beq.s .none
        lea dlg_wait(pc),a1
        subq.w #1,(a1)
        bne.s .none
        move.w #DIALOG_REPEAT_RATE,(a1)
.chosen_button:
        bsr.s dialog_button
.code:
        move.w DIALOG_BUTTON_CODE(a1),d0
.chosen:
        ext.l d0
        rts
.none:
        moveq #-1,d0
.out:
        rts

; D7.w index -> A1 button. Trashes D0.
dialog_button:
        move.w d7,d0
        lsl.w #4,d0
        lea dlg_buttons(pc),a1
        adda.w d0,a1
        rts

; D7.w index, D0.w 1 = hovered. Redraws the button.
dialog_set_hover:
        move.w d0,d2
        bsr.s dialog_button
        move.w d7,d0
        add.w d0,d0
        lea dlg_states(pc),a2
        move.w 0(a2,d0.w),d0
        tst.w d2
        beq.s .state
        bsr.s dialog_hovered
.state:
        move.w d0,DIALOG_BUTTON_STATE(a1)
        bra dialog_draw_button

; D0.w base state -> the state drawn while the pointer is over the button.
dialog_hovered:
        cmpi.w #UI_NORMAL,d0
        bne.s .default
        moveq #UI_HOVER,d0
        rts
.default:
        cmpi.w #UI_DEFAULT,d0
        bne.s .keep
        moveq #UI_DEFAULT_HOVER,d0
.keep:
        rts

; D2.w button index, D3.w new state (UI_NORMAL, UI_ACTIVE or UI_DISABLED;
; the default button shows NORMAL as DEFAULT), A0 new label or 0.
dialog_set:
        moveq #10,d0
        move.w dlg_open(pc),d1
        beq.s .out
        cmp.w dlg_count(pc),d2
        bhs.s .out
        move.w d2,d7
        bsr dialog_button
        move.l a0,d0
        beq.s .label
        move.l a0,DIALOG_BUTTON_LABEL(a1)
.label:
        move.w d3,d0
        cmpi.w #UI_NORMAL,d0
        bne.s .base
        cmp.w dlg_default(pc),d7
        bne.s .base
        moveq #UI_DEFAULT,d0
.base:
        move.w d7,d1
        add.w d1,d1
        lea dlg_states(pc),a2
        move.w d0,0(a2,d1.w)
        lea dlg_hover(pc),a2
        cmp.w (a2),d7
        bne.s .draw
        cmpi.w #UI_DISABLED,d0
        bne.s .hovered
        move.w #-1,(a2)
        bra.s .draw
.hovered:
        bsr.s dialog_hovered
.draw:
        move.w d0,DIALOG_BUTTON_STATE(a1)
        bsr dialog_draw_button
        moveq #0,d0
.out:
        rts

dialog_close:
        moveq #10,d0
        lea dlg_open(pc),a1
        tst.w (a1)
        beq.s .out
        clr.w (a1)
        bsr dialog_blitter_idle
        movea.l expmem(pc),a0
        lea editor_copper_list,a1
        move.w #DIALOG_COPPER_SAVE_BYTES/4-1,d0
.restore:
        move.l (a0)+,(a1)+
        dbra d0,.restore
        move.w dlg_cursor_active(pc),native_cursor_active
        move.l dlg_cursor_offsets(pc),native_cursor_offsets
        ; The copper may still fetch the panel in this frame: give the
        ; borrowed memory back once a new frame started from the restored list.
        move.l $dff004,d0
        andi.l #$1ff00,d0
.beam:
        move.l d0,d1
        move.l $dff004,d0
        andi.l #$1ff00,d0
        cmp.l d1,d0
        bhs.s .beam
        moveq #1,d0
        bsr dialog_exchange
        moveq #0,d0
.out:
        rts

; D0.w=0 saves the band rows of the panel planes, the copper list and the
; empty sprite into the expansion memory; 1 restores them.
dialog_exchange:
        movea.l expmem(pc),a2
        lea DIALOG_BACKUP(a2),a2
        move.w dlg_top(pc),d1
        mulu #40,d1
        add.l #DIALOG_PANEL,d1
        move.w dlg_height(pc),d2
        mulu #10,d2
        subq.w #1,d2
        moveq #3,d3
.plane:
        movea.l d1,a3
        move.w d2,d4
        bsr.s .copy
        add.l #DIALOG_PANEL_STRIDE,d1
        dbra d3,.plane
        lea DIALOG_COPPER,a3
        move.w #(DIALOG_CHIP_END-DIALOG_COPPER)/4-1,d4
.copy:
        tst.w d0
        bne.s .restore
.save:
        move.l (a3)+,(a2)+
        dbra d4,.save
        rts
.restore:
        move.l (a2)+,(a3)+
        dbra d4,.restore
        rts

dialog_draw:
        moveq #10,d0
        move.w dlg_open(pc),d1
        beq.s .out
        move.l a0,d1
        btst #0,d1
        bne.s .out
        bsr dialog_ui
.out:
        rts

dlg_ui_palette:
        UI_PALETTE_RGB
; The editor's pointer: the hill's yellow arrow with a dark outline.
dlg_pointer:
        dc.w $0243,$0dcd,$0aa9,$0776,$0554,$0332,$0540,$0e80
        dc.w $0705,$0b40,$0a07,$0504,$0ec0,$0970,$0660,$0111
dlg_roles:
        dc.b 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
dlg_open:           dc.w 0
dlg_stamped:        dc.w 0
dlg_ring:           dc.w 0
dlg_map:            dc.w 0
dlg_depth:          dc.w 0
dlg_sum:            dc.l 0
dlg_dark:           dcb.w 16,0
dlg_top:            dc.w 0
dlg_height:         dc.w 0
dlg_default:        dc.w 0
dlg_cancel:         dc.w 0
dlg_count:          dc.w 0
dlg_hover:          dc.w 0
dlg_held:           dc.w 0
dlg_right_held:     dc.w 0
dlg_pressed:        dc.w 0
dlg_wait:           dc.w 0
dlg_guard:          dc.w 0,0,0
; Set by a left click that chose a button, with the field it happened in.
dlg_click:          dc.w 0,0
dlg_descriptor:     dc.l 0
dlg_lower:          dc.w 0
dlg_cursor_active:  dc.w 0
dlg_cursor_offsets: dc.l 0
dlg_target:         dc.l 0,0,0
dlg_buttons:        dcb.b DIALOG_MAX_BUTTONS*DIALOG_BUTTON_BYTES,0
dlg_states:         dcb.w DIALOG_MAX_BUTTONS,0
; DIALOG_REPEAT and DIALOG_ROW, shifted down by eight bits.
dlg_flags:          dcb.b DIALOG_MAX_BUTTONS,0
dlg_list:           dcb.w 48,0
        even
