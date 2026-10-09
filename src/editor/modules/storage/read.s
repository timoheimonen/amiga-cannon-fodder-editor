; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Fields that the Slave's file service publishes in serializer WORK.
read_context equ EDITOR_SERIAL_WORK_BASE
read_directory_crc equ EDITOR_SERIAL_WORK_BASE+8
read_marker_data equ EDITOR_SERIAL_WORK_BASE+16
        section .text,code
        xdef storage_read_start,storage_read_entry,storage_read_end
        xdef storage_inspect_disk,storage_read_track
        xdef storage_read_before_final,storage_read_before_publish
storage_read_start:
storage_read_entry:
        moveq #2,d0
        bra.s whd_reader_call
storage_inspect_disk:
        moveq #1,d0
whd_reader_call:
        cmpa.l #EDITOR_IO_BASE+64,a0
        bne.s whd_reader_invalid
storage_read_before_final:
        jsr EDITOR_BACKEND_ENTRY
storage_read_before_publish:
        tst.w d0
        rts
whd_reader_invalid:
        moveq #STORAGE_READ_INVALID,d0
        rts

; This API exposes only a normalized catalog snapshot at native scratch+20.
; It never supplies file contents. The caller must own the initialized native
; track scratch.
; Preserve its80-byte request while inspection refreshes the directory view.
storage_read_track:
        movem.l d1-d7/a0-a6,-(sp)
        moveq #STORAGE_READ_INVALID,d0
        cmpi.w #2,d2
        bne .return
        move.l sensi_track_scratch_pointer,d1
        beq .return
        btst #0,d1
        bne .return
        addi.l #20+6144,d1
        bcs .return
        cmpi.l #$100000,d1
        bhi.s .return
        lea -80(sp),sp
        lea EDITOR_IO_BASE+64,a0
        movea.l sp,a1
        moveq #19,d1
.save:  move.l (a0)+,(a1)+
        dbf d1,.save
        lea EDITOR_IO_BASE+64,a0
        bsr.s storage_inspect_disk
        move.l d0,d7
        bne.s .restore
        movea.l sensi_track_scratch_pointer,a1
        lea 20(a1),a1
        move.w #1535,d1
.zero:  clr.l (a1)+
        dbf d1,.zero
        movea.l sensi_track_scratch_pointer,a1
        lea 20(a1),a1
        move.l #$63666469,(a1)
        move.w #$736b,4(a1)
        move.w EDITOR_IO_BASE+64+STORAGE_INSPECT_RECORDS,26(a1)
        lea 32(a1),a1
        lea EDITOR_DIRECTORY_BASE,a0
        move.w #1199,d1
.copy:  move.l (a0)+,(a1)+
        dbf d1,.copy
.restore:
        movea.l sp,a0
        lea EDITOR_IO_BASE+64,a1
        moveq #19,d1
.request: move.l (a0)+,(a1)+
        dbf d1,.request
        lea 80(sp),sp
        move.l d7,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
read_name_equal:
        moveq   #14,d1
.compare:
        move.b  (a0)+,d0
        move.b  (a1)+,d2
        ori.b   #$20,d0
        ori.b   #$20,d2
        cmp.b   d2,d0
        bne.s   .done
        tst.b   -1(a0)
        beq.s   .done
        dbf     d1,.compare
        moveq   #1,d0
.done:
        rts

read_valid_name:
        moveq   #14,d1
.character:
        move.b  (a0)+,d0
        beq.s   .done
        cmpi.b  #'.',d0
        beq.s   .next
        cmpi.b  #'-',d0
        beq.s   .next
        cmpi.b  #'_',d0
        beq.s   .next
        cmpi.b  #'0',d0
        blo.s   .bad
        cmpi.b  #'9',d0
        bls.s   .next
        ori.b   #$20,d0
        cmpi.b  #'a',d0
        blo.s   .bad
        cmpi.b  #'z',d0
        bhi.s   .bad
.next:
        dbf     d1,.character
.bad:
        moveq   #1,d0
.done:
        rts

read_valid_target:
        moveq   #7,d1
        cmpi.l  #$2e636d69,8(a0)
        bne.s   .phase
        tst.b   12(a0)
        beq.s   .hex_start
.phase:
        moveq   #9,d1
        cmpi.l  #$2e6d6170,10(a0)
        beq.s   .phase_end
        cmpi.l  #$2e737074,10(a0)
        bne.s   .bad
.phase_end:
        tst.b   14(a0)
        bne.s   .bad
.hex_start:
        movea.l a0,a1
.hex:
        move.b  (a1)+,d0
        cmpi.b  #'0',d0
        blo.s   .bad
        cmpi.b  #'9',d0
        bls.s   .next
        cmpi.b  #'a',d0
        blo.s   .bad
        cmpi.b  #'f',d0
        bhi.s   .bad
.next:
        dbf     d1,.hex
        moveq   #0,d0
        rts
.bad:
        moveq   #STORAGE_READ_INVALID,d0
        rts

; Reflected IEEE CRC32 over a positive bounded byte count in D1, starting A0.
; The Slave's table-driven CRC computes it; A0 ends after the bytes and
; D1-D3 are clobbered.
read_crc32:
        moveq   #CRC_OPERATION,d0
        jmp     EDITOR_BACKEND_ENTRY

storage_read_end:
