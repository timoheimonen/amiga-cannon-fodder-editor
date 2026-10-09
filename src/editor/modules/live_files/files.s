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
        include "save.i"
        include "authoring.i"
        include "private.i"
        include "browser.i"
        include "browser_delete.i"
        include "../editor/state.i"
        include "ui.i"
        include "dialog.i"
LIVE_FILES_PAGE equ AUR_PAGE_FILES
AUR_VALIDATE_ONLY equ 1
LF_MODE equ EDITOR_UI_BASE
LF_STATUS equ EDITOR_UI_BASE+2
; The manifest name of the mission selected in Open, until it is found.
LF_START equ EDITOR_UI_BASE+4
LF_TITLE equ EDITOR_UI_BASE+32
LF_TEXT equ EDITOR_UI_BASE+96

        section .text,code
        xdef live_files_start,files_entry,files_refresh,files_ready,files_confirm
        xdef files_before_commit,files_after_commit,files_finish,files_return
; Fixed load-base anchor: X+PCREL(pc) reads the absolute address X
; PC-relatively from module code.
module_pc_base:
PCREL   equ module_pc_base-EDITOR_MODULE_BASE
live_files_start:
        dc.l MODULE_MAGIC
        dc.w MODULE_ABI,MODULE_HEADER_BYTES
        dc.l FILES_MODULE_ID,EDITOR_MODULE_BASE
        dc.l live_files_end-live_files_start,files_entry-live_files_start,0,0
files_entry:
        movem.l d1-d7/a0-a6,-(sp)
        move.w #REQ_ACTION_UNENTERED,EDITOR_SESSION_BASE+REQ_ACTION
        cmpi.w #MODULE_ABI,d0
        bne files_bad
        cmpa.l #EDITOR_SESSION_BASE,a0
        bne files_bad
        bsr live_files_owner
        bne files_return
        cmpi.w #FILES_REQUEST_TAG,SAVE_CONTEXT
        bne files_bad
        move.w SAVE_CONTEXT+2,d6
        tst.w d6
        bne files_bad
        lea BROWSER_STATE,a0
        moveq #31,d0
.clear:
        clr.l (a0)+
        dbf d0,.clear
        move.l #BROWSER_STATE_TAG,BROWSER_MAGIC
        move.l #$00010001,BROWSER_VERSION
        move.w d6,BROWSER_DATA_DRIVE
        clr.w LF_STATUS
        lea SAVE_CONTEXT+4,a0
        lea LF_START,a1
        moveq #3,d0
.start:
        move.l (a0)+,(a1)+
        dbf d0,.start
files_refresh:
        clr.w BROWSER_COUNT
        lea BROWSER_DISK_ID,a0
        moveq #11,d0
.clear_identity:
        clr.l (a0)+
        dbf d0,.clear_identity
        moveq #10,d0
        tst.w BROWSER_DATA_DRIVE
        bne files_error
        clr.l STORAGE_CONTEXT+STORAGE_READ_CANCEL
        lea STORAGE_CONTEXT,a0
        bsr storage_inspect_disk
        bne files_error
        lea STORAGE_CONTEXT+STORAGE_INSPECT_DISK_ID,a0
        lea BROWSER_DISK_ID,a1
        moveq #11,d0
.identity:
        move.l (a0)+,(a1)+
        dbf d0,.identity
        lea BDQ_CONTEXT,a0
        moveq #31,d0
.request_clear:
        clr.l (a0)+
        dbf d0,.request_clear
        move.l #BDQ_MAGIC,BDQ_CONTEXT
        move.l #$00010080,BDQ_CONTEXT+4
        move.w BROWSER_FILES_VIEW,d0
        addq.w #1,d0
        move.w d0,BDQ_CONTEXT+BDQ_OPERATION
        move.w BROWSER_DATA_DRIVE,BDQ_CONTEXT+BDQ_DRIVE
        lea BROWSER_DISK_ID,a0
        lea BDQ_CONTEXT+BDQ_DISK_ID,a1
        moveq #3,d0
.id:
        move.l (a0)+,(a1)+
        dbf d0,.id
        move.l STORAGE_CONTEXT+STORAGE_INSPECT_DIRECTORY_CRC,(a1)
        clr.w bdq_open_tag
        clr.w bdq_identity_valid
        lea BDQ_CONTEXT,a0
        bsr browser_delete_open
        bne files_error
        bsr browser_files_classify
        bne files_close_error
        bsr files_indices
        bsr files_start
files_select:
        clr.w LF_MODE
        tst.w BROWSER_COUNT
        beq.s files_ready
        move.w BROWSER_SELECTED,d0
        add.w d0,d0
        lea BF_VIEW_INDICES,a0
        move.w 0(a0,d0.w),d0
        bsr bf_record
        lea BF_NAME,a1
        bsr bf_copy_name
        bsr browser_files_title
        bne files_close_error
files_ready:
        bsr edtr_modal
        tst.w d0
        bmi files_close_error
        beq.s files_back
        cmpi.w #5,d0
        bhs files_close_error
        cmpi.w #4,d0
        beq.s files_recover
        cmpi.w #1,d0
        beq.s files_delete
        subq.w #2,d0
        add.w d0,d0
        subq.w #1,d0
        add.w BROWSER_SELECTED,d0
        cmp.w BROWSER_COUNT,d0
        bhs.s files_ready
        move.w d0,BROWSER_SELECTED
        bra.s files_select
files_recover:
        tst.w BDQ_CONTEXT+BDQ_RECOVERY_COUNT
        beq.s files_ready
        move.w #1,BROWSER_FILES_VIEW
        clr.w BROWSER_SELECTED
        moveq #0,d0
        bsr browser_delete_close
        bra files_refresh
files_back:
        moveq #0,d0
        bsr browser_delete_close
        tst.w BROWSER_FILES_VIEW
        beq files_finish
        clr.w BROWSER_FILES_VIEW
        clr.w BROWSER_SELECTED
        bra files_refresh
files_delete:
        tst.w BROWSER_COUNT
        beq files_ready
        bsr browser_files_select
        bne.s files_close_error
        bsr browser_files_title
        bne.s files_close_error
        move.w #1,LF_MODE
files_confirm:
        bsr edtr_modal
        cmpi.w #1,d0
        bne.s files_decline
        bsr browser_delete_check
        bne.s files_close_error
        move.w #1,BDQ_CONTEXT+BDQ_CONFIRMED
        lea BDQ_CONTEXT,a0
files_before_commit:
        bsr browser_delete_commit
files_after_commit:
        bra.s files_error
files_decline:
        tst.w d0
        bne.s files_close_error
        moveq #0,d0
        bsr browser_delete_close
        bra files_refresh
files_close_error:
        cmpi.w #5,d0
        bne.s .close
        move.w LF_STATUS,d0
.close:
        bsr browser_delete_close
files_error:
        move.w d0,LF_STATUS
        move.w #2,LF_MODE
        bsr edtr_modal
        tst.w d0
        bmi.s files_finish
        bne files_refresh
        moveq #0,d0
files_finish:
        ; Every guard is closed before publishing a typed entered result.
        tst.w BDQ_CONTEXT+BDQ_INSTALLED
        bne.s files_blocked
        move.w d0,EDITOR_SESSION_BASE+REQ_LAST_RESULT
        move.l #FILES_MODULE_ID,EDITOR_SESSION_BASE+REQ_RESULT_ID
        lea files_editor_request(pc),a0
        lea EDITOR_SESSION_BASE+REQ_NAME,a1
        moveq #5,d1
.copy:
        move.l (a0)+,(a1)+
        dbf d1,.copy
        move.w #REQ_ACTION_DISPATCH,EDITOR_SESSION_BASE+REQ_ACTION
        moveq #0,d0
files_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
files_bad:
        moveq #EDTR_STATE_ERROR,d0
        bra.s files_return
files_blocked:
        jsr wait_frame
        bra.s files_blocked
files_editor_request:
        dc.b "cf_editor.mod",0,0,0
        dc.l EDTR_MODULE_ID,EDITOR_SERIALIZER_BYTES

; Catalog indices reference the immutable directory, never a discarded buffer.
; The first list selects the mission that was selected in Open.
files_start:
        tst.b LF_START
        beq.s .out
        tst.w BROWSER_FILES_VIEW
        bne.s .out
        moveq #0,d7
.view:
        cmp.w BROWSER_COUNT,d7
        bhs.s .done
        move.w d7,d0
        add.w d0,d0
        lea BF_VIEW_INDICES,a0
        move.w 0(a0,d0.w),d0
        bsr bf_record
        lea LF_START,a1
        bsr bf_name_equal
        beq.s .found
        addq.w #1,d7
        bra.s .view
.found:
        move.w d7,BROWSER_SELECTED
.done:
        clr.b LF_START
.out:
        rts

files_indices:
        clr.w BROWSER_COUNT
        moveq #0,d6
.record:
        move.w d6,d0
        bsr bf_record
        tst.w BROWSER_FILES_VIEW
        bne.s .recovery
        cmpi.b #BF_DAMAGED,5(a2)
        blo.s .next
        bra.s .add
.recovery:
        move.w d6,d0
        lea BF_RECOVERY,a1
        bsr bf_test_bit
        beq.s .next
        movea.l a0,a4
        moveq #0,d7
.previous:
        cmp.w BROWSER_COUNT,d7
        bhs.s .add
        move.w d7,d0
        add.w d0,d0
        lea BF_VIEW_INDICES,a0
        move.w 0(a0,d0.w),d0
        bsr bf_record
        movea.l a4,a1
        bsr bf_prefix_equal
        beq.s .next
        addq.w #1,d7
        bra.s .previous
.add:
        move.w BROWSER_COUNT,d0
        add.w d0,d0
        lea BF_VIEW_INDICES,a0
        move.w d6,0(a0,d0.w)
        addq.w #1,BROWSER_COUNT
.next:
        addq.w #1,d6
        cmp.w BF_RECORD_COUNT,d6
        blo.s .record
        move.w BROWSER_SELECTED,d0
        cmp.w BROWSER_COUNT,d0
        blo.s .return
        ; Past the end after a deletion: select the new last entry.
        move.w BROWSER_COUNT,d0
        subq.w #1,d0
        bpl.s .last_entry
        moveq #0,d0
.last_entry:
        move.w d0,BROWSER_SELECTED
.return:
        rts

        include "ui.s"
        include "dialog.s"
        include "../dialog/dialog.s"
        include "../controller/text.s"
        include "core.s"
