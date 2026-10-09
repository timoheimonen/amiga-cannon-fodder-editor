; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Shared 48-line tool bar of the Terrain and Object views, drawn by the Slave's
; text service. Rows 0..31 use the fixed UI palette and hold every button; the
; game clamps the pointer to Y227, bar row 35. Rows 32..47 use the terrain
; palette: the selected tile and the information/status line.
; The layout table below drives both drawing and hit testing.
        include "ui.i"
BAR_ROWS            equ 48
BAR_UI_ROWS         equ 32
BAR_HOVER           equ EDITOR_UI_BASE+88
BAR_XY_TEXT         equ EDITOR_UI_BASE+96
BAR_INFO_TEXT       equ EDITOR_UI_BASE+112
BAR_INFO_BYTES      equ 64
BAR_ROLES           equ EDITOR_UI_BASE+176
; Button states as drawn by the Slave, and as last drawn.
BAR_STATES          equ EDITOR_UI_BASE+192
BAR_DRAWN           equ EDITOR_UI_BASE+214
; Checksums of the texts on screen; unchanged texts are not redrawn.
BAR_XY_SUM          equ EDITOR_UI_BASE+236
BAR_INFO_SUM        equ EDITOR_UI_BASE+240
BAR_STATE_END       equ EDITOR_UI_BASE+244
        ifgt BAR_STATE_END-EDITOR_UI_BASE-EDITOR_UI_BYTES
        fail "Tool bar state exceeds UI scratch"
        endif
BAR_BUTTON_BYTES    equ 18
BAR_BUTTON_COUNT    equ 11
; Button indices.
BAR_PAINT           equ 0
BAR_FILL            equ 1
BAR_OBJECT          equ 2
BAR_MARKER          equ 3
BAR_INSPECT         equ 4
BAR_UNDO            equ 5
BAR_SECOND          equ 6
BAR_CHECK           equ 7
BAR_TEST            equ 8
BAR_SAVE            equ 9
BAR_MENU            equ 10
BAR_THUMBNAIL       equ 11
; Bar-relative geometry, exported for the acceptance scenarios.
BAR_TOOL_Y          equ 2
BAR_COMMAND_Y       equ 18
BAR_BUTTON_H        equ 13
BAR_INFO_Y          equ 36

; D0.w screen X (pointer X+16), D1.w bar row. D0=button index or -1.
; Preserves D1-D7/A0-A6.
bar_hit:
        movem.l d2-d4/a0,-(sp)
        cmpi.w #BAR_UI_ROWS,d1
        bhs.s .thumbnail
        lea bar_buttons(pc),a0
        moveq #0,d4
.button:
        move.w 2(a0),d2
        cmp.w d2,d0
        blo.s .next
        add.w 6(a0),d2
        cmp.w d2,d0
        bhs.s .next
        move.w 4(a0),d3
        cmp.w d3,d1
        blo.s .next
        add.w 8(a0),d3
        cmp.w d3,d1
        blo.s .found
.next:
        lea BAR_BUTTON_BYTES(a0),a0
        addq.w #1,d4
        cmpi.w #BAR_BUTTON_COUNT,d4
        blo.s .button
.none:
        moveq #-1,d0
        bra.s .return
.thumbnail:
        ; The Object view draws no selected-tile image, so it has no button.
        ifd AUR_OBJECT_VIEW
        bra.s .none
        else
        cmpi.w #16,d0
        bhs.s .none
        moveq #BAR_THUMBNAIL,d4
        endif
.found:
        move.w d4,d0
.return:
        movem.l (sp)+,d2-d4/a0
        rts

; Track the button under the pointer; a change requests a button redraw.
; D0.w index or -1. Preserves all registers.
bar_hover:
        cmp.w BAR_HOVER,d0
        beq.s .same
        move.w d0,BAR_HOVER
        ori.w #8,TERRAIN_BAR_DIRTY
.same:
        rts

; D0.w button index, D1.w state. Preserves all registers.
bar_set_state:
        movem.l d0/a0,-(sp)
        add.w d0,d0
        lea BAR_STATES,a0
        move.w d1,0(a0,d0.w)
        movem.l (sp)+,d0/a0
        rts

; Mark the active tool and the hovered button. Composers mark disabled
; buttons afterwards. Preserves all registers.
bar_reset_states:
        movem.l d0-d1,-(sp)
        moveq #BAR_BUTTON_COUNT-1,d0
.state:
        moveq #UI_NORMAL,d1
        cmp.w BAR_HOVER,d0
        bne.s .plain
        moveq #UI_HOVER,d1
.plain:
        cmp.w AUR_BASE+AUR_TOOL,d0
        bne.s .set
        moveq #UI_ACTIVE,d1
.set:
        bsr.s bar_set_state
        dbra d0,.state
        movem.l (sp)+,d0-d1
        rts

; Choose the most contrasting terrain colour against colour 0 as the ink of
; the lower band. D0=0 ready, EDTR_VISUAL_ERROR without contrast.
; Preserves D1-D7/A0-A6.
bar_prepare:
        movem.l d1/a1,-(sp)
        bsr contrast_ink
        beq.s .flat
        move.w d0,terrain_font_ink
        lea BAR_ROLES,a1
        moveq #15,d1
.role:
        move.b d0,(a1)+
        dbra d1,.role
        clr.b BAR_ROLES+UI_BG
        move.w #-1,BAR_HOVER
        moveq #0,d0
        bra.s .return
.flat:
        moveq #EDTR_VISUAL_ERROR,d0
.return:
        movem.l (sp)+,d1/a1
        tst.w d0
        rts

; Draw what TERRAIN_BAR_DIRTY requests: bit1 the whole bar, bit2 the cell
; readout, bit0 the readout and the information line. Buttons whose state
; changed (hover, Undo, Delete, the active tool) are redrawn one by one.
; The composer bar_compose fills the texts and button states. Preserves all.
bar_draw:
        movem.l d0-d7/a0-a6,-(sp)
        bsr.s bar_reset_states
        bsr bar_compose
        move.w TERRAIN_BAR_DIRTY,d7
        btst #1,d7
        beq.s .changed
        lea BAR_STATES,a0
        lea BAR_DRAWN,a1
        moveq #BAR_BUTTON_COUNT-1,d0
.adopt:
        move.w (a0)+,(a1)+
        dbra d0,.adopt
        lea BAR_XY_TEXT,a0
        bsr bar_sum
        move.l d0,BAR_XY_SUM
        lea bar_target_ui(pc),a1
        lea bar_list(pc),a0
        bsr bar_ui
        bra.s .lower
.changed:
        lea BAR_STATES,a2
        lea BAR_DRAWN,a3
        lea bar_buttons(pc),a0
        lea bar_target_ui(pc),a1
        moveq #BAR_BUTTON_COUNT-1,d6
.button:
        cmpm.w (a2)+,(a3)+
        beq.s .same
        move.w -2(a2),-2(a3)
        moveq #1,d1
        bsr.s bar_ui_limited
.same:
        lea BAR_BUTTON_BYTES(a0),a0
        dbra d6,.button
        move.w d7,d0
        andi.w #5,d0
        beq.s .lower
        lea BAR_XY_TEXT,a0
        bsr.s bar_sum
        cmp.l BAR_XY_SUM,d0
        beq.s .lower
        move.l d0,BAR_XY_SUM
        lea bar_xy_list(pc),a0
        bsr.s bar_ui
.lower:
        lea BAR_INFO_TEXT,a0
        bsr.s bar_sum
        lea bar_target_terrain(pc),a1
        lea bar_band_list(pc),a0
        btst #1,d7
        bne.s .info
        btst #0,d7
        beq.s .done
        cmp.l BAR_INFO_SUM,d0
        beq.s .done
        lea bar_info_list(pc),a0
.info:
        move.l d0,BAR_INFO_SUM
        bsr.s bar_ui
        bsr bar_band_extra
.done:
bar_draw_end:
        clr.w TERRAIN_BAR_DIRTY
        movem.l (sp)+,d0-d7/a0-a6
        rts

; A0 command list, A1 target; bar_ui_limited draws D1.w commands.
; Preserves D1-D7/A0-A6.
bar_ui:
        moveq #0,d1
bar_ui_limited:
        moveq #UI_OPERATION,d0
        jsr EDITOR_BACKEND_ENTRY
        rts

; A0 zero-terminated text -> D0 its checksum. Preserves D1-D7/A0-A6.
bar_sum:
        movem.l d1/a0,-(sp)
        moveq #0,d0
        moveq #0,d1
.byte:
        move.b (a0)+,d1
        beq.s .done
        rol.l #5,d0
        add.l d1,d0
        bra.s .byte
.done:
        movem.l (sp)+,d1/a0
        rts

; Clear the whole 48-line bar to colour 0. Preserves all registers.
bar_clear:
        movem.l d0-d1/a0,-(sp)
        lea BAR_BITMAP,a0
        moveq #3,d1
.plane:
        move.w #BAR_ROWS*UI_ROW_BYTES/4-1,d0
.long:
        clr.l (a0)+
        dbra d0,.long
        lea BAR_PLANE-BAR_ROWS*UI_ROW_BYTES(a0),a0
        dbra d1,.plane
        movem.l (sp)+,d0-d1/a0
        rts

; D0.w value, D1.w digits-1, A0 output. Writes zero-padded digits and
; returns A0 after them. Clobbers D0/A1.
bar_digits:
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

; Copy the zero-terminated string A1 to A0; A0 ends on the terminator.
bar_append:
        move.b (a1)+,(a0)+
        bne.s bar_append
        subq.l #1,a0
        rts

; Write "X000 Y000" for the cursor cell, or nothing for the SAVED notice
; and the DELETE readout. Preserves all registers.
bar_compose_xy:
        movem.l d0-d1/a0-a1,-(sp)
        lea BAR_XY_TEXT,a0
        move.w TERRAIN_CURSOR_X,d0
        bmi.s .empty
        move.b #'X',(a0)+
        moveq #2,d1
        bsr.s bar_digits
        move.b #' ',(a0)+
        move.b #'Y',(a0)+
        move.w TERRAIN_CURSOR_Y,d0
        moveq #2,d1
        bsr.s bar_digits
.empty:
        clr.b (a0)
        movem.l (sp)+,d0-d1/a0-a1
        rts

; Append "  Phase n of m" and "  Unsaved" to the information line at A0.
; Clobbers D0-D1/A1.
bar_append_phase:
        lea bar_phase_text(pc),a1
        bsr.s bar_append
        moveq #0,d0
        move.b AUR_BASE+AUR_SELECTED,d0
        addq.w #1,d0
        moveq #0,d1
        bsr.s bar_digits
        lea bar_of_text(pc),a1
        bsr.s bar_append
        moveq #0,d0
        move.b AUR_BASE+AUR_PHASE_COUNT,d0
        moveq #0,d1
        bsr bar_digits
        btst #1,AUR_BASE+AUR_FLAGS+1
        beq.s .saved
        lea bar_unsaved_text(pc),a1
        bsr.s bar_append
.saved:
        clr.b (a0)
        rts

bar_target_ui:
        dc.l BAR_BITMAP,BAR_PLANE,bar_ui_roles
bar_target_terrain:
        dc.l BAR_BITMAP,BAR_PLANE,BAR_ROLES
bar_ui_roles:
        dc.b 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15

bar_list:
        dc.w UI_RECT,0,0,320,BAR_UI_ROWS,UI_BG
bar_buttons:
        dc.w UI_BUTTON_REF,2,BAR_TOOL_Y,44,BAR_BUTTON_H
        dc.l BAR_STATES+0
        dc.l bar_paint_label
        dc.w UI_BUTTON_REF,48,BAR_TOOL_Y,38,BAR_BUTTON_H
        dc.l BAR_STATES+2
        dc.l bar_fill_label
        dc.w UI_BUTTON_REF,88,BAR_TOOL_Y,50,BAR_BUTTON_H
        dc.l BAR_STATES+4
        dc.l bar_object_label
        dc.w UI_BUTTON_REF,140,BAR_TOOL_Y,50,BAR_BUTTON_H
        dc.l BAR_STATES+6
        dc.l bar_marker_label
        dc.w UI_BUTTON_REF,192,BAR_TOOL_Y,54,BAR_BUTTON_H
        dc.l BAR_STATES+8
        dc.l bar_inspect_label
        dc.w UI_BUTTON_REF,3,BAR_COMMAND_Y,48,BAR_BUTTON_H
        dc.l BAR_STATES+10
        dc.l bar_undo_label
        dc.w UI_BUTTON_REF,53,BAR_COMMAND_Y,48,BAR_BUTTON_H
        dc.l BAR_STATES+12
        ifd BAR_OBJECT_MODE
        dc.l bar_delete_label
        else
        dc.l bar_tiles_label
        endif
        dc.w UI_BUTTON_REF,103,BAR_COMMAND_Y,48,BAR_BUTTON_H
        dc.l BAR_STATES+14
        dc.l bar_check_label
        dc.w UI_BUTTON_REF,153,BAR_COMMAND_Y,48,BAR_BUTTON_H
        dc.l BAR_STATES+16
        dc.l bar_test_label
        dc.w UI_BUTTON_REF,203,BAR_COMMAND_Y,48,BAR_BUTTON_H
        dc.l BAR_STATES+18
        dc.l bar_save_label
        dc.w UI_BUTTON_REF,253,BAR_COMMAND_Y,48,BAR_BUTTON_H
        dc.l BAR_STATES+20
        dc.l bar_menu_label
bar_xy_list:
        dc.w UI_RECT,248,BAR_TOOL_Y,56,BAR_BUTTON_H,UI_BG
        dc.w UI_TEXT_AT,248,BAR_TOOL_Y+3,55,UI_INK,UI_RIGHT
        dc.l BAR_XY_TEXT
        dc.w UI_END
bar_band_list:
        dc.w UI_RECT,0,BAR_UI_ROWS,320,BAR_ROWS-BAR_UI_ROWS,UI_BG
        dc.w UI_TEXT_AT,22,BAR_INFO_Y,264,UI_INK,UI_LEFT
        dc.l BAR_INFO_TEXT
        dc.w UI_END
bar_info_list:
        dc.w UI_RECT,20,BAR_UI_ROWS,300,BAR_ROWS-BAR_UI_ROWS,UI_BG
        dc.w UI_TEXT_AT,22,BAR_INFO_Y,264,UI_INK,UI_LEFT
        dc.l BAR_INFO_TEXT
        dc.w UI_END

bar_paint_label: dc.b "Paint",0
bar_fill_label: dc.b "Fill",0
bar_object_label: dc.b "Object",0
bar_marker_label: dc.b "Marker",0
bar_inspect_label: dc.b "Inspect",0
bar_undo_label: dc.b "Undo",0
bar_tiles_label: dc.b "Tiles",0
bar_delete_label: dc.b "Delete",0
bar_check_label: dc.b "Check",0
bar_test_label: dc.b "Test",0
bar_save_label: dc.b "Save",0
bar_menu_label: dc.b "Menu",0
bar_phase_text: dc.b "  Phase ",0
bar_of_text: dc.b " of ",0
bar_unsaved_text: dc.b "  Unsaved",0
bar_saved_text: dc.b "Saved.",0
        even
