; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; EDTR authoring overlay: draft admission, viewport, tools and service requests.
; Requires the resident/CTRL mode 2 handoff and SPT construction bypass.
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
        include "authoring_recovery.i"
        include "state.i"
        include "dialog.i"
STORAGE_INSPECT_ONLY equ 1
PAYLOAD_STRUCTURAL_ONLY equ 1
AUR_INCOMPLETE_RECOVERY equ 1
AUR_OBJECT_PAGES equ 1
AUR_PHASE_PAGES equ 1
AUR_PHASE_CONTINUATIONS equ 1

AUR_VALIDATION_PAGE equ 1
AUR_TEST_PAGE equ 1
AUR_PHASE_ADDITIONS equ 1
        section .text,code
        xdef editor_start,editor_entry,editor_end
        xdef edtr_new_validate,edtr_before_assets,edtr_after_assets
        xdef edtr_view_idle,edtr_before_return,edtr_validate
        xdef edtr_request_save,edtr_receive,edtr_recovery_blocked
        xdef edtr_save_refused
        xdef edtr_decline_or_invariant,edtr_initial_failure
        xdef edtr_restore_camera,edtr_capture_camera
        xdef edtr_menu,edtr_discard,edtr_close_released
        xdef edtr_finish_receipt,edtr_exit_publish,edtr_assets_cleanup,edtr_menu_released
; Fixed load-base anchor: X+PCREL(pc) reads the absolute address X
; PC-relatively from module code.
module_pc_base:
PCREL   equ module_pc_base-EDITOR_MODULE_BASE
editor_start:
        dc.l MODULE_MAGIC
        dc.w MODULE_ABI,MODULE_HEADER_BYTES
        dc.l EDTR_MODULE_ID,EDITOR_MODULE_BASE
        dc.l editor_end-editor_start
        dc.l editor_entry-editor_start
        dc.l 0,0

; Canonical MAP/SPT/CFMD remain the only authored objects. Neither New nor
; any viewport scratch is touched until the Custom directory CFDI qualifies.
editor_entry:
        movem.l d1-d7/a0-a6,-(sp)
        cmpi.w #MODULE_ABI,d0
        bne edtr_bad_entry
        cmpa.l #EDITOR_SESSION_BASE,a0
        bne edtr_bad_entry
        bsr aur_owner
        bne edtr_decline_or_invariant
        ; Decline qualification so the permanent loop can try another EDTR.
        ; Its live-AUR recovery path, not this evictable frame, retains draft.
        move.w #-1,EDITOR_SESSION_BASE+REQ_ACTION
        clr.l STORAGE_CONTEXT+STORAGE_READ_CANCEL
        bsr edtr_epoch
        bne edtr_return
        ; A returning editor was just loaded by the transport, which checked the
        ; Custom marker; only the first entry lists Custom again.
        cmpi.l #AUR_MAGIC,AUR_BASE
        beq.s .qualified
        lea STORAGE_CONTEXT+PCREL(pc),a0
        bsr storage_inspect_disk
        tst.w d0
        bne edtr_return
        bsr edtr_epoch
        bne edtr_return
.qualified:
        clr.w edtr_view_live
        clr.w edtr_notice
        cmpi.l #AUR_MAGIC,AUR_BASE
        beq edtr_resume
        bsr edtr_owner
        bne edtr_recovery_blocked
        cmpi.w #EDTR_NEW,EDTR_OPERATION
        bne.s edtr_open_validate
edtr_new_validate:
        ; CTRL staged New after campaign capture; an import receipt is invalid.
        tst.l STORAGE_READY
        bne edtr_initial_failure
        bra.s edtr_payload_validate
edtr_open_validate:
        cmpi.l #1,STORAGE_READY
        bne edtr_initial_failure
        tst.w STORAGE_STATUS
        bne edtr_initial_failure
edtr_payload_validate:
        bsr edtr_validate
        bne edtr_return
        bsr edtr_load_assets
        bne edtr_return
        ; The resident mode 2 SPT path must have returned without
        ; constructing objects, even when a structural draft has errors.
        bsr edtr_owner
        bne edtr_recovery_blocked
        ; BRW1 remains authoritative until all fallible asset setup completed.
        bsr aur_initialize
        bne edtr_recovery_blocked
        cmpi.w #EDTR_NEW,EDTR_OPERATION
        bne edtr_acquire_view
        move.w map_file_buffer+84,d1
        subi.w #19,d1
        lsr.w #1,d1
        move.w d1,AUR_BASE+AUR_CAMERA_X
        move.w map_file_buffer+86,d1
        subi.w #12,d1
        lsr.w #1,d1
        move.w d1,AUR_BASE+AUR_CAMERA_Y
        bra edtr_acquire_view
edtr_resume:
        ; Preserve proof that a successful close came from an entered SAVE,
        ; not a successful EDTR transport or a no-pending reentry.
        moveq #0,d5
        btst #2,AUR_BASE+AUR_FLAGS+1+PCREL(pc)
        beq.s .receive
        cmpi.l #SAVE_MODULE_ID,EDITOR_SESSION_BASE+REQ_RESULT_ID
        bne.s .receive
        cmpi.l #1,SAVE_CONTEXT+SAVE_READY
        bne.s .receive
        tst.w SAVE_CONTEXT+SAVE_STATUS
        bne.s .receive
        moveq #1,d5
.receive:
        bsr edtr_receive
        bne edtr_recovery_blocked
        move.w d0,d7
        ; A legitimate entered service failure consumes pending too. An
        ; inconsistent receipt leaves it set and may not regain a live view.
        bsr aur_validate
        bne edtr_recovery_blocked
        move.w AUR_BASE+AUR_FLAGS+PCREL(pc),d1
        andi.w #AUR_SAVE_PENDING|AUR_PAGE_PENDING,d1
        bne edtr_recovery_blocked
edtr_finish_receipt:
        cmpi.w #6,d5
        beq edtr_validation_released
        cmpi.w #5,d5
        beq edtr_object_result
        cmpi.w #4,d5
        bne.s .ordinary_receipt
        bsr edtr_large_commit
        bmi edtr_recovery_blocked
        bra edtr_acquire_view
.ordinary_receipt:
        cmpi.w #3,d5
        bne.s .ordinary
        move.w #AUR_ASSETS_INCOMPLETE,AUR_BASE+AUR_ASSET_STATE
        bsr edtr_load_assets
        bne edtr_menu_released
        clr.w AUR_BASE+AUR_ASSET_STATE
        bsr aur_validate
        bne edtr_recovery_blocked
        bra.s edtr_acquire_view
.ordinary:
        cmpi.w #2,d5
        beq edtr_close_released
        tst.w AUR_BASE+AUR_EXIT_REQUEST
        beq.s .notice
        tst.w d7
        bne.s .failed_save
        tst.w d5
        beq edtr_recovery_blocked
        btst #0,AUR_BASE+AUR_FLAGS+1+PCREL(pc)
        beq edtr_recovery_blocked
        btst #1,AUR_BASE+AUR_FLAGS+1+PCREL(pc)
        bne edtr_recovery_blocked
        cmpi.w #AUR_CONTINUE_EXIT,AUR_BASE+AUR_EXIT_REQUEST
        beq edtr_close_released
        move.w AUR_BASE+AUR_EXIT_REQUEST+PCREL(pc),d0
        clr.w AUR_BASE+AUR_EXIT_REQUEST
        cmpi.w #AUR_CONTINUE_TEST,d0
        beq edtr_test_saved
        move.w d0,-(sp)
        move.w #AUR_PAGE_MENU,-(sp)
        bra edtr_page_released
.failed_save:
        ; Entered failure/unentered cancellation retains source, dirty and
        ; undo, and cancels only this one Exit request.
        clr.w AUR_BASE+AUR_EXIT_REQUEST
.notice:
        move.w d7,edtr_notice
        tst.w d7
        bne.s .message
        cmpi.w #1,d5
        bne.s edtr_acquire_view
        move.w #EDTR_NOTICE_SAVED,edtr_notice
        bra.s edtr_acquire_view
.message:
        move.w d7,d1
        bra edtr_message_released
edtr_acquire_view:
        tst.w AUR_BASE+AUR_ASSET_STATE
        bne edtr_menu_released
        bsr edtr_focus_resume
        bne edtr_page_released
        cmpi.w #2,AUR_BASE+AUR_TOOL
        beq edtr_object_released
        ; enter_view publishes its ring immediately, so initialize its tile
        ; origins first. It preserves them; render_view uses the same words.
        clr.l TERRAIN_OP
        clr.l TERRAIN_CURSOR_X
        ; Marker and Inspect read the map at the cursor; only Paint and Fill
        ; show the SAVED notice.
        cmpi.w #EDTR_NOTICE_SAVED,edtr_notice
        bne.s .cursor_ready
        cmpi.w #1,AUR_BASE+AUR_TOOL
        bhi.s .cursor_ready
        move.l #-1,TERRAIN_CURSOR_X
.cursor_ready:
        clr.w TERRAIN_STROKE_BLOCK
        bsr terrain_scroll_enter
        bsr edtr_restore_camera
        bne edtr_recovery_blocked
        bsr edtr_prepare_font
        bne edtr_recovery_blocked
        bsr enter_view
        move.w #1,edtr_view_live
        clr.w EDITOR_SESSION_BASE+REQ_ACTION
        bsr render_view
        bsr terrain_objects
.drain:
        clr.w native_last_key
        jsr wait_frame
        jsr editor_pointer_update
        tst.w native_left_down
        bne.s .drain
        tst.w native_right_down
        bne.s .drain
        move.w native_raw_key,d0
        subi.w #$4C,d0
        cmpi.w #3,d0
        bls.s .drain
        clr.w native_last_key
        clr.w native_left_pressed
        clr.w native_right_pressed
edtr_view_idle:
        jsr wait_frame
        jsr editor_pointer_update
        bsr terrain_input
        tst.w d0
        bmi edtr_recovery_blocked
        beq.s edtr_view_idle
        cmpi.w #11,d0
        bhi edtr_recovery_blocked
        ; Index only the low word; Fill/large-stroke keep their high-word seed.
        add.w d0,d0
        lea edtr_input_actions(pc),a0
        move.w 0(a0,d0.w),d1
        jmp 0(a0,d1.w)
edtr_input_actions:
        dc.w edtr_view_idle-edtr_input_actions
        dc.w edtr_request_save-edtr_input_actions
        dc.w edtr_menu-edtr_input_actions
        dc.w edtr_request_tile-edtr_input_actions
        dc.w edtr_request_fill-edtr_input_actions
        dc.w edtr_marker_warning-edtr_input_actions
        dc.w edtr_marker_limit-edtr_input_actions
        dc.w edtr_request_large-edtr_input_actions
        dc.w edtr_request_object-edtr_input_actions
        dc.w edtr_request_palette-edtr_input_actions
        dc.w edtr_request_validation-edtr_input_actions
        dc.w edtr_request_test-edtr_input_actions
edtr_request_save:
        cmpi.w #1,edtr_view_live
        bne edtr_recovery_blocked
        bsr edtr_release_view
        bra.s edtr_save_released

edtr_marker_warning:
        moveq #EDTR_MARKER_WARNING,d1
        bra.s edtr_marker_message
edtr_marker_limit:
        moveq #EDTR_MARKER_LIMIT,d1
edtr_marker_message:
        move.w d1,-(sp)
        bsr edtr_release_view
        move.w (sp)+,d1
edtr_message_released:
        move.w d1,-(sp)
        move.w #AUR_PAGE_MESSAGE,-(sp)
        bra edtr_page_released

; All durable Exit state is by value, never a callback into this overlay.
edtr_menu:
        bsr edtr_release_view
edtr_menu_released:
        move.l #$0004FFFF,-(sp)
        bra edtr_page_released
edtr_save_released:
        ; All preview, copper, font, mask, palette and sidebar owners end
        ; before prepare can publish pending, and before any overlay eviction.
        moveq #0,d0
        bsr aur_prepare_save
        tst.w d0
        bne.s edtr_prepare_failed
        lea edtr_save_request(pc),a0
edtr_service_dispatch:
        lea EDITOR_SESSION_BASE+REQ_NAME+PCREL(pc),a1
        moveq #4,d1
.request:
        move.l (a0)+,(a1)+
        dbra d1,.request
        move.l #EDITOR_SERIALIZER_BYTES,(a1)
        move.w #REQ_ACTION_DISPATCH,EDITOR_SESSION_BASE+REQ_ACTION
        moveq #0,d0
        bra.s edtr_before_return
edtr_prepare_failed:
        clr.w AUR_BASE+AUR_EXIT_REQUEST
        move.w d0,d1
        bra.s edtr_message_released

edtr_discard:
        ; Reached only from the explicit UNSAVED middle-button choice.
edtr_close_released:
        bsr aur_validate
        bne.s edtr_recovery_blocked
        tst.w edtr_view_live
        bne.s edtr_recovery_blocked
        move.w AUR_BASE+AUR_FLAGS+PCREL(pc),d0
        andi.w #AUR_SAVE_PENDING|AUR_PAGE_PENDING,d0
        bne.s edtr_recovery_blocked
        ; All fallible operations finished. The existing resident action0
        ; path receives a normal RTS, then reconstructs the campaign itself.
        lea EDITOR_UNDO_BASE+PCREL(pc),a0
        move.w #EDITOR_UNDO_BYTES/4-1,d0
.clear_undo:
        clr.l (a0)+
        dbra d0,.clear_undo
        move.w sr,-(sp)
        ori.w #$0700,sr
        lea AUR_BASE+PCREL(pc),a0
        moveq #AUR_BYTES/4-1,d0
.clear_owner:
        clr.l (a0)+
        dbra d0,.clear_owner
edtr_exit_publish:
        clr.l E7_CONTEXT
        move.w #REQ_ACTION_RETURN,EDITOR_SESSION_BASE+REQ_ACTION
        move.w (sp)+,sr
        moveq #0,d0
edtr_before_return:
edtr_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
edtr_bad_entry:
        moveq #EDTR_STATE_ERROR,d0
edtr_decline_or_invariant:
        ; Even malformed ABI/context cannot release a known mode2 lifetime
        ; into ordinary campaign restoration. No caller pointer is dereferenced.
        cmpi.w #2,session_custom_mode
        beq.s edtr_recovery_blocked
        bra.s edtr_return

; Before AUR publication, an invalid initial staged payload is a loader
; decline (ACTION remains -1), not permission to destroy a live draft.
edtr_initial_failure:
        moveq #EDTR_STATE_ERROR,d0
        bra.s edtr_return

edtr_save_refused:
        moveq #EDTR_ASSET_UNPROVED,d1
        bra edtr_message_released

edtr_release_view:
        bsr terrain_end
        tst.w d0
        bmi.s edtr_recovery_blocked
        bsr edtr_capture_camera
        bsr exit_view
        clr.w edtr_view_live
        rts

; No fallible or unimplemented close path may silently discard live AUR.
; Invariant failure retains the current frame and draft in a noninteractive wait.
edtr_recovery_blocked:
        move.w d0,edtr_notice
.wait:
        jsr wait_frame
        clr.w native_last_key
        bra.s .wait

; Exact notice/service combinations only. A notice is never a SAVE result.
edtr_receive:
        moveq #-1,d6
        bsr aur_validate
        bne edtr_receive_return
        moveq #AUR_ERROR_RESULT,d0
        btst #3,AUR_BASE+AUR_FLAGS+1+PCREL(pc)
        bne edtr_receive_tile
        btst #2,AUR_BASE+AUR_FLAGS+1+PCREL(pc)
        beq.s .no_pending
        cmpi.l #SAVE_MODULE_ID,AUR_BASE+AUR_TRANSPORT_ID
        beq.s .unentered_save
        tst.l AUR_BASE+AUR_TRANSPORT_ID
        beq.s .entered
        cmpi.l #EDTR_MODULE_ID,AUR_BASE+AUR_TRANSPORT_ID
        bne.s edtr_receive_return
.entered:
        bsr.s edtr_receive_save
        btst #2,AUR_BASE+AUR_FLAGS+1+PCREL(pc)
        bne.s edtr_receive_return
        bra.s edtr_consume_notice
.unentered_save:
        lea AUR_BASE+PCREL(pc),a5
        lea EDITOR_METADATA_BASE+PCREL(pc),a6
        bsr aur_match_request
        bne.s edtr_receive_return
        moveq #AUR_ERROR_RESULT,d0
        cmpi.w #-10,AUR_BASE+AUR_TRANSPORT_STATUS
        bne.s edtr_receive_return
        tst.l EDITOR_SESSION_BASE+REQ_RESULT_ID
        bne.s edtr_receive_return
        cmpi.w #AUR_STATUS_UNENTERED,SAVE_CONTEXT+SAVE_STATUS
        bne.s edtr_receive_return
        tst.l SAVE_CONTEXT+SAVE_READY
        bne.s edtr_receive_return
        andi.w #$FFFF-AUR_SAVE_PENDING,AUR_BASE+AUR_FLAGS
        moveq #-10,d0
        bra.s edtr_consume_notice
.no_pending:
        tst.l EDITOR_SESSION_BASE+REQ_RESULT_ID
        bne.s edtr_receive_return
        tst.l AUR_BASE+AUR_TRANSPORT_ID
        beq.s .ok
        cmpi.l #EDTR_MODULE_ID,AUR_BASE+AUR_TRANSPORT_ID
        bne.s edtr_receive_return
        moveq #-10,d0
        bra.s edtr_consume_notice
.ok:
        moveq #0,d0
edtr_consume_notice:
        clr.w AUR_BASE+AUR_TRANSPORT_STATUS
        clr.l AUR_BASE+AUR_TRANSPORT_ID
        moveq #0,d6
edtr_receive_return:
        tst.w d6
        rts
; The file service refuses a Save that would exceed the 150 records (status 1)
; or the quota (status 2) of Custom; name both on the message page.
edtr_receive_save:
        bsr aur_receive_save
        cmpi.w #1,d0
        bne.s .quota
        moveq #EDTR_SAVE_FILES,d0
.quota:
        cmpi.w #2,d0
        bne.s .named
        moveq #EDTR_SAVE_QUOTA,d0
.named:
        rts
edtr_save_request:
        dc.b "cf_save.mod",0,0,0,0,0
        dc.l SAVE_MODULE_ID

edtr_restore_camera:
        move.w AUR_BASE+AUR_CAMERA_X+PCREL(pc),d0
        move.w AUR_BASE+AUR_CAMERA_Y+PCREL(pc),d1
        bsr set_camera
        tst.w d0
        rts
edtr_capture_camera:
        move.w view_origin_x+PCREL(pc),AUR_BASE+AUR_CAMERA_X
        move.w view_origin_y+PCREL(pc),AUR_BASE+AUR_CAMERA_Y
        rts

; No lifecycle state or request is published by this owner predicate.
edtr_owner:
        bsr aur_owner
        bne.s .failed
        moveq #EDTR_STATE_ERROR,d0
        cmpi.l #BROWSER_STATE_TAG,BROWSER_STATE
        bne.s .return
        cmpi.w #1,BROWSER_VERSION
        bne.s .return
        cmpi.w #REQ_PURPOSE_EDITOR,BROWSER_PURPOSE
        bne.s .return
        tst.w EDTR_RESERVED
        bne.s .return
        move.w EDTR_OPERATION+PCREL(pc),d1
        subq.w #1,d1
        lsr.w #1,d1
        bne.s .return
        moveq #0,d0
.return:
        tst.w d0
        rts
.failed:
        moveq #EDTR_STATE_ERROR,d0
        rts

edtr_epoch:
        moveq #STORAGE_READ_CANCELLED,d0
        tst.l STORAGE_CONTEXT+STORAGE_READ_CANCEL
        bne.s .return
        moveq #4,d0
        moveq #0,d0
.return:
        tst.w d0
        rts

; Shared initial/replacement asset admission; no authored-data publication.
edtr_load_assets:
        bsr.s edtr_assets_call
edtr_assets_cleanup:
        clr.l RECOVERY_ASSET_STACK
        tst.w d0
        rts
edtr_assets_call:
        move.l sp,RECOVERY_ASSET_STACK
        move.w EDITOR_IO_BASE+MODULE_IO_KEEP_DRIVE+PCREL(pc),d1
        moveq #36,d0
        jsr sensi_disk_command
        tst.w d0
        bne.s edtr_assets_return
        clr.b native_base_asset_cache
        clr.b native_sub_asset_cache
edtr_before_assets:
        jsr native_map_full_loaded
edtr_after_assets:
        moveq #0,d0
edtr_assets_return:
        rts

; Gameplay errors and reviews are not a structural opening refusal.
; Rendering bounds-checks every MAP cell and substitutes an out-of-range tile.
edtr_validate:
        lea map_file_buffer,a0
        moveq #0,d0
        move.w EDITOR_METADATA_BASE+CFMD_MAP_BYTES+PCREL(pc),d0
        lea EDITOR_SPT_BASE+PCREL(pc),a1
        moveq #0,d1
        move.w EDITOR_METADATA_BASE+CFMD_SPT_BYTES+PCREL(pc),d1
        lea EDITOR_METADATA_BASE+PCREL(pc),a2
        lea edtr_validation+PCREL(pc),a3
        lea edtr_validation_scratch+PCREL(pc),a4
        bsr cf_payload_validate
        tst.w d0
        rts

; Rebase the 37 native hill descriptors into the owned font strip.
; Pixel source is the game's immutable cached hills.lbm, never new game data.
; The tool bar draws its text through the Slave; only its lower band's ink
; is chosen from the terrain palette.
edtr_prepare_font:
        bra bar_prepare

        include "objects.s"
OBJECT_PARTS_DATA_ONLY equ 1
        include "object_parts.s"

        include "view.s"
        include "../storage/read.s"
        include "../storage/payload.s"
        include "aur.s"
TESTED_RESULT_ENTRY equ 1
        include "tested.s"
        include "dialog_receipt.s"
        include "../controller/text.s"
        include "undo.s"
        include "marker.s"
        include "terrain.s"
        include "ink.s"
        include "tile_class.s"
        include "inspect.s"
        include "scroll.s"
        include "tile_receipt.s"
        include "object_route.s"
        include "validation_route.s"
        include "test_route.s"
editor_end:
        ifgt editor_end-editor_start-EDITOR_SERIALIZER_BYTES
        fail "EDTR exceeds installable 16 KiB"
        endif
        ifne PV_STATE_SIZE-3216
        fail "Preview scratch extent changed"
        endif
        ifgt edtr_state_end-EDITOR_READBACK_BASE-EDITOR_READBACK_BYTES
        fail "EDTR display scratch exceeds readback"
        endif
        ifgt edtr_validation_end-EDITOR_SERIAL_WORK_BASE-EDITOR_SERIAL_WORK_BYTES
        fail "EDTR structural validation exceeds work"
        endif
