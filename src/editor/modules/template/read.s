; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        section .text,code
        xdef template_read_file,template_read_end,template_read_track
        xdef template_read_before_copy,template_read_before_verify

TR_SEEN         equ EDITOR_SERIAL_WORK_BASE
TR_NAME         equ EDITOR_SERIAL_WORK_BASE+320
TR_RECORD       equ EDITOR_SERIAL_WORK_BASE+336
TR_LENGTH       equ EDITOR_SERIAL_WORK_BASE+368
TR_REMAINING    equ EDITOR_SERIAL_WORK_BASE+372
TR_DESTINATION  equ EDITOR_SERIAL_WORK_BASE+376
TR_DIRECTORY_CRC equ EDITOR_SERIAL_WORK_BASE+380
TR_TRACK        equ EDITOR_SERIAL_WORK_BASE+384
TR_SECTOR       equ EDITOR_SERIAL_WORK_BASE+386
TR_CACHED       equ EDITOR_SERIAL_WORK_BASE+388
TR_BYTE         equ EDITOR_SERIAL_WORK_BASE+390
TR_STARTED      equ EDITOR_SERIAL_WORK_BASE+391
TR_KEEP         equ EDITOR_SERIAL_WORK_BASE+392
TR_KIND         equ EDITOR_SERIAL_WORK_BASE+394
TR_DRIVE        equ EDITOR_SERIAL_WORK_BASE+396
TR_CANCEL       equ EDITOR_SERIAL_WORK_BASE+398

; D0.w=original map number 1..72, D1.w=0 MAP / 1 SPT. Drive already selected.
; Return positive stored byte count, or -1 arguments, -2 media, -3 file bounds,
; -4 cancelled, -5 absent, -6 native read failure. Preserve D1-D7/A0-A6/SP/SR
; control. Own READBACK and WORK[0,400); failed bytes are not authoritative.
; The caller owns disk selection, UI, custom identity and authored publication.
template_read_file:
        movem.l d1-d7/a0-a6,-(sp)
        clr.b TR_STARTED
        clr.w TR_CANCEL
        cmpi.w #1,d0
        blo tr_bad_argument
        cmpi.w #72,d0
        bhi tr_bad_argument
        cmpi.w #1,d1
        bhi tr_bad_argument
        move.w d1,TR_KIND
        move.w sensi_selected_drive,d2
        cmpi.w #3,d2
        bhi tr_bad_argument
        move.w d2,TR_DRIVE
        lea TR_NAME+PCREL(pc),a0
        move.l #$6D61706D,(a0)+
        andi.l #$FFFF,d0
        divu #10,d0
        tst.w d0
        beq.s .ones
        addi.b #'0',d0
        move.b d0,(a0)+
.ones:
        swap d0
        addi.b #'0',d0
        move.b d0,(a0)+
        tst.w d1
        bne.s .spt_name
        move.b #'.',(a0)+
        move.b #'m',(a0)+
        move.b #'a',(a0)+
        move.b #'p',(a0)+
        bra.s .name_end
.spt_name:
        move.b #'.',(a0)+
        move.b #'s',(a0)+
        move.b #'p',(a0)+
        move.b #'t',(a0)+
.name_end:
        clr.b (a0)
        bsr tr_cancel_check
        bne tr_return
        move.w sensi_keep_drive_selected,TR_KEEP
        move.w #1,sensi_keep_drive_selected
        move.b #1,TR_STARTED
        moveq #2,d2
        bsr template_read_track
        bne tr_return
        movea.l sensi_track_scratch_pointer,a4
        lea 20(a4),a4
        cmpi.l #$53656E73,(a4)
        bne tr_bad_media
        cmpi.l #$69206469,4(a4)
        bne tr_bad_media
        cmpi.w #$736B,8(a4)
        bne tr_bad_media
        move.l 24(a4),d7
        beq tr_bad_file
        cmpi.l #EDITOR_DIRECTORY_RECORDS,d7
        bhi tr_bad_file
        movea.l a4,a0
        move.l #5632,d1
        bsr read_crc32
        move.l d0,TR_DIRECTORY_CRC
        moveq #0,d6
        lea 32(a4),a4
.find:
        lea TR_NAME+PCREL(pc),a0
        movea.l a4,a1
        moveq #14,d2
.compare:
        move.b (a0)+,d0
        move.b (a1)+,d1
        or.b d0,d1
        beq.s .match
        tst.b d0
        beq.s .next
        move.b -1(a1),d1
        beq.s .next
        ori.b #$20,d0
        ori.b #$20,d1
        cmp.b d0,d1
        bne.s .next
        dbf d2,.compare
        bra.s .next
.match:
        tst.w d6
        bne tr_bad_file
        moveq #1,d6
        movea.l a4,a0
        lea TR_RECORD+PCREL(pc),a1
        moveq #7,d0
.record:
        move.l (a0)+,(a1)+
        dbf d0,.record
.next:
        lea 32(a4),a4
        subq.w #1,d7
        bne.s .find
        tst.w d6
        beq tr_absent
        tst.b TR_RECORD+21
        bne tr_bad_file
        move.l TR_RECORD+28+PCREL(pc),d0
        beq tr_bad_file
        cmpi.l #EDITOR_READBACK_BYTES,d0
        bhi tr_bad_file
        tst.w TR_KIND
        beq.s .map_size
        cmpi.l #EDITOR_SPT_BYTES,d0
        bhi tr_bad_file
        move.l d0,d1
        divu #10,d1
        swap d1
        tst.w d1
        bne tr_bad_file
        bra.s .size
.map_size:
        cmpi.l #18,d0
        blo tr_bad_file
.size:
        move.l d0,TR_LENGTH
        move.l d0,TR_REMAINING
        move.l #EDITOR_READBACK_BASE,TR_DESTINATION
        moveq #0,d0
        move.b TR_RECORD+26+PCREL(pc),d0
        move.w d0,TR_TRACK
        move.b TR_RECORD+27+PCREL(pc),d0
        move.w d0,TR_SECTOR
        move.w #-1,TR_CACHED
        lea TR_SEEN+PCREL(pc),a0
        moveq #79,d0
.clear_seen:
        clr.l (a0)+
        dbf d0,.clear_seen
tr_sector_loop:
        bsr tr_cancel_check
        bne tr_return
        move.w TR_TRACK+PCREL(pc),d2
        cmpi.w #3,d2
        blo tr_bad_file
        cmpi.w #160,d2
        bhs tr_bad_file
        move.w TR_SECTOR+PCREL(pc),d4
        cmpi.w #11,d4
        bhs tr_bad_file
        move.w d2,d0
        add.w d0,d0
        lea TR_SEEN+PCREL(pc),a0
        move.w (a0,d0.w),d1
        bset d4,d1
        bne tr_bad_file
        move.w d1,(a0,d0.w)
        cmp.w TR_CACHED+PCREL(pc),d2
        beq.s .cached
        bsr template_read_track
        bne tr_return
        move.w d2,TR_CACHED
.cached:
        moveq #0,d0
        move.w d4,d0
        lsl.l #8,d0
        add.l d0,d0
        movea.l sensi_track_scratch_pointer,a3
        lea 20(a3,d0.l),a3
        moveq #0,d0
        move.b 510(a3),d0
        move.w d0,TR_TRACK
        move.b 511(a3),d0
        move.w d0,TR_SECTOR
        move.l TR_REMAINING+PCREL(pc),d5
        cmpi.l #510,d5
        bls.s .count
        move.l #510,d5
.count:
        bsr tr_cancel_check
        bne.s tr_return
        sub.l d5,TR_REMAINING
        movea.l TR_DESTINATION+PCREL(pc),a1
        subq.w #1,d5
template_read_before_copy:
.copy:
        move.b (a3)+,(a1)+
        dbf d5,.copy
        move.l a1,TR_DESTINATION
        tst.l TR_REMAINING
        bne tr_sector_loop
        ; Original files terminate at their stored byte count. The unused
        ; final-sector link may point onward and is not followed.
template_read_before_verify:
        moveq #2,d2
        bsr.s template_read_track
        bne.s tr_return
        movea.l sensi_track_scratch_pointer,a0
        lea 20(a0),a0
        move.l #5632,d1
        bsr read_crc32
        cmp.l TR_DIRECTORY_CRC+PCREL(pc),d0
        bne.s tr_bad_media
        bsr tr_cancel_check
        bne.s tr_return
        move.l TR_LENGTH+PCREL(pc),d0
        bra.s tr_return
tr_bad_argument:
        moveq #-1,d0
        bra.s tr_return
tr_bad_media:
        moveq #-2,d0
        bra.s tr_return
tr_bad_file:
        moveq #-3,d0
        bra.s tr_return
tr_absent:
        moveq #-5,d0
tr_return:
        tst.b TR_STARTED
        beq.s .registers
        move.l d0,-(sp)
        move.w TR_KEEP+PCREL(pc),d1
        moveq #36,d0
        jsr sensi_disk_command
        move.l (sp)+,d0
.registers:
        movem.l (sp)+,d1-d7/a0-a6
        tst.l d0
        rts

; Command 44 decodes a whole track but copies one owned byte. Native SOS6
; media is refused.
template_read_track:
        movem.l d1-d7/a0-a6,-(sp)
        bsr.s tr_cancel_check
        bne.s .return
        movea.l sensi_track_scratch_pointer,a0
        clr.l SENSI_TRACK_MAGIC_OFFSET(a0)
        lea TR_BYTE+PCREL(pc),a1
        moveq #1,d1
        moveq #44,d0
        jsr sensi_disk_command
        tst.w d0
        bne.s .read_error
        movea.l sensi_track_scratch_pointer,a0
        cmpi.l #SENSI_NATIVE_MAGIC,SENSI_TRACK_MAGIC_OFFSET(a0)
        beq.s .media
        move.b #2,TR_STARTED
        bsr.s tr_cancel_check
        bra.s .return
.media:
        moveq #-2,d0
        bra.s .return
.read_error:
        moveq #-6,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.l d0
        rts
tr_cancel_check:
        cmpi.w #$C5,native_last_key
        beq.s .cancel
        cmpi.b #$45,native_raw_key+1
        bne.s .latched
.cancel:
        move.w #1,TR_CANCEL
.latched:
        moveq #-4,d0
        tst.w TR_CANCEL
        bne.s .return
        moveq #-2,d0
        move.w sensi_selected_drive,d1
        cmp.w TR_DRIVE+PCREL(pc),d1
        bne.s .return
.ok:
        moveq #0,d0
.return:
        tst.l d0
        rts

template_read_end:
        ifgt TR_CANCEL+2-EDITOR_SERIAL_WORK_BASE-EDITOR_SERIAL_WORK_BYTES
        fail "Template reader exceeds scratch allocation"
        endif
