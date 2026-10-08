; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Called immediately after SAVE publishes READY, before its held guard returns.
; Private SAVE fields below are dead SAVE temporaries after successful commit.
cf_cleanup_last_attempted equ SAVE_CONTEXT+98
cf_cleanup_last_verified equ SAVE_CONTEXT+100
cf_cleanup_directory_crc equ SAVE_CONTEXT+104
cf_cleanup_previous_count equ SAVE_CONTEXT+108
cf_cleanup_index equ SAVE_CONTEXT+110
cf_cleanup_input_bytes equ SAVE_CONTEXT+112
cf_cleanup_canonical_bytes equ SAVE_CONTEXT+118
cf_cleanup_phase_count equ SAVE_CONTEXT+120
cf_cleanup_phase equ SAVE_CONTEXT+122
cf_cleanup_removed equ SAVE_CONTEXT+124
cf_cleanup_new_pass equ SAVE_CONTEXT+126
cf_cleanup_name equ SAVE_ENCODER_STATE

        xdef cf_cleanup_entry,cf_cleanup_before_erase,cf_cleanup_end
; D0=cleanup status only. SAVE READY/status/results and authored bytes unchanged.
; D1-D7/A0-A6/SP preserved. Success can leave incomplete generations untouched.
cf_cleanup_entry:
        movem.l d1-d7/a0-a6,-(sp)
        moveq #10,d0
        cmpi.l #1,SAVE_CONTEXT+SAVE_READY
        bne cf_cleanup_return
        tst.w SAVE_CONTEXT+SAVE_STATUS
        bne cf_cleanup_return
        tst.w save_guard_installed
        beq cf_cleanup_return
        move.l SAVE_CONTEXT+SAVE_TARGET_ID,d1
        cmp.l EDITOR_METADATA_BASE+CFMD_ID,d1
        bne cf_cleanup_return
        move.l SAVE_CONTEXT+SAVE_GENERATION,d1
        cmp.l EDITOR_METADATA_BASE+CFMD_GENERATION,d1
        bne cf_cleanup_return
        bsr cf_delete_lifecycle
        bne cf_cleanup_return
        move.w #151,cf_cleanup_previous_count
        clr.w cf_cleanup_index
        clr.w cf_cleanup_removed
        move.w #1,cf_cleanup_new_pass
cf_cleanup_scan:
; A fresh preflight inspection also rebuilds the directory cache.
; Its token chooser must never change the already committed SAVE generation.
        move.l SAVE_CONTEXT+SAVE_GENERATION,-(sp)
        lea SAVE_CONTEXT,a0
        bsr cf_preflight_entry
        move.l (sp)+,SAVE_CONTEXT+SAVE_GENERATION
        tst.w d0
        bne cf_cleanup_return
        move.w SAVE_PREFLIGHT_RESULT+SAVE_LIVE_RECORDS,d1
        move.l SAVE_PREFLIGHT_RESULT+SAVE_DIRECTORY_CRC,d2
        tst.w cf_cleanup_new_pass
        beq.s cf_cleanup_same_pass
        cmp.w cf_cleanup_previous_count,d1
        bhs cf_cleanup_corrupt
        move.w d1,cf_cleanup_previous_count
        move.l d2,cf_cleanup_directory_crc
        clr.w cf_cleanup_new_pass
        bra.s cf_cleanup_select
cf_cleanup_same_pass:
        cmp.w cf_cleanup_previous_count,d1
        bne cf_cleanup_corrupt
        cmp.l cf_cleanup_directory_crc,d2
        bne cf_cleanup_corrupt
cf_cleanup_select:
        bsr cf_save_epoch
        bne cf_cleanup_return
        move.w cf_cleanup_previous_count,d1
        moveq #0,d2
        move.w cf_cleanup_index,d2
        cmp.w d1,d2
        bhs cf_cleanup_success
        addq.w #1,cf_cleanup_index
        lsl.w #5,d2
        lea EDITOR_READBACK_BASE+32,a0
        adda.w d2,a0
        move.l 28(a0),d3
        lea cf_cleanup_name,a1
        moveq #16,d0
        bsr cf_save_copy
        lea cf_cleanup_name,a0
        movea.l a0,a1
        moveq #15,d1
cf_cleanup_fold:
        move.b (a1),d0
        cmpi.b #'A',d0
        blo.s cf_cleanup_fold_next
        cmpi.b #'Z',d0
        bhi.s cf_cleanup_fold_next
        ori.b #32,(a1)
cf_cleanup_fold_next:
        addq.l #1,a1
        dbf d1,cf_cleanup_fold
        cmpi.l #$2E636D69,8(a0)
        bne.s cf_cleanup_select
        tst.b 12(a0)
        bne.s cf_cleanup_select
        bsr read_valid_target
        bne.s cf_cleanup_select
        move.l d3,d0
        cmpi.l #17,d0
        blo.s cf_cleanup_select
        cmpi.l #4096,d0
        bhi cf_cleanup_select
        move.l d0,cf_cleanup_input_bytes
        bsr cf_save_read_manifest
        tst.w d0
        bne cf_cleanup_read_failure
        moveq #0,d0
        bsr cf_cleanup_parse_input
        bne cf_cleanup_scan
        move.l SAVE_CANDIDATE+CFMD_ID,d0
        cmp.l SAVE_CONTEXT+SAVE_TARGET_ID,d0
        bne cf_cleanup_scan
        move.l SAVE_CANDIDATE+CFMD_GENERATION,d0
        cmp.l SAVE_CONTEXT+SAVE_GENERATION,d0
        beq cf_cleanup_scan
        moveq #0,d0
        move.b SAVE_CANDIDATE+CFMD_PHASE_COUNT,d0
        move.w d0,cf_cleanup_phase_count
        bsr cf_cleanup_canonicalize
        bne cf_cleanup_return
        clr.w cf_cleanup_phase
cf_cleanup_validate:
        move.w cf_cleanup_phase,d0
        bsr cf_cleanup_parse_canonical
        bne cf_cleanup_corrupt
        moveq #1,d5
        bsr cf_cleanup_read_payload
        bne cf_cleanup_read_failure
        lea EDITOR_READBACK_BASE,a0
        lea SAVE_SPT_SCRATCH,a1
        move.w SAVE_CANDIDATE+CFMD_SPT_BYTES,d0
        bsr cf_save_copy
        moveq #0,d5
        bsr cf_cleanup_read_payload
        bne cf_cleanup_read_failure
        lea EDITOR_READBACK_BASE,a0
        lea SAVE_SPT_SCRATCH,a1
        moveq #0,d0
        move.w SAVE_CANDIDATE+CFMD_MAP_BYTES,d0
        moveq #0,d1
        move.w SAVE_CANDIDATE+CFMD_SPT_BYTES,d1
        lea SAVE_CANDIDATE,a2
        lea EDITOR_SERIAL_WORK_BASE,a3
        lea EDITOR_SERIAL_WORK_BASE+CFVR_BYTES,a4
        bsr cf_payload_validate
        tst.w d0
        bne cf_cleanup_scan
        addq.w #1,cf_cleanup_phase
        move.w cf_cleanup_phase,d0
        cmp.w cf_cleanup_phase_count,d0
        blo cf_cleanup_validate
; No erase has occurred until every old phase passed CRC and structure checks.
; Remove its manifest first; an interruption leaves only explicit-recovery
; orphan files, never a visible manifest with dependencies deleted by cleanup.
cf_cleanup_before_erase:
        lea cf_cleanup_name,a0
        bsr cf_cleanup_delete
        tst.w d0
        bne.s cf_cleanup_return
        clr.w cf_cleanup_phase
cf_cleanup_erase_phase:
        move.w cf_cleanup_phase,d0
        bsr cf_cleanup_parse_canonical
        bne.s cf_cleanup_corrupt
        lea SAVE_CANDIDATE+CFMD_MAP_NAME,a0
        bsr cf_cleanup_delete
        tst.w d0
        bne.s cf_cleanup_return
        lea SAVE_CANDIDATE+CFMD_SPT_NAME,a0
        bsr cf_cleanup_delete
        tst.w d0
        bne.s cf_cleanup_return
        addq.w #1,cf_cleanup_phase
        move.w cf_cleanup_phase,d0
        cmp.w cf_cleanup_phase_count,d0
        blo.s cf_cleanup_erase_phase
        clr.w cf_cleanup_index
        move.w #1,cf_cleanup_new_pass
        bra cf_cleanup_scan
cf_cleanup_read_failure:
; Missing or invalid package bytes make this generation ineligible. Other
; file service failures stop cleanup; directory corruption stops earlier.
        cmpi.w #3,d0
        beq cf_cleanup_scan
        cmpi.w #STORAGE_READ_VERIFY,d0
        beq cf_cleanup_scan
        cmpi.w #STORAGE_READ_SIZE,d0
        beq cf_cleanup_scan
        bra.s cf_cleanup_return
cf_cleanup_corrupt:
        moveq #STORAGE_READ_CORRUPT,d0
        bra.s cf_cleanup_return
cf_cleanup_success:
        moveq #0,d0
cf_cleanup_return:
        move.w d0,SAVE_CONTEXT+SAVE_CLEANUP_STATUS
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

cf_cleanup_canonicalize:
        movem.l d1-d7/a0-a6,-(sp)
        lea SAVE_CANDIDATE,a0
        lea EDITOR_MANIFEST_BASE,a1
        move.l #SAVE_OUTPUT_CAPACITY,d0
        lea SAVE_ENCODER_STATE,a2
        bsr cf_encode_begin
        tst.w d0
        bne.s .return
        moveq #0,d6
.phase:
        move.w d6,d0
        bsr.s cf_cleanup_parse_input
        bne.s .return
        lea SAVE_CANDIDATE,a0
        lea SAVE_ENCODER_STATE,a2
        bsr cf_encode_phase
        tst.w d0
        bne.s .return
        addq.w #1,d6
        cmp.w cf_cleanup_phase_count,d6
        blo.s .phase
        bsr cf_encode_finish
        tst.w d0
        bne.s .return
        move.w SAVE_ENCODER_STATE+CFE_BYTES+2,cf_cleanup_canonical_bytes
        lea save_read_context,a0
        lea cf_cleanup_name,a1
        moveq #16,d0
        bsr cf_save_copy
        moveq #0,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

cf_cleanup_parse_input:
        movem.l d1-d7/a0-a6,-(sp)
        move.w d0,d1
        lea EDITOR_READBACK_BASE,a0
        move.l cf_cleanup_input_bytes,d0
        lea save_read_context,a1
        bra.s cf_cleanup_parse
cf_cleanup_parse_canonical:
        movem.l d1-d7/a0-a6,-(sp)
        move.w d0,d1
        lea EDITOR_MANIFEST_BASE,a0
        moveq #0,d0
        move.w cf_cleanup_canonical_bytes,d0
        lea cf_cleanup_name,a1
cf_cleanup_parse:
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

cf_cleanup_read_payload:
        movem.l d1-d7/a0-a6,-(sp)
        lea SAVE_CANDIDATE+CFMD_MAP_NAME,a0
        tst.w d5
        beq.s .map
        lea SAVE_CANDIDATE+CFMD_SPT_NAME,a0
.map:
        bsr cf_save_dependency_values
        bsr cf_save_read_verified
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
cf_cleanup_delete:
        bsr cf_delete_guarded
        tst.w cf_delete_verified
        beq.s .return
        addq.w #1,cf_cleanup_removed
.return:
        tst.w d0
        rts
cf_cleanup_end:
