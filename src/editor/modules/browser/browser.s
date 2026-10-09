; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        include "layout.i"
        include "module.i"
        include "session.i"
        include "fodders.i"
        include "storage_read.i"
        include "storage.i"
        include "metadata.i"
        include "browser.i"
        include "browser_delete.i"
        include "ui.i"
        include "dialog.i"
        section .text,code
        xdef browser_start,browser_entry,browser_end
        xdef browser_idle,browser_before_read,browser_request_validation
        xdef browser_selection_ready,browser_resume
        xdef browser_can_play,browser_request_play
        xdef browser_can_new
        xdef browser_can_open,browser_request_new,browser_request_controller
browser_start:
        dc.l MODULE_MAGIC
        dc.w MODULE_ABI,MODULE_HEADER_BYTES
        dc.l BROWSER_MODULE_ID,EDITOR_MODULE_BASE
        dc.l browser_end-browser_start
        dc.l browser_entry-browser_start
        dc.l 0,0

; ABI 2: D0=2, A0=fixed resident session. Active recruitment hill only.
; All exits restore its display before returning through the dispatcher.
browser_entry:
        movem.l d1-d7/a0-a6,-(sp)
        cmpi.w  #2,d0
        bne     browser_bad_entry
        cmpa.l  #EDITOR_SESSION_BASE,a0
        bne     browser_bad_entry
        cmpi.w  #REQ_PURPOSE_EDITOR,REQ_PURPOSE(a0)
        beq.s   browser_control_purpose
        cmpi.w  #REQ_PURPOSE_PLAY,REQ_PURPOSE(a0)
        bne     browser_bad_entry
browser_control_purpose:
        clr.w   REQ_ACTION(a0)
        bsr     browser_qualify
        tst.w   d0
        bne     browser_qualification_failed
        bsr     browser_resume
        clr.w   BROWSER_FILES_VIEW
        bsr     browser_ui_enter
        move.w  #1,browser_ui_qualified
browser_control_inspect:
        bsr     browser_inspect
        tst.w   d0
        bne     browser_control_failed
        bsr     browser_files_catalog
        bne     browser_control_failed
        bsr     browser_page
        tst.w   d0
        bne     browser_control_failed
browser_control_redraw:
        ; Play and Edit check the selected mission first. When the check has
        ; returned, the action goes on without drawing the list again.
        tst.w   BROWSER_ACT
        beq.s   .draw
        clr.w   BROWSER_ACT
        bsr     browser_can_action
        bne     browser_request_action
.draw:
        tst.w   BROWSER_FILES_VIEW
        bne.s   .named
        tst.w   BROWSER_COUNT
        beq.s   .named
        bsr     browser_name_selected
.named:
; Reached once per drawn selection, before the list is drawn.
browser_selection_ready:
        bsr     browser_ui_draw
browser_idle:
        bsr     browser_ui_input
        cmpi.w  #1,d0
        beq     browser_control_back
        cmpi.w  #2,d0
        beq.s   browser_control_up
        cmpi.w  #3,d0
        beq.s   browser_control_down
        cmpi.w  #4,d0
        beq     browser_request_action
        cmpi.w  #6,d0
        beq.s   browser_control_changed
        cmpi.w  #8,d0
        beq     browser_files_delete
        cmpi.w  #9,d0
        beq     browser_files_recovery
        cmpi.w  #10,d0
        beq     browser_request_new
        bra.s   browser_idle
browser_control_up:
        tst.w   BROWSER_SELECTED
        beq.s   browser_idle
        subq.w  #1,BROWSER_SELECTED
        bra.s   browser_control_changed
browser_control_down:
        move.w  BROWSER_SELECTED,d0
        addq.w  #1,d0
        cmp.w   BROWSER_COUNT,d0
        bhs.s   browser_idle
        move.w  d0,BROWSER_SELECTED
browser_control_changed:
        clr.w   BROWSER_ACT
        clr.w   BROWSER_FILES_STATUS
        clr.w   BROWSER_VALIDATION
        clr.w   BROWSER_STATUS
        clr.w   BROWSER_CONTROLLER_STATUS
        clr.l   BROWSER_PENDING_ID
        clr.l   BROWSER_ERRORS
        bsr     browser_update_selection
        tst.w   d0
        beq     browser_control_redraw
browser_control_failed:
        move.w  d0,BROWSER_STATUS
        clr.w   BROWSER_COUNT
        clr.w   BROWSER_PAGE_COUNT
        clr.w   BROWSER_VALIDATION
        clr.w   BROWSER_CONTROLLER_STATUS
        clr.l   BROWSER_PENDING_ID
        bsr     browser_ui_error
browser_control_error_input:
        bsr     browser_ui_input
        cmpi.w  #1,d0
        beq.s   browser_control_back
        cmpi.w  #4,d0
        bne.s   browser_control_error_input
browser_control_retry:
        moveq   #10,d0
        tst.w   BROWSER_DATA_DRIVE
        bne.s   browser_control_failed
        clr.w   BROWSER_RESUMING
        clr.w   BROWSER_FILES_STATUS
        clr.l   STORAGE_CONTEXT+STORAGE_READ_CANCEL
        move.w  BROWSER_DATA_DRIVE,d1
        bsr     browser_select_drive
        bne.s   browser_control_failed
        lea     STORAGE_CONTEXT,a0
        bsr     storage_inspect_disk
        tst.w   d0
        bne.s   browser_control_failed
        move.w  #1,browser_ui_qualified
        bra     browser_control_inspect
browser_control_back:
        tst.w   BROWSER_FILES_VIEW
        bne     browser_files_normal
        clr.w   EDITOR_SESSION_BASE+REQ_ACTION
browser_finish:
        bsr     browser_ui_leave
        moveq   #0,d0
        movem.l (sp)+,d1-d7/a0-a6
        rts
browser_bad_entry:
        moveq   #STORAGE_READ_INVALID,d0
browser_qualification_failed:
        move.w  #REQ_ACTION_UNENTERED,EDITOR_SESSION_BASE+REQ_ACTION
        movem.l (sp)+,d1-d7/a0-a6
        rts

; Check for cancellation, then inspect the Custom directory and require its
; complete CFDI marker.
browser_qualify:
        bsr     browser_epoch
        bne.s   .return
        lea     STORAGE_CONTEXT,a0
        bsr     storage_inspect_disk
        tst.w   d0
        bne.s   .return
        cmpi.l  #1,STORAGE_CONTEXT+STORAGE_READ_READY
        beq.s   .return
        moveq   #STORAGE_READ_MEDIA,d0
.return:
        rts

; A returned service result is a numeric tag, never a module callback.
browser_resume:
        clr.w   BROWSER_RESUMING
        cmpi.l  #BROWSER_STATE_TAG,BROWSER_MAGIC
        bne     .fresh
        cmpi.w  #1,BROWSER_VERSION
        bne     .fresh
        move.w  EDITOR_SESSION_BASE+REQ_PURPOSE,d0
        cmp.w   BROWSER_PURPOSE,d0
        bne     .fresh
        cmpi.l  #STORAGE_MODULE_ID,EDITOR_SESSION_BASE+REQ_RESULT_ID
        beq.s   .storage
        cmpi.l  #BROWSER_CONTROLLER_ID,EDITOR_SESSION_BASE+REQ_RESULT_ID
        bne     .fresh
        cmpi.l  #BROWSER_CONTROLLER_ID,BROWSER_PENDING_ID
        bne     .fresh
        move.w  #1,BROWSER_RESUMING
        move.w  EDITOR_SESSION_BASE+REQ_LAST_RESULT,BROWSER_CONTROLLER_STATUS
        bra     .done
.storage:
        move.w  #1,BROWSER_RESUMING
        move.w  #BROWSER_VALID_FAILED,BROWSER_VALIDATION
        move.w  #STORAGE_READ_INVALID,BROWSER_STATUS
        cmpi.l  #STORAGE_MODULE_ID,BROWSER_PENDING_ID
        bne     .done
        move.w  EDITOR_SESSION_BASE+REQ_LAST_RESULT,d0
        bne.s   .failed
        move.w  STORAGE_STATUS,d0
        bne.s   .failed
        cmpi.l  #1,STORAGE_READY
        bne     .done
        cmpi.l  #CFMD_MAGIC,EDITOR_METADATA_BASE
        bne.s   .done
        lea     BROWSER_SELECTED_NAME,a0
        lea     EDITOR_METADATA_BASE+CFMD_MANIFEST_NAME,a1
        moveq   #3,d0
.name:
        cmpm.l  (a0)+,(a1)+
        bne.s   .done
        dbf     d0,.name
        move.l  STORAGE_ERRORS,BROWSER_ERRORS
        clr.w   BROWSER_STATUS
        ; Static checks never prove a phase winnable: without errors, REVIEW.
        move.w  #BROWSER_VALID_INVALID,BROWSER_VALIDATION
        tst.l   BROWSER_ERRORS
        bne.s   .done
        move.w  #BROWSER_VALID_REVIEW,BROWSER_VALIDATION
        bra.s   .done
.failed:
        move.w  d0,BROWSER_STATUS
        bra.s   .done
.fresh:
        lea     BROWSER_STATE,a0
        moveq   #31,d0
.clear:
        clr.l   (a0)+
        dbf     d0,.clear
        move.l  #BROWSER_STATE_TAG,BROWSER_MAGIC
        move.w  #1,BROWSER_VERSION
        move.w  EDITOR_SESSION_BASE+REQ_PURPOSE,BROWSER_PURPOSE
        move.w  EDITOR_SESSION_BASE+REQ_DRIVE,BROWSER_DATA_DRIVE
.done:
        clr.l   BROWSER_PENDING_ID
        clr.l   EDITOR_SESSION_BASE+REQ_RESULT_ID
        rts

; A fresh inspection qualifies the Custom directory again. Resumption requires
; the same CFDI identity and directory fingerprint before retaining validation status.
browser_inspect:
        tst.w   BROWSER_DATA_DRIVE
        bne     .invalid
        bsr     browser_epoch
        bne     .return
        tst.w   browser_ui_qualified
        bne.s   .inspected
.inspect:
        lea     STORAGE_CONTEXT,a0
        bsr     storage_inspect_disk
        tst.w   d0
        bne     .return
.inspected:
        clr.w   browser_ui_qualified
        cmpi.l  #1,STORAGE_CONTEXT+STORAGE_READ_READY
        bne     .invalid
        tst.w   BROWSER_RESUMING
        beq.s   .copy
        lea     BROWSER_DISK_ID,a0
        lea     STORAGE_CONTEXT+STORAGE_INSPECT_DISK_ID,a1
        moveq   #3,d0
.identity:
        cmpm.l  (a0)+,(a1)+
        bne     .media
        dbf     d0,.identity
        move.l  BROWSER_DIRECTORY_CRC,d0
        cmp.l   STORAGE_CONTEXT+STORAGE_INSPECT_DIRECTORY_CRC,d0
        bne     .media
.copy:
        lea     STORAGE_CONTEXT+STORAGE_INSPECT_DISK_ID,a0
        lea     BROWSER_DISK_ID,a1
        moveq   #11,d0
.identity_name:
        move.l  (a0)+,(a1)+
        dbf     d0,.identity_name
        move.l  STORAGE_CONTEXT+STORAGE_INSPECT_FREE_BYTES,BROWSER_FREE_BYTES
        move.w  STORAGE_CONTEXT+STORAGE_INSPECT_FREE_RECORDS,BROWSER_FREE_RECORDS
        move.w  STORAGE_CONTEXT+STORAGE_INSPECT_RECORDS,BROWSER_RECORDS
        move.l  STORAGE_CONTEXT+STORAGE_INSPECT_DIRECTORY_CRC,BROWSER_DIRECTORY_CRC
        clr.w   BROWSER_COUNT
        lea     EDITOR_DIRECTORY_BASE,a4
        lea     BROWSER_NAMES,a5
        move.w  BROWSER_RECORDS,d7
        subq.w  #1,d7
.record:
        movea.l a4,a0
        movea.l a5,a1
        bsr     bf_copy_name
        cmpi.l  #$2E636D69,8(a5)
        bne.s   .next
        tst.b   12(a5)
        bne.s   .next
        movea.l a5,a0
        bsr     read_valid_target
        tst.w   d0
        bne.s   .next
        lea     16(a5),a5
        addq.w  #1,BROWSER_COUNT
.next:
        lea     32(a4),a4
        dbf     d7,.record
        tst.w   BROWSER_RESUMING
        beq.s   .index
        ; An empty browser has no selected mission to locate after New/Cancel.
        ; Its CFDI identity and directory fingerprint were still checked above.
        tst.w   BROWSER_COUNT
        bne.s   .find_start
        tst.b   BROWSER_SELECTED_NAME
        beq.s   .index
.find_start:
        moveq   #0,d6
.find_selected:
        cmp.w   BROWSER_COUNT,d6
        bhs.s   .media
        move.w  d6,d0
        lsl.w   #4,d0
        lea     BROWSER_NAMES,a0
        adda.w  d0,a0
        lea     BROWSER_SELECTED_NAME,a1
        moveq   #3,d0
.compare_selected:
        cmpm.l  (a0)+,(a1)+
        bne.s   .next_selected
        dbf     d0,.compare_selected
        move.w  d6,BROWSER_SELECTED
        bra.s   .selected
.next_selected:
        addq.w  #1,d6
        bra.s   .find_selected
.index:
        clr.w   BROWSER_STATUS
        move.w  BROWSER_SELECTED,d0
        cmp.w   BROWSER_COUNT,d0
        blo.s   .selected
        ; Past the end after a deletion: select the new last entry.
        move.w  BROWSER_COUNT,d0
        subq.w  #1,d0
        bpl.s   .last_entry
        moveq   #0,d0
.last_entry:
        move.w  d0,BROWSER_SELECTED
.selected:
        bra     browser_epoch
.media:
        moveq   #STORAGE_READ_MEDIA,d0
        bra.s   .return
.invalid:
        moveq   #STORAGE_READ_INVALID,d0
.return:
        clr.w   browser_ui_qualified
        rts

browser_select_drive:
        moveq   #STORAGE_READ_INVALID,d0
        tst.w   d1
        bne.s   .return
        moveq   #0,d0
.return:
        tst.w   d0
        rts

; Only schema checking occurs here. Full payload validation is another module
; transaction and never follows an on-disk pointer or executable address.
browser_page:
        move.w  BROWSER_SELECTED,d0
        andi.w  #$FFFC,d0
        move.w  d0,BROWSER_TOP
        clr.w   BROWSER_PAGE_COUNT
        clr.w   BROWSER_DISPLAY_SAFE
        move.w  d0,BROWSER_SCAN_INDEX
        lea     BROWSER_ROWS,a0
        move.w  #BROWSER_PAGE_ROWS*BROWSER_ROW_BYTES/4-1,d0
browser_page_clear:
        clr.l   (a0)+
        dbf     d0,browser_page_clear
browser_page_row:
        move.w  BROWSER_SCAN_INDEX,d0
        cmp.w   BROWSER_COUNT,d0
        bhs     browser_page_done
        cmpi.w  #BROWSER_PAGE_ROWS,BROWSER_PAGE_COUNT
        bhs     browser_page_done
        tst.w   BROWSER_FILES_VIEW
        bne     browser_files_row
        bsr     browser_epoch
        bne     browser_page_return
        lea     STORAGE_CONTEXT,a1
        moveq   #18,d0
browser_page_request_clear:
        clr.l   (a1)+
        dbf     d0,browser_page_request_clear
        move.w  BROWSER_SCAN_INDEX,d0
        lsl.w   #4,d0
        lea     BROWSER_NAMES,a0
        adda.w  d0,a0
        lea     STORAGE_CONTEXT,a1
        moveq   #3,d0
browser_page_name:
        move.l  (a0)+,(a1)+
        dbf     d0,browser_page_name
        lea     BROWSER_DISK_ID,a0
        moveq   #3,d0
browser_page_id:
        move.l  (a0)+,(a1)+
        dbf     d0,browser_page_id
        move.l  #4096,STORAGE_CONTEXT+STORAGE_READ_CAPACITY
        lea     STORAGE_CONTEXT,a0
browser_before_read:
        bsr     storage_read_entry
        tst.w   d0
        beq.s   browser_page_parse
        cmpi.w  #4,d0
        beq     browser_page_return
        cmpi.w  #STORAGE_READ_CANCELLED,d0
        beq     browser_page_return
        cmpi.w  #STORAGE_READ_MEDIA,d0
        beq     browser_page_return
        bra.s   browser_page_damaged
browser_page_parse:
        lea     EDITOR_READBACK_BASE,a0
        move.l  STORAGE_CONTEXT+STORAGE_READ_RESULT_BYTES,d0
        lea     STORAGE_CONTEXT,a1
        moveq   #0,d1
        lea     EDITOR_SERIAL_WORK_BASE,a2
        lea     BROWSER_PARSER_WORK,a3
        bsr     cfmi_parse
        tst.w   d0
        bne.s   browser_page_damaged
        bsr     browser_row_pointer
        moveq   #0,d0
        move.b  EDITOR_SERIAL_WORK_BASE+CFMD_PHASE_COUNT,d0
        move.w  d0,BROWSER_ROW_PHASES(a4)
        lea     EDITOR_SERIAL_WORK_BASE+CFMD_TITLE,a0
        bsr     browser_text_length
        movea.l a4,a1
        move.w  #TITLE_HILL_WIDTH,d2
        bsr     browser_text_project
        tst.w   d0
        bne.s   browser_page_unsupported
        move.w  d1,BROWSER_ROW_WIDTH(a4)
        bra.s   browser_page_advance
browser_page_unsupported:
        move.w  #BROWSER_ROW_GLYPH,BROWSER_ROW_STATUS(a4)
        cmpi.w  #-3,d0
        bne.s   browser_page_advance
        move.w  #BROWSER_ROW_WIDE,BROWSER_ROW_STATUS(a4)
        bra.s   browser_page_advance
browser_page_damaged:
        bsr.s   browser_row_pointer
        move.w  #BROWSER_ROW_DAMAGED,BROWSER_ROW_STATUS(a4)
browser_page_advance:
        move.w  BROWSER_SELECTED,d0
        cmp.w   BROWSER_SCAN_INDEX,d0
        bne.s   browser_page_next
        tst.w   BROWSER_ROW_STATUS(a4)
        bne.s   browser_page_next
        move.w  #1,BROWSER_DISPLAY_SAFE
browser_page_next:
        addq.w  #1,BROWSER_SCAN_INDEX
        addq.w  #1,BROWSER_PAGE_COUNT
        bra     browser_page_row
browser_page_done:
        bra.s   browser_epoch
browser_page_return:
        rts

; The selected row's file name. It locates the selection again when a
; module returns, and ties a check to the mission it was made for.
browser_name_selected:
        move.w  BROWSER_SELECTED,d0
        lsl.w   #4,d0
        lea     BROWSER_NAMES,a0
        adda.w  d0,a0
        lea     BROWSER_SELECTED_NAME,a1
        moveq   #3,d0
.name:
        move.l  (a0)+,(a1)+
        dbf     d0,.name
        rts

browser_row_pointer:
        move.w  BROWSER_PAGE_COUNT,d0
        mulu.w  #BROWSER_ROW_BYTES,d0
        lea     BROWSER_ROWS,a4
        adda.w  d0,a4
        rts

; Moving the highlight within a loaded page only checks for cancellation. It
; does not reread four manifests, keeping normal selection responsive.
browser_update_selection:
        move.w  BROWSER_SELECTED,d0
        andi.w  #$FFFC,d0
        cmp.w   BROWSER_TOP,d0
        bne     browser_page
        bsr.s   browser_epoch
        bne.s   .return
        clr.w   BROWSER_DISPLAY_SAFE
        move.w  BROWSER_SELECTED,d0
        sub.w   BROWSER_TOP,d0
        mulu.w  #BROWSER_ROW_BYTES,d0
        lea     BROWSER_ROWS,a0
        adda.w  d0,a0
        tst.w   BROWSER_ROW_STATUS(a0)
        bne.s   .ok
        move.w  #1,BROWSER_DISPLAY_SAFE
.ok:
        moveq   #0,d0
.return:
        rts

browser_epoch:
        moveq   #STORAGE_READ_CANCELLED,d0
        tst.l   STORAGE_CONTEXT+STORAGE_READ_CANCEL
        bne.s   .done
        moveq   #4,d0
        moveq   #0,d0
.done:
        tst.w   d0
        rts

; This is a presentation gate, not the controller's final launch validation.
; The Custom directory is qualified again on the actual request path.
browser_can_play:
        moveq   #0,d0
        cmpi.w  #REQ_PURPOSE_PLAY,BROWSER_PURPOSE
        bne.s   .return
        tst.w   BROWSER_DISPLAY_SAFE
        beq.s   .return
        tst.l   BROWSER_ERRORS
        bne.s   .return
        cmpi.w  #BROWSER_VALID_REVIEW,BROWSER_VALIDATION
        beq.s   browser_can_selected
.return:
        tst.w   d0
        rts

; Drafts may be gameplay-invalid or have a title the browser cannot render.
; STG still has to provide a structurally valid, currently selected payload.
browser_can_open:
        moveq   #0,d0
        cmpi.w  #REQ_PURPOSE_EDITOR,BROWSER_PURPOSE
        bne.s   browser_can_selected_return
        cmpi.l  #1,STORAGE_READY
        bne.s   browser_can_selected_return
        tst.w   STORAGE_STATUS
        bne.s   browser_can_selected_return
        move.w  BROWSER_VALIDATION,d1
        subq.w  #BROWSER_VALID_INVALID,d1
        cmpi.w  #BROWSER_VALID_REVIEW-BROWSER_VALID_INVALID,d1
        bhi.s   browser_can_selected_return
browser_can_selected:
        tst.w   BROWSER_COUNT
        beq.s   browser_can_selected_return
        tst.w   BROWSER_STATUS
        bne.s   browser_can_selected_return
        tst.w   BROWSER_CONTROLLER_STATUS
        bne.s   browser_can_selected_return
        tst.l   BROWSER_PENDING_ID
        bne.s   browser_can_selected_return
        cmpi.l  #CFMD_MAGIC,EDITOR_METADATA_BASE
        bne.s   browser_can_selected_return
        lea     BROWSER_SELECTED_NAME,a0
        lea     EDITOR_METADATA_BASE+CFMD_MANIFEST_NAME,a1
        moveq   #3,d1
.name:
        cmpm.l  (a0)+,(a1)+
        bne.s   browser_can_selected_return
        dbf     d1,.name
        moveq   #1,d0
browser_can_selected_return:
        tst.w   d0
        rts

browser_can_action:
        cmpi.w  #REQ_PURPOSE_EDITOR,BROWSER_PURPOSE
        beq.s   browser_can_open
        bra     browser_can_play

; New takes no authored/session ownership and needs no valid mission row.
browser_can_new:
        tst.w   session_custom_mode
        bne.s   .no
        tst.w   SESSION_SNAPSHOT_VALID
        bne.s   .no
        tst.w   native_gameplay_active
        bne.s   .no
        tst.w   native_fifth_plane
        bne.s   .no
        move.w  sr,d0
        andi.w  #$0700,d0
        bne.s   .no
        cmpi.l  #BROWSER_STATE_TAG,BROWSER_MAGIC
        bne.s   .no
        cmpi.w  #1,BROWSER_VERSION
        bne.s   .no
        move.w  BROWSER_PURPOSE,d0
        cmp.w   EDITOR_SESSION_BASE+REQ_PURPOSE,d0
        bne.s   .no
        cmpi.w  #REQ_PURPOSE_EDITOR,d0
        beq.s   .yes
        cmpi.w  #REQ_PURPOSE_PLAY,d0
        bne.s   .no
.yes:
        moveq   #1,d0
        rts
.no:
        moveq   #0,d0
        rts

browser_request_action:
        tst.w   BROWSER_FILES_VIEW
        bne     browser_files_delete
        bsr.s   browser_can_action
        bne.s   .allowed
        ; Not checked yet: check, then go on. A checked mission that cannot
        ; be played or opened stays selected with the reason shown.
        tst.w   BROWSER_VALIDATION
        bne     browser_idle
        move.w  #1,BROWSER_ACT
        bra.s   browser_request_validation
.allowed:
        cmpi.w  #REQ_PURPOSE_EDITOR,BROWSER_PURPOSE
        bne.s   browser_request_play
        move.l  #$00020000,BROWSER_AUTHORING_OPERATION
        bra.s   browser_request_controller
browser_request_play:
        bsr     browser_can_play
        beq     browser_idle
        clr.l   BROWSER_AUTHORING_OPERATION
        bra.s   browser_request_controller
browser_request_new:
        cmpi.w  #REQ_PURPOSE_EDITOR,BROWSER_PURPOSE
        bne     browser_idle
        tst.w   BROWSER_FILES_VIEW
        bne     browser_idle
        tst.w   browser_ui_error_mode
        bne     browser_idle
        bsr     browser_can_new
        beq     browser_idle
        move.l  #$00010000,BROWSER_AUTHORING_OPERATION
browser_request_controller:
        bsr     browser_epoch
        bne     browser_control_failed
        move.l  #BROWSER_CONTROLLER_ID,BROWSER_PENDING_ID
        clr.w   EDITOR_SESSION_BASE+REQ_LAST_RESULT
        clr.l   EDITOR_SESSION_BASE+REQ_RESULT_ID
        lea     browser_controller_request(pc),a0
        bra     browser_dispatch_request

browser_request_validation:
        tst.w   BROWSER_COUNT
        beq     browser_check_refused
        move.w  BROWSER_SELECTED,d0
        sub.w   BROWSER_TOP,d0
        mulu.w  #BROWSER_ROW_BYTES,d0
        lea     BROWSER_ROWS,a0
        adda.w  d0,a0
        cmpi.w  #BROWSER_ROW_DAMAGED,BROWSER_ROW_STATUS(a0)
        beq     browser_check_refused
        bsr     browser_epoch
        bne     browser_control_failed
        move.w  BROWSER_SELECTED,d0
        lsl.w   #4,d0
        lea     BROWSER_NAMES,a0
        adda.w  d0,a0
        lea     BROWSER_SELECTED_NAME,a1
        lea     STORAGE_CONTEXT,a2
        moveq   #3,d0
.name:
        move.l  (a0)+,d1
        move.l  d1,(a1)+
        move.l  d1,(a2)+
        dbf     d0,.name
        lea     BROWSER_DISK_ID,a0
        moveq   #3,d0
.id:
        move.l  (a0)+,(a2)+
        dbf     d0,.id
        clr.l   STORAGE_READY
        clr.w   STORAGE_SELECTED
        move.w  #STORAGE_CMD_VALIDATE,STORAGE_COMMAND
        move.w  #BROWSER_VALID_PENDING,BROWSER_VALIDATION
        move.l  #STORAGE_MODULE_ID,BROWSER_PENDING_ID
        clr.w   BROWSER_STATUS
        clr.w   BROWSER_CONTROLLER_STATUS
        clr.w   EDITOR_SESSION_BASE+REQ_LAST_RESULT
        clr.l   EDITOR_SESSION_BASE+REQ_RESULT_ID
        lea     browser_storage_request(pc),a0
        bra.s   browser_dispatch_request
browser_check_refused:
        clr.w   BROWSER_ACT
        bra     browser_idle
browser_dispatch_request:
        lea     EDITOR_SESSION_BASE+REQ_NAME,a1
        moveq   #5,d0
.module:
        move.l  (a0)+,(a1)+
        dbf     d0,.module
        move.w  #REQ_ACTION_DISPATCH,EDITOR_SESSION_BASE+REQ_ACTION
        bra     browser_finish

DIALOG_LIST_CLICKS equ 1
        include "ui.s"
        include "text.s"
        include "../controller/text.s"
        include "../storage/read.s"
        include "../storage/manifest.s"
        include "files.s"
        include "glue.s"
        include "delete.s"
        include "files_ui.s"
        include "../dialog/dialog.s"
        even
browser_storage_request:
        dc.b "cf_storage.mod",0,0
        dc.l STORAGE_MODULE_ID,EDITOR_SERIALIZER_BYTES
browser_controller_request:
        dc.b "controller.mod",0,0
        dc.l BROWSER_CONTROLLER_ID,EDITOR_SERIALIZER_BYTES
browser_end:
        printv browser_end-browser_start
        ifgt browser_end-browser_start-EDITOR_SERIALIZER_BYTES
        fail "Browser module exceeds 16 KiB"
        endif
