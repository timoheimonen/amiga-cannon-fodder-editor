; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        include "layout.i"
        include "module.i"
        include "session.i"
        include "fodders.i"
        include "metadata.i"
        include "payload.i"
        include "storage_read.i"
        include "storage.i"
        include "save.i"
        include "authoring.i"
        include "ui.i"
        include "dialog.i"
OPEN_TEST_SELECTED equ 1
TEST_RELOAD_UI equ 1
TEST_SAVED_TAIL equ SAVE_CONTEXT
TEST_TITLE equ OPEN_STAGE_METADATA+CFMD_RECORD_BYTES
TEST_PHASE_TITLE equ TEST_TITLE+64
        section .text,code
        xdef test_start,test_entry,test_end,test_owner,test_stage_pin
        xdef test_before_stage,test_before_publish,test_publish_play
        xdef test_publish_editor,test_prepare_roster,test_success
; Fixed load-base anchor: X+PCREL(pc) reads the absolute address X
; PC-relatively from module code.
module_pc_base:
PCREL   equ module_pc_base-EDITOR_MODULE_BASE
test_start:
        dc.l MODULE_MAGIC
        dc.w MODULE_ABI,MODULE_HEADER_BYTES
        dc.l TEST_MODULE_ID,EDITOR_MODULE_BASE
        dc.l test_end-test_start,test_entry-test_start,0,0

; Start accepts only a once-consumed verified SAVE continuation. Return keeps
; mode1 until a fresh exact-generation read reconstructs every authored owner.
; Both paths return normally; only permanent code may enter native gameplay.
test_entry:
        movem.l d1-d7/a0-a6,-(sp)
        move.w #REQ_ACTION_UNENTERED,EDITOR_SESSION_BASE+REQ_ACTION
        cmpi.w #MODULE_ABI,d0
        bne test_bad_entry
        cmpa.l #EDITOR_SESSION_BASE,a0
        bne test_bad_entry
        bsr test_owner
        bne test_return
        clr.w EDITOR_SESSION_BASE+REQ_ACTION
        cmpi.w #1,session_custom_mode
        bne.s test_initialize
        ; Capture the outcome exactly once before fallible disk work. No native
        ; completion accounting, phase progression or recruitment is invoked.
        cmpi.b #E7_TEST_PLAY,E7_STAGE
        bne.s test_stage
        bsr test_success
        move.b d1,E7_LOCATION
        move.b #E7_TEST_RELOAD,E7_STAGE
        bra.s test_stage
test_initialize:
        lea E7_CONTEXT,a0
        cmpi.l #E7_TAG,(a0)
        beq.s .existing
        clr.b 5(a0)
        move.l #E7_TAG,(a0)
.existing:
        move.b AUR_BASE+AUR_SELECTED,6(a0)
        clr.b 7(a0)
        clr.l 8(a0)
        clr.l 12(a0)
test_stage:
        moveq #STORAGE_READ_INVALID,d0
        tst.w AUR_BASE+AUR_DRIVE
        bne test_failed
        clr.l STORAGE_CONTEXT+STORAGE_READ_CANCEL
        lea STORAGE_CONTEXT,a0
        bsr storage_inspect_disk
        bne test_failed
        lea STORAGE_CONTEXT,a0
        moveq #STORAGE_READ_CONTEXT_BYTES/4-1,d0
.clear:
        clr.l (a0)+
        dbf d0,.clear
        lea AUR_BASE+AUR_SOURCE_NAME,a0
        lea STORAGE_CONTEXT,a1
        moveq #3,d0
.name:
        move.l (a0)+,(a1)+
        dbf d0,.name
        lea AUR_BASE+AUR_DISK_ID,a0
        moveq #3,d0
.id:
        move.l (a0)+,(a1)+
        dbf d0,.id
        moveq #0,d0
        move.b AUR_BASE+AUR_SELECTED,d0
        lea STORAGE_CONTEXT,a0
test_before_stage:
        bsr open_stage
        bne test_failed
        tst.l OPEN_STAGE_RESULT+CFVR_ERRORS
        bne test_gameplay_error
        cmpi.w #1,session_custom_mode
        beq test_restore_editor
        ; Source data is a staged copy. All fallible checks precede canonical
        ; publication and the fresh-scenario reset; the campaign snapshot is
        ; never captured again. REVIEW diagnostics do not block this phase.
        bsr test_match_canonical
        bne test_failed
        bsr test_project_titles
        bne test_failed
        bsr test_initial_preflight
        bne test_failed
        bsr test_owner
        bne test_failed
test_before_publish:
        move.w sr,-(sp)
        ori.w #$0700,sr
        lea EDITOR_METADATA_BASE+256,a0
        lea TEST_SAVED_TAIL,a1
        moveq #31,d0
.save_tail:
        move.l (a0)+,(a1)+
        dbf d0,.save_tail
        bsr test_copy_payload
        bsr test_prepare_roster
        clr.l SESSION_CHECKPOINT_VALID
        clr.l session_outcome_sr
        clr.l session_outcome_success
        clr.b E7_LOCATION
        move.b #E7_TEST_PLAY,E7_STAGE
        move.w #REQ_PURPOSE_TEST,EDITOR_SESSION_BASE+REQ_PURPOSE
        move.w #1,session_custom_mode
test_publish_play:
        move.w #REQ_ACTION_PREPARE,EDITOR_SESSION_BASE+REQ_ACTION
        move.w (sp)+,sr
        moveq #0,d0
        bra test_return

test_restore_editor:
        bsr test_owner
        bne test_failed
        move.w sr,-(sp)
        ori.w #$0700,sr
        bsr test_copy_payload
        lea TEST_SAVED_TAIL,a0
        lea EDITOR_METADATA_BASE+256,a1
        moveq #31,d0
.restore_tail:
        move.l (a0)+,(a1)+
        dbf d0,.restore_tail
        lea EDITOR_UNDO_BASE,a0
        move.w #(EDITOR_UNDO_BYTES+EDITOR_MANIFEST_BYTES)/4-1,d0
.clear_bank:
        clr.l (a0)+
        dbf d0,.clear_bank
        lea OPEN_STAGE_MANIFEST,a0
        lea EDITOR_MANIFEST_BASE,a1
        moveq #0,d0
        move.w EDITOR_METADATA_BASE+CFMD_MANIFEST_BYTES,d0
        bsr os_copy
        clr.l AUR_BASE+AUR_UNDO_NEXT
        move.w #AUR_ASSETS_INCOMPLETE,AUR_BASE+AUR_ASSET_STATE
        clr.l STORAGE_READY
        clr.l SESSION_CHECKPOINT_VALID
        tst.b E7_LOCATION
        beq.s .not_won
        moveq #0,d0
        move.b E7_PHASE,d0
        bset d0,E7_TESTED
.not_won:
        move.b #E7_TEST_RETURNED,E7_STAGE
        move.w #SESSION_EVENT_HILL,session_event
        move.w #REQ_PURPOSE_EDITOR,EDITOR_SESSION_BASE+REQ_PURPOSE
        move.w #2,session_custom_mode
test_publish_editor:
        move.w (sp)+,sr
        moveq #1,d0
        bra.s test_editor_reply

test_gameplay_error:
        moveq #TEST_ERROR_GAMEPLAY,d0
        bra.s test_failed
test_media_error:
        moveq #STORAGE_READ_MEDIA,d0
test_failed:
        cmpi.w #2,session_custom_mode
        beq.s .editable
        ; The failed staged data is disposable. Release the modal before
        ; retrying disk I/O, keeping mode1 and the captured outcome unchanged.
        move.w d0,d1
        moveq #1,d0
        bsr controller_result_ui
        cmpi.w #1,d0
        beq test_stage
        clr.w EDITOR_SESSION_BASE+REQ_ACTION
        moveq #0,d0
        bra.s test_return
.editable:
        cmpi.w #TEST_ERROR_CAPACITY,d0
        beq.s .reply
        cmpi.w #TEST_ERROR_GAMEPLAY,d0
        beq.s .reply
        cmpi.w #TEST_ERROR_TITLE,d0
        beq.s .reply
        moveq #-125,d0
.reply:
        clr.b E7_STAGE
test_editor_reply:
        move.w d0,EDITOR_SESSION_BASE+REQ_LAST_RESULT
        move.l #TEST_MODULE_ID,EDITOR_SESSION_BASE+REQ_RESULT_ID
        lea test_editor_request(pc),a0
        lea EDITOR_SESSION_BASE+REQ_NAME,a1
        moveq #5,d0
.request:
        move.l (a0)+,(a1)+
        dbf d0,.request
        move.w #REQ_ACTION_DISPATCH,EDITOR_SESSION_BASE+REQ_ACTION
        moveq #0,d0
        bra.s test_return
test_bad_entry:
        moveq #TEST_ERROR_STATE,d0
test_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; The pointer-free AUR survives battle. Its mode1 guard intentionally never
; validates damaged live MAP/SPT or the evicted manifest/history bank.
test_owner:
        moveq #TEST_ERROR_STATE,d0
        tst.w native_gameplay_active
        bne .return
        cmpi.w #SESSION_SNAPSHOT_TAG,SESSION_SNAPSHOT_VALID
        bne .return
        move.w sr,d1
        andi.w #$0700,d1
        bne .return
        cmpi.l #AUR_MAGIC,AUR_BASE
        bne .return
        cmpi.w #AUR_VERSION,AUR_BASE+4
        bne .return
        cmpi.w #AUR_HAS_SOURCE|AUR_PAGE_PENDING,AUR_BASE+AUR_FLAGS
        bne .return
        tst.w AUR_BASE+AUR_DRIVE
        bne .return
        tst.l AUR_BASE+AUR_TRANSPORT_STATUS
        bne .return
        tst.l AUR_BASE+AUR_TRANSPORT_ID+2
        bne .return
        tst.w AUR_BASE+AUR_EXIT_REQUEST
        bne .return
        cmpi.l #AUR_PAGE_TEST*$10000+AUR_PAGE_NONE,AUR_BASE+AUR_PAGE_KIND
        bne .return
        tst.w AUR_BASE+AUR_ASSET_STATE
        bne .return
        moveq #0,d1
        move.b AUR_BASE+AUR_PHASE_COUNT,d1
        beq .return
        cmpi.w #6,d1
        bhi .return
        moveq #0,d2
        move.b AUR_BASE+AUR_SELECTED,d2
        cmp.w d1,d2
        bhs .return
        lea AUR_BASE+AUR_PHASE_MAP,a0
        moveq #0,d2
.mapping:
        moveq #-1,d3
        cmp.w d1,d2
        bhs.s .expected
        move.w d2,d3
.expected:
        cmp.b (a0)+,d3
        bne .return
        addq.w #1,d2
        cmpi.w #6,d2
        blo.s .mapping
        tst.l AUR_BASE+AUR_SOURCE_BYTES
        beq .return
        cmpi.l #4096,AUR_BASE+AUR_SOURCE_BYTES
        bhi .return
        cmpi.w #2,session_custom_mode
        bne .playing
        cmpi.w #SESSION_EVENT_HILL,session_event
        bne .return
        cmpi.w #REQ_PURPOSE_EDITOR,EDITOR_SESSION_BASE+REQ_PURPOSE
        bne .return
        cmpi.b #E7_TEST_READY,E7_STAGE
        bne .return
        tst.l EDITOR_SESSION_BASE+REQ_RESULT_ID
        bne .return
        tst.w EDITOR_SESSION_BASE+REQ_LAST_RESULT
        bne .return
        cmpi.l #SAVE_MAGIC,SAVE_CONTEXT
        bne .return
        cmpi.l #1,SAVE_CONTEXT+SAVE_READY
        bne .return
        tst.w SAVE_CONTEXT+SAVE_STATUS
        bne .return
        move.l SAVE_CONTEXT+SAVE_TARGET_ID,d1
        cmp.l AUR_BASE+AUR_SOURCE_ID,d1
        bne .return
        move.l SAVE_CONTEXT+SAVE_RESULT_BYTES,d1
        cmp.l AUR_BASE+AUR_SOURCE_BYTES,d1
        bne .return
        move.l SAVE_CONTEXT+SAVE_RESULT_BODY_CRC,d1
        cmp.l AUR_BASE+AUR_SOURCE_CRC,d1
        bne .return
        tst.l E7_CONTEXT
        beq.s .new_record
        cmpi.l #E7_TAG,E7_CONTEXT
        bne .return
        cmpi.b #63,E7_TESTED
        bhi.s .return
.new_record:
        tst.w native_fifth_plane
        bne.s .return
        bra.s .ok
.playing:
        cmpi.l #$4354524C,EDITOR_SESSION_BASE+REQ_RESULT_ID
        bne.s .return
        tst.w EDITOR_SESSION_BASE+REQ_LAST_RESULT
        bne.s .return
        cmpi.l #E7_TAG,E7_CONTEXT
        bne.s .return
        cmpi.b #63,E7_TESTED
        bhi.s .return
        tst.w E7_RESERVED
        bne.s .return
        move.b AUR_BASE+AUR_SELECTED,d1
        cmp.b E7_PHASE,d1
        bne.s .return
        cmpi.w #1,session_custom_mode
        bne.s .return
        cmpi.w #SESSION_EVENT_OUTCOME,session_event
        bne.s .return
        cmpi.w #REQ_PURPOSE_TEST,EDITOR_SESSION_BASE+REQ_PURPOSE
        bne.s .return
        move.b E7_STAGE,d1
        subi.b #E7_TEST_PLAY,d1
        cmpi.b #E7_TEST_RELOAD-E7_TEST_PLAY,d1
        bhi.s .return
.ok:
        moveq #0,d0
.return:
        tst.w d0
        rts

; Called immediately after CFMI parse, before any referenced payload is read.
; The schema parser checked all six descriptors; only the selected gameplay
; payload is inspected, so another phase's ERROR cannot block this test.
test_stage_pin:
        moveq #TEST_ERROR_SOURCE,d0
        move.l AUR_BASE+AUR_SOURCE_BYTES,d1
        cmp.l OS_LENGTH(a6),d1
        bne.s .return
        move.l AUR_BASE+AUR_SOURCE_CRC,d1
        cmp.l OPEN_STAGE_METADATA+CFMD_MANIFEST_CRC,d1
        bne.s .return
        move.l AUR_BASE+AUR_SOURCE_ID,d1
        cmp.l OPEN_STAGE_METADATA+CFMD_ID,d1
        bne.s .return
        move.w AUR_BASE+AUR_SOURCE_REVISION,d1
        cmp.w OPEN_STAGE_METADATA+CFMD_REVISION,d1
        bne.s .return
        move.b AUR_BASE+AUR_PHASE_COUNT,d1
        cmp.b OPEN_STAGE_METADATA+CFMD_PHASE_COUNT,d1
        bne.s .return
        move.b E7_PHASE,d1
        cmp.b OPEN_STAGE_METADATA+CFMD_PHASE_INDEX,d1
        bne.s .return
        moveq #0,d0
.return:
        tst.w d0
        rts

; Require the saved draft still equals the source that TEST will consume.
test_match_canonical:
        lea EDITOR_METADATA_BASE,a0
        lea OPEN_STAGE_METADATA,a1
        moveq #63,d1
        moveq #TEST_ERROR_SOURCE,d0
.metadata:
        cmpm.l (a0)+,(a1)+
        bne.s .return
        dbf d1,.metadata
        lea map_file_buffer,a0
        moveq #0,d1
        move.w OPEN_STAGE_METADATA+CFMD_MAP_BYTES,d1
        bsr read_crc32
        cmp.l OPEN_STAGE_METADATA+CFMD_MAP_CRC,d0
        bne.s .bad
        lea EDITOR_SPT_BASE,a0
        moveq #0,d1
        move.w OPEN_STAGE_METADATA+CFMD_SPT_BYTES,d1
        bsr read_crc32
        cmp.l OPEN_STAGE_METADATA+CFMD_SPT_CRC,d0
        bne.s .bad
        moveq #0,d0
        rts
.bad:
        moveq #TEST_ERROR_SOURCE,d0
.return:
        tst.w d0
        rts

test_project_titles:
        lea OPEN_STAGE_METADATA+CFMD_TITLE,a0
        lea TEST_TITLE,a1
        bsr.s test_project_one
        bne.s .return
        lea OPEN_STAGE_METADATA+CFMD_PHASE_TITLE,a0
        lea TEST_PHASE_TITLE,a1
        bsr.s test_project_one
.return:
        rts
test_project_one:
        movea.l a0,a2
        moveq #0,d0
.length:
        cmpi.b #$FF,(a2)+
        beq.s .project
        addq.w #1,d0
        cmpi.w #64,d0
        blo.s .length
        moveq #TEST_ERROR_TITLE,d0
        rts
.project:
        moveq #1,d1
        move.w #320,d2
        moveq #1,d3
        bsr text_preflight
        tst.w d0
        beq.s .return
        moveq #TEST_ERROR_TITLE,d0
.return:
        rts

; Source CRC equality has established canonical SPT. The existing native
; allocation preflight checks a temporary empty roster and fresh counters.
test_initial_preflight:
        lea EDITOR_SERIAL_WORK_BASE+STORAGE_READ_WORK_BYTES,a2
        movea.l a2,a0
        moveq #23,d1
.empty:
        move.l #-1,(a0)+
        dbf d1,.empty
        move.w OPEN_STAGE_METADATA+CFMD_RECRUITS,d4
        moveq #0,d5
        moveq #0,d2
        moveq #0,d3
        bsr cp_preflight
        tst.w d0
        beq.s .return
        moveq #TEST_ERROR_CAPACITY,d0
.return:
        rts

; Only called inside the final IRQ-excluded transaction, after all preflights.
test_copy_payload:
        lea OPEN_STAGE_MAP,a0
        lea map_file_buffer,a1
        moveq #0,d0
        move.w OPEN_STAGE_METADATA+CFMD_MAP_BYTES,d0
        bsr os_copy
        lea OPEN_STAGE_SPT,a0
        lea EDITOR_SPT_BASE,a1
        move.w #EDITOR_SPT_BYTES,d0
        bsr os_copy
        lea OPEN_STAGE_METADATA,a0
        lea EDITOR_METADATA_BASE,a1
        move.w #EDITOR_METADATA_BYTES,d0
        bra os_copy

test_prepare_roster:
        lea campaign_payload,a0
        move.w #(EDITOR_SNAPSHOT_BYTES-24)/4-1,d0
.clear:
        clr.l (a0)+
        dbf d0,.clear
        jsr native_roster_init
        jsr native_score_init
        move.l #native_dead_ranks,native_dead_rank_end
        move.l #native_dead_ranks,native_dead_rank_cursor
        move.w #-1,native_dead_ranks
        move.l #native_dead_names,native_dead_name_end
        move.w #-1,native_dead_names
        move.w #1,native_mission_number
        move.w EDITOR_METADATA_BASE+CFMD_RECRUITS,native_recruits_remaining
        moveq #0,d1
        move.b EDITOR_METADATA_BASE+CFMD_PHASE_COUNT,d1
        move.w d1,native_phase_count
        moveq #0,d2
        move.b EDITOR_METADATA_BASE+CFMD_PHASE_INDEX,d2
        move.w d2,native_phase_number
        sub.w d2,d1
        move.w d1,native_phases_remaining
        rts

test_success:
        moveq #0,d1
        btst #2,session_outcome_sr+1
        beq.s .return
        tst.w session_outcome_no_squad
        bne.s .return
        tst.w session_outcome_failure
        bne.s .return
        tst.w session_outcome_success
        beq.s .return
        moveq #1,d1
.return:
        rts
        even
test_editor_request:
        dc.b "cf_editor.mod",0,0,0
        dc.l $45445452,EDITOR_SERIALIZER_BYTES
        include "../open/stage.s"
        include "../controller/text.s"
        include "../controller/checkpoint.s"
        include "../controller/result_ui.s"
        include "../dialog/dialog.s"
        include "../dialog/text.s"
        include "../storage/read.s"
        include "../storage/manifest.s"
        include "../storage/payload.s"
test_end:
        ifgt test_end-test_start-(EDITOR_SERIALIZER_BYTES-OPEN_RESERVED_BYTES)
        fail "Test code overlaps reserved authored generation"
        endif
