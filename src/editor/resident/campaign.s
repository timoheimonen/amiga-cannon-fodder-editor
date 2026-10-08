; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Ordinary campaign I/O is unavailable while a custom session owns the
; immutable snapshot. Native campaign loads stage exact-size raw bytes from the
; save disk and publish them atomically.
        xdef    editor_campaign_gate
        xdef    editor_campaign_list
        xdef    editor_campaign_load
        xdef    editor_campaign_publish
        xdef    editor_campaign_load_return
        xdef    editor_campaign_close
        xdef    editor_campaign_release
        xdef    editor_campaign_previous_keep
        xdef    editor_campaign_modal

; Replace the exact six-byte TST at $A9E56. Refusal changes only D0/CCR:
; mode, UI flags, loaded flag, campaign bytes, disk and display stay untouched.
editor_campaign_gate:
        bsr     editor_test_custom_mode
        bne.s   .refuse
        tst.w   FODDERS_LOAD_FLAG
        bra     editor_resident_start+(campaign_gate_continue-EDITOR_RESIDENT_BASE)
.refuse:
        moveq   #4,d0
        rts

; Replace $A9E90..$A9E99, bypassing every unbounded scan/removal loop.
; Fresh marker, then fresh native directory while holding one selected drive.
editor_campaign_list:
        movem.l d0-d7/a0-a6,-(sp)
        lea     editor_resident_start+(EDITOR_IO_BASE-EDITOR_RESIDENT_BASE)(pc),a5
        move.w  sensi_keep_drive_selected,editor_campaign_previous_keep-editor_resident_start+EDITOR_RESIDENT_BASE-EDITOR_IO_BASE(a5)
        move.w  #1,editor_campaign_modal-editor_resident_start+EDITOR_RESIDENT_BASE-EDITOR_IO_BASE(a5)
        move.w  #1,sensi_keep_drive_selected
        lea     editor_resident_start+(campaign_marker_name-EDITOR_RESIDENT_BASE)(pc),a0
        bsr     editor_marker_call
        bne     .failed
        bsr     editor_raw_epoch
        bne     .failed
        bsr     editor_raw_directory
        bne     .failed
        move.l  a4,campaign_directory_pointer
        lea     32(a4),a0
        movea.l a0,a1
        moveq   #0,d5
.record:
        subq.l  #1,d6
        bmi     .finish
        movea.l a0,a3
        moveq   #14,d2
.name:
        move.b  (a3)+,d0
        beq.s   .name_end
        cmpi.b  #' ',d0
        blo     .failed
        cmpi.b  #'~',d0
        bhi     .failed
        dbra    d2,.name
        bra     .failed
.name_end:
        cmpi.w  #14,d2
        beq     .failed
        cmpi.w  #6,d2
        bne.s   .campaign_record
        move.l  (a0),d0
        ori.l   #$20202020,d0
        cmpi.l  #$63666564,d0
        bne.s   .campaign_record
        move.l  4(a0),d0
        ori.l   #$20202020,d0
        cmpi.l  #$69746f72,d0
        beq     .failed
.campaign_record:
        tst.b   21(a0)
        bne.s   .next
        cmpi.l  #CAMPAIGN_BYTES,28(a0)
        bne.s   .next
        cmpi.w  #10,d2
        bhi.s   .include
        subq.l  #5,a3
        moveq   #0,d0
        moveq   #3,d1
.suffix:
        lsl.l   #8,d0
        move.b  (a3)+,d0
        dbra    d1,.suffix
        ori.l   #$20202020,d0
        cmpi.l  #$2e6d6170,d0
        beq.s   .next
        cmpi.l  #$2e737074,d0
        beq.s   .next
        cmpi.l  #$2e636d69,d0
        beq.s   .next
        cmpi.l  #$2e6d6f64,d0
        beq.s   .next
.include:
        movea.l a0,a3
        moveq   #7,d0
.copy:
        move.l  (a3)+,(a1)+
        dbra    d0,.copy
        addq.w  #1,d5
.next:
        lea     32(a0),a0
        bra     .record
.finish:
        move.w  d5,campaign_directory_count
        ; Exactly one marker is excluded, so at least one sentinel fits.
        move.w  #150*8-1,d0
        lsl.w   #3,d5
        sub.w   d5,d0
.zero:
        clr.l   (a1)+
        dbra    d0,.zero
        bsr     editor_raw_epoch
        bne.s   .failed
        movem.l (sp)+,d0-d7/a0-a6
        bra     editor_resident_start+(campaign_list_continue-EDITOR_RESIDENT_BASE)
.failed:
        bsr.s   editor_campaign_release
        movem.l (sp)+,d0-d7/a0-a6
        bra     editor_resident_start+(campaign_retry-EDITOR_RESIDENT_BASE)

; Replace only the JSR at $A9FFE with JMP. The unsafe loaded-flag store
; becomes unreachable. Snapshot bytes exchange with staging for rollback.
editor_campaign_load:
        movem.l d0-d7/a0-a6,-(sp)
        clr.w   campaign_loaded
        bsr     editor_raw_epoch
        bne.s   editor_campaign_load_return
        move.l  a0,-(sp)
        lea     editor_resident_start+(campaign_marker_name-EDITOR_RESIDENT_BASE)(pc),a0
        bsr     editor_marker_call
        movea.l (sp)+,a0
        tst.w   d0
        bne.s   editor_campaign_load_return
        bsr     editor_snapshot_call
        bne.s   editor_campaign_load_return
        bsr     editor_raw_epoch
        bne.s   editor_campaign_load_return
        move.w  sr,-(sp)
        ori.w   #$0700,sr
        bsr.s   editor_campaign_exchange
editor_campaign_publish:
        bsr     editor_raw_epoch
        beq.s   .commit
        bsr.s   editor_campaign_exchange
        bra.s   .restore_sr
.commit:
        move.w  #-1,campaign_loaded
.restore_sr:
        move.w  (sp)+,sr
editor_campaign_load_return:
        movem.l (sp)+,d0-d7/a0-a6
        bra     editor_resident_start+(campaign_cleanup_hook-EDITOR_RESIDENT_BASE)
editor_campaign_exchange:
        lea     editor_resident_start+(EDITOR_SNAPSHOT_BASE-EDITOR_RESIDENT_BASE)(pc),a0
        lea     campaign_payload,a1
        move.w  #CAMPAIGN_BYTES/4-1,d0
.copy:
        move.l  (a0),d1
        move.l  (a1),(a0)+
        move.l  d1,(a1)+
        dbra    d0,.copy
        rts

; Replace the two BSRs at $AA00C with JMP plus NOP (eight whole bytes).
editor_campaign_close:
        bsr.s   editor_campaign_release
        bsr     editor_resident_start+(campaign_cleanup-EDITOR_RESIDENT_BASE)
        bra     editor_resident_start+(campaign_restore_display-EDITOR_RESIDENT_BASE)
editor_campaign_release:
        tst.w   editor_campaign_modal
        beq.s   .return
        clr.w   editor_campaign_modal
        move.w     editor_campaign_previous_keep(pc),d1
        moveq   #36,d0
        jsr     sensi_disk_command
.return:
        rts

editor_campaign_previous_keep:
        dc.w    0
editor_campaign_modal:
        dc.w    0
