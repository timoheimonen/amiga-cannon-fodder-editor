; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        include "fodders.i"
        include "layout.i"
        include "session.i"
        include "resident_symbols.i"
        include "authoring_recovery.i"
        section .text,code
        xdef editor_resource_raw,editor_resource_ilbm
        xdef editor_resource_result,editor_resource_wait,editor_resource_after_wait
        xdef editor_resource_loaders_end
        xdef editor_resource_retry_native,editor_resource_scan_next
        xdef editor_resource_toggle,editor_resource_toggle_end,editor_resource_cancel_live

; Fixed native entries retain the shared argument record and synchronous read
; contracts. The common result path adds one four-byte return frame; it never
; retains a pointer into an overlay. A two-byte stack counter belongs to the
; complete resource call and counts failed drives during stopped custom preparation
; or the checked campaign-return transaction.
; It is discarded without altering CCR on successful return.
; D0.w=0 is the only ordinary return status.
editor_resource_raw:
        move.w #4,-(sp)
        movem.l d1/a0-a1,native_resource_arguments
.retry:
        movem.l editor_resource_raw+(native_resource_arguments-native_resource_raw)(pc),d1/a0-a1
        move.w #8,d0
        bsr.w editor_resource_raw+(sensi_disk_command-native_resource_raw)
        bsr.s editor_resource_result
        bne.s .retry
        addq.l #2,sp
        rts

; Preserve the native delay toggle on both success and failure, and preserve
; its D0 upper word. Failure waits, advances the native drive selector and
; returns nonzero only to the local retry loop. Required files never return
; an error to callers that expect a complete asset.
editor_resource_result:
        move.w d0,native_resource_status
        bsr.w editor_resource_toggle
        tst.w d0
        beq.s resource_result_return
        move.w editor_resource_raw+(native_resource_retry_delay-native_resource_raw)(pc),d0
editor_resource_wait:
        bsr.s editor_resource_retry_native
editor_resource_after_wait:
        dbf d0,editor_resource_wait
        addq.w #1,native_resource_drive
        andi.w #3,native_resource_drive
        clr.w d0
        move.w editor_resource_raw+(native_resource_drive-native_resource_raw)(pc),d1
        moveq #-1,d3
        movea.l d3,a0
        bsr.w editor_resource_raw+(sensi_disk_command-native_resource_raw)
        move.w #1,d0
resource_result_return:
        rts
editor_resource_scan_next:
        clr.w d0
        rts
resource_retry_native_frame:
        bra.w editor_resource_raw+(wait_frame-native_resource_raw)
        dcb.b native_resource_ilbm-native_resource_raw-(*-editor_resource_raw),0

editor_resource_ilbm:
        move.w #4,-(sp)
        movem.l a0-a2,native_resource_arguments
.retry:
        movem.l editor_resource_raw+(native_resource_arguments-native_resource_raw)(pc),a0-a2
        bsr.w editor_resource_raw+(native_ilbm_load-native_resource_raw)
        bsr.s editor_resource_result
        bne.s .retry
        addq.l #2,sp
        rts
; Mode/event form one longword: zero is ordinary campaign; RETURN remains
; published after mode clears until the rebuilt hill consumes the snapshot.
; Active gameplay keeps the exact native frame-wait ABI.
; Stopped custom preparation instead presents the required game disk, preserving
; D0's upper word and all other registers. D0.w=0 ends the caller's DBF delay so
; its next drive scan follows immediately; that caller does not consume CCR.
; Published drafts return to their active EDTR asset frame on Cancel. Only a
; session without a live draft abandons preparation through campaign return.
editor_resource_retry_native:
        tst.l session_custom_mode
        beq.s resource_retry_native_frame
        tst.w native_gameplay_active
        bne.s resource_retry_native_frame
        ; Two return addresses precede this wrapper-owned countdown word.
        subq.w #1,8(sp)
        bne.s editor_resource_scan_next
        ; The exhausted word is zero here; reload it without an immediate word.
        addq.w #4,8(sp)
        move.l d0,-(sp)
        moveq #3,d0
        jsr RESIDENT_editor_resource_prompt
        beq.s resource_retry_continue
        tst.w session_custom_mode
        beq.s resource_retry_continue
        jsr RESIDENT_editor_authoring_live
        beq.s editor_resource_cancel_live
        jmp RESIDENT_editor_session_cancel_original
resource_retry_continue:
        move.l (sp)+,d0
        bra.s editor_resource_scan_next

; Native delay rule for every input word: 44 becomes 14; anything else becomes
; 44. Preserve all registers and X; the positive word store clears N/Z/V/C.
; MOVEM restores D0 without changing those flags. The saved longword adds four
; transient stack bytes, released before any wait, prompt or disk operation.
editor_resource_toggle:
        move.l d0,-(sp)
        moveq #44,d0
        cmp.w editor_resource_raw+(native_resource_retry_delay-native_resource_raw)(pc),d0
        bne.s .store
        moveq #14,d0
.store:
        move.w d0,native_resource_retry_delay
        movem.l (sp)+,d0
        rts
editor_resource_toggle_end:
; Only the live EDTR asset caller can reach this stopped authoring path. Its
; stack anchor enters its own cleanup frame, which clears the anchor and tests
; D0=1 before any overlay request. Native resource frames are abandoned only
; after disk and prompt cleanup have returned. No authored object is released.
editor_resource_cancel_live:
        movea.l RECOVERY_ASSET_STACK,sp
        rts
        dcb.b native_resource_loaders_end-native_resource_raw-(*-editor_resource_raw),0
editor_resource_loaders_end:
