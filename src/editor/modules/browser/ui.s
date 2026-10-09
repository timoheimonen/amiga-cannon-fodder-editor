; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; The Custom levels browser: full-height dialogs of the WHDLoad Slave's dialog
; service (the page, the directory error and the deletion confirmation), over
; black. The hill's display is left untouched and is shown again on leave.
BROWSER_UI_KIND         equ EDITOR_UI_BASE
BROWSER_UI_NONE         equ 0
BROWSER_UI_PAGE         equ 1
BROWSER_UI_ERROR        equ 2
BROWSER_UI_CONFIRM      equ 3
browser_ui_game         equ EDITOR_UI_BASE+2
; Four row details of 21 bytes, shown under the row titles.
browser_ui_details      equ EDITOR_UI_BASE+4
BROWSER_UI_DETAIL_BYTES equ 21
browser_ui_keep         equ EDITOR_UI_BASE+88
browser_ui_drive        equ EDITOR_UI_BASE+90
browser_ui_error_mode   equ EDITOR_UI_BASE+92
browser_ui_qualified    equ EDITOR_UI_BASE+94
; The page title is copied here before the page opens; the confirmation
; reuses the area for its title once the page is closed.
browser_ui_title        equ EDITOR_UI_BASE+96
EXIT_LIST               equ EDITOR_UI_BASE+186
; The page top and view the open list was drawn for.
browser_ui_top          equ EDITOR_UI_BASE+218
browser_ui_files        equ EDITOR_UI_BASE+220
; Row and field of the last click on a mission.
browser_ui_click        equ EDITOR_UI_BASE+222
browser_ui_end          equ EDITOR_UI_BASE+226
browser_ui_text         equ EDITOR_SERIAL_WORK_BASE+864
browser_ui_format       equ EDITOR_SERIAL_WORK_BASE+928
browser_ui_temporary_end equ EDITOR_SERIAL_WORK_BASE+992
BROWSER_UI_ROW          equ 20

; Keep the hill's drive state for its own restoration. No hill animation
; executes while the browser is entered.
browser_ui_enter:
        move.w  native_gameplay_active,browser_ui_game
        move.w  sensi_keep_drive_selected,browser_ui_keep
        move.w  sensi_selected_drive,browser_ui_drive
        clr.w   BROWSER_UI_KIND
        clr.w   browser_ui_error_mode
        clr.w   browser_ui_qualified
        move.w  #-1,browser_ui_click
        clr.w   native_gameplay_active
        clr.w   native_last_key
.release:
        jsr     wait_frame
        tst.w   native_left_down
        bne.s   .release
        clr.w   native_left_pressed
        rts

browser_ui_leave:
        bsr.s   browser_ui_close
        bsr     dialog_release
        move.w  browser_ui_game,native_gameplay_active
        move.w  browser_ui_drive,d1
        bsr     browser_select_drive
        move.w  browser_ui_keep,d1
        moveq   #36,d0
        jsr     sensi_disk_command
        rts

; Closes whichever browser dialog is open.
browser_ui_close:
        tst.w   BROWSER_UI_KIND
        beq.s   .done
        bsr     dialog_close
        clr.w   BROWSER_UI_KIND
.done:
        rts

; The open list of the same page and view only updates the rows and
; buttons; another page or view is redrawn in place. D7 is nonzero for the
; update.
browser_ui_draw:
        movem.l d0-d7/a0-a4,-(sp)
        clr.w   browser_ui_error_mode
        moveq   #0,d7
        cmpi.w  #BROWSER_UI_PAGE,BROWSER_UI_KIND
        beq.s   .open
        bsr.s   browser_ui_close
        bra.s   .title
.open:
        move.w  BROWSER_TOP,d0
        cmp.w   browser_ui_top,d0
        bne.s   .title
        move.w  BROWSER_FILES_VIEW,d0
        cmp.w   browser_ui_files,d0
        bne.s   .title
        moveq   #1,d7
.title:
        ; Title strip.
        lea     browser_title(pc),a0
        cmpi.w  #REQ_PURPOSE_EDITOR,BROWSER_PURPOSE
        bne.s   .mode_title
        lea     browser_editor_title(pc),a0
.mode_title:
        tst.w   BROWSER_FILES_VIEW
        beq.s   .heading
        lea     browser_files_recovery_label(pc),a0
.heading:
        lea     browser_ui_title,a1
        bsr     browser_ui_copy
        ; Room left.
        lea     browser_ui_text,a1
        lea     browser_room_label(pc),a0
        bsr     browser_append
        moveq   #0,d0
        move.w  BROWSER_FREE_RECORDS,d0
        bsr     browser_decimal
        lea     browser_records_label(pc),a0
        bsr     browser_append
        move.l  BROWSER_FREE_BYTES,d0
        bsr     browser_decimal
        lea     browser_bytes_label(pc),a0
        bsr     browser_append
        clr.b   (a1)
        ; Row details: phases and damage, or files in the recovery view.
        moveq   #0,d6
        lea     BROWSER_ROWS,a4
        lea     browser_ui_details,a3
.detail:
        movea.l a3,a1
        cmp.w   BROWSER_PAGE_COUNT,d6
        bhs.s   .detail_end
        moveq   #0,d0
        move.w  BROWSER_ROW_PHASES(a4),d0
        lea     browser_phases_label(pc),a0
        tst.w   BROWSER_FILES_VIEW
        beq.s   .detail_kind
        lea     browser_files_count_label(pc),a0
.detail_kind:
        cmpi.w  #1,d0
        bne.s   .plural
        ; The singular label follows its plural.
.skip:
        tst.b   (a0)+
        bne.s   .skip
.plural:
        bsr     browser_decimal
        bsr     browser_append
        cmpi.w  #BROWSER_ROW_DAMAGED,BROWSER_ROW_STATUS(a4)
        bne.s   .detail_end
        lea     browser_damaged_detail(pc),a0
        bsr     browser_append
.detail_end:
        clr.b   (a1)
        lea     BROWSER_UI_DETAIL_BYTES(a3),a3
        lea     BROWSER_ROW_BYTES(a4),a4
        addq.w  #1,d6
        cmpi.w  #4,d6
        blo.s   .detail
        ; Disabled buttons: rows past the page, Up, Down, the primary action
        ; on an empty list, New, Delete... and Recover....
        moveq   #0,d2
        move.w  BROWSER_PAGE_COUNT,d0
.disabled_rows:
        cmpi.w  #4,d0
        bhs.s   .up
        bset    d0,d2
        addq.w  #1,d0
        bra.s   .disabled_rows
.up:
        tst.w   BROWSER_SELECTED
        bne.s   .down
        bset    #4,d2
.down:
        move.w  BROWSER_SELECTED,d0
        addq.w  #1,d0
        cmp.w   BROWSER_COUNT,d0
        blo.s   .primary
        bset    #5,d2
.primary:
        tst.w   BROWSER_COUNT
        bne.s   .files
        bset    #6,d2
.files:
        tst.w   BROWSER_FILES_VIEW
        bne.s   .no_files
        tst.w   BROWSER_COUNT
        bne.s   .recover
        bset    #7,d2
.recover:
        tst.w   BDQ_CONTEXT+BDQ_RECOVERY_COUNT
        bne.s   .new
        bset    #8,d2
        bra.s   .new
.no_files:
        bset    #7,d2
        bset    #8,d2
.new:
        lea     dlg_browser(pc),a0
        cmpi.w  #REQ_PURPOSE_EDITOR,BROWSER_PURPOSE
        bne.s   .open_page
        tst.w   BROWSER_FILES_VIEW
        bne.s   .open_page
        lea     dlg_browser_editor(pc),a0
        bsr     browser_can_new
        bne.s   .open_page
        bset    #9,d2
.open_page:
        tst.w   d7
        beq.s   .whole
        ; Up, Down, Delete..., Recover... and New... follow the mask.
        move.l  d2,d6
        moveq   #4,d2
.mask:
        cmpi.w  #6,d2
        beq.s   .mask_next
        moveq   #UI_NORMAL,d3
        btst    d2,d6
        beq.s   .mask_set
        moveq   #UI_DISABLED,d3
.mask_set:
        movea.l a0,a2
        suba.l  a0,a0
        bsr     dialog_set
        movea.l a2,a0
.mask_next:
        addq.w  #1,d2
        cmpi.w  #9,d2
        bls.s   .mask
        bra.s   .shown
.whole:
        bsr     dialog_open
        bne     .out
        move.w  #BROWSER_UI_PAGE,BROWSER_UI_KIND
        move.w  BROWSER_TOP,browser_ui_top
        move.w  BROWSER_FILES_VIEW,browser_ui_files
.shown:
        ; Row titles, the selected one active; an empty list says so.
        moveq   #0,d2
        lea     BROWSER_ROWS,a4
.row:
        moveq   #UI_DISABLED,d3
        lea     browser_none(pc),a0
        cmp.w   BROWSER_PAGE_COUNT,d2
        bhs.s   .row_empty
        moveq   #UI_NORMAL,d3
        move.w  d2,d0
        add.w   BROWSER_TOP,d0
        cmp.w   BROWSER_SELECTED,d0
        bne.s   .row_title
        moveq   #UI_ACTIVE,d3
.row_title:
        movea.l a4,a0
        move.w  BROWSER_ROW_STATUS(a4),d0
        beq.s   .row_set
        lea     browser_damaged(pc),a0
        cmpi.w  #BROWSER_ROW_DAMAGED,d0
        beq.s   .row_set
        lea     browser_glyph(pc),a0
        cmpi.w  #BROWSER_ROW_GLYPH,d0
        beq.s   .row_set
        lea     browser_wide(pc),a0
        bra.s   .row_set
.row_empty:
        tst.w   d2
        bne.s   .row_set
        tst.w   BROWSER_COUNT
        bne.s   .row_set
        lea     browser_empty(pc),a0
        tst.w   BROWSER_FILES_VIEW
        beq.s   .row_set
        lea     browser_empty_files(pc),a0
.row_set:
        bsr     dialog_set
        lea     BROWSER_ROW_BYTES(a4),a4
        addq.w  #1,d2
        cmpi.w  #4,d2
        blo.s   .row
        ; The primary action names what it does: Play or Edit, which check
        ; the mission first. It is disabled when a check has refused it.
        moveq   #UI_NORMAL,d3
        tst.w   BROWSER_VALIDATION
        beq.s   .label
        bsr     browser_can_action
        bne.s   .label
        moveq   #UI_DISABLED,d3
.label:
        lea     browser_play_action(pc),a0
        cmpi.w  #REQ_PURPOSE_EDITOR,BROWSER_PURPOSE
        bne.s   .action_text
        lea     browser_edit_action(pc),a0
.action_text:
        tst.w   BROWSER_FILES_VIEW
        beq.s   .primary_label
        moveq   #UI_NORMAL,d3
        lea     browser_files_delete_label(pc),a0
.primary_label:
        moveq   #6,d2
        tst.w   BROWSER_COUNT
        bne.s   .primary_set
        moveq   #UI_DISABLED,d3
.primary_set:
        bsr     dialog_set
        ; The status line, coloured by its meaning, over a cleared line.
        bsr.s   browser_ui_status
        lea     EXIT_LIST,a0
        move.w  #UI_RECT,(a0)+
        move.l  #(12<<16)|172,(a0)+
        move.l  #(288<<16)|8,(a0)+
        move.w  #UI_PANEL,(a0)+
        move.w  #UI_TEXT_AT,(a0)+
        move.l  #(12<<16)|172,(a0)+
        move.w  #288,(a0)+
        move.w  d5,(a0)+
        move.w  #UI_LEFT,(a0)+
        move.l  #browser_ui_format,(a0)+
        clr.w   (a0)
        lea     EXIT_LIST,a0
        bsr     dialog_draw
.out:
        movem.l (sp)+,d0-d7/a0-a4
        rts

; The status line in browser_ui_format, its colour role in D5.
browser_ui_status:
        lea     browser_ui_format,a1
        moveq   #UI_INK,d5
        move.w  BROWSER_FILES_STATUS,d0
        beq.s   .controller
        moveq   #UI_OK,d5
        lea     browser_files_verified(pc),a0
        cmpi.w  #-1,d0
        beq.s   .text
        moveq   #UI_ERROR,d5
        lea     browser_files_error_label(pc),a0
        bra.s   .number
.controller:
        move.w  BROWSER_CONTROLLER_STATUS,d0
        beq.s   .validation
        moveq   #UI_ERROR,d5
        lea     browser_start_error(pc),a0
.number:
        bsr     browser_append
        tst.w   d0
        bpl.s   .positive
        neg.w   d0
.positive:
        andi.l  #$ffff,d0
        bsr     browser_decimal
        bra.s   .end
.validation:
        move.w  BROWSER_VALIDATION,d0
        lea     browser_none(pc),a0
        beq.s   .text
        moveq   #UI_DIM,d5
        lea     browser_validating(pc),a0
        cmpi.w  #BROWSER_VALID_PENDING,d0
        beq.s   .text
        moveq   #UI_ERROR,d5
        lea     browser_validate_failed(pc),a0
        cmpi.w  #BROWSER_VALID_FAILED,d0
        beq.s   .text
        lea     browser_invalid(pc),a0
        cmpi.w  #BROWSER_VALID_INVALID,d0
        beq.s   .text
        moveq   #UI_WARN,d5
        lea     browser_review(pc),a0
.text:
        bsr     browser_append
.end:
        clr.b   (a1)
        rts

browser_ui_error:
        bsr     browser_ui_close
        move.w  #1,browser_ui_error_mode
        lea     dlg_browser_error(pc),a0
        moveq   #0,d2
        bsr     dialog_open
        bne.s   .out
        move.w  #BROWSER_UI_ERROR,BROWSER_UI_KIND
.out:
        rts

; One frame: 0 nothing, 1 Back, 2 up, 3 down, 4 the primary action or Retry,
; 6 a row was selected, 8 Delete..., 9 Recover..., 10 New. Opening and
; closing presses are drained by the dialogs.
browser_ui_input:
        jsr     wait_frame
        moveq   #2,d0
        cmpi.w  #$CC,native_last_key
        beq.s   .key
        moveq   #3,d0
        cmpi.w  #$CD,native_last_key
        bne.s   .poll
.key:
        clr.w   native_last_key
        rts
.poll:
        bsr     dialog_poll
        bmi.s   .none
        cmpi.w  #BROWSER_UI_ROW,d0
        blo.s   .return
        subi.w  #BROWSER_UI_ROW,d0
        add.w   BROWSER_TOP,d0
        cmp.w   BROWSER_COUNT,d0
        bhs.s   .none
        ; A double click on a mission chooses the primary action.
        lea     browser_ui_click,a0
        bsr     dialog_double
        bne.s   .primary
        cmp.w   BROWSER_SELECTED,d0
        beq.s   .none
        move.w  d0,BROWSER_SELECTED
        moveq   #6,d0
        rts
.primary:
        moveq   #4,d0
        rts
.none:
        moveq   #0,d0
.return:
        rts

; A0 string, ending with NUL or $FF, copied to A1 with a NUL.
browser_ui_copy:
        bsr.s   browser_append
        clr.b   (a1)
        rts

; D0 unsigned <= 999999, A1 has at least six output bytes.
browser_decimal:
        movem.l d1-d4/a2,-(sp)
        lea     browser_powers(pc),a2
        moveq   #5,d3
        moveq   #0,d4
.digit:
        move.l  (a2)+,d2
        moveq   #'0',d1
.subtract:
        cmp.l   d2,d0
        blo.s   .emit
        sub.l   d2,d0
        addq.b  #1,d1
        bra.s   .subtract
.emit:
        cmpi.b  #'0',d1
        bne.s   .visible
        tst.w   d4
        bne.s   .visible
        tst.w   d3
        bne.s   .next
.visible:
        move.b  d1,(a1)+
        moveq   #1,d4
.next:
        dbf     d3,.digit
        movem.l (sp)+,d1-d4/a2
        rts
browser_append:
        move.l  d0,-(sp)
.copy:
        move.b  (a0)+,d0
        beq.s   .done
        cmpi.b  #$FF,d0
        beq.s   .done
        move.b  d0,(a1)+
        bra.s   .copy
.done:
        move.l  (sp)+,d0
        rts

        even
browser_powers: dc.l 100000,10000,1000,100,10,1
; The page keeps the old hit zones: rows from Y54 every 28 lines, the actions
; on Y190-203 and Delete.../Recover... on Y208-221.
dlg_browser_editor:
        dc.w 8,216,UI_SELECT
        dc.l browser_ui_title,browser_page_body
        dc.w 6,1,11
        dc.w 8,54,256,12,BROWSER_UI_ROW,UI_NORMAL|DIALOG_ROW
        dc.l browser_none
        dc.w 8,82,256,12,BROWSER_UI_ROW+1,UI_NORMAL|DIALOG_ROW
        dc.l browser_none
        dc.w 8,110,256,12,BROWSER_UI_ROW+2,UI_NORMAL|DIALOG_ROW
        dc.l browser_none
        dc.w 8,138,256,12,BROWSER_UI_ROW+3,UI_NORMAL|DIALOG_ROW
        dc.l browser_none
        dc.w 268,54,32,14,2,UI_NORMAL
        dc.l browser_up_label
        dc.w 268,138,32,14,3,UI_NORMAL
        dc.l browser_down_label
        dc.w 16,190,94,14,4,UI_NORMAL
        dc.l browser_edit_action
        dc.w 16,208,94,14,8,UI_NORMAL
        dc.l browser_delete_label
        dc.w 112,208,94,14,9,UI_NORMAL
        dc.l browser_recover_label
        dc.w 112,190,94,14,10,UI_NORMAL
        dc.l browser_new_action
        dc.w 208,190,92,14,1,UI_NORMAL
        dc.l browser_back_action
dlg_browser:
        dc.w 8,216,UI_SELECT
        dc.l browser_ui_title,browser_page_body
        dc.w 6,1,10
        dc.w 8,54,256,12,BROWSER_UI_ROW,UI_NORMAL|DIALOG_ROW
        dc.l browser_none
        dc.w 8,82,256,12,BROWSER_UI_ROW+1,UI_NORMAL|DIALOG_ROW
        dc.l browser_none
        dc.w 8,110,256,12,BROWSER_UI_ROW+2,UI_NORMAL|DIALOG_ROW
        dc.l browser_none
        dc.w 8,138,256,12,BROWSER_UI_ROW+3,UI_NORMAL|DIALOG_ROW
        dc.l browser_none
        dc.w 268,54,32,14,2,UI_NORMAL
        dc.l browser_up_label
        dc.w 268,138,32,14,3,UI_NORMAL
        dc.l browser_down_label
        dc.w 16,190,182,14,4,UI_NORMAL
        dc.l browser_play_action
        dc.w 16,208,94,14,8,UI_NORMAL
        dc.l browser_delete_label
        dc.w 112,208,94,14,9,UI_NORMAL
        dc.l browser_recover_label
        dc.w 200,190,100,14,1,UI_NORMAL
        dc.l browser_back_action
browser_page_body:
        dc.w UI_TEXT_AT,128,12,168,UI_ACCENT,UI_RIGHT
        dc.l BROWSER_DISK_NAME
        dc.w UI_TEXT_AT,12,26,288,UI_DIM,UI_LEFT
        dc.l browser_ui_text
        dc.w UI_TEXT_AT,12,68,252,UI_DIM,UI_LEFT
        dc.l browser_ui_details
        dc.w UI_TEXT_AT,12,96,252,UI_DIM,UI_LEFT
        dc.l browser_ui_details+BROWSER_UI_DETAIL_BYTES
        dc.w UI_TEXT_AT,12,124,252,UI_DIM,UI_LEFT
        dc.l browser_ui_details+2*BROWSER_UI_DETAIL_BYTES
        dc.w UI_TEXT_AT,12,152,252,UI_DIM,UI_LEFT
        dc.l browser_ui_details+3*BROWSER_UI_DETAIL_BYTES
        dc.w UI_END
; Retry and Back keep the old zones on Y190-203.
dlg_browser_error:
        dc.w 52,160,UI_ERROR
        dc.l browser_error_title,browser_error_body
        dc.w 0,1,2
        dc.w 16,190,124,14,4,UI_NORMAL
        dc.l browser_retry_label
        dc.w 176,190,124,14,1,UI_NORMAL
        dc.l browser_back_action
browser_error_body:
        dc.w UI_TEXT,16,72,288,UI_INK,UI_LEFT
        dc.b "The Custom directory cannot be used. It needs",0
        even
        dc.w UI_TEXT,16,84,288,UI_INK,UI_LEFT
        dc.b "its CFEDITOR marker, no CFSDISK file and at",0
        even
        dc.w UI_TEXT,16,96,288,UI_INK,UI_LEFT
        dc.b "most 150 files. Fix it, then Retry.",0
        even
        dc.w UI_END

browser_title: dc.b "Custom levels",0
browser_editor_title: dc.b "Editor: choose a mission",0
browser_files_recovery_label: dc.b "Interrupted saves",0
browser_room_label: dc.b "Room left for ",0
browser_records_label: dc.b " files and ",0
browser_bytes_label: dc.b " bytes",0
browser_phases_label: dc.b " phases",0," phase",0
browser_files_count_label: dc.b " files",0," file",0
browser_damaged_detail: dc.b ", damaged",0
browser_none: dc.b 0
browser_damaged: dc.b "Damaged mission",0
browser_glyph: dc.b "Title uses characters the game cannot show",0
browser_wide: dc.b "Title too wide for the game",0
browser_empty: dc.b "No missions in Custom yet",0
browser_empty_files: dc.b "No leftover files",0
browser_files_verified: dc.b "Files deleted.",0
browser_invalid: dc.b "Invalid: errors must be fixed in the editor.",0
browser_review: dc.b "Review: playable, some goals need a playtest.",0
browser_validate_failed: dc.b "The mission could not be checked.",0
browser_validating: dc.b "Checking the mission...",0
browser_start_error: dc.b "Could not start, status ",0
browser_files_error_label: dc.b "File error, status ",0
browser_play_action: dc.b "_Play",0
browser_edit_action: dc.b "_Edit",0
browser_new_action: dc.b "_New...",0
browser_back_action: dc.b "Back",0
browser_files_delete_label: dc.b "Delete...",0
browser_delete_label: dc.b "_Delete...",0
browser_recover_label: dc.b "_Recover...",0
browser_up_label: dc.b "Up",0
browser_down_label: dc.b "Down",0
browser_error_title: dc.b "Custom directory needs attention",0
browser_retry_label: dc.b "_Retry",0
        even
        ifgt browser_ui_end-EDITOR_UI_BASE-EDITOR_UI_BYTES
        fail "Browser dialog state exceeds UI storage"
        endif
        ifgt browser_ui_temporary_end-EDITOR_SERIAL_WORK_BASE-STORAGE_READ_CANDIDATE_OFFSET
        fail "Browser text scratch overlaps storage candidate"
        endif
