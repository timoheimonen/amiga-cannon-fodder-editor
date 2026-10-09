; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        xdef edtr_modal,edtr_modal_idle
        xdef edtr_modal_finish,edtr_modal_end

; FILES: a dialog of the Slave's dialog service over the darkened map, in the
; mode LF_MODE names. 0 browses the missions or the recovery sets, 1 confirms
; a deletion, 2 reports its result. Returns 0 back, 1 delete/yes/OK, 2 up,
; 3 down, 4 recover, 5 a failed guard with its status in LF_STATUS.
; Owns WORK160..383 and UI96..159 until return. No disk calls; the delete
; guard is checked in memory every frame of modes 0 and 1.
EXIT_UI             equ EDITOR_SERIAL_WORK_BASE+160
FILES_HEADER        equ EXIT_UI
FILES_NUMBER        equ EXIT_UI+32
EXIT_CHOICE         equ EXIT_UI+192
EXIT_UI_BYTES       equ 224
FILES_UP            equ 2
FILES_DOWN          equ 3

edtr_modal:
        movem.l d1-d7/a0-a6,-(sp)
        bsr live_files_owner
        bne files_dialog_refuse
        clr.w EXIT_CHOICE
        bsr files_dialog_texts
        moveq #0,d2
        lea dlg_files_message(pc),a0
        cmpi.w #2,LF_MODE
        bne.s .browse
        tst.w LF_STATUS
        beq.s .open
        lea dlg_files_failed(pc),a0
        bra.s .open
.browse:
        lea dlg_files_confirm(pc),a0
        tst.w LF_MODE
        bne.s .open
        bsr files_dialog_mask
        lea dlg_files(pc),a0
.open:
        bsr dialog_open
        bne files_dialog_refuse

edtr_modal_idle:
        jsr wait_frame
        cmpi.w #2,LF_MODE
        beq.s .poll
        bsr browser_delete_check
        beq.s .keys
        ; The check takes Esc as the deletion's cancellation; before any
        ; file is deleted it is the dialog's Cancel or Back.
        cmpi.w #STORAGE_READ_CANCELLED,d0
        bne.s .failed
        tst.w BDQ_CONTEXT+BDQ_ATTEMPTED
        bne.s .failed
        clr.l BDQ_CONTEXT+BDQ_CANCEL
        moveq #0,d0
        bra.s .choice
.failed:
        move.w d0,LF_STATUS
        moveq #5,d0
        bra.s .choice
.keys:
        tst.w LF_MODE
        bne.s .poll
        moveq #FILES_UP,d0
        cmpi.w #$CC,native_last_key
        beq.s .key
        moveq #FILES_DOWN,d0
        cmpi.w #$CD,native_last_key
        bne.s .poll
.key:
        clr.w native_last_key
        bra.s .choice
.poll:
        bsr dialog_poll
        bmi.s edtr_modal_idle
.choice:
        move.w d0,EXIT_CHOICE

edtr_modal_finish:
        bsr dialog_close
        bsr dialog_release
        moveq #0,d0
        move.w EXIT_CHOICE,d0
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
files_dialog_refuse:
        moveq #EDTR_VISUAL_ERROR,d0
        movem.l (sp)+,d1-d7/a0-a6
        rts

; D2.w = disabled buttons of the browsing mode: Up 0, Down 1, Delete 2,
; Recover 3 (no leftovers, or already in the recovery view).
files_dialog_mask:
        moveq #0,d2
        move.w BROWSER_SELECTED,d0
        bne.s .up
        bset #0,d2
.up:
        addq.w #1,d0
        cmp.w BROWSER_COUNT,d0
        blo.s .down
        bset #1,d2
.down:
        tst.w BROWSER_COUNT
        bne.s .delete
        bset #2,d2
.delete:
        tst.w BROWSER_FILES_VIEW
        bne.s .recover
        tst.w BDQ_CONTEXT+BDQ_RECOVERY_COUNT
        bne.s .done
.recover:
        bset #3,d2
.done:
        rts

; Title strip, position or deletion counts in LF_TEXT, and the mode's text.
files_dialog_texts:
        movem.l d0-d2/a0-a1,-(sp)
        lea files_title_mission(pc),a0
        tst.w BROWSER_FILES_VIEW
        beq.s .header
        lea files_title_recovery(pc),a0
.header:
        lea FILES_HEADER,a1
        bsr files_dialog_copy
        lea LF_TEXT,a1
        cmpi.w #2,LF_MODE
        beq .message
        tst.w LF_MODE
        bne.s .counts
        tst.w BROWSER_COUNT
        bne.s .listed
        ; An empty list has no selection; its title would be stale.
        lea files_none(pc),a0
        lea LF_TITLE,a1
        bsr files_dialog_copy
        lea LF_TEXT,a1
.listed:
        lea files_position_mission(pc),a0
        tst.w BROWSER_FILES_VIEW
        beq.s .position
        lea files_position_set(pc),a0
.position:
        bsr files_dialog_append
        moveq #0,d0
        tst.w BROWSER_COUNT
        beq.s .number
        move.w BROWSER_SELECTED,d0
        addq.w #1,d0
.number:
        bsr files_decimal
        lea files_of(pc),a0
        bsr files_dialog_append
        moveq #0,d0
        move.w BROWSER_COUNT,d0
        bsr files_decimal
        bra .end
.counts:
        ; "5 files will be deleted.", or with several saved versions of the
        ; mission "9 files in 2 saved versions will be deleted."
        moveq #0,d0
        move.w BDQ_CONTEXT+BDQ_FILE_COUNT,d0
        bsr files_decimal
        lea files_word_files(pc),a0
        cmpi.w #1,BDQ_CONTEXT+BDQ_FILE_COUNT
        bne.s .files
        lea files_word_file(pc),a0
.files:
        bsr files_dialog_append
        cmpi.w #1,BDQ_CONTEXT+BDQ_GENERATION_COUNT
        beq.s .tail
        lea files_in(pc),a0
        bsr files_dialog_append
        moveq #0,d0
        move.w BDQ_CONTEXT+BDQ_GENERATION_COUNT,d0
        bsr files_decimal
        lea files_versions(pc),a0
        bsr files_dialog_append
.tail:
        lea files_deleted_tail(pc),a0
        bsr files_dialog_append
        bra.s .end
.message:
        ; Result title in FILES_HEADER, cause in LF_TEXT, status number below.
        lea files_done_title(pc),a0
        move.w LF_STATUS,d0
        beq.s .result
        lea files_failed_title(pc),a0
.result:
        lea FILES_HEADER,a1
        bsr.s files_dialog_copy
        lea LF_TEXT,a1
        lea files_done_text(pc),a0
        tst.w d0
        beq.s .cause
        lea files_in_use_text(pc),a0
        cmpi.w #LIVE_FILES_SOURCE_PROTECTED,d0
        beq.s .cause
        lea files_write_text(pc),a0
        cmpi.w #5,d0
        beq.s .cause
        lea files_error_text(pc),a0
.cause:
        bsr.s files_dialog_append
        clr.b (a1)
        lea FILES_NUMBER,a1
        clr.b (a1)
        ; Known causes are named; only an unknown one shows its status.
        move.w LF_STATUS,d0
        beq.s .done
        cmpi.w #LIVE_FILES_SOURCE_PROTECTED,d0
        beq.s .done
        cmpi.w #5,d0
        beq.s .done
        lea files_status_text(pc),a0
        bsr.s files_dialog_append
        tst.w d0
        bpl.s .positive
        move.b #'-',(a1)+
        neg.w d0
.positive:
        andi.l #$ffff,d0
        bsr files_decimal
.end:
        clr.b (a1)
.done:
        movem.l (sp)+,d0-d2/a0-a1
        rts
files_dialog_copy:
        bsr.s files_dialog_append
        clr.b (a1)
        rts
; A0 string appended at A1 without its NUL.
files_dialog_append:
        move.b (a0)+,(a1)+
        bne.s files_dialog_append
        subq.l #1,a1
        rts

; The browsing row keeps the old hit zones of Down, Delete, Recover and Back;
; the confirmation keeps Yes and the message keeps OK.
dlg_files:
        dc.w 44,80,UI_SELECT
        dc.l FILES_HEADER,files_body
        dc.w -1,0,5
        dc.w 8,103,36,14,FILES_UP,UI_NORMAL
        dc.l files_up_label
        dc.w 46,103,50,14,FILES_DOWN,UI_NORMAL
        dc.l files_down_label
        dc.w 98,103,78,14,1,UI_NORMAL
        dc.l files_delete_label
        dc.w 178,103,84,14,4,UI_NORMAL
        dc.l files_recover_label
        dc.w 264,103,36,14,0,UI_NORMAL
        dc.l files_back_label
files_body:
        dc.w UI_TEXT_AT,128,48,168,UI_ACCENT,UI_RIGHT
        dc.l BROWSER_DISK_NAME
        dc.w UI_TEXT_AT,16,62,288,UI_DIM,UI_LEFT
        dc.l LF_TEXT
        dc.w UI_TEXT_AT,16,74,288,UI_INK,UI_LEFT
        dc.l LF_TITLE
        dc.w UI_TEXT,16,86,288,UI_DIM,UI_LEFT
        dc.b "Delete... removes every file of the selection.",0
        even
        dc.w UI_END
dlg_files_confirm:
        dc.w 44,80,UI_ERROR
        dc.l files_confirm_title,files_confirm_body
        dc.w 1,0,2
        dc.w 160,103,70,14,1,UI_NORMAL
        dc.l files_delete_now_label
        dc.w 232,103,68,14,0,UI_NORMAL
        dc.l files_cancel_label
files_confirm_body:
        dc.w UI_TEXT_AT,16,62,288,UI_INK,UI_LEFT
        dc.l LF_TITLE
        dc.w UI_TEXT_AT,16,74,288,UI_INK,UI_LEFT
        dc.l LF_TEXT
        dc.w UI_TEXT,16,86,288,UI_WARN,UI_LEFT
        dc.b "Deleted files cannot be restored.",0
        even
        dc.w UI_END
dlg_files_message:
        dc.w 44,80,UI_SELECT
        dc.l FILES_HEADER,files_message_body
        dc.w 0,0,2
        dc.w 16,103,124,14,1,UI_NORMAL
        dc.l files_ok_label
        dc.w 176,103,124,14,0,UI_NORMAL
        dc.l files_editor_label
dlg_files_failed:
        dc.w 44,80,UI_ERROR
        dc.l FILES_HEADER,files_message_body
        dc.w 0,0,2
        dc.w 16,103,124,14,1,UI_NORMAL
        dc.l files_ok_label
        dc.w 176,103,124,14,0,UI_NORMAL
        dc.l files_editor_label
files_message_body:
        dc.w UI_TEXT_AT,16,62,288,UI_INK,UI_LEFT
        dc.l LF_TEXT
        dc.w UI_TEXT_AT,16,74,288,UI_DIM,UI_LEFT
        dc.l FILES_NUMBER
        dc.w UI_END

files_title_mission: dc.b "Mission files",0
files_title_recovery: dc.b "Interrupted saves",0
files_position_mission: dc.b "Mission ",0
files_position_set: dc.b "Leftover set ",0
files_of: dc.b " of ",0
files_none: dc.b "No files",0
files_word_files: dc.b " files",0
files_word_file: dc.b " file",0
files_in: dc.b " in ",0
files_versions: dc.b " saved versions",0
files_deleted_tail: dc.b " will be deleted.",0
files_confirm_title: dc.b "Delete files",0
files_done_title: dc.b "Files deleted",0
files_failed_title: dc.b "Could not delete",0
files_done_text: dc.b "The files were deleted from Custom.",0
files_in_use_text: dc.b "They belong to the mission open in the editor.",0
files_write_text: dc.b "Writing to Custom failed.",0
files_error_text: dc.b "The files could not be read or deleted.",0
files_status_text: dc.b "Status ",0
files_up_label: dc.b "Up",0
files_down_label: dc.b "Down",0
files_delete_label: dc.b "_Delete...",0
files_recover_label: dc.b "_Recover...",0
files_back_label: dc.b "Back",0
files_delete_now_label: dc.b "_Delete",0
files_cancel_label: dc.b "Cancel",0
files_ok_label: dc.b "_OK",0
files_editor_label: dc.b "_Back to editor",0
        even
edtr_modal_end:
