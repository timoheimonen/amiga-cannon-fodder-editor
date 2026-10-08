; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; The confirmed catalog stays immutable in CF_TRACK_COPY. Two 20-byte masks
; live in the fixed delete work area; no runtime allocation is added.
; A completed file removal is verified before another can begin. Manifests
; precede payloads, so interruption leaves recoverable orphan payloads.
        ifnd CF_DELETE_GUARDED
        fail "WHD deletion requires a typed guarded caller"
        endif
CF_DIRECTORY_BYTES equ 6144
CF_DIRECTORY_COPY equ EDITOR_READBACK_BASE
        ifnd CF_TRACK_COPY
CF_TRACK_COPY equ EDITOR_READBACK_BASE+6144
        endif
CF_DELETE_INVALID equ 10
CF_DELETE_MEDIA equ 11
CF_DELETE_CORRUPT equ 12
CF_DELETE_VERIFY equ 13
CF_DELETE_CANCEL equ 14
cf_del_done equ CF_DELETE_WORK_BASE
cf_del_selected equ CF_DELETE_WORK_BASE+20
cf_del_removed equ CF_DELETE_WORK_BASE+40
cf_del_context equ CF_DELETE_WORK_BASE+640
cf_del_record_count equ CF_DELETE_WORK_BASE+648
CF_DELETE_WORK_BYTES equ 652
        xdef delete_start,delete_entry,delete_before_commit,delete_end
delete_start:
delete_entry:
        movem.l d1-d7/a0-a6,-(sp)
        move.l a0,cf_del_context
        lea cf_del_done,a1
        moveq #10,d1
.clear: clr.l (a1)+
        dbf d1,.clear
        moveq #CF_DELETE_INVALID,d0
        ifnd CF_DELETE_RECORD_SET
        bsr read_valid_target
        bne cf_del_finish
        endif
        bsr cf_delete_inspect
        bne cf_del_finish
        bsr cf_del_snapshot
        bne cf_del_finish
        lea CF_DIRECTORY_COPY,a5
        move.l 24(a5),d7
        beq cf_del_media
        cmpi.l #150,d7
        bhi cf_del_media
        move.w d7,cf_del_record_count
        ifd CF_DELETE_RECORD_SET
        bsr cf_del_compare_directories
        bne cf_del_media
        bsr cf_del_validate_set
        bne cf_del_finish
        else
        lea CF_DIRECTORY_COPY,a0
        lea CF_TRACK_COPY,a1
        move.w #1535,d1
.remember: move.l (a0)+,(a1)+
        dbf d1,.remember
        endif
; Validate every selected record before the first externally visible change.
        lea CF_TRACK_COPY+32,a5
        moveq #0,d6
        moveq #0,d5
.select:
        ifd CF_DELETE_RECORD_SET
        bsr cf_del_set_member
        tst.w d0
        bmi.s .next
        movea.l a5,a0
        bsr cf_del_set_name
        bne cf_del_invalid
        else
        movea.l a5,a0
        movea.l cf_del_context,a1
        bsr read_name_equal
        bne.s .next
        endif
        move.w d6,d1
        lsr.w #3,d1
        lea cf_del_selected,a0
        bset d6,(a0,d1.w)
        addq.w #1,d5
.next: lea 32(a5),a5
        addq.w #1,d6
        cmp.w d7,d6
        blo.s .select
        tst.w d5
        beq cf_del_not_found
        ifnd CF_DELETE_RECORD_SET
        cmpi.w #1,d5
        bne cf_del_corrupt
        endif
        bsr cf_delete_inspect
        bne cf_del_finish
        bsr cf_del_survivors
        bne cf_del_finish
; Two bounded passes: all selected CMI first, then their payloads. Original
; record indices, masks and names remain stable while the live catalog shrinks.
        moveq #0,d5
cf_del_loop_pass:
        moveq #0,d6
        lea CF_TRACK_COPY+32,a5
cf_del_loop_file:
        move.w d6,d1
        lsr.w #3,d1
        lea cf_del_selected,a0
        btst d6,(a0,d1.w)
        beq.s cf_del_loop_next
        move.l 8(a5),d0
        ori.l #$20202020,d0
        cmpi.l #$2E636D69,d0
        seq d0
        tst.w d5
        beq.s .manifest_pass
        tst.b d0
        bne.s cf_del_loop_next
        bra.s .remove
.manifest_pass:
        tst.b d0
        beq.s cf_del_loop_next
.remove:
        bsr cf_del_cancel_check
        bne.s cf_del_finish
delete_before_commit:
        bsr cf_delete_inspect
        bne.s cf_del_finish
        bsr cf_del_survivors
        bne.s cf_del_finish
        move.w #1,cf_delete_attempted
        bsr cf_del_remove_file
        bne.s cf_del_finish
        move.w d6,d1
        lsr.w #3,d1
        lea cf_del_done,a0
        bset d6,(a0,d1.w)
        addq.w #1,cf_del_removed
        bsr cf_delete_inspect
        bne.s cf_del_finish
        bsr cf_del_survivors
        bne.s cf_del_finish
        ifd CF_DELETE_RECORD_SET
; This is a verified completed-prefix count, even when a later file refuses.
        move.w cf_del_removed,BDQ_CONTEXT+BDQ_REMOVED
        endif
cf_del_loop_next:
        lea 32(a5),a5
        addq.w #1,d6
        cmp.w cf_del_record_count,d6
        blo cf_del_loop_file
        addq.w #1,d5
        cmpi.w #2,d5
        blo cf_del_loop_pass
        move.w #1,cf_delete_verified
        bsr.s cf_del_cancel_check
        bra.s cf_del_finish
cf_del_invalid: moveq #CF_DELETE_INVALID,d0
        bra.s cf_del_finish
cf_del_media: moveq #CF_DELETE_MEDIA,d0
        bra.s cf_del_finish
cf_del_corrupt: moveq #CF_DELETE_CORRUPT,d0
        bra.s cf_del_finish
cf_del_not_found: moveq #3,d0
cf_del_finish:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; Cooperative cancellation is deferred only through one file's verification.
cf_del_cancel_check:
        bsr cf_delete_check
        bne.s .return
        moveq #CF_DELETE_CANCEL,d0
        ifd CF_DELETE_RECORD_SET
        tst.l BDQ_CONTEXT+BDQ_CANCEL
        else
        tst.l SAVE_CONTEXT+SAVE_CANCEL
        endif
        bne.s .return
        moveq #0,d0
.return: tst.w d0
        rts

cf_del_snapshot:
        moveq #2,d2
        bsr storage_read_track
        bne.s .return
        movea.l sensi_track_scratch_pointer,a0
        lea 20(a0),a0
        lea CF_DIRECTORY_COPY,a1
        move.w #1535,d1
.copy: move.l (a0)+,(a1)+
        dbf d1,.copy
        moveq #0,d0
.return: tst.w d0
        rts

; Inspector has refreshed the directory cache. Compare exact ordered survivors
; and its zero tail against the immutable confirmed names/sizes, not just a CRC.
cf_del_survivors:
        movem.l d1-d7/a0-a5,-(sp)
        move.w cf_del_record_count,d7
        sub.w cf_del_removed,d7
        cmp.w EDITOR_IO_BASE+64+STORAGE_INSPECT_RECORDS,d7
        bne.s .bad
        lea CF_TRACK_COPY+32,a5
        lea EDITOR_DIRECTORY_BASE,a4
        moveq #0,d6
.record:
        move.w d6,d1
        lsr.w #3,d1
        lea cf_del_done,a0
        btst d6,(a0,d1.w)
        bne.s .skip
        movea.l a5,a0
        moveq #7,d1
.compare: cmpm.l (a0)+,(a4)+
        bne.s .bad
        dbf d1,.compare
.skip: lea 32(a5),a5
        addq.w #1,d6
        cmp.w cf_del_record_count,d6
        blo.s .record
        move.w #150,d1
        sub.w d7,d1
        beq.s .good
        lsl.w #3,d1
        subq.w #1,d1
.tail: tst.l (a4)+
        bne.s .bad
        dbf d1,.tail
.good: moveq #0,d0
        bra.s .return
.bad: moveq #CF_DELETE_MEDIA,d0
.return: movem.l (sp)+,d1-d7/a0-a5
        tst.w d0
        rts

; A5=trusted immutable record. The exact fixed80-byte reader request survives.
; Zero cancellation inside the primitive ensures a returned success means its
; full readback/identity proof completed before this outer loop sees Cancel.
cf_del_remove_file:
        movem.l d1-d7/a0-a6,-(sp)
        lea -80(sp),sp
        lea EDITOR_IO_BASE+64,a0
        movea.l sp,a1
        moveq #19,d1
.save: move.l (a0)+,(a1)+
        dbf d1,.save
        lea EDITOR_IO_BASE+64,a1
        movea.l a5,a0
        moveq #15,d1
.name: move.b (a0)+,d0
        cmpi.b #'A',d0
        blo.s .store
        cmpi.b #'Z',d0
        bhi.s .store
        ori.b #32,d0
.store: move.b d0,(a1)+
        dbf d1,.name
        lea cf_delete_marker+16,a0
        moveq #3,d1
.id: move.l (a0)+,(a1)+
        dbf d1,.id
        moveq #11,d1
.clear: clr.l (a1)+
        dbf d1,.clear
        lea EDITOR_IO_BASE+64,a0
        moveq #4,d0
        jsr EDITOR_BACKEND_ENTRY
        move.l d0,d7
        bne.s .restore
        cmpi.l #1,EDITOR_IO_BASE+64+STORAGE_READ_READY
        beq.s .restore
        moveq #CF_DELETE_VERIFY,d7
.restore:
        movea.l sp,a0
        lea EDITOR_IO_BASE+64,a1
        moveq #19,d1
.context: move.l (a0)+,(a1)+
        dbf d1,.context
        lea 80(sp),sp
        move.l d7,d0
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

cf_del_compare_directories:
        lea CF_DIRECTORY_COPY,a0
        lea CF_TRACK_COPY,a1
        move.w #1535,d1
.compare: cmpm.l (a0)+,(a1)+
        bne.s .return
        dbf d1,.compare
.return: rts

; Original bounded name and record-set validators follow unchanged.
        include "../storage/delete_names.s"
delete_end:
        ifgt CF_TRACK_COPY+6144-EDITOR_READBACK_BASE-EDITOR_READBACK_BYTES
        fail "WHD delete snapshot exceeds existing readback"
        endif
