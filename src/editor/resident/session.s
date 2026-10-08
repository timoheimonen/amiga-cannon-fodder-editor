; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Resident phase adapters never keep a return address in an overlay. The
; controller owns the continuation, stack anchor and custom-mode publication.
        xdef    session_map_full
        xdef    session_map_reload
        xdef    session_spt
        xdef    session_outcome
        xdef    session_after_hill
        xdef    session_return_controller
        xdef    session_prepare_phase
        xdef    session_return_original
        xdef    session_before_hill
        xdef    session_hill_history
        xdef    session_copy_original

; JMP + two NOPs replace BSR.W filename + LEA name,A0 (10 bytes).
; Nonzero mode authorizes an already validated MAP at the fixed engine buffer.
session_map_full:
        bsr     editor_test_custom_mode
        bne.s   .custom
        jsr     native_map_filename
        lea     native_map_name,a0
        jmp     native_map_full_resume
.custom:
        jmp     native_map_full_loaded

session_map_reload:
        bsr     editor_test_custom_mode
        bne.s   .custom
        jsr     native_map_filename
        lea     native_map_name,a0
        jmp     native_map_reload_resume
.custom:
session_map_staged_return:
        rts

; Only PLAY constructs the validated canonical SPT. Authored drafts bypass the
; constructor: their gameplay diagnostics may include unsafe allocation spans.
; Native mode reproduces the filename/load path; modes above PLAY return.
session_spt:
        cmpi.w  #1,session_custom_mode
        bhi.s   session_map_staged_return
        beq.s   .custom
        jsr     native_map_filename
        lea     native_map_name,a0
        jmp     native_spt_resume
.custom:
        moveq   #0,d1
        move.w     editor_resident_start+(EDITOR_METADATA_BASE+CFMD_SPT_BYTES-EDITOR_RESIDENT_BASE)(pc),d1
        clr.w   native_enemy_count
        clr.w   native_rescue_count
        lea     editor_resident_start+(EDITOR_SPT_BASE-EDITOR_RESIDENT_BASE)(pc),a0
        lea     native_entity_pool,a1
        jmp     native_spt_construct

; JMP + NOP replaces BNE.S + CLR.W at $86236 (8 bytes). Save the gameplay
; return SR before the mode test. Native mode reproduces both original arms.
session_outcome:
        move.w  sr,-(sp)
        ori.w   #$0700,sr
        bsr     editor_test_custom_mode
        bne.s   .custom
        move.w  (sp)+,sr
        bne.s   .nonzero
        clr.w   native_play_guard
        jmp     native_outcome_zero
.nonzero:
        jmp     native_outcome_nonzero
.custom:
        move.w  (sp)+,session_outcome_sr
        move.w  native_no_squad,session_outcome_no_squad
        move.w  native_objective_success,session_outcome_success
        move.w  native_abort_or_failure,session_outcome_failure
        clr.w   native_gameplay_active
        clr.w   native_play_guard
        move.w     editor_resident_start+(session_outcome_sr-EDITOR_RESIDENT_BASE)(pc),sr
        ; The skipped results screen restarts the front-end song; without it the
        ; victory or defeat tune keeps looping in the editor and result screens.
        clr.w   fodders_music_song
        jsr     fodders_music_start
        move.w  #SESSION_EVENT_OUTCOME,session_event
        bra.s   session_return_controller

; JMP replaces the six-byte JSR at $85FDE. All native hill/modal frames have
; returned here. Record the main-lifecycle stack, not an overlay return frame.
session_after_hill:
        bsr     editor_test_custom_mode
        bne.s   .custom
        bsr     editor_resident_start+(native_campaign_dialog-EDITOR_RESIDENT_BASE)
        jmp     native_after_dialog
.custom:
        move.l  sp,session_stack_anchor
        move.w  #SESSION_EVENT_HILL,session_event
session_return_controller:
        bra     editor_session_continue

; Nonlocal preparation entry for a trusted resident caller.
; The caller owns snapshot/checkpoint/roster/metadata publication and eviction.
; It may enter only after all modal/disk/module calls have returned, with no
; borrowed overlay return address. It must not expect this entry to return.
session_prepare_phase:
        movea.l     editor_resident_start+(session_stack_anchor-EDITOR_RESIDENT_BASE)(pc),sp
        clr.w   native_recruitment_pending
        ; The skipped departure sequence normally installs the briefing colors.
        lea     native_briefing_palette_resources,a3
        jsr     native_resource_list_load
session_reset_phase:
        clr.w   native_binding_backup_valid
        clr.w   native_terrain_marker
        clr.b   native_base_asset_cache
        clr.b   native_sub_asset_cache
        jmp     native_phase_reset

; Success transfers to native reconstruction and never returns. Refusal leaves
; persistent state untouched: D0=-1 for an invalid snapshot, -2 for active play.
; The controller supplies a trusted main-lifecycle SP, never an overlay frame.
session_return_original:
        cmpi.w  #SESSION_SNAPSHOT_TAG,SESSION_SNAPSHOT_VALID
        bne.s   .invalid
        tst.w   native_gameplay_active
        bne.s   .active
        clr.l   editor_module_active
        bsr.s   session_copy_original
        clr.w   session_custom_mode
        move.w  #SESSION_EVENT_RETURN,session_event
        clr.l   SESSION_CHECKPOINT_VALID
        move.w  #-1,native_recruitment_pending
        movea.l     editor_resident_start+(session_stack_anchor-EDITOR_RESIDENT_BASE)(pc),sp
        bra.s   session_reset_phase
.invalid:
        moveq   #-1,d0
        rts
.active:
        moveq   #-2,d0
        rts

; IRQ/frame and display state occupy the first 24 snapshot bytes and remain
; live-owned. Only the stable campaign suffix is published, with IRQs excluded.
session_copy_original:
        movem.l d0/a0-a1,-(sp)
        move.w  sr,-(sp)
        ori.w   #$0700,sr
        lea     editor_resident_start+(EDITOR_SNAPSHOT_BASE+24-EDITOR_RESIDENT_BASE)(pc),a0
        lea     campaign_payload,a1
        move.w  #(EDITOR_SNAPSHOT_BYTES-24)/4-1,d0
.copy:
        move.l  (a0)+,(a1)+
        dbra    d0,.copy
        move.w  (sp)+,sr
        movem.l (sp)+,d0/a0-a1
        rts

; The native setup has rebuilt entities/bindings but changed presentation
; counters. Republish the snapshot before the hill consumes those counters.
; This is a JSR replacement and tail-calls the original hill entry.
; RETURN is a resident-owned capability, published only by the checked entry
; above. Native reconstruction and IRQ code cannot alter it or the snapshot.
session_before_hill:
        cmpi.w  #SESSION_EVENT_RETURN,session_event
        bne.s   .native
        bsr.s   session_copy_original
.native:
        jmp     native_hill_enter

; Only the return transaction skips aging historical dead-list entries. The
; ordinary campaign still calls both displaced services in the original order.
session_hill_history:
        cmpi.w  #SESSION_EVENT_RETURN,session_event
        bne.s   .native
        clr.w   session_event
        clr.w   SESSION_SNAPSHOT_VALID
        bra.s   .render
.native:
        jsr     native_dead_list_age
.render:
        jsr     native_hall_of_fame_draw
        jmp     native_hill_history_next
