; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; D0.l source phase0..5. Exactly three qualified reads stage one diagnostic payload.
; The source manifest stays canonical and unchanged: its immutable AUR identity
; is revalidated against the read CFMI before either dependency is accepted.
; UI and the512-byte metadata/AUR snapshot survive all reader/parser work.
; READBACK ends with MAP; tail retains zero-padded SPT432 and metadata256.
; All other registers preserved. No canonical or page publication.
vdm_stage:
        movem.l d1-d7/a0-a6,-(sp)
        cmpi.l #5,d0
        bhi vdm_stage_argument
        move.w d0,d6
        bsr vdm_read_source
        bne vdm_stage_return
        moveq #0,d1
        move.w d6,d1
        bsr vdm_parse_source
        bne.s vdm_stage_return
        lea EDITOR_SERIAL_WORK_BASE,a0
        lea VD_METADATA,a1
        move.w #256,d0
        bsr vdm_copy
        lea VD_METADATA+CFMD_SPT_NAME,a0
        moveq #0,d0
        move.w VD_METADATA+CFMD_SPT_BYTES,d0
        move.l VD_METADATA+CFMD_SPT_CRC,d1
        bsr vdm_read_dependency
        bne.s vdm_stage_return
        lea VD_STAGE_SPT,a1
        moveq #0,d1
        move.w #107,d0
.clear:
        move.l d1,(a1)+
        dbf d0,.clear
        lea EDITOR_READBACK_BASE,a0
        lea VD_STAGE_SPT,a1
        moveq #0,d0
        move.w VD_METADATA+CFMD_SPT_BYTES,d0
        bsr vdm_copy
        lea VD_METADATA+CFMD_MAP_NAME,a0
        moveq #0,d0
        move.w VD_METADATA+CFMD_MAP_BYTES,d0
        move.l VD_METADATA+CFMD_MAP_CRC,d1
        bsr vdm_read_dependency
        bne.s vdm_stage_return
        bsr vdm_epoch
        bra.s vdm_stage_return
vdm_stage_argument:
        moveq #VDM_ERROR_SOURCE,d0
vdm_stage_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; Fresh source manifest in READBACK, pinned to the captured author record.
vdm_read_source:
        bsr vdm_epoch
        bne .return
        btst #0,VDM_OWNER+AUR_FLAGS+1
        beq.s .source_error
        lea VDM_OWNER+AUR_SOURCE_NAME,a0
        lea STORAGE_CONTEXT,a1
        moveq #3,d0
.name:
        move.l (a0)+,(a1)+
        dbf d0,.name
        bsr vdm_reader_identity
        move.l VDM_OWNER+AUR_SOURCE_BYTES,STORAGE_CONTEXT+STORAGE_READ_EXPECTED_BYTES
        move.l #4096,STORAGE_CONTEXT+STORAGE_READ_CAPACITY
        clr.l STORAGE_CONTEXT+STORAGE_READ_EXPECTED_CRC
        clr.l STORAGE_CONTEXT+STORAGE_READ_FLAGS
        lea STORAGE_CONTEXT,a0
        bsr storage_read_entry
        tst.w d0
        bne.s .return
        move.l read_directory_crc,d1
        tst.w VDM_DIRECTORY_VALID
        beq.s .capture
        cmp.l VDM_DIRECTORY,d1
        bne.s .directory_error
        bra.s .pinned
.capture:
        move.l d1,VDM_DIRECTORY
        move.w #1,VDM_DIRECTORY_VALID
.pinned:
        bra vdm_epoch
.directory_error:
        moveq #STORAGE_READ_MEDIA,d0
        bra.s .return
.source_error:
        moveq #VDM_ERROR_SOURCE,d0
.return:
        tst.w d0
        rts

; D1.w chosen source index; READBACK CFMI, output WORK0..511, scratch512..1023.
; The reader already enforced exact source bytes; parser enforces bodyCRC/schema.
vdm_parse_source:
        lea EDITOR_READBACK_BASE,a0
        move.l VDM_OWNER+AUR_SOURCE_BYTES,d0
        lea VDM_OWNER+AUR_SOURCE_NAME,a1
        lea EDITOR_SERIAL_WORK_BASE,a2
        lea EDITOR_SERIAL_WORK_BASE+512,a3
        bsr cfmi_parse
        tst.w d0
        bne.s .return
        moveq #VDM_ERROR_SOURCE,d0
        move.l VDM_OWNER+AUR_SOURCE_ID,d1
        cmp.l EDITOR_SERIAL_WORK_BASE+CFMD_ID,d1
        bne.s .return
        move.l VDM_OWNER+AUR_SOURCE_CRC,d1
        cmp.l EDITOR_SERIAL_WORK_BASE+CFMD_MANIFEST_CRC,d1
        bne.s .return
        move.w VDM_OWNER+AUR_SOURCE_REVISION,d1
        cmp.w EDITOR_SERIAL_WORK_BASE+CFMD_REVISION,d1
        bne.s .return
        move.b EDITOR_SERIAL_WORK_BASE+CFMD_PHASE_COUNT,VDM_SOURCE_COUNT+1
        moveq #0,d0
.return:
        tst.w d0
        rts

; A0=name16,D0.l exact length,D1.l full fileCRC. Preserve D1-D7/A0-A6.
vdm_read_dependency:
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
        bsr.s vdm_reader_identity
        bsr.s vdm_epoch
        bne.s .return
        lea STORAGE_CONTEXT,a0
        bsr storage_read_entry
        tst.w d0
        bne.s .return
        moveq #STORAGE_READ_MEDIA,d0
        move.l read_directory_crc,d1
        cmp.l VDM_DIRECTORY,d1
        bne.s .return
        bsr.s vdm_epoch
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
vdm_reader_identity:
        lea VDM_OWNER+AUR_DISK_ID,a0
        lea STORAGE_CONTEXT+16,a1
        moveq #3,d0
.id:
        move.l (a0)+,(a1)+
        dbf d0,.id
        rts
vdm_epoch:
        moveq #STORAGE_READ_CANCELLED,d0
        tst.l STORAGE_CONTEXT+STORAGE_READ_CANCEL
        bne.s .return
        moveq #STORAGE_READ_MEDIA,d0
        tst.w VDM_OWNER+AUR_DRIVE
        bne.s .return
        moveq #0,d0
.return:
        tst.w d0
        rts
vdm_copy:
        subq.w #1,d0
.copy:
        move.b (a0)+,(a1)+
        dbf d0,.copy
        rts
