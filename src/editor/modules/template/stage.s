; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        section .text,code
        xdef template_stage,template_stage_end,template_stage_ready
        xdef template_stage_before_map

; D0.w=mission 0..23, D1.w=phase, D2.w=drive 0..3. Return D0.l=0 or
; a negative metadata/transport/decoder/structural status. Preserve D1-D7/A0-A6.
; No canonical draft, undo, source identity or campaign writes. Failed scratch
; is disposable. Caller owns an inactive display and restores the drive selection.
; Reader owns READBACK/WORK0..399, SPT and metadata occupy separate WORK slices.
; Copy compressed MAP into the reserved overlay tail before decoding into
; READBACK. This tail is data, never executable code or a published module size.
TPL_STAGE_MAP       equ EDITOR_READBACK_BASE
TPL_STAGE_SPT       equ EDITOR_SERIAL_WORK_BASE+400
TPL_STAGE_METADATA  equ EDITOR_SERIAL_WORK_BASE+832
TPL_PACKED_BYTES    equ 4992
TPL_PACKED_BASE     equ EDITOR_MODULE_BASE+EDITOR_SERIALIZER_BYTES-TPL_PACKED_BYTES
TS_MISSION equ 0
TS_PHASE equ 2
TS_MAP equ 4
TS_DRIVE equ 6
TS_DIRECTORY_CRC equ 8
TS_PACKED_BYTES equ 12
TS_FRAME equ 16

template_stage:
        movem.l d1-d7/a0-a6,-(sp)
        lea -TS_FRAME(sp),sp
        movea.l sp,a6
        cmpi.w #3,d2
        bhi ts_bad
        move.w d0,TS_MISSION(a6)
        move.w d1,TS_PHASE(a6)
        move.w d2,TS_DRIVE(a6)
        bsr template_lookup
        bmi ts_return
        move.w d0,TS_MAP(a6)
        move.w TS_MISSION(a6),d0
        move.w TS_PHASE(a6),d1
        lea TPL_STAGE_METADATA+PCREL(pc),a0
        bsr template_metadata
        bne ts_return
        move.w TS_DRIVE(a6),d1
        moveq #-1,d3
        movea.l d3,a0
        moveq #0,d0
        jsr sensi_disk_command
        tst.w d0
        bne ts_media
        move.w TS_MAP(a6),d0
        moveq #1,d1
        bsr template_read_file
        tst.l d0
        bmi ts_return
        move.l TR_DIRECTORY_CRC+PCREL(pc),TS_DIRECTORY_CRC(a6)
        move.w d0,TPL_STAGE_METADATA+CFMD_SPT_BYTES
        lea TPL_STAGE_SPT+PCREL(pc),a0
        move.w #EDITOR_SPT_BYTES/2-1,d1
.clear_spt:
        clr.w (a0)+
        dbf d1,.clear_spt
        lea EDITOR_READBACK_BASE+PCREL(pc),a0
        lea TPL_STAGE_SPT+PCREL(pc),a1
        subq.w #1,d0
.spt:
        move.b (a0)+,(a1)+
        dbf d0,.spt
template_stage_before_map:
        move.w TS_MAP(a6),d0
        moveq #0,d1
        bsr template_read_file
        tst.l d0
        bmi ts_return
        cmpi.l #TPL_PACKED_BYTES,d0
        bhi ts_bounds
        move.l TR_DIRECTORY_CRC+PCREL(pc),d1
        cmp.l TS_DIRECTORY_CRC(a6),d1
        bne ts_media
        move.l d0,TS_PACKED_BYTES(a6)
        lea EDITOR_READBACK_BASE+PCREL(pc),a0
        lea TPL_PACKED_BASE+PCREL(pc),a1
        subq.w #1,d0
.packed:
        move.b (a0)+,(a1)+
        dbf d0,.packed
        lea TPL_PACKED_BASE+PCREL(pc),a0
        move.l TS_PACKED_BYTES(a6),d0
        lea TPL_STAGE_MAP+PCREL(pc),a1
        move.l #EDITOR_READBACK_BYTES,d1
        bsr template_rnc_unpack
        tst.l d0
        bmi.s ts_return
        move.w d0,TPL_STAGE_METADATA+CFMD_MAP_BYTES
        move.l d0,d1
        lea TPL_STAGE_MAP+PCREL(pc),a0
        bsr read_crc32
        move.l d0,TPL_STAGE_METADATA+CFMD_MAP_CRC
        moveq #0,d1
        move.w TPL_STAGE_METADATA+CFMD_SPT_BYTES+PCREL(pc),d1
        lea TPL_STAGE_SPT+PCREL(pc),a0
        bsr read_crc32
        move.l d0,TPL_STAGE_METADATA+CFMD_SPT_CRC
        lea TPL_STAGE_MAP+PCREL(pc),a0
        moveq #0,d0
        move.w TPL_STAGE_METADATA+CFMD_MAP_BYTES+PCREL(pc),d0
        lea TPL_STAGE_SPT+PCREL(pc),a1
        moveq #0,d1
        move.w TPL_STAGE_METADATA+CFMD_SPT_BYTES+PCREL(pc),d1
        lea TPL_STAGE_METADATA+PCREL(pc),a2
        lea EDITOR_SERIAL_WORK_BASE+PCREL(pc),a3
        lea EDITOR_SERIAL_WORK_BASE+32+PCREL(pc),a4
        bsr cf_payload_validate
        ext.l d0
template_stage_ready:
        bra.s ts_return
ts_bad:
        moveq #-1,d0
        bra.s ts_return
ts_bounds:
        moveq #-3,d0
        bra.s ts_return
ts_media:
        moveq #-6,d0
ts_return:
        lea TS_FRAME(sp),sp
        movem.l (sp)+,d1-d7/a0-a6
        tst.l d0
        rts
template_stage_end:
        ifgt TPL_STAGE_METADATA+EDITOR_METADATA_BYTES-EDITOR_SERIAL_WORK_BASE-EDITOR_SERIAL_WORK_BYTES
        fail "Template metadata stage exceeds WORK"
        endif
        ifgt template_stage_end-template_stage-(EDITOR_SERIALIZER_BYTES-TPL_PACKED_BYTES)
        fail "Template stage code overlaps compressed input"
        endif
