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
        include "save.i"
        include "save_return.i"
        include "authoring.i"
save_read_context    equ EDITOR_IO_BASE+64
save_old_generation  equ SAVE_CONTEXT+100
save_initial_crc     equ SAVE_CONTEXT+104
save_required_sectors equ SAVE_CONTEXT+112
save_guard_installed equ SAVE_CONTEXT+116
save_name            equ SAVE_ENCODER_STATE
save_id_directory    equ EDITOR_READBACK_BASE+10240

PAYLOAD_STRUCTURAL_ONLY equ 1
        section .text,code
        xdef cf_save_start,cf_save_end,cf_save_entry,cf_save_module_entry
        xdef cf_save_before_write,cf_save_before_manifest,cf_save_before_publish
        xdef cf_save_after_metadata
        xdef cf_save_return_decision,cf_save_return_copy,cf_save_return_publish
        xdef cf_save_module_bad,cf_save_module_return,cf_save_editor_request
        xdef cf_save_qualify,cf_save_data_ready,cf_save_entered_result
        xdef cf_save_author_invariant,cf_save_plain_return
cf_save_start:
        dc.l MODULE_MAGIC
        dc.w MODULE_ABI,MODULE_HEADER_BYTES
        dc.l SAVE_MODULE_ID,EDITOR_MODULE_BASE
        dc.l cf_save_end-cf_save_start
        dc.l cf_save_module_entry-cf_save_start
        dc.l 0,0

cf_save_module_entry:
        movem.l d1-d7/a0-a6,-(sp)
        moveq #STORAGE_READ_INVALID,d1
        cmpi.w #MODULE_ABI,d0
        bne cf_save_module_bad
        cmpa.l #EDITOR_SESSION_BASE,a0
        bne cf_save_module_bad
        cmpi.w #2,session_custom_mode
        bne.s .core
        cmpi.w #SESSION_SNAPSHOT_TAG,SESSION_SNAPSHOT_VALID
        bne cf_save_author_invariant
        cmpi.l #AUR_MAGIC,AUR_BASE
        bne cf_save_author_invariant
        cmpi.w #AUR_VERSION,AUR_BASE+4
        bne cf_save_author_invariant
        bsr cf_save_qualify
        tst.w d0
        beq.s .core
        ; The overlay entered, but qualification refused before the core.
        ; This is an actual entered status, never a loader-cancel notice.
        clr.l SAVE_CONTEXT+SAVE_READY
        move.w d0,SAVE_CONTEXT+SAVE_STATUS
        move.w #SAVE_STAGE_ARGUMENT,SAVE_CONTEXT+SAVE_STAGE
        clr.w SAVE_CONTEXT+SAVE_PROCESSED
        clr.l SAVE_CONTEXT+SAVE_RESULT_BYTES
        clr.l SAVE_CONTEXT+SAVE_RESULT_BODY_CRC
        clr.w SAVE_CONTEXT+SAVE_CLEANUP_STATUS
        bra.s cf_save_entered_result
.core:
        lea SAVE_CONTEXT,a0
        bsr cf_save_entry
cf_save_entered_result:
        move.w d0,EDITOR_SESSION_BASE+REQ_LAST_RESULT
        move.l #SAVE_MODULE_ID,EDITOR_SESSION_BASE+REQ_RESULT_ID
cf_save_return_decision:
        cmpi.w #2,session_custom_mode
        bne.s cf_save_plain_return
        cmpi.w #SESSION_SNAPSHOT_TAG,SESSION_SNAPSHOT_VALID
        bne.s cf_save_author_invariant
        cmpi.l #SAVE_RETURN_AUR_MAGIC,SAVE_RETURN_AUR_BASE
        bne.s cf_save_author_invariant
        cmpi.w #SAVE_RETURN_AUR_VERSION,SAVE_RETURN_AUR_BASE+4
        bne.s cf_save_author_invariant
        lea cf_save_editor_request(pc),a0
        lea EDITOR_SESSION_BASE+REQ_NAME,a1
        moveq #5,d1
cf_save_return_copy:
        move.l (a0)+,(a1)+
        dbra d1,cf_save_return_copy
cf_save_return_publish:
        move.w #REQ_ACTION_DISPATCH,EDITOR_SESSION_BASE+REQ_ACTION
        bra.s cf_save_module_return
cf_save_plain_return:
        move.w #REQ_ACTION_RETURN,EDITOR_SESSION_BASE+REQ_ACTION
        bra.s cf_save_module_return
cf_save_module_bad:
        move.w d1,d0
cf_save_module_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
cf_save_editor_request:
        dc.b "cf_editor.mod",0,0,0
        dc.l SAVE_RETURN_EDITOR_ID,EDITOR_SERIALIZER_BYTES

; Broken author-owner invariants cannot fall into ordinary hill restoration.
; Invariant failure retains this SAVE frame in a noninteractive wait.
cf_save_author_invariant:
        jsr wait_frame
        bra.s cf_save_author_invariant

; Qualify the session and author state, then the Custom directory and its
; pinned CFDI identity.
; IO64..143 and WORK/READBACK are dead display scratch at this boundary.
; No authored byte, undo byte, AUR source/dirty field, or IRQ vector is changed.
cf_save_qualify:
        moveq #STORAGE_READ_INVALID,d0
        cmpi.w #SESSION_SNAPSHOT_TAG,SESSION_SNAPSHOT_VALID
        bne .return
        cmpi.w #SESSION_EVENT_HILL,session_event
        bne .return
        cmpi.w #REQ_PURPOSE_EDITOR,EDITOR_SESSION_BASE+REQ_PURPOSE
        bne .return
        tst.w native_gameplay_active
        bne .return
        tst.w native_fifth_plane
        bne .return
        move.w sr,d1
        andi.w #$0700,d1
        bne .return
        cmpi.l #AUR_MAGIC,AUR_BASE
        bne .return
        cmpi.w #AUR_VERSION,AUR_BASE+4
        bne .return
        cmpi.w #AUR_ASSETS_INCOMPLETE,AUR_BASE+AUR_ASSET_STATE
        bhi .return
        move.w AUR_BASE+AUR_FLAGS,d1
        andi.w #$FFFF-AUR_HAS_SOURCE-AUR_DIRTY,d1
        cmpi.w #AUR_SAVE_PENDING,d1
        bne .return
        tst.w AUR_BASE+AUR_TRANSPORT_STATUS
        bne .return
        tst.l AUR_BASE+AUR_TRANSPORT_ID
        bne .return
        cmpi.l #SAVE_MAGIC,SAVE_CONTEXT
        bne .return
        cmpi.l #$00010080,SAVE_CONTEXT+4
        bne .return
        cmpi.w #AUR_STATUS_UNENTERED,SAVE_CONTEXT+SAVE_STATUS
        bne.s .return
        tst.l SAVE_CONTEXT+SAVE_READY
        bne.s .return
        tst.l EDITOR_SESSION_BASE+REQ_RESULT_ID
        bne.s .return
        move.w AUR_BASE+AUR_DRIVE,d6
        cmpi.w #3,d6
        bhi.s .return
        cmp.w SAVE_CONTEXT+SAVE_DRIVE,d6
        bne.s .return
        lea AUR_BASE+AUR_DISK_ID,a0
        lea SAVE_CONTEXT+SAVE_DISK_ID,a1
        moveq #3,d1
.same_id:
        cmpm.l (a0)+,(a1)+
        bne.s .return
        dbra d1,.same_id
        tst.w d6
        bne.s .return
        bsr cf_save_epoch
        bne.s .return
        move.l SAVE_CONTEXT+SAVE_CANCEL,save_read_context+STORAGE_READ_CANCEL
        lea save_read_context,a0
        bsr storage_inspect_disk
        bne.s .return
.identity:
        lea save_read_context+STORAGE_INSPECT_DISK_ID,a0
        lea AUR_BASE+AUR_DISK_ID,a1
        moveq #3,d1
        moveq #STORAGE_READ_MEDIA,d0
.pinned_id:
        cmpm.l (a0)+,(a1)+
        bne.s .return
        dbra d1,.pinned_id
        bsr cf_save_epoch
cf_save_data_ready equ .return
.return:
        tst.w d0
        rts

; A0=fixed SVR1 request, D0.w=status. Authored MAP/SPT/CFMD and undo are
; immutable until verified publication; all registers except D0 are preserved.
cf_save_entry:
        movem.l d1-d7/a0-a6,-(sp)
        moveq #STORAGE_READ_INVALID,d0
        cmpa.l #SAVE_CONTEXT,a0
        bne cf_save_registers
        clr.w SAVE_CONTEXT+SAVE_STATUS
        move.w #SAVE_STAGE_ARGUMENT,SAVE_CONTEXT+SAVE_STAGE
        clr.w SAVE_CONTEXT+SAVE_PROCESSED
        clr.l SAVE_CONTEXT+SAVE_RESULT_BYTES
        clr.l SAVE_CONTEXT+SAVE_RESULT_BODY_CRC
        clr.l SAVE_CONTEXT+SAVE_READY
        clr.w SAVE_CONTEXT+SAVE_CLEANUP_STATUS
        lea SAVE_CONTEXT+SAVE_PRIVATE,a1
        moveq #14,d1
.private:
        clr.w (a1)+
        dbf d1,.private
        cmpi.l #SAVE_MAGIC,(a0)
        bne cf_save_return
        cmpi.w #SAVE_ABI,4(a0)
        bne cf_save_return
        cmpi.w #SAVE_CONTEXT_BYTES,6(a0)
        bne cf_save_return
        tst.w native_gameplay_active
        bne cf_save_return
        move.w session_custom_mode,d1
        beq.s .inactive
        cmpi.w #2,d1
        bne cf_save_return
        cmpi.w #SESSION_SNAPSHOT_TAG,SESSION_SNAPSHOT_VALID
        bne cf_save_return
        bra.s .ownership
.inactive:
        tst.w SESSION_SNAPSHOT_VALID
        bne cf_save_return
.ownership:
        tst.w SAVE_DRIVE(a0)
        bne cf_save_return
        move.w sr,d1
        andi.w #$0700,d1
        cmpi.w #$0600,d1
        bhs cf_save_return
        move.w SAVE_FLAGS(a0),d1
        cmpi.w #SAVE_KNOWN_FLAGS,d1
        bhi cf_save_return
        cmpi.w #SAVE_AS_NEW,d1
        beq cf_save_return
        moveq #0,d7
        move.b SAVE_PHASE_COUNT(a0),d7
        beq cf_save_return
        cmpi.w #6,d7
        bhi cf_save_return
        moveq #0,d6
        move.b SAVE_SELECTED(a0),d6
        cmp.w d7,d6
        bhs cf_save_return
        cmpi.l #CFMD_MAGIC,EDITOR_METADATA_BASE
        bne cf_save_return
        cmpi.w #CFMD_ABI,EDITOR_METADATA_BASE+4
        bne cf_save_return
        cmpi.w #CFMD_RECORD_BYTES,EDITOR_METADATA_BASE+6
        bne cf_save_return
        tst.w SAVE_FLAGS(a0)
        bne.s .source
        cmpi.w #1,d7
        bne cf_save_return
        lea SAVE_SOURCE_NAME(a0),a1
        moveq #6,d1
.no_source:
        tst.l (a1)+
        bne cf_save_return
        dbf d1,.no_source
        tst.w SAVE_REVISION(a0)
        bne cf_save_return
.source:
        moveq #0,d2
        lea SAVE_SOURCE_PHASES(a0),a1
.mapping:
        moveq #0,d1
        move.b (a1)+,d1
        cmp.w d7,d2
        bhs.s .unused
        cmpi.w #6,d1
        blo.s .mapped
        cmp.w d6,d2
        bne cf_save_return
        cmpi.w #SAVE_CURRENT_SOURCE,d1
        bne cf_save_return
        bra.s .mapped
.unused:
        cmpi.w #SAVE_CURRENT_SOURCE,d1
        bne cf_save_return
.mapped:
        addq.w #1,d2
        cmpi.w #6,d2
        blo.s .mapping
        tst.w SAVE_FLAGS(a0)
        bne.s .guard
        cmpi.b #SAVE_CURRENT_SOURCE,SAVE_SOURCE_PHASES(a0)
        bne cf_save_return
.guard:
        bsr cf_save_epoch
        bne cf_save_return
        move.w #1,save_guard_installed
.preflight:
        move.w #SAVE_STAGE_PREFLIGHT,SAVE_CONTEXT+SAVE_STAGE
        bsr cf_preflight_entry
        tst.w d0
        bne cf_save_return
        move.l SAVE_PREFLIGHT_RESULT+SAVE_DIRECTORY_CRC,save_initial_crc
        cmpi.w #SAVE_HAS_SOURCE,SAVE_CONTEXT+SAVE_FLAGS
        beq.s .manifest
        bsr cf_save_choose_id
        bne cf_save_return
.manifest:
        move.w #SAVE_STAGE_MANIFEST,SAVE_CONTEXT+SAVE_STAGE
        bsr cf_save_encode
        bne cf_save_return
        moveq #0,d6
        move.w #SAVE_STAGE_VALIDATE,SAVE_CONTEXT+SAVE_STAGE
        clr.w save_required_sectors
.validate:
        move.w d6,d0
        bsr cf_save_parse_new
        bne cf_save_return
        bsr cf_save_validate_phase
        bne cf_save_return
        moveq #0,d0
        move.w SAVE_CANDIDATE+CFMD_MAP_BYTES,d0
        bsr cf_save_add_sectors
        moveq #0,d0
        move.w SAVE_CANDIDATE+CFMD_SPT_BYTES,d0
        bsr cf_save_add_sectors
        addq.w #1,d6
        cmp.w d7,d6
        blo.s .validate
        move.l SAVE_CONTEXT+SAVE_RESULT_BYTES,d0
        bsr cf_save_add_sectors
        move.w #SAVE_STAGE_CAPACITY,SAVE_CONTEXT+SAVE_STAGE
        move.l SAVE_CONTEXT+SAVE_GENERATION,-(sp)
        lea SAVE_CONTEXT,a0
        bsr cf_preflight_entry
        move.l (sp)+,d1
        tst.w d0
        bne cf_save_return
        moveq #STORAGE_READ_MEDIA,d0
        cmp.l SAVE_CONTEXT+SAVE_GENERATION,d1
        bne cf_save_return
        move.l save_initial_crc,d1
        cmp.l SAVE_PREFLIGHT_RESULT+SAVE_DIRECTORY_CRC,d1
        bne cf_save_return
        moveq #SAVE_DIRECTORY_FULL,d0
        move.w d7,d1
        add.w d1,d1
        addq.w #1,d1
        cmp.w SAVE_PREFLIGHT_RESULT+SAVE_FREE_RECORDS,d1
        bhi cf_save_return
        moveq #SAVE_DISK_FULL,d0
        move.w save_required_sectors,d1
        cmp.w SAVE_PREFLIGHT_RESULT+SAVE_FREE_SECTORS,d1
        bhi cf_save_return
        moveq #0,d6
.write_phase:
        move.w d6,d0
        bsr cf_save_parse_new
        bne cf_save_return
        moveq #0,d5
.write_payload:
        bsr cf_save_write_payload
        bne cf_save_return
        addq.w #1,d5
        cmpi.w #2,d5
        blo.s .write_payload
        addq.w #1,d6
        cmp.w d7,d6
        blo.s .write_phase
cf_save_before_manifest:
        bsr cf_save_epoch
        bne cf_save_return
        move.w #SAVE_STAGE_MANIFEST_WRITE,SAVE_CONTEXT+SAVE_STAGE
        lea save_name,a0
        move.l SAVE_CONTEXT+SAVE_GENERATION,d0
        moveq #2,d2
        bsr cf_save_filename
        lea EDITOR_MANIFEST_BASE,a1
        move.l SAVE_CONTEXT+SAVE_RESULT_BYTES,d1
        bsr cf_write_entry
        tst.w d0
        bne cf_save_return
        addq.w #1,SAVE_CONTEXT+SAVE_PROCESSED
        move.w #SAVE_STAGE_MANIFEST_VERIFY,SAVE_CONTEXT+SAVE_STAGE
        lea EDITOR_MANIFEST_BASE,a0
        move.l SAVE_CONTEXT+SAVE_RESULT_BYTES,d1
        bsr read_crc32
        move.l d0,d1
        move.l SAVE_CONTEXT+SAVE_RESULT_BYTES,d0
        lea save_name,a0
        ; Read helper takes length in D0; LEA does not alter it.
        bsr cf_save_read_verified
        bne cf_save_return
        lea EDITOR_MANIFEST_BASE,a0
        lea EDITOR_READBACK_BASE,a1
        move.l SAVE_CONTEXT+SAVE_RESULT_BYTES,d0
        bsr cf_save_compare
        bne cf_save_return
        moveq #0,d0
        move.b SAVE_CONTEXT+SAVE_SELECTED,d0
        bsr cf_save_parse_new
        bne.s cf_save_return
cf_save_before_publish:
        bsr cf_save_epoch
        bne.s cf_save_return
        move.w #SAVE_STAGE_COMMIT,SAVE_CONTEXT+SAVE_STAGE
        lea EDITOR_METADATA_BASE,a0
        lea EDITOR_READBACK_BASE+6144,a1
        move.w #EDITOR_METADATA_BYTES,d0
        bsr cf_save_copy
        lea SAVE_CANDIDATE,a0
        lea EDITOR_METADATA_BASE,a1
        move.w #CFMD_RECORD_BYTES,d0
        bsr cf_save_copy
        moveq #(EDITOR_METADATA_BYTES-CFMD_RECORD_BYTES)/4-1,d0
.titles:
        clr.l (a1)+
        dbf d0,.titles
cf_save_after_metadata:
        bsr.s cf_save_epoch
        beq.s .commit
        move.w d0,-(sp)
        lea EDITOR_READBACK_BASE+6144,a0
        lea EDITOR_METADATA_BASE,a1
        move.w #EDITOR_METADATA_BYTES,d0
        bsr cf_save_copy
        move.w (sp)+,d0
        bra.s cf_save_return
.commit:
        move.w #SAVE_CLEANUP_PENDING,SAVE_CONTEXT+SAVE_CLEANUP_STATUS
        move.l #1,SAVE_CONTEXT+SAVE_READY
        move.w #SAVE_STAGE_CLEANUP,SAVE_CONTEXT+SAVE_STAGE
        xdef cf_save_cleanup
cf_save_cleanup:
        bsr cf_cleanup_entry
        moveq #0,d0
cf_save_return:
        move.w d0,SAVE_CONTEXT+SAVE_STATUS
        tst.w save_guard_installed
        beq.s cf_save_registers
        clr.w save_guard_installed
cf_save_registers:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

cf_save_epoch:
        moveq #STORAGE_READ_CANCELLED,d0
        tst.l SAVE_CONTEXT+SAVE_CANCEL
        bne.s .return
        moveq #0,d0
.return:
        tst.w d0
        rts

; Scan only canonical manifest names. Valid schemas authorize identities;
; malformed content never blocks choosing another identity or becomes trusted.
cf_save_choose_id:
        movem.l d1-d7/a0-a6,-(sp)
        lea EDITOR_READBACK_BASE+32,a0
        lea save_id_directory,a1
        move.w #4800,d0
        bsr cf_save_copy
        moveq #0,d7
        move.w SAVE_PREFLIGHT_RESULT+SAVE_LIVE_RECORDS,d7
        moveq #0,d6
        move.w #150,d5
.restart:
        moveq #0,d6
        lea save_id_directory,a5
.record:
        cmp.w d7,d6
        bhs .success
        cmpi.b #'.',8(a5)
        bne .next
        move.l 8(a5),d0
        ori.l #$00202020,d0
        cmpi.l #$2E636D69,d0
        bne .next
        tst.b 12(a5)
        bne .next
        cmpi.l #17,28(a5)
        blo .next
        cmpi.l #4096,28(a5)
        bhi .next
        movea.l a5,a0
        lea save_read_context,a1
        moveq #16,d0
        bsr cf_save_copy
        lea save_read_context,a1
        moveq #11,d1
.fold:
        move.b (a1),d0
        cmpi.b #'A',d0
        blo.s .fold_next
        cmpi.b #'Z',d0
        bhi.s .fold_next
        ori.b #32,(a1)
.fold_next:
        addq.l #1,a1
        dbf d1,.fold
        lea save_read_context,a0
        bsr read_valid_target
        tst.w d0
        bne.s .next
        move.l 28(a5),d0
        bsr cf_save_read_manifest
        bne.s .return
        lea EDITOR_READBACK_BASE,a0
        move.l 28(a5),d0
        lea save_read_context,a1
        moveq #0,d1
        lea EDITOR_SERIAL_WORK_BASE,a2
        lea SAVE_PARSER_WORK,a3
        bsr cfmi_parse
        tst.w d0
        bne.s .next
        move.l EDITOR_SERIAL_WORK_BASE+CFMD_ID,d0
        cmp.l SAVE_CONTEXT+SAVE_TARGET_ID,d0
        bne.s .next
        addq.l #1,SAVE_CONTEXT+SAVE_TARGET_ID
        dbf d5,.restart
        moveq #STORAGE_READ_CORRUPT,d0
        bra.s .return
.next:
        lea 32(a5),a5
        addq.w #1,d6
        bra .record
.success:
        moveq #0,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

cf_save_encode:
        movem.l d1-d7/a0-a6,-(sp)
        tst.w SAVE_CONTEXT+SAVE_FLAGS
        beq .begin
        lea SAVE_CONTEXT+SAVE_SOURCE_NAME,a0
        move.l SAVE_CONTEXT+SAVE_SOURCE_BYTES,d0
        cmpi.l #17,d0
        blo .argument
        cmpi.l #4096,d0
        bhi .argument
        bsr cf_save_read_manifest
        bne .return
        moveq #0,d0
        bsr cf_save_parse_old
        bne .return
        moveq #STORAGE_READ_VERIFY,d0
        move.l SAVE_CONTEXT+SAVE_SOURCE_ID,d1
        cmp.l SAVE_CANDIDATE+CFMD_ID,d1
        bne .return
        move.l SAVE_CONTEXT+SAVE_SOURCE_BODY_CRC,d1
        cmp.l SAVE_CANDIDATE+CFMD_MANIFEST_CRC,d1
        bne .return
        move.l SAVE_CANDIDATE+CFMD_GENERATION,save_old_generation
        moveq #0,d3
        move.b SAVE_CANDIDATE+CFMD_PHASE_COUNT,d3
        lea SAVE_CONTEXT+SAVE_SOURCE_PHASES,a1
        moveq #0,d2
.source_mapping:
        moveq #0,d1
        move.b (a1)+,d1
        cmpi.w #SAVE_CURRENT_SOURCE,d1
        beq.s .source_next
        cmp.w d3,d1
        bhs .argument
.source_next:
        addq.w #1,d2
        cmp.b SAVE_CONTEXT+SAVE_PHASE_COUNT,d2
        blo.s .source_mapping
        cmpi.w #SAVE_HAS_SOURCE,SAVE_CONTEXT+SAVE_FLAGS
        bne.s .save_as
        move.l SAVE_CONTEXT+SAVE_TARGET_ID,d1
        cmp.l SAVE_CONTEXT+SAVE_SOURCE_ID,d1
        bne .argument
        move.w SAVE_CANDIDATE+CFMD_REVISION,d1
        addq.w #1,d1
        cmp.w SAVE_CONTEXT+SAVE_REVISION,d1
        bne .argument
        bra.s .begin
.save_as:
        tst.w SAVE_CONTEXT+SAVE_REVISION
        bne .argument
.begin:
        lea EDITOR_METADATA_BASE,a0
        lea SAVE_CANDIDATE,a1
        move.w #CFMD_RECORD_BYTES,d0
        bsr cf_save_copy
        move.l SAVE_CONTEXT+SAVE_TARGET_ID,SAVE_CANDIDATE+CFMD_ID
        move.l SAVE_CONTEXT+SAVE_GENERATION,SAVE_CANDIDATE+CFMD_GENERATION
        move.w SAVE_CONTEXT+SAVE_REVISION,SAVE_CANDIDATE+CFMD_REVISION
        move.b SAVE_CONTEXT+SAVE_PHASE_COUNT,SAVE_CANDIDATE+CFMD_PHASE_COUNT
        lea SAVE_CANDIDATE,a0
        lea EDITOR_MANIFEST_BASE,a1
        move.l #SAVE_OUTPUT_CAPACITY,d0
        lea SAVE_ENCODER_STATE,a2
        bsr cf_encode_begin
        tst.w d0
        bne .return
        moveq #0,d6
.phase:
        cmp.b SAVE_CONTEXT+SAVE_SELECTED,d6
        beq.s .current
        lea SAVE_CONTEXT+SAVE_SOURCE_PHASES,a0
        moveq #0,d0
        move.b (a0,d6.w),d0
        bsr cf_save_parse_old
        bne .return
        bra.s .append
.current:
        lea EDITOR_METADATA_BASE,a0
        lea SAVE_CANDIDATE,a1
        move.w #CFMD_RECORD_BYTES,d0
        bsr cf_save_copy
        moveq #0,d1
        move.w SAVE_CANDIDATE+CFMD_MAP_BYTES,d1
        beq .argument
        cmpi.l #EDITOR_READBACK_BYTES,d1
        bhi .argument
        lea map_file_buffer,a0
        bsr read_crc32
        move.l d0,SAVE_CANDIDATE+CFMD_MAP_CRC
        moveq #0,d1
        move.w SAVE_CANDIDATE+CFMD_SPT_BYTES,d1
        beq.s .argument
        cmpi.l #430,d1
        bhi.s .argument
        lea EDITOR_SPT_BASE,a0
        bsr read_crc32
        move.l d0,SAVE_CANDIDATE+CFMD_SPT_CRC
.append:
        move.b SAVE_CONTEXT+SAVE_PHASE_COUNT,SAVE_CANDIDATE+CFMD_PHASE_COUNT
        move.b d6,SAVE_CANDIDATE+CFMD_PHASE_INDEX
        lea SAVE_CANDIDATE,a0
        lea SAVE_ENCODER_STATE,a2
        bsr cf_encode_phase
        tst.w d0
        bne.s .return
        addq.w #1,d6
        cmp.b SAVE_CONTEXT+SAVE_PHASE_COUNT,d6
        blo .phase
        bsr cf_encode_finish
        tst.w d0
        bne.s .return
        move.l SAVE_ENCODER_STATE+CFE_BYTES,SAVE_CONTEXT+SAVE_RESULT_BYTES
        move.l SAVE_ENCODER_STATE+CFE_CRC,SAVE_CONTEXT+SAVE_RESULT_BODY_CRC
        bra.s .return
.argument:
        moveq #STORAGE_READ_INVALID,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; D0.w phase; output is the private CFMD candidate. The old manifest resides
; in readback only until encoding finishes. New parsing never needs it again.
cf_save_parse_old:
        movem.l d1-d7/a0-a6,-(sp)
        move.w d0,d1
        lea EDITOR_READBACK_BASE,a0
        move.l SAVE_CONTEXT+SAVE_SOURCE_BYTES,d0
        lea SAVE_CONTEXT+SAVE_SOURCE_NAME,a1
        bra.s cf_save_parse
cf_save_parse_new:
        movem.l d1-d7/a0-a6,-(sp)
        move.w d0,d3
        lea save_name,a0
        move.l SAVE_CONTEXT+SAVE_GENERATION,d0
        moveq #2,d2
        bsr cf_save_filename
        move.w d3,d1
        lea EDITOR_MANIFEST_BASE,a0
        move.l SAVE_CONTEXT+SAVE_RESULT_BYTES,d0
        lea save_name,a1
cf_save_parse:
        lea EDITOR_SERIAL_WORK_BASE,a2
        lea SAVE_PARSER_WORK,a3
        bsr cfmi_parse
        tst.w d0
        bne.s .return
        lea EDITOR_SERIAL_WORK_BASE,a0
        lea SAVE_CANDIDATE,a1
        move.w #CFMD_RECORD_BYTES,d0
        bsr cf_save_copy
        moveq #0,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

cf_save_validate_phase:
        movem.l d1-d7/a0-a6,-(sp)
        moveq #0,d1
        move.w SAVE_CANDIDATE+CFMD_SPT_BYTES,d1
        moveq #0,d0
        move.w SAVE_CANDIDATE+CFMD_MAP_BYTES,d0
        cmp.b SAVE_CONTEXT+SAVE_SELECTED,d6
        beq.s .current
        moveq #1,d5
        bsr.s cf_save_read_source
        bne.s .return
        lea EDITOR_READBACK_BASE,a0
        lea SAVE_SPT_SCRATCH,a1
        move.w SAVE_CANDIDATE+CFMD_SPT_BYTES,d0
        bsr cf_save_copy
        moveq #0,d5
        bsr.s cf_save_read_source
        bne.s .return
        lea EDITOR_READBACK_BASE,a0
        lea SAVE_SPT_SCRATCH,a1
        bra.s .validate
.current:
        lea map_file_buffer,a0
        lea EDITOR_SPT_BASE,a1
.validate:
        moveq #0,d0
        move.w SAVE_CANDIDATE+CFMD_MAP_BYTES,d0
        moveq #0,d1
        move.w SAVE_CANDIDATE+CFMD_SPT_BYTES,d1
        lea SAVE_CANDIDATE,a2
        lea EDITOR_SERIAL_WORK_BASE,a3
        lea EDITOR_SERIAL_WORK_BASE+CFVR_BYTES,a4
        bsr cf_payload_validate
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; D6=target phase, D5=0 MAP/1 SPT. Candidate contains target names/checksums.
cf_save_read_source:
        movem.l d1-d7/a0-a6,-(sp)
        lea save_read_context,a0
        move.l save_old_generation,d0
        lea SAVE_CONTEXT+SAVE_SOURCE_PHASES,a1
        moveq #0,d1
        move.b (a1,d6.w),d1
        move.w d5,d2
        bsr cf_save_filename
        bsr.s cf_save_dependency_values
        bsr cf_save_read_verified
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; D5 selects candidate length/CRC, returned in D0/D1; A0 is unchanged.
cf_save_dependency_values:
        moveq #0,d0
        tst.w d5
        bne.s .spt
        move.w SAVE_CANDIDATE+CFMD_MAP_BYTES,d0
        move.l SAVE_CANDIDATE+CFMD_MAP_CRC,d1
        rts
.spt:
        move.w SAVE_CANDIDATE+CFMD_SPT_BYTES,d0
        move.l SAVE_CANDIDATE+CFMD_SPT_CRC,d1
        rts

cf_save_write_payload:
        movem.l d1-d7/a0-a6,-(sp)
        cmp.b SAVE_CONTEXT+SAVE_SELECTED,d6
        beq.s .current
        bsr.s cf_save_read_source
        bne.s cf_save_write_return
        lea EDITOR_READBACK_BASE,a1
        bra.s .source
.current:
        lea map_file_buffer,a1
        tst.w d5
        beq.s .source
        lea EDITOR_SPT_BASE,a1
.source:
        lea SAVE_CANDIDATE+CFMD_MAP_NAME,a0
        tst.w d5
        beq.s .name
        lea SAVE_CANDIDATE+CFMD_SPT_NAME,a0
.name:
        move.w #SAVE_STAGE_PAYLOAD_WRITE,SAVE_CONTEXT+SAVE_STAGE
        bsr.s cf_save_dependency_values
        move.l d0,d1
cf_save_before_write:
        bsr cf_write_entry
        tst.w d0
        bne.s cf_save_write_return
        addq.w #1,SAVE_CONTEXT+SAVE_PROCESSED
        move.w #SAVE_STAGE_PAYLOAD_VERIFY,SAVE_CONTEXT+SAVE_STAGE
        bsr.s cf_save_dependency_values
        bsr.s cf_save_read_verified
        bne.s cf_save_write_return
        cmp.b SAVE_CONTEXT+SAVE_SELECTED,d6
        bne.s cf_save_write_return
        movea.l a1,a0
        lea EDITOR_READBACK_BASE,a1
        bsr cf_save_dependency_values
        bsr cf_save_compare
cf_save_write_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; A0=source filename, D0.l=exact length; manifest supplies its own body CRC.
cf_save_read_manifest:
        movem.l d1-d2,-(sp)
        moveq #0,d1
        moveq #0,d2
        bsr.s cf_save_read_file
        movem.l (sp)+,d1-d2
        tst.w d0
        rts
cf_save_read_verified:
        move.l d2,-(sp)
        moveq #STORAGE_READ_CHECK_CRC,d2
        bsr.s cf_save_read_file
        move.l (sp)+,d2
        tst.w d0
        rts
cf_save_read_file:
        movem.l d1-d7/a0-a6,-(sp)
        lea save_read_context,a1
        move.l d0,STORAGE_READ_EXPECTED_BYTES(a1)
        move.l d0,STORAGE_READ_CAPACITY(a1)
        move.l d1,STORAGE_READ_EXPECTED_CRC(a1)
        move.w d2,STORAGE_READ_FLAGS(a1)
        clr.w STORAGE_READ_RESERVED(a1)
        moveq #3,d3
.name:
        move.l (a0)+,(a1)+
        dbf d3,.name
        lea SAVE_CONTEXT+SAVE_DISK_ID,a0
        moveq #3,d3
.identity:
        move.l (a0)+,(a1)+
        dbf d3,.identity
        move.l SAVE_CONTEXT+SAVE_CANCEL,save_read_context+STORAGE_READ_CANCEL
        bsr cf_save_epoch
        bne.s .return
        lea save_read_context,a0
        bsr storage_read_entry
        tst.w d0
        bne.s .return
        bsr cf_save_epoch
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; A0=16-byte destination, D0.l=generation, D1.w=phase, D2.w=0/1/2 MAP/SPT/CMI.
cf_save_filename:
        movem.l d0-d4/a0-a1,-(sp)
        move.l d0,d3
        moveq #7,d4
.hex:
        rol.l #4,d3
        move.w d3,d0
        andi.w #15,d0
        bsr.s cf_save_hex_digit
        move.b d0,(a0)+
        dbf d4,.hex
        cmpi.w #2,d2
        beq.s .cmi
        move.b #'0',(a0)+
        move.w d1,d0
        bsr.s cf_save_hex_digit
        move.b d0,(a0)+
        tst.w d2
        bne.s .spt
        move.l #$2E6D6170,(a0)+
        bra.s .end
.spt:
        move.l #$2E737074,(a0)+
.end:
        clr.w (a0)
        bra.s .return
.cmi:
        move.l #$2E636D69,(a0)+
        clr.l (a0)
.return:
        movem.l (sp)+,d0-d4/a0-a1
        rts
cf_save_hex_digit:
        addi.b #'0',d0
        cmpi.b #'9',d0
        bls.s .return
        addq.b #7,d0
        addi.b #32,d0
.return:
        rts

cf_save_add_sectors:
        addi.l #509,d0
        divu.w #510,d0
        add.w d0,save_required_sectors
        rts
cf_save_copy:
        subq.w #1,d0
.copy:
        move.b (a0)+,(a1)+
        dbf d0,.copy
        rts
cf_save_compare:
        subq.w #1,d0
.compare:
        cmpm.b (a0)+,(a1)+
        bne.s .bad
        dbf d0,.compare
        moveq #0,d0
        rts
.bad:
        moveq #STORAGE_READ_VERIFY,d0
        rts

        include "read.s"
        include "manifest.s"
        include "payload.s"
        include "encode.s"
        include "write.s"
        include "preflight.s"
        include "guarded_delete.s"
        include "cleanup.s"
cf_save_end:
        ifgt cf_save_end-cf_save_start-EDITOR_SERIALIZER_BYTES
        fail "Save module exceeds serializer code budget"
        endif
        ifgt save_id_directory+4800-EDITOR_READBACK_BASE-EDITOR_READBACK_BYTES
        fail "Save identity scan exceeds readback"
        endif
