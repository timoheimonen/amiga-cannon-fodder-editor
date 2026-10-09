; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Browser deletion confirmation, a dialog of the Slave's dialog service. No
; destructive calls. Include after the BROW UI/text helpers and
; browser_delete.i.

BROWSER_FILES_DELETE     equ 8
BROWSER_FILES_RECOVER    equ 9
files_ui_title          equ EDITOR_UI_BASE+96
files_ui_prepared       equ EDITOR_UI_BASE+160
files_ui_mission        equ EDITOR_UI_BASE+164
files_ui_intent         equ EDITOR_UI_BASE+166
files_ui_name           equ EDITOR_UI_BASE+168
files_ui_end_state      equ EDITOR_UI_BASE+184

        xdef browser_files_ui_start,browser_files_ui_end
        xdef browser_files_ui_prepare,browser_files_ui_confirm
        xdef browser_files_ui_idle,browser_files_ui_drain
browser_files_ui_start:

; D0.w=1: A0 is the freshly schema-validated selected title (64 readable
; bytes). D0.w=0: use the selected hexadecimal generation. No pointer is kept.
; A failed display projection falls back to the generation, not damaged text.
browser_files_ui_prepare:
        movem.l d1-d7/a0-a6,-(sp)
        move.w d0,d7
        bsr files_ui_owner
        bne files_ui_return
        bsr browser_delete_check
        bne files_ui_return
        clr.w files_ui_prepared
        cmpi.w #1,d7
        bhi files_ui_invalid
        move.w d7,files_ui_mission
        tst.w d7
        beq.s .generation
        cmpi.w #BDQ_DELETE,BDQ_CONTEXT+BDQ_OPERATION
        bne files_ui_invalid
        bsr browser_text_length
        lea files_ui_title,a1
        move.w #TITLE_HILL_WIDTH,d2
        bsr browser_text_project
        tst.l d0
        beq.s .ready
.generation:
        lea BDQ_CONTEXT+BDQ_NAME,a0
        lea files_ui_title,a1
        moveq #7,d1
.hex:
        move.b (a0)+,d0
        cmpi.b #'a',d0
        blo.s .upper
        cmpi.b #'f',d0
        bhi files_ui_invalid
        subi.b #32,d0
.upper:
        cmpi.b #'0',d0
        blo files_ui_invalid
        cmpi.b #'9',d0
        bls.s .store
        cmpi.b #'A',d0
        blo files_ui_invalid
        cmpi.b #'F',d0
        bhi files_ui_invalid
.store:
        move.b d0,(a1)+
        dbf d1,.hex
        move.b #$FF,(a1)
.ready:
        lea BDQ_CONTEXT+BDQ_NAME,a0
        lea files_ui_name,a1
        moveq #3,d0
.name:
        move.l (a0)+,(a1)+
        dbf d0,.name
        move.w #$4654,files_ui_prepared
        moveq #0,d0
        bra files_ui_return

; A fresh YES returns1; Return/NO returns0; Escape/cancel/refusal returns its
; nonzero error status (never1). Caller sets CONFIRMED only after another check.
; The full open guard stays owned by the caller across this synchronous modal.
browser_files_ui_confirm:
        movem.l d1-d7/a0-a6,-(sp)
        bsr files_ui_owner
        bne files_ui_return
        bsr browser_delete_check
        bne files_ui_return
        cmpi.w #1,BDQ_CONTEXT+BDQ_CLASS_READY
        bne files_ui_invalid
        cmpi.w #$4654,files_ui_prepared
        bne files_ui_invalid
        lea BDQ_CONTEXT+BDQ_NAME,a0
        lea files_ui_name,a1
        moveq #3,d0
.name:
        cmpm.l (a0)+,(a1)+
        bne files_ui_invalid
        dbf d0,.name
        move.w BDQ_CONTEXT+BDQ_OPERATION,d0
        subq.w #1,d0
        cmpi.w #1,d0
        bhi files_ui_invalid
        move.w BDQ_CONTEXT+BDQ_FILE_COUNT,d1
        beq files_ui_invalid
        cmpi.w #150,d1
        bhi files_ui_invalid
        move.w BDQ_CONTEXT+BDQ_GENERATION_COUNT,d2
        beq files_ui_invalid
        cmp.w d1,d2
        bhi files_ui_invalid
        bsr browser_files_ui_drain
        bne files_ui_finish
        ; Title, then "m files will be deleted.", with several saved
        ; versions "m files in n saved versions will be deleted."
        lea files_ui_label_files(pc),a0
        tst.w files_ui_mission
        beq.s .heading
        lea files_ui_label_mission(pc),a0
.heading:
        lea browser_ui_text,a1
        bsr browser_ui_copy
        lea browser_ui_format,a1
        moveq #0,d0
        move.w BDQ_CONTEXT+BDQ_FILE_COUNT,d0
        bsr browser_decimal
        lea files_ui_label_files_count(pc),a0
        cmpi.w #1,BDQ_CONTEXT+BDQ_FILE_COUNT
        bne.s .files
        lea files_ui_label_file_count(pc),a0
.files:
        bsr browser_append
        cmpi.w #1,BDQ_CONTEXT+BDQ_GENERATION_COUNT
        beq.s .tail
        lea files_ui_label_in(pc),a0
        bsr browser_append
        moveq #0,d0
        move.w BDQ_CONTEXT+BDQ_GENERATION_COUNT,d0
        bsr browser_decimal
        lea files_ui_label_versions(pc),a0
        bsr browser_append
.tail:
        lea files_ui_label_count(pc),a0
        bsr browser_append
        clr.b (a1)
        bsr browser_ui_close
        lea dlg_files_ui_confirm(pc),a0
        moveq #0,d2
        bsr dialog_open
        bne files_ui_invalid
        move.w #BROWSER_UI_CONFIRM,BROWSER_UI_KIND
browser_files_ui_idle:
        bsr files_ui_owner
        bne.s files_ui_finish
        bsr browser_delete_check
        bne.s files_ui_finish
        jsr wait_frame
        bsr browser_delete_check
        bne.s files_ui_finish
        bsr dialog_poll
        bmi.s browser_files_ui_idle
        move.w d0,files_ui_intent
        bsr browser_files_ui_drain
        bne.s files_ui_finish
        moveq #0,d0
        move.w files_ui_intent,d0
files_ui_finish:
        clr.w files_ui_prepared
        move.l d0,-(sp)
        bsr browser_ui_close
        move.l (sp)+,d0
        bra files_ui_return
files_ui_label_files: dc.b "Delete leftover files",0
files_ui_label_mission: dc.b "Delete mission",0
files_ui_label_files_count: dc.b " files",0
files_ui_label_file_count: dc.b " file",0
files_ui_label_in: dc.b " in ",0
files_ui_label_versions: dc.b " saved versions",0
files_ui_label_count: dc.b " will be deleted.",0
        even
; Delete keeps the old Yes zone on Y144-157.
dlg_files_ui_confirm:
        dc.w 52,112,UI_ERROR
        dc.l browser_ui_text,files_ui_body
        dc.w 1,0,2
        dc.w 16,144,124,14,1,UI_NORMAL
        dc.l files_ui_delete_label
        dc.w 176,144,124,14,0,UI_NORMAL
        dc.l files_ui_cancel_label
files_ui_body:
        dc.w UI_TEXT_AT,128,56,168,UI_INK,UI_RIGHT
        dc.l BROWSER_DISK_NAME
        dc.w UI_TEXT_AT,16,70,288,UI_INK,UI_LEFT
        dc.l files_ui_title
        dc.w UI_TEXT_AT,16,84,288,UI_INK,UI_LEFT
        dc.l browser_ui_format
        dc.w UI_TEXT,16,98,288,UI_WARN,UI_LEFT
        dc.b "Deleted files cannot be restored.",0
        even
        dc.w UI_END
files_ui_delete_label: dc.b "_Delete",0
files_ui_cancel_label: dc.b "Cancel",0
        even

browser_files_ui_drain:
        bsr.s files_ui_owner
        bne.s .return
        bsr browser_delete_check
        bne.s .return
        clr.w native_last_key
        jsr wait_frame
        tst.w native_left_down
        bne.s browser_files_ui_drain
        clr.w native_left_pressed
        bsr browser_delete_check
.return:
        rts

; Require an open BROW dialog, not merely a stopped engine.
files_ui_owner:
        moveq #10,d0
        tst.w session_custom_mode
        bne.s .return
        tst.w SESSION_SNAPSHOT_VALID
        bne.s .return
        tst.w native_gameplay_active
        bne.s .return
        tst.w native_fifth_plane
        bne.s .return
        move.w sr,d1
        andi.w #$0700,d1
        bne.s .return
        cmpi.l #BROWSER_STATE_TAG,BROWSER_MAGIC
        bne.s .return
        cmpi.w #1,BROWSER_VERSION
        bne.s .return
        move.w BROWSER_PURPOSE,d1
        cmp.w EDITOR_SESSION_BASE+REQ_PURPOSE,d1
        bne.s .return
        subq.w #1,d1
        cmpi.w #1,d1
        bhi.s .return
        tst.w BROWSER_UI_KIND
        beq.s .return
        moveq #0,d0
.return:
        rts
files_ui_invalid:
        moveq #10,d0
files_ui_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
browser_files_ui_end:
        ifgt files_ui_end_state-EDITOR_UI_BASE-EDITOR_UI_BYTES
        fail "Browser file UI exceeds its transient UI partition"
        endif
