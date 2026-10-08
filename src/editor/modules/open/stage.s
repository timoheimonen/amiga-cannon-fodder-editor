; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        section .text,code
        xdef open_stage,open_stage_end,open_stage_ready
        xdef open_stage_before_manifest,open_stage_before_spt,open_stage_before_map

; D0.w=selected phase 0..5; A0=fixed STORAGE_CONTEXT with manifest basename
; and expected CFDI disk ID. Caller qualifies the Custom directory.
; D0.w=0 on success, otherwise parser/payload/reader status. Preserve all
; other registers. No canonical data, AUR, undo, manifest workspace or campaign
; publication occurs here. On failure every staging byte is disposable.
;
; READBACK holds each read, ending with the selected MAP. A reserved overlay
; tail retains the manifest, SPT and CFMD. WORK0..1023 is parser output/scratch,
; or the raw reader's scratch, or CFVR32 plus payload scratch, never concurrent.
; Validate every phase, with the selected phase last. Require one directory
; fingerprint across all reads as well as each reader's CFDI/CRC/cancel checks.
OPEN_RESERVED_BYTES equ 4928
OPEN_STAGE_MANIFEST equ EDITOR_MODULE_BASE+EDITOR_SERIALIZER_BYTES-OPEN_RESERVED_BYTES
OPEN_STAGE_SPT equ OPEN_STAGE_MANIFEST+4096
OPEN_STAGE_METADATA equ OPEN_STAGE_MANIFEST+4528
OPEN_STAGE_MAP equ EDITOR_READBACK_BASE
OPEN_STAGE_RESULT equ EDITOR_SERIAL_WORK_BASE
OS_NAME equ 0
OS_ID equ 16
OS_LENGTH equ 32
OS_DIRECTORY_CRC equ 36
OS_SELECTED equ 40
OS_PHASE equ 42
OS_COUNT equ 44
OS_LAST equ 46
OS_ERRORS equ 48
OS_REVIEWS equ 52
OS_DRIVE equ 56
OS_FRAME equ 60

open_stage:
        movem.l d1-d7/a0-a6,-(sp)
        lea -OS_FRAME(sp),sp
        movea.l sp,a6
        move.w d0,OS_SELECTED(a6)
        cmpi.w #5,d0
        bhi os_argument
        cmpa.l #STORAGE_CONTEXT,a0
        bne os_argument
        lea STORAGE_CONTEXT+PCREL(pc),a0
        movea.l a6,a1
        moveq #7,d1
.copy:
        move.l (a0)+,(a1)+
        dbf d1,.copy
        clr.l OS_ERRORS(a6)
        clr.l OS_REVIEWS(a6)
        clr.w OS_LAST(a6)
        clr.w OS_DRIVE(a6)
        bsr os_epoch
        bne os_return
        clr.l STORAGE_CONTEXT+STORAGE_READ_EXPECTED_BYTES
        move.l #4096,STORAGE_CONTEXT+STORAGE_READ_CAPACITY
        clr.l STORAGE_CONTEXT+STORAGE_READ_EXPECTED_CRC
        clr.l STORAGE_CONTEXT+STORAGE_READ_FLAGS
open_stage_before_manifest:
        lea STORAGE_CONTEXT+PCREL(pc),a0
        bsr storage_read_entry
        tst.w d0
        bne os_return
        move.l read_directory_crc,OS_DIRECTORY_CRC(a6)
        move.l STORAGE_CONTEXT+STORAGE_READ_RESULT_BYTES+PCREL(pc),d0
        move.l d0,OS_LENGTH(a6)
        lea EDITOR_READBACK_BASE+PCREL(pc),a0
        lea OPEN_STAGE_MANIFEST+PCREL(pc),a1
        bsr os_copy
        move.w OS_SELECTED(a6),d1
        bsr os_parse
        bne os_return
        moveq #0,d0
        move.b OPEN_STAGE_METADATA+CFMD_PHASE_COUNT+PCREL(pc),d0
        move.w d0,OS_COUNT(a6)
        ifd OPEN_TEST_SELECTED
        bsr test_stage_pin
        bne os_return
        bra.s os_selected
        endif
        clr.w OS_PHASE(a6)
os_next:
        move.w OS_PHASE(a6),d1
        cmp.w OS_COUNT(a6),d1
        bhs.s os_selected
        cmp.w OS_SELECTED(a6),d1
        bne.s os_phase
        addq.w #1,OS_PHASE(a6)
        bra.s os_next
os_selected:
        move.w OS_SELECTED(a6),d1
        move.w #1,OS_LAST(a6)
os_phase:
        bsr os_parse
        bne os_return
        lea OPEN_STAGE_METADATA+CFMD_SPT_NAME+PCREL(pc),a0
        moveq #0,d0
        move.w OPEN_STAGE_METADATA+CFMD_SPT_BYTES+PCREL(pc),d0
        move.l OPEN_STAGE_METADATA+CFMD_SPT_CRC+PCREL(pc),d1
open_stage_before_spt:
        bsr os_dependency
        bne os_return
        lea OPEN_STAGE_SPT+PCREL(pc),a1
        move.w #EDITOR_SPT_BYTES/2-1,d0
.clear_spt:
        clr.w (a1)+
        dbf d0,.clear_spt
        lea EDITOR_READBACK_BASE+PCREL(pc),a0
        lea OPEN_STAGE_SPT+PCREL(pc),a1
        moveq #0,d0
        move.w OPEN_STAGE_METADATA+CFMD_SPT_BYTES+PCREL(pc),d0
        bsr os_copy
        lea OPEN_STAGE_METADATA+CFMD_MAP_NAME+PCREL(pc),a0
        moveq #0,d0
        move.w OPEN_STAGE_METADATA+CFMD_MAP_BYTES+PCREL(pc),d0
        move.l OPEN_STAGE_METADATA+CFMD_MAP_CRC+PCREL(pc),d1
open_stage_before_map:
        bsr os_dependency
        bne.s os_return
        lea OPEN_STAGE_MAP+PCREL(pc),a0
        lea OPEN_STAGE_SPT+PCREL(pc),a1
        lea OPEN_STAGE_METADATA+PCREL(pc),a2
        lea OPEN_STAGE_RESULT+PCREL(pc),a3
        lea EDITOR_SERIAL_WORK_BASE+32+PCREL(pc),a4
        moveq #0,d0
        move.w CFMD_MAP_BYTES(a2),d0
        moveq #0,d1
        move.w CFMD_SPT_BYTES(a2),d1
        bsr cf_payload_validate
        tst.w d0
        bne.s os_return
        move.l OPEN_STAGE_RESULT+CFVR_ERRORS+PCREL(pc),d0
        or.l d0,OS_ERRORS(a6)
        move.l OPEN_STAGE_RESULT+CFVR_REVIEWS+PCREL(pc),d0
        or.l d0,OS_REVIEWS(a6)
        tst.w OS_LAST(a6)
        bne.s .ready
        addq.w #1,OS_PHASE(a6)
        bra os_next
.ready:
        bsr os_epoch
        bne.s os_return
        move.l OS_ERRORS(a6),OPEN_STAGE_RESULT+CFVR_ERRORS
        move.l OS_REVIEWS(a6),OPEN_STAGE_RESULT+CFVR_REVIEWS
        moveq #0,d0
open_stage_ready:
        bra.s os_return
os_argument:
        moveq #STORAGE_READ_INVALID,d0
os_return:
        lea OS_FRAME(sp),sp
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; D1.w selects the phase; parser validates the entire manifest schema.
os_parse:
        lea OPEN_STAGE_MANIFEST+PCREL(pc),a0
        move.l OS_LENGTH(a6),d0
        lea OS_NAME(a6),a1
        lea EDITOR_SERIAL_WORK_BASE+PCREL(pc),a2
        lea EDITOR_SERIAL_WORK_BASE+512+PCREL(pc),a3
        bsr cfmi_parse
        tst.w d0
        bne.s .return
        lea EDITOR_SERIAL_WORK_BASE+PCREL(pc),a0
        lea OPEN_STAGE_METADATA+PCREL(pc),a1
        move.w #EDITOR_METADATA_BYTES,d0
        bsr.s os_copy
        moveq #0,d0
.return:
        tst.w d0
        rts

; A0=filename16, D0.l=length, D1.l=expected CRC.
os_dependency:
        move.l d0,STORAGE_CONTEXT+STORAGE_READ_EXPECTED_BYTES
        move.l d0,STORAGE_CONTEXT+STORAGE_READ_CAPACITY
        move.l d1,STORAGE_CONTEXT+STORAGE_READ_EXPECTED_CRC
        move.l #STORAGE_READ_CHECK_CRC*65536,STORAGE_CONTEXT+STORAGE_READ_FLAGS
        lea STORAGE_CONTEXT+PCREL(pc),a1
        moveq #3,d0
.name:
        move.l (a0)+,(a1)+
        dbf d0,.name
        lea OS_ID(a6),a0
        moveq #3,d0
.id:
        move.l (a0)+,(a1)+
        dbf d0,.id
        bsr.s os_epoch
        bne.s .return
        lea STORAGE_CONTEXT+PCREL(pc),a0
        bsr storage_read_entry
        tst.w d0
        bne.s .return
        moveq #STORAGE_READ_MEDIA,d0
        move.l read_directory_crc,d1
        cmp.l OS_DIRECTORY_CRC(a6),d1
        bne.s .return
        bsr.s os_epoch
.return:
        tst.w d0
        rts
os_epoch:
        moveq #STORAGE_READ_CANCELLED,d0
        tst.l STORAGE_CONTEXT+STORAGE_READ_CANCEL
        bne.s .return
        moveq #STORAGE_READ_MEDIA,d0
        tst.w OS_DRIVE(a6)
        bne.s .return
        moveq #0,d0
.return:
        tst.w d0
        rts
os_copy:
        subq.w #1,d0
.copy:
        move.b (a0)+,(a1)+
        dbf d0,.copy
        rts
open_stage_end:
        ifgt open_stage_end-open_stage-(EDITOR_SERIALIZER_BYTES-OPEN_RESERVED_BYTES)
        fail "Open stage overlaps reserved candidate data"
        endif
        ifgt OPEN_STAGE_METADATA+EDITOR_METADATA_BYTES-EDITOR_MODULE_BASE-EDITOR_SERIALIZER_BYTES
        fail "Open candidate exceeds module window"
        endif
