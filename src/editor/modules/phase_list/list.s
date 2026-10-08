; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Mission phases: a dialog of the Slave's dialog service with one row per
; logical phase (number, title, size and the phase being edited), Edit, Move
; up, Move down, Delete, Add copy, Add blank..., Add template..., Settings...,
; Done (default) and Cancel. Reordering and deleting other phases stay
; private until Done; Edit, Delete of the edited phase, the additions and
; Settings leave through the ordinary guarded replacement and are disabled
; while private changes are pending. With the Blank intent the page is the
; shared New dialog instead.
PHL_ACTION_CODE     equ 10  ; 10..17 actions 0..7
PHL_ROW_CODE        equ 20  ; 20..25 rows
PHL_ROW_TEXT        equ EDITOR_READBACK_BASE
PHL_ROW_TEXT_BYTES  equ 50
PHL_TITLE_CHARS     equ 27
PHL_SIZE_COLUMN     equ 31
PHL_STATUS_Y        equ 133
NEW_DIALOG_FAMILY   equ PHL_BLANK_FAMILY
NEW_DIALOG_WIDTH    equ PHL_BLANK_WIDTH
NEW_DIALOG_HEIGHT   equ PHL_BLANK_HEIGHT
NEW_DIALOG_PHASE    equ 1

page_open:
        cmpi.w #AUR_CONTINUE_PHASE_BLANK,PHL_INTENT
        beq new_dialog_open
        ; The mission title, at most 28 characters, in the title strip.
        lea PHL_ORIGINAL+CFMD_TITLE,a1
        lea EXIT_TEXT,a0
        moveq #27,d0
.title:
        move.b (a1)+,d1
        cmpi.b #$FF,d1
        beq.s .titled
        move.b d1,(a0)+
        dbf d0,.title
.titled:
        clr.b (a0)
        lea dlg_phase_list(pc),a0
        moveq #0,d2
        bsr dialog_open
        bne.s .out
        bsr phl_list_refresh
        moveq #0,d0
.out:
        rts

page_step:
        bsr dialog_poll
        bmi edtr_modal_idle
        cmpi.w #AUR_CONTINUE_PHASE_BLANK,PHL_INTENT
        bne.s .list
        bsr new_dialog_event
        bmi edtr_modal_idle
        bra phl_ui_finish
.list:
        clr.w PHL_STATUS
        cmpi.w #1,d0
        bhi.s .control
        bne phl_ui_finish
        move.w #1,PHL_READY
        bra phl_ui_finish
.control:
        cmpi.w #PHL_ROW_CODE,d0
        blo.s .action
        subi.w #PHL_ROW_CODE,d0
        move.w d0,PHL_FOCUS
        bra phl_ui_redraw
.action:
        move.w d0,d3
        subi.w #PHL_ACTION_CODE,d3
        moveq #0,d1
        move.w PHL_FOCUS,d1
        tst.w d3
        beq.s .select
        cmpi.w #3,d3
        bhs.s .other
        move.w d1,d2
        subq.w #1,d2
        cmpi.w #1,d3
        beq.s .move
        addq.w #2,d2
.move:
        andi.l #$FFFF,d2
        moveq #0,d0
        lea PHL_MAP,a0
        bsr phl_map_apply
        tst.w d0
        bmi phl_ui_error
        move.w d2,PHL_FOCUS
        bra phl_ui_redraw
.other:
        cmpi.w #4,d3
        bne.s .guarded
        cmp.b PHL_MAP+7,d1
        beq.s .guarded
        moveq #1,d0
        lea PHL_MAP,a0
        bsr phl_map_apply
        tst.w d0
        bmi phl_ui_error
        moveq #0,d0
        move.b PHL_MAP+6,d0
        cmp.w PHL_FOCUS,d0
        bhi phl_ui_redraw
        subq.w #1,PHL_FOCUS
        bra.s phl_ui_redraw
.select:
        cmp.b PHL_MAP+7,d1
        beq.s phl_ui_redraw
.guarded:
        cmpi.w #6,d3
        bhs.s .add_bound
        cmpi.w #3,d3
        bne.s .delete_bound
.add_bound:
        cmpi.b #6,PHL_MAP+6
        beq.s .bounded
.delete_bound:
        cmpi.w #4,d3
        bne.s .private_check
        cmpi.b #1,PHL_MAP+6
        bne.s .private_check
.bounded:
        moveq #PHL_ERROR_SOURCE,d0
        bra.s phl_ui_error
.private_check:
        bsr phl_private_changed
        tst.w d0
        bne.s .private
        cmpi.w #5,d3
        beq.s .settings
        move.w d3,d0
        addi.w #AUR_CONTINUE_PHASE_BLANK-6,d0
        cmpi.w #6,d3
        bhs.s .intent
        moveq #AUR_CONTINUE_PHASE_DELETE,d0
        cmpi.w #4,d3
        beq.s .intent
        move.w PHL_FOCUS,d0
        addq.w #AUR_CONTINUE_PHASE_SELECT,d0
        tst.w d3
        beq.s .intent
        addq.w #6,d0
.intent:
        move.w d0,PHL_INTENT
        moveq #2,d0
        bra.s phl_ui_finish
.settings:
        moveq #3,d0
        bra.s phl_ui_finish
.private:
        moveq #PHL_ERROR_PRIVATE,d0
phl_ui_error:
        move.w d0,PHL_STATUS
phl_ui_redraw:
        bsr.s phl_list_refresh
        bra edtr_modal_idle
phl_ui_finish:
        move.w d0,EXIT_CHOICE
        bra edtr_modal_finish

; Row texts, every button state and the status line.
phl_list_refresh:
        movem.l d0-d7/a0-a2,-(sp)
        bsr phl_list_texts
        ; D7 = disabled buttons.
        moveq #0,d7
        moveq #0,d4
        move.b PHL_MAP+6,d4
        move.w d4,d0
.rows:
        cmpi.w #6,d0
        bhs.s .rows_done
        bset d0,d7
        addq.w #1,d0
        bra.s .rows
.rows_done:
        move.w PHL_FOCUS,d5
        bsr phl_private_changed
        sne d6
        ; Edit: another phase and no pending change.
        cmp.b PHL_MAP+7,d5
        beq.s .no_edit
        tst.b d6
        beq.s .edit
.no_edit:
        bset #6,d7
.edit:
        tst.w d5
        bne.s .up
        bset #7,d7
.up:
        move.w d5,d0
        addq.w #1,d0
        cmp.w d4,d0
        blo.s .down
        bset #8,d7
.down:
        cmpi.w #1,d4
        beq.s .no_delete
        cmp.b PHL_MAP+7,d5
        bne.s .delete
        tst.b d6
        beq.s .delete
.no_delete:
        bset #9,d7
.delete:
        tst.b d6
        bne.s .no_add
        cmpi.w #6,d4
        blo.s .add
.no_add:
        bset #10,d7
        bset #11,d7
        bset #12,d7
.add:
        tst.b d6
        beq.s .states
        bset #13,d7
.states:
        moveq #0,d2
.state:
        moveq #UI_DISABLED,d3
        btst d2,d7
        bne.s .set
        moveq #UI_NORMAL,d3
        cmp.w d5,d2
        bne.s .set
        moveq #UI_ACTIVE,d3
.set:
        suba.l a0,a0
        bsr dialog_set
        addq.w #1,d2
        cmpi.w #14,d2
        blo.s .state
        ; The phase count, then a hint or the refusal.
        lea EXIT_NUMBER,a0
        move.w d4,d0
        bsr dialog_number
        lea phl_of_six(pc),a1
        bsr dialog_copy
        lea EXIT_NUMBER,a1
        moveq #8,d1
        move.w #PHL_STATUS_Y,d2
        moveq #90,d3
        moveq #UI_DIM,d4
        moveq #UI_LEFT,d5
        bsr dialog_field
        lea phl_hint(pc),a1
        tst.b d6
        beq.s .status
        lea phl_pending(pc),a1
        moveq #UI_WARN,d4
.status:
        tst.w PHL_STATUS
        beq.s .line
        lea phl_refused(pc),a1
        moveq #UI_ERROR,d4
.line:
        moveq #100,d1
        move.w #200,d3
        bsr dialog_field
        movem.l (sp)+,d0-d7/a0-a2
        rts

; "1  TITLE ... 40 x 30  editing" for every logical phase.
phl_list_texts:
        lea PHL_ROW_TEXT,a2
        moveq #0,d6
.row:
        movea.l a2,a0
        clr.b (a0)
        cmp.b PHL_MAP+6,d6
        bhs .next
        move.b d6,d0
        addi.b #'1',d0
        move.b d0,(a0)+
        move.b #' ',(a0)+
        move.b #' ',(a0)+
        cmp.b PHL_MAP+7,d6
        bne.s .source
        lea PHL_ORIGINAL+CFMD_PHASE_TITLE,a1
        move.l PHL_CURRENT_SIZE,d5
        bra.s .title
.source:
        lea PHL_MAP,a1
        moveq #0,d0
        move.b (a1,d6.w),d0
        mulu #PHL_ROW_BYTES,d0
        lea PHL_CACHE,a1
        adda.w d0,a1
        move.l PHL_ROW_SIZE(a1),d5
.title:
        moveq #PHL_TITLE_CHARS-1,d0
.title_copy:
        move.b (a1)+,d1
        cmpi.b #$FF,d1
        beq.s .pad
        move.b d1,(a0)+
        dbf d0,.title_copy
.pad:
        lea PHL_SIZE_COLUMN(a2),a1
.space:
        cmpa.l a1,a0
        bhs.s .size
        move.b #' ',(a0)+
        bra.s .space
.size:
        move.l d5,d0
        swap d0
        bsr dialog_number
        lea phl_times(pc),a1
        bsr dialog_copy
        move.w d5,d0
        bsr dialog_number
        cmp.b PHL_MAP+7,d6
        bne.s .next
        lea phl_editing(pc),a1
        bsr dialog_copy
.next:
        lea PHL_ROW_TEXT_BYTES(a2),a2
        addq.w #1,d6
        cmpi.w #6,d6
        blo .row
        rts

phl_times: dc.b " x ",0
phl_editing: dc.b "  editing",0
phl_of_six: dc.b " of 6 phases",0
phl_hint: dc.b "Click a phase, then an action.",0
phl_pending: dc.b "Done applies the new order first.",0
phl_refused: dc.b "That change is not possible.",0
        even

; Rows on Y50-126; the actions on three rows below the status line.
dlg_phase_list:
        dc.w 32,168,UI_SELECT
        dc.l phl_heading,phl_body
        dc.w 14,0,16
        dc.w 8,50,292,12,PHL_ROW_CODE,UI_NORMAL|DIALOG_ROW
        dc.l PHL_ROW_TEXT
        dc.w 8,63,292,12,PHL_ROW_CODE+1,UI_NORMAL|DIALOG_ROW
        dc.l PHL_ROW_TEXT+PHL_ROW_TEXT_BYTES
        dc.w 8,76,292,12,PHL_ROW_CODE+2,UI_NORMAL|DIALOG_ROW
        dc.l PHL_ROW_TEXT+2*PHL_ROW_TEXT_BYTES
        dc.w 8,89,292,12,PHL_ROW_CODE+3,UI_NORMAL|DIALOG_ROW
        dc.l PHL_ROW_TEXT+3*PHL_ROW_TEXT_BYTES
        dc.w 8,102,292,12,PHL_ROW_CODE+4,UI_NORMAL|DIALOG_ROW
        dc.l PHL_ROW_TEXT+4*PHL_ROW_TEXT_BYTES
        dc.w 8,115,292,12,PHL_ROW_CODE+5,UI_NORMAL|DIALOG_ROW
        dc.l PHL_ROW_TEXT+5*PHL_ROW_TEXT_BYTES
        dc.w 8,145,70,14,PHL_ACTION_CODE,UI_NORMAL
        dc.l phl_label_edit
        dc.w 82,145,70,14,PHL_ACTION_CODE+1,UI_NORMAL
        dc.l phl_label_up
        dc.w 156,145,70,14,PHL_ACTION_CODE+2,UI_NORMAL
        dc.l phl_label_down
        dc.w 230,145,70,14,PHL_ACTION_CODE+4,UI_NORMAL
        dc.l phl_label_delete
        dc.w 8,162,94,14,PHL_ACTION_CODE+3,UI_NORMAL
        dc.l phl_label_copy
        dc.w 106,162,94,14,PHL_ACTION_CODE+6,UI_NORMAL
        dc.l phl_label_blank
        dc.w 204,162,96,14,PHL_ACTION_CODE+7,UI_NORMAL
        dc.l phl_label_template
        dc.w 8,181,94,14,PHL_ACTION_CODE+5,UI_NORMAL
        dc.l phl_label_settings
        dc.w 106,181,94,14,1,UI_NORMAL
        dc.l phl_label_done
        dc.w 204,181,96,14,0,UI_NORMAL
        dc.l phl_label_cancel
phl_body:
        dc.w UI_TEXT_AT,128,36,172,UI_ACCENT,UI_RIGHT
        dc.l EXIT_TEXT
        dc.w UI_END
phl_heading: dc.b "Mission phases",0
phl_label_edit: dc.b "Edit",0
phl_label_up: dc.b "Move up",0
phl_label_down: dc.b "Move down",0
phl_label_delete: dc.b "Delete",0
phl_label_copy: dc.b "Add copy",0
phl_label_blank: dc.b "Add blank...",0
phl_label_template: dc.b "Add template...",0
phl_label_settings: dc.b "Settings...",0
phl_label_done: dc.b "Done",0
phl_label_cancel: dc.b "Cancel",0
        even
