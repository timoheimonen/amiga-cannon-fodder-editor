; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

CF_PREFLIGHT_REQUEST equ SAVE_CONTEXT
CF_PREFLIGHT_DISK_ID equ SAVE_CONTEXT+SAVE_DISK_ID
CF_PREFLIGHT_GENERATION equ SAVE_CONTEXT+SAVE_GENERATION
CF_PREFLIGHT_CANCEL equ SAVE_CONTEXT+SAVE_CANCEL
CF_PREFLIGHT_RESULT equ SAVE_PREFLIGHT_RESULT
CF_PREFLIGHT_INSPECT equ EDITOR_IO_BASE+64
CF_PREFLIGHT_DIRECTORY equ EDITOR_READBACK_BASE
CF_PREFLIGHT_TRACK equ EDITOR_READBACK_BASE+6144
CF_PREFLIGHT_SEEN equ EDITOR_READBACK_BASE+12288
CF_PREFLIGHT_STATE equ CF_PREFLIGHT_SEEN+320
cf_preflight_directory_crc equ CF_PREFLIGHT_STATE+8
cf_preflight_marker equ CF_PREFLIGHT_STATE+12
cf_preflight_count equ CF_PREFLIGHT_STATE+76
cf_preflight_generation equ CF_PREFLIGHT_STATE+80
cf_preflight_token equ CF_PREFLIGHT_STATE+84
cf_preflight_free equ CF_PREFLIGHT_STATE+92
CF_PREFLIGHT_WORK_END equ CF_PREFLIGHT_STATE+96
        xdef cf_preflight_start,cf_preflight_entry,cf_preflight_end
        xdef cf_preflight_before_scan,cf_preflight_before_final,cf_preflight_before_publish
        xdef cf_preflight_track,cf_preflight_after_qualification
        xdef CF_PREFLIGHT_DIRECTORY
cf_preflight_start:
; Same fixed SVR1 request and result ABI. Only generation changes on success.
; File inspection checks sizes, names and the CFDI marker twice, while the
; immutable normalized catalog occupies existing READBACK.
cf_preflight_entry:
        movem.l d1-d7/a0-a6,-(sp)
        moveq #STORAGE_READ_INVALID,d0
        cmpa.l #CF_PREFLIGHT_REQUEST,a0
        bne cf_preflight_registers
        lea CF_PREFLIGHT_RESULT,a1
        moveq #SAVE_PREFLIGHT_BYTES/4-1,d1
.clear: clr.l (a1)+
        dbf d1,.clear
        cmpi.l #SAVE_MAGIC,SAVE_CONTEXT
        bne cf_preflight_finish
        cmpi.w #SAVE_ABI,SAVE_CONTEXT+4
        bne cf_preflight_finish
        cmpi.w #SAVE_CONTEXT_BYTES,SAVE_CONTEXT+6
        bne cf_preflight_finish
        tst.w native_gameplay_active
        bne cf_preflight_finish
        move.w sr,d1
        andi.w #$0700,d1
        cmpi.w #$0600,d1
        bhs cf_preflight_finish
        move.l CF_PREFLIGHT_DISK_ID,d1
        or.l CF_PREFLIGHT_DISK_ID+4,d1
        or.l CF_PREFLIGHT_DISK_ID+8,d1
        or.l CF_PREFLIGHT_DISK_ID+12,d1
        beq cf_preflight_finish
        bsr cf_preflight_inspect
        bne cf_preflight_finish
cf_preflight_after_qualification:
        move.l CF_PREFLIGHT_INSPECT+STORAGE_INSPECT_DIRECTORY_CRC,cf_preflight_directory_crc
        move.w CF_PREFLIGHT_INSPECT+STORAGE_INSPECT_RECORDS,cf_preflight_count
        move.l CF_PREFLIGHT_INSPECT+STORAGE_INSPECT_FREE_BYTES,d0
        divu #510,d0
        move.w d0,cf_preflight_free
        lea read_marker_data,a0
        lea cf_preflight_marker,a1
        moveq #15,d1
.marker: move.l (a0)+,(a1)+
        dbf d1,.marker
        move.l CF_PREFLIGHT_GENERATION,cf_preflight_generation
        moveq #2,d2
        bsr cf_preflight_track
        bne cf_preflight_finish
        lea CF_PREFLIGHT_TRACK,a0
        move.l #6144,d1
        bsr read_crc32
        cmp.l cf_preflight_directory_crc,d0
        bne cf_preflight_media
        lea CF_PREFLIGHT_TRACK,a0
        lea CF_PREFLIGHT_DIRECTORY,a1
        move.w #1535,d1
.snapshot: move.l (a0)+,(a1)+
        dbf d1,.snapshot
cf_preflight_before_scan:
        bsr cf_preflight_choose_generation
cf_preflight_before_final:
        moveq #2,d2
        bsr cf_preflight_track
        bne cf_preflight_finish
        lea CF_PREFLIGHT_DIRECTORY,a0
        lea CF_PREFLIGHT_TRACK,a1
        move.w #1535,d1
.compare: cmpm.l (a0)+,(a1)+
        bne.s cf_preflight_media
        dbf d1,.compare
        bsr cf_preflight_inspect
        bne.s cf_preflight_finish
        move.l CF_PREFLIGHT_INSPECT+STORAGE_INSPECT_DIRECTORY_CRC,d0
        cmp.l cf_preflight_directory_crc,d0
        bne.s cf_preflight_media
        lea read_marker_data,a0
        lea cf_preflight_marker,a1
        moveq #15,d1
.identity: cmpm.l (a0)+,(a1)+
        bne.s cf_preflight_media
        dbf d1,.identity
cf_preflight_before_publish:
        bsr.s cf_preflight_check
        bne.s cf_preflight_finish
        move.w #150,d0
        sub.w cf_preflight_count,d0
        move.w d0,CF_PREFLIGHT_RESULT+SAVE_FREE_RECORDS
        move.w cf_preflight_free,CF_PREFLIGHT_RESULT+SAVE_FREE_SECTORS
        move.w cf_preflight_count,CF_PREFLIGHT_RESULT+SAVE_LIVE_RECORDS
        move.l cf_preflight_directory_crc,CF_PREFLIGHT_RESULT+SAVE_DIRECTORY_CRC
        move.l cf_preflight_generation,CF_PREFLIGHT_GENERATION
        move.l #1,CF_PREFLIGHT_RESULT+SAVE_PREFLIGHT_READY
        moveq #0,d0
        bra.s cf_preflight_finish
cf_preflight_media:
        moveq #STORAGE_READ_MEDIA,d0
cf_preflight_finish:
        move.w d0,CF_PREFLIGHT_RESULT+SAVE_PREFLIGHT_STATUS
cf_preflight_registers:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
cf_preflight_check:
        moveq #STORAGE_READ_CANCELLED,d0
        tst.l CF_PREFLIGHT_CANCEL
        bne.s .done
        moveq #0,d0
.done:  tst.w d0
        rts
cf_preflight_inspect:
        bsr.s cf_preflight_check
        bne.s .done
        move.l CF_PREFLIGHT_CANCEL,CF_PREFLIGHT_INSPECT+STORAGE_READ_CANCEL
        lea CF_PREFLIGHT_INSPECT,a0
        bsr storage_inspect_disk
        bne.s .done
        lea CF_PREFLIGHT_INSPECT+STORAGE_INSPECT_DISK_ID,a0
        lea CF_PREFLIGHT_DISK_ID,a1
        moveq #3,d1
.id:    cmpm.l (a0)+,(a1)+
        bne.s .media
        dbf d1,.id
        bra.s cf_preflight_check
.media: moveq #STORAGE_READ_MEDIA,d0
.done:  tst.w d0
        rts
cf_preflight_track:
        movem.l d1-d7/a0-a6,-(sp)
        bsr.s cf_preflight_check
        bne.s .done
        bsr storage_read_track
        bne.s .done
        bsr.s cf_preflight_check
        bne.s .done
        movea.l sensi_track_scratch_pointer,a0
        lea 20(a0),a0
        lea CF_PREFLIGHT_TRACK,a1
        move.w #1535,d1
.copy:  move.l (a0)+,(a1)+
        dbf d1,.copy
        moveq #0,d0
.done:  movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; Bounded generation-prefix reservation. At most150 records
; can exclude150 candidate prefixes; no wrapping search depends on payload data.
; A zero hint (a new mission or Save as) starts at the next block of 65,536
; generations after the highest one in Custom; a Save passes its own
; generation + 1. File names sort by generation, so the lists keep missions
; in the order they were made and a saved mission keeps its place.
cf_preflight_choose_generation:
        tst.l cf_preflight_generation
        bne.s .candidate
        bsr.s cf_preflight_block
        move.l d0,cf_preflight_generation
.candidate:
        move.l cf_preflight_generation,d0
        lea cf_preflight_token,a0
        moveq #7,d1
.hex:   rol.l #4,d0
        move.w d0,d2
        andi.w #15,d2
        addi.b #'0',d2
        cmpi.b #'9',d2
        bls.s .digit
        addq.b #7,d2
        ori.b #$20,d2
.digit: move.b d2,(a0)+
        dbf d1,.hex
        lea CF_PREFLIGHT_DIRECTORY+32,a5
        move.w cf_preflight_count,d6
.record:
        lea cf_preflight_token,a0
        movea.l a5,a1
        moveq #7,d1
.prefix: move.b (a1)+,d0
        ori.b #$20,d0
        cmp.b (a0)+,d0
        bne.s .next
        dbf d1,.prefix
        addq.l #1,cf_preflight_generation
        bra.s .candidate
.next:  lea 32(a5),a5
        subq.w #1,d6
        bne.s .record
        rts

; D0.l = the first generation of the block after the highest name in the
; catalog that starts with eight hexadecimal digits, 0 when there is none.
cf_preflight_block:
        movem.l d1-d6/a0-a1,-(sp)
        moveq #0,d4
        moveq #0,d5
        lea CF_PREFLIGHT_DIRECTORY+32,a0
        move.w cf_preflight_count,d6
        beq.s .done
.record:
        movea.l a0,a1
        moveq #0,d0
        moveq #7,d1
.digit: move.b (a1)+,d2
        ori.b #$20,d2
        subi.b #'0',d2
        cmpi.b #9,d2
        bls.s .value
        subi.b #'a'-'0'-10,d2
        cmpi.b #10,d2
        blo.s .skip
        cmpi.b #15,d2
        bhi.s .skip
.value: lsl.l #4,d0
        or.b d2,d0
        dbf d1,.digit
        moveq #1,d5
        cmp.l d4,d0
        bls.s .skip
        move.l d0,d4
.skip:  lea 32(a0),a0
        subq.w #1,d6
        bne.s .record
.done:  moveq #0,d0
        tst.w d5
        beq.s .out
        move.l d4,d0
        clr.w d0
        addi.l #$10000,d0
.out:   movem.l (sp)+,d1-d6/a0-a1
        rts
cf_preflight_end:
        ifgt CF_PREFLIGHT_WORK_END-EDITOR_READBACK_BASE-EDITOR_READBACK_BYTES
        fail "WHD preflight exceeds existing scratch"
        endif
