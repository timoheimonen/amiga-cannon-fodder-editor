; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; D0.l source phase0..5. Exactly three qualified reads stage one replacement.
; The source manifest stays canonical and unchanged: its immutable AUR identity
; is revalidated against the read CFMI before either dependency is accepted.
; UI and the512-byte metadata/AUR snapshot survive all reader/parser work.
; READBACK ends with MAP; tail retains zero-padded SPT432 and metadata384.
; All other registers preserved. No canonical or page publication.
phl_stage:
        movem.l d1-d7/a0-a6,-(sp)
        cmpi.l #5,d0
        bhi phl_stage_argument
        move.w d0,d6
        bsr phl_read_source
        bne phl_stage_return
        move.w d6,d1
        bsr phl_parse_source
        bne phl_stage_return
        lea EDITOR_SERIAL_WORK_BASE,a0
        lea PHL_STAGE_METADATA,a1
        move.w #384,d0
        bsr phl_copy
        lea PHL_STAGE_METADATA+CFMD_SPT_NAME,a0
        moveq #0,d0
        move.w PHL_STAGE_METADATA+CFMD_SPT_BYTES,d0
        move.l PHL_STAGE_METADATA+CFMD_SPT_CRC,d1
        bsr phl_read_dependency
        bne phl_stage_return
        lea PHL_STAGE_SPT,a1
        moveq #0,d1
        move.w #107,d0
.clear:
        move.l d1,(a1)+
        dbf d0,.clear
        lea EDITOR_READBACK_BASE,a0
        lea PHL_STAGE_SPT,a1
        moveq #0,d0
        move.w PHL_STAGE_METADATA+CFMD_SPT_BYTES,d0
        bsr phl_copy
        lea PHL_STAGE_METADATA+CFMD_MAP_NAME,a0
        moveq #0,d0
        move.w PHL_STAGE_METADATA+CFMD_MAP_BYTES,d0
        move.l PHL_STAGE_METADATA+CFMD_MAP_CRC,d1
        bsr phl_read_dependency
        bne.s phl_stage_return
        lea EDITOR_READBACK_BASE,a0
        lea PHL_STAGE_SPT,a1
        lea PHL_STAGE_METADATA,a2
        lea EDITOR_SERIAL_WORK_BASE,a3
        lea EDITOR_SERIAL_WORK_BASE+32,a4
        moveq #0,d0
        move.w PHL_STAGE_METADATA+CFMD_MAP_BYTES,d0
        moveq #0,d1
        move.w PHL_STAGE_METADATA+CFMD_SPT_BYTES,d1
        bsr cf_payload_validate
        tst.w d0
        bne.s phl_stage_return
        bsr phl_epoch
        bra.s phl_stage_return
phl_stage_argument:
        moveq #PHL_ERROR_SOURCE,d0
phl_stage_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; Fresh source manifest in READBACK, pinned to the captured author record.
phl_read_source:
        bsr phl_epoch
        bne.s .return
        btst #0,PHL_OWNER+AUR_FLAGS+1
        beq.s .source_error
        lea PHL_OWNER+AUR_SOURCE_NAME,a0
        lea STORAGE_CONTEXT,a1
        moveq #3,d0
.name:
        move.l (a0)+,(a1)+
        dbf d0,.name
        bsr phl_reader_identity
        move.l PHL_OWNER+AUR_SOURCE_BYTES,STORAGE_CONTEXT+STORAGE_READ_EXPECTED_BYTES
        move.l #4096,STORAGE_CONTEXT+STORAGE_READ_CAPACITY
        clr.l STORAGE_CONTEXT+STORAGE_READ_EXPECTED_CRC
        clr.l STORAGE_CONTEXT+STORAGE_READ_FLAGS
        lea STORAGE_CONTEXT,a0
        bsr storage_read_entry
        tst.w d0
        bne.s .return
        move.l read_directory_crc,PHL_DIRECTORY_CRC
        bra phl_epoch
.source_error:
        moveq #PHL_ERROR_SOURCE,d0
.return:
        tst.w d0
        rts

; D1.w chosen source index; READBACK CFMI, output WORK0..511, scratch512..1023.
; The reader already enforced exact source bytes; parser enforces bodyCRC/schema.
phl_parse_source:
        lea EDITOR_READBACK_BASE,a0
        move.l PHL_OWNER+AUR_SOURCE_BYTES,d0
        lea PHL_OWNER+AUR_SOURCE_NAME,a1
        lea EDITOR_SERIAL_WORK_BASE,a2
        lea EDITOR_SERIAL_WORK_BASE+512,a3
        bsr cfmi_parse
        tst.w d0
        bne.s .return
        moveq #PHL_ERROR_SOURCE,d0
        move.l PHL_OWNER+AUR_SOURCE_ID,d1
        cmp.l EDITOR_SERIAL_WORK_BASE+CFMD_ID,d1
        bne.s .return
        move.l PHL_OWNER+AUR_SOURCE_CRC,d1
        cmp.l EDITOR_SERIAL_WORK_BASE+CFMD_MANIFEST_CRC,d1
        bne.s .return
        move.w PHL_OWNER+AUR_SOURCE_REVISION,d1
        cmp.w EDITOR_SERIAL_WORK_BASE+CFMD_REVISION,d1
        bne.s .return
        move.b EDITOR_SERIAL_WORK_BASE+CFMD_PHASE_COUNT,PHL_SOURCE_COUNT
        moveq #0,d0
.return:
        tst.w d0
        rts

; A0=name16,D0.l exact length,D1.l full fileCRC. Preserve D1-D7/A0-A6.
phl_read_dependency:
        movem.l d1-d7/a0-a6,-(sp)
        move.l d0,STORAGE_CONTEXT+STORAGE_READ_EXPECTED_BYTES
        move.l d0,STORAGE_CONTEXT+STORAGE_READ_CAPACITY
        move.l d1,STORAGE_CONTEXT+STORAGE_READ_EXPECTED_CRC
        move.l #STORAGE_READ_CHECK_CRC*65536,STORAGE_CONTEXT+STORAGE_READ_FLAGS
        lea STORAGE_CONTEXT,a1
        moveq #3,d0
.name:
        move.l (a0)+,(a1)+
        dbf d0,.name
        bsr.s phl_reader_identity
        bsr.s phl_epoch
        bne.s .return
        lea STORAGE_CONTEXT,a0
        bsr storage_read_entry
        tst.w d0
        bne.s .return
        moveq #STORAGE_READ_MEDIA,d0
        move.l read_directory_crc,d1
        cmp.l PHL_DIRECTORY_CRC,d1
        bne.s .return
        bsr.s phl_epoch
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
phl_reader_identity:
        lea PHL_OWNER+AUR_DISK_ID,a0
        lea STORAGE_CONTEXT+16,a1
        moveq #3,d0
.id:
        move.l (a0)+,(a1)+
        dbf d0,.id
        rts
phl_epoch:
        moveq #STORAGE_READ_CANCELLED,d0
        tst.l STORAGE_CONTEXT+STORAGE_READ_CANCEL
        bne.s .return
        moveq #STORAGE_READ_MEDIA,d0
        tst.w PHL_OWNER+AUR_DRIVE
        bne.s .return
        moveq #0,d0
.return:
        tst.w d0
        rts
phl_copy:
        subq.w #1,d0
.copy:
        move.b (a0)+,(a1)+
        dbf d0,.copy
        rts
