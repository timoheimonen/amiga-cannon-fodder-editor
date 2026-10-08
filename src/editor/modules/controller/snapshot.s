; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
        xdef session_begin_custom,session_begin_authoring,session_restore_campaign
CAMPAIGN_STABLE equ EDITOR_SNAPSHOT_BYTES-24

; Begin only after STG1 validation and independent display/name preflight.
; No UI, disk I/O, renderer or native phase entry is called here. The caller
; must own the inactive engine and return normally before evicting this code.
; D0=0 success, -1 invalid state/record, -2 gameplay active. Other registers
; and SP survive; SR control bits survive, result NZVC is returned.
session_begin_custom:
        movem.l d1-d7/a0-a6,-(sp)
        move.w  sr,-(sp)
        ori.w   #$0700,sr
        tst.w   native_gameplay_active
        bne     snapshot_active
        tst.w   session_custom_mode
        bne     snapshot_invalid
        tst.w   SESSION_SNAPSHOT_VALID
        bne     snapshot_invalid
        cmpi.l  #1,STORAGE_READY
        bne     snapshot_invalid
        tst.w   STORAGE_STATUS
        bne     snapshot_invalid
        tst.l   STORAGE_ERRORS
        bne     snapshot_invalid
        lea     EDITOR_METADATA_BASE,a2
        cmpi.l  #CFMD_MAGIC,(a2)
        bne     snapshot_invalid
        cmpi.l  #$00010100,4(a2)
        bne     snapshot_invalid
        moveq   #0,d1
        move.b  CFMD_PHASE_COUNT(a2),d1
        beq     snapshot_invalid
        cmpi.w  #6,d1
        bhi     snapshot_invalid
        moveq   #0,d2
        move.b  CFMD_PHASE_INDEX(a2),d2
        cmp.w   d1,d2
        bhs     snapshot_invalid
        tst.w   CFMD_RECRUITS(a2)
        ble     snapshot_invalid

        ; Capture all E68 bytes for audit. Only the E50 stable suffix will be
        ; restored: frame/IRQ, buffer selector and drive state are live owners.
        bsr     snapshot_capture
        lea     campaign_payload,a0
        move.w  #CAMPAIGN_STABLE/4-1,d0
.clear:
        clr.l   (a0)+
        dbra    d0,.clear
        jsr     native_roster_init
        jsr     native_score_init
        ; Death consumers append through these pointers even without a native
        ; debrief. A cleared campaign domain alone would leave NULL pointers.
        move.l  #native_dead_ranks,native_dead_rank_end
        move.l  #native_dead_ranks,native_dead_rank_cursor
        move.w  #-1,native_dead_ranks
        move.l  #native_dead_names,native_dead_name_end
        move.w  #-1,native_dead_names
        lea     EDITOR_METADATA_BASE,a2
        move.w  #1,native_mission_number
        move.w  CFMD_RECRUITS(a2),native_recruits_remaining
        moveq   #0,d1
        move.b  CFMD_PHASE_COUNT(a2),d1
        move.w  d1,native_phase_count
        moveq   #0,d2
        move.b  CFMD_PHASE_INDEX(a2),d2
        move.w  d2,native_phase_number
        sub.w   d2,d1
        move.w  d1,native_phases_remaining
        clr.l   SESSION_CHECKPOINT_VALID
        move.w  #SESSION_SNAPSHOT_TAG,SESSION_SNAPSHOT_VALID
        move.w  #1,session_custom_mode
        moveq   #0,d0
        bra     snapshot_return

; Capture before authoring takes ownership. Unlike PLAY, draft entry changes
; no campaign roster, policy or phase state and calls no native constructor.
session_begin_authoring:
        movem.l d1-d7/a0-a6,-(sp)
        move.w  sr,-(sp)
        ori.w   #$0700,sr
        move.w  (sp),d1
        andi.w  #$0700,d1
        bne     snapshot_invalid
        tst.w   native_gameplay_active
        bne     snapshot_active
        tst.w   session_custom_mode
        bne     snapshot_invalid
        tst.w   SESSION_SNAPSHOT_VALID
        bne.s   snapshot_invalid
        bsr     controller_authoring_record
        bne.s   snapshot_invalid
        bsr.s   snapshot_capture
        clr.l   SESSION_CHECKPOINT_VALID
        move.w  #SESSION_SNAPSHOT_TAG,SESSION_SNAPSHOT_VALID
        move.w  #2,session_custom_mode
        moveq   #0,d0
        bra.s   snapshot_return

; Pre-hill rollback only: restore bytes while the native hill still owns its
; unchanged display. Post-hill exits use the resident reconstruction path.
session_restore_campaign:
        movem.l d1-d7/a0-a6,-(sp)
        move.w  sr,-(sp)
        ori.w   #$0700,sr
        tst.w   native_gameplay_active
        bne.s   snapshot_active
        move.w  session_custom_mode,d1
        subq.w  #1,d1
        lsr.w   #1,d1
        bne.s   snapshot_invalid
        cmpi.w  #SESSION_SNAPSHOT_TAG,SESSION_SNAPSHOT_VALID
        bne.s   snapshot_invalid
        lea     EDITOR_SNAPSHOT_BASE+24,a0
        lea     campaign_payload,a1
        move.w  #CAMPAIGN_STABLE/4-1,d0
.restore:
        move.l  (a0)+,(a1)+
        dbra    d0,.restore
        clr.l   SESSION_CHECKPOINT_VALID
        clr.w   SESSION_SNAPSHOT_VALID
        clr.l   session_custom_mode
        moveq   #0,d0
        bra.s   snapshot_return
snapshot_active:
        moveq   #-2,d0
        bra.s   snapshot_return
snapshot_invalid:
        moveq   #-1,d0
snapshot_return:
        move.w  (sp)+,sr
        movem.l (sp)+,d1-d7/a0-a6
        tst.w   d0
        rts
snapshot_capture:
        lea     native_frame_domain,a0
        lea     EDITOR_SNAPSHOT_BASE,a1
        move.w  #EDITOR_SNAPSHOT_BYTES/4-1,d0
.capture:
        move.l  (a0)+,(a1)+
        dbf     d0,.capture
        rts
session_snapshot_end:
        ifne EDITOR_SNAPSHOT_BYTES-24-CAMPAIGN_STABLE
        fail "Snapshot suffix extent differs"
        endif
