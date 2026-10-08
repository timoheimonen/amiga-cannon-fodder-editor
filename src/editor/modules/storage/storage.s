; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        include "layout.i"
        include "module.i"
        include "session.i"
        include "fodders.i"
        include "storage_read.i"
        include "metadata.i"
        include "payload.i"
        include "storage.i"
        include "browser.i"
        include "controller.i"
        section .text,code
        xdef storage_start,storage_end,storage_entry,storage_module_entry
        xdef storage_before_file,storage_before_publish,storage_direct_publish,storage_phase
storage_phase equ STORAGE_PHASE
storage_start:
        dc.l MODULE_MAGIC
        dc.w MODULE_ABI,MODULE_HEADER_BYTES
        dc.l STORAGE_MODULE_ID,EDITOR_MODULE_BASE
        dc.l storage_end-storage_start
        dc.l storage_module_entry-storage_start
        dc.l 0,0

; ABI 2 service entry. Qualify the Custom directory and its pinned CFDI identity.
; Inspection may replace the reader context, so retain its bounded request on
; the stack until qualification completes.
storage_module_entry:
        movem.l d1-d7/a0-a6,-(sp)
        moveq   #STORAGE_READ_INVALID,d1
        cmpi.w  #MODULE_ABI,d0
        bne     storage_module_bad_entry
        cmpa.l  #EDITOR_SESSION_BASE,a0
        bne     storage_module_bad_entry
        tst.w   session_custom_mode
        beq.s   .caller
        cmpi.w  #1,session_custom_mode
        bne     storage_module_bad_entry
        cmpi.w  #SESSION_SNAPSHOT_TAG,SESSION_SNAPSHOT_VALID
        bne     storage_module_bad_entry
        cmpi.l  #CONTROLLER_TRANSACTION_TAG,CONTROLLER_TRANSACTION
        bne     storage_module_bad_entry
        cmpi.w  #CONTROLLER_STAGE_STORAGE,CONTROLLER_STAGE
        bne     storage_module_bad_entry
        cmpi.w  #SESSION_EVENT_OUTCOME,session_event
        bne     storage_module_bad_entry
        tst.w   native_gameplay_active
        bne     storage_module_bad_entry
        cmpi.w  #REQ_PURPOSE_PLAY,EDITOR_SESSION_BASE+REQ_PURPOSE
        bne     storage_module_bad_entry
        move.w  CONTROLLER_OPERATION,d0
        subq.w  #1,d0
        cmpi.w  #1,d0
        bhi     storage_module_bad_entry
        move.w  CONTROLLER_TARGET_PHASE,d0
        cmp.w   STORAGE_SELECTED,d0
        bne     storage_module_bad_entry
        cmpi.w  #6,d0
        bhs     storage_module_bad_entry
.caller:
        cmpi.l  #BROWSER_STATE_TAG,BROWSER_MAGIC
        bne     storage_module_bad_entry
        cmpi.w  #1,BROWSER_VERSION
        bne     storage_module_bad_entry
        move.w  BROWSER_DATA_DRIVE,d0
        tst.w   d0
        bne     storage_module_bad_entry
        clr.l   STORAGE_READY
        move.w  sensi_selected_drive,-(sp)
        lea     -STORAGE_READ_CONTEXT_BYTES(sp),sp
        lea     STORAGE_CONTEXT,a0
        movea.l sp,a1
        moveq   #STORAGE_READ_CONTEXT_BYTES/4-1,d0
.save:
        move.l  (a0)+,(a1)+
        dbf     d0,.save
        bsr     storage_epoch
        bne.s   storage_module_qualified
        lea     STORAGE_CONTEXT,a0
        bsr     storage_inspect_disk
        tst.w   d0
        bne.s   storage_module_qualified
.identity:
        lea     STORAGE_CONTEXT+STORAGE_INSPECT_DISK_ID,a0
        lea     STORAGE_READ_DISK_ID(sp),a1
        moveq   #3,d1
        moveq   #STORAGE_READ_MEDIA,d0
.compare:
        cmpm.l  (a0)+,(a1)+
        bne.s   storage_module_qualified
        dbf     d1,.compare
        moveq   #0,d0
storage_module_qualified:
        move.w  d0,d7
        movea.l sp,a0
        lea     STORAGE_CONTEXT,a1
        ; CANCEL remains live; inspection results are never raw-read results.
        moveq   #STORAGE_READ_RESULT_BYTES/4-1,d0
.restore:
        move.l  (a0)+,(a1)+
        dbf     d0,.restore
        moveq   #6,d0
.clear_result:
        clr.l   (a1)+
        dbf     d0,.clear_result
        lea     STORAGE_READ_CONTEXT_BYTES(sp),sp
        move.w  d7,d0
        bne.s   storage_module_finish
        bsr     storage_entry
storage_module_finish:
        move.w  d0,d7
        move.w  (sp)+,d1
.status:
        move.w  d7,STORAGE_STATUS
        beq.s   .result
        clr.l   STORAGE_READY
.result:
        move.w  d7,EDITOR_SESSION_BASE+REQ_LAST_RESULT
        move.l  #STORAGE_MODULE_ID,EDITOR_SESSION_BASE+REQ_RESULT_ID
        lea     storage_browser_request(pc),a0
        tst.w   session_custom_mode
        beq.s   .reply
        lea     storage_controller_request(pc),a0
.reply:
        lea     EDITOR_SESSION_BASE+REQ_NAME,a1
        moveq   #5,d0
.request:
        move.l  (a0)+,(a1)+
        dbf     d0,.request
        move.w  #REQ_ACTION_DISPATCH,EDITOR_SESSION_BASE+REQ_ACTION
        move.w  d7,d0
        movem.l (sp)+,d1-d7/a0-a6
        tst.w   d0
        rts
storage_module_bad_entry:
        move.w  d1,d0
        movem.l (sp)+,d1-d7/a0-a6
        tst.w   d0
        rts

storage_select_drive:
        movem.l d1-d7/a0-a6,-(sp)
        moveq   #-1,d3
        movea.l d3,a0
        moveq   #0,d0
        jsr     sensi_disk_command
        movem.l (sp)+,d1-d7/a0-a6
        tst.w   d0
        rts
        even
storage_browser_request:
        dc.b "cf_browser.mod",0,0
        dc.l BROWSER_MODULE_ID,EDITOR_SERIALIZER_BYTES
storage_controller_request:
        dc.b "controller.mod",0,0
        dc.l CONTROLLER_MODULE_ID,EDITOR_SERIALIZER_BYTES

; The caller owns the inactive engine MAP and a qualified Custom directory.
; Fixed resident command block; A0's generic module context is not a request.
; D0.w=status; preserve D1-D7/A0-A6 and SP. READY is the publication boundary.
storage_entry:
        movem.l d1-d7/a0-a6,-(sp)
        lea     STORAGE_READY,a0
        moveq   #12,d0
.clear:
        clr.l   (a0)+
        dbf     d0,.clear
        clr.l   STORAGE_PRIVATE_RESERVED
        bsr     storage_epoch
        bne     storage_return
        lea     STORAGE_CONTEXT,a0
        cmpi.w  #STORAGE_CMD_READ,STORAGE_COMMAND
        beq     storage_raw
        cmpi.w  #STORAGE_CMD_INSPECT,STORAGE_COMMAND
        beq     storage_inspect
        cmpi.w  #STORAGE_CMD_VALIDATE,STORAGE_COMMAND
        bne     storage_argument
        move.w  STORAGE_SELECTED,d4
        cmpi.w  #6,d4
        bhs     storage_argument
        lea     STORAGE_MANIFEST_NAME,a1
        moveq   #3,d0
.name:
        move.l  (a0)+,(a1)+
        dbf     d0,.name
        lea     STORAGE_CONTEXT,a0
        clr.l   STORAGE_READ_EXPECTED_BYTES(a0)
        move.l  #EDITOR_MANIFEST_BYTES,STORAGE_READ_CAPACITY(a0)
        clr.l   STORAGE_READ_EXPECTED_CRC(a0)
        clr.l   STORAGE_READ_FLAGS(a0)
        move.w  #STORAGE_STAGE_MANIFEST,STORAGE_STAGE
        bsr     storage_read_checked
        bne     storage_return
        move.l  STORAGE_CONTEXT+STORAGE_READ_RESULT_BYTES,d0
        move.l  d0,STORAGE_MANIFEST_LENGTH
        lea     EDITOR_READBACK_BASE,a0
        lea     EDITOR_MANIFEST_BASE,a1
        bsr     storage_copy_bytes
        move.w  d4,d3
        bsr     storage_parse_phase
        bne     storage_return
        moveq   #0,d5
        move.b  STORAGE_CANDIDATE+CFMD_PHASE_COUNT,d5
        move.w  d5,STORAGE_PHASE_COUNT
        moveq   #0,d3
        moveq   #0,d6
storage_next_phase:
        cmp.w   d5,d3
        bhs.s   storage_selected_last
        cmp.w   d4,d3
        bne.s   storage_validate_phase
        addq.w  #1,d3
        bra.s   storage_next_phase
storage_selected_last:
        move.w  d4,d3
        moveq   #1,d6
storage_validate_phase:
        bsr     storage_parse_phase
        bne     storage_return
        lea     STORAGE_CANDIDATE+CFMD_MAP_NAME,a0
        moveq   #0,d0
        move.w  STORAGE_CANDIDATE+CFMD_MAP_BYTES,d0
        move.l  STORAGE_CANDIDATE+CFMD_MAP_CRC,d1
        move.w  #STORAGE_STAGE_MAP,STORAGE_STAGE
        bsr     storage_read_dependency
        bne     storage_return
        lea     EDITOR_READBACK_BASE,a0
        lea     map_file_buffer,a1
        move.l  STORAGE_CONTEXT+STORAGE_READ_RESULT_BYTES,d0
        bsr     storage_copy_bytes
        lea     STORAGE_CANDIDATE+CFMD_SPT_NAME,a0
        moveq   #0,d0
        move.w  STORAGE_CANDIDATE+CFMD_SPT_BYTES,d0
        move.l  STORAGE_CANDIDATE+CFMD_SPT_CRC,d1
        move.w  #STORAGE_STAGE_SPT,STORAGE_STAGE
        bsr     storage_read_dependency
        bne     storage_return
        move.w  #STORAGE_STAGE_PAYLOAD,STORAGE_STAGE
        lea     map_file_buffer,a0
        moveq   #0,d0
        move.w  STORAGE_CANDIDATE+CFMD_MAP_BYTES,d0
        lea     EDITOR_READBACK_BASE,a1
        moveq   #0,d1
        move.w  STORAGE_CANDIDATE+CFMD_SPT_BYTES,d1
        lea     STORAGE_CANDIDATE,a2
        lea     STORAGE_RESULT,a3
        lea     STORAGE_PAYLOAD_WORK,a4
        bsr     cf_payload_validate
        tst.w   d0
        bne     storage_return
        move.l  STORAGE_RESULT+CFVR_ERRORS,d0
        or.l    d0,STORAGE_ERRORS
        move.l  STORAGE_RESULT+CFVR_REVIEWS,d0
        or.l    d0,STORAGE_REVIEWS
        tst.w   d6
        bne.s   storage_publish
        addq.w  #1,d3
        bra     storage_next_phase

storage_publish:
        move.w  #STORAGE_STAGE_PUBLISH,STORAGE_STAGE
        bsr     storage_epoch
        bne     storage_return
        ; No more file reads: the short SPT leaves room for rollback records.
        lea     EDITOR_METADATA_BASE,a0
        lea     STORAGE_OLD_METADATA,a1
        move.w  #EDITOR_METADATA_BYTES,d0
        bsr     storage_copy_bytes
        lea     EDITOR_SPT_BASE,a0
        lea     STORAGE_OLD_SPT,a1
        bsr     storage_copy_spt
        lea     STORAGE_CANDIDATE,a0
        lea     EDITOR_METADATA_BASE,a1
        move.w  #CFMD_RECORD_BYTES,d0
        bsr     storage_copy_bytes
        moveq   #(EDITOR_METADATA_BYTES-CFMD_RECORD_BYTES)/4-1,d0
.metadata_reserve:
        clr.l   (a1)+
        dbf     d0,.metadata_reserve
        lea     EDITOR_SPT_BASE,a1
        move.w  #EDITOR_SPT_BYTES/2-1,d0
.spt_clear:
        clr.w   (a1)+
        dbf     d0,.spt_clear
        lea     EDITOR_READBACK_BASE,a0
        lea     EDITOR_SPT_BASE,a1
        move.w  STORAGE_CANDIDATE+CFMD_SPT_BYTES,d0
        bsr     storage_copy_bytes
storage_before_publish:
        bsr     storage_epoch
        beq.s   storage_success
        move.w  d0,-(sp)
        lea     STORAGE_OLD_METADATA,a0
        lea     EDITOR_METADATA_BASE,a1
        move.w  #EDITOR_METADATA_BYTES,d0
        bsr     storage_copy_bytes
        lea     STORAGE_OLD_SPT,a0
        lea     EDITOR_SPT_BASE,a1
        bsr     storage_copy_spt
        move.w  (sp)+,d0
        bra.s   storage_return
storage_success:
        move.l  #1,STORAGE_READY
        moveq   #0,d0
storage_return:
        move.w  d0,STORAGE_STATUS
        movem.l (sp)+,d1-d7/a0-a6
        tst.w   d0
        rts
storage_argument:
        moveq   #STORAGE_READ_INVALID,d0
        bra.s   storage_return
storage_raw:
        bsr     storage_read_entry
        tst.w   d0
        beq.s   storage_direct_publish
        bra.s   storage_return
storage_inspect:
        bsr     storage_inspect_disk
        tst.w   d0
        bne.s   storage_return
storage_direct_publish:
        bsr     storage_epoch
        beq.s   storage_success
        bra.s   storage_return

storage_parse_phase:
        move.w  #STORAGE_STAGE_PARSE,STORAGE_STAGE
        move.w  d3,STORAGE_PHASE
        bsr.s   storage_epoch
        bne.s   .return
        lea     EDITOR_MANIFEST_BASE,a0
        move.l  STORAGE_MANIFEST_LENGTH,d0
        lea     STORAGE_MANIFEST_NAME,a1
        move.w  d3,d1
        lea     EDITOR_SERIAL_WORK_BASE,a2
        lea     STORAGE_PARSER_WORK,a3
        bsr     cfmi_parse
        tst.w   d0
        bne.s   .return
        lea     EDITOR_SERIAL_WORK_BASE,a0
        lea     STORAGE_CANDIDATE,a1
        move.w  #CFMD_RECORD_BYTES,d0
        bsr.s   storage_copy_bytes
        moveq   #0,d0
.return:
        rts

; A0=name, D0.l=positive checked reference length, D1.l=CRC.
storage_read_dependency:
        lea     STORAGE_CONTEXT,a1
        move.l  d0,STORAGE_READ_EXPECTED_BYTES(a1)
        move.l  d0,STORAGE_READ_CAPACITY(a1)
        move.l  d1,STORAGE_READ_EXPECTED_CRC(a1)
        move.w  #STORAGE_READ_CHECK_CRC,STORAGE_READ_FLAGS(a1)
        moveq   #3,d0
.name:
        move.l  (a0)+,(a1)+
        dbf     d0,.name
storage_read_checked:
storage_before_file:
        bsr.s   storage_epoch
        bne.s   .return
        lea     STORAGE_CONTEXT,a0
        bsr.s   storage_read_entry
        tst.w   d0
.return:
        rts

; Return the cancellation status of the current storage request.
storage_epoch:
        moveq   #STORAGE_READ_CANCELLED,d0
        tst.l   STORAGE_CONTEXT+STORAGE_READ_CANCEL
        bne.s   .return
        moveq   #4,d0
        moveq   #0,d0
.return:
        tst.w   d0
        rts

storage_copy_spt:
        move.w  #EDITOR_SPT_BYTES,d0
storage_copy_bytes:
        subq.w  #1,d0
.copy:
        move.b  (a0)+,(a1)+
        dbf     d0,.copy
        rts

        include "read.s"
        include "manifest.s"
        include "payload.s"
storage_end:
        ifgt storage_end-storage_start-EDITOR_SERIALIZER_BYTES
        fail "Storage module exceeds serializer code budget"
        endif
        ifgt STORAGE_IO_END-EDITOR_IO_BASE-EDITOR_IO_BYTES
        fail "Storage command block exceeds resident I/O budget"
        endif
        ifgt STORAGE_PARSER_WORK+CFMD_PARSE_BYTES-EDITOR_READBACK_BASE-EDITOR_READBACK_BYTES
        fail "Parser work exceeds inactive readback storage"
        endif
        ifgt STORAGE_PAYLOAD_WORK+CFVR_SCRATCH_BYTES-STORAGE_CANDIDATE
        fail "Payload work overlaps retained phase metadata"
        endif
