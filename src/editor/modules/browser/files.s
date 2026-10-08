; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Bounded catalog classification and record selection under an open delete guard.

BF_REQUEST       equ BDQ_CONTEXT
BF_OPERATION     equ BF_REQUEST+8
BF_NAME          equ BF_REQUEST+16
BF_DISK_ID       equ BF_REQUEST+32
BF_DIRECTORY_CRC equ BF_REQUEST+48
BF_MISSION_ID    equ BF_REQUEST+52
BF_SELECTED_COUNT equ BF_REQUEST+56
BF_GENERATION_COUNT equ BF_REQUEST+58
BF_RECORD_COUNT  equ BF_REQUEST+80
BF_CMI_COUNT     equ BF_REQUEST+82
BF_RECOVERY_COUNT equ BF_REQUEST+84
BF_SCAN_INDEX    equ BF_REQUEST+86
BF_READY         equ BF_REQUEST+88
BF_SNAPSHOT      equ BDQ_SNAPSHOT
BF_PROTECTED     equ BDQ_PROTECTED
BF_SELECTED      equ BDQ_SELECTED
BF_RECOVERY      equ BDQ_RECOVERY
BF_METADATA      equ BDQ_RECORDS
BF_VIEW_INDICES  equ BDQ_VIEW
BF_END           equ BDQ_VIEW+300
BF_PARSER        equ EDITOR_READBACK_BASE+4096
BF_FOREIGN       equ 0
BF_PHASE         equ 1
BF_DAMAGED       equ 2
BF_VALID         equ 3

        xdef browser_files_classify,browser_files_select
        xdef browser_files_compare_snapshot,browser_files_title,browser_files_end

; Requires an open BDQ1 adapter: exact CFDI pinned and guard live.
; The adapter checks retain IRQ/identity authority; this routine only reads.
; All 6144 snapshot bytes remain immutable until explicit caller refresh.
browser_files_classify:
        movem.l d1-d7/a0-a6,-(sp)
        clr.w BF_READY
        clr.w BF_RECORD_COUNT
        clr.w BF_CMI_COUNT
        clr.w BF_RECOVERY_COUNT
        clr.w BF_SELECTED_COUNT
        clr.w BF_GENERATION_COUNT
        clr.l BF_MISSION_ID
        lea BF_PROTECTED,a0
        move.w #(BF_END-BF_PROTECTED)/4-1,d0
.clear:
        clr.l (a0)+
        dbf d0,.clear
        bsr browser_delete_identity
        bne .return
        moveq #2,d2
        bsr storage_read_track
        tst.w d0
        bne .return
        movea.l sensi_track_scratch_pointer,a0
        lea 20(a0),a0
        lea BF_SNAPSHOT,a1
        move.w #6144/4-1,d1
.snapshot:
        move.l (a0)+,(a1)+
        dbf d1,.snapshot
        lea BF_SNAPSHOT,a0
        move.l #6144,d1
        bsr read_crc32
        cmp.l BF_DIRECTORY_CRC,d0
        bne .media
        move.l BF_SNAPSHOT+24,d0
        beq .corrupt
        cmpi.l #150,d0
        bhi .corrupt
        move.w d0,BF_RECORD_COUNT
        moveq #0,d6
.record:
        move.w d6,BF_SCAN_INDEX
        move.w d6,d0
        bsr bf_record
        lea STORAGE_CONTEXT,a1
        bsr bf_copy_name
        lea STORAGE_CONTEXT,a0
        bsr read_valid_target
        tst.w d0
        bne.s .foreign
        lea STORAGE_CONTEXT,a0
        cmpi.l #$2E636D69,8(a0)
        beq.s .manifest
        move.b #BF_PHASE,5(a2)
        bra.s .next
.foreign:
        lea BF_PROTECTED,a1
        move.w d6,d0
        bsr bf_set_bit
        bra.s .next
.manifest:
        move.b #BF_DAMAGED,5(a2)
        addq.w #1,BF_CMI_COUNT
        move.w d6,d0
        bsr bf_record
        move.l 28(a0),d5
        cmpi.l #17,d5
        blo.s .next
        cmpi.l #4096,d5
        bhi.s .next
        bsr bf_read_manifest
        bne .return
        lea EDITOR_READBACK_BASE,a0
        move.l d5,d0
        lea STORAGE_CONTEXT,a1
        moveq #0,d1
        lea EDITOR_SERIAL_WORK_BASE,a2
        lea BF_PARSER,a3
        bsr cfmi_parse
        tst.w d0
        bne.s .next
        move.w d6,d0
        bsr bf_record
        move.l EDITOR_SERIAL_WORK_BASE+CFMD_ID,(a2)
        move.b EDITOR_SERIAL_WORK_BASE+CFMD_PHASE_COUNT,4(a2)
        move.b #BF_VALID,5(a2)
.next:
        addq.w #1,d6
        cmp.w BF_RECORD_COUNT,d6
        blo .record
; Protect valid manifests and only their exact schema-derived dependencies.
        moveq #0,d6
.references:
        move.w d6,d0
        bsr bf_record
        cmpi.b #BF_VALID,5(a2)
        bne.s .reference_next
        movea.l a0,a4
        moveq #0,d5
        move.b 4(a2),d5
        lea BF_PROTECTED,a1
        move.w d6,d0
        bsr bf_set_bit
        moveq #0,d7
.dependency:
        move.w d7,d0
        bsr bf_record
        cmpi.b #BF_PHASE,5(a2)
        bne.s .dependency_next
        movea.l a4,a1
        bsr bf_prefix_equal
        bne.s .dependency_next
        move.b 8(a0),d0
        cmpi.b #'0',d0
        bne.s .dependency_next
        moveq #0,d0
        move.b 9(a0),d0
        subi.b #'0',d0
        cmp.w d5,d0
        bhs.s .dependency_next
        lea BF_PROTECTED,a1
        move.w d7,d0
        bsr bf_set_bit
.dependency_next:
        addq.w #1,d7
        cmp.w BF_RECORD_COUNT,d7
        blo.s .dependency
.reference_next:
        addq.w #1,d6
        cmp.w BF_RECORD_COUNT,d6
        blo.s .references
        moveq #0,d6
.recovery:
        move.w d6,d0
        lea BF_PROTECTED,a1
        bsr bf_test_bit
        bne.s .recover_next
        lea BF_RECOVERY,a1
        bsr bf_set_bit
.recover_next:
        addq.w #1,d6
        cmp.w BF_RECORD_COUNT,d6
        blo.s .recovery
        lea BF_RECOVERY,a5
        bsr bf_count_groups
        move.w d0,BF_RECOVERY_COUNT
        bsr bf_revalidate_snapshot
        bne.s .return
        move.w #1,BF_READY
        moveq #0,d0
        bra.s .return
.media:
        moveq #11,d0
        bra.s .return
.corrupt:
        moveq #12,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; Prepare only a projected title, not confirmation or mutation authority.
; UI accepts no persistent pointer. A final marker/snapshot check follows copy.
browser_files_title:
        movem.l d1-d7/a0-a6,-(sp)
        moveq #10,d0
        cmpi.w #1,BF_READY
        bne .return
        bsr browser_delete_check
        bne .return
        cmpi.w #1,BF_OPERATION
        bne .generation
        moveq #0,d6
.find:
        move.w d6,d0
        bsr bf_record
        lea BF_NAME,a1
        bsr bf_name_equal
        beq.s .found
        addq.w #1,d6
        cmp.w BF_RECORD_COUNT,d6
        blo.s .find
        moveq #10,d0
        bra.s .return
.found:
        cmpi.b #BF_VALID,5(a2)
        bne.s .generation
        move.l 28(a0),d5
        lea STORAGE_CONTEXT,a1
        bsr bf_copy_name
        bsr.s bf_read_manifest
        bne.s .return
        lea EDITOR_READBACK_BASE,a0
        move.l d5,d0
        lea STORAGE_CONTEXT,a1
        moveq #0,d1
        lea EDITOR_SERIAL_WORK_BASE,a2
        lea BF_PARSER,a3
        bsr cfmi_parse
        tst.w d0
        bne.s .changed
        move.w d6,d0
        bsr bf_record
        move.l (a2),d0
        cmp.l EDITOR_SERIAL_WORK_BASE+CFMD_ID,d0
        bne.s .changed
        move.b 4(a2),d0
        cmp.b EDITOR_SERIAL_WORK_BASE+CFMD_PHASE_COUNT,d0
        bne.s .changed
        lea EDITOR_SERIAL_WORK_BASE+CFMD_TITLE,a0
        moveq #1,d0
        bra.s .prepare
.generation:
        moveq #0,d0
.prepare:
        bsr browser_files_ui_prepare
        tst.w d0
        bne.s .return
        bsr.s bf_revalidate_snapshot
        bra.s .return
.changed:
        moveq #11,d0
.return:
        tst.w d0
        beq.s .valid_return
        clr.w BF_READY
        clr.w BF_SELECTED_COUNT
        clr.w BF_GENERATION_COUNT
.valid_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; The folded name is already copied into STORAGE_CONTEXT; D5 exact file size.
bf_read_manifest:
        movem.l d1-d7/a0-a6,-(sp)
        bsr browser_delete_check
        bne.s .return
        lea STORAGE_CONTEXT+16,a1
        lea BF_DISK_ID,a0
        moveq #3,d0
.identity:
        move.l (a0)+,(a1)+
        dbf d0,.identity
        move.l d5,(a1)+
        move.l #4096,(a1)+
        moveq #9,d0
.request:
        clr.l (a1)+
        dbf d0,.request
        lea STORAGE_CONTEXT,a0
        bsr storage_read_entry
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

bf_revalidate_snapshot:
        bsr browser_delete_identity
        bne.s .return
        moveq #2,d2
        bsr storage_read_track
        tst.w d0
        bne.s .return
        movea.l sensi_track_scratch_pointer,a0
        lea 20(a0),a0
        bsr bf_compare_snapshot
        bne.s .return
        bsr browser_delete_check
.return:
        tst.w d0
        rts

; BDQ1 operation 1=DELETE selected CMI, 2=RECOVER selected unreferenced group.
; Zero ID is valid. Kind, never the numeric ID, grants same-mission authority.
browser_files_select:
        movem.l d1-d7/a0-a6,-(sp)
        clr.w BF_SELECTED_COUNT
        clr.w BF_GENERATION_COUNT
        clr.l BF_MISSION_ID
        lea BF_SELECTED,a0
        moveq #4,d0
.clear:
        clr.l (a0)+
        dbf d0,.clear
        moveq #10,d0
        cmpi.w #1,BF_READY
        bne .return
        cmpi.w #1,BF_OPERATION
        beq.s .find
        cmpi.w #2,BF_OPERATION
        bne .return
.find:
        moveq #0,d6
.lookup:
        move.w d6,d0
        bsr bf_record
        lea BF_NAME,a1
        bsr bf_name_equal
        beq.s .found
        addq.w #1,d6
        cmp.w BF_RECORD_COUNT,d6
        blo.s .lookup
        bra .invalid
.found:
        movea.l a0,a4
        moveq #0,d4
        move.b 5(a2),d4
        cmpi.w #2,BF_OPERATION
        beq.s .recover_input
        cmpi.w #BF_DAMAGED,d4
        blo .invalid
        move.l (a2),BF_MISSION_ID
        bra.s .reset_protected
.recover_input:
        lea BF_RECOVERY,a1
        move.w d6,d0
        bsr bf_test_bit
        beq .invalid
.reset_protected:
; Rebuild on every selection; an earlier authorized clear must not leak forward.
        lea BF_PROTECTED,a1
        moveq #4,d0
.zero_protected:
        clr.l (a1)+
        dbf d0,.zero_protected
        moveq #0,d7
.protect:
        move.w d7,d0
        lea BF_RECOVERY,a1
        bsr bf_test_bit
        bne.s .protect_next
        lea BF_PROTECTED,a1
        bsr bf_set_bit
.protect_next:
        addq.w #1,d7
        cmp.w BF_RECORD_COUNT,d7
        blo.s .protect
        cmpi.w #2,BF_OPERATION
        beq.s .one_prefix
        cmpi.w #BF_VALID,d4
        bne.s .one_prefix
; A valid selected CMI authorizes every valid CMI carrying that same ID.
        moveq #0,d6
.mission:
        move.w d6,d0
        bsr bf_record
        cmpi.b #BF_VALID,5(a2)
        bne.s .mission_next
        move.l (a2),d0
        cmp.l BF_MISSION_ID,d0
        bne.s .mission_next
        movea.l a0,a4
        bsr.s bf_select_prefix
.mission_next:
        addq.w #1,d6
        cmp.w BF_RECORD_COUNT,d6
        blo.s .mission
        bra.s .count
.one_prefix:
        bsr.s bf_select_prefix
.count:
        lea BF_SELECTED,a5
        bsr bf_count_groups
        move.w d0,BF_GENERATION_COUNT
        moveq #10,d0
        tst.w BF_SELECTED_COUNT
        beq.s .return
        bsr browser_delete_check
        ifd LIVE_FILES_CONTEXT
        bne.s .return
        bsr live_files_protect_source
        endif
        bra.s .return
.invalid:
        moveq #10,d0
.return:
        tst.w d0
        beq.s .valid_return
        clr.w BF_READY
        clr.w BF_SELECTED_COUNT
        clr.w BF_GENERATION_COUNT
.valid_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; A4=selected raw prefix; operation2 additionally restricts to recovery bits.
bf_select_prefix:
        moveq #0,d7
.record:
        move.w d7,d0
        bsr bf_record
        tst.b 5(a2)
        beq.s .next
        movea.l a4,a1
        bsr bf_prefix_equal
        bne.s .next
        cmpi.w #2,BF_OPERATION
        bne.s .select
        move.w d7,d0
        lea BF_RECOVERY,a1
        bsr bf_test_bit
        beq.s .next
.select:
        move.w d7,d0
        lea BF_SELECTED,a1
        bsr bf_test_bit
        bne.s .next
        bsr bf_set_bit
        lea BF_PROTECTED,a1
        bsr bf_clear_bit
        addq.w #1,BF_SELECTED_COUNT
.next:
        addq.w #1,d7
        cmp.w BF_RECORD_COUNT,d7
        blo.s .record
        rts

; A5=record bitmap. Return distinct selected prefixes, preserving outer loops.
bf_count_groups:
        movem.l d1-d7/a0-a4,-(sp)
        moveq #0,d5
        moveq #0,d6
.record:
        move.w d6,d0
        movea.l a5,a1
        bsr bf_test_bit
        beq.s .next
        bsr.s bf_record
        movea.l a0,a4
        moveq #0,d7
.previous:
        cmp.w d6,d7
        bhs.s .new
        move.w d7,d0
        movea.l a5,a1
        bsr bf_test_bit
        beq.s .previous_next
        bsr.s bf_record
        movea.l a4,a1
        bsr.s bf_prefix_equal
        beq.s .next
.previous_next:
        addq.w #1,d7
        bra.s .previous
.new:
        addq.w #1,d5
.next:
        addq.w #1,d6
        cmp.w BF_RECORD_COUNT,d6
        blo.s .record
        move.w d5,d0
        movem.l (sp)+,d1-d7/a0-a4
        rts

; D0.w index -> A0 raw directory record, A2 metadata; D0 clobbered only.
bf_record:
        andi.l #$FFFF,d0
        lsl.w #5,d0
        lea BF_SNAPSHOT+32,a0
        adda.w d0,a0
        lsr.w #5,d0
        mulu.w #6,d0
        lea BF_METADATA,a2
        adda.w d0,a2
        rts

; Copy/fold exactly16 input bytes into owned request without modifying source.
bf_copy_name:
        movem.l d0-d1/a0-a1,-(sp)
        moveq #15,d1
.byte:
        move.b (a0)+,d0
        cmpi.b #'A',d0
        blo.s .copy
        cmpi.b #'Z',d0
        bhi.s .copy
        ori.b #32,d0
.copy:
        move.b d0,(a1)+
        dbf d1,.byte
        movem.l (sp)+,d0-d1/a0-a1
        rts

; Both pointer arguments preserved. Native name folding uses ASCII bit5.
bf_name_equal:
        moveq #14,d1
        bra.s bf_equal
bf_prefix_equal:
        moveq #7,d1
bf_equal:
        movem.l d0/d2/a0-a1,-(sp)
.byte:
        move.b (a0)+,d0
        move.b (a1)+,d2
        ori.b #$20,d0
        ori.b #$20,d2
        cmp.b d2,d0
        bne.s .done
        cmpi.b #$20,d0
        beq.s .done
        dbf d1,.byte
        moveq #0,d0
.done:
        movem.l (sp)+,d0/d2/a0-a1
        rts

; LSB-first bytes: record i uses byte i>>3, bit i&7. D0 is unchanged.
bf_test_bit:
        move.w d0,d1
        lsr.w #3,d1
        btst d0,0(a1,d1.w)
        rts
bf_set_bit:
        move.w d0,d1
        lsr.w #3,d1
        bset d0,0(a1,d1.w)
        rts
bf_clear_bit:
        move.w d0,d1
        lsr.w #3,d1
        bclr d0,0(a1,d1.w)
        rts

browser_files_compare_snapshot:
        movem.l d1-d7/a0-a6,-(sp)
        moveq #10,d0
        cmpa.l #EDITOR_READBACK_BASE,a0
        bne.s .return
        bsr.s bf_compare_snapshot
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
bf_compare_snapshot:
        lea BF_SNAPSHOT,a1
        move.w #6144/4-1,d1
.long:
        cmpm.l (a0)+,(a1)+
        bne.s .changed
        dbf d1,.long
        moveq #0,d0
        rts
.changed:
        moveq #11,d0
        rts

browser_files_end:
        ifgt BF_END-EDITOR_READBACK_BASE-EDITOR_READBACK_BYTES
        fail "Browser catalog exceeds readback"
        endif
