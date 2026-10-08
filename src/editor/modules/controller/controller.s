; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        include "layout.i"
        include "module.i"
        include "session.i"
        include "fodders.i"
        include "metadata.i"
        include "storage_read.i"
        include "storage.i"
        include "browser.i"
        include "controller.i"
        include "save.i"
        include "authoring.i"
        include "ui.i"
        include "dialog.i"
CONTROLLER_STATE_ERROR equ -20
CONTROLLER_RECORD_ERROR equ -21
CONTROLLER_PAYLOAD_ERROR equ -22
CONTROLLER_TITLE_ERROR equ -23
CONTROLLER_TITLE equ EDITOR_METADATA_BASE+CFMD_RECORD_BYTES
CONTROLLER_PHASE_TITLE equ CONTROLLER_TITLE+64

        section .text,code
        xdef controller_start,controller_entry,controller_end
        xdef controller_before_begin,controller_before_publish
        xdef controller_before_storage,controller_storage_reply
        xdef controller_transaction_publish,controller_result
; Fixed load-base anchor: X+PCREL(pc) reads the absolute address X
; PC-relatively from module code.
module_pc_base:
PCREL   equ module_pc_base-EDITOR_MODULE_BASE
controller_start:
        dc.l MODULE_MAGIC
        dc.w MODULE_ABI,MODULE_HEADER_BYTES
        dc.l CONTROLLER_MODULE_ID,EDITOR_MODULE_BASE
        dc.l controller_end-controller_start
        dc.l controller_entry-controller_start
        dc.l 0,0

; ABI 2, normal-stack entry. No native asset loading or nonlocal transfer.
; Qualify the Custom directory before reading session state. The resident
; dispatcher holds the game's drive selection while this overlay runs and
; restores it after this overlay returns.
controller_entry:
        movem.l d1-d7/a0-a6,-(sp)
        cmpi.w  #MODULE_ABI,d0
        bne.s   controller_bad_entry
        cmpa.l  #EDITOR_SESSION_BASE,a0
        bne.s   controller_bad_entry
        bra.s   controller_abi_checked
controller_bad_entry:
        moveq   #CONTROLLER_STATE_ERROR,d0
        movem.l (sp)+,d1-d7/a0-a6
        tst.w   d0
        rts
controller_abi_checked:
        clr.w   EDITOR_SESSION_BASE+REQ_ACTION
        moveq   #0,d7
        cmpi.w #REQ_PURPOSE_TEST,EDITOR_SESSION_BASE+REQ_PURPOSE
        beq controller_test_dispatch
        bsr     controller_epoch
        bne     controller_finish
        lea     STORAGE_CONTEXT,a0
        bsr     storage_inspect_disk
        tst.w   d0
        bne     controller_finish
        moveq   #CONTROLLER_STATE_ERROR,d0
        tst.w   native_gameplay_active
        bne     controller_finish
        cmpi.w  #REQ_PURPOSE_EDITOR,EDITOR_SESSION_BASE+REQ_PURPOSE
        beq     controller_authoring
        tst.w   session_custom_mode
        beq.s   controller_selection
        cmpi.w  #1,session_custom_mode
        bne     controller_finish
        cmpi.w  #SESSION_SNAPSHOT_TAG,SESSION_SNAPSHOT_VALID
        bne     controller_finish
        cmpi.w  #SESSION_EVENT_OUTCOME,session_event
        beq     controller_outcome
        cmpi.w  #SESSION_EVENT_HILL,session_event
        bne     controller_finish
        cmpi.l  #SESSION_CHECKPOINT_TAG,SESSION_CHECKPOINT_VALID
        bne     controller_finish
controller_selection:
        bsr     controller_check_record
        bne     controller_finish
        bsr.s   controller_check_disk
        bne     controller_finish
        bsr     controller_check_payload
        bne     controller_finish
        bsr     controller_project_titles
        bne     controller_finish
        tst.w   session_custom_mode
        bne.s   controller_continue
        bsr     checkpoint_initial_preflight
        bne     controller_finish
controller_before_begin:
        bsr     controller_epoch
        bne     controller_finish
        bsr     session_begin_custom
        bne     controller_finish
        moveq   #1,d7
        bsr     checkpoint_capture
        bne     controller_finish
        bsr     controller_transaction_init
        bra.s   controller_before_publish
controller_continue:
        bsr     checkpoint_preflight
        bne     controller_finish
controller_before_publish:
        move.w  sr,-(sp)
        ori.w   #$0700,sr
        bsr     controller_epoch
        bne.s   .unmask
        move.w  #REQ_ACTION_PREPARE,EDITOR_SESSION_BASE+REQ_ACTION
.unmask:
        move.w  (sp)+,sr
        tst.w   d0
        bne     controller_finish
        moveq   #0,d7
        bra     controller_finish

; Qualify the Custom directory and require its pinned CFDI identity.
controller_check_disk:
        moveq #STORAGE_READ_INVALID,d0
        tst.w BROWSER_DATA_DRIVE
        bne.s .return
        lea STORAGE_CONTEXT,a0
        bsr storage_inspect_disk
        bne.s .return
.identity:
        lea     STORAGE_CONTEXT+STORAGE_INSPECT_DISK_ID,a0
        lea     BROWSER_DISK_ID,a1
        moveq   #3,d1
        moveq   #STORAGE_READ_MEDIA,d0
.compare:
        cmpm.l  (a0)+,(a1)+
        bne.s   .return
        dbra    d1,.compare
        move.l  STORAGE_CONTEXT+STORAGE_INSPECT_DIRECTORY_CRC,d1
        cmp.l   BROWSER_DIRECTORY_CRC,d1
        bne.s   .return
        moveq   #0,d0
.return:
        tst.w   d0
        rts

controller_outcome:
        cmpi.l  #CONTROLLER_TRANSACTION_TAG,CONTROLLER_TRANSACTION
        bne     controller_transaction_bad
        cmpi.l  #SESSION_CHECKPOINT_TAG,SESSION_CHECKPOINT_VALID
        bne     controller_transaction_bad
        bsr     controller_eligibility
        btst    #0,d0
        beq     controller_transaction_bad
        cmpi.w  #CONTROLLER_STAGE_STORAGE,CONTROLLER_STAGE
        beq.s   controller_storage_reply
        cmpi.w  #CONTROLLER_STAGE_RESULT,CONTROLLER_STAGE
        beq.s   .result
        tst.w   CONTROLLER_STAGE
        bne     controller_transaction_bad
        bsr     controller_account_outcome
        bne     controller_finish
        move.w  #CONTROLLER_STAGE_RESULT,CONTROLLER_STAGE
.result:
        moveq   #0,d0
        bra     controller_result

; A consumed reply cannot be replayed by redispatching the controller. Failed
; storage may have changed MAP scratch; only a successful new load can PREPARE.
controller_storage_reply:
        move.w  #CONTROLLER_STAGE_RESULT,CONTROLLER_STAGE
        cmpi.l  #STORAGE_MODULE_ID,EDITOR_SESSION_BASE+REQ_RESULT_ID
        bne     controller_transaction_bad
        clr.l   EDITOR_SESSION_BASE+REQ_RESULT_ID
        move.w  EDITOR_SESSION_BASE+REQ_LAST_RESULT,d0
        bne     controller_result
        bsr     controller_check_record
        bne     controller_result
        bsr     controller_check_identity
        bne     controller_result
        bsr     controller_check_disk
        bne     controller_result
        bsr     controller_check_payload
        bne     controller_result
        bsr     controller_project_titles
        bne     controller_result
        bsr     controller_eligibility
        cmpi.w  #CONTROLLER_OP_RETRY,CONTROLLER_OPERATION
        beq.s   .retry
        cmpi.w  #CONTROLLER_OP_NEXT,CONTROLLER_OPERATION
        bne     controller_transaction_bad
        btst    #1,d0
        beq     controller_transaction_bad
        bsr     checkpoint_preflight
        bne     controller_result
        bra.s   controller_transaction_publish
.retry:
        btst    #0,d0
        beq     controller_transaction_bad
controller_transaction_publish:
        move.w  sr,-(sp)
        ori.w   #$0700,sr
        bsr     controller_epoch
        bne.s   .unmask
        cmpi.w  #CONTROLLER_OP_RETRY,CONTROLLER_OPERATION
        bne.s   .next
        bsr     checkpoint_retry
        bra.s   .committed
.next:
        move.w  native_phase_number,-(sp)
        move.w  native_phases_remaining,-(sp)
        move.w  CONTROLLER_TARGET_PHASE,d0
        move.w  d0,native_phase_number
        moveq   #0,d1
        move.b  EDITOR_METADATA_BASE+CFMD_PHASE_COUNT,d1
        sub.w   d0,d1
        move.w  d1,native_phases_remaining
        bsr     checkpoint_capture
        tst.w   d0
        beq.s   .discard
        move.w  (sp),native_phases_remaining
        move.w  2(sp),native_phase_number
.discard:
        addq.l  #4,sp
.committed:
        tst.w   d0
        bne.s   .unmask
        bsr     controller_transaction_init
        move.w  #REQ_ACTION_PREPARE,EDITOR_SESSION_BASE+REQ_ACTION
.unmask:
        move.w  (sp)+,sr
        tst.w   d0
        bne.s   controller_result
        bra     controller_finish

; D0.w is the latest transaction error. UI choices are re-authorized here.
controller_result:
        move.w  d0,d6
        bsr     controller_eligibility
        move.w  d6,d1
        bsr     controller_result_ui
        move.w  d0,d5
        beq     controller_result_return
        bsr     controller_eligibility
        cmpi.w  #CONTROLLER_OP_RETRY,d5
        beq.s   .retry
        cmpi.w  #CONTROLLER_OP_NEXT,d5
        bne     controller_transaction_bad
        btst    #1,d0
        beq     controller_transaction_bad
        move.w  CONTROLLER_SOURCE_PHASE,d1
        addq.w  #1,d1
        bra.s   .request
.retry:
        btst    #0,d0
        beq     controller_transaction_bad
        move.w  CONTROLLER_SOURCE_PHASE,d1
.request:
        move.w  d5,CONTROLLER_OPERATION
        move.w  d1,CONTROLLER_TARGET_PHASE
        move.w  d1,STORAGE_SELECTED
        lea     STORAGE_CONTEXT,a0
        moveq   #STORAGE_READ_CONTEXT_BYTES/4-1,d0
.clear:
        clr.l   (a0)+
        dbra    d0,.clear
        lea     BROWSER_SELECTED_NAME,a0
        lea     STORAGE_CONTEXT,a1
        moveq   #3,d0
.name:
        move.l  (a0)+,(a1)+
        dbra    d0,.name
        lea     BROWSER_DISK_ID,a0
        moveq   #3,d0
.id:
        move.l  (a0)+,(a1)+
        dbra    d0,.id
        clr.l   STORAGE_READY
        move.w  #STORAGE_CMD_VALIDATE,STORAGE_COMMAND
        clr.l   EDITOR_SESSION_BASE+REQ_RESULT_ID
        clr.w   EDITOR_SESSION_BASE+REQ_LAST_RESULT
        lea     controller_storage_request(pc),a0
        lea     EDITOR_SESSION_BASE+REQ_NAME,a1
        moveq   #5,d0
.module:
        move.l  (a0)+,(a1)+
        dbra    d0,.module
        move.w  #CONTROLLER_STAGE_STORAGE,CONTROLLER_STAGE
        move.w  #REQ_ACTION_DISPATCH,EDITOR_SESSION_BASE+REQ_ACTION
controller_before_storage:
        moveq   #0,d0
        bra.s   controller_finish
controller_transaction_bad:
        moveq   #CONTROLLER_STATE_ERROR,d0
        bra.s   controller_finish
controller_result_return:
        moveq   #0,d0
controller_finish:
        tst.w   d0
        beq.s   .publish_result
        tst.w   d7
        beq.s   .publish_result
        ; Only a just-created, inactive session reaches this rollback. Its
        ; snapshot tag and mode cannot change during the bounded transaction.
        move.w  d0,d6
        bsr     session_restore_campaign
        tst.w   d0
        bne.s   .publish_result
        move.w  d6,d0
.publish_result:
        move.w  d0,d6
        move.w  d0,EDITOR_SESSION_BASE+REQ_LAST_RESULT
        move.l  #CONTROLLER_MODULE_ID,EDITOR_SESSION_BASE+REQ_RESULT_ID
        tst.w   d0
        beq.s   .status
        tst.w   session_custom_mode
        bne.s   .status
        tst.w   native_gameplay_active
        bne.s   .status
        move.w  EDITOR_SESSION_BASE+REQ_PURPOSE,d1
        subq.w  #1,d1
        lsr.w   #1,d1
        bne.s   .status
        ; The unchanged hill still owns its graphics. Return an initial error
        ; to the browser only after any newly captured campaign was restored.
        lea     controller_browser_request(pc),a0
        lea     EDITOR_SESSION_BASE+REQ_NAME,a1
        moveq   #5,d0
.request:
        move.l  (a0)+,(a1)+
        dbra    d0,.request
        move.w  #REQ_ACTION_DISPATCH,EDITOR_SESSION_BASE+REQ_ACTION
.status:
        move.w  d6,d0
        ext.l   d0
        movem.l (sp)+,d1-d7/a0-a6
        tst.w   d0
        rts

controller_epoch:
        moveq   #STORAGE_READ_CANCELLED,d0
        tst.l   STORAGE_CONTEXT+STORAGE_READ_CANCEL
        bne.s   .return
        moveq   #4,d0
        moveq   #0,d0
.return:
        tst.w   d0
        rts

controller_transaction_init:
        lea     CONTROLLER_TRANSACTION,a0
        moveq   #5,d0
.clear:
        clr.l   (a0)+
        dbra    d0,.clear
        moveq   #0,d0
        move.b  EDITOR_METADATA_BASE+CFMD_PHASE_INDEX,d0
        move.w  d0,CONTROLLER_SOURCE_PHASE
        move.w  d0,CONTROLLER_TARGET_PHASE
        move.l  EDITOR_METADATA_BASE+CFMD_MANIFEST_CRC,CONTROLLER_MANIFEST_CRC
        move.l  EDITOR_METADATA_BASE+CFMD_GENERATION,CONTROLLER_GENERATION
        move.l  #CONTROLLER_TRANSACTION_TAG,CONTROLLER_TRANSACTION
        moveq   #0,d0
        rts

; D1=1 only for an objective success whose original caller could advance.
; Completion accounting separately follows the captured native SR.Z alone.
controller_success:
        moveq   #0,d1
        btst    #2,session_outcome_sr+1
        beq.s   .return
        tst.w   session_outcome_no_squad
        bne.s   .return
        tst.w   session_outcome_failure
        bne.s   .return
        tst.w   session_outcome_success
        beq.s   .return
        moveq   #1,d1
.return:
        tst.w   d1
        rts

; Eligibility uses the old checkpoint, never an uncommitted STG candidate.
controller_eligibility:
        moveq   #0,d0
        cmpi.l  #SESSION_CHECKPOINT_TAG,SESSION_CHECKPOINT_VALID
        bne.s   .return
        moveq   #0,d1
        move.b  CONTROLLER_SAVED_POLICY+CFMD_PHASE_INDEX-CFMD_ID,d1
        cmp.w   CONTROLLER_SOURCE_PHASE,d1
        bne.s   .return
        moveq   #0,d2
        move.b  CONTROLLER_SAVED_POLICY+CFMD_PHASE_COUNT-CFMD_ID,d2
        cmpi.w  #6,d2
        bhi.s   .return
        cmp.w   d2,d1
        bhs.s   .return
        moveq   #1,d0
        addq.w  #1,d1
        cmp.w   d2,d1
        bhs.s   .return
        bsr.s   controller_success
        beq.s   .return
        bset    #1,d0
.return:
        rts

controller_check_identity:
        moveq   #CONTROLLER_RECORD_ERROR,d0
        lea     CONTROLLER_SAVED_POLICY,a0
        lea     EDITOR_METADATA_BASE+CFMD_ID,a1
        move.l  CONTROLLER_GENERATION,d1
        cmp.l   4(a0),d1
        bne.s   .return
        move.l  CONTROLLER_MANIFEST_CRC,d1
        cmp.l   CFMD_MANIFEST_CRC-CFMD_ID(a0),d1
        bne.s   .return
        moveq   #0,d1
        move.b  CFMD_PHASE_INDEX-CFMD_ID(a1),d1
        cmp.w   CONTROLLER_TARGET_PHASE,d1
        bne.s   .return
        cmpi.w  #CONTROLLER_OP_RETRY,CONTROLLER_OPERATION
        bne.s   .next
        cmp.w   CONTROLLER_SOURCE_PHASE,d1
        bne.s   .return
        moveq   #19,d1
.retry:
        cmpm.w  (a0)+,(a1)+
        bne.s   .return
        dbra    d1,.retry
        bra.s   .ok
.next:
        cmpi.w  #CONTROLLER_OP_NEXT,CONTROLLER_OPERATION
        bne.s   .return
        subq.w  #1,d1
        cmp.w   CONTROLLER_SOURCE_PHASE,d1
        bne.s   .return
        moveq   #2,d1
.mission:
        cmpm.l  (a0)+,(a1)+
        bne.s   .return
        dbra    d1,.mission
        cmpm.b  (a0)+,(a1)+
        bne.s   .return
        ; The phase policy differs; the manifest length and CRC cannot.
        lea     CONTROLLER_SAVED_POLICY+CFMD_MANIFEST_BYTES-CFMD_ID,a0
        lea     EDITOR_METADATA_BASE+CFMD_MANIFEST_BYTES,a1
        cmpm.w  (a0)+,(a1)+
        bne.s   .return
        cmpm.l  (a0)+,(a1)+
        bne.s   .return
.ok:
        moveq   #0,d0
.return:
        tst.w   d0
        rts

; Native phase completion is counted once before any retryable disk request.
; Final custom success grants earned ranks directly to each surviving record,
; including unassigned survivors, without the native debrief's cursor mutation.
controller_account_outcome:
        moveq   #CONTROLLER_STATE_ERROR,d0
        tst.w   CONTROLLER_ACCOUNTED
        bne     .return
        lea     native_roster,a0
        moveq   #7,d2
.validate:
        cmpi.w  #-1,(a0)
        beq.s   .empty
        cmpi.w  #360,(a0)
        bhs     .return
        cmpi.b  #15,2(a0)
        bhi     .return
        cmpi.b  #6,3(a0)
        bhi     .return
        bra.s   .valid_next
.empty:
        tst.w   4(a0)
        bpl     .return
.valid_next:
        lea     12(a0),a0
        dbra    d2,.validate
        move.w  sr,-(sp)
        ori.w   #$0700,sr
        btst    #2,session_outcome_sr+1
        beq.s   .accounted
        lea     native_roster,a0
        moveq   #7,d2
.count:
        tst.w   4(a0)
        bmi.s   .count_next
        addq.b  #1,3(a0)
.count_next:
        lea     12(a0),a0
        dbra    d2,.count
        bsr     controller_success
        beq.s   .accounted
        moveq   #0,d1
        move.b  CONTROLLER_SAVED_POLICY+CFMD_PHASE_COUNT-CFMD_ID,d1
        subq.w  #1,d1
        cmp.w   CONTROLLER_SOURCE_PHASE,d1
        bne.s   .accounted
        lea     native_roster,a0
        moveq   #7,d2
.promote:
        cmpi.w  #-1,(a0)
        beq.s   .promote_next
        moveq   #0,d1
        move.b  2(a0),d1
        add.b   3(a0),d1
        cmpi.w  #15,d1
        bls.s   .rank
        moveq   #15,d1
.rank:
        move.b  d1,2(a0)
        clr.b   3(a0)
.promote_next:
        lea     12(a0),a0
        dbra    d2,.promote
.accounted:
        move.w  #1,CONTROLLER_ACCOUNTED
        move.w  (sp)+,sr
        moveq   #0,d0
.return:
        tst.w   d0
        rts

controller_check_record:
        moveq   #CONTROLLER_RECORD_ERROR,d0
        cmpi.w  #REQ_PURPOSE_PLAY,EDITOR_SESSION_BASE+REQ_PURPOSE
        bne.s   .return
        cmpi.l  #BROWSER_STATE_TAG,BROWSER_MAGIC
        bne.s   .return
        cmpi.w  #1,BROWSER_VERSION
        bne.s   .return
        cmpi.w  #REQ_PURPOSE_PLAY,BROWSER_PURPOSE
        bne.s   .return
        cmpi.w  #3,BROWSER_DATA_DRIVE
        bhi.s   .return
        cmpi.l  #1,STORAGE_READY
        bne.s   .return
        tst.w   STORAGE_STATUS
        bne.s   .return
        tst.l   STORAGE_ERRORS
        bne.s   .return
        bra.s   controller_record_metadata
.return:
        tst.w   d0
        rts
controller_record_metadata:
        moveq   #CONTROLLER_RECORD_ERROR,d0
        cmpi.l  #CFMD_MAGIC,EDITOR_METADATA_BASE
        bne.s   .return
        cmpi.l  #$00010100,EDITOR_METADATA_BASE+4
        bne.s   .return
        moveq   #0,d1
        move.b  EDITOR_METADATA_BASE+CFMD_PHASE_COUNT,d1
        beq.s   .return
        cmpi.w  #6,d1
        bhi.s   .return
        moveq   #0,d2
        move.b  EDITOR_METADATA_BASE+CFMD_PHASE_INDEX,d2
        cmp.w   d1,d2
        bhs.s   .return
        cmp.w   STORAGE_SELECTED,d2
        bne.s   .return
        tst.w   EDITOR_METADATA_BASE+CFMD_RECRUITS
        ble.s   .return
        lea     EDITOR_METADATA_BASE+CFMD_MANIFEST_NAME,a0
        lea     BROWSER_SELECTED_NAME,a1
        lea     STORAGE_MANIFEST_NAME,a2
        moveq   #3,d1
.name:
        move.l  (a0)+,d2
        cmp.l   (a1)+,d2
        bne.s   .return
        cmp.l   (a2)+,d2
        bne.s   .return
        dbra    d1,.name
        moveq   #0,d0
.return:
        tst.w   d0
        rts

; Recheck resident payload bytes, not just the earlier service's READY tag.
; Positive bounded lengths prevent CRC reads outside their fixed owners.
controller_check_payload:
        moveq   #CONTROLLER_PAYLOAD_ERROR,d0
        moveq   #0,d1
        move.w  EDITOR_METADATA_BASE+CFMD_MAP_BYTES,d1
        cmpi.w  #96,d1
        blo.s   .return
        cmpi.w  #EDITOR_READBACK_BYTES,d1
        bhi.s   .return
        lea     map_file_buffer,a0
        bsr     read_crc32
        cmp.l   EDITOR_METADATA_BASE+CFMD_MAP_CRC,d0
        bne.s   .bad
        moveq   #0,d1
        move.w  EDITOR_METADATA_BASE+CFMD_SPT_BYTES,d1
        cmpi.w  #10,d1
        blo.s   .bad
        cmpi.w  #430,d1
        bhi.s   .bad
        lea     EDITOR_SPT_BASE,a0
        bsr     read_crc32
        cmp.l   EDITOR_METADATA_BASE+CFMD_SPT_CRC,d0
        bne.s   .bad
        moveq   #0,d0
        rts
.bad:
        moveq   #CONTROLLER_PAYLOAD_ERROR,d0
.return:
        tst.w   d0
        rts

controller_project_titles:
        lea     EDITOR_METADATA_BASE+CFMD_TITLE,a0
        lea     CONTROLLER_TITLE,a1
        bsr.s   controller_project_one
        bne.s   .return
        lea     EDITOR_METADATA_BASE+CFMD_PHASE_TITLE,a0
        lea     CONTROLLER_PHASE_TITLE,a1
        bsr.s   controller_project_one
.return:
        rts
controller_project_one:
        movea.l a0,a2
        moveq   #0,d0
.length:
        cmpi.b  #$FF,(a2)+
        beq.s   .project
        addq.w  #1,d0
        cmpi.w  #64,d0
        blo.s   .length
        moveq   #CONTROLLER_TITLE_ERROR,d0
        rts
.project:
        moveq   #1,d1
        move.w  #320,d2
        moveq   #1,d3
        bsr     text_preflight
        tst.w   d0
        beq.s   .return
        moveq   #CONTROLLER_TITLE_ERROR,d0
.return:
        rts

        even
controller_browser_request:
        dc.b "cf_browser.mod",0,0
        dc.l BROWSER_MODULE_ID,EDITOR_SERIALIZER_BYTES
controller_storage_request:
        dc.b "cf_storage.mod",0,0
        dc.l STORAGE_MODULE_ID,EDITOR_SERIALIZER_BYTES

        include "test_route.s"
        include "snapshot.s"
        include "authoring.s"
        include "authoring_new.s"
        include "new_setup.s"
        include "template_picker.s"
        include "template_import.s"
        include "../template/metadata.s"
        include "../template/read.s"
        include "../template/rnc.s"
        include "checkpoint.s"
        include "text.s"
        include "result_ui.s"
        include "../dialog/dialog.s"
        include "../dialog/text.s"
        include "../dialog/new_mission.s"
        include "../dialog/template_list.s"
        include "../storage/read.s"
controller_end:
        ifgt controller_end-controller_start-EDITOR_SERIALIZER_BYTES
        fail "Controller exceeds serialization code partition"
        endif
        ifgt CONTROLLER_PHASE_TITLE+64-EDITOR_METADATA_BASE-EDITOR_METADATA_BYTES
        fail "Controller title projection exceeds resident metadata"
        endif
        ifgt STORAGE_READ_WORK_BYTES+96-STORAGE_READ_CANDIDATE_OFFSET
        fail "Controller empty roster overlaps the metadata candidate"
        endif
