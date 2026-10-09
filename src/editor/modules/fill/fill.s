; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; FILL overlay: cancellable discovery, bounded undo and atomic commit.
        include "layout.i"
        include "module.i"
        include "session.i"
        include "fodders.i"
        include "metadata.i"
        include "payload.i"
        include "storage_read.i"
        include "storage.i"
        include "browser.i"
        include "save.i"
        include "authoring.i"
        include "../editor/state.i"
        include "ui.i"
        include "dialog.i"
FILL_MASK       equ EDITOR_SERIAL_WORK_BASE
FILL_RESULT     equ EDITOR_SERIAL_WORK_BASE+938
FILL_CANCEL     equ EDITOR_SERIAL_WORK_BASE+954
FILL_OP         equ EDITOR_SERIAL_WORK_BASE+956
FILL_WIDTH      equ EDITOR_SERIAL_WORK_BASE+960
FILL_HEIGHT     equ EDITOR_SERIAL_WORK_BASE+962
FILL_CELLS      equ EDITOR_SERIAL_WORK_BASE+964
FILL_TARGET     equ EDITOR_SERIAL_WORK_BASE+966
FILL_COUNT      equ EDITOR_SERIAL_WORK_BASE+968
FILL_PHASE      equ EDITOR_SERIAL_WORK_BASE+970
FILL_TILE       equ EDITOR_SERIAL_WORK_BASE+972
FILL_SEED       equ EDITOR_SERIAL_WORK_BASE+974
FILL_READY      equ EDITOR_SERIAL_WORK_BASE+976
FILL_WORK_END   equ EDITOR_SERIAL_WORK_BASE+978
FILL_QUEUE      equ EDITOR_READBACK_BASE
FILL_QUEUE_END  equ FILL_QUEUE+15000

PAYLOAD_STRUCTURAL_ONLY equ 1
        section .text,code
        xdef fill_start,fill_entry,fill_end,fill_owner,fill_epoch,fill_poll
        xdef fill_before_discovery,fill_before_modal,fill_after_modal
        xdef fill_before_second_discovery,fill_before_commit,fill_commit_loop
        xdef fill_after_commit,fill_finish,fill_publish,fill_commit_blocked
        xdef fill_verify_queue,fill_discover,fill_context,fill_editor_request
; Fixed load-base anchor: X+PCREL(pc) reads the absolute address X
; PC-relatively from module code.
module_pc_base:
PCREL   equ module_pc_base-EDITOR_MODULE_BASE
fill_start:
        dc.l MODULE_MAGIC
        dc.w MODULE_ABI,MODULE_HEADER_BYTES
        dc.l FILL_MODULE_ID,EDITOR_MODULE_BASE
        dc.l fill_end-fill_start,fill_entry-fill_start,0,0

fill_entry:
        movem.l d1-d7/a0-a6,-(sp)
        move.w #REQ_ACTION_UNENTERED,EDITOR_SESSION_BASE+REQ_ACTION
        cmpi.w #MODULE_ABI,d0
        bne fill_bad_entry
        cmpa.l #EDITOR_SESSION_BASE,a0
        bne fill_bad_entry
        bsr fill_owner
        bne fill_return
        clr.l STORAGE_CONTEXT+STORAGE_READ_CANCEL
        bsr fill_epoch
        bne fill_return
        lea STORAGE_CONTEXT,a0
        bsr storage_inspect_disk
        tst.w d0
        bne fill_return
        bsr fill_epoch
        bne fill_return
        bsr fill_owner
        bne fill_return
        ; Reader scratch is now dead. Never run payload/reader code after
        ; this initialization: authored CRCs are stale and scratch may alias.
        lea FILL_CANCEL,a0
        moveq #(FILL_WORK_END-FILL_CANCEL)/2-1,d0
.clear:
        clr.w (a0)+
        dbra d0,.clear
        move.w map_file_buffer+84,FILL_WIDTH
        move.w map_file_buffer+86,FILL_HEIGHT
        move.w FILL_WIDTH,d0
        mulu FILL_HEIGHT,d0
        move.w d0,FILL_CELLS
        move.w AUR_BASE+AUR_TILE,FILL_TILE
        move.w AUR_BASE+AUR_PAGE_CANDIDATE,d0
        move.w d0,FILL_SEED
        add.w d0,d0
        lea editor_map_grid,a0
        move.w 0(a0,d0.w),d0
        andi.w #$1FF,d0
        move.w d0,FILL_TARGET
        moveq #0,d0
        move.b AUR_BASE+AUR_SELECTED,d0
        move.w d0,FILL_PHASE
        bsr fill_context
        bsr tu_validate
        bne fill_precommit_error
        bsr fill_poll
        bne fill_cancelled
        move.w FILL_TILE,d0
        cmp.w FILL_TARGET,d0
        beq fill_no_change
fill_before_discovery:
        bsr fill_discover
        bsr fill_check_discovery
        bne fill_discovery_failed
        cmpi.w #256,FILL_COUNT
        bls.s fill_prepare_commit
        ; No queue/mask authority survives the modal's READBACK backup.
        clr.w FILL_READY
        clr.w edtr_view_live
fill_before_modal:
        moveq #EDTR_DIALOG_LARGE,d0
        moveq #0,d1
        bsr edtr_modal
fill_after_modal:
        ; The modal is fully restored on every non-refusal return.
        clr.w edtr_view_live
        tst.w d0
        bmi fill_precommit_error
        beq fill_cancelled
        bsr fill_poll
        bne fill_cancelled
        bsr fill_owner
        bne fill_precommit_error
fill_before_second_discovery:
        bsr fill_discover
        bsr fill_check_discovery
        bne.s fill_discovery_failed
fill_prepare_commit:
        bsr fill_owner
        bne.s fill_precommit_error
        bsr fill_context
        bsr tu_validate
        bne.s fill_precommit_error
        bsr fill_poll
        bne.s fill_cancelled
        cmpi.w #1,FILL_READY
        bne.s fill_precommit_error
        ; No I/O, UI, cancellation, callbacks or expected refusal from here.
        ; Closed log, unique queue and exclusive immutable MAP establish every
        ; unchanged helper precondition before the first authored write.
fill_before_commit:
        bsr tu_begin
        bne fill_commit_blocked
        cmpi.w #256,FILL_COUNT
        bls.s .queue
        bsr tu_confirm_large
        bne fill_commit_blocked
.queue:
        lea FILL_QUEUE,a4
        move.w FILL_COUNT,d5
        subq.w #1,d5
fill_commit_loop:
        move.w (a4)+,d1
        move.w d1,d2
        add.w d2,d2
        move.w 0(a0,d2.w),d2
        andi.w #$FE00,d2
        or.w FILL_TILE,d2
        bsr tu_change
        cmpi.w #1,d0
        bne fill_commit_blocked
        dbra d5,fill_commit_loop
        bsr tu_end
        bne fill_commit_blocked
        bsr aur_mark_edited
fill_after_commit:
        moveq #1,d7
        bra.s fill_finish
fill_discovery_failed:
        cmpi.w #14,d0
        beq.s fill_cancelled
fill_precommit_error:
        moveq #EDTR_VISUAL_ERROR,d7
        bra.s fill_finish
fill_cancelled:
        moveq #14,d7
        bra.s fill_finish
fill_no_change:
        moveq #0,d7
fill_finish:
        clr.w FILL_READY
        ; Native pointer update may clobber D7. Drain after commitment without
        ; reinterpreting late input as a pre-commit Cancel or rollback.
        move.l d7,-(sp)
.release:
        clr.w native_last_key
        clr.w native_left_pressed
        clr.w native_right_pressed
        jsr wait_frame
        jsr editor_pointer_update
        tst.w native_left_down
        bne.s .release
        tst.w native_right_down
        bne.s .release
        clr.w native_last_key
        move.l (sp)+,d7
        bsr.s fill_owner
        bne.s fill_commit_blocked
        tst.l FILL_OP
        bne.s fill_commit_blocked
fill_publish:
        move.w d7,EDITOR_SESSION_BASE+REQ_LAST_RESULT
        lea fill_editor_request(pc),a0
        lea EDITOR_SESSION_BASE+REQ_NAME,a1
        moveq #5,d1
.request:
        move.l (a0)+,(a1)+
        dbra d1,.request
        move.w #REQ_ACTION_DISPATCH,EDITOR_SESSION_BASE+REQ_ACTION
        move.l #FILL_MODULE_ID,EDITOR_SESSION_BASE+REQ_RESULT_ID
        move.l d7,d0
fill_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
fill_bad_entry:
        moveq #EDTR_STATE_ERROR,d0
        bra.s fill_return

; Unreachable under the validated exclusive commit contract. Never label a
; partial authored operation as Cancel/error with unchanged-draft semantics.
fill_commit_blocked:
        jsr wait_frame
        bra.s fill_commit_blocked

fill_owner:
        bsr aur_validate
        bne.s .return
        moveq #AUR_ERROR_REQUEST,d0
        btst #3,AUR_BASE+AUR_FLAGS+1
        beq.s .return
        cmpi.w #AUR_PAGE_FILL,AUR_BASE+AUR_PAGE_KIND
        bne.s .return
        tst.w AUR_BASE+AUR_TRANSPORT_STATUS
        bne.s .return
        tst.l EDITOR_SESSION_BASE+REQ_RESULT_ID
        bne.s .return
        tst.w EDITOR_SESSION_BASE+REQ_LAST_RESULT
        bne.s .return
        moveq #0,d0
.return:
        tst.w d0
        rts

fill_epoch:
        moveq #STORAGE_READ_CANCELLED,d0
        tst.l STORAGE_CONTEXT+STORAGE_READ_CANCEL
        bne.s .return
        moveq #4,d0
        moveq #0,d0
.return:
        tst.w d0
        rts

; Reestablish the discovery helper's A6/A5 poll ABI explicitly, preserving the
; caller's registers. Capture a translated Escape edge before modal clears.
fill_poll:
        movem.l a5-a6,-(sp)
        lea FILL_CANCEL,a6
        lea native_raw_key+1,a5
        tst.w (a6)
        bne.s .poll
        cmpi.w #$C5,native_last_key
        bne.s .poll
        move.w #1,(a6)
.poll:
        bsr fc_poll
        movem.l (sp)+,a5-a6
        rts

fill_context:
        lea editor_map_grid,a0
        lea EDITOR_UNDO_BASE,a1
        lea AUR_BASE+AUR_UNDO_NEXT,a2
        lea FILL_OP,a3
        moveq #0,d7
        move.w FILL_CELLS,d7
        rts

fill_discover:
        clr.w FILL_READY
        lea editor_map_grid,a0
        lea FILL_QUEUE,a1
        lea FILL_MASK,a2
        lea FILL_RESULT,a3
        lea FILL_CANCEL,a4
        lea native_raw_key+1,a5
        move.w FILL_WIDTH,d1
        move.w FILL_HEIGHT,d2
        move.w FILL_SEED,d3
        moveq #0,d7
        move.w FILL_CELLS,d7
        bra fc_discover

fill_check_discovery:
        tst.w d0
        bne.s .return
        bra.s fill_verify_queue
.return:
        rts

; Consume the completed discovery, then reuse its visited mask to prove each
; queue entry unique, in range and still equal to the original low9 target.
; Only trusted scratch changes; cancellation leaves READY0 on every path.
fill_verify_queue:
        moveq #EDTR_VISUAL_ERROR,d0
        lea FILL_WIDTH,a0
        lea FILL_RESULT,a1
        moveq #3,d1
.geometry:
        cmpm.w (a0)+,(a1)+
        bne .return
        dbra d1,.geometry
        move.w FILL_RESULT+8,d4
        beq .return
        cmp.w FILL_CELLS,d4
        bhi .return
        cmp.w FILL_RESULT+10,d4
        bne .return
        tst.l FILL_RESULT+12
        bne .return
        tst.w FILL_COUNT
        beq.s .first
        cmp.w FILL_COUNT,d4
        bne .return
.first:
        move.w map_file_buffer+84,d1
        cmp.w FILL_WIDTH,d1
        bne .return
        move.w map_file_buffer+86,d1
        cmp.w FILL_HEIGHT,d1
        bne .return
        moveq #0,d1
        move.b AUR_BASE+AUR_SELECTED,d1
        cmp.w FILL_PHASE,d1
        bne .return
        move.w AUR_BASE+AUR_TILE,d1
        cmp.w FILL_TILE,d1
        bne.s .return
        move.w AUR_BASE+AUR_PAGE_CANDIDATE,d1
        cmp.w FILL_SEED,d1
        bne.s .return
        lea FILL_MASK,a2
        move.w #938/2-1,d1
.clear:
        clr.w (a2)+
        dbra d1,.clear
        lea FILL_MASK,a2
        lea FILL_QUEUE,a1
        lea editor_map_grid,a0
        move.w d4,d5
        subq.w #1,d5
.cell:
        bsr fill_poll
        bne.s .cancel
        moveq #EDTR_VISUAL_ERROR,d0
        move.w (a1)+,d1
        cmp.w FILL_CELLS,d1
        bhs.s .return
        move.w d1,d2
        lsr.w #3,d2
        bset d1,0(a2,d2.w)
        bne.s .return
        add.w d1,d1
        move.w 0(a0,d1.w),d2
        andi.w #$1FF,d2
        cmp.w FILL_TARGET,d2
        bne.s .return
        dbra d5,.cell
        move.w d4,FILL_COUNT
        move.w #1,FILL_READY
        moveq #0,d0
        bra.s .return
.cancel:
        moveq #14,d0
.return:
        tst.w d0
        rts

; Same page-bound predicate as the EDTR receiver. Full AUR metadata
; validation also enforces nonzero geometry and the7500-cell product bound.
        include "../editor/page_bounds.s"

fill_editor_request:
        dc.b "cf_editor.mod",0,0,0
        dc.l EDTR_MODULE_ID,EDITOR_SERIALIZER_BYTES

        include "discover.s"
        include "../editor/undo.s"
        include "modal.s"
        include "../dialog/dialog.s"
        include "../dialog/standard.s"
        include "../editor/aur.s"
        include "../editor/tested.s"
        include "../controller/text.s"
        include "../storage/read.s"
        include "../storage/payload.s"
fill_end:
        ifgt fill_end-fill_start-EDITOR_SERIALIZER_BYTES
        fail "FILL exceeds installable16KiB cap"
        endif
        ifgt FILL_WORK_END-EDITOR_SERIAL_WORK_BASE-EDITOR_SERIAL_WORK_BYTES
        fail "FILL work exceeds existing scratch"
        endif
        ifgt FILL_QUEUE_END-EDITOR_READBACK_BASE-EDITOR_READBACK_BYTES
        fail "FILL queue exceeds existing readback"
        endif
