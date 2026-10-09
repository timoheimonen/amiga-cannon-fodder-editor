; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Browser deletion authority. Include browser_delete.i before this source.
; No SAVE READY, resident CFMD, callback pointer or disk reinitialization.

        xdef browser_delete_open,browser_delete_check,browser_delete_identity
        xdef browser_delete_commit,browser_delete_close,browser_delete_end
browser_delete_start:
; A0=fixed BDQ1. Success retains this live guard until close/commit.
browser_delete_open:
        movem.l d1-d7/a0-a6,-(sp)
        moveq #10,d0
        cmpa.l #BDQ_CONTEXT,a0
        bne .return
; Fixed I/O may still contain another module's request. Refuse before mutation.
        bsr bdq_lifecycle
        beq.s .valid_request
        bsr bdq_owned_guard
        bne .return
        bra.s .finish
.valid_request:
        moveq #10,d0
        tst.w BDQ_CONTEXT+BDQ_INSTALLED
        bne.s .finish
        clr.w BDQ_CONTEXT+BDQ_CONFIRMED
        clr.w BDQ_CONTEXT+BDQ_CLASS_READY
        clr.w BDQ_CONTEXT+BDQ_ATTEMPTED
        clr.w BDQ_CONTEXT+BDQ_VERIFIED
        clr.w BDQ_CONTEXT+BDQ_REMOVED
        clr.w bdq_open_tag
        clr.w bdq_identity_valid
        bsr bdq_lifecycle
        bne.s .finish
        bsr bdq_epoch
        bne.s .finish
        move.w #1,BDQ_CONTEXT+BDQ_INSTALLED
        move.w #BDQ_OPEN_TAG,bdq_open_tag
        bsr bdq_inspect
        bne.s .finish
        lea read_marker_data,a0
        lea cf_delete_marker,a1
        moveq #15,d1
.pin:
        move.l (a0)+,(a1)+
        dbf d1,.pin
        move.w #1,bdq_identity_valid
        bsr.s browser_delete_check
        bne.s .finish
        clr.w BDQ_CONTEXT+BDQ_STATUS
        bra.s .return
.finish:
        bsr browser_delete_close
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; No I/O or wait. Escape release is a real consumed input edge, not a callback.
; Check remains valid while a native metadata write has deferred cancellation.
browser_delete_check:
        movem.l d1-d7/a0-a6,-(sp)
        moveq #10,d0
        cmpi.w #BDQ_OPEN_TAG,bdq_open_tag
        bne.s .return
        cmpi.w #1,BDQ_CONTEXT+BDQ_INSTALLED
        bne.s .return
        bne.s .return
        bsr.s bdq_lifecycle
        bne.s .return
        bsr bdq_epoch
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
cf_delete_check equ browser_delete_check

bdq_header:
        moveq #10,d0
        cmpi.l #BDQ_MAGIC,BDQ_CONTEXT
        bne.s .return
        cmpi.w #BDQ_VERSION,BDQ_CONTEXT+4
        bne.s .return
        cmpi.w #BDQ_BYTES,BDQ_CONTEXT+6
        bne.s .return
        tst.w BDQ_CONTEXT+BDQ_RESERVED
        bne.s .return
        moveq #0,d0
.return:
        tst.w d0
        rts

bdq_lifecycle:
        bsr.s bdq_header
        bne.s .return
        moveq #10,d0
        move.w BDQ_CONTEXT+BDQ_OPERATION,d1
        subq.w #1,d1
        cmpi.w #1,d1
        bhi.s .return
        cmpi.l #BROWSER_STATE_TAG,BROWSER_MAGIC
        bne.s .return
        cmpi.w #1,BROWSER_VERSION
        bne.s .return
        move.w BROWSER_PURPOSE,d1
        cmpi.w #REQ_PURPOSE_EDITOR,d1
        beq.s .purpose
        cmpi.w #REQ_PURPOSE_PLAY,d1
        bne.s .return
.purpose:
        cmp.w EDITOR_SESSION_BASE+REQ_PURPOSE,d1
        bne.s .return
        ifd LIVE_FILES_CONTEXT
        bsr live_files_owner
        bne.s .return
        moveq #10,d0
        else
        tst.w session_custom_mode
        bne.s .return
        tst.w SESSION_SNAPSHOT_VALID
        bne.s .return
        endif
        tst.w native_gameplay_active
        bne.s .return
        tst.w native_fifth_plane
        bne.s .return
        move.w sr,d1
        andi.w #$0700,d1
        bne.s .return
        tst.w BDQ_CONTEXT+BDQ_DRIVE
        bne.s .return
        tst.w BROWSER_DATA_DRIVE
        bne.s .return
        moveq #0,d0
.return:
        tst.w d0
        rts

bdq_epoch:
        cmpi.w #$C5,native_last_key
        bne.s .cancel
        clr.w native_last_key
        move.l #1,BDQ_CONTEXT+BDQ_CANCEL
.cancel:
        moveq #14,d0
        tst.w BDQ_CONTEXT+BDQ_ATTEMPTED
        bne.s .epoch
        tst.l BDQ_CONTEXT+BDQ_CANCEL
        bne.s .return
.epoch:
        moveq #0,d0
.return:
        tst.w d0
        rts

; Initial inspection does not pin; only open copies its complete result.
bdq_inspect:
        bsr browser_delete_check
        bne.s .return
        clr.l STORAGE_CONTEXT+STORAGE_READ_CANCEL
        tst.w BDQ_CONTEXT+BDQ_ATTEMPTED
        bne.s .inspect
        move.l BDQ_CONTEXT+BDQ_CANCEL,STORAGE_CONTEXT+STORAGE_READ_CANCEL
.inspect:
        lea STORAGE_CONTEXT,a0
        bsr storage_inspect_disk
        tst.w d0
        bne.s .return
        lea STORAGE_CONTEXT+STORAGE_INSPECT_DISK_ID,a0
        lea BDQ_CONTEXT+BDQ_DISK_ID,a1
        lea BROWSER_DISK_ID,a2
        moveq #3,d1
.id:
        move.l (a0)+,d2
        cmp.l (a1)+,d2
        bne.s .media
        cmp.l (a2)+,d2
        bne.s .media
        dbf d1,.id
        bsr browser_delete_check
        bra.s .return
.media:
        moveq #11,d0
.return:
        tst.w d0
        rts

; Fresh exact marker check. Never reset or repin after initial opening.
browser_delete_identity:
        movem.l d1-d7/a0-a6,-(sp)
        moveq #10,d0
        cmpi.w #1,bdq_identity_valid
        bne.s .return
        bsr.s bdq_inspect
        bne.s .return
        lea read_marker_data,a0
        lea cf_delete_marker,a1
        moveq #15,d1
.compare:
        cmpm.l (a0)+,(a1)+
        bne.s .media
        dbf d1,.compare
        bsr browser_delete_check
        bra.s .return
.media:
        moveq #11,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
cf_delete_inspect equ browser_delete_identity

browser_delete_write_check:
        bsr browser_delete_check
        bne.s .return
        moveq #0,d0
.return:
        tst.w d0
        rts

; A0=fixed BDQ1, CLASS_READY=CONFIRMED=1. Always closes after accepted context.
; Core re-reads the initial DIR and compares all6144 confirmed bytes before reuse.
browser_delete_commit:
        movem.l d1-d7/a0-a6,-(sp)
        moveq #10,d0
        cmpa.l #BDQ_CONTEXT,a0
        bne.s .return
        bsr bdq_header
        beq.s .valid_request
        bsr bdq_owned_guard
        bne.s .return
        bra.s .finish
.valid_request:
        moveq #10,d0
        cmpi.w #1,BDQ_CONTEXT+BDQ_CLASS_READY
        bne.s .finish
        cmpi.w #1,BDQ_CONTEXT+BDQ_CONFIRMED
        bne.s .finish
        move.w BDQ_CONTEXT+BDQ_FILE_COUNT,d1
        beq.s .finish
        cmpi.w #150,d1
        bhi.s .finish
        bsr browser_delete_identity
        bne.s .finish
        ifd LIVE_FILES_CONTEXT
        bsr live_files_protect_source
        bne.s .finish
        endif
        lea cf_delete_request,a1
        moveq #3,d1
.clear_target:
        clr.l (a1)+
        dbf d1,.clear_target
        lea .marker_name(pc),a0
        moveq #3,d1
.marker:
        move.l (a0)+,(a1)+
        dbf d1,.marker
        clr.l (a1)
        lea cf_delete_request,a0
        bsr delete_entry
.result:
        tst.w d0
        bne.s .finish
        tst.l BDQ_CONTEXT+BDQ_CANCEL
        beq.s .finish
        moveq #14,d0
.finish:
        bsr.s browser_delete_close
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
.marker_name:
        dc.b "CFEDITOR",0,0,0,0,0,0,0,0
        even

; Fixed request only. D0 status survives, other registers and SR control survive.
browser_delete_close:
        movem.l d1-d7/a0-a6,-(sp)
        bsr.s bdq_owned_guard
        bne.s .lost
        bra.s .clear
.lost:
; Do not use stale/corrupt request words as an IRQ restoration pointer.
        tst.w d0
        bne.s .clear
        move.w bdq_open_tag,d1
        or.w BDQ_CONTEXT+BDQ_INSTALLED,d1
        beq.s .clear
        moveq #10,d0
.clear:
        move.w d0,BDQ_CONTEXT+BDQ_STATUS
        tst.w BDQ_CONTEXT+BDQ_ATTEMPTED
        beq.s .authority
        clr.w sensi_directory_cached_count
.authority:
        clr.w BDQ_CONTEXT+BDQ_CONFIRMED
        clr.w BDQ_CONTEXT+BDQ_CLASS_READY
        clr.w BDQ_CONTEXT+BDQ_INSTALLED
        clr.w bdq_open_tag
        clr.w bdq_identity_valid
        clr.w BROWSER_VALIDATION
        clr.w BROWSER_DISPLAY_SAFE
        clr.l BROWSER_PENDING_ID
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; Z is true only while this adapter still owns its installed IRQ.
; D0 and all other registers survive, so error paths can use this predicate.
bdq_owned_guard:
        cmpi.w #BDQ_OPEN_TAG,bdq_open_tag
        bne.s .return
        cmpi.w #1,BDQ_CONTEXT+BDQ_INSTALLED
.return:
        rts

        include "../storage/delete.s"
browser_delete_end:
