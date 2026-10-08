; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

CF_DELETE_LIBRARY equ 1
CF_DELETE_GUARDED equ 1
CF_DELETE_WORK_BASE equ EDITOR_READBACK_BASE+12288
CF_DELETE_STATE equ CF_DELETE_WORK_BASE+652
cf_delete_keep equ CF_DELETE_STATE
cf_delete_installed equ CF_DELETE_STATE+2
cf_delete_vector equ CF_DELETE_STATE+4
cf_delete_attempted equ CF_DELETE_STATE+8
cf_delete_verified equ CF_DELETE_STATE+10
cf_delete_identity_valid equ CF_DELETE_STATE+12
cf_delete_request equ CF_DELETE_STATE+16
cf_delete_marker equ CF_DELETE_STATE+52
CF_DELETE_STATE_END equ CF_DELETE_STATE+116

        xdef cf_delete_guarded,cf_delete_attempted,cf_delete_verified
; A0=trusted padded target[16]. Requires a fully verified current SAVE and a
; caller-validated obsolete generation. Never permits deleting the new prefix.
; In batch builds A0 names its CMI and D1.w is its validated phase count 1..6.
; D0=status, other registers preserved. ATTEMPTED/VERIFIED distinguish late
; errors/cancel from a mutation that was never attempted.
cf_delete_guarded:
        movem.l d1-d7/a0-a6,-(sp)
        clr.w cf_delete_installed
        clr.w cf_delete_attempted
        clr.w cf_delete_verified
        clr.w cf_delete_identity_valid
        moveq #10,d0
        cmpi.l #1,SAVE_CONTEXT+SAVE_READY
        bne .return
        tst.w SAVE_CONTEXT+SAVE_STATUS
        bne .return
        move.l SAVE_CONTEXT+SAVE_TARGET_ID,d1
        cmp.l EDITOR_METADATA_BASE+CFMD_ID,d1
        bne .return
        move.l SAVE_CONTEXT+SAVE_GENERATION,d1
        cmp.l EDITOR_METADATA_BASE+CFMD_GENERATION,d1
        bne .return
        bsr cf_delete_lifecycle
        bne .return
        moveq #10,d0
        tst.w native_gameplay_active
        bne .return
        tst.w SAVE_CONTEXT+SAVE_DRIVE
        bne.s .return
        move.w sr,d1
        andi.w #$0700,d1
        cmpi.w #$0600,d1
        bhs.s .return
        bsr read_valid_target
        bne.s .return
        move.l (a0),d1
        cmp.l EDITOR_METADATA_BASE+CFMD_MAP_NAME,d1
        bne.s .old_prefix
        move.l 4(a0),d1
        cmp.l EDITOR_METADATA_BASE+CFMD_MAP_NAME+4,d1
        beq.s .invalid
.old_prefix:
        lea cf_delete_request,a1
        moveq #3,d1
.target:
        move.l (a0)+,(a1)+
        dbf d1,.target
        lea .marker_name(pc),a0
        moveq #3,d1
.name:
        move.l (a0)+,(a1)+
        dbf d1,.name
        clr.l (a1)
        bsr.s cf_delete_check
        bne.s .return
        move.w #1,cf_delete_installed
        lea cf_delete_request,a0
        bsr delete_entry
        tst.w d0
        bne.s .finish
        tst.l SAVE_CONTEXT+SAVE_CANCEL
        beq.s .finish
        moveq #14,d0
        bra.s .finish
.invalid:
        moveq #10,d0
.finish:
        tst.w cf_delete_attempted
        beq.s .cache_ok
        clr.w sensi_directory_cached_count
.cache_ok:
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
.marker_name:
        dc.b "CFEDITOR",0,0,0,0,0,0,0,0
        even

cf_delete_lifecycle:
        moveq #10,d0
        tst.w session_custom_mode
        beq.s .ordinary
        cmpi.w #2,session_custom_mode
        bne.s .return
        cmpi.w #SESSION_SNAPSHOT_TAG,SESSION_SNAPSHOT_VALID
        bne.s .return
        bra.s .valid
.ordinary:
        tst.w SESSION_SNAPSHOT_VALID
        bne.s .return
.valid:
        moveq #0,d0
.return:
        tst.w d0
        rts

; After a file deletion is attempted, defer cooperative cancellation until
; its verification completes.
cf_delete_check:
        moveq #14,d0
        tst.w cf_delete_attempted
        bne.s .epoch
        tst.l SAVE_CONTEXT+SAVE_CANCEL
        bne.s .return
.epoch:
        moveq #0,d0
.return:
        tst.w d0
        rts

; Inspector owns WORK[0:864], but no READBACK bytes. DEL state lives beyond
; its two 6144-byte buffers, so all three identity checks share the same code.
cf_delete_inspect:
        movem.l d1-d7/a0-a6,-(sp)
        bsr.s cf_delete_check
        bne.s .return
        clr.l save_read_context+STORAGE_READ_CANCEL
        tst.w cf_delete_attempted
        bne.s .inspect
        move.l SAVE_CONTEXT+SAVE_CANCEL,save_read_context+STORAGE_READ_CANCEL
.inspect:
        lea save_read_context,a0
        bsr storage_inspect_disk
        tst.w d0
        bne.s .return
        lea save_read_context+STORAGE_INSPECT_DISK_ID,a0
        lea SAVE_CONTEXT+SAVE_DISK_ID,a1
        moveq #3,d1
.id:
        cmpm.l (a0)+,(a1)+
        bne.s .media
        dbf d1,.id
        lea read_marker_data,a0
        lea cf_delete_marker,a1
        moveq #15,d1
        tst.w cf_delete_identity_valid
        bne.s .compare
.remember:
        move.l (a0)+,(a1)+
        dbf d1,.remember
        move.w #1,cf_delete_identity_valid
        bra.s .checked
.compare:
        cmpm.l (a0)+,(a1)+
        bne.s .media
        dbf d1,.compare
.checked:
        bsr cf_delete_check
        bra.s .return
.media:
        moveq #11,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

        include "delete.s"
        ifgt CF_DELETE_STATE_END-EDITOR_READBACK_BASE-EDITOR_READBACK_BYTES
        fail "Guarded delete state exceeds readback"
        endif
