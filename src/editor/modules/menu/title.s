; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Title entry for Save as and the mission and phase titles, a dialog of the
; Slave's dialog service. The title is typed on the keyboard and edited by the bounded picker
; engine; Space, Delete and Clear are also buttons. The game's key table gives
; upper-case letters, digits and punctuation; Backspace and Del delete. The
; title starts selected: typing replaces it, and Left or Right keeps it.
MENU_TITLE_OK       equ 1
MENU_TITLE_CANCEL   equ 2
MENU_TITLE_SPACE    equ 3
MENU_TITLE_DELETE   equ 4
MENU_TITLE_CLEAR    equ 5
MENU_TITLE_FIELD_Y  equ 82
MENU_TITLE_STATUS_Y equ 114
; Glyph cells of the text field, the cursor included.
MENU_TITLE_CELLS    equ 264/UI_CELL_WIDTH

; D7.w=MENU_DIALOG_TITLE or MENU_DIALOG_PHASE_TITLE with a begun picker;
; for the latter PHM_FIELD names the mission (0) or the phase title.
; D0.l=0 open, otherwise refused.
menu_title_open:
        lea menu_title_save_as(pc),a1
        lea menu_title_mission_label(pc),a2
        cmpi.w #MENU_DIALOG_PHASE_TITLE,d7
        bne.s .texts
        lea menu_title_phase(pc),a1
        tst.w PHM_FIELD
        bne.s .field
        lea menu_title_mission(pc),a1
.field:
        movea.l a1,a2
.texts:
        ; The dialog draws its title and label once, from scratch that the
        ; field and status line reuse afterwards.
        lea EXIT_TEXT,a0
        bsr dialog_copy
        movea.l a2,a1
        lea EXIT_NUMBER,a0
        bsr dialog_copy
        lea dlg_title(pc),a0
        moveq #0,d2
        bsr dialog_open
        bne.s .out
        bsr.s menu_title_draw
        moveq #0,d0
.out:
        rts

; One frame of input: typed text first, then the dialog's buttons.
menu_title_step:
        move.w native_last_key,d1
        beq.s .poll
        moveq #PICKER_BACKSPACE,d0
        cmpi.w #$C1,d1
        beq.s .typed
        cmpi.w #$C6,d1
        beq.s .typed
        moveq #PICKER_KEEP,d0
        cmpi.w #$CE,d1
        beq.s .typed
        cmpi.w #$CF,d1
        beq.s .typed
        ; Return, Esc and other untranslated keys belong to the dialog.
        cmpi.w #$80,d1
        bhs.s .poll
        move.w d1,d0
.typed:
        clr.w native_last_key
        bra.s menu_title_event
.poll:
        bsr dialog_poll
        bmi edtr_modal_idle
        lea menu_title_codes-1(pc),a0
        move.b 0(a0,d0.w),d0
        ext.w d0
menu_title_event:
        cmpi.w #MENU_DIALOG_PHASE_TITLE,EXIT_KIND
        bne.s .save_as
        bsr phm_title_event
        bra.s .result
.save_as:
        bsr text_picker_event
.result:
        cmpi.w #1,d0
        beq.s .close
        cmpi.w #2,d0
        beq.s .close
        bsr.s menu_title_draw
        bra edtr_modal_idle
.close:
        move.w d0,EXIT_CHOICE
        bra edtr_modal_finish

; The edited text with a cursor, then the width or the last refusal.
menu_title_draw:
        movem.l d0-d5/a0-a2,-(sp)
        ; A long title shows its end, where the cursor is.
        lea picker_edit,a1
        move.w picker_length,d0
        subi.w #MENU_TITLE_CELLS-1,d0
        ble.s .whole
        adda.w d0,a1
.whole:
        lea EXIT_TEXT,a0
        bsr dialog_copy
        ; A selected title is shown highlighted, without the cursor.
        lea menu_title_selected(pc),a2
        tst.w picker_selected
        bne.s .field
        move.b #'_',(a0)+
        lea menu_title_field(pc),a2
.field:
        clr.b (a0)
        movea.l a2,a0
        bsr dialog_draw
        move.w picker_error,d0
        moveq #UI_ERROR,d4
        lea menu_title_errors(pc),a2
.find:
        move.w (a2)+,d1
        beq.s .width
        movea.l (a2)+,a1
        cmp.w d1,d0
        bne.s .find
        bra.s .status
.width:
        lea menu_title_width(pc),a1
        lea EXIT_NUMBER,a0
        bsr dialog_copy
        move.w picker_width,d0
        bsr dialog_number
        lea menu_title_of(pc),a1
        bsr dialog_copy
        move.w picker_hill_width,d0
        bsr dialog_number
        lea EXIT_NUMBER,a1
        moveq #UI_DIM,d4
.status:
        moveq #16,d1
        moveq #MENU_TITLE_STATUS_Y,d2
        move.w #272,d3
        moveq #UI_LEFT,d5
        bsr dialog_field
        movem.l (sp)+,d0-d5/a0-a2
        rts

menu_title_codes:
        dc.b PICKER_ACCEPT,PICKER_CANCEL,' ',PICKER_BACKSPACE,PICKER_CLEAR
        even
menu_title_errors:
        dc.w -2
        dc.l menu_title_glyph
        dc.w -3
        dc.l menu_title_wide
        dc.w -5
        dc.l menu_title_long
        dc.w -6
        dc.l menu_title_empty
        dc.w 0

; Old hit zones are kept: Space and Clear on Y128, OK and Cancel on Y146.
dlg_title:
        dc.w 52,116,UI_SELECT
        dc.l EXIT_TEXT,menu_title_body
        dc.w 3,MENU_TITLE_CANCEL,5
        dc.w 16,128,92,14,MENU_TITLE_SPACE,UI_NORMAL
        dc.l menu_title_space
        dc.w 112,128,92,14,MENU_TITLE_DELETE,UI_NORMAL|DIALOG_REPEAT
        dc.l menu_title_delete
        dc.w 208,128,92,14,MENU_TITLE_CLEAR,UI_NORMAL
        dc.l menu_title_clear
        dc.w 16,146,92,14,MENU_TITLE_OK,UI_NORMAL
        dc.l menu_title_ok
        dc.w 208,146,92,14,MENU_TITLE_CANCEL,UI_NORMAL
        dc.l dlg_cancel_label
menu_title_body:
        dc.w UI_TEXT_AT,16,70,272,UI_DIM,UI_LEFT
        dc.l EXIT_NUMBER
        dc.w UI_TEXT_AT,16,102,272,UI_DIM,UI_LEFT
        dc.l menu_title_hint
        dc.w UI_END
menu_title_field:
        dc.w UI_RECT,16,MENU_TITLE_FIELD_Y,272,14,UI_SHADOW
        dc.w UI_FRAME,16,MENU_TITLE_FIELD_Y,272,14,UI_LIGHT
        dc.w UI_TEXT_AT,20,MENU_TITLE_FIELD_Y+3,MENU_TITLE_CELLS*UI_CELL_WIDTH,UI_INK,UI_LEFT
        dc.l EXIT_TEXT
        dc.w UI_END
menu_title_selected:
        dc.w UI_RECT,16,MENU_TITLE_FIELD_Y,272,14,UI_SELECT
        dc.w UI_FRAME,16,MENU_TITLE_FIELD_Y,272,14,UI_LIGHT
        dc.w UI_TEXT_AT,20,MENU_TITLE_FIELD_Y+3,MENU_TITLE_CELLS*UI_CELL_WIDTH,UI_INK,UI_LEFT
        dc.l EXIT_TEXT
        dc.w UI_END

menu_title_save_as: dc.b "Save as",0
menu_title_mission_label: dc.b "Title of the new mission",0
menu_title_mission: dc.b "Mission title",0
menu_title_phase: dc.b "Phase title",0
menu_title_hint: dc.b "Type the title. Return: OK, Esc: Cancel.",0
menu_title_width: dc.b "Width ",0
menu_title_of: dc.b " of ",0
menu_title_glyph: dc.b "The game font has no such character.",0
menu_title_wide: dc.b "Too wide for the game's title.",0
menu_title_long: dc.b "Too long.",0
menu_title_empty: dc.b "Type a title first.",0
menu_title_space: dc.b "Space",0
menu_title_delete: dc.b "Delete",0
menu_title_clear: dc.b "Clear",0
menu_title_ok: dc.b "OK",0
        even
